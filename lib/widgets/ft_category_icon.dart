import 'package:flutter/material.dart';

/// Un icono envuelto en un círculo con el fondo del mismo color pero muy tenue.
/// Recrea el estilo visual de las categorías en Fintonic.
class FtCategoryIconWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double padding;

  const FtCategoryIconWidget({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24.0,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
