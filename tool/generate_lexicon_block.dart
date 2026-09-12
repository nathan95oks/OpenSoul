import 'dart:convert';
import 'dart:io';

String stripAccents(String input) {
  const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const to = 'AAAAEEEEIIIIOOOOUUUUN';
  var out = input.toUpperCase().replaceAll('-', '_');
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

void main() {
  final dictDoc = jsonDecode(File('assets/dictionary/official_dictionary.json').readAsStringSync()) as Map<String, dynamic>;
  final entries = (dictDoc['entries'] as List).cast<Map<String, dynamic>>();

  final Map<String, ({String role, String es})> lexicon = {};

  for (final e in entries) {
    final gloss = (e['gloss'] as String).toUpperCase().replaceAll('-', '_');
    final norm = stripAccents(gloss);
    final cat = e['categoryId'] as String;

    String role = 'marcador';
    String es = (e['displayText'] as String).toLowerCase();

    if (const {'GRACIAS', 'HOLA', 'PERMISO', 'POR_FAVOR', 'LO_SIENTO', 'BUENOS_DIAS', 'DE_NADA', 'HASTA_LUEGO', 'HASTA_MANANA'}.contains(norm)) {
      role = 'marcador';
      if (norm == 'GRACIAS') es = 'gracias';
      else if (norm == 'HOLA') es = 'hola';
      else if (norm == 'PERMISO') es = 'con permiso';
      else if (norm == 'POR_FAVOR') es = 'por favor';
      else if (norm == 'LO_SIENTO') es = 'lo siento';
      else if (norm == 'BUENOS_DIAS') es = 'buenos días';
      else if (norm == 'DE_NADA') es = 'de nada';
      else if (norm == 'HASTA_LUEGO') es = 'hasta luego';
      else if (norm == 'HASTA_MANANA') es = 'hasta mañana';
    } else if (const {'SI', 'NO', 'ESTOY_BIEN', 'MAS_O_MENOS', 'PUEDO', 'NO_PUEDO', 'SABER', 'NO_SABER', 'COMPRENDER', 'NO_ENTIENDO', 'NO_RECUERDO', 'PUEDE_REPETIR', 'ESTAR_DE_ACUERDO', 'NO_ESTAR_DE_ACUERDO', 'VERDAD', 'MENTIRA', 'TAL_VEZ'}.contains(norm)) {
      role = 'marcador';
      if (norm == 'ESTOY_BIEN') es = 'estoy bien';
      else if (norm == 'NO') es = 'no';
      else if (norm == 'NO_PUEDO') es = 'no puedo';
      else if (norm == 'NO_SABER') es = 'no sé';
      else if (norm == 'PUEDO') es = 'puedo';
      else if (norm == 'SABER') es = 'sé';
      else if (norm == 'SI') es = 'sí';
      else if (norm == 'MAS_O_MENOS') es = 'más o menos';
      else if (norm == 'NO_RECUERDO') es = 'no recuerdo';
      else if (norm == 'NO_ENTIENDO') es = 'no entiendo';
      else if (norm == 'PUEDE_REPETIR') es = '¿puede repetir?';
      else if (norm == 'ESTAR_DE_ACUERDO') es = 'estoy de acuerdo';
      else if (norm == 'NO_ESTAR_DE_ACUERDO') es = 'no estoy de acuerdo';
      else if (norm == 'VERDAD') es = 'es verdad';
      else if (norm == 'MENTIRA') es = 'es mentira';
      else if (norm == 'TAL_VEZ') es = 'tal vez';
    } else if (const {'QUE', 'QUIEN', 'DONDE', 'CUANDO', 'CUAL', 'COMO', 'CUANTOS', 'POR_QUE', 'PARA_QUE'}.contains(norm)) {
      role = 'interrogativa';
      if (norm == 'QUE') es = 'qué';
      else if (norm == 'QUIEN') es = 'quién';
      else if (norm == 'DONDE') es = 'dónde';
      else if (norm == 'CUANDO') es = 'cuándo';
      else if (norm == 'CUAL') es = 'cuál';
      else if (norm == 'COMO') es = 'cómo';
      else if (norm == 'CUANTOS') es = 'cuántos';
      else if (norm == 'POR_QUE') es = 'por qué';
      else if (norm == 'PARA_QUE') es = 'para qué';
    } else if (const {'YO', 'TU', 'EL', 'ELLA', 'NOSOTROS', 'ELLOS', 'MIO', 'TUYO', 'SUYO', 'AMBOS', 'VARIOS'}.contains(norm)) {
      role = 'sujeto';
      if (norm == 'YO') es = 'yo';
      else if (norm == 'TU') es = 'tú';
      else if (norm == 'EL') es = 'él';
      else if (norm == 'ELLA') es = 'ella';
      else if (norm == 'NOSOTROS') es = 'nosotros';
      else if (norm == 'ELLOS') es = 'ellos';
      else if (norm == 'MIO') es = 'mi';
      else if (norm == 'TUYO') es = 'su';
      else if (norm == 'SUYO') es = 'suyo';
      else if (norm == 'AMBOS') es = 'ambos';
      else if (norm == 'VARIOS') es = 'varios';
    } else if (const {'TESTIGO'}.contains(norm)) {
      role = 'testigo';
      es = 'un testigo';
    } else if (const {'NOMBRE', 'APELLIDO', 'IDENTIDAD', 'EDAD'}.contains(norm)) {
      role = 'marcador';
      if (norm == 'NOMBRE') es = 'mi nombre es';
      else if (norm == 'APELLIDO') es = 'mi apellido es';
      else if (norm == 'IDENTIDAD') es = 'mi carnet de identidad';
      else if (norm == 'EDAD') es = 'tengo esa edad';
    } else if (const {'FLACO', 'GORDO', 'ALTO', 'BAJO'}.contains(norm)) {
      role = 'rasgo';
      if (norm == 'FLACO') es = 'delgado';
      else if (norm == 'GORDO') es = 'de contextura gruesa';
      else if (norm == 'ALTO') es = 'alto';
      else if (norm == 'BAJO') es = 'bajo';
    } else if (const {'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'LADRON', 'PAREJA', 'EXPAREJA', 'FAMILIAR', 'VECINO', 'AMIGO', 'COMPANERO', 'JEFE', 'TRABAJADOR', 'SENOR', 'HIJO', 'HIJA', 'MAMA', 'ESPOSA', 'HERMANO', 'HERMANA', 'SEPARADOS', 'PARIENTE', 'SORDO', 'OYENTE', 'COMUNIDAD_SORDA', 'ASOCIACION_SORDOS'}.contains(norm)) {
      role = 'personaDesc';
      if (norm == 'HOMBRE') es = 'un hombre';
      else if (norm == 'MUJER') es = 'una mujer';
      else if (norm == 'JOVEN') es = 'joven';
      else if (norm == 'ADULTO') es = 'adulto';
      else if (norm == 'LADRON') es = 'un ladrón';
      else if (norm == 'PAREJA') es = 'mi pareja';
      else if (norm == 'EXPAREJA') es = 'mi expareja';
      else if (norm == 'FAMILIAR') es = 'un familiar';
      else if (norm == 'VECINO') es = 'un vecino';
      else if (norm == 'AMIGO') es = 'un amigo';
      else if (norm == 'COMPANERO') es = 'un compañero';
      else if (norm == 'JEFE') es = 'mi jefe';
      else if (norm == 'TRABAJADOR') es = 'un trabajador';
      else if (norm == 'SENOR') es = 'el señor';
      else if (norm == 'HIJO') es = 'mi hijo';
      else if (norm == 'HIJA') es = 'mi hija';
      else if (norm == 'MAMA') es = 'mi mamá';
      else if (norm == 'ESPOSA') es = 'mi esposa';
      else if (norm == 'HERMANO') es = 'mi hermano';
      else if (norm == 'HERMANA') es = 'mi hermana';
      else if (norm == 'SEPARADOS') es = 'separados';
      else if (norm == 'PARIENTE') es = 'un pariente';
      else if (norm == 'SORDO') es = 'una persona sorda';
      else if (norm == 'OYENTE') es = 'oyente';
      else if (norm == 'COMUNIDAD_SORDA') es = 'la comunidad sorda';
      else if (norm == 'ASOCIACION_SORDOS') es = 'la asociación de sordos';
    } else if (const {'ABOGADO', 'INTERPRETE', 'DOCTOR', 'ASISTENTE', 'OFICIAL'}.contains(norm)) {
      role = 'servicio';
      if (norm == 'ABOGADO') es = 'un abogado';
      else if (norm == 'INTERPRETE') es = 'un intérprete de LSB';
      else if (norm == 'DOCTOR') es = 'un doctor';
      else if (norm == 'ASISTENTE') es = 'un asistente';
      else if (norm == 'OFICIAL') es = 'un oficial';
    } else if (const {'POLICIA', 'FISCAL', 'JUEZ', 'AUTORIDAD', 'GOBIERNO', 'ALCALDIA', 'INSTITUCION', 'ORGANO_JUDICIAL', 'HOSPITAL', 'SEPDAVI', 'SEPDEP', 'FELCC', 'FELCV', 'FISCALIA', 'JUZGADO'}.contains(norm)) {
      role = 'institucion';
      if (norm == 'POLICIA') es = 'en la policía';
      else if (norm == 'FISCAL') es = 'el fiscal';
      else if (norm == 'JUEZ') es = 'el juez';
      else if (norm == 'AUTORIDAD') es = 'la autoridad';
      else if (norm == 'GOBIERNO') es = 'el gobierno';
      else if (norm == 'ALCALDIA') es = 'en la alcaldía';
      else if (norm == 'INSTITUCION') es = 'en la institución';
      else if (norm == 'ORGANO_JUDICIAL') es = 'en el Órgano Judicial';
      else if (norm == 'HOSPITAL') es = 'en el hospital';
      else if (norm == 'SEPDAVI') es = 'en el SEPDAVI';
      else if (norm == 'SEPDEP') es = 'en el SEPDEP';
      else if (norm == 'FELCC') es = 'en la FELCC';
      else if (norm == 'FELCV') es = 'en la FELCV';
      else if (norm == 'FISCALIA') es = 'en la Fiscalía';
      else if (norm == 'JUZGADO') es = 'en el juzgado';
    } else if (const {'INVESTIGACION', 'TRAMITE', 'CITACION', 'CONVOCAR', 'PLAZO'}.contains(norm)) {
      role = 'tramite';
      if (norm == 'INVESTIGACION') es = 'la investigación de mi caso';
      else if (norm == 'TRAMITE') es = 'un trámite';
      else if (norm == 'CITACION' || norm == 'CONVOCAR') es = 'una citación';
      else if (norm == 'PLAZO') es = 'el plazo';
    } else if (const {'LEY', 'JUSTICIA', 'RESOLUCION', 'TESTIMONIO', 'DENUNCIA', 'ASISTENCIA', 'DISCRIMINACION', 'PROHIBIDO', 'RESULTADO'}.contains(norm)) {
      role = 'documento';
      if (norm == 'LEY') es = 'la ley';
      else if (norm == 'JUSTICIA') es = 'la justicia';
      else if (norm == 'RESOLUCION') es = 'una resolución';
      else if (norm == 'TESTIMONIO') es = 'mi testimonio';
      else if (norm == 'DENUNCIA') es = 'la denuncia';
      else if (norm == 'ASISTENCIA') es = 'asistencia';
      else if (norm == 'DISCRIMINACION') es = 'discriminación';
      else if (norm == 'PROHIBIDO') es = 'prohibido';
      else if (norm == 'RESULTADO') es = 'el resultado';
    } else if (const {'HERIDA', 'DOLOR', 'FRACTURA', 'HUESOS', 'AUXILIO', 'URGENTE', 'VIOLENCIA', 'ACCIDENTE'}.contains(norm)) {
      role = 'urgencia';
      if (norm == 'HERIDA') es = 'una herida';
      else if (norm == 'DOLOR') es = 'dolor físico';
      else if (norm == 'FRACTURA') es = 'una fractura';
      else if (norm == 'HUESOS') es = 'los huesos';
      else if (norm == 'AUXILIO') es = 'auxilio urgente';
      else if (norm == 'URGENTE') es = 'de manera urgente';
      else if (norm == 'VIOLENCIA') es = 'un hecho de violencia';
      else if (norm == 'ACCIDENTE') es = 'un accidente';
    } else if (const {'ROBAR', 'PEGAR', 'MALTRATAR', 'AMENAZAR', 'ABUSAR', 'PELEAR', 'PERDER', 'ENGANAR', 'DANAR', 'ESCAPAR'}.contains(norm)) {
      role = 'verboAgresion';
      if (norm == 'ROBAR') es = 'robó';
      else if (norm == 'PEGAR') es = 'golpeó y pegó';
      else if (norm == 'MALTRATAR') es = 'maltrató';
      else if (norm == 'AMENAZAR') es = 'amenazó';
      else if (norm == 'ABUSAR') es = 'cometió abusos';
      else if (norm == 'PELEAR') es = 'inició una pelea';
      else if (norm == 'PERDER') es = 'perdí';
      else if (norm == 'ENGANAR') es = 'engañó y estafó';
      else if (norm == 'DANAR') es = 'dañó';
      else if (norm == 'ESCAPAR') es = 'escapó';
    } else if (const {'HOY', 'AYER', 'ANTEAYER', 'MANANA', 'PASADO_MANANA', 'PASADO', 'FUTURO', 'AHORA', 'DESPUES', 'LUEGO', 'TEMPRANO', 'TARDE', 'SIEMPRE', 'JAMAS', 'AUN', 'MOMENTO', 'FECHA', 'DIA', 'SEMANA', 'MES', 'ANO', 'ANO_PASADO', 'CADA_DIA', 'TODOS_LOS_DIAS', 'PRIMERA_VEZ', 'HORA', 'MINUTO', 'SEGUNDO', 'DURANTE', 'PROXIMO', 'ULTIMO', 'LUNES', 'MARTES', 'JUEVES', 'VIERNES', 'SABADO', 'JULIO', 'MARZO', 'DESCANSO', 'POSTERGAR', 'OCUPADO', 'LIBRE'}.contains(norm)) {
      role = 'tiempo';
      if (norm == 'HOY') es = 'hoy';
      else if (norm == 'AYER') es = 'ayer';
      else if (norm == 'ANTEAYER') es = 'anteayer';
      else if (norm == 'MANANA') es = 'mañana';
      else if (norm == 'PASADO_MANANA') es = 'pasado mañana';
      else if (norm == 'PASADO') es = 'en el pasado';
      else if (norm == 'FUTURO') es = 'en el futuro';
      else if (norm == 'AHORA') es = 'ahora mismo';
      else if (norm == 'DESPUES') es = 'después';
      else if (norm == 'LUEGO') es = 'luego';
      else if (norm == 'TEMPRANO') es = 'temprano';
      else if (norm == 'TARDE') es = 'por la tarde';
      else if (norm == 'SIEMPRE') es = 'siempre';
      else if (norm == 'JAMAS') es = 'jamás';
      else if (norm == 'AUN') es = 'aún';
      else if (norm == 'MOMENTO') es = 'en ese momento';
      else if (norm == 'FECHA') es = 'en la fecha indicada';
      else if (norm == 'DIA') es = 'día';
      else if (norm == 'SEMANA') es = 'semana';
      else if (norm == 'MES') es = 'mes';
      else if (norm == 'ANO') es = 'año';
      else if (norm == 'ANO_PASADO') es = 'el año pasado';
      else if (norm == 'CADA_DIA') es = 'cada día';
      else if (norm == 'TODOS_LOS_DIAS') es = 'todos los días';
      else if (norm == 'PRIMERA_VEZ') es = 'la primera vez';
      else if (norm == 'HORA') es = 'hora';
      else if (norm == 'MINUTO') es = 'minuto';
      else if (norm == 'SEGUNDO') es = 'segundo';
      else if (norm == 'DURANTE') es = 'durante ese tiempo';
      else if (norm == 'PROXIMO') es = 'el próximo';
      else if (norm == 'ULTIMO') es = 'el último';
      else if (norm == 'LUNES') es = 'el lunes';
      else if (norm == 'MARTES') es = 'el martes';
      else if (norm == 'JUEVES') es = 'el jueves';
      else if (norm == 'VIERNES') es = 'el viernes';
      else if (norm == 'SABADO') es = 'el sábado';
      else if (norm == 'JULIO') es = 'en julio';
      else if (norm == 'MARZO') es = 'en marzo';
      else if (norm == 'DESCANSO') es = 'en horario de descanso';
      else if (norm == 'POSTERGAR') es = 'postergar';
      else if (norm == 'OCUPADO') es = 'ocupado';
      else if (norm == 'LIBRE') es = 'libre';
    } else if (const {'CASA', 'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'BARRIO', 'TIENDA', 'BANCO', 'ESCUELA', 'ESCUELA_NOCTURNA', 'OFICINA', 'COCHABAMBA', 'PROVINCIA', 'AQUI', 'ALLI', 'ALLA', 'DENTRO', 'FUERA', 'CERCA', 'LEJOS', 'AL_LADO', 'ENFRENTE', 'ATRAS', 'DIRECCION'}.contains(norm)) {
      role = 'lugar';
      if (norm == 'CASA') es = 'en mi casa';
      else if (norm == 'CALLE') es = 'en la calle';
      else if (norm == 'AVENIDA') es = 'en la avenida';
      else if (norm == 'PLAZA') es = 'en la plaza';
      else if (norm == 'MERCADO') es = 'en el mercado';
      else if (norm == 'BARRIO') es = 'en el barrio';
      else if (norm == 'TIENDA') es = 'en la tienda';
      else if (norm == 'BANCO') es = 'en el banco';
      else if (norm == 'ESCUELA') es = 'en la escuela';
      else if (norm == 'ESCUELA_NOCTURNA') es = 'en la escuela nocturna';
      else if (norm == 'OFICINA') es = 'en la oficina';
      else if (norm == 'COCHABAMBA') es = 'en Cochabamba';
      else if (norm == 'PROVINCIA') es = 'en la provincia';
      else if (norm == 'AQUI') es = 'aquí';
      else if (norm == 'ALLI') es = 'allí';
      else if (norm == 'ALLA') es = 'allá';
      else if (norm == 'DENTRO') es = 'dentro del lugar';
      else if (norm == 'FUERA') es = 'afuera del lugar';
      else if (norm == 'CERCA') es = 'cerca del lugar';
      else if (norm == 'LEJOS') es = 'lejos';
      else if (norm == 'AL_LADO') es = 'al lado';
      else if (norm == 'ENFRENTE') es = 'enfrente';
      else if (norm == 'ATRAS') es = 'atrás';
      else if (norm == 'DIRECCION') es = 'en mi dirección';
    } else if (const {'PAPEL', 'CERTIFICADO', 'FACTURA', 'FOTOCOPIA', 'CARPETA', 'PAGINA', 'SELLO', 'LISTA'}.contains(norm)) {
      role = 'documento';
      if (norm == 'PAPEL') es = 'el documento';
      else if (norm == 'CERTIFICADO') es = 'un certificado';
      else if (norm == 'FACTURA') es = 'la factura';
      else if (norm == 'FOTOCOPIA') es = 'una fotocopia';
      else if (norm == 'CARPETA') es = 'la carpeta de documentos';
      else if (norm == 'PAGINA') es = 'la página';
      else if (norm == 'SELLO') es = 'un sello oficial';
      else if (norm == 'LISTA') es = 'la lista';
    } else if (const {'CELULAR', 'FOTOS', 'VIDEO', 'CAMARA_FOTOGRAFICA', 'COMPUTADORA', 'INTERNET', 'DINERO', 'BILLETES', 'CAJA', 'BOLSA', 'MOCHILA', 'LENTES', 'POLERA', 'PANTALON', 'CHAMARRA', 'GORRA', 'PUERTA', 'AUTO', 'MICRO', 'TRUFI', 'MEDICINA', 'RAYOS_X', 'BRAZO', 'BOCA', 'CABELLO'}.contains(norm)) {
      role = 'objeto';
      if (norm == 'CELULAR') es = 'mi celular';
      else if (norm == 'FOTOS') es = 'fotografías';
      else if (norm == 'VIDEO') es = 'un video';
      else if (norm == 'CAMARA_FOTOGRAFICA') es = 'una cámara fotográfica';
      else if (norm == 'COMPUTADORA') es = 'una computadora';
      else if (norm == 'INTERNET') es = 'por internet';
      else if (norm == 'DINERO') es = 'mi dinero';
      else if (norm == 'BILLETES') es = 'billetes y dinero';
      else if (norm == 'CAJA') es = 'la caja';
      else if (norm == 'BOLSA') es = 'mi bolsa';
      else if (norm == 'MOCHILA') es = 'mi mochila';
      else if (norm == 'LENTES') es = 'mis lentes';
      else if (norm == 'POLERA') es = 'mi polera';
      else if (norm == 'PANTALON') es = 'mi pantalón';
      else if (norm == 'CHAMARRA') es = 'mi chamarra';
      else if (norm == 'GORRA') es = 'mi gorra';
      else if (norm == 'PUERTA') es = 'la puerta';
      else if (norm == 'AUTO') es = 'mi auto';
      else if (norm == 'MICRO') es = 'un micro';
      else if (norm == 'TRUFI') es = 'un trufi';
      else if (norm == 'MEDICINA') es = 'medicinas';
      else if (norm == 'RAYOS_X') es = 'placas de rayos X';
      else if (norm == 'BRAZO') es = 'el brazo';
      else if (norm == 'BOCA') es = 'la boca';
      else if (norm == 'CABELLO') es = 'el cabello';
    } else if (const {'ROJO', 'AZUL', 'NEGRO', 'BUENO', 'MAL', 'MEJOR', 'NUEVO', 'CARO', 'CORTO', 'DIFERENTE', 'DIFICIL', 'OSCURO', 'MUCHO', 'POCO', 'LENTO'}.contains(norm)) {
      role = 'descriptor';
      if (norm == 'ROJO') es = 'de color rojo';
      else if (norm == 'AZUL') es = 'de color azul';
      else if (norm == 'NEGRO') es = 'de color negro';
      else if (norm == 'BUENO') es = 'bueno';
      else if (norm == 'MAL') es = 'mal';
      else if (norm == 'MEJOR') es = 'mejor';
      else if (norm == 'NUEVO') es = 'nuevo';
      else if (norm == 'CARO') es = 'costoso';
      else if (norm == 'CORTO') es = 'corto';
      else if (norm == 'DIFERENTE') es = 'diferente';
      else if (norm == 'DIFICIL') es = 'difícil';
      else if (norm == 'OSCURO') es = 'oscuro';
      else if (norm == 'MUCHO') es = 'mucho';
      else if (norm == 'POCO') es = 'poco';
      else if (norm == 'LENTO') es = 'despacio';
    } else if (const {'MIEDO', 'TRISTE', 'CONFIANZA', 'PREOCUPAR'}.contains(norm)) {
      role = 'emocion';
      if (norm == 'MIEDO') es = 'tengo miedo';
      else if (norm == 'TRISTE') es = 'estoy triste';
      else if (norm == 'CONFIANZA') es = 'tengo confianza';
      else if (norm == 'PREOCUPAR') es = 'estoy preocupado';
    } else {
      role = 'verboAccion';
      if (norm == 'ESCRIBIR') es = 'quiero escribir';
      else if (norm == 'VER' || norm == 'MIRAR') es = 'vi';
      else if (norm == 'OIR') es = 'escuché';
      else if (norm == 'HABLAR') es = 'quiero hablar';
      else if (norm == 'EXPLICAR') es = 'quiero explicar';
      else if (norm == 'LEER') es = 'quiero leer';
      else if (norm == 'MOSTRAR') es = 'puedo mostrar';
      else if (norm == 'NARRAR') es = 'quiero relatar';
      else if (norm == 'OBSERVAR') es = 'observé';
      else if (norm == 'PRESENTAR') es = 'quiero presentar';
      else if (norm == 'GUARDAR') es = 'guardé';
      else if (norm == 'BUSCAR') es = 'quiero buscar';
      else if (norm == 'DAR') es = 'entregué';
      else if (norm == 'ENVIAR') es = 'envié';
      else if (norm == 'RECIBIR') es = 'recibí';
      else if (norm == 'TRAER') es = 'puedo traer';
      else if (norm == 'LLEVAR') es = 'llevaba';
      else if (norm == 'VENIR') es = 'vine';
      else if (norm == 'IR') es = 'fui';
      else if (norm == 'LLEGAR') es = 'llegué';
      else if (norm == 'VOLVER') es = 'debo volver';
      else if (norm == 'DEVOLVER') es = 'quiero que devuelvan';
      else if (norm == 'PEDIR') es = 'solicito';
      else if (norm == 'AYUDAR') es = 'necesito ayuda';
      else if (norm == 'PROTEGER') es = 'necesito protección';
      else if (norm == 'HACER') es = 'hice';
      else if (norm == 'TERMINAR') es = 'terminó';
      else if (norm == 'EMPEZAR') es = 'empezó';
      else if (norm == 'CONTINUAR') es = 'continúa';
      else if (norm == 'CAMBIAR') es = 'cambié';
      else if (norm == 'ARREGLAR') es = 'quiero corregir';
      else if (norm == 'AUMENTAR') es = 'quiero agregar información';
      else if (norm == 'CONOCER') es = 'conozco';
      else if (norm == 'RECORDAR') es = 'recuerdo';
      else if (norm == 'IDENTIFICAR') es = 'puedo identificar';
      else if (norm == 'DEJAR') es = 'dejé';
      else if (norm == 'ABRIR') es = 'abrí';
      else if (norm == 'COMPRAR') es = 'compré';
      else if (norm == 'VENDER') es = 'vendí';
      else if (norm == 'GANAR_DINERO') es = 'gané dinero';
      else if (norm == 'VIVIR') es = 'vivo';
      else if (norm == 'DORMIR') es = 'dormía';
      else if (norm == 'ANDAR') es = 'caminaba';
      else if (norm == 'LLAMAR') es = 'llamé';
      else if (norm == 'BURLAR') es = 'se burlaron';
      else if (norm == 'IGNORAR') es = 'me ignoraron';
      else if (norm == 'CREER') es = 'creo';
      else if (norm == 'DECIDIR') es = 'decidí';
      else if (norm == 'ORGANIZAR') es = 'organicé';
      else if (norm == 'EVALUAR') es = 'evaluar';
      else if (norm == 'DIBUJAR') es = 'dibujé';
      else if (norm == 'FILMAR') es = 'filmé';
      else if (norm == 'FUNCIONAR') es = 'funciona';
      else if (norm == 'ENCONTRARSE') es = 'me encontré';
      else if (norm == 'ESCONDER') es = 'escondió';
      else if (norm == 'CURAR') es = 'curar';
      else if (norm == 'GRITAR') es = 'gritó';
      else if (norm == 'ACEPTAR') es = 'acepto';
      else if (norm == 'RECHAZAR') es = 'rechazo';
      else if (norm == 'CONTESTAR_DOS_VECES') es = 'contesté dos veces';
      else if (norm == 'ARRESTAR') es = 'arrestaron';
      else if (norm == 'ATENDER') es = 'atender';
      else if (norm == 'CONFESAR') es = 'quiero confesar';
      else if (norm == 'GRATIS') { role = 'descriptor'; es = 'gratuito'; }
    }

    lexicon[gloss] = (role: role, es: es);
  }

  final buffer = StringBuffer();
  final sortedGlosses = lexicon.keys.toList()..sort();

  for (final g in sortedGlosses) {
    final e = lexicon[g]!;
    final esEscaped = e.es.replaceAll("'", r"\'");
    buffer.writeln("    '$g': _Lex(_Role.${e.role}, '$esEscaped'),");
  }

  File('tool/generated_lexicon_block.dart').writeAsStringSync(buffer.toString());
  print('Successfully regenerated tool/generated_lexicon_block.dart with ${lexicon.length} entries.');
}
