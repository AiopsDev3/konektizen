import 'package:flutter/material.dart';
import 'package:konektizen/core/config/server_connection_config.dart';

class C3ServerDialog extends StatefulWidget {
  const C3ServerDialog({super.key, required this.initialValue});

  final String initialValue;

  @override
  State<C3ServerDialog> createState() => _C3ServerDialogState();
}

class _C3ServerDialogState extends State<C3ServerDialog> {
  late final TextEditingController _controller;

  static const List<String> _presets = [
    'http://172.16.0.50:5001',
    ServerConnectionConfig.defaultOrigin,
    'https://c3.aitelligenz.com',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    Navigator.of(context).pop(value);
  }

  String _labelFor(String preset) {
    if (preset.contains('172.16.')) return 'Local';
    if (preset.contains('montalban')) return 'Montalban';
    return 'Cloud';
  }

  IconData _iconFor(String preset) {
    if (preset.contains('172.16.')) return Icons.router_outlined;
    if (preset.contains('montalban')) return Icons.business_outlined;
    return Icons.cloud_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('C3 Server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Domain / IP and port',
              hintText: 'http://172.16.0.50:5001',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ActionChip(
                  avatar: Icon(_iconFor(preset), size: 18),
                  label: Text(_labelFor(preset)),
                  onPressed: () => setState(() => _controller.text = preset),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _close(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => _close(_controller.text),
          child: const Text('Save & Test'),
        ),
      ],
    );
  }
}
