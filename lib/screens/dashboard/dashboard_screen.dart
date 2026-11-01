import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../state/display_state.dart';
import '../../state/settings.dart';

const _retryDelay = Duration(seconds: 30);

/// Adds `kiosk` to the dashboard URL - the kiosk-mode plugin then hides the
/// header and sidebar.
Uri kioskDashboardUri(String dashboardUrl) {
  final uri = Uri.parse(dashboardUrl.trim());
  if (uri.queryParameters.containsKey('kiosk')) return uri;
  final query = [if (uri.query.isNotEmpty) uri.query, 'kiosk'].join('&');
  return uri.replace(query: query);
}

/// The Home Assistant dashboard, full screen. The login (once, with
/// "Angemeldet bleiben") is kept in the WebView's storage.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final WebViewController _controller;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            // Home Assistant restarting or Wi-Fi gone: try again later
            // instead of leaving an error page on the wall.
            if (error.isForMainFrame ?? true) {
              _retryTimer?.cancel();
              _retryTimer = Timer(_retryDelay, _load);
            }
          },
        ),
      );
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _load() {
    final url = ref.read(settingsProvider).dashboardUrl;
    _controller.loadRequest(kioskDashboardUri(url));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      displayProvider.select((display) => display.reloadRequests),
      (_, _) => _load(),
    );
    ref.listen(
      settingsProvider.select((settings) => settings.dashboardUrl),
      (_, _) => _load(),
    );
    return WebViewWidget(controller: _controller);
  }
}
