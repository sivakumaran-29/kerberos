import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService _signaling;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  Function(Uint8List data)? onFileChunkReceived;
  Function()? onTransferComplete;
  Function(double progress)? onTransferProgress;

  WebRTCService(this._signaling) {
    _signaling.onOfferReceived = _handleOffer;
    _signaling.onAnswerReceived = _handleAnswer;
    _signaling.onIceCandidateReceived = _handleIceCandidate;
  }

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // NAT traversal
    ]
  };

  Future<void> _initializeConnection(String targetId) async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _signaling.sendSignal(
        targetId: targetId,
        type: 'ice',
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _dataChannel = channel;
      _setupDataChannelListeners();
    };
  }

  Future<void> initiateTransfer(String targetId) async {
    await _initializeConnection(targetId);

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30;

    _dataChannel = await _peerConnection!.createDataChannel('secure_file_transfer', dataChannelDict);
    _setupDataChannelListeners();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _signaling.sendSignal(
      targetId: targetId,
      type: 'offer',
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  Future<void> _handleOffer(Map<String, dynamic> payload, String senderId) async {
    await _initializeConnection(senderId);
    final offer = RTCSessionDescription(payload['sdp'], payload['type']);
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _signaling.sendSignal(
      targetId: senderId,
      type: 'answer',
      payload: {'sdp': answer.sdp, 'type': answer.type},
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    final answer = RTCSessionDescription(payload['sdp'], payload['type']);
    await _peerConnection!.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> payload) async {
    final candidate = RTCIceCandidate(payload['candidate'], payload['sdpMid'], payload['sdpMLineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  void _setupDataChannelListeners() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        if (message.text == 'EOF') {
          onTransferComplete?.call();
        } else {
          closeConnection();
          throw Exception("SILENT INTEGRITY PROTOCOL: Invalid non-binary payload detected.");
        }
        return;
      }
      onFileChunkReceived?.call(message.binary);
    };
  }

  Future<void> sendFileBytes(Uint8List fileBytes) async {
    // Zero-Trust Constraint: Wait dynamically until the handshake actually opens the tunnel.
    int retries = 0;
    while ((_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception("Zero-Trust Fault: Signaling handshake timed out. Tunnel could not be established.");
    }

    const int chunkSize = 16384; // 16KB chunks
    int offset = 0;

    while (offset < fileBytes.length) {
      int end = (offset + chunkSize < fileBytes.length) ? offset + chunkSize : fileBytes.length;
      final chunk = fileBytes.sublist(offset, end);
      
      // Actual native byte transmission over the data channel
      await _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
      
      offset += chunkSize;
      onTransferProgress?.call(offset / fileBytes.length);
    }

    await _dataChannel!.send(RTCDataChannelMessage("EOF"));
    onTransferComplete?.call();
  }

  void closeConnection() {
    _dataChannel?.close();
    _peerConnection?.close();
  }
}
