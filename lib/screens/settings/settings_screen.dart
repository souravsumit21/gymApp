import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voice_cue_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<_VoiceSettingsData> _voiceDataFuture;
  List<TtsVoiceOption> _voices = [];
  TtsVoiceOption? _selectedVoice;
  TtsVoiceGender _selectedGender = TtsVoiceGender.female;

  @override
  void initState() {
    super.initState();
    _voiceDataFuture = _loadVoiceData();
  }

  Future<_VoiceSettingsData> _loadVoiceData() async {
    final voiceService = ref.read(voiceCueServiceProvider);
    final results = await Future.wait([
      voiceService.getAvailableVoices(),
      voiceService.getSelectedVoice(),
    ]);

    final voices = results[0] as List<TtsVoiceOption>;
    final selectedVoice = results[1] as TtsVoiceOption?;

    _voices = voices;
    _selectedVoice = selectedVoice;
    _selectedGender = selectedVoice?.gender ?? TtsVoiceGender.female;

    return _VoiceSettingsData(
      voices: voices,
      selectedVoice: selectedVoice,
    );
  }

  List<TtsVoiceOption> _voicesForGender(TtsVoiceGender gender) {
    return _voices.where((voice) => voice.gender == gender).toList();
  }

  Future<void> _openVoicePicker(TtsVoiceGender gender) async {
    final options = _voicesForGender(gender);
    if (options.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gender == TtsVoiceGender.male
                ? 'No male voices available on this device.'
                : 'No female voices available on this device.',
          ),
        ),
      );
      return;
    }

    final picked = await showDialog<TtsVoiceOption>(
      context: context,
      builder: (context) => _VoicePickerDialog(
        gender: gender,
        voices: options,
        selectedVoice: _selectedVoice,
        voiceService: ref.read(voiceCueServiceProvider),
      ),
    );

    if (!mounted || picked == null) return;

    await ref.read(voiceCueServiceProvider).setSelectedVoice(picked);
    setState(() {
      _selectedVoice = picked;
      _selectedGender = picked.gender;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voice set to ${picked.displayLabel}')),
    );
  }

  Future<void> _onGenderChanged(Set<TtsVoiceGender> selection) async {
    if (selection.isEmpty) return;
    final gender = selection.first;
    if (gender == _selectedGender) return;
    final previousGender = _selectedGender;
    setState(() => _selectedGender = gender);
    await _openVoicePicker(gender);
    if (!mounted) return;
    setState(() => _selectedGender = _selectedVoice?.gender ?? previousGender);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title:
            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
      ),
      body: FutureBuilder<_VoiceSettingsData>(
        future: _voiceDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: Text('Loading voices...'));
          }

          if (_voices.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No workout voices were found on this device.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
            );
          }

          final currentLabel = _selectedVoice?.displayLabel ?? 'Not set';
          final currentGenderLabel =
              _selectedVoice?.isMale == true ? 'Male' : 'Female';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _SettingsSection(
                title: 'Workout Voice',
                subtitle: 'Choose a male or female voice for workout cues.',
                children: [
                  SegmentedButton<TtsVoiceGender>(
                    segments: const [
                      ButtonSegment(
                        value: TtsVoiceGender.female,
                        label: Text('Female'),
                        icon: Icon(Icons.female_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: TtsVoiceGender.male,
                        label: Text('Male'),
                        icon: Icon(Icons.male_rounded, size: 18),
                      ),
                    ],
                    selected: {_selectedGender},
                    onSelectionChanged: _onGenderChanged,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      currentLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    subtitle: Text(
                      _selectedVoice == null
                          ? 'No voice selected'
                          : '$currentGenderLabel voice · tap to change',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openVoicePicker(_selectedGender),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VoicePickerDialog extends StatefulWidget {
  final TtsVoiceGender gender;
  final List<TtsVoiceOption> voices;
  final TtsVoiceOption? selectedVoice;
  final VoiceCueService voiceService;

  const _VoicePickerDialog({
    required this.gender,
    required this.voices,
    required this.selectedVoice,
    required this.voiceService,
  });

  @override
  State<_VoicePickerDialog> createState() => _VoicePickerDialogState();
}

class _VoicePickerDialogState extends State<_VoicePickerDialog> {
  TtsVoiceOption? _pendingVoice;
  String? _previewingVoiceName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.selectedVoice;
    if (current != null &&
        current.gender == widget.gender &&
        widget.voices.any((v) => v.isSameVoice(current))) {
      _pendingVoice = current;
    } else {
      _pendingVoice = widget.voices.first;
    }
  }

  Future<void> _preview(TtsVoiceOption voice) async {
    setState(() => _previewingVoiceName = voice.name);
    await widget.voiceService.previewVoice(voice);
    if (mounted) setState(() => _previewingVoiceName = null);
  }

  Future<void> _useVoice() async {
    final voice = _pendingVoice;
    if (voice == null || _saving) return;
    setState(() => _saving = true);
    if (mounted) Navigator.pop(context, voice);
  }

  @override
  Widget build(BuildContext context) {
    final genderLabel =
        widget.gender == TtsVoiceGender.male ? 'Male' : 'Female';

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Choose $genderLabel voice'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.voices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final voice = widget.voices[index];
            final selected = _pendingVoice?.isSameVoice(voice) ?? false;
            final previewing = _previewingVoiceName == voice.name;

            return InkWell(
              onTap: () => setState(() => _pendingVoice = voice),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.surfaceElevated : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color: selected ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        voice.displayLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Preview',
                      onPressed: previewing ? null : () => _preview(voice),
                      icon: Icon(
                        previewing
                            ? Icons.volume_up_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving || _pendingVoice == null ? null : _useVoice,
          child: Text(_saving ? 'Saving...' : 'Use voice'),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _VoiceSettingsData {
  final List<TtsVoiceOption> voices;
  final TtsVoiceOption? selectedVoice;

  const _VoiceSettingsData({
    required this.voices,
    required this.selectedVoice,
  });
}
