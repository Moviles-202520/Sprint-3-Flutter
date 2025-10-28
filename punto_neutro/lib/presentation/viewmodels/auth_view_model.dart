import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_login.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  AuthViewModel(this._repository);

  UserLogin? _currentUser;
  bool _loading = false;
  String? _error;
  int? _userProfileId;

  UserLogin? get currentUser => _currentUser;
  bool get loading => _loading;
  int? get userProfileId => _userProfileId;
  bool get loggedIn => _currentUser != null;
  String? get error => _error;

  Future<void> loginWithPassword(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _repository.loginWithPassword(
        email: email,
        password: password,
      );
      _currentUser = user;
      _userProfileId = int.tryParse(user.userLoginId);
    } catch (e) {
      _error = e.toString();
      _userProfileId = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithBiometric() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final ok = await _repository.refreshSession();
      if (ok) {
        _currentUser = UserLogin(
          userLoginId: 'biometric',
          email: 'test@demo.com',
          password: 'password123',
          fingerprintEnabled: true,
        );
      } else {
        _error = 'No biometric session found';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _userProfileId = null;
    notifyListeners();
  }

  Future<void> registerWithPassword(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Registrar usuario en Supabase Auth
      final supabase = Supabase.instance.client;
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.user == null) {
        throw Exception('No se pudo crear el usuario en Supabase Auth');
      }

      // 2. Crear perfil en user_profiles con el UUID y el email
      final profileResponse = await supabase
          .from('user_profiles')
          .insert({
            'user_auth_id': authResponse.user!.id,
            'user_auth_email': email,
          })
          .select()
          .single();

      // 3. Guardar usuario y marcar como logueado
      _currentUser = UserLogin(
        userLoginId: profileResponse['user_profile_id'].toString(),
        email: profileResponse['user_auth_email'],
        password: password,
        fingerprintEnabled: false,
      );
      _userProfileId = int.tryParse(profileResponse['user_profile_id'].toString());
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentUser = null;
      _userProfileId = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
