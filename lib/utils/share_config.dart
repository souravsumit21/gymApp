/// Deep link and app store configuration for external workout sharing.
class ShareConfig {
  static const String appName = 'Repp Up';
  static const String deepLinkBase = 'https://reppup.app';
  static const String termsUrl = '$deepLinkBase/terms';
  static const String privacyUrl = '$deepLinkBase/privacy';
  static const String appStoreUrl =
      'https://apps.apple.com/app/repp-up'; // placeholder
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.forgefit.forge_fit';

  static String workoutDeepLink(String shareId) => '$deepLinkBase/w/$shareId';

  static String communityDeepLink(String workoutId) =>
      '$deepLinkBase/c/$workoutId';
}
