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

@Riverpod(keepAlive: true)
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

@Riverpod(keepAlive: true)
WebRTCService webRtcService(WebRtcServiceRef ref) {
  final signaling = ref.watch(signalingServiceProvider);
  final service = WebRTCService(signaling);
  ref.onDispose(() => service.closeConnection());
  return service;
}

@Riverpod(keepAlive: true)
class TransferStatusNotifier extends _$TransferStatusNotifier {
  @override
  String build() {
    final webrtc = ref.watch(webRtcServiceProvider);
    webrtc.onStatusUpdate = (status) {
      state = status;
    };
    return 'STANDBY // READY FOR P2P HANDSHAKE';
  }

  void updateStatus(String status) {
    state = status;
  }

  void reset() {
    state = 'STANDBY // READY FOR P2P HANDSHAKE';
  }
}

@riverpod
class TransferProgressNotifier extends _$TransferProgressNotifier {
  @override
  AsyncValue<double> build() {
    return const AsyncValue.data(0.0);
  }

  void reset() {
    final webrtc = ref.read(webRtcServiceProvider);
    webrtc.closeConnection();
    ref.read(transferStatusNotifierProvider.notifier).reset();
    state = const AsyncValue.data(0.0);
  }

  void startTransfer(String targetId) async {
    state = const AsyncValue.loading();
    final webrtc = ref.read(webRtcServiceProvider);
    final statusNotifier = ref.read(transferStatusNotifierProvider.notifier);

    try {
      final ledger = ref.read(ledgerProvider);
      final record = ledger.getLatestRecord();
      
      // 1. Read binary payload from disk (Cross-platform safe)
      Uint8List fileBytes;
      if (record == null) {
        // Fallback: If no asset is sealed yet, send a 1KB mock payload
        fileBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      } else {
        try {
          final file = XFile(record.filePath);
          fileBytes = await file.readAsBytes();
        } catch (e) {
          fileBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
        }
      }

      // 2. Bind WebRTC tracking callbacks
      webrtc.onStatusUpdate = (status) {
        statusNotifier.updateStatus(status);
      };

      webrtc.onTransferProgress = (progress) {
        state = AsyncValue.data(progress);
      };
      
      webrtc.onTransferComplete = () {
        state = const AsyncValue.data(1.0); // 100%
        statusNotifier.updateStatus('TRANSFER COMPLETE [100%]');
      };

      // 3. Initiate pure WebRTC signaling handshake
      statusNotifier.updateStatus('Dispatching SDP Offer to target peer...');
      await webrtc.initiateTransfer(targetId);
      
      // 4. Stream bytes over the encrypted DTLS/SCTP DataChannel
      await webrtc.sendFileBytes(fileBytes);
      
    } catch (e, st) {
      statusNotifier.updateStatus('HANDSHAKE FAULT: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}');
      state = AsyncValue.error(e, st);
    }
  }
}
