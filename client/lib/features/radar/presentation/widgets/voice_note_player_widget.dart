import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/radar_models.dart';
import '../../services/file_download_helper.dart';

/// Ultra-compact, authentic WhatsApp-style voice note bubble with play/pause,
/// scrubbable waveform, live progress duration, deterministic speed toggling,
/// and slow-connection buffering protection.
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

    // Generate deterministic 22-bar waveform from SHA-256 hash
    _waveformHeights = _generateWaveform(widget.file.sha256Hash, 22);

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
    if (oldWidget.file.bytes != widget.file.bytes || oldWidget.file.isCompleted != widget.file.isCompleted) {
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
      return base.clamp(0.2, 1.0);
    });
  }

  Future<void> _togglePlay() async {
    // Guard against playing uninitialized audio or empty bytes on slow connections
    if (widget.file.bytes == null || widget.file.bytes!.isEmpty || !widget.file.isCompleted) {
      debugPrint('[VoiceNotePlayer] Audio still downloading or incomplete. Playback prevented.');
      return;
    }

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

          await _player.setSource(BytesSource(widget.file.bytes!, mimeType: mimeType));
          _isSourceLoaded = true;
        }
        await _player.resume();
        await _player.setPlaybackRate(_speed);
      }
    } catch (e) {
      _isSourceLoaded = false;
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
    if (_totalDuration.inMilliseconds <= 0) return;
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
    final isReady = widget.file.isCompleted && widget.file.bytes != null && widget.file.bytes!.isNotEmpty;
    final currentProgress = _totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final primaryAccent = widget.isSelf ? const Color(0xFFC084FC) : const Color(0xFF34D399);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardMaxWidth = (screenWidth * 0.72).clamp(210.0, 280.0);

    return Container(
      constraints: BoxConstraints(maxWidth: cardMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Play/Pause Button + Scrubbable Waveform
          Row(
            children: [
              // Circular Play / Pause Button (WhatsApp-sized 36x36)
              InkWell(
                onTap: isReady ? _togglePlay : null,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryAccent,
                        primaryAccent.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withValues(alpha: _isPlaying ? 0.45 : 0.2),
                        blurRadius: _isPlaying ? 10 : 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: !isReady
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF090D16)),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF090D16),
                            size: 22,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Scrubbable Waveform Bars
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null && isReady) {
                      final local = box.globalToLocal(details.globalPosition);
                      final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
                      _seekToPercent(pct);
                    }
                  },
                  onTapUp: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null && isReady) {
                      final local = box.globalToLocal(details.globalPosition);
                      final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
                      _seekToPercent(pct);
                    }
                  },
                  child: SizedBox(
                    height: 28,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_waveformHeights.length, (idx) {
                        final barPercent = idx / _waveformHeights.length;
                        final isPassed = barPercent <= currentProgress;
                        final heightFactor = _waveformHeights[idx];

                        return Container(
                          width: 2.5,
                          height: 24 * heightFactor,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? primaryAccent
                                : const Color(0xFF64748B).withValues(alpha: 0.5),
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
          const SizedBox(height: 5),

          // Row 2: Duration, Seal Badge, Speed Chip, and Optional Download Button
          Row(
            children: [
              // Elapsed / Total Duration (WhatsApp style)
              Text(
                _isPlaying || _position.inSeconds > 0
                    ? _formatDuration(_position)
                    : _formatDuration(_totalDuration),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 6),

              // Micro C2PA Hardware Seal Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0x1810B981),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x3510B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 9, color: Color(0xFF34D399)),
                    const SizedBox(width: 3),
                    Text(
                      'C2PA',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // WhatsApp-style Speed Toggle Chip (1x, 1.5x, 2x)
              InkWell(
                onTap: _toggleSpeed,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x35FFFFFF)),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Optional Download Button for System Audio Files (Omitted for live mic recordings)
              if (isReady && !widget.file.isLiveRecorded) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Download Audio',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF38BDF8)),
                  onPressed: () {
                    FileDownloadHelper.downloadFile(
                      context: context,
                      fileName: widget.file.fileName,
                      bytes: widget.file.bytes!,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
