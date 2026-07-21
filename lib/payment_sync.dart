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

    final started = await _ensureRunning();
    if (!started) {
      return ListenerState.inactive;
    }

    return ListenerState.listening;
  }

  static Future<bool> ensureRunning() async {
    if (!_isAndroid) {
      return false;
    }

    final hasPermission = await NotificationsListener.hasPermission ?? false;
    if (!hasPermission) {
      return false;
    }

    await NotificationsListener.initialize(
      callbackHandle: paymentSyncBackgroundNotificationCallback,
    );

    return _ensureRunning();
  }

  static Future<bool> isRunning() async {
    if (!_isAndroid) {
      return false;
    }
    return await NotificationsListener.isRunning ?? false;
  }

  static Future<void> openPermissionSettings() async {
    if (!_isAndroid) {
      return;
    }
    await NotificationsListener.openPermissionSettings();
  }

  static Future<bool> _ensureRunning() async {
    final isRunning = await NotificationsListener.isRunning ?? false;
    if (isRunning) {
      _log('Notification listener service already running');
      return true;
    }

    _log('Notification listener service is not running, starting it now');
    final started = await NotificationsListener.startService(
      foreground: true,
      title: 'Payment tracker',
      description: 'Listening for payment notifications',
    );
    _log('Notification listener service start result: $started');
    return started == true;
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
      unawaited(
        PaymentBackendClient.instance.logDiagnostic(
          stage: 'dedupe',
          outcome: 'dropped',
          reason: 'Duplicate signature within $_dedupeWindow',
          payment: notification,
          background: true,
        ),
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
    final normalizedCounterparty =
        notification.counterparty?.trim().toLowerCase() ?? '';
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

  final packageName = event.packageName?.toString() ?? '';
  if (packageName.isNotEmpty) {
    unawaited(
      PaymentBackendClient.instance.logDiagnostic(
        stage: 'receive',
        outcome: 'observed',
        packageName: packageName,
        rawTitle: event.title?.toString(),
        rawBody: event.text?.toString(),
        rawText: event.raw?.toString(),
        reason: 'Raw notification observed by the listener service',
        background: true,
      ),
    );
  }

  String? parseReason;
  final parsed = PaymentNotificationParser.tryParse(
    event,
    logger: (message) {
      parseReason = message;
      developer.log(message, name: 'PaymentTracker');
    },
  );
  if (parsed == null) {
    unawaited(
      PaymentBackendClient.instance.logDiagnostic(
        stage: 'parse',
        outcome: 'rejected',
        reason: parseReason ?? 'parser returned null',
        packageName: event.packageName?.toString(),
        rawTitle: event.title?.toString(),
        rawBody: event.text?.toString(),
        rawText: event.raw?.toString(),
        background: true,
      ),
    );
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

  final sendPort = IsolateNameServer.lookupPortByName(PaymentSync._uiPortName);
  if (sendPort == null) {
    developer.log(
      'UI bridge not available for sourceId=${parsed.sourceId}',
      name: 'PaymentTracker',
    );
    unawaited(
      PaymentBackendClient.instance.logDiagnostic(
        stage: 'forward',
        outcome: 'ui_bridge_missing',
        payment: parsed,
        reason: 'No UI isolate port was registered',
        background: true,
      ),
    );
    return;
  }

  sendPort.send(parsed.toMap());
  developer.log(
    'Forwarded payment to UI: sourceId=${parsed.sourceId}',
    name: 'PaymentTracker',
  );
}
