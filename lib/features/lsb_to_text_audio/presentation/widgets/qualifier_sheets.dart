import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/amount_input_sheet.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/disambiguation_modal.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/entity_editor_sheets.dart';

import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/app/app_theme.dart';

/// Cuánto tiempo hace (o falta): teclado numérico nativo en vez de una
/// grilla fija de 1 a 9 — así admite cualquier cifra ("hace 15 días", "hace
/// 45 minutos"), no solo un dígito.
Future<String?> mostrarSelectorCantidad(
  BuildContext context, {
  required String unidad,
}) {
  final controlador = TextEditingController();
  const acento = AppTheme.brandPrimary;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final n = controlador.text.trim();
        final preview = n.isEmpty ? null : 'Hace $n $unidad';

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cuántos/as $unidad?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controlador,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) => setModalState(() {}),
                  onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: unidad,
                    filled: true,
                    fillColor: AppTheme.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Atajos para las cifras más frecuentes; no reemplazan al
                // teclado, solo ahorran el tecleo en el caso común.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final valor in const [1, 2, 3, 5, 10, 15, 30])
                      _Tecla(
                        etiqueta: '$valor',
                        onTap: () => setModalState(
                            () => controlador.text = '$valor'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (preview != null) ...[
                  Text(
                    preview,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: acento,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: n.isEmpty
                      ? null
                      : () => Navigator.of(ctx).pop(n),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Confirmar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
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

  /// Caracteres que el avatar sabe deletrear.
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
    'numero' => (titulo: 'Escribe el número', alfanumerico: true, soloDigitos: false),
    'edad' => (titulo: '¿Qué edad tienes?', alfanumerico: true, soloDigitos: true),
    'carnet' => (titulo: 'Escribe tu número de carnet', alfanumerico: true, soloDigitos: false),
    'nombre' => (titulo: 'Deletrea tu nombre', alfanumerico: false, soloDigitos: false),
    'apellido' => (titulo: 'Deletrea tu apellido', alfanumerico: false, soloDigitos: false),
    _ => (titulo: 'Deletrea el nombre de la $etiqueta', alfanumerico: false, soloDigitos: false),
  };
}

/// Zonas estructuradas cuyas respuestas son entidades con relaciones
/// propias (persona↔prenda↔color, objeto↔papel, lugar↔referencia).
const _zonasDeEntidad = {'persona', 'objetos', 'lugar'};

Future<void> elegirGlosa(
  BuildContext context,
  WidgetRef ref,
  LsbCard card,
) async {
  final gloss = card.gloss.toUpperCase();
  final zonesNotifier = ref.read(semanticZonesProvider.notifier);
  final zoneId = ref.read(semanticZonesProvider).activeZoneId;

  // 1. Desambiguación Obligatoria de Verbos y Hechos
  if (gloss == 'ESCAPAR') {
    await DisambiguationModal.desambiguarEscapar(context, ref);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  if (gloss == 'PERDER') {
    await DisambiguationModal.desambiguarPerderVsRobar(context, ref);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  // 2. Desambiguación de Objetos y Lugares Específicos
  if (gloss == 'PAPEL') {
    await DisambiguationModal.desambiguarPapel(context, ref);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  if (gloss == 'IDENTIDAD') {
    await DisambiguationModal.desambiguarIdentidad(context, ref);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  // ESCRIBIR es el "otro / escribe qué es" de una pregunta de opción
  // múltiple (evidencia, etc.): sin este despacho quedaba como una glosa
  // más sin abrir nada, así que lo que se quería nombrar libremente nunca
  // se registraba.
  if (gloss == 'ESCRIBIR') {
    final texto = await mostrarTecladoTextoLibre(
      context,
      titulo: '¿Qué otro elemento tienes?',
      hint: 'Ej: un recibo, una nota, un audio guardado',
    );
    if (texto == null || texto.isEmpty) return;
    zonesNotifier.toggleAnswer(card.gloss);
    zonesNotifier.appendQualifiers(card.gloss, [texto]);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  // MOCHILA es contenedor en la zona de objetos (pide qué llevaba dentro) y
  // prenda/accesorio en la zona de persona (pide color, vía el wizard de
  // abajo): la misma glosa tiene un papel distinto según qué se describe.
  if (gloss == 'CAJA' || gloss == 'BOLSA' || (gloss == 'MOCHILA' && zoneId != 'persona')) {
    await DisambiguationModal.desambiguarCajaBolsa(context, ref, gloss);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  if (gloss == 'MICRO' || gloss == 'TRUFI') {
    await DisambiguationModal.desambiguarTransporteVehiculo(context, ref, gloss);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  if (gloss == 'BILLETES' || gloss == 'DINERO') {
    await mostrarEditorMontoDinero(context, ref);
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  // 3. Editores de Entidad (Personas / Objetos / Lugar)
  if (_zonasDeEntidad.contains(zoneId)) {
    switch (zoneId) {
      case 'persona':
        await mostrarEditorPersona(context, ref, card);
        break;
      case 'objetos':
        await mostrarEditorObjeto(context, ref, card);
        break;
      case 'lugar':
        await mostrarEditorLugar(context, ref, card);
        break;
    }
    zonesNotifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(zonesNotifier.orderedGlosses());
    return;
  }

  final notifier = zonesNotifier;
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
