import 'package:flutter/material.dart';

/// Sized for the Galaxy Tab A 10.1 (SM-T585): 1280×800 dp in landscape,
/// usually a few steps away on the wall - big targets, big type.
class AppSizes {
  const AppSizes._();

  /// Overlay buttons on photos.
  static const overlayButton = 64.0;
  static const overlayIcon = 36.0;
  static const captionFontSize = 20.0;
  static const clockFontSize = 72.0;
  static const runningTileWidth = 340.0;

  /// Appliance tiles along the bottom edge.
  static const deviceTileMinWidth = 300.0;
  static const deviceTileHeight = 88.0;
  static const agendaWidth = 460.0;
  static const galleryColumns = 6;
  static const menuPaneWidth = 340.0;
  static const keypadButton = 80.0;
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF03A9F4), // Home Assistant blue
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.black,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 16,
      titleTextStyle: TextStyle(fontSize: 18),
    ),
  );
}
