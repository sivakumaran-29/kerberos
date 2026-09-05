import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/home/presentation/home_screen.dart';
import 'shared/widgets/neomorphic_container.dart';
import 'features/ledger/services/ledger_service.dart';
import 'features/network/providers/network_providers.dart';

// Global Provider for the securely initialized ledger
final ledgerProvider = Provider<LedgerService>((ref) {
  throw UnimplementedError('LedgerService must be initialized before runApp');
});

void main() async {
  // Required for accessing platform channels (like path_provider/Hive) before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Strict Environment Load
  await dotenv.load(fileName: ".env");

  // 2. Air-gapped AES-256 Ledger Boot
  // If the key is missing or invalid, initialize() will throw a hard fault and crash 
  // the app, strictly enforcing the zero-trust paradigm.
  final secureLedger = LedgerService();
  await secureLedger.initialize();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the booted ledger into the provider tree
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
    // Eagerly boot signaling and WebRTC engine globally so handshakes are answered anywhere in the app
    ref.watch(webRtcServiceProvider);

    return MaterialApp(
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
