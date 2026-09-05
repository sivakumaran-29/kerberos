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

  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(transferProgressNotifierProvider);

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
              
              NeomorphicContainer(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('> INITIATING ZERO-TRUST DTLS TUNNEL', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    // Discovered Peers List (AirDrop Style)
                    const Text('> DISCOVERED AGENTS (AIR-DROP)', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, child) {
                      final peers = ref.watch(discoveredPeersNotifierProvider);
                      if (peers.isEmpty) {
                        return const Text('  SCANNING LOCAL NETWORK...', style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic));
                      }
                      return Column(
                        children: peers.map((peer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: NeomorphicButton(
                              isExpanded: true,
                              onTap: () {
                                _targetController.text = peer['uuid'];
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.computer, color: kAccentColor),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${peer['platform']}', style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
                                      Text('${peer['uuid']}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
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
                          hintText: 'ENTER TARGET UUID...',
                          hintStyle: TextStyle(color: Colors.black26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    NeomorphicButton(
                      isExpanded: true,
                      onTap: () {
                        if (_targetController.text.isNotEmpty) {
                          ref.read(transferProgressNotifierProvider.notifier).startTransfer(_targetController.text);
                        }
                      },
                      child: const Text('ENGAGE HANDSHAKE', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 48),
                    
                    progressState.when(
                      data: (progress) {
                        if (progress == 0.0) return const SizedBox.shrink();
                        final percentage = (progress * 100).toStringAsFixed(1);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Light Depressed Progress Bar
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
                                          color: progress == 1.0 ? Colors.green.withOpacity(0.6) : kAccentColor.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              progress == 1.0 
                                  ? 'TRANSFER COMPLETE [100%]' 
                                  : 'TRANSFERRING: $percentage% [16KB CHUNKS]', 
                              style: const TextStyle(fontSize: 12, color: kTextColor, fontWeight: FontWeight.w600)
                            ),
                          ],
                        );
                      },
                      error: (err, stack) => const Text(
                        'CONNECTION TERMINATED.', 
                        style: TextStyle(color: kAlertColor, letterSpacing: 2, fontWeight: FontWeight.bold)
                      ),
                      loading: () => const Text('> EXECUTING STRICT HANDSHAKE...', style: TextStyle(color: kTextColor)),
                    ),
                    
                    const SizedBox(height: 48),
                    const Text(
                      'WARNING: SILENT INTEGRITY PROTOCOL ACTIVE.\n'
                      'If spoofing is detected, connection will terminate immediately without visual prompt.',
                      style: TextStyle(color: kTextColor, fontStyle: FontStyle.italic),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
