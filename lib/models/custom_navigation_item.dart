
import 'package:flangapp_pro/models/navigation_item.dart';

class CustomNavigationItem {
  final String tab;
  final String link;
  final List<NavigationItem> data;

  CustomNavigationItem({
    required this.tab,
    required this.link,
    required this.data,
  });
}