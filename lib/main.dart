import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
Future<void>? _googleInitialization;

Future<void> initializeGoogleSignIn() {
  return _googleInitialization ??= GoogleSignIn.instance.initialize(
    serverClientId: ApiService.googleWebClientId,
  );
}

Widget homeForUser(Map<String, dynamic> user) {
  final uid = user['uid']?.toString() ?? '';
  final name = user['name']?.toString() ?? '';
  switch (user['userType']?.toString()) {
    case 'DRIVER':
      return DriverStatusScreen(uid: uid, userName: name);
    case 'MANAGER':
      return AdminHomeScreen(uid: uid, userName: name);
    case 'FAMILY':
      return FamilyHomeScreen(uid: uid, userName: name);
    default:
      throw const ApiException('알 수 없는 사용자 유형입니다.');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  ApiService.onAuthExpired = () {
    // HTTP 401 발생 시 서버 JWT를 제거한 뒤 재로그인 화면으로 복귀.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  };
  runApp(const HeartMonitorApp());
}

// ============================================================
// APP
// ============================================================

class HeartMonitorApp extends StatelessWidget {
  const HeartMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      title: '심박한 녀석들',

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 64),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(60, 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 20),
          hintStyle: TextStyle(fontSize: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        ),
        listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),

      // 유효한 서버 JWT가 있으면 기존 세션 복원, 없으면 로그인.
      home: const StartupScreen(),
    );
  }
}

// ============================================================
// 공통 반응형 레이아웃
// 세로 모드에서는 기존 화면 구성을 유지하고,
// 가로 모드/키보드 등장으로 화면이 낮아지면 스크롤을 허용합니다.
// ============================================================

class ResponsiveScreenBody extends StatelessWidget {
  final Widget Function(bool compact) builder;
  final double maxWidth;

  const ResponsiveScreenBody({
    super.key,
    required this.builder,
    this.maxWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 740;
          final content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: builder(compact),
            ),
          );

          return compact
              ? SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                )
              : content;
        },
      ),
    );
  }
}

// ============================================================
// 심박한 녀석들: 홈 화면 상단의 심플한 브랜드 표시
// ============================================================

class SimbakguysBrandHeader extends StatelessWidget {
  const SimbakguysBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/simbakguys_symbol.png',
          width: 38,
          height: 38,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        const Text(
          '심박한 녀석들',
          style: TextStyle(
            color: Color(0xFF5D2389),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 공통 상단 설정 버튼: 현재 로그인한 계정의 설정만 엽니다.
// 운전자 상세 조회 중에도 조회 대상 운전자의 계정으로 바뀌지 않습니다.
// ============================================================

class CurrentAccountSettingsButton extends StatelessWidget {
  const CurrentAccountSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ApiService.currentProfile;
    if (profile == null) return const SizedBox.shrink();

    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsScreen(
              uid: profile['uid']?.toString() ?? '',
              userName: profile['name']?.toString() ?? '',
              userType: profile['userType']?.toString() ?? '',
            ),
          ),
        );
      },
      child: const Text(
        '설정',
        style: TextStyle(fontSize: 24, color: Colors.black),
      ),
    );
  }
}

// ============================================================
// 공통 함수
// ============================================================

const int minHeartRate = 60;
const int maxHeartRate = 100;

String signalStatusToKorean(dynamic value) {
  switch (value?.toString()) {
    case 'GOOD':
      return '양호';

    case 'FAIR':
      return '불안정';

    case 'UNKNOWN':
      return '미확인';

    default:
      return '미확인';
  }
}

String deviceStatusToKorean(dynamic value) {
  switch (value?.toString()) {
    case 'CONNECTED':
      return '연결됨';

    case 'DISCONNECTED':
      return '연결 끊김';

    case 'UNKNOWN':
      return '미확인';

    default:
      return '미확인';
  }
}

String formatTime(dynamic value) {
  if (value == null) {
    return '--:--';
  }

  try {
    final dateTime = DateTime.parse(
      value.toString(),
    ).toLocal();

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  } catch (_) {
    return '--:--';
  }
}

String formatTimeWithSeconds(dynamic value) {
  if (value == null) {
    return '--:--:--';
  }

  try {
    final dateTime =
        DateTime.parse(value.toString()).toLocal();

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    final second =
        dateTime.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  } catch (_) {
    return '--:--:--';
  }
}

String formatDateHour(dynamic value) {
  if (value == null) {
    return '';
  }

  try {
    final dateTime = DateTime.parse(
      value.toString(),
    ).toLocal();

    final year =
        (dateTime.year % 100)
            .toString()
            .padLeft(2, '0');

    final month =
        dateTime.month.toString().padLeft(2, '0');

    final day =
        dateTime.day.toString().padLeft(2, '0');

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    return '$year.$month.$day $hour:00';
  } catch (_) {
    return '';
  }
}

bool isHeartRateInRange(int? bpm) {
  if (bpm == null) {
    return false;
  }

  return bpm >= minHeartRate &&
      bpm <= maxHeartRate;
}

String getDriverSummaryStatus(
  Map<String, dynamic> driver,
) {
  if (driver['deviceStatus'] == 'DISCONNECTED') {
    return '연결 끊김';
  }

  if (driver['signalQuality'] == 'FAIR') {
    return '신호 불안정';
  }

  final dynamic rawBpm = driver['heartRate'];

  if (rawBpm == null) {
    return '측정 불가';
  }

  final int bpm = (rawBpm as num).toInt();

  if (!isHeartRateInRange(bpm)) {
    return '확인 필요';
  }

  return '정상';
}

// ============================================================
// 서버 JWT 세션 복원
// ============================================================

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await ApiService.restoreSession();
    if (!mounted) return;
    Widget next = const LoginScreen();
    if (session != null) {
      try {
        next = homeForUser(session);
      } catch (_) {
        await ApiService.clearSession();
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/simbakguys_logo.png',
              width: 250,
              height: 185,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 로그인 화면
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  String? errorMessage;

  Future<void> _googleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      await initializeGoogleSignIn();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const ApiException('이 예제의 Google 로그인 버튼은 Android/iOS에서 지원됩니다.');
      }

      // 같은 디바이스에서 다른 계정으로 재로그인할 수 있게 계정 선택 초기화.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException('Google ID Token을 받지 못했습니다. OAuth 설정을 확인해주세요.');
      }
      final response = await ApiService.googleLogin(idToken);
      if (!mounted) return;
      if (response['isNewUser'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleRegisterScreen(idToken: idToken),
          ),
        );
      } else {
        await ApiService.saveSession(response);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => homeForUser(response)),
        );
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => errorMessage = 'Google 로그인 실패: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = 'Google 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                // 화면이 넉넉하면 내용 전체를 세로 중앙에 배치하고,
                // 키보드가 나타나거나 화면이 좁아지면 스크롤을 허용합니다.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/simbakguys_logo.png',
                          width: 300,
                          height: 225,
                          fit: BoxFit.contain,
                          semanticLabel: '심박한 녀석들 로고',
                        ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          height: 78,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : _googleLogin,
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Google 계정으로 로그인',
                                    style: TextStyle(fontSize: 24),
                                  ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// Google 신규 가입: 서버 userType 선택 후 JWT 발급
// ============================================================

class GoogleRegisterScreen extends StatefulWidget {
  final String idToken;

  const GoogleRegisterScreen({
    super.key,
    required this.idToken,
  });

  @override
  State<GoogleRegisterScreen> createState() => _GoogleRegisterScreenState();
}

class _GoogleRegisterScreenState extends State<GoogleRegisterScreen> {
  String userType = 'DRIVER';
  final TextEditingController nameController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final enteredName = nameController.text.trim();
    if (enteredName.isEmpty) {
      setState(() => errorMessage = '사용할 이름을 입력해주세요.');
      return;
    }
    if (enteredName.length > 30) {
      setState(() => errorMessage = '이름은 30자 이내로 입력해주세요.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.googleRegister(
        widget.idToken,
        userType,
        enteredName,
      );
      await ApiService.saveSession(result);
      if (!mounted) return;

      // 이전 버전 서버는 name 요청 값을 무시할 수 있습니다.
      // 원격 연결 목록의 이름은 서버 DB 기준이므로 로컬에서 조용히 덮어쓰지 않습니다.
      final serverName = result['name']?.toString().trim() ?? '';
      if (serverName != enteredName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text('가입은 완료되었지만 서버 응답의 이름이 다릅니다. 서버 담당자에게 name 저장과 응답 처리를 확인해주세요.'),
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => homeForUser(result)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = '회원가입 실패: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ResponsiveScreenBody(
        builder: (compact) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('사용자 정보 입력',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '앱에서 사용할 이름을 입력해주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('사용자 유형 선택',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            RadioListTile<String>(
              value: 'DRIVER',
              groupValue: userType,
              title: const Text('운전자', style: TextStyle(fontSize: 24)),
              onChanged: isLoading ? null : (v) => setState(() => userType = v!),
            ),
            RadioListTile<String>(
              value: 'MANAGER',
              groupValue: userType,
              title: const Text('관리자', style: TextStyle(fontSize: 24)),
              onChanged: isLoading ? null : (v) => setState(() => userType = v!),
            ),
            RadioListTile<String>(
              value: 'FAMILY',
              groupValue: userType,
              title: const Text('가족', style: TextStyle(fontSize: 24)),
              onChanged: isLoading ? null : (v) => setState(() => userType = v!),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            if (compact) const SizedBox(height: 28) else const Spacer(),
            SizedBox(
              height: 78,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoading ? null : _register,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('가입 완료', style: TextStyle(fontSize: 24)),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 운전자 화면
// ============================================================

enum HeartDisplayState {
  checking,
  stable,
  warning,
}

class DriverStatusScreen extends StatefulWidget {
  final String uid;
  final String userName;
  // 가족·관리자가 운전자 상태를 확인할 때 true.
  final bool isRemote;
  // 기존 권한 설정 유지: 가족은 이력 가능, 관리자는 기존처럼 상태만 확인.
  final bool allowHistory;

  const DriverStatusScreen({
    super.key,
    required this.uid,
    required this.userName,
    this.isRemote = false,
    this.allowHistory = true,
  });

  @override
  State<DriverStatusScreen> createState() =>
      _DriverStatusScreenState();
}

class _DriverStatusScreenState
    extends State<DriverStatusScreen> {
  static const int stableCheckSeconds = 10;
  static const int updateIntervalSeconds = 1;

  int? heartRate;

  String signalStatus = '확인 중';
  String deviceStatus = '확인 중';
  String lastMeasuredTime = '--:--';

  int inRangeSeconds = 0;

  HeartDisplayState displayState =
      HeartDisplayState.checking;

  Timer? statusTimer;

  bool isLoading = true;
  bool isFetching = false;

  String? lastMeasurementTimeRaw;

  @override
  void initState() {
    super.initState();

    _fetchDriverStatus();

    statusTimer = Timer.periodic(
      const Duration(
        seconds: updateIntervalSeconds,
      ),
      (_) {
        _fetchDriverStatus();
      },
    );
  }

  Future<void> _fetchDriverStatus() async {
    if (isFetching) {
      return;
    }

    isFetching = true;

    try {
      final data =
          await ApiService.getDriverStatus(
        widget.uid,
      );

      if (!mounted) {
        return;
      }

      int? newHeartRate;

      final dynamic rawHeartRate =
          data['heartRate'];

      if (rawHeartRate is num) {
        newHeartRate =
            rawHeartRate.toInt();
      }

      final String newSignalStatus =
          signalStatusToKorean(
        data['signalQuality'],
      );

      final String newDeviceStatus =
          deviceStatusToKorean(
        data['deviceStatus'],
      );

      final String newMeasuredTime =
          formatTime(
        data['measurementTime'],
      );

      final String? newMeasurementTimeRaw =
          data['measurementTime']?.toString();

      final bool isNewMeasurement =
          newMeasurementTimeRaw != null &&
          newMeasurementTimeRaw != lastMeasurementTimeRaw;

      setState(() {
        heartRate = newHeartRate;
        signalStatus = newSignalStatus;
        deviceStatus = newDeviceStatus;
        lastMeasuredTime = newMeasuredTime;

        isLoading = false;

        // 서버에서 실제로 새로운 측정값이 들어온 경우에만
        // 안정 상태 판정을 진행
        if (isNewMeasurement) {
          lastMeasurementTimeRaw =
              newMeasurementTimeRaw;

          _updateHeartDisplayState(
            newHeartRate,
          );
        }
      });
    } catch (e) {
      debugPrint(
        '운전자 상태 조회 실패: $e',
      );

      if (mounted) {
        setState(() {
          isLoading = false;
          if (e is ApiException && e.statusCode == 404) {
            // 현재 UID에 해당하는 측정 기록이 없는 경우입니다.
            // 사용자를 방해하는 경고 없이 미측정 상태만 보여줍니다.
            heartRate = null;
            lastMeasuredTime = '--:--';
            lastMeasurementTimeRaw = null;
            inRangeSeconds = 0;
            displayState = HeartDisplayState.checking;
            signalStatus = '미확인';
            deviceStatus = '미확인';
          } else {
            // 실제 네트워크/서버 오류는 콘솔에 남기고 상태만 표시합니다.
            signalStatus = '조회 실패';
            deviceStatus = '확인 불가';
          }
        });
      }
    } finally {
      isFetching = false;
    }
  }

  void _updateHeartDisplayState(
    int? value,
  ) {
    if (value == null) {
      inRangeSeconds = 0;

      displayState =
          HeartDisplayState.checking;

      return;
    }

    final bool inRange =
        isHeartRateInRange(value);

    // 범위 밖이면 바로 경고
    if (!inRange) {
      inRangeSeconds = 0;

      displayState =
          HeartDisplayState.warning;

      return;
    }

    // 이미 안정 상태면 유지
    if (displayState ==
        HeartDisplayState.stable) {
      return;
    }

    // 다시 정상 범위로 들어왔으면
    // 시간을 다시 누적
    inRangeSeconds +=
        updateIntervalSeconds;

    if (inRangeSeconds >=
        stableCheckSeconds) {
      inRangeSeconds =
          stableCheckSeconds;

      displayState =
          HeartDisplayState.stable;
    } else {
      displayState =
          HeartDisplayState.checking;
    }
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    super.dispose();
  }

  Widget _buildHeartRateText() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Text(
          '${heartRate ?? '--'}',
          style: const TextStyle(
            fontSize: 98,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),

        const SizedBox(width: 8),

        const Padding(
          padding:
              EdgeInsets.only(bottom: 10),
          child: Text(
            'bpm',
            style: TextStyle(
              fontSize: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeartDisplay() {
    if (isLoading) {
      return const CircularProgressIndicator();
    }

    if (heartRate == null) {
      return const Text(
        '측정 불가',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    switch (displayState) {
      case HeartDisplayState.checking:
        return _buildHeartRateText();

      case HeartDisplayState.stable:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '😊',
              style: TextStyle(
                fontSize: 88,
                height: 1,
              ),
            ),

            SizedBox(height: 8),

            Text(
              '안정 범위',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case HeartDisplayState.warning:
        return _buildHeartRateText();
    }
  }

  Color _getBackgroundColor() {
    switch (displayState) {
      case HeartDisplayState.checking:
        return Colors.white;

      case HeartDisplayState.stable:
        return const Color.fromARGB(
          255,
          193,
          225,
          156,
        );

      case HeartDisplayState.warning:
        return const Color.fromARGB(
          255,
          255,
          222,
          132,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _getBackgroundColor(),
      appBar: widget.isRemote
          ? AppBar(
              title: Text(widget.userName.isEmpty ? '운전자 상태' : widget.userName),
              backgroundColor: _getBackgroundColor(),
              actions: const [CurrentAccountSettingsButton()],
            )
          : null,

      body: ResponsiveScreenBody(
        builder: (compact) => Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 20,
          ),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              // 브랜드 로고 (운전자 본인 및 원격 조회 화면에 동일 적용)
              const Align(
                alignment: Alignment.centerLeft,
                child: SimbakguysBrandHeader(),
              ),
              const SizedBox(height: 8),
              // 상단
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Text(
                    '최근 측정 $lastMeasuredTime',
                    style: const TextStyle(
                      fontSize: 24,
                    ),
                  ),

                  // 자기 화면은 기존 상단 Row, 원격 화면은 AppBar 오른쪽에 표시.
                  if (!widget.isRemote)
                    const CurrentAccountSettingsButton(),
                ],
              ),

              if (compact) const SizedBox(height: 24) else const Spacer(flex: 2),

              // 심박 표시
              SizedBox(
                height: 164,
                child: Center(
                  child:
                      _buildHeartDisplay(),
                ),
              ),

              if (compact) const SizedBox(height: 24) else const Spacer(),

              // 상태 정보
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        const Text(
                          '신호 상태',
                          style: TextStyle(
                            fontSize: 26,
                          ),
                        ),

                        Text(
                          signalStatus,
                          style:
                              const TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        const Text(
                          '장치 상태',
                          style: TextStyle(
                            fontSize: 26,
                          ),
                        ),

                        Text(
                          deviceStatus,
                          style:
                              const TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),

              if (compact) const SizedBox(height: 24) else const Spacer(flex: 2),

              // 상세 기록
              if (widget.allowHistory)
                SizedBox(
                width: double.infinity,
                height: 78,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailRecordScreen(
                          driverUid:
                              widget.uid,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    '상세 기록 보기',
                    style: TextStyle(
                      fontSize: 24,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 상세 심박 기록
// ============================================================

class DetailRecordScreen extends StatefulWidget {
  final String driverUid;

  const DetailRecordScreen({
    super.key,
    required this.driverUid,
  });

  @override
  State<DetailRecordScreen> createState() =>
      _DetailRecordScreenState();
}

class _DetailRecordScreenState
    extends State<DetailRecordScreen> {
  List<Map<String, dynamic>> records = [];

  bool isLoading = true;
  String? errorMessage;

  late DateTime selectedMonth;
  late DateTime selectedDate;

  final ScrollController dateScrollController =
      ScrollController();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedMonth =
        DateTime(now.year, now.month);

    selectedDate =
        DateTime(now.year, now.month, now.day);

    _loadRecordsForDate();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _scrollToSelectedDay();
      },
    );
  }

  // ------------------------------------------------------------
  // 날짜 문자열 YYYY-MM-DD
  // ------------------------------------------------------------

  String _dateToString(DateTime date) {
    final year =
        date.year.toString();

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ------------------------------------------------------------
  // 선택 날짜 데이터 불러오기
  // ------------------------------------------------------------

  Future<void> _loadRecordsForDate() async {
    final requestedDate =
        _dateToString(selectedDate);

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result =
          await ApiService.getMeasurementsByDate(
        widget.driverUid,
        requestedDate,
        limit: 500,
      );

      if (!mounted) {
        return;
      }

      // 사용자가 데이터를 불러오는 동안
      // 다른 날짜를 선택했다면 이전 응답 무시
      if (requestedDate !=
          _dateToString(selectedDate)) {
        return;
      }

      final converted = result
          .map(
            (item) =>
                Map<String, dynamic>.from(
              item as Map,
            ),
          )
          .toList();

      // 서버는 최신 → 과거 순서
      // 화면에서는 과거 → 최신 순서로 표시
      final chronological =
          converted.reversed.toList();

      setState(() {
        records = chronological;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // ------------------------------------------------------------
  // 해당 월의 날짜 수
  // ------------------------------------------------------------

  int _daysInMonth(
    int year,
    int month,
  ) {
    return DateTime(
      year,
      month + 1,
      0,
    ).day;
  }

  // ------------------------------------------------------------
  // 월/년 변경
  // ------------------------------------------------------------

  void _changeMonth({
    int? year,
    int? month,
  }) {
    final newYear =
        year ?? selectedMonth.year;

    final newMonth =
        month ?? selectedMonth.month;

    final maxDay =
        _daysInMonth(
      newYear,
      newMonth,
    );

    final newDay =
        selectedDate.day > maxDay
            ? maxDay
            : selectedDate.day;

    setState(() {
      selectedMonth =
          DateTime(
        newYear,
        newMonth,
      );

      selectedDate =
          DateTime(
        newYear,
        newMonth,
        newDay,
      );
    });

    _loadRecordsForDate();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _scrollToSelectedDay();
      },
    );
  }

  // ------------------------------------------------------------
  // 날짜 선택
  // ------------------------------------------------------------

  void _selectDay(int day) {
    final newDate =
        DateTime(
      selectedMonth.year,
      selectedMonth.month,
      day,
    );

    if (newDate == selectedDate) {
      return;
    }

    setState(() {
      selectedDate = newDate;
    });

    _loadRecordsForDate();
  }

  // ------------------------------------------------------------
  // 현재 선택된 날짜가 보이도록 가로 스크롤
  // ------------------------------------------------------------

  void _scrollToSelectedDay() {
    if (!dateScrollController.hasClients) {
      return;
    }

    const itemWidth = 68.0;

    final rawOffset =
        (selectedDate.day - 1) *
                itemWidth -
            120;

    final targetOffset =
        rawOffset.clamp(
      0.0,
      dateScrollController
          .position.maxScrollExtent,
    ).toDouble();

    dateScrollController.animateTo(
      targetOffset,
      duration:
          const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ------------------------------------------------------------
  // 요일
  // ------------------------------------------------------------

  String _weekdayText(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      case DateTime.sunday:
        return '일';
      default:
        return '';
    }
  }

  // ------------------------------------------------------------
  // 년 / 월 선택 영역
  // ------------------------------------------------------------

  Widget _buildMonthSelector() {
    final currentYear =
        DateTime.now().year;

    final years =
        List<int>.generate(
      6,
      (index) =>
          currentYear - 3 + index,
    );

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: selectedMonth.year,
          underline: const SizedBox(),
          style: const TextStyle(
            fontSize: 26,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
          items: years
              .map(
                (year) =>
                    DropdownMenuItem<int>(
                  value: year,
                  child:
                      Text('$year년'),
                ),
              )
              .toList(),
          onChanged: (year) {
            if (year != null) {
              _changeMonth(
                year: year,
              );
            }
          },
        ),

        const SizedBox(width: 25),

        DropdownButton<int>(
          value: selectedMonth.month,
          underline: const SizedBox(),
          style: const TextStyle(
            fontSize: 26,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
          items:
              List.generate(
            12,
            (index) {
              final month =
                  index + 1;

              return DropdownMenuItem<int>(
                value: month,
                child:
                    Text('$month월'),
              );
            },
          ),
          onChanged: (month) {
            if (month != null) {
              _changeMonth(
                month: month,
              );
            }
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // 가로 날짜 선택 영역
  // ------------------------------------------------------------

  Widget _buildDateSelector() {
    final days =
        _daysInMonth(
      selectedMonth.year,
      selectedMonth.month,
    );

    return SizedBox(
      height: 90,
      child: ListView.builder(
        controller:
            dateScrollController,
        scrollDirection:
            Axis.horizontal,
        itemCount: days,
        itemBuilder:
            (context, index) {
          final day =
              index + 1;

          final date =
              DateTime(
            selectedMonth.year,
            selectedMonth.month,
            day,
          );

          final selected =
              selectedDate.year ==
                      date.year &&
                  selectedDate.month ==
                      date.month &&
                  selectedDate.day ==
                      date.day;

          return GestureDetector(
            onTap: () {
              _selectDay(day);
            },
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 150,
              ),
              width: 60,
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.black
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.black
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayText(date),
                    style: TextStyle(
                      fontSize: 16,
                      color: selected
                          ? Colors.white70
                          : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // 날짜별 기록: 기존 세로 목록 대신 가로 스크롤 선그래프
  // ------------------------------------------------------------

  Widget _buildRecordList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          '기록을 불러오지 못했습니다.\n\n$errorMessage',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (records.isEmpty) {
      return Center(
        child: Text(
          '${selectedDate.month}월 ${selectedDate.day}일의\n'
          '측정 기록이 없습니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, height: 1.5),
        ),
      );
    }

    return _HeartRateHistoryGraph(
      key: ValueKey(_dateToString(selectedDate)),
      records: records,
    );
  }

  @override
  void dispose() {
    dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 기록'),
        actions: const [CurrentAccountSettingsButton()],
      ),

      body: ResponsiveScreenBody(
        maxWidth: 760,
        builder: (compact) => Padding(
          padding:
              const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),

        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // 년 / 월
            _buildMonthSelector(),

            const SizedBox(height: 8),

            // 날짜 가로 스크롤
            _buildDateSelector(),

            const SizedBox(height: 12),

            const Divider(),

            const SizedBox(height: 8),

            // 선택된 날짜
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                '${selectedDate.year}년 '
                '${selectedDate.month}월 '
                '${selectedDate.day}일',
                style:
                    const TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 심박 기록 그래프 (가로 스크롤)
            if (compact)
              SizedBox(height: 320, child: _buildRecordList())
            else
              Expanded(child: _buildRecordList()),

            const SizedBox(height: 12),

            SizedBox(
              width:
                  double.infinity,
              height: 78,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child:
                    const Text(
                  '현재 심박 보기',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }
}

// ============================================================
// 상세 기록의 심박 선그래프
// 추가 패키지 없이 Flutter CustomPainter로 구현합니다.
// 위쪽 연·월/일 선택 UI는 변경하지 않습니다.
// ============================================================

class _HeartRateChartEntry {
  final DateTime? time;
  final int? bpm;

  _HeartRateChartEntry(Map<String, dynamic> record)
      : time = DateTime.tryParse(
          record['measurementTime']?.toString() ?? '',
        )?.toLocal(),
        bpm = record['heartRate'] is num
            ? (record['heartRate'] as num).toInt()
            : int.tryParse(record['heartRate']?.toString() ?? '');

  String get timeLabel {
    final value = time;
    if (value == null) return '--:--:--';
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final s = value.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _HeartRateHistoryGraph extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const _HeartRateHistoryGraph({
    super.key,
    required this.records,
  });

  @override
  State<_HeartRateHistoryGraph> createState() =>
      _HeartRateHistoryGraphState();
}

class _HeartRateHistoryGraphState extends State<_HeartRateHistoryGraph> {
  static const double _leftInset = 52;
  static const double _rightInset = 26;
  static const double _pointSpacing = 48;

  final ScrollController _horizontalScrollController = ScrollController();
  int? _selectedIndex;

  late List<_HeartRateChartEntry> _entries;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didUpdateWidget(covariant _HeartRateHistoryGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.records, widget.records)) {
      _loadEntries();
      _selectedIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _horizontalScrollController.hasClients) {
          _horizontalScrollController.jumpTo(0);
        }
      });
    }
  }

  void _loadEntries() {
    _entries = widget.records
        .map(_HeartRateChartEntry.new)
        .toList()
      ..sort((a, b) {
        if (a.time == null && b.time == null) return 0;
        if (a.time == null) return 1;
        if (b.time == null) return -1;
        return a.time!.compareTo(b.time!);
      });
  }

  void _selectAtX(double x) {
    if (_entries.isEmpty) return;
    final rawIndex = (x - _leftInset) / _pointSpacing;
    final nearest = rawIndex.round().clamp(0, _entries.length - 1).toInt();

    // 터치한 위치에서 가장 가까운 측정 지점을 선택합니다.
    if ((x - (_leftInset + nearest * _pointSpacing)).abs() > 30) {
      return;
    }
    if (_selectedIndex != nearest) {
      setState(() => _selectedIndex = nearest);
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null ||
            _selectedIndex! >= _entries.length
        ? null
        : _entries[_selectedIndex!];

    final valueText = selected == null
        ? '그래프의 점을 누르면 심박수와 시간을 볼 수 있습니다.'
        : '${selected.timeLabel}  ·  '
            '${selected.bpm == null ? '측정 불가' : '${selected.bpm} bpm'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text(
                '심박수 변화',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.swipe, size: 19, color: Colors.grey),
              const SizedBox(width: 5),
              const Text(
                '좌우로 이동',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            valueText,
            maxLines: 2,
            style: TextStyle(
              fontSize: selected == null ? 14 : 20,
              fontWeight:
                  selected == null ? FontWeight.normal : FontWeight.w600,
              color: selected == null ? Colors.black54 : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                _leftInset + _rightInset +
                    (_entries.length - 1) * _pointSpacing,
              );

              return SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _selectAtX(details.localPosition.dx),
                    onLongPressStart: (details) =>
                        _selectAtX(details.localPosition.dx),
                    onLongPressMoveUpdate: (details) =>
                        _selectAtX(details.localPosition.dx),
                    child: CustomPaint(
                      painter: _HeartRateChartPainter(
                        entries: _entries,
                        selectedIndex: _selectedIndex,
                        leftInset: _leftInset,
                        rightInset: _rightInset,
                        pointSpacing: _pointSpacing,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '가로 간격은 측정 순서 기준이며, 시간은 실제 측정 시각입니다.',
          maxLines: 2,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _HeartRateChartPainter extends CustomPainter {
  static const Color _lineColor = Color(0xFF248775);
  static const Color _gridColor = Color(0xFFE3E7E6);

  final List<_HeartRateChartEntry> entries;
  final int? selectedIndex;
  final double leftInset;
  final double rightInset;
  final double pointSpacing;

  _HeartRateChartPainter({
    required this.entries,
    required this.selectedIndex,
    required this.leftInset,
    required this.rightInset,
    required this.pointSpacing,
  });

  void _text(
    Canvas canvas,
    String value,
    Offset position, {
    double fontSize = 12,
    Color color = Colors.black54,
    FontWeight weight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const double chartTop = 12;
    final chartBottom = math.max(chartTop + 24, size.height - 46);
    final chartHeight = chartBottom - chartTop;

    final validValues = entries
        .where((entry) => entry.bpm != null)
        .map((entry) => entry.bpm!)
        .toList();

    // 정상값 기준 범위를 포함하되, 실제 데이터의 최솟값/최댓값에 맞춰 확장합니다.
    double lower = 60;
    double upper = 100;
    if (validValues.isNotEmpty) {
      final minValue = validValues.reduce(math.min);
      final maxValue = validValues.reduce(math.max);
      lower = math.min(60, ((minValue - 8) / 10).floor() * 10).toDouble();
      upper = math.max(100, ((maxValue + 8) / 10).ceil() * 10).toDouble();
      lower = math.max(0.0, lower);
    }
    if (upper <= lower) upper = lower + 20;

    double xAt(int index) => leftInset + index * pointSpacing;
    double yAt(int bpm) => chartBottom -
        (bpm - lower) / (upper - lower) * chartHeight;

    // BPM 눈금 및 수평 안내선
    for (var tick = 0; tick <= 4; tick++) {
      final y = chartTop + chartHeight * tick / 4;
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(size.width - rightInset, y),
        Paint()
          ..color = _gridColor
          ..strokeWidth = 1,
      );
      final bpmLabel = (upper - (upper - lower) * tick / 4).round();
      _text(canvas, '$bpmLabel', Offset(5, y - 8), fontSize: 12);
    }

    // 중간에 heartRate가 null인 구간은 연결하지 않습니다.
    final line = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    bool isContinuous = false;
    for (var i = 0; i < entries.length; i++) {
      final bpm = entries[i].bpm;
      if (bpm == null) {
        isContinuous = false;
        continue;
      }
      final dx = xAt(i);
      final dy = yAt(bpm);
      if (isContinuous) {
        path.lineTo(dx, dy);
      } else {
        path.moveTo(dx, dy);
        isContinuous = true;
      }
    }
    canvas.drawPath(path, line);

    // 실제 측정 지점의 점 표시
    final dotFill = Paint()..color = _lineColor;
    for (var i = 0; i < entries.length; i++) {
      final bpm = entries[i].bpm;
      if (bpm == null) continue;
      canvas.drawCircle(Offset(xAt(i), yAt(bpm)), 3.6, dotFill);
    }

    // 시간축은 실제 측정 시각으로 표기합니다.
    final labelInterval = math.max(1, (135 / pointSpacing).ceil());
    for (var i = 0; i < entries.length; i += labelInterval) {
      _text(
        canvas,
        entries[i].timeLabel,
        Offset(math.max(0.0, xAt(i) - 33), chartBottom + 12),
        fontSize: 12,
      );
    }

    if (validValues.isEmpty) {
      _text(
        canvas,
        '유효한 심박 측정값이 없습니다.',
        Offset(leftInset + 8, chartTop + chartHeight / 2),
        fontSize: 15,
      );
    }

    // 선택한 지점 강조 + 지점 부근 BPM 툴팁 표시
    final index = selectedIndex;
    if (index == null || index < 0 || index >= entries.length) return;
    final entry = entries[index];
    final x = xAt(index);
    final y = entry.bpm == null ? chartBottom : yAt(entry.bpm!);
    canvas.drawLine(
      Offset(x, chartTop),
      Offset(x, chartBottom),
      Paint()
        ..color = _lineColor.withAlpha(110)
        ..strokeWidth = 1.5,
    );
    if (entry.bpm != null) {
      canvas.drawCircle(Offset(x, y), 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        7.5,
        Paint()
          ..color = _lineColor
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }

    final detail = entry.bpm == null ? '측정 불가' : '${entry.bpm} bpm';
    final tooltipX =
        (x - 54).clamp(0.0, math.max(0.0, size.width - 108)).toDouble();
    final tooltipY = y - 68 >= 0
        ? y - 68
        : math.min(y + 16, math.max(0.0, chartBottom - 62));
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, 108, 52),
      const Radius.circular(10),
    );
    canvas.drawRRect(bubble, Paint()..color = const Color(0xFF243C38));
    _text(
      canvas,
      entry.timeLabel,
      Offset(tooltipX + 10, tooltipY + 7),
      fontSize: 13,
      color: Colors.white70,
    );
    _text(
      canvas,
      detail,
      Offset(tooltipX + 10, tooltipY + 25),
      fontSize: 16,
      color: Colors.white,
      weight: FontWeight.w600,
    );
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.pointSpacing != pointSpacing;
  }
}

// ============================================================
// 설정
// ============================================================

class SettingsScreen
    extends StatelessWidget {
  final String uid;
  final String userName;
  final String userType;

  const SettingsScreen({
    super.key,
    required this.uid,
    required this.userName,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),

      body: ResponsiveScreenBody(
        builder: (compact) => Padding(
          padding:
              const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 20,
        ),

        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              '사용자 정보',
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              userName.trim().isEmpty
                  ? '이름 미설정'
                  : userName,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              '연결 관리',
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('연결된 사용자  >',
                  style: TextStyle(fontSize: 24)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConnectedUsersScreen(userType: userType),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(userType == 'DRIVER' ? '내 QR 코드 생성  >' : '운전자 QR 코드 스캔  >',
                  style: const TextStyle(fontSize: 24)),
              onTap: () async {
                if (userType == 'DRIVER') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DriverQrScreen()),
                  );
                } else {
                  final connected = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScanScreen()),
                  );
                  if (connected == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('운전자 연결이 완료되었습니다.')),
                    );
                  }
                }
              },
            ),

            if (compact) const SizedBox(height: 28) else const Spacer(),

            TextButton(
              onPressed: () async {
                await ApiService.clearSession();
                try {
                  await initializeGoogleSignIn();
                  await GoogleSignIn.instance.signOut();
                } catch (_) {
                  // Google 로그아웃 실패와 관계없이 로컬 서버 세션은 삭제합니다.
                }
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}

// ============================================================
// 연결된 사용자 목록 (서버 JWT 인증)
// ============================================================

class ConnectedUsersScreen extends StatefulWidget {
  final String userType;

  const ConnectedUsersScreen({super.key, required this.userType});

  @override
  State<ConnectedUsersScreen> createState() => _ConnectedUsersScreenState();
}

class _ConnectedUsersScreenState extends State<ConnectedUsersScreen> {
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.getMyConnections();
      if (!mounted) return;
      setState(() {
        users = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'DRIVER':
        return '운전자';
      case 'MANAGER':
        return '관리자';
      case 'FAMILY':
        return '가족';
      default:
        return '사용자';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연결된 사용자'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
          const CurrentAccountSettingsButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        OutlinedButton(onPressed: _refresh, child: const Text('다시 시도')),
                      ],
                    ),
                  )
                : users.isEmpty
                    ? const Center(child: Text('연결된 사용자가 없습니다.'))
                    : ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 36),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final uid = user['uid']?.toString() ?? '';
                          final rawName = user['name']?.toString().trim() ?? '';
                          final name = rawName.isEmpty ? '이름 미설정' : rawName;
                          final type = user['userType']?.toString();
                          final canOpen = type == 'DRIVER' && uid.isNotEmpty;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name, style: const TextStyle(fontSize: 24)),
                            subtitle: Text(_typeLabel(type)),
                            trailing: canOpen ? const Icon(Icons.chevron_right) : null,
                            onTap: !canOpen
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RemoteDriverScreen(
                                          driverUid: uid,
                                          driverName: name,
                                          allowHistory: widget.userType == 'FAMILY',
                                        ),
                                      ),
                                    ),
                          );
                        },
                      ),
      ),
    );
  }
}

// ============================================================
// 운전자: 서버 일회용 QR 토큰 발급 및 표시
// ============================================================

class DriverQrScreen extends StatefulWidget {
  const DriverQrScreen({super.key});

  @override
  State<DriverQrScreen> createState() => _DriverQrScreenState();
}

class _DriverQrScreenState extends State<DriverQrScreen> {
  String? token;
  DateTime? expiresAt;
  bool isLoading = false;
  String? errorMessage;
  Timer? tickTimer;
  bool autoRenewAttempted = false;

  int get remainingSeconds {
    if (expiresAt == null) return 0;
    final ms = expiresAt!.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _issueQr();
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (token != null && remainingSeconds == 0 && !isLoading &&
          !autoRenewAttempted) {
        autoRenewAttempted = true;
        _issueQr();
      }
    });
  }

  Future<void> _issueQr() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await ApiService.issueQrToken();
      final raw = response['token']?.toString();
      final expires = DateTime.tryParse(response['expiresAt']?.toString() ?? '');
      if (raw == null || raw.isEmpty || expires == null) {
        throw const ApiException('QR 발급 응답 형식이 올바르지 않습니다.');
      }
      if (!mounted) return;
      setState(() {
        token = raw;
        expiresAt = expires.toLocal();
        autoRenewAttempted = false;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        token = null;
        expiresAt = null;
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 QR 코드'),
        actions: const [CurrentAccountSettingsButton()],
      ),
      body: ResponsiveScreenBody(
        builder: (compact) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              const Text('가족 또는 관리자가 이 QR 코드를 스캔하면 연결됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24)),
            if (compact) const SizedBox(height: 22) else const Spacer(),
            if (isLoading && token == null)
              const CircularProgressIndicator()
            else if (token != null && remainingSeconds > 0)
              QrImageView(
                data: token!,
                version: QrVersions.auto,
                size: MediaQuery.sizeOf(context).width < 340
                    ? MediaQuery.sizeOf(context).width - 64
                    : 280,
                backgroundColor: Colors.white,
              )
            else
              const Text('QR 코드가 만료되었습니다.',
                  style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            Text('남은 시간: $remainingSeconds초',
                style: const TextStyle(fontSize: 24)),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ],
            if (compact) const SizedBox(height: 22) else const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 78,
              child: OutlinedButton(
                onPressed: isLoading ? null : () {
                  autoRenewAttempted = false;
                  _issueQr();
                },
                child: const Text('새 QR 코드 발급',
                    style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 가족/관리자: 카메라로 QR 스캔 -> 서버 연결 수락
// ============================================================

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );
  bool processing = false;
  String? errorMessage;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (processing) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
        raw = barcode.rawValue!.trim();
        break;
      }
    }
    if (raw == null) return;
    setState(() {
      processing = true;
      errorMessage = null;
    });
    try {
      await controller.stop();
      final result = await ApiService.acceptQrToken(raw);
      if (!mounted) return;
      if (result['success'] != true) {
        throw const ApiException('연결 완료 응답을 확인할 수 없습니다.');
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      processing = false;
      errorMessage = null;
    });
    await controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운전자 QR 스캔'),
        actions: const [CurrentAccountSettingsButton()],
      ),
      body: ResponsiveScreenBody(
        builder: (compact) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              const Text('운전자 화면에 표시된 QR 코드를 카메라로 스캔해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24)),
            const SizedBox(height: 24),
            if (compact)
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(controller: controller, onDetect: _onDetect),
                ),
              )
            else
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(controller: controller, onDetect: _onDetect),
                ),
              ),
            const SizedBox(height: 20),
            if (processing && errorMessage == null)
              const CircularProgressIndicator(),
            if (errorMessage != null) ...[
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _retry, child: const Text('다시 스캔')),
            ],
            const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 관리자 화면
// ============================================================

class AdminHomeScreen
    extends StatefulWidget {
  final String uid;
  final String userName;
  // FAMILY와 MANAGER가 동일한 운전자 목록 UI를 사용합니다.
  final String userType;

  const AdminHomeScreen({
    super.key,
    required this.uid,
    required this.userName,
    this.userType = 'MANAGER',
  });

  @override
  State<AdminHomeScreen> createState() =>
      _AdminHomeScreenState();
}

class _AdminHomeScreenState
    extends State<AdminHomeScreen> {
  List<Map<String, dynamic>> drivers = [];

  bool isLoading = true;
  String? errorMessage;

  Timer? refreshTimer;
  bool isFetching = false;

  @override
  void initState() {
    super.initState();

    _loadDrivers();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _loadDrivers();
      },
    );
  }

  Future<void> _loadDrivers() async {
    if (isFetching) {
      return;
    }

    isFetching = true;

    try {
      final result =
          await ApiService.getConnectedDrivers(
        widget.uid,
      );

      if (!mounted) {
        return;
      }

      final profiles = result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      // 새 /users/me/connections 응답에는 심박 상태가 없어서 별도 조회.
      final withStatus = await Future.wait(profiles.map((driver) async {
        try {
          final status = await ApiService.getDriverStatus(driver['uid'].toString());
          return <String, dynamic>{
            ...driver,
            ...status,
            'uid': driver['uid'],
            'name': driver['name'],
          };
        } catch (_) {
          return driver;
        }
      }));
      if (!mounted) return;
      setState(() {
        drivers = withStatus;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    } finally {
      isFetching = false;
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/simbakguys_symbol.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 7),
            Text(widget.userType == 'FAMILY' ? '가족' : '관리자'),
          ],
        ),
        actions: const [CurrentAccountSettingsButton()],
      ),

      body: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 20,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SimbakguysBrandHeader(),
            const SizedBox(height: 14),
            const Text(
              '운전자 목록',
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Text(
                            '운전자 정보를 불러오지 못했습니다.\n\n$errorMessage',
                            textAlign:
                                TextAlign.center,
                          ),
                        )
                      : drivers.isEmpty
                          ? const Center(
                              child: Text(
                                '연결된 운전자가 없습니다.',
                              ),
                            )
                          : ListView.separated(
                              itemCount:
                                  drivers.length,

                              separatorBuilder:
                                  (
                                context,
                                index,
                              ) =>
                                      const Divider(
                                height: 40,
                              ),

                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                final driver =
                                    drivers[
                                        index];

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                RemoteDriverScreen(
                                          driverUid:
                                              driver['uid']
                                                  .toString(),
                                          driverName:
                                              driver['name']
                                                      ?.toString() ??
                                                  '',
                                          allowHistory:
                                              widget.userType == 'FAMILY',
                                        ),
                                      ),
                                    );
                                  },

                                  child:
                                      Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical:
                                          8,
                                    ),

                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (driver['name']?.toString().trim().isNotEmpty ?? false)
                                                ? driver['name'].toString()
                                                : '이름 미설정',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 26),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        Text(
                                          getDriverSummaryStatus(
                                            driver,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontSize: 24,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 가족 홈: 관리자와 동일한 목록 -> 선택한 운전자 상태 화면
// 심박 기록이 없어도 목록은 그대로 표시됩니다.
// ============================================================

class FamilyHomeScreen extends StatelessWidget {
  final String uid;
  final String userName;

  const FamilyHomeScreen({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return AdminHomeScreen(
      uid: uid,
      userName: userName,
      userType: 'FAMILY',
    );
  }
}

// ============================================================
// 관리자용 운전자 상태 화면
// ============================================================

class RemoteDriverScreen extends StatelessWidget {
  final String driverUid;
  final String driverName;
  final bool allowHistory;

  const RemoteDriverScreen({
    super.key,
    required this.driverUid,
    required this.driverName,
    required this.allowHistory,
  });

  @override
  Widget build(BuildContext context) {
    // 실제 운전자 홈과 동일한 심박 상태 UI/판정 로직을 재사용.
    // 조회 UID는 연결된 운전자의 UID이며, 로그인 사용자의 UID가 아님.
    return DriverStatusScreen(
      uid: driverUid,
      userName: driverName,
      isRemote: true,
      allowHistory: allowHistory,
    );
  }
}
