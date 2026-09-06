import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/theme/cyber_theme.dart';
import '../../../../shared/widgets/cyber_button.dart';
import '../../models/radar_models.dart';
import '../../services/p2p_session_service.dart';
import '../../services/file_download_helper.dart';
import '../../services/voice_note_service.dart';
import 'voice_note_player_widget.dart';

/// Ultra-premium Dark Obsidian P2P Encrypted Messaging Interface with Inline Asset Sealing
class P2PChatScreen extends StatefulWidget {
  final P2PSessionService sessionService;
  final VoidCallback onDisconnect;
  final Function(String fileName, Uint8List bytes)? onAuditInVerification;

  const P2PChatScreen({
    super.key,
    required this.sessionService,
    required this.onDisconnect,
    this.onAuditInVerification,
  });

  @override
  State<P2PChatScreen> createState() => _P2PChatScreenState();
}

class _P2PChatScreenState extends State<P2PChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  final VoiceNoteService _voiceNoteService = VoiceNoteService();

  @override
  void initState() {
    super.initState();
    widget.sessionService.addListener(_handleSessionUpdate);
    _voiceNoteService.addListener(_handleVoiceNoteUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.sessionService.removeListener(_handleSessionUpdate);
    _voiceNoteService.removeListener(_handleVoiceNoteUpdate);
    _voiceNoteService.dispose();
    _chatFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSessionUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _handleVoiceNoteUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await widget.sessionService.sendTextMessage(text);
    _scrollToBottom();
    _chatFocusNode.requestFocus();
  }

  Future<void> _startVoiceRecording() async {
    final started = await _voiceNoteService.startRecording();
    if (!started && mounted) {
      final msg = _voiceNoteService.lastErrorMessage ??
          'Microphone access denied. Please allow microphone permissions in your browser or choose an audio file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 12.5)),
          backgroundColor: const Color(0xFFF43F5E),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'CHOOSE AUDIO',
            textColor: Colors.white,
            onPressed: _pickAudioFileDirectly,
          ),
        ),
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    await _voiceNoteService.cancelRecording();
  }

  Future<void> _sendVoiceRecording() async {
    final result = await _voiceNoteService.stopRecording();
    if (result != null) {
      await widget.sessionService.sendVoiceNote(
        audioBytes: result.bytes,
        durationSeconds: result.durationSeconds,
        localFilePath: result.localFilePath,
      );
      _scrollToBottom();
      _chatFocusNode.requestFocus();
    }
  }

  Future<void> _pickAudioFileDirectly() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac'],
    );
    if (result != null && result.files.isNotEmpty) {
      final List<XFile> xFiles = [];
      for (final picked in result.files) {
        if (picked.path != null && picked.path!.isNotEmpty) {
          xFiles.add(XFile(picked.path!));
        } else if (picked.bytes != null) {
          xFiles.add(XFile.fromData(picked.bytes!, name: picked.name, path: picked.name));
        }
      }
      if (xFiles.isNotEmpty) {
        await widget.sessionService.enqueueFiles(xFiles);
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickAndSealAsset() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'pdf', 'webp', 'bin', 'txt',
        'm4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      final List<XFile> xFiles = [];
      for (final picked in result.files) {
        if (picked.path != null && picked.path!.isNotEmpty) {
          xFiles.add(XFile(picked.path!));
        } else if (picked.bytes != null) {
          xFiles.add(XFile.fromData(picked.bytes!, name: picked.name, path: picked.name));
        }
      }
      if (xFiles.isNotEmpty) {
        await widget.sessionService.enqueueFiles(xFiles);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.sessionService.activePeer;
    final messages = widget.sessionService.messages;
    final isSealing = widget.sessionService.isSealing;
    final isTransferring = widget.sessionService.isTransferring;
    final transferProgress = widget.sessionService.transferProgress;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && !_chatFocusNode.hasFocus) {
          final char = event.character;
          if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
            _chatFocusNode.requestFocus();
            _textController.text = _textController.text + char;
            _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x28FFFFFF), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Session Header
            _buildSessionHeader(peer, isMobile),

            // 2. Chat Timeline
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  if (message.isSystemNotice) {
                    return _buildSystemNotice(message);
                  }
                  return _buildMessageBubble(message, screenWidth);
                },
              ),
            ),

            // 3. Inline Sealing & Streaming Progress Indicator
            if (isSealing || isTransferring || widget.sessionService.transferQueueCount > 0) ...[
              _buildActiveTransferBanner(isSealing, transferProgress, isMobile),
            ],

            // 4. Compose Input Bar
            _buildComposeBar(isMobile),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. SESSION HEADER
  // ==========================================
  Widget _buildSessionHeader(RadarPeer? peer, bool isMobile) {
    final displayName = peer?.displayName ?? 'Encrypted Peer';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(bottom: BorderSide(color: Color(0x20FFFFFF), width: 1.0)),
      ),
      child: Row(
        children: [
          // Peer Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isMobile ? 36 : 42,
                height: isMobile ? 36 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CyberTheme.shardGradient,
                  boxShadow: [
                    BoxShadow(
                      color: CyberTheme.accentColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 15 : 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(color: const Color(0xFF160F2B), width: 2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: isMobile ? 10 : 14),

          // Peer Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 13.5 : 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x20C084FC),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0x40C084FC)),
                      ),
                      child: Text(
                        peer?.platform.toUpperCase() ?? 'PEER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE9D5FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isMobile
                            ? 'P2P DTLS • ~${peer?.pingMs ?? 16}ms'
                            : 'P2P DTLS 1.3 TUNNEL • ZERO-TRUST AIR-GAPPED • ~${peer?.pingMs ?? 16}ms',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: isMobile ? 8.5 : 9.5,
                          color: const Color(0xFF34D399),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Disconnect Button
          isMobile
              ? Tooltip(
                  message: 'End Session',
                  child: InkWell(
                    onTap: widget.onDisconnect,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x22F43F5E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x50F43F5E)),
                      ),
                      child: const Center(
                        child: Icon(Icons.link_off_rounded, color: Color(0xFFF43F5E), size: 18),
                      ),
                    ),
                  ),
                )
              : CyberButton(
                  variant: CyberButtonVariant.danger,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  icon: Icons.link_off_rounded,
                  onTap: widget.onDisconnect,
                  child: const Text('End Session'),
                ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. CHAT MESSAGE BUBBLES
  // ==========================================
  Widget _buildMessageBubble(P2PChatMessage message, double screenWidth) {
    final isSelf = message.isSelf;
    final bubbleMaxWidth = (screenWidth * 0.82).clamp(240.0, 480.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) ...[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: CyberTheme.shardGradient,
              ),
              child: Center(
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'P',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelf ? const Color(0xFF6B21A8) : const Color(0x30FFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isSelf ? 18 : 4),
                  bottomRight: Radius.circular(isSelf ? 4 : 18),
                ),
                border: Border.all(
                  color: isSelf ? const Color(0xFFC084FC) : const Color(0x28FFFFFF),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // File Attachment Card (if message has file)
                  if (message.fileAttachment != null) ...[
                    _buildFileAttachmentCard(message.fileAttachment!, isSelf, screenWidth),
                    const SizedBox(height: 8),
                  ],

                  // Text content
                  if (message.text.isNotEmpty && (message.fileAttachment == null || !message.text.startsWith('Sent sealed digital asset:'))) ...[
                    SelectableText(
                      message.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Timestamp
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      color: isSelf ? const Color(0xFFE9D5FF) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. PROVENANCE FILE ATTACHMENT CARD
  // ==========================================
  Widget _buildFileAttachmentCard(P2PFileAttachment file, bool isSelf, double screenWidth) {
    final ext = file.fileName.split('.').last.toLowerCase();
    final isAudio = ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac'].contains(ext);
    if (file.isVoiceNote || isAudio) {
      return VoiceNotePlayerWidget(file: file, isSelf: isSelf);
    }

    final cardMaxWidth = (screenWidth * 0.74).clamp(220.0, 340.0);

    return Container(
      constraints: BoxConstraints(maxWidth: cardMaxWidth),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4010B981), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x2210B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x6010B981)),
                ),
                child: const Icon(Icons.file_present_rounded, color: Color(0xFF34D399), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(file.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (file.isCompleted && file.bytes != null)
                IconButton(
                  tooltip: 'Download ${file.fileName}',
                  icon: const Icon(Icons.download_rounded, color: Color(0xFF34D399), size: 20),
                  onPressed: () => FileDownloadHelper.downloadFile(
                    context: context,
                    fileName: file.fileName,
                    bytes: file.bytes!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // C2PA Seal Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x2510B981),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x5010B981)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'C2PA HARDWARE SEAL VERIFIED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF34D399),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // SHA-256 Hash with Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x18FFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.sha256Hash.length > 20
                        ? 'SHA-256: ${file.sha256Hash.substring(0, 10)}...${file.sha256Hash.substring(file.sha256Hash.length - 6)}'
                        : 'SHA-256: ${file.sha256Hash}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.0, color: const Color(0xFFE2E8F0)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: file.sha256Hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SHA-256 Hash copied!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Icon(Icons.copy, size: 12, color: Color(0xFFC084FC)),
                ),
              ],
            ),
          ),

          // Progress Bar during active transfer
          if (!file.isCompleted) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: file.progress > 0 ? file.progress : null,
                backgroundColor: const Color(0x30FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
                minHeight: 4,
              ),
            ),
          ],

          // Completed Actions: Download File and Audit in Verification Protocol
          if (file.isCompleted && file.bytes != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    variant: CyberButtonVariant.purple,
                    height: 32,
                    icon: Icons.download_rounded,
                    onTap: () => FileDownloadHelper.downloadFile(
                      context: context,
                      fileName: file.fileName,
                      bytes: file.bytes!,
                    ),
                    child: const Text('Download'),
                  ),
                ),
                if (widget.onAuditInVerification != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: CyberButton(
                      variant: CyberButtonVariant.emerald,
                      height: 32,
                      icon: Icons.shield_outlined,
                      onTap: () => widget.onAuditInVerification!(file.fileName, file.bytes!),
                      child: const Text('Audit'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 4. SYSTEM NOTICE
  // ==========================================
  Widget _buildSystemNotice(P2PChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0x20FFFFFF)),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ==========================================
  // 5. ACTIVE TRANSFER & SEALING BANNER
  // ==========================================
  Widget _buildActiveTransferBanner(bool isSealing, double progress, bool isMobile) {
    final queueCount = widget.sessionService.transferQueueCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
      color: isSealing ? const Color(0x22A855F7) : const Color(0x2210B981),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSealing ? const Color(0xFFC084FC) : const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSealing
                      ? '> INLINE SEALING: ${widget.sessionService.sealingStep}'
                      : '> STREAMING: ${(progress * 100).toStringAsFixed(0)}% • ${widget.sessionService.activeTransferringFileName}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: isSealing ? const Color(0xFFE9D5FF) : const Color(0xFF34D399),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (queueCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x3038BDF8),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0x6038BDF8)),
                  ),
                  child: Text(
                    '+$queueCount in queue',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isSealing) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0x20FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 6. COMPOSE INPUT BAR
  // ==========================================
  Widget _buildComposeBar(bool isMobile) {
    if (_voiceNoteService.isRecording) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x22160F2B),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Color(0x35A855F7), width: 1.0)),
        ),
        child: Row(
          children: [
            // Pulsing Red REC Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x25EF4444),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0x60EF4444)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'REC',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),

            // Live Timer
            Text(
              _voiceNoteService.formattedDuration,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isMobile ? 12.5 : 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 14),

            // Live Waveform Visualizer
            Expanded(
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(isMobile ? 14 : 20, (i) {
                    final h = (0.25 + (0.75 * (i % 4 == 0 ? 0.9 : (i % 3 == 0 ? 0.6 : 0.35)))).clamp(0.2, 1.0);
                    return Container(
                      width: 2.5,
                      height: 24 * h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC084FC),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  }),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 12),

            // Cancel Button
            if (isMobile)
              Tooltip(
                message: 'Cancel Recording',
                child: InkWell(
                  onTap: _cancelVoiceRecording,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0x22F43F5E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x40F43F5E)),
                    ),
                    child: const Center(
                      child: Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 18),
                    ),
                  ),
                ),
              )
            else
              CyberButton(
                variant: CyberButtonVariant.danger,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                icon: Icons.delete_outline_rounded,
                onTap: _cancelVoiceRecording,
                child: const Text('Cancel'),
              ),
            SizedBox(width: isMobile ? 6 : 8),

            // Send Voice Note Button
            if (isMobile)
              Tooltip(
                message: 'Send Voice Note',
                child: InkWell(
                  onTap: _sendVoiceRecording,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, color: Color(0xFF090D16), size: 18),
                    ),
                  ),
                ),
              )
            else
              CyberButton(
                variant: CyberButtonVariant.emerald,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                icon: Icons.send_rounded,
                onTap: _sendVoiceRecording,
                child: const Text('Send'),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Color(0x20FFFFFF), width: 1.0)),
      ),
      child: Row(
        children: [
          // Attach & Seal Button
          if (isMobile)
            Tooltip(
              message: 'Attach & Seal Files',
              child: InkWell(
                onTap: _pickAndSealAsset,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x2210B981),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x4010B981)),
                  ),
                  child: const Center(
                    child: Icon(Icons.attach_file_rounded, color: Color(0xFF34D399), size: 20),
                  ),
                ),
              ),
            )
          else
            CyberButton(
              variant: CyberButtonVariant.emerald,
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              icon: Icons.attach_file_rounded,
              onTap: _pickAndSealAsset,
              child: const Text('Attach & Seal Asset'),
            ),
          SizedBox(width: isMobile ? 8 : 12),

          // Message Input Field with direct auto-focus
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x28FFFFFF)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                controller: _textController,
                focusNode: _chatFocusNode,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: isMobile ? 'Encrypted message...' : 'Type an encrypted P2P message...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 10),

          // Send Audio File Button (Direct audio file picker)
          Tooltip(
            message: 'Send Audio File (.mp3, .m4a, .wav, .opus)',
            child: InkWell(
              onTap: _pickAudioFileDirectly,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isMobile ? 38 : 42,
                height: isMobile ? 38 : 42,
                decoration: BoxDecoration(
                  color: const Color(0x2238BDF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4038BDF8)),
                ),
                child: Center(
                  child: Icon(Icons.audio_file_rounded, color: const Color(0xFF38BDF8), size: isMobile ? 18 : 21),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),

          // WhatsApp-style Voice Note Mic Button
          Tooltip(
            message: 'Record Voice Note',
            child: InkWell(
              onTap: _startVoiceRecording,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isMobile ? 38 : 42,
                height: isMobile ? 38 : 42,
                decoration: BoxDecoration(
                  color: const Color(0x22C084FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x40C084FC)),
                ),
                child: Center(
                  child: Icon(Icons.mic_rounded, color: const Color(0xFFC084FC), size: isMobile ? 19 : 22),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),

          // Send Button
          if (isMobile)
            Tooltip(
              message: 'Send',
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.send_rounded, color: Color(0xFF090D16), size: 18),
                  ),
                ),
              ),
            )
          else
            CyberButton(
              variant: CyberButtonVariant.whitePill,
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              icon: Icons.send_rounded,
              onTap: _sendMessage,
              child: const Text('Send'),
            ),
        ],
      ),
    );
  }
}

