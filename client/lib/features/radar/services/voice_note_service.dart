import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VoiceNoteResult {
  final Uint8List bytes;
  final int durationSeconds;
  final String fileName;
  final String? localFilePath;

  const VoiceNoteResult({
    required this.bytes,
    required this.durationSeconds,
    required this.fileName,
    this.localFilePath,
  });
}

/// Service to handle microphone recording for WhatsApp-style voice notes.
class VoiceNoteService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _durationSeconds = 0;
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  int get durationSeconds => _durationSeconds;

  String get formattedDuration {
    final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Starts recording a voice note with AAC-LC encoding.
  Future<bool> startRecording() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = p.join(tempDir.path, fileName);

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _durationSeconds = 0;
      notifyListeners();

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _durationSeconds++;
        notifyListeners();
      });

      return true;
    } catch (e) {
      debugPrint('[VoiceNoteService] startRecording error: $e');
      _isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Finalizes and returns the recorded voice note audio bytes.
  Future<VoiceNoteResult?> stopRecording() async {
    _timer?.cancel();
    if (!_isRecording) return null;

    try {
      final recordedPath = await _recorder.stop();
      _isRecording = false;
      final finalDuration = _durationSeconds > 0 ? _durationSeconds : 1;
      _durationSeconds = 0;
      notifyListeners();

      if (recordedPath == null || recordedPath.isEmpty) {
        return null;
      }

      final file = File(recordedPath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }

      final fileName = p.basename(recordedPath);
      return VoiceNoteResult(
        bytes: bytes,
        durationSeconds: finalDuration,
        fileName: fileName,
        localFilePath: recordedPath,
      );
    } catch (e) {
      debugPrint('[VoiceNoteService] stopRecording error: $e');
      _isRecording = false;
      _durationSeconds = 0;
      notifyListeners();
      return null;
    }
  }

  /// Aborts and cancels the current recording without saving.
  Future<void> cancelRecording() async {
    _timer?.cancel();
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _durationSeconds = 0;
      notifyListeners();

      if (path != null) {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('[VoiceNoteService] cancelRecording error: $e');
      _isRecording = false;
      _durationSeconds = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
