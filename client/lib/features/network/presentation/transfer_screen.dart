import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/neomorphic_container.dart';
import '../../../shared/widgets/neomorphic_button.dart';
import '../providers/network_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final TextEditingController _targetController = TextEditingController();
  double _receiverProgress = 0.0;
  bool _isReceiving = false;

  @override
  Widget build(BuildContext context) {
    // Zero-Trust Constraint: Keep WebRTC receiver pipeline active
    final webrtc = ref.watch(webRtcServiceProvider);
    final activeStatus = ref.watch(transferStatusNotifierProvider);
    final progressState = ref.watch(transferProgressNotifierProvider);

    // Bind receiver chunk tracking
    webrtc.onFileChunkReceived = (data) {
      if (!_isReceiving) {
        setState(() {
          _isReceiving = true;
          _receiverProgress = 0.5;
        });
      }
    };

    // Listen for incoming files on the receiver side
    ref.listen(webRtcServiceProvider, (previous, webrtcService) {
      webrtcService.onTransferComplete = () {
        setState(() {
          _isReceiving = false;
          _receiverProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'INCOMING ASSET SECURELY RECEIVED & CRYPTOGRAPHICALLY VERIFIED.',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      };
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Text('P2P WEBRTC // SECURE TRANSFER', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 48),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: NeomorphicContainer(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '> ZERO-TRUST P2P DTLS TUNNEL',
                              style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kAccentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kAccentColor.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'WEBRTC ONLY',
                                style: TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Live Status Bar
                        NeomorphicContainer(
                          depressed: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.sensors, color: kAccentColor, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  activeStatus,
                                  style: const TextStyle(
                                    color: kTextColor,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Discovered Peers List (AirDrop Style)
                        const Text('> DISCOVERED AGENTS (AIR-DROP)', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Consumer(builder: (context, ref, child) {
                          final peers = ref.watch(discoveredPeersNotifierProvider);
                          if (peers.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('  SCANNING LOCAL NETWORK FOR ACTIVE PEERS...', style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic)),
                            );
                          }
                          return Column(
                            children: peers.map((peer) {
                              final isSelected = _targetController.text == peer['uuid'];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: NeomorphicButton(
                                  isExpanded: true,
                                  onTap: () {
                                    setState(() {
                                      _targetController.text = peer['uuid'];
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.computer,
                                        color: isSelected ? Colors.green : kAccentColor,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '${peer['platform']}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    '[SELECTED]',
                                                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '${peer['uuid']}',
                                              style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                        const SizedBox(height: 32),
                        
                        // Input Target UUID (Manual Fallback)
                        NeomorphicContainer(
                          depressed: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _targetController,
                            style: const TextStyle(color: kTextColor, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'ENTER OR SELECT TARGET UUID...',
                              hintStyle: TextStyle(color: Colors.black26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        NeomorphicButton(
                          isExpanded: true,
                          onTap: () {
                            if (_targetController.text.isNotEmpty) {
                              ref.read(transferProgressNotifierProvider.notifier).startTransfer(_targetController.text.trim());
                            }
                          },
                          child: const Text('ENGAGE HANDSHAKE', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 36),
                        
                        // Receiver In-flight transfer indicator
                        if (_isReceiving) ...[
                          const Text('> RECEIVING ASSET OVER WEBRTC DATACHANNEL...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          NeomorphicContainer(
                            depressed: true,
                            height: 24,
                            padding: EdgeInsets.zero,
                            child: LinearProgressIndicator(
                              value: _receiverProgress > 0 ? _receiverProgress : null,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Sender Transfer Progress / Diagnostic Error
                        progressState.when(
                          data: (progress) {
                            if (progress == 0.0) return const SizedBox.shrink();
                            final percentage = (progress * 100).toStringAsFixed(1);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NeomorphicContainer(
                                  depressed: true,
                                  height: 32,
                                  padding: EdgeInsets.zero,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 100),
                                            width: constraints.maxWidth * progress,
                                            decoration: BoxDecoration(
                                              color: progress == 1.0 ? Colors.green.withValues(alpha: 0.8) : kAccentColor.withValues(alpha: 0.85),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      progress == 1.0 
                                          ? 'TRANSFER COMPLETE [100%]' 
                                          : 'STREAMING: $percentage% [16KB CHUNKS]', 
                                      style: const TextStyle(fontSize: 12, color: kTextColor, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                    ),
                                    if (progress == 1.0)
                                      NeomorphicButton(
                                        onTap: () {
                                          ref.read(transferProgressNotifierProvider.notifier).reset();
                                        },
                                        child: const Text('NEW TRANSFER', style: TextStyle(color: kAccentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                          loading: () => Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccentColor),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  '> $activeStatus',
                                  style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          error: (err, stack) {
                            final rawError = err.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                            return NeomorphicContainer(
                              depressed: true,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: kAlertColor, size: 22),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'WEBRTC / HANDSHAKE FAULT DETECTED',
                                          style: TextStyle(color: kAlertColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SelectableText(
                                    rawError,
                                    style: const TextStyle(
                                      color: kTextColor,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      NeomorphicButton(
                                        onTap: () {
                                          ref.read(transferProgressNotifierProvider.notifier).reset();
                                        },
                                        child: const Text(
                                          'RESET / RETRY HANDSHAKE',
                                          style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 36),
                        const Text(
                          'SECURITY NOTICE: ZERO-TRUST PROTOCOL ACTIVE.\n'
                          'Payload bytes are encrypted end-to-end via WebRTC DTLS/SCTP. No data is stored on signaling servers.',
                          style: TextStyle(color: Colors.black38, fontSize: 11, fontStyle: FontStyle.italic, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
