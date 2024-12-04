import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flangapp_pro/models/app_config.dart';
import 'package:flangapp_pro/models/custom_navigation_item.dart';
import 'package:flangapp_pro/services/hex_color.dart';
import 'package:flangapp_pro/widgets/app_drawer.dart';
import 'package:flangapp_pro/widgets/app_tabs.dart';
import 'package:flangapp_pro/widgets/error_page.dart';
import 'package:flangapp_pro/widgets/navbar.dart';
import 'package:flangapp_pro/widgets/offline_page.dart';
import 'package:flangapp_pro/widgets/progress_load.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:collection/collection.dart';

import '../config/config.dart';
import '../models/enum/action_type.dart';
import '../models/enum/load_indicator.dart';
import '../models/enum/navigation_type.dart';
import '../models/enum/template.dart';
import '../models/navigation_item.dart';
import '../models/web_view_collection.dart';

class WebViewer extends StatefulWidget {
  final AppConfig appConfig;

  const WebViewer({super.key, required this.appConfig});

  @override
  State<WebViewer> createState() => _WebViewerState();
}

class _WebViewerState extends State<WebViewer> {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  InAppWebViewSettings settings = InAppWebViewSettings(
    mediaPlaybackRequiresUserGesture: true,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    horizontalScrollBarEnabled: false,
    geolocationEnabled: true,
    allowFileAccessFromFileURLs: true,
    useOnDownloadStart: true,
  );

  List<WebViewCollection> collection = []; // WebViewCollection items for the bottom bar navigation
  int activePage = 0;
  bool isOffline = false;
  StreamSubscription<ConnectivityResult>? subscription;
  bool showNavigation = false;
  late HttpServer server;
  bool loggedIn = false;
  String currentPageUrl = '';
  String randomKeyPart = '';
  String oldPageUrl = '';
  bool isPageLoadingInProgress = false;
  String platform = '';
  String chatConversationId = '';
  List<NavigationItem> currentNavigationItems = []; // Current bottom bar navigation items. It can be from main nav, guest nav, custom nav...
  BottomBarNavigationType currentNavType = BottomBarNavigationType.unknown;
  List<String> pagesWithNavigation = [];
  List<String> pagesWithoutTopBar = [];

  final urlController = TextEditingController();

  @override
  void initState() {
    settings.userAgent = widget.appConfig.customUserAgent;

    if(widget.appConfig.showGuestNavigation == false) {
      // Create collection with the first item from main navigation items
      createGeneralCollection(widget.appConfig.mainNavigation.getRange(0, 1).toList(), BottomBarNavigationType.main);
    } else {
      isPageLoadingInProgress = true;
      createGeneralCollection(widget.appConfig.guestNavigation, BottomBarNavigationType.guest);
    }

    if (Config.oneSignalPushId.isNotEmpty) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(Config.oneSignalPushId);
      OneSignal.Notifications.requestPermission(true);
      // OneSignal.Notifications.addClickListener((event) {
      //   NotificationMessage? notification = getNotification(event.notification.additionalData);
      //     openPage(notification);
      // });
      OneSignal.Notifications.addClickListener((event) {
        var additionalData = event.notification.additionalData;
        if(additionalData != null && additionalData!.containsKey('url')) {
          String url = event.notification.additionalData!['url'];
          openPage(url);
        }
      });
    }

    super.initState();

    startServer();

    subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        setState(() {
          isOffline = true;
        });
      } else {
        setState(() {
          isOffline = false;
        });
      }
    });

    if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isMacOS) {
      platform = 'MacOS';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    } else if (Platform.isFuchsia) {
      platform = 'Fuchsia';
    } else {
      platform = 'Unknown';
    }
  }

  @override
  dispose() {
    subscription?.cancel();
    super.dispose();
    server.close();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        debugPrint("didPop1: $didPop");
        if (didPop) {
          return;
        }
        if (collection[activePage].isCanBack) {
          collection[activePage].controller?.goBack();
          return;
        }
        String? res = await showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(widget.appConfig.titleExit),
            content: Text(widget.appConfig.messageExit),
            backgroundColor: Colors.white,
            surfaceTintColor: HexColor.fromHex(widget.appConfig.color),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'YES'),
                child: Text(widget.appConfig.actionYesDownload, style: const TextStyle(
                    color: Colors.blueGrey
                )),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'NO'),
                child: Text(widget.appConfig.actionNoDownload, style: TextStyle(
                    color: HexColor.fromHex(widget.appConfig.color)
                ),),
              ),
            ],
          ),
        );
        if (res == 'NO') {
          return;
        }
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: true,
        // Top Bar
        appBar: ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.bar) && pagesWithoutTopBar.contains(currentPageUrl) == false) ? Navbar(
          background: widget.appConfig.color,
          isDark: widget.appConfig.isDark,
          title: widget.appConfig.displayTitle ? collection[activePage].title : widget.appConfig.appName,
          isCanBack: collection[activePage].isCanBack,
          isDrawer: widget.appConfig.template == Template.drawerBar,
          actions: widget.appConfig.barNavigation,
          onBack: () => collection[activePage].controller?.goBack(),
          onAction: (NavigationItem item) => navigationAction(item),
          onOpenDrawer: () => _scaffoldKey.currentState!.openDrawer(),
        ) : null,
        // Body area (the web views)
        body: SafeArea(
          // Top Safe Area for the templates without a Top Bar
          top: widget.appConfig.template == Template.blank || widget.appConfig.template == Template.tabs,
          child: !isOffline ? IndexedStack(
            index: activePage,
            children: [
              // Create the web view for teach item inside collection list
              for (var i = 0; i < collection.length; i ++)
                webContainer(i),
            ],
          ) : OfflinePage(),
        ),
        // Drawer
        drawer: widget.appConfig.template == Template.drawerBar ? AppDrawer(
          title: widget.appConfig.drawerTitle,
          subtitle: widget.appConfig.drawerSubtitle,
          backgroundMode: widget.appConfig.drawerBackgroundMode,
          backgroundColor: widget.appConfig.drawerBackgroundColor,
          isDark: widget.appConfig.drawerIsDark,
          backgroundImage: widget.appConfig.drawerBackgroundImage,
          logoImage: widget.appConfig.drawerLogoImage,
          isDisplayLogo: widget.appConfig.drawerIsDisplayLogo,
          actions: currentNavigationItems, // (widget.appConfig.showGuestNavigation == true && loggedIn == false) ? widget.appConfig.guestNavigation : widget.appConfig.mainNavigation,
          iconColor: widget.appConfig.iconColor,
          onAction: (NavigationItem item) => navigationAction(item),
        ) : null,
        drawerEdgeDragWidth: 0,
        // Bottom navigation bar
        bottomNavigationBar: showNavigation == true && (widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) ? AppTabs(
          actions: currentNavigationItems,
          activeTab: activePage,
          onChange: (index) {

            // Get the item the user clicked
            NavigationItem item = currentNavigationItems[index];

            // Check if we have a custom navigation for this page
            List<NavigationItem>? customNavItems = getCustomNavItem(item.value);

            Function eq = const ListEquality().equals;
            if(customNavItems != null) {
              // Custom navigation
              int customIndex = 0;
              setState(() {
                if(eq(currentNavigationItems, customNavItems) == false) {
                  // Create a new collection for the bottom bar navigation
                  createGeneralCollection(customNavItems, BottomBarNavigationType.custom);
                } else {
                  // We don't have a new collection, we are working with an existing collection
                  customIndex = index;// < currentNavigationItems.length ? index : 0;

                  // Check if the page needs to reload
                  if(item.refresh) {
                    isPageLoadingInProgress = true;
                    collection[index].controller!.loadUrl(
                        urlRequest: URLRequest(url: WebUri(item.value)));
                  }
                }

                // Set the active page. 0 for a newly created collection or the clicked index for an existing collection
                activePage = customIndex;

                oldPageUrl = currentPageUrl;
                // Update current page url used in the app_tabs to highlight or not the bottom menu item
                currentPageUrl = item.value;
              });
            } else {
              // No custom navigation. Main or guest

              if(currentNavType == BottomBarNavigationType.guest) {
                // If we are already on a guest navigation menu type, then just update the active page
                setState(() {
                  activePage = index;// < currentNavigationItems.length ? index : 0;

                  if(item.refresh) {
                    isPageLoadingInProgress = true;
                    collection[index].controller!.loadUrl(
                        urlRequest: URLRequest(url: WebUri(item.value)));
                  }

                  oldPageUrl = currentPageUrl;
                  // Update current page url used in the app_tabs to highlight or not the bottom menu item
                  currentPageUrl = item.value;
                });
              } else {
                // Main navigation type
                if(eq(currentNavigationItems, widget.appConfig.mainNavigation) == false) {
                  // Current navigation items are not main. Then create the main navigation collection and set active page to 0
                  setState(() {
                    createGeneralCollection(widget.appConfig.mainNavigation, BottomBarNavigationType.main);
                    activePage = 0;

                    if(item.refresh) {
                      isPageLoadingInProgress = true;
                      collection[index].controller!.loadUrl(
                          urlRequest: URLRequest(url: WebUri(item.value)));
                    }

                    oldPageUrl = currentPageUrl;
                    // Update current page url used in the app_tabs to highlight or not the bottom menu item
                    currentPageUrl = item.value;
                  });
                } else {
                  // If we are already on a main navigation menu type, then just update the active page
                  setState(() {
                    activePage = index;// < currentNavigationItems.length ? index : 0;

                    if(item.refresh) {
                      isPageLoadingInProgress = true;
                      collection[index].controller!.loadUrl(
                          urlRequest: URLRequest(url: WebUri(item.value)));
                    }

                    oldPageUrl = currentPageUrl;
                    // Update current page url used in the app_tabs to highlight or not the bottom menu item
                    currentPageUrl = item.value;
                  });
                }
              }

              // Check if the page needs to reload
              // if(item.refresh) {
              //   setState(() {
              //     isPageLoadingInProgress = true;
              //     collection[index].controller!.loadUrl(
              //         urlRequest: URLRequest(url: WebUri(item.value)));
              //   });
              // }
            }

            // setState(() {
            //   oldPageUrl = currentPageUrl;
            //   // Update current page url used in the app_tabs to highlight or not the bottom menu item
            //   currentPageUrl = item.value;
            // });
          },
          color: widget.appConfig.activeColor,
          currentPageUrl: currentPageUrl,
        ) : null,
      ),
    );
  }

  List<NavigationItem>? getCustomNavItem (String link) {
    // Check for the link in the main navigation item
    CustomNavigationItem? item = widget.appConfig.customNavigation.firstWhereOrNull((element) => element.link == link);
    if(item != null) {
      return item.data;
    } else {
      // Search for the link inside navigation item data
      for (int i = 0; i < widget.appConfig.customNavigation.length; i++) {
        NavigationItem? navItem = widget.appConfig.customNavigation[i].data.firstWhereOrNull((element) => element.value == link);
        if(navItem != null) {
          return widget.appConfig.customNavigation[i].data;
        }
      }
    }

    return null;
  }

  Widget webContainer(int index) {

    WebViewCollection currentItem = collection[index];
    return Stack(
      children: [

        Opacity(
            opacity: isPageLoadingInProgress ? 0 : 1,
            child:
            InAppWebView(
                key: ValueKey(currentItem.url + randomKeyPart),
                initialUrlRequest: URLRequest(url: WebUri(currentItem.url)),
                initialSettings: settings,
                pullToRefreshController: widget.appConfig.pullToRefreshEnabled
                    ? currentItem.pullToRefreshController
                    : null,
                onWebViewCreated: (controller) {

                  currentItem.controller = controller;
                  controller.addJavaScriptHandler(handlerName: 'pushNotificationsHandler', callback: (args) async {

                    String? pushId = OneSignal.User.pushSubscription.id;
                    String? pushToken = OneSignal.User.pushSubscription.token;

                    // String? oneSignalId = await OneSignal.User.getOnesignalId();
                    // String? externalId = await OneSignal.User.getExternalId();

                    // return data to the JavaScript side!
                    return {
                      'appId': Config.appUid, 'pushToken': pushToken, 'oneSignalUserId': pushId, 'platform': platform
                    };
                  });

                  // controller.addJavaScriptHandler(handlerName: 'chatHandler', callback: (args) async {
                  //
                  //   String tempChatConversationId = chatConversationId;
                  //   chatConversationId = '';
                  //   // return data to the JavaScript side!
                  //   return {
                  //     'id': tempChatConversationId
                  //   };
                  // });
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  //Do some checks here to decide if CANCELS or PROCEEDS
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
                // onLoadStart: (controller, url) {
                // },
                onProgressChanged: (controller, progress) {

                  injectCss(currentItem);
                  if (progress == 100) {
                    currentItem.pullToRefreshController?.endRefreshing();
                    // setState(() {
                    //   isPageLoadingInProgress = false;
                    // });
                  }
                  setState(() {
                    currentItem.progress = progress / 100;
                  });
                  controller.getTitle().then((value) {
                    if (value != null) {
                      setState(() {
                        currentItem.title = value;
                      });
                    }
                  });
                },
                onLoadStop: (controller, url) async {
                  currentItem.firstPageLoaded = true;
                  currentItem.pullToRefreshController?.endRefreshing();

                  if(pagesWithNavigation.contains(url.toString())) {
                    setState(() {
                      showNavigation = true;
                    });
                  }

                  setState(() {
                    currentItem.progress = 1;
                    isPageLoadingInProgress = false;
                  });
                  controller.canGoBack().then((value) {
                    setState(() {
                      currentItem.isCanBack = value;
                    });
                  });
                },
                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                  debugPrint("UPDATE HISTORY");
                  controller.canGoBack().then((value) {
                    debugPrint("NEW VALUE $value");
                    setState(() {
                      currentItem.isCanBack = value;
                    });
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {

                  // On Android the shouldOverrideUrlLoading callback is not called as many times as on iOS, so this condition is not required
                  if (defaultTargetPlatform == TargetPlatform.android) {
                    currentItem.isInit = true;
                  }

                  bool isCustomNavigation = false;

                  if(currentItem.isInit == true) {
                    // Check if we have to display the Guest navigation (user not logged in)
                    if(widget.appConfig.showGuestNavigation == true && loggedIn == false) {
                      currentNavigationItems = widget.appConfig.guestNavigation;
                    } else {
                      // Check if we have a custom navigation for this page or we have to display the main navigation
                      List<NavigationItem>? customNavItems = getCustomNavItem(navigationAction.request.url.toString());

                      Function eq = const ListEquality().equals;

                      if(customNavItems != null) {
                        // Custom navigation
                        if(eq(currentNavigationItems, customNavItems) == false) {
                          // Create a new collection for the bottom bar navigation
                          createGeneralCollection(customNavItems, BottomBarNavigationType.custom);
                        }

                        isCustomNavigation = true;
                      } else {
                        if(currentNavType != BottomBarNavigationType.main) {
                          // Main navigation type
                          createGeneralCollection(widget.appConfig.mainNavigation, BottomBarNavigationType.main);
                        }
                      }
                    }

                    // Check if the page we are navigating to is also in the bottom bar menu and get the index of that page
                    int highlightedIndex = currentNavigationItems.indexWhere((item) => item.value == navigationAction.request.url.toString());

                    setState(() {

                      oldPageUrl = currentPageUrl;
                      // Update current page url used in the app_tabs to highlight or not the bottom menu item
                      currentPageUrl = navigationAction.request.url.toString();

                      if (highlightedIndex >= 0 && highlightedIndex < currentNavigationItems.length) {
                        // If the page we are navigating to is also an item in the bottom menu, then display that bottom menu page
                        activePage = highlightedIndex;

                        // If the page we are navigating to is also an item in the bottom menu, check if it needs to refresh or not
                        NavigationItem item = currentNavigationItems[activePage];
                        if (item.refresh && oldPageUrl != currentPageUrl) {
                            isPageLoadingInProgress = true;
                            collection[activePage].controller!.loadUrl(
                                urlRequest: URLRequest(url: WebUri(item.value)));
                        }
                      }
                    });
                  } else {
                    currentItem.isInit = true;
                  }

                  if(isCustomNavigation) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                    final shouldPerformDownload =
                        navigationAction.shouldPerformDownload ?? false;
                    final url = navigationAction.request.url;
                    if (shouldPerformDownload && url != null) {
                      return NavigationActionPolicy.DOWNLOAD;
                    }
                  }
                  var uri = navigationAction.request.url!;

                  if (![
                    "http",
                    "https",
                    "file",
                    "chrome",
                    "data",
                    "javascript",
                    "about"
                  ].contains(uri.scheme)) {
                    if (await canLaunchUrl(uri)) {
                      // Launch the App
                      await launchUrl(
                        uri,
                      );
                      // and cancel the request
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onGeolocationPermissionsShowPrompt: (InAppWebViewController controller, String origin) async {
                  if (widget.appConfig.gpsEnabled) {
                    await Permission.location.request();
                    return GeolocationPermissionShowPromptResponse(
                        origin: origin,
                        allow: true,
                        retain: true
                    );
                  }
                },
                onPermissionRequest: (controller, request) async {
                  for (var i = 0; i < request.resources.length; i ++) {
                    if (request.resources[i].toString().contains("MICROPHONE")) {
                      if (widget.appConfig.microphoneEnabled) {
                        await Permission.microphone.request();
                      }
                    }
                    if (request.resources[i].toString().contains("CAMERA")) {
                      if (widget.appConfig.cameraEnabled) {
                        await Permission.camera.request();
                      }
                    }
                  }
                  return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT);
                },
                onDownloadStartRequest: (controller, downloadStartRequest) async {
                  launchUrl(Uri.parse(downloadStartRequest.url.toString()), mode: LaunchMode.externalApplication);
                },
                onReceivedHttpError: (controller, request, errorResponse) async {
                  currentItem.pullToRefreshController?.endRefreshing();
                  var isForMainFrame = request.isForMainFrame ?? false;
                  if (!isForMainFrame) {
                    return;
                  }
                  final snackBar = SnackBar(
                    content: Text(
                        'HTTP: ${request.url}: ${errorResponse.statusCode} ${errorResponse.reasonPhrase ?? ''}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  setState(() {
                    currentItem.isError = true;
                  });
                },
                onReceivedError: (controller, request, error) async {
                  currentItem.pullToRefreshController?.endRefreshing();
                  var isForMainFrame = request.isForMainFrame ?? false;
                  if (!isForMainFrame ||
                      (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS &&
                          error.type == WebResourceErrorType.CANCELLED)) {
                    return;
                  }
                  setState(() {
                    currentItem.isError = true;
                  });
                }
            )
        ),

        if (currentItem.progress < 1 && widget.appConfig.indicator != LoadIndicator.none)
          ProgressLoad(
              value: currentItem.progress,
              color: widget.appConfig.indicatorColor,
              type: widget.appConfig.indicator
          ),
        if (currentItem.isError)
          ErrorPage(
              onBack: () {
                setState(() {
                  collection[activePage].controller?.goBack();
                  isPageLoadingInProgress = true;

                  collection[activePage].controller!.loadUrl(
                      urlRequest: URLRequest(url: WebUri(collection[activePage].url)));
                  currentItem.isError = false;
                });
              },
              color: widget.appConfig.color,
              email: widget.appConfig.email,
              //image: widget.appConfig.errorBrowserImage,
              message: widget.appConfig.messageErrorBrowser,
              buttonBackLabel: widget.appConfig.backBtn,
              buttonContactLabel: widget.appConfig.contactBtn
          )
      ],
    );
  }

  void createGeneralCollection(List<NavigationItem> navigation, BottomBarNavigationType barNavType) {
    randomKeyPart = DateTime.now().millisecondsSinceEpoch.toString();
    if ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) && navigation.isNotEmpty) {

      currentNavType = barNavType;
      currentNavigationItems = navigation;

      collection = [];
        for (var i = 0; i < currentNavigationItems.length; i ++) {
          if (currentNavigationItems[i].type == ActionType.internal) {

            // Add the collection items
            collection.add(WebViewCollection(
                url: currentNavigationItems[i].value.toString(),
                isLoading: true,
                title: widget.appConfig.appName,
                isCanBack: false,
                progress: 0,
                isError: false,
                isInit: false,
                firstPageLoaded: false
            ));

            // Create pull to refresh controller for the collection items
            collection[i].pullToRefreshController = PullToRefreshController(
              settings: PullToRefreshSettings(
                color: Colors.grey,
              ),
              onRefresh: () async {
                if (defaultTargetPlatform == TargetPlatform.android) {
                  collection[i].controller?.reload();
                } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                  collection[i].controller?.loadUrl(
                      urlRequest:
                      URLRequest(url: await collection[i].controller?.getUrl()));
                }
              },
            );
          }
        }
    } else {
      // Create the single collection item
      collection = [
        WebViewCollection(
          url: widget.appConfig.appLink,
          isLoading: true,
          title: widget.appConfig.appName,
          isCanBack: false,
          progress: 0,
          isError: false,
          isInit: false,
          firstPageLoaded: false,
        )
      ];

      // Create pull to refresh controller for the single collection item
      collection[0].pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: Colors.grey,
        ),
        onRefresh: () async {
          if (defaultTargetPlatform == TargetPlatform.android) {
            collection[0].controller?.reload();
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            collection[0].controller?.loadUrl(
                urlRequest:
                URLRequest(url: await collection[0].controller?.getUrl()));
          }
        },
      );

      //showNavigation = widget.appConfig.showNavigationAfterLogin;
    }
  }

  void injectCss(WebViewCollection item) {
    String styles = "";
    for (var item in widget.appConfig.cssHideBlock) {
      styles = "$styles$item{ display: none; }";
    }
    item.controller?.injectCSSCode(
        source: styles
    );
  }

  void navigationAction(NavigationItem item) async {
    if (item.type == ActionType.internal) {
      setState(() {
        isPageLoadingInProgress = true;
      });
      collection[activePage].controller?.loadUrl(
          urlRequest: URLRequest(url: WebUri(item.value))
      );
    } else if (item.type == ActionType.external) {
      WebUri uri = WebUri(item.value);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else if (item.type == ActionType.email) {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: item.value,
      );
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } else if (item.type == ActionType.phone) {
      final Uri phoneLaunchUri = Uri(
        scheme: 'tel',
        path: item.value,
      );
      if (await canLaunchUrl(phoneLaunchUri)) {
        await launchUrl(phoneLaunchUri);
      }
    } else if (item.type == ActionType.share) {
      collection[activePage].controller?.getUrl().then((url) {
        Share.share(
            "${url.toString()} ${widget.appConfig.displayTitle
                ? collection[activePage].title
                : widget.appConfig.appName}"
        );
      });
    }
  }

  void startServer() async {
    try {
      ByteData chain = await rootBundle.load('assets/certificates/domain.crt');
      ByteData key = await rootBundle.load('assets/certificates/domain.key');

      var securityContext = SecurityContext();
      securityContext.useCertificateChainBytes(chain.buffer.asUint8List());
      securityContext.usePrivateKeyBytes(key.buffer.asUint8List());

      server = await HttpServer.bindSecure(
          InternetAddress.anyIPv6, 4200, securityContext);

      await for (var request in server) {
        String url = request.uri.toString();
        if (url.contains('auth')) {
          String? userId = request.uri.queryParameters['id'];
          String? showBottomMenuValue = request.uri.queryParameters['show_menu'];
          String? showTopBarValue = request.uri.queryParameters['show_top_bar'];

          bool showMenu = true;
          if(showBottomMenuValue != null && showBottomMenuValue?.toLowerCase() == 'false') {
            showMenu = false;
          }

          if(showTopBarValue != null && showTopBarValue?.toLowerCase() == 'false') {
            if(pagesWithoutTopBar.contains(currentPageUrl) == false) {
              pagesWithoutTopBar.add(currentPageUrl);
            }
          }

          if (userId == null || userId.isEmpty) {
            setState(() {
              isPageLoadingInProgress = false;
            });
            // Logout
            if(loggedIn == true) {
              if(widget.appConfig.showGuestNavigation) {
                setState(() {
                  createGeneralCollection(widget.appConfig.guestNavigation, BottomBarNavigationType.guest);
                  activePage = 0;
                  showNavigation = true;
                });
              } else {
                //Reload first page to show the login page because the user can log out from different page
                List<NavigationItem> items = widget.appConfig.mainNavigation;
                setState(() {
                  isPageLoadingInProgress = true;
                });
                collection[0].controller!.loadUrl(urlRequest: URLRequest(url: WebUri(items[0].value)));

                // hide navigation tabs
                setState(() {
                  activePage = 0;
                  showNavigation = false;
                  createGeneralCollection(widget.appConfig.mainNavigation.getRange(0, 1).toList(), BottomBarNavigationType.main);
                });
              }

              loggedIn = false;
            } else {
              if(widget.appConfig.showGuestNavigation) {
                setState(() {
                  showNavigation = true;
                });
              }
            }
          } else {
            // Login
            setState(() {

              if (loggedIn == false) {
                createGeneralCollection(widget.appConfig.mainNavigation, BottomBarNavigationType.main);

                isPageLoadingInProgress = false;
                showNavigation = true;
                loggedIn = true;
              } else {
                isPageLoadingInProgress = false;
              }

              if(showMenu == false) {
                showNavigation = false;
              }

              if(showNavigation == true) {
                if(pagesWithNavigation.contains(currentPageUrl) == false) {
                  pagesWithNavigation.add(currentPageUrl);
                }
              }
            });
          }
        }
      }
    }
    catch (exception, stacktrace) {
      debugPrint(exception.toString());
    }
  }

  void openPage(String url) async {
    List<NavigationItem> items = widget.appConfig.mainNavigation;

    if (items != null) {
      int pageMenuIndex = items.indexWhere((item) => url.startsWith(item.value));

      if(pageMenuIndex == -1) {
        for (var i = 0; i < 10; i ++) {
          if(collection[activePage].firstPageLoaded == false) {
            await Future.delayed(Duration(seconds: 1));
          }
          else {
            break;
          }
        }

        oldPageUrl = currentPageUrl;
        // Update current page url used in the app_tabs to highlight or not the bottom menu item
        currentPageUrl = url;

        setState(() {
          //activePage = pageMenuIndex;
          setState(() {
            isPageLoadingInProgress = true;
          });

          collection[activePage].controller!.loadUrl(
              urlRequest: URLRequest(url: WebUri(url)));
        });
      }
      else if (pageMenuIndex >= 0 && pageMenuIndex < items.length) {
        for (var i = 0; i < 10; i ++) {
          if(pageMenuIndex >= collection.length) {
            await Future.delayed(Duration(seconds: 1));
          }
          else {
            break;
          }
        }

        for (var i = 0; i < 10; i ++) {
          if(collection[pageMenuIndex].firstPageLoaded == false) {
            await Future.delayed(Duration(seconds: 1));
          }
          else {
            break;
          }
        }

        oldPageUrl = currentPageUrl;
        // Update current page url used in the app_tabs to highlight or not the bottom menu item
        currentPageUrl = items[pageMenuIndex].value;

        setState(() {
          //activePage = pageMenuIndex;
          setState(() {
            isPageLoadingInProgress = true;
          });

          collection[0].controller!.loadUrl(
              urlRequest: URLRequest(url: WebUri(url)));
        });
      }
    }
  }
}