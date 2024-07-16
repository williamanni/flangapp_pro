
class Config {

  /// Generated by Flangapp PRO 16-07-2024 10:51
  /// App UID: cb700bd8-0fbf-71fb-90c4-3588356e7a13
  /// Version: 1.0.11
  /// API server: https://mobilebuilderapi.bss-lab.it/

  /// *** Main settings *** ///
  static String apiUrl = "https://mobilebuilderapi.bss-lab.it/";
  static String appUid = "cb700bd8-0fbf-71fb-90c4-3588356e7a13";
  static String oneSignalPushId = "";

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
  static bool splashIsDisplayLogo = false;

  /// *** Offline localization settings *** ///
  static String offlineErrorMessage = "No internet connection";
  static String offlineImage = "dino.png";

  /// *** Subscribe need settings *** ///
  static String subscribeErrorTitle = "App not available";
  static String subscribeErrorMessage = "This app may have been removed or your administrator may need to renew your subscription";
}