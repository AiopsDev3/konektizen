import 'package:flutter/material.dart';
import 'package:konektizen/core/config/server_connection_config.dart';

class C3ServerSelection {
  const C3ServerSelection({required this.origin, this.videoApiUrl});

  final String origin;
  final String? videoApiUrl;
}

class C3ServerDialog extends StatefulWidget {
  const C3ServerDialog({
    super.key,
    required this.initialValue,
    this.initialVideoApiUrl,
  });

  final String initialValue;
  final String? initialVideoApiUrl;

  @override
  State<C3ServerDialog> createState() => _C3ServerDialogState();
}

class _C3ServerDialogState extends State<C3ServerDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _videoApiController;

  static const List<String> _presets = [
    'http://172.16.0.50:5001',
    ServerConnectionConfig.defaultOrigin,
    'https://c3.aitelligenz.com',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _videoApiController = TextEditingController(
      text: widget.initialVideoApiUrl ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoApiController.dispose();
    super.dispose();
  }

  void _close([C3ServerSelection? value]) {
    Navigator.of(context).pop(value);
  }

  void _save() {
    _close(
      C3ServerSelection(
        origin: _controller.text,
        videoApiUrl: _videoApiController.text,
      ),
    );
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
      content: SingleChildScrollView(
        child: Column(
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
                    onPressed: () => setState(() {
                      _controller.text = preset;
                      _videoApiController.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _videoApiController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Video API URL (optional)',
                hintText: 'http://172.16.0.50:5001/api/livekit',
                prefixIcon: Icon(Icons.video_call_outlined),
                helperText:
                    'Leave blank to use the selected C3 Server /api/livekit.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _close(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _save,
          child: const Text('Save & Test'),
        ),
      ],
    );
  }
}
