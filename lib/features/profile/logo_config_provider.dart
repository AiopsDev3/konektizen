import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LogoConfig {
  final String title;
  final String subtitle;
  final String logoType; // 'preset', 'url', 'file'
  final String presetPath; // e.g. 'assets/images/logo_laoag.png'
  final String customUrl;
  final String customFilePath;

  const LogoConfig({
    required this.title,
    required this.subtitle,
    required this.logoType,
    required this.presetPath,
    required this.customUrl,
    required this.customFilePath,
  });

  LogoConfig copyWith({
    String? title,
    String? subtitle,
    String? logoType,
    String? presetPath,
    String? customUrl,
    String? customFilePath,
  }) {
    return LogoConfig(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      logoType: logoType ?? this.logoType,
      presetPath: presetPath ?? this.presetPath,
      customUrl: customUrl ?? this.customUrl,
      customFilePath: customFilePath ?? this.customFilePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'logoType': logoType,
      'presetPath': presetPath,
      'customUrl': customUrl,
      'customFilePath': customFilePath,
    };
  }

  factory LogoConfig.fromMap(Map<String, dynamic> map) {
    return LogoConfig(
      title: map['title'] ?? 'CITY OF LAOAG',
      subtitle: map['subtitle'] ?? 'Smart Citizen Services',
      logoType: map['logoType'] ?? 'preset',
      presetPath: map['presetPath'] ?? 'assets/images/logo_laoag.png',
      customUrl: map['customUrl'] ?? '',
      customFilePath: map['customFilePath'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory LogoConfig.fromJson(String source) => LogoConfig.fromMap(json.decode(source));
}

class LogoConfigNotifier extends StateNotifier<LogoConfig> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'konektizen_logo_config';

  LogoConfigNotifier()
      : super(const LogoConfig(
          title: 'CITY OF LAOAG',
          subtitle: 'Smart Citizen Services',
          logoType: 'preset',
          presetPath: 'assets/images/logo_laoag.png',
          customUrl: '',
          customFilePath: '',
        )) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        state = LogoConfig.fromJson(saved);
      }
    } catch (_) {}
  }

  Future<void> updateConfig(LogoConfig next) async {
    state = next;
    try {
      await _storage.write(key: _storageKey, value: next.toJson());
    } catch (_) {}
  }
}

final logoConfigProvider = StateNotifierProvider<LogoConfigNotifier, LogoConfig>((ref) {
  return LogoConfigNotifier();
});

class AppLogoImage extends StatelessWidget {
  final LogoConfig config;
  final double size;

  const AppLogoImage({super.key, required this.config, this.size = 40});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (config.logoType == 'url' && config.customUrl.isNotEmpty) {
      imageWidget = Image.network(
        config.customUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
      );
    } else if (config.logoType == 'file' && config.customFilePath.isNotEmpty) {
      final file = File(config.customFilePath);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
        );
      } else {
        imageWidget = _fallbackWidget();
      }
    } else {
      // Default / Preset
      imageWidget = Image.asset(
        config.presetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipOval(child: imageWidget),
    );
  }

  Widget _fallbackWidget() {
    return Image.asset(
      'assets/images/logo.jpg',
      fit: BoxFit.cover,
    );
  }
}
