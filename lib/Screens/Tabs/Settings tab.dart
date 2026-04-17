import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Utils/theme_manager.dart';
import 'package:lerolove/Screens/Theme%20settings%20screen.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/Utils/app_state.dart';
import 'package:lerolove/Screens/Welcome%20screen.dart';
import 'package:lerolove/services/backend_api.dart';
import '../Edit profile screen.dart';
import '../Manage photos screen.dart';
import '../Discovery settings screen.dart';
import '../Blocked users screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileProvider>().currentProfile;
    final appState = context.watch<AppState>();
    final displayName = profile?.name ?? appState.displayName;
    final displayPhone = profile?.phoneNumber.isNotEmpty == true
        ? profile!.phoneNumber
        : appState.displayPhone;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile Card
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: Responsive.icon(context, 40),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: Responsive.font(context, 18),
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayPhone,
                            style: TextStyle(
                              fontSize: Responsive.font(context, 14),
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: 0.7,
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '70%',
                                style: TextStyle(
                                  fontSize: Responsive.font(context, 12),
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Profile completeness',
                            style: TextStyle(
                              fontSize: Responsive.font(context, 12),
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Appearance Section
          _buildSection(context, 'Appearance', isDark),
          _buildListTile(
            context,
            Icons.palette_outlined,
            'Theme & Wallpaper',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ThemeSettingsScreen(),
              ),
            ),
          ),
          // Dark Mode Quick Toggle
          Consumer<ThemeManager>(
            builder: (context, themeManager, child) {
              final isDarkMode = themeManager.themeMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: Responsive.font(context, 16),
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  isDarkMode ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: Responsive.font(context, 13),
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                value: isDarkMode,
                activeColor: colorScheme.primary,
                onChanged: (value) {
                  themeManager.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              );
            },
          ),
          const Divider(height: 1),

          // Profile Section
          _buildSection(context, 'Profile', isDark),
          _buildListTile(
            context,
            Icons.edit,
            'Edit Profile',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            ),
          ),
          _buildListTile(
            context,
            Icons.photo_library,
            'Manage Photos',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagePhotosScreen(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Preferences Section
          _buildSection(context, 'Preferences', isDark),
          _buildListTile(
            context,
            Icons.tune,
            'Discovery Settings',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DiscoverySettingsScreen(),
              ),
            ),
          ),
          _buildListTile(context, Icons.notifications, 'Notifications', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          }),
          const Divider(height: 1),

          // Safety & Privacy Section
          _buildSection(context, 'Safety & Privacy', isDark),
          _buildListTile(
            context,
            Icons.block,
            'Blocked Users',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BlockedUsersScreen(),
              ),
            ),
          ),
          _buildListTile(context, Icons.privacy_tip, 'Privacy Settings', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy Settings coming soon')),
            );
          }),
          const Divider(height: 1),

          // Support Section
          _buildSection(context, 'Support', isDark),
          _buildListTile(context, Icons.help_outline, 'Help & FAQ', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & FAQ coming soon')),
            );
          }),
          _buildListTile(context, Icons.mail_outline, 'Contact Support', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact Support coming soon')),
            );
          }),
          _buildListTile(context, Icons.info_outline, 'About', () {
            _showAboutDialog(context);
          }),
          const Divider(height: 1),

          // Account Section
          _buildSection(context, 'Account', isDark),
          _buildListTile(
            context,
            Icons.logout,
            'Log Out',
            () => _showLogoutDialog(context),
            color: Colors.red,
          ),
          _buildListTile(
            context,
            Icons.delete_outline,
            'Delete Account',
            () => _showDeleteAccountDialog(context),
            color: Colors.red,
          ),

          const SizedBox(height: 10),
          const _BackendStatusPanel(),

          const SizedBox(height: 24),

          // Version Info
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: Responsive.font(context, 13),
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 2,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.font(context, 16),
          color: color ?? (isDark ? Colors.white : Colors.black87),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Log Out',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Delete Account',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion requested'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'About LoversConnect',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Find love in Malawi',
                style: TextStyle(
                  fontSize: Responsive.font(context, 14),
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2024 LoversConnect\nAll rights reserved.',
                style: TextStyle(
                  fontSize: Responsive.font(context, 12),
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _BackendStatusPanel extends StatefulWidget {
  const _BackendStatusPanel();

  @override
  State<_BackendStatusPanel> createState() => _BackendStatusPanelState();
}

class _BackendStatusPanelState extends State<_BackendStatusPanel> {
  final BackendApi _backendApi = BackendApi();

  bool _checking = false;
  bool? _apiReachable;
  DateTime? _lastCheckedAt;
  String? _error;

  Future<void> _checkApi() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final reachable = await _backendApi.ping();
      if (!mounted) return;
      setState(() {
        _apiReachable = reachable;
        _lastCheckedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiReachable = false;
        _lastCheckedAt = DateTime.now();
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  String _timeLabel(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _statusChip({required String label, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withOpacity(0.12)
            : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ok ? Colors.green[800] : Colors.red[800],
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final isFirebaseAuthed = auth.isAuthenticated;
    final hasBackendToken =
        auth.backendToken != null && auth.backendToken!.isNotEmpty;
    final hasBackendSession = auth.isBackendAuthenticated;
    final backendUserId = auth.backendUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.developer_mode,
                  size: Responsive.icon(context, 18),
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Backend Status (Debug)',
                  style: TextStyle(
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(label: 'Firebase Auth', ok: isFirebaseAuthed),
                _statusChip(label: 'Backend Token', ok: hasBackendToken),
                _statusChip(label: 'Backend Session', ok: hasBackendSession),
                _statusChip(label: 'API Reachable', ok: _apiReachable == true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Backend User ID: ${backendUserId ?? 'Not resolved'}',
              style: TextStyle(
                fontSize: Responsive.font(context, 12),
                color: colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
            if (_lastCheckedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last checked: ${_timeLabel(_lastCheckedAt!)}',
                style: TextStyle(
                  fontSize: Responsive.font(context, 12),
                  color: colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                'Error: $_error',
                style: TextStyle(
                  fontSize: Responsive.font(context, 12),
                  color: Colors.red[700],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checking ? null : _checkApi,
                icon: _checking
                    ? SizedBox(
                        height: Responsive.icon(context, 16),
                        width: Responsive.icon(context, 16),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_checking ? 'Checking...' : 'Check Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
