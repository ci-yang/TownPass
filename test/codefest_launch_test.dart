import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/config/codefest.dart';
import 'package:town_pass/page/city_service/model/my_service_model.dart';
import 'package:town_pass/page/city_service/widget/pinned_service_item_widget.dart';
import 'package:town_pass/page/city_service/widget/pinned_service_widget_controller.dart';
import 'package:town_pass/page/codefest/codefest_view.dart';
import 'package:town_pass/page/home/home_view.dart';
import 'package:town_pass/page/home/widget/activity_info/activity_banner_widget_controller.dart';
import 'package:town_pass/page/home/widget/news/news_banner_widget_controller.dart';
import 'package:town_pass/page/main/main_view.dart';
import 'package:town_pass/page/main/main_view_controller.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/service/subscription_service.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_web_view.dart';

class _WebViewPlatform extends InAppWebViewPlatform {
  final creations = <PlatformInAppWebViewWidgetCreationParams>[];

  PlatformInAppWebViewWidgetCreationParams get creation => creations.last;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    creations.add(params);
    return _WebViewWidget(params);
  }

  @override
  PlatformWebMessageListener createPlatformWebMessageListener(
    PlatformWebMessageListenerCreationParams params,
  ) => _MessageListener(params);
}

class _MessageListener extends PlatformWebMessageListener {
  _MessageListener(super.params) : super.implementation();
}

class _WebViewWidget extends PlatformInAppWebViewWidget {
  _WebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      InAppWebViewController.fromPlatform(platform: controller) as T;

  @override
  void dispose() {}
}

class _Controller extends PlatformInAppWebViewController {
  _Controller()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'test'),
      );

  final listenerReady = Completer<void>();
  final events = <String>[];
  bool hasHistory = false;
  bool failLoad = false;

  @override
  Future<void> addWebMessageListener(
    PlatformWebMessageListener listener,
  ) async {
    events.add('listener:${listener.jsObjectName}');
    await listenerReady.future;
    events.add('listener-ready');
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    events.add('load:${urlRequest.url}');
    if (failLoad) throw StateError('Load failed');
  }

  @override
  Future<bool> canGoBack() async => hasHistory;

  @override
  Future<void> goBack() async => events.add('back');
}

// Keep unrelated home banners in their loading state without their data timers.
class _NewsController extends NewsBannerWidgetController {
  @override
  // Deliberately omit the production timer in this unrelated banner test double.
  // ignore: must_call_super
  void onInit() {}
}

class _ActivityController extends ActivityBannerWidgetController {
  @override
  // Deliberately omit the production timer in this unrelated banner test double.
  // ignore: must_call_super
  void onInit() {
    isLoading = true;
  }
}

void main() {
  late _WebViewPlatform platform;
  late _Controller nativeController;
  late InAppWebViewController controller;

  setUp(() async {
    Get.testMode = true;
    platform = _WebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService().init();
    Get.put<SubscriptionService>(SubscriptionService());
    Get.put<NewsBannerWidgetController>(_NewsController());
    Get.put<ActivityBannerWidgetController>(_ActivityController());
  });

  tearDown(() => Get.reset());

  Future<void> pumpRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> launchHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(initialRoute: TPRoute.main, getPages: TPRoute.page),
    );
    await pumpRoute(tester);
  }

  Future<void> attachController(
    WidgetTester tester, {
    bool bridgeReady = true,
    bool failLoad = false,
  }) async {
    nativeController = _Controller()..failLoad = failLoad;
    controller = InAppWebViewController.fromPlatform(
      platform: nativeController,
    );
    if (bridgeReady) nativeController.listenerReady.complete();
    platform.creation.onWebViewCreated!(controller);
    await tester.pump();
  }

  Future<void> enterFromHome(
    WidgetTester tester, {
    bool bridgeReady = true,
    bool failLoad = false,
  }) async {
    await launchHome(tester);
    await tester.tap(find.text('友善同行'));
    await pumpRoute(tester);
    await attachController(
      tester,
      bridgeReady: bridgeReady,
      failLoad: failLoad,
    );
  }

  Future<void> setHistory(WidgetTester tester, bool value) async {
    nativeController.hasHistory = value;
    platform.creation.onUpdateVisitedHistory!(
      controller,
      WebUri(kCodefestServiceUrl),
      false,
    );
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      !value,
    );
  }

  void failMainFrame() {
    platform.creation.onReceivedHttpError!(
      controller,
      WebResourceRequest(
        url: WebUri(kCodefestServiceUrl),
        isForMainFrame: true,
      ),
      WebResourceResponse(statusCode: 503),
    );
  }

  testWidgets('saved start-page preference remains effective', (tester) async {
    await SharedPreferencesService().instance.setInt(
      SharedPreferencesService.keyHomeIndex,
      0,
    );
    await launchHome(tester);
    expect(find.byType(MainView), findsOneWidget);
    expect(Get.find<MainViewController>().currentIndex.value, 0);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
  });

  testWidgets('new launch restores TownPass home and both required bindings', (
    tester,
  ) async {
    await launchHome(tester);
    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(CodefestView), findsNothing);
    expect(Get.find<MainViewController>().currentIndex.value, 1);
    expect(Get.isRegistered<PinnedServiceWidgetController>(), isTrue);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    expect(find.text('友善同行').hitTestable(), findsOneWidget);
  });

  testWidgets('home entry waits for the bridge then returns to native home', (
    tester,
  ) async {
    await enterFromHome(tester, bridgeReady: false);
    expect(Get.currentRoute, '/codefest');
    expect(find.byType(CodefestView), findsOneWidget);
    expect(platform.creation.initialUrlRequest, isNull);
    expect(nativeController.events, ['listener:flutterObject']);
    expect(find.text('返回台北通').hitTestable(), findsOneWidget);

    nativeController.listenerReady.complete();
    await tester.pump();
    expect(nativeController.events, [
      'listener:flutterObject',
      'listener-ready',
      'load:$kCodefestServiceUrl',
    ]);
    await tester.tap(find.text('返回台北通'));
    await pumpRoute(tester);
    expect(Get.currentRoute, TPRoute.main);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(CodefestView), findsNothing);
  });

  testWidgets('pinned service uses the same dedicated service route', (
    tester,
  ) async {
    await launchHome(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('服務'),
      ),
    );
    await tester.pump();
    final pinnedEntry = find.byWidgetPredicate(
      (widget) =>
          widget is PinnedServiceItemWidget &&
          widget.service.destinationUrl ==
              MyServiceItemId.codefest.item.destinationUrl,
    );
    await tester.tap(pinnedEntry);
    await pumpRoute(tester);
    await attachController(tester);
    expect(Get.currentRoute, '/codefest');
    expect(find.byType(CodefestView), findsOneWidget);
    expect(nativeController.events.last, 'load:$kCodefestServiceUrl');
    await tester.tap(find.text('返回台北通'));
    await pumpRoute(tester);
    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(CodefestView), findsNothing);
  });

  testWidgets('only the exact service URL receives the dedicated container', (
    tester,
  ) async {
    await launchHome(tester);
    final otherUrls = [
      MyServiceItemId.dashboard.item.destinationUrl,
      '$kCodefestServiceUrl/other',
      '$kCodefestServiceUrl?service=other',
    ];
    for (final url in otherUrls) {
      unawaited(TPRoute.openUri(uri: url, forceTitle: 'Other service'));
      await pumpRoute(tester);
      expect(Get.currentRoute, TPRoute.webView);
      expect(find.byType(TPWebView), findsOneWidget);
      expect(find.byType(CodefestView), findsNothing);
      expect((Get.arguments as WebViewArgument).url, url);
      expect((Get.arguments as WebViewArgument).forceTitle, 'Other service');
      Get.back();
      await pumpRoute(tester);
    }
  });

  testWidgets('explicit return bypasses WebView history without going back', (
    tester,
  ) async {
    await enterFromHome(tester);
    await setHistory(tester, true);
    await tester.tap(find.text('返回台北通'));
    await pumpRoute(tester);
    expect(nativeController.events, isNot(contains('back')));
    expect(Get.currentRoute, TPRoute.main);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(CodefestView), findsNothing);
  });

  testWidgets(
    'system back uses web history then returns when history is empty',
    (tester) async {
      await enterFromHome(tester);
      await setHistory(tester, true);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(nativeController.events.last, 'back');
      expect(find.byType(CodefestView), findsOneWidget);
      await setHistory(tester, false);
      await tester.binding.handlePopRoute();
      await pumpRoute(tester);
      expect(Get.currentRoute, TPRoute.main);
      expect(find.byType(HomeView), findsOneWidget);
    },
  );

  testWidgets('main-frame failure permits retry and native return', (
    tester,
  ) async {
    await enterFromHome(tester);
    failMainFrame();
    await tester.pump();
    expect(find.text('重新載入'), findsOneWidget);
    expect(find.text('返回台北通').hitTestable(), findsOneWidget);
    await tester.tap(find.text('重新載入'));
    await tester.pump();
    expect(find.text('重新載入'), findsNothing);
    expect(
      nativeController.events.where(
        (event) => event == 'load:$kCodefestServiceUrl',
      ),
      hasLength(2),
    );
    failMainFrame();
    await tester.pump();
    await tester.tap(find.text('返回台北通'));
    await pumpRoute(tester);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(CodefestView), findsNothing);
  });

  testWidgets('loadUrl failure permits retry', (tester) async {
    await enterFromHome(tester, failLoad: true);
    expect(find.text('重新載入'), findsOneWidget);
    nativeController.failLoad = false;
    await tester.tap(find.text('重新載入'));
    await tester.pump();
    expect(find.text('重新載入'), findsNothing);
    expect(
      nativeController.events.where(
        (event) => event == 'load:$kCodefestServiceUrl',
      ),
      hasLength(2),
    );
  });

  testWidgets('successful history navigation clears a previous load failure', (
    tester,
  ) async {
    await enterFromHome(tester);
    await setHistory(tester, true);
    failMainFrame();
    await tester.pump();
    expect(find.text('重新載入'), findsOneWidget);
    await tester.binding.handlePopRoute();
    platform.creation.onLoadStart!(controller, WebUri(kCodefestServiceUrl));
    platform.creation.onLoadStop!(controller, WebUri(kCodefestServiceUrl));
    await tester.pump();
    expect(nativeController.events.last, 'back');
    expect(find.text('重新載入'), findsNothing);
  });

  testWidgets('browser geolocation is limited to the configured origin', (
    tester,
  ) async {
    await enterFromHome(tester);
    final ask = platform.creation.onGeolocationPermissionsShowPrompt!;
    expect(
      (await ask(controller, Uri.parse(kCodefestServiceUrl).origin))?.allow,
      isTrue,
    );
    expect((await ask(controller, 'https://example.invalid'))?.allow, isFalse);
    expect((await ask(controller, 'null'))?.allow, isFalse);
    expect(
      (await ask(
        controller,
        'http://${Uri.parse(kCodefestServiceUrl).host}',
      ))?.allow,
      isFalse,
    );
  });
}
