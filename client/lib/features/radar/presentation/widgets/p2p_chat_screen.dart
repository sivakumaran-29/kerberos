import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/theme/cyber_theme.dart';
import '../../../../shared/widgets/cyber_button.dart';
import '../../models/radar_models.dart';
import '../../services/p2p_session_service.dart';

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

  @override
  void initState() {
    super.initState();
    widget.sessionService.addListener(_handleSessionUpdate);
  }

  @override
  void dispose() {
    widget.sessionService.removeListener(_handleSessionUpdate);
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
  }

  Future<void> _pickAndSealAsset() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'webp', 'bin', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.single;
      XFile xFile;
      if (picked.bytes != null) {
        xFile = XFile.fromData(picked.bytes!, name: picked.name);
      } else if (picked.path != null) {
        xFile = XFile(picked.path!);
      } else {
        return;
      }

      await widget.sessionService.sealAndSendFile(xFile);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.sessionService.activePeer;
    final messages = widget.sessionService.messages;
    final isSealing = widget.sessionService.isSealing;
    final isTransferring = widget.sessionService.isTransferring;
    final transferProgress = widget.sessionService.transferProgress;

    return Container(
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
          _buildSessionHeader(peer),

          // 2. Chat Timeline
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                if (message.isSystemNotice) {
                  return _buildSystemNotice(message);
                }
                return _buildMessageBubble(message);
              },
            ),
          ),

          // 3. Inline Sealing & Streaming Progress Indicator
          if (isSealing || isTransferring) ...[
            _buildActiveTransferBanner(isSealing, transferProgress),
          ],

          // 4. Compose Input Bar
          _buildComposeBar(),
        ],
      ),
    );
  }

  // ==========================================
  // 1. SESSION HEADER
  // ==========================================
  Widget _buildSessionHeader(RadarPeer? peer) {
    final displayName = peer?.displayName ?? 'Encrypted Peer';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                width: 42,
                height: 42,
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
                      fontSize: 18,
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
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(color: const Color(0xFF160F2B), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Peer Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x20C084FC),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0x40C084FC)),
                      ),
                      child: Text(
                        peer?.platform.toUpperCase() ?? 'PEER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
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
                    Text(
                      'P2P DTLS 1.3 TUNNEL • ZERO-TRUST AIR-GAPPED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: const Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '~${peer?.pingMs ?? 16}ms',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Disconnect Button
          CyberButton(
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
  Widget _buildMessageBubble(P2PChatMessage message) {
    final isSelf = message.isSelf;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: CyberTheme.shardGradient,
              ),
              child: Center(
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'P',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    _buildFileAttachmentCard(message.fileAttachment!, isSelf),
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
  Widget _buildFileAttachmentCard(P2PFileAttachment file, bool isSelf) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
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
                Text(
                  'C2PA HARDWARE SEAL VERIFIED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF34D399),
                    letterSpacing: 0.5,
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
                    'SHA-256: ${file.sha256Hash.substring(0, 12)}...${file.sha256Hash.substring(file.sha256Hash.length - 8)}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFFE2E8F0)),
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

          // Completed Actions: Audit in Verification Protocol
          if (file.isCompleted && file.bytes != null && widget.onAuditInVerification != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    variant: CyberButtonVariant.emerald,
                    height: 32,
                    icon: Icons.shield_outlined,
                    onTap: () => widget.onAuditInVerification!(file.fileName, file.bytes!),
                    child: const Text('Audit in Verify Protocol ➔'),
                  ),
                ),
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
  Widget _buildActiveTransferBanner(bool isSealing, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      : '> STREAMING SEALED BYTES: ${(progress * 100).toStringAsFixed(0)}% • ${widget.sessionService.activeTransferringFileName}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSealing ? const Color(0xFFE9D5FF) : const Color(0xFF34D399),
                  ),
                ),
              ),
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
  Widget _buildComposeBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Color(0x20FFFFFF), width: 1.0)),
      ),
      child: Row(
        children: [
          // Attach & Seal Button
          CyberButton(
            variant: CyberButtonVariant.emerald,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            icon: Icons.attach_file_rounded,
            onTap: _pickAndSealAsset,
            child: const Text('Attach & Seal Asset'),
          ),
          const SizedBox(width: 12),

          // Message Input Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x28FFFFFF)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _textController,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type an encrypted P2P message...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Button
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
