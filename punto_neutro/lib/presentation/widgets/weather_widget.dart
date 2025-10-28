import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/weather_viewmodel.dart';

class WeatherWidget extends StatelessWidget {
  final String city;
  const WeatherWidget({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const SizedBox(width: 64, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)));
        }
        if (vm.error != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Text('Err', style: TextStyle(color: Colors.white, fontSize: 12)),
          );
        }
        final data = vm.data;
        if (data == null) return const SizedBox.shrink();

        String iconUrl = '';
        if (data.icon.isNotEmpty) {
          if (data.icon.startsWith('http')) {
            iconUrl = data.icon;
          } else {
            iconUrl = 'https://openweathermap.org/img/wn/${data.icon}@2x.png';
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconUrl.isNotEmpty)
                Image.network(
                  iconUrl,
                  width: 28,
                  height: 28,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(width: 28, height: 28),
                ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data.temperature.round()}°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (data.cityName.isNotEmpty || data.description.isNotEmpty)
                    Text(
                      '${data.cityName.isNotEmpty ? data.cityName : ''}${data.cityName.isNotEmpty && data.description.isNotEmpty ? ' · ' : ''}${data.description}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}