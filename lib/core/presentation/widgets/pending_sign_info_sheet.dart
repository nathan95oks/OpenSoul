import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Explica qué es cada palabra de [glosses] que no tiene seña propia en los
/// módulos M1–M4 ni en el II Diccionario 2024.
///
/// Se abre donde se esperaría la seña: al deslizar una fila o tocar una
/// palabra en azul. Una palabra con seña se hace en el avatar; una sin seña
/// no se inventa: se explica. No hace nada si ninguna glosa es pendiente.
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
    builder: (_) => PendingSignInfoSheet(infos: infos),
  );
}

class PendingSignInfoSheet extends StatelessWidget {
  final List<PendingSignInfo> infos;

  const PendingSignInfoSheet({super.key, required this.infos});

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
                _Palabra(info: info),
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

class _Palabra extends StatelessWidget {
  final PendingSignInfo info;

  const _Palabra({required this.info});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
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
                    : 'No tiene seña propia en los módulos M1–M4 ni en el '
                          'II Diccionario LSB–Castellano 2024.',
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
        Text(
          info.description.isEmpty
              ? 'Todavía no tiene descripción.'
              : info.description,
          style: tema.bodyLarge,
        ),
        if (info.example.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'En el trámite',
            style: tema.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '«${info.example}»',
            style: tema.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        if (info.description.isNotEmpty && !info.reviewed) ...[
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
