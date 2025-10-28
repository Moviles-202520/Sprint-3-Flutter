import '../services/weather_service.dart';
import '../../domain/models/weather_data.dart';

class WeatherRepository {
  final WeatherService service;
  WeatherRepository(this.service);

  Future<WeatherData> fetchCurrentWeather({required String city}) async {
    return await service.getCurrentWeather(city: city);
  }
}