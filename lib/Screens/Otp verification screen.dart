import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Screens/Add%20photos%20screen.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Main%20app%20screen.dart';
import 'package:lerolove/Screens/Preferences%20screen.dart';
import 'package:lerolove/Screens/Profile%20basics%20screen.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'dart:async';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({Key? key, required this.phoneNumber})
    : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _canResend = false;
  int _resendTimer = 30;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 30;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered, auto-verify
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOTPCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _verifyOTP() async {
    final code = _getOTPCode();
    if (code.length != 6) return;

    setState(() {
      _isVerifying = true;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifySmsCode(code);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error != null
                ? context.trError(auth.error!)
                : context.tr('invalid_verification_code'),
          ),
        ),
      );
      return;
    }

    await context.read<ProfileProvider>().syncFromBackendIfAvailable();
    final profileData = context.read<ProfileProvider>().currentProfile;
    final Widget nextScreen;
    if (profileData == null || !profileData.hasCompletedBasics) {
      nextScreen = const ProfileBasicsScreen();
    } else if (!profileData.hasSelfiePhoto) {
      nextScreen = const AddPhotosScreen();
    } else if (!profileData.hasLocationSet) {
      nextScreen = const PreferencesScreen();
    } else {
      nextScreen = const MainAppScreen();
    }

    // Navigate to profile setup first when profile is incomplete.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
      (route) => false,
    );
  }

  void _resendCode() {
    if (!_canResend) return;
    context
        .read<AuthProvider>()
        .startPhoneVerification(widget.phoneNumber)
        .then((ok) {
          if (!mounted) return;
          if (ok) {
            _startResendTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('verification_code_sent')),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.read<AuthProvider>().error != null
                      ? context.trError(context.read<AuthProvider>().error!)
                      : context.tr('failed_resend_code'),
                ),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: Responsive.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: colorScheme.primary,
                      size: Responsive.icon(context, 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('verification'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                context.tr('enter_verification_code'),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.font(context, 28),
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                '${context.tr('we_sent_code_to')} ${widget.phoneNumber}',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.7),
                  fontSize: Responsive.font(context, 15),
                ),
              ),
              const SizedBox(height: 32),
              // OTP Input Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.font(context, 20),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.surfaceVariant,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              // Resend Code Button
              Center(
                child: TextButton(
                  onPressed: _canResend ? _resendCode : null,
                  child: Text(
                    _canResend
                        ? context.tr('resend_code')
                        : '${context.tr('resend_in')} ${_resendTimer}s',
                    style: textTheme.bodyLarge?.copyWith(
                      color: _canResend
                          ? colorScheme.primary
                          : colorScheme.onBackground.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.font(context, 15),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Loading Indicator
              if (_isVerifying)
                Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
