import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const configUrl = 'https://fnyunkr.oss-ap-northeast-2.aliyuncs.com/configt.json';

class V2Board {
  V2Board._();
  static final V2Board instance = V2Board._();
  final _client = http.Client();
  List<String> domains = [];
  String? baseUrl;
  String? authData;

  Future<void> loadDomains() async {
    final r = await _client.get(Uri.parse(configUrl)).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('无法读取域名配置（HTTP ${r.statusCode}）');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    domains = (data['domains'] as List).whereType<String>().map((e) => e.replaceAll(RegExp(r'/+$'), '')).toList();
    if (domains.isEmpty) throw Exception('域名配置为空');
  }

  Future<String> findAvailableDomain() async {
    if (domains.isEmpty) await loadDomains();
    for (final domain in domains) {
      try {
        final r = await _client.get(Uri.parse('$domain/api/v1/guest/comm/config')).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final body = jsonDecode(utf8.decode(r.bodyBytes));
          if (body is Map && body.containsKey('data')) {
            baseUrl = domain;
            return domain;
          }
        }
      } catch (_) {}
    }
    throw Exception('所有候选站点均无法连接，请检查网络或更新 OSS 域名配置');
  }

  Future<Map<String, dynamic>> request(String path, {String method = 'GET', Map<String, dynamic>? body, bool auth = false}) async {
    if (baseUrl == null) await findAvailableDomain();
    final uri = Uri.parse('$baseUrl/api/v1$path');
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (auth && authData != null) headers['Authorization'] = authData!;
    http.Response r;
    try {
      r = method == 'POST'
          ? await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15))
          : await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      baseUrl = null;
      await findAvailableDomain();
      return request(path, method: method, body: body, auth: auth);
    } catch (_) {
      baseUrl = null;
      await findAvailableDomain();
      return request(path, method: method, body: body, auth: auth);
    }
    dynamic decoded;
    try { decoded = jsonDecode(utf8.decode(r.bodyBytes)); } catch (_) { throw Exception('服务器返回了无法识别的数据（HTTP ${r.statusCode}）'); }
    if (r.statusCode < 200 || r.statusCode >= 300 || decoded is! Map || decoded['data'] == null) {
      final msg = decoded is Map ? (decoded['message'] ?? decoded['msg'] ?? '请求失败') : '请求失败';
      throw Exception('$msg（HTTP ${r.statusCode}）');
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<Map<String, dynamic>> login(String email, String password) => request('/passport/auth/login', method: 'POST', body: {'email': email, 'password': password});
  Future<Map<String, dynamic>> register(String email, String password) => request('/passport/auth/register', method: 'POST', body: {'email': email, 'password': password, 'email_code': '', 'invite_code': '', 'recaptcha_data': ''});
  Future<Map<String, dynamic>> getSubscribe() => request('/user/getSubscribe', auth: true);

  Future<String> fetchSubscription(String url) async {
    final uri = Uri.parse(url);
    final r = await _client.get(uri, headers: {'User-Agent': 'v2rayNG/1.8.29'}).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('订阅更新失败（HTTP ${r.statusCode}）');
    return utf8.decode(r.bodyBytes);
  }
}
