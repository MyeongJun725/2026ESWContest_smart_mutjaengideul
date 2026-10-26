import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/ui/widgets/hardware_test_dialog.dart';

void main() {
  testWidgets('manual fan and alarm stop are independent; no curtain controls', (tester) async {
    tester.view.physicalSize=const Size(1280,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final alerts=<String>[];final fans=<bool>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HardwareTestDialog(
      connected:true,classifierUri:Uri.parse('http://127.0.0.1:9380/classify'),
      publishAlert:(d,a){alerts.add('$d:$a');return true;},
      publishFan:(p){fans.add(p);return true;}))));
    await tester.tap(find.text('팬 켜기'));await tester.pump();
    expect(fans,[true]);
    await tester.tap(find.text('낙상 의심 경보 10초'));await tester.pump();
    expect(alerts,['led:blink','bedshaker:on']);
    await tester.tap(find.text('LED·진동 끄기'));await tester.pump();
    expect(alerts.sublist(2),['led:off','bedshaker:off']);expect(fans,[true]);
    expect(find.text('커튼 올리기'),findsNothing);expect(tester.takeException(),isNull);
  });
  testWidgets('typed negative never publishes; explicit fire publishes both commands', (tester) async {
    tester.view.physicalSize=const Size(1280,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final alerts=<String>[];var calls=0;
    final client=MockClient((request) async {calls++;return http.Response(jsonEncode({
      'hazard':calls==2,'reason':calls==1?'negated_fire':'explicit_announcement'}),200);});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HardwareTestDialog(
      connected:true,client:client,classifierUri:Uri.parse('http://127.0.0.1:9380/classify'),
      publishAlert:(d,a){alerts.add('$d:$a');return true;},publishFan:(_)=>true))));
    await tester.enterText(find.byType(TextField),'화재가 발생하지 않았습니다.');
    await tester.tap(find.text('문장 판별 후 LED·진동 시험'));await tester.pumpAndSettle();
    expect(alerts,isEmpty);expect(find.textContaining('위험 작동 보류'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'화재가 발생했습니다.');
    await tester.tap(find.text('문장 판별 후 LED·진동 시험'));await tester.pumpAndSettle();
    expect(alerts,['led:blink','bedshaker:on']);expect(tester.takeException(),isNull);
    client.close();
  });
}
