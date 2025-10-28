class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final String cityName;

  WeatherData({required this.temperature, required this.description, required this.icon, required this.cityName});

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>?;
    final weatherList = json['weather'] as List<dynamic>?;
    final weather = weatherList != null && weatherList.isNotEmpty ? weatherList[0] as Map<String, dynamic> : null;
    // Try WeatherAPI response first: { location: { name }, current: { temp_c, condition: { text, icon } } }
    if (json.containsKey('current') && json.containsKey('location')) {
      final loc = json['location'] as Map<String, dynamic>?;
      final cur = json['current'] as Map<String, dynamic>?;
      final cond = cur?['condition'] as Map<String, dynamic>?;
      return WeatherData(
        temperature: (cur?['temp_c'] as num?)?.toDouble() ?? 0.0,
        description: (cond?['text'] as String?) ?? '',
        // WeatherAPI returns icon like "//cdn.weatherapi.com/..." - normalize to https
        icon: (cond?['icon'] as String?)?.replaceFirst('//', 'https://') ?? '',
        cityName: (loc?['name'] as String?) ?? '',
      );
    }

    // Fallback: try OpenWeatherMap structure
    return WeatherData(
      temperature: (main?['temp'] as num?)?.toDouble() ?? 0.0,
      description: (weather?['description'] as String?) ?? '',
      icon: (weather?['icon'] as String?) ?? '',
      cityName: (json['name'] as String?) ?? '',
    );
  }
}