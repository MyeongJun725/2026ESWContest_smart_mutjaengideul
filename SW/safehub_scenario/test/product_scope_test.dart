import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/core/appliance_controls.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/widgets/appliance_panel.dart';
import 'package:safehub_app/ui/widgets/house_status_card.dart';
import 'local_preview_test.dart' show mockAudioPlugins;

void main() {
  test(
    'fresh settings select fastText and old engine settings remain disabled',
    () {
      expect(SituationSettings().model, 'fasttext-fire-screen');
      final saved = <String, dynamic>{
        'model': 'gemma4-e2b',
        'enabled': true,
        'endpoint': 'http://127.0.0.1:9379/v1/chat/completions',
        'address': '보존할 주소',
      };
      final migrated = SituationSettings.fromJson(saved);
      expect(migrated.enabled, isFalse);
      expect(migrated.fastProtocol, isTrue);
      expect(migrated.model, 'fasttext-fire-screen');
      expect(migrated.address, '보존할 주소');
      expect(saved['model'], 'gemma4-e2b');
      expect(saved['enabled'], isTrue);
      expect(
        SituationSettings.fromJson({
          'model': 'fasttext-fire-screen',
          'enabled': true,
        }).enabled,
        isTrue,
      );
    },
  );

  for (final developer in [false, true]) {
    testWidgets(
      'home developer=$developer separates training/tests from product',
      (t) async {
        t.view.physicalSize = const Size(1400, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        mockAudioPlugins(t);
        AppConfig.resetForTesting();
        addTearDown(AppConfig.resetForTesting);
        await t.pumpWidget(
          MaterialApp(home: SafeHubHomePage(developerTools: developer)),
        );
        await t.pump();
        expect(find.text('장치 테스트'), developer ? findsOneWidget : findsNothing);
        expect(
          find.text('시나리오 테스트'),
          developer ? findsOneWidget : findsNothing,
        );
        await t.tap(
          find.byKey(
            ValueKey(developer ? 'navigation-신호 관리' : 'navigation-활동 상태'),
          ),
        );
        await t.pump();
        expect(
          find.text('1. 신호 수집'),
          developer ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('2. 기록 · 학습'),
          developer ? findsOneWidget : findsNothing,
        );
        if (!developer) expect(find.text('현재 모델의 행동 예측'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }

  testWidgets(
    'product appliances show fan/curtain and preserve inactive legacy binding',
    (t) async {
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final controls = ApplianceControls()
        ..restore(
          '[{"sign":"점등","room":"livingroom","device":"light","action":"on"}]',
        );
      final commands = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppliancePanel(
              controls: controls,
              connected: true,
              latestSign: '',
              loadShortcuts: false,
              allowPreview: false,
              publishDeviceCommand: (device, action) {
                commands.add('$device:$action');
                return true;
              },
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.text('거실 팬'), findsOneWidget);
      expect(find.text('거실 커튼'), findsOneWidget);
      expect(find.text('거실 조명'), findsNothing);
      await t.tap(find.text('켜기').first);
      await t.pump();
      expect(commands, ['aircon:on']);
      expect(controls.bindings['점등']!.device, 'light');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('real help remains reachable without developer tools', (t) async {
    final service = SituationService(
      settings: SituationSettings(enabled: false),
    );
    addTearDown(service.dispose);
    service.openHelp();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HouseStatusCard(
            service: service,
            onAcknowledge: service.acknowledge,
            developerTools: false,
          ),
        ),
      ),
    );
    expect(find.text('시나리오 테스트'), findsNothing);
    expect(find.text('상황 응답 · 도움'), findsOneWidget);
  });
}
