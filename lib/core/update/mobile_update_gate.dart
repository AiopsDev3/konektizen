import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/server_connection_config.dart';

class MobileUpdateGate extends StatefulWidget {
  const MobileUpdateGate({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<MobileUpdateGate> createState() => _MobileUpdateGateState();
}

class _MobileUpdateGateState extends State<MobileUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogVisible = false;
  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (!mounted ||
        kIsWeb ||
        !Platform.isAndroid ||
        _checking ||
        _dialogVisible) {
      return;
    }
    final previousCheck = _lastCheckedAt;
    if (previousCheck != null &&
        DateTime.now().difference(previousCheck) <
            const Duration(minutes: 15)) {
      return;
    }
    _checking = true;
    _lastCheckedAt = DateTime.now();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final origin = Uri.parse(ServerConnectionConfig.instance.origin);
      final endpoint = origin
          .resolve('/api/v1/mobile-releases/latest/konektizen')
          .replace(
            queryParameters: {'currentVersionCode': '$currentVersionCode'},
          );
      final response = await http
          .get(endpoint, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['updateAvailable'] != true) {
        return;
      }
      final release = KonektizenMobileRelease.fromJson(decoded, origin: origin);
      final dialogContext = widget.navigatorKey.currentState?.overlay?.context;
      if (!mounted || dialogContext == null || !dialogContext.mounted) return;
      _dialogVisible = true;
      await showDialog<void>(
        context: dialogContext,
        useRootNavigator: true,
        barrierDismissible: !release.required,
        builder: (context) => KonektizenUpdateDialog(release: release),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Konektizen update check skipped: $error');
    } finally {
      _dialogVisible = false;
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KonektizenMobileRelease {
  const KonektizenMobileRelease({
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.required,
    required this.downloadUrl,
    required this.sha256,
    required this.fileSize,
  });

  factory KonektizenMobileRelease.fromJson(
    Map<String, dynamic> json, {
    required Uri origin,
  }) {
    final rawUrl = (json['downloadUrl'] ?? '').toString().trim();
    final parsed = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || parsed == null) {
      throw const FormatException('Release download URL is missing.');
    }
    final resolved = parsed.hasScheme ? parsed : origin.resolveUri(parsed);
    return KonektizenMobileRelease(
      versionName: (json['versionName'] ?? '').toString(),
      versionCode: int.tryParse('${json['versionCode']}') ?? 0,
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
      required: json['requiredForCurrentVersion'] == true,
      downloadUrl: resolved.toString(),
      sha256: (json['sha256'] ?? '').toString().trim(),
      fileSize: int.tryParse('${json['fileSize']}') ?? 0,
    );
  }

  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final bool required;
  final String downloadUrl;
  final String sha256;
  final int fileSize;
}

class KonektizenUpdateDialog extends StatefulWidget {
  const KonektizenUpdateDialog({required this.release, super.key});

  final KonektizenMobileRelease release;

  @override
  State<KonektizenUpdateDialog> createState() => _KonektizenUpdateDialogState();
}

class _KonektizenUpdateDialogState extends State<KonektizenUpdateDialog> {
  StreamSubscription<OtaEvent>? _subscription;
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await _subscription?.cancel();
      _subscription = OtaUpdate()
          .execute(
            widget.release.downloadUrl,
            destinationFilename: 'konektizen-${widget.release.versionName}.apk',
            sha256checksum: widget.release.sha256.isEmpty
                ? null
                : widget.release.sha256,
          )
          .listen(
            _handleEvent,
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _downloading = false;
                _error =
                    'The update could not be downloaded. Please try again.';
              });
            },
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'The update could not start. Please try again.';
      });
    }
  }

  void _handleEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        setState(() {
          _progress = (double.tryParse(event.value ?? '') ?? 0)
              .clamp(0, 100)
              .toDouble();
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() {
          _progress = 100;
          _downloading = false;
        });
      case OtaStatus.CANCELED:
        setState(() {
          _downloading = false;
          _error = 'Update download canceled.';
        });
      case OtaStatus.CHECKSUM_ERROR:
        setState(() {
          _downloading = false;
          _error = 'Security check failed. The APK checksum does not match.';
        });
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        setState(() {
          _downloading = false;
          _error = 'Allow Konektizen to install updates when Android asks.';
        });
      case OtaStatus.ALREADY_RUNNING_ERROR:
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.INTERNAL_ERROR:
        setState(() {
          _downloading = false;
          _error = event.value?.trim().isNotEmpty == true
              ? event.value
              : 'The update could not be installed. Please try again.';
        });
    }
  }

  String get _fileSizeLabel {
    final megabytes = widget.release.fileSize / (1024 * 1024);
    return megabytes >= 0.1 ? '${megabytes.toStringAsFixed(1)} MB' : 'APK';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.release.required && !_downloading,
      child: AlertDialog(
        icon: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.system_update_alt_rounded, color: scheme.primary),
        ),
        title: Text('Konektizen ${widget.release.versionName} is available'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Build ${widget.release.versionCode}')),
                  Chip(label: Text(_fileSizeLabel)),
                  if (widget.release.required)
                    const Chip(
                      avatar: Icon(Icons.lock_rounded, size: 16),
                      label: Text('Required update'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.release.releaseNotes.isEmpty
                    ? 'This release includes stability and service improvements.'
                    : widget.release.releaseNotes,
              ),
              if (_downloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: _progress / 100),
                const SizedBox(height: 8),
                Text('Downloading update… ${_progress.toStringAsFixed(0)}%'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              Text(
                'Android will ask you to confirm the installation after the secure download finishes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          if (!widget.release.required && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton.icon(
            onPressed: _downloading ? null : _install,
            icon: Icon(_error == null ? Icons.download_rounded : Icons.refresh),
            label: Text(_error == null ? 'Update now' : 'Try again'),
          ),
        ],
      ),
    );
  }
}
