import 'package:uuid/uuid.dart';
import '../../core/biometric_vault.dart';
import '../models/user_login.dart';
import 'auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final _uuid = const Uuid();

  // --- CREDENCIALES QUEMADAS (para pruebas) ---
  static const String testEmail = 'test@demo.com';
  static const String testPassword = 'password123';
  static const bool testFingerprintEnabled = true;
  // ---------------------------------------------

  final Map<String, UserLogin> _usersByEmail = {};

  static const _tokenPrefix = 'rt_';

  FakeAuthRepository() {
    final seeded = UserLogin(
      userLoginId: _uuid.v4(),
      email: testEmail,
      password: testPassword,
      fingerprintEnabled: testFingerprintEnabled,
    );
    _usersByEmail[testEmail] = seeded;
  }

  @override
  Future<UserLogin> register({
    required String email,
    required String password,
    bool fingerprintEnabled = false,
  }) async {
    if (!email.contains('@') || password.length < 6) {
      throw Exception('Datos inválidos');
    }
    if (_usersByEmail.containsKey(email)) {
      throw Exception('El usuario ya existe');
    }

    final user = UserLogin(
      userLoginId: _uuid.v4(),
      email: email,
      password: password,
      fingerprintEnabled: fingerprintEnabled,
    );

    _usersByEmail[email] = user;

    if (fingerprintEnabled) {
      final refresh = '$_tokenPrefix${_uuid.v4()}';
      await BiometricVault.instance.writeRefresh(refresh);
    }
    return user;
  }

  @override
  Future<UserLogin> loginWithPassword({
    required String email,
    required String password,
  }) async {
    // Si coincide con el usuario "quemado" lo aceptamos
    final user = _usersByEmail[email];
    if (user == null || user.password != password) {
      throw Exception('Credenciales incorrectas');
    }

    // Sembramos/actualizamos refresh_token si fingerprintEnabled
    if (user.fingerprintEnabled) {
      final refresh = '$_tokenPrefix${_uuid.v4()}';
      await BiometricVault.instance.writeRefresh(refresh);
    }
    return user;
  }

  @override
  Future<bool> refreshSession() async {
    try {
      final token = await BiometricVault.instance.readRefresh(); // pedirá huella
      return token != null && token.startsWith(_tokenPrefix);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> logout() async {
    await BiometricVault.instance.clear();
  }
}
