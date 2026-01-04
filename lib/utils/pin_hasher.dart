import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hashes PIN with business ID/companyCode to avoid storing plaintext.
String hashPin(String companyCode, String pin) {
  final normalized = '${companyCode.trim().toUpperCase()}::${pin.trim()}';
  return sha256.convert(utf8.encode(normalized)).toString();
}
