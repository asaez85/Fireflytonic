import 'package:flutter/material.dart';
import 'package:waterflyiii/pages/home/piggybank.dart';

/// Página de Huchas accesible desde el menú lateral (Drawer).
class PiggyBanksPage extends StatefulWidget {
  const PiggyBanksPage({super.key});

  @override
  State<PiggyBanksPage> createState() => _PiggyBanksPageState();
}

class _PiggyBanksPageState extends State<PiggyBanksPage> {
  @override
  Widget build(BuildContext context) {
    return const HomePiggybank();
  }
}
