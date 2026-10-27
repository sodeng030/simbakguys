import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://211.233.215.66:8000';

  // ============================================================
  // 서버 상태
  // ============================================================

  static Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/health'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '서버 연결 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 임시 로그인
  // ============================================================

  static Future<Map<String, dynamic>> mockLogin(
    String uid,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/mock-login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'uid': uid,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '로그인 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 사용자 정보
  // ============================================================

  static Future<Map<String, dynamic>> getUser(
    String uid,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/users/$uid'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '사용자 조회 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 관리자 / 가족의 연결 운전자
  // ============================================================

  static Future<List<dynamic>> getConnectedDrivers(
    String uid,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/users/$uid/drivers',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '연결 운전자 조회 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 운전자 최신 상태
  // ============================================================

  static Future<Map<String, dynamic>> getDriverStatus(
    String uid,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/drivers/$uid/replay-status',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '운전자 상태 조회 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 운전자 전체 심박 기록
  // ============================================================

  static Future<List<dynamic>> getMeasurements(
    String uid, {
    int limit = 100,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/drivers/$uid/measurements?limit=$limit',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '심박 기록 조회 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 날짜별 심박 기록
  // ============================================================

  static Future<List<dynamic>> getMeasurementsByDate(
    String uid,
    String date, {
    int limit = 500,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/drivers/$uid/measurements/by-date'
        '?measurementDate=$date&limit=$limit',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '날짜별 기록 조회 실패: ${response.statusCode}',
    );
  }

  // ============================================================
  // 이벤트 조회
  // ============================================================

  static Future<List<dynamic>> getEvents(
    String uid, {
    int limit = 100,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/drivers/$uid/events?limit=$limit',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    }

    throw Exception(
      '이벤트 조회 실패: ${response.statusCode}',
    );
  }
}