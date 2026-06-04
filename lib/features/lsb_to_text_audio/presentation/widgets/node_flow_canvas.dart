import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';
import 'context_path_indicator.dart';
import 'suggested_gloss_panel.dart';

/// Canvas del flujo de nodos — contenedor principal de la nueva experiencia
/// de construcción progresiva de significado.
///
/// Integra ContextPathIndicator (breadcrumb + zonas) y SuggestedGlossPanel
/// (nodos semánticos) con transición animada al cambiar de zona.
class NodeFlowCanvas extends ConsumerWidget {
  const NodeFlowCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(zonesState.activeZoneId),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ContextPathIndicator(),
          SuggestedGlossPanel(),
        ],
      ),
    );
  }
}
