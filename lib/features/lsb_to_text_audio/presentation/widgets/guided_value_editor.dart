import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// Qué decidió la persona en el editor de valor.
sealed class ValueEditorResult {
  const ValueEditorResult();
}

/// Confirmó un valor válido.
class ValueConfirmed extends ValueEditorResult {
  final Map<String, Object?> values;
  const ValueConfirmed(this.values);
}

/// Pidió quitar la opción (solo se ofrece si ya estaba elegida).
class ValueRemoved extends ValueEditorResult {
  const ValueRemoved();
}

/// Abre el editor del valor de [option] (nombre, teléfono, monto…).
///
/// Es una transacción: la hoja trabaja sobre una copia y **no toca la
/// sesión**. Devuelve [ValueConfirmed] solo al pulsar «Confirmar» con un
/// valor que el dominio acepta; cerrar la hoja devuelve `null` y quien llama
/// no cambia nada.
Future<ValueEditorResult?> showGuidedValueEditor(
  BuildContext context, {
  required BankOption option,
  required String question,
  Map<String, Object?>? initial,
  bool canRemove = false,
}) {
  return showModalBottomSheet<ValueEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => GuidedValueEditor(
      option: option,
      question: question,
      initial: initial,
      canRemove: canRemove,
    ),
  );
}

class GuidedValueEditor extends StatefulWidget {
  final BankOption option;
  final String question;
  final Map<String, Object?>? initial;
  final bool canRemove;

  const GuidedValueEditor({
    super.key,
    required this.option,
    required this.question,
    this.initial,
    this.canRemove = false,
  });

  @override
  State<GuidedValueEditor> createState() => _GuidedValueEditorState();
}

class _GuidedValueEditorState extends State<GuidedValueEditor> {
  final Map<String, TextEditingController> _fields = {};
  String? _currency;
  bool _approximate = false;

  String get _editor => widget.option.editor!;

  List<String> get _textKeys => [
        for (final k in kEditorKeys[_editor] ?? const <String>[])
          if (k != 'moneda') k
      ];

  @override
  void initState() {
    super.initState();
    for (final key in _textKeys) {
      _fields[key] =
          TextEditingController(text: widget.initial?[key]?.toString() ?? '');
    }
    // Sin moneda por defecto: una moneda no elegida sería un dato inventado.
    _currency = widget.initial?['moneda']?.toString();
    _approximate = widget.initial?['aprox'] == 'si';
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _draft => {
        for (final e in _fields.entries) e.key: e.value.text,
        if (_editor == 'monto') 'moneda': _currency,
        if (_editor == 'edad' && _approximate) 'aprox': 'si',
      };

  ValueCheck get _check =>
      GuidedValues.check(_editor, _draft, range: widget.option.range);

  bool get _touched =>
      _fields.values.any((c) => c.text.trim().isNotEmpty) || _currency != null;

  void _confirm() {
    final check = _check;
    if (!check.isValid) return;
    Navigator.of(context).pop(ValueConfirmed(check.values));
  }

  (String, TextInputType, List<TextInputFormatter>, int) _fieldSpec() {
    return switch (_editor) {
      'telefono' => (
          'Número de celular',
          TextInputType.phone,
          [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            LengthLimitingTextInputFormatter(14),
          ],
          1
        ),
      'entero' || 'edad' => (
          _editor == 'edad' ? 'Edad en años' : 'Número',
          TextInputType.number,
          [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          1
        ),
      'monto' => (
          'Monto',
          const TextInputType.numberWithOptions(decimal: true),
          [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(12),
          ],
          1
        ),
      'hora' => (
          'Hora (por ejemplo 18:30)',
          TextInputType.datetime,
          [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            LengthLimitingTextInputFormatter(5),
          ],
          1
        ),
      'texto_nombre' => ('Nombre', TextInputType.name, const [], 1),
      'lugar_literal' => ('Nombre del lugar', TextInputType.text, const [], 1),
      'referencia' => ('Lugar de referencia', TextInputType.text, const [], 1),
      'documento_numero' =>
        ('Número del documento', TextInputType.text, const [], 1),
      _ => ('Escribe aquí', TextInputType.multiline, const [], 3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final (label, keyboard, format, lines) = _fieldSpec();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.option.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.lightTextSub),
            ),
            const SizedBox(height: 14),
            for (final key in _textKeys) ...[
              TextField(
                key: Key('editor_campo_$key'),
                controller: _fields[key],
                autofocus: key == _textKeys.first,
                keyboardType: keyboard,
                inputFormatters: format,
                minLines: lines,
                maxLines: lines,
                maxLength: kMaxValueLength,
                textCapitalization: _editor == 'texto_nombre'
                    ? TextCapitalization.words
                    : TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: label,
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.lightBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_editor == 'monto') ...[
              const Text('Moneda',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.lightText)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: [
                for (final c in kCurrencies)
                  ChoiceChip(
                    key: Key('editor_moneda_$c'),
                    label: Text(
                        c == 'Bs' ? 'Bolivianos (Bs)' : 'Dólares (USD)'),
                    selected: _currency == c,
                    onSelected: (_) => setState(() => _currency = c),
                  ),
              ]),
              const SizedBox(height: 12),
            ],
            if (_editor == 'edad' && !widget.option.noApproximate)
              SwitchListTile(
                key: const Key('editor_aprox'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Es una edad aproximada'),
                value: _approximate,
                onChanged: (v) => setState(() => _approximate = v),
              ),
            if (_touched && !check.isValid)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  check.error!,
                  style: const TextStyle(color: AppTheme.errorLight),
                ),
              ),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const Key('editor_confirmar'),
                onPressed: check.isValid ? _confirm : null,
                child: const Text('Confirmar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            if (widget.canRemove) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('editor_quitar'),
                onPressed: () =>
                    Navigator.of(context).pop(const ValueRemoved()),
                child: const Text('Quitar esta respuesta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
