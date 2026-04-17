import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lerolove/Screens/Profile%20basics%20screen.dart';
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
    // Malawi phone numbers are 9 digits after +265
    final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    setState(() {
      _isValid = phone.length == 9 && RegExp(r'^[0-9]+$').hasMatch(phone);
    });
  }

  Future<void> _continue() async {
    if (_isValid) {
      final phoneNumber =
          '+265${_phoneController.text.replaceAll(RegExp(r'\s+'), '')}';
      final auth = context.read<AuthProvider>();
      final appState = context.read<AppState>();
      appState.setPhoneNumber(phoneNumber);
      final ok = await auth.continueWithoutOtp(phoneNumber);
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Could not continue right now')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileBasicsScreen()),
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
                            'Secure Sign In',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        'Your Phone Number',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.font(context, 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'OTP via OneKhuza is coming soon. Continue to complete your profile setup for now.',
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
                              'Phone Number',
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
                                // Country Code Selector
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
                                    child: Row(
                                      children: [
                                        Text(
                                          '🇲🇼',
                                          style: TextStyle(
                                            fontSize: Responsive.font(
                                              context,
                                              24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '+265',
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: Responsive.font(
                                              context,
                                              16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Phone Number Input
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 9,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: '991234567',
                                      counterText: '',
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
                              'Enter your 9-digit Malawi phone number',
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
                              : const Text('Continue'),
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
