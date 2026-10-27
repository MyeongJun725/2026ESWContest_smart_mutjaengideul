import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class DisasterService {
  DisasterService({
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _now = now ?? DateTime.now;

  static const int _rowsPerPage = 100;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final Duration timeout;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>?> fetchLatest() async {
    final startDate = _formatDate(_now().subtract(const Duration(days: 2)));

    final primaryResponse = await _request(pageNo: 1, startDate: startDate);

    final candidates = <dynamic>[..._extractBody(primaryResponse)];

    final totalCount = _parseNumber(primaryResponse['totalCount']);

    final actualLastPage = totalCount <= 0
        ? 1
        : (totalCount / _rowsPerPage).ceil();

    // The API may return newest-first or oldest-first. Inspect both edges on
    // every poll; caching only the last page can hide new first-page alerts.
    if (actualLastPage > 1) {
      final latestPageResponse = await _request(
        pageNo: actualLastPage,
        startDate: startDate,
      );

      candidates.addAll(_extractBody(latestPageResponse));
    }

    return selectLatest(candidates);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year$month$day';
  }

  static List<dynamic> _extractBody(Map<String, dynamic> response) {
    final body = response['body'];

    if (body is! List) {
      return const [];
    }

    return body;
  }

  static String? identifierOf(Map<String, dynamic> disaster) {
    final value = disaster['SN'];

    if (value == null) {
      return null;
    }

    final identifier = value.toString().trim();
    return identifier.isEmpty ? null : identifier;
  }

  static bool isNewerThan(
    Map<String, dynamic> candidate,
    Map<String, dynamic> current,
  ) {
    return _compareDisasters(candidate, current) > 0;
  }

  static Map<String, dynamic>? selectLatest(List<dynamic> items) {
    Map<String, dynamic>? latest;

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      final candidate = Map<String, dynamic>.from(item);

      if (latest == null || _compareDisasters(candidate, latest) > 0) {
        latest = candidate;
      }
    }

    return latest;
  }

  static int _compareDisasters(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final dateComparison = _dateKey(
      left['CRT_DT'],
    ).compareTo(_dateKey(right['CRT_DT']));

    if (dateComparison != 0) {
      return dateComparison;
    }

    return _parseNumber(left['SN']).compareTo(_parseNumber(right['SN']));
  }

  static String _dateKey(dynamic value) {
    return value?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  }

  static int _parseNumber(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? -1;
  }

  Future<Map<String, dynamic>> _request({
    required int pageNo,
    required String startDate,
  }) async {
    final endpoint = Uri.parse(AppConfig.disasterApiUrl);
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'serviceKey': AppConfig.disasterApiKey,
        'returnType': 'json',
        'pageNo': pageNo.toString(),
        'numOfRows': _rowsPerPage.toString(),
        'crtDt': startDate,
      },
    );

    final response = await _client.get(uri).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('재난 API HTTP 오류: ${response.statusCode}');
    }

    final responseText = utf8.decode(response.bodyBytes);

    print('[재난 API] request page=$pageNo');
    print('[재난 API STATUS] ${response.statusCode}');

    final decoded = jsonDecode(responseText);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('재난 API 응답 형식 오류');
    }

    final header = decoded['header'];

    if (header is Map<String, dynamic>) {
      final resultCode = header['resultCode']?.toString();

      if (resultCode != '00') {
        throw Exception('재난 API 응답 오류: $resultCode');
      }
    }

    return decoded;
  }
}
