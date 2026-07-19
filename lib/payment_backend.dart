import 'dart:async';
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
      unawaited(
        logDiagnostic(
          stage: 'save',
          outcome: 'inserted',
          payment: payment,
          background: background,
        ),
      );
    } catch (error) {
      // Keep notification capture resilient even if database writes fail.
      developer.log(
        'Payment backend sync failed: $error',
        name: 'PaymentTracker',
      );
      unawaited(
        logDiagnostic(
          stage: 'save',
          outcome: 'failed',
          reason: error.toString(),
          payment: payment,
          background: background,
        ),
      );
    }
  }

  Future<void> logDiagnostic({
    required String stage,
    required String outcome,
    String? reason,
    PaymentNotification? payment,
    String? packageName,
    String? appName,
    String? rawTitle,
    String? rawBody,
    String? rawText,
    bool background = false,
  }) async {
    try {
      final client = background ? _backgroundClient : Supabase.instance.client;
      await client.from('notification_diagnostics').insert(<String, dynamic>{
        'source_id': payment?.sourceId,
        'package_name': payment?.packageName ?? packageName,
        'app_name': payment?.appName ?? appName,
        'stage': stage,
        'outcome': outcome,
        'reason': reason,
        'amount': payment?.amount,
        'received': payment?.direction == PaymentDirection.incoming,
        'notification_timestamp': payment?.receivedAt.toUtc().toIso8601String(),
        'raw_title': payment?.rawTitle ?? rawTitle,
        'raw_body': payment?.rawBody ?? rawBody,
        'raw_text': payment?.rawText ?? rawText,
      });
    } catch (error) {
      developer.log(
        'Notification diagnostic sync failed: $error',
        name: 'PaymentTracker',
      );
    }
  }

  Future<void> logServiceHealth({
    required String outcome,
    String? reason,
    bool background = false,
  }) async {
    await logDiagnostic(
      stage: 'service',
      outcome: outcome,
      reason: reason,
      background: background,
    );
  }
}
