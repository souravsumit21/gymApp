import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

const _goalOptions = [
  ('muscle_gain', 'Build Muscle'),
  ('weight_loss', 'Lose Fat'),
  ('general_fitness', 'Stay Fit'),
  ('strength', 'Get Stronger'),
  ('endurance', 'Improve Endurance'),
];

const _experienceOptions = [
  ('beginner', 'Beginner'),
  ('intermediate', 'Intermediate'),
  ('advanced', 'Advanced'),
];

const _trainingTypeOptions = [
  ('strength', 'Strength'),
  ('cardio', 'Cardio'),
  ('flexibility', 'Flexibility'),
  ('mixed', 'Mixed'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _currentPage = 0;

  // Form state
  int _age = 25;
  String _gender = 'male';
  double _weightKg = 70;
  double _heightCm = 170;
  String? _primaryGoal;
  String _fitnessLevel = 'beginner';
  int _weeklyWorkoutDays = 3;
  int _preferredWorkoutMinutes = 30;
  String _trainingType = 'mixed';
  bool _isSaving = false;
  String? _stepError;

  final _pages = 5; // Total steps

  @override
  void initState() {
    super.initState();
    final displayName = ref.read(authServiceProvider).currentUser?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _nameController.text = displayName.trim();
    }
  }

  void _nextPage() {
    if (!_validateCurrentPage()) return;

    setState(() => _stepError = null);
    if (_currentPage < _pages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _stepError = null;
      _currentPage = page;
    });
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skipWorkoutPreference() {
    setState(() {
      _trainingType = 'mixed';
      _stepError = null;
    });
    _goToPage(4);
  }

  bool _validateCurrentPage() {
    String? message;
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      message = 'Add your name so we can personalize the app.';
    } else if (_currentPage == 1 && _primaryGoal == null) {
      message = 'Choose your primary goal to personalize your plan.';
    }

    if (message == null) return true;
    setState(() => _stepError = message);
    return false;
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isSaving = true;
      _stepError = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw AuthException('No signed-in user found.');
      }
      final existing = await authService.loadUserProfile(currentUser.uid);
      final profile = existing ??
          UserProfile(
            uid: currentUser.uid,
            email: currentUser.email ?? '',
            displayName: currentUser.displayName ?? 'Athlete',
            photoUrl: currentUser.photoURL,
            createdAt: DateTime.now(),
          );

      final updated = profile.copyWith(
        displayName: _nameController.text.trim(),
        age: _age,
        gender: _gender,
        weightKg: _weightKg,
        heightCm: _heightCm,
        fitnessLevel: _fitnessLevel,
        goals: _primaryGoal == null ? [] : [_primaryGoal!],
        primaryGoal: _primaryGoal,
        weeklyWorkoutDays: _weeklyWorkoutDays,
        preferredWorkoutMinutes: _preferredWorkoutMinutes,
        trainingLocation: 'home',
        trainingType: _trainingType,
        onboardingComplete: true,
      );
      await authService.updateProfile(updated);
      ref.invalidate(userProfileProvider(currentUser.uid));
      if (mounted) context.go('/workouts');
    } catch (e) {
      if (mounted) {
        setState(() => _stepError = 'Could not save your profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _prevPage,
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: AppTheme.textSecondary, size: 20),
                    ),
                  const Spacer(),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppTheme.primary,
                      dotColor: AppTheme.border,
                      dotHeight: 6,
                      dotWidth: 6,
                      expansionFactor: 4,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _AboutYouPage(
                    nameController: _nameController,
                    age: _age,
                    gender: _gender,
                    weightKg: _weightKg,
                    heightCm: _heightCm,
                    onAgeChanged: (v) => setState(() => _age = v),
                    onGenderChanged: (v) => setState(() => _gender = v),
                    onWeightChanged: (v) => setState(() => _weightKg = v),
                    onHeightChanged: (v) => setState(() => _heightCm = v),
                  ),
                  _ExperienceGoalPage(
                    fitnessLevel: _fitnessLevel,
                    primaryGoal: _primaryGoal,
                    onFitnessLevelChanged: (v) => setState(() => _fitnessLevel = v),
                    onPrimaryGoalChanged: (v) => setState(() => _primaryGoal = v),
                  ),
                  _SchedulePage(
                    weeklyWorkoutDays: _weeklyWorkoutDays,
                    preferredWorkoutMinutes: _preferredWorkoutMinutes,
                    onWeeklyWorkoutDaysChanged: (v) =>
                        setState(() => _weeklyWorkoutDays = v),
                    onPreferredWorkoutMinutesChanged: (v) =>
                        setState(() => _preferredWorkoutMinutes = v),
                  ),
                  _WorkoutPreferencePage(
                    trainingType: _trainingType,
                    onTrainingTypeChanged: (v) => setState(() => _trainingType = v),
                    onSkip: _skipWorkoutPreference,
                  ),
                  _ReviewPage(
                    name: _nameController.text.trim(),
                    age: _age,
                    gender: _gender,
                    weightKg: _weightKg,
                    heightCm: _heightCm,
                    primaryGoal: _primaryGoal,
                    fitnessLevel: _fitnessLevel,
                    weeklyWorkoutDays: _weeklyWorkoutDays,
                    preferredWorkoutMinutes: _preferredWorkoutMinutes,
                    trainingType: _trainingType,
                    onEdit: _goToPage,
                  ),
                ],
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  if (_stepError != null) ...[
                    Text(
                      _stepError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _isSaving ? null : _nextPage,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.background,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(_currentPage == _pages - 1
                            ? "Looks Good - Let's Go"
                            : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutYouPage extends StatelessWidget {
  final TextEditingController nameController;
  final int age;
  final String gender;
  final double weightKg;
  final double heightCm;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<double> onHeightChanged;

  const _AboutYouPage({
    required this.nameController,
    required this.age,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.onAgeChanged,
    required this.onGenderChanged,
    required this.onWeightChanged,
    required this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      header: _OnboardingHeader(
        emoji: '👋',
        title: 'About You',
        subtitle: 'A few basics help personalize your workout profile.',
      ),
      child: ListView(
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Name'),
          ),
          const SizedBox(height: 20),
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceWrap(
            selected: gender,
            options: const [
              ('male', 'Male'),
              ('female', 'Female'),
              ('other', 'Other'),
            ],
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 20),
          _PickerCard(
            label: 'Age',
            value: '$age years',
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: age - 15),
              itemExtent: 40,
              onSelectedItemChanged: (i) => onAgeChanged(i + 15),
              children: List.generate(66, (i) => Center(child: Text('${i + 15}'))),
            ),
          ),
          const SizedBox(height: 20),
          _NumberSlider(
            label: 'Height',
            value: heightCm,
            unit: 'cm',
            min: 130,
            max: 230,
            onChanged: onHeightChanged,
          ),
          const SizedBox(height: 20),
          _NumberSlider(
            label: 'Weight',
            value: weightKg,
            unit: 'kg',
            min: 30,
            max: 200,
            onChanged: onWeightChanged,
          ),
        ],
      ),
    );
  }
}

class _ExperienceGoalPage extends StatelessWidget {
  final String fitnessLevel;
  final String? primaryGoal;
  final ValueChanged<String> onFitnessLevelChanged;
  final ValueChanged<String> onPrimaryGoalChanged;

  const _ExperienceGoalPage({
    required this.fitnessLevel,
    required this.primaryGoal,
    required this.onFitnessLevelChanged,
    required this.onPrimaryGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      header: _OnboardingHeader(
        emoji: '🎯',
        title: 'Your Experience\n& Goal',
        subtitle: 'This guides plan intensity and exercise selection.',
      ),
      child: ListView(
        children: [
          Text('Experience level', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceColumn(
            selected: fitnessLevel,
            options: _experienceOptions,
            onChanged: onFitnessLevelChanged,
          ),
          const SizedBox(height: 24),
          Text('Primary goal', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceColumn(
            selected: primaryGoal,
            options: _goalOptions,
            onChanged: onPrimaryGoalChanged,
          ),
        ],
      ),
    );
  }
}

class _SchedulePage extends StatelessWidget {
  final int weeklyWorkoutDays;
  final int preferredWorkoutMinutes;
  final ValueChanged<int> onWeeklyWorkoutDaysChanged;
  final ValueChanged<int> onPreferredWorkoutMinutesChanged;

  const _SchedulePage({
    required this.weeklyWorkoutDays,
    required this.preferredWorkoutMinutes,
    required this.onWeeklyWorkoutDaysChanged,
    required this.onPreferredWorkoutMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      header: _OnboardingHeader(
        emoji: '📅',
        title: 'Your Schedule',
        subtitle: 'Your streak is based on hitting your weekly goal.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Days per week', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceWrap(
            selected: '$weeklyWorkoutDays',
            options: [for (var i = 2; i <= 7; i++) ('$i', '$i days')],
            onChanged: (v) => onWeeklyWorkoutDaysChanged(int.parse(v)),
          ),
          const SizedBox(height: 28),
          Text('Session duration', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceWrap(
            selected: '$preferredWorkoutMinutes',
            options: const [
              ('15', '15 min'),
              ('30', '30 min'),
              ('45', '45 min'),
              ('60', '60+ min'),
            ],
            onChanged: (v) => onPreferredWorkoutMinutesChanged(int.parse(v)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
            ),
            child: const Text(
              'Your streak is based on hitting your weekly goal.',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutPreferencePage extends StatelessWidget {
  final String trainingType;
  final ValueChanged<String> onTrainingTypeChanged;
  final VoidCallback onSkip;

  const _WorkoutPreferencePage({
    required this.trainingType,
    required this.onTrainingTypeChanged,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      header: _OnboardingHeader(
        emoji: '⚙️',
        title: 'Workout\nPreference',
        subtitle: 'Optional. Skip to use Mixed by default.',
      ),
      trailing: TextButton(
        onPressed: onSkip,
        child: const Text('Skip'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Training type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ChoiceColumn(
            selected: trainingType,
            options: _trainingTypeOptions,
            onChanged: onTrainingTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  final String name;
  final int age;
  final String gender;
  final double weightKg;
  final double heightCm;
  final String? primaryGoal;
  final String fitnessLevel;
  final int weeklyWorkoutDays;
  final int preferredWorkoutMinutes;
  final String trainingType;
  final ValueChanged<int> onEdit;

  const _ReviewPage({
    required this.name,
    required this.age,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.primaryGoal,
    required this.fitnessLevel,
    required this.weeklyWorkoutDays,
    required this.preferredWorkoutMinutes,
    required this.trainingType,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      header: _OnboardingHeader(
        emoji: '✅',
        title: 'Summary',
        subtitle: 'Tap any section to edit before entering the app.',
      ),
      child: ListView(
        children: [
          _SummaryCard(
            title: 'About You',
            pageIndex: 0,
            onEdit: onEdit,
            rows: [
              ('Name', name),
              ('Gender', _label(gender)),
              ('Age', '$age'),
              ('Height & Weight',
                  '${heightCm.toStringAsFixed(0)} cm, ${weightKg.toStringAsFixed(0)} kg'),
            ],
          ),
          _SummaryCard(
            title: 'Experience & Goal',
            pageIndex: 1,
            onEdit: onEdit,
            rows: [
              ('Experience', _label(fitnessLevel)),
              ('Primary goal', _label(primaryGoal ?? 'Not selected')),
            ],
          ),
          _SummaryCard(
            title: 'Schedule',
            pageIndex: 2,
            onEdit: onEdit,
            rows: [
              ('Days per week', '$weeklyWorkoutDays'),
              ('Session duration', '$preferredWorkoutMinutes min'),
            ],
          ),
          _SummaryCard(
            title: 'Workout Preference',
            pageIndex: 3,
            onEdit: onEdit,
            rows: [
              ('Training type', _label(trainingType)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int pageIndex;
  final List<(String, String)> rows;
  final ValueChanged<int> onEdit;

  const _SummaryCard({
    required this.title,
    required this.pageIndex,
    required this.rows,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onEdit(pageIndex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.$1,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Widget header;
  final Widget child;
  final Widget? trailing;

  const _OnboardingPage({
    required this.header,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing!),
          header,
          const SizedBox(height: 28),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ChoiceColumn extends StatelessWidget {
  final String? selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _ChoiceColumn({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              label: option.$2,
              selected: selected == option.$1,
              onTap: () => onChanged(option.$1),
            ),
          ),
      ],
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final String? selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _ChoiceWrap({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          _ChoicePill(
            label: option.$2,
            selected: selected == option.$1,
            onTap: () => onChanged(option.$1),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.12) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.12) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;

  const _PickerCard({
    required this.label,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 104,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _NumberSlider extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _NumberSlider({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(0)} $unit',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppTheme.textSecondary),
    filled: true,
    fillColor: AppTheme.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.primary),
    ),
  );
}

String _label(String value) => value
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

// ─────────────────────────────────────────────
// Shared header widget
// ─────────────────────────────────────────────
class _OnboardingHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _OnboardingHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}
