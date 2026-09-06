import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:kerberos_client/features/ledger/models/provenance_record.dart';
import 'package:kerberos_client/features/verification/models/verification_models.dart';
import 'package:kerberos_client/features/verification/services/verification_service.dart';

void main() {
  group('Zero-Trust Content-Addressable Verification Tests', () {
    late Uint8List originalBytes;
    late String originalHash;
    late ProvenanceRecord sealedRecord;

    setUp(() {
      originalBytes = Uint8List.fromList(utf8.encode('CONFIDENTIAL_OBSIDIAN_PAYLOAD_V2_DATA'));
      originalHash = sha256.convert(originalBytes).toString();

      sealedRecord = ProvenanceRecord(
        id: 'rec-uuid-001',
        originalFileHash: originalHash,
        c2paManifestUri: 'urn:c2pa:obsidian:${originalHash.substring(0, 12)}',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        signature: 'ed25519-signature-token',
        filePath: 'quarterly_financials_2026.pdf',
      );
    });

    test('Identifies renamed file with identical bitstream as pristineSealed', () {
      final report = VerificationService.analyzeAsset(
        bytes: originalBytes,
        fileName: 'renamed_copy_financials.pdf', // Renamed by user!
        ledgerHistory: [sealedRecord],
      );

      expect(report.verdict, equals(VerificationVerdict.pristineSealed));
      expect(report.bitstream.isMatch, isTrue);
      expect(report.isRenamed, isTrue);
      expect(report.originalSealedName, equals('quarterly_financials_2026.pdf'));
      expect(report.fileName, equals('renamed_copy_financials.pdf'));
      expect(report.matchedRecord?.id, equals('rec-uuid-001'));
      expect(report.matchReason, contains('File was renamed from "quarterly_financials_2026.pdf"'));
    });

    test('Identifies tampered bitstream when 1 byte is flipped (Hex attack)', () {
      final pristineReport = VerificationService.analyzeAsset(
        bytes: originalBytes,
        fileName: 'quarterly_financials_2026.pdf',
        ledgerHistory: [sealedRecord],
      );

      final tamperedReport = VerificationService.simulateHexEditorAttack(pristineReport);

      expect(tamperedReport.verdict, equals(VerificationVerdict.bitstreamShattered));
      expect(tamperedReport.bitstream.isMatch, isFalse);
      expect(tamperedReport.bitstream.flippedBytesCount, equals(1));
      expect(tamperedReport.bitstream.stealthAlertTriggered, isTrue);
    });

    test('Explicit targetRecordId successfully detects bitstream divergence for renamed tampered file', () {
      // Simulate 1 byte change
      final tamperedBytes = Uint8List.fromList(originalBytes);
      tamperedBytes[5] = tamperedBytes[5] ^ 0x01;

      final report = VerificationService.analyzeAsset(
        bytes: tamperedBytes,
        fileName: 'attacker_altered.pdf',
        ledgerHistory: [sealedRecord],
        targetRecordId: 'rec-uuid-001',
      );

      expect(report.verdict, equals(VerificationVerdict.bitstreamShattered));
      expect(report.bitstream.isMatch, isFalse);
      expect(report.matchedRecord?.id, equals('rec-uuid-001'));
      expect(report.originalSealedName, equals('quarterly_financials_2026.pdf'));
    });

    test('Marks unsealed files as unsealed when no match exists in ledger and no C2PA envelope', () {
      final foreignBytes = Uint8List.fromList(utf8.encode('COMPLETELY_UNRELATED_FILE_FROM_INTERNET'));
      final report = VerificationService.analyzeAsset(
        bytes: foreignBytes,
        fileName: 'cat_picture.jpg',
        ledgerHistory: [], // Empty ledger
      );

      expect(report.verdict, equals(VerificationVerdict.unsealed));
      expect(report.matchedRecord, isNull);
    });
  });
}
