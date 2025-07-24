import 'dart:math' show pow;

class DurationUtil {
  static String formatDuration(num? seconds) {
    if (seconds == null || seconds == 0) {
      return '00:00';
    }
    int h = seconds ~/ 3600;
    seconds %= 3600;
    int m = seconds ~/ 60;
    seconds %= 60;
    String sms = seconds is double
        ? seconds.toStringAsFixed(3).padLeft(6, '0')
        : seconds.toString().padLeft(2, '0');
    return h == 0
        ? "${m.toString().padLeft(2, '0')}:$sms"
        : "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:$sms";
  }

  static int parseDuration(String? data) {
    if (data == null || data.isEmpty) {
      return 0;
    }
    List<int> split = data
        .split(':')
        .reversed
        .map((e) => int.parse(e))
        .toList();
    int duration = 0;
    for (int i = 0; i < split.length; i++) {
      duration += split[i] * pow(60, i).toInt();
    }
    return duration;
  }
}
