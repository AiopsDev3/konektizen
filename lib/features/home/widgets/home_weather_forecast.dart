import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/home/widgets/city_advisory_filters.dart';

class HomeWeatherForecast extends ConsumerStatefulWidget {
  const HomeWeatherForecast({super.key});
  @override
  ConsumerState<HomeWeatherForecast> createState() =>
      _HomeWeatherForecastState();
}

class _HomeWeatherForecastState extends ConsumerState<HomeWeatherForecast> {
  bool _isLoading = true, _hasError = false;
  List<Map<String, dynamic>> _dailyForecast = [];
  String _rainText = 'No rain expected soon';
  int _currentWeatherCode = 0;
  int _currentTemp = 33;
  int _feelsLike = 38;
  int _humidity = 70;
  int _windSpeed = 14;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final c3Loaded = await _fetchC3Weather();
      if (c3Loaded) return;

      final res = await http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=18.1960&longitude=120.5989&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&hourly=precipitation_probability,weathercode&timezone=Asia%2FManila',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final daily = data['daily'];
        final hourly = data['hourly'];
        final current = data['current'] ?? {};

        final forecast = List.generate(7, (i) {
          final date = DateTime.parse(daily['time'][i]);
          return {
            'day': i == 0
                ? 'TDY'
                : DateFormat('EEE').format(date).toUpperCase(),
            'code': daily['weathercode'][i],
            'maxTemp': daily['temperature_2m_max'][i].round(),
            'minTemp': daily['temperature_2m_min'][i].round(),
          };
        });

        var rainExpected = 'No rain expected soon';
        for (int i = 0; i < 24; i++) {
          if (hourly['precipitation_probability'][i] > 30) {
            rainExpected =
                'Rain expected at ${DateFormat('h:mm a').format(DateTime.parse(hourly['time'][i]))} (${hourly['precipitation_probability'][i]}%)';
            break;
          }
        }

        if (mounted) {
          setState(() {
            _dailyForecast = forecast;
            _currentTemp = current['temperature_2m']?.round() ?? 33;
            _feelsLike = current['apparent_temperature']?.round() ?? 38;
            _humidity = current['relative_humidity_2m']?.round() ?? 70;
            _windSpeed = current['wind_speed_10m']?.round() ?? 14;
            _currentWeatherCode =
                current['weather_code'] ?? daily['weathercode'][0] ?? 0;
            _rainText = rainExpected;
            _isLoading = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _fetchC3Weather() async {
    final uri = Uri.parse('${ApiService.baseUrl}/weather/history').replace(
      queryParameters: {
        'municipality': 'Laoag City',
        'province': 'Ilocos Norte',
        'region': 'Region I',
        'hours': '720',
        'limit': '50',
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;

      final decoded = jsonDecode(res.body);
      final history = decoded is Map ? decoded['history'] : null;
      if (history is! List || history.isEmpty) return false;

      final rows = history.whereType<Map>().toList();
      if (rows.isEmpty) return false;
      rows.sort((a, b) => _rowTime(b).compareTo(_rowTime(a)));

      final latest = rows.first.cast<String, dynamic>();
      final forecast = _buildForecastFromC3Rows(rows);
      if (forecast.length < 7) {
        forecast.addAll(_fallbackForecastRows(forecast.length, latest));
      }

      final precipitationProbability = _asInt(
        latest['precipitation_probability_24h'],
      );
      final precipitation = _asDouble(latest['precipitation']);
      final rainText = precipitationProbability >= 30
          ? 'Rain expected today ($precipitationProbability%)'
          : precipitation > 0
          ? 'Light rain observed nearby'
          : 'No rain expected soon';

      if (!mounted) return true;
      setState(() {
        _dailyForecast = forecast.take(7).toList();
        _currentTemp = _asInt(latest['temperature'], fallback: _currentTemp);
        _feelsLike = _asInt(
          latest['apparent_temperature'],
          fallback: _feelsLike,
        );
        _humidity = _asInt(latest['humidity'], fallback: _humidity);
        _windSpeed = _asInt(latest['wind_speed'], fallback: _windSpeed);
        _currentWeatherCode = _asInt(
          latest['weather_code'],
          fallback: _currentWeatherCode,
        );
        _rainText = rainText;
        _isLoading = false;
        _hasError = false;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _buildForecastFromC3Rows(List<Map> rows) {
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final sourceTime =
          DateTime.tryParse('${row['source_time'] ?? ''}') ??
          DateTime.tryParse('${row['fetched_at'] ?? ''}');
      if (sourceTime == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(sourceTime);
      byDate.putIfAbsent(key, () => row.cast<String, dynamic>());
    }

    final today = DateTime.now();
    return List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day + index);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final row = byDate[key] ?? (rows.first).cast<String, dynamic>();
      final temp = _asInt(row['temperature'], fallback: _currentTemp);
      return {
        'day': index == 0
            ? 'TDY'
            : DateFormat('EEE').format(date).toUpperCase(),
        'code': _asInt(row['weather_code'], fallback: _currentWeatherCode),
        'maxTemp': temp,
        'minTemp': _asInt(row['apparent_temperature'], fallback: temp),
      };
    });
  }

  List<Map<String, dynamic>> _fallbackForecastRows(
    int startIndex,
    Map<String, dynamic> latest,
  ) {
    final today = DateTime.now();
    final temp = _asInt(latest['temperature'], fallback: _currentTemp);
    return List.generate(7 - startIndex, (offset) {
      final index = startIndex + offset;
      final date = DateTime(today.year, today.month, today.day + index);
      return {
        'day': index == 0
            ? 'TDY'
            : DateFormat('EEE').format(date).toUpperCase(),
        'code': _asInt(latest['weather_code'], fallback: _currentWeatherCode),
        'maxTemp': temp,
        'minTemp': _asInt(latest['apparent_temperature'], fallback: temp),
      };
    });
  }

  DateTime _rowTime(Map row) {
    return DateTime.tryParse('${row['fetched_at'] ?? ''}') ??
        DateTime.tryParse('${row['source_time'] ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num && value.isFinite) return value.round();
    final parsed = num.tryParse('$value');
    return parsed?.round() ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num && value.isFinite) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Failed to load weather data.'),
        ),
      );
    }

    final hasWeatherAlert = _rainText.startsWith('Rain expected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Active Weather Alert Box (matches mockup)
        if (hasWeatherAlert)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2), // Light Red/Pink
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFEE2E2), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), // Crimson Red Warning
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Weather Alert',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF991B1B), // Dark Red
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_rainText\nStay safe and monitor updates.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7F1D1D), // Subtle Dark Red
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ref.read(selectedCategoryFilterProvider.notifier).state =
                        'Alerts';
                    context.push('/home/city-updates');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View Alert',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFDC2626),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFDC2626),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 2. Main Weather Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: Today's current weather
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ComposedWeatherIcon(
                              code: _currentWeatherCode,
                              size: 44,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TODAY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '$_currentTemp°',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Feels like $_feelsLike°',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Weather metrics (humidity & wind)
                        Row(
                          children: [
                            const Icon(
                              Icons.water_drop_outlined,
                              color: Color(0xFF0F766E),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Humidity\n$_humidity%',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.air_outlined,
                              color: Color(0xFF0F766E),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Wind\n$_windSpeed km/h',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider line
                  Container(
                    height: 80,
                    width: 1.5,
                    color: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(width: 12),

                  // Right side: 6-day weather forecast preview
                  Expanded(
                    flex: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _dailyForecast.skip(1).take(6).map((dayData) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                dayData['day'],
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _ComposedWeatherIcon(
                                code: dayData['code'] as int,
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${dayData['maxTemp']}°',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${dayData['minTemp']}°',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // View full forecast links
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(selectedCategoryFilterProvider.notifier).state =
                          'Weather';
                      context.push('/home/city-updates');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View full forecast',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(
                              0xFF166534,
                            ), // Dark Green Accent Link
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF166534),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposedWeatherIcon extends StatelessWidget {
  final int code;
  final double size;

  const _ComposedWeatherIcon({required this.code, required this.size});

  @override
  Widget build(BuildContext context) {
    if (code >= 95) {
      // Thunderstorm: Dark cloud + lightning + rain
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              child: Icon(
                Icons.cloud_rounded,
                color: const Color(0xFF94A3B8),
                size: size * 0.82,
              ),
            ),
            Positioned(
              bottom: size * 0.08,
              right: size * 0.08,
              child: Icon(
                Icons.flash_on_rounded,
                color: const Color(0xFFF59E0B),
                size: size * 0.52,
              ),
            ),
            Positioned(
              bottom: 0,
              left: size * 0.15,
              child: Icon(
                Icons.water_drop_rounded,
                color: const Color(0xFF3B82F6),
                size: size * 0.32,
              ),
            ),
          ],
        ),
      );
    } else if (code >= 80 || (code >= 51 && code <= 67)) {
      // Rain / Showers: Sun + Cloud + Rain
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              right: size * 0.05,
              child: Icon(
                Icons.wb_sunny_rounded,
                color: const Color(0xFFF59E0B),
                size: size * 0.52,
              ),
            ),
            Positioned(
              top: size * 0.1,
              left: 0,
              child: Icon(
                Icons.cloud_rounded,
                color: const Color(0xFFCBD5E1),
                size: size * 0.78,
              ),
            ),
            Positioned(
              bottom: 0,
              left: size * 0.22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    color: const Color(0xFF3B82F6),
                    size: size * 0.25,
                  ),
                  SizedBox(width: size * 0.04),
                  Icon(
                    Icons.water_drop_rounded,
                    color: const Color(0xFF3B82F6),
                    size: size * 0.25,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (code >= 1 && code <= 3) {
      // Partly Cloudy: Sun + Cloud
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              right: size * 0.08,
              child: Icon(
                Icons.wb_sunny_rounded,
                color: const Color(0xFFF59E0B),
                size: size * 0.58,
              ),
            ),
            Positioned(
              bottom: size * 0.02,
              left: size * 0.02,
              child: Icon(
                Icons.cloud_rounded,
                color: const Color(0xFFE2E8F0),
                size: size * 0.78,
              ),
            ),
          ],
        ),
      );
    } else if (code >= 45 && code <= 48) {
      // Foggy / Overcast: Multiple clouds
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Icon(
                Icons.cloud_rounded,
                color: const Color(0xFFCBD5E1),
                size: size * 0.68,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Icon(
                Icons.cloud_rounded,
                color: const Color(0xFF94A3B8),
                size: size * 0.68,
              ),
            ),
          ],
        ),
      );
    } else {
      // Sunny
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            Icons.wb_sunny_rounded,
            color: const Color(0xFFF59E0B),
            size: size * 0.9,
          ),
        ),
      );
    }
  }
}
