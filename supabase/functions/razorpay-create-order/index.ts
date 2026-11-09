import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { authenticatedUser, env, errorMessage, json, razorpayRequest, serviceClient } from '../_shared/razorpay.ts';

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info' } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  let attemptId: string | null = null;
  try {
    await authenticatedUser(request);
    const body = await request.json();
    if (!Array.isArray(body.items) || typeof body.delivery_address_id !== 'string' || typeof body.idempotency_key !== 'string') {
      return json({ error: 'Invalid checkout request' }, 400);
    }
    const supabase = serviceClient();
    const bearer = request.headers.get('Authorization')!;
    const userClient = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
      global: { headers: { Authorization: bearer } }, auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: reserved, error: reserveError } = await userClient.rpc('reserve_razorpay_checkout', {
      p_items: body.items,
      p_delivery_address_id: body.delivery_address_id,
      p_idempotency_key: body.idempotency_key,
    });
    if (reserveError) throw new Error(reserveError.message);
    attemptId = String(reserved.attempt_id);
    if (reserved.razorpay_order_id) {
      return json({ success: true, attempt_id: attemptId, razorpay_order_id: reserved.razorpay_order_id,
        amount_paise: Number(reserved.amount_paise), currency: 'INR', key_id: env('RAZORPAY_KEY_ID') });
    }
    const order = await razorpayRequest('/orders', {
      method: 'POST',
      body: JSON.stringify({ amount: Number(reserved.amount_paise), currency: 'INR',
        receipt: `pc_${attemptId.replaceAll('-', '')}`, notes: { checkout_attempt_id: attemptId } }),
    });
    if (order.amount !== Number(reserved.amount_paise) || order.currency !== 'INR') throw new Error('Razorpay order amount mismatch');
    const { error: attachError } = await supabase.rpc('attach_razorpay_order', {
      p_attempt_id: attemptId, p_razorpay_order_id: order.id,
    });
    if (attachError) throw new Error('Could not save payment order. Retry payment verification or contact support.');
    return json({ success: true, attempt_id: attemptId, razorpay_order_id: order.id,
      amount_paise: Number(order.amount), currency: 'INR', key_id: env('RAZORPAY_KEY_ID') });
  } catch (error) {
    // Do not release on network ambiguity: Razorpay may have accepted the request.
    return json({ error: errorMessage(error) }, 400);
  }
});
