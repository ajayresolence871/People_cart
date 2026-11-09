import { authenticatedUser, constantTimeEqual, env, errorMessage, hmacHex, json, razorpayRequest, refundPayment, serviceClient } from '../_shared/razorpay.ts';

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info' } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await authenticatedUser(request);
    const body = await request.json();
    const attemptId = String(body.attempt_id ?? '');
    const paymentId = String(body.razorpay_payment_id ?? '');
    const suppliedOrderId = String(body.razorpay_order_id ?? '');
    const signature = String(body.razorpay_signature ?? '').toLowerCase();
    if (!attemptId || !paymentId || !suppliedOrderId || !/^[a-f0-9]{64}$/.test(signature)) {
      return json({ error: 'Incomplete payment verification data' }, 400);
    }
    const admin = serviceClient();
    const { data: attempt, error: lookupError } = await admin
      .from('razorpay_checkout_attempts')
      .select('id,user_id,razorpay_order_id,razorpay_payment_id,amount_paise,total_amount,status,order_id')
      .eq('id', attemptId).maybeSingle();
    if (lookupError || !attempt || attempt.user_id !== user.id) return json({ error: 'Payment attempt not found' }, 404);
    if (attempt.razorpay_order_id !== suppliedOrderId) {
      return json({ error: 'Payment order does not match this checkout' }, 400);
    }
    const expected = await hmacHex(env('RAZORPAY_KEY_SECRET'), `${attempt.razorpay_order_id}|${paymentId}`);
    if (!constantTimeEqual(expected, signature)) return json({ error: 'Invalid payment signature' }, 400);

    let payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`);
    if (payment.order_id !== attempt.razorpay_order_id || Number(payment.amount) !== Number(attempt.amount_paise) || payment.currency !== 'INR') {
      return json({ error: 'Payment details do not match the checkout' }, 400);
    }
    if (attempt.status === 'completed') {
      if (attempt.razorpay_payment_id !== paymentId) {
        if (payment.status === 'captured') await refundPayment(paymentId, Number(attempt.amount_paise));
        return json({ error: 'This checkout was already paid; the additional captured payment is being refunded.' }, 409);
      }
      if (payment.status !== 'captured') return json({ error: 'The completed payment is not currently captured.' }, 409);
      return json({ success: true, order_id: attempt.order_id, total_amount: attempt.total_amount });
    }
    if (attempt.status === 'released') {
      if (payment.status === 'captured') await refundPayment(paymentId, Number(attempt.amount_paise));
      return json({ error: 'This checkout expired; any late captured payment is being refunded. Please retry.' }, 409);
    }
    if (attempt.status !== 'reserved') return json({ error: 'Payment attempt is not active' }, 409);
    if (payment.status === 'authorized') {
      payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}/capture`, {
        method: 'POST', body: JSON.stringify({ amount: Number(attempt.amount_paise), currency: 'INR' }),
      });
    }
    if (payment.status !== 'captured') return json({ error: 'Payment is not captured yet; retry verification shortly' }, 409);
    const { data: result, error: finalizeError } = await admin.rpc('finalize_razorpay_checkout', {
      p_attempt_id: attemptId, p_razorpay_order_id: suppliedOrderId, p_razorpay_payment_id: paymentId,
    });
    if (finalizeError) throw new Error('Payment was captured but order confirmation is pending. Retry verification.');
    return json(result);
  } catch (error) {
    return json({ error: errorMessage(error) }, 400);
  }
});
