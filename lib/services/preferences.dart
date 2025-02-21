import 'package:shared_preferences/shared_preferences.dart';

 class Preferences {
   Preferences._(); // Private constructor to prevent instantiation
   static const String biometricsSkipKey = 'biometricsSkipKey';

   static Future<bool> getBiometricsSkipValue() async {
     final prefs = await SharedPreferences.getInstance();
     return prefs.getBool(biometricsSkipKey) ?? false;
   }

   static Future<void> setBiometricsSkipValue(bool? value) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setBool(biometricsSkipKey, value ?? false);
   }
 }