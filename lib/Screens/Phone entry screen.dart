import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Screens/Otp%20verification%20screen.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/Utils/app_state.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({Key? key}) : super(key: key);

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    setState(() {
      _isValid = RegExp(r'^\d{9}$').hasMatch(phone);
    });
  }

  Future<void> _continue() async {
    if (_isValid) {
      final normalized = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
      final phoneNumber = '+265$normalized';
      final auth = context.read<AuthProvider>();
      final appState = context.read<AppState>();
      appState.setPhoneNumber(phoneNumber);
      final ok = await auth.startPhoneVerification(phoneNumber);
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.error != null
                  ? context.trError(auth.error!)
                  : context.tr('could_not_continue'),
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(phoneNumber: phoneNumber),
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: Responsive.pagePadding(context).add(
                EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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
                              Icons.lock_outline,
                              color: colorScheme.primary,
                              size: Responsive.icon(context, 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.tr('secure_sign_in'),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        context.tr('your_phone_number'),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.font(context, 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        context.tr('otp_intro'),
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7),
                          fontSize: Responsive.font(context, 15),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Input Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.secondary.withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('phone_number'),
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+265',
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: Responsive.font(context, 16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Phone Number Input
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 9,
                                    cursorColor: colorScheme.primary,
                                    cursorWidth: 2.2,
                                    cursorHeight: Responsive.font(context, 20),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '991234567',
                                      hintStyle: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.34),
                                        fontSize: Responsive.font(context, 16),
                                      ),
                                      counterText: '',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 2,
                                          ),
                                    ),
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: Responsive.font(context, 16),
                                    ),
                                    onSubmitted: (_) => _continue(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('phone_help'),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.55,
                                ),
                                fontSize: Responsive.font(context, 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isValid && !auth.isLoading)
                              ? _continue
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isValid
                                ? colorScheme.primary
                                : colorScheme.surfaceVariant,
                            foregroundColor: _isValid
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                          child: auth.isLoading
                              ? SizedBox(
                                  width: Responsive.icon(context, 20),
                                  height: Responsive.icon(context, 20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.tr('continue')),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
