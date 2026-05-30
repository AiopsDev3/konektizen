import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/weather/weather_advisory.dart';
import 'package:konektizen/features/weather/weather_advisory_service.dart';

final weatherAdvisoryServiceProvider = Provider<WeatherAdvisoryService>((ref) {
  return const WeatherAdvisoryService();
});

final weatherAdvisoriesProvider =
    FutureProvider.autoDispose<List<WeatherAdvisory>>((ref) async {
      return ref.watch(weatherAdvisoryServiceProvider).fetchAdvisories();
    });
