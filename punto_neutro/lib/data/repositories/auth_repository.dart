import '../models/user_login.dart';

abstract class AuthRepository {
  /// Crea usuario (mock local) y guarda refresh_token protegido por huella si fingerprintEnabled = true

  Future<int?> currentUserProfileId();

  Future<UserLogin> register({
    required String email,
    required String password,
    bool fingerprintEnabled = false,
  });

  /// Login con correo/clave. Devuelve refresh_token (interno) y/o usuario.
  Future<UserLogin> loginWithPassword({
    required String email,
    required String password,
  });

  /// Intenta refrescar sesión con el refresh_token guardado en la bóveda biométrica.
  Future<bool> refreshSession();

  /// Cierra sesión y limpia credenciales locales.
  Future<void> logout();
}
