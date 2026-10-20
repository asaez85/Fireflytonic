import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/pages/transaction/category_select.dart';
import 'package:waterflyiii/services/ai_categorizer.dart';
import 'package:waterflyiii/settings.dart';

final Logger log = Logger("Pages.AICategorizer");

class _AICategorizerPageData {
  _AICategorizerPageData({
    required this.config,
    required this.reviewGroups,
    required this.categoryIdByName,
  });

  final AICategorizerConfig config;
  final List<AICategorizerReviewGroup> reviewGroups;
  final Map<String, String> categoryIdByName;
}

class AICategorizerPage extends StatefulWidget {
  const AICategorizerPage({super.key});

  @override
  State<AICategorizerPage> createState() => _AICategorizerPageState();
}

class _AICategorizerPageState extends State<AICategorizerPage> {
  bool _runningBatch = false;
  Future<_AICategorizerPageData>? _dataFuture;

  AICategorizerClient get _client {
    final SettingsProvider settings = context.read<SettingsProvider>();
    return AICategorizerClient(
      baseUrl: settings.aiCategorizerUrl,
      apiKey: settings.aiCategorizerKey,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= _loadData();
  }

  Future<_AICategorizerPageData> _loadData() async {
    final AICategorizerClient client = _client;
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      client.getConfig(),
      client.getReview(),
      client.getCategories(),
    ]);
    final AICategorizerConfig config = results[0] as AICategorizerConfig;
    final List<AICategorizerReviewGroup> review =
        results[1] as List<AICategorizerReviewGroup>;
    final List<AICategorizerCategory> categories =
        results[2] as List<AICategorizerCategory>;
    final Map<String, String> categoryIdByName = <String, String>{};
    for (final AICategorizerCategory c in categories) {
      categoryIdByName[c.name] = c.id;
    }
    return _AICategorizerPageData(
      config: config,
      reviewGroups: review,
      categoryIdByName: categoryIdByName,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _runBatch() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _runningBatch = true);
    try {
      final AICategorizerBatchResponse resp = await _client.runBatch();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Batch lanzado: ${resp.enqueued} transacciones en cola",
          ),
        ),
      );
      await _refresh();
    } on AICategorizerException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error al lanzar batch: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error al lanzar batch: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _runningBatch = false);
      }
    }
  }

  Future<void> _applyCategory(
    AICategorizerReviewGroup group,
    String categoryName,
    _AICategorizerPageData data,
  ) async {
    final String? categoryId = data.categoryIdByName[categoryName];
    if (categoryId == null || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró el ID de esa categoría")),
      );
      return;
    }

    setState(() => _runningBatch = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      for (final AICategorizerReviewTransaction t in group.transactions) {
        await _client.applyCategory(t.id, categoryId: categoryId);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Categoría '$categoryName' aplicada a ${group.transactions.length} movimiento(s)",
          ),
        ),
      );
      await _refresh();
    } on AICategorizerException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error al aplicar categoría: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error al aplicar categoría: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _runningBatch = false);
      }
    }
  }

  Future<void> _pickAndApplyCategory(
    AICategorizerReviewGroup group,
    _AICategorizerPageData data,
  ) async {
    final String? selected = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) =>
            CategorySelectPage(selectedCategoryName: group.categoryName ?? ""),
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      await _applyCategory(group, selected, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clasificador IA"),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
            onPressed: _runningBatch ? null : _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_AICategorizerPageData>(
        future: _dataFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<_AICategorizerPageData> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          "No se pudo conectar con el clasificador:",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _refresh,
                          child: const Text("Reintentar"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final _AICategorizerPageData data = snapshot.data!;
              final AICategorizerConfig config = data.config;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  _buildStatusCard(context, config),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _runningBatch
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        _runningBatch
                            ? "Lanzando batch..."
                            : "Clasificar movimientos pendientes",
                      ),
                      onPressed: _runningBatch ? null : _runBatch,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildReviewSection(context, data),
                ],
              );
            },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AICategorizerConfig config) {
    final Color statusColor = config.configured
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  config.configured ? Icons.check_circle : Icons.warning,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.configured
                        ? "Clasificador configurado"
                        : "Clasificador no configurado",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow("URL Firefly", config.fireflyUrl),
            _buildStatusRow("Proveedor IA", config.aiProvider),
            _buildStatusRow("Modelo", _modelLabel(config)),
            _buildStatusRow(
              "Mapeo de destino",
              config.destinationMatchEnabled ? "Activado" : "Desactivado",
            ),
          ],
        ),
      ),
    );
  }

  String _modelLabel(AICategorizerConfig config) {
    switch (config.aiProvider.toLowerCase()) {
      case "openai":
        return config.openaiModel;
      case "gemini":
        return config.geminiModel;
      case "deepseek":
        return config.deepseekModel;
      default:
        return "—";
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "—",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(
    BuildContext context,
    _AICategorizerPageData data,
  ) {
    if (data.reviewGroups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                "No hay movimientos pendientes de revisión",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "Revisión (${data.reviewGroups.length} grupos)",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...data.reviewGroups.map(
          (AICategorizerReviewGroup group) =>
              _buildReviewCard(context, group, data),
        ),
      ],
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    AICategorizerReviewGroup group,
    _AICategorizerPageData data,
  ) {
    final Color outcomeColor = _outcomeColor(group.outcome);
    final String outcomeLabel = _outcomeLabel(group.outcome);
    final bool canConfirm =
        group.categoryName != null && group.categoryName!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Chip(
                  label: Text(outcomeLabel),
                  backgroundColor: outcomeColor.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: outcomeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  "${group.transactions.length} mov.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              group.description.isNotEmpty
                  ? group.description
                  : group.destinationName,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (group.destinationName.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                group.destinationName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (canConfirm) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.category,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Sugerencia: ${group.categoryName}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...group.transactions.map(
              (AICategorizerReviewTransaction t) =>
                  _buildReviewTransactionRow(t),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (canConfirm)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Confirmar"),
                      onPressed: _runningBatch
                          ? null
                          : () => _applyCategory(
                              group,
                              group.categoryName!,
                              data,
                            ),
                    ),
                  ),
                if (canConfirm) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.category, size: 18),
                    label: const Text("Categoría"),
                    onPressed: _runningBatch
                        ? null
                        : () => _pickAndApplyCategory(group, data),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTransactionRow(AICategorizerReviewTransaction t) {
    final double? amount = double.tryParse(t.amount);
    final String amountText = amount != null
        ? NumberFormat.currency(symbol: "", decimalDigits: 2).format(amount)
        : t.amount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              t.date.isNotEmpty ? t.date : "Movimiento ${t.id}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            amountText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _outcomeColor(String outcome) {
    final ThemeData theme = Theme.of(context);
    switch (outcome) {
      case "NEEDS_REVIEW":
        return theme.colorScheme.error;
      case "ASSUMED":
        return theme.colorScheme.tertiary;
      case "DEST_ASSUMED":
        return theme.colorScheme.secondary;
      case "TRANSFER_CATEGORY":
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String _outcomeLabel(String outcome) {
    switch (outcome) {
      case "NEEDS_REVIEW":
        return "Revisar";
      case "ASSUMED":
        return "Asumido";
      case "DEST_ASSUMED":
        return "Destino asumido";
      case "TRANSFER_CATEGORY":
        return "Transferencia";
      default:
        return outcome;
    }
  }
}
