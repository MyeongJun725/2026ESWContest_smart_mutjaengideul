import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/ui/widgets/editable_dashboard.dart';

void main() {
  test('invalid saved rectangles fall back while valid positions are retained', () {
    final result = parseDashboardLayout({'camera': [0.1, .2, .5, .6], 'help': [-1, 0, 2, 1], 'csi': [0,0,double.nan,1]});
    expect(result['camera']!.x, .1);
    expect(result['help']!.x, defaultDashboardLayout()['help']!.x);
    expect(result['csi']!.w, defaultDashboardLayout()['csi']!.w);
  });
  testWidgets('move, resize, portrait preset and save survive a fresh editor', (t) async {
    t.view.physicalSize = const Size(1280, 900); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final folder = (await t.runAsync(() => Directory.systemTemp.createTemp('safehub-layout-test-')))!;
    final file = File('${folder.path}/layout.json');
    bool editing = true;
    final tiles = {for (final id in defaultDashboardLayout().keys) id: ColoredBox(color: Colors.white, child: Text(id))};
    await t.pumpWidget(MaterialApp(home: Scaffold(body: EditableDashboard(
      storageFile: file, tiles: tiles, editing: editing, onEditingChanged: (v) => editing = v))));
    await t.pumpAndSettle();
    final before = t.getRect(find.byKey(const ValueKey('tile-camera')));
    await t.drag(find.byKey(const ValueKey('move-camera')), const Offset(30, 15)); await t.pump();
    expect(t.getRect(find.byKey(const ValueKey('tile-camera'))).left, greaterThan(before.left));
    await t.drag(find.byKey(const ValueKey('resize-camera')), const Offset(-90, -20)); await t.pump();
    expect(t.getRect(find.byKey(const ValueKey('tile-camera'))).width, lessThan(before.width));
    await t.tap(find.text('카메라 세로형')); await t.pump();
    final portrait = t.getRect(find.byKey(const ValueKey('tile-camera')));
    expect(portrait.width, lessThan(portrait.height));
    await t.runAsync(() async {
      await t.tap(find.text('배치 저장'));
      for (var i=0; i<100 && editing; i++) { await Future<void>.delayed(const Duration(milliseconds: 10)); }
    });
    await t.pumpAndSettle();
    expect(editing, isFalse);
    final saved = (await t.runAsync(() async => jsonDecode(await file.readAsString()))) as Map;
    expect(saved['camera'][2], lessThan(.5));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home: Scaffold(body: EditableDashboard(
      storageFile: file, tiles: tiles, editing: false, onEditingChanged: (_) {}))));
    for (var i=0; i<20; i++) {
      await t.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 20)); });
      await t.pumpAndSettle();
      if ((t.getRect(find.byKey(const ValueKey('tile-camera'))).width - portrait.width).abs() < 1) break;
    }
    expect(t.getRect(find.byKey(const ValueKey('tile-camera'))).width, closeTo(portrait.width, 1));
    expect(t.takeException(), isNull);
  });
}
