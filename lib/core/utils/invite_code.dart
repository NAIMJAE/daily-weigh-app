import 'dart:math';

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateInviteCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(6, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
}
