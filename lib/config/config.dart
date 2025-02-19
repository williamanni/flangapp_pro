
class Config {

  /// Generated by Flangapp PRO 19-02-2025 11:27
  /// App UID: 7cb0ba04-08a7-1157-81c5-0f4c1efa7048
  /// Version: 1.0.11
  /// API server: https://mobilebuilderapi.bss-lab.it/

  /// *** Main settings *** ///
  static String apiUrl = "https://mobilebuilderapi.bss-lab.it/";
  static String appUid = "7cb0ba04-08a7-1157-81c5-0f4c1efa7048";
  static String oneSignalPushId = "b96e4098-9fcb-4dcf-92fc-196df9304bb6";

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
  static int splashDelay = 3;
  // Logo image name
  static String splashLogoImage = "splash_logo.png";
  // Display logo
  static bool splashIsDisplayLogo = true;

  /// *** Offline localization settings *** ///
  static String offlineErrorMessage = "No internet connection";
  static String offlineImage = "dino.png";

  /// *** Subscribe need settings *** ///
  static String subscribeErrorTitle = "App not available";
  static String subscribeErrorMessage = "This app may have been removed or your administrator may need to renew your subscription";
}