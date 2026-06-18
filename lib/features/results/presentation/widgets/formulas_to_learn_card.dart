import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/formula_providers.dart';
import '../../domain/formula.dart';

/// Feature 4 — "Formulas to learn" (Pro, gated by advancedBreakdown in the
/// results screen). Static lookup from the curated formula bank for the result's
/// weak chapters/topics, important first. NO meter. Renders LaTeX with
/// flutter_math_fork and falls back to a pre-rendered image_url when present.
///
/// Returns nothing when no formulas are curated for the weak topics (graceful
/// empty state — never an empty card).
class FormulasToLearnCard extends ConsumerWidget {
  final String attemptId;
  const FormulasToLearnCard({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formulas = ref.watch(formulasToLearnProvider(attemptId)).valueOrNull;
    if (formulas == null || formulas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppColors.greenSurface,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.sigma, color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Formulas to learn', style: AppTypography.heading3),
                      Text('For your weak chapters — most important first',
                          style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...formulas.asMap().entries.map((e) => _FormulaRow(
                  formula: e.value,
                  showBorder: e.key != formulas.length - 1,
                )),
          ],
        ),
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final Formula formula;
  final bool showBorder;
  const _FormulaRow({required this.formula, required this.showBorder});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(formula.name,
                        style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  if (formula.isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.weak.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.star, size: 11, color: AppColors.weak),
                          const SizedBox(width: 4),
                          Text('Important',
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.weak,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _FormulaBody(formula: formula),
              if (formula.note != null && formula.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(formula.note!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
        if (showBorder)
          Divider(color: AppColors.divider, height: 1, thickness: 0.5),
      ],
    );
  }
}

/// Renders the formula: pre-rendered image when authored, otherwise LaTeX via
/// flutter_math_fork (falling back to the raw TeX string on a parse error so a
/// bad row never blanks the card).
class _FormulaBody extends StatelessWidget {
  final Formula formula;
  const _FormulaBody({required this.formula});

  @override
  Widget build(BuildContext context) {
    final mathTextStyle = AppTypography.bodyLarge
        .copyWith(fontSize: 17, color: AppColors.textDark);

    if (formula.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          formula.imageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _tex(mathTextStyle),
        ),
      );
    }
    return _tex(mathTextStyle);
  }

  Widget _tex(TextStyle style) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          formula.formulaTex,
          mathStyle: MathStyle.text,
          textStyle: style,
          onErrorFallback: (_) => Text(
            formula.formulaTex,
            style: style.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}
