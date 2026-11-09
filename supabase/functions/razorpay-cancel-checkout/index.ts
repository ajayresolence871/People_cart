import { authenticatedUser, errorMessage, json, razorpayRequest, serviceClient } from '../_shared/razorpay.ts';

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info' } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await authenticatedUser(request);
    const body = await request.json();
    const admin = serviceClient();
    const { data: attempt, error } = await admin.from('razorpay_checkout_attempts')
      .select('id,user_id,razorpay_order_id,status').eq('id', String(body.attempt_id ?? '')).maybeSingle();
    if (error || !attempt || attempt.user_id !== user.id || attempt.razorpay_order_id !== body.razorpay_order_id) {
      return json({ error: 'Checkout attempt not found' }, 404);
    }
    if (attempt.status !== 'reserved') return json({ released: false });
    const payments = await razorpayRequest(`/orders/${encodeURIComponent(attempt.razorpay_order_id)}/payments`);
    const payable = (payments.items ?? []).some((payment: { status?: string }) =>
      payment.status === 'authorized' || payment.status === 'captured');
    if (payable) return json({ released: false, payment_pending: true });
    const { error: releaseError } = await admin.rpc('release_razorpay_checkout', { p_attempt_id: attempt.id });
    if (releaseError) throw new Error('Could not safely release the payment reservation');
    return json({ released: true });
  } catch (error) {
    return json({ error: errorMessage(error) }, 400);
  }
});