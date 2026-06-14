// lib/screens/library/exercise_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/exercise_media.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_media_widget.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final LibraryExercise exercise;
  final bool showAddButton;
  final VoidCallback? onAdd;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.showAddButton = false,
    this.onAdd,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  bool _showGif = true; // Toggle GIF vs static

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final hasGif = ex.media?.gifUrl != null;
    final hasVideo = ex.media?.videoUrl != null &&
        ex.media?.primaryType == MediaType.video;
    final hasMedia = ex.media?.videoUrl != null ||
        ex.media?.gifUrl != null ||
        ex.media?.thumbnailUrl != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Media header
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 280,
            pinned: true,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: AppTheme.textPrimary, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Media
                  if (hasMedia)
                    SizedBox.expand(
                      child: ExerciseMediaWidget(
                        media: hasGif && !_showGif
                            ? ExerciseMedia(
                                exerciseId: ex.media!.exerciseId,
                                primaryType: MediaType.image,
                                thumbnailUrl: ex.media!.thumbnailUrl,
                                gifUrl: ex.media!.gifUrl,
                              )
                            : ex.media,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppTheme.surfaceElevated,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surfaceElevated,
                      child: const Center(
                        child: Icon(Icons.fitness_center_rounded,
                            color: AppTheme.textMuted, size: 56),
                      ),
                    ),

                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.background,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // GIF/Static toggle (legacy GIF exercises only)
                  if (hasGif && !hasVideo)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _showGif = !_showGif),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.background.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showGif
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                color: AppTheme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showGif ? 'Pause GIF' : 'Play GIF',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: AppTheme.textLabel,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ex.name,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DifficultyBadge(difficulty: ex.difficulty),
                    ],
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 8),

                  // Category + muscles
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TagChip(
                        label: ex.category,
                        color: AppTheme.accentYellow,
                      ),
                      for (final m in ex.muscleGroups)
                        _TagChip(label: m, color: AppTheme.primary),
                      for (final m in ex.secondaryMuscles)
                        _TagChip(
                          label: m,
                          color: AppTheme.textMuted,
                          secondary: true,
                        ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 20),

                  // Default sets/reps
                  _InfoRow(
                    items: [
                      ('Sets', '${ex.defaultSets}'),
                      if (ex.isTimeBased)
                        ('Duration', '${ex.defaultSeconds}s')
                      else
                        ('Reps', '${ex.defaultReps ?? '—'}'),
                      ('Rest', '${ex.restSeconds}s'),
                    ],
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 24),

                  // Description
                  _Section(
                    title: 'About',
                    child: Text(
                      ex.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 20),

                  // Instructions
                  _Section(
                    title: 'How to perform',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ex.instructions
                          .split('\n')
                          .where((line) => line.isNotEmpty)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) => _InstructionStep(
                                step: entry.key + 1,
                                text: entry.value
                                    .replaceAll(RegExp(r'^\d+\.\s*'), ''),
                              ))
                          .toList(),
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  // Tips (if any)
                  if (ex.tips.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Section(
                      title: '💡 Coaching Tips',
                      child: Column(
                        children: ex.tips
                            .map((tip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('•  ',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                          )),
                                      Expanded(
                                        child: Text(
                                          tip,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: AppTheme.textLabel,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],

                  // Equipment required
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Equipment needed',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ex.requiredEquipment
                          .map((e) => _TagChip(
                                label: e == 'none' ? '🙌 No equipment' : e,
                                color: AppTheme.textSecondary,
                              ))
                          .toList(),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  if (ex.metValue != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Text('🔥', style: TextStyle(fontSize: AppTheme.textIcon)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calorie burn estimate',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: AppTheme.textLabel,
                                  )),
                              Text(
                                '~${(ex.metValue! * 3.5 * 70 / 200).toStringAsFixed(0)} kcal per set (70kg)',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppTheme.textLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // Floating add button
      bottomNavigationBar: widget.showAddButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: ElevatedButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add to Workout'),
                ),
              ),
            )
          : null,
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  Color get _color {
    switch (difficulty) {
      case 'beginner': return const Color(0xFF4DFFB4);
      case 'intermediate': return const Color(0xFFFFD74D);
      case 'advanced': return AppTheme.accent;
      default: return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        difficulty[0].toUpperCase() + difficulty.substring(1),
        style: TextStyle(
          color: _color,
          fontSize: AppTheme.textLabel,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool secondary;

  const _TagChip({
    required this.label,
    required this.color,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: secondary ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: secondary ? AppTheme.border : color.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: secondary ? AppTheme.textMuted : color,
          fontSize: AppTheme.textLabel,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<(String, String)> items;
  const _InfoRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items
            .map((item) => Column(
                  children: [
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: AppTheme.textLabel,
                      ),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int step;
  final String text;

  const _InstructionStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: AppTheme.textLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.textLabel,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
