// pitch_detector_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:audioplayers_web/audioplayers_web.dart';
// 添加数学库导入
import 'dart:math' as math;

import 'package:record/record.dart';

class PitchDetectorScreen extends StatefulWidget {
  const PitchDetectorScreen({super.key});

  @override
  State<PitchDetectorScreen> createState() => _PitchDetectorScreenState();
}

class _PitchDetectorScreenState extends State<PitchDetectorScreen> {
  late PitchDetector _pitchDetector;
  //  final PitchHandler _pitchup;

  late AudioRecorder _audioRecorder;
  double _currentPitch = 0.0;
  String _currentNote = '未检测到';
  bool _isListening = false;
  String _status = '准备就绪';

  // 音符映射
  final List<String> _notes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  @override
  void initState() {
    super.initState();
    // _initializePitchDetector();
    _pitchDetector = PitchDetector();
    _audioRecorder = AudioRecorder();
  }

  // void _initializePitchDetector() {
  //   // 初始化音高检测器 (44.1kHz 采样率, 1024 帧大小)
  //   _pitchDetector = PitchDetector();
  // }

  // 请求麦克风权限
  Future<bool> _requestMicrophonePermission() async {

    try {
      if (await _audioRecorder.hasPermission()) {
      }
   } catch (e) {
      debugPrint(e.toString());
    }
    if (await Permission.microphone.request().isGranted) {
      return true;
    }
    return false;
  }

  // 开始检测
  void _startDetection() async {
    bool hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      setState(() {
        _status = '需要麦克风权限';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _status = '正在监听...';
    });

    //   _pitchDetector = PitchDetector();

    // 模拟音频输入（在实际应用中，这里应该连接到真实的音频流）
    await _simulateAudioInput();
  }

  // 停止检测
  void _stopDetection() {
    setState(() {
      _isListening = false;
      _status = '已停止';
      _currentPitch = 0.0;
      _currentNote = '未检测到';
    });
  }

/// 简化版本：将 Uint8List 流缓冲为指定大小的 Float32List
Stream<Float32List> bufferStream(
  Stream<Uint8List> stream, 
  int bufferSize
) async* {
  final List<double> buffer = [];
  
  await for (final Uint8List chunk in stream) {
    // 将 Uint8List 转换为浮点数并添加到缓冲区
    for (int i = 0; i < chunk.length - 1; i += 2) {
      // 16-bit PCM 小端序转换
      final int sample = (chunk[i + 1] << 8) | chunk[i];
      final int signedSample = (sample > 32767) ? sample - 65536 : sample;
      final double floatValue = signedSample / 32768.0;
      buffer.add(floatValue);
    }
    
    // 输出完整的缓冲区
    while (buffer.length >= bufferSize) {
      final Float32List floatBuffer = Float32List(bufferSize);
      for (int i = 0; i < bufferSize; i++) {
        floatBuffer[i] = buffer[i];
      }
      
      yield floatBuffer;
      buffer.removeRange(0, bufferSize);
    }
  }
}
  Future _simulateAudioInput() async {
    if (!_isListening) return;

    final recordStream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        bitRate: 128000,
        sampleRate: PitchDetector.DEFAULT_SAMPLE_RATE,
      ),
    );

    var audioSampleBufferedStream = bufferStream(
      recordStream,
      // recordStream.map((event) {
      //   return event.toList();
      // }),
      //The library converts a PCM16 to 8bits internally. So we need twice as many bytes
      PitchDetector.DEFAULT_BUFFER_SIZE * 2,
    );

    await for (var audioSample in audioSampleBufferedStream) {
      // final intBuffer = Float32List.fromList(audioSample);

      await _detectPitch(audioSample);

      // var result = await _pitchDetector.getPitchFromIntBuffer(intBuffer);

      // if (result.pitched) {
      //   //  _pitchupDart.handlePitch(detectedPitch.pitch).then((pitchResult) => {

      //   //   emit(TunningState(
      //   //     note: pitchResult.note,
      //   //     status: pitchResult.tuningStatus.getDescription(),
      //   //   ))
      //   // });
      // }
    }
    // 这里应该使用实际的音频输入
    // 由于 Flutter Web 的限制，我们模拟一些数据
    // Future.delayed(const Duration(milliseconds: 100), () async {
    //   if (_isListening) {
    //     // 生成模拟的音频数据
    //     Float32List audioData = Float32List(1024);
    //     for (int i = 0; i < 1024; i++) {
    //       // 生成一个 440Hz 的正弦波（A4 音符）
    //       audioData[i] = 0.5 *
    //           math.sin(2 * math.pi * 440 * i / 44100);
    //     }

    //     // 检测音高
    //    await  _detectPitch(audioData);

    //     // 继续模拟
    //     _simulateAudioInput();
    //   }
    // });
  }

  // 检测音高
  Future _detectPitch(Float32List audioData) async {
    // 使用 pitch_detector_dart 检测音高
    final result = await _pitchDetector.getPitchFromFloatBuffer(audioData);
    var pitch = result.pitch;
    // _currentNote = _pitchToNote(result.pitch);

    // if (pitch != 0.0 && pitch.isFinite) {
      setState(() {
        _currentPitch = pitch;
        _currentNote = _pitchToNote(pitch);
        _status = '检测到音高';
      });
    // }
  }

  // 将频率转换为音符
  String _pitchToNote(double frequency) {
    if (frequency <= 0) return '未检测到';

    // A4 = 440Hz
    const double a4 = 440.0;
    const int a4Index = 69; // MIDI note number for A4

    // 计算 MIDI 音符编号
    int midiNote =
        (12 * (math.log(frequency / a4) / math.ln2) + a4Index).round();

    // 确保在有效范围内
    if (midiNote < 0 || midiNote >= 128) return '超出范围';

    // 计算八度和音符
    int octave = (midiNote ~/ 12) - 1;
    int noteIndex = midiNote % 12;

    return '${_notes[noteIndex]}$octave';
  }

  // 获取音符与标准音的偏差（以音分为单位）
  double _getDeviation(double frequency, String note) {
    if (frequency <= 0) return 0.0;

    // 计算标准频率
    double standardFreq = _noteToFrequency(note);
    if (standardFreq == 0.0) return 0.0;

    // 计算偏差（音分）
    return 1200 * math.log(frequency / standardFreq) / math.ln2;
  }

  // 将音符转换为频率
  double _noteToFrequency(String note) {
    // 简化的实现
    Map<String, double> noteFrequencies = {
      'A4': 440.0,
      'A#4': 466.16,
      'B4': 493.88,
      'C5': 523.25,
      'C#5': 554.37,
      'D5': 587.33,
      'D#5': 622.25,
      'E5': 659.25,
      'F5': 698.46,
      'F#5': 739.99,
      'G5': 783.99,
      'G#5': 830.61,
    };

    return noteFrequencies[note] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    double deviation = _getDeviation(_currentPitch, _currentNote);

    return Scaffold(
      appBar: AppBar(
        title: const Text('音高检测器'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 音高显示
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1), //.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    '当前音高',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_currentPitch.toStringAsFixed(2)} Hz',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentNote,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 偏差指示器
            if (_currentPitch > 0)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:
                      Colors.grey..withValues(alpha: 0.1), // withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      '音准偏差',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${deviation.toStringAsFixed(1)} 音分',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            deviation.abs() < 10
                                ? Colors.green
                                : deviation.abs() < 30
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 偏差条
                    SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(
                        value: (deviation + 50) / 100, // 映射到 0-1 范围
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          deviation.abs() < 10
                              ? Colors.green
                              : deviation.abs() < 30
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // 状态显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _isListening
                          ? Colors.green.withValues(
                            alpha: 0.2,
                          ) //withOpacity(0.2)
                          : Colors.grey
                      ..withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isListening ? null : _startDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('开始检测', style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: _isListening ? _stopDetection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('停止检测', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 说明文本
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '请允许麦克风权限并对着麦克风发声来检测音高。\n'
                '应用会显示检测到的频率和对应的音符。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
