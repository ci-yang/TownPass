import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:town_pass/config/codefest.dart';
import 'package:town_pass/page/codefest/codefest_view.dart';
import 'package:town_pass/util/tp_route.dart';

class _WebViewPlatform extends InAppWebViewPlatform {
  late PlatformInAppWebViewWidgetCreationParams creation;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    creation = params;
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
  }) async => events.add('load:${urlRequest.url}');

  @override
  Future<bool> canGoBack() async => hasHistory;

  @override
  Future<void> goBack() async => events.add('back');
}

void main() {
  late _WebViewPlatform platform;
  late _Controller nativeController;
  late InAppWebViewController controller;

  setUp(() {
    Get.testMode = true;
    platform = _WebViewPlatform();
    InAppWebViewPlatform.instance = platform;
  });

  tearDown(() => Get.reset());

  Future<void> launch(WidgetTester tester, {bool bridgeReady = true}) async {
    nativeController = _Controller();
    controller = InAppWebViewController.fromPlatform(
      platform: nativeController,
    );
    if (bridgeReady) nativeController.listenerReady.complete();
    await tester.pumpWidget(
      GetMaterialApp(initialRoute: TPRoute.main, getPages: TPRoute.page),
    );
    await tester.pump();
    platform.creation.onWebViewCreated!(controller);
    await tester.pump();
  }

  testWidgets(
    'root directly opens the service only after its bridge is ready',
    (tester) async {
      await launch(tester, bridgeReady: false);
      expect(find.byType(CodefestView), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(platform.creation.initialUrlRequest, isNull);
      expect(nativeController.events, ['listener:flutterObject']);

      nativeController.listenerReady.complete();
      await tester.pump();
      expect(nativeController.events, [
        'listener:flutterObject',
        'listener-ready',
        'load:$kCodefestServiceUrl',
      ]);
    },
  );

  testWidgets('main-frame failure offers a retry without a TownPass home', (
    tester,
  ) async {
    await launch(tester);
    platform.creation.onReceivedHttpError!(
      controller,
      WebResourceRequest(
        url: WebUri(kCodefestServiceUrl),
        isForMainFrame: true,
      ),
      WebResourceResponse(statusCode: 503),
    );
    await tester.pump();
    expect(find.text('重新載入'), findsOneWidget);
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

  testWidgets('Android back uses WebView history before leaving the root', (
    tester,
  ) async {
    await launch(tester);
    nativeController.hasHistory = true;
    platform.creation.onUpdateVisitedHistory!(
      controller,
      WebUri(kCodefestServiceUrl),
      false,
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(nativeController.events.last, 'back');
    expect(find.byType(CodefestView), findsOneWidget);
  });

  testWidgets('successful history navigation clears a previous load failure', (
    tester,
  ) async {
    await launch(tester);
    nativeController.hasHistory = true;
    platform.creation.onUpdateVisitedHistory!(
      controller,
      WebUri(kCodefestServiceUrl),
      false,
    );
    platform.creation.onReceivedHttpError!(
      controller,
      WebResourceRequest(
        url: WebUri('$kCodefestServiceUrl/unavailable'),
        isForMainFrame: true,
      ),
      WebResourceResponse(statusCode: 503),
    );
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
    await launch(tester);
    final ask = platform.creation.onGeolocationPermissionsShowPrompt!;
    expect(
      (await ask(controller, Uri.parse(kCodefestServiceUrl).origin))?.allow,
      isTrue,
    );
    expect((await ask(controller, 'https://example.invalid'))?.allow, isFalse);
    expect((await ask(controller, 'null'))?.allow, isFalse);
  });
}
