import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/context_provider.dart';
import '../providers/guided_flow_provider.dart';

class GuidedFlowHeader extends ConsumerWidget {
  const GuidedFlowHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(guidedFlowProvider);
    final flowNotifier = ref.read(guidedFlowProvider.notifier);
    final currentStep = flowNotifier.currentStep;
    final ctx = ref.watch(contextProvider);

    if (currentStep == null || ctx == null) return const SizedBox.shrink();

    final isLastStep = flowState.currentStepIndex == ctx.defaultSteps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Indicador visual de progreso (Dots)
              Expanded(
                child: Row(
                  children: List.generate(ctx.defaultSteps.length, (index) {
                    final isActive = index == flowState.currentStepIndex;
                    final isPast = index < flowState.currentStepIndex;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isActive 
                            ? const Color(0xFF00ADB5) 
                            : (isPast ? const Color(0xFF00ADB5).withOpacity(0.5) : const Color(0xFF30363D)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentStep.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentStep.hint,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (flowState.currentStepIndex > 0)
                TextButton.icon(
                  onPressed: () => flowNotifier.previousStep(),
                  icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF8B949E)),
                  label: const Text('Anterior', style: TextStyle(color: Color(0xFF8B949E))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                )
              else
                const SizedBox.shrink(),
              
              if (!isLastStep)
                ElevatedButton(
                  onPressed: () => flowNotifier.advanceStep(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ADB5).withOpacity(0.15),
                    foregroundColor: const Color(0xFF00ADB5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currentStep.isOptional ? 'Saltar' : 'Siguiente', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
