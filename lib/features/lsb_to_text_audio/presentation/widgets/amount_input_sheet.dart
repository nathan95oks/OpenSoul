import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';

/// Modal Bottom Sheet accesible para captura de montos de dinero sustraídos o involucrados.
///
/// Ofrece:
/// - Teclado numérico táctil grande para digitar la cifra.
/// - Botones de montos rápidos predefinidos (50, 100, 200, 500, 1000, 2000 Bs.).
/// - Selector de moneda: Bolivianos (Bs.) o Dólares ($).
/// - Botón principal accesible de 56dp para confirmar.
/// - Opción para omitir o indicar que no se recuerda la cifra exacta.
Future<void> mostrarEditorMontoDinero(
  BuildContext context,
  WidgetRef ref, {
  String? existingObjectId,
  String initialRole = 'stolen',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AmountInputSheetContent(
      existingObjectId: existingObjectId,
      initialRole: initialRole,
    ),
  );
}

class _AmountInputSheetContent extends ConsumerStatefulWidget {
  final String? existingObjectId;
  final String initialRole;

  const _AmountInputSheetContent({
    this.existingObjectId,
    required this.initialRole,
  });

  @override
  ConsumerState<_AmountInputSheetContent> createState() =>
      _AmountInputSheetContentState();
}

class _AmountInputSheetContentState
    extends ConsumerState<_AmountInputSheetContent> {
  static const _orange = AppTheme.brandPrimary;
  final _controller = TextEditingController();
  String _moneda = 'bolivianos'; // 'bolivianos' o 'dólares'
  String _rol = 'stolen'; // 'stolen', 'lost', 'transferred'

  @override
  void initState() {
    super.initState();
    _rol = widget.initialRole;
    if (widget.existingObjectId != null) {
      final draft = ref.read(declarationDraftProvider);
      final obj = draft.objects.where((o) => o.id == widget.existingObjectId).firstOrNull;
      if (obj != null) {
        if (obj.quantity != null) _controller.text = obj.quantity!;
        if (obj.unit != null && obj.unit!.isNotEmpty) {
          _moneda = obj.unit!.toLowerCase().contains('dolar') || obj.unit == 'USD'
              ? 'dólares'
              : 'bolivianos';
        }
        _rol = obj.role;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _agregarDigito(String digito) {
    if (_controller.text.length >= 8) return;
    setState(() {
      _controller.text = '${_controller.text}$digito';
    });
  }

  void _borrarDigito() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _controller.text =
          _controller.text.substring(0, _controller.text.length - 1);
    });
  }

  void _limpiar() {
    setState(() {
      _controller.text = '';
    });
  }

  void _fijarMonto(int monto) {
    setState(() {
      _controller.text = monto.toString();
    });
  }

  void _confirmar() {
    final montoStr = _controller.text.trim();
    final notifier = ref.read(declarationDraftProvider.notifier);

    if (montoStr.isEmpty) {
      AppToastManager.showInfo(
          context, 'Digita una cifra o selecciona un monto rápido');
      return;
    }

    final displayMoneda = _moneda == 'dólares' ? 'USD (\$)' : 'Bs.';

    if (widget.existingObjectId != null) {
      notifier.setObjectDetail(
        widget.existingObjectId!,
        quantity: montoStr,
        unit: _moneda,
        role: _rol,
      );
      AppToastManager.showSuccess(
          context, 'Monto actualizado: $montoStr $displayMoneda');
    } else {
      notifier.addObject(
        concept: 'BILLETES',
        role: _rol,
        quantity: montoStr,
        unit: _moneda,
      );
      AppToastManager.showSuccess(
          context, 'Monto registrado: $montoStr $displayMoneda');
    }

    Navigator.of(context).pop();
  }

  void _omitir() {
    final notifier = ref.read(declarationDraftProvider.notifier);
    if (widget.existingObjectId == null) {
      notifier.addObject(
        concept: 'BILLETES',
        role: _rol,
        quantity: null,
        unit: _moneda,
      );
    }
    AppToastManager.showInfo(context, 'Monto exacto omitido');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final montoActual = _controller.text;
    final displayMoneda = _moneda == 'dólares' ? 'USD (\$)' : 'Bs.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título con Icono
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: _orange, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '¿Cuánto dinero fue?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Digita la cantidad aproximada o exacta del monto sustraído/entregado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.lightTextSub,
                ),
              ),

              const SizedBox(height: 16),

              // Selector de Moneda (Bolivianos / Dólares)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MonedaChip(
                    label: 'Bs. (Bolivianos)',
                    isSelected: _moneda == 'bolivianos',
                    onTap: () => setState(() => _moneda = 'bolivianos'),
                  ),
                  const SizedBox(width: 12),
                  _MonedaChip(
                    label: 'USD (\$)',
                    isSelected: _moneda == 'dólares',
                    onTap: () => setState(() => _moneda = 'dólares'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Visor Numérico Principal Grande
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: montoActual.isNotEmpty
                        ? _orange
                        : AppTheme.lightBorder,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      montoActual.isEmpty ? '0' : montoActual,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: montoActual.isEmpty
                            ? AppTheme.lightTextSub.withValues(alpha: 0.5)
                            : AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayMoneda,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Montos Rápidos Comunes
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in [50, 100, 200, 500, 1000, 2000, 5000]) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _fijarMonto(m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: montoActual == m.toString()
                                ? _orange.withValues(alpha: 0.15)
                                : AppTheme.lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: montoActual == m.toString()
                                  ? _orange
                                  : AppTheme.lightBorder,
                            ),
                          ),
                          child: Text(
                            '$m $displayMoneda',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: montoActual == m.toString()
                                  ? _orange
                                  : AppTheme.lightText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Teclado Numérico Táctil Accesible
              _TecladoNumerico(
                onDigito: _agregarDigito,
                onBorrar: _borrarDigito,
                onLimpiar: _limpiar,
              ),

              const SizedBox(height: 16),

              // Botón Principal de Confirmación (56dp)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: montoActual.isNotEmpty ? _confirmar : null,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    montoActual.isNotEmpty
                        ? 'CONFIRMAR $montoActual $displayMoneda'
                        : 'DIGITA UN MONTO',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.lightBorder,
                    disabledForegroundColor: AppTheme.lightTextSub,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: montoActual.isNotEmpty ? 2 : 0,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Botón Secundario: Omitir / No recuerdo
              TextButton.icon(
                onPressed: _omitir,
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text(
                  'No recuerdo la cifra exacta (Omitir)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTextSub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonedaChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonedaChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _orange : AppTheme.lightBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _orange : AppTheme.lightBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppTheme.lightTextSub,
          ),
        ),
      ),
    );
  }
}

class _TecladoNumerico extends StatelessWidget {
  final ValueChanged<String> onDigito;
  final VoidCallback onBorrar;
  final VoidCallback onLimpiar;

  const _TecladoNumerico({
    required this.onDigito,
    required this.onBorrar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final fila in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['C', '0', '⌫'],
        ]) ...[
          Row(
            children: [
              for (final tecla in fila) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.5),
                    child: Material(
                      color: AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (tecla == '⌫') {
                            onBorrar();
                          } else if (tecla == 'C') {
                            onLimpiar();
                          } else {
                            onDigito(tecla);
                          }
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tecla == 'C' || tecla == '⌫'
                                  ? AppTheme.brandPrimary.withValues(alpha: 0.3)
                                  : AppTheme.lightBorder,
                            ),
                          ),
                          child: tecla == '⌫'
                              ? const Icon(Icons.backspace_outlined,
                                  size: 20, color: AppTheme.brandPrimary)
                              : Text(
                                  tecla,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: tecla == 'C'
                                        ? AppTheme.brandPrimary
                                        : AppTheme.lightText,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
