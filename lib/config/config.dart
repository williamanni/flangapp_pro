
class Config {

  /// Generated by Flangapp PRO 20-02-2025 07:57
  /// App UID: cb700bd8-0fbf-71fb-90c4-3588356e7a13
  /// Version: 1.0.67
  /// API server: https://mobilebuilderapi.bss-lab.it/

  /// *** Main settings *** ///
  static String apiUrl = "https://mobilebuilderapi.bss-lab.it/";
  static String appUid = "cb700bd8-0fbf-71fb-90c4-3588356e7a13";
  static String oneSignalPushId = "f3efaa6e-cdc9-48cd-8758-7992a3559b7d";

  /// *** Splashscreen settings *** ///
  // Background color (any HEX color)
  static String splashBackgroundColor = "#3F51B5";
  // Text color (any HEX color)
  static String splashTextColor = "#ffffff";
  // Is image background
  static bool splashIsBackgroundImage = false;
  // Background image name
  static String splashBackgroundImage = "splash_screen.png";
  // Tagline
  static String splashTagline = "";
  // Delay display (seconds)
  static int splashDelay = 5;
  // Logo image name
  static String splashLogoImage = "splash_logo.png";
  // Display logo
  static bool splashIsDisplayLogo = false;

  /// *** Offline localization settings *** ///
  static String offlineErrorMessage = "No internet connection";
  static String offlineImage = "dino.png";

  /// *** Subscribe need settings *** ///
  static String subscribeErrorTitle = "App not available";
  static String subscribeErrorMessage = "This app may have been removed or your administrator may need to renew your subscription";
}