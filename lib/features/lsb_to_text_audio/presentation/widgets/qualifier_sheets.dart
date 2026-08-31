import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/app/app_theme.dart';

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

Future<List<String>?> mostrarTecladoDactilologico(
  BuildContext context, {
  required String titulo,
  required bool alfanumerico,
  bool soloDigitos = false,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TecladoDactilologico(
      titulo: titulo,
      alfanumerico: alfanumerico,
      soloDigitos: soloDigitos,
    ),
  );
}

class _TecladoDactilologico extends StatefulWidget {
  final String titulo;
  final bool alfanumerico;
  final bool soloDigitos;

  const _TecladoDactilologico({
    required this.titulo,
    required this.alfanumerico,
    this.soloDigitos = false,
  });

  @override
  State<_TecladoDactilologico> createState() => _TecladoDactilologicoState();
}

class _TecladoDactilologicoState extends State<_TecladoDactilologico> {
  final _controlador = TextEditingController();

  /// Caracteres que el avatar sabe deletrear. Lo que se escriba fuera de aqui
  /// no se puede signar, asi que no se deja entrar.
  static final _permitidoTexto = RegExp(r'[A-Za-z0-9ÑñÁÉÍÓÚáéíóúÜü ]');
  static final _permitidoLetras = RegExp(r'[A-Za-zÑñÁÉÍÓÚáéíóúÜü ]');
  static final _permitidoDigitos = RegExp(r'[0-9]');

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  RegExp get _permitido {
    if (widget.soloDigitos) return _permitidoDigitos;
    return widget.alfanumerico ? _permitidoTexto : _permitidoLetras;
  }

  /// Convierte lo escrito en la lista de letras que se deletrea.
  ///
  /// Cada caracter es una sena: los espacios no se signan y se descartan, y
  /// las tildes se quitan porque el alfabeto dactilologico no las tiene —pero
  /// la N con virgulilla si es una letra propia y se conserva.
  static List<String> letrasDe(String texto) {
    const con = 'ÁÉÍÓÚÜáéíóúü';
    const sin = 'AEIOUUAEIOUU';
    final buffer = StringBuffer();
    for (final char in texto.toUpperCase().trim().split('')) {
      final i = con.indexOf(char);
      buffer.write(i >= 0 ? sin[i] : char);
    }
    return buffer
        .toString()
        .split('')
        .where((c) => c.trim().isNotEmpty)
        .toList();
  }

  void _confirmar() {
    Navigator.of(context).pop(letrasDe(_controlador.text));
  }

  @override
  Widget build(BuildContext context) {
    final letras = letrasDe(_controlador.text);

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
            const SizedBox(height: 14),
            TextField(
              controller: _controlador,
              // Se abre el teclado del telefono al aparecer la hoja: es el
              // teclado que la persona ya sabe usar.
              autofocus: true,
              keyboardType: widget.soloDigitos
                  ? TextInputType.number
                  : TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirmar(),
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.allow(_permitido),
                LengthLimitingTextInputFormatter(40),
              ],
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: widget.soloDigitos ? 'Escribe el número' : 'Escribe aquí',
                filled: true,
                fillColor: AppTheme.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _controlador.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        tooltip: 'Borrar',
                        onPressed: () => setState(_controlador.clear),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // Se muestra como quedara deletreado, que es lo que el avatar hara
            // seña a seña: sin esto no hay forma de saber que la frase se
            // convierte en letras sueltas.
            SizedBox(
              height: 22,
              child: letras.isEmpty
                  ? null
                  : Text(
                      'Se deletreará: ${letras.join(' · ')}',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightText.withValues(alpha: 0.6),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _confirmar,
              child: Text(letras.isEmpty ? 'Omitir' : 'Confirmar'),
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

({String titulo, bool alfanumerico, bool soloDigitos})? detalleQuePide(String gloss) {
  final etiqueta = LocalSentenceAssembler.etiquetaDeDetalle(gloss);
  if (etiqueta == null) return null;
  return switch (etiqueta) {
    'placa' => (titulo: 'Deletrea la placa', alfanumerico: true, soloDigitos: false),
    'numero' => (titulo: 'Escribe el número de tu caso', alfanumerico: true, soloDigitos: false),
    'edad' => (titulo: '¿Qué edad tienes?', alfanumerico: true, soloDigitos: true),
    'carnet' => (titulo: 'Escribe tu número de carnet', alfanumerico: true, soloDigitos: false),
    'nombre' => (titulo: 'Deletrea tu nombre', alfanumerico: false, soloDigitos: false),
    'apellido' => (titulo: 'Deletrea tu apellido', alfanumerico: false, soloDigitos: false),
    _ => (titulo: 'Deletrea el nombre de la $etiqueta', alfanumerico: false, soloDigitos: false),
  };
}

Future<void> elegirGlosa(
  BuildContext context,
  WidgetRef ref,
  LsbCard card,
) async {
  final notifier = ref.read(semanticZonesProvider.notifier);
  final yaEstaba = notifier.activeAnswersOf(card.gloss);

  notifier.toggleAnswer(card.gloss);
  ref.read(sentenceProvider.notifier).setWords(notifier.orderedGlosses());
  if (yaEstaba) return;

  final unidad = notifier.unidadTemporalDe(card.gloss);
  if (unidad != null) {
    final n = await mostrarSelectorCantidad(context, unidad: unidad);
    if (n != null) notifier.appendQualifiers(card.gloss, [n]);
  } else {
    final pide = detalleQuePide(card.gloss);
    if (pide != null) {
      final letras = await mostrarTecladoDactilologico(
        context,
        titulo: pide.titulo,
        alfanumerico: pide.alfanumerico,
        soloDigitos: pide.soloDigitos,
      );
      if (letras != null && letras.isNotEmpty) {
        notifier.appendQualifiers(card.gloss, letras);
      }
    }
  }
  ref.read(sentenceProvider.notifier).setWords(notifier.orderedGlosses());
}
