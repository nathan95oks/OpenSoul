/// Valores literales que acompañan a una opción del banco.
///
/// Cada editor rellena unas claves concretas, las mismas que leen las
/// plantillas (`{telefono}`, `{monto}`, `{n}`…) en Dart y en Python. La
/// validación vive aquí, en el dominio, y no solo en el campo de texto: una
/// respuesta con un teléfono de tres cifras o un monto sin moneda no puede
/// entrar en la sesión aunque alguna pantalla se olvide de comprobarlo.
///
/// Validar no es reescribir: el monto, el nombre, el número de documento o el
/// teléfono se guardan como la persona los escribió (recortados). Solo se
/// quitan los espacios y guiones de un teléfono, que no son parte del número.
library;

/// Claves que rellena cada editor. Gemelo de `EDITOR_KEYS` en
/// `aws/guided_composer.py`.
const Map<String, List<String>> kEditorKeys = {
  'texto_nombre': ['nombre'],
  'telefono': ['telefono'],
  'entero': ['n'],
  'edad': ['n'],
  'monto': ['monto', 'moneda'],
  'texto_detalle': ['texto'],
  'lugar_literal': ['nombre'],
  'referencia': ['referencia'],
  'documento_numero': ['numero'],
  'hora': ['hora'],
};

/// Monedas que el editor de monto ofrece. No hay moneda por defecto: una
/// moneda que la persona no eligió sería un dato inventado. `Bs` es el
/// boliviano (código ISO BOB).
const List<String> kCurrencies = ['Bs', 'USD'];

/// Longitud máxima de un valor escrito. Gemelo de `MAX_VALUE_LENGTH` en la
/// Lambda.
const int kMaxValueLength = 120;

/// Resultado de validar los valores de un editor.
class ValueCheck {
  final Map<String, Object?> values;
  final String? error;

  const ValueCheck.ok(this.values) : error = null;

  const ValueCheck.invalid(this.error) : values = const {};

  bool get isValid => error == null;
}

class GuidedValues {
  const GuidedValues._();

  /// Valida [raw] para [editor] y devuelve los valores tal como se guardarán,
  /// o el motivo por el que no pueden guardarse. Nunca completa un valor que
  /// falta.
  static ValueCheck check(String editor, Map<String, Object?> raw,
      {List<int>? range}) {
    String text(String key) => (raw[key] ?? '').toString().trim();

    switch (editor) {
      case 'telefono':
        final digits = text('telefono').replaceAll(RegExp(r'[\s-]'), '');
        final local = digits.startsWith('+591')
            ? digits.substring(4)
            : (digits.startsWith('591') && digits.length > 9
                ? digits.substring(3)
                : digits);
        if (!RegExp(r'^\d{7,8}$').hasMatch(local)) {
          return const ValueCheck.invalid(
              'Un número de Bolivia tiene 7 u 8 dígitos.');
        }
        return ValueCheck.ok({'telefono': digits});
      case 'entero':
      case 'edad':
        final n = int.tryParse(text('n'));
        if (n == null) return const ValueCheck.invalid('Escribe un número.');
        final min = range != null && range.isNotEmpty ? range[0] : 0;
        final max = range != null && range.length > 1 ? range[1] : 999;
        if (n < min || n > max) {
          return ValueCheck.invalid('El número debe estar entre $min y $max.');
        }
        return ValueCheck.ok({
          'n': '$n',
          if (editor == 'edad' && raw['aprox'] == 'si') 'aprox': 'si',
        });
      case 'monto':
        final amount = text('monto');
        if (!RegExp(r'^\d{1,9}([.,]\d{1,3})*$').hasMatch(amount) ||
            !RegExp(r'[1-9]').hasMatch(amount)) {
          return const ValueCheck.invalid('Escribe un monto mayor que cero.');
        }
        final currency = text('moneda');
        if (!kCurrencies.contains(currency)) {
          return const ValueCheck.invalid('Elige la moneda.');
        }
        return ValueCheck.ok({'monto': amount, 'moneda': currency});
      case 'hora':
        final hour = text('hora');
        final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hour);
        final h = int.tryParse(match?.group(1) ?? '');
        final m = int.tryParse(match?.group(2) ?? '');
        if (h == null || m == null || h > 23 || m > 59) {
          return const ValueCheck.invalid('Escribe la hora como 18:30.');
        }
        return ValueCheck.ok({'hora': hour});
      default:
        final keys = kEditorKeys[editor];
        if (keys == null) {
          return ValueCheck.invalid('Editor desconocido: $editor');
        }
        final out = <String, Object?>{};
        for (final key in keys) {
          final value = text(key);
          if (value.isEmpty) return const ValueCheck.invalid('Escribe el dato.');
          if (value.length > kMaxValueLength) {
            return const ValueCheck.invalid('El texto es demasiado largo.');
          }
          out[key] = value;
        }
        return ValueCheck.ok(out);
    }
  }

  /// Si [values] tiene todo lo que pide [editor].
  static bool isComplete(String editor, Map<String, Object?>? values) {
    final keys = kEditorKeys[editor] ?? const <String>[];
    if (values == null || keys.isEmpty) return false;
    return keys.every((k) => '${values[k] ?? ''}'.trim().isNotEmpty);
  }

  /// Texto corto para mostrar el valor guardado en la tarjeta.
  static String summary(String editor, Map<String, Object?>? values) {
    if (values == null) return '';
    return switch (editor) {
      'monto' => '${values['moneda'] ?? ''} ${values['monto'] ?? ''}'.trim(),
      'edad' => values['n'] == null
          ? ''
          : '${values['aprox'] == 'si' ? '≈ ' : ''}${values['n']} años',
      _ => [
          for (final k in kEditorKeys[editor] ?? const <String>[])
            if ('${values[k] ?? ''}'.trim().isNotEmpty) '${values[k]}',
        ].join(' '),
    };
  }
}
