import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';

import '../../../shared/theme/cyber_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../provenance/providers/provenance_providers.dart';
import '../../network/providers/network_providers.dart';
import '../../../main.dart'; // for ledgerProvider

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final TextEditingController _targetController = TextEditingController();
  bool _isDragging = false;
  double _receiverProgress = 0.0;
  bool _isReceiving = false;
  bool _showLedgerHistory = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final provenanceState = ref.watch(provenanceTaskNotifierProvider);
    final activeStatus = ref.watch(transferStatusNotifierProvider);
    final progressState = ref.watch(transferProgressNotifierProvider);
    final autoAccept = ref.watch(autoAcceptNotifierProvider);
    final incomingRequest = ref.watch(incomingTransferNotifierProvider);
    final peers = ref.watch(discoveredPeersNotifierProvider);
    final webrtc = ref.watch(webRtcServiceProvider);

    // Bind receiver chunk tracking
    webrtc.onFileChunkReceived = (data) {
      if (!_isReceiving) {
        setState(() {
          _isReceiving = true;
          _receiverProgress = 0.5;
        });
      }
    };

    webrtc.onTransferComplete = () {
      setState(() {
        _isReceiving = false;
        _receiverProgress = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'INCOMING ASSET CRYPTOGRAPHICALLY RECEIVED & SEALED TO LEDGER.',
            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          backgroundColor: CyberTheme.emerald,
          duration: Duration(seconds: 4),
        ),
      );
    };

    return Scaffold(
      backgroundColor: CyberTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Executive Glass Top Header
            _buildTopHeader(userProfile, peers.length),

            // 2. Main Dual-Engine Command Center
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      // Desktop / Wide Layout: Side-by-Side Dual Engines
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildProvenanceStudio(provenanceState),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _buildSecureTransferEngine(
                              peers: peers,
                              activeStatus: activeStatus,
                              progressState: progressState,
                              autoAccept: autoAccept,
                              incomingRequest: incomingRequest,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Narrow / Mobile Layout: Scrollable Vertical Stack
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildProvenanceStudio(provenanceState),
                            const SizedBox(height: 20),
                            _buildSecureTransferEngine(
                              peers: peers,
                              activeStatus: activeStatus,
                              progressState: progressState,
                              autoAccept: autoAccept,
                              incomingRequest: incomingRequest,
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ),

            // 3. Bottom Collapsible Ledger Audit Bar
            _buildLedgerBottomBar(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP HEADER: BRAND, TELEMETRY, & USER AUTH
  // ==========================================
  Widget _buildTopHeader(UserProfile profile, int activePeersCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: CyberTheme.surface.withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: CyberTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Project Brand & Status
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CyberTheme.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CyberTheme.cyanGlow, width: 1.2),
            ),
            child: const Icon(Icons.shield_outlined, color: CyberTheme.cyan, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'PROJECT KERBEROS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: CyberTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CyberTheme.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CyberTheme.emeraldGlow, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: CyberTheme.emerald, size: 6),
                        SizedBox(width: 5),
                        Text(
                          'ZERO-TRUST ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: CyberTheme.emerald,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'C2PA HARDWARE PROVENANCE // SERVERLESS WEBRTC ENCLAVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: CyberTheme.textMuted,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Radar telemetry counter badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CyberTheme.borderBright),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, color: CyberTheme.cyan, size: 14),
                const SizedBox(width: 8),
                Text(
                  '$activePeersCount AGENTS IN ENCLAVE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: CyberTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // User Profile Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CyberTheme.borderBright),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: CyberTheme.cyan.withValues(alpha: 0.2),
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: CyberTheme.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CyberTheme.textPrimary,
                      ),
                    ),
                    if (profile.email.isNotEmpty)
                      Text(
                        profile.email,
                        style: const TextStyle(
                          fontSize: 10,
                          color: CyberTheme.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: CyberTheme.surface,
                        title: const Text('Sign Out', style: TextStyle(color: CyberTheme.textPrimary)),
                        content: const Text('Are you sure you want to end your enclave session?', style: TextStyle(color: CyberTheme.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('SIGN OUT', style: TextStyle(color: CyberTheme.coral, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authServiceProvider).signOut();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.logout, size: 16, color: CyberTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PANEL 1: PROVENANCE STUDIO (INJECT & SEAL)
  // ==========================================
  Widget _buildProvenanceStudio(AsyncValue<dynamic> provenanceState) {
    return GlassContainer(
      glow: true,
      glowColor: CyberTheme.cyan,
      borderColor: CyberTheme.borderBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.fingerprint, color: CyberTheme.cyan, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'PROVENANCE STUDIO // INGEST & SEAL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: CyberTheme.cyan,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CyberTheme.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'C2PA + SHA-256',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CyberTheme.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Drag-and-Drop Ingestion Zone
          Expanded(
            flex: 4,
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                if (details.files.isNotEmpty) {
                  ref.read(provenanceTaskNotifierProvider.notifier).ingestFile(details.files.first);
                }
              },
              child: GestureDetector(
                onTap: _pickAndIngestFile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? CyberTheme.cyan.withValues(alpha: 0.15)
                        : CyberTheme.surfaceElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isDragging ? CyberTheme.cyanGlow : CyberTheme.borderBright,
                      width: _isDragging ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CyberTheme.cyan.withValues(alpha: 0.1),
                          border: Border.all(color: CyberTheme.cyanGlow, width: 1.2),
                        ),
                        child: const Icon(Icons.file_upload_outlined, color: CyberTheme.cyan, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isDragging ? 'RELEASE TO SEAL ASSET' : 'DROP ASSET OR CLICK TO INGEST',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: _isDragging ? CyberTheme.cyan : CyberTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Supports Images, Documents, PDFs, Audio (C2PA Hardware Signed)',
                        style: TextStyle(fontSize: 11, color: CyberTheme.textMuted),
                      ),
                      if (provenanceState.isLoading) ...[
                        const SizedBox(height: 16),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CyberTheme.cyan),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Steganography Vector Heatmap & Sealing Metadata
          Expanded(
            flex: 5,
            child: provenanceState.when(
              data: (metadata) {
                if (metadata == null) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: CyberTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CyberTheme.border),
                    ),
                    child: const Center(
                      child: Text(
                        '> ENCLAVE STANDBY: NO ASSET INGESTED YET',
                        style: TextStyle(color: CyberTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CyberTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CyberTheme.emeraldGlow, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: CyberTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'CRYPTOGRAPHIC PROVENANCE SEALED',
                            style: TextStyle(
                              color: CyberTheme.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CyberTheme.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('ED25519 VERIFIED', style: TextStyle(color: CyberTheme.emerald, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Heatmap representation if vector exists
                      if (metadata.perceptualHash != null && metadata.perceptualHash!.isNotEmpty) ...[
                        const Text('PERCEPTUAL VECTOR HEATMAP:', style: TextStyle(fontSize: 10, color: CyberTheme.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CyberTheme.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CustomPaint(
                              painter: CyberHeatMapRenderer(metadata.perceptualHash!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Hash and Path chips
                      _buildCryptoChip('FILE PATH', metadata.filePath),
                      const SizedBox(height: 8),
                      _buildCryptoChip('SHA-256 HASH', metadata.sha256Hash, isMonospace: true, copyable: true),
                    ],
                  ),
                );
              },
              error: (err, stack) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CyberTheme.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CyberTheme.coral),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: CyberTheme.coral, size: 18),
                        SizedBox(width: 8),
                        Text('ZERO-TRUST INGESTION FAULT', style: TextStyle(color: CyberTheme.coral, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(err.toString(), style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CyberTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CyberTheme.border),
                ),
                child: const Center(
                  child: Text(
                    '> CALCULATING SHA-256 & APPLYING C2PA SEAL...',
                    style: TextStyle(color: CyberTheme.cyan, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoChip(String label, String value, {bool isMonospace = false, bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CyberTheme.textMuted),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CyberTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: CyberTheme.textPrimary,
                      fontFamily: isMonospace ? 'monospace' : null,
                    ),
                  ),
                ),
                if (copyable)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hash copied to clipboard!'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Icon(Icons.copy, size: 13, color: CyberTheme.cyan),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndIngestFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        final name = result.files.single.name;
        if (bytes != null) {
          ref.read(provenanceTaskNotifierProvider.notifier).ingestFile(XFile.fromData(bytes, name: name));
        }
      } else {
        final pickedPath = result.files.single.path;
        if (pickedPath != null) {
          ref.read(provenanceTaskNotifierProvider.notifier).ingestFile(XFile(pickedPath));
        }
      }
    }
  }

  // ==========================================
  // PANEL 2: ENCLAVE RADAR (SECURE TRANSFER)
  // ==========================================
  Widget _buildSecureTransferEngine({
    required List<Map<String, dynamic>> peers,
    required String activeStatus,
    required AsyncValue<double> progressState,
    required bool autoAccept,
    required IncomingTransferRequest? incomingRequest,
  }) {
    return GlassContainer(
      glow: true,
      glowColor: CyberTheme.emerald,
      borderColor: CyberTheme.borderBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: CyberTheme.emerald, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'ENCLAVE RADAR // WEBRTC P2P TRANSFER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: CyberTheme.emerald,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Re-scan button
                  InkWell(
                    onTap: () => ref.invalidate(discoveredPeersNotifierProvider),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CyberTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: CyberTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 12, color: CyberTheme.cyan),
                          SizedBox(width: 4),
                          Text('RE-SCAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.cyan)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Auto-Accept toggle pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: autoAccept ? CyberTheme.emerald.withValues(alpha: 0.15) : CyberTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: autoAccept ? CyberTheme.emeraldGlow : CyberTheme.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          autoAccept ? 'AUTO-ACCEPT: ON' : 'AUTO-ACCEPT: OFF',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: autoAccept ? CyberTheme.emerald : CyberTheme.textMuted,
                          ),
                        ),
                        Switch.adaptive(
                          value: autoAccept,
                          activeThumbColor: CyberTheme.emerald,
                          onChanged: (val) => ref.read(autoAcceptNotifierProvider.notifier).set(val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // In-Line AirDrop Notification Prompt Card (Instant Action)
          if (incomingRequest != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CyberTheme.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CyberTheme.emeraldGlow, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: CyberTheme.emerald, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'INCOMING AIR-DROP: ${incomingRequest.senderName.toUpperCase()}',
                          style: const TextStyle(
                            color: CyberTheme.emerald,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CyberTheme.emerald,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ACTION REQUIRED', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Agent ${incomingRequest.senderName} (${incomingRequest.senderEmail.isNotEmpty ? incomingRequest.senderEmail : incomingRequest.senderId}) requests to stream an encrypted asset payload.',
                    style: const TextStyle(fontSize: 11, color: CyberTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CyberButton(
                        variant: CyberButtonVariant.danger,
                        height: 32,
                        onTap: () {
                          ref.read(webRtcServiceProvider).declineIncomingTransfer(incomingRequest.senderId);
                          ref.read(incomingTransferNotifierProvider.notifier).clear();
                        },
                        child: const Text('DECLINE'),
                      ),
                      const SizedBox(width: 10),
                      CyberButton(
                        variant: CyberButtonVariant.emerald,
                        height: 32,
                        onTap: () {
                          ref.read(webRtcServiceProvider).acceptIncomingTransfer(incomingRequest.senderId, incomingRequest.offerPayload);
                          ref.read(incomingTransferNotifierProvider.notifier).clear();
                        },
                        child: const Text('ACCEPT TRANSFER'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Discovered Active Peers List
          const Text(
            'ONLINE AGENTS (CLICK TO SELECT):',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CyberTheme.textMuted),
          ),
          const SizedBox(height: 8),

          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: CyberTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CyberTheme.border),
              ),
              child: peers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: 28, color: CyberTheme.textMuted),
                          SizedBox(height: 8),
                          Text(
                            'SCANNING ENCLAVE RADAR FOR ONLINE PEERS...',
                            style: TextStyle(fontSize: 11, color: CyberTheme.textMuted, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: peers.length,
                      itemBuilder: (context, index) {
                        final peer = peers[index];
                        final peerUuid = peer['uuid']?.toString() ?? '';
                        final peerName = peer['display_name']?.toString() ?? 'Kerberos Agent';
                        final peerEmail = peer['email']?.toString() ?? '';
                        final peerPlatform = peer['platform']?.toString() ?? 'Kerberos Agent';
                        final isSelected = _targetController.text == peerUuid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? CyberTheme.emerald.withValues(alpha: 0.12) : CyberTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? CyberTheme.emeraldGlow : CyberTheme.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () {
                              setState(() {
                                _targetController.text = peerUuid;
                              });
                            },
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected ? CyberTheme.emerald : CyberTheme.cyan.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: isSelected ? Colors.black : CyberTheme.cyan,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  peerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: CyberTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CyberTheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: CyberTheme.border),
                                  ),
                                  child: Text(
                                    peerPlatform,
                                    style: const TextStyle(fontSize: 9, color: CyberTheme.cyan, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              peerEmail.isNotEmpty ? '$peerEmail • $peerUuid' : peerUuid,
                              style: const TextStyle(fontSize: 10, color: CyberTheme.textMuted, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: CyberTheme.emerald, size: 18)
                                : const Icon(Icons.chevron_right, color: CyberTheme.textMuted, size: 18),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Target Selection Field & Trigger Handshake
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: CyberTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CyberTheme.borderBright),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _targetController,
                    style: const TextStyle(color: CyberTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'SELECT AGENT ABOVE OR PASTE TARGET UUID...',
                      hintStyle: TextStyle(color: CyberTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CyberButton(
                variant: CyberButtonVariant.emerald,
                height: 42,
                isLoading: progressState.isLoading,
                onTap: () {
                  if (_targetController.text.isNotEmpty) {
                    ref.read(transferProgressNotifierProvider.notifier).startTransfer(_targetController.text.trim());
                  }
                },
                child: const Text('ENGAGE HANDSHAKE'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live DTLS Status Telemetry Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CyberTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, color: CyberTheme.cyan, size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeStatus,
                    style: const TextStyle(
                      color: CyberTheme.textPrimary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // In-Flight Receiver Transfer Progress
          if (_isReceiving) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECEIVING ASSET OVER ENCRYPTED DTLS TUNNEL...', style: TextStyle(color: CyberTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('IN PROGRESS', style: TextStyle(color: CyberTheme.emerald, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _receiverProgress > 0 ? _receiverProgress : null,
                backgroundColor: CyberTheme.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(CyberTheme.emerald),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Sender Transfer Progress Indicator
          progressState.when(
            data: (progress) {
              if (progress > 0 && progress < 1.0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TRANSMITTING ENCRYPTED ASSET CHUNKS...', style: TextStyle(color: CyberTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('${(progress * 100).toInt()}%', style: const TextStyle(color: CyberTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: CyberTheme.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(CyberTheme.cyan),
                        minHeight: 10,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            error: (err, stack) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CyberTheme.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CyberTheme.coral),
              ),
              child: Text(
                err.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            loading: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM BAR: IMMUTABLE ZERO-TRUST LEDGER
  // ==========================================
  Widget _buildLedgerBottomBar() {
    final ledger = ref.watch(ledgerProvider);
    final history = ledger.getHistory();

    return Container(
      decoration: const BoxDecoration(
        color: CyberTheme.surface,
        border: Border(top: BorderSide(color: CyberTheme.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _showLedgerHistory = !_showLedgerHistory),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: CyberTheme.cyan, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'IMMUTABLE ZERO-TRUST LEDGER (${history.length} SEALED ASSETS)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _showLedgerHistory ? 'HIDE AUDIT TRAIL' : 'EXPAND AUDIT TRAIL',
                        style: const TextStyle(fontSize: 10, color: CyberTheme.cyan, fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        _showLedgerHistory ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        size: 16,
                        color: CyberTheme.cyan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showLedgerHistory)
            Container(
              height: 160,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: history.isEmpty
                  ? const Center(
                      child: Text('NO PROVENANCE ASSETS SEALED YET', style: TextStyle(color: CyberTheme.textMuted, fontSize: 11)),
                    )
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final record = history[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: CyberTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CyberTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: CyberTheme.emerald, size: 14),
                              const SizedBox(width: 10),
                              Text(record.filePath.split(RegExp(r'[\\/]')).last, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CyberTheme.textPrimary)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('SHA-256: ${record.originalFileHash}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: CyberTheme.textMuted), overflow: TextOverflow.ellipsis),
                              ),
                              Text(record.timestamp.toLocal().toString().substring(0, 16), style: const TextStyle(fontSize: 10, color: CyberTheme.textMuted)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

/// Hardware Accelerated Heatmap Renderer for Perceptual Hash
class CyberHeatMapRenderer extends CustomPainter {
  final List<double> vector;

  CyberHeatMapRenderer(this.vector);

  @override
  void paint(Canvas canvas, Size size) {
    if (vector.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    const int gridSize = 16;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int i = 0; i < 256; i++) {
      if (i >= vector.length) break;
      final row = i ~/ gridSize;
      final col = i % gridSize;
      final rect = Rect.fromLTWH(col * cellWidth, row * cellHeight, cellWidth, cellHeight);

      final intensity = vector[i];
      if (intensity < 0.3) {
        paint.color = CyberTheme.surfaceElevated;
      } else if (intensity < 0.7) {
        paint.color = CyberTheme.cyan.withValues(alpha: intensity);
      } else {
        paint.color = CyberTheme.emerald.withValues(alpha: intensity);
      }
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberHeatMapRenderer oldDelegate) {
    return oldDelegate.vector != vector;
  }
}
