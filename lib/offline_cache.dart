import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

final Logger _log = Logger("OfflineCache");

class CachedHttpResponse {
  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final DateTime timestamp;

  CachedHttpResponse({
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'statusCode': statusCode,
    'headers': headers,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CachedHttpResponse.fromJson(Map<String, dynamic> json) =>
      CachedHttpResponse(
        url: json['url'] as String,
        statusCode: json['statusCode'] as int? ?? 200,
        headers:
            (json['headers'] as Map<String, dynamic>?)?.map(
              (String k, dynamic v) =>
                  MapEntry<String, String>(k, v.toString()),
            ) ??
            <String, String>{},
        body: json['body'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
      );

  http.StreamedResponse toStreamedResponse(http.BaseRequest request) {
    final List<int> bytes = utf8.encode(body);
    final Map<String, String> respHeaders = Map<String, String>.from(headers);
    respHeaders.remove('content-encoding');
    respHeaders['content-length'] = bytes.length.toString();
    if (!respHeaders.containsKey('content-type')) {
      respHeaders['content-type'] = 'application/json; charset=utf-8';
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      contentLength: bytes.length,
      request: request,
      headers: respHeaders,
      reasonPhrase: 'OK (Offline Cache)',
    );
  }
}

class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  final Map<String, CachedHttpResponse> _httpCache =
      <String, CachedHttpResponse>{};
  final Map<String, dynamic> _genericJsonCache = <String, dynamic>{};

  bool _initialized = false;
  File? _httpCacheFile;
  File? _genericCacheFile;
  Timer? _saveDebounce;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final Directory cacheDir = Directory('${dir.path}/stock_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _httpCacheFile = File('${cacheDir.path}/http_get_cache.json');
      _genericCacheFile = File('${cacheDir.path}/offline_generic_cache.json');

      if (await _httpCacheFile!.exists()) {
        final String content = await _httpCacheFile!.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> decoded =
              jsonDecode(content) as Map<String, dynamic>;
          for (final MapEntry<String, dynamic> e in decoded.entries) {
            try {
              _httpCache[e.key] = CachedHttpResponse.fromJson(
                e.value as Map<String, dynamic>,
              );
            } catch (err) {
              _log.fine("Error loading cache entry ${e.key}: $err");
            }
          }
        }
      }

      if (await _genericCacheFile!.exists()) {
        final String content = await _genericCacheFile!.readAsString();
        if (content.isNotEmpty) {
          final dynamic decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _genericJsonCache.addAll(decoded);
          }
        }
      }
      _initialized = true;
    } catch (e) {
      _log.warning("OfflineCache init failed: $e");
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        if (_httpCacheFile != null) {
          final Map<String, dynamic> jsonMap = <String, dynamic>{};
          _httpCache.forEach((String k, CachedHttpResponse v) {
            jsonMap[k] = v.toJson();
          });
          await _httpCacheFile!.writeAsString(jsonEncode(jsonMap));
        }
        if (_genericCacheFile != null) {
          await _genericCacheFile!.writeAsString(jsonEncode(_genericJsonCache));
        }
      } catch (e) {
        _log.warning("OfflineCache save failed: $e");
      }
    });
  }

  Future<void> saveHttpResponse(
    String url,
    int statusCode,
    Map<String, String> headers,
    String body,
  ) async {
    await init();
    _httpCache[url] = CachedHttpResponse(
      url: url,
      statusCode: statusCode,
      headers: headers,
      body: body,
    );
    _scheduleSave();
  }

  Future<CachedHttpResponse?> getHttpResponse(String url) async {
    await init();
    if (_httpCache.containsKey(url)) {
      return _httpCache[url];
    }
    // Try matching ignoring query order or host
    final Uri targetUri = Uri.parse(url);
    for (final MapEntry<String, CachedHttpResponse> entry
        in _httpCache.entries) {
      final Uri cachedUri = Uri.parse(entry.key);
      if (cachedUri.path == targetUri.path) {
        // Same endpoint path
        bool match = true;
        for (final MapEntry<String, String> q
            in targetUri.queryParameters.entries) {
          if (cachedUri.queryParameters[q.key] != q.value) {
            match = false;
            break;
          }
        }
        if (match) {
          return entry.value;
        }
      }
    }

    // Dynamic fallback synthesis from existing transactions in stock_cache
    final CachedHttpResponse? synthesized = await _synthesizeFromTransactions(
      url,
      targetUri,
    );
    if (synthesized != null) {
      _httpCache[url] = synthesized;
      _scheduleSave();
      return synthesized;
    }

    return null;
  }

  Future<void> saveJson(String key, dynamic data) async {
    await init();
    _genericJsonCache[key] = data;
    _scheduleSave();
  }

  Future<dynamic> getJson(String key) async {
    await init();
    return _genericJsonCache[key];
  }

  /// Synchronous in-memory lookup for instant UI rendering (0 ms)
  dynamic getJsonSync(String key) {
    return _genericJsonCache[key];
  }

  Map<String, dynamic>? _cachedTxMap;

  /// Synthesizes valid responses for core endpoints when offline
  /// based on transactions_single.json if it exists on disk.
  Future<CachedHttpResponse?> _synthesizeFromTransactions(
    String rawUrl,
    Uri uri,
  ) async {
    try {
      Map<String, dynamic>? txMap = _cachedTxMap;
      if (txMap == null) {
        final Directory dir = await getApplicationSupportDirectory();
        final File txFile = File(
          '${dir.path}/stock_cache/transactions_single.json',
        );
        if (!await txFile.exists()) {
          return null;
        }
        final String txText = await txFile.readAsString();
        if (txText.isEmpty) {
          return null;
        }
        txMap = jsonDecode(txText) as Map<String, dynamic>;
        _cachedTxMap = txMap;
      }

      // 1) /api/v1/accounts?type=asset
      if (uri.path.endsWith('/accounts')) {
        final Map<String, Map<String, dynamic>> accountsById =
            <String, Map<String, dynamic>>{};

        for (final dynamic item in txMap.values) {
          if (item is! Map<String, dynamic>) continue;
          final dynamic attrs = item['attributes'];
          if (attrs is! Map<String, dynamic>) continue;
          final dynamic txs = attrs['transactions'];
          if (txs is! List || txs.isEmpty) continue;

          for (final dynamic tx in txs) {
            if (tx is! Map<String, dynamic>) continue;
            final String? srcId = tx['source_id']?.toString();
            final String? srcName = tx['source_name']?.toString();
            final String? srcType = tx['source_type']?.toString();
            final String? srcBal = tx['source_balance_after']?.toString();

            if (srcId != null &&
                srcName != null &&
                (srcType == 'Asset account' || srcType == 'asset')) {
              accountsById.putIfAbsent(
                srcId,
                () => <String, dynamic>{
                  'type': 'accounts',
                  'id': srcId,
                  'attributes': <String, dynamic>{
                    'name': srcName,
                    'type': 'asset',
                    'current_balance': srcBal ?? '0.00',
                    'active': true,
                    'account_role': 'defaultAsset',
                  },
                },
              );
            }

            final String? destId = tx['destination_id']?.toString();
            final String? destName = tx['destination_name']?.toString();
            final String? destType = tx['destination_type']?.toString();
            final String? destBal = tx['destination_balance_after']?.toString();

            if (destId != null &&
                destName != null &&
                (destType == 'Asset account' || destType == 'asset')) {
              accountsById.putIfAbsent(
                destId,
                () => <String, dynamic>{
                  'type': 'accounts',
                  'id': destId,
                  'attributes': <String, dynamic>{
                    'name': destName,
                    'type': 'asset',
                    'current_balance': destBal ?? '0.00',
                    'active': true,
                    'account_role': 'defaultAsset',
                  },
                },
              );
            }
          }
        }

        if (accountsById.isNotEmpty) {
          final Map<String, dynamic> response = <String, dynamic>{
            'data': accountsById.values.toList(),
            'meta': <String, dynamic>{
              'pagination': <String, dynamic>{
                'total': accountsById.length,
                'count': accountsById.length,
                'per_page': 50,
                'current_page': 1,
                'total_pages': 1,
              },
            },
          };
          return CachedHttpResponse(
            url: rawUrl,
            statusCode: 200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(response),
          );
        }
      }

      // 2) /api/v1/insight/income/total OR /api/v1/insight/expense/total
      if (uri.path.contains('/insight/income/total') ||
          uri.path.contains('/insight/expense/total')) {
        final bool isExpense = uri.path.contains('expense');
        final String? startStr = uri.queryParameters['start'];
        final String? endStr = uri.queryParameters['end'];
        final DateTime? start = startStr != null
            ? DateTime.tryParse(startStr)
            : null;
        final DateTime? end = endStr != null ? DateTime.tryParse(endStr) : null;

        double sum = 0;
        for (final dynamic item in txMap.values) {
          if (item is! Map<String, dynamic>) continue;
          final dynamic attrs = item['attributes'];
          if (attrs is! Map<String, dynamic>) continue;
          final dynamic txs = attrs['transactions'];
          if (txs is! List) continue;

          for (final dynamic tx in txs) {
            if (tx is! Map<String, dynamic>) continue;
            final String? type = tx['type']?.toString();
            final String? dateStr = tx['date']?.toString();
            final DateTime? dt = dateStr != null
                ? DateTime.tryParse(dateStr)
                : null;
            if (dt == null) continue;

            if (start != null && dt.isBefore(start)) continue;
            if (end != null && dt.isAfter(end.add(const Duration(days: 1)))) {
              continue;
            }

            final double amt =
                double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
            if (isExpense && (type == 'withdrawal' || type == 'expense')) {
              sum += amt;
            } else if (!isExpense &&
                (type == 'deposit' || type == 'revenue' || type == 'income')) {
              sum += amt;
            }
          }
        }

        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'name': 'EUR',
            'difference_float': isExpense ? -sum : sum,
            'currency_id': '1',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'currency_decimal_places': 2,
          },
        ];
        return CachedHttpResponse(
          url: rawUrl,
          statusCode: 200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(list),
        );
      }

      // 3) /api/v1/insight/expense/category
      if (uri.path.contains('/insight/expense/category')) {
        final String? startStr = uri.queryParameters['start'];
        final String? endStr = uri.queryParameters['end'];
        final DateTime? start = startStr != null
            ? DateTime.tryParse(startStr)
            : null;
        final DateTime? end = endStr != null ? DateTime.tryParse(endStr) : null;

        final Map<String, double> catSums = <String, double>{};
        for (final dynamic item in txMap.values) {
          if (item is! Map<String, dynamic>) continue;
          final dynamic attrs = item['attributes'];
          if (attrs is! Map<String, dynamic>) continue;
          final dynamic txs = attrs['transactions'];
          if (txs is! List) continue;

          for (final dynamic tx in txs) {
            if (tx is! Map<String, dynamic>) continue;
            final String? type = tx['type']?.toString();
            if (type != 'withdrawal' && type != 'expense') continue;

            final String? dateStr = tx['date']?.toString();
            final DateTime? dt = dateStr != null
                ? DateTime.tryParse(dateStr)
                : null;
            if (dt == null) continue;

            if (start != null && dt.isBefore(start)) continue;
            if (end != null && dt.isAfter(end.add(const Duration(days: 1)))) {
              continue;
            }

            final String catName =
                tx['category_name']?.toString() ?? 'Sin categoría';
            final double amt =
                double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
            catSums[catName] = (catSums[catName] ?? 0) + amt;
          }
        }

        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
        catSums.forEach((String name, double amount) {
          list.add(<String, dynamic>{
            'id': name.hashCode.toString(),
            'name': name,
            'difference_float': -amount,
            'currency_id': '1',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'currency_decimal_places': 2,
          });
        });

        return CachedHttpResponse(
          url: rawUrl,
          statusCode: 200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(list),
        );
      }

      // 4) /api/v1/piggy-banks
      if (uri.path.contains('/piggy-banks')) {
        final Map<String, dynamic> response = <String, dynamic>{
          'data': <dynamic>[],
          'meta': <String, dynamic>{
            'pagination': <String, dynamic>{
              'total': 0,
              'count': 0,
              'per_page': 50,
              'current_page': 1,
              'total_pages': 1,
            },
          },
        };
        return CachedHttpResponse(
          url: rawUrl,
          statusCode: 200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(response),
        );
      }
    } catch (e) {
      _log.warning("Failed to synthesize offline fallback for $rawUrl: $e");
    }
    return null;
  }
}

/// A transparent HTTP client wrapper that caches successful GET responses
/// to disk and returns cached responses when network is down or offline.
class OfflineCachingClient extends http.BaseClient {
  final http.Client _inner;
  OfflineCachingClient(this._inner);

  static bool _knownOffline = false;
  static DateTime? _lastOfflineCheck;
  static const Duration _offlineGracePeriod = Duration(seconds: 20);
  static const Duration _networkTimeout = Duration(seconds: 20);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') {
      return _inner.send(request);
    }

    final String url = request.url.toString();

    // Fast-path: if we recently detected offline and grace period is active,
    // immediately check cache to avoid blocking UI with connection timeouts.
    if (_knownOffline &&
        _lastOfflineCheck != null &&
        DateTime.now().difference(_lastOfflineCheck!) < _offlineGracePeriod) {
      final CachedHttpResponse? cached = await OfflineCache.instance
          .getHttpResponse(url);
      if (cached != null) {
        return cached.toStreamedResponse(request);
      }
    }

    try {
      final http.StreamedResponse response = await _inner
          .send(request)
          .timeout(_networkTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _knownOffline = false;
        final List<int> bytes = await response.stream.toBytes();
        final String body = utf8.decode(bytes);
        unawaited(
          OfflineCache.instance.saveHttpResponse(
            url,
            response.statusCode,
            response.headers,
            body,
          ),
        );
        return http.StreamedResponse(
          Stream<List<int>>.value(bytes),
          response.statusCode,
          contentLength: bytes.length,
          request: request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }

      // If server error 5xx or server unreachable code, check cache
      if (response.statusCode >= 500) {
        final CachedHttpResponse? cached = await OfflineCache.instance
            .getHttpResponse(url);
        if (cached != null) {
          _log.info(
            "Serving cached response (server status ${response.statusCode}) for $url",
          );
          return cached.toStreamedResponse(request);
        }
      }

      return response;
    } catch (e) {
      _knownOffline = true;
      _lastOfflineCheck = DateTime.now();
      _log.info(
        "Network exception/timeout for $url ($e), attempting offline cache lookup",
      );
      final CachedHttpResponse? cached = await OfflineCache.instance
          .getHttpResponse(url);
      if (cached != null) {
        _log.info("Offline cache hit for $url");
        return cached.toStreamedResponse(request);
      }
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }
}
