import 'package:flutter/material.dart';
import 'package:konektizen/features/home/city_update_link.dart';

const laoagCdrrmoFacebook = 'https://www.facebook.com/cdrrmo.laoag';
const laoagCityFacebook = 'https://www.facebook.com/LaoagCityOfficial';
const laoagCityEvents = 'https://www.facebook.com/LaoagCityOfficial/events';
const pagasaWeather = 'https://www.pagasa.dost.gov.ph/weather';
const pagasaTropicalCyclone =
    'https://www.pagasa.dost.gov.ph/tropical-cyclone/severe-weather-bulletin';
const phivolcsEarthquake =
    'https://www.phivolcs.dost.gov.ph/earthquake/earthquake-information3';

const officialCityLinks = [
  CityUpdateLink(
    title: 'Laoag CDRRMO',
    description: 'Official disaster risk reduction and emergency updates.',
    url: laoagCdrrmoFacebook,
    icon: Icons.health_and_safety_outlined,
    group: CityUpdateGroup.official,
    badge: 'Facebook',
  ),
  CityUpdateLink(
    title: 'City Government of Laoag',
    description: 'City announcements, public advisories, and local programs.',
    url: laoagCityFacebook,
    icon: Icons.account_balance_outlined,
    group: CityUpdateGroup.official,
    badge: 'Facebook',
  ),
];

const cityEventLinks = [
  CityUpdateLink(
    title: 'Laoag City Events',
    description: 'Public events and announcements from the city page.',
    url: laoagCityEvents,
    icon: Icons.event_available_outlined,
    group: CityUpdateGroup.events,
    badge: 'City page',
  ),
];

const alertNotificationLinks = [
  CityUpdateLink(
    title: 'CDRRMO Alerts',
    description: 'Local alerts, emergency reminders, and response updates.',
    url: laoagCdrrmoFacebook,
    icon: Icons.notification_important_outlined,
    group: CityUpdateGroup.alerts,
    badge: 'Local',
  ),
  CityUpdateLink(
    title: 'PAGASA Cyclone Bulletins',
    description:
        'Official tropical cyclone bulletins and severe weather posts.',
    url: pagasaTropicalCyclone,
    icon: Icons.cyclone_outlined,
    group: CityUpdateGroup.alerts,
    badge: 'Official',
  ),
  CityUpdateLink(
    title: 'PHIVOLCS Earthquake Info',
    description: 'Official earthquake information and volcano-related updates.',
    url: phivolcsEarthquake,
    icon: Icons.terrain_outlined,
    group: CityUpdateGroup.alerts,
    badge: 'Official',
  ),
];

const cityNewsLinks = [
  CityUpdateLink(
    title: 'CDRRMO Laoag News',
    description: 'Preparedness news and city response updates.',
    url: laoagCdrrmoFacebook,
    icon: Icons.article_outlined,
    group: CityUpdateGroup.news,
    badge: 'Local',
  ),
  CityUpdateLink(
    title: 'PAGASA Weather News',
    description: 'Official weather forecasts and advisories.',
    url: pagasaWeather,
    icon: Icons.cloud_outlined,
    group: CityUpdateGroup.news,
    badge: 'Official',
  ),
  CityUpdateLink(
    title: 'PHIVOLCS Updates',
    description: 'Earthquake and volcano advisories from PHIVOLCS.',
    url: phivolcsEarthquake,
    icon: Icons.public_outlined,
    group: CityUpdateGroup.news,
    badge: 'Official',
  ),
];
