import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/screens/photo_frame/short_swipe_physics.dart';

void main() {
  Future<PageController> pump(WidgetTester tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: controller,
          physics: ShortSwipePhysics(startPage: () => 0),
          pageSnapping: false,
          itemBuilder: (_, page) => Text('$page'),
        ),
      ),
    );
    return controller;
  }

  // Slow, so it isn't a fling.
  Future<void> swipe(WidgetTester tester, double share) async {
    final gesture = await tester.startGesture(const Offset(700, 300));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (var i = 1; i <= 20; i++) {
      await gesture.moveBy(Offset(-width * share / 20, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a short calm swipe turns the page', (tester) async {
    final controller = await pump(tester);
    await swipe(tester, 0.25);
    expect(controller.page, 1);
  });

  testWidgets('a tiny swipe springs back', (tester) async {
    final controller = await pump(tester);
    await swipe(tester, 0.08);
    expect(controller.page, 0);
  });
}
