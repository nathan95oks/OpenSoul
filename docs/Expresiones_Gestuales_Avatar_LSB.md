# Inventario de expresiones gestuales para el avatar LSB

## Objetivo

Este documento identifica las glosas actuales de OpenSoul que pueden necesitar
un apoyo visual no manual junto al avatar. El apoyo propuesto no modifica el
archivo GLB ni pretende reemplazar la expresión facial propia de la seña: es un
dibujo lineal blanco, pequeño y accesible, mostrado en un costado inferior
mientras se reproduce la glosa correspondiente.

La expresión debe asociarse a la glosa activa, no a toda la frase. No se debe
inferir un sentimiento a partir de un hecho: `VIOLENCIA`, `AMENAZAR`, `PEGAR` o
`ROBAR`, por ejemplo, no significan por sí solos que quien seña esté enojado,
triste o asustado.

## 1. Expresiones emocionales directas

Estas son todas las entradas que el catálogo actual clasifica explícitamente
como **Estado y emoción**, más `DOLOR`, cuyo significado físico sí admite una
expresión inequívoca. Son las únicas aptas para activación automática inicial.

| Glosa | Expresión visual sugerida | Dibujo blanco | Fuente del catálogo | Animación 3D actual | Estado |
|---|---|---|---|---|---|
| `MIEDO` | miedo / alarma | ojos abiertos, cejas elevadas, boca pequeña abierta | M3-T12-05 · M3 · Opuestos II · p.101 | Sí | **Piloto implementable** |
| `TRISTE` | tristeza | cejas interiores elevadas, boca curvada hacia abajo | M4-T04-11 · M4 · Opuestos II · p.51 | No | Esperar animación y revisión LSB |
| `PREOCUPAR` | preocupación | cejas inclinadas, boca tensa | M4-T02-11 · M4 · Verbos IV · p.39 | No | Esperar animación y revisión LSB |
| `CONFIANZA` | seguridad / calma | ojos relajados, sonrisa leve | M4-T11-11 · M4 · General II · p.99 | No | Esperar animación y revisión LSB |
| `DOLOR` | dolor físico | ojos cerrados, cejas contraídas, boca tensa | M2-T13-17 · M2 · Salud sexual y reproductiva · p.91 | No | Esperar animación y revisión LSB |

> La expresión exacta de cada fila debe ser validada por una persona experta
> en LSB antes de declararla definitiva. El dibujo es una ayuda semántica, no
> documentación lingüística de un componente no manual.

## 2. Palabras afectivas dependientes del contexto

El catálogo contiene también `BUENO`, `MEJOR` y `MAL`. No se les asignará una
cara automáticamente en la primera etapa: pueden describir calidad, estado o
valoración sin expresar el ánimo de la persona. Solo deben incorporarse después
de una revisión LSB que establezca cuándo el apoyo visual es correcto.

| Glosa | Posible apoyo | Riesgo si se activa siempre |
|---|---|---|
| `BUENO` | rostro positivo | puede significar calidad, no felicidad |
| `MEJOR` | alivio o rostro positivo | puede ser una comparación objetiva |
| `MAL` | disgusto o malestar | puede calificar un objeto o situación |

`FELIZ` y `ENOJADO` no existen hoy como entradas del catálogo oficial de la
aplicación. Por eso no se deben inventar animaciones ni asociaciones para esas
palabras; primero deben incorporarse al léxico y tener una seña validada.

## 3. Marcadores no manuales gramaticales

Estos elementos también involucran rostro o cabeza en una lengua de señas, pero
no son emociones y no deben usar las caras de la sección 1.

### Preguntas QU-

Las glosas `CÓMO`, `CUÁL`, `CUÁNDO`, `CUÁNTOS`, `DÓNDE`, `QUÉ` y `QUIÉN`
aparecen en el catálogo (M1 · Preguntas · p.97). El banco de preguntas registra
una marca no manual QU-, pero advierte que todavía no está documentada ni
modelada. La marca corresponde a la oración interrogativa completa; no debe
resolverse con un emoji emocional al lado de una sola palabra.

### Preguntas de sí/no

El banco de preguntas exige una marca no manual de pregunta sí/no (cejas y
cabeza), también pendiente de documentación y modelado. Es una propiedad de la
oración, no de la glosa `SÍ` o `NO` aislada.

### Negación y estado cognitivo

`NO`, `NO_PUEDO`, `NO_SABER` y `NO_ESTAR_DE_ACUERDO` pueden llevar movimiento
de cabeza o actitud facial según el enunciado. No deben representarse con una
cara triste o enojada fija. Se requiere un sistema futuro de marcadores no
manuales por alcance de frase.

## 4. Regla de implementación

1. Mostrar el dibujo únicamente mientras su glosa está activa.
2. Dibujarlo en blanco para mantener contraste y coherencia con el avatar.
3. Ubicarlo en el costado inferior izquierdo, sin tapar manos, glosa ni
   controles.
4. Añadir una etiqueta semántica accesible, por ejemplo
   `Expresión: miedo`.
5. No usar emojis del sistema: cambian de color y forma entre plataformas.
6. No asociar sentimientos a hechos ni inferirlos desde el texto circundante.
7. Incorporar nuevas glosas una por una después de revisión visual y LSB.

## 5. Piloto elegido

El primer piloto es `MIEDO` porque:

- pertenece explícitamente a **Estado y emoción**;
- tiene fuente oficial trazada;
- ya posee un clip dentro de `avatar_test.glb`;
- permite comprobar el dibujo junto a una animación real, no sobre un
  marcador de “animación no disponible”.

La validación del piloto debe confirmar tamaño, ubicación, contraste y si la
representación comunica miedo sin distraer de las manos del avatar.
