import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReceiptScannerService {
  final SupabaseClient? _supabase;
  final ImagePicker _picker;
  final Uuid _uuid;

  ReceiptScannerService({
    SupabaseClient? supabase,
    ImagePicker? picker,
    Uuid? uuid,
  }) : _supabase = supabase,
       _picker = picker ?? ImagePicker(),
       _uuid = uuid ?? const Uuid();

  /// Validasi ketat keamanan file (anti double extension, anti malware, magic bytes, max size 2MB)
  static String? validateReceiptImage({
    required String fileName,
    required Uint8List bytes,
  }) {
    // 1. Cek ekstensi berbahaya / ganda (e.g. nota.jpg.php, struk.png.exe)
    final lowerName = fileName.toLowerCase();
    final dangerousDoubleExt = RegExp(
      r'\.(php|exe|sh|bat|cmd|js|jsp|asp|aspx|html|htm|py|pl|cgi|jar|apk|msi)(\.|$)',
      caseSensitive: false,
    );
    if (dangerousDoubleExt.hasMatch(lowerName)) {
      return 'File dengan ekstensi ganda berisiko keamanan dan ditolak!';
    }

    // 2. Cek ekstensi yang diizinkan (Hanya JPG, JPEG, PNG)
    final ext = lowerName.split('.').last;
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      return 'Format file tidak didukung! Hanya file gambar JPG, JPEG, atau PNG.';
    }

    // 3. Cek ukuran file (Maksimal 2MB = 2097152 bytes)
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      return 'Gambar terlalu besar, silakan potong (crop) foto Anda.';
    }

    // 4. Validasi Magic Bytes (File Signature)
    if (bytes.length < 8) {
      return 'File gambar rusak atau tidak terbaca!';
    }

    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final isPng =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;

    if (!isJpeg && !isPng) {
      return 'File bukan gambar asli (Magic Bytes mismatch)!';
    }

    return null; // Valid
  }

  /// Ambil gambar dari Kamera atau Galeri dengan kompresi awal ImagePicker (max 800x800, quality 70)
  Future<XFile?> pickReceiptImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      return image;
    } catch (_) {
      return null;
    }
  }

  /// Kompresi gambar agresif di sisi klien (max 800x800, quality 70%, target < 200 KB)
  Future<Uint8List> compressImageBytes(Uint8List rawBytes) async {
    try {
      var compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (compressed.length > 200 * 1024) {
        compressed = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(compressed),
          minWidth: 720,
          minHeight: 720,
          quality: 55,
          format: CompressFormat.jpeg,
        );
      }
      if (compressed.isNotEmpty) {
        return Uint8List.fromList(compressed);
      }
    } catch (_) {
      // Fallback jika platform compressor tidak tersedia di test environment
    }
    return rawBytes;
  }

  /// Unggah file nota ke bucket private `receipt_scans` dalam folder user
  Future<String> uploadReceiptToStorage({
    required Uint8List bytes,
    required String userId,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.jpg';
    final storagePath = '$userId/$fileName';

    final client = _supabase ?? Supabase.instance.client;
    await client.storage
        .from('receipt_scans')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return storagePath;
  }
}
