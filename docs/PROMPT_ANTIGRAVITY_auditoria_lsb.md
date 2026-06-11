# Prompt para Antigravity — Auditoría lingüística del vocabulario LSB

> Copia y pega TODO lo que está debajo de esta línea en Antigravity.

---

## ROL

Eres un auditor lingüístico de Lengua de Señas Boliviana (LSB). Tu trabajo es **verificar contra fuentes oficiales** si el vocabulario usado en un módulo de software corresponde a señas/términos que una persona Sorda boliviana realmente conoce y usa, o si fueron inventados por el desarrollador. NO debes asumir ni inventar: cada conclusión debe estar respaldada por los PDFs oficiales que te doy.

## CONTEXTO DEL PROYECTO — OpenSoul

OpenSoul es una aplicación de accesibilidad (Flutter + backend AWS) para **personas Sordas en Bolivia**, orientada a trámites y situaciones reales en entidades públicas: denuncias policiales, defensoría, hospitales, SEGIP, alcaldía, fiscalía, etc. El objetivo es que una persona Sorda pueda comunicarse con un funcionario oyente.

La app tiene **dos módulos independientes**:

- **`audio_to_lsb`** — convierte voz/texto del funcionario a glosas LSB. **NO es mi parte, NO lo audites.**
- **`lsb_to_text_audio`** — **ESTA ES MI PARTE.** El usuario Sordo selecciona tarjetas (cards) con glosas LSB; el sistema arma una oración en español formal y genera audio. Cada tarjeta representa una **seña/palabra** que el usuario Sordo debe reconocer visualmente.

**El problema que quiero auditar:** las tarjetas de mi módulo usan ~154 palabras/glosas. Yo (el desarrollador) las elegí por sentido común, pero **necesito confirmar que esas palabras/conceptos efectivamente existen y se enseñan en la LSB oficial**, porque si invento un término que la comunidad Sorda no conoce, la herramienta no sirve: la persona Sorda no sabría qué tarjeta tocar.

## FUENTES OFICIALES (obligatorio basarte SOLO en estas)

Curso de Enseñanza de la Lengua de Señas Boliviana — Ministerio de Educación de Bolivia (Viceministerio de Educación Alternativa y Especial / DGEE):

1. Módulo 1: https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/CURSO-DE-ENSENANZA-DE-LA-LENGUA-DE-SENAS-BOLIVIANA-Modulo-1.pdf
2. Módulo 2: https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Curso-de-ensenanza-de-la-LSB-MODULO-2.pdf
3. Módulo 3: https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Modulos-de-ensenanza-de-la-LSB-MODULO-3.pdf
4. Módulo 4: https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Curso-de-ensenanza--LSB-Mod-4.pdf

Lee/descarga los 4 PDFs y construye un índice del vocabulario (señas y palabras) que enseñan. Si algún PDF no se puede leer, indícalo explícitamente y NO inventes su contenido.

## CRITERIOS DE CLASIFICACIÓN

Para **cada una de las 154 glosas** de mi módulo, clasifícala en una de estas categorías:

- ✅ **CONFIRMADO** — la palabra/seña aparece tal cual en al menos un módulo. Indica en cuál (Módulo N) y, si puedes, página/unidad temática.
- 🔁 **VARIANTE / SINÓNIMO** — el concepto existe en los PDFs pero con otra palabra o forma (ej. el PDF dice "HURTO" y yo uso "ROBAR"). Indica el término oficial y recomienda si conviene renombrar mi tarjeta.
- 🟡 **NO ENCONTRADO COMO SEÑA DIRECTA** — la palabra no figura como seña propia en los módulos. Aquí distingue dos sub-casos:
  - Es un concepto que probablemente se expresa por **dactilología (deletreo manual)** o por **seña compuesta** (típico en nombres propios de instituciones o tecnicismos: SEGIP, FISCALÍA, ANTECEDENTES PENALES, DECLARACIÓN JURADA). Márcalo y explica.
  - Es un término que **no parece pertenecer al repertorio enseñado** y podría ser invención mía → bandera roja, sugiere alternativa o validación con intérprete.
- ❌ **AUSENTE / PROBLEMÁTICO** — no aparece y además no tiene forma evidente de expresarse; recomienda eliminar o reemplazar la tarjeta.

Ten en cuenta que la LSB es lengua **viso-gestual**: los PDFs enseñan señas con imágenes y descripciones, no solo listas de palabras. Considera categorías temáticas (familia, colores, tiempo, lugares, verbos, emergencias, etc.) que suelen cubrir estos cursos básicos.

## VOCABULARIO A AUDITAR (formato: GLOSA → texto mostrado al usuario)

```
IDENTIFICACIÓN: YO, FAMILIA, HIJO(HIJO/A), ESPOSO(ESPOSO/A), MAMA(MAMÁ), PAPA(PAPÁ), HERMANO(HERMANO/A)
DESCRIPCIÓN-PERSONAS: HOMBRE, MUJER, JOVEN, NIÑO, DESCONOCIDO, VECINO, GRUPO, ADULTO, ANCIANO, SOLO(UNA PERSONA), DOS(DOS PERSONAS), TRES_MAS(TRES O MÁS), CONOCIDO
DESCRIPCIÓN-FÍSICA: ALTO, BAJO, DELGADO, GORDO(GORDO/ROBUSTO), FUERTE(FUERTE/MUSCULOSO), MORENO, BLANCO_PIEL(PIEL CLARA)
CABELLO: PELO_CORTO, PELO_LARGO, CALVO(CALVO/RAPADO), BARBA(CON BARBA), BIGOTE(CON BIGOTE)
MARCAS: TATUAJE, CICATRIZ, LENTES(CON LENTES), MASCARA(MÁSCARA/CARA TAPADA)
VESTIMENTA: GORRA, CAPUCHA, CHOMPA(CHOMPA/CHAQUETA), CASCO, CAMISETA(CAMISETA/POLERA), PANTALON(PANTALÓN), ZAPATILLAS, MOCHILA_USADA(CON MOCHILA)
COLORES: NEGRO, BLANCO, AZUL, ROJO, GRIS, VERDE, OSCURO(COLOR OSCURO), CLARO(COLOR CLARO)
AGRESIÓN: ROBAR, GOLPEAR, AMENAZAR, EMPUJAR, GRITAR, QUITAR, PERSEGUIR, ASALTAR, ACOSAR, ABUSO(ABUSO SEXUAL), SECUESTRAR
ACCIONES/VERBOS: TRAMITAR, SOLICITAR, CONSULTAR, NECESITAR, PAGAR, RENOVAR, RECOGER, ENTREGAR, PERDER, CORREGIR(CORREGIR DATOS)
EMOCIONES: MIEDO, ENOJO, TRISTE, ASUSTADO, NERVIOSO
ESTADO/URGENCIA: URGENTE, AYUDA, EMERGENCIA, ENFERMO, DOLOR, CONFUNDIDO
OBJETOS: CELULAR, DINERO, MOCHILA, BOLSA, LLAVE, CUCHILLO(CUCHILLO/ARMA), AUTO, MOTO, BILLETERA, TARJETA(TARJETA BANCARIA), RELOJ, CADENA, ANILLO, COLLAR, ARETES, LAPTOP(LAPTOP/COMPUTADORA), AUDIFONOS, LENTES_SOL(LENTES DE SOL), BICICLETA
DOCUMENTOS: CARNET, DOCUMENTO, CERTIFICADO, PARTIDA_NACIMIENTO(PARTIDA NAC.), LICENCIA, FACTURA, ANTECEDENTES(ANTECEDENTES PENALES), COPIA_DENUNCIA, COPIA_SENTENCIA, PODER(PODER NOTARIAL), DECLARACION_JURADA
LUGARES: CALLE, CASA, MERCADO, PARADA, MICRO(MICRO/BUS), PARQUE, TRABAJO, CAJERO(CAJERO AUTOMÁTICO), BANCO, TAXI(TAXI/TRUFI), PLAZA, ESQUINA, PUENTE
INSTITUCIONES: POLICIA(POLICÍA), DEFENSORIA(DEFENSORÍA), SEGIP, HOSPITAL(HOSPITAL/CLÍNICA), ALCALDIA(ALCALDÍA), REGISTRO_CIVIL(REG. CIVIL), FISCALIA(FISCALÍA), JUZGADO, NOTARIA(NOTARÍA)
SERVICIOS: INTERPRETE(INTÉRPRETE), AMBULANCIA, DOCTOR, ABOGADO, INFORMACION(INFORMACIÓN), ORIENTACION(ORIENTACIÓN)
CONSULTAS/TRÁMITES: DENUNCIA, CONSULTA, RECLAMO, RENOVACION(RENOVACIÓN), PAGO, DUPLICADO
TIEMPO: HOY, AHORA, AYER, MAÑANA(DÍA/MAÑANA), TARDE, NOCHE
```

## ENTREGABLE (lo que quiero que produzcas)

1. **Tabla maestra** con una fila por glosa, columnas:
   `GLOSA | Categoría | Estado (✅/🔁/🟡/❌) | Fuente (Módulo N / pág / unidad) | Término oficial sugerido | Recomendación`
   La columna *Recomendación* debe decir una de: **MANTENER** · **RENOMBRAR a "X"** · **VALIDAR con intérprete** · **ELIMINAR/REEMPLAZAR**.

2. **Resumen ejecutivo**: cuántas glosas quedaron en cada estado (con porcentajes) y veredicto general de qué tan alineado está el módulo con la LSB oficial.

3. **Lista de acción priorizada**: solo las glosas que requieren cambio (🟡/❌/🔁 con recomendación de renombrar), ordenadas por riesgo, con la justificación basada en el PDF.

4. **Vacíos detectados**: conceptos importantes para el contexto (denuncia, trámites, emergencia) que SÍ están en los PDFs pero que NO tengo como tarjeta y debería considerar agregar.

5. **Limitaciones**: indica qué no pudiste verificar (PDFs ilegibles, conceptos que requieren video de seña, nombres propios que solo se deletrean) y qué pasos de validación humana (intérprete LSB / asociación de Sordos) recomiendas como cierre.

## REGLAS DURAS

- No marques nada como CONFIRMADO sin haberlo encontrado realmente en un PDF. Ante la duda → 🟡 NO ENCONTRADO + VALIDAR.
- Cita el módulo (y página si es posible) en cada CONFIRMADO/VARIANTE.
- No modifiques código todavía: esta es una auditoría. Primero el reporte; los cambios los decido yo a partir de tus recomendaciones.
- Responde en español.
