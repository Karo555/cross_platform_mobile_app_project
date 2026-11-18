import 'dart:math';

final _random = Random.secure();

/// A random version 4 UUID, for example
/// `6f1c2c1e-3b7a-4c55-9a3e-2d3f7b9e1a10`. Used as the `eventId` of a
/// transfer, which also names its history document (`docs/schema.md`).
String newEventId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
