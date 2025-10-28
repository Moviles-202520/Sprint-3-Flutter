import 'package:local_auth/local_auth.dart';
import 'package:punto_neutro/domain/auth/auth_strategy.dart';
import '../../data/repositories/auth_repository.dart';

class BiometricAuthStrategy implements AuthStrategy {
  final AuthRepository repo;
  final _localAuth = LocalAuthentication();

  BiometricAuthStrategy(this.repo);

  @override
  String get name => 'biometric';

  @override
  Future<bool> signIn() async {
    final supported = await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    if (!supported) throw Exception('Biometría no disponible');

    final ok = await _localAuth.authenticate(
      localizedReason: 'Usa tu huella para continuar',
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
    if (!ok) return false;

    return await repo.refreshSession();
  }
}
