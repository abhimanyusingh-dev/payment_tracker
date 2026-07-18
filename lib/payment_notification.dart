import 'package:flutter_notification_listener/flutter_notification_listener.dart';

typedef PaymentParseLogger = void Function(String message);

enum PaymentDirection { incoming, outgoing, unknown }

enum PaymentStatus { success, failed, pending, reversed, unknown }

class PaymentNotification {
  final String sourceId;
  final String packageName;
  final String appName;
  final DateTime receivedAt;
  final String rawTitle;
  final String rawBody;
  final String rawText;
  final PaymentDirection direction;
  final PaymentStatus status;
  final double? amount;
  final String? currency;
  final String? counterparty;
  final String? upiId;
  final String? transactionId;
  final String? referenceId;
  final String? note;
  final String? maskedAccount;

  const PaymentNotification({
    required this.sourceId,
    required this.packageName,
    required this.appName,
    required this.receivedAt,
    required this.rawTitle,
    required this.rawBody,
    required this.rawText,
    required this.direction,
    required this.status,
    this.amount,
    this.currency,
    this.counterparty,
    this.upiId,
    this.transactionId,
    this.referenceId,
    this.note,
    this.maskedAccount,
  });

  factory PaymentNotification.fromMap(Map<dynamic, dynamic> map) {
    return PaymentNotification(
      sourceId: map['sourceId']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
      receivedAt:
          DateTime.tryParse(map['receivedAt']?.toString() ?? '') ??
          DateTime.now(),
      rawTitle: map['rawTitle']?.toString() ?? '',
      rawBody: map['rawBody']?.toString() ?? '',
      rawText: map['rawText']?.toString() ?? '',
      direction: PaymentDirection.values.firstWhere(
        (value) => value.name == map['direction'],
        orElse: () => PaymentDirection.unknown,
      ),
      status: PaymentStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => PaymentStatus.unknown,
      ),
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency']?.toString(),
      counterparty: map['counterparty']?.toString(),
      upiId: map['upiId']?.toString(),
      transactionId: map['transactionId']?.toString(),
      referenceId: map['referenceId']?.toString(),
      note: map['note']?.toString(),
      maskedAccount: map['maskedAccount']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'packageName': packageName,
      'appName': appName,
      'receivedAt': receivedAt.toIso8601String(),
      'rawTitle': rawTitle,
      'rawBody': rawBody,
      'rawText': rawText,
      'direction': direction.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      'counterparty': counterparty,
      'upiId': upiId,
      'transactionId': transactionId,
      'referenceId': referenceId,
      'note': note,
      'maskedAccount': maskedAccount,
    };
  }

  Map<String, dynamic> toBackendPayload() {
    return <String, dynamic>{
      'source_id': sourceId,
      'package_name': packageName,
      'app_name': appName,
      'amount': amount,
      'received': direction == PaymentDirection.incoming,
      'payee_name': counterparty,
      'timestamp': receivedAt.toUtc().toIso8601String(),
      'status': status.name,
      'transaction_id': transactionId,
      'reference_id': referenceId,
      'upi_id': upiId,
      'currency': currency,
      'raw_title': rawTitle,
      'raw_body': rawBody,
      'raw_text': rawText,
      'note': note,
      'masked_account': maskedAccount,
    };
  }

  String get formattedAmount {
    final value = amount;
    if (value == null) {
      return 'Amount unavailable';
    }

    final decimals = value % 1 == 0 ? 0 : 2;
    final number = _withCommas(value.toStringAsFixed(decimals));
    final prefix = currency == null || currency!.isEmpty ? '₹' : '$currency ';
    return '$prefix$number';
  }

  String get statusLabel {
    switch (status) {
      case PaymentStatus.success:
        return 'Success';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.reversed:
        return 'Reversed';
      case PaymentStatus.unknown:
        return 'Unknown';
    }
  }

  String get directionLabel {
    switch (direction) {
      case PaymentDirection.incoming:
        return 'Incoming';
      case PaymentDirection.outgoing:
        return 'Outgoing';
      case PaymentDirection.unknown:
        return 'Unknown';
    }
  }

  static String _withCommas(String value) {
    final parts = value.split('.');
    final buffer = StringBuffer();
    final digits = parts.first;
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      buffer.write(digits[i]);
      count++;
      if (i > 0 && count % 3 == 0) {
        buffer.write(',');
      }
    }
    final formattedInt = buffer.toString().split('').reversed.join();
    if (parts.length == 1) {
      return formattedInt;
    }
    return '$formattedInt.${parts[1]}';
  }
}

class PaymentNotificationParser {
  static const Map<String, String> _packageLabels = {
    'com.phonepe.app': 'PhonePe',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.google.android.apps.nbu.paisa.merchant': 'Google Pay Business',
    'com.paytm.business': 'Paytm Business',
    'net.one97.paytm': 'Paytm',
  };

  static final RegExp _amountPrefix = RegExp(
    r'(?:₹|rs\.?|inr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _amountSuffix = RegExp(
    r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:₹|rs\.?|inr)',
    caseSensitive: false,
  );
  static final RegExp _upiId = RegExp(
    r'\b[a-z0-9._-]+@[a-z0-9._-]+\b',
    caseSensitive: false,
  );
  static final RegExp _transactionId = RegExp(
    r'\b(?:utr|rrn|upi ref(?:erence)?(?: no)?|txn(?: id| ref(?:erence)?(?: no)?| no)?|transaction id|reference no|ref no|order id|approval code)\s*[:#\-]?\s*([a-z0-9/-]+)\b',
    caseSensitive: false,
  );
  static final RegExp _maskedAccount = RegExp(
    r'\b(?:a\/c|account|acct)(?:\s+ending)?(?:\s+(?:no\.?|number))?\s*[:\-]?\s*([x*0-9]{3,})\b',
    caseSensitive: false,
  );
  static final RegExp _note = RegExp(
    r'\b(?:note|remarks?|message|towards|for)\s*[:\-]\s*([^\n|]{2,120})',
    caseSensitive: false,
  );

  static const List<String> _paymentKeywords = [
    'payment',
    'paid',
    'received',
    'credited',
    'debited',
    'sent',
    'transfer',
    'transferred',
    'withdrawn',
    'refund',
    'reversed',
    'failed',
    'success',
    'pending',
    'upi',
    'imps',
    'neft',
    'rtgs',
  ];

  static PaymentNotification? tryParse(
    NotificationEvent event, {
    PaymentParseLogger? logger,
  }) {
    final packageName = event.packageName?.trim() ?? '';
    if (!_packageLabels.containsKey(packageName)) {
      logger?.call('Rejected notification from unsupported package: $packageName');
      return null;
    }

    final candidate = _buildCandidateText(event);
    if (candidate.isEmpty) {
      logger?.call('Rejected notification from $packageName because candidate text was empty');
      return null;
    }

    final hasPaymentSignal = _containsPaymentSignal(candidate);
    if (!hasPaymentSignal) {
      logger?.call(
        'Rejected notification from $packageName because no payment signal was found',
      );
      return null;
    }

    final amount = _extractAmount(candidate);
    final direction = _extractDirection(candidate);
    if (direction != PaymentDirection.incoming) {
      logger?.call(
        'Rejected notification from $packageName because it is not an incoming payment (direction=${direction.name})',
      );
      return null;
    }
    final status = _extractStatus(candidate);
    final upiId = _firstMatch(candidate, [_upiId]);
    final transactionId = _firstGroup(candidate, [_transactionId]);
    final maskedAccount = _firstGroup(candidate, [_maskedAccount]);
    final note = _firstGroup(candidate, [_note]);
    final counterparty = _extractCounterparty(candidate, direction);

    final rawTitle = event.title?.trim() ?? '';
    final rawBody = event.text?.trim() ?? '';

    logger?.call(
      'Parsed payment notification: package=$packageName amount=${amount?.toStringAsFixed(2) ?? 'null'} '
      'direction=${direction.name} status=${status.name} counterparty=${counterparty ?? 'null'} '
      'sourceId=${event.uniqueId?.trim() ?? 'generated'}',
    );

    return PaymentNotification(
      sourceId:
          event.uniqueId?.trim() ??
          '${packageName}_${event.timestamp ?? event.createAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
      packageName: packageName,
      appName: _packageLabels[packageName] ?? packageName,
      receivedAt: event.createAt ?? DateTime.now(),
      rawTitle: rawTitle,
      rawBody: rawBody,
      rawText: candidate,
      direction: direction,
      status: status,
      amount: amount,
      currency: _extractCurrency(candidate),
      counterparty: counterparty,
      upiId: upiId,
      transactionId: transactionId,
      referenceId: transactionId,
      note: note,
      maskedAccount: maskedAccount,
    );
  }

  static String _buildCandidateText(NotificationEvent event) {
    final raw = event.raw ?? const <dynamic, dynamic>{};
    final parts = <String?>[
      event.title?.toString(),
      event.text?.toString(),
      event.message?.toString(),
      raw['bigText']?.toString(),
      raw['subText']?.toString(),
      raw['summaryText']?.toString(),
      raw['text']?.toString(),
      raw['tickerText']?.toString(),
    ];

    final buffer = StringBuffer();
    for (final part in parts) {
      final normalized = _normalize(part);
      if (normalized.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write(' | ');
      }
      buffer.write(normalized);
    }
    return buffer.toString();
  }

  static bool _containsPaymentSignal(String text) {
    final lower = text.toLowerCase();
    return _paymentKeywords.any(lower.contains) ||
        _amountPrefix.hasMatch(text) ||
        _amountSuffix.hasMatch(text) ||
        _upiId.hasMatch(text) ||
        _transactionId.hasMatch(text);
  }

  static double? _extractAmount(String text) {
    final match =
        _amountPrefix.firstMatch(text) ?? _amountSuffix.firstMatch(text);
    if (match == null) {
      return null;
    }
    final numeric = match.group(1)?.replaceAll(',', '');
    if (numeric == null || numeric.isEmpty) {
      return null;
    }
    return double.tryParse(numeric);
  }

  static String? _extractCurrency(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('rs') || lower.contains('inr')) {
      return 'INR';
    }
    if (text.contains('₹')) {
      return '₹';
    }
    return null;
  }

  static PaymentDirection _extractDirection(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, ['received', 'credited', 'refund', 'added'])) {
      return PaymentDirection.incoming;
    }
    if (_containsAny(lower, [
      'paid',
      'sent',
      'debited',
      'deducted',
      'spent',
      'withdrawn',
      'transferred',
    ])) {
      return PaymentDirection.outgoing;
    }
    return PaymentDirection.unknown;
  }

  static PaymentStatus _extractStatus(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, [
      'failed',
      'declined',
      'rejected',
      'unsuccessful',
      'not completed',
    ])) {
      return PaymentStatus.failed;
    }
    if (_containsAny(lower, [
      'pending',
      'processing',
      'initiated',
      'in progress',
    ])) {
      return PaymentStatus.pending;
    }
    if (_containsAny(lower, ['reversed', 'reversal'])) {
      return PaymentStatus.reversed;
    }
    if (_containsAny(lower, [
      'success',
      'successful',
      'credited',
      'debited',
      'paid',
      'received',
    ])) {
      return PaymentStatus.success;
    }
    return PaymentStatus.unknown;
  }

  static String? _extractCounterparty(String text, PaymentDirection direction) {
    final patterns = <RegExp>[
      if (direction == PaymentDirection.incoming)
        RegExp(
          r'\b(?:received from|from)\s+([a-z0-9@._&\-\s]{2,80}?)(?=(?:\s+(?:via|using|on|at|for|to|in|upi|imps|neft|rtgs|credited|debited|sent|received|paid|transferred)\b)|[,.|;:]|$)',
          caseSensitive: false,
        ),
      if (direction == PaymentDirection.outgoing)
        RegExp(
          r'\b(?:paid to|sent to|to)\s+([a-z0-9@._&\-\s]{2,80}?)(?=(?:\s+(?:via|using|on|at|for|in|upi|imps|neft|rtgs|credited|debited|sent|received|paid|transferred)\b)|[,.|;:]|$)',
          caseSensitive: false,
        ),
      RegExp(
        r'\b([a-z0-9@._&\-\s]{2,80}?)\s+(?:has sent|has paid|has transferred)\s+(?:₹|rs\.?|inr)?\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:payment from|money received from)\s+([a-z0-9@._&\-\s]{2,80}?)(?=(?:\s+(?:via|using|on|at|for|to|in|upi|imps|neft|rtgs)\b)|[,.|;:]|$)',
        caseSensitive: false,
      ),
    ];

    final candidate = _firstGroup(text, patterns);
    if (candidate == null) {
      return _firstMatch(text, [_upiId]);
    }

    final cleaned = _normalize(candidate)
        .replaceAll(
          RegExp(
            r'\b(?:upi|imps|neft|rtgs|payment|transfer|transaction)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:has sent|has paid|has transferred)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _firstGroup(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final group = match?.group(1)?.trim();
      if (group != null && group.isNotEmpty) {
        return group;
      }
    }
    return null;
  }

  static String? _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = match?.group(0)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }

  static String _normalize(String? value) {
    if (value == null) {
      return '';
    }
    return value
        .replaceAll('\u200b', '')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
