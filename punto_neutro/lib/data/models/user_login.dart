class UserLogin {
  final String userLoginId;     // UUID en local
  final String email;
  final String password;        // SOLO para mock local (no guardes plano en prod)
  final bool fingerprintEnabled;

  UserLogin({
    required this.userLoginId,
    required this.email,
    required this.password,
    required this.fingerprintEnabled,
  });

  factory UserLogin.fromMap(Map<String, dynamic> m) => UserLogin(
    userLoginId: m['userLoginId'] as String,
    email: m['email'] as String,
    password: m['password'] as String,
    fingerprintEnabled: m['fingerprintEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'userLoginId': userLoginId,
    'email': email,
    'password': password,
    'fingerprintEnabled': fingerprintEnabled,
  };
}
