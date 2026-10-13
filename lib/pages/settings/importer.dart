import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterflyiii/auth.dart';

const String _prefsKeyUrl = "import_runner_url";

/// Cliente mínimo del "import runner" (servicio del VPS que protege las cuotas
/// de Enable Banking y expone estado/historial del importador de Firefly III).
class ImportRunnerClient {
  ImportRunnerClient(this.baseUrl, this.headers);

  final String baseUrl;
  final Map<String, String> headers;

  Uri _uri(String path) => Uri.parse("$baseUrl$path");

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final http.Client client = httpClient;
    try {
      final http.Request req = http.Request(method, _uri(path));
      req.headers.addAll(headers);
      if (body != null) {
        req.body = jsonEncode(body);
      }
      final http.StreamedResponse streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 40));
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final http.Response r = await _send("GET", path);
    if (r.statusCode != 200) {
      throw ImportRunnerException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<http.Response> post(String path, Object body) =>
      _send("POST", path, body: body);

  Future<http.Response> put(String path, Object body) =>
      _send("PUT", path, body: body);
}

class ImportRunnerException implements Exception {
  ImportRunnerException(this.status, this.body);

  final int status;
  final String body;

  @override
  String toString() => "HTTP $status: $body";
}

String defaultRunnerUrl(Uri? firefly) {
  if (firefly == null) {
    return "";
  }
  final List<String> labels = firefly.host.split(".");
  if (labels.length >= 3) {
    labels[0] = "import-runner";
    return "${firefly.scheme}://${labels.join(".")}";
  }
  return "";
}

String reasonText(String? reason) {
  switch (reason) {
    case "disabled":
      return "Fuente desactivada";
    case "import_running":
      return "Hay una importación en curso";
    case "cooldown_429":
      return "Pausa por límite del banco (429)";
    case "min_interval":
      return "Intervalo mínimo entre importaciones";
    case "daily_budget":
      return "Presupuesto de consultas agotado";
    default:
      return reason ?? "";
  }
}

String statusText(String? s) {
  switch (s) {
    case "ok":
      return "Correcta";
    case "rate_limited":
      return "Límite del banco (429)";
    case "error":
      return "Error";
    case "running":
      return "En curso";
    default:
      return "Desconocido";
  }
}

IconData statusIcon(String? s) {
  switch (s) {
    case "ok":
      return Icons.check_circle_outline;
    case "rate_limited":
      return Icons.hourglass_bottom;
    case "error":
      return Icons.error_outline;
    case "running":
      return Icons.sync;
    default:
      return Icons.help_outline;
  }
}

String fmtDate(String? iso) {
  if (iso == null) {
    return "—";
  }
  final DateTime? d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) {
    return iso;
  }
  return DateFormat("dd/MM HH:mm").format(d);
}

class SettingsImporter extends StatefulWidget {
  const SettingsImporter({super.key});

  @override
  State<SettingsImporter> createState() => _SettingsImporterState();
}

class _SettingsImporterState extends State<SettingsImporter> {
  final Logger log = Logger("Settings.Importer");

  String _url = "";
  Map<String, dynamic>? _status;
  List<dynamic> _runs = <dynamic>[];
  String? _error;
  bool _loading = true;
  bool _running = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  ImportRunnerClient get _client =>
      ImportRunnerClient(_url, context.read<FireflyService>().user!.headers());

  Future<void> _init() async {
    final String? stored = await SharedPreferencesAsync().getString(
      _prefsKeyUrl,
    );
    if (!mounted) {
      return;
    }
    _url =
        stored ?? defaultRunnerUrl(context.read<FireflyService>().user?.host);
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_url.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Configura la URL del servicio de importación.";
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final ImportRunnerClient c = _client;
      final List<Map<String, dynamic>> res = await Future.wait(
        <Future<Map<String, dynamic>>>[
          c.getJson("/api/status"),
          c.getJson("/api/runs?limit=30"),
        ],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = res[0];
        _runs = res[1]["runs"] as List<dynamic>;
        _error = null;
        _loading = false;
        _running = _status?["running"] != null;
      });
      if (_running) {
        _startPolling((_status!["running"] as Map<String, dynamic>)["id"]);
      }
    } catch (e) {
      log.warning("refresh failed", e);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startPolling(String runId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (Timer t) async {
      try {
        final Map<String, dynamic> r = await _client.getJson("/api/run/$runId");
        if (r["status"] != "running") {
          t.cancel();
          if (!mounted) {
            return;
          }
          setState(() => _running = false);
          await _refresh();
        }
      } catch (e) {
        log.warning("poll failed", e);
      }
    });
  }

  Future<void> _runImport(List<String> sources) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text("Importar ahora"),
        content: Text(
          "Se consultará el banco para: ${sources.join(", ")}.\n\n"
          "Cada importación consume parte del límite diario de consultas del "
          "banco (Enable Banking). El servicio bloqueará la petición si "
          "se supera el presupuesto configurado.",
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Importar"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    try {
      final http.Response r = await _client.post("/api/run", <String, dynamic>{
        "sources": sources,
      });
      final Map<String, dynamic> body =
          jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 202) {
        final Map<String, dynamic> denied =
            (body["denied"] as Map<String, dynamic>?) ?? <String, dynamic>{};
        if (denied.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                "Omitido: ${denied.entries.map((MapEntry<String, dynamic> e) => "${e.key} (${reasonText(e.value["reason"] as String?)})").join(", ")}",
              ),
            ),
          );
        }
        _startPolling(body["run_id"] as String);
      } else {
        setState(() => _running = false);
        final Map<String, dynamic> denied =
            (body["denied"] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final String msg = denied.isNotEmpty
            ? denied.entries
                  .map(
                    (MapEntry<String, dynamic> e) =>
                        "${e.key}: ${reasonText(e.value["reason"] as String?)}",
                  )
                  .join("\n")
            : reasonText(body["error"] as String?);
        messenger.showSnackBar(SnackBar(content: Text("No se ejecutó.\n$msg")));
        await _refresh();
      }
    } catch (e) {
      setState(() => _running = false);
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _editUrl() async {
    final TextEditingController ctrl = TextEditingController(text: _url);
    final String? res = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text("URL del servicio de importación"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: "https://import-runner.ejemplo.com",
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
    if (res == null) {
      return;
    }
    final String clean = res.endsWith("/")
        ? res.substring(0, res.length - 1)
        : res;
    await SharedPreferencesAsync().setString(_prefsKeyUrl, clean);
    setState(() => _url = clean);
    await _refresh();
  }

  Future<void> _patchConfig(Map<String, dynamic> patch) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final http.Response r = await _client.put("/api/config", patch);
      if (r.statusCode != 200) {
        messenger.showSnackBar(SnackBar(content: Text(r.body)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    await _refresh();
  }

  Future<void> _editConfig() async {
    final Map<String, dynamic> cfg = _status!["config"] as Map<String, dynamic>;
    final Map<String, TextEditingController> ctrls =
        <String, TextEditingController>{
          "min_interval_minutes": TextEditingController(
            text: "${cfg["min_interval_minutes"]}",
          ),
          "daily_limit_per_source": TextEditingController(
            text: "${cfg["daily_limit_per_source"]}",
          ),
          "reserve_scheduled_hours": TextEditingController(
            text: "${cfg["reserve_scheduled_hours"]}",
          ),
          "cooldown_after_429_minutes": TextEditingController(
            text: "${cfg["cooldown_after_429_minutes"]}",
          ),
        };
    bool reconcile = cfg["run_reconcile"] as bool;
    const Map<String, String> labels = <String, String>{
      "min_interval_minutes": "Intervalo mínimo entre importaciones (min)",
      "daily_limit_per_source": "Máx. consultas por fuente en 24 h",
      "reserve_scheduled_hours": "Reservar hueco para el cron (próximas h)",
      "cooldown_after_429_minutes": "Pausa tras error 429 (min)",
    };
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSt) => AlertDialog(
          title: const Text("Configuración"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final MapEntry<String, TextEditingController> e
                    in ctrls.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: labels[e.key]),
                    ),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Conciliar transferencias tras importar"),
                  value: reconcile,
                  onChanged: (bool v) => setSt(() => reconcile = v),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      return;
    }
    final Map<String, dynamic> patch = <String, dynamic>{
      for (final MapEntry<String, TextEditingController> e in ctrls.entries)
        if (int.tryParse(e.value.text) != null) e.key: int.parse(e.value.text),
      "run_reconcile": reconcile,
    };
    await _patchConfig(patch);
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> sources =
        (_status?["sources"] as List<dynamic>?) ?? <dynamic>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Importación bancaria"),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: <Widget>[
            if (_loading || _running) const LinearProgressIndicator(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dns_outlined),
              title: const Text("Servicio de importación"),
              subtitle: Text(_url.isEmpty ? "Sin configurar" : _url),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editUrl,
            ),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            if (_status != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "Próxima importación programada: "
                  "${fmtDate(_status!["next_scheduled"] as String?)}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final dynamic s in sources)
                _sourceCard(s as Map<String, dynamic>),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.sync),
                      label: const Text("Importar todo"),
                      onPressed:
                          _running ||
                              !sources.any(
                                (dynamic s) =>
                                    (s as Map<String, dynamic>)["can_run"] ==
                                    true,
                              )
                          ? null
                          : () => _runImport(<String>[
                              for (final dynamic s in sources)
                                if ((s as Map<String, dynamic>)["can_run"] ==
                                    true)
                                  s["id"] as String,
                            ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text("Configurar"),
                    onPressed: _editConfig,
                  ),
                ],
              ),
              const Divider(height: 32),
              Text("Historial", style: Theme.of(context).textTheme.titleMedium),
              if (_runs.isEmpty) const ListTile(title: Text("Sin registros")),
              for (final dynamic r in _runs)
                _runTile(r as Map<String, dynamic>),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(Map<String, dynamic> s) {
    final Map<String, dynamic>? last = s["last"] as Map<String, dynamic>?;
    final Map<String, dynamic> usage = s["usage"] as Map<String, dynamic>;
    final bool canRun = s["can_run"] == true && !_running;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    s["label"] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch.adaptive(
                  value: s["enabled"] == true,
                  onChanged: (bool v) => _patchConfig(<String, dynamic>{
                    "sources": <String, dynamic>{
                      s["id"] as String: <String, dynamic>{"enabled": v},
                    },
                  }),
                ),
              ],
            ),
            if (last != null)
              Row(
                children: <Widget>[
                  Icon(statusIcon(last["status"] as String?), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Última: ${fmtDate(last["start"] as String?)} · "
                      "${statusText(last["status"] as String?)} · "
                      "${last["imported"]} nuevos",
                    ),
                  ),
                ],
              )
            else
              const Text("Sin importaciones registradas"),
            const SizedBox(height: 4),
            Text(
              "Consultas al banco (últimas ${usage["window_hours"]} h): "
              "${usage["used"]}/${usage["limit"]}"
              "${(usage["reserved_for_schedule"] as int) > 0 ? " (+${usage["reserved_for_schedule"]} reservadas para el cron)" : ""}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (s["can_run"] != true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "${reasonText(s["reason"] as String?)}"
                  "${s["retry_at"] != null ? " · disponible ${fmtDate(s["retry_at"] as String?)}" : ""}",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text("Importar"),
                onPressed: canRun
                    ? () => _runImport(<String>[s["id"] as String])
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runTile(Map<String, dynamic> r) {
    final List<dynamic> moves =
        (r["movements"] as List<dynamic>?) ?? <dynamic>[];
    final String trigger = r["trigger"] == "app" ? "manual" : "programada";
    final String title =
        "${r["label"]} · ${fmtDate(r["start"] as String?)} · $trigger";
    final String subtitle =
        "${statusText(r["status"] as String?)} · ${r["imported"]} nuevos";
    if (moves.isEmpty) {
      return ListTile(
        dense: true,
        leading: Icon(statusIcon(r["status"] as String?)),
        title: Text(title),
        subtitle: Text(subtitle),
      );
    }
    return ExpansionTile(
      leading: Icon(statusIcon(r["status"] as String?)),
      title: Text(title),
      subtitle: Text(subtitle),
      children: <Widget>[
        for (final dynamic m in moves) _movementTile(m as Map<String, dynamic>),
      ],
    );
  }

  Widget _movementTile(Map<String, dynamic> m) {
    final double? amount = double.tryParse(m["amount"] as String? ?? "");
    final String type = m["type"] as String? ?? "";
    final String sign = type == "withdrawal"
        ? "-"
        : (type == "deposit" ? "+" : "");
    final String amountText = amount == null
        ? ""
        : "$sign${amount.abs().toStringAsFixed(2)} ${m["currency"] ?? ""}";
    final DateTime? d = DateTime.tryParse(m["date"] as String? ?? "");
    return ListTile(
      dense: true,
      title: Text(
        m["description"] as String? ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${d != null ? DateFormat("dd/MM/yyyy").format(d) : ""} · $type",
      ),
      trailing: Text(amountText),
    );
  }
}
