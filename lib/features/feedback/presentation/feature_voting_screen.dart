import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/feedback_providers.dart';
import '../domain/feature_request.dart';

/// Bucket 2 §3b — the feature-voting board (Pro perk). Pushed from Settings,
/// which already gates entry behind FeatureGate(prioritySupport); this screen
/// assumes the viewer is Pro.
class FeatureVotingScreen extends ConsumerStatefulWidget {
  const FeatureVotingScreen({super.key});

  @override
  ConsumerState<FeatureVotingScreen> createState() =>
      _FeatureVotingScreenState();
}

class _FeatureVotingScreenState extends ConsumerState<FeatureVotingScreen> {
  final Set<String> _busy = {}; // request ids with an in-flight vote toggle

  Future<void> _toggleVote(FeatureRequest req) async {
    if (_busy.contains(req.id)) return;
    setState(() => _busy.add(req.id));
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .setVote(requestId: req.id, voted: !req.hasVoted);
      ref.invalidate(featureRequestsProvider);
      await ref.read(featureRequestsProvider.future);
    } catch (e) {
      _snack("Couldn't save your vote — try again.");
    } finally {
      if (mounted) setState(() => _busy.remove(req.id));
    }
  }

  Future<void> _openSuggestSheet() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SuggestSheet(titleCtrl: titleCtrl, descCtrl: descCtrl),
    );
    if (submitted == true) {
      try {
        await ref.read(feedbackRepositoryProvider).submitFeatureRequest(
              title: titleCtrl.text,
              description: descCtrl.text,
            );
        ref.invalidate(featureRequestsProvider);
        _snack('Thanks — your suggestion is on the board.');
      } catch (_) {
        _snack("Couldn't submit just now — try again.");
      }
    }
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(featureRequestsProvider);
    return GradientBackground(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Feature requests'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSuggestSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
        label: const Text('Suggest', style: TextStyle(color: Colors.white)),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(featureRequestsProvider)),
        data: (requests) {
          if (requests.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            physics: const BouncingScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = requests[i];
              return _RequestCard(
                request: r,
                busy: _busy.contains(r.id),
                onVote: () => _toggleVote(r),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FeatureRequest request;
  final bool busy;
  final VoidCallback onVote;
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VotePill(
            count: request.voteCount,
            voted: request.hasVoted,
            busy: busy,
            onTap: onVote,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.title,
                        style: AppTypography.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (request.status != 'open') _StatusChip(status: request.status),
                  ],
                ),
                if (request.description != null &&
                    request.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(request.description!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VotePill extends StatelessWidget {
  final int count;
  final bool voted;
  final bool busy;
  final VoidCallback onTap;
  const _VotePill({
    required this.count,
    required this.voted,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = voted ? AppColors.primary : AppColors.textMedium;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: voted
              ? AppColors.primarySurface
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: voted ? AppColors.primary : AppColors.divider,
            width: voted ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(LucideIcons.chevronUp, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'planned' => ('Planned', AppColors.primary),
      'shipped' => ('Shipped', AppColors.success),
      _ => (status, AppColors.textLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SuggestSheet extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  const _SuggestSheet({required this.titleCtrl, required this.descCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggest a feature', style: AppTypography.heading2),
            const SizedBox(height: 4),
            Text('Tell us what would help you most.',
                style: AppTypography.caption),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Offline mock tests',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.lightbulb, size: 34, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No requests yet', style: AppTypography.heading3),
            const SizedBox(height: 6),
            Text(
              'Be the first — tap “Suggest” to add a feature for everyone to vote on.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 30, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text("Couldn't load requests", style: AppTypography.bodyLarge),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
