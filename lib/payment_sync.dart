import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import 'payment_notification.dart';

enum ListenerState { unsupported, permissionRequired, listening, inactive }

class PaymentSync {
  static const String _uiPortName = 'payment_tracker_payment_port';
  static const Duration _dedupeWindow = Duration(seconds: 5);
  static final StreamController<PaymentNotification> _controller =
      StreamController<PaymentNotification>.broadcast();
  static final Map<String, DateTime> _recentSignatures = <String, DateTime>{};
  static ReceivePort? _uiPort;
  static bool _uiBridgeReady = false;

  static Stream<PaymentNotification> get payments => _controller.stream;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void ensureUiBridge() {
    if (_uiBridgeReady) {
      return;
    }

    _uiPort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_uiPortName);
    IsolateNameServer.registerPortWithName(_uiPort!.sendPort, _uiPortName);
    _uiPort!.listen(_onMessage);
    _uiBridgeReady = true;
  }

  static Future<ListenerState> startListening() async {
    ensureUiBridge();

    if (!_isAndroid) {
      return ListenerState.unsupported;
    }

    final hasPermission = await NotificationsListener.hasPermission ?? false;
    if (!hasPermission) {
      return ListenerState.permissionRequired;
    }

    await NotificationsListener.initialize(
      callbackHandle: paymentSyncBackgroundNotificationCallback,
    );

    final isRunning = await NotificationsListener.isRunning ?? false;
    if (!isRunning) {
      final started = await NotificationsListener.startService(
        foreground: true,
        title: 'Payment tracker',
        description: 'Listening for payment notifications',
      );
      if (started != true) {
        return ListenerState.inactive;
      }
    }

    return ListenerState.listening;
  }

  static Future<void> openPermissionSettings() async {
    if (!_isAndroid) {
      return;
    }
    await NotificationsListener.openPermissionSettings();
  }

  static void _onMessage(dynamic message) {
    if (message is PaymentNotification) {
      _emit(message);
      return;
    }

    if (message is Map) {
      _emit(PaymentNotification.fromMap(message));
    }
  }

  static void _emit(PaymentNotification notification) {
    final signature = _signature(notification);
    if (signature.isEmpty) {
      return;
    }

    final now = notification.receivedAt;
    _recentSignatures.removeWhere(
      (key, seenAt) => now.difference(seenAt).abs() > _dedupeWindow,
    );

    final lastSeen = _recentSignatures[signature];
    if (lastSeen != null && now.difference(lastSeen).abs() <= _dedupeWindow) {
      return;
    }

    _recentSignatures[signature] = now;
    _controller.add(notification);
  }

  static String _signature(PaymentNotification notification) {
    final normalizedCounterparty = notification.counterparty?.trim().toLowerCase() ?? '';
    final normalizedUpiId = notification.upiId?.trim().toLowerCase() ?? '';
    final normalizedTransactionId =
        notification.transactionId?.trim().toLowerCase() ?? '';
    final normalizedReferenceId =
        notification.referenceId?.trim().toLowerCase() ?? '';
    final normalizedNote = notification.note?.trim().toLowerCase() ?? '';
    final normalizedMaskedAccount =
        notification.maskedAccount?.trim().toLowerCase() ?? '';
    final amount = notification.amount?.toStringAsFixed(2) ?? 'na';

    return [
      notification.packageName.trim().toLowerCase(),
      notification.appName.trim().toLowerCase(),
      notification.direction.name,
      notification.status.name,
      amount,
      normalizedCounterparty,
      normalizedUpiId,
      normalizedTransactionId,
      normalizedReferenceId,
      normalizedNote,
      normalizedMaskedAccount,
    ].join('|');
  }
}

@pragma('vm:entry-point')
void paymentSyncBackgroundNotificationCallback(NotificationEvent event) {
  final parsed = PaymentNotificationParser.tryParse(event);
  if (parsed == null) {
    return;
  }

  final sendPort =
      IsolateNameServer.lookupPortByName(PaymentSync._uiPortName);
  sendPort?.send(parsed.toMap());
}
