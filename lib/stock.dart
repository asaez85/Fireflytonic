import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stock/stock.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.enums.swagger.dart'
    as enums
    show TransactionTypeFilter;
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

final Logger log = Logger("Stock");

class PersistentSourceOfTruth<K, V> implements SourceOfTruth<K, V> {
  final String namespace;
  final V Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(V value) toJson;
  final K Function(String keyStr)? stringToKey;

  final CachedSourceOfTruth<K, V> _inner = CachedSourceOfTruth<K, V>();
  final Map<String, V> _diskMap = <String, V>{};

  File? _file;
  Timer? _saveDebounce;
  late final Future<void> _initFuture;

  PersistentSourceOfTruth({
    required this.namespace,
    required this.fromJson,
    required this.toJson,
    this.stringToKey,
  }) {
    _initFuture = _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final Directory cacheDir = Directory('${dir.path}/stock_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _file = File('${cacheDir.path}/$namespace.json');
      if (await _file!.exists()) {
        final String text = await _file!.readAsString();
        if (text.isNotEmpty) {
          final Map<String, dynamic> jsonMap =
              jsonDecode(text) as Map<String, dynamic>;
          for (final MapEntry<String, dynamic> entry in jsonMap.entries) {
            try {
              final V val = fromJson(entry.value as Map<String, dynamic>);
              _diskMap[entry.key] = val;
              final K key = stringToKey != null
                  ? stringToKey!(entry.key)
                  : entry.key as K;
              await _inner.write(key, val);
            } catch (e) {
              log.fine(
                "Failed to parse cached entry $namespace/${entry.key}: $e",
              );
            }
          }
        }
      }
    } catch (e) {
      log.warning("Failed to load disk cache for $namespace: $e");
    }
  }

  Future<void> _saveToDisk() async {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        if (_file == null) {
          final Directory dir = await getApplicationSupportDirectory();
          final Directory cacheDir = Directory('${dir.path}/stock_cache');
          if (!await cacheDir.exists()) {
            await cacheDir.create(recursive: true);
          }
          _file = File('${cacheDir.path}/$namespace.json');
        }
        final Map<String, dynamic> jsonMap = <String, dynamic>{};
        _diskMap.forEach((String k, V v) {
          try {
            jsonMap[k] = toJson(v);
          } catch (_) {}
        });
        await _file!.writeAsString(jsonEncode(jsonMap));
      } catch (e) {
        log.warning("Failed to save disk cache for $namespace: $e");
      }
    });
  }

  @override
  Stream<V?> reader(K key) async* {
    await _initFuture;
    yield* _inner.reader(key);
  }

  @override
  Future<void> write(K key, V? value) async {
    await _initFuture;
    final String keyStr = key is DateTime
        ? key.toIso8601String()
        : key.toString();
    if (value == null) {
      _diskMap.remove(keyStr);
    } else {
      _diskMap[keyStr] = value;
    }
    await _inner.write(key, value);
    unawaited(_saveToDisk());
  }

  @override
  Future<void> delete(K key) async {
    final String keyStr = key is DateTime
        ? key.toIso8601String()
        : key.toString();
    _diskMap.remove(keyStr);
    await _inner.delete(key);
    unawaited(_saveToDisk());
  }

  @override
  Future<void> deleteAll() async {
    _diskMap.clear();
    await _inner.deleteAll();
    if (_file != null && await _file!.exists()) {
      try {
        await _file!.delete();
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    await deleteAll();
  }
}

class TransStockRead {
  final List<TransactionRead> data;
  final Meta$Pagination? pagination;

  TransStockRead(this.data, this.pagination);
}

class TransStockList {
  final List<String> identifiers;
  final Meta$Pagination? pagination;

  TransStockList(this.identifiers, this.pagination);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identifiers': identifiers,
    'pagination': pagination?.toJson(),
  };

  factory TransStockList.fromJson(Map<String, dynamic> json) => TransStockList(
    (json['identifiers'] as List<dynamic>).cast<String>(),
    json['pagination'] != null
        ? Meta$Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
        : null,
  );
}

class TransStock with ChangeNotifier {
  final FireflyIii api;

  late Stock<String, TransactionRead> _singleStock;

  late Stock<String, TransStockList> _getStock;
  late Stock<String, TransStockList> _getAccountStock;
  late Stock<String, TransStockList> _getSearchStock;

  final PersistentSourceOfTruth<String, TransactionRead> _singleSoT =
      PersistentSourceOfTruth<String, TransactionRead>(
        namespace: 'transactions_single',
        fromJson: (Map<String, dynamic> json) => TransactionRead.fromJson(json),
        toJson: (TransactionRead value) => value.toJson(),
      );
  final PersistentSourceOfTruth<String, TransStockList> _listSoT =
      PersistentSourceOfTruth<String, TransStockList>(
        namespace: 'transactions_list',
        fromJson: (Map<String, dynamic> json) => TransStockList.fromJson(json),
        toJson: (TransStockList value) => value.toJson(),
      );

  TransStock(this.api) {
    _singleStock = Stock<String, TransactionRead>(
      fetcher: Fetcher.ofFuture<String, TransactionRead>(
        (String id) => api
            .v1TransactionsIdGet(id: id)
            .then((Response<TransactionSingle> value) => value.body!.data),
      ),
      sourceOfTruth: _singleSoT,
    );
    _getStock = Stock<String, TransStockList>(
      fetcher: Fetcher.ofFuture<String, TransStockList>((String id) {
        final _getOptions query = .fromJson(jsonDecode(id));
        return api
            .v1TransactionsGet(
              xTraceId: query.xTraceId,
              page: query.page,
              limit: query.limit,
              start: query.start,
              end: query.end,
              type: query.type,
            )
            .then<TransStockList>(_onAPIValue);
      }),
      sourceOfTruth: _listSoT,
    );
    _getAccountStock = Stock<String, TransStockList>(
      fetcher: Fetcher.ofFuture<String, TransStockList>((String id) {
        final _getOptions query = .fromJson(jsonDecode(id));
        return api
            .v1AccountsIdTransactionsGet(
              xTraceId: query.xTraceId,
              id: query.id,
              page: query.page,
              limit: query.limit,
              start: query.start,
              end: query.end,
              type: query.type,
            )
            .then<TransStockList>(_onAPIValue);
      }),
      sourceOfTruth: _listSoT,
    );
    _getSearchStock = Stock<String, TransStockList>(
      fetcher: Fetcher.ofFuture<String, TransStockList>((String id) {
        final _getOptions query = .fromJson(jsonDecode(id));
        return api
            .v1SearchTransactionsGet(
              xTraceId: query.xTraceId,
              query: query.query,
              page: query.page,
              limit: query.limit,
            )
            .then<TransStockList>(_onAPIValue);
      }),
      sourceOfTruth: _listSoT,
    );
  }

  Future<TransStockList> _onAPIValue(
    Response<TransactionArray> response,
  ) async {
    if (!response.isSuccessful || response.body == null) {
      if (response.error != null && response.error.toString().isNotEmpty) {
        throw Exception("_onAPIValue() call not successful: ${response.error}");
      } else {
        throw Exception("_onAPIValue() call not successful: empty body/error");
      }
    }
    await Future.wait(
      response.body!.data.map(
        (TransactionRead element) => _singleSoT.write(element.id, element),
      ),
    );
    return TransStockList(
      response.body!.data.map((TransactionRead e) => e.id).toList(),
      response.body!.meta.pagination,
    );
  }

  Future<TransStockRead> get({
    String? xTraceId,
    int? page,
    int? limit,
    String? start,
    String? end,
    enums.TransactionTypeFilter? type,
  }) async {
    final String key = jsonEncode(
      _getOptions(
        xTraceId: xTraceId,
        page: page,
        limit: limit,
        start: start,
        end: end,
        type: type,
      ),
    );
    try {
      final TransStockList list = await _getStock.get(key);
      return await _onGetValue(list);
    } catch (e) {
      log.warning("Offline fallback for get(): $e");
      final TransStockList? cachedList = await _listSoT.reader(key).first;
      if (cachedList != null) {
        return _onGetValue(cachedList);
      }
      rethrow;
    }
  }

  Future<TransStockRead> getAccount({
    String? xTraceId,
    required String id,
    int? page,
    int? limit,
    String? start,
    String? end,
    enums.TransactionTypeFilter? type,
  }) async {
    final String key = jsonEncode(
      _getOptions(
        xTraceId: xTraceId,
        id: id,
        page: page,
        limit: limit,
        start: start,
        end: end,
        type: type,
      ),
    );
    try {
      final TransStockList list = await _getAccountStock.get(key);
      return await _onGetValue(list);
    } catch (e) {
      log.warning("Offline fallback for getAccount(): $e");
      final TransStockList? cachedList = await _listSoT.reader(key).first;
      if (cachedList != null) {
        return _onGetValue(cachedList);
      }
      rethrow;
    }
  }

  Future<TransStockRead> getSearch({
    String? xTraceId,
    required String? query,
    int? page,
    int? limit,
  }) async {
    final String key = jsonEncode(
      _getOptions(xTraceId: xTraceId, query: query, page: page, limit: limit),
    );
    try {
      final TransStockList list = await _getSearchStock.get(key);
      return await _onGetValue(list);
    } catch (e) {
      log.warning("Offline fallback for getSearch(): $e");
      final TransStockList? cachedList = await _listSoT.reader(key).first;
      if (cachedList != null) {
        return _onGetValue(cachedList);
      }
      rethrow;
    }
  }

  Future<TransStockRead> _onGetValue(TransStockList list) async {
    final List<TransactionRead?> items = await Future.wait(
      list.identifiers.map((String element) async {
        try {
          return await _singleStock.get(element);
        } catch (e) {
          try {
            final TransactionRead? cached = await _singleSoT
                .reader(element)
                .first;
            if (cached != null) return cached;
          } catch (_) {}
          log.warning("Could not load transaction $element: $e");
          return null;
        }
      }),
    );

    final List<TransactionRead> result = items.nonNulls.toList();
    if (result.isEmpty && list.identifiers.isNotEmpty) {
      throw Exception("Failed to load transactions for list");
    }
    return TransStockRead(result, list.pagination);
  }

  void clear({bool notify = true}) {
    _getStock.clearAll();
    _getAccountStock.clearAll();
    _getSearchStock.clearAll();
    _singleSoT.clear();
    _listSoT.clear();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setTransaction(TransactionRead transaction) async {
    final TransactionRead? oldTransaction = await _singleSoT
        .reader(transaction.id)
        .first;
    // if no old transaction (= new one) or date has changed, clear cache
    if (oldTransaction == null ||
        oldTransaction.attributes.transactions.first.date !=
            transaction.attributes.transactions.first.date) {
      clear();
    }

    return _singleSoT.write(transaction.id, transaction);
  }
}

// ignore: camel_case_types
class _getOptions {
  final String? xTraceId; // get, getAccount, getSearch
  final int? page; // get, getAccount, getSearch
  final String? start; // get, getAccount
  final String? end; // get, getAccount
  final enums.TransactionTypeFilter? type; // get, getAccount
  final String? id; // getAccount
  final int? limit; // get, getAccount, getSearch
  final String? query; // getSearch

  _getOptions({
    this.xTraceId,
    this.page,
    this.start,
    this.end,
    this.type,
    this.id,
    this.limit,
    this.query,
  });

  _getOptions.fromJson(Map<String, dynamic> json)
    : xTraceId = json['xTraceId'],
      page = json['page'],
      start = json['start'],
      end = json['end'],
      type = enums.TransactionTypeFilter.values.firstWhereOrNull(
        (enums.TransactionTypeFilter e) => e.name == json['type'],
      ),
      id = json['id'],
      limit = json['limit'],
      query = json['query'];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'xTraceId': xTraceId,
    'page': page,
    'start': start,
    'end': end,
    'type': type?.name,
    'id': id,
    'limit': limit,
    'query': query,
  };
}

class CatStock {
  final FireflyIii api;
  final CurrencyRead defaultCurrency;

  late Stock<DateTime, CategoryArray> _stock;
  final PersistentSourceOfTruth<DateTime, CategoryArray> _sot =
      PersistentSourceOfTruth<DateTime, CategoryArray>(
        namespace: 'categories_insights',
        stringToKey: (String keyStr) => DateTime.parse(keyStr),
        fromJson: (Map<String, dynamic> json) => CategoryArray.fromJson(json),
        toJson: (CategoryArray value) => value.toJson(),
      );

  CatStock(this.api, this.defaultCurrency) {
    _stock = Stock<DateTime, CategoryArray>(
      fetcher: Fetcher.ofFuture<DateTime, CategoryArray>((DateTime t) async {
        final String startDate = DateFormat(
          'yyyy-MM-dd',
          'en_US',
        ).format(t.copyWith(day: 1));
        final String endDate = DateFormat('yyyy-MM-dd', 'en_US').format(t);

        final Response<InsightGroup> respIncomeCat = await api
            .v1InsightIncomeCategoryGet(start: startDate, end: endDate);
        if (!respIncomeCat.isSuccessful || respIncomeCat.body == null) {
          throw Exception(
            "[stock] Invalid v1InsightIncomeCategoryGet response: ${respIncomeCat.error}",
          );
        }
        final Response<InsightTotal> respIncomeNoCat = await api
            .v1InsightIncomeNoCategoryGet(start: startDate, end: endDate);
        if (!respIncomeNoCat.isSuccessful || respIncomeNoCat.body == null) {
          throw Exception(
            "[stock] Invalid v1InsightIncomeNoCategoryGet response: ${respIncomeNoCat.error}",
          );
        }
        final Response<InsightGroup> respExpenseCat = await api
            .v1InsightExpenseCategoryGet(start: startDate, end: endDate);
        if (!respExpenseCat.isSuccessful || respExpenseCat.body == null) {
          throw Exception(
            "[stock] Invalid v1InsightExpenseCategoryGet response: ${respExpenseCat.error}",
          );
        }
        final Response<InsightTotal> respExpenseNoCat = await api
            .v1InsightExpenseNoCategoryGet(start: startDate, end: endDate);
        if (!respExpenseNoCat.isSuccessful || respExpenseNoCat.body == null) {
          throw Exception(
            "[stock] Invalid v1InsightExpenseNoCategoryGet response: ${respExpenseNoCat.error}",
          );
        }

        final Map<String, CategoryRead> categories = <String, CategoryRead>{};
        for (InsightGroupEntry cat in respIncomeCat.body!) {
          if ((cat.id?.isEmpty ?? true) || (cat.name?.isEmpty ?? true)) {
            continue;
          }

          if (cat.currencyId != defaultCurrency.id) {
            continue;
          }
          if (!categories.containsKey(cat.id)) {
            categories[cat.id!] = CategoryRead(
              id: cat.id!,
              type: "categories",
              attributes: CategoryWithSum(
                name: cat.name!,
                spent: <ArrayEntryWithCurrencyAndSum>[],
                earned: <ArrayEntryWithCurrencyAndSum>[],
              ),
            );
          }
          categories[cat.id!]!.attributes.earned!.add(
            ArrayEntryWithCurrencyAndSum(
              currencyId: cat.currencyId,
              currencyCode: cat.currencyCode,
              currencyDecimalPlaces: defaultCurrency.attributes.decimalPlaces,
              currencySymbol: defaultCurrency.attributes.symbol,
              sum: cat.difference,
            ),
          );
        }
        for (InsightGroupEntry cat in respExpenseCat.body!) {
          if ((cat.id?.isEmpty ?? true) || (cat.name?.isEmpty ?? true)) {
            continue;
          }

          if (cat.currencyId != defaultCurrency.id) {
            continue;
          }
          if (!categories.containsKey(cat.id)) {
            categories[cat.id!] = CategoryRead(
              id: cat.id!,
              type: "categories",
              attributes: CategoryWithSum(
                name: cat.name!,
                spent: <ArrayEntryWithCurrencyAndSum>[],
                earned: <ArrayEntryWithCurrencyAndSum>[],
              ),
            );
          }
          categories[cat.id!]!.attributes.spent!.add(
            ArrayEntryWithCurrencyAndSum(
              currencyId: cat.currencyId,
              currencyCode: cat.currencyCode,
              currencyDecimalPlaces: defaultCurrency.attributes.decimalPlaces,
              currencySymbol: defaultCurrency.attributes.symbol,
              sum: cat.difference,
            ),
          );
        }
        for (InsightTotalEntry cat in respIncomeNoCat.body!) {
          if (cat.currencyId != defaultCurrency.id) {
            continue;
          }
          if (!categories.containsKey("-1")) {
            categories["-1"] = CategoryRead(
              id: "-1",
              type: "no-category",
              attributes: CategoryWithSum(
                name: "L10NNONE",
                spent: <ArrayEntryWithCurrencyAndSum>[],
                earned: <ArrayEntryWithCurrencyAndSum>[],
              ),
            );
          }
          categories["-1"]!.attributes.earned!.add(
            ArrayEntryWithCurrencyAndSum(
              currencyId: cat.currencyId,
              currencyCode: cat.currencyCode,
              currencyDecimalPlaces: defaultCurrency.attributes.decimalPlaces,
              currencySymbol: defaultCurrency.attributes.symbol,
              sum: cat.difference,
            ),
          );
        }
        for (InsightTotalEntry cat in respExpenseNoCat.body!) {
          if (cat.currencyId != defaultCurrency.id) {
            continue;
          }
          if (!categories.containsKey("-1")) {
            categories["-1"] = CategoryRead(
              id: "-1",
              type: "no-category",
              attributes: CategoryWithSum(
                name: "L10NNONE",
                spent: <ArrayEntryWithCurrencyAndSum>[],
                earned: <ArrayEntryWithCurrencyAndSum>[],
              ),
            );
          }
          categories["-1"]!.attributes.spent!.add(
            ArrayEntryWithCurrencyAndSum(
              currencyId: cat.currencyId,
              currencyCode: cat.currencyCode,
              currencyDecimalPlaces: defaultCurrency.attributes.decimalPlaces,
              currencySymbol: defaultCurrency.attributes.symbol,
              sum: cat.difference,
            ),
          );
        }

        categories.forEach((_, CategoryRead c) {
          final CategoryWithSum cs = c.attributes as CategoryWithSum;
          cs.sumEarned = c.attributes.earned!.fold<double>(
            0,
            (double p, ArrayEntryWithCurrencyAndSum e) =>
                p += double.parse(e.sum ?? "0"),
          );
          cs.sumSpent = c.attributes.spent!.fold<double>(
            0,
            (double p, ArrayEntryWithCurrencyAndSum e) =>
                p += double.parse(e.sum ?? "0"),
          );
        });

        return CategoryArray(
          data: categories.values.toList(growable: false),
          meta: const Meta(),
        );
      }),
      sourceOfTruth: _sot,
    );
  }

  Future<CategoryArray> get(DateTime t) async {
    try {
      return await _stock.get(t);
    } catch (e) {
      log.warning("Offline fallback for CatStock.get(): $e");
      final CategoryArray? cached = await _sot.reader(t).first;
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<void> reset() async {
    await _stock.clearAll();
    await _sot.clear();
  }
}
