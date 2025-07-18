import 'package:flutter/material.dart';

class Contribution {
  final String compte;
  final Color couleur;
  final double montant;
  Contribution({
    required this.compte,
    required this.couleur,
    required this.montant,
  });
}

class PieChartWithLegend extends StatelessWidget {
  final List<Contribution> contributions;
  final double size;
  const PieChartWithLegend({
    super.key,
    required this.contributions,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final total = contributions.fold<double>(0, (sum, c) => sum + c.montant);
    double start = -90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PieChartPainter(contributions, total, start),
          ),
        ),
        const SizedBox(height: 8),
        ...contributions.map(
          (c) => Row(
            children: [
              Container(
                width: 12,
                height: 12,
                color: c.couleur,
                margin: const EdgeInsets.only(right: 6),
              ),
              Text(
                '${c.compte}: ${c.montant.toStringAsFixed(2)} / 24',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<Contribution> contributions;
  final double total;
  final double startAngle;
  _PieChartPainter(this.contributions, this.total, this.startAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double angle = startAngle;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final c in contributions) {
      final sweep = total == 0 ? 0 : 360 * (c.montant / total);
      paint.color = c.couleur;
      canvas.drawArc(
        rect,
        angle * 3.1415926535 / 180,
        sweep * 3.1415926535 / 180,
        true,
        paint,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
