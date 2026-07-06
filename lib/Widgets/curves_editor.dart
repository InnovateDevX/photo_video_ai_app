import 'package:flutter/material.dart';
import '../Models/curves_data.dart';

class CurvesEditor extends StatefulWidget {
  final CurvesData data;
  final ValueChanged<CurvesData> onChanged;
  final bool isDark;

  const CurvesEditor({
    super.key,
    required this.data,
    required this.onChanged,
    this.isDark = true,
  });

  @override
  State<CurvesEditor> createState() => _CurvesEditorState();
}

class _CurvesEditorState extends State<CurvesEditor> {
  final List<String> _channels = ['master', 'red', 'green', 'blue'];
  int? _dragIndex;
  double _graphWidth = 0;
  double _graphHeight = 0;

  List<Offset> get _points => widget.data.activePoints;

  Color _channelColor(String ch) {
    switch (ch) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Channel Selector (left side, like Photoshop) ──
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _channels.map((ch) {
            final isActive = widget.data.activeChannel == ch;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () {
                  widget.data.activeChannel = ch;
                  widget.onChanged(widget.data.copy());
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? _channelColor(ch) : Colors.grey,
                      width: isActive ? 3 : 1.5,
                    ),
                    color: isActive
                        ? _channelColor(ch).withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _channelColor(ch),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
        // ── Graph Area ──
        Expanded(
          child: AspectRatio(
            aspectRatio: 2.0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _graphWidth = constraints.maxWidth;
                _graphHeight = constraints.maxHeight;
                return GestureDetector(
                  onTapDown: (details) => _onTapDown(details.localPosition),
                  onPanStart: (details) => _onPanStart(details.localPosition),
                  onPanUpdate: (details) => _onPanUpdate(details.localPosition),
                  onPanEnd: (_) => setState(() => _dragIndex = null),
                  child: CustomPaint(
                    painter: _CurvesGraphPainter(
                      points: _points,
                      channelColor: _channelColor(widget.data.activeChannel),
                      isDark: widget.isDark,
                    ),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _onTapDown(Offset local) {
    final norm = _toNormalized(local);
    // Add new point if not near existing
    if (_findNearest(norm) == null) {
      final updated = List<Offset>.from(_points)..add(norm);
      _sortAndUpdate(updated);
    }
  }

  void _onPanStart(Offset local) {
    final norm = _toNormalized(local);
    _dragIndex = _findNearest(norm);
  }

  void _onPanUpdate(Offset local) {
    if (_dragIndex == null) return;
    var norm = _toNormalized(local);
    // Clamp to graph bounds
    norm = Offset(norm.dx.clamp(0.0, 1.0), norm.dy.clamp(0.0, 1.0));

    final updated = List<Offset>.from(_points);
    updated[_dragIndex!] = norm;

    // Remove if dragged outside or too close to neighbor
    _sortAndUpdate(updated);
  }

  int? _findNearest(Offset norm) {
    int? best;
    double bestDist = 0.08; // 8% of graph = touch threshold
    for (int i = 0; i < _points.length; i++) {
      final d = (_points[i] - norm).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _sortAndUpdate(List<Offset> points) {
    // Keep endpoints locked
    if (points.isEmpty) return;
    points.sort((a, b) => a.dx.compareTo(b.dx));
    // Clamp endpoints
    points[0] = Offset(0, points[0].dy.clamp(0.0, 1.0));
    points[points.length - 1] = Offset(1, points.last.dy.clamp(0.0, 1.0));

    // Remove duplicates or points too close in X
    final cleaned = <Offset>[points.first];
    for (int i = 1; i < points.length; i++) {
      if ((points[i].dx - cleaned.last.dx) > 0.02) {
        cleaned.add(points[i]);
      }
    }
    if (cleaned.last.dx < 0.98) cleaned.add(points.last);

    widget.data.activePoints = cleaned;
    widget.onChanged(widget.data.copy());
  }

  Offset _toNormalized(Offset local) {
    return Offset(local.dx / _graphWidth, 1.0 - (local.dy / _graphHeight));
  }
}

// ═══════════════════════════════════════════════════════════
// GRAPH PAINTER
// ═══════════════════════════════════════════════════════════

class _CurvesGraphPainter extends CustomPainter {
  final List<Offset> points;
  final Color channelColor;
  final bool isDark;

  _CurvesGraphPainter({
    required this.points,
    required this.channelColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1a1a1a) : Colors.grey.shade200;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid lines (10% increments)
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 1; i < 10; i++) {
      final t = i / 10.0;
      // Vertical
      canvas.drawLine(
        Offset(t * size.width, 0),
        Offset(t * size.width, size.height),
        gridPaint,
      );
      // Horizontal
      canvas.drawLine(
        Offset(0, t * size.height),
        Offset(size.width, t * size.height),
        gridPaint,
      );
    }

    // Diagonal reference line (identity)
    final diagPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), diagPaint);

    // Build LUT for smooth curve rendering
    final lut = _buildLut(points);

    // Draw curve
    final curvePaint = Paint()
      ..color = channelColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;
    for (int i = 0; i < 256; i++) {
      final x = i / 255.0;
      final y = lut[i] / 255.0;
      final px = x * size.width;
      final py = (1.0 - y) * size.height;
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Control points
    for (final p in points) {
      final px = p.dx * size.width;
      final py = (1.0 - p.dy) * size.height;

      // Outer ring
      canvas.drawCircle(
        Offset(px, py),
        6,
        Paint()..color = channelColor.withValues(alpha: 0.3),
      );
      // Inner dot
      canvas.drawCircle(Offset(px, py), 4, Paint()..color = Colors.white);
      // Center
      canvas.drawCircle(Offset(px, py), 2, Paint()..color = channelColor);
    }
  }

  List<double> _buildLut(List<Offset> pts) {
    final lut = List<double>.filled(256, 0);
    if (pts.length < 2) {
      for (int i = 0; i < 256; i++) {
        lut[i] = i.toDouble();
      }
      return lut;
    }

    final sorted = List<Offset>.from(pts)..sort((a, b) => a.dx.compareTo(b.dx));

    for (int i = 0; i < 256; i++) {
      final x = i / 255.0;
      lut[i] = _interpolate(sorted, x) * 255.0;
    }
    return lut;
  }

  double _interpolate(List<Offset> sorted, double x) {
    if (x <= sorted.first.dx) return sorted.first.dy;
    if (x >= sorted.last.dx) return sorted.last.dy;

    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (x >= a.dx && x <= b.dx) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return sorted.last.dy;
  }

  @override
  bool shouldRepaint(covariant _CurvesGraphPainter old) =>
      old.points != points || old.channelColor != channelColor;
}
