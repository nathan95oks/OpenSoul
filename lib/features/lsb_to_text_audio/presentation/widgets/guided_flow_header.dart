import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/guided_flow_provider.dart';

class GuidedFlowHeader extends ConsumerWidget {
  const GuidedFlowHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(guidedFlowProvider);
    final currentStep = ref.read(guidedFlowProvider.notifier).currentStep;

    if (currentStep == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ADB5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Paso ${flowState.currentStepIndex + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ADB5),
                  ),
                ),
              ),
              const Spacer(),
              if (flowState.currentStepIndex > 0)
                InkWell(
                  onTap: () {
                    ref.read(guidedFlowProvider.notifier).previousStep();
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 12, color: Color(0xFF8B949E)),
                      SizedBox(width: 4),
                      Text('Anterior', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currentStep.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentStep.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
        ],
      ),
    );
  }
}
