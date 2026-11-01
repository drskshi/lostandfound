import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Shared demo password for the seeded sample accounts on this phone.
const demoPassword = 'lost-and-found-demo';

const categories = [
  'Electronics',
  'Bags',
  'Bottles & cups',
  'Keys',
  'Clothing',
  'Books & stationery',
  'Accessories',
];

const colours = [
  'Black',
  'White',
  'Grey',
  'Silver',
  'Navy',
  'Blue',
  'Green',
  'Red',
  'Pink',
  'Purple',
  'Yellow',
  'Orange',
  'Brown',
  'Beige',
  'Cream',
  'Gold',
  'Multicoloured',
];

const stopWords = {
  'a',
  'an',
  'and',
  'the',
  'of',
  'in',
  'on',
  'at',
  'to',
  'with',
  'my',
  'it',
  'is',
  'was',
  'i',
  'for',
  'near',
  'by',
  'from',
  'this',
  'that',
  'has',
  'have',
  'had',
  'or',
  'but',
  'left',
  'lost',
  'found',
  'me',
  'please',
};

const handoverDays = 7;
const maxActiveClaims = 3;
const maxCodeAttempts = 5;

String hashPassword(String password) {
  return sha256.convert(utf8.encode('ulf-local:$password')).toString();
}

String newCode(int value) => value.toString().padLeft(6, '0');

List<String> tokenize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 1 && !stopWords.contains(word))
      .map(_stem)
      .toList();
}

String _stem(String word) {
  if (word.length > 4 && word.endsWith('ies'))
    return '${word.substring(0, word.length - 3)}y';
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

class Assist {
  const Assist({required this.score, required this.matched});
  final int score;
  final List<String> matched;
}

/// Hint for a reviewer. This never approves a claim by itself.
Assist verificationAssist(String? privateDetails, String claimText) {
  final secret = tokenize(privateDetails ?? '').toSet().toList();
  if (secret.isEmpty) return const Assist(score: 0, matched: []);
  final claim = tokenize(claimText).toSet();
  final matched = secret.where(claim.contains).toList();
  final denom = secret.length < 6 ? secret.length : 6;
  final score = ((matched.length / denom).clamp(0, 1) * 100).round();
  return Assist(score: score, matched: matched);
}

class Risk {
  const Risk({required this.level, required this.signals});
  final String level;
  final List<String> signals;
}

Risk claimRisk({
  required double accountAgeDays,
  required int claimsLast30Days,
  required int rejectedClaims,
  required int distinctCategories,
  required int flaggedMessages,
  required int assistScore,
}) {
  final signals = <String>[];
  var points = 0;
  if (accountAgeDays < 2) {
    points += 2;
    signals.add('Account created in the last 48 hours');
  }
  if (claimsLast30Days >= 4) {
    points += 2;
    signals.add('$claimsLast30Days claims in the last 30 days');
  }
  if (rejectedClaims >= 2) {
    points += 3;
    signals.add('$rejectedClaims earlier claims were not approved');
  } else if (rejectedClaims == 1) {
    points += 1;
    signals.add('1 earlier claim was not approved');
  }
  if (distinctCategories >= 3) {
    points += 2;
    signals.add('Claimed items in several unrelated categories this month');
  }
  if (flaggedMessages > 0) {
    points += 2;
    signals.add('Messages mentioned payment or contact details');
  }
  if (assistScore < 20) {
    points += 2;
    signals.add('Mentions few of the private details');
  }
  final level = points >= 5
      ? 'high'
      : points >= 2
      ? 'medium'
      : 'low';
  return Risk(level: level, signals: signals);
}

class Screened {
  const Screened({
    required this.text,
    required this.flagged,
    required this.reasons,
  });
  final String text;
  final bool flagged;
  final List<String> reasons;
}

Screened screenText(String text) {
  final reasons = <String>{};
  var masked = text;
  final email = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  final phone = RegExp(
    r'(?:\+44\s?7\d{3}|\(?07\d{3}\)?)[\s-]?\d{3}[\s-]?\d{3}',
  );
  if (email.hasMatch(masked)) {
    reasons.add('an email address');
    masked = masked.replaceAll(email, '[email hidden]');
  }
  if (phone.hasMatch(masked)) {
    reasons.add('a phone number');
    masked = masked.replaceAll(phone, '[phone hidden]');
  }
  final flags = <RegExp, String>{
    RegExp(
      r'\b(paypal|venmo|revolut|bank transfer|gift ?card|bitcoin)\b',
      caseSensitive: false,
    ): 'a payment request',
    RegExp(r'£\s?\d+|\b(postage|release)\s+fee\b', caseSensitive: false):
        'a fee for returning an item',
    RegExp(r'\b(whats\s?app|telegram|text me|call me)\b', caseSensitive: false):
        'moving the chat off the app',
    RegExp(r'\b(passcode|pin|password)\b', caseSensitive: false):
        'a passcode or PIN',
  };
  for (final entry in flags.entries) {
    if (entry.key.hasMatch(text)) reasons.add(entry.value);
  }
  return Screened(
    text: masked,
    flagged: reasons.isNotEmpty,
    reasons: reasons.toList(),
  );
}

bool sameCampusEmail(String email, String campusId) {
  final domain = email.split('@').last.toLowerCase();
  return campusId == 'kingsmere'
      ? domain == 'kingsmere.example'
      : domain == 'ravensbourne.example';
}

String? campusForEmail(String email) {
  final domain = email.split('@').last.toLowerCase();
  if (domain == 'ravensbourne.example') return 'ravensbourne';
  if (domain == 'kingsmere.example') return 'kingsmere';
  return null;
}

/// How many feed or search rows to build at once.
const listPageSize = 8;

List<T> pageWindow<T>(List<T> source, int shown) {
  final end = shown.clamp(0, source.length);
  return source.sublist(0, end);
}
