import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/features/coach/domain/services/receipt_scanner_service.dart';

void main() {
  group('ReceiptScannerService Validation Tests', () {
    test('rejects null or empty bytes', () {
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'receipt.jpg',
        bytes: Uint8List(0),
      );
      expect(res, contains('File gambar rusak'));
    });

    test('rejects file larger than 2MB with exact spec copy', () {
      // 2MB + 1 byte
      final largeBytes = Uint8List(2 * 1024 * 1024 + 1);
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'receipt.jpg',
        bytes: largeBytes,
      );
      expect(res, equals('Gambar terlalu besar, silakan potong (crop) foto Anda.'));
    });

    test('rejects double extension attacks', () {
      final validBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final doubleExt1 = ReceiptScannerService.validateReceiptImage(
        fileName: 'nota.jpg.php',
        bytes: validBytes,
      );
      expect(doubleExt1, contains('ekstensi ganda'));

      final doubleExt2 = ReceiptScannerService.validateReceiptImage(
        fileName: 'receipt.png.exe',
        bytes: validBytes,
      );
      expect(doubleExt2, contains('ekstensi ganda'));
    });

    test('rejects non-image extensions', () {
      final validBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'document.pdf',
        bytes: validBytes,
      );
      expect(res, contains('Format file tidak didukung'));
    });

    test('rejects magic bytes mismatch (e.g. text file renamed to .jpg)', () {
      final textBytes = Uint8List.fromList('Hello World'.codeUnits);
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'fake_receipt.jpg',
        bytes: textBytes,
      );
      expect(res, contains('Magic Bytes mismatch'));
    });

    test('accepts valid JPEG file with correct magic bytes', () {
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,
      ]);
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'struk_alfa.jpg',
        bytes: jpegBytes,
      );
      expect(res, isNull);
    });

    test('accepts valid PNG file with correct magic bytes', () {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      final res = ReceiptScannerService.validateReceiptImage(
        fileName: 'struk_indomaret.png',
        bytes: pngBytes,
      );
      expect(res, isNull);
    });
  });
}
