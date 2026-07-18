import 'dart:async';
import 'dart:isolate';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import 'payment_backend.dart';
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
      _log('Dropped notification because signature was empty');
      return;
    }

    final now = notification.receivedAt;
    _recentSignatures.removeWhere(
      (key, seenAt) => now.difference(seenAt).abs() > _dedupeWindow,
    );

    final lastSeen = _recentSignatures[signature];
    if (lastSeen != null && now.difference(lastSeen).abs() <= _dedupeWindow) {
      _log(
        'Deduped notification: sourceId=${notification.sourceId} app=${notification.appName} '
        'amount=${notification.amount?.toStringAsFixed(2) ?? 'null'}',
      );
      return;
    }

    _recentSignatures[signature] = now;
    _log(
      'Accepted notification for UI: sourceId=${notification.sourceId} '
      'app=${notification.appName} amount=${notification.amount?.toStringAsFixed(2) ?? 'null'}',
    );
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

  static void _log(String message) {
    developer.log(message, name: 'PaymentTracker');
  }
}

@pragma('vm:entry-point')
void paymentSyncBackgroundNotificationCallback(NotificationEvent event) {
  developer.log(
    'Raw notification: package=${event.packageName} title=${event.title} '
    'text=${event.text} id=${event.id} uniqueId=${event.uniqueId} timestamp=${event.timestamp}',
    name: 'PaymentTracker',
  );

  final parsed = PaymentNotificationParser.tryParse(
    event,
    logger: (message) => developer.log(message, name: 'PaymentTracker'),
  );
  if (parsed == null) {
    return;
  }

  developer.log(
    'Saving payment: sourceId=${parsed.sourceId} app=${parsed.appName} '
    'amount=${parsed.amount?.toStringAsFixed(2) ?? 'null'}',
    name: 'PaymentTracker',
  );

  unawaited(
    PaymentBackendClient.instance.savePayment(parsed, background: true),
  );

  final sendPort =
      IsolateNameServer.lookupPortByName(PaymentSync._uiPortName);
  if (sendPort == null) {
    developer.log(
      'UI bridge not available for sourceId=${parsed.sourceId}',
      name: 'PaymentTracker',
    );
    return;
  }

  sendPort.send(parsed.toMap());
  developer.log(
    'Forwarded payment to UI: sourceId=${parsed.sourceId}',
    name: 'PaymentTracker',
  );
}
