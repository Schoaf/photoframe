import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/models/frame_crop.dart';
import 'package:ha_display/models/photo_item.dart';
import 'package:ha_display/screens/photo_frame/photo_slide.dart';

void main() {
  test('reads the part set in photoframe-client from the description', () {
    final crop = FrameCrop.parse(
      'Urlaub am See\n[rahmen 0.1000 0.2000 0.6000 0.5000]',
    );
    expect(crop?.isWhole, isFalse);
    expect(crop?.rect, const Rect.fromLTRB(0.1, 0.2, 0.6, 0.5));
    expect(FrameCrop.parse('[rahmen ganz]')?.isWhole, isTrue);
  });

  test('reads a part zoomed out past the photo', () {
    expect(
      FrameCrop.parse('[rahmen -0.3000 0.0000 1.3000 1.0000]')?.rect,
      const Rect.fromLTRB(-0.3, 0, 1.3, 1),
    );
  });

  test('ignores descriptions without a valid marker', () {
    expect(FrameCrop.parse(null), isNull);
    expect(FrameCrop.parse('Urlaub'), isNull);
    expect(FrameCrop.parse('[rahmen 0.5 0.2 0.4 0.5]'), isNull);
    // Nothing of the photo in it.
    expect(FrameCrop.parse('[rahmen 1.2 0 2 1]'), isNull);
  });

  test('a photo item carries the crop of its description', () {
    final item = PhotoItem.fromJson({
      'id': 1,
      'filename': 'a.jpg',
      'type': 'photo',
      'additional': {'description': '[rahmen ganz]'},
    });
    expect(item.crop?.isWhole, isTrue);
  });

  testWidgets('the chosen part fills the 16:10 screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PhotoSlide(
          image: MemoryImage(Uint8List(0)),
          crop: const FrameCrop(Rect.fromLTRB(0.25, 0.5, 0.75, 1)),
        ),
      ),
    );
    // Half the photo's width and height fill the screen: the photo is
    // laid out at twice the screen, its middle bottom part in view.
    expect(
      tester.getRect(find.byType(Image)),
      const Rect.fromLTWH(-800, -1000, 3200, 2000),
    );
  });
}
