import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeWeatherForecast extends StatefulWidget {
  const HomeWeatherForecast({super.key});

  @override
  State<HomeWeatherForecast> createState() => _HomeWeatherForecastState();
}

class _HomeWeatherForecastState extends State<HomeWeatherForecast> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _dailyForecast = [];
  String _rainText = 'No rain expected soon';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=18.1960&longitude=120.5989&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&hourly=precipitation_probability,weathercode&timezone=Asia%2FManila'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final daily = data['daily'];
        
        List<Map<String, dynamic>> forecast = [];
        for (int i = 0; i < 7; i++) {
          final dateStr = daily['time'][i];
          final date = DateTime.parse(dateStr);
          final dayName = i == 0 ? 'TDY' : DateFormat('EEE').format(date).toUpperCase();
          final code = daily['weathercode'][i];
          final maxTemp = daily['temperature_2m_max'][i].round();
          final minTemp = daily['temperature_2m_min'][i].round();
          final pop = daily['precipitation_probability_max'][i];

          forecast.add({
            'day': dayName,
            'code': code,
            'maxTemp': maxTemp,
            'minTemp': minTemp,
            'pop': pop,
          });
        }

        // Calculate expected rain text
        final hourly = data['hourly'];
        String rainExpected = 'No rain expected soon';
        for (int i = 0; i < 24; i++) {
          if (hourly['precipitation_probability'][i] > 30) {
             final time = DateTime.parse(hourly['time'][i]);
             final timeStr = DateFormat('h:mm a').format(time);
             rainExpected = 'Rain expected at $timeStr (${hourly['precipitation_probability'][i]}%)';
             break;
          }
        }

        if (mounted) {
          setState(() {
            _dailyForecast = forecast;
            _rainText = rainExpected;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code >= 1 && code <= 3) return Icons.cloud_queue;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.water_drop_outlined;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.grain;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_outlined;
    return Icons.wb_sunny_outlined;
  }

  Color _getIconColor(int code) {
    if (code >= 95 && code <= 99) return Colors.purple; // Thunderstorm
    if (code >= 51 && code <= 82) return Colors.blue; // Rain
    if (code <= 3) return Colors.amber; // Sun/Cloud
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_hasError) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Failed to load weather data.')));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dailyForecast.asMap().entries.map((entry) {
                final idx = entry.key;
                final dayData = entry.value;
                final isToday = idx == 0;
                
                return Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isToday ? AppTheme.primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayData['day'],
                        style: GoogleFonts.inter(
                          color: isToday ? AppTheme.primary : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        _getWeatherIcon(dayData['code']),
                        color: _getIconColor(dayData['code']),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${dayData['maxTemp']}°',
                        style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${dayData['minTemp']}°',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _rainText,
            style: GoogleFonts.inter(
              color: AppTheme.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
