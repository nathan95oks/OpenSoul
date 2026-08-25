# Vocabulario del corpus conversacional (2026)

Este documento registra la incorporación de vocabulario derivado de
`docs/_MConverter.eu_Corpus_conversacional_judicial_Espanol_LSB_Cochabamba.md`
("CORPUS CONVERSACIONAL PRELIMINAR — Denuncias, consultas y trámites") al
catálogo único de OpenSoul, y el estado de imágenes en S3 para todo el
vocabulario vigente.

## 1. Qué se agregó

Se compararon las 20 escenarios del corpus conversacional (Denuncias,
Consultas, Trámites) contra las 245 glosas que ya existían en
`assets/dictionary/official_dictionary.json`. Se identificaron **51 glosas
nuevas** — vocabulario institucional/procesal y marcadores de aclaración que
el corpus marca como indispensables y que no tenían equivalente.

Las 51 se agregaron a:

- `assets/dictionary/official_dictionary.json` (catálogo único, ids g246–g296)
- `lib/core/engines/semantic_engine/local_sentence_assembler.dart` (lexicón
  del cliente, fuente de la que `tool/sync_vocabulary.dart` deriva ambas
  Lambdas)

y se regeneraron automáticamente `GLOSS_LEXICON` en `aws/lambda_function.py`
y `AVAILABLE_GLOSSES` en `aws/lambda_text_to_lsb.py` con
`dart run tool/sync_vocabulary.dart`. `flutter test` y `flutter analyze`
pasan sin regresiones sobre el estado anterior.

Fuente registrada en cada entrada nueva: `"Corpus conversacional judicial
2026"` (distinta del resto del catálogo, que cita el diccionario oficial
D2024/M1-M4, para no atribuir estas 51 a una fuente que no les corresponde).

**Vocabulario total ahora: 296 glosas** (245 del corpus judicial oficial + 51
de este corpus conversacional).

### Decisiones tomadas sin confirmación explícita

- **CELULAR**: no se agregó como glosa aparte; el corpus lo usa como
  sinónimo de "teléfono", que ya existe (`TELEFONO`).
- **DEPARTAMENTO**: sí se agregó tal como aparece en el corpus (división
  administrativa, p.ej. "seleccionar Cochabamba").
- **REPETIR**: no se agregó como verbo suelto; el corpus solo lo usa en la
  frase fija "¿Puede repetir la pregunta?", cubierta por `PUEDE_REPETIR`.

Si alguna de estas no es la elección correcta, son fáciles de revisar — están
aisladas y no afectan al resto del vocabulario.

## 2. Vocabulario completo en uso, por categoría

`✅` = tiene imagen en S3 (`opensoul-3d-animations/lsb/judicial/`) · `⛔` = no
tiene imagen todavía (la tarjeta cae al ícono de respaldo) · `🆕` = agregada
en este documento.

### Cortesía (5)
✅ GRACIAS · ✅ HOLA · ✅ LO_SIENTO · ✅ PERMISO · ✅ POR_FAVOR

### Respuesta (11)
✅ ESTOY_BIEN · ✅ MAS_O_MENOS · ✅ NO · ⛔🆕 NO_ENTIENDO · ✅ NO_PUEDO ·
⛔🆕 NO_RECUERDO · ✅ NO_SABER · ⛔🆕 PUEDE_REPETIR · ✅ PUEDO · ✅ SABER · ✅ SI

### Preguntas (16)
✅ COMO · ✅ CUAL · ✅ CUANDO · ✅ CUANTOS · ✅ DONDE · ⛔ EL · ⛔ ELLA ·
✅ ELLOS · ✅ NOSOTROS · ✅ PARA_QUE · ✅ POR_QUE · ✅ QUE · ✅ QUIEN · ✅ TU ·
✅ USTEDES · ✅ YO

### Identificación (12)
⛔🆕 EXPAREJA · ⛔🆕 FAMILIAR · ✅ HOMBRE · ✅ IDENTIDAD · ⛔ LADRON ·
⛔ MILITAR · ✅ MUJER · ✅ NOMBRE · ⛔🆕 PAREJA · ⛔ SOLDADO · ⛔ TESTIGO ·
⛔ VECINO

### Instituciones (19)
⛔ ABOGADO · ✅ ALCALDIA · ✅ ASISTENTE · ✅ AUTORIDAD · ✅ COORDINADOR ·
⛔🆕 DESPACHO · ⛔ DOCTOR · ⛔ ENFERMERA · ⛔ FISCAL · ✅ GOBIERNO ·
⛔ INSTITUCION · ✅ INTERPRETE · ✅ JUEZ · ✅ MINISTERIO · ✅ OFICIAL ·
⛔🆕 OFICINA · ⛔ ORGANO_JUDICIAL · ⛔ POLICIA · ⛔🆕 VENTANILLA

### Conceptos jurídicos (27)
⛔ ACUERDO_SOCIAL · ⛔ ARTICULO · ⛔🆕 AUDIENCIA · ⛔🆕 CASO · ⛔🆕 CITACION ·
⛔🆕 CODIGO · ⛔ CONFIRMACION · ⛔ CONTEXTO · ✅ DECRETO_SUPREMO · ⛔ ESTADO ·
⛔🆕 EXPEDIENTE · ✅ INVESTIGACION · ✅ JUICIO · ✅ JUSTICIA · ✅ LEY ·
⛔ NORMA · ⛔🆕 NOTIFICACION · ⛔🆕 NUREJ · ✅ PERSONERIA_JURIDICA · ✅ PODER ·
✅ REGLAMENTO · ⛔🆕 REQUISITO · ⛔ RESOLUCION · ⛔🆕 SUBSANACION ·
⛔ TESTIMONIO · ⛔ TRAMITE · ⛔🆕 WEBID

### Acciones (31)
⛔🆕 ACLARAR · ✅ ACOMPANAR · ✅ ADMINISTRAR · ⛔ ANOTAR · ✅ AVISAR ·
✅ CONFESAR · ⛔🆕 CONOCER · ⛔ COORDINAR · ✅ COPIAR · ⛔🆕 CORREGIR ·
✅ CUMPLIR · ✅ DECIDIR · ✅ ESCRIBIR · ⛔ EXIGIR · ⛔ GESTIONAR ·
⛔ IDENTIFICAR · ⛔🆕 IMPRIMIR · ✅ JURAR · ✅ MOSTRAR · ⛔ NARRAR ·
⛔ OBSERVAR · ✅ PEDIR · ⛔ PRESENTAR · ✅ PROTEGER · ✅ QUEJAR · ✅ RECOGER ·
⛔ RECONOCER · ⛔🆕 RECORDAR · ⛔🆕 SEGUIMIENTO · ⛔ SOLUCIONAR · ⛔ TRATAR

### Hechos y urgencia (18)
⛔ ABUSAR · ✅ ACCIDENTE · ✅ AMENAZAR · ⛔ ARRESTAR · ⛔ ASISTENCIA ·
⛔ AUXILIO · ⛔ CORRER · ✅ CRISIS · ✅ DANAR · ✅ DISCRIMINACION · ✅ HERIDA ·
⛔ MALTRATAR · ⛔ PARAR · ⛔ ROBAR · ⛔ SALVAR · ✅ SOBORNO · ⛔ VIOLACION ·
⛔ VIOLENCIA

### Descripción (18)
✅ AMARILLO · ✅ AZUL · ✅ BLANCO · ✅ CAFE · ✅ CELESTE · ⛔ CORRECTO ·
⛔ DELGADO · ⛔ GRUESO · ⛔ INOCENTE · ✅ LILA · ✅ NARANJA · ✅ NEGRO ·
⛔ PELIGROSO · ✅ PRESO · ✅ ROJO · ✅ ROSADO · ⛔🆕 SEGURO · ✅ VERDE

### Estado y emoción (11)
✅ CONFIANZA · ✅ CONFUSION · ⛔ FALTA · ✅ MAL · ⛔🆕 MIEDO · ⛔ PROBLEMA ·
✅ RAZON · ⛔ SITUACION · ⛔🆕 SOSPECHA · ⛔ TEMOR · ✅ VERGUENZA

### Tiempo (17)
✅ AHORA · ✅ ANO · ✅ ANTEAYER · ⛔🆕 ANTERIORMENTE · ✅ AYER · ✅ DIA ·
✅ FECHA · ✅ HORA · ✅ HOY · ✅ MANANA · ✅ MES · ✅ MINUTO ·
✅ PASADO_MANANA · ⛔🆕 PRIMERA_VEZ · ✅ SEGUNDO · ✅ SEMANA ·
⛔🆕 VARIAS_VECES

### Lugares (16)
⛔ AEROPUERTO · ✅ AVENIDA · ✅ CALLE · ✅ CARCEL · ✅ CASA ·
⛔🆕 CENTRO_DE_SALUD · ✅ COCHABAMBA · ⛔🆕 DEPARTAMENTO · ✅ DIRECCION ·
✅ FARMACIA · ✅ HOSPITAL · ✅ MERCADO · ⛔🆕 PARADA · ⛔🆕 PISO · ✅ PLAZA ·
⛔ UBICACION_GPS

### Documentos (21)
⛔🆕 ANEXO · ✅ ARCHIVADOR · ✅ CARPETA · ⛔ CARTA · ⛔🆕 CERTIFICADO ·
⛔🆕 COMPROBANTE · ⛔🆕 CONSTANCIA · ⛔🆕 FORMATO · ⛔ FORMULARIO ·
✅ FOTOCOPIA · ⛔🆕 HOJA · ⛔ LICENCIA · ⛔ LICENCIA_DECONDUCIR ·
⛔🆕 MEMORIAL · ⛔🆕 OBSERVACION · ✅ PAPEL · ✅ PASAPORTE · ⛔🆕 RESPALDO ·
✅ SELLO · ⛔ TEXTO · ✅ TITULO

### Objetos (18)
✅ AUTO · ✅ AVION · ✅ BICICLETA · ⛔🆕 BILLETERA · ⛔🆕 CAMARA ·
⛔🆕 CUENTA · ⛔ DINERO · ⛔🆕 FOTOGRAFIA · ⛔🆕 MENSAJE · ✅ MICRO ·
✅ MOCHILA · ✅ MOTOCICLETA · ⛔🆕 PRODUCTO · ⛔🆕 PRUEBA · ✅ TAXI ·
✅ TELEFONO · ✅ TREN · ✅ TRUFI

### Comunicación (7)
✅ ACEPTAR · ✅ ATENDER · ✅ AYUDAR · ✅ COMPRENDER · ✅ HABLAR · ✅ RECHAZAR ·
⛔ RESPONDER

### Comunicación digital (4)
⛔ VIDEOLLAMADA · ⛔ WHATSAPP · ⛔ WIFI · ⛔ ZOOM

### Integridad (8)
✅ AUTONOMIA · ✅ COMPROMISO · ✅ CORRUPTO · ⛔ DIGNIDAD · ⛔ ETICA ·
⛔ FIRME · ✅ GARANTE · ✅ HONESTIDAD

### Abecedario (27) — dactilología
✅ A–Z (26) · ⛔ Ñ

### Números (10) — dactilología
✅ 0–9 (todos)

## 3. Resumen de imágenes en S3

Bucket: `opensoul-3d-animations.s3.us-east-1.amazonaws.com/lsb/judicial/`
(verificado con 204 objetos listados el 2026-08-25).

| | Cantidad |
|---|---|
| Vocabulario total | 296 |
| Con imagen en S3 | 174 |
| **Sin imagen en S3** | **122** |

De las 122 sin imagen:

- **71 son vocabulario previo** (70 palabras del corpus judicial oficial +
  `Ñ`), ya identificadas antes de este documento.
- **51 son las glosas nuevas de este corpus conversacional** — ninguna tiene
  imagen todavía, porque son de creación reciente.

### Lista completa de glosas sin imagen en S3

```
ABOGADO, ABUSAR, ACLARAR, ACUERDO_SOCIAL, AEROPUERTO, ANEXO, ANOTAR,
ANTERIORMENTE, ARRESTAR, ARTICULO, ASISTENCIA, AUDIENCIA, AUXILIO, BILLETERA,
CAMARA, CARTA, CASO, CENTRO_DE_SALUD, CERTIFICADO, CITACION, CODIGO,
COMPROBANTE, CONFIRMACION, CONOCER, CONSTANCIA, CONTEXTO, CORRECTO, CORREGIR,
CORRER, CUENTA, DELGADO, DEPARTAMENTO, DESPACHO, DIGNIDAD, DINERO, DOCTOR,
EL, ELLA, ENFERMERA, ESTADO, ETICA, EXIGIR, EXPAREJA, EXPEDIENTE, FALTA,
FAMILIAR, FIRME, FISCAL, FORMATO, FORMULARIO, FOTOGRAFIA, GESTIONAR, GRUESO,
HOJA, IDENTIFICAR, IMPRIMIR, INOCENTE, INSTITUCION, LADRON, LICENCIA,
LICENCIA_DECONDUCIR, MALTRATAR, MEMORIAL, MENSAJE, MIEDO, MILITAR, NARRAR,
NORMA, NOTIFICACION, NUREJ, NO_ENTIENDO, NO_RECUERDO, OBSERVACION, OBSERVAR,
OFICINA, ORGANO_JUDICIAL, PARADA, PARAR, PAREJA, PELIGROSO, PISO, POLICIA,
PRESENTAR, PRIMERA_VEZ, PROBLEMA, PRODUCTO, PRUEBA, PUEDE_REPETIR,
RECONOCER, RECORDAR, REQUISITO, RESOLUCION, RESPALDO, RESPONDER, ROBAR,
SALVAR, SEGUIMIENTO, SEGURO, SITUACION, SOLDADO, SOLUCIONAR, SOSPECHA,
SUBSANACION, TEMOR, TESTIGO, TESTIMONIO, TEXTO, TRAMITE, TRATAR,
UBICACION_GPS, VARIAS_VECES, VECINO, VENTANILLA, VIDEOLLAMADA, VIOLACION,
VIOLENCIA, WEBID, WHATSAPP, WIFI, ZOOM, Ñ
```

Estas tarjetas no rompen la app: `sign_image_resolver.dart` cae al ícono de
respaldo (`semanticIcon`) cuando no hay imagen. Es una brecha de contenido
visual, no de funcionamiento.

## 4. Pendiente (fuera del alcance de este documento)

- Subir imágenes (idealmente descriptivas del concepto, no de lengua de
  señas, según se acordó para las 71 previas) para las 122 glosas listadas
  arriba.
- La brecha estructural identificada por separado — que Consultas y Trámites
  comparten hoy el mismo contexto genérico `orientacion` en vez de zonas
  propias por escenario del corpus — sigue sin resolver; este documento solo
  cubre vocabulario, no la reestructuración de contextos.
