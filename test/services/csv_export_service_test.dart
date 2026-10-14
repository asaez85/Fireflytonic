import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions/services/csv_export_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('CsvExportService Tests', () {
    test('generateCsv outputs UTF-8 BOM and correct headers', () {
      final String csv = CsvExportService.generateCsv(
        splits: <TransactionSplit>[],
        accountsMap: <String, AccountRead>{},
        selectedAccountIds: <String>{},
      );

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv,
        contains(
          'Fecha valor;Fecha de operación;Importe;Moneda;Concepto;Entidad;Nombre de producto;Tipo de producto;Tipo de movimiento;Categoría;Nota',
        ),
      );
    });

    test(
      'generateCsv correctly maps withdrawal, deposit and bank entities',
      () {
        final AccountRead bbvaAccount = const AccountRead(
          id: '1',
          type: 'accounts',
          attributes: AccountProperties(
            name: 'Cuenta Corriente BBVA',
            type: ShortAccountTypeProperty.asset,
            iban: 'ES120182000000000000',
          ),
        );

        final AccountRead cardAccount = const AccountRead(
          id: '2',
          type: 'accounts',
          attributes: AccountProperties(
            name: 'Tarjeta Crédito Santander',
            type: ShortAccountTypeProperty.liability,
            creditCardType: CreditCardTypeProperty.monthlyfull,
          ),
        );

        final Map<String, AccountRead> accountsMap = <String, AccountRead>{
          '1': bbvaAccount,
          '2': cardAccount,
        };

        final List<TransactionSplit> splits = <TransactionSplit>[
          TransactionSplit(
            user: '1',
            transactionJournalId: '101',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 10),
            amount: '45.50',
            description: 'Mercadona compra; semanal',
            sourceId: '1',
            sourceName: 'Cuenta Corriente BBVA',
            categoryName: 'Alimentación',
            notes: 'Nota con "comillas"',
            currencyCode: 'EUR',
          ),
          TransactionSplit(
            user: '1',
            transactionJournalId: '102',
            type: TransactionTypeProperty.deposit,
            date: DateTime(2026, 10, 5),
            amount: '1200.00',
            description: 'Nómina empresa',
            destinationId: '1',
            destinationName: 'Cuenta Corriente BBVA',
            categoryName: 'Nómina',
            currencyCode: 'EUR',
          ),
          TransactionSplit(
            user: '1',
            transactionJournalId: '103',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 12),
            amount: '20.00',
            description: 'Restaurante',
            sourceId: '2',
            sourceName: 'Tarjeta Crédito Santander',
            categoryName: 'Restaurantes',
            currencyCode: 'EUR',
          ),
        ];

        final String csv = CsvExportService.generateCsv(
          splits: splits,
          accountsMap: accountsMap,
          selectedAccountIds: <String>{'1', '2'},
        );

        final List<String> lines = csv.trim().split('\n');
        expect(lines.length, 4); // Header + 3 rows

        // Row 1: Gasto BBVA (-45,50)
        expect(lines[1], contains('10/10/2026'));
        expect(lines[1], contains('-45,50'));
        expect(lines[1], contains('BBVA'));
        expect(lines[1], contains('Cuenta'));
        expect(lines[1], contains('Gasto'));
        expect(lines[1], contains('Alimentación'));
        // Escaped semicolon and quotes
        expect(lines[1], contains('"Mercadona compra; semanal"'));
        expect(lines[1], contains('"Nota con ""comillas"""'));

        // Row 2: Ingreso BBVA (1200,00)
        expect(lines[2], contains('05/10/2026'));
        expect(lines[2], contains('1200,00'));
        expect(lines[2], contains('Ingreso'));
        expect(lines[2], contains('Nómina'));

        // Row 3: Gasto Tarjeta Santander (-20,00)
        expect(lines[3], contains('12/10/2026'));
        expect(lines[3], contains('-20,00'));
        expect(lines[3], contains('Santander'));
        expect(lines[3], contains('Tarjeta de crédito'));
      },
    );
  });
}
