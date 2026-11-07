import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:town_pass/config/codefest.dart';
import 'package:town_pass/util/tp_web_view.dart';

/// The service is the root screen; TPInAppWebView installs the native bridge
/// before onWebViewCreated loads the configured HTTPS application.
class CodefestView extends StatefulWidget {
  const CodefestView({super.key});

  @override
  State<CodefestView> createState() => _CodefestViewState();
}

class _CodefestViewState extends State<CodefestView> {
  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _loadFailed = false;

  Future<void> _openService() async {
    if (mounted) setState(() => _loadFailed = false);
    try {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(kCodefestServiceUrl)),
      );
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _updateHistory() async {
    final canGoBack = await _controller?.canGoBack() ?? false;
    if (mounted && _canGoBack != canGoBack) {
      setState(() => _canGoBack = canGoBack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _controller?.goBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              TPInAppWebView(
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _openService();
                },
                onUpdateVisitedHistory: (_, _, _) => _updateHistory(),
                onLoadStart: (_, _) {
                  if (mounted && _loadFailed) {
                    setState(() => _loadFailed = false);
                  }
                },
                onLoadStop: (_, _) => _updateHistory(),
                onReceivedError: (_, request, _) {
                  if (request.isForMainFrame == true && mounted) {
                    setState(() => _loadFailed = true);
                  }
                },
                onReceivedHttpError: (_, request, response) {
                  if (request.isForMainFrame == true &&
                      (response.statusCode ?? 0) >= 400 &&
                      mounted) {
                    setState(() => _loadFailed = true);
                  }
                },
                onGeolocationPermissionsShowPrompt: (_, origin) async {
                  final expected = Uri.parse(kCodefestServiceUrl);
                  final requested = Uri.tryParse(origin);
                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow:
                        requested?.scheme == expected.scheme &&
                        requested?.host == expected.host &&
                        requested?.port == expected.port,
                    retain: false,
                  );
                },
              ),
              if (_loadFailed)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('目前無法載入友善同行，請確認網路後重試。'),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _openService,
                              child: const Text('重新載入'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
