import 'package:flutter/material.dart';
import 'package:lerolove/Screens/Add%20photos%20screen.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/app_state.dart';

class ProfileBasicsScreen extends StatefulWidget {
  const ProfileBasicsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileBasicsScreen> createState() => _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends State<ProfileBasicsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isValid = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  void _validateForm() {
    setState(() {
      _isValid = _formKey.currentState?.validate() ?? false;
      _isValid = _isValid && _selectedDate != null && _selectedGender != null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(now.year - 100),
      lastDate: eighteenYearsAgo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _validateForm();
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _continue() async {
    if (_isValid) {
      context.read<AppState>().setUserName(
            firstNameValue: _firstNameController.text.trim(),
            lastNameValue: _lastNameController.text.trim(),
          );
      final age = _calculateAge(_selectedDate!);
      final auth = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();

      await profileProvider.upsertBasics(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: age,
        gender: _selectedGender ?? 'Other',
        phoneNumber: auth.currentPhoneNumber ?? '',
      );
      if (!mounted) return;

      if (profileProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(profileProvider.error!)),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddPhotosScreen()),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: Responsive.pagePadding(context),
                child: Form(
                  key: _formKey,
                  onChanged: _validateForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About You',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.font(context, 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell us a bit about yourself',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7),
                          fontSize: Responsive.font(context, 15),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          hintText: 'Enter your first name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          if (value.length < 2 || value.length > 50) {
                            return 'Name must be between 2 and 50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          hintText: 'Enter your last name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          if (value.length < 2 || value.length > 50) {
                            return 'Name must be between 2 and 50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Date of Birth
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              hintText: 'Select your date of birth',
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            controller: TextEditingController(
                              text: _selectedDate == null
                                  ? ''
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} (${_calculateAge(_selectedDate!)} years old)',
                            ),
                            validator: (value) {
                              if (_selectedDate == null) {
                                return 'Please select your date of birth';
                              }
                              final age = _calculateAge(_selectedDate!);
                              if (age < 18) {
                                return 'You must be 18 years or older';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Gender
                      Text(
                        'Gender',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: Responsive.font(context, 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: _genders.map((gender) {
                          final isSelected = _selectedGender == gender;
                          return ChoiceChip(
                            label: Text(gender),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedGender = selected ? gender : null;
                                _validateForm();
                              });
                            },
                            selectedColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onBackground,
                              fontWeight: FontWeight.w500,
                            ),
                            backgroundColor: colorScheme.surfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Button
            Padding(
              padding: Responsive.pagePadding(context),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isValid && !profileProvider.isLoading) ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isValid ? colorScheme.primary : colorScheme.surfaceVariant,
                    foregroundColor: _isValid
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                  child: profileProvider.isLoading
                      ? SizedBox(
                          width: Responsive.icon(context, 20),
                          height: Responsive.icon(context, 20),
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
