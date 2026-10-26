import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/alert_coordinator.dart';
import '../core/house_scenario.dart';
import 'widgets/house_status_card.dart';
import 'widgets/editable_dashboard.dart';
import 'widgets/hardware_test_dialog.dart';
import 'widgets/scenario_event_overlay.dart';
import '../core/appliance_controls.dart';
import '../core/event_manager.dart';
import '../core/recent_activity.dart';
import '../mqtt/mqtt_receiver.dart';
import '../services/audio_service.dart';
import '../services/camera_stream_service.dart';
import '../services/disaster_service.dart';
import '../services/sign_speech_policy.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/live_caption_service.dart';
import '../services/wifi_sensing_service.dart';
import 'connection_settings_page.dart';
import 'utils/disaster_display.dart';
import '../services/situation_service.dart';
import 'widgets/situation_panel.dart';
import 'widgets/appliance_panel.dart';
import 'widgets/wifi_sensing_panel.dart';
import 'widgets/wifi_action_status.dart';
import 'widgets/live_caption_panel.dart';

part 'home_dashboard.dart';

enum _SafeHubPage { home, signTranslation, appliances, wifiSensing }

class SafeHubHomePage extends StatefulWidget {
  const SafeHubHomePage({super.key, this.onSettingsSaved, this.cameraService});
  final VoidCallback? onSettingsSaved;
  final CameraStreamService? cameraService;

  @override
  State<SafeHubHomePage> createState() => _SafeHubHomePageState();
}

class _SafeHubHomePageState extends State<SafeHubHomePage>
    with SingleTickerProviderStateMixin {
  bool _layoutEditing = false;
  bool _hardwareTestOpen = false;
  void _closeHardwareTestForAlert() {
    if (_hardwareTestOpen && mounted) {
      _hardwareTestOpen = false;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }
  }
  void _openHardwareTest() {
    if (_hardwareTestOpen) return;
    _hardwareTestOpen = true;
    showDialog<void>(context: context,
    builder: (_) => HardwareTestDialog(connected: _mqttConnected && !AppConfig.localPreview,
      publishAlert: _mqttReceiver.publishAlertSignal,
      publishFan: _mqttReceiver.publishHardwareTestFan,
      publishCurtain: _mqttReceiver.publishCurtain,
      classifierUri: Uri.parse(_situation.settings.endpoint).replace(path: '/classify')))
      .whenComplete(() => _hardwareTestOpen = false);
  }
  final EventManager _eventManager = EventManager();
  final ApplianceControls _appliances = ApplianceControls();
  final DisasterService _disasterService = DisasterService();
  final AlertCoordinator _alertCoordinator = AlertCoordinator();
  final AudioService _audioService = AudioService();
  final SignSpeechPolicy _signSpeechPolicy = SignSpeechPolicy();

  late final MqttReceiver _mqttReceiver;
  late final AnimationController _alertPulseController;
  late final TtsService _ttsService;
  late final SttService _sttService;
  late final LiveCaptionService _captions;
  final _situation = SituationService();
  Timer? _situationTimer;
  bool _sensorPolling = false;
  String? _activeLedOff;
  bool _shakerSent = false;
  late final CameraStreamService _cameraStreamService =
      widget.cameraService ?? CameraStreamService();
  final WifiSensingService _wifiSensingService = WifiSensingService(
    baseUrl: AppConfig.csiServiceUrl,
  );

  Timer? _disasterTimer;
  Timer? _signOverlayTimer;
  Timer? _clockTimer;
  Timer? _previewSignTimer;
  final _clock = ValueNotifier<DateTime>(DateTime.now());

  _SafeHubPage _currentPage = _SafeHubPage.home;

  bool _mqttConnected = false;
  bool _mqttStarted = false;
  String _connectionStatus = '연결 중';
  String _signText = '수어 인식 대기 중';
  DateTime? _lastSignAt;
  String _ttsStatus = '음성 안내 대기';
  static const int _cameraWidth = 320;
  static const int _cameraHeight = 240;

  final _cameraImage = ValueNotifier<ui.Image?>(null);
  int _cameraGeneration = 0;
  bool _cameraConnected = false;
  bool _cameraDecodeInProgress = false;
  bool _showSignOverlay = false;

  Map<String, dynamic>? _latestDisaster;

  String? _lastDisasterId;
  int _speechGeneration = 0;

  final List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clock.value = DateTime.now();
    });

    _alertPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _ttsService = TtsService(baseUrl: AppConfig.ttsServerUrl);

    _situation.onAnnouncement = () {
      if (!mounted) return;
      _closeHardwareTestForAlert();
      _interruptNormalSpeech();
      _sendScenarioSignal();
    };
    _situation.onScenarioAlert = () {
      if (!mounted) return;
      _closeHardwareTestForAlert();
      _interruptNormalSpeech();
      _sendScenarioSignal();
    };
    _situation.onScenarioTestChanged = () {
      if (!mounted) return;
      _stopScenarioSignal();
      if (_situation.scenarioTestMode) _sendScenarioSignal();
    };
    _situation.onConversation = (input, reply, sign) {
      if (!mounted || _situation.scenarioTestMode) return;
      if (updateInterpretation(_recentEvents, reply, sign, input: input))
        setState(() {});
    };
    unawaited(_situation.loadSettings());
    _situationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _situation.expireSensor();
      _updateHomeContext();
      if (!AppConfig.localPreview) unawaited(_pollSituationSensor());
    });

    _sttService = SttService(baseUrl: AppConfig.sttServerUrl);
    _captions = LiveCaptionService(
      transcribe: _sttService.transcribe,
      connectStream: _sttService.connectCaptions,
      onFinalText: (text) {
        _updateHomeContext();
        _situation.addEvidence('확정 음성자막', text);
      },
    );
    if (!AppConfig.localPreview && AppConfig.sttServerUrl.trim().isNotEmpty) {
      unawaited(_captions.start());
    }

    _mqttReceiver = MqttReceiver(
      broker: AppConfig.mqttBroker,
      port: AppConfig.mqttPort,
      eventManager: _eventManager,
      onEventReceived: _handleEvent,
      onSignTextReceived: _handleSignText,
      onDeviceCommand: (topic, data) {
        if (mounted && _appliances.receiveCommand(topic, data)) setState(() {});
      },
      onConnectionChanged: _handleConnectionChanged,
    );

    if (AppConfig.localPreview) {
      _connectionStatus = '체험 모드';
      final demoSign = Uri.base.queryParameters['signDemo'];
      if (demoSign == 'help' || demoSign == 'collapse') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _previewScenario(HouseScenario.assistance);
          final active = _situation.flow.active;
          _previewSignTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _situation.flow.active == active) {
              _situation.receiveSign(
                demoSign == 'help' ? '도움' : '쓰러짐',
                simulated: true,
              );
            }
          });
        });
      }
    } else {
      if (AppConfig.mqttConfigured) {
        _mqttStarted = true;
        _connectMqtt();
      } else {
        _connectionStatus = '주소 미설정';
      }
      if (AppConfig.cameraConfigured) _connectCamera();
      if (AppConfig.disasterConfigured) _startDisasterPolling();
    }
  }

  void _connectCamera() {
    unawaited(
      _cameraStreamService.connect(
        host: AppConfig.cameraHost,
        port: AppConfig.cameraPort,
        onFrame: _handleCameraFrame,
        onConnectionChanged: (connected) {
          if (!mounted) {
            return;
          }

          final previousImage = connected ? null : _cameraImage.value;

          setState(() {
            _cameraConnected = connected;

            if (!connected) {
              _cameraGeneration++;
              _cameraImage.value = null;
            }
          });

          previousImage?.dispose();
        },
      ),
    );
  }

  void _handleCameraFrame(Uint8List frame) {
    if (!mounted) return;
    const expectedBytes = _cameraWidth * _cameraHeight * 4;

    if (frame.lengthInBytes != expectedBytes) {
      return;
    }

    if (_cameraDecodeInProgress) {
      return;
    }

    _cameraDecodeInProgress = true;
    final generation = _cameraGeneration;

    ui.decodeImageFromPixels(
      frame,
      _cameraWidth,
      _cameraHeight,
      ui.PixelFormat.rgba8888,
      (image) {
        _cameraDecodeInProgress = false;

        if (!mounted || generation != _cameraGeneration) {
          image.dispose();
          return;
        }

        final previousImage = _cameraImage.value;
        // Only the preview rebuilds for each frame, not the integrated home.
        _cameraImage.value = image;

        previousImage?.dispose();
      },
    );
  }

  void _startDisasterPolling() {
    _fetchLatestDisaster();

    _disasterTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchLatestDisaster();
    });
  }

  Future<void> _fetchLatestDisaster() async {
    try {
      final disaster = await _disasterService.fetchLatest();

      if (disaster == null || !mounted) {
        return;
      }

      final disasterId = DisasterService.identifierOf(disaster);

      if (disasterId == null || _lastDisasterId == disasterId) {
        return;
      }

      final disasterData = Map<String, dynamic>.from(disaster);
      final currentDisaster = _latestDisaster;

      if (currentDisaster != null &&
          !DisasterService.isNewerThan(disasterData, currentDisaster)) {
        debugPrint(
          '[재난 API] 이전 데이터 무시: '
          'current=${currentDisaster['CRT_DT']} '
          'candidate=${disasterData['CRT_DT']}',
        );
        return;
      }

      final isInitialLoad = _lastDisasterId == null;
      final severity = getDisasterSeverity(disasterData);
      _situation.addEvidence(
        isInitialLoad ? '기존 재난 API 기록 (현재 경보 아님)' : '새 재난 API 알림',
        '${disasterData['CRT_DT'] ?? ''} ${disasterData['MSG_CN'] ?? ''}',
      );

      if (severity != DisasterSeverity.notice) {
        final issued = DateTime.tryParse(
          '${disasterData['CRT_DT'] ?? ''}'.replaceAll('/', '-'),
        );
        _situation.observeDisaster(
          id: disasterId,
          text: '${disasterData['MSG_CN'] ?? ''}',
          region: '${disasterData['RCPTN_RGN_NM'] ?? ''}',
          issuedAt: issued,
        );
      }

      setState(() {
        _lastDisasterId = disasterId;
        _latestDisaster = disasterData;
      });
    } catch (e, st) {
      debugPrint('[재난 API 실패] $e');
      debugPrint('$st');
      // 재난 API 실패 시 다른 SafeHub 기능은 계속 동작한다.
    }
  }

  int _getDisasterPriority(DisasterSeverity severity) {
    switch (severity) {
      case DisasterSeverity.notice:
        return 3;
      case DisasterSeverity.emergency:
        return 6;
      case DisasterSeverity.critical:
        return 8;
    }
  }

  Future<void> _connectMqtt() async {
    try {
      await _mqttReceiver.connect();

      if (!mounted) {
        return;
      }

      setState(() {
        _mqttConnected = true;
        _connectionStatus = '연결됨';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mqttConnected = false;
        _connectionStatus = '연결 실패';
      });
    }
  }

  void _handleConnectionChanged(bool connected) {
    if (!mounted) {
      return;
    }

    setState(() {
      _mqttConnected = connected;
      _connectionStatus = connected ? '연결됨' : '재연결 중';
    });
    // Deliver an alert that arrived while the broker was unavailable.
    final incident = _situation.flow.active;
    if (connected && incident != null &&
        DateTime.now().difference(incident.receivedAt) < const Duration(seconds: 30)) {
      _sendScenarioSignal();
    }
  }

  void _handleSignText(String text) {
    if (!mounted) {
      return;
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    _situation.receiveSign(cleanText);
    _lastSignAt = DateTime.now();
    final ttsConfigured = AppConfig.ttsServerUrl.trim().isNotEmpty;
    final alertActive =
        _alertCoordinator.hasActiveAlert || _situation.needsAttention;
    final shouldSpeak =
        ttsConfigured &&
        !alertActive &&
        _signSpeechPolicy.shouldSpeak(cleanText);

    final String nextTtsStatus;

    if (!ttsConfigured) {
      nextTtsStatus = '텍스트로 표시됨';
    } else if (alertActive) {
      nextTtsStatus = '긴급 경보 우선 안내 중';
    } else if (!shouldSpeak) {
      nextTtsStatus = '최근 음성 안내와 동일';
    } else {
      nextTtsStatus = '음성 변환 준비 중';
    }

    _signOverlayTimer?.cancel();

    setState(() {
      _signText = cleanText;
      _showSignOverlay = true;
      _ttsStatus = nextTtsStatus;
    });

    _signOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showSignOverlay = false;
      });
    });

    if (!shouldSpeak) {
      return;
    }

    final generation = ++_speechGeneration;
    final speechText = _signSpeechPolicy.phraseFor(cleanText);

    unawaited(_speakTranslation(speechText, generation));
  }

  Future<void> _speakTranslation(String text, int generation) async {
    if (AppConfig.ttsServerUrl.trim().isEmpty) {
      return;
    }

    if (_alertCoordinator.hasActiveAlert) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _ttsStatus = '음성 안내 준비 중';
        });
      }

      await _audioService.stop();

      if (generation != _speechGeneration || _alertCoordinator.hasActiveAlert) {
        return;
      }

      final bytes = await _ttsService.synthesize(text);

      if (!mounted ||
          generation != _speechGeneration ||
          _alertCoordinator.hasActiveAlert) {
        return;
      }

      setState(() {
        _ttsStatus = '음성 안내 중';
      });

      await _audioService.playBytes(bytes);

      if (mounted &&
          generation == _speechGeneration &&
          !_alertCoordinator.hasActiveAlert) {
        setState(() {
          _ttsStatus = '음성으로 전달됨';
        });
      }
    } catch (_) {
      if (mounted && generation == _speechGeneration) {
        setState(() {
          _ttsStatus = '텍스트 번역은 정상 표시 중';
        });
      }
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (!mounted) {
      print('[UI] event ignored because widget is not mounted');
      return;
    }

    print(
      '[UI] event received event=${event['event']} '
      'location=${event['location']} priority=${event['priority']}',
    );

    final eventData = Map<String, dynamic>.from(event);
    eventData['_receivedAt'] ??= DateTime.now().toIso8601String();
    _situation.addEvidence(
      '센서 이벤트 (의심 신호)',
      '${eventData['event']} · ${eventData['location'] ?? '위치 미확인'}',
    );

    if (_isEmergencyEvent(eventData)) {
      _situation.observeFall(
        '${eventData['id'] ?? eventData['timestamp'] ?? eventData['_receivedAt']}',
        '${_getLocationName(eventData)} · 낙상 의심 신호 · ${_formatEventDateTime(eventData)}',
      );
    }

    setState(() {
      _recentEvents.insert(0, eventData);

      if (_recentEvents.length > 30) {
        _recentEvents.removeLast();
      }
    });
  }

  int _getEventPriority(Map<String, dynamic> event) {
    final priority = event['priority'];

    if (priority is int && priority >= 1 && priority <= 10) {
      return priority;
    }

    return 9;
  }

  bool _isEmergencyEvent(Map<String, dynamic> event) {
    return event['event'] == 'fall_detected';
  }

  void _interruptNormalSpeech() {
    _speechGeneration++;
    unawaited(
      _audioService.stop().catchError((Object error, StackTrace stack) {
        debugPrint('[음성 안내 중단 실패] $error');
      }),
    );
    // Continue captions so a user can follow announcements during an alarm.

    if (mounted) {
      setState(() {
        _ttsStatus = '안전 알림으로 음성 안내 중단';
      });
    }
  }

  void _acknowledgeActiveAlert() {
    _alertCoordinator.acknowledgeCurrent();

    setState(() {});

    _syncAlertPulse();
    if (!_alertCoordinator.hasActiveAlert) _stopScenarioSignal();
  }

  Future<void> _pollSituationSensor() async {
    if (_sensorPolling || !mounted) return;
    _sensorPolling = true;
    try {
      final state = await _wifiSensingService.state({'view': 'summary'});
      if (mounted) _situation.setSensor(state);
    } catch (_) {
      if (mounted) _situation.setSensor(null);
    } finally {
      _sensorPolling = false;
    }
  }

  void _sendScenarioSignal() {
    final settings = _situation.settings;
    if (_situation.scenarioTestMode && !_situation.scenarioActuators) {
      _situation.flow.setDelivery('테스트: 화면·LED·진동 표시 확인 · 실제 명령 없음');
      return;
    }
    if (AppConfig.localPreview || !settings.actuatorsEnabled) {
      _situation.flow.setDelivery('화면 안내 중 · LED·진동 명령 전송 꺼짐');
      return;
    }
    final incident = _situation.flow.active;
    if (incident == null) return;
    if (!_situation.scenarioTestMode && incident.kind == HouseScenario.disaster &&
        settings.homeRegion.trim().isEmpty &&
        !(incident?.evidence.contains('지역: 전국') ?? false)) {
      _situation.liveFlow.setDelivery('집 지역 미설정 · 지역 확인 후 자동 장치 알림을 사용하세요. 장치 테스트는 가능해요.');
      return;
    }
    final shaker = _mqttReceiver.publishAlertSignal('bedshaker', 'on');
    _shakerSent = _shakerSent || shaker;
    var led = false;
    if (settings.ledOnAction.isNotEmpty && settings.ledOffAction.isNotEmpty) {
      led = _mqttReceiver.publishAlertSignal('led', settings.ledOnAction);
      if (led) _activeLedOff = settings.ledOffAction;
    }
    _situation.actuatorStatus =
        '진동: ${shaker ? '10초 명령 제출' : '전송 실패'} · '
        'LED: ${led
            ? '명령 제출'
            : settings.ledOnAction.isEmpty
            ? '미설정'
            : '전송 실패'} · 실제 동작 미확인';
    _situation.flow.setDelivery(_situation.actuatorStatus);
  }

  void _stopScenarioSignal() {
    if (_shakerSent) _mqttReceiver.publishAlertSignal('bedshaker', 'off');
    if (_activeLedOff != null)
      _mqttReceiver.publishAlertSignal('led', _activeLedOff!);
    _shakerSent = false;
    _activeLedOff = null;
  }

  void _restartAlertPulse() {
    _situation.beginIncident();
    _sendScenarioSignal();
    _alertPulseController
      ..stop()
      ..reset()
      ..repeat(reverse: true);
  }

  void _syncAlertPulse() {
    if (_alertCoordinator.hasActiveAlert) {
      _restartAlertPulse();
      return;
    }

    _alertPulseController
      ..stop()
      ..reset();
  }

  void _openSignTranslation() {
    if (_currentPage == _SafeHubPage.signTranslation) {
      return;
    }

    setState(() {
      _currentPage = _SafeHubPage.signTranslation;
    });
  }

  void _returnHome() {
    if (_currentPage == _SafeHubPage.home) {
      return;
    }

    setState(() {
      _currentPage = _SafeHubPage.home;
    });
  }

  Future<void> _openConnectionSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ConnectionSettingsPage()),
    );
    if (saved == true && mounted) widget.onSettingsSaved?.call();
  }

  @override
  void dispose() {
    _previewSignTimer?.cancel();
    _situationTimer?.cancel();
    _stopScenarioSignal();
    _situation.dispose();
    _clockTimer?.cancel();
    _clock.dispose();
    _wifiSensingService.close();
    _disasterTimer?.cancel();
    _signOverlayTimer?.cancel();
    _speechGeneration++;
    _ttsService.dispose();
    _sttService.dispose();
    _captions.dispose();
    unawaited(
      _audioService.dispose().catchError((Object error, StackTrace stack) {
        debugPrint('[음성 안내 종료 실패] $error');
      }),
    );
    unawaited(_cameraStreamService.dispose());
    _cameraGeneration++;
    _cameraImage.value?.dispose();
    _cameraImage.dispose();
    _alertPulseController.dispose();
    if (_mqttStarted) _mqttReceiver.disconnect();
    super.dispose();
  }

  void _updateHomeContext() {
    _situation.setHomeContext({
      'camera': _cameraConnected ? '연결됨' : '연결 끊김 · 영상 확인 불가',
      'sign':
          _lastSignAt != null &&
                  DateTime.now().difference(_lastSignAt!) <
                      const Duration(minutes: 2)
              ? {
                'text': _signText,
                'observed_at': _lastSignAt!.toIso8601String(),
              }
              : '최근 수어 결과 없음',
      'mqtt': _mqttConnected ? '연결됨' : '연결 끊김',
      'active_alarm': _situation.liveFlow.active?.title ?? '접수된 활성 경보 없음',
      'disaster':
          _latestDisaster == null
              ? '수신 정보 없음'
              : {
                'message': _latestDisaster!['MSG_CN'],
                'issued_at': _latestDisaster!['CRT_DT'],
                'region': _latestDisaster!['RCPTN_RGN_NM'],
              },
      'events':
          _recentEvents
              .where((e) => e['event'] != 'llm_conversation')
              .take(3)
              .map(
                (e) => {
                  'event': _getEventName(e),
                  'at': _formatEventDateTime(e),
                },
              )
              .toList(),
    });
  }

  void _navigate(_SafeHubPage page) => setState(() => _currentPage = page);

  // SafeHub glass layout v4 — presentation only.
  static const _ink = Color(0xFF242629);
  static const _muted = Color(0xFF686C73);
  static const _blue = Color(0xFFA32640);
  static const _green = Color(0xFF287055);
  static const _amber = Color(0xFF96651F);
  String _selectedRoom = 'all';
  String? _detailTitle;
  String _detailBody = '';

  Text _text(
    String value, {
    double size = 18,
    Color color = _ink,
    FontWeight weight = FontWeight.w500,
    int lines = 1,
  }) => Text(
    value,
    maxLines: lines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.3,
      letterSpacing: -0.3,
    ),
  );

  void _previewScenario(HouseScenario kind) {
    _previewSignTimer?.cancel();
    _situation.settings.enabled = false;
    _situation.settings.address = '예시로 119, 안심아파트 101동 1203호';
    _situation.startScenarioTest(kind, switch (kind) {
      HouseScenario.broadcast =>
        '아파트 안내방송입니다. 화재가 발생했습니다. 방송 안내에 따라 비상계단으로 대피하세요.',
      HouseScenario.disaster =>
        '시연지역에 지진이 발생했습니다. 재난 안내에 따라 대피 장소와 주변 안전을 확인해 주세요.',
      HouseScenario.assistance => '침실 · 보호자 쓰러짐 의심. 실제 의식 상태는 확인이 필요합니다.',
    });
    _sendScenarioSignal();
  }

  @override
  Widget build(BuildContext context) {
    final activeAlert = _alertCoordinator.activeAlert;
    return Scaffold(
      backgroundColor: _paper,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final width = math.max(1200.0, bounds.maxWidth);
                final height = math.max(900.0, bounds.maxHeight);
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
                        child: Column(
                          children: [
                            _modernHeader(),
                            const SizedBox(height: 14),
                            if (AppConfig.setupError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  AppConfig.setupError!,
                                  style: const TextStyle(color: _accent),
                                ),
                              ),
                            Expanded(
                              child:
                                  _currentPage == _SafeHubPage.home
                                      ? _modernDashboard(activeAlert)
                                      : _currentPage == _SafeHubPage.wifiSensing
                                      ? WifiSensingPanel(
                                        service: _wifiSensingService,
                                        allowDummy: AppConfig.localPreview,
                                      )
                                      : _currentPage == _SafeHubPage.appliances
                                      ? AppliancePanel(
                                        controls: _appliances,
                                        allowPreview: AppConfig.localPreview,
                                        connected: _mqttConnected,
                                        latestSign: _signText,
                                        publishDeviceCommand: AppConfig.localPreview ? null : (device, action) {
                                          if (device == 'aircon') return _mqttReceiver.publishHardwareTestFan(action == 'on');
                                          if (device == 'curtain') return _mqttReceiver.publishCurtain(
                                              action == 'on' ? 'up' : action == 'off' ? 'down' : 'stop');
                                          return false;
                                        },
                                        publishShortcutCommand:
                                            _mqttReceiver
                                                .publishShortcutCommand,
                                      )
                                      : _glassTranslation(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_detailTitle != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x99000000),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: math.min(
                        680,
                        MediaQuery.sizeOf(context).width - 32,
                      ),
                      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                    ),
                    child: _glass(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _text(
                            _detailTitle!,
                            size: 24,
                            weight: FontWeight.w600,
                          ),
                          const SizedBox(height: 20),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Text(
                                _detailBody,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 20,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _action(
                            '닫기',
                            Icons.close,
                            () => setState(() => _detailTitle = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _buildSignOverlay(
            visible:
                _showSignOverlay && activeAlert == null && _detailTitle == null,
          ),
          if (AppConfig.localPreview)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: const Color(0xFFF6F5F3),
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed:
                              () => _previewScenario(HouseScenario.broadcast),
                          child: const Text('① 방송 화재'),
                        ),
                        TextButton(
                          onPressed:
                              () => _previewScenario(HouseScenario.disaster),
                          child: const Text('② 재난 알림'),
                        ),
                        TextButton(
                          onPressed:
                              () => _previewScenario(HouseScenario.assistance),
                          child: const Text('③ 보호자 도움'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _situation,
              builder: (context, _) {
                if (activeAlert == null &&
                    _situation.flow.active == null &&
                    !_situation.needsAttention)
                  return const SizedBox.shrink();
                return ScenarioEventOverlay(
                  key: ValueKey(_situation.flow.active),
                  service: _situation,
                  camera: _cameraPlaceholder(),
                  onSignal: () {
                    _sendScenarioSignal();
                    setState(() {});
                  },
                  onAcknowledge: () {
                    final simulated = _situation.scenarioTestMode;
                    _situation.acknowledge();
                      if (simulated) {
                        if (_situation.flow.active == null) _stopScenarioSignal();
                        else _sendScenarioSignal();
                        return;
                      }
                    if (_situation.liveFlow.active != null) {
                      _sendScenarioSignal();
                      return;
                    }
                    if (activeAlert != null) {
                      _acknowledgeActiveAlert();
                    } else {
                      _stopScenarioSignal();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glass({
    required Widget child,
    bool inset = false,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            inset
                ? const [Color(0xFFF6F5F3), Color(0xFFF6F5F3)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      ),
      borderRadius: BorderRadius.circular(inset ? 15 : 20),
      border: Border.all(
        color: inset ? const Color(0xFFE9E8E5) : const Color(0xFFE9E8E5),
      ),
      boxShadow:
          inset
              ? null
              : const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
    ),
    child: child,
  );

  Widget _heading(IconData icon, String title, {Widget? trailing}) => Row(
    children: [
      Icon(icon, color: _ink, size: 25),
      const SizedBox(width: 12),
      Expanded(child: _text(title, size: 22, weight: FontWeight.w600)),
      if (trailing != null) trailing,
    ],
  );

  Widget _dot(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withAlpha(55), blurRadius: 8)],
        ),
      ),
      const SizedBox(width: 8),
      _text(label, color: color, size: 16),
    ],
  );

  Widget _glassHeader() => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth >= 1100) return _wideHeader();
      return Column(
        children: [
          Row(
            children: [
              const Icon(Icons.home_rounded, color: _blue, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      'SafeHub',
                      size: 28,
                      color: _blue,
                      weight: FontWeight.w700,
                    ),
                    _text('배리어프리 스마트홈', size: 14, color: _muted),
                  ],
                ),
              ),
              if (bounds.maxWidth >= 500) ...[
                _headerClock(),
                const SizedBox(width: 20),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text('MQTT', size: 14, color: _muted),
                  const SizedBox(height: 4),
                  _dot(_connectionStatus, _mqttConnected ? _green : _amber),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentPage == _SafeHubPage.home)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _glass(
                padding: const EdgeInsets.all(5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roomTab('all', '전체', Icons.grid_view_rounded),
                    _roomTab('livingroom', '거실', Icons.weekend_outlined),
                    _roomTab('bedroom', '침실', Icons.bed_outlined),
                    _roomTab('bathroom', '화장실', Icons.bathroom_outlined),
                  ],
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: _action('홈으로', Icons.home_outlined, _returnHome),
            ),
        ],
      );
    },
  );

  Widget _wideHeader() => SizedBox(
    height: 70,
    child: Row(
      children: [
        const Icon(Icons.home_rounded, color: _blue, size: 48),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text('SafeHub', size: 31, color: _blue, weight: FontWeight.w700),
            _text('배리어프리 스마트홈', size: 15, color: _muted),
          ],
        ),
        const Spacer(),
        if (_currentPage == _SafeHubPage.home)
          _glass(
            padding: const EdgeInsets.all(5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roomTab('all', '전체', Icons.grid_view_rounded),
                _roomTab('livingroom', '거실', Icons.weekend_outlined),
                _roomTab('bedroom', '침실', Icons.bed_outlined),
                _roomTab('bathroom', '화장실', Icons.bathroom_outlined),
              ],
            ),
          )
        else
          _action('홈으로', Icons.home_outlined, _returnHome),
        const Spacer(),
        _headerClock(),
        const SizedBox(width: 30),
        Icon(
          _mqttConnected ? Icons.wifi : Icons.wifi_off,
          color: _mqttConnected ? _blue : _amber,
          size: 30,
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text('MQTT', size: 14, color: _muted),
            const SizedBox(height: 4),
            _dot(_connectionStatus, _mqttConnected ? _green : _amber),
          ],
        ),
      ],
    ),
  );

  Widget _headerClock() => ValueListenableBuilder<DateTime>(
    valueListenable: _clock,
    builder: (context, now, child) {
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      final date =
          '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(date, size: 14, color: _muted),
          _text('$hh:$mm', size: 30, weight: FontWeight.w600),
        ],
      );
    },
  );

  Widget _roomTab(String id, String label, IconData icon) {
    final selected = _selectedRoom == id;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _selectedRoom = id),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0x556F8FAE) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF9EBDE7) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: selected ? _blue : _muted),
              const SizedBox(width: 8),
              _text(label, size: 16, color: selected ? _ink : _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactDashboard(SafeHubAlert? alert, double width) {
    final sign = SizedBox(height: 660, child: _signPanel());
    final space = SizedBox(height: 490, child: _spacePanel(alert));
    final alarm = SizedBox(height: 490, child: _alarmPanel(alert));
    final captions = SizedBox(height: 340, child: _sttPanel());
    final events = SizedBox(height: 320, child: _eventsPanel());
    const gap = SizedBox(height: 20);
    return SingleChildScrollView(
      child: Column(
        children: [
          SituationPanel(service: _situation),
          gap,
          width >= 680
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [sign, gap, events])),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(children: [space, gap, captions, gap, alarm]),
                  ),
                ],
              )
              : Column(
                children: [
                  sign,
                  gap,
                  space,
                  gap,
                  alarm,
                  gap,
                  captions,
                  gap,
                  events,
                ],
              ),
        ],
      ),
    );
  }

  Widget _glassDashboard(SafeHubAlert? alert) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(flex: 34, child: _signPanel()),
      const SizedBox(width: 20),
      Expanded(
        flex: 35,
        child: Column(
          children: [
            Expanded(flex: 6, child: _spacePanel(alert)),
            const SizedBox(height: 20),
            Expanded(flex: 4, child: _sttPanel()),
          ],
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        flex: 31,
        child: Column(
          children: [
            Expanded(flex: 6, child: _alarmPanel(alert)),
            const SizedBox(height: 20),
            Expanded(flex: 4, child: _eventsPanel()),
          ],
        ),
      ),
    ],
  );

  Widget _signPanel() => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(Icons.sign_language_outlined, '수어 · 의사소통'),
        const SizedBox(height: 16),
        Expanded(flex: 4, child: _cameraPlaceholder()),
        const SizedBox(height: 16),
        Expanded(flex: 4, child: _signResultCard()),
        const SizedBox(height: 16),
        _action(
          '의사소통 화면 열기',
          Icons.arrow_forward_rounded,
          _openSignTranslation,
          primary: true,
        ),
      ],
    ),
  );

  Widget _cameraPlaceholder() => ValueListenableBuilder<ui.Image?>(
    valueListenable: _cameraImage,
    builder:
        (context, image, child) => RepaintBoundary(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0x88202020),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE9E8E5)),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                image == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_outlined,
                          size: 46,
                          color: _blue,
                        ),
                        const SizedBox(height: 8),
                        _text(
                          '수어 카메라',
                          color: Colors.white,
                          size: 23,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: 8),
                        _text(
                          AppConfig.localPreview
                              ? '장비 연결 후 수어 인식을 사용할 수 있어요'
                              : !AppConfig.cameraConfigured
                              ? '연결 설정에서 카메라 서버 주소를 입력하세요'
                              : _cameraConnected
                              ? '카메라 영상 수신 대기 중'
                              : 'RPi4 카메라 연결 대기 중',
                          size: 15,
                          color: const Color(0xFFD3D7DC),
                        ),
                      ],
                    )
                    : Stack(
                      fit: StackFit.expand,
                      children: [
                        RawImage(
                          image: image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xAA111111),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 9,
                                  color: _cameraConnected ? _green : _amber,
                                ),
                                const SizedBox(width: 7),
                                _text(
                                  _cameraConnected ? 'LIVE' : '연결 확인',
                                  size: 13,
                                  color: Colors.white,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
  );

  Widget _action(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool primary = false,
  }) => SizedBox(
    height: 55,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: primary ? Colors.white : _ink,
        backgroundColor: primary ? _blue : const Color(0xFFF6F5F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 22),
        ],
      ),
    ),
  );

  Widget _spacePanel(SafeHubAlert? alert) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(Icons.sensors_outlined, '재실 · 활동 상태'),
          const SizedBox(height: 10),
          Expanded(
            child: WifiActionStatus(
              service: _wifiSensingService,
              allowDummy: AppConfig.localPreview,
            ),
          ),
          const SizedBox(height: 10),
          _action(
            '신호 수집 · 모델 관리',
            Icons.sensors_rounded,
            () => setState(() => _currentPage = _SafeHubPage.wifiSensing),
          ),
          if (_selectedRoom == 'all' || _selectedRoom == 'livingroom') ...[
            const SizedBox(height: 10),
            _action(
              '가전 · 수어 단축키',
              Icons.tune_rounded,
              () => setState(() => _currentPage = _SafeHubPage.appliances),
              primary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _alarmPanel(SafeHubAlert? alert) => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(Icons.shield_outlined, '경보 · 재난 알림'),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _systemRow(
                  Icons.warning_amber_rounded,
                  '화면 경보',
                  alert != null
                      ? '알림 발생'
                      : _mqttConnected
                      ? '수신 대기'
                      : '연결 확인 필요',
                  alert != null ? _amber : _muted,
                ),
                const SizedBox(height: 18),
                _disasterSummary(),
                const SizedBox(height: 18),
                _systemRow(
                  Icons.sensors_outlined,
                  '초인종 · 세탁기',
                  '이벤트 연결 필요',
                  _muted,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0x33FFFFFF), height: 24),
        _systemRow(
          Icons.wifi,
          '알림 연결',
          AppConfig.localPreview
              ? '체험 모드'
              : _mqttConnected
              ? '연결됨'
              : _connectionStatus,
          _mqttConnected ? _green : _amber,
        ),
      ],
    ),
  );

  Widget _systemRow(IconData icon, String label, String value, Color color) =>
      Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(child: _text(label, size: 17)),
          const SizedBox(width: 8),
          Flexible(child: _text(value, color: color, size: 15, lines: 2)),
        ],
      );

  Widget _disasterSummary() {
    final disaster = _latestDisaster;
    final color =
        disaster == null
            ? _muted
            : _disasterAccent(getDisasterSeverity(disaster));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x33202020),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _disasterIcon(disaster?['DST_SE_NM']?.toString()),
                color: color,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(child: _text('재난경보', size: 18, weight: FontWeight.w600)),
              if (disaster != null) _more(() => _showDisasterDetails(disaster)),
            ],
          ),
          const SizedBox(height: 12),
          _text(
            disaster == null
                ? '수신된 재난 정보가 없습니다'
                : disaster['DST_SE_NM']?.toString() ?? '재난 안내',
            size: 17,
            weight: FontWeight.w600,
            lines: 2,
          ),
          const SizedBox(height: 8),
          _text(
            disaster == null
                ? AppConfig.localPreview
                    ? '체험 모드에서는 재난 정보를 수신하지 않습니다'
                    : AppConfig.disasterConfigured
                    ? '새 재난 정보 수신 대기'
                    : '재난 API 연결 설정 필요'
                : disaster['MSG_CN']?.toString() ?? '상세 정보를 확인해 주세요',
            size: 15,
            color: _muted,
            lines: 4,
          ),
          if (disaster?['CRT_DT'] != null) ...[
            const SizedBox(height: 8),
            _text(disaster!['CRT_DT'].toString(), size: 12, color: _muted),
          ],
        ],
      ),
    );
  }

  Widget _more(VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: _muted,
      minimumSize: const Size(60, 44),
    ),
    child: const Text('더보기 ›', style: TextStyle(fontSize: 15)),
  );

  List<Map<String, dynamic>> get _visibleEvents =>
      _recentEvents
          .where(
            (event) =>
                _selectedRoom == 'all' ||
                event['event'] == 'llm_conversation' ||
                event['location'] == _selectedRoom,
          )
          .toList();

  Widget _eventsPanel() {
    final events = _visibleEvents;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            Icons.receipt_long_outlined,
            '최근 이벤트',
            trailing: events.isEmpty ? null : _more(_showEventDetails),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                events.isEmpty
                    ? Center(
                      child: _text(
                        '아직 수신된 이벤트가 없습니다',
                        size: 17,
                        color: _muted,
                        lines: 2,
                      ),
                    )
                    : ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, index) => _eventLine(events[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _eventLine(Map<String, dynamic> event) =>
      event['event'] == 'llm_conversation'
          ? InkWell(
            onTap:
                () => _showDetails('AI 대화 · 상황 해석', _conversationText(event)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  event['sign'] == true ? '수어 → AI 확인 질문' : '음성·이벤트 → AI 상황 해석',
                  size: 15,
                  color: _blue,
                ),
                const SizedBox(height: 4),
                _text(event['reply'].toString(), size: 18, lines: 4),
                const SizedBox(height: 4),

                _text(_formatEventDateTime(event), size: 12, color: _muted),
              ],
            ),
          )
          : Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color:
                    _isEmergencyEvent(event) ? const Color(0xFFFF9A93) : _blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      _getLocationName(event) + ' · ' + _getEventName(event),
                      size: 17,
                    ),
                    const SizedBox(height: 3),
                    _text(_formatEventDateTime(event), size: 14, color: _muted),
                  ],
                ),
              ),
            ],
          );

  void _showDisasterDetails(Map<String, dynamic> disaster) => _showDetails(
    '재난 정보',
    [
      disaster['DST_SE_NM']?.toString() ?? '재난 안내',
      disaster['RCPTN_RGN_NM']?.toString() ?? '',
      disaster['CRT_DT']?.toString() ?? '',
      disaster['MSG_CN']?.toString() ?? '내용 없음',
    ].where((s) => s.isNotEmpty).join('\n\n'),
  );

  String _conversationText(Map<String, dynamic> event) =>
      '${_formatEventDateTime(event)}\n\nAI 상황 해석 (참고)\n${event['reply']}';

  void _showEventDetails() => _showDetails(
    '최근 이벤트',
    _visibleEvents
        .map(
          (e) =>
              e['event'] == 'llm_conversation'
                  ? _conversationText(e)
                  : _getLocationName(e) +
                      ' · ' +
                      _getEventName(e) +
                      '\n' +
                      _formatEventDateTime(e),
        )
        .join('\n\n'),
  );

  void _showDetails(String title, String body) {
    setState(() {
      _detailTitle = title;
      _detailBody = body;
    });
  }

  Widget _buildSignOverlay({required bool visible}) {
    final isUrgent = _signText == '아프다';
    final accent = isUrgent ? const Color(0xFFB3263E) : const Color(0xFFA32640);

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            reverseDuration: const Duration(milliseconds: 180),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                ),
            child:
                visible
                    ? Container(
                      key: ValueKey(_signText),
                      constraints: const BoxConstraints(maxWidth: 440),
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.fromLTRB(26, 20, 30, 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        border: Border.all(color: accent.withOpacity(0.72)),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Semantics(
                        liveRegion: true,
                        label: '수어 인식 결과 $_signText',
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.sign_language_rounded,
                                color: accent,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '수어가 인식되었습니다',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _signText,
                                    style: const TextStyle(
                                      color: Color(0xFF242629),
                                      fontSize: 34,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : const SizedBox.shrink(
                      key: ValueKey('sign-overlay-hidden'),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _signResultCard() {
    final isWaiting = _signText == '수어 인식 대기 중';
    final isUrgent = _signText == '아프다';

    final accent = isUrgent ? const Color(0xFFB3263E) : const Color(0xFFA32640);

    final resultColor =
        isUrgent ? const Color(0xFFB3263E) : const Color(0xFF242629);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        ),
        border: Border.all(
          color: isUrgent ? const Color(0x80FF9B91) : const Color(0xFFE9E8E5),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sign_language_outlined, color: accent, size: 25),
              const SizedBox(width: 10),
              const Text(
                '수어 인식 결과',
                style: TextStyle(
                  fontSize: 19,
                  color: Color(0xFF242629),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  label: '수어 인식 결과 $_signText',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _signText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: isWaiting ? 29 : 58,
                          color: resultColor,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: isWaiting ? -0.5 : -1.2,
                        ),
                      ),
                      if (!isWaiting) ...[
                        const SizedBox(height: 12),
                        Text(
                          isUrgent ? '도움이 필요한 수어입니다' : '수어가 정상적으로 인식되었습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                border: Border.all(color: accent.withOpacity(0.28)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _ttsStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isUrgent
                          ? const Color(0xFFB3263E)
                          : const Color(0xFF686C73),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassTranslation() => LayoutBuilder(
    builder: (context, bounds) {
      final camera = _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(Icons.videocam_outlined, '수어 카메라'),
            const SizedBox(height: 16),
            Expanded(child: _cameraPlaceholder()),
            const SizedBox(height: 16),
            _text('카메라를 보며 수어를 표현하세요', size: 16, color: _muted),
          ],
        ),
      );
      if (bounds.maxWidth < 1000 || bounds.maxHeight < 480) {
        return ListView(
          children: [
            SizedBox(height: 280, child: camera),
            const SizedBox(height: 16),
            SizedBox(height: 260, child: _signResultCard()),
            const SizedBox(height: 16),
            SizedBox(height: 320, child: _sttPanel()),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 4, child: camera),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Expanded(flex: 5, child: _signResultCard()),
                const SizedBox(height: 20),
                Expanded(flex: 5, child: _sttPanel()),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _sttPanel() => _glass(
    child: LiveCaptionPanel(
      situation: _situation,
      service: _captions,
      configured: AppConfig.sttServerUrl.trim().isNotEmpty,
      preview: AppConfig.localPreview,
    ),
  );

  String _getEventName(Map<String, dynamic> event) {
    switch (event['event']) {
      case 'fall_detected':
        return '낙상 감지';
      default:
        return event['event']?.toString() ?? '안전 이벤트';
    }
  }

  String _getLocationName(Map<String, dynamic> event) {
    switch (event['location']) {
      case 'bedroom':
        return '침실';
      case 'bathroom':
        return '화장실';
      default:
        return '실내';
    }
  }

  String _formatEventDateTime(Map<String, dynamic> event) {
    final raw = event['_receivedAt']?.toString();

    if (raw == null || raw.isEmpty) {
      return '감지 시각 확인 불가';
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return '감지 시각 확인 불가';
    }

    final local = parsed.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }

  Color _disasterAccent(DisasterSeverity severity) {
    switch (severity) {
      case DisasterSeverity.notice:
        return const Color(0xFFF59E0B);
      case DisasterSeverity.emergency:
        return const Color(0xFFEA580C);
      case DisasterSeverity.critical:
        return const Color(0xFFDC2626);
    }
  }

  IconData _disasterIcon(String? type) {
    switch (type) {
      case '폭염':
        return Icons.sunny;
      case '호우':
        return Icons.water_drop_outlined;
      case '태풍':
        return Icons.cyclone;
      case '대설':
        return Icons.ac_unit;
      case '산불':
        return Icons.local_fire_department_outlined;
      case '지진':
        return Icons.vibration;
      case '미세먼지':
        return Icons.air;
      default:
        return Icons.campaign_outlined;
    }
  }
}
