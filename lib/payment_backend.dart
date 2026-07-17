import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_notification.dart';

class PaymentBackendClient {
  PaymentBackendClient._();

  static final PaymentBackendClient instance = PaymentBackendClient._();

  Future<void> savePayment(PaymentNotification payment) async {
    try {
      await Supabase.instance.client
          .from('payment_events')
          .insert(payment.toBackendPayload());
      debugPrint('Payment backend sync succeeded: ${payment.sourceId}');
    } catch (error) {
      // Keep notification capture resilient even if database writes fail.
      debugPrint('Payment backend sync failed: $error');
    }
  }
}
