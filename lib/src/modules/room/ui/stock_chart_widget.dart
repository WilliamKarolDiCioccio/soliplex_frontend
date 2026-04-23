import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders a vertical bar chart from a `render_stock_chart` tool result.
///
/// [data] is the decoded JSON map returned by the backend tool:
/// ```json
/// {
///   "title":    "AAPL — This Week",
///   "symbol":   "AAPL",
///   "currency": "USD",
///   "bars": [
///     {"label": "Mon", "value": 189.50},
///     {"label": "Tue", "value": 191.20}
///   ]
/// }
/// ```
class StockChartWidget extends StatelessWidget {
  const StockChartWidget({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = data['title'] as String? ?? '';
    final symbol = data['symbol'] as String? ?? '';
    final currency = data['currency'] as String? ?? 'USD';
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
          _ChartHeader(symbol: symbol, title: title, scheme: scheme),
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
              child: _BarsRow(
                bars: bars,
                currency: currency,
                scheme: scheme,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.symbol,
    required this.title,
    required this.scheme,
  });

  final String symbol;
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (symbol.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
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
  const _BarsRow({
    required this.bars,
    required this.currency,
    required this.scheme,
  });

  final List<({String label, double value})> bars;
  final String currency;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final maxVal = bars.map((b) => b.value).reduce(math.max);
    final minVal = bars.map((b) => b.value).reduce(math.min);
    // Set the chart floor slightly below the minimum so short bars are still
    // visible when values are clustered in a narrow range.
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
              currency: currency,
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
    required this.currency,
    required this.scheme,
  });

  final String label;
  final double value;

  /// Normalised height in [0, 1] relative to the tallest bar.
  final double fraction;
  final String currency;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Bar area: grows to fill available space, bar anchored to bottom.
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                // Reserve space for the value label (≈14px) and its gap (2px).
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
                    // Value label floats directly above the bar.
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
          // X-axis label.
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
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return '\$${v.toStringAsFixed(0)}';
    return '\$${v.toStringAsFixed(2)}';
  }
}
