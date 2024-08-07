import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flangapp_pro/models/app_config.dart';
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


import '../config/config.dart';
import '../models/enum/action_type.dart';
import '../models/enum/load_indicator.dart';
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

  List<WebViewCollection> collection = [];
  int activePage = 0;
  bool isOffline = false;
  StreamSubscription<ConnectivityResult>? subscription;
  bool showNavigation = false;
  late HttpServer server;
  bool loggedIn = false;
  String currentPageUrl = '';
  String oldPageUrl = '';
  bool isPageLoadingInProgress = false;
  String platform = '';
  String chatConversationId = '';

  final urlController = TextEditingController();

  @override
  void initState() {
    settings.userAgent = widget.appConfig.customUserAgent;
    createCollection();
    createPullToRefresh();
    if (Config.oneSignalPushId.isNotEmpty) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(Config.oneSignalPushId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addClickListener((event) {
        // debugPrint("GEO-GEO-GEO-GEO-GEO-GEO - addClickListener()");
        var additionalData = event.notification.additionalData;
        if(additionalData != null && additionalData.containsKey('conversation_id')) {
          String conversationId = additionalData['conversation_id'];
          openChatPage(conversationId);
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
        appBar: widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.bar ? Navbar(
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
        body: SafeArea(
          // top: widget.appConfig.template == Template.blank,
          top: widget.appConfig.template == Template.blank || widget.appConfig.template == Template.tabs,
          child: !isOffline ? IndexedStack(
            index: activePage,
            children: [
              for (var i = 0; i < collection.length; i ++)
                webContainer(i),
            ],
          ) : OfflinePage(),
        ),
        drawer: widget.appConfig.template == Template.drawerBar ? AppDrawer(
          title: widget.appConfig.drawerTitle,
          subtitle: widget.appConfig.drawerSubtitle,
          backgroundMode: widget.appConfig.drawerBackgroundMode,
          backgroundColor: widget.appConfig.drawerBackgroundColor,
          isDark: widget.appConfig.drawerIsDark,
          backgroundImage: widget.appConfig.drawerBackgroundImage,
          logoImage: widget.appConfig.drawerLogoImage,
          isDisplayLogo: widget.appConfig.drawerIsDisplayLogo,
          actions: widget.appConfig.mainNavigation,
          iconColor: widget.appConfig.iconColor,
          onAction: (NavigationItem item) => navigationAction(item),
        ) : null,
        drawerEdgeDragWidth: 0,
        bottomNavigationBar: showNavigation == true && (widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) ? AppTabs(
          actions: widget.appConfig.mainNavigation,
          activeTab: activePage,
          onChange: (index) {

            //Reload the page on tab change if the config says so
            NavigationItem item = widget.appConfig.mainNavigation[index];
            if(item.refresh) {
              setState(() {
                isPageLoadingInProgress = true;
              });
              collection[index].controller!.loadUrl(
                  urlRequest: URLRequest(url: WebUri(item.value)));
            }
            setState(() {
              // Update bottom bar active page index
              activePage = index;

              oldPageUrl = currentPageUrl;
              // Update current page url used in the app_tabs to highlight or not the bottom menu item
              currentPageUrl = item.value;
            });
          },
          color: widget.appConfig.activeColor,
          currentPageUrl: currentPageUrl,
        ) : null,
      ),
    );
  }

  Widget webContainer(int index) {

    WebViewCollection currentItem = collection[index];
    return Stack(
      children: [

        Opacity(
            opacity: isPageLoadingInProgress ? 0 : 1,
            child:
            InAppWebView(
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

                  controller.addJavaScriptHandler(handlerName: 'chatHandler', callback: (args) async {

                    // debugPrint("GEO-GEO-GEO-GEO-GEO-GEO - chatHandler()");
                    String tempChatConversationId = chatConversationId;
                    chatConversationId = '';
                    // return data to the JavaScript side!
                    return {
                      'conversation_id': tempChatConversationId
                    };
                  });
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  //Do some checks here to decide if CANCELS or PROCEEDS
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
                // onLoadStart: (controller, url) {
                //   setState(() {
                //     isPageLoadingInProgress = true;
                //   });
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
                  currentItem.pullToRefreshController?.endRefreshing();
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

                  if(currentItem.isInit == true) {
                    // Check if the page we are navigating to is also in the bottom bar menu and get the index of that page
                    List<NavigationItem> items = widget.appConfig.mainNavigation;
                    int highlightedIndex = items.indexWhere((item) => item.value == navigationAction.request.url.toString());

                    setState(() {

                      oldPageUrl = currentPageUrl;
                      // Update current page url used in the app_tabs to highlight or not the bottom menu item
                      currentPageUrl = navigationAction.request.url.toString();

                      if (highlightedIndex >= 0 && highlightedIndex < items.length) {
                        // If the page we are navigating to is also an item in the bottom menu, then display that bottom menu page
                        activePage = highlightedIndex;

                        // If the page we are navigating to is also an item in the bottom menu, check if it needs to refresh or not
                        NavigationItem item = widget.appConfig.mainNavigation[activePage];
                        // if (item.refresh && item.value != currentPageUrl) {
                        if (item.refresh && oldPageUrl != currentPageUrl) {
                          setState(() {
                            isPageLoadingInProgress = true;
                          });
                          collection[activePage].controller!.loadUrl(
                              urlRequest: URLRequest(url: WebUri(item.value)));
                        }
                      }
                    });
                  } else {
                    currentItem.isInit = true;
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
                  currentItem.isError = false;
                });
              },
              color: widget.appConfig.color,
              email: widget.appConfig.email,
              image: widget.appConfig.errorBrowserImage,
              message: widget.appConfig.messageErrorBrowser,
              buttonBackLabel: widget.appConfig.backBtn,
              buttonContactLabel: widget.appConfig.contactBtn
          )
      ],
    );
  }

  void addRestOfCollectionItems() {
    if ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) && widget.appConfig.mainNavigation.length > 1) {
      List<NavigationItem> items = widget.appConfig.mainNavigation;

      for (var i = 1; i < items.length; i ++) {
        if (items[i].type == ActionType.internal) {
          collection.add(
              WebViewCollection(
                  url: items[i].value.toString(),
                  isLoading: true,
                  title: widget.appConfig.appName,
                  isCanBack: false,
                  progress: 0,
                  isError: false,
                  isInit: false,
              ));
        }
      }
    }
  }

  void removeRestOfCollectionItems() async {
    if ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) && collection.length > 1) {
      // Leave only the first page
      collection.removeRange(1, collection.length);
    }
  }

  void createCollection() {
    if ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) && widget.appConfig.mainNavigation.isNotEmpty) {
      List<NavigationItem> items = widget.appConfig.mainNavigation;

      collection = [
          if (items[0].type == ActionType.internal)
            WebViewCollection(
                url: items[0].value.toString(),
                isLoading: true,
                title: widget.appConfig.appName,
                isCanBack: false,
                progress: 0,
                isError: false,
                isInit: false,
            )
      ];
      //showNavigation = widget.appConfig.showNavigationAfterLogin; // TODO - implement showNavigationAfterLogin logic
    } else {
      collection = [
        WebViewCollection(
          url: widget.appConfig.appLink,
          isLoading: true,
          title: widget.appConfig.appName,
          isCanBack: false,
          progress: 0,
          isError: false,
          isInit: false,
        )
      ];
      //showNavigation = widget.appConfig.showNavigationAfterLogin;
    }
  }

  void addRestOfPullToRefreshItems() {
    if ((widget.appConfig.template == Template.tabsBar || widget.appConfig.template == Template.tabs) && widget.appConfig.mainNavigation.length > 1) {
      List<NavigationItem> items = widget.appConfig.mainNavigation;
      for (var i = 1; i < items.length; i ++) {
        if (items[i].type == ActionType.internal) {
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
    }
  }

  void createPullToRefresh() {
    if (widget.appConfig.template != Template.tabsBar &&
        widget.appConfig.template != Template.tabs) {
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
      return;
    }
    List<NavigationItem> items = widget.appConfig.mainNavigation;

    if (items.isNotEmpty && items[0].type == ActionType.internal) {
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

  startServer() async {
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

          if (userId == null || userId.isEmpty) {

            // Logout
            if(loggedIn == true) {

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
                removeRestOfCollectionItems();
              });

              loggedIn = false;
            }
          } else {
            // Login
            setState(() {
              if (loggedIn == false) {
                addRestOfCollectionItems();
                addRestOfPullToRefreshItems();
                showNavigation = true;
                loggedIn = true;
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

  openChatPage(String conversationId) {

      List<NavigationItem> items = widget.appConfig.mainNavigation;

      if (items != null) {
        int chatMenuIndex = items.indexWhere((item) => item.value.contains('inbox')); // TODO GEO - do better the hardcoded 'inbox' string

        if (chatMenuIndex >= 0 && chatMenuIndex < items.length) {
          oldPageUrl = currentPageUrl;
          // Update current page url used in the app_tabs to highlight or not the bottom menu item
          currentPageUrl = items[chatMenuIndex].value;

          chatConversationId = conversationId;

          setState(() {
          // If the page we are navigating to is also an item in the bottom menu, then display that bottom menu page
            activePage = chatMenuIndex;

            // If the page we are navigating to is also an item in the bottom menu, check if it needs to refresh or not
            NavigationItem item = widget.appConfig.mainNavigation[activePage];
            // if (item.refresh && item.value != currentPageUrl) {
            if (item.refresh && oldPageUrl != currentPageUrl) {
              setState(() {
                isPageLoadingInProgress = true;
              });
              collection[activePage].controller!.loadUrl(
                  urlRequest: URLRequest(url: WebUri(item.value)));
            }
          });
        }
      }
  }
}