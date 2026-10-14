import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chopper/chopper.dart' show Response;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.enums.swagger.dart'
    as enums;

class CsvExportService {
  static const String csvDelimiter = ';';

  /// Obtiene la fecha de la transacción más antigua registrada en Firefly III.
  static Future<DateTime?> fetchOldestTransactionDate(FireflyIii api) async {
    try {
      final Response<TransactionArray> firstResp = await api.v1TransactionsGet(
        limit: 1,
        page: 1,
      );
      if (!firstResp.isSuccessful || firstResp.body == null) {
        return null;
      }

      final int totalPages = firstResp.body!.meta.pagination?.totalPages ?? 1;
      if (totalPages <= 1) {
        if (firstResp.body!.data.isNotEmpty &&
            firstResp.body!.data.first.attributes.transactions.isNotEmpty) {
          return firstResp.body!.data.first.attributes.transactions.first.date;
        }
        return null;
      }

      final Response<TransactionArray> lastResp = await api.v1TransactionsGet(
        limit: 1,
        page: totalPages,
      );
      if (lastResp.isSuccessful &&
          lastResp.body != null &&
          lastResp.body!.data.isNotEmpty &&
          lastResp.body!.data.first.attributes.transactions.isNotEmpty) {
        return lastResp.body!.data.first.attributes.transactions.first.date;
      }
    } catch (_) {
      // Silently ignore and return null for fallback
    }
    return null;
  }

  /// Descarga paginada de transacciones entre [startDate] y [endDate],
  /// filtrando opcionalmente por [selectedAccountIds].
  /// Emite progreso mediante [onProgress] (página actual, total páginas).
  static Future<List<TransactionSplit>> fetchTransactionsForExport({
    required FireflyIii api,
    required DateTime startDate,
    required DateTime endDate,
    required Set<String> selectedAccountIds,
    void Function(int currentProgress, int? totalProgress)? onProgress,
  }) async {
    final List<TransactionSplit> collectedSplits = <TransactionSplit>[];
    final String startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final String endStr = DateFormat('yyyy-MM-dd').format(endDate);

    int currentPage = 1;
    int totalPages = 1;

    do {
      final Response<TransactionArray> resp = await api.v1TransactionsGet(
        start: startStr,
        end: endStr,
        page: currentPage,
        limit: 100,
      );

      if (!resp.isSuccessful || resp.body == null) {
        break;
      }

      totalPages = resp.body!.meta.pagination?.totalPages ?? currentPage;
      if (onProgress != null) {
        onProgress(currentPage, totalPages);
      }

      for (final TransactionRead item in resp.body!.data) {
        for (final TransactionSplit split in item.attributes.transactions) {
          final bool matchesAccount =
              selectedAccountIds.isEmpty ||
              (split.sourceId != null &&
                  selectedAccountIds.contains(split.sourceId)) ||
              (split.destinationId != null &&
                  selectedAccountIds.contains(split.destinationId));

          if (matchesAccount) {
            collectedSplits.add(split);
          }
        }
      }

      currentPage++;
    } while (currentPage <= totalPages);

    return collectedSplits;
  }

  /// Genera el contenido CSV con cabeceras, codificación UTF-8 con BOM y separador ';'
  static String generateCsv({
    required List<TransactionSplit> splits,
    required Map<String, AccountRead> accountsMap,
    required Set<String> selectedAccountIds,
    String delimiter = csvDelimiter,
  }) {
    final StringBuffer buffer = StringBuffer();
    // UTF-8 BOM para compatibilidad con Excel
    buffer.write('\uFEFF');

    // Encabezados exactos según especificación
    final List<String> headers = <String>[
      'Fecha valor',
      'Fecha de operación',
      'Importe',
      'Moneda',
      'Concepto',
      'Entidad',
      'Nombre de producto',
      'Tipo de producto',
      'Tipo de movimiento',
      'Categoría',
      'Nota',
    ];
    buffer.writeln(
      headers.map((String h) => _escapeCsv(h, delimiter)).join(delimiter),
    );

    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final NumberFormat numberFormat = NumberFormat('0.00', 'es_ES');

    for (final TransactionSplit split in splits) {
      // 1. Fecha valor (interestDate ?? bookDate ?? date)
      final DateTime valueDate =
          split.interestDate ?? split.bookDate ?? split.date;
      final String valueDateStr = dateFormat.format(valueDate);

      // 2. Fecha de operación (date)
      final String opDateStr = dateFormat.format(split.date);

      // 3. Importe: Negativo en gastos, positivo en ingresos
      final double rawAmount = double.tryParse(split.amount) ?? 0.0;
      double finalAmount = rawAmount;
      if (split.type == enums.TransactionTypeProperty.withdrawal) {
        finalAmount = -rawAmount.abs();
      } else if (split.type == enums.TransactionTypeProperty.deposit) {
        finalAmount = rawAmount.abs();
      } else if (split.type == enums.TransactionTypeProperty.transfer) {
        if (split.sourceId != null &&
            selectedAccountIds.contains(split.sourceId) &&
            !(split.destinationId != null &&
                selectedAccountIds.contains(split.destinationId))) {
          finalAmount = -rawAmount.abs();
        } else if (split.destinationId != null &&
            selectedAccountIds.contains(split.destinationId) &&
            !(split.sourceId != null &&
                selectedAccountIds.contains(split.sourceId))) {
          finalAmount = rawAmount.abs();
        } else {
          finalAmount = -rawAmount.abs();
        }
      }
      final String amountStr = numberFormat.format(finalAmount);

      // 4. Moneda
      final String currency =
          split.currencyCode ?? split.currencySymbol ?? 'EUR';

      // 5. Concepto
      final String description = split.description;

      // 6. Entidad (deducida por algoritmo de BankLogoBadge)
      final String entity = _detectBankEntity(
        split,
        accountsMap,
        selectedAccountIds,
      );

      // 7. Nombre de producto (cuenta propia)
      final String productName = _getProductName(
        split,
        accountsMap,
        selectedAccountIds,
      );

      // 8. Tipo de producto (Cuenta o Tarjeta de crédito)
      final String productType = _getProductType(
        split,
        accountsMap,
        selectedAccountIds,
      );

      // 9. Tipo de movimiento
      final String movementType = _getMovementType(split.type);

      // 10. Categoría
      final String category = split.categoryName ?? '';

      // 11. Nota
      final String note = split.notes ?? '';

      final List<String> row = <String>[
        valueDateStr,
        opDateStr,
        amountStr,
        currency,
        description,
        entity,
        productName,
        productType,
        movementType,
        category,
        note,
      ];

      buffer.writeln(
        row.map((String cell) => _escapeCsv(cell, delimiter)).join(delimiter),
      );
    }

    return buffer.toString();
  }

  static String _detectBankEntity(
    TransactionSplit split,
    Map<String, AccountRead> accountsMap,
    Set<String> selectedAccountIds,
  ) {
    AccountRead? ownAccount;
    if (split.sourceId != null && accountsMap.containsKey(split.sourceId)) {
      ownAccount = accountsMap[split.sourceId];
    } else if (split.destinationId != null &&
        accountsMap.containsKey(split.destinationId)) {
      ownAccount = accountsMap[split.destinationId];
    }

    final String name =
        ownAccount?.attributes.name ??
        split.sourceName ??
        split.destinationName ??
        '';
    final String? iban =
        ownAccount?.attributes.iban ??
        split.sourceIban ??
        split.destinationIban;
    final String combined =
        '${name.toLowerCase()} ${iban?.toLowerCase() ?? ''}';

    if (combined.contains('bbva')) return 'BBVA';
    if (combined.contains('santander')) return 'Santander';
    if (combined.contains('caixa') || combined.contains('imagin')) {
      return 'CaixaBank';
    }
    if (combined.contains('ing')) return 'ING';
    if (combined.contains('sabadell')) return 'Banco Sabadell';
    if (combined.contains('openbank')) return 'Openbank';
    if (combined.contains('revolut')) return 'Revolut';
    if (combined.contains('bankinter')) return 'Bankinter';

    return name.isNotEmpty ? name : 'Entidad';
  }

  static String _getProductName(
    TransactionSplit split,
    Map<String, AccountRead> accountsMap,
    Set<String> selectedAccountIds,
  ) {
    if (split.type == enums.TransactionTypeProperty.withdrawal) {
      return split.sourceName ?? '';
    } else if (split.type == enums.TransactionTypeProperty.deposit) {
      return split.destinationName ?? '';
    } else if (split.type == enums.TransactionTypeProperty.transfer) {
      if (split.sourceId != null &&
          selectedAccountIds.contains(split.sourceId)) {
        return split.sourceName ?? '';
      }
      return split.destinationName ?? split.sourceName ?? '';
    }
    return split.sourceName ?? split.destinationName ?? '';
  }

  static String _getProductType(
    TransactionSplit split,
    Map<String, AccountRead> accountsMap,
    Set<String> selectedAccountIds,
  ) {
    String? accountId = split.sourceId;
    if (split.type == enums.TransactionTypeProperty.deposit &&
        split.destinationId != null) {
      accountId = split.destinationId;
    } else if (split.type == enums.TransactionTypeProperty.transfer) {
      if (split.destinationId != null &&
          selectedAccountIds.contains(split.destinationId)) {
        accountId = split.destinationId;
      }
    }

    final AccountRead? acc = accountId != null ? accountsMap[accountId] : null;
    if (acc != null) {
      final ShortAccountTypeProperty type = acc.attributes.type;
      final dynamic ccType = acc.attributes.creditCardType;
      final String nameLower = acc.attributes.name.toLowerCase();

      if (type == ShortAccountTypeProperty.liability ||
          type == ShortAccountTypeProperty.liabilities ||
          ccType != null ||
          nameLower.contains('tarjeta') ||
          nameLower.contains('card')) {
        return 'Tarjeta de crédito';
      }
    }
    return 'Cuenta';
  }

  static String _getMovementType(enums.TransactionTypeProperty type) {
    switch (type) {
      case enums.TransactionTypeProperty.withdrawal:
        return 'Gasto';
      case enums.TransactionTypeProperty.deposit:
        return 'Ingreso';
      case enums.TransactionTypeProperty.transfer:
        return 'Transferencia';
      case enums.TransactionTypeProperty.reconciliation:
        return 'Ajuste';
      case enums.TransactionTypeProperty.openingBalance:
        return 'Saldo inicial';
      default:
        return 'Otro';
    }
  }

  static String _escapeCsv(String? value, String delimiter) {
    if (value == null) return '';
    final String str = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (str.contains(delimiter) || str.contains('"') || str.contains(';')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Guarda el archivo CSV en el almacenamiento local.
  /// Primero guarda en directorio temporal y luego invoca FilePicker para guardar.
  static Future<String?> saveCsv({
    required String csvContent,
    required String fileName,
  }) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

    // Guardar siempre en directorio temporal primero
    final Directory tempDir = await getTemporaryDirectory();
    final File tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);

    try {
      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Descargar informe CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: <String>['csv'],
        bytes: bytes,
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final File destFile = File(selectedPath);
        if (!destFile.existsSync() || destFile.lengthSync() == 0) {
          await destFile.writeAsBytes(bytes);
        }
        return selectedPath;
      }
      return null; // El usuario canceló el diálogo
    } catch (_) {
      // En caso de que FilePicker falle o no esté implementado en la plataforma actual
      return tempFile.path;
    }
  }
}
