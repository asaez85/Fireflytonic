import 'package:flutter/material.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class BankLogoBadge extends StatelessWidget {
  final String accountName;
  final String? iban;
  final ShortAccountTypeProperty? type;
  final double size;

  const BankLogoBadge({
    super.key,
    required this.accountName,
    this.iban,
    this.type,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final String text =
        '${accountName.toLowerCase()} ${iban?.toLowerCase() ?? ''}';

    Color bgColor = const Color(0xFF1E2C45);
    String label = '';
    IconData? icon;

    if (text.contains('bbva')) {
      bgColor = const Color(0xFF004481);
      label = 'BBVA';
    } else if (text.contains('santander')) {
      bgColor = const Color(0xFFEC0000);
      label = 'SAN';
    } else if (text.contains('caixa') || text.contains('imagin')) {
      bgColor = const Color(0xFF00A9E0);
      label = 'Caixa';
    } else if (text.contains('ing')) {
      bgColor = const Color(0xFFFF6200);
      label = 'ING';
    } else if (text.contains('sabadell')) {
      bgColor = const Color(0xFF007BC7);
      label = 'BS';
    } else if (text.contains('openbank')) {
      bgColor = const Color(0xFF1E1E1E);
      label = 'Open';
    } else if (text.contains('revolut')) {
      bgColor = const Color(0xFF191C1F);
      label = 'R';
    } else if (text.contains('bankinter')) {
      bgColor = const Color(0xFFFF6600);
      label = 'Bk';
    } else if (text.contains('n26')) {
      bgColor = const Color(0xFF36A18B);
      label = 'N26';
    } else if (text.contains('wise')) {
      bgColor = const Color(0xFF2ED06E);
      label = 'Wise';
    } else if (text.contains('paypal')) {
      bgColor = const Color(0xFF003087);
      label = 'PP';
    } else if (text.contains('kutxa')) {
      bgColor = const Color(0xFF1A1A1A);
      label = 'Kutxa';
    } else if (text.contains('unicaja')) {
      bgColor = const Color(0xFF00833E);
      label = 'Uni';
    } else if (text.contains('abanca')) {
      bgColor = const Color(0xFF0066B3);
      label = 'Abanca';
    } else if (text.contains('ibercaja')) {
      bgColor = const Color(0xFFE4002B);
      label = 'Iber';
    } else if (type == ShortAccountTypeProperty.liability ||
        type == ShortAccountTypeProperty.liabilities) {
      bgColor = const Color(0xFF4A154B);
      icon = Icons.credit_card_outlined;
    } else if (type == ShortAccountTypeProperty.cash) {
      bgColor = const Color(0xFF1B5E20);
      icon = Icons.account_balance_wallet_outlined;
    } else if (type == ShortAccountTypeProperty.expense) {
      bgColor = const Color(0xFFB71C1C);
      icon = Icons.shopping_bag_outlined;
    } else if (type == ShortAccountTypeProperty.revenue) {
      bgColor = const Color(0xFF0D47A1);
      icon = Icons.arrow_downward_outlined;
    } else {
      bgColor = const Color(0xFF1E2C45);
      icon = Icons.account_balance_outlined;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: label.isNotEmpty
          ? Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.28,
                letterSpacing: 0.5,
              ),
            )
          : Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
