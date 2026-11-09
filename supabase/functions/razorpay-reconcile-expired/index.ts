import { constantTimeEqual, env, json, razorpayRequest, serviceClient } from '../_shared/razorpay.ts';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const supplied = request.headers.get('x-reconcile-secret') ?? '';
  if (!constantTimeEqual(env('RAZORPAY_RECONCILE_SECRET'), supplied)) return json({ error: 'Unauthorized' }, 401);
  const admin = serviceClient();
  const { data: attempts, error } = await admin.from('razorpay_checkout_attempts')
    .select('id,razorpay_order_id,amount_paise,status')
    .eq('status', 'reserved').lt('expires_at', new Date().toISOString()).limit(100);
  if (error) return json({ error: 'Could not load expired checkout attempts' }, 500);
  let finalized = 0;
  let released = 0;
  let waiting = 0;
  for (const attempt of attempts ?? []) {
    try {
      if (!attempt.razorpay_order_id) {
        const { error: releaseError } = await admin.rpc('release_razorpay_checkout', { p_attempt_id: attempt.id });
        if (releaseError) waiting++; else released++;
        continue;
      }
      const result = await razorpayRequest(`/orders/${encodeURIComponent(attempt.razorpay_order_id)}/payments`);
      const payments = result.items ?? [];
      let payable = payments.find((payment: any) => payment.status === 'captured');
      const authorized = payments.find((payment: any) => payment.status === 'authorized');
      if (!payable && authorized) {
        payable = await razorpayRequest(`/payments/${encodeURIComponent(authorized.id)}/capture`, {
          method: 'POST', body: JSON.stringify({ amount: Number(attempt.amount_paise), currency: 'INR' }),
        });
      }
      if (payable) {
        if (payable.status !== 'captured' || Number(payable.amount) !== Number(attempt.amount_paise) || payable.currency !== 'INR') {
          waiting++;
          continue;
        }
        const { error: finalizeError } = await admin.rpc('finalize_razorpay_checkout', {
          p_attempt_id: attempt.id, p_razorpay_order_id: attempt.razorpay_order_id,
          p_razorpay_payment_id: payable.id,
        });
        if (finalizeError) waiting++; else finalized++;
        continue;
      }
      const { error: releaseError } = await admin.rpc('release_razorpay_checkout', { p_attempt_id: attempt.id });
      if (releaseError) waiting++; else released++;
    } catch (_) {
      // Unknown gateway state is never treated as a safe stock release.
      waiting++;
    }
  }
  return json({ checked: attempts?.length ?? 0, finalized, released, waiting });
});
