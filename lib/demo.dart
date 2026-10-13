import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:http/http.dart' as http;

import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

/// Modo demo: una implementación falsa de [FireflyIii] que devuelve datos
/// inventados, para poder desarrollar y previsualizar la interfaz sin un
/// servidor Firefly III accesible.
///
/// Solo se implementan los endpoints que usan las pantallas Inicio,
/// Movimientos, Análisis y Huchas. El resto cae en [noSuchMethod] y devuelve
/// una respuesta vacía.
class DemoFireflyIii implements FireflyIii {
  static Response<T> _ok<T>(T body) =>
      Response<T>(http.Response('', 200), body);

  static String _d(int daysAgo) => DateTime.now()
      .toUtc()
      .subtract(Duration(days: daysAgo))
      .toIso8601String();

  Map<String, dynamic> _split({
    required String type,
    required String desc,
    required String amount,
    required int daysAgo,
    String? category,
    String source = 'Cuenta corriente',
    String destination = 'Comercio',
    List<String> tags = const <String>[],
  }) => <String, dynamic>{
    'transaction_journal_id': '${desc.hashCode}',
    'type': type,
    'date': _d(daysAgo),
    'currency_id': '1',
    'currency_code': 'EUR',
    'currency_symbol': '€',
    'currency_name': 'Euro',
    'currency_decimal_places': 2,
    'amount': amount,
    'description': desc,
    'source_id': '10',
    'source_name': source,
    'source_type': type == 'deposit' ? 'Revenue account' : 'Asset account',
    'destination_id': '20',
    'destination_name': destination,
    'destination_type': type == 'deposit' ? 'Asset account' : 'Expense account',
    'category_name': category,
    'tags': tags,
    'reconciled': false,
    'has_attachments': false,
  };

  Map<String, dynamic> _tx(String id, Map<String, dynamic> split) =>
      <String, dynamic>{
        'type': 'transactions',
        'id': id,
        'attributes': <String, dynamic>{
          'created_at': _d(0),
          'updated_at': _d(0),
          'group_title': null,
          'transactions': <Map<String, dynamic>>[split],
        },
        'links': <String, dynamic>{'self': 'https://demo.local/tx/$id'},
      };

  List<Map<String, dynamic>> get _txData => <Map<String, dynamic>>[
    _tx(
      '1',
      _split(
        type: 'withdrawal',
        desc: 'Mercadona',
        amount: '41.21',
        daysAgo: 0,
        category: 'Supermercado',
        destination: 'Mercadona',
      ),
    ),
    _tx(
      '2',
      _split(
        type: 'withdrawal',
        desc: 'Continental Café',
        amount: '3.30',
        daysAgo: 1,
        category: 'Restaurante',
        destination: 'Continental Café',
      ),
    ),
    _tx(
      '3',
      _split(
        type: 'deposit',
        desc: 'Nómina',
        amount: '1850.00',
        daysAgo: 2,
        category: 'Salario',
        source: 'Mi Empresa S.L.',
      ),
    ),
    _tx(
      '4',
      _split(
        type: 'withdrawal',
        desc: 'Adeudo PayPal',
        amount: '99.00',
        daysAgo: 3,
        category: 'Electrónica',
        destination: 'PayPal Europe',
        tags: <String>['suscripción'],
      ),
    ),
    _tx(
      '5',
      _split(
        type: 'withdrawal',
        desc: 'Gasolinera Repsol',
        amount: '64.00',
        daysAgo: 4,
        category: 'Gasolina',
        destination: 'Repsol',
      ),
    ),
    _tx(
      '6',
      _split(
        type: 'withdrawal',
        desc: 'Factura móvil',
        amount: '12.90',
        daysAgo: 5,
        category: 'Móvil',
        destination: 'Operadora',
      ),
    ),
    _tx(
      '7',
      _split(
        type: 'withdrawal',
        desc: 'Cena con amigos',
        amount: '38.50',
        daysAgo: 6,
        category: 'Restaurante',
        destination: 'Bar Pepe',
        tags: <String>['dividido'],
      ),
    ),
    _tx(
      '8',
      _split(
        type: 'deposit',
        desc: 'Devolución',
        amount: '15.40',
        daysAgo: 7,
        category: 'Otros',
        source: 'Amazon',
      ),
    ),
    _tx(
      '9',
      _split(
        type: 'withdrawal',
        desc: 'La Tagliatella',
        amount: '52.00',
        daysAgo: 40,
        category: 'Restaurante',
        destination: 'La Tagliatella',
      ),
    ),
    _tx(
      '10',
      _split(
        type: 'withdrawal',
        desc: 'Mercadona',
        amount: '63.10',
        daysAgo: 38,
        category: 'Supermercado',
        destination: 'Mercadona',
      ),
    ),
  ];

  Map<String, dynamic> get _txArray => <String, dynamic>{
    'data': _txData,
    'links': <String, dynamic>{},
    'meta': <String, dynamic>{
      'pagination': <String, dynamic>{
        'total': _txData.length,
        'count': _txData.length,
        'per_page': 50,
        'current_page': 1,
        'total_pages': 1,
      },
    },
  };

  Map<String, dynamic> _account(
    String id,
    String name,
    String type,
    String balance,
    String role,
  ) => <String, dynamic>{
    'type': 'accounts',
    'id': id,
    'attributes': <String, dynamic>{
      'name': name,
      'active': true,
      'type': type,
      'account_role': role,
      'current_balance': balance,
      'currency_id': '1',
      'currency_code': 'EUR',
      'currency_symbol': '€',
      'currency_decimal_places': 2,
    },
  };

  Map<String, dynamic> get _assetAccounts => <String, dynamic>{
    'data': <Map<String, dynamic>>[
      _account('1', 'Cuenta corriente', 'asset', '2540.18', 'defaultAsset'),
      _account('2', 'Ahorro', 'asset', '8200.00', 'savingAsset'),
      _account('3', 'Cartera de efectivo', 'asset', '85.50', 'cashWalletAsset'),
    ],
    'links': <String, dynamic>{},
    'meta': <String, dynamic>{
      'pagination': <String, dynamic>{
        'total': 3,
        'count': 3,
        'current_page': 1,
        'total_pages': 1,
      },
    },
  };

  Map<String, dynamic> get _emptyArray => <String, dynamic>{
    'data': <dynamic>[],
    'links': <String, dynamic>{},
    'meta': <String, dynamic>{
      'pagination': <String, dynamic>{
        'total': 0,
        'count': 0,
        'current_page': 1,
        'total_pages': 1,
      },
    },
  };

  List<Map<String, dynamic>> get _expenseCategories => <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'name': 'Supermercado',
      'difference_float': -312.40,
      'difference': '-312.40',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '2',
      'name': 'Restaurante',
      'difference_float': -188.20,
      'difference': '-188.20',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '3',
      'name': 'Electrónica',
      'difference_float': -99.00,
      'difference': '-99.00',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '4',
      'name': 'Gasolina',
      'difference_float': -128.00,
      'difference': '-128.00',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '5',
      'name': 'Móvil',
      'difference_float': -38.70,
      'difference': '-38.70',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '6',
      'name': 'Hogar',
      'difference_float': -210.00,
      'difference': '-210.00',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '7',
      'name': 'Ocio',
      'difference_float': -74.30,
      'difference': '-74.30',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
  ];

  List<Map<String, dynamic>> get _incomeCategories => <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '8',
      'name': 'Salario',
      'difference_float': 1850.00,
      'difference': '1850.00',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
    <String, dynamic>{
      'id': '9',
      'name': 'Otros',
      'difference_float': 15.40,
      'difference': '15.40',
      'currency_id': '1',
      'currency_code': 'EUR',
    },
  ];

  List<Map<String, dynamic>> _total(double v) => <Map<String, dynamic>>[
    <String, dynamic>{
      'difference_float': v,
      'difference': v.toString(),
      'currency_id': '1',
      'currency_code': 'EUR',
    },
  ];

  // ---- Endpoints usados por las pantallas ----

  @override
  Future<Response<TransactionArray>> v1TransactionsGet({
    String? xTraceId,
    int? page,
    String? start,
    String? end,
    TransactionTypeFilter? type,
    int? limit,
  }) async {
    Map<String, dynamic> arr = _txArray;
    if (type == TransactionTypeFilter.withdrawal) {
      arr = _filterByType('withdrawal');
    } else if (type == TransactionTypeFilter.deposit) {
      arr = _filterByType('deposit');
    }
    return _ok(TransactionArray.fromJson(arr));
  }

  Map<String, dynamic> _arrayOf(List<Map<String, dynamic>> data) =>
      <String, dynamic>{
        'data': data,
        'links': <String, dynamic>{},
        'meta': <String, dynamic>{
          'pagination': <String, dynamic>{
            'total': data.length,
            'count': data.length,
            'per_page': 50,
            'current_page': 1,
            'total_pages': 1,
          },
        },
      };

  String _splitField(Map<String, dynamic> tx, String key) =>
      (((tx['attributes'] as Map<String, dynamic>)['transactions']
                      as List<Map<String, dynamic>>)
                  .first[key] ??
              '')
          .toString();

  Map<String, dynamic> _filterByType(String t) => _arrayOf(
    _txData
        .where((Map<String, dynamic> e) => _splitField(e, 'type') == t)
        .toList(),
  );

  @override
  Future<Response<TransactionArray>> v1SearchTransactionsGet({
    String? xTraceId,
    int? page,
    int? limit,
    required String? query,
  }) async {
    final String q = query ?? '';
    final String? cat = RegExp(
      r'category_is:"([^"]+)"',
    ).firstMatch(q)?.group(1);
    final DateTime? after = DateTime.tryParse(
      RegExp(r'date_after:(\d{4}-\d{2}-\d{2})').firstMatch(q)?.group(1) ?? '',
    );
    final DateTime? before = DateTime.tryParse(
      RegExp(r'date_before:(\d{4}-\d{2}-\d{2})').firstMatch(q)?.group(1) ?? '',
    );

    final List<Map<String, dynamic>> data = _txData.where((
      Map<String, dynamic> e,
    ) {
      if (cat != null && _splitField(e, 'category_name') != cat) {
        return false;
      }
      final DateTime? d = DateTime.tryParse(_splitField(e, 'date'));
      if (d != null) {
        if (after != null && d.isBefore(after)) {
          return false;
        }
        if (before != null && d.isAfter(before.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();

    return _ok(TransactionArray.fromJson(_arrayOf(data)));
  }

  @override
  Future<Response<AccountArray>> v1AccountsGet({
    String? xTraceId,
    int? page,
    int? limit,
    String? start,
    String? end,
    String? date,
    AccountTypeFilter? type,
  }) async => _ok(
    AccountArray.fromJson(
      type == AccountTypeFilter.liabilities ? _emptyArray : _assetAccounts,
    ),
  );

  // ¿El rango 'start' corresponde al mes en curso?
  bool _isCurrentMonth(String? start) {
    final DateTime now = DateTime.now();
    final String cur = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return (start ?? '').startsWith(cur);
  }

  // Semilla estable [0..1) según el mes del rango, para variar los importes.
  double _monthSeed(String? start) {
    final List<String> p = (start ?? '').split('-');
    final int m = p.length > 1 ? (int.tryParse(p[1]) ?? 1) : 1;
    final int y = p.isNotEmpty ? (int.tryParse(p[0]) ?? 0) : 0;
    return (((m * 37 + y * 13) % 100)) / 100.0;
  }

  @override
  Future<Response<InsightTotal>> v1InsightIncomeTotalGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
  }) async {
    final double v = _isCurrentMonth(start)
        ? 1865.40
        : 1500 + _monthSeed(start) * 700;
    return _ok(_total(v).map(InsightTotalEntry.fromJson).toList());
  }

  @override
  Future<Response<InsightTotal>> v1InsightExpenseTotalGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
  }) async {
    final double v = _isCurrentMonth(start)
        ? -1050.60
        : -(850 + _monthSeed(start) * 650);
    return _ok(_total(v).map(InsightTotalEntry.fromJson).toList());
  }

  @override
  Future<Response<InsightGroup>> v1InsightExpenseCategoryGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
    List<int>? categories,
  }) async {
    // El mes en curso usa los importes base; los demás se escalan por mes.
    final double f = _isCurrentMonth(start) ? 1.0 : 0.55 + _monthSeed(start);
    final List<Map<String, dynamic>> list = _expenseCategories.map((
      Map<String, dynamic> m,
    ) {
      final Map<String, dynamic> mm = Map<String, dynamic>.of(m);
      final double base = mm['difference_float'] as double;
      final double v = double.parse((base * f).toStringAsFixed(2));
      mm['difference_float'] = v;
      mm['difference'] = v.toString();
      return mm;
    }).toList();
    return _ok(list.map(InsightGroupEntry.fromJson).toList());
  }

  @override
  Future<Response<InsightGroup>> v1InsightIncomeCategoryGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
    List<int>? categories,
  }) async => _ok(_incomeCategories.map(InsightGroupEntry.fromJson).toList());

  @override
  Future<Response<InsightTotal>> v1InsightIncomeNoCategoryGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
  }) async => _ok(<InsightTotalEntry>[]);

  @override
  Future<Response<InsightTotal>> v1InsightExpenseNoCategoryGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
  }) async => _ok(_total(-45.80).map(InsightTotalEntry.fromJson).toList());

  @override
  Future<Response<InsightGroup>> v1InsightExpenseTagGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
    List<int>? tags,
  }) async => _ok(<InsightGroupEntry>[]);

  @override
  Future<Response<InsightGroup>> v1InsightIncomeTagGet({
    String? xTraceId,
    required String? start,
    required String? end,
    List<int>? accounts,
    List<int>? tags,
  }) async => _ok(<InsightGroupEntry>[]);

  @override
  Future<Response<PiggyBankArray>> v1PiggyBanksGet({
    String? xTraceId,
    int? page,
    int? limit,
  }) async => _ok(PiggyBankArray.fromJson(_emptyArray));

  /// Cualquier otro endpoint devuelve una respuesta vacía sin romper.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Response<dynamic>>.value(
        Response<dynamic>(http.Response('', 200), null),
      );
}
