
class Config {

  /// Generated by Flangapp PRO 14-08-2024 08:45
  /// App UID: 12d28d8a-5181-75a5-0797-13bcc85a9f5d
  /// Version: 1.0.3
  /// API server: https://mobilebuilderapi.bss-lab.it/

  /// *** Main settings *** ///
  static String apiUrl = "https://mobilebuilderapi.bss-lab.it/";
  static String appUid = "12d28d8a-5181-75a5-0797-13bcc85a9f5d";
  static String oneSignalPushId = "4e3e3745-fa23-40a8-9fc9-16d028021b25";

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