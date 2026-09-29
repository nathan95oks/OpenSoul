// GENERADO por tool/build_semantica_lsb.py desde
// docs/negocio/config/semantica_lsb.json. No editar a mano.

// Clases cerradas de lectura semántica, compartidas con la Lambda de
// texto a LSB (aws/lambda_text_to_lsb.py).

const List<String> kSlotVocabulary = [
  'time',
  'place',
  'person',
  'object',
  'amount',
  'evidence',
  'polarity',
  'free_text',
  'description',
];

const Map<String, String> kInterrogativeSlots = {
  'DONDE': 'place',
  'CUANDO': 'time',
  'QUIEN': 'person',
  'CUANTOS': 'amount',
};

const Map<String, String> kHeadSlots = {
  'DIA': 'time',
  'DIRECCION': 'place',
  'FECHA': 'time',
  'HORA': 'time',
  'MOMENTO': 'time',
};

const Map<String, String> kSpokenInterrogativeSlots = {
  'ADONDE': 'place',
  'CUANDO': 'time',
  'CUANTA': 'amount',
  'CUANTAS': 'amount',
  'CUANTO': 'amount',
  'CUANTOS': 'amount',
  'DONDE': 'place',
  'QUIEN': 'person',
  'QUIENES': 'person',
};

const Map<String, String> kSpokenHeadSlots = {
  'DIA': 'time',
  'DIRECCION': 'place',
  'FECHA': 'time',
  'HORA': 'time',
  'LUGAR': 'place',
  'MOMENTO': 'time',
  'SITIO': 'place',
};

const Map<String, String> kSpokenWordSlots = {
  'LUGAR': 'place',
  'SITIO': 'place',
};

const Map<String, String> kSpokenStemSlots = {
  'DESCRIB': 'description',
  'DESCRIPCION': 'description',
  'CARACTERISTICA': 'description',
  'APARIENCIA': 'description',
  'RASGO': 'description',
  'FISICAMENTE': 'description',
  'VESTI': 'description',
};

const Map<String, String> kSpokenAfterHowSlots = {
  'ERA': 'description',
  'ERAN': 'description',
  'LUCIA': 'description',
  'LUCIAN': 'description',
};

const Set<String> kOpenInterrogatives = {
  'COMO',
  'CUAL',
  'PARA_QUE',
  'POR_QUE',
  'QUE',
};

const Set<String> kNegators = {
  'JAMAS',
  'NADA',
  'NADIE',
  'NINGUNO',
  'NO',
  'NUNCA',
};

const Set<String> kSpokenOpenInterrogatives = {'COMO', 'CUAL', 'CUALES', 'QUE'};

const Set<String> kQuestionPrepositions = {
  'A',
  'CON',
  'DE',
  'DESDE',
  'EN',
  'HACIA',
  'HASTA',
  'PARA',
  'POR',
};

const Set<String> kSpokenWearVerbs = {
  'LLEVABA',
  'LLEVABAN',
  'USABA',
  'USABAN',
  'TENIA',
  'TENIAN',
};

const Set<String> kSpokenWearWords = {
  'ROPA',
  'PRENDA',
  'PRENDAS',
  'PUESTO',
  'PUESTA',
  'PUESTOS',
  'PUESTAS',
};

const String kSpokenWearSlot = 'description';
