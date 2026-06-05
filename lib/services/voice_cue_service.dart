import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsVoiceGender { male, female }

class _VoiceProfile {
  final List<String> tokens;
  final String label;
  final TtsVoiceGender gender;

  const _VoiceProfile({
    required this.tokens,
    required this.label,
    required this.gender,
  });
}

class TtsVoiceOption {
  final String name;
  final String locale;

  const TtsVoiceOption({
    required this.name,
    required this.locale,
  });

  Map<String, String> get voiceMap => {'name': name, 'locale': locale};

  bool isSameVoice(TtsVoiceOption other) {
    return name == other.name && locale == other.locale;
  }

  String get displayLabel => _profileFor(this)?.label ?? _fallbackLabel;

  TtsVoiceGender get gender =>
      _profileFor(this)?.gender ?? TtsVoiceGender.female;

  bool get isMale => gender == TtsVoiceGender.male;

  String get _fallbackLabel => name
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('#', ' ')
      .trim();
}

class VoiceCueService {
  static const _voiceNameKey = 'tts_voice_name';
  static const _voiceLocaleKey = 'tts_voice_locale';
  static const _profiles = [
    _VoiceProfile(
      tokens: ['x', 'sfg', 'local'],
      label: 'SFG',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['x', 'iob', 'local'],
      label: 'IOB (Local)',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['x', 'iom', 'local'],
      label: 'IOM',
      gender: TtsVoiceGender.male,
    ),
    _VoiceProfile(
      tokens: ['us', 'x', 'msm000013', 'local'],
      label: 'MSM',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['x', 'iol', 'local'],
      label: 'IOL',
      gender: TtsVoiceGender.male,
    ),
    _VoiceProfile(
      tokens: ['x', 'iog', 'local'],
      label: 'IOG',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['x', 'tpc', 'network'],
      label: 'TPC (Network)',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['x', 'iob', 'network'],
      label: 'IOB (Network)',
      gender: TtsVoiceGender.female,
    ),
    _VoiceProfile(
      tokens: ['us', 'language'],
      label: 'US English',
      gender: TtsVoiceGender.female,
    ),
  ];

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _configureAudioSession();
    await _configurePreferredVoice();
    await _configureSpeech();
    _initialized = true;
  }

  Future<void> _configureAudioSession() async {
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
  }

  Future<void> _configureSpeech() async {
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
  }

  Future<void> _configurePreferredVoice() async {
    await _tts.setLanguage('en-US');

    try {
      final selectedVoice = await getSelectedVoice();
      if (selectedVoice != null) {
        await _tts.setVoice(selectedVoice.voiceMap);
        return;
      }

      final englishVoices = await getAvailableVoices();

      if (englishVoices.isEmpty) return;
      englishVoices.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
      await _tts.setVoice(englishVoices.first.voiceMap);
    } catch (_) {
      // Voice names vary by device. If discovery fails, keep the language fallback.
    }
  }

  Future<List<TtsVoiceOption>> getAvailableVoices() async {
    try {
      await _configureAudioSession();
      await _tts.setLanguage('en-US');
      final voices = await _tts.getVoices;
      if (voices is! List) return [];

      final englishVoices = voices
          .map(_voiceFromDynamic)
          .whereType<TtsVoiceOption>()
          .where((voice) {
        final locale = voice.locale.toLowerCase();
        return (locale == 'en-us' || locale == 'en_us') &&
            _isAllowedVoice(voice);
      }).toList();

      englishVoices.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
      return englishVoices;
    } catch (_) {
      return [];
    }
  }

  Future<TtsVoiceOption?> getSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_voiceNameKey);
    final locale = prefs.getString(_voiceLocaleKey);
    if (name == null || locale == null) return null;

    final voice = TtsVoiceOption(name: name, locale: locale);
    if (!_isAllowedVoice(voice)) return null;

    return voice;
  }

  Future<void> setSelectedVoice(TtsVoiceOption voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceNameKey, voice.name);
    await prefs.setString(_voiceLocaleKey, voice.locale);

    await _ensureInitialized();
    await _tts.setVoice(voice.voiceMap);
  }

  Future<void> previewVoice(TtsVoiceOption voice) async {
    await _ensureInitialized();
    await _tts.stop();
    await _tts.setVoice(voice.voiceMap);
    await _tts.speak("Welcome back, let's begin. Push ups");
  }

  TtsVoiceOption? _voiceFromDynamic(dynamic voice) {
    if (voice is! Map) return null;

    final name = voice['name']?.toString();
    final locale = (voice['locale'] ?? voice['language'])?.toString();
    if (name == null || locale == null) return null;

    return TtsVoiceOption(name: name, locale: locale);
  }

  int _voiceScore(TtsVoiceOption voice) {
    final name = voice.name.toLowerCase();
    var score = 0;

    if (name.contains('enhanced')) score += 5;
    if (name.contains('premium')) score += 5;
    if (name.contains('neural')) score += 5;
    if (name.contains('google')) score += 3;
    if (name.contains('ava')) score += 2;
    if (name.contains('samantha')) score += 2;
    if (name.contains('local')) score += 1;

    return score;
  }

  bool _isAllowedVoice(TtsVoiceOption voice) => _profileFor(voice) != null;

  Future<void> speak(String message) async {
    final cue = message.trim();
    if (cue.isEmpty) return;
    await _ensureInitialized();
    await _tts.stop();
    await _tts.speak(cue);
  }

  Future<void> announceExercise(String exerciseName) {
    return speak(exerciseName);
  }

  Future<void> announceWorkoutStart(String exerciseName) {
    return speak("Welcome back, let's begin. $exerciseName");
  }

  Future<void> announceBegin() {
    return speak('Begin');
  }

  Future<void> announceCountdown(int secondsLeft) {
    return speak('$secondsLeft');
  }

  Future<void> announceRest() {
    return speak('Rest');
  }

  Future<void> announceGetReady(String exerciseName) {
    return speak('Get ready for $exerciseName');
  }

  Future<void> stop() => _tts.stop();

  Future<void> pause() => stop();
}

final voiceCueServiceProvider = Provider<VoiceCueService>((ref) {
  final service = VoiceCueService();
  ref.onDispose(service.stop);
  return service;
});

_VoiceProfile? _profileFor(TtsVoiceOption voice) {
  final normalizedName = _normalizeVoiceName(voice.name);
  final nameTokens = normalizedName.split(' ');
  for (final profile in VoiceCueService._profiles) {
    if (profile.tokens.every(nameTokens.contains)) {
      return profile;
    }
  }
  return null;
}

String _normalizeVoiceName(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
