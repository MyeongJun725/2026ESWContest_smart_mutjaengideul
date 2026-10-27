import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/services/disaster_service.dart';

void main() {
  group('DisasterService API polling', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('safehub-disaster-');
      final config = File('${directory.path}/settings.json');
      await config.writeAsString(
        jsonEncode({
          'DISASTER_API_URL': 'https://example.invalid/disaster?region=local',
          'DISASTER_API_KEY': 'fake-test-key',
        }),
      );
      await AppConfig.load(filePath: config.path);
    });

    tearDown(() async {
      AppConfig.resetForTesting();
      await directory.delete(recursive: true);
    });

    http.Response response(
      List<Map<String, dynamic>> body, {
      int total = 200,
    }) => http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'header': {'resultCode': '00'},
          'body': body,
          'totalCount': total,
        }),
      ),
      200,
    );

    test(
      'newest-first APIs expose first-page additions on the next poll',
      () async {
        var newest = 10;
        final pages = <String>[];
        final client = MockClient((request) async {
          final page = request.url.queryParameters['pageNo']!;
          pages.add(page);
          return response([
            {
              'SN': page == '1' ? newest : 1,
              'CRT_DT': page == '1'
                  ? '2026/10/27 12:00:00'
                  : '2026/10/26 12:00:00',
            },
          ]);
        });
        addTearDown(client.close);
        final service = DisasterService(client: client);
        expect((await service.fetchLatest())?['SN'], 10);
        newest = 11;
        expect((await service.fetchLatest())?['SN'], 11);
        expect(pages, ['1', '2', '1', '2']);
      },
    );

    test(
      'oldest-first APIs expose last-page additions and page growth',
      () async {
        var total = 200;
        final pages = <String>[];
        final client = MockClient((request) async {
          final page = request.url.queryParameters['pageNo']!;
          pages.add(page);
          return response([
            {
              'SN': page == '1' ? 1 : total,
              'CRT_DT': page == '1'
                  ? '2026/10/26 12:00:00'
                  : '2026/10/27 12:00:00',
            },
          ], total: total);
        });
        addTearDown(client.close);
        final service = DisasterService(client: client);
        expect((await service.fetchLatest())?['SN'], 200);
        total = 201;
        expect((await service.fetchLatest())?['SN'], 201);
        expect(pages, ['1', '2', '1', '3']);
      },
    );

    test(
      'empty single-page results preserve URL filters and query date',
      () async {
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['region'], 'local');
          expect(request.url.queryParameters['crtDt'], '20261025');
          expect(request.url.queryParameters['serviceKey'], 'fake-test-key');
          return response([], total: 0);
        });
        addTearDown(client.close);
        final service = DisasterService(
          client: client,
          now: () => DateTime(2026, 10, 27),
        );
        expect(await service.fetchLatest(), isNull);
        expect(requests, 1);
      },
    );

    test(
      'HTTP failure remains a failure rather than an empty alert list',
      () async {
        final client = MockClient(
          (_) async => http.Response('unavailable', 503),
        );
        addTearDown(client.close);
        await expectLater(
          DisasterService(client: client).fetchLatest(),
          throwsA(
            isA<Exception>().having((e) => '$e', 'message', contains('503')),
          ),
        );
      },
    );

    test(
      'API failure does not repeat arbitrary provider messages containing a key',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'header': {
                'resultCode': '30',
                'resultMsg': 'invalid fake-test-key',
              },
            }),
            200,
          ),
        );
        addTearDown(client.close);
        await expectLater(
          DisasterService(client: client).fetchLatest(),
          throwsA(
            isA<Exception>().having(
              (e) => '$e',
              'message',
              isNot(contains('fake-test-key')),
            ),
          ),
        );
      },
    );

    test('stalled requests have a bounded timeout', () async {
      final waiting = Completer<http.Response>();
      final client = MockClient((_) => waiting.future);
      addTearDown(client.close);
      await expectLater(
        DisasterService(
          client: client,
          timeout: const Duration(milliseconds: 5),
        ).fetchLatest(),
        throwsA(isA<TimeoutException>()),
      );
      waiting.complete(response([], total: 0));
    });
  });

  group('DisasterService.identifierOf', () {
    test('숫자 SN을 문자열 식별자로 변환한다', () {
      expect(DisasterService.identifierOf({'SN': 301}), '301');
    });

    test('문자열 SN 앞뒤 공백을 제거한다', () {
      expect(DisasterService.identifierOf({'SN': ' 302 '}), '302');
    });

    test('SN이 없거나 비어 있으면 null을 반환한다', () {
      expect(DisasterService.identifierOf({}), isNull);
      expect(DisasterService.identifierOf({'SN': '  '}), isNull);
    });
  });

  group('DisasterService.selectLatest', () {
    test('응답이 오래된 순서여도 가장 최신 CRT_DT를 선택한다', () {
      final latest = DisasterService.selectLatest([
        {'SN': 100, 'CRT_DT': '2026/09/12 10:00:00', 'MSG_CN': '오래된 재난'},
        {'SN': 102, 'CRT_DT': '2026/09/14 15:30:00', 'MSG_CN': '최신 재난'},
        {'SN': 101, 'CRT_DT': '2026/09/13 12:00:00', 'MSG_CN': '중간 재난'},
      ]);

      expect(latest?['SN'], 102);
      expect(latest?['MSG_CN'], '최신 재난');
    });

    test('응답이 최신 순서여도 가장 최신 CRT_DT를 선택한다', () {
      final latest = DisasterService.selectLatest([
        {'SN': '202', 'CRT_DT': '2026-09-14 18:00:00'},
        {'SN': '201', 'CRT_DT': '2026-09-13 18:00:00'},
      ]);

      expect(latest?['SN'], '202');
    });

    test('CRT_DT가 같으면 더 큰 SN을 선택한다', () {
      final latest = DisasterService.selectLatest([
        {'SN': '300', 'CRT_DT': '2026/09/14 18:00:00'},
        {'SN': 301, 'CRT_DT': '2026/09/14 18:00:00'},
      ]);

      expect(latest?['SN'], 301);
    });

    test('현재 항목보다 오래된 재난은 최신으로 판단하지 않는다', () {
      final current = {'SN': 500, 'CRT_DT': '2026/09/20 10:00:00'};

      final older = {'SN': 499, 'CRT_DT': '2026/09/17 13:50:40'};

      final newer = {'SN': 501, 'CRT_DT': '2026/09/21 09:00:00'};

      expect(DisasterService.isNewerThan(older, current), isFalse);

      expect(DisasterService.isNewerThan(newer, current), isTrue);
    });

    test('잘못된 항목과 빈 목록을 안전하게 처리한다', () {
      final latest = DisasterService.selectLatest([
        null,
        'invalid',
        {'SN': 400, 'CRT_DT': '2026/09/14 19:00:00'},
      ]);

      expect(latest?['SN'], 400);
      expect(DisasterService.selectLatest([]), isNull);
    });
  });
}
