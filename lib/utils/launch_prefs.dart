import 'package:shared_preferences/shared_preferences.dart';

class LaunchPrefs {
  LaunchPrefs._();

  static const _introVideoSeenKey = 'intro_video_seen';

  static Future<bool> hasSeenIntroVideo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introVideoSeenKey) ?? false;
  }

  static Future<void> markIntroVideoSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introVideoSeenKey, true);
  }
}
