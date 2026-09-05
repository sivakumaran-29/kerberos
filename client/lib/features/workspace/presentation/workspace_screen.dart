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
import '../../../shared/widgets/shards_background.dart';
import '../../auth/providers/auth_providers.dart';
import '../../provenance/providers/provenance_providers.dart';
import '../../network/providers/network_providers.dart';
import '../../../main.dart'; // for ledgerProvider

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _targetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;
  double _receiverProgress = 0.0;
  bool _isReceiving = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _targetController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToSection(double offset) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Enclave Session?', style: TextStyle(color: CyberTheme.textPrimary)),
        content: const Text('You will be signed out of this Kerberos node.', style: TextStyle(color: CyberTheme.textSecondary)),
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
  }

  void _showSpecsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CyberTheme.borderAccent),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: CyberTheme.shardGradient,
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Wind Sculpture Specs',
              style: TextStyle(color: CyberTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpecRow('Flow', 'stream'),
            _buildSpecRow('Material', 'pearl'),
            _buildSpecRow('Detail', 'balanced'),
            _buildSpecRow('Interaction', 'repel'),
            _buildSpecRow('Chromatic Aberration', '0.0075 (Cyan / Coral)'),
            const Divider(color: CyberTheme.border, height: 20),
            _buildSpecRow('Background Color', '#120F17'),
            _buildSpecRow('Shard Color', '#896ABD'),
            _buildSpecRow('Accent Color', '#A855F7'),
          ],
        ),
        actions: [
          CyberButton(
            variant: CyberButtonVariant.whitePill,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onTap: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CyberTheme.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: CyberTheme.textPrimary, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        ],
      ),
    );
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
            'INCOMING ASSET SECURELY RECEIVED & VERIFIED IN LEDGER.',
            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          backgroundColor: CyberTheme.emerald,
          duration: Duration(seconds: 4),
        ),
      );
    };

    return Scaffold(
      backgroundColor: CyberTheme.background,
      body: Stack(
        children: [
          // 1. 3D Prismatic Shards ("Wind Sculpture") Interactive Engine
          const Positioned.fill(
            child: ShardsBackground(),
          ),

          // 2. Scrollable Page Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: Column(
                    children: [
                      // Floating Glass Navbar (React Bits style)
                      _buildFloatingNavbar(userProfile, peers.length, autoAccept),
                      const SizedBox(height: 36),

                      // Dribbble SaaS Hero Section
                      _buildHeroSection(),
                      const SizedBox(height: 44),

                      // Flagship Bento Grid (Live Functional Engines)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 920) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildProvenanceStudio(provenanceState),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: _buildSecureTransferRadar(
                                    peers: peers,
                                    activeStatus: activeStatus,
                                    progressState: progressState,
                                    incomingRequest: incomingRequest,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildProvenanceStudio(provenanceState),
                                const SizedBox(height: 24),
                                _buildSecureTransferRadar(
                                  peers: peers,
                                  activeStatus: activeStatus,
                                  progressState: progressState,
                                  incomingRequest: incomingRequest,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 28),

                      // Bottom Bento Card: Immutable Zero-Trust Ledger
                      _buildLedgerAuditTrail(),
                      const SizedBox(height: 40),

                      // Footer
                      _buildFooter(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          title,
          style: const TextStyle(
            color: CyberTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FLOATING GLASS NAVBAR (REACT BITS STYLE)
  // ==========================================
  Widget _buildFloatingNavbar(UserProfile profile, int activePeersCount, bool autoAccept) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      borderRadius: 100,
      showSheen: true,
      borderColor: CyberTheme.border,
      child: Row(
        children: [
          // Logo & Brand (React Bits / Project Kerberos)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: CyberTheme.shardGradient,
              boxShadow: [
                BoxShadow(
                  color: CyberTheme.accentColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'React Bits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: CyberTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CyberTheme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: CyberTheme.borderAccent),
            ),
            child: const Text(
              'KERBEROS',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Color(0xFFC084FC),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Center Navigation Links (Matching Screenshot 1)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavLink('Studio', () => _scrollToSection(220)),
                const SizedBox(width: 14),
                _buildNavLink('Radar', () => _scrollToSection(600)),
                const SizedBox(width: 14),
                _buildNavLink('Ledger', () => _scrollToSection(950)),
                const SizedBox(width: 14),
                _buildNavLink('Wind Specs', _showSpecsDialog),
              ],
            ),
          ),

          // Telemetry Peer Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: CyberTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering, size: 12, color: CyberTheme.cyan),
                const SizedBox(width: 5),
                Text(
                  '$activePeersCount ONLINE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: CyberTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Auto-Accept Toggle Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: autoAccept ? CyberTheme.emerald.withValues(alpha: 0.15) : CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: autoAccept ? CyberTheme.borderEmerald : CyberTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  autoAccept ? 'AUTO: ON' : 'AUTO: OFF',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: autoAccept ? CyberTheme.emerald : CyberTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 16,
                  width: 28,
                  child: Switch.adaptive(
                    value: autoAccept,
                    activeThumbColor: CyberTheme.emerald,
                    onChanged: (val) => ref.read(autoAcceptNotifierProvider.notifier).set(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // User Profile Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: CyberTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: CyberTheme.accentColor.withValues(alpha: 0.3),
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Color(0xFFC084FC),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CyberTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Solid White Pill Button (React Bits Navbar Right CTA)
          CyberButton(
            variant: CyberButtonVariant.whitePill,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: _confirmSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HERO SECTION (REACT BITS STYLE)
  // ==========================================
  Widget _buildHeroSection() {
    return Column(
      children: [
        // Announcement Badge Pill (Matching Screenshot 1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x22A855F7),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0x44A855F7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Color(0xFF120F17),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Creative Components // Digital Provenance',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios, size: 9, color: CyberTheme.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bold Crisp Modern Sans Headline (Matching Screenshot 1)
        const Text(
          "Don't touch them, they are pretty sharp!\nHardware-Sealed Digital Originals.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: Colors.white,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 14),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Text(
            'Interactive 3D Prismatic Shards protecting true digital originals. Seal assets with C2PA hardware manifests, extract perceptual hash vectors, and stream encrypted payloads directly between peers over WebRTC DTLS tunnels.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: CyberTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Hero Action Buttons (Solid White Pill + Translucent Glass Pill)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CyberButton(
              variant: CyberButtonVariant.whitePill,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              icon: Icons.upload_file,
              onTap: _pickAndIngestFile,
              child: const Text('Get started'),
            ),
            const SizedBox(width: 14),
            CyberButton(
              variant: CyberButtonVariant.glassPill,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              icon: Icons.radar,
              onTap: () => _scrollToSection(600),
              child: const Text('Learn more'),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // BENTO CARD 1: PROVENANCE STUDIO (INGEST & SEAL)
  // ==========================================
  Widget _buildProvenanceStudio(AsyncValue<dynamic> provenanceState) {
    return GlassContainer(
      glow: true,
      glowColor: CyberTheme.cyan,
      borderColor: CyberTheme.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bento Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberTheme.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CyberTheme.borderCyan),
                    ),
                    child: const Icon(Icons.fingerprint, color: CyberTheme.cyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROVENANCE STUDIO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'C2PA HARDWARE MANIFEST & PERCEPTUAL VECTOR',
                        style: TextStyle(fontSize: 10, color: CyberTheme.textMuted, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CyberTheme.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: CyberTheme.borderCyan),
                ),
                child: const Text('ED25519 READY', style: TextStyle(color: CyberTheme.cyan, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dotted Cyber Ingestion Portal
          DropTarget(
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
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? CyberTheme.accentColor.withValues(alpha: 0.18)
                      : CyberTheme.surfaceElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isDragging ? CyberTheme.accentColor : CyberTheme.borderShard,
                    width: _isDragging ? 2 : 1.2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CyberTheme.shardGradient,
                        boxShadow: [
                          BoxShadow(
                            color: CyberTheme.accentColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isDragging ? 'RELEASE TO SEAL ASSET' : 'DRAG & DROP ASSET HERE OR BROWSE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: _isDragging ? const Color(0xFFC084FC) : CyberTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Supports Images, RAW, Documents, PDFs, Video (Automatic C2PA Sealing)',
                      style: TextStyle(fontSize: 11, color: CyberTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    CyberButton(
                      variant: CyberButtonVariant.whitePill,
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      icon: Icons.folder_open,
                      onTap: _pickAndIngestFile,
                      child: const Text('Browse Device'),
                    ),
                    if (provenanceState.isLoading) ...[
                      const SizedBox(height: 18),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: CyberTheme.accentColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sealing Results & Cryptographic Inspector
          provenanceState.when(
            data: (metadata) {
              if (metadata == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CyberTheme.surfaceElevated.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CyberTheme.border),
                  ),
                  child: const Center(
                    child: Text(
                      'STANDBY: INGEST AN ASSET TO CALCULATE PERCEPTUAL VECTOR & SEAL WITH C2PA',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CyberTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                );
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CyberTheme.surfaceElevated.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CyberTheme.borderEmerald, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: CyberTheme.emerald.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: CyberTheme.emerald, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'C2PA HARDWARE SEAL VERIFIED',
                          style: TextStyle(
                            color: CyberTheme.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
                          child: const Text('IMMUTABLE HASH', style: TextStyle(color: CyberTheme.emerald, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vector Spectrum Equalizer Visualizer
                    if (metadata.perceptualHash != null && metadata.perceptualHash!.isNotEmpty) ...[
                      const Text(
                        'PERCEPTUAL VECTOR SPECTRUM (256-D EMBEDDING):',
                        style: TextStyle(fontSize: 10, color: CyberTheme.textMuted, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: CyberTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CyberTheme.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CustomPaint(
                            painter: CyberHeatMapRenderer(metadata.perceptualHash!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildDetailRow('FILE PATH', metadata.filePath),
                    const SizedBox(height: 8),
                    _buildDetailRow('SHA-256', metadata.sha256Hash, isMonospace: true, copyable: true),
                  ],
                ),
              );
            },
            error: (err, stack) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberTheme.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CyberTheme.coral.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Fault: ${err.toString()}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            loading: () => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CyberTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CyberTheme.border),
              ),
              child: const Center(
                child: Text('> APPLYING ED25519 DIGITAL SIGNATURE & C2PA SEAL...', style: TextStyle(color: CyberTheme.cyan, fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false, bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CyberTheme.textMuted)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CyberTheme.surface,
              borderRadius: BorderRadius.circular(8),
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
                    child: const Icon(Icons.copy, size: 14, color: CyberTheme.cyan),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BENTO CARD 2: ENCLAVE RADAR (SECURE AIRDROP)
  // ==========================================
  Widget _buildSecureTransferRadar({
    required List<Map<String, dynamic>> peers,
    required String activeStatus,
    required AsyncValue<double> progressState,
    required IncomingTransferRequest? incomingRequest,
  }) {
    return GlassContainer(
      glow: true,
      glowColor: CyberTheme.emerald,
      borderColor: CyberTheme.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bento Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CyberTheme.borderEmerald),
                    ),
                    child: const Icon(Icons.radar, color: CyberTheme.emerald, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ENCLAVE RADAR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'WEBRTC DTLS 1.3 / SCTP P2P AIRDROP',
                        style: TextStyle(fontSize: 10, color: CyberTheme.textMuted, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () => ref.invalidate(discoveredPeersNotifierProvider),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: CyberTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: CyberTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 12, color: CyberTheme.cyan),
                      SizedBox(width: 6),
                      Text('SCAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.cyan)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // In-Line AirDrop Notification Prompt
          if (incomingRequest != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberTheme.emerald.withValues(alpha: 0.2),
                    CyberTheme.surfaceElevated,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CyberTheme.emeraldLight, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: CyberTheme.emerald.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CyberTheme.emerald.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.security, color: CyberTheme.emerald, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'INCOMING AIRDROP: ${incomingRequest.senderName.toUpperCase()}',
                          style: const TextStyle(
                            color: CyberTheme.emerald,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agent ${incomingRequest.senderName} (${incomingRequest.senderEmail.isNotEmpty ? incomingRequest.senderEmail : incomingRequest.senderId}) is requesting to stream an encrypted asset payload.',
                    style: const TextStyle(fontSize: 11, color: CyberTheme.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CyberButton(
                        variant: CyberButtonVariant.danger,
                        height: 34,
                        onTap: () {
                          ref.read(webRtcServiceProvider).declineIncomingTransfer(incomingRequest.senderId);
                          ref.read(incomingTransferNotifierProvider.notifier).clear();
                        },
                        child: const Text('DECLINE'),
                      ),
                      const SizedBox(width: 10),
                      CyberButton(
                        variant: CyberButtonVariant.emerald,
                        height: 34,
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
            const SizedBox(height: 18),
          ],

          // Discovered Agents Radar List
          const Text(
            'ACTIVE AGENTS IN RANGE (CLICK TO AIRDROP):',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: CyberTheme.textMuted),
          ),
          const SizedBox(height: 10),

          Container(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 240),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CyberTheme.border),
            ),
            child: peers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CyberTheme.cyan.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: CyberTheme.cyan.withValues(alpha: 0.2 + (_pulseController.value * 0.4)),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(Icons.radar, color: CyberTheme.cyan, size: 22),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pinging Supabase enclave channel for online peers...',
                          style: TextStyle(fontSize: 11, color: CyberTheme.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    shrinkWrap: true,
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? CyberTheme.emerald.withValues(alpha: 0.12) : CyberTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? CyberTheme.emeraldLight : CyberTheme.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? CyberTheme.emerald : CyberTheme.cyan.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: isSelected ? Colors.black : CyberTheme.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        peerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: CyberTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CyberTheme.surfaceElevated,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: CyberTheme.border),
                                        ),
                                        child: Text(
                                          peerPlatform,
                                          style: const TextStyle(fontSize: 9, color: CyberTheme.cyanLight, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    peerEmail.isNotEmpty ? '$peerEmail • $peerUuid' : peerUuid,
                                    style: const TextStyle(fontSize: 10, color: CyberTheme.textMuted, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            CyberButton(
                              variant: isSelected ? CyberButtonVariant.emerald : CyberButtonVariant.purple,
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              onTap: () {
                                setState(() {
                                  _targetController.text = peerUuid;
                                });
                                ref.read(transferProgressNotifierProvider.notifier).startTransfer(peerUuid);
                              },
                              child: Text(isSelected ? 'ENGAGE' : 'AIRDROP'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Manual UUID Input & Handshake Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: CyberTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CyberTheme.borderBright),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _targetController,
                    style: const TextStyle(color: CyberTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'SELECT AGENT ABOVE OR ENTER TARGET UUID...',
                      hintStyle: TextStyle(color: CyberTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CyberButton(
                variant: CyberButtonVariant.whitePill,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                isLoading: progressState.isLoading,
                onTap: () {
                  if (_targetController.text.isNotEmpty) {
                    ref.read(transferProgressNotifierProvider.notifier).startTransfer(_targetController.text.trim());
                  }
                },
                child: const Text('START TRANSFER'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live DTLS Telemetry Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CyberTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CyberTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, color: CyberTheme.cyan, size: 16),
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
          const SizedBox(height: 14),

          // Progress Bars
          if (_isReceiving) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RECEIVING ENCRYPTED ASSET OVER DTLS TUNNEL...', style: TextStyle(color: CyberTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('${(_receiverProgress * 100).toInt()}%', style: const TextStyle(color: CyberTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _receiverProgress > 0 ? _receiverProgress : null,
                backgroundColor: CyberTheme.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(CyberTheme.emerald),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 14),
          ],

          progressState.when(
            data: (progress) {
              if (progress > 0 && progress < 1.0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TRANSMITTING STREAM OVER SCTP DATACHANNEL...', style: TextStyle(color: CyberTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('${(progress * 100).toInt()}%', style: const TextStyle(color: CyberTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: CyberTheme.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(CyberTheme.cyan),
                        minHeight: 8,
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
                borderRadius: BorderRadius.circular(10),
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
  // BENTO CARD 3: IMMUTABLE ZERO-TRUST LEDGER
  // ==========================================
  Widget _buildLedgerAuditTrail() {
    final ledger = ref.watch(ledgerProvider);
    final history = ledger.getHistory();

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderColor: CyberTheme.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberTheme.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x666366F1)),
                    ),
                    child: const Icon(Icons.receipt_long, color: CyberTheme.indigo, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMMUTABLE ZERO-TRUST LEDGER',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'AIR-GAPPED AES-256 ENCRYPTED AUDIT TRAIL',
                        style: TextStyle(fontSize: 10, color: CyberTheme.textMuted, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CyberTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: CyberTheme.border),
                ),
                child: Text(
                  '${history.length} SEALED ASSETS',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.cyanLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Text(
                'NO ASSETS RECORDED IN AIR-GAPPED LEDGER YET',
                style: TextStyle(color: CyberTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length > 5 ? 5 : history.length,
              itemBuilder: (context, index) {
                final record = history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CyberTheme.surfaceElevated.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CyberTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: CyberTheme.emerald, size: 16),
                      const SizedBox(width: 12),
                      Text(
                        record.filePath.split(RegExp(r'[\\/]')).last,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CyberTheme.textPrimary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'SHA-256: ${record.originalFileHash}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: CyberTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CyberTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CyberTheme.border),
                        ),
                        child: Text(
                          record.timestamp.toLocal().toString().substring(0, 16),
                          style: const TextStyle(fontSize: 10, color: CyberTheme.textMuted, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: CyberTheme.border, thickness: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROJECT KERBEROS // THE LAST ORIGINAL',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: CyberTheme.textMuted),
            ),
            Text(
              'C2PA STANDARD • AES-256-GCM • WEBRTC DTLS 1.3 • SUPABASE REALTIME',
              style: TextStyle(fontSize: 9, color: CyberTheme.textMuted.withValues(alpha: 0.8), letterSpacing: 0.8),
            ),
          ],
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
        paint.color = CyberTheme.shardColor.withValues(alpha: intensity);
      } else {
        paint.color = CyberTheme.accentColor.withValues(alpha: intensity);
      }
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberHeatMapRenderer oldDelegate) {
    return oldDelegate.vector != vector;
  }
}
