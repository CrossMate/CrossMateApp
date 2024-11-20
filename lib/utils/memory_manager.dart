import 'package:flutter/services.dart';

class MemoryManager {
  static const _channel = MethodChannel('memory_channel');

  static Future<Map<String, int>?> getMemoryUsage() async {
    try {
      final result = await _channel.invokeMethod('getMemoryUsage');
      if (result == null) return null;

      return Map<String, int>.from(result as Map);
    } catch (e) {
      print('메모리 사용량 조회 중 오류 발생: $e');
      return null;
    }
  }

  static Future<num> getResidentMemory() async {
    try {
      final memory = await _channel.invokeMethod<num>('getResidentMemory');
      return memory ?? 0;
    } catch (e) {
      print('메모리 조회 중 오류 발생: $e');
      return 0;
    }
  }
}
