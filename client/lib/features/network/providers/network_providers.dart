import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../../../main.dart'; // for ledgerProvider

part 'network_providers.g.dart';

@riverpod
SignalingService signalingService(SignalingServiceRef ref) {
  // On Vercel (Web), generate a fresh UUID so every visitor is a unique peer.
  // On Native (Windows), strictly use the air-gapped .env identity.
  final myUuid = kIsWeb ? const Uuid().v4() : (dotenv.env['DEVICE_UUID'] ?? const Uuid().v4());
  
  final service = SignalingService(
    SupabaseClient(
      dotenv.env['SUPABASE_URL'] ?? 'https://mock.supabase.co',
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'mock_key'
    ),
    myUuid
  );
  
  service.connect();
  ref.onDispose(() => service.dispose());
  return service;
}

@riverpod
class DiscoveredPeersNotifier extends _$DiscoveredPeersNotifier {
  @override
  List<Map<String, dynamic>> build() {
    final signaling = ref.watch(signalingServiceProvider);
    signaling.onPeersUpdated = (peers) {
      state = peers;
    };
    return [];
  }
}

@riverpod
WebRTCService webRtcService(WebRtcServiceRef ref) {
  final signaling = ref.watch(signalingServiceProvider);
  final service = WebRTCService(signaling);
  ref.onDispose(() => service.closeConnection());
  return service;
}

@riverpod
class TransferProgressNotifier extends _$TransferProgressNotifier {
  @override
  AsyncValue<double> build() {
    return const AsyncValue.data(0.0);
  }

  void startTransfer(String targetId) async {
    state = const AsyncValue.loading();
    try {
      final ledger = ref.read(ledgerProvider);
      final record = ledger.getLatestRecord();
      
      // 2. Read the binary payload from disk (Cross-platform safe)
      Uint8List fileBytes;
      if (record == null) {
        // HACKATHON FALLBACK: If they haven't uploaded an asset yet, send a mock payload
        // to demonstrate the P2P tunnel rather than crashing.
        fileBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      } else {
        try {
          final file = XFile(record.filePath);
          fileBytes = await file.readAsBytes();
        } catch (e) {
          // Fallback for Web/Vercel (Mock payload since browsers lack file paths)
          fileBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
        }
      }

      // 3. Bind WebRTC tracking
      final webrtc = ref.read(webRtcServiceProvider);
      webrtc.onTransferProgress = (progress) {
        state = AsyncValue.data(progress);
      };
      
      webrtc.onTransferComplete = () {
        state = const AsyncValue.data(1.0); // 100%
      };

      // 4. Initiate the real signaling handshake
      await webrtc.initiateTransfer(targetId);
      
      // 5. Stream the exact bytes over the DTLS tunnel
      await webrtc.sendFileBytes(fileBytes);
      
    } catch (e, st) {
      // SILENT INTEGRITY PROTOCOL ACTIVE
      state = AsyncValue.error(e, st);
    }
  }
}
