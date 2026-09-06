import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/theme/cyber_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../network/providers/network_providers.dart';
import '../models/radar_models.dart';
import '../providers/radar_providers.dart';
import '../services/p2p_session_service.dart';
import 'widgets/mentimeter_peer_mesh.dart';
import 'widgets/navigation_guard_dialog.dart';
import 'widgets/p2p_chat_screen.dart';

/// The Next-Generation Enclave Radar Page:
/// - Mentimeter-style floating/orbiting peer mesh representation
/// - Live node counter banner
/// - Instant P2P DTLS 1.3 handshake
/// - Full-featured encrypted P2P messaging interface with inline asset sealing
/// - Navigation protection against mid-transfer disconnects
class RadarPage extends ConsumerStatefulWidget {
  final Function(int targetTab)? onNavigateToTab;
  final Function(String fileName, Uint8List bytes)? onAuditInVerification;

  const RadarPage({
    super.key,
    this.onNavigateToTab,
    this.onAuditInVerification,
  });

  @override
  ConsumerState<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends ConsumerState<RadarPage> {
  @override
  Widget build(BuildContext context) {
    final sessionService = ref.watch(p2pSessionServiceProvider);
    final peers = ref.watch(radarPeersListProvider);
    final userProfile = ref.watch(userProfileProvider);
    final showSimulated = ref.watch(simulatedPeersEnabledProvider);
    final incomingRequest = ref.watch(incomingTransferNotifierProvider);

    final isSessionActive = sessionService.sessionState == P2PSessionState.connected ||
        sessionService.sessionState == P2PSessionState.awaitingHandshake;

    String currentPlatform = 'Desktop Node';
    try {
      if (kIsWeb) {
        currentPlatform = 'Web Browser';
      } else if (Platform.isWindows) {
        currentPlatform = 'Windows Enclave';
      } else if (Platform.isMacOS) {
        currentPlatform = 'macOS Node';
      } else if (Platform.isLinux) {
        currentPlatform = 'Linux Station';
      } else if (Platform.isAndroid) {
        currentPlatform = 'Android Vault';
      } else if (Platform.isIOS) {
        currentPlatform = 'iOS Hardware';
      }
    } catch (_) {}

    return Stack(
      children: [
        // Main Content: Mentimeter Mesh vs P2P Chat Screen
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: isSessionActive
              ? P2PChatScreen(
                  key: const ValueKey('p2p_chat_screen'),
                  sessionService: sessionService,
                  onDisconnect: () => _handleDisconnect(sessionService),
                  onAuditInVerification: (fileName, bytes) {
                    if (widget.onAuditInVerification != null) {
                      widget.onAuditInVerification!(fileName, bytes);
                    }
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(2); // Switch to Verify Tab
                    }
                  },
                )
              : MentimeterPeerMesh(
                  key: const ValueKey('mentimeter_peer_mesh'),
                  peers: peers,
                  myName: userProfile.displayName.isNotEmpty ? userProfile.displayName : 'Local Enclave',
                  myPlatform: currentPlatform,
                  isSimulatedActive: showSimulated,
                  onToggleSimulated: (val) {
                    ref.read(simulatedPeersEnabledProvider.notifier).state = val;
                  },
                  onRefresh: () {
                    ref.invalidate(discoveredPeersNotifierProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'MESH SCAN DISPATCHED // REFRESHING PEER TELEMETRY',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: CyberTheme.cyan,
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                  onPeerSelected: (peer) async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'INITIATING DTLS 1.3 HANDSHAKE WITH ${peer.displayName.toUpperCase()}...',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: CyberTheme.accentColor,
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                    await sessionService.connectToPeer(peer);
                  },
                ),
        ),

        // Incoming Transfer / Handshake Modal Overlay for the Radar Screen
        if (incomingRequest != null && !isSessionActive)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildIncomingInvitationCard(incomingRequest, sessionService),
          ),
      ],
    );
  }

  Widget _buildIncomingInvitationCard(
    IncomingTransferRequest request,
    P2PSessionService sessionService,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xF0130D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CyberTheme.emeraldLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CyberTheme.emerald.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CyberTheme.emerald.withValues(alpha: 0.2),
              border: Border.all(color: CyberTheme.emerald, width: 1.5),
            ),
            child: const Icon(Icons.wifi_tethering, color: CyberTheme.emerald, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'INCOMING P2P ENCLAVE INVITATION',
                      style: GoogleFonts.plusJakartaSans(
                        color: CyberTheme.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CyberTheme.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DTLS 1.3',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: CyberTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Agent ${request.senderName} (${request.senderEmail.isNotEmpty ? request.senderEmail : request.senderId.substring(0, 8)}) is requesting a direct P2P connection to exchange C2PA sealed assets.',
                  style: GoogleFonts.plusJakartaSans(
                    color: CyberTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CyberButton(
            variant: CyberButtonVariant.danger,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            onTap: () {
              ref.read(webRtcServiceProvider).declineIncomingTransfer(request.senderId);
              ref.read(incomingTransferNotifierProvider.notifier).clear();
            },
            child: const Text('DECLINE'),
          ),
          const SizedBox(width: 10),
          CyberButton(
            variant: CyberButtonVariant.emerald,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            onTap: () {
              final peer = RadarPeer(
                uuid: request.senderId,
                displayName: request.senderName,
                email: request.senderEmail,
                platform: 'Mesh Node',
                pingMs: 16,
              );
              ref.read(webRtcServiceProvider).acceptIncomingTransfer(request.senderId, request.offerPayload);
              ref.read(incomingTransferNotifierProvider.notifier).clear();
              sessionService.handleIncomingSessionAccepted(peer);
            },
            child: const Text('ACCEPT & CONNECT'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDisconnect(P2PSessionService sessionService) async {
    if (sessionService.hasActiveTransfer) {
      final shouldLeave = await NavigationGuardDialog.show(
        context,
        fileName: sessionService.activeTransferringFileName ?? 'digital asset',
        progress: sessionService.transferProgress,
      );

      if (shouldLeave) {
        await sessionService.disconnect();
      }
    } else {
      await sessionService.disconnect();
    }
  }
}
