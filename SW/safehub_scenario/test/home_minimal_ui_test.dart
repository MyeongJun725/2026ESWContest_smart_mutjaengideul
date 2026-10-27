import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/sign_result_strip.dart';
import 'local_preview_test.dart' show mockAudioPlugins;

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  final directory = Platform.environment['MINIMAL_UI_SCREENSHOTS'];
  if (directory == null) return;
  await t.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('original FHD home keeps its other panels and help response', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    AppConfig.resetForTesting();
    addTearDown(AppConfig.resetForTesting);
    mockAudioPlugins(t);
    await t.runAsync(() async {
      final loader = FontLoader('Pretendard');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
      }
      await loader.load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
      debugShowCheckedModeBanner: false, theme: AppTheme.light, home: const SafeHubHomePage())));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('새로운 알림이 없어요'), findsOneWidget);
    expect(find.text('수어로 이야기해요'), findsOneWidget);
    expect(find.text('최근 알림'), findsOneWidget);
    expect(find.byTooltip('AI·알림 설정'), findsOneWidget);
    final video = t.getRect(find.ancestor(of: find.text('수어 카메라'), matching: find.byType(Container)).first);
    final strip = t.getRect(find.byKey(const ValueKey('sign-result-strip')));
    expect((video.bottom - strip.top).abs(), lessThan(1));
    expect(find.text('도움 요청').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, key, 'home-fhd');
    await t.tap(find.text('도움 요청'));
    await t.pumpAndSettle();
    expect(find.text('도움이 필요하신가요?'), findsOneWidget);
    expect(find.text('괜찮아요'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, key, 'original-help');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('large sign result preserves conversation action and last-result status', (t) async {
    t.view.physicalSize = const Size(1200, 180);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var opened = 0;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false,
      theme: AppTheme.light, home: Scaffold(body: Center(child: SignResultStrip(
        sign: '아프다', connected: false, onConversation: () => opened++))))));
    final text = t.widget<Text>(find.byKey(const ValueKey('sign-result-text')));
    expect(text.data, '아프다');
    expect(text.style!.fontSize, 40);
    expect(find.textContaining('최근 인식 결과'), findsOneWidget);
    await t.tap(find.text('수어 대화'));
    expect(opened, 1);
    expect(t.takeException(), isNull);
    await capture(t, key, 'sign-result');
  });
}
