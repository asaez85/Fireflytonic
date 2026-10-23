import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/pages/settings.dart';
import 'package:waterflyiii/services/ai_categorizer.dart';
import 'package:waterflyiii/settings.dart';

final Logger log = Logger("Pages.Settings.AICategorizer");

class AICategorizerSettingsSection extends StatefulWidget {
  const AICategorizerSettingsSection({super.key});

  @override
  State<AICategorizerSettingsSection> createState() =>
      _AICategorizerSettingsSectionState();
}

class _AICategorizerSettingsSectionState
    extends State<AICategorizerSettingsSection> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _keyFocusNode = FocusNode();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _urlFocusNode.addListener(_onUrlFocusChange);
    _keyFocusNode.addListener(_onKeyFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SettingsProvider settings = context.read<SettingsProvider>();
    if (_urlController.text != settings.aiCategorizerUrl) {
      _urlController.text = settings.aiCategorizerUrl;
    }
    final String keyText = settings.aiCategorizerKey ?? "";
    if (_keyController.text != keyText) {
      _keyController.text = keyText;
    }
  }

  void _onUrlFocusChange() {
    if (!_urlFocusNode.hasFocus) {
      _saveUrl();
    }
  }

  void _onKeyFocusChange() {
    if (!_keyFocusNode.hasFocus) {
      _saveKey();
    }
  }

  Future<void> _saveUrl() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    await settings.setAICategorizerUrl(url);
  }

  Future<void> _saveKey() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    final String key = _keyController.text.trim();
    await settings.setAICategorizerKey(key.isEmpty ? null : key);
  }

  Future<void> _testConnection() async {
    await _saveUrl();
    await _saveKey();
    if (!mounted) return;

    final SettingsProvider settings = context.read<SettingsProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (!settings.aiCategorizerEnabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Activa el clasificador antes de probar")),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final AICategorizerClient client = AICategorizerClient(
        baseUrl: settings.aiCategorizerUrl,
        apiKey: settings.aiCategorizerKey,
      );
      final AICategorizerConfig config = await client.getConfig();
      if (!mounted) return;
      if (config.configured) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "Conectado. Configurado: ${config.configured} • Proveedor: ${config.aiProvider}",
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Conectado, pero el clasificador no está configurado. Revisa la configuración del servicio.",
            ),
          ),
        );
      }
    } on AICategorizerException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error de conexión: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  void dispose() {
    _urlFocusNode.removeListener(_onUrlFocusChange);
    _keyFocusNode.removeListener(_onKeyFocusChange);
    _urlFocusNode.dispose();
    _keyFocusNode.dispose();
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final bool enabled = settings.aiCategorizerEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SettingsSectionHeader(title: "Clasificador IA"),
        SwitchListTile.adaptive(
          title: const Text("Activar clasificador IA"),
          subtitle: const Text("Usar FireflyIII-AI-Categorizer"),
          value: enabled,
          secondary: const CircleAvatar(child: Icon(Icons.auto_awesome)),
          onChanged: (bool value) => settings.setAICategorizerEnabled(value),
        ),
        if (enabled) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 4.0,
            ),
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: "URL del clasificador",
                hintText: "http://127.0.0.1:3000",
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 4.0,
            ),
            child: TextField(
              controller: _keyController,
              focusNode: _keyFocusNode,
              obscureText: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: "API Key / token (opcional)",
                helperText:
                    "Pangolin SSO: TokenID.Token (ej: mvhbjdgs.secreto)",
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_testing ? "Probando..." : "Probar conexión"),
                onPressed: _testing ? null : _testConnection,
              ),
            ),
          ),
        ],
        const Divider(),
      ],
    );
  }
}
