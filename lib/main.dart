import 'dart:async';

import 'package:flutter/material.dart';

import 'api_service.dart';

void main() {
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
      title: '심박 모니터링',

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),

      // 앱 시작 → UID 로그인 화면
      home: const LoginScreen(),
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
// 로그인 화면
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController uidController =
      TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> _login() async {
    final uid = uidController.text.trim();

    if (uid.isEmpty) {
      setState(() {
        errorMessage = 'UID를 입력해주세요.';
      });

      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result =
          await ApiService.mockLogin(uid);

      if (!mounted) {
        return;
      }

      final String resultUid =
          result['uid']?.toString() ?? uid;

      final String userName =
          result['name']?.toString() ?? '';

      final String userType =
          result['userType']?.toString() ?? '';

      Widget nextScreen;

      switch (userType) {
        case 'DRIVER':
          nextScreen = DriverStatusScreen(
            uid: resultUid,
            userName: userName,
          );
          break;

        case 'MANAGER':
          nextScreen = AdminHomeScreen(
            uid: resultUid,
            userName: userName,
          );
          break;

        case 'FAMILY':
          nextScreen = FamilyHomeScreen(
            uid: resultUid,
            userName: userName,
          );
          break;

        default:
          throw Exception(
            '알 수 없는 사용자 유형입니다: $userType',
          );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => nextScreen,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage =
            '로그인에 실패했습니다.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Text(
                '심박 모니터링',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 50),

              TextField(
                controller: uidController,
                decoration: const InputDecoration(
                  labelText: 'UID',
                  hintText: 'driver001',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!isLoading) {
                    _login();
                  }
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed:
                      isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style:
                              TextStyle(fontSize: 18),
                        ),
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 20),

                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ],

              const SizedBox(height: 35),

              const Text(
                '테스트 UID\n'
                'driver001\n'
                'manager001\n'
                'family001',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  height: 1.5,
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

  const DriverStatusScreen({
    super.key,
    required this.uid,
    required this.userName,
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
  bool hasError = false;
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
        hasError = false;

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
          hasError = true;

          signalStatus = '조회 실패';
          deviceStatus = '확인 불가';
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
            fontSize: 92,
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
              fontSize: 22,
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
          fontSize: 28,
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
                fontSize: 82,
                height: 1,
              ),
            ),

            SizedBox(height: 8),

            Text(
              '안정 범위',
              style: TextStyle(
                fontSize: 20,
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

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 20,
          ),
          child: Column(
            children: [
              // 상단
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Text(
                    '최근 측정 $lastMeasuredTime',
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(
                            uid: widget.uid,
                            userName:
                                widget.userName,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      '설정',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // 심박 표시
              SizedBox(
                height: 150,
                child: Center(
                  child:
                      _buildHeartDisplay(),
                ),
              ),

              const Spacer(),

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
                            fontSize: 20,
                          ),
                        ),

                        Text(
                          signalStatus,
                          style:
                              const TextStyle(
                            fontSize: 20,
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
                            fontSize: 20,
                          ),
                        ),

                        Text(
                          deviceStatus,
                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (hasError) ...[
                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        '서버에서 최신 정보를 불러오지 못했습니다.',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // 상세 기록
              SizedBox(
                width: double.infinity,
                height: 60,
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
                      fontSize: 18,
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

    const itemWidth = 62.0;

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
  // 시간대가 바뀌었는지 확인
  // ------------------------------------------------------------

  bool _isNewHour(int index) {
    if (index == 0) {
      return true;
    }

    try {
      final current =
          DateTime.parse(
        records[index]['measurementTime']
            .toString(),
      ).toLocal();

      final previous =
          DateTime.parse(
        records[index - 1]
                ['measurementTime']
            .toString(),
      ).toLocal();

      return current.year != previous.year ||
          current.month != previous.month ||
          current.day != previous.day ||
          current.hour != previous.hour;
    } catch (_) {
      return false;
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
            fontSize: 20,
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
            fontSize: 20,
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
      height: 78,
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
              width: 54,
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
                      fontSize: 13,
                      color: selected
                          ? Colors.white70
                          : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 18,
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
  // 기록 목록
  // ------------------------------------------------------------

  Widget _buildRecordList() {
    if (isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          '기록을 불러오지 못했습니다.\n\n$errorMessage',
          textAlign:
              TextAlign.center,
        ),
      );
    }

    if (records.isEmpty) {
      return Center(
        child: Text(
          '${selectedDate.month}월 '
          '${selectedDate.day}일의\n'
          '측정 기록이 없습니다.',
          textAlign:
              TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            height: 1.5,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder:
          (context, index) {
        final record =
            records[index];

        final time =
            formatTimeWithSeconds(
          record['measurementTime'],
        );

        final bpm =
            record['heartRate'];

        return Column(
          children: [
            if (_isNewHour(index)) ...[
              const SizedBox(height: 8),

              Row(
                children: [
                  const Expanded(
                    child: Divider(),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      formatDateHour(
                        record[
                            'measurementTime'],
                      ),
                      style:
                          const TextStyle(
                        fontSize: 14,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),

                  const Expanded(
                    child: Divider(),
                  ),
                ],
              ),

              const SizedBox(height: 14),
            ],

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                Text(
                  time,
                  style:
                      const TextStyle(
                    fontSize: 20,
                  ),
                ),

                Text(
                  bpm == null
                      ? '측정 불가'
                      : '$bpm bpm',
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
          ],
        );
      },
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
        title:
            const Text('상세 기록'),
      ),

      body: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),

        child: Column(
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
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 타임라인 세로 스크롤
            Expanded(
              child:
                  _buildRecordList(),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width:
                  double.infinity,
              height: 60,
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
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 설정
// ============================================================

class SettingsScreen
    extends StatelessWidget {
  final String uid;
  final String userName;

  const SettingsScreen({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
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
            const Text(
              '사용자 정보',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              userName.isEmpty
                  ? uid
                  : userName,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'UID : $uid',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              '연결 관리',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              '관리자/가족 연결 조회 및 추가 기능은 '
              '서버 API 추가 후 연동 예정',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const Spacer(),

            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
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

  const AdminHomeScreen({
    super.key,
    required this.uid,
    required this.userName,
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

      setState(() {
        drivers = result
            .map(
              (item) =>
                  Map<String, dynamic>.from(
                item as Map,
              ),
            )
            .toList();

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
        title: const Text('관리자'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    uid: widget.uid,
                    userName: widget.userName,
                  ),
                ),
              );
            },
            child: const Text(
              '설정',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ),
        ],
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
            const Text(
              '운전자 목록',
              style: TextStyle(
                fontSize: 24,
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
                                              false,
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
                                        Text(
                                          driver['name']
                                                  ?.toString() ??
                                              driver['uid']
                                                  .toString(),
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                20,
                                          ),
                                        ),

                                        Text(
                                          getDriverSummaryStatus(
                                            driver,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                18,
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
// 가족 화면
// ============================================================

class FamilyHomeScreen extends StatefulWidget {
  final String uid;
  final String userName;

  const FamilyHomeScreen({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  State<FamilyHomeScreen> createState() =>
      _FamilyHomeScreenState();
}

class _FamilyHomeScreenState
    extends State<FamilyHomeScreen> {
  // 가족과 연결된 운전자 기본 정보
  Map<String, dynamic>? driverInfo;

  // replay-status에서 받아오는 실시간 상태
  Map<String, dynamic>? driverStatus;

  bool isLoading = true;
  String? errorMessage;

  Timer? refreshTimer;
  bool isFetching = false;

  @override
  void initState() {
    super.initState();

    _initializeFamilyScreen();
  }

  // ------------------------------------------------------------
  // 처음 한 번 연결된 운전자 확인
  // ------------------------------------------------------------

  Future<void> _initializeFamilyScreen() async {
    try {
      final result =
          await ApiService.getConnectedDrivers(
        widget.uid,
      );

      if (!mounted) {
        return;
      }

      if (result.isEmpty) {
        setState(() {
          isLoading = false;
          driverInfo = null;
        });

        return;
      }

      driverInfo =
          Map<String, dynamic>.from(
        result.first as Map,
      );

      // 운전자 상태 최초 1회 조회
      await _loadDriverStatus();

      if (!mounted) {
        return;
      }

      // 이후 1초마다 replay-status 조회
      refreshTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          _loadDriverStatus();
        },
      );
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
  // 연결된 운전자의 현재 상태 조회
  // ------------------------------------------------------------

  Future<void> _loadDriverStatus() async {
    if (isFetching) {
      return;
    }

    if (driverInfo == null) {
      return;
    }

    isFetching = true;

    try {
      final String driverUid =
          driverInfo!['uid'].toString();

      final result =
          await ApiService.getDriverStatus(
        driverUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        driverStatus = result;
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
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('가족'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('가족'),
        ),
        body: Center(
          child: Text(
            '정보를 불러오지 못했습니다.\n\n$errorMessage',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (driverInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('가족'),
        ),
        body: const Center(
          child: Text(
            '연결된 운전자가 없습니다.',
          ),
        ),
      );
    }

    final driver = driverInfo!;
    final status = driverStatus;

    int? bpm;

    if (status != null) {
      final dynamic rawBpm =
          status['heartRate'];

      if (rawBpm is num) {
        bpm = rawBpm.toInt();
      }
    }

    final bool stable =
        isHeartRateInRange(bpm);

    final Color backgroundColor =
        bpm == null
            ? Colors.white
            : stable
                ? const Color.fromARGB(
                    255,
                    193,
                    225,
                    156,
                  )
                : const Color.fromARGB(
                    255,
                    255,
                    222,
                    132,
                  );

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        title: const Text('가족'),
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    uid: widget.uid,
                    userName: widget.userName,
                  ),
                ),
              );
            },
            child: const Text(
              '설정',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 20,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              '연결된 운전자',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              driver['name']
                      ?.toString() ??
                  driver['uid'].toString(),
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '최근 측정 '
              '${formatTime(status?['measurementTime'])}',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const Spacer(),

            Center(
              child: bpm == null
                  ? const Text(
                      '측정 불가',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    )
                  : stable
                      ? const Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Text(
                              '😊',
                              style:
                                  TextStyle(
                                fontSize: 82,
                              ),
                            ),

                            SizedBox(
                              height: 8,
                            ),

                            Text(
                              '안정 범위',
                              style:
                                  TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,
                          children: [
                            Text(
                              '$bpm',
                              style:
                                  const TextStyle(
                                fontSize: 92,
                                fontWeight:
                                    FontWeight.w600,
                                height: 1,
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            const Padding(
                              padding:
                                  EdgeInsets.only(
                                bottom: 10,
                              ),
                              child: Text(
                                'bpm',
                                style:
                                    TextStyle(
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetailRecordScreen(
                        driverUid:
                            driver['uid']
                                .toString(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  '상세 기록 보기',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 관리자용 운전자 상태 화면
// ============================================================

class RemoteDriverScreen
    extends StatefulWidget {
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
  State<RemoteDriverScreen>
      createState() =>
          _RemoteDriverScreenState();
}

class _RemoteDriverScreenState
    extends State<RemoteDriverScreen> {
  Map<String, dynamic>? status;

  bool isLoading = true;
  String? errorMessage;

  Timer? statusTimer;
  bool isFetching = false;

  @override
  void initState() {
    super.initState();

    // 화면 진입 즉시 한 번 조회
    _loadStatus();

    // 이후 1초마다 polling
    statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _loadStatus();
      },
    );
  }

  Future<void> _loadStatus() async {
    // 이전 요청이 아직 끝나지 않았으면
    // 중복 요청 방지
    if (isFetching) {
      return;
    }

    isFetching = true;

    try {
      final result =
          await ApiService.getDriverStatus(
        widget.driverUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        status = result;
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
    } finally {
      isFetching = false;
    }
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.driverName.isEmpty
              ? '운전자 상태'
              : widget.driverName,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 20,
        ),

        child: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : errorMessage != null
                ? Center(
                    child: Text(
                      '상태를 불러오지 못했습니다.\n\n$errorMessage',
                      textAlign:
                          TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      Center(
                        child: Text(
                          getDriverSummaryStatus(
                            status!,
                          ),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            '신호 상태',
                            style:
                                TextStyle(
                              fontSize: 20,
                            ),
                          ),

                          Text(
                            signalStatusToKorean(
                              status![
                                  'signalQuality'],
                            ),
                            style:
                                const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            '장치 상태',
                            style:
                                TextStyle(
                              fontSize: 20,
                            ),
                          ),

                          Text(
                            deviceStatusToKorean(
                              status![
                                  'deviceStatus'],
                            ),
                            style:
                                const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            '최근 측정',
                            style:
                                TextStyle(
                              fontSize: 20,
                            ),
                          ),

                          Text(
                            formatTime(
                              status![
                                  'measurementTime'],
                            ),
                            style:
                                const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      if (widget.allowHistory)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child:
                              OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailRecordScreen(
                                    driverUid:
                                        widget.driverUid,
                                  ),
                                ),
                              );
                            },
                            child:
                                const Text(
                              '상세 기록 보기',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
      ),
    );
  }
}