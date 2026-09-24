import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';

/// La necesidad elegida en el modo personal.
///
/// `null` es un valor válido y frecuente: en ventanilla la necesidad la marca
/// lo que se diga, y en personal se puede empezar sin haberla fijado. No
/// bloquea nada.
class ActiveNeedNotifier extends Notifier<NeedId?> {
  @override
  NeedId? build() => null;

  void select(NeedId? need) => state = need;

  void clear() => state = null;
}

final activeNeedProvider =
    NotifierProvider<ActiveNeedNotifier, NeedId?>(ActiveNeedNotifier.new);
