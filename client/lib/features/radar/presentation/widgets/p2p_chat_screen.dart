import 'dart:async';
import 'dart:math' as math;
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

/// Ultra-premium Dark Obsidian P2P Encrypted Messaging Interface with Inline Asset Sealing,
/// Instagram-style Seen Receipts, Live Peer Typing Indicator, WhatsApp Quoted Replies,
/// and decluttered edge-to-edge mobile experience.
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

  Timer? _typingDebounceTimer;
  P2PChatMessage? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    widget.sessionService.addListener(_handleSessionUpdate);
    _voiceNoteService.addListener(_handleVoiceNoteUpdate);
    _textController.addListener(_onTextChanged);

    // Automatically mark existing peer messages as seen upon entering screen
    widget.sessionService.markMessagesAsSeen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _typingDebounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    widget.sessionService.removeListener(_handleSessionUpdate);
    _voiceNoteService.removeListener(_handleVoiceNoteUpdate);
    _voiceNoteService.dispose();
    _chatFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_textController.text.trim().isNotEmpty) {
      widget.sessionService.sendTypingIndicator(true);
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
        widget.sessionService.sendTypingIndicator(false);
      });
    } else {
      _typingDebounceTimer?.cancel();
      widget.sessionService.sendTypingIndicator(false);
    }
  }

  void _handleSessionUpdate() {
    if (mounted) {
      widget.sessionService.markMessagesAsSeen();
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

    final replyingTo = _replyingToMessage;
    _textController.clear();
    _typingDebounceTimer?.cancel();
    widget.sessionService.sendTypingIndicator(false);

    setState(() {
      _replyingToMessage = null;
    });

    await widget.sessionService.sendTextMessage(
      text,
      replyToId: replyingTo?.id,
      replyToSender: replyingTo?.senderName,
      replyToText: replyingTo?.fileAttachment != null
          ? '📎 ${replyingTo!.fileAttachment!.fileName}'
          : replyingTo?.text,
    );

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
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac'],
      );
      if (result != null && result.files.isNotEmpty) {
        final List<XFile> xFiles = [];
        for (final picked in result.files) {
          if (picked.bytes != null && picked.bytes!.isNotEmpty) {
            xFiles.add(XFile.fromData(picked.bytes!, name: picked.name, path: picked.path));
          } else if (picked.path != null && picked.path!.isNotEmpty) {
            xFiles.add(XFile(picked.path!));
          }
        }
        if (xFiles.isNotEmpty) {
          await widget.sessionService.enqueueFiles(xFiles);
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audio files: $e', style: GoogleFonts.plusJakartaSans(fontSize: 12.5)),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSealAsset() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'png', 'jpg', 'jpeg', 'pdf', 'webp', 'bin', 'txt',
          'm4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        final List<XFile> xFiles = [];
        for (final picked in result.files) {
          if (picked.bytes != null && picked.bytes!.isNotEmpty) {
            xFiles.add(XFile.fromData(picked.bytes!, name: picked.name, path: picked.path));
          } else if (picked.path != null && picked.path!.isNotEmpty) {
            xFiles.add(XFile(picked.path!));
          }
        }
        if (xFiles.isNotEmpty) {
          await widget.sessionService.enqueueFiles(xFiles);
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to seal/load files: $e', style: GoogleFonts.plusJakartaSans(fontSize: 12.5)),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  String _formatSeenText(DateTime? seenAt) {
    if (seenAt == null) return 'Seen';
    final diff = DateTime.now().difference(seenAt);
    if (diff.inSeconds < 60) return 'Seen just now';
    if (diff.inMinutes < 60) return 'Seen ${diff.inMinutes}m ago';
    return 'Seen ${seenAt.hour.toString().padLeft(2, '0')}:${seenAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.sessionService.activePeer;
    final messages = widget.sessionService.messages;
    final isSealing = widget.sessionService.isSealing;
    final isTransferring = widget.sessionService.isTransferring;
    final transferProgress = widget.sessionService.transferProgress;
    final isPeerTyping = widget.sessionService.isPeerTyping;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    // Identify latest self message index for Instagram-style seen receipt
    int latestSelfMessageIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isSelf && !messages[i].isSystemNotice) {
        latestSelfMessageIndex = i;
        break;
      }
    }

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
          borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
          border: isMobile ? null : Border.all(color: const Color(0x28FFFFFF), width: 1.2),
          boxShadow: isMobile
              ? null
              : [
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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 20,
                  vertical: isMobile ? 8 : 16,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  if (message.isSystemNotice) {
                    return _buildSystemNotice(message);
                  }
                  final isLatestSelf = index == latestSelfMessageIndex;
                  return _buildMessageBubble(message, screenWidth, isMobile, isLatestSelf);
                },
              ),
            ),

            // Live Peer Typing Indicator Bubble
            if (isPeerTyping) ...[
              _TypingBubble(peerName: peer?.displayName ?? 'Peer'),
            ],

            // 3. Inline Sealing & Streaming Progress Indicator
            if (isSealing || isTransferring || widget.sessionService.transferQueueCount > 0) ...[
              _buildActiveTransferBanner(isSealing, transferProgress, isMobile),
            ],

            // 4. Quoted Reply Preview Banner (Above compose input)
            if (_replyingToMessage != null) ...[
              _buildQuotedReplyBanner(isMobile),
            ],

            // 5. Compose Input Bar
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
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 20,
        vertical: isMobile ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: isMobile ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(bottom: BorderSide(color: Color(0x20FFFFFF), width: 1.0)),
      ),
      child: Row(
        children: [
          // Peer Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isMobile ? 32 : 42,
                height: isMobile ? 32 : 42,
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
                      fontSize: isMobile ? 13 : 18,
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
                  width: isMobile ? 8 : 10,
                  height: isMobile ? 8 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(color: const Color(0xFF160F2B), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: isMobile ? 8 : 14),

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
                          fontSize: isMobile ? 13 : 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x20C084FC),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0x40C084FC)),
                      ),
                      child: Text(
                        peer?.platform.toUpperCase() ?? 'PEER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.0,
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
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isMobile
                            ? 'P2P DTLS 1.3 • ~${peer?.pingMs ?? 16}ms'
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
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0x22F43F5E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x50F43F5E)),
                      ),
                      child: const Center(
                        child: Icon(Icons.link_off_rounded, color: Color(0xFFF43F5E), size: 16),
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
  Widget _buildMessageBubble(
    P2PChatMessage message,
    double screenWidth,
    bool isMobile,
    bool isLatestSelf,
  ) {
    final isSelf = message.isSelf;
    final bubbleMaxWidth = isMobile
        ? (screenWidth * 0.86).clamp(220.0, 400.0)
        : (screenWidth * 0.78).clamp(240.0, 480.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 5),
      child: Column(
        crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSelf) ...[
                Container(
                  width: isMobile ? 24 : 26,
                  height: isMobile ? 24 : 26,
                  margin: const EdgeInsets.only(right: 6, bottom: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CyberTheme.shardGradient,
                  ),
                  child: Center(
                    child: Text(
                      message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'P',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 9.5 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              Flexible(
                child: GestureDetector(
                  onDoubleTap: () {
                    setState(() {
                      _replyingToMessage = message;
                    });
                    _chatFocusNode.requestFocus();
                  },
                  child: Container(
                    constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 11 : 14,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelf ? const Color(0xFF6B21A8) : const Color(0x30FFFFFF),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isSelf ? 16 : 4),
                        bottomRight: Radius.circular(isSelf ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isSelf ? const Color(0xFFC084FC) : const Color(0x28FFFFFF),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // Embedded Quote Card (if replying to another message)
                        if (message.replyToText != null && message.replyToText!.isNotEmpty) ...[
                          _buildEmbeddedReplyCard(message, isSelf),
                        ],

                        // File Attachment Card (if message has file)
                        if (message.fileAttachment != null) ...[
                          _buildFileAttachmentCard(message.fileAttachment!, isSelf, screenWidth, isMobile),
                          const SizedBox(height: 6),
                        ],

                        // Text content
                        if (message.text.isNotEmpty &&
                            (message.fileAttachment == null || !message.text.startsWith('Sent sealed digital asset:'))) ...[
                          SelectableText(
                            message.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 13.0 : 13.5,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Timestamp & Quick Reply Icon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.0,
                                color: isSelf ? const Color(0xFFE9D5FF) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _replyingToMessage = message;
                                });
                                _chatFocusNode.requestFocus();
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.reply_rounded,
                                  size: 13,
                                  color: isSelf ? const Color(0xFFE9D5FF).withValues(alpha: 0.7) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Instagram-style "Seen just now" / "Seen Xm ago" indicator
          if (isSelf && isLatestSelf && message.isSeen) ...[
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all_rounded, size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  Text(
                    _formatSeenText(message.seenAt),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 3. EMBEDDED QUOTE CARD IN MESSAGE BUBBLE
  // ==========================================
  Widget _buildEmbeddedReplyCard(P2PChatMessage message, bool isSelf) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isSelf ? const Color(0xFFE9D5FF) : const Color(0xFF38BDF8),
            width: 3.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.replyToSender ?? 'Peer',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isSelf ? const Color(0xFFE9D5FF) : const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            message.replyToText!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.0,
              color: const Color(0xFFE2E8F0),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. QUOTED REPLY BANNER (ABOVE COMPOSE BAR)
  // ==========================================
  Widget _buildQuotedReplyBanner(bool isMobile) {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    final rep = _replyingToMessage!;
    final previewText = rep.fileAttachment != null
        ? '📎 ${rep.fileAttachment!.fileName}'
        : rep.text;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x351E1538),
        border: const Border(
          top: BorderSide(color: Color(0x30C084FC), width: 1.0),
          left: BorderSide(color: Color(0xFFC084FC), width: 4.0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: Color(0xFFC084FC)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${rep.senderName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC084FC),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  previewText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFFCBD5E1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 16,
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. PROVENANCE FILE ATTACHMENT CARD
  // ==========================================
  Widget _buildFileAttachmentCard(
    P2PFileAttachment file,
    bool isSelf,
    double screenWidth,
    bool isMobile,
  ) {
    final ext = file.fileName.split('.').last.toLowerCase();
    final isAudio = ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm', 'opus', 'flac'].contains(ext);
    if (file.isVoiceNote || isAudio) {
      return VoiceNotePlayerWidget(file: file, isSelf: isSelf);
    }

    final cardMaxWidth = isMobile
        ? (screenWidth * 0.76).clamp(200.0, 320.0)
        : (screenWidth * 0.74).clamp(220.0, 340.0);

    return Container(
      constraints: BoxConstraints(maxWidth: cardMaxWidth),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x4010B981), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isMobile ? 32 : 36,
                height: isMobile ? 32 : 36,
                decoration: BoxDecoration(
                  color: const Color(0x2210B981),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x6010B981)),
                ),
                child: Icon(Icons.file_present_rounded, color: const Color(0xFF34D399), size: isMobile ? 18 : 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 12.0 : 13.0,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(file.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (file.isCompleted && file.bytes != null)
                IconButton(
                  tooltip: 'Download ${file.fileName}',
                  icon: const Icon(Icons.download_rounded, color: Color(0xFF34D399), size: 19),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => FileDownloadHelper.downloadFile(
                    context: context,
                    fileName: file.fileName,
                    bytes: file.bytes!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // C2PA Seal Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0x2510B981),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x5010B981)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF34D399)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'C2PA HARDWARE SEAL VERIFIED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.0,
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
          const SizedBox(height: 6),

          // SHA-256 Hash with Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0x18FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.sha256Hash.length > 20
                        ? 'SHA-256: ${file.sha256Hash.substring(0, 8)}...${file.sha256Hash.substring(file.sha256Hash.length - 6)}'
                        : 'SHA-256: ${file.sha256Hash}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFFE2E8F0)),
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
                  child: const Icon(Icons.copy, size: 11, color: Color(0xFFC084FC)),
                ),
              ],
            ),
          ),

          // Progress Bar during active transfer
          if (!file.isCompleted) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: file.progress > 0 ? file.progress : null,
                backgroundColor: const Color(0x30FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
                minHeight: 3,
              ),
            ),
          ],

          // Completed Actions: Download File and Audit in Verification Protocol
          if (file.isCompleted && file.bytes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    variant: CyberButtonVariant.purple,
                    height: 30,
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: CyberButton(
                      variant: CyberButtonVariant.emerald,
                      height: 30,
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
  // 6. SYSTEM NOTICE
  // ==========================================
  Widget _buildSystemNotice(P2PChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0x20FFFFFF)),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ==========================================
  // 7. ACTIVE TRANSFER & SEALING BANNER
  // ==========================================
  Widget _buildActiveTransferBanner(bool isSealing, double progress, bool isMobile) {
    final queueCount = widget.sessionService.transferQueueCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 6),
      color: isSealing ? const Color(0x22A855F7) : const Color(0x2210B981),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSealing ? const Color(0xFFC084FC) : const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSealing
                      ? '> INLINE SEALING: ${widget.sessionService.sealingStep}'
                      : '> STREAMING: ${(progress * 100).toStringAsFixed(0)}% • ${widget.sessionService.activeTransferringFileName}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isMobile ? 9.5 : 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSealing ? const Color(0xFFE9D5FF) : const Color(0xFF34D399),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (queueCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0x3038BDF8),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0x6038BDF8)),
                  ),
                  child: Text(
                    '+$queueCount in queue',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isSealing) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0x20FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
                minHeight: 2.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 8. COMPOSE INPUT BAR
  // ==========================================
  Widget _buildComposeBar(bool isMobile) {
    if (_voiceNoteService.isRecording) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0x22160F2B),
          borderRadius: isMobile ? BorderRadius.zero : const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Color(0x35A855F7), width: 1.0)),
        ),
        child: Row(
          children: [
            // Pulsing Red REC Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x25EF4444),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0x60EF4444)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REC',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 6 : 12),

            // Live Timer
            Text(
              _voiceNoteService.formattedDuration,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isMobile ? 11.5 : 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: isMobile ? 6 : 14),

            // Live Waveform Visualizer
            Expanded(
              child: SizedBox(
                height: 22,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(isMobile ? 12 : 20, (i) {
                    final h = (0.25 + (0.75 * (i % 4 == 0 ? 0.9 : (i % 3 == 0 ? 0.6 : 0.35)))).clamp(0.2, 1.0);
                    return Container(
                      width: 2.2,
                      height: 22 * h,
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0x22F43F5E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x40F43F5E)),
                    ),
                    child: const Center(
                      child: Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 16),
                    ),
                  ),
                ),
              )
            else
              CyberButton(
                variant: CyberButtonVariant.danger,
                height: 36,
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, color: Color(0xFF090D16), size: 16),
                    ),
                  ),
                ),
              )
            else
              CyberButton(
                variant: CyberButtonVariant.emerald,
                height: 36,
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
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 14,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: isMobile ? BorderRadius.zero : const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Color(0x20FFFFFF), width: 1.0)),
      ),
      child: Row(
        children: [
          // Attach & Seal Asset Button
          if (isMobile)
            Tooltip(
              message: 'Attach & Seal Files',
              child: InkWell(
                onTap: _pickAndSealAsset,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x2210B981),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4010B981)),
                  ),
                  child: const Center(
                    child: Icon(Icons.attach_file_rounded, color: Color(0xFF34D399), size: 18),
                  ),
                ),
              ),
            )
          else
            CyberButton(
              variant: CyberButtonVariant.emerald,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              icon: Icons.attach_file_rounded,
              onTap: _pickAndSealAsset,
              child: const Text('Attach & Seal Asset'),
            ),
          SizedBox(width: isMobile ? 6 : 10),

          // Message Input Field with auto-focus & multiline breathing room
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
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: isMobile ? 13.0 : 13.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: isMobile ? 'Encrypted message...' : 'Type an encrypted P2P message...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: isMobile ? 12.5 : 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 5 : 8),

          // Send Audio File Button (Direct system audio file picker)
          Tooltip(
            message: 'Send Audio File (.mp3, .m4a, .wav)',
            child: InkWell(
              onTap: _pickAudioFileDirectly,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: isMobile ? 34 : 40,
                height: isMobile ? 34 : 40,
                decoration: BoxDecoration(
                  color: const Color(0x2238BDF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4038BDF8)),
                ),
                child: Center(
                  child: Icon(Icons.audio_file_rounded, color: const Color(0xFF38BDF8), size: isMobile ? 17 : 20),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 5 : 6),

          // WhatsApp-style Voice Note Mic Button
          Tooltip(
            message: 'Record Voice Note',
            child: InkWell(
              onTap: _startVoiceRecording,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: isMobile ? 34 : 40,
                height: isMobile ? 34 : 40,
                decoration: BoxDecoration(
                  color: const Color(0x22C084FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x40C084FC)),
                ),
                child: Center(
                  child: Icon(Icons.mic_rounded, color: const Color(0xFFC084FC), size: isMobile ? 18 : 21),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 5 : 6),

          // Send Button
          if (isMobile)
            Tooltip(
              message: 'Send',
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.send_rounded, color: Color(0xFF090D16), size: 16),
                  ),
                ),
              ),
            )
          else
            CyberButton(
              variant: CyberButtonVariant.whitePill,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              icon: Icons.send_rounded,
              onTap: _sendMessage,
              child: const Text('Send'),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// LIVE PEER TYPING ANIMATION BUBBLE
// ==========================================
class _TypingBubble extends StatefulWidget {
  final String peerName;

  const _TypingBubble({required this.peerName});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 14, bottom: 6, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x351F1538),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x30C084FC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.peerName} is typing',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC084FC),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final offset = ((_animController.value + index * 0.22) % 1.0);
                    final bounce = math.sin(offset * math.pi);
                    return Container(
                      width: 4.5,
                      height: 4.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      transform: Matrix4.translationValues(0, -3.5 * bounce.clamp(0.0, 1.0), 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          const Color(0xFF94A3B8),
                          const Color(0xFF38BDF8),
                          bounce.clamp(0.0, 1.0),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
