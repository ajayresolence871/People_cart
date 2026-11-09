import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/models/cart_item.dart';
import 'package:people_cart/models/product.dart';
import 'package:people_cart/services/razorpay_order_service.dart';

void main() {
  group('RazorpayOrderService', () {
    test('sends aggregated product quantities, never client prices', () async {
      String? calledFunction;
      Map<String, dynamic>? sentBody;
      final service = RazorpayOrderService(
        caller: (name, body) async {
          calledFunction = name;
          sentBody = body;
          return {
            'success': true,
            'attempt_id': 'attempt-1',
            'razorpay_order_id': 'order_test_1',
            'key_id': 'rzp_test_public',
            'amount_paise': 12000,
            'currency': 'INR',
          };
        },
      );
      final product = Product(id: '9', name: 'Milk', price: 35);
      final result = await service.createOrder(
        items: [
          CartItem(product: product, quantity: 1),
          CartItem(product: product, quantity: 2),
        ],
        addressId: 'address-1',
        idempotencyKey: 'idempotency-1',
      );

      expect(calledFunction, 'razorpay-create-order');
      expect(sentBody!['items'], [
        {'product_id': 9, 'quantity': 3},
      ]);
      expect(sentBody!.containsKey('total'), isFalse);
      expect(sentBody!.containsKey('price'), isFalse);
      expect(result.amountPaise, 12000);
      expect(result.razorpayOrderId, 'order_test_1');
    });

    test('rejects malformed cart before making a server request', () async {
      var invoked = false;
      final service = RazorpayOrderService(
        caller: (_, _) async {
          invoked = true;
          return <String, dynamic>{};
        },
      );
      await expectLater(
        service.createOrder(
          items: [
            CartItem(
              product: Product(id: 'deal_1', name: 'Deal', price: 20),
            ),
          ],
          addressId: 'address-1',
          idempotencyKey: 'idempotency-1',
        ),
        throwsArgumentError,
      );
      expect(invoked, isFalse);
    });

    test('rejects a server amount below Razorpay minimum', () async {
      final service = RazorpayOrderService(
        caller: (_, _) async => {
          'success': true,
          'attempt_id': 'attempt-1',
          'razorpay_order_id': 'order_test_1',
          'key_id': 'rzp_test_public',
          'amount_paise': 99,
        },
      );
      await expectLater(
        service.createOrder(
          items: [
            CartItem(
              product: Product(id: '1', name: 'Item', price: 1),
            ),
          ],
          addressId: 'address-1',
          idempotencyKey: 'idempotency-1',
        ),
        throwsException,
      );
    });

    test('sends callback fields only to server verification and requires order result', () async {
      Map<String, dynamic>? sentBody;
      final service = RazorpayOrderService(
        caller: (_, body) async {
          sentBody = body;
          return {'success': true, 'order_id': 55, 'total_amount': 120};
        },
      );
      final result = await service.verifyPayment(
        attemptId: 'attempt-1',
        razorpayOrderId: 'order_test_1',
        razorpayPaymentId: 'pay_test_1',
        signature: 'signature',
      );
      expect(sentBody, {
        'attempt_id': 'attempt-1',
        'razorpay_order_id': 'order_test_1',
        'razorpay_payment_id': 'pay_test_1',
        'razorpay_signature': 'signature',
      });
      expect(result['order_id'], 55);
    });
  });
}
