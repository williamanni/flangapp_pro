import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flangapp_pro/services/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons_named/ionicons_named.dart';
import '../models/enum/action_type.dart';
import '../models/navigation_item.dart';

class AppTabs extends StatefulWidget {

  final List<NavigationItem> actions;
  final int activeTab;
  final Function onChange;
  final String color;
  final String currentPageUrl;

  const AppTabs({
    super.key,
    required this.actions,
    required this.activeTab,
    required this.onChange,
    required this.color,
    required this.currentPageUrl,
  });

  @override
  State<AppTabs> createState() => _AppTabsState();

}

class _AppTabsState extends State<AppTabs> {

  @override
  Widget build(BuildContext context) {
    final List<NavigationItem> items = widget.actions;

    // Check if the current page displayed is also in the bottom bar menu and get the index of that page in order to highlight or not the bottom menu item
    int highlightedIndex = items.indexWhere((item) => item.value == widget.currentPageUrl);
    bool showHighlightedTab = highlightedIndex >= 0;

    return !Platform.isIOS ? BottomNavigationBar(
      currentIndex: widget.activeTab,
      selectedItemColor: showHighlightedTab ? HexColor.fromHex(widget.color) : Colors.grey.shade600,
      showUnselectedLabels: true,
      showSelectedLabels: true,
      type: BottomNavigationBarType.fixed,
      unselectedFontSize: 11,
      selectedFontSize: 11,
      unselectedLabelStyle: TextStyle(color: Colors.grey.shade600),
      onTap: (int index) => widget.onChange(index),
      items: [
        for (var i = 0; i < items.length; i ++)
          if (items[i].type == ActionType.internal)
            BottomNavigationBarItem(
              icon: Icon(ionicons[items[i].icon], size: 26),
              label: items[i].name,
            ),
      ],
    ) : CupertinoTabBar(
      items: [
        for (var i = 0; i < items.length; i ++)
          if (items[i].type == ActionType.internal)
            BottomNavigationBarItem(
              icon: Icon(ionicons[items[i].icon], size: 26),
              label: items[i].name,
            ),
      ],
      currentIndex: widget.activeTab,
      iconSize: 26,
      activeColor: showHighlightedTab ? HexColor.fromHex(widget.color) : Colors.grey.shade600,
      inactiveColor: Colors.grey.shade600,
      onTap: (int index) => widget.onChange(index),
    );
  }

}