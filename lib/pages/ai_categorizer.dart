import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/pages/transaction/category_select.dart';
import 'package:waterflyiii/services/ai_categorizer.dart';
import 'package:waterflyiii/settings.dart';

final Logger log = Logger("Pages.AICategorizer");

class _AICategorizerPageData {
  _AICategorizerPageData({
    required this.config,
    required this.reviewGroups,
    required this.categoryIdByName,
    required this.jobs,
  });

  final AICategorizerConfig config;
  final List<AICategorizerReviewGroup> reviewGroups;
  final Map<String, String> categoryIdByName;
  final List<AICategorizerJob> jobs;
}

class AICategorizerPage extends StatefulWidget {
  const AICategorizerPage({super.key});

  @override
  State<AICategorizerPage> createState() => _AICategorizerPageState();
}

class _AICategorizerPageState extends State<AICategorizerPage>
    with SingleTickerProviderStateMixin {
  bool _runningBatch = false;
  Future<_AICategorizerPageData>? _dataFuture;
  _AICategorizerPageData? _data;
  late TabController _tabController;

  AICategorizerClient get _client {
    final SettingsProvider settings = context.read<SettingsProvider>();
    return AICategorizerClient(
      baseUrl: settings.aiCategorizerUrl,
      apiKey: settings.aiCategorizerKey,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavElements();
    });
  }

  @override
  void dispose() {
    if (mounted) {
      final NavPageElements nav = context.read<NavPageElements>();
      nav.appBarBottom = null;
    }
    _tabController.dispose();
    super.dispose();
  }

  void _updateNavElements() {
    if (!mounted) return;
    final NavPageElements nav = context.read<NavPageElements>();
    final int pendingCount = _data?.reviewGroups.length ?? 0;
    final int runningCount =
        _data?.jobs
            .where((AICategorizerJob j) => j.status.toLowerCase() == "running")
            .length ??
        0;
    nav.appBarTitle = const Text("Clasificador IA");
    nav.appBarActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: "Actualizar",
        onPressed: _runningBatch ? null : _refresh,
      ),
    ];
    nav.appBarBottom = TabBar(
      controller: _tabController,
      tabs: <Widget>[
        _buildTab("Pendientes", pendingCount),
        _buildTab("Trabajos", runningCount),
      ],
    );
  }

  Widget _buildTab(String label, int count) {
    if (count > 0) {
      return Badge(
        isLabelVisible: true,
        label: Text("$count"),
        child: Text(label),
      );
    }
    return Text(label);
  }

  Future<_AICategorizerPageData> _loadData() async {
    final AICategorizerClient client = _client;
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      client.getConfig(),
      client.getReview(),
      client.getCategories(),
      client.getJobs(),
    ]);
    final AICategorizerConfig config = results[0] as AICategorizerConfig;
    final List<AICategorizerReviewGroup> review =
        results[1] as List<AICategorizerReviewGroup>;
    final List<AICategorizerCategory> categories =
        results[2] as List<AICategorizerCategory>;
    final List<AICategorizerJob> jobs = results[3] as List<AICategorizerJob>;
    final Map<String, String> categoryIdByName = <String, String>{};
    for (final AICategorizerCategory c in categories) {
      categoryIdByName[c.name] = c.id;
    }
    return _AICategorizerPageData(
      config: config,
      reviewGroups: review,
      categoryIdByName: categoryIdByName,
      jobs: jobs,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _runBatch() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _runningBatch = true;
    });
    _updateNavElements();
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
        setState(() {
          _runningBatch = false;
        });
        _updateNavElements();
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

    setState(() {
      _runningBatch = true;
    });
    _updateNavElements();
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
        setState(() {
          _runningBatch = false;
        });
        _updateNavElements();
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
    return FutureBuilder<_AICategorizerPageData>(
      future: _dataFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<_AICategorizerPageData> snapshot,
          ) {
            if (snapshot.hasData) {
              _data = snapshot.data;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateNavElements();
              });
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                _data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && _data == null) {
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

            final _AICategorizerPageData data = _data!;

            return TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildPendingTab(context, data),
                _buildJobsTab(context, data),
              ],
            );
          },
    );
  }

  Widget _buildPendingTab(BuildContext context, _AICategorizerPageData data) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildStatusCard(context, data.config),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _runningBatch
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
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
      ),
    );
  }

  Widget _buildJobsTab(BuildContext context, _AICategorizerPageData data) {
    if (data.jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildJobsEmptyState(context),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: data.jobs.length,
        itemBuilder: (BuildContext context, int index) =>
            _buildJobCard(context, data.jobs[index]),
      ),
    );
  }

  Widget _buildJobsEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.work_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay trabajos de clasificación recientes",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "Los trabajos aparecerán cuando lances un batch",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, AICategorizerJob job) {
    final String amountText = NumberFormat.currency(
      symbol: "",
      decimalDigits: 2,
    ).format(job.amount);
    final String dateText = _formatJobDate(job.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _showJobDetails(context, job),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildJobStatusChip(context, job),
                  const Spacer(),
                  if (job.source.isNotEmpty) ...<Widget>[
                    Chip(
                      label: Text(_jobSourceLabel(job.source)),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                      labelStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.description.isNotEmpty
                    ? job.description
                    : "Movimiento ${job.transactionId}",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (job.destinationName.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  job.destinationName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.euro_symbol,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    amountText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (job.category != null &&
                      job.category!.isNotEmpty) ...<Widget>[
                    Icon(
                      Icons.category,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.category!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobStatusChip(BuildContext context, AICategorizerJob job) {
    final bool isRunning = job.status.toLowerCase() == "running";
    final Color color = _jobStatusColor(context, job);
    return Chip(
      avatar: isRunning
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : null,
      label: Text(_jobStatusLabel(job)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  String _jobStatusLabel(AICategorizerJob job) {
    final String status = job.status.toLowerCase();
    if (status == "running") return "En curso";
    if (status == "failed") return "Error";
    switch (job.outcome.toUpperCase()) {
      case "CLASSIFIED":
        return "Clasificado";
      case "NEEDS_REVIEW":
        return "Revisar";
      case "SKIPPED":
        return "Omitido";
      case "ERROR":
        return "Error";
      default:
        return status.isNotEmpty ? job.status : "Finalizado";
    }
  }

  Color _jobStatusColor(BuildContext context, AICategorizerJob job) {
    final ThemeData theme = Theme.of(context);
    final String status = job.status.toLowerCase();
    if (status == "running") return theme.colorScheme.primary;
    if (status == "failed") return theme.colorScheme.error;
    switch (job.outcome.toUpperCase()) {
      case "CLASSIFIED":
        return theme.colorScheme.primary;
      case "NEEDS_REVIEW":
        return theme.colorScheme.error;
      case "SKIPPED":
        return theme.colorScheme.onSurfaceVariant;
      case "ERROR":
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _jobSourceLabel(String source) {
    switch (source.toLowerCase()) {
      case "jev":
        return "Jev";
      case "jev_fallback":
        return "Jev fallback";
      case "llm":
        return "LLM";
      case "history":
        return "Historial";
      default:
        return source;
    }
  }

  String _formatJobDate(DateTime date) {
    return DateFormat.yMMMd().add_Hm().format(date);
  }

  Future<void> _showJobDetails(
    BuildContext context,
    AICategorizerJob job,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Detalle del trabajo"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildDetailRow("ID", job.id),
                _buildDetailRow("Batch", job.batchId),
                _buildDetailRow("Estado", _jobStatusLabel(job)),
                _buildDetailRow(
                  "Resultado",
                  job.outcome.isNotEmpty ? job.outcome : "—",
                ),
                _buildDetailRow("Origen", _jobSourceLabel(job.source)),
                _buildDetailRow("Transacción", job.transactionId),
                _buildDetailRow("Descripción", job.description),
                _buildDetailRow("Destino", job.destinationName),
                _buildDetailRow(
                  "Importe",
                  NumberFormat.currency(
                    symbol: "",
                    decimalDigits: 2,
                  ).format(job.amount),
                ),
                if (job.category != null && job.category!.isNotEmpty)
                  _buildDetailRow("Categoría", job.category!),
                _buildDetailRow(
                  "Motivo",
                  job.reason.isNotEmpty ? job.reason : "—",
                ),
                _buildDetailRow("Creado", _formatJobDate(job.createdAt)),
                _buildDetailRow("Actualizado", _formatJobDate(job.updatedAt)),
                if (job.error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    "Error",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(job.error),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
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
