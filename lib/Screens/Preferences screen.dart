import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/Screens/Main%20app%20screen.dart';
import 'package:lerolove/Utils/app_state.dart';
import 'package:lerolove/Utils/responsive.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late String _interestedIn;
  late RangeValues _ageRange;
  late double _maxDistance;
  bool _showOnlineOnly = false;
  bool _verifiedProfilesOnly = false;
  DiscoverSortMode _sortMode = DiscoverSortMode.nearby;
  bool _initialized = false;

  final List<String> _interests = ['Male', 'Female', 'Everyone'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final appState = context.read<AppState>();
    _interestedIn = appState.interestedIn;
    _ageRange = appState.ageRange;
    _maxDistance = appState.maxDistanceKm;
    _showOnlineOnly = appState.showOnlineOnly;
    _verifiedProfilesOnly = appState.verifiedProfilesOnly;
    _sortMode = appState.discoverSortMode;
    _initialized = true;
  }

  void _startMatching() {
    context.read<AppState>().updateDiscoverySettings(
          interestedInValue: _interestedIn,
          ageRangeValue: _ageRange,
          maxDistanceKmValue: _maxDistance,
          showOnlineOnlyValue: _showOnlineOnly,
          verifiedProfilesOnlyValue: _verifiedProfilesOnly,
          discoverSortModeValue: _sortMode,
        );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainAppScreen()),
      (route) => false,
    );
  }

  int _estimateLocalMatches() {
    final appState = context.read<AppState>();
    return appState.estimateMatchesFor(
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
        title: const Text('Your Preferences'),
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
                      'Set Your Preferences',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.font(context, 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will show nearby people with the strongest relation first.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
                        fontSize: Responsive.font(context, 15),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'I\'m interested in',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.font(context, 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: _interests.map((interest) {
                        final isSelected = _interestedIn == interest;
                        return ChoiceChip(
                          label: Text(interest),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _interestedIn = interest;
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
                          'Age range',
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
                          'Maximum distance',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_maxDistance.round()} km',
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
                      title: const Text('Show online only'),
                      subtitle: const Text('Only people active right now'),
                      value: _showOnlineOnly,
                      onChanged: (value) {
                        setState(() {
                          _showOnlineOnly = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verified profiles only'),
                      subtitle: const Text('Only see verified accounts'),
                      value: _verifiedProfilesOnly,
                      onChanged: (value) {
                        setState(() {
                          _verifiedProfilesOnly = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sort discovery by',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        ChoiceChip(
                          label: const Text('Nearby first'),
                          selected: _sortMode == DiscoverSortMode.nearby,
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
                          label: const Text('Best relation'),
                          selected: _sortMode == DiscoverSortMode.bestMatch,
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
                              '~$estimated people match your nearby preferences',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onBackground.withOpacity(0.7),
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
                  child: const Text('Start Matching'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
