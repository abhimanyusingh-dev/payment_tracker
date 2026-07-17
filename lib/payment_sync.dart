import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import 'payment_notification.dart';

enum ListenerState {
  unsupported,
  permissionRequired,
  listening,
  inactive,
}

class PaymentSync {
  static const String _uiPortName = 'payment_tracker_payment_port';
  static final StreamController<PaymentNotification> _controller =
      StreamController<PaymentNotification>.broadcast();
  static final Set<String> _seenIds = <String>{};
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
      callbackHandle: _onBackgroundNotification,
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
    if (notification.sourceId.isEmpty) {
      return;
    }
    if (_seenIds.add(notification.sourceId)) {
      _controller.add(notification);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationEvent event) {
    final parsed = PaymentNotificationParser.tryParse(event);
    if (parsed == null) {
      return;
    }

    final sendPort = IsolateNameServer.lookupPortByName(_uiPortName);
    sendPort?.send(parsed.toMap());
  }
}
