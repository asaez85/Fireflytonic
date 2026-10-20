import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final Logger log = Logger("Services.AICategorizer");

class AICategorizerException implements Exception {
  AICategorizerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? "AICategorizerException ($statusCode): $message"
      : "AICategorizerException: $message";
}

class AICategorizerConfig {
  AICategorizerConfig({
    required this.fireflyUrl,
    required this.fireflyTokenSet,
    required this.aiProvider,
    required this.openaiKeySet,
    required this.openaiModel,
    required this.openaiBaseUrl,
    required this.geminiKeySet,
    required this.geminiModel,
    required this.deepseekKeySet,
    required this.deepseekModel,
    required this.tagPrefix,
    required this.customSystemContext,
    required this.configured,
    required this.destinationMatchEnabled,
    required this.searchEngine,
    required this.historyContextLimit,
    required this.historyLookbackDays,
    required this.workerConcurrency,
    required this.batchConcurrency,
  });

  final String fireflyUrl;
  final bool fireflyTokenSet;
  final String aiProvider;
  final bool openaiKeySet;
  final String openaiModel;
  final String openaiBaseUrl;
  final bool geminiKeySet;
  final String geminiModel;
  final bool deepseekKeySet;
  final String deepseekModel;
  final String tagPrefix;
  final String customSystemContext;
  final bool configured;
  final bool destinationMatchEnabled;
  final String searchEngine;
  final int historyContextLimit;
  final int historyLookbackDays;
  final int workerConcurrency;
  final int batchConcurrency;

  factory AICategorizerConfig.fromJson(Map<String, dynamic> json) {
    return AICategorizerConfig(
      fireflyUrl: json['firefly_url'] as String? ?? "",
      fireflyTokenSet: json['firefly_token_set'] as bool? ?? false,
      aiProvider: json['ai_provider'] as String? ?? "",
      openaiKeySet: json['openai_key_set'] as bool? ?? false,
      openaiModel: json['openai_model'] as String? ?? "",
      openaiBaseUrl: json['openai_base_url'] as String? ?? "",
      geminiKeySet: json['gemini_key_set'] as bool? ?? false,
      geminiModel: json['gemini_model'] as String? ?? "",
      deepseekKeySet: json['deepseek_key_set'] as bool? ?? false,
      deepseekModel: json['deepseek_model'] as String? ?? "",
      tagPrefix: json['tag_prefix'] as String? ?? "ai",
      customSystemContext: json['custom_system_context'] as String? ?? "",
      configured: json['configured'] as bool? ?? false,
      destinationMatchEnabled:
          json['destination_match_enabled'] as bool? ?? false,
      searchEngine: json['search_engine'] as String? ?? "",
      historyContextLimit: json['history_context_limit'] as int? ?? 0,
      historyLookbackDays: json['history_lookback_days'] as int? ?? 0,
      workerConcurrency: json['worker_concurrency'] as int? ?? 1,
      batchConcurrency: json['batch_concurrency'] as int? ?? 5,
    );
  }
}

class AICategorizerBatchResponse {
  AICategorizerBatchResponse({required this.batchId, required this.enqueued});

  final String batchId;
  final int enqueued;

  factory AICategorizerBatchResponse.fromJson(Map<String, dynamic> json) {
    return AICategorizerBatchResponse(
      batchId: json['batch_id'] as String? ?? "",
      enqueued: json['enqueued'] as int? ?? 0,
    );
  }
}

class AICategorizerReviewTransaction {
  AICategorizerReviewTransaction({
    required this.id,
    required this.date,
    required this.amount,
  });

  final String id;
  final String date;
  final String amount;

  factory AICategorizerReviewTransaction.fromJson(Map<String, dynamic> json) {
    return AICategorizerReviewTransaction(
      id: json['id'] as String? ?? "",
      date: json['date'] as String? ?? "",
      amount: json['amount'] as String? ?? "",
    );
  }
}

class AICategorizerReviewGroup {
  AICategorizerReviewGroup({
    required this.outcome,
    required this.description,
    required this.destinationName,
    required this.sourceName,
    required this.categoryName,
    required this.categoryId,
    required this.destinationAccountId,
    required this.transactions,
  });

  final String outcome;
  final String description;
  final String destinationName;
  final String sourceName;
  final String? categoryName;
  final String? categoryId;
  final String? destinationAccountId;
  final List<AICategorizerReviewTransaction> transactions;

  factory AICategorizerReviewGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> txnJson =
        json['transactions'] as List<dynamic>? ?? <dynamic>[];
    return AICategorizerReviewGroup(
      outcome: json['outcome'] as String? ?? "",
      description: json['description'] as String? ?? "",
      destinationName: json['destination_name'] as String? ?? "",
      sourceName: json['source_name'] as String? ?? "",
      categoryName: json['category_name'] as String?,
      categoryId: json['category_id'] as String?,
      destinationAccountId: json['destination_account_id'] as String?,
      transactions: txnJson
          .map(
            (dynamic e) => AICategorizerReviewTransaction.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class AICategorizerCategory {
  AICategorizerCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory AICategorizerCategory.fromJson(Map<String, dynamic> json) {
    return AICategorizerCategory(
      id: json['id'] as String? ?? "",
      name: json['name'] as String? ?? "",
    );
  }
}

class AICategorizerClient {
  AICategorizerClient({required String baseUrl, this.apiKey})
    : _baseUrl = _cleanUrl(baseUrl);

  final String _baseUrl;
  final String? apiKey;

  static const Duration _timeout = Duration(seconds: 15);

  static String _cleanUrl(String url) {
    String cleaned = url.trim();
    while (cleaned.endsWith("/")) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Map<String, String> _headers() {
    final Map<String, String> headers = <String, String>{
      HttpHeaders.contentTypeHeader: "application/json",
      HttpHeaders.acceptHeader: "application/json",
    };
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = "Bearer ${apiKey!}";
      if (apiKey!.contains(".")) {
        final List<String> parts = apiKey!.split(".");
        if (parts.length == 2) {
          headers["P-Access-Token-Id"] = parts[0];
          headers["P-Access-Token"] = parts[1];
        }
      }
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse("$_baseUrl$path");

  Future<AICategorizerConfig> getConfig() async {
    final http.Client client = http.Client();
    try {
      final http.Response response = await client
          .get(_uri("/api/config"), headers: _headers())
          .timeout(_timeout);
      _checkResponse(response);
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      return AICategorizerConfig.fromJson(json);
    } on TimeoutException {
      throw AICategorizerException(
        "Tiempo de espera agotado al contactar el clasificador",
      );
    } on FormatException catch (e) {
      throw AICategorizerException("Respuesta inválida del clasificador: $e");
    } catch (e) {
      throw AICategorizerException("Error de conexión: $e");
    } finally {
      client.close();
    }
  }

  Future<AICategorizerBatchResponse> runBatch({
    bool uncategorizedOnly = true,
    List<String>? transactionIds,
    bool dryRun = false,
    bool force = false,
    String mode = "classify",
  }) async {
    final http.Client client = http.Client();
    try {
      final Map<String, dynamic> filter = <String, dynamic>{
        "uncategorized_only": uncategorizedOnly,
      };
      if (transactionIds != null) {
        filter["transaction_ids"] = transactionIds;
      }
      final Map<String, dynamic> body = <String, dynamic>{
        "filter": filter,
        "dry_run": dryRun,
        "force": force,
        "mode": mode,
      };

      final http.Response response = await client
          .post(_uri("/batch/run"), headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      _checkResponse(response);
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      return AICategorizerBatchResponse.fromJson(json);
    } on TimeoutException {
      throw AICategorizerException(
        "Tiempo de espera agotado al lanzar el batch",
      );
    } on FormatException catch (e) {
      throw AICategorizerException("Respuesta inválida del clasificador: $e");
    } catch (e) {
      throw AICategorizerException("Error de conexión: $e");
    } finally {
      client.close();
    }
  }

  Future<List<AICategorizerReviewGroup>> getReview() async {
    final http.Client client = http.Client();
    try {
      final http.Response response = await client
          .get(_uri("/api/review"), headers: _headers())
          .timeout(_timeout);
      _checkResponse(response);
      final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
      return json
          .map(
            (dynamic e) =>
                AICategorizerReviewGroup.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on TimeoutException {
      throw AICategorizerException(
        "Tiempo de espera agotado al obtener revisión",
      );
    } on FormatException catch (e) {
      throw AICategorizerException("Respuesta inválida del clasificador: $e");
    } catch (e) {
      throw AICategorizerException("Error de conexión: $e");
    } finally {
      client.close();
    }
  }

  Future<AICategorizerBatchResponse> classifyTransactionById(String id) {
    return runBatch(transactionIds: <String>[id], uncategorizedOnly: false);
  }

  Future<void> applyCategory(
    String transactionId, {
    String? categoryId,
    String? destinationAction,
    String? destinationName,
    String? destinationId,
  }) async {
    final http.Client client = http.Client();
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        if (categoryId != null && categoryId.isNotEmpty)
          "category_id": categoryId,
        if (destinationAction != null && destinationAction.isNotEmpty)
          "destination_action": destinationAction,
        if (destinationName != null && destinationName.isNotEmpty)
          "destination_name": destinationName,
        if (destinationId != null && destinationId.isNotEmpty)
          "destination_id": destinationId,
      };

      final http.Response response = await client
          .put(
            _uri("/api/transactions/$transactionId/categorize"),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      _checkResponse(response, allowNoContent: true);
    } on TimeoutException {
      throw AICategorizerException(
        "Tiempo de espera agotado al aplicar la categoría",
      );
    } catch (e) {
      throw AICategorizerException("Error de conexión: $e");
    } finally {
      client.close();
    }
  }

  Future<List<AICategorizerCategory>> getCategories() async {
    final http.Client client = http.Client();
    try {
      final http.Response response = await client
          .get(_uri("/api/categories"), headers: _headers())
          .timeout(_timeout);
      _checkResponse(response);
      final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
      return json
          .map(
            (dynamic e) =>
                AICategorizerCategory.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on TimeoutException {
      throw AICategorizerException(
        "Tiempo de espera agotado al obtener categorías",
      );
    } catch (e) {
      throw AICategorizerException("Error de conexión: $e");
    } finally {
      client.close();
    }
  }

  void _checkResponse(http.Response response, {bool allowNoContent = false}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 && allowNoContent) {
        return;
      }
      if (response.body.isNotEmpty) {
        return;
      }
      throw AICategorizerException(
        "Respuesta vacía del servidor",
        statusCode: response.statusCode,
      );
    }

    String message =
        response.reasonPhrase ?? "Error HTTP ${response.statusCode}";
    try {
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey("error")) {
        message = json["error"]?.toString() ?? message;
      }
    } catch (_) {
      // Keep default HTTP message
    }
    throw AICategorizerException(message, statusCode: response.statusCode);
  }
}
