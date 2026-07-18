import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_notification.dart';
import 'supabase_config.dart';

class PaymentBackendClient {
  PaymentBackendClient._();

  static final PaymentBackendClient instance = PaymentBackendClient._();
  static final SupabaseClient _backgroundClient =
      SupabaseClient(supabaseUrl, supabaseAnonKey);

  Future<void> savePayment(
    PaymentNotification payment, {
    bool background = false,
  }) async {
    try {
      final client = background ? _backgroundClient : Supabase.instance.client;
      await client
          .from('payment_events')
          .insert(payment.toBackendPayload());
      developer.log(
        'Payment backend sync succeeded: ${payment.sourceId}',
        name: 'PaymentTracker',
      );
    } catch (error) {
      // Keep notification capture resilient even if database writes fail.
      developer.log(
        'Payment backend sync failed: $error',
        name: 'PaymentTracker',
      );
    }
  }
}
