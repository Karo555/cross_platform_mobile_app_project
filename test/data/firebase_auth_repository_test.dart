import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/data/models/app_user.dart';
import 'package:patient_tracker/data/repositories/auth_repository.dart';
import 'package:patient_tracker/data/repositories/firebase_auth_repository.dart';

void main() {
  group('authErrorForCode', () {
    test('does not reveal whether the email or the password was wrong', () {
      for (final code in [
        'invalid-credential',
        'invalid-email',
        'user-not-found',
        'wrong-password',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        expect(
          authErrorForCode(code),
          AuthError.invalidCredentials,
          reason: code,
        );
      }
    });

    test('maps the other known codes', () {
      expect(authErrorForCode('user-disabled'), AuthError.userDisabled);
      expect(authErrorForCode('too-many-requests'), AuthError.tooManyRequests);
      expect(authErrorForCode('network-request-failed'), AuthError.network);
    });

    test('maps anything else to unknown', () {
      expect(authErrorForCode('operation-not-allowed'), AuthError.unknown);
      expect(authErrorForCode(''), AuthError.unknown);
    });
  });

  group('appUserFromToken', () {
    test('reads the role from the role claim', () {
      final user = appUserFromToken(
        uid: 'u1',
        email: 'doc@example.com',
        claims: {'role': 'doctor'},
      );

      expect(user.uid, 'u1');
      expect(user.email, 'doc@example.com');
      expect(user.role, UserRole.doctor);
    });

    test(
      'gives no role when the claim is missing, unknown or not a string',
      () {
        for (final claims in <Map<String, dynamic>?>[
          null,
          {},
          {'role': 'admin'},
          {'role': 'Nurse'},
          {'role': 1},
        ]) {
          final user = appUserFromToken(
            uid: 'u',
            email: 'x@example.com',
            claims: claims,
          );
          expect(user.role, isNull, reason: '$claims');
        }
      },
    );

    test('uses an empty email when the account has none', () {
      expect(appUserFromToken(uid: 'u', email: null, claims: null).email, '');
    });
  });
}
