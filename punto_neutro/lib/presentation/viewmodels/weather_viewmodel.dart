import 'package:flutter/foundation.dart';
import '../../data/repositories/weather_repository.dart';
import '../../domain/models/weather_data.dart';

class WeatherViewModel extends ChangeNotifier {
  final WeatherRepository repo;
  WeatherData? _data;
  bool _loading = false;
  String? _error;

  WeatherViewModel(this.repo);

  WeatherData? get data => _data;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadWeather(String city) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _data = await repo.fetchCurrentWeather(city: city);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false; notifyListeners();
    }
  }
}