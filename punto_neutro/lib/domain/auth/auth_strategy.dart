abstract class AuthStrategy {
  Future<bool> signIn();
  String get name;
}
