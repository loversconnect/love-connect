import 'package:flutter/material.dart';
import 'package:lerolove/Utils/app_i18n.dart';
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
        message: context.tr('privacy_load_failed'),
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
        message: context.tr('privacy_saved'),
      );
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: context.tr('privacy_save_failed'),
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
      appBar: AppBar(title: Text(context.tr('privacy_settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr('privacy_intro'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _discoverable,
                  onChanged: _saving ? null : (v) => _save(discoverable: v),
                  title: Text(context.tr('show_profile_discovery')),
                  subtitle: Text(context.tr('show_profile_discovery_sub')),
                ),
                SwitchListTile(
                  value: _showOnlineStatus,
                  onChanged: _saving ? null : (v) => _save(showOnlineStatus: v),
                  title: Text(context.tr('show_online_status')),
                  subtitle: Text(context.tr('show_online_status_sub')),
                ),
                SwitchListTile(
                  value: _showDistanceInDiscovery,
                  onChanged: _saving
                      ? null
                      : (v) => _save(showDistanceInDiscovery: v),
                  title: Text(context.tr('show_distance_discovery')),
                  subtitle: Text(context.tr('show_distance_discovery_sub')),
                ),
                SwitchListTile(
                  value: _allowMessagesFromMatchesOnly,
                  onChanged: _saving
                      ? null
                      : (v) => _save(allowMessagesFromMatchesOnly: v),
                  title: Text(context.tr('messages_matches_only')),
                  subtitle: Text(context.tr('messages_matches_only_sub')),
                ),
              ],
            ),
    );
  }
}
