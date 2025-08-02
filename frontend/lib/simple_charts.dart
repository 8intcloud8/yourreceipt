import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<BarChartItem> items;
  final double barWidth;
  final double barSpacing;
  final double maxValue;
  
  const SimpleBarChart({
    super.key,
    required this.items,
    this.barWidth = 30,
    this.barSpacing = 10,
    this.maxValue = 0,
  });
  
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }
    
    // Find the maximum value for scaling
    final maxVal = maxValue > 0 ? maxValue : items.map((item) => item.value).reduce(max);
    
    return Container(
      height: 300,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            // Scale the bar height based on the maximum value
            final barHeight = maxVal > 0 
                ? (item.value / maxVal) * 180 
                : 0;
            
            return Container(
              width: barWidth + barSpacing,
              padding: EdgeInsets.symmetric(horizontal: barSpacing / 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Total money spent label
                  Text(
                    item.totalSpent ?? '\$0.00',
                    style: const TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bar
                  Container(
                    width: barWidth,
                    height: max(barHeight, 1.0).toDouble(),
                    decoration: BoxDecoration(
                      color: item.color ?? Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Label
                  Container(
                    width: barWidth + barSpacing,
                    height: 60,
                    alignment: Alignment.center,
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class BarChartItem {
  final String label;
  final double value;
  final String? tooltip;
  final Color? color;
  final String? totalSpent;
  
  BarChartItem({
    required this.label,
    required this.value,
    this.tooltip,
    this.color,
    this.totalSpent,
  });
}

class SimplePieChart extends StatelessWidget {
  final List<PieChartItem> items;
  final double size;

  const SimplePieChart({
    Key? key,
    required this.items,
    this.size = 300,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    // Calculate total for percentages
    final total = items.fold(0.0, (sum, item) => sum + item.value);

    return Row(
      children: [
        // Pie chart visualization
        Expanded(
          flex: 3,
          child: SizedBox(
            height: size,
            child: CustomPaint(
              painter: SimplePieChartPainter(
                items: items,
                total: total,
              ),
              size: Size(size, size),
            ),
          ),
        ),
        
        // Legend
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              final percentage = total > 0 ? (item.value / total) * 100 : 0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: item.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.label} (${percentage.isFinite ? percentage.toStringAsFixed(1) : 0}%)',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class PieChartItem {
  final String label;
  final double value;
  final Color color;

  PieChartItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class SimplePieChartPainter extends CustomPainter {
  final List<PieChartItem> items;
  final double total;

  SimplePieChartPainter({
    required this.items,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    if (total <= 0) {
      // Draw empty circle if no data
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius, paint);
      return;
    }
    
    double startAngle = 0;
    
    for (final item in items) {
      final sweepAngle = (item.value / total) * 2 * math.pi;
      
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      startAngle += sweepAngle;
    }
    
    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
