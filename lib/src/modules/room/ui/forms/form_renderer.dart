import 'package:flutter/material.dart';

import 'form_schema.dart';

/// Called when the user submits the form.
///
/// [title] is the form title (may be null).
/// [answers] maps field labels to their values.
typedef FormSubmitCallback = void Function(
  String? title,
  Map<String, dynamic> answers,
);

/// Parses a JSON [content] string into a form and renders it.
///
/// On submit the form collapses to a summary card and [onSubmit] is called
/// so the caller can relay the answers back to the LLM.
class FormRenderer extends StatefulWidget {
  const FormRenderer({
    required this.content,
    required this.onSubmit,
    super.key,
  });

  final String content;
  final FormSubmitCallback onSubmit;

  @override
  State<FormRenderer> createState() => _FormRendererState();
}

class _FormRendererState extends State<FormRenderer> {
  late final FormSchema? _schema;
  final Map<String, dynamic> _values = {};
  final Map<String, String> _errors = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _schema = FormSchema.parse(widget.content);
    _initDefaults();
  }

  void _initDefaults() {
    final schema = _schema;
    if (schema == null) return;
    for (final field in schema.fields) {
      _values[field.id] = switch (field) {
        TextFieldSchema() => '',
        CheckboxSchema() => false,
        DropdownSchema() => null,
        SelectorSchema() => <String>[],
      };
    }
  }

  bool _validate() {
    _errors.clear();
    for (final field in (_schema?.fields ?? [])) {
      if (!field.required) continue;
      final value = _values[field.id];
      final error = switch (field) {
        TextFieldSchema() when (value as String).trim().isEmpty =>
          'Required',
        CheckboxSchema() when value == false => 'Must be checked',
        DropdownSchema() when value == null => 'Please select an option',
        SelectorSchema() when (value as List<String>).isEmpty =>
          'Please select at least one',
        _ => null,
      };
      if (error != null) _errors[field.id] = error;
    }
    return _errors.isEmpty;
  }

  void _submit() {
    if (!_validate()) {
      setState(() {});
      return;
    }
    final schema = _schema!;
    // Build answer map keyed by label for LLM readability.
    final answers = <String, dynamic>{
      for (final field in schema.fields)
        if (_values[field.id] case final v
            when v != null &&
                !(v is String && v.isEmpty) &&
                !(v is List && v.isEmpty))
          field.label: v,
    };
    setState(() => _submitted = true);
    widget.onSubmit(schema.title, answers);
  }

  @override
  Widget build(BuildContext context) {
    final schema = _schema;
    if (schema == null) {
      return _ParseError(content: widget.content);
    }
    if (_submitted) {
      return _SubmittedSummary(schema: schema, values: _values);
    }
    return _FormCard(
      schema: schema,
      values: _values,
      errors: _errors,
      onChanged: (id, value) => setState(() {
        _values[id] = value;
        _errors.remove(id);
      }),
      onSubmit: _submit,
    );
  }
}

// ---------------------------------------------------------------------------
// Form card (active state)
// ---------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.schema,
    required this.values,
    required this.errors,
    required this.onChanged,
    required this.onSubmit,
  });

  final FormSchema schema;
  final Map<String, dynamic> values;
  final Map<String, String> errors;
  final void Function(String id, dynamic value) onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (schema.title != null || schema.description != null)
            _FormHeader(
              title: schema.title,
              description: schema.description,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in schema.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildField(context, field),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send, size: 18),
              label: Text(schema.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, FormFieldSchema field) {
    return switch (field) {
      TextFieldSchema() => _TextFieldWidget(
          schema: field,
          value: values[field.id] as String,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      CheckboxSchema() => _CheckboxWidget(
          schema: field,
          value: values[field.id] as bool,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      DropdownSchema() => _DropdownWidget(
          schema: field,
          value: values[field.id] as String?,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      SelectorSchema() => _SelectorWidget(
          schema: field,
          value: values[field.id] as List<String>,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
    };
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({this.title, this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withAlpha(40)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withAlpha(160),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual field widgets
// ---------------------------------------------------------------------------

class _TextFieldWidget extends StatefulWidget {
  const _TextFieldWidget({
    required this.schema,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final TextFieldSchema schema;
  final String value;
  final String? error;
  final void Function(String) onChanged;

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextInputType get _keyboardType => switch (widget.schema.inputType) {
        TextFieldType.email => TextInputType.emailAddress,
        TextFieldType.phone => TextInputType.phone,
        TextFieldType.number => TextInputType.number,
        _ => TextInputType.text,
      };

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.schema.label + (widget.schema.required ? ' *' : ''),
        hintText: widget.schema.placeholder,
        errorText: widget.error,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: _keyboardType,
      obscureText: widget.schema.inputType == TextFieldType.password,
      onChanged: widget.onChanged,
    );
  }
}

class _CheckboxWidget extends StatelessWidget {
  const _CheckboxWidget({
    required this.schema,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final CheckboxSchema schema;
  final bool value;
  final String? error;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          title: Text(
            schema.label + (schema.required ? ' *' : ''),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _DropdownWidget extends StatelessWidget {
  const _DropdownWidget({
    required this.schema,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final DropdownSchema schema;
  final String? value;
  final String? error;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: schema.label + (schema.required ? ' *' : ''),
        errorText: error,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final option in schema.options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}

class _SelectorWidget extends StatelessWidget {
  const _SelectorWidget({
    required this.schema,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final SelectorSchema schema;
  final List<String> value;
  final String? error;
  final void Function(List<String>) onChanged;

  void _toggle(String option) {
    final updated = List<String>.from(value);
    if (updated.contains(option)) {
      updated.remove(option);
    } else {
      if (!schema.multiple) updated.clear();
      updated.add(option);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          schema.label + (schema.required ? ' *' : ''),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (schema.multiple)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              'Select all that apply',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withAlpha(140),
                  ),
            ),
          )
        else
          const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in schema.options)
              FilterChip(
                label: Text(option),
                selected: value.contains(option),
                onSelected: (_) => _toggle(option),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              style: TextStyle(
                color: scheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Submitted summary
// ---------------------------------------------------------------------------

class _SubmittedSummary extends StatelessWidget {
  const _SubmittedSummary({required this.schema, required this.values});

  final FormSchema schema;
  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                schema.title != null
                    ? '${schema.title} — submitted'
                    : 'Form submitted',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final field in schema.fields)
            if (_formatValue(field) case final display when display != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.label}: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withAlpha(160),
                          ),
                    ),
                    Flexible(
                      child: Text(
                        display,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String? _formatValue(FormFieldSchema field) {
    final v = values[field.id];
    if (v == null) return null;
    return switch (v) {
      final bool b => b ? 'Yes' : 'No',
      final List<dynamic> l when l.isEmpty => null,
      final List<dynamic> l => l.join(', '),
      final String s when s.isEmpty => null,
      _ => '$v',
    };
  }
}

// ---------------------------------------------------------------------------
// Parse error
// ---------------------------------------------------------------------------

class _ParseError extends StatelessWidget {
  const _ParseError({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          const Flexible(child: Text('Could not parse form schema.')),
        ],
      ),
    );
  }
}
