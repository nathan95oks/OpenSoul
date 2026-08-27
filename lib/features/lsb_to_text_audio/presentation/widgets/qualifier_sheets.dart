import 'package:flutter/material.dart';
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
  final _letras = <String>[];

  static const _abecedario = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  Widget build(BuildContext context) {
    const digitos = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    final teclas = widget.soloDigitos
        ? digitos
        : [..._abecedario, if (widget.alfanumerico) ...digitos];

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
