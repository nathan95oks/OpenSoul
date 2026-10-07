import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/case_search.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/case_search_provider.dart';

/// Búsquedas para empezar, cuando el buscador está abierto y vacío. Todas
/// llevan a algún caso (lo comprueba una prueba).
const kCaseSearchSuggestions = [
  'Robo',
  'Violencia',
  'Cédula',
  'Certificado',
  'Estafa',
  'Intérprete',
  'Audiencia',
];

/// La barra del buscador, como la del sistema: una cápsula que al tocarla se
/// enciende en violeta, cambia la lupa por una flecha para salir y muestra
/// la × para borrar mientras hay texto. Lo escrito siempre se puede editar.
class CaseSearchBar extends ConsumerStatefulWidget {
  final FocusNode focusNode;

  /// Enter en el teclado: abrir el primer resultado.
  final VoidCallback? onSubmitted;

  const CaseSearchBar({super.key, required this.focusNode, this.onSubmitted});

  @override
  ConsumerState<CaseSearchBar> createState() => _CaseSearchBarState();
}

class _CaseSearchBarState extends ConsumerState<CaseSearchBar> {
  late final TextEditingController _texto = TextEditingController(
    text: ref.read(caseSearchQueryProvider),
  );

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_alCambiarFoco);
    _texto.dispose();
    super.dispose();
  }

  void _alCambiarFoco() => setState(() {});

  /// Sale del buscador: borra y cierra el teclado.
  void _salir() {
    ref.read(caseSearchQueryProvider.notifier).clear();
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Lo que cambia desde fuera (una sugerencia, salir) llega al campo, con
    // el cursor al final para seguir escribiendo.
    ref.listen(caseSearchQueryProvider, (_, query) {
      if (_texto.text == query) return;
      _texto.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    });
    final query = ref.watch(caseSearchQueryProvider);
    final activo = widget.focusNode.hasFocus || query.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 54,
      decoration: BoxDecoration(
        color: activo ? AppTheme.pageBg : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: activo ? AppTheme.lsbViolet : AppTheme.lightBorder,
          width: activo ? 2 : 1.2,
        ),
        boxShadow: activo
            ? [
                BoxShadow(
                  color: AppTheme.lsbViolet.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // La lupa gira hasta ser la flecha para salir.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.6, end: 1).animate(anim),
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: activo
                ? IconButton(
                    key: const Key('buscador_salir'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.lsbVioletDeep,
                    ),
                    tooltip: 'Cerrar la búsqueda',
                    onPressed: _salir,
                  )
                : IconButton(
                    key: const Key('buscador_lupa'),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.lightTextSub,
                    ),
                    tooltip: 'Buscar',
                    onPressed: widget.focusNode.requestFocus,
                  ),
          ),
          Expanded(
            child: TextField(
              key: const Key('buscador_campo'),
              controller: _texto,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  CaseSearchQueryNotifier.maxLength,
                ),
              ],
              cursorColor: AppTheme.lightInputCursor,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightInputText,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Busca: robo, cédula…',
                hintStyle: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.lightInputHint,
                ),
              ),
              onChanged: ref.read(caseSearchQueryProvider.notifier).set,
              onSubmitted: (_) => widget.onSubmitted?.call(),
            ),
          ),
          // La × aparece con el texto y lo borra sin cerrar el teclado.
          AnimatedScale(
            scale: query.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: query.isEmpty ? Curves.easeIn : Curves.easeOutBack,
            child: IconButton(
              key: const Key('buscador_borrar'),
              icon: const Icon(
                Icons.close_rounded,
                color: AppTheme.lightTextSub,
              ),
              tooltip: 'Borrar',
              onPressed: query.isEmpty
                  ? null
                  : () {
                      ref.read(caseSearchQueryProvider.notifier).clear();
                      widget.focusNode.requestFocus();
                    },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Chips de búsquedas para empezar: llenan el buscador, que sigue editable.
class CaseSearchSuggestions extends ConsumerWidget {
  const CaseSearchSuggestions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      key: const Key('buscador_sugerencias'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulito('Prueba con'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, s) in kCaseSearchSuggestions.indexed)
              BubbleEntrance(
                index: i,
                child: BubblePress(
                  child: ActionChip(
                    key: Key('buscador_sugerencia_$s'),
                    avatar: const Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: AppTheme.lsbViolet,
                    ),
                    label: Text(s),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.lightText,
                    ),
                    backgroundColor: AppTheme.lightSurface,
                    side: const BorderSide(color: AppTheme.glossCardBorder),
                    shape: const StadiumBorder(),
                    onPressed: () =>
                        ref.read(caseSearchQueryProvider.notifier).set(s),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Los resultados: un grupo por familia o institución, que aparecen y se
/// van a medida que la búsqueda se afina.
class CaseSearchResults extends ConsumerWidget {
  final ValueChanged<CaseSearchHit> onOpen;

  const CaseSearchResults({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(caseSearchQueryProvider);
    final grupos = ref.watch(caseSearchResultsProvider);
    final hayResultados = grupos.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: bubbleSwitcherTransition,
      layoutBuilder: (actual, anteriores) => Stack(
        alignment: Alignment.topCenter,
        children: [...anteriores, ?actual],
      ),
      child: hayResultados
          ? AnimatedFilterList(
              key: const Key('buscador_resultados'),
              children: [
                for (final g in grupos)
                  _Grupo(
                    key: ValueKey('buscador_grupo_${g.id}'),
                    grupo: g,
                    query: query,
                    onOpen: onOpen,
                  ),
              ],
            )
          : _SinResultados(key: const Key('buscador_vacio'), query: query),
    );
  }
}

class _Titulito extends StatelessWidget {
  final String texto;
  const _Titulito(this.texto);

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
      color: AppTheme.lightTextSub,
    ),
  );
}

class _Grupo extends StatelessWidget {
  final CaseSearchGroup grupo;
  final String query;
  final ValueChanged<CaseSearchHit> onOpen;

  const _Grupo({
    super.key,
    required this.grupo,
    required this.query,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(grupo.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Flexible(child: _Titulito(grupo.name)),
                const SizedBox(width: 8),
                // Cuántos quedan en el grupo, cambia con la búsqueda.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Container(
                    key: ValueKey(grupo.hits.length),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lsbViolet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${grupo.hits.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lsbVioletDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.lightBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedFilterList(
              children: [
                for (final (i, h) in grupo.hits.indexed)
                  _Fila(
                    key: ValueKey(
                      'buscador_${h.entry.kind.name}_${h.entry.id}',
                    ),
                    hit: h,
                    query: query,
                    separada: i > 0,
                    onTap: () => onOpen(h),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final CaseSearchHit hit;
  final String query;
  final bool separada;
  final VoidCallback onTap;

  const _Fila({
    super.key,
    required this.hit,
    required this.query,
    required this.separada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = hit.entry;
    final snippet = hit.snippet;
    final esCaso = e.kind == CaseHitKind.context;
    return Semantics(
      button: true,
      label: [
        e.title,
        e.subtitle,
        if (snippet != null) 'Incluye: $snippet',
        if (!esCaso) 'Abre la lista',
      ].join('. '),
      excludeSemantics: true,
      child: BubblePress(
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: separada
                  ? const Border(top: BorderSide(color: AppTheme.lightBorder))
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: Row(
              children: [
                Text(e.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HighlightedText(
                        e.title,
                        query: query,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightText,
                        ),
                      ),
                      if (e.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        HighlightedText(
                          e.subtitle,
                          query: query,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: AppTheme.lightTextSub,
                          ),
                        ),
                      ],
                      // Se encontró por lo que se pregunta o responde dentro
                      // del caso: esa frase, para saber por qué aparece.
                      if (snippet != null) ...[
                        const SizedBox(height: 5),
                        HighlightedText(
                          '«$snippet»',
                          query: query,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                            color: AppTheme.lsbVioletDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  esCaso
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.chevron_right_rounded,
                  size: esCaso ? 14 : 22,
                  color: AppTheme.lightTextSub,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  final String query;
  const _SinResultados({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lsbViolet.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: AppTheme.lsbVioletDeep,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No encontramos «${query.trim()}»',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Prueba con otra palabra o corrige lo escrito.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightTextSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const CaseSearchSuggestions(),
        ],
      ),
    );
  }
}

/// [text] con las palabras de [query] resaltadas en violeta.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    required this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final rangos = CaseSearch.highlights(text, query);
    final resaltado = style.copyWith(
      color: AppTheme.lsbVioletDeep,
      fontWeight: FontWeight.w800,
      backgroundColor: AppTheme.lsbViolet.withValues(alpha: 0.14),
    );
    final partes = <TextSpan>[];
    var i = 0;
    for (final (inicio, fin) in rangos) {
      if (inicio >= text.length) break;
      final hasta = fin.clamp(inicio, text.length);
      if (inicio > i) partes.add(TextSpan(text: text.substring(i, inicio)));
      partes.add(
        TextSpan(text: text.substring(inicio, hasta), style: resaltado),
      );
      i = hasta;
    }
    if (i < text.length) partes.add(TextSpan(text: text.substring(i)));
    return Text.rich(
      TextSpan(style: style, children: partes),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Una columna que anima lo que entra y lo que sale cuando cambian sus
/// [children] (cada uno con su `key`): lo nuevo se abre y aparece, lo que ya
/// no está se cierra y se desvanece, y lo que sigue se queda en su lugar.
/// Así el buscador filtra «poco a poco», sin saltos.
class AnimatedFilterList extends StatefulWidget {
  final List<Widget> children;

  const AnimatedFilterList({super.key, required this.children});

  @override
  State<AnimatedFilterList> createState() => _AnimatedFilterListState();
}

class _Lugar {
  final Key key;
  Widget child;
  final AnimationController animacion;
  bool saliendo = false;

  _Lugar(this.key, this.child, this.animacion);
}

class _AnimatedFilterListState extends State<AnimatedFilterList>
    with TickerProviderStateMixin {
  static const _entrada = Duration(milliseconds: 280);
  static const _salida = Duration(milliseconds: 200);

  final List<_Lugar> _lugares = [];

  @override
  void initState() {
    super.initState();
    for (final c in widget.children) {
      _lugares.add(_nuevo(c));
    }
  }

  _Lugar _nuevo(Widget child) {
    final lugar = _Lugar(
      child.key!,
      child,
      AnimationController(
        vsync: this,
        duration: _entrada,
        reverseDuration: _salida,
      ),
    );
    lugar.animacion
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.dismissed && lugar.saliendo && mounted) {
          setState(() => _lugares.remove(lugar));
          lugar.animacion.dispose();
        }
      })
      ..forward();
    return lugar;
  }

  @override
  void didUpdateWidget(AnimatedFilterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevos = {for (final c in widget.children) c.key!: c};
    final antes = {for (final l in _lugares) l.key: l};

    // Lo que ya no está, se va desde su lugar.
    for (final l in _lugares) {
      if (!nuevos.containsKey(l.key) && !l.saliendo) {
        l.saliendo = true;
        l.animacion.reverse();
      }
    }

    // El orden nuevo; lo que se va queda detrás del que tenía delante.
    final orden = <_Lugar>[];
    for (final c in widget.children) {
      final l = antes[c.key!];
      if (l == null) {
        orden.add(_nuevo(c));
      } else {
        l.child = c;
        if (l.saliendo) {
          l.saliendo = false;
          l.animacion.forward();
        }
        orden.add(l);
      }
    }
    for (var i = 0; i < _lugares.length; i++) {
      final l = _lugares[i];
      if (!l.saliendo) continue;
      final previo = i == 0 ? null : _lugares[i - 1];
      final donde = previo == null ? 0 : orden.indexOf(previo) + 1;
      orden.insert(donde.clamp(0, orden.length), l);
    }
    _lugares
      ..clear()
      ..addAll(orden);
  }

  @override
  void dispose() {
    for (final l in _lugares) {
      l.animacion.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in _lugares)
          // Su propia llave (no la del hijo): una prueba que busca la fila
          // por su llave la encuentra una sola vez.
          KeyedSubtree(
            key: ValueKey<Key>(l.key),
            child: _Animado(animacion: l.animacion, child: l.child),
          ),
      ],
    );
  }
}

class _Animado extends StatelessWidget {
  final Animation<double> animacion;
  final Widget child;

  const _Animado({required this.animacion, required this.child});

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(
      parent: animacion,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curva,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curva,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curva),
          child: child,
        ),
      ),
    );
  }
}
