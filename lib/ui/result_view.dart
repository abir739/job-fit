import 'package:flutter/material.dart';

import '../evaluation/evaluation_controller.dart';
import '../scoring/fit_score.dart';
import 'cover_letter_card.dart';

const _green = Color(0xFF1E8E5A);
const _amber = Color(0xFFE08A00);
const _red = Color(0xFFD64545);
const _blue = Color(0xFF2F6FDB);

Color verdictColor(Verdict v) => switch (v) {
  Verdict.apply => _green,
  Verdict.applyWithCaution => _amber,
  Verdict.skip => _red,
};

String verdictLabel(Verdict v) => switch (v) {
  Verdict.apply => 'APPLY',
  Verdict.applyWithCaution => 'APPLY WITH CAUTION',
  Verdict.skip => 'SKIP',
};

String blockerLabel(Blocker b) => switch (b) {
  Blocker.notMobileRole => 'Not mainly a mobile role',
  Blocker.tooSenior => 'Too senior for now',
  Blocker.locationNotAllowed => 'Location not possible for me',
  Blocker.noSponsorship => 'No visa sponsorship',
  Blocker.remoteRegionExcluded => 'Remote, but not open to my region',
  Blocker.unsupportedLanguage => 'Needs a language I don\'t speak',
  Blocker.mainFrameworkMissing => 'Main framework is not mine',
};

/// The whole answer for one job: score ring, verdict, summary, skills, details.
class ResultView extends StatelessWidget {
  const ResultView(this.evaluation, {super.key});

  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final a = evaluation.analysis;
    final r = evaluation.result;
    final color = verdictColor(r.verdict);
    final text = Theme.of(context).textTheme;

    List<Requirement> withMatch(Match m) =>
        a.requirements.where((req) => req.match == m).toList();
    final must = a.requirements.where((x) => x.type == RequirementType.must);
    final strongMust = must.where((x) => x.match == Match.strong).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Job title
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.title,
                style: text.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [a.company, a.location].where((s) => s.isNotEmpty).join(' · '),
                style: text.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Score ring + verdict
        _Section(
          child: Row(
            children: [
              _ScoreRing(score: r.score, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictLabel(r.verdict),
                      style: text.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$strongMust of ${must.length} must-have skills fully matched',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Blockers
        for (final b in a.blockers)
          _Banner(icon: Icons.block, color: _red, child: Text(blockerLabel(b))),

        // Short summary
        if (a.reasons.isNotEmpty)
          _Banner(
            icon: Icons.lightbulb_outline,
            color: _amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in a.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(reason),
                  ),
              ],
            ),
          ),

        // How to adapt my CV for this job
        if (a.cvTips.isNotEmpty)
          _Banner(
            icon: Icons.edit_note,
            color: _blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Improve your CV for this job',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                for (final tip in a.cvTips)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $tip'),
                  ),
              ],
            ),
          ),

        // Skills
        _SkillGroup(
          'Matched',
          withMatch(Match.strong),
          _green,
          Icons.check_circle,
        ),
        _SkillGroup('Partly', withMatch(Match.partial), _amber, Icons.adjust),
        _SkillGroup('Missing', withMatch(Match.missing), _red, Icons.cancel),

        // Cover letter (only for jobs worth applying to)
        if (r.verdict != Verdict.skip && evaluation.historyId != null)
          CoverLetterCard(
            key: ValueKey('cover-${evaluation.historyId}'),
            historyId: evaluation.historyId!,
            initialLetter: evaluation.coverLetter,
          ),

        // Details (closed by default)
        _Section(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: const Text('Details'),
            shape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.calculation, style: text.bodySmall),
              Text(
                'Can I work there: ${a.eligibility.name}',
                style: text.bodySmall,
              ),
              const Divider(height: 24),
              for (final req in a.requirements) _RequirementRow(req),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Text(
              '$score%',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup(this.title, this.items, this.color, this.icon);

  final String title;
  final List<Requirement> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${items.length})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final req in items)
                Tooltip(
                  message: req.evidence,
                  child: Chip(
                    avatar: Icon(icon, size: 18, color: color),
                    label: Text(
                      req.type == RequirementType.nice
                          ? '${req.name} (nice)'
                          : req.name,
                    ),
                    backgroundColor: color.withValues(alpha: 0.08),
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow(this.req);

  final Requirement req;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${req.name} · ${req.type.name.toUpperCase()} · '
            '${req.match.name.toUpperCase()}',
          ),
          if (req.evidence.isNotEmpty) Text(req.evidence, style: small),
        ],
      ),
    );
  }
}

/// White rounded block, like the cards in the reference designs.
class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.child});

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
