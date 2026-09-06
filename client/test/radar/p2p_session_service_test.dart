import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kerberos_client/features/radar/models/radar_models.dart';
import 'package:kerberos_client/features/radar/services/p2p_session_service.dart';
import 'package:kerberos_client/features/network/services/webrtc_service.dart';
import 'package:kerberos_client/features/network/services/signaling_service.dart';
import 'package:kerberos_client/features/ledger/services/ledger_service.dart';

class MockWebRTCService extends Fake implements WebRTCService {
  @override
  bool get isConnected => true;
  @override
  void Function(String text)? onTextMessageReceived;
  @override
  Function(Uint8List data)? onFileChunkReceived;
  @override
  Function(double progress)? onTransferProgress;
  @override
  Function()? onTransferComplete;
  @override
  Function(RTCDataChannelState state)? onDataChannelStateChanged;
  @override
  Function(String error)? onRemoteErrorOccurred;
  @override
  Function(String senderId)? onCancelReceived;

  @override
  Future<void> sendTextMessage(String text) async {}

  @override
  Future<void> initiateTransfer(String targetId) async {}

  @override
  void closeConnection() {}
}

class MockSignalingService extends Fake implements SignalingService {
  @override
  List<Map<String, dynamic>> getDiscoveredPeers() => [];

  @override
  Future<void> sendSignal({
    required String targetId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {}
}

class MockLedgerService extends Fake implements LedgerService {
  @override
  Future<void> addRecord(dynamic record) async {}
}

void main() {
  group('P2P Radar & Session Logic Tests', () {
    test('RadarPeer model properties and copyWith', () {
      const peer = RadarPeer(
        uuid: 'test-peer-1',
        displayName: 'MacBook Pro Node',
        email: 'alex@domain.test',
        platform: 'macOS',
        pingMs: 12,
        isSimulated: true,
      );

      expect(peer.uuid, 'test-peer-1');
      expect(peer.displayName, 'MacBook Pro Node');
      expect(peer.isSimulated, isTrue);

      final updated = peer.copyWith(pingMs: 15);
      expect(updated.pingMs, 15);
      expect(updated.displayName, 'MacBook Pro Node');
    });

    test('P2PFileAttachment serialization round-trip', () {
      final attachment = P2PFileAttachment(
        fileId: 'f-123',
        fileName: 'classified_briefing.pdf',
        fileSizeBytes: 2048576,
        sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        c2paManifestUri: 'urn:c2pa:obsidian:e3b0c44298fc',
        isSealed: true,
      );

      final jsonMap = attachment.toJson();
      expect(jsonMap['fileId'], 'f-123');
      expect(jsonMap['fileName'], 'classified_briefing.pdf');
      expect(jsonMap['isSealed'], isTrue);

      final reconstructed = P2PFileAttachment.fromJson(jsonMap);
      expect(reconstructed.fileId, 'f-123');
      expect(reconstructed.sha256Hash, attachment.sha256Hash);
      expect(reconstructed.c2paManifestUri, attachment.c2paManifestUri);
    });

    test('P2PSessionService connection and simulated handshake lifecycle', () async {
      final session = P2PSessionService(
        webrtc: MockWebRTCService(),
        signaling: MockSignalingService(),
        ledger: MockLedgerService(),
      );

      expect(session.sessionState, P2PSessionState.discovery);
      expect(session.hasActiveTransfer, isFalse);

      const simPeer = RadarPeer(
        uuid: 'sim-mac',
        displayName: 'MacBook Pro M3 Max',
        email: 'alex@mac.internal',
        platform: 'macOS',
        isSimulated: true,
      );

      // Connect to simulated peer
      await session.connectToPeer(simPeer);
      expect(session.sessionState, P2PSessionState.connected);
      expect(session.activePeer?.displayName, 'MacBook Pro M3 Max');
      expect(session.messages.isNotEmpty, isTrue);

      // Send text message
      await session.sendTextMessage('Hello from enclave node');
      expect(session.messages.any((m) => m.text == 'Hello from enclave node' && m.isSelf), isTrue);

      // Clean disconnect
      await session.disconnect();
      expect(session.sessionState, P2PSessionState.discovery);
      expect(session.activePeer, isNull);
      expect(session.messages.isEmpty, isTrue);

      session.dispose();
    });

    test('User 1 initiates connection and cancels while awaiting handshake', () async {
      final session = P2PSessionService(
        webrtc: MockWebRTCService(),
        signaling: MockSignalingService(),
        ledger: MockLedgerService(),
      );

      const remotePeer = RadarPeer(
        uuid: 'remote-user-2',
        displayName: 'Sivakumaran',
        email: 'siva@enclave.io',
        platform: 'Windows Enclave',
        isSimulated: false,
      );

      // Start connecting (async)
      final future = session.connectToPeer(remotePeer);
      expect(session.sessionState, P2PSessionState.awaitingHandshake);
      expect(session.activePeer?.displayName, 'Sivakumaran');

      // User 1 decides to cancel
      await session.cancelHandshake();
      expect(session.sessionState, P2PSessionState.discovery);
      expect(session.activePeer, isNull);

      await future;
      session.dispose();
    });

    test('User 1 initiates connection and remote peer declines', () async {
      final mockWebRTC = MockWebRTCService();
      final session = P2PSessionService(
        webrtc: mockWebRTC,
        signaling: MockSignalingService(),
        ledger: MockLedgerService(),
      );

      String? declinedName;
      session.onHandshakeDeclined = (name, reason) {
        declinedName = name;
      };

      const remotePeer = RadarPeer(
        uuid: 'remote-user-2',
        displayName: 'Elena Rostova',
        email: 'elena@vault.io',
        platform: 'macOS Node',
        isSimulated: false,
      );

      final future = session.connectToPeer(remotePeer);
      expect(session.sessionState, P2PSessionState.awaitingHandshake);

      // Remote peer declines
      mockWebRTC.onRemoteErrorOccurred?.call('Recipient declined connection request');
      expect(session.sessionState, P2PSessionState.discovery);
      expect(session.activePeer, isNull);
      expect(declinedName, 'Elena Rostova');

      await future;
      session.dispose();
    });

    test('User 2 accepts incoming handshake and remains connected through DataChannelConnecting to Open', () async {
      final mockWebRTC = MockWebRTCService();
      final session = P2PSessionService(
        webrtc: mockWebRTC,
        signaling: MockSignalingService(),
        ledger: MockLedgerService(),
      );

      const senderPeer = RadarPeer(
        uuid: 'sender-user-1',
        displayName: 'Sivakumaran',
        email: 'siva@enclave.io',
        platform: 'Windows Enclave',
        isSimulated: false,
      );

      // User 2 accepts invitation
      session.handleIncomingSessionAccepted(senderPeer);
      expect(session.sessionState, P2PSessionState.connected);
      expect(session.activePeer?.displayName, 'Sivakumaran');

      // Intermediate RTCDataChannelConnecting MUST NOT disconnect User 2
      mockWebRTC.onDataChannelStateChanged?.call(RTCDataChannelState.RTCDataChannelConnecting);
      expect(session.sessionState, P2PSessionState.connected);

      // RTCDataChannelOpen confirms tunnel
      mockWebRTC.onDataChannelStateChanged?.call(RTCDataChannelState.RTCDataChannelOpen);
      expect(session.sessionState, P2PSessionState.connected);

      // Only RTCDataChannelClosed disconnects
      mockWebRTC.onDataChannelStateChanged?.call(RTCDataChannelState.RTCDataChannelClosed);
      expect(session.sessionState, P2PSessionState.disconnected);

      session.dispose();
    });
  });
}
