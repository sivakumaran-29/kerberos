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
          if (payload['uuid'] != null && payload['uuid'].toString().toLowerCase() != _myUuid.toLowerCase()) {
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
          if (payload['uuid'] != null && payload['uuid'].toString().toLowerCase() != _myUuid.toLowerCase()) {
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
      callback: (Map<String, dynamic> raw) {
        print(">> [Signaling] Broadcast payload received: $raw");

        // Normalize payload in case realtime-client wraps or unwraps it
        Map<String, dynamic> msg = raw;
        if (raw.containsKey('payload') && raw['payload'] is Map<String, dynamic>) {
          final inner = raw['payload'] as Map<String, dynamic>;
          if (inner.containsKey('target_id') || inner.containsKey('type')) {
            msg = inner;
          }
        }

        final rawTargetId = msg['target_id']?.toString();
        if (rawTargetId == null) {
          print(">> [Signaling] Broadcast ignored: missing 'target_id'. Msg: $msg");
          return;
        }

        final targetId = rawTargetId.trim().toLowerCase();
        final myId = _myUuid.trim().toLowerCase();

        print(">> [Signaling] Checking targetId: '$targetId' vs myUuid: '$myId'");
        if (targetId != myId) {
          print(">> [Signaling] Signal not for us. Ignored.");
          return;
        }

        final type = msg['type']?.toString();
        final senderId = msg['sender_id']?.toString() ?? 'unknown';
        final signalPayload = msg['payload'] is Map<String, dynamic>
            ? msg['payload'] as Map<String, dynamic>
            : <String, dynamic>{};

        print(">> [Signaling] MATCH! Dispatching '$type' signal from $senderId");

        switch (type) {
          case 'offer':
            print(">> [Signaling] Firing onOfferReceived for $senderId");
            onOfferReceived?.call(signalPayload, senderId);
            break;
          case 'answer':
            print(">> [Signaling] Firing onAnswerReceived");
            onAnswerReceived?.call(signalPayload);
            break;
          case 'ice':
            onIceCandidateReceived?.call(signalPayload);
            break;
          case 'error':
            onRemoteErrorReceived?.call(signalPayload['error']?.toString() ?? 'Remote fault');
            break;
        }
      }
    );

    // 3. Connect and broadcast our identity
    _channel!.subscribe((status, [error]) async {
      print(">> [Signaling] Channel subscription status: $status (error: $error)");
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

    print(">> [Signaling] Outbound '$type' signal to $targetId");
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
