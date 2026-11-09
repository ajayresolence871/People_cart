import { constantTimeEqual, env, hmacHex, json, razorpayRequest, refundPayment, serviceClient } from '../_shared/razorpay.ts';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const raw = await request.text();
  const supplied = (request.headers.get('x-razorpay-signature') ?? '').toLowerCase();
  const expected = await hmacHex(env('RAZORPAY_WEBHOOK_SECRET'), raw);
  if (!constantTimeEqual(expected, supplied)) return json({ error: 'Invalid webhook signature' }, 401);
  try {
    const event = JSON.parse(raw);
    if (event.event !== 'payment.captured') return json({ received: true });
    const payment = event.payload?.payment?.entity;
    if (!payment?.id || !payment?.order_id || payment.status !== 'captured') return json({ error: 'Invalid payment event' }, 400);
    const admin = serviceClient();
    const { data: attempt, error } = await admin.from('razorpay_checkout_attempts')
      .select('id,razorpay_order_id,razorpay_payment_id,amount_paise,status')
      .eq('razorpay_order_id', payment.order_id).maybeSingle();
    if (error || !attempt) return json({ error: 'Checkout attempt not found' }, 404);
    if (Number(payment.amount) !== Number(attempt.amount_paise) || payment.currency !== 'INR') {
      return json({ error: 'Captured payment does not match checkout amount' }, 400);
    }
    if (attempt.status === 'released') {
      const currentPayment = await razorpayRequest(`/payments/${encodeURIComponent(payment.id)}`);
      if (currentPayment.status !== 'refunded') await refundPayment(payment.id, Number(attempt.amount_paise));
      return json({ received: true, refunded: true });
    }
    if (attempt.status === 'completed' && attempt.razorpay_payment_id !== payment.id) {
      const currentPayment = await razorpayRequest(`/payments/${encodeURIComponent(payment.id)}`);
      if (currentPayment.status !== 'refunded') await refundPayment(payment.id, Number(attempt.amount_paise));
      return json({ received: true, refunded: true });
    }
    const { data: result, error: finalizeError } = await admin.rpc('finalize_razorpay_checkout', {
      p_attempt_id: attempt.id, p_razorpay_order_id: payment.order_id, p_razorpay_payment_id: payment.id,
    });
    if (finalizeError) return json({ error: 'Order finalization will be retried' }, 500);
    return json(result);
  } catch (_) {
    return json({ error: 'Could not process payment webhook' }, 400);
  }
});
