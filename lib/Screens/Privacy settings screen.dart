import 'package:flutter/material.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/Utils/app_feedback.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:provider/provider.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final BackendApi _api = BackendApi();

  bool _loading = true;
  bool _saving = false;
  bool _discoverable = true;
  bool _showOnlineStatus = true;
  bool _showDistanceInDiscovery = true;
  bool _allowMessagesFromMatchesOnly = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<String?> _token() async {
    final auth = context.read<AuthProvider>();
    final ready = await auth.ensureBackendSession();
    final token = auth.backendToken;
    if (!ready || token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> _loadPrivacy() async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Backend session unavailable.');
      final dto = await _api.getPrivacySettings(token: token);
      if (!mounted) return;
      setState(() {
        _discoverable = dto.discoverable;
        _showOnlineStatus = dto.showOnlineStatus;
        _showDistanceInDiscovery = dto.showDistanceInDiscovery;
        _allowMessagesFromMatchesOnly = dto.allowMessagesFromMatchesOnly;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      await AppFeedback.showBottomStatus(
        context,
        message: 'Failed to load privacy settings',
        success: false,
      );
    }
  }

  Future<void> _save({
    bool? discoverable,
    bool? showOnlineStatus,
    bool? showDistanceInDiscovery,
    bool? allowMessagesFromMatchesOnly,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      final token = await _token();
      if (token == null) throw Exception('Backend session unavailable.');
      final updated = await _api.updatePrivacySettings(
        token: token,
        discoverable: discoverable,
        showOnlineStatus: showOnlineStatus,
        showDistanceInDiscovery: showDistanceInDiscovery,
        allowMessagesFromMatchesOnly: allowMessagesFromMatchesOnly,
      );
      if (!mounted) return;
      setState(() {
        _discoverable = updated.discoverable;
        _showOnlineStatus = updated.showOnlineStatus;
        _showDistanceInDiscovery = updated.showDistanceInDiscovery;
        _allowMessagesFromMatchesOnly = updated.allowMessagesFromMatchesOnly;
      });
      await AppFeedback.showBottomStatus(
        context,
        message: 'Privacy setting saved',
      );
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: 'Failed to save privacy setting',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: const Text(
                    'These privacy options are saved on your account and enforced by backend.',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _discoverable,
                  onChanged: _saving ? null : (v) => _save(discoverable: v),
                  title: const Text('Show my profile in discovery'),
                  subtitle: const Text(
                    'If off, other people cannot find you in swipe/discovery.',
                  ),
                ),
                SwitchListTile(
                  value: _showOnlineStatus,
                  onChanged: _saving ? null : (v) => _save(showOnlineStatus: v),
                  title: const Text('Show online status'),
                  subtitle: const Text('Allow app to show your active status.'),
                ),
                SwitchListTile(
                  value: _showDistanceInDiscovery,
                  onChanged: _saving
                      ? null
                      : (v) => _save(showDistanceInDiscovery: v),
                  title: const Text('Show distance in discovery'),
                  subtitle: const Text('Hide your exact distance from others.'),
                ),
                SwitchListTile(
                  value: _allowMessagesFromMatchesOnly,
                  onChanged: _saving
                      ? null
                      : (v) => _save(allowMessagesFromMatchesOnly: v),
                  title: const Text('Messages from matches only'),
                  subtitle: const Text(
                    'Block messages from non-matched users.',
                  ),
                ),
              ],
            ),
    );
  }
}
