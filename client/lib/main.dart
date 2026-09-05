import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/theme/cyber_theme.dart';
import 'shared/widgets/glass_container.dart';
import 'shared/widgets/cyber_button.dart';
import 'features/ledger/services/ledger_service.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/network/providers/network_providers.dart';
import 'features/workspace/presentation/workspace_screen.dart';

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
        child: GlassContainer(
          width: 480,
          padding: const EdgeInsets.all(32),
          glow: true,
          glowColor: CyberTheme.emerald,
          borderColor: CyberTheme.emeraldGlow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberTheme.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, color: CyberTheme.emerald, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'INCOMING P2P AIR-DROP REQUEST',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: CyberTheme.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'A remote Kerberos agent is requesting to establish an end-to-end encrypted WebRTC DTLS tunnel to transfer a signed asset payload.',
                style: TextStyle(color: CyberTheme.textSecondary, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CyberTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CyberTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SENDER AGENT: ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.textMuted),
                        ),
                        Text(
                          request.senderName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CyberTheme.emerald),
                        ),
                      ],
                    ),
                    if (request.senderEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'EMAIL: ',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.textMuted),
                          ),
                          Text(
                            request.senderEmail,
                            style: const TextStyle(fontSize: 11, color: CyberTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'UUID: ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CyberTheme.textMuted),
                        ),
                        Expanded(
                          child: SelectableText(
                            request.senderId,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: CyberTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CyberButton(
                    variant: CyberButtonVariant.danger,
                    height: 38,
                    onTap: () {
                      isGlobalAirDropPromptOpen = false;
                      Navigator.pop(dialogContext);
                      ref.read(webRtcServiceProvider).declineIncomingTransfer(request.senderId);
                      ref.read(incomingTransferNotifierProvider.notifier).clear();
                    },
                    child: const Text('DECLINE'),
                  ),
                  const SizedBox(width: 14),
                  CyberButton(
                    variant: CyberButtonVariant.emerald,
                    height: 38,
                    onTap: () {
                      isGlobalAirDropPromptOpen = false;
                      Navigator.pop(dialogContext);
                      ref.read(webRtcServiceProvider).acceptIncomingTransfer(request.senderId, request.offerPayload);
                      ref.read(incomingTransferNotifierProvider.notifier).clear();
                    },
                    child: const Text('ACCEPT TRANSFER'),
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

  // 2. Global Supabase Client with persistent Auth Storage
  await Supabase.initialize(
    url: getSupabaseUrl(),
    anonKey: getSupabaseAnonKey(),
  );

  // 3. Air-gapped AES-256 Ledger Boot
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
    // Watch current user authentication state
    final currentUser = ref.watch(currentUserProvider);

    // Eagerly boot signaling, WebRTC, and incoming transfer listeners when authenticated
    if (currentUser != null) {
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
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Project Kerberos',
      theme: CyberTheme.darkTheme,
      home: currentUser != null ? const WorkspaceScreen() : const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
