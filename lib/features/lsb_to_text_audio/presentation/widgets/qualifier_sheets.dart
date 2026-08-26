import 'package:flutter/material.dart';

import 'package:lsb_legal_app/core/engines/semantic_engine/local_sentence_assembler.dart';
import 'package:lsb_legal_app/app/theme.dart';

/// Hojas para precisar una glosa sin salir de la pregunta.
///
/// Las dos existen por el mismo motivo: llevar a la persona a otra pantalla
/// completa para un dato de un toque rompe el hilo de lo que está contando.
/// Aquí el detalle se pide encima, se resuelve y se vuelve.

/// Cantidad de una unidad de tiempo: SEMANA → "2" → "hace dos semanas".
///
/// Sustituye a la zona de cantidad como pantalla propia. Solo 1-9: el 0 no es
/// una cantidad ("hace cero semanas" no significa nada) aunque sí sea un
/// dígito válido para deletrear un número de expediente.
Future<String?> mostrarSelectorCantidad(
  BuildContext context, {
  required String unidad,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cuántos/as $unidad?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var n = 1; n <= 9; n++)
                  _Tecla(
                    etiqueta: '$n',
                    onTap: () => Navigator.of(context).pop('$n'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Teclado dactilológico para el nombre propio de un lugar o la placa de un
/// vehículo. Devuelve las letras y dígitos como glosas sueltas, que es como
/// los espera el motor: `_joinSpelled` los reconstruye.
Future<List<String>?> mostrarTecladoDactilologico(
  BuildContext context, {
  required String titulo,
  required bool alfanumerico,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TecladoDactilologico(
      titulo: titulo,
      alfanumerico: alfanumerico,
    ),
  );
}

class _TecladoDactilologico extends StatefulWidget {
  final String titulo;
  final bool alfanumerico;
  const _TecladoDactilologico({required this.titulo, required this.alfanumerico});

  @override
  State<_TecladoDactilologico> createState() => _TecladoDactilologicoState();
}

class _TecladoDactilologicoState extends State<_TecladoDactilologico> {
  final _letras = <String>[];

  static const _abecedario = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  Widget build(BuildContext context) {
    final teclas = [
      ..._abecedario,
      if (widget.alfanumerico) ...['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            // Lo deletreado, siempre a la vista: sin esto no hay forma de
            // saber si una letra entró o se perdió el toque.
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
              ),
              child: Text(
                _letras.isEmpty ? 'Deletrea aquí' : _letras.join(),
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: _letras.isEmpty
                      ? AppTheme.lightText.withValues(alpha: 0.4)
                      : AppTheme.lightText,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in teclas)
                      _Tecla(
                        etiqueta: t,
                        onTap: () => setState(() => _letras.add(t)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _letras.isEmpty
                        ? null
                        : () => setState(_letras.removeLast),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Borrar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    // Confirmar sin nada equivale a omitir el detalle: es una
                    // salida válida, no todo el mundo recuerda el nombre.
                    onPressed: () =>
                        Navigator.of(context).pop(List<String>.from(_letras)),
                    child: Text(_letras.isEmpty ? 'Omitir' : 'Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onTap;
  const _Tecla({required this.etiqueta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 48 es el mínimo táctil accesible; estas teclas se pulsan deprisa y en
      // situaciones de tensión.
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(
          etiqueta,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Detalle que pide una glosa, o `null` si no pide ninguno.
///
/// Se consulta al elegir la tarjeta: la interfaz decide con esto si abre una
/// hoja o deja seguir.
({String titulo, bool alfanumerico})? detalleQuePide(String gloss) {
  final etiqueta = LocalSentenceAssembler.etiquetaDeDetalle(gloss);
  if (etiqueta == null) return null;
  return etiqueta == 'placa'
      ? (titulo: 'Deletrea la placa', alfanumerico: true)
      : (titulo: 'Deletrea el nombre de la $etiqueta', alfanumerico: false);
}
