import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Explica qué es cada palabra de [glosses] que no tiene seña propia en los
/// módulos M1–M4.
///
/// Se abre donde se esperaría la seña: al deslizar una fila o tocar una
/// palabra en azul. Una palabra con seña se hace en el avatar; una sin seña
/// no se inventa: se explica. No hace nada si ninguna glosa es pendiente.
/// Una palabra en azul dentro de la descripción también se toca: abre la
/// suya encima, y así.
Future<void> showPendingSignInfo(
  BuildContext context,
  FutureOr<PendingSignCatalog> catalogo,
  List<String> glosses,
) async {
  if (!glosses.any(PendingSign.isPending)) return;
  PendingSignCatalog catalog;
  try {
    // Viene empaquetado con la app: la primera vez solo hay que leerlo.
    catalog = await catalogo;
  } catch (_) {
    catalog = PendingSignCatalog.empty;
  }
  if (!context.mounted) return;
  final infos = [
    for (final g in glosses.where(PendingSign.isPending).toSet())
      catalog.infoOf(g),
  ];
  if (infos.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.pageBg,
    builder: (_) => PendingSignInfoSheet(infos: infos, catalog: catalog),
  );
}

class PendingSignInfoSheet extends StatelessWidget {
  final List<PendingSignInfo> infos;

  /// De dónde salen las descripciones de las palabras en azul de cada
  /// descripción. Sin él, esas palabras no se pueden tocar.
  final PendingSignCatalog? catalog;

  const PendingSignInfoSheet({super.key, required this.infos, this.catalog});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          key: const Key('info_sin_sena'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, info) in infos.indexed) ...[
                if (i > 0) const Divider(height: 32),
                PendingSignInfoView(info: info, catalog: catalog),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Qué es una palabra sin seña: su nombre en azul, que no tiene seña y su
/// descripción en señas. La misma vista se usa en la hoja «¿Qué es?» de las
/// tarjetas y en la pantalla que tapa al avatar en el Traductor a LSB.
class PendingSignInfoView extends StatelessWidget {
  final PendingSignInfo info;
  final PendingSignCatalog? catalog;

  /// Muestra «Descripción provisional, por revisar.» si nadie la confirmó.
  final bool showReviewNote;

  const PendingSignInfoView({
    super.key,
    required this.info,
    this.catalog,
    this.showReviewNote = true,
  });

  @override
  Widget build(BuildContext context) {
    // La hoja es blanca: el texto va oscuro siempre. Con el tema oscuro de
    // la app, el color por defecto era blanco y no se leía.
    final tema = Theme.of(context).textTheme.apply(
      bodyColor: AppTheme.lightText,
      displayColor: AppTheme.lightText,
    );
    final catalogo = catalog;
    final tocables =
        catalogo != null && info.lsbDescription.any(PendingSign.isPending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.word,
          style: tema.headlineSmall?.copyWith(
            color: AppTheme.pendingSign,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.sign_language_outlined,
              size: 18,
              color: AppTheme.lightTextSub,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                info.isProperName
                    ? 'Nombre propio: no tiene seña, se deletrea.'
                    : 'No tiene seña propia en los módulos M1–M4.',
                style: tema.bodySmall?.copyWith(color: AppTheme.lightTextSub),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '¿Qué es?',
          style: tema.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        // Explicada en LSB, con señas que la persona ya conoce; el español
        // solo mientras no esté traducida.
        if (info.lsbDescription.isNotEmpty)
          LsbDescriptionText(
            glosses: info.lsbDescription,
            style: tema.titleMedium,
            onPendingTap: catalogo == null
                ? null
                : (g) => showPendingSignInfo(context, catalogo, [g]),
          )
        else
          Text(
            info.description.isEmpty
                ? 'Todavía no tiene descripción.'
                : info.description,
            style: tema.bodyLarge,
          ),
        if (tocables) ...[
          const SizedBox(height: 4),
          Text(
            'Toque una palabra en azul para ver qué es.',
            style: tema.bodySmall?.copyWith(color: AppTheme.lightTextSub),
          ),
        ],
        if (showReviewNote &&
            info.description.isNotEmpty &&
            !info.reviewed) ...[
          const SizedBox(height: 10),
          Text(
            'Descripción provisional, por revisar.',
            style: tema.bodySmall?.copyWith(color: AppTheme.lightTextSub),
          ),
        ],
      ],
    );
  }
}

/// Una descripción en glosas LSB: las señas en oscuro y, en azul, las
/// palabras que tampoco tienen seña. Con [onPendingTap], cada palabra en
/// azul se toca (va subrayada) para ver qué es.
class LsbDescriptionText extends StatefulWidget {
  final List<String> glosses;
  final TextStyle? style;

  /// Fondo oscuro (el bloque delante del avatar): señas en claro y el azul
  /// que se lee sobre oscuro.
  final bool onDark;
  final ValueChanged<String>? onPendingTap;

  const LsbDescriptionText({
    super.key,
    required this.glosses,
    this.style,
    this.onDark = false,
    this.onPendingTap,
  });

  @override
  State<LsbDescriptionText> createState() => _LsbDescriptionTextState();
}

class _LsbDescriptionTextState extends State<LsbDescriptionText> {
  final List<TapGestureRecognizer> _toques = [];

  @override
  void dispose() {
    _soltarToques();
    super.dispose();
  }

  void _soltarToques() {
    for (final t in _toques) {
      t.dispose();
    }
    _toques.clear();
  }

  TapGestureRecognizer? _toque(String gloss) {
    final onTap = widget.onPendingTap;
    if (onTap == null) return null;
    final t = TapGestureRecognizer()..onTap = () => onTap(gloss);
    _toques.add(t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    _soltarToques();
    final tinta = widget.onDark ? Colors.white : AppTheme.lightText;
    final tenue = widget.onDark ? Colors.white60 : AppTheme.lightTextSub;
    final azul = widget.onDark
        ? AppTheme.pendingSignOnDark
        : AppTheme.pendingSign;
    final base = (widget.style ?? const TextStyle(fontSize: 16)).copyWith(
      color: tinta,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      height: 1.4,
    );
    return Text.rich(
      key: const Key('descripcion_lsb'),
      TextSpan(
        children: [
          for (final (i, g) in widget.glosses.indexed) ...[
            if (i > 0)
              TextSpan(
                text: ' · ',
                style: base.copyWith(color: tenue),
              ),
            PendingSign.isPending(g)
                ? TextSpan(
                    text: PendingSign.wordOf(g),
                    style: base.copyWith(
                      color: azul,
                      decoration: widget.onPendingTap == null
                          ? null
                          : TextDecoration.underline,
                      decorationColor: azul,
                    ),
                    recognizer: _toque(g),
                  )
                : TextSpan(text: g.replaceAll('_', ' ')),
          ],
        ],
      ),
      style: base,
    );
  }
}
