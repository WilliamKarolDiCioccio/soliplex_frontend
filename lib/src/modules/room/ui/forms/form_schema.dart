import 'dart:convert';

/// Text input variants for [TextFieldSchema].
enum TextFieldType {
  text,
  email,
  phone,
  number,
  password;

  static TextFieldType fromString(String? value) => switch (value) {
        'email' => email,
        'phone' => phone,
        'number' => number,
        'password' => password,
        _ => text,
      };
}

/// Base class for all form field schemas.
sealed class FormFieldSchema {
  const FormFieldSchema({
    required this.id,
    required this.label,
    this.required = false,
  });

  final String id;
  final String label;
  final bool required;

  /// Parses a field from JSON.
  ///
  /// Supports two formats:
  ///
  /// **Legacy format** (existing markdown-block path) — uses `type` and `id`:
  /// ```json
  /// {"type": "textfield", "id": "name", "label": "Name", "required": true}
  /// ```
  ///
  /// **GenUI backend format** — uses `field_type`; `id` is auto-generated from
  /// the label:
  /// ```json
  /// {"label": "Name", "field_type": "text", "required": true}
  /// ```
  static FormFieldSchema? _fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String?;
    if (label == null) return null;

    final req = (json['required'] as bool?) ?? false;
    final rawType = json['type'] as String?;
    final fieldType = json['field_type'] as String?;

    // Auto-generate id from label when not explicitly provided.
    final id = json['id'] as String? ?? _toId(label);

    if (rawType != null) {
      return _parseByType(rawType, id, label, req, json);
    }
    if (fieldType != null) {
      return _parseByFieldType(fieldType, id, label, req, json);
    }
    return null;
  }

  /// Converts a human-readable label to a stable snake_case identifier.
  static String _toId(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// Parses a field using the legacy `type` discriminator.
  static FormFieldSchema? _parseByType(
    String type,
    String id,
    String label,
    bool req,
    Map<String, dynamic> json,
  ) {
    return switch (type) {
      'textfield' => TextFieldSchema(
          id: id,
          label: label,
          required: req,
          placeholder: json['placeholder'] as String?,
          inputType: TextFieldType.fromString(json['inputType'] as String?),
        ),
      'checkbox' => CheckboxSchema(id: id, label: label, required: req),
      'dropdown' => DropdownSchema(
          id: id,
          label: label,
          required: req,
          options: (json['options'] as List<dynamic>? ?? [])
              .map((e) => '$e')
              .toList(),
        ),
      'selector' => SelectorSchema(
          id: id,
          label: label,
          required: req,
          options: (json['options'] as List<dynamic>? ?? [])
              .map((e) => '$e')
              .toList(),
          multiple: (json['multiple'] as bool?) ?? false,
        ),
      _ => null,
    };
  }

  /// Parses a field using the GenUI backend `field_type` key.
  ///
  /// Maps simplified type names to the richer legacy schema types.
  static FormFieldSchema? _parseByFieldType(
    String fieldType,
    String id,
    String label,
    bool req,
    Map<String, dynamic> json,
  ) {
    final placeholder = json['placeholder'] as String?;
    final options =
        (json['options'] as List<dynamic>? ?? []).map((e) => '$e').toList();

    return switch (fieldType) {
      'email' => TextFieldSchema(
          id: id,
          label: label,
          required: req,
          placeholder: placeholder,
          inputType: TextFieldType.email,
        ),
      'number' => TextFieldSchema(
          id: id,
          label: label,
          required: req,
          placeholder: placeholder,
          inputType: TextFieldType.number,
        ),
      'checkbox' => CheckboxSchema(id: id, label: label, required: req),
      'dropdown' => DropdownSchema(
          id: id,
          label: label,
          required: req,
          options: options,
        ),
      // 'text' and any unknown value fall back to plain text input.
      _ => TextFieldSchema(
          id: id,
          label: label,
          required: req,
          placeholder: placeholder,
          inputType: TextFieldType.text,
        ),
    };
  }
}

/// A single-line or multi-line text input.
final class TextFieldSchema extends FormFieldSchema {
  const TextFieldSchema({
    required super.id,
    required super.label,
    super.required,
    this.placeholder,
    this.inputType = TextFieldType.text,
  });

  final String? placeholder;
  final TextFieldType inputType;
}

/// A boolean checkbox.
final class CheckboxSchema extends FormFieldSchema {
  const CheckboxSchema({
    required super.id,
    required super.label,
    super.required,
  });
}

/// A single-choice dropdown.
final class DropdownSchema extends FormFieldSchema {
  const DropdownSchema({
    required super.id,
    required super.label,
    super.required,
    required this.options,
  });

  final List<String> options;
}

/// A chip-based selector supporting single or multiple selections.
final class SelectorSchema extends FormFieldSchema {
  const SelectorSchema({
    required super.id,
    required super.label,
    super.required,
    required this.options,
    this.multiple = false,
  });

  final List<String> options;
  final bool multiple;
}

/// The top-level form schema produced by the LLM or the GenUI backend.
///
/// Legacy markdown-block example:
/// ```json
/// {
///   "title": "Contact us",
///   "fields": [
///     {"type": "textfield", "id": "name", "label": "Name",
///      "inputType": "text", "required": true}
///   ]
/// }
/// ```
///
/// GenUI backend example:
/// ```json
/// {
///   "title": "Contact us",
///   "submit_label": "Send",
///   "fields": [
///     {"label": "Name",  "field_type": "text",  "required": true},
///     {"label": "Email", "field_type": "email", "required": true}
///   ]
/// }
/// ```
final class FormSchema {
  const FormSchema({
    this.title,
    this.description,
    this.submitLabel = 'Submit',
    required this.fields,
  });

  final String? title;
  final String? description;

  /// Text shown on the submit button. Defaults to `'Submit'`.
  ///
  /// Set by the `submit_label` key in the GenUI backend format.
  final String submitLabel;

  final List<FormFieldSchema> fields;

  /// Parses [jsonContent] and returns a [FormSchema], or `null` on failure.
  static FormSchema? parse(String jsonContent) {
    try {
      final json = jsonDecode(jsonContent) as Map<String, dynamic>;
      final fieldsRaw = json['fields'] as List<dynamic>?;
      if (fieldsRaw == null) return null;

      final fields = fieldsRaw
          .whereType<Map<String, dynamic>>()
          .map(FormFieldSchema._fromJson)
          .whereType<FormFieldSchema>()
          .toList();

      return FormSchema(
        title: json['title'] as String?,
        description: json['description'] as String?,
        submitLabel: json['submit_label'] as String? ?? 'Submit',
        fields: fields,
      );
    } catch (_) {
      return null;
    }
  }
}
