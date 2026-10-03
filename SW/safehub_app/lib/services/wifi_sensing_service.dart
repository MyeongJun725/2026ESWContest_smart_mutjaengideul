import 'dart:convert';
import 'package:http/http.dart' as http;

/// Native UI control channel to the same-device CSI process.
/// Device-to-device MQTT topics are intentionally unchanged.
class WifiSensingService {
  WifiSensingService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<dynamic> _decode(Future<http.Response> request) async {
    final response = await request.timeout(const Duration(seconds: 5));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw StateError(body is Map ? '${body['error']}' : '센싱 서비스 오류');
    }
    return body;
  }

  Future<Map<String, dynamic>> state(Map<String, String> stages) async =>
      Map<String, dynamic>.from(
        await _decode(
          _client.get(
            Uri.parse('$baseUrl/state').replace(queryParameters: stages),
          ),
        ),
      );

  Future<List<dynamic>> ports() async => List<dynamic>.from(
    await _decode(_client.get(Uri.parse('$baseUrl/ports'))),
  );

  Future<Map<String, dynamic>> command(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async => Map<String, dynamic>.from(
    await _decode(
      _client.post(
        Uri.parse('$baseUrl/command/$action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ),
    ),
  );

  void close() => _client.close();
}
