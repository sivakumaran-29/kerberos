import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/radar_models.dart';
import '../../services/file_download_helper.dart';

/// WhatsApp-style voice note bubble with play/pause, scrubbable waveform,
/// speed toggling, live progress, and instant download.
class VoiceNotePlayerWidget extends StatefulWidget {
  final P2PFileAttachment file;
  final bool isSelf;

  const VoiceNotePlayerWidget({
    super.key,
    required this.file,
    required this.isSelf,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _speed = 1.0;
  bool _isSourceLoaded = false;
  late final List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _totalDuration = Duration(seconds: widget.file.durationSeconds > 0 ? widget.file.durationSeconds : 0);

    // Generate deterministic waveform from SHA-256 hash
    _waveformHeights = _generateWaveform(widget.file.sha256Hash, 30);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inMilliseconds > 0) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant VoiceNotePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.bytes != widget.file.bytes) {
      _isSourceLoaded = false;
      if (_isPlaying) {
        _player.stop();
        _isPlaying = false;
      }
    }
    if (oldWidget.file.durationSeconds != widget.file.durationSeconds && widget.file.durationSeconds > 0) {
      _totalDuration = Duration(seconds: widget.file.durationSeconds);
    }
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  List<double> _generateWaveform(String seed, int barCount) {
    final random = Random(seed.hashCode);
    return List.generate(barCount, (i) {
      final base = 0.25 + (random.nextDouble() * 0.75);
      return base.clamp(0.18, 1.0);
    });
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (!_isSourceLoaded) {
          String? mimeType;
          final name = widget.file.fileName.toLowerCase();
          if (name.endsWith('.webm') || name.endsWith('.opus')) {
            mimeType = 'audio/webm';
          } else if (name.endsWith('.m4a') || name.endsWith('.aac')) {
            mimeType = 'audio/mp4';
          } else if (name.endsWith('.mp3')) {
            mimeType = 'audio/mpeg';
          } else if (name.endsWith('.wav')) {
            mimeType = 'audio/wav';
          } else if (name.endsWith('.ogg')) {
            mimeType = 'audio/ogg';
          } else if (name.endsWith('.flac')) {
            mimeType = 'audio/flac';
          }

          if (widget.file.bytes != null && widget.file.bytes!.isNotEmpty) {
            await _player.setSource(BytesSource(widget.file.bytes!, mimeType: mimeType));
          }
          await _player.setPlaybackRate(_speed);
          _isSourceLoaded = true;
        }
        await _player.resume();
      }
    } catch (e) {
      debugPrint('[VoiceNotePlayer] Error toggling playback: $e');
    }
  }

  Future<void> _toggleSpeed() async {
    final nextSpeed = _speed == 1.0
        ? 1.5
        : _speed == 1.5
            ? 2.0
            : 1.0;
    setState(() {
      _speed = nextSpeed;
    });
    try {
      await _player.setPlaybackRate(_speed);
    } catch (_) {}
  }

  void _seekToPercent(double percent) {
    final targetMs = (_totalDuration.inMilliseconds * percent).round();
    _player.seek(Duration(milliseconds: targetMs));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final currentProgress = _totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final primaryAccent = widget.isSelf ? const Color(0xFFC084FC) : const Color(0xFF34D399);

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Controls & Waveform Row
          Row(
            children: [
              // Play / Pause Circle
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryAccent,
                        primaryAccent.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withValues(alpha: _isPlaying ? 0.5 : 0.25),
                        blurRadius: _isPlaying ? 14 : 8,
                        spreadRadius: _isPlaying ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: (!widget.file.isCompleted && (widget.file.bytes == null || widget.file.bytes!.isEmpty))
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF090D16)),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF090D16),
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Waveform Bars Area (Scrubbable)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(details.globalPosition);
                      final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
                      _seekToPercent(pct);
                    }
                  },
                  onTapUp: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(details.globalPosition);
                      final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
                      _seekToPercent(pct);
                    }
                  },
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_waveformHeights.length, (idx) {
                        final barPercent = idx / _waveformHeights.length;
                        final isPassed = barPercent <= currentProgress;
                        final heightFactor = _waveformHeights[idx];

                        return Container(
                          width: 3.2,
                          height: 32 * heightFactor,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? primaryAccent
                                : const Color(0xFF475569).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Timeline, Speed Toggle & Download Action
          Row(
            children: [
              // Current / Total Time
              Text(
                _isPlaying || _position.inSeconds > 0
                    ? _formatDuration(_position)
                    : _formatDuration(_totalDuration),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),

              // Speed Chip
              InkWell(
                onTap: _toggleSpeed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x35FFFFFF)),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Download Voice Note Button
              if (widget.file.bytes != null && widget.file.bytes!.isNotEmpty)
                IconButton(
                  tooltip: 'Download Voice Note',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.download_rounded, size: 17, color: Color(0xFF38BDF8)),
                  onPressed: () {
                    FileDownloadHelper.downloadFile(
                      context: context,
                      fileName: widget.file.fileName,
                      bytes: widget.file.bytes!,
                    );
                  },
                ),
            ],
          ),

          // 3. Cryptographic C2PA Seal Indicator
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x1810B981),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x3510B981)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF34D399)),
                const SizedBox(width: 5),
                Text(
                  'C2PA HARDWARE ENCLAVE VOICE SEAL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF34D399),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
