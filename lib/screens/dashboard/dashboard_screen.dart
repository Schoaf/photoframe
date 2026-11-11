import 'dart:async';
import 'dart:convert';

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

/// [view] in place of the dashboard's view: `…/lovelace/0` + `wetter` →
/// `…/lovelace/wetter`. A dashboard URL without a view gets it appended.
String dashboardViewUrl(String dashboardUrl, String? view) {
  final uri = Uri.parse(dashboardUrl.trim());
  if (view == null || view.isEmpty) return uri.toString();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return uri
      .replace(
        pathSegments: [
          if (segments.length > 1)
            ...segments.take(segments.length - 1)
          else
            ...segments,
          view,
        ],
      )
      .toString();
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
      ..setOnConsoleMessage((message) {
        if (message.level == JavaScriptLogLevel.error ||
            message.level == JavaScriptLogLevel.warning) {
          debugPrint('WebView ${message.level.name}: ${message.message}');
        }
      })
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

  /// Switches the view inside Home Assistant's page - much faster than
  /// loading it again on the tablet. Loads it when another page is open.
  Future<void> _showView(String? view) async {
    final settings = ref.read(settingsProvider);
    final target = kioskDashboardUri(
      dashboardViewUrl(settings.dashboardUrl, view),
    );
    final current = Uri.tryParse(await _controller.currentUrl() ?? '');
    if (current == null || current.origin != target.origin) {
      await _controller.loadRequest(target);
      return;
    }
    final path = jsonEncode('${target.path}?${target.query}');
    try {
      await _controller.runJavaScript(
        'history.replaceState(null, "", $path);'
        'window.dispatchEvent(new CustomEvent("location-changed", '
        '{detail: {replace: true}}));',
      );
    } on Exception {
      await _controller.loadRequest(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      displayProvider.select((display) => display.viewRequests),
      (_, _) => _showView(ref.read(displayProvider).dashboardView),
    );
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
