// Run only in the disposable browser host prepared by run_ui_preview.py.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/main.dart' as app;

void main() {
  testWidgets('browser opens the product home and help without native OS APIs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await app.main();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('도움 요청').hitTestable(), findsOneWidget);
    expect(find.text('수어를 기다리고 있어요'), findsOneWidget);
    expect(find.text('최근 알림'), findsOneWidget);
    await tester.tap(find.text('도움 요청'));
    await tester.pumpAndSettle();
    expect(find.text('도움이 필요하신가요?'), findsOneWidget);
    await tester.tap(find.text('괜찮아요'));
    await tester.pumpAndSettle();
    expect(find.text('도움이 필요하신가요?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
