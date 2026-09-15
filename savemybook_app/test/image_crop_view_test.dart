import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/books/image_crop_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/utils/crop_geometry.dart';

ui.Image photo() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1600, 1000), Paint()..color = const Color(0xFF336699));
  return recorder.endRecording().toImageSync(1600, 1000);
}

Future<ImageCropViewState> pumpCrop(WidgetTester tester, ui.Image image, {bool circular = false}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.build(Brightness.light),
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    supportedLocales: const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      S = AppLocalizations.of(context);
      return child!;
    },
    home: ImageCropView(image: image, circular: circular),
  ));
  await tester.pump();
  return tester.state<ImageCropViewState>(find.byType(ImageCropView));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
  });

  testWidgets('image starts covering the frame', (tester) async {
    final image = photo();
    final state = await pumpCrop(tester, image);
    final frame = state.frameSize;
    expect(frame.width, closeTo(350, 0.01));
    expect(state.transform!.scale, closeTo(CropGeometry.minScale(const Size(1600, 1000), frame, 0), 1e-9));
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });

  testWidgets('dragging past the edge springs back inside the bounds', (tester) async {
    final image = photo();
    final state = await pumpCrop(tester, image);
    const size = Size(1600, 1000);
    final center = tester.getCenter(find.byType(ImageCropView));

    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final bound = CropGeometry.maxOffset(size, state.frameSize, state.transform!.scale, 0);
    expect(state.transform!.offset.dx, greaterThan(bound.dx));
    expect(state.transform!.offset.dx, lessThan(bound.dx + state.frameSize.width));

    await gesture.up();
    await tester.pumpAndSettle();
    final settled = state.transform!;
    expect(CropGeometry.isWithinBounds(settled, size, state.frameSize), isTrue);
    expect(settled.offset.dx, closeTo(bound.dx, 0.6));
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });

  testWidgets('double tap zooms in and out', (tester) async {
    final image = photo();
    final state = await pumpCrop(tester, image);
    const size = Size(1600, 1000);
    final minScale = CropGeometry.minScale(size, state.frameSize, 0);
    final center = tester.getCenter(find.byType(ImageCropView));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(state.transform!.scale, closeTo(minScale * 2.5, 1e-6));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(state.transform!.scale, closeTo(minScale, 1e-6));
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });

  testWidgets('rotate button turns the image and keeps it covering the frame', (tester) async {
    final image = photo();
    final state = await pumpCrop(tester, image, circular: true);
    await tester.tap(find.byIcon(Icons.rotate_90_degrees_ccw_rounded));
    await tester.pumpAndSettle();
    final t = state.transform!;
    expect(t.quarterTurns, 3);
    expect(CropGeometry.isWithinBounds(t, const Size(1600, 1000), state.frameSize), isTrue);

    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    await tester.pumpAndSettle();
    expect(state.transform!.quarterTurns, 0);
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });
}
