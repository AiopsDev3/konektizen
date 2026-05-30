import 'package:flutter/material.dart';

enum CityUpdateGroup { official, events, alerts, news }

class CityUpdateLink {
  const CityUpdateLink({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.group,
    this.badge,
  });

  final String title;
  final String description;
  final String url;
  final IconData icon;
  final CityUpdateGroup group;
  final String? badge;
}
