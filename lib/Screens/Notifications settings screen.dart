import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/Utils/app_feedback.dart';
import 'package:lerolove/services/message_alert_service.dart';
import 'package:lerolove/services/push_service.dart';
import 'package:provider/provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _pushEnabled = true;
  String _ringtoneTitle = 'Default phone ringtone';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final ringtoneTitle = await MessageAlertService.getRingtoneTitle();
    if (!mounted) return;
    setState(() {
      _pushEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      _ringtoneTitle = ringtoneTitle;
      _loading = false;
    });
  }

  Future<void> _chooseRingtone() async {
    try {
      await MessageAlertService.pickRingtone();
      final title = await MessageAlertService.getRingtoneTitle();
      if (!mounted) return;
      setState(() {
        _ringtoneTitle = title;
      });
      await AppFeedback.showBottomStatus(
        context,
        message: 'Message ringtone saved',
      );
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: 'Could not choose ringtone',
        success: false,
      );
    }
  }

  Future<void> _previewRingtone() async {
    try {
      await MessageAlertService.playSelectedRingtone();
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: 'Playing ringtone preview',
      );
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: 'Ringtone preview failed',
        success: false,
      );
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final ready = await auth.ensureBackendSession();
      final backendToken = auth.backendToken;
      if (!ready || backendToken == null || backendToken.isEmpty) {
        throw Exception('Backend session unavailable.');
      }

      if (enabled) {
        final permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final granted =
            permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional;
        if (!granted) {
          throw Exception('Notification permission denied.');
        }
        await PushService.instance.bindBackendSession(backendToken);
      } else {
        await PushService.instance.unbindBackendSession();
      }

      if (!mounted) return;
      setState(() {
        _pushEnabled = enabled;
      });
      await AppFeedback.showBottomStatus(
        context,
        message: enabled ? 'Notifications enabled' : 'Notifications disabled',
      );
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showBottomStatus(
        context,
        message: 'Notification update failed',
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
      appBar: AppBar(title: const Text('Notifications')),
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
                    'Control whether this account receives push notifications for new matches and messages.',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _pushEnabled,
                  onChanged: _saving ? null : _setPushEnabled,
                  title: const Text('Push notifications'),
                  subtitle: const Text('Match and chat alerts'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  enabled: _pushEnabled && !_saving,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Message ringtone'),
                  subtitle: Text(_ringtoneTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _chooseRingtone,
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pushEnabled && !_saving
                          ? _previewRingtone
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Preview'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _pushEnabled && !_saving
                          ? MessageAlertService.stopRingtone
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
