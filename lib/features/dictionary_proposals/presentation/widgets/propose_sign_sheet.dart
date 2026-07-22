import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/dictionary/domain/dictionary_proposal.dart';

/// Formulario de propuesta de una palabra/seña faltante (Fase 3).
///
/// La propuesta viaja al backend como `pending`: nunca toca el diccionario
/// oficial. Si no hay conexión queda en la cola offline y se reenvía sola
/// en la próxima sincronización — el usuario nunca pierde lo que redactó.
class ProposeSignSheet extends ConsumerStatefulWidget {
  /// Palabra con la que se pre-llena el formulario (p. ej. una glosa que
  /// el avatar tuvo que deletrear por no tener seña).
  final String? initialWord;

  /// Contexto situacional activo cuando surgió la necesidad.
  final String? contextId;

  const ProposeSignSheet({super.key, this.initialWord, this.contextId});

  static Future<void> show(
    BuildContext context, {
    String? initialWord,
    String? contextId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        // Deja visible el formulario por encima del teclado.
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ProposeSignSheet(initialWord: initialWord, contextId: contextId),
      ),
    );
  }

  @override
  ConsumerState<ProposeSignSheet> createState() => _ProposeSignSheetState();
}

class _ProposeSignSheetState extends ConsumerState<ProposeSignSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _word =
      TextEditingController(text: widget.initialWord ?? '');
  final TextEditingController _description = TextEditingController();
  final TextEditingController _videoUrl = TextEditingController();
  final TextEditingController _proposedBy = TextEditingController();
  String? _categoryId;
  bool _sending = false;

  @override
  void dispose() {
    _word.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _proposedBy.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final proposal = DictionaryProposal(
      word: _word.text.trim().toUpperCase(),
      description: _description.text.trim(),
      categoryId: _categoryId,
      contexts: [if (widget.contextId != null) widget.contextId!],
      videoUrl: _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
      proposedBy:
          _proposedBy.text.trim().isEmpty ? null : _proposedBy.text.trim(),
    );

    final result =
        await ref.read(lexiconRepositoryProvider).submitProposal(proposal);

    if (!mounted) return;
    setState(() => _sending = false);

    final (message, isError) = switch (result) {
      ProposalSubmissionResult.sent => (
          'Propuesta enviada. Quedará en revisión de la comunidad.',
          false,
        ),
      ProposalSubmissionResult.queued => (
          'Sin conexión: tu propuesta quedó guardada y se enviará sola.',
          false,
        ),
      ProposalSubmissionResult.failed => (
          'No se pudo guardar la propuesta. Intenta de nuevo.',
          true,
        ),
    };

    if (!isError) Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppTheme.errorLight : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_proposalCategoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.playlist_add, color: AppTheme.brandPrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proponer palabra o seña',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu propuesta será revisada por validadores de la comunidad '
                'sorda antes de entrar al diccionario.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.lightTextSub),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _word,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Palabra *',
                  hintText: 'Ej: MUNICIPIO',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Escribe la palabra' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Qué significa y cuándo se usa *',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Describe brevemente el significado'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration:
                    const InputDecoration(labelText: 'Categoría (opcional)'),
                items: [
                  for (final cat in categoriesAsync.value ?? const <String>[])
                    DropdownMenuItem(value: cat, child: Text(cat)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Video de la seña (enlace, opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _proposedBy,
                decoration:
                    const InputDecoration(labelText: 'Tu nombre (opcional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Enviando…' : 'Enviar propuesta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Categorías existentes del diccionario para sugerir en el formulario.
final _proposalCategoriesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(lexiconRepositoryProvider).getCategories();
});
