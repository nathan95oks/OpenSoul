import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/case_search.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/case_search_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/case_search_view.dart';

class ContextSelectionWidget extends ConsumerStatefulWidget {
  const ContextSelectionWidget({super.key});

  @override
  ConsumerState<ContextSelectionWidget> createState() =>
      _ContextSelectionWidgetState();
}

class _ContextSelectionWidgetState
    extends ConsumerState<ContextSelectionWidget> {
  ContextFamily? _abierta;

  /// El foco del buscador: con él (o con algo escrito) la búsqueda manda.
  final FocusNode _buscador = FocusNode();

  final ScrollController _scroll = ScrollController();

  /// Qué lista se ve (familia, institución, búsqueda): si cambia, la vista
  /// vuelve arriba, al título o a los primeros resultados.
  String? _vista;

  /// La familia que pidió Conversation («¿Quiere denunciar algo?» abre
  /// Denuncias). La persona puede volver a la lista general igual.
  static ContextFamily? _familiaDe(CardsFlowLaunch launch) =>
      _familiaPorId(launch.focusedFamilyId);

  static ContextFamily? _familiaPorId(String? id) {
    if (id == null) return null;
    for (final f in contextFamilies) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _buscador.addListener(() {
      if (mounted) setState(() {});
    });
    // Al volver de un contexto con la flecha, la lista de su familia sigue
    // abierta (Denuncias → Denunciar robo → ← vuelve a Denuncias).
    _abierta =
        _familiaPorId(ref.read(openFamilyProvider)) ??
        _familiaDe(ref.read(cardsFlowLaunchProvider));
    // La familia que abrió la conversación también cuenta como abierta (la
    // barra superior oculta su flecha); se anota tras el primer cuadro.
    final abierta = _abierta;
    if (abierta != null && ref.read(openFamilyProvider) != abierta.id) {
      Future.microtask(() {
        if (mounted) ref.read(openFamilyProvider.notifier).open(abierta.id);
      });
    }
  }

  @override
  void dispose() {
    _buscador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Abre lo que se tocó en el buscador. Un caso entra directo y deja la
  /// búsqueda escrita (al volver con la flecha sigue ahí); una familia o
  /// una institución abre su lista, como si se hubiera tocado en el menú.
  void _abrirResultado(CaseSearchHit hit) {
    _buscador.unfocus();
    final e = hit.entry;
    switch (e.kind) {
      case CaseHitKind.context:
        ref.read(contextProvider.notifier).setContext(e.context!);
      case CaseHitKind.family:
        ref.read(caseSearchQueryProvider.notifier).clear();
        final contextos = contextsOfFamily(e.family!);
        if (contextos.length == 1) {
          ref.read(contextProvider.notifier).setContext(contextos.first);
        } else {
          _abrir(e.family);
        }
      case CaseHitKind.section:
        ref.read(caseSearchQueryProvider.notifier).clear();
        final tramites = _familiaPorId(e.familyId);
        if (tramites != null) _abrir(tramites);
        ref.read(openSectionProvider.notifier).open(e.id);
    }
  }

  /// Enter en el teclado: el primer resultado.
  void _abrirPrimero() {
    final grupos = ref.read(caseSearchResultsProvider);
    if (grupos.isEmpty) return;
    // Primero un caso (es lo directo); si no hay, la primera sección.
    final casos = [
      for (final g in grupos)
        for (final h in g.hits)
          if (h.entry.kind == CaseHitKind.context) h,
    ];
    _abrirResultado(casos.isNotEmpty ? casos.first : grupos.first.hits.first);
  }

  Widget _familyButton(ContextFamily f, String? highlightedId) => _FamilyButton(
    family: f,
    highlighted: highlightedId != null && f.contextIds.contains(highlightedId),
    onTap: () {
      final contextos = contextsOfFamily(f);
      if (contextos.length == 1) {
        ref.read(contextProvider.notifier).setContext(contextos.first);
      } else {
        _abrir(f);
      }
    },
  );

  /// Una institución de Trámites: se abre como una familia más.
  Widget _sectionButton(ContextFamily s, String? highlightedId) =>
      _FamilyButton(
        family: s,
        highlighted:
            highlightedId != null && s.contextIds.contains(highlightedId),
        onTap: () => ref.read(openSectionProvider.notifier).open(s.id),
      );

  void _abrir(ContextFamily? familia) {
    setState(() => _abierta = familia);
    final recordada = ref.read(openFamilyProvider.notifier);
    familia == null ? recordada.clear() : recordada.open(familia.id);
  }

  @override
  Widget build(BuildContext context) {
    // La flecha de la barra superior cierra la familia abierta.
    ref.listen(openFamilyProvider, (_, id) {
      if (id == null && _abierta != null) setState(() => _abierta = null);
    });
    ref.listen(cardsFlowLaunchProvider, (anterior, launch) {
      if (anterior?.sameErrand(launch) ?? false) return;
      ref.read(caseSearchQueryProvider.notifier).clear();
      _abrir(_familiaDe(launch));
    });
    final query = ref.watch(caseSearchQueryProvider);
    final buscando = query.trim().isNotEmpty;
    final activo = buscando || _buscador.hasFocus;
    final pending = ref.watch(pendingReplyProvider);
    final suggestion = pending?.suggestion;
    final highlightedId = pending?.proposedContextId;
    final familia = _abierta;
    final seccion = familia == null
        ? null
        : RagTramites.sectionById(ref.watch(openSectionProvider));
    // Trámites se ordena por institución: primero sus contextos propios
    // (Identificación) y las instituciones; dentro de una, sus trámites.
    final porSecciones = familia?.id == 'tramites';
    final desplegados = familia == null
        ? const <SemanticContext>[]
        : seccion != null
        ? [
            for (final id in seccion.contextIds)
              if (contextById(id) != null) contextById(id)!,
          ]
        : porSecciones
        ? [
            for (final id in familia.contextIds)
              if (contextById(id) != null) contextById(id)!,
          ]
        : contextsOfFamily(familia);

    final lista = Column(
      key: const ValueKey('lista'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (familia == null)
          ...contextFamilies.indexed.map(
            (e) => BubbleEntrance(
              key: ValueKey('menu_${e.$2.id}'),
              index: e.$1,
              child: _familyButton(e.$2, highlightedId),
            ),
          )
        else ...[
          ...desplegados.indexed.map(
            (e) => BubbleEntrance(
              key: ValueKey('${seccion?.id ?? familia.id}_${e.$2.id}'),
              index: e.$1,
              child: _ContextButton(
                context: e.$2,
                highlighted: e.$2.id == highlightedId,
                suggestion: e.$2.id == suggestion?.contextId
                    ? suggestion
                    : null,
              ),
            ),
          ),
          if (porSecciones && seccion == null)
            ...RagTramites.sections.indexed.map(
              (e) => BubbleEntrance(
                key: ValueKey(e.$2.id),
                index: desplegados.length + e.$1,
                child: _sectionButton(e.$2, highlightedId),
              ),
            ),
        ],
      ],
    );

    // Debajo de la barra: la lista de siempre, las sugerencias al abrir el
    // buscador vacío, o los resultados mientras se escribe.
    final debajo = buscando
        ? CaseSearchResults(
            key: const ValueKey('resultados'),
            onOpen: _abrirResultado,
          )
        : activo
        ? const CaseSearchSuggestions(key: ValueKey('sugerencias'))
        : lista;

    final vista = '${familia?.id}/${seccion?.id}/$buscando';
    if (_vista != null && vista != _vista) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _vista = vista;

    return PopScope(
      // El «atrás» del teléfono primero cierra la búsqueda.
      canPop: !activo,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(caseSearchQueryProvider.notifier).clear();
        _buscador.unfocus();
      },
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              // Al buscar, el encabezado se pliega y la barra sube: la
              // pantalla es de los resultados.
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: activo ? 0 : 1,
                  child: activo
                      ? const SizedBox(width: double.infinity, height: 12)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 36),
                            if (pending != null) ...[
                              _ReplyingToBanner(text: pending.question),
                              const SizedBox(height: 20),
                            ],
                            Text(
                              seccion != null
                                  ? seccion.name
                                  : pending != null
                                  ? '¿Desde qué contexto respondes?'
                                  : 'Selecciona el contexto',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.lightText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              seccion != null
                                  ? seccion.description
                                  : pending != null
                                  ? 'Puedes aceptar el contexto propuesto o elegir otro.'
                                  : '¿Qué necesitas hacer?',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.lightTextSub,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
          // La barra queda fija arriba al desplazar la lista.
          SliverPersistentHeader(
            pinned: true,
            delegate: _BarraFija(
              CaseSearchBar(focusNode: _buscador, onSubmitted: _abrirPrimero),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: bubbleSwitcherTransition,
                layoutBuilder: (actual, anteriores) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...anteriores, ?actual],
                ),
                child: debajo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La barra del buscador fija arriba, sobre el fondo de la página.
class _BarraFija extends SliverPersistentHeaderDelegate {
  final Widget barra;

  const _BarraFija(this.barra);

  static const _alto = 54.0 + 16;

  @override
  double get minExtent => _alto;

  @override
  double get maxExtent => _alto;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: AppTheme.lightBg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: barra,
    );
  }

  @override
  bool shouldRebuild(_BarraFija oldDelegate) => barra != oldDelegate.barra;
}

class _FamilyButton extends StatelessWidget {
  final ContextFamily family;
  final VoidCallback onTap;
  final bool highlighted;

  const _FamilyButton({
    required this.family,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: highlighted
          ? '${family.name}. ${family.description}. Sugerido para responder.'
          : '${family.name}. ${family.description}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BubblePress(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlighted
                      ? AppTheme.brandPrimary
                      : AppTheme.lightBorder,
                  width: highlighted ? 2 : 1,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Text(family.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          family.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.lightText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          family.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.lightTextSub,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.lightTextSub),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyingToBanner extends StatelessWidget {
  final String text;

  const _ReplyingToBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Respondiendo a: $text',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.brandPrimary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.brandPrimary.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.record_voice_over,
                  size: 14,
                  color: AppTheme.brandPrimary,
                ),
                SizedBox(width: 6),
                Text(
                  'RESPONDIENDO A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.brandPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '«$text»',
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppTheme.lightText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextButton extends ConsumerStatefulWidget {
  final SemanticContext context;
  final bool highlighted;
  final ContextSuggestion? suggestion;

  const _ContextButton({
    required this.context,
    this.highlighted = false,
    this.suggestion,
  });

  @override
  ConsumerState<_ContextButton> createState() => _ContextButtonState();
}

class _ContextButtonState extends ConsumerState<_ContextButton> {
  bool _hovered = false;

  static const _orange = AppTheme.brandPrimary;

  String? get _badge {
    if (!widget.highlighted) return null;
    return widget.suggestion != null ? 'SUGERIDO' : 'CONTEXTO ACTUAL';
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final evidence = widget.suggestion?.evidence ?? const <String>[];
    final active = _hovered || widget.highlighted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: [
          ?badge,
          '${widget.context.name}.',
          widget.context.description,
          if (evidence.isNotEmpty) 'Detectado: ${evidence.join(", ")}',
        ].join(' '),
        excludeSemantics: true,
        child: BubblePress(
          child: GestureDetector(
            onTapDown: (_) => setState(() => _hovered = true),
            onTapUp: (_) {
              setState(() => _hovered = false);
              ref.read(contextProvider.notifier).setContext(widget.context);
            },
            onTapCancel: () => setState(() => _hovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? _orange : AppTheme.lightBorder,
                  width: active ? 2 : 1.5,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Text(
                    widget.context.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.context.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: active ? _orange : AppTheme.lightText,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.context.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.lightTextSub,
                          ),
                        ),
                        if (evidence.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Detectado: ${evidence.join(" · ")}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: active ? _orange : AppTheme.lightTextSub,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
