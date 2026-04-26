import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/providers/app_lock_provider.dart';
import 'package:lerolove/providers/auth_provider.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _unlockBusy = false;
  bool _didInitialLockCheck = false;
  bool _obscurePasscode = true;
  String? _error;
  final TextEditingController _passcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthProvider>();
    final lock = context.read<AppLockProvider>();
    if (!auth.isAuthenticated || !lock.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      lock.lockNow();
    }
  }

  Future<void> _unlockWithPasscode() async {
    final input = _passcodeController.text.trim();
    final lock = context.read<AppLockProvider>();
    if (input.isEmpty || input.length < 4) {
      setState(() {
        _error = context.tr('enter_app_passcode');
      });
      return;
    }
    if (!lock.verifyPasscode(input)) {
      setState(() {
        _error = context.tr('passcode_incorrect');
      });
      return;
    }
    setState(() {
      _error = null;
      _passcodeController.clear();
    });
    lock.unlock();
  }

  Future<void> _unlockWithBiometric() async {
    if (_unlockBusy) return;
    final lock = context.read<AppLockProvider>();
    setState(() {
      _unlockBusy = true;
      _error = null;
    });
    final ok = await lock.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() {
      _unlockBusy = false;
      if (!ok) {
        _error = context.tr('biometric_failed');
      }
    });
    if (ok) {
      lock.unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AppLockProvider>(
      builder: (context, auth, lock, _) {
        if (!auth.isAuthenticated) {
          _didInitialLockCheck = false;
        } else if (lock.isReady && lock.enabled && !_didInitialLockCheck) {
          _didInitialLockCheck = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<AppLockProvider>().lockNow();
          });
        }

        final shouldShowLock = auth.isAuthenticated && lock.isLocked;
        if (!shouldShowLock) return widget.child;

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.surface,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 34,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                context.tr('app_locked_title'),
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('app_locked_subtitle'),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              if (lock.hasPasscode) ...[
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _passcodeController,
                                  builder: (context, value, _) {
                                    final digits = value.text.trim();
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(6, (index) {
                                        final hasValue = index < digits.length;
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: index == 5 ? 0 : 8,
                                            ),
                                            child: Container(
                                              height: 54,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: hasValue
                                                      ? colorScheme.primary
                                                      : colorScheme.outline,
                                                  width: hasValue ? 2 : 1.4,
                                                ),
                                              ),
                                              child: Text(
                                                hasValue
                                                    ? (_obscurePasscode
                                                          ? '•'
                                                          : digits[index])
                                                    : '',
                                                style: textTheme.titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: colorScheme
                                                          .onSurface,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passcodeController,
                                  obscureText: _obscurePasscode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 10,
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: context.tr('passcode'),
                                    hintText: context.tr('passcode_digits_hint'),
                                    counterText: '',
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    prefixIcon: const Icon(Icons.password_rounded),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePasscode = !_obscurePasscode;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePasscode
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: colorScheme.outline,
                                        width: 1.4,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) {
                                    if (_error != null) {
                                      setState(() => _error = null);
                                    }
                                  },
                                  onSubmitted: (_) => _unlockWithPasscode(),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _unlockWithPasscode,
                                    icon: const Icon(Icons.lock_open_rounded),
                                    label: Text(
                                      context.tr('unlock_with_passcode'),
                                    ),
                                  ),
                                ),
                              ],
                              if (lock.biometricEnabled) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _unlockBusy
                                        ? null
                                        : _unlockWithBiometric,
                                    icon: const Icon(Icons.fingerprint_rounded),
                                    label: Text(
                                      _unlockBusy
                                          ? context.tr('checking')
                                          : context.tr('unlock_with_biometrics'),
                                    ),
                                  ),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
