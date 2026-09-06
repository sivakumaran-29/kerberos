import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  test('Audio packages import and compile test', () {
    expect(AudioRecorder, isNotNull);
    expect(AudioPlayer, isNotNull);
    expect(RecordConfig, isNotNull);
    expect(AudioEncoder.aacLc, isNotNull);
  });
}
