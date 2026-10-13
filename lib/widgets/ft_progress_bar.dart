import 'package:flutter/material.dart';

/// Barra de progreso lineal para indicar el consumo de presupuesto,
/// estilo Fintonic.
class FtProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double height;
  final Color? backgroundColor;

  const FtProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 4.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp progress between 0 and 1 just in case
    final double safeProgress = progress.clamp(0.0, 1.0);
    final Color bgColor =
        backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * safeProgress,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
