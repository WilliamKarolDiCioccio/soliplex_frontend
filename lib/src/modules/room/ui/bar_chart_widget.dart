import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders a vertical bar chart from a `render_bar_chart_from_script` result.
///
/// [data] is the decoded JSON map returned by the backend tool:
/// ```json
/// {
///   "title":   "TKV by Customer",
///   "bars":    [{"label": "Marcus Chen", "value": 1149.90}, ...],
///   "x_label": "Customer",
///   "y_label": "TKV ($)"
/// }
/// ```
class BarChartWidget extends StatelessWidget {
  const BarChartWidget({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = data['title'] as String? ?? '';
    final xLabel = data['x_label'] as String? ?? '';
    final yLabel = data['y_label'] as String? ?? '';
    final barsRaw = data['bars'] as List<dynamic>? ?? [];

    final bars = barsRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (b) => (
            label: b['label'] as String? ?? '',
            value: (b['value'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _BarChartHeader(title: title, yLabel: yLabel, scheme: scheme),
          const SizedBox(height: 14),
          if (bars.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No data',
                style: TextStyle(
                  color: scheme.onSurface.withAlpha(120),
                  fontSize: 13,
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: _BarsRow(bars: bars, scheme: scheme),
            ),
          if (xLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                xLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withAlpha(140),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarChartHeader extends StatelessWidget {
  const _BarChartHeader({
    required this.title,
    required this.yLabel,
    required this.scheme,
  });

  final String title;
  final String yLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (yLabel.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              yLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.3,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withAlpha(180),
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BarsRow extends StatelessWidget {
  const _BarsRow({required this.bars, required this.scheme});

  final List<({String label, double value})> bars;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final maxVal = bars.map((b) => b.value).reduce(math.max);
    final minVal = bars.map((b) => b.value).reduce(math.min);
    final floor = minVal > 0 ? minVal * 0.98 : minVal;
    final range = maxVal - floor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bar in bars)
          Expanded(
            child: _BarItem(
              label: bar.label,
              value: bar.value,
              fraction: range > 0 ? (bar.value - floor) / range : 1.0,
              scheme: scheme,
            ),
          ),
      ],
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.label,
    required this.value,
    required this.fraction,
    required this.scheme,
  });

  final String label;
  final double value;
  final double fraction;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                const labelH = 14.0;
                const gap = 2.0;
                final availForBar =
                    (constraints.maxHeight - labelH - gap).clamp(
                  0.0,
                  double.infinity,
                );
                final barH =
                    (fraction * availForBar).clamp(4.0, availForBar);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatValue(value),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withAlpha(160),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: gap),
                    SizedBox(
                      height: barH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(200),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurface.withAlpha(180),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}
