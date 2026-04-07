import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_user.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'expert_detail_screen.dart';

class ExpertsScreen extends StatefulWidget {
  const ExpertsScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<ExpertsScreen> createState() => _ExpertsScreenState();
}

class _ExpertsScreenState extends State<ExpertsScreen> {
  String? _selectedDomain;
  RangeValues _priceRange = const RangeValues(0, 10000);
  double _minRating = 0;
  String _sortBy = 'rating';

  List<Expert> _applyFiltersAndSort(List<Expert> list) {
    var filtered = list.where((e) {
      final domainMatch = _selectedDomain == null || e.domain == _selectedDomain;
      final priceMatch = e.pricePerSession >= _priceRange.start &&
          e.pricePerSession <= _priceRange.end;
      final ratingMatch = e.rating >= _minRating;
      return domainMatch && priceMatch && ratingMatch;
    }).toList();

    switch (_sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      case 'price_low':
        filtered.sort((a, b) => a.pricePerSession.compareTo(b.pricePerSession));
      case 'price_high':
        filtered.sort((a, b) => b.pricePerSession.compareTo(a.pricePerSession));
      case 'reviews':
        filtered.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Experts')),
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: StreamBuilder<List<Expert>>(
        stream: svc.experts.watchVerifiedExperts(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error loading experts',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          if (!snap.hasData) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SkeletonLoader.list(itemCount: 4),
            );
          }

          final allExperts = snap.data!;
          final domains = allExperts.map((e) => e.domain).toSet().toList()..sort();
          final filtered = _applyFiltersAndSort(allExperts);

          return Column(
            children: [
              // Filter bar
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceLight.withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Domain filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: _selectedDomain == null,
                              onSelected: (_) => setState(() => _selectedDomain = null),
                            ),
                          ),
                          ...domains.map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(d),
                                selected: _selectedDomain == d,
                                onSelected: (_) => setState(
                                  () => _selectedDomain = _selectedDomain == d ? null : d,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Price range slider
                    Row(
                      children: [
                        Text('Price:', style: theme.textTheme.labelSmall),
                        Expanded(
                          child: RangeSlider(
                            values: _priceRange,
                            min: 0,
                            max: 10000,
                            divisions: 20,
                            labels: RangeLabels(
                              'INR ${_priceRange.start.round()}',
                              'INR ${_priceRange.end.round()}',
                            ),
                            onChanged: (v) => setState(() => _priceRange = v),
                          ),
                        ),
                      ],
                    ),
                    // Rating filter + sort
                    Row(
                      children: [
                        Text('Min rating:', style: theme.textTheme.labelSmall),
                        const SizedBox(width: 4),
                        ...List.generate(
                          5,
                          (i) => GestureDetector(
                            onTap: () => setState(() => _minRating = (i + 1).toDouble()),
                            child: Icon(
                              i < _minRating ? Icons.star : Icons.star_border,
                              size: 20,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        if (_minRating > 0)
                          GestureDetector(
                            onTap: () => setState(() => _minRating = 0),
                            child: Icon(
                              Icons.clear,
                              size: 16,
                              color: colorScheme.outline,
                            ),
                          ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _sortBy,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'rating', child: Text('Rating')),
                            DropdownMenuItem(value: 'price_low', child: Text('Price ↑')),
                            DropdownMenuItem(value: 'price_high', child: Text('Price ↓')),
                            DropdownMenuItem(value: 'reviews', child: Text('Reviews')),
                          ],
                          onChanged: (v) => setState(() => _sortBy = v ?? 'rating'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Expert list
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateWidget(
                        title: 'No Experts Found',
                        subtitle: 'Try adjusting your filters',
                        icon: Icons.person_search,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ExpertDetailScreen(
                                  appUser: widget.appUser,
                                  expert: e,
                                ),
                              ),
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                e.name,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (e.isVerified)
                                              const Icon(
                                                Icons.verified,
                                                color: Colors.blue,
                                                size: 16,
                                              ),
                                          ],
                                        ),
                                        Text(
                                          e.domain,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 14, color: Colors.amber),
                                            Text(
                                              ' ${e.rating.toStringAsFixed(1)} (${e.totalReviews})',
                                              style: theme.textTheme.labelSmall,
                                            ),
                                            const Spacer(),
                                            Text(
                                              'INR ${e.pricePerSession}',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: colorScheme.outline),
                                ],
                              ),
                            ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: 0.05, end: 0),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
