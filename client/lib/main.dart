import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/home/presentation/home_screen.dart';
import 'shared/widgets/neomorphic_container.dart';
import 'shared/widgets/neomorphic_button.dart';
import 'features/ledger/services/ledger_service.dart';
import 'features/network/providers/network_providers.dart';
import 'features/network/presentation/transfer_screen.dart';

// Global Provider for the securely initialized ledger
final ledgerProvider = Provider<LedgerService>((ref) {
  throw UnimplementedError('LedgerService must be initialized before runApp');
});

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
bool isGlobalAirDropPromptOpen = false;

void showGlobalAirDropPrompt(BuildContext context, IncomingTransferRequest request, WidgetRef ref) {
  if (isGlobalAirDropPromptOpen) return;
  isGlobalAirDropPromptOpen = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: NeomorphicContainer(
          width: 480,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: kAccentColor, size: 28),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'INCOMING P2P AIR-DROP REQUEST',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextColor, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'A remote Kerberos agent is requesting to establish an end-to-end encrypted WebRTC DTLS tunnel to transfer an asset payload.',
                style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              NeomorphicContainer(
                depressed: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SENDER AGENT IDENTITY:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
                    const SizedBox(height: 4),
                    SelectableText(
                      request.senderId,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: kTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeomorphicButton(
                    onTap: () {
                      isGlobalAirDropPromptOpen = false;
                      Navigator.pop(dialogContext);
                      ref.read(webRtcServiceProvider).declineIncomingTransfer(request.senderId);
                      ref.read(incomingTransferNotifierProvider.notifier).clear();
                    },
                    child: const Text('DECLINE', style: TextStyle(color: kAlertColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 16),
                  NeomorphicButton(
                    onTap: () {
                      isGlobalAirDropPromptOpen = false;
                      Navigator.pop(dialogContext);
                      ref.read(webRtcServiceProvider).acceptIncomingTransfer(request.senderId, request.offerPayload);
                      ref.read(incomingTransferNotifierProvider.notifier).clear();
                      rootNavigatorKey.currentState?.push(
                        MaterialPageRoute(builder: (_) => const TransferScreen()),
                      );
                    },
                    child: const Text('ACCEPT TRANSFER', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Strict Environment Load
  await dotenv.load(fileName: ".env");

  // 2. Air-gapped AES-256 Ledger Boot
  final secureLedger = LedgerService();
  await secureLedger.initialize();

  runApp(
    ProviderScope(
      overrides: [
        ledgerProvider.overrideWithValue(secureLedger),
      ],
      child: const KerberosApp(),
    ),
  );
}

class KerberosApp extends ConsumerWidget {
  const KerberosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly boot signaling, WebRTC, and incoming transfer listeners globally
    ref.watch(webRtcServiceProvider);
    ref.watch(incomingTransferNotifierProvider);

    ref.listen<IncomingTransferRequest?>(incomingTransferNotifierProvider, (previous, request) {
      if (request != null) {
        final autoAccept = ref.read(autoAcceptNotifierProvider);
        if (!autoAccept) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showGlobalAirDropPrompt(ctx, request, ref);
            });
          }
        }
      }
    });

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Project Kerberos',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: kNeomorphicBaseColor,
        primaryColor: kNeomorphicBaseColor,
        iconTheme: const IconThemeData(color: kTextColor),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: kTextColor, fontFamily: 'monospace', letterSpacing: 1.2, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(color: kTextColor, fontFamily: 'monospace', letterSpacing: 1.0, fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.5),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
