import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsManager {
  TtsManager._();

  static final TtsManager _instance = TtsManager._()..initTts();

  static TtsManager get instance => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  String language = "ko-KR";
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> initTts() async {
    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    _flutterTts.setStartHandler(() {
      print("Playing");
      ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      print("Complete");
      ttsState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      print("Cancel");
      ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      print("Paused");
      ttsState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      print("Continued");
      ttsState = TtsState.continued;
    });

    _flutterTts.setErrorHandler((msg) {
      print("error: $msg");
      ttsState = TtsState.stopped;
    });
  }

  void dispose() {
    _flutterTts.stop();
  }

  Future<void> _getDefaultEngine() async {
    var engine = await _flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await _flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _setAwaitOptions() async {
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    await _flutterTts.setVolume(volume);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setLanguage(language);

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    var result = await _flutterTts.stop();
    if (result == 1) ttsState = TtsState.stopped;
  }

  // Future<void> _pause() async {
  //   var result = await _flutterTts.pause();
  //   if (result == 1) ttsState = TtsState.paused;
  // }
}

enum TtsState { playing, stopped, paused, continued }
