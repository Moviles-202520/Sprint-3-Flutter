import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton para exponer una única instancia del cliente de Supabase
class SupabaseClientSingleton {
  SupabaseClientSingleton._();
  static final SupabaseClientSingleton instance = SupabaseClientSingleton._();

  late final SupabaseClient client;

  /// Inicializa Supabase al inicio de la app
  Future<void> init() async {
    await Supabase.initialize(
      url: 'https://<PROJECT>.supabase.co', // TODO: reemplazar con tu URL
      anonKey: '<ANON_KEY>',                // TODO: reemplazar con tu key
    );
    client = Supabase.instance.client;
  }
}
