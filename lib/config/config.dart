
class Config {

  /// Generated by Flangapp PRO 15-11-2024 09:18
  /// App UID: 3dc7472b-e14b-f0f0-9abb-75e3eed4c902
  /// Version: 1.0.0
  /// API server: https://mobilebuilderapi.bss-lab.it/

  /// *** Main settings *** ///
  static String apiUrl = "https://mobilebuilderapi.bss-lab.it/";
  static String appUid = "3dc7472b-e14b-f0f0-9abb-75e3eed4c902";
  static String oneSignalPushId = "b103dac4-2d66-4431-a5e2-144f8be21306";

  /// *** Splashscreen settings *** ///
  // Background color (any HEX color)
  static String splashBackgroundColor = "#1F6D58";
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