import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/services/api_config.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class PaymentRequiredCard extends StatefulWidget {
  const PaymentRequiredCard({super.key});

  @override
  State<PaymentRequiredCard> createState() => _PaymentRequiredCardState();
}

class _PaymentRequiredCardState extends State<PaymentRequiredCard> {
  static const int _productionPremiumAmount = 2999;
  static const int _testPremiumAmount = 100;
  static const bool _useTestPaymentAmount = bool.fromEnvironment(
    'USE_TEST_PAYMENT_AMOUNT',
    defaultValue: true,
  );
  static const int _premiumAmount = _useTestPaymentAmount
      ? _testPremiumAmount
      : _productionPremiumAmount;

  final BackendApi _api = BackendApi();
  io.Socket? _socket;
  bool _isStartingPayment = false;
  bool _isCheckingPayment = false;
  String? _timedAccountNumber;
  String? _reference;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectPaymentSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectPaymentSocket();
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _connectPaymentSocket() async {
    final auth = context.read<AuthProvider>();
    await auth.ensureBackendSession();
    final userId = auth.backendUserId;
    if (userId == null || userId.isEmpty || _socket != null) return;

    final baseUrl = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'userId': userId})
          .setQuery({'userId': userId})
          .build(),
    );
    socket.on('webhook_received', (_) {
      unawaited(context.read<ProfileProvider>().syncFromBackendIfAvailable());
    });
    socket.connect();
    _socket = socket;
  }

  Future<void> _startPayment() async {
    setState(() {
      _isStartingPayment = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final ready = await auth.ensureBackendSession();
      final token = auth.backendToken;
      if (!ready || token == null || token.isEmpty) {
        throw ApiException('Could not start a backend session.');
      }

      final payment = await _api.initiatePayment(
        token: token,
        amount: _premiumAmount,
      );
      if (!mounted) return;
      setState(() {
        _timedAccountNumber = payment.timedAccountNumber;
        _reference = payment.reference;
      });
      unawaited(_checkPayment());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not start payment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingPayment = false;
        });
      }
    }
  }

  Future<void> _checkPayment() async {
    if (_isCheckingPayment) return;
    setState(() {
      _isCheckingPayment = true;
      _error = null;
    });

    try {
      await context.read<ProfileProvider>().syncFromBackendIfAvailable();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Payment is not confirmed yet.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Material(
          color: Colors.black.withValues(alpha: isDark ? 0.56 : 0.34),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 430),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(
                          alpha: isDark ? 0.78 : 0.82,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: colorScheme.primary,
                            size: 42,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Free trial is over',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your 24-hour trial has ended. Upgrade to keep discovering, swiping, and chatting.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.72,
                              ),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _PricePanel(
                            amount: _premiumAmount,
                            timedAccountNumber: _timedAccountNumber,
                            reference: _reference,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _isStartingPayment
                                ? null
                                : _startPayment,
                            icon: _isStartingPayment
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(
                              _timedAccountNumber == null
                                  ? 'Unlock premium'
                                  : 'Generate a new TAN',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isCheckingPayment
                                ? null
                                : _checkPayment,
                            child: Text(
                              _isCheckingPayment
                                  ? 'Checking payment...'
                                  : 'I have paid',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.amount,
    required this.timedAccountNumber,
    required this.reference,
  });

  final int amount;
  final String? timedAccountNumber;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            'MWK $amount',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          if (timedAccountNumber != null &&
              timedAccountNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Timed account number',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              timedAccountNumber!,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
          if (reference != null && reference!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reference $reference',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
