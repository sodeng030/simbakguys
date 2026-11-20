import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthExpiredException extends ApiException {
  const AuthExpiredException()
      : super('로그인 유효기간이 만료되었습니다. 다시 로그인해주세요.', statusCode: 401);
}

class ApiService {
  // Google ID Token / 서버 JWT를 전송하는 모든 요청은 반드시 HTTPS 사용.
  static const String baseUrl = 'https://simbakguys-api.duckdns.org';

  // 서버 인수인계서의 공개 Web OAuth Client ID. (비밀 키가 아님)
  static const String googleWebClientId =
      '900260706226-h17rsk68euk092n93prv6dl4jaaefc3a.apps.googleusercontent.com';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'server_access_token';
  static const String _sessionKey = 'server_session_profile';
  static const String _savedAtKey = 'server_session_saved_at';
  static const Duration _requestTimeout = Duration(seconds: 12);

  static String? _accessToken;
  static Map<String, dynamic>? _profile;
  static bool _expiredNotified = false;

  /// main.dart가 앱 전체를 로그인 화면으로 돌려보낼 때 사용.
  static void Function()? onAuthExpired;

  static bool get hasServerSession => _accessToken != null;
  static String? get currentUserType => _profile?['userType']?.toString();
  // 로그인한 사용자의 공개 프로필 정보만 반환합니다 (JWT 포함하지 않음).
  static Map<String, dynamic>? get currentProfile =>
      _profile == null ? null : Map<String, dynamic>.unmodifiable(_profile!);

  static Future<void> saveSession(Map<String, dynamic> response) async {
    final token = response['accessToken']?.toString();
    final uid = response['uid']?.toString();
    final userType = response['userType']?.toString();
    if (token == null || token.isEmpty || uid == null || uid.isEmpty ||
        !const ['DRIVER', 'MANAGER', 'FAMILY'].contains(userType)) {
      throw const ApiException('로그인 응답에 서버 JWT 또는 사용자 정보가 없습니다.');
    }

    final profile = <String, dynamic>{
      'uid': uid,
      'name': response['name']?.toString() ?? '',
      'email': response['email']?.toString() ?? '',
      'userType': userType,
    };

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _sessionKey, value: jsonEncode(profile));
    await _storage.write(
      key: _savedAtKey,
      value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
    _accessToken = token;
    _profile = profile;
    _expiredNotified = false;
  }

  static Future<Map<String, dynamic>?> restoreSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final profileJson = await _storage.read(key: _sessionKey);
      final savedAtRaw = await _storage.read(key: _savedAtKey);
      if (token == null || profileJson == null || savedAtRaw == null) {
        return null;
      }
      final profile = Map<String, dynamic>.from(jsonDecode(profileJson) as Map);
      final savedAt = int.tryParse(savedAtRaw);
      if (savedAt == null || _tokenHasExpired(token, savedAt)) {
        await clearSession();
        return null;
      }
      if (profile['uid'] == null || profile['userType'] == null) {
        await clearSession();
        return null;
      }
      _accessToken = token;
      _profile = profile;
      _expiredNotified = false;
      return profile;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  // JWT 서명 검증은 서버에서 한다. 앱에서는 만료 시각 판단에만 payload 사용.
  static bool _tokenHasExpired(String token, int savedAtMs) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (payload is Map && payload['exp'] is num) {
          final exp = (payload['exp'] as num).toInt();
          final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          return nowSeconds >= exp - 30;
        }
      }
    } catch (_) {
      // 알 수 없는 토큰 형식일 때는 문서에 기재된 60분 수명 이용.
    }
    return DateTime.now().toUtc().millisecondsSinceEpoch - savedAtMs >=
        const Duration(minutes: 59).inMilliseconds;
  }

  static Future<void> clearSession() async {
    _accessToken = null;
    _profile = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _savedAtKey);
  }

  static Future<void> _expireSession() async {
    if (_expiredNotified) return;
    _expiredNotified = true;
    await clearSession();
    onAuthExpired?.call();
  }

  static Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final token = _accessToken;
    if (requireAuth && (token == null || token.isEmpty)) {
      throw const ApiException('이 기능은 Google 계정으로 로그인한 후 사용할 수 있습니다.');
    }
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final uri = Uri.parse('$baseUrl$path');
      if (method == 'POST') {
        response = await http
            .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(_requestTimeout);
      } else {
        response = await http.get(uri, headers: headers).timeout(_requestTimeout);
      }
    } catch (_) {
      throw const ApiException('서버에 연결할 수 없습니다. 네트워크와 HTTPS 주소를 확인해주세요.');
    }

    if (response.statusCode == 401 && token != null) {
      await _expireSession();
      throw const AuthExpiredException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && data['detail'] != null) {
          final raw = data['detail'];
          detail = raw is String ? raw : jsonEncode(raw);
        }
      } catch (_) {}
      final code = response.statusCode;
      final message = switch (code) {
        400 => '잘못된 QR 코드 또는 요청입니다.',
        401 => '인증이 필요합니다. 다시 로그인해주세요.',
        403 => '이 작업을 수행할 권한이 없습니다.',
        404 => '요청한 정보를 찾지 못했습니다.',
        409 => '이미 사용된 QR 코드이거나 중복 요청입니다.',
        410 => 'QR 코드의 유효기간이 지났습니다. 새 코드를 발급해주세요.',
        _ => '서버 요청에 실패했습니다. (HTTP $code)',
      };
      throw ApiException(detail == null ? message : '$message\n$detail', statusCode: code);
    }
    return response;
  }

  static Map<String, dynamic> _readObject(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw const ApiException('서버 응답 형식이 올바르지 않습니다.');
    return Map<String, dynamic>.from(data);
  }

  static List<dynamic> _readList(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const ApiException('서버 목록 응답 형식이 올바르지 않습니다.');
    return data;
  }

  static Future<Map<String, dynamic>> getHealth() async =>
      _readObject(await _request('GET', '/health'));

  static Future<Map<String, dynamic>> googleLogin(String idToken) async =>
      _readObject(await _request('POST', '/api/v1/auth/google', body: {'idToken': idToken}));

  // 서버도 name 필드를 받아 users.name에 저장하도록 수정해야 합니다.
  // 서버가 name을 무시한다면 Google 계정 이름이 그대로 저장될 수 있습니다.
  static Future<Map<String, dynamic>> googleRegister(
    String idToken,
    String userType,
    String name,
  ) async =>
      _readObject(await _request('POST', '/api/v1/auth/google/register',
          body: {'idToken': idToken, 'userType': userType, 'name': name}));

  static Future<Map<String, dynamic>> getUser(String uid) async =>
      _readObject(await _request('GET', '/api/v1/users/${Uri.encodeComponent(uid)}'));

  /// Google 로그인 이후 공통 연결 목록 (운전자는 가족/관리자, 그 외는 운전자 목록).
  static Future<List<dynamic>> getMyConnections() async =>
      _readList(await _request('GET', '/api/v1/users/me/connections', requireAuth: true));

  /// 관리자/가족의 연결 운전자 목록. 서버 JWT로 자신의 연결만 조회합니다.
  /// 기존 화면과의 호환을 위해 uid 인자를 유지합니다.
  static Future<List<dynamic>> getConnectedDrivers(String uid) async {
    if (_profile?['uid']?.toString() != uid) {
      throw const ApiException('현재 로그인한 계정과 조회 대상 UID가 다릅니다.');
    }
    final connections = await getMyConnections();
    return connections.where((item) =>
        item is Map && item['userType']?.toString() == 'DRIVER').toList();
  }

  static Future<Map<String, dynamic>> issueQrToken() async =>
      _readObject(await _request('POST', '/api/v1/connections/qr-token', requireAuth: true));

  static Future<Map<String, dynamic>> acceptQrToken(String token) async =>
      _readObject(await _request('POST', '/api/v1/connections/accept',
          body: {'token': token}, requireAuth: true));

  static Future<Map<String, dynamic>> getDriverStatus(String uid) async =>
      _readObject(await _request('GET',
          '/api/v1/drivers/${Uri.encodeComponent(uid)}/replay-status'));

  static Future<List<dynamic>> getMeasurements(String uid, {int limit = 100}) async =>
      _readList(await _request('GET',
          '/api/v1/drivers/${Uri.encodeComponent(uid)}/measurements?limit=$limit'));

  static Future<List<dynamic>> getMeasurementsByDate(
    String uid,
    String date, {
    int limit = 500,
  }) async {
    final params = Uri(queryParameters: {
      'measurementDate': date,
      'limit': '$limit',
    }).query;
    return _readList(await _request('GET',
        '/api/v1/drivers/${Uri.encodeComponent(uid)}/measurements/by-date?$params'));
  }

  static Future<List<dynamic>> getEvents(String uid, {int limit = 100}) async =>
      _readList(await _request('GET',
          '/api/v1/drivers/${Uri.encodeComponent(uid)}/events?limit=$limit'));
}
