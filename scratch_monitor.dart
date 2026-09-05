import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: "client/.env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  final client = Supabase.instance.client;
  final channel = client.channel('kerberos_enclave');
  
  channel.onBroadcast(
    event: 'signal',
    callback: (payload) {
      print(">>> BROADCAST RECEIVED: ${payload['type']} from ${payload['sender_id']} to ${payload['target_id']}");
      if (payload['type'] == 'ice') {
        print("    ICE Candidate: ${payload['payload']['candidate']}");
      }
    }
  );
  
  channel.subscribe((status, [error]) {
    print("STATUS: $status");
  });
  
  print("Listening for signaling events...");
  await Future.delayed(Duration(minutes: 5));
}
