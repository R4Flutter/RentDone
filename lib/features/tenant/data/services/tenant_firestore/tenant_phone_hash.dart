import 'dart:convert';

import 'package:crypto/crypto.dart';

String normalizeTenantPhone(String phone) =>
    phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();

String hashTenantPhone(String normalizedPhone) =>
    sha256.convert(utf8.encode(normalizedPhone)).toString();
