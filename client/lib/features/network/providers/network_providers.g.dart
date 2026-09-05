// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$signalingServiceHash() => r'b27ae392b8e26563a182c394e2cda528d0d08e3b';

/// See also [signalingService].
@ProviderFor(signalingService)
final signalingServiceProvider = AutoDisposeProvider<SignalingService>.internal(
  signalingService,
  name: r'signalingServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$signalingServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SignalingServiceRef = AutoDisposeProviderRef<SignalingService>;
String _$webRtcServiceHash() => r'2a4592e97485e4ce31a5f91d8452e4ada332d7cf';

/// See also [webRtcService].
@ProviderFor(webRtcService)
final webRtcServiceProvider = AutoDisposeProvider<WebRTCService>.internal(
  webRtcService,
  name: r'webRtcServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$webRtcServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef WebRtcServiceRef = AutoDisposeProviderRef<WebRTCService>;
String _$discoveredPeersNotifierHash() =>
    r'1f65170788dd4ec31fcd992ddfb862f35d0933ef';

/// See also [DiscoveredPeersNotifier].
@ProviderFor(DiscoveredPeersNotifier)
final discoveredPeersNotifierProvider = AutoDisposeNotifierProvider<
    DiscoveredPeersNotifier, List<Map<String, dynamic>>>.internal(
  DiscoveredPeersNotifier.new,
  name: r'discoveredPeersNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$discoveredPeersNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DiscoveredPeersNotifier
    = AutoDisposeNotifier<List<Map<String, dynamic>>>;
String _$transferProgressNotifierHash() =>
    r'0df1db53fb2005e9c3210245def9b29b6430cd6c';

/// See also [TransferProgressNotifier].
@ProviderFor(TransferProgressNotifier)
final transferProgressNotifierProvider = AutoDisposeNotifierProvider<
    TransferProgressNotifier, AsyncValue<double>>.internal(
  TransferProgressNotifier.new,
  name: r'transferProgressNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transferProgressNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransferProgressNotifier = AutoDisposeNotifier<AsyncValue<double>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
