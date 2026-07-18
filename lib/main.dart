import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_notification.dart';
import 'payment_sync.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );
  runApp(const PaymentTrackerApp());
}

class PaymentTrackerApp extends StatelessWidget {
  const PaymentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payment Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const PaymentFeedScreen(),
    );
  }
}

class PaymentFeedScreen extends StatefulWidget {
  const PaymentFeedScreen({super.key});

  @override
  State<PaymentFeedScreen> createState() => _PaymentFeedScreenState();
}

class _PaymentFeedScreenState extends State<PaymentFeedScreen> {
  final List<PaymentNotification> _payments = <PaymentNotification>[];
  StreamSubscription<PaymentNotification>? _subscription;
  ListenerState _listenerState = ListenerState.inactive;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    PaymentSync.ensureUiBridge();
    _subscription = PaymentSync.payments.listen((payment) {
      if (!mounted) {
        return;
      }
      setState(() {
        _payments.insert(0, payment);
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final state = await PaymentSync.startListening();
    if (!mounted) {
      return;
    }
    setState(() {
      _listenerState = state;
      _booting = false;
    });
  }

  Future<void> _openPermissionSettings() async {
    await PaymentSync.openPermissionSettings();
  }

  String _statusText() {
    switch (_listenerState) {
      case ListenerState.listening:
        return 'Listening for payment notifications';
      case ListenerState.permissionRequired:
        return 'Notification access is required';
      case ListenerState.unsupported:
        return 'Android only feature';
      case ListenerState.inactive:
        return 'Listener is not running';
    }
  }

  Color _statusColor(BuildContext context) {
    switch (_listenerState) {
      case ListenerState.listening:
        return const Color(0xFF0F766E);
      case ListenerState.permissionRequired:
        return const Color(0xFFB45309);
      case ListenerState.unsupported:
        return Theme.of(context).colorScheme.outline;
      case ListenerState.inactive:
        return const Color(0xFF334155);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _payments.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF071A2B),
              Color(0xFF0F3D46),
              Color(0xFFF5F7FA),
            ],
            stops: <double>[0.0, 0.34, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Payment Tracker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Extracts payment details from PhonePe, Paytm, and Google Pay notifications.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _StatusCard(
                        label: _statusText(),
                        count: total,
                        accentColor: _statusColor(context),
                        booting: _booting,
                        onActionPressed:
                            _listenerState == ListenerState.permissionRequired
                            ? _openPermissionSettings
                            : _bootstrap,
                        actionLabel:
                            _listenerState == ListenerState.permissionRequired
                            ? 'Open access'
                            : 'Refresh',
                      ),
                    ],
                  ),
                ),
              ),
              if (_payments.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptyState(
                      listenerState: _listenerState,
                      onGrantAccess: _openPermissionSettings,
                      onRetry: _bootstrap,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: _payments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      return _PaymentCard(payment: payment);
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.count,
    required this.accentColor,
    required this.booting,
    required this.onActionPressed,
    required this.actionLabel,
  });

  final String label;
  final int count;
  final Color accentColor;
  final bool booting;
  final VoidCallback onActionPressed;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              booting ? Icons.hourglass_top_rounded : Icons.notifications,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count payment notification${count == 1 ? '' : 's'} captured',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: onActionPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.listenerState,
    required this.onGrantAccess,
    required this.onRetry,
  });

  final ListenerState listenerState;
  final VoidCallback onGrantAccess;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = switch (listenerState) {
      ListenerState.permissionRequired => 'Allow notification access',
      ListenerState.unsupported => 'Run on Android',
      ListenerState.inactive => 'Waiting for payment notifications',
      ListenerState.listening => 'No payment notifications yet',
    };

    final message = switch (listenerState) {
      ListenerState.permissionRequired =>
        'Grant notification listener access so the app can read payment alerts from PhonePe, Paytm, and Google Pay.',
      ListenerState.unsupported =>
        'The notification listener works only on Android devices.',
      ListenerState.inactive =>
        'Once a payment alert arrives, we will parse the amount, sender, receiver, UPI ID, and transaction reference here.',
      ListenerState.listening =>
        'We are connected. When a payment notification arrives, the parsed details will appear here.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              if (listenerState == ListenerState.permissionRequired)
                OutlinedButton(
                  onPressed: onGrantAccess,
                  child: const Text('Open settings'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentNotification payment;

  Color _chipColor(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.success => const Color(0xFF0F766E),
      PaymentStatus.failed => const Color(0xFFB91C1C),
      PaymentStatus.pending => const Color(0xFFB45309),
      PaymentStatus.reversed => const Color(0xFF7C3AED),
      PaymentStatus.unknown => const Color(0xFF334155),
    };
  }

  IconData _directionIcon(PaymentDirection direction) {
    return switch (direction) {
      PaymentDirection.incoming => Icons.call_received_rounded,
      PaymentDirection.outgoing => Icons.call_made_rounded,
      PaymentDirection.unknown => Icons.payments_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _chipColor(payment.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_directionIcon(payment.direction), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      payment.appName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.formattedAmount,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              _Chip(label: payment.statusLabel, color: accent),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip(
                label: payment.directionLabel,
                color: const Color(0xFF0F766E),
              ),
              if ((payment.counterparty ?? '').isNotEmpty)
                _Chip(
                  label: payment.counterparty!,
                  color: const Color(0xFF334155),
                ),
              if ((payment.upiId ?? '').isNotEmpty)
                _Chip(label: payment.upiId!, color: const Color(0xFF0F172A)),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Received', value: _formatDate(payment.receivedAt)),
          if ((payment.transactionId ?? '').isNotEmpty)
            _InfoRow(label: 'Transaction', value: payment.transactionId!),
          if ((payment.referenceId ?? '').isNotEmpty)
            _InfoRow(label: 'Reference', value: payment.referenceId!),
          if ((payment.maskedAccount ?? '').isNotEmpty)
            _InfoRow(label: 'Account', value: payment.maskedAccount!),
          if ((payment.note ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              payment.note!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF475569),
              ),
            ),
          ],
          if (payment.rawTitle.isNotEmpty ||
              payment.rawBody.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (payment.rawTitle.isNotEmpty) ...<Widget>[
                    const Text(
                      'Notification title',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.rawTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (payment.rawBody.isNotEmpty) ...<Widget>[
                    const Text(
                      'Notification body',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.rawBody,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute $period';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
