import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

/// En ventanilla, "¿tiene su carnet?" y "traiga su carnet" hablan de lo mismo
/// y piden cosas opuestas. Antes las dos abrían el mismo cuestionario.
void main() {
  group('preguntas', () {
    test('con signo de cierre', () {
      for (final t in [
        '¿Tiene el número de su caso?',
        'Tiene el número de su caso?',
        '¿Sabes qué documento debes llevar?',
        '¿Puede explicarme qué ocurrió?',
      ]) {
        expect(classifySpeechAct(t), SpeechAct.question, reason: t);
      }
    });

    test('sin ningún signo, por el interrogativo inicial', () {
      // El teclado del móvil se come el signo de apertura y a veces los dos.
      for (final t in [
        'Donde ocurrio el hecho',
        'Cuando paso',
        'Tiene su carnet',
        'Necesita un interprete',
      ]) {
        expect(classifySpeechAct(t), SpeechAct.question, reason: t);
      }
    });
  });

  group('instrucciones', () {
    test('perífrasis de obligación', () {
      for (final t in [
        'Debe traer su carnet y luego ir a la ventanilla 3',
        'Tiene que presentar el memorial antes del viernes',
        'Hay que llenar el formulario primero',
      ]) {
        expect(classifySpeechAct(t), SpeechAct.instruction, reason: t);
      }
    });

    test('imperativo de ventanilla, con o sin cortesía delante', () {
      for (final t in [
        'Vaya a la ventanilla 4 con su certificado',
        'Por favor, diríjase a la oficina de la esquina',
        'Presente su constancia en el primer piso',
        'Vuelva mañana con la fotocopia',
      ]) {
        expect(classifySpeechAct(t), SpeechAct.instruction, reason: t);
      }
    });
  });

  group('ni una cosa ni la otra', () {
    test('un informe no abre nada', () {
      for (final t in [
        'Su trámite está en revisión',
        'El fiscal asignado se llama Pérez',
        'Buenos días, tome asiento',
      ]) {
        expect(classifySpeechAct(t), isNot(SpeechAct.question), reason: t);
      }
    });

    test('texto vacío no inventa un acto de habla', () {
      expect(classifySpeechAct(''), SpeechAct.statement);
      expect(classifySpeechAct('   '), SpeechAct.statement);
    });

    test('una subordinada no es una pregunta', () {
      // "dónde" en medio de la frase no pregunta: informa.
      expect(classifySpeechAct('No sé dónde queda esa oficina'),
          isNot(SpeechAct.question));
    });
  });

  test('la pregunta manda sobre la instrucción cuando hay ambas', () {
    // "¿Debe traer algo más?" es una pregunta, aunque contenga "debe".
    expect(classifySpeechAct('¿Debe traer algo más?'), SpeechAct.question);
  });
}
