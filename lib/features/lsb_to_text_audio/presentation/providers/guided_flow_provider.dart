import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/semantic_context.dart';
import 'context_provider.dart';

class GuidedFlowState {
  final int currentStepIndex;
  final bool isCompleted;

  const GuidedFlowState({
    required this.currentStepIndex,
    required this.isCompleted,
  });

  GuidedFlowState copyWith({
    int? currentStepIndex,
    bool? isCompleted,
  }) {
    return GuidedFlowState(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class GuidedFlowNotifier extends Notifier<GuidedFlowState> {
  @override
  GuidedFlowState build() {
    return const GuidedFlowState(currentStepIndex: 0, isCompleted: false);
  }

  void advanceStep() {
    final context = ref.read(contextProvider);
    if (context == null) return;

    if (state.currentStepIndex < context.defaultSteps.length - 1) {
      state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
    } else {
      state = state.copyWith(isCompleted: true);
    }
  }

  void previousStep() {
    if (state.currentStepIndex > 0) {
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex - 1,
        isCompleted: false,
      );
    }
  }

  void setStep(int index) {
    final context = ref.read(contextProvider);
    if (context == null) return;
    if (index >= 0 && index < context.defaultSteps.length) {
      state = state.copyWith(currentStepIndex: index, isCompleted: false);
    }
  }

  void reset() {
    state = const GuidedFlowState(currentStepIndex: 0, isCompleted: false);
  }

  GuidedStep? get currentStep {
    final context = ref.read(contextProvider);
    if (context == null || state.isCompleted) return null;
    return context.defaultSteps[state.currentStepIndex];
  }
}

final guidedFlowProvider = NotifierProvider<GuidedFlowNotifier, GuidedFlowState>(GuidedFlowNotifier.new);
