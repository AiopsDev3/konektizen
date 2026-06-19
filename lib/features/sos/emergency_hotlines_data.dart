import 'package:flutter/material.dart';

class HotlineItemModel {
  final String name;
  final String number;
  final String desc;

  HotlineItemModel({
    required this.name,
    required this.number,
    required this.desc,
  });
}

class HotlineGroupModel {
  final String title;
  final IconData icon;
  final Color color;
  final List<HotlineItemModel> items;

  HotlineGroupModel({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

final List<HotlineGroupModel> emergencyHotlineCategories = [
  HotlineGroupModel(
    title: 'Quick Access',
    icon: Icons.flash_on_rounded,
    color: const Color(0xFFDC2626),
    items: [
      HotlineItemModel(name: 'National Emergency', number: '911', desc: 'General emergency response & dispatch'),
    ],
  ),
  HotlineGroupModel(
    title: 'Disaster Response (CDRRMO)',
    icon: Icons.umbrella_rounded,
    color: const Color(0xFFEA580C),
    items: [
      HotlineItemModel(name: 'CDRRMO Office Trunkline', number: '(077) 772-0001', desc: 'Laoag disaster management (Local 238)'),
      HotlineItemModel(name: 'CDRRMO Mobile (Smart)', number: '0998-950-5028', desc: 'Direct emergency mobile coordinator'),
      HotlineItemModel(name: 'CDRRMO Mobile (Globe)', number: '0917-626-7947', desc: 'Direct emergency mobile coordinator'),
    ],
  ),
  HotlineGroupModel(
    title: 'Philippine Police (PNP)',
    icon: Icons.shield_rounded,
    color: const Color(0xFF1D4ED8),
    items: [
      HotlineItemModel(name: 'Laoag Police Station', number: '(077) 772-0201', desc: 'Main police station landline desk'),
      HotlineItemModel(name: 'Laoag Police Alt Line', number: '(077) 772-1887', desc: 'Main desk secondary line'),
      HotlineItemModel(name: 'Police Mobile (Smart)', number: '0909-532-8524', desc: 'Hotline coordinator mobile'),
      HotlineItemModel(name: 'Police Mobile (Globe)', number: '0917-599-7414', desc: 'Hotline coordinator mobile'),
    ],
  ),
  HotlineGroupModel(
    title: 'Fire Protection (BFP)',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFD97706),
    items: [
      HotlineItemModel(name: 'BFP Ilocos Norte Landline', number: '(077) 670-7681', desc: 'Laoag fire station dispatcher'),
      HotlineItemModel(name: 'BFP Mobile hotline', number: '0917-187-3811', desc: 'Mobile fire dispatch unit coordinator'),
    ],
  ),
  HotlineGroupModel(
    title: 'Hospitals & Medical',
    icon: Icons.local_hospital_rounded,
    color: const Color(0xFF16A34A),
    items: [
      HotlineItemModel(name: 'Laoag City General Hospital', number: '(077) 772-8828', desc: 'Laoag public hospital primary desk'),
      HotlineItemModel(name: 'Gov. Roque Ablan Memorial', number: '(077) 772-0303', desc: 'Provincial public hospital desk'),
      HotlineItemModel(name: 'Karmelli Clinic & Hospital', number: '(077) 772-2752', desc: 'Private hospital emergency desk'),
      HotlineItemModel(name: 'Ranada General Hospital', number: '(077) 773-1199', desc: 'Private medical emergency trunkline'),
    ],
  ),
  HotlineGroupModel(
    title: 'Red Cross',
    icon: Icons.add_box_rounded,
    color: const Color(0xFFE11D48),
    items: [
      HotlineItemModel(name: 'PRC Ilocos Norte Chapter', number: '(077) 770-5615', desc: 'Red Cross blood bank & first aid dispatch'),
      HotlineItemModel(name: 'PRC Secondary Hotline', number: '(077) 772-0217', desc: 'Alternative administrative emergency desk'),
    ],
  ),
];
