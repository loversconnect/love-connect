import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lerolove/providers/discovery_provider.dart';
import 'package:lerolove/Utils/responsive.dart';
import 'package:lerolove/Utils/app_feedback.dart';

class DiscoverySettingsScreen extends StatefulWidget {
  const DiscoverySettingsScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverySettingsScreen> createState() =>
      _DiscoverySettingsScreenState();
}

class _DiscoverySettingsScreenState extends State<DiscoverySettingsScreen> {
  late String _interestedIn;
  late RangeValues _ageRange;
  late double _maxDistance;
  late bool _showOnlineOnly;
  late bool _verifiedProfilesOnly;
  late DiscoverSortMode _sortMode;
  bool _hasChanges = false;
  bool _initialized = false;

  final List<Map<String, String>> _interestOptions = const [
    {'label': 'Male', 'value': 'MALE'},
    {'label': 'Female', 'value': 'FEMALE'},
    {'label': 'Everyone', 'value': 'Everyone'},
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

  Future<void> _saveChanges() async {
    await context.read<DiscoveryProvider>().updateDiscoverySettings(
      interestedInValue: _interestedIn,
      ageRangeValue: _ageRange,
      maxDistanceKmValue: _maxDistance,
      showOnlineOnlyValue: _showOnlineOnly,
      verifiedProfilesOnlyValue: _verifiedProfilesOnly,
      discoverSortModeValue: _sortMode,
    );
    if (!mounted) return;
    await AppFeedback.showBottomStatus(
      context,
      message: 'Discovery settings saved',
    );
    setState(() {
      _hasChanges = false;
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _markChanged() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  int _estimateLocalMatches() {
    return context.read<DiscoveryProvider>().estimateMatchesFor(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Discovery Settings'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      Icons.tune,
                      color: colorScheme.primary,
                      size: Responsive.icon(context, 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tune nearby people by distance and relation fit.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'I\'m interested in',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.font(context, 18),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: _interestOptions.map((option) {
                  final label = option['label']!;
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
                      _markChanged();
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Age range',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.font(context, 18),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_ageRange.start.round()}-${_ageRange.end.round()}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                        fontSize: Responsive.font(context, 15),
                      ),
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
                labels: RangeLabels(
                  _ageRange.start.round().toString(),
                  _ageRange.end.round().toString(),
                ),
                onChanged: (values) {
                  setState(() {
                    _ageRange = values;
                  });
                  _markChanged();
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Maximum distance',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.font(context, 18),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_maxDistance.round()} km',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                        fontSize: Responsive.font(context, 15),
                      ),
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
                label: '${_maxDistance.round()} km',
                onChanged: (value) {
                  setState(() {
                    _maxDistance = value;
                  });
                  _markChanged();
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Additional Filters',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.font(context, 18),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show online only'),
                subtitle: const Text('Only see people currently active'),
                value: _showOnlineOnly,
                onChanged: (value) {
                  setState(() {
                    _showOnlineOnly = value;
                  });
                  _markChanged();
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
                  _markChanged();
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Sort discovery by',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.font(context, 16),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Nearby first'),
                    selected: _sortMode == DiscoverSortMode.nearby,
                    showCheckmark: true,
                    checkmarkColor: colorScheme.onPrimary,
                    onSelected: (_) {
                      setState(() {
                        _sortMode = DiscoverSortMode.nearby;
                      });
                      _markChanged();
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
                    showCheckmark: true,
                    checkmarkColor: colorScheme.onPrimary,
                    onSelected: (_) {
                      setState(() {
                        _sortMode = DiscoverSortMode.bestMatch;
                      });
                      _markChanged();
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
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.12),
                      colorScheme.secondary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline,
                        color: colorScheme.primary,
                        size: Responsive.icon(context, 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Matches',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onBackground.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '~$estimated people',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                              fontSize: Responsive.font(context, 20),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'match your preferences',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
