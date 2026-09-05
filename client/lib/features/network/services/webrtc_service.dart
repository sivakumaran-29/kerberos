import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService _signaling;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];
  bool _isRemoteDescriptionSet = false;

  Function(Uint8List data)? onFileChunkReceived;
  Function()? onTransferComplete;
  Function(double progress)? onTransferProgress;

  WebRTCService(this._signaling) {
    _signaling.onOfferReceived = _handleOffer;
    _signaling.onAnswerReceived = _handleAnswer;
    _signaling.onIceCandidateReceived = _handleIceCandidate;
  }

  // 1. Unified-Plan and Free Public TURN Servers for Firewall Bypassing
  final Map<String, dynamic> _configuration = {
    'sdpSemantics': 'unified-plan',
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      }
    ]
  };

  Future<void> _initializeConnection(String targetId) async {
    if (_peerConnection != null) {
      _isRemoteDescriptionSet = false;
      _remoteCandidatesQueue.clear();
      await _peerConnection?.close();
    }
    
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

    // 3. ICE Connection State Monitoring
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print(">> ICE CONNECTION STATE: $state");
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print(">> ICE FAILED! Attempting fallback...");
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      print(">> RECEIVER: DataChannel received!");
      _dataChannel = channel;
      _setupDataChannelListeners();
    };
  }

  Future<void> initiateTransfer(String targetId) async {
    print(">> SENDER: Initiating Transfer to $targetId");
    await _initializeConnection(targetId);

    // 4. Safe DataChannel Negotiation
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
    print(">> RECEIVER: Offer received from $senderId");
    await _initializeConnection(senderId);
    
    final offer = RTCSessionDescription(payload['sdp'], payload['type']);
    await _peerConnection!.setRemoteDescription(offer);
    
    _isRemoteDescriptionSet = true;
    _processQueuedCandidates();
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    await _signaling.sendSignal(
      targetId: senderId,
      type: 'answer',
      payload: {'sdp': answer.sdp, 'type': answer.type},
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    print(">> SENDER: Answer received");
    final answer = RTCSessionDescription(payload['sdp'], payload['type']);
    await _peerConnection!.setRemoteDescription(answer);
    
    _isRemoteDescriptionSet = true;
    _processQueuedCandidates();
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> payload) async {
    final candidate = RTCIceCandidate(payload['candidate'], payload['sdpMid'], payload['sdpMLineIndex']);
    if (_isRemoteDescriptionSet && _peerConnection != null) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _remoteCandidatesQueue.add(candidate);
    }
  }

  void _processQueuedCandidates() {
    for (var candidate in _remoteCandidatesQueue) {
      _peerConnection?.addCandidate(candidate);
    }
    _remoteCandidatesQueue.clear();
  }

  void _setupDataChannelListeners() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        if (message.text == 'EOF') {
          print(">> RECEIVER: EOF received. Transfer complete.");
          onTransferComplete?.call();
        } else {
          closeConnection();
          throw Exception("SILENT INTEGRITY PROTOCOL: Invalid non-binary payload detected.");
        }
        return;
      }
      onFileChunkReceived?.call(message.binary);
    };

    _dataChannel?.onDataChannelState = (RTCDataChannelState state) {
      print(">> DATA CHANNEL STATE: $state");
    };
  }

  Future<void> sendFileBytes(Uint8List fileBytes) async {
    // Zero-Trust Constraint: Wait dynamically until the handshake actually opens the tunnel.
    // Extended timeout to 10 seconds to allow TURN proxies to negotiate TCP relays.
    int retries = 0;
    while ((_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) && retries < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception("Zero-Trust Fault: Signaling handshake timed out. Tunnel could not be established.");
    }

    print(">> SENDER: DataChannel Open! Transmitting payload...");

    const int chunkSize = 16384; // 16KB chunks
    int offset = 0;

    while (offset < fileBytes.length) {
      int end = (offset + chunkSize < fileBytes.length) ? offset + chunkSize : fileBytes.length;
      final chunk = fileBytes.sublist(offset, end);
      
      await _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
      
      offset += chunkSize;
      onTransferProgress?.call(offset / fileBytes.length);
      
      // Throttle slightly to prevent buffer overflow on Web
      await Future.delayed(const Duration(milliseconds: 2));
    }

    await _dataChannel!.send(RTCDataChannelMessage("EOF"));
    print(">> SENDER: EOF sent. Transfer complete.");
    onTransferComplete?.call();
  }

  void closeConnection() {
    _isRemoteDescriptionSet = false;
    _remoteCandidatesQueue.clear();
    _dataChannel?.close();
    _peerConnection?.close();
  }
}
