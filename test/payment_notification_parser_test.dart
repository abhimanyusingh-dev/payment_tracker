import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:payment_tracker/payment_notification.dart';

NotificationEvent _event({
  required String packageName,
  required String title,
  required String text,
  String uniqueId = 'id-1',
}) {
  return NotificationEvent(
    uniqueId: uniqueId,
    packageName: packageName,
    title: title,
    text: text,
    createAt: DateTime.parse('2026-07-17T10:30:00Z'),
  );
}

void main() {
  test('parses PhonePe payment notification', () {
    final parsed = PaymentNotificationParser.tryParse(
      _event(
        packageName: 'com.phonepe.app',
        title: 'Payment received',
        text: '₹250 received from Raju via UPI\nUPI Ref No: 12345\nraju@upi',
      ),
    );

    expect(parsed, isNotNull);
    expect(parsed!.appName, 'PhonePe');
    expect(parsed.amount, 250);
    expect(parsed.direction, PaymentDirection.incoming);
    expect(parsed.status, PaymentStatus.success);
    expect(parsed.counterparty, contains('Raju'));
    expect(parsed.upiId, 'raju@upi');
    expect(parsed.transactionId, '12345');
    expect(parsed.transactionKey, isNotEmpty);
  });

  test('parses PhonePe sent to you notification as incoming', () {
    final parsed = PaymentNotificationParser.tryParse(
      _event(
        packageName: 'com.phonepe.app',
        title: '******1986: ******1986',
        text: 'sent ₹472 to you.',
      ),
    );

    expect(parsed, isNotNull);
    expect(parsed!.appName, 'PhonePe');
    expect(parsed.amount, 472);
    expect(parsed.direction, PaymentDirection.incoming);
    expect(parsed.status, PaymentStatus.success);
    expect(parsed.transactionKey, isNotEmpty);
  });

  test('parses Paytm Business incoming payment notification', () {
    final parsed = PaymentNotificationParser.tryParse(
      _event(
        packageName: 'com.paytm.business',
        title: 'Payment successful',
        text:
            '₹1,200 received from ABC Stores\nTxn ID: TXN12345\nNote: Tea order',
      ),
    );

    expect(parsed, isNotNull);
    expect(parsed!.appName, 'Paytm Business');
    expect(parsed.amount, 1200);
    expect(parsed.direction, PaymentDirection.incoming);
    expect(parsed.status, PaymentStatus.success);
    expect(parsed.counterparty, contains('ABC Stores'));
    expect(parsed.transactionId, 'TXN12345');
    expect(parsed.note, contains('Tea order'));
    expect(parsed.transactionKey, isNotEmpty);
  });

  test('parses Google Pay notification', () {
    final parsed = PaymentNotificationParser.tryParse(
      _event(
        packageName: 'com.google.android.apps.nbu.paisa.user',
        title: 'Money received',
        text: 'Rs. 80 received from Aman\nUPI Ref No: 998877',
      ),
    );

    expect(parsed, isNotNull);
    expect(parsed!.appName, 'Google Pay');
    expect(parsed.amount, 80);
    expect(parsed.direction, PaymentDirection.incoming);
    expect(parsed.status, PaymentStatus.success);
    expect(parsed.counterparty, contains('Aman'));
    expect(parsed.transactionId, '998877');
    expect(parsed.transactionKey, isNotEmpty);
  });

  test('ignores non-payment notifications from supported apps', () {
    final parsed = PaymentNotificationParser.tryParse(
      _event(
        packageName: 'net.one97.paytm',
        title: 'Promotional offer',
        text: 'Get cashback on your next recharge',
      ),
    );

    expect(parsed, isNull);
  });
}
