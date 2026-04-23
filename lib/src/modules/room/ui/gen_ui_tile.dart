import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'bar_chart_widget.dart';
import 'forms/form_renderer.dart';
import 'stock_chart_widget.dart';

class GenUiTile extends StatelessWidget {
  const GenUiTile({
    super.key,
    required this.message,
    this.onFormSubmit,
  });

  final GenUiMessage message;
  final FormSubmitCallback? onFormSubmit;

  @override
  Widget build(BuildContext context) {
    return switch (message.widgetName) {
      'render_form' => _buildForm(context),
      'render_stock_chart' => _buildChart(),
      'render_bar_chart_from_script' => _buildBarChart(),
      _ => _buildUnknown(context),
    };
  }

  Widget _buildForm(BuildContext context) {
    if (message.data.isEmpty) return _buildLoading(context);
    return FormRenderer(
      content: jsonEncode(message.data),
      onSubmit: onFormSubmit ?? (title, answers) {},
    );
  }

  Widget _buildChart() {
    if (message.data.isEmpty) return Builder(builder: _buildLoading);
    return StockChartWidget(data: message.data);
  }

  Widget _buildBarChart() {
    if (message.data.isEmpty) return Builder(builder: _buildLoading);
    return BarChartWidget(data: message.data);
  }

  Widget _buildLoading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rendering…',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknown(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.widgetName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(message.data),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
