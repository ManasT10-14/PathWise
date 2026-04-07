import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/expert.dart';
import '../models/review.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/skeleton_loader.dart';
import 'book_consultation_screen.dart';

class ExpertDetailScreen extends StatelessWidget {
  const ExpertDetailScreen({super.key, required this.appUser, required this.expert});

  final AppUser appUser;
  final Expert expert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(expert.name)),
      body: GradientBackground(
        variant: GradientVariant.accent,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header card
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          expert.name.isNotEmpty ? expert.name[0].toUpperCase() : '?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    expert.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (expert.isVerified)
                                  Chip(
                                    avatar: const Icon(Icons.verified, size: 16),
                                    label: const Text('Verified'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            Text(
                              expert.domain,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < expert.rating.round() ? Icons.star : Icons.star_border,
                          size: 20,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${expert.rating.toStringAsFixed(1)} (${expert.totalReviews} reviews)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${expert.experience} experience',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Skills section
            if (expert.skills.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Skills', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: expert.skills
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 16),

            // Book button
            GlassCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Session price', style: theme.textTheme.titleSmall),
                      Text(
                        'INR ${expert.pricePerSession}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Book Consultation — INR ${expert.pricePerSession}'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookConsultationScreen(
                            appUser: appUser,
                            expert: expert,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // Reviews section
            Text(
              'Reviews',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 8),
            StreamBuilder<List<Review>>(
              stream: context.svc.reviews.watchForExpert(expert.id),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SkeletonLoader(lines: 3);
                }
                final reviews = snap.data!;
                if (reviews.isEmpty) {
                  return GlassCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No reviews yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: List.generate(reviews.length, (i) {
                    final r = reviews[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(5, (star) => Icon(
                                      star < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 16,
                                      color: Colors.amber,
                                    )),
                                const Spacer(),
                                if (r.timestamp != null)
                                  Text(
                                    DateFormat.yMMMd().format(r.timestamp!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                              ],
                            ),
                            if (r.feedback.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                r.feedback,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: (i * 60 + 300).ms),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
