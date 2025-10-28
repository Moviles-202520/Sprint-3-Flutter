import 'package:punto_neutro/domain/auth/auth_strategy.dart';
import '../../data/repositories/auth_repository.dart';

class PasswordAuthStrategy implements AuthStrategy {
  final AuthRepository repo;
  final String email;
  final String password;

  PasswordAuthStrategy(this.repo, {required this.email, required this.password});

  @override
  String get name => 'password';

  @override
  Future<bool> signIn() async {
    await repo.loginWithPassword(email: email, password: password);
    return true;
  }
}
