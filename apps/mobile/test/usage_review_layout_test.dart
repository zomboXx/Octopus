import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/usage_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class ReviewUsageDevice extends MemoryDevice {
  @override
  Future<Map<String, dynamic>> usageWeek(String start) async {
    final monday = DateTime.parse(start), now = DateTime.now();
    final days = List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      final future = date.isAfter(now);
      return {
        'date': dayKey(date),
        'milliseconds': future ? 0 : 7200000,
        'future': future,
        'available': !future,
      };
    });
    final total = days.fold<int>(
      0,
      (sum, day) => sum + (day['milliseconds'] as int),
    );
    return {
      'granted': true,
      'days': days,
      'apps': [
        {
          'package': 'video.test',
          'name': 'Ứng dụng video',
          'milliseconds': total * .8,
        },
        {
          'package': 'reading.test',
          'name': 'Đọc sách',
          'milliseconds': total * .2,
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'weekly overview and suggestion actions fit a phone-sized screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(() async {
        final windowsDirectory = Platform.environment['WINDIR'];
        if (windowsDirectory != null) {
          final fontFile = File('$windowsDirectory/Fonts/segoeui.ttf');
          if (fontFile.existsSync()) {
            final font = FontLoader('Roboto')
              ..addFont(
                Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
              );
            await font.load();
          }
        }
        await icons.load();
      });
      final store = BrainStore(device: ReviewUsageDevice())
        ..onboardingComplete = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('usage-review-capture'),
          child: OctopusApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thống kê'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tuần trước'));
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('usage-review-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('../../tmp/octopus-067-$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('week');
      final suggestion = find.byType(RestrictionSuggestionCard);
      await tester.scrollUntilVisible(
        suggestion,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(suggestion);
      await tester.pumpAndSettle();
      expect(find.text('Thêm hạn chế').hitTestable(), findsOneWidget);
      await capture('suggestion');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
