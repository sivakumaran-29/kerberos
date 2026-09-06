import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

/// Helper to download and save files cross-platform (Windows desktop, Web, macOS, Linux, Mobile).
class FileDownloadHelper {
  /// Prompts user with save dialog and writes bytes to chosen file path.
  static Future<String?> downloadFile({
    required BuildContext context,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      String? savedPath;

      if (kIsWeb) {
        // Web: file_picker saveFile with bytes prompts browser download directly
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Download $fileName',
          fileName: fileName,
          bytes: bytes,
        );
      } else {
        // Desktop / Mobile: Open native Save File Dialog
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save $fileName',
          fileName: fileName,
          bytes: bytes,
        );

        if (savedPath != null) {
          final file = File(savedPath);
          await file.writeAsBytes(bytes);
        } else {
          // Fallback: If user canceled dialog, allow quick saving to Downloads folder
          final downloadsDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          final fallbackPath = p.join(downloadsDir.path, fileName);
          final file = File(fallbackPath);
          await file.writeAsBytes(bytes);
          savedPath = fallbackPath;
        }
      }

      if (context.mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
            ),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0x2210B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Icon(Icons.download_done_rounded, color: Color(0xFF34D399), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File downloaded successfully',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$fileName (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return savedPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF43F5E),
            content: Text('Download failed: $e', style: GoogleFonts.plusJakartaSans()),
          ),
        );
      }
      return null;
    }
  }
}
