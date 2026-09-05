import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Zero-Trust Signaling Service using Supabase Realtime Channels.
/// Bypasses database tables entirely. Uses Broadcast for WebRTC signaling
/// and Presence for AirDrop-style Peer Discovery.
class SignalingService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  
  // Callbacks for WebRTC layer
  Function(Map<String, dynamic> offer, String senderId)? onOfferReceived;
  Function(Map<String, dynamic> answer)? onAnswerReceived;
  Function(Map<String, dynamic> iceCandidate)? onIceCandidateReceived;
  Function(String error)? onRemoteErrorReceived;
  
  // Callback for Peer Discovery
  Function(List<Map<String, dynamic>> peers)? onPeersUpdated;

  // Cached active peers in the enclave
  List<Map<String, dynamic>> currentPeers = [];

  final String _myUuid;

  SignalingService(this._supabase, this._myUuid);

  List<Map<String, dynamic>> getDiscoveredPeers() {
    if (_channel == null) return currentPeers;
    try {
      final state = _channel!.presenceState();
      final List<Map<String, dynamic>> discovered = [];
      for (final client in state) {
        for (final presence in client.presences) {
          final payload = presence.payload;
          if (payload['uuid'] != null && payload['uuid'] != _myUuid) {
            discovered.add({
              'uuid': payload['uuid'],
              'platform': payload['platform'] ?? 'Kerberos Agent',
              'online_at': payload['online_at'],
            });
          }
        }
      }
      if (discovered.isNotEmpty) {
        currentPeers = discovered;
      }
    } catch (_) {}
    return currentPeers;
  }

  void connect() {
    print(">> [Signaling] Booting Supabase enclave for UUID: $_myUuid");
    _channel = _supabase.channel('kerberos_enclave');

    // 1. Listen for Peer Discovery (Presence)
    _channel!.onPresenceSync((_) {
      final state = _channel!.presenceState();
      final List<Map<String, dynamic>> discoveredPeers = [];
      
      for (final client in state) {
        for (final presence in client.presences) {
          final payload = presence.payload;
          if (payload['uuid'] != null && payload['uuid'] != _myUuid) {
            discoveredPeers.add({
              'uuid': payload['uuid'],
              'platform': payload['platform'] ?? 'Kerberos Agent',
              'online_at': payload['online_at'],
            });
          }
        }
      }
      currentPeers = discoveredPeers;
      print(">> [Signaling] Discovered peers updated (${currentPeers.length} active): $currentPeers");
      onPeersUpdated?.call(currentPeers);
    });

    // 2. Listen for Secure Handshakes (Broadcast)
    _channel!.onBroadcast(
      event: 'signal',
      callback: (payload) {
        final targetId = payload['target_id'];
        if (targetId != _myUuid) return; // Ignore signals not meant for us

        final type = payload['type'] as String;
        final signalPayload = payload['payload'] as Map<String, dynamic>;
        final senderId = payload['sender_id'] as String;

        print(">> [Signaling] Received '$type' signal from $senderId");

        switch (type) {
          case 'offer':
            onOfferReceived?.call(signalPayload, senderId);
            break;
          case 'answer':
            onAnswerReceived?.call(signalPayload);
            break;
          case 'ice':
            onIceCandidateReceived?.call(signalPayload);
            break;
          case 'error':
            onRemoteErrorReceived?.call(signalPayload['error'] as String? ?? 'Remote fault');
            break;
        }
      }
    );

    // 3. Connect and broadcast our identity
    _channel!.subscribe((status, [error]) async {
      print(">> [Signaling] Channel status: $status");
      if (status == RealtimeSubscribeStatus.subscribed) {
        final platformName = kIsWeb ? 'Kerberos Web' : 'Kerberos Windows';
        await _channel!.track({
          'uuid': _myUuid,
          'platform': platformName,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Sends a signaling payload (SDP or ICE) directly through the broadcast tunnel.
  Future<void> sendSignal({
    required String targetId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    if (_channel == null) {
      throw Exception("Zero-Trust Fault: Signaling channel not established.");
    }

    print(">> [Signaling] Sending '$type' signal to $targetId");
    await _channel!.sendBroadcastMessage(
      event: 'signal',
      payload: {
        'sender_id': _myUuid,
        'target_id': targetId,
        'type': type,
        'payload': payload,
      },
    );
  }

  void dispose() {
    _channel?.unsubscribe();
  }
}
