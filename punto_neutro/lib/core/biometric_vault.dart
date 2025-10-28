import 'package:biometric_storage/biometric_storage.dart';

class BiometricVault {
  BiometricVault._();
  static final BiometricVault instance = BiometricVault._();

  Future<BiometricStorageFile> _file() async {
    final can = await BiometricStorage().canAuthenticate();
    if (can != CanAuthenticateResponse.success) {
      throw Exception('Biometría no disponible en el dispositivo');
    }
    return BiometricStorage().getStorage(
      'pn_refresh_token',
      options: StorageFileInitOptions(
        authenticationRequired: true, // exige huella en cada lectura/escritura
      ),
    );
  }

  Future<void> writeRefresh(String token) async {
    final f = await _file();
    await f.write(token);
  }

  Future<String?> readRefresh() async {
    final f = await _file();
    final data = await f.read();
    return (data == null || data.isEmpty) ? null : data;
  }

  Future<void> clear() async {
    final f = await _file();
    await f.delete();
  }
}
