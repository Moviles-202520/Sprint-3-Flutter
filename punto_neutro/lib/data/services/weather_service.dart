import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/weather_data.dart';

class WeatherService {
  // Usaremos WeatherAPI (https://www.weatherapi.com/) como servicio.
  static const _baseUrl = 'https://api.weatherapi.com/v1';
  final String apiKey;
  final http.Client client;

  WeatherService({required this.apiKey, http.Client? client}) : client = client ?? http.Client();

  Future<WeatherData> getCurrentWeather({required String city}) async {
    final url = Uri.parse('$_baseUrl/current.json?key=$apiKey&q=${Uri.encodeComponent(city)}&aqi=no');
    try {
      final resp = await client.get(url).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) throw Exception('Failed to fetch weather: ${resp.statusCode}');
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return WeatherData.fromJson(json);
    } catch (e, st) {
      print('[WEATHER] Error fetching weather: $e');
      print(st);
      rethrow;
    }
  }
}