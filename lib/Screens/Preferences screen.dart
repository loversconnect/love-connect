import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Main%20app%20screen.dart';
import 'package:lerolove/Utils/app_i18n.dart';
import 'package:lerolove/providers/auth_provider.dart';
import 'package:lerolove/providers/discovery_provider.dart';
import 'package:lerolove/providers/profile_provider.dart';
import 'package:lerolove/services/backend_api.dart';
import 'package:lerolove/Utils/responsive.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final BackendApi _backendApi = BackendApi();
  late String _interestedIn;
  late RangeValues _ageRange;
  late double _maxDistance;
  bool _showOnlineOnly = false;
  bool _verifiedProfilesOnly = false;
  DiscoverSortMode _sortMode = DiscoverSortMode.nearby;
  bool _initialized = false;

  final List<Map<String, String>> _interestOptions = const [
    {'label': 'male', 'value': 'MALE'},
    {'label': 'female', 'value': 'FEMALE'},
    {'label': 'everyone', 'value': 'Everyone'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final discovery = context.read<DiscoveryProvider>();
    _interestedIn = discovery.interestedIn;
    _ageRange = discovery.ageRange;
    _maxDistance = discovery.maxDistanceKm;
    _showOnlineOnly = discovery.showOnlineOnly;
    _verifiedProfilesOnly = discovery.verifiedProfilesOnly;
    _sortMode = discovery.discoverSortMode;
    _initialized = true;
  }

  Future<void> _startMatching() async {
    final discovery = context.read<DiscoveryProvider>();
    final locationReady = await _ensureLocationReady();
    if (!locationReady) return;

    await discovery.updateDiscoverySettings(
      interestedInValue: _interestedIn,
      ageRangeValue: _ageRange,
      maxDistanceKmValue: _maxDistance,
      showOnlineOnlyValue: _showOnlineOnly,
      verifiedProfilesOnlyValue: _verifiedProfilesOnly,
      discoverSortModeValue: _sortMode,
    );
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainAppScreen()),
      (route) => false,
    );
  }

  Future<bool> _ensureLocationReady() async {
    final profile = context.read<ProfileProvider>();
    final auth = context.read<AuthProvider>();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location_services_required'))),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location_permission_required'))),
      );
      return false;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    await profile.updateLocalLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final ready = await auth.ensureBackendSession();
    final token = auth.backendToken;
    if (!ready || token == null || token.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('backend_session_unavailable'))),
      );
      return false;
    }

    try {
      await _backendApi.updateLocation(
        token: token,
        lat: position.latitude,
        lng: position.longitude,
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location_sync_failed'))),
      );
      return false;
    }
  }

  int _estimateLocalMatches() {
    final discovery = context.read<DiscoveryProvider>();
    return discovery.estimateMatchesFor(
      interestedInValue: _interestedIn,
      ageRangeValue: _ageRange,
      maxDistanceKmValue: _maxDistance,
      showOnlineOnlyValue: _showOnlineOnly,
      verifiedProfilesOnlyValue: _verifiedProfilesOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final estimated = _estimateLocalMatches();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('your_preferences')),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('set_your_preferences'),
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.font(context, 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('preferences_intro'),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
                        fontSize: Responsive.font(context, 15),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      context.tr('interested_in'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.font(context, 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: _interestOptions.map((option) {
                        final label = context.tr(option['label']!);
                        final value = option['value']!;
                        final isSelected = _interestedIn == value;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          showCheckmark: true,
                          checkmarkColor: colorScheme.onPrimary,
                          onSelected: (_) {
                            setState(() {
                              _interestedIn = value;
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
                            horizontal: 20,
                            vertical: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('age_range'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_ageRange.start.round()}-${_ageRange.end.round()}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                            fontSize: Responsive.font(context, 16),
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _ageRange,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: colorScheme.primary,
                      inactiveColor: colorScheme.surfaceVariant,
                      onChanged: (values) {
                        setState(() {
                          _ageRange = values;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('max_distance'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_maxDistance.round()} ${context.tr('km_away_suffix')}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                            fontSize: Responsive.font(context, 16),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxDistance,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: colorScheme.primary,
                      inactiveColor: colorScheme.surfaceVariant,
                      onChanged: (value) {
                        setState(() {
                          _maxDistance = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('show_online_only')),
                      subtitle: Text(context.tr('only_people_active_now')),
                      value: _showOnlineOnly,
                      onChanged: (value) {
                        setState(() {
                          _showOnlineOnly = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('verified_only')),
                      subtitle: Text(context.tr('verified_only_sub')),
                      value: _verifiedProfilesOnly,
                      onChanged: (value) {
                        setState(() {
                          _verifiedProfilesOnly = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('sort_by'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        ChoiceChip(
                          label: Text(context.tr('nearby_first')),
                          selected: _sortMode == DiscoverSortMode.nearby,
                          showCheckmark: true,
                          checkmarkColor: colorScheme.onPrimary,
                          onSelected: (_) {
                            setState(() {
                              _sortMode = DiscoverSortMode.nearby;
                            });
                          },
                          selectedColor: colorScheme.primary,
                          backgroundColor: colorScheme.surfaceVariant,
                          labelStyle: TextStyle(
                            color: _sortMode == DiscoverSortMode.nearby
                                ? colorScheme.onPrimary
                                : colorScheme.onBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(context.tr('best_relation')),
                          selected: _sortMode == DiscoverSortMode.bestMatch,
                          showCheckmark: true,
                          checkmarkColor: colorScheme.onPrimary,
                          onSelected: (_) {
                            setState(() {
                              _sortMode = DiscoverSortMode.bestMatch;
                            });
                          },
                          selectedColor: colorScheme.primary,
                          backgroundColor: colorScheme.surfaceVariant,
                          labelStyle: TextStyle(
                            color: _sortMode == DiscoverSortMode.bestMatch
                                ? colorScheme.onPrimary
                                : colorScheme.onBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.secondary.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: colorScheme.primary,
                            size: Responsive.icon(context, 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '~$estimated ${context.tr('estimated_people_match')}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.7,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: Responsive.pagePadding(context),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startMatching,
                  child: Text(context.tr('start_matching')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
