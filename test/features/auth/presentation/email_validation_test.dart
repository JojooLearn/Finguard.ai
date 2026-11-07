import 'package:flutter_test/flutter_test.dart';
import 'package:email_validator/email_validator.dart';

void main() {
  group('Email Validation & Anti-Bot Filtering', () {
    const Set<String> disposableDomains = {
      'mailinator.com',
      'tempmail.com',
      'temp-mail.org',
      '10minutemail.com',
      'guerrillamail.com',
      'yopmail.com',
      'sharklasers.com',
      'throwawaymail.com',
      'getairmail.com',
      'dispostable.com',
    };

    String? validateEmail(String? value) {
      if (value == null || value.trim().isEmpty) return 'Email wajib diisi lah!';
      final email = value.trim();

      if (!EmailValidator.validate(email)) {
        return 'Format email tidak valid atau tidak lengkap!';
      }

      final atIndex = email.lastIndexOf('@');
      if (atIndex <= 0 || atIndex >= email.length - 1) {
        return 'Format email tidak valid!';
      }

      final localPart = email.substring(0, atIndex);
      final domain = email.substring(atIndex + 1).toLowerCase();

      if (localPart.length < 2) {
        return 'Username email terlalu pendek!';
      }

      final dotIndex = domain.lastIndexOf('.');
      if (dotIndex <= 0 || dotIndex >= domain.length - 2) {
        return 'Domain email tidak valid!';
      }

      final tld = domain.substring(dotIndex + 1);
      if (!RegExp(r'^[a-zA-Z]{2,}$').hasMatch(tld)) {
        return 'Akhiran domain email (.com, .id, dll) tidak valid!';
      }

      if (disposableDomains.contains(domain)) {
        return 'Email sementara / palsu tidak diizinkan! Gunakan email asli.';
      }

      return null;
    }

    test('accepts valid personal emails', () {
      expect(validateEmail('jojo@gmail.com'), isNull);
      expect(validateEmail('budi.santoso@yahoo.co.id'), isNull);
      expect(validateEmail('alex@company.org'), isNull);
    });

    test('rejects empty or whitespace', () {
      expect(validateEmail(''), 'Email wajib diisi lah!');
      expect(validateEmail('   '), 'Email wajib diisi lah!');
      expect(validateEmail(null), 'Email wajib diisi lah!');
    });

    test('rejects malformed syntax', () {
      expect(validateEmail('plainaddress'), isNotNull);
      expect(validateEmail('@missingusername.com'), isNotNull);
      expect(validateEmail('username@.com'), isNotNull);
      expect(validateEmail('user@domain..com'), isNotNull);
    });

    test('rejects disposable / temporary bot domains', () {
      expect(
        validateEmail('bot123@mailinator.com'),
        'Email sementara / palsu tidak diizinkan! Gunakan email asli.',
      );
      expect(
        validateEmail('spammer@tempmail.com'),
        'Email sementara / palsu tidak diizinkan! Gunakan email asli.',
      );
      expect(
        validateEmail('fake@yopmail.com'),
        'Email sementara / palsu tidak diizinkan! Gunakan email asli.',
      );
    });
  });
}

