import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';

final Logger log = Logger("AppUpdater");

enum UpdateChannel {
  stable,
  beta;

  String get label {
    switch (this) {
      case UpdateChannel.stable:
        return 'Estable';
      case UpdateChannel.beta:
        return 'Beta';
    }
  }

  String get description {
    switch (this) {
      case UpdateChannel.stable:
        return 'Versiones oficiales y probadas';
      case UpdateChannel.beta:
        return 'Versiones preliminares con las últimas novedades';
    }
  }

  String get defaultUrl {
    switch (this) {
      case UpdateChannel.stable:
        return defaultUpdateUrl;
      case UpdateChannel.beta:
        return betaUpdateUrl;
    }
  }
}

const String defaultUpdateUrl = String.fromEnvironment(
  'UPDATE_URL_STABLE',
  defaultValue:
      'https://raw.githubusercontent.com/asaez85/Fireflytonic/main/version.json',
);
const String betaUpdateUrl = String.fromEnvironment(
  'UPDATE_URL_BETA',
  defaultValue:
      'https://raw.githubusercontent.com/asaez85/Fireflytonic/beta/version.json',
);
const String settingUpdateChannel = "update_channel";
const String settingUpdateCheckUrl = "update_check_url";
const String settingAutoUpdateCheck = "update_auto_check";
const String settingLastUpdateCheck = "update_last_check_ms";
const String settingDismissedVersionCode = "update_dismissed_version_code";

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    this.changelog,
    this.minSupportVersionCode,
  });

  final String version;
  final int versionCode;
  final String apkUrl;
  final String? changelog;
  final int? minSupportVersionCode;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: (json['version'] ?? json['versionName'])?.toString() ?? '',
      versionCode: json['versionCode'] is int
          ? json['versionCode'] as int
          : int.tryParse(json['versionCode']?.toString() ?? '') ?? 0,
      apkUrl:
          (json['apkUrl'] ?? json['downloadUrl'] ?? json['url'])?.toString() ??
          '',
      changelog: (json['changelog'] ?? json['notes'] ?? json['description'])
          ?.toString(),
      minSupportVersionCode: json['minSupportVersionCode'] is int
          ? json['minSupportVersionCode'] as int
          : int.tryParse(
              (json['minSupportVersionCode'] ?? json['minSupportedVersionCode'])
                      ?.toString() ??
                  '',
            ),
    );
  }
}

class AppUpdater {
  AppUpdater._();
  static final AppUpdater instance = AppUpdater._();

  static bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  static Future<(String version, int versionCode)> getCurrentVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final int code = int.tryParse(info.buildNumber) ?? 0;
      return (info.version, code);
    } catch (e) {
      return ('3.0.6', 59);
    }
  }

  static Future<UpdateChannel> getDefaultChannel() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (info.packageName.endsWith('.beta') ||
          info.packageName.contains('beta')) {
        return UpdateChannel.beta;
      }
    } catch (_) {}
    return UpdateChannel.stable;
  }

  static Future<UpdateChannel> getUpdateChannel() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final String? saved = await prefs.getString(settingUpdateChannel);
    if (saved == 'beta') return UpdateChannel.beta;
    if (saved == 'stable') return UpdateChannel.stable;
    return getDefaultChannel();
  }

  static Future<void> setUpdateChannel(UpdateChannel channel) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    await prefs.setString(settingUpdateChannel, channel.name);
  }

  static Future<String> getUpdateCheckUrl() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final String? custom = await prefs.getString(settingUpdateCheckUrl);
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    final UpdateChannel channel = await getUpdateChannel();
    return channel.defaultUrl;
  }

  static Future<void> setUpdateCheckUrl(String? url) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(settingUpdateCheckUrl);
    } else {
      await prefs.setString(settingUpdateCheckUrl, url.trim());
    }
  }

  static Future<bool> isAutoCheckEnabled() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    return await prefs.getBool(settingAutoUpdateCheck) ?? true;
  }

  static Future<void> setAutoCheckEnabled(bool enabled) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    await prefs.setBool(settingAutoUpdateCheck, enabled);
  }

  /// Consulta el JSON remoto y devuelve AppUpdateInfo si hay una versión superior.
  Future<AppUpdateInfo?> checkForUpdate({
    String? customUrl,
    bool isManual = false,
  }) async {
    if (!isSupportedPlatform) {
      log.fine("No es Android: omitiendo comprobación de actualización.");
      return null;
    }

    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    if (!isManual) {
      final bool autoEnabled = await isAutoCheckEnabled();
      if (!autoEnabled) return null;

      final int lastCheck = await prefs.getInt(settingLastUpdateCheck) ?? 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      // Intervalo de 4 horas en comprobaciones automáticas al iniciar
      if (now - lastCheck < 4 * 60 * 60 * 1000) {
        log.fine("Comprobación omitida por intervalo de tiempo.");
        return null;
      }
    }

    final String urlStr = customUrl ?? await getUpdateCheckUrl();
    if (urlStr.trim().isEmpty) return null;

    try {
      log.info("Comprobando actualización desde: $urlStr");
      final Uri uri = Uri.parse(urlStr);
      final http.Response response = await http
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'User-Agent': 'Fireflytonic-InAppUpdater',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        log.warning("HTTP ${response.statusCode} al obtener $urlStr");
        if (isManual) {
          throw Exception(
            "Error HTTP ${response.statusCode} al consultar actualizaciones.",
          );
        }
        return null;
      }

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        log.warning("JSON con estructura inválida en $urlStr");
        if (isManual) {
          throw Exception("Respuesta de actualización no válida.");
        }
        return null;
      }

      final AppUpdateInfo updateInfo = AppUpdateInfo.fromJson(data);
      final (String localVersionStr, int localCode) = await getCurrentVersion();

      await prefs.setInt(
        settingLastUpdateCheck,
        DateTime.now().millisecondsSinceEpoch,
      );

      log.info(
        "Local: $localVersionStr (code $localCode) vs Remoto: ${updateInfo.version} (code ${updateInfo.versionCode})",
      );

      bool isNewer = updateInfo.versionCode > localCode;
      if (!isNewer) {
        // Fallback semver: si los versionCode difieren por sufijos ABI o convenciones de build
        try {
          final String cleanRemote = updateInfo.version
              .split(' ')
              .first
              .replaceAll('v', '');
          final String cleanLocal = localVersionStr
              .split(' ')
              .first
              .replaceAll('v', '');
          if (cleanRemote.isNotEmpty && cleanLocal.isNotEmpty) {
            final Version vRemote = Version.parse(cleanRemote);
            final Version vLocal = Version.parse(cleanLocal);
            if (vRemote > vLocal) {
              isNewer = true;
            }
          }
        } catch (_) {}
      }

      if (isNewer && updateInfo.apkUrl.isNotEmpty) {
        if (!isManual) {
          final int dismissed =
              await prefs.getInt(settingDismissedVersionCode) ?? 0;
          if (dismissed == updateInfo.versionCode) {
            return null;
          }
        }
        return updateInfo;
      }
      return null;
    } catch (e, st) {
      log.warning("Error comprobando actualizaciones: $e", e, st);
      if (isManual) rethrow;
      return null;
    }
  }

  /// Descarga el APK con progreso y lo lanza mediante Intent con OpenFile
  Future<void> downloadAndInstall({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) async {
    if (!isSupportedPlatform) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) =>
          _DownloadDialog(updateInfo: updateInfo),
    );
  }

  /// Muestra diálogo modal con novedades y opción para descargar o posponer
  static Future<void> showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) async {
    if (!context.mounted) return;

    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          icon: const Icon(Icons.system_update_rounded, size: 36),
          title: Text("Nueva versión disponible: v${updateInfo.version}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                "Hay una actualización de Fireflytonic lista para instalar.",
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              if (updateInfo.changelog != null &&
                  updateInfo.changelog!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  "Novedades:",
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.changelog!,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final SharedPreferencesAsync prefs = SharedPreferencesAsync();
                await prefs.setInt(
                  settingDismissedVersionCode,
                  updateInfo.versionCode,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(false);
                }
              },
              child: const Text("Más tarde"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: const Text("Actualizar ahora"),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if ((shouldUpdate ?? false) && context.mounted) {
      await instance.downloadAndInstall(
        context: context,
        updateInfo: updateInfo,
      );
    }
  }
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.updateInfo});

  final AppUpdateInfo updateInfo;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0.0;
  String _status = "Iniciando descarga...";
  bool _isError = false;
  String _errorMessage = "";
  bool _downloadCompleted = false;
  String? _apkPath;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final Uri uri = Uri.parse(widget.updateInfo.apkUrl);
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = "${tempDir.path}/fireflytonic-update.apk";
      _apkPath = savePath;

      final File apkFile = File(savePath);
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      _client = http.Client();
      final http.Request request = http.Request('GET', uri);
      request.headers['User-Agent'] = 'Fireflytonic-InAppUpdater';
      final http.StreamedResponse response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception("Error al descargar APK: HTTP ${response.statusCode}");
      }

      final int totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final IOSink sink = apkFile.openWrite();

      await for (List<int> chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (mounted && totalBytes > 0) {
          setState(() {
            _progress = receivedBytes / totalBytes;
            final double mbReceived = receivedBytes / (1024 * 1024);
            final double mbTotal = totalBytes / (1024 * 1024);
            _status =
                "Descargando: ${mbReceived.toStringAsFixed(1)} / ${mbTotal.toStringAsFixed(1)} MB (${(_progress * 100).toInt()}%)";
          });
        } else if (mounted) {
          setState(() {
            final double mbReceived = receivedBytes / (1024 * 1024);
            _status = "Descargando: ${mbReceived.toStringAsFixed(1)} MB";
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _downloadCompleted = true;
          _status = "Descarga completada. Abriendo instalador...";
        });
        await _launchInstaller(savePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
          _status = "Error en la descarga";
        });
      }
    }
  }

  Future<void> _launchInstaller(String path) async {
    try {
      final OpenResult result = await OpenFile.open(
        path,
        type: "application/vnd.android.package-archive",
      );
      log.info(
        "Resultado apertura instalador: ${result.type} - ${result.message}",
      );
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _status = "Esperando confirmación de instalación...";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = "No se pudo iniciar el instalador: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            _isError
                ? Icons.error_outline
                : (_downloadCompleted
                      ? Icons.check_circle_outline
                      : Icons.cloud_download_outlined),
            color: _isError ? Theme.of(context).colorScheme.error : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isError
                  ? "Error de actualización"
                  : (_downloadCompleted
                        ? "Instalar actualización"
                        : "Descargando v${widget.updateInfo.version}"),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (!_isError && !_downloadCompleted)
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          if (_isError) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (_isError)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cerrar"),
          ),
        if (_downloadCompleted && _apkPath != null)
          FilledButton.icon(
            icon: const Icon(Icons.install_mobile),
            label: const Text("Instalar de nuevo"),
            onPressed: () => _launchInstaller(_apkPath!),
          ),
        if (!_downloadCompleted && !_isError)
          TextButton(
            onPressed: () {
              _client?.close();
              Navigator.of(context).pop();
            },
            child: const Text("Cancelar"),
          ),
        if (_downloadCompleted)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cerrar"),
          ),
      ],
    );
  }
}
