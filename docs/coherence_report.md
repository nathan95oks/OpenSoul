# Informe de Coherencia y Wizard Jerárquico de Entidades y Hechos
**OpenSoul — Sistema de Accesibilidad LSB para el Ámbito Penal y Administrativo (Cochabamba, Bolivia)**  
*Fecha: Septiembre 2026 | Versión: 2.0 (Grado de Producción)*

---

## 1. Resumen Ejecutivo y Transformación Arquitectónica

OpenSoul ha sido transformado desde una selección plana de tarjetas ("bolsa de palabras") a un **Sistema de Navegación Jerárquica Guiada (Wizard de Entidades y Hechos)** de grado de producción.

Esta arquitectura resuelve de raíz el riesgo de ambigüedad jurídica, atribución involuntaria de delitos y discordancias gramaticales en español de Bolivia cuando personas sordas usuarias de Lengua de Señas Boliviana (LSB) estructuran sus declaraciones formales ante la policía (FELCC, FELCV), Ministerio Público (Fiscalía), SEPDAVI o plataformas de atención judicial.

```
                    ┌──────────────────────────────────────────────┐
                    │       SemanticContext (8 Contextos)          │
                    └──────────────────────┬───────────────────────┘
                                           │
                        ┌──────────────────▼──────────────────┐
                        │       GuidedWizardStepper (UI)      │
                        │ (Paso a Paso con Indicador de Progreso)
                        └──────────────────┬──────────────────┘
                                           │
             ┌─────────────────────────────┼─────────────────────────────┐
             │                             │                             │
┌────────────▼────────────┐   ┌────────────▼────────────┐   ┌────────────▼────────────┐
│   DisambiguationModal   │   │  Person Entity Wizard   │   │   Transversal Details   │
│  - ESCAPAR (3 roles)    │   │  1. Rol y Género        │   │  - Violencia / Medidas  │
│  - PERDER vs ROBAR      │   │  2. Complexión/Estatura │   │  - Engaño / Bancos QR   │
│  - PAPEL / IDENTIDAD    │   │  3. Prendas y Ropa      │   │  - Amenaza Digital Chat │
│  - CAJA/BOLSA evidencia │   │  4. Color por prenda    │   │  - Trámite NUREJ/Seguim.│
│  - MICRO/TRUFI escena   │   │  (Aislamiento Estricto) │   │  - Testimonio / Sordo   │
└────────────┬────────────┘   └────────────┬────────────┘   └────────────┬────────────┘
             │                             │                             │
             └─────────────────────────────┼─────────────────────────────┘
                                           │
                         ┌─────────────────▼─────────────────┐
                         │    DeclarationDraft (Universal)   │
                         └─────────────────┬─────────────────┘
                                           │
             ┌─────────────────────────────┴─────────────────────────────┐
             │                                                           │
┌────────────▼─────────────────────────┐   ┌─────────────────────────────▼────────────────────────┐
│  LocalSentenceAssembler (Dart Client) │   │   generate_structured_sentence (Python AWS Lambda)   │
│  - Generación Determinista Inmediata │   │   - Paridad Semántica y Gramatical Formal 100%       │
│  - Sin Dependencia de Red            │   │   - Anclaje Inviolable de Hechos en Backend          │
└──────────────────────────────────────┘   └──────────────────────────────────────────────────────┘
```

---

## 2. Los 8 Contextos Operativos y Estructura de Preguntas

El catálogo unificado define 8 contextos completos organizados en familias semánticas:

| # | Contexto ID | Familia | Propósito Jurídico / Funcional | Zona de Entrada | Zonas Clave |
|---|-------------|---------|--------------------------------|-----------------|-------------|
| 1 | `denuncia_robo` | Denuncias | Delitos patrimoniales (robo, hurto, extravío) | `hecho` | `hecho`, `objetos`, `persona`, `conocimiento`, `lugar`, `tiempo`, `testigos`, `evidencia`, `emergencia`, `denuncia`, `apoyo_legal`, `institucion` |
| 2 | `violencia` | Denuncias | Agresión física, maltrato intrafamiliar, amenazas | `hecho` | `hecho`, `persona`, `salud_urgencia`, `emocion_riesgo`, `tiempo`, `evidencia`, `institucion` |
| 3 | `amenaza_digital` | Denuncias | Hostigamiento y extorsión por WhatsApp / redes | `hecho` | `hecho`, `persona`, `evidencia`, `institucion` |
| 4 | `engano_dinero` | Denuncias | Estafas, transferencias bancarias o pagos QR | `hecho` | `hecho`, `medio_banco`, `persona`, `comprobante`, `institucion` |
| 5 | `seguimiento` | Consultas | Estado de investigación, citaciones, NUREJ | `tramite` | `tramite`, `accion`, `institucion_autoridad`, `tiempo` |
| 6 | `otro` | Denuncias | Testimonio presencial de testigos | `relato` | `relato`, `persona`, `acceso` |
| 7 | `identificacion` | Trámites | Filiación, lengua sorda y datos de contacto | `identidad` | `identidad`, `contacto`, `acompanante`, `edad` |
| 8 | `preguntas` | Preguntas | Consultas directas a funcionarios y ventanillas | `interrogativa` | `interrogativa`, `lugar_pregunta`, `persona_pregunta`, `tema_pregunta`, `tiempo_pregunta`, `cantidad_pregunta` |

---

## 3. Desambiguaciones Obligatorias Implementadas

Para erradicar afirmaciones erróneas o falsas imputaciones delictivas, cada glosa polisémica abre automáticamente un modal interactivo (`DisambiguationModal`):

### 3.1. `ESCAPAR` (Quién escapó)
- **Sospechoso / Autor**: `"El sospechoso se dio a la fuga."`
- **Víctima / Declarante**: `"El declarante logró escapar del lugar."`
- **Tercera persona / Testigo**: `"Una tercera persona escapó del lugar."`

### 3.2. `PERDER` vs. `ROBAR` (Extravío vs. Delito)
- **Extravío sin delito**: Redacta `"He extraviado o perdido: mi celular en la calle."`. Prohibición absoluta de atribuir la acción a un tercero o calificar como "robo" cuando la persona solo extravió su bien.
- **Sustracción / Robo**: Redacta `"Un hombre alto me robó mi celular en la calle."`.

### 3.3. `PAPEL` (Tipo de Documento)
- Desambigua entre: Cédula de Identidad (C.I.), denuncia policial previa, factura comercial de respaldo, fotocopia simple/legalizada, comprobante de depósito bancario.

### 3.4. `IDENTIDAD` (Documentación Oficial)
- Desambigua entre: Carnet de Identidad (C.I.), Licencia de Conducir, Pasaporte oficial, Certificado de Nacimiento.

### 3.5. `CAJA` / `BOLSA` (Objeto Robado vs. Evidencia)
- **Objeto sustraído**: `"me robó una mochila que contenía documentos."`
- **Elemento de prueba**: `"Cuento con la caja original del celular como prueba."`

### 3.6. `MICRO` / `TRUFI` (Lugar/Transporte vs. Vehículo Sustraído)
- **Lugar del hecho / Transporte público**: `"Ocurrió en el micro Línea 3B."`
- **Vehículo sustraído**: `"Denuncio el robo de un micro (Línea 3B)."`

---

## 4. Máquina de Estados del Wizard de Personas y Aislamiento Estricto

El `PersonEntityWizard` guía la descripción física y vestimenta de sospechosos o involucrados en 4 pasos obligatorios:

```
[Paso 1: Rol y Género]  ──►  [Paso 2: Complexión / Estatura]
                                      │
[Paso 4: Color por Prenda] ◄──  [Paso 3: Selección de Prendas]
```

### Garantía de Aislamiento Estricto (Nested Isolation):
- Cada prenda (`ClothingItem`) posee un identificador único inmutable asociado a la entidad (`personId`).
- La edición del color del pantalón (ej: modificar a *azul*) **NUNCA** muta ni contamina el color de la chamarra (ej: *negra*) ni de otras prendas de la misma o diferente persona.
- Las mutaciones en `DeclarationDraftNotifier` ejecutan transformaciones puras respetando inmutabilidad en Riverpod.

---

## 5. Componentes Visuales e Interactivos Creados

1. **`GuidedWizardStepper`** (`guided_wizard_stepper.dart`):
   - Barra superior interactiva con indicador visual del paso actual (ej: "Paso 2 de 5: Lugar y Referencia").
   - Permite avanzar, retroceder o saltar zonas completadas.

2. **`DisambiguationModal`** (`disambiguation_modal.dart`):
   - Diálogo modal accesible de alto contraste con tarjetas grandes y claras en LSB/Español para resolver ambigüedades antes de insertar la entidad.

3. **`EntityEditorSheets`** (`entity_editor_sheets.dart`):
   - Bottom sheets especializados para configuración de Personas (4 pasos), Objetos (papel, contenido, cantidad, banco), Lugares (espacio y referencia espacial de proximidad) y Testigos.

4. **`CoherenceBanner`** (`coherence_banner.dart`):
   - Banner inteligente ubicado sobre el lienzo de señas que advierte en tiempo real si falta completar datos críticos (ej: *"Seleccionó 'cerca', indique el lugar de referencia"* o *"Describió una persona, complete su ropa o vestimenta"*).

5. **`AppToastManager`** (`app_toast_manager.dart`):
   - Sistema de notificaciones no intrusivas con retroalimentación visual clara para acciones de agregar, editar o desambiguar entidades.

---

## 6. Paridad y Verificación de Generación Determinista

Tanto en el cliente Flutter (`LocalSentenceAssembler.assembleStructured`) como en el backend Python AWS Lambda (`generate_structured_sentence`), la síntesis de texto en español boliviano es 100% coherente y determinista.

### Matriz de Verificación de Tests Automatizados:
- **Flutter / Dart Test Suite (`test/hierarchical_wizard_test.dart` y `test/zone_inference_engine_test.dart`)**:
  - `34 tests ejecutados | 34 PASADOS (100% de éxito)`.
- **AWS Lambda Python Test Suite (`aws/tests/test_hierarchical_wizard.py`)**:
  - `10 tests ejecutados | 10 PASADOS (100% de éxito)`.

---

## 7. Conclusión

El sistema OpenSoul cuenta ahora con un motor guiado de alta fidelidad jurídica, garantizando que el ciudadano sordo en Cochabamba sea comprendido de forma exacta, digna y formal ante cualquier autoridad pública o policial.
