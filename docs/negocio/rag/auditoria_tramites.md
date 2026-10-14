# Auditoría de trámites (Conversación)

Generada por `python tool/auditar_tramites.py --escribir`. No se edita a mano.

- Escenarios en el corpus: **183**; con recorrido en «Trámites»: **167**; preguntas del banco: **571**.
- Escenarios **sin recorrido** (ninguna pregunta se ofrece): **16**.
- Recorridos **poco profundos** (menos de 8 turnos): **43**.
- Recorridos **sin ramificaciones**: **119** de 167.
- Escenarios marcados como consolidados en otro (los que tenían recorrido dejan de listarse): **4**; con datos editables: **2**.

## Sin recorrido

ESC-DDRR-01, ESC-DDRR-02, ESC-DDRR-03, ESC-DDRR-04, ESC-IMP-04, ESC-IMP-06, ESC-OJ-03, ESC-SEPDEP-02, ESC-FELCC-03, ESC-FELCV-04, ESC-SLIM-02, ESC-DNA-02, ESC-DNA-04, ESC-NOT-01, ESC-SEGIP-04, ESC-DISC-04

## Poco profundos

ESC-IMP-01 (7), ESC-IMP-02 (7), ESC-IMP-03 (6), ESC-FIS-01 (7), ESC-FIS-02 (7), ESC-FIS-03 (7), ESC-FIS-04 (7), ESC-OJ-01 (7), ESC-OJ-02 (7), ESC-OJ-04 (7), ESC-SEPDEP-01 (7), ESC-SEPDEP-03 (6), ESC-SEPDEP-04 (7), ESC-SEPDAVI-01 (7), ESC-SEPDAVI-02 (7), ESC-SEPDAVI-03 (6), ESC-SEPDAVI-04 (6), ESC-FELCC-02 (7), ESC-FELCC-04 (6), ESC-FELCV-01 (7), ESC-FELCV-02 (6), ESC-FELCV-03 (6), ESC-SLIM-01 (6), ESC-SLIM-03 (6), ESC-SLIM-04 (6), ESC-DNA-01 (7), ESC-DNA-03 (6), ESC-NOT-02 (6), ESC-NOT-03 (6), ESC-NOT-04 (6), ESC-SEGIP-01 (7), ESC-SEGIP-02 (6), ESC-SEGIP-03 (7), ESC-SERECI-01 (5), ESC-SERECI-02 (6), ESC-SERECI-03 (6), ESC-SERECI-04 (6), ESC-DISC-02 (6), ESC-DISC-03 (7), ESC-LSB-01 (6), ESC-LSB-02 (6), ESC-LSB-03 (5), ESC-LSB-04 (6)

## Trámites que se ven como el mismo

| Parecido | Más corto | Más profundo | Títulos |
|---|---|---|---|
| 0.75 | ESC-DDRR-04 | ESC-DDRR-103 | Inscripción de compra venta / Inscripción de compra venta de inmueble |
| 0.75 | ESC-DDRR-01 | ESC-DDRR-101 | Folio Real actualizado / Solicitar Folio Real actualizado |
| 0.67 | ESC-SERECI-03 | ESC-SERECI-103 | Duplicado de certificado de defunción / Certificado de defunción |
| 0.67 | ESC-SEGIP-03 | ESC-SEGIP-103 | Reposición por pérdida / Reposición por pérdida o robo |
| 0.67 | ESC-SEGIP-01 | ESC-SEGIP-101 | Cédula por primera vez / Primera cédula de identidad |
| 0.67 | ESC-NOT-03 | ESC-NOT-103 | Contrato de anticrético / Contrato de alquiler o anticrético |
| 0.67 | ESC-NOT-02 | ESC-NOT-103 | Contrato de alquiler / Contrato de alquiler o anticrético |
| 0.67 | ESC-DDRR-11 | ESC-DDRR-12 | Certificado de no propiedad departamental / Certificado de propiedad |
| 0.6 | ESC-SERECI-01 | ESC-SERECI-101 | Duplicado de certificado de nacimiento / Certificado de nacimiento: duplicado o corrección de datos |
| 0.6 | ESC-DDRR-13 | ESC-DDRR-04 | Inscripción de compra venta con documento incompleto / Inscripción de compra venta |
| 0.6 | ESC-DDRR-05 | ESC-DDRR-01 | Folio Real actualizado: titular y matrícula / Folio Real actualizado |
| 0.5 | ESC-SERECI-02 | ESC-SERECI-03 | Duplicado de certificado de matrimonio / Duplicado de certificado de defunción |
| 0.5 | ESC-SERECI-01 | ESC-SERECI-201 | Duplicado de certificado de nacimiento / Pedir un certificado de nacimiento |
| 0.5 | ESC-SERECI-01 | ESC-SERECI-03 | Duplicado de certificado de nacimiento / Duplicado de certificado de defunción |
| 0.5 | ESC-SERECI-01 | ESC-SERECI-02 | Duplicado de certificado de nacimiento / Duplicado de certificado de matrimonio |
| 0.5 | ESC-SEGIP-01 | ESC-SEGIP-301 | Cédula por primera vez / Cédula por primera vez sin certificado de nacimiento |
| 0.5 | ESC-OJ-04 | ESC-OJ-102 | Confirmar modalidad de audiencia / Audiencia y confirmación de modalidad |
| 0.5 | ESC-OJ-01 | ESC-OJ-301 | Consultar causa con NUREJ y WebID / Consultar un proceso y qué hacer sin NUREJ o WebID |
| 0.5 | ESC-NOT-01 | ESC-NOT-101 | Reconocimiento o certificación de firmas / Reconocimiento de firmas y comprensión |
| 0.5 | ESC-DDRR-13 | ESC-DDRR-103 | Inscripción de compra venta con documento incompleto / Inscripción de compra venta de inmueble |
| 0.5 | ESC-DDRR-10 | ESC-DDRR-12 | Certificado de no propiedad a nivel nacional / Certificado de propiedad |
| 0.5 | ESC-DDRR-08 | ESC-DDRR-02 | Certificado de gravámenes: hipoteca o anticresis / Certificado de gravámenes |
| 0.5 | ESC-DDRR-05 | ESC-DDRR-101 | Folio Real actualizado: titular y matrícula / Solicitar Folio Real actualizado |
| 0.5 | ESC-DDRR-02 | ESC-DDRR-102 | Certificado de gravámenes / Consultar gravámenes o certificado alodial |

## Dimensiones por institución

Escenarios de la institución cuyo texto toca cada dimensión.

| Área | Escenarios | requisitos | documento faltante | costos | observaciones | seguimiento | derivación | cierre | con ramificaciones |
|---|---|---|---|---|---|---|---|---|---|
| DDRR | 40 | 40 | 36 | 8 | 4 | 11 | 0 | 7 | 2 |
| DISC | 9 | 8 | 5 | 3 | 0 | 2 | 0 | 5 | 2 |
| DNA | 9 | 5 | 3 | 0 | 0 | 2 | 0 | 7 | 1 |
| FELCC | 12 | 10 | 8 | 2 | 0 | 1 | 2 | 6 | 6 |
| FELCV | 11 | 4 | 4 | 1 | 0 | 1 | 0 | 8 | 4 |
| FIS | 10 | 10 | 5 | 0 | 0 | 3 | 0 | 5 | 5 |
| GAM | 6 | 6 | 6 | 0 | 4 | 4 | 0 | 6 | 1 |
| IMP | 11 | 11 | 6 | 9 | 0 | 5 | 0 | 6 | 2 |
| LSB | 10 | 5 | 3 | 3 | 0 | 0 | 1 | 5 | 4 |
| NOT | 9 | 9 | 4 | 4 | 0 | 4 | 0 | 6 | 4 |
| OJ | 10 | 9 | 7 | 1 | 0 | 8 | 0 | 6 | 3 |
| SEGIP | 9 | 8 | 6 | 3 | 2 | 1 | 1 | 6 | 4 |
| SEPDAVI | 9 | 7 | 5 | 3 | 0 | 1 | 0 | 4 | 2 |
| SEPDEP | 9 | 6 | 7 | 4 | 0 | 0 | 1 | 5 | 3 |
| SERECI | 10 | 10 | 6 | 4 | 3 | 2 | 0 | 6 | 3 |
| SLIM | 9 | 2 | 2 | 3 | 2 | 0 | 1 | 5 | 2 |

## Hechos

- Sin usar por ningún turno: H-DDRR-06, H-OJ-01, H-OJ-08, H-SEPDEP-06, H-FELCC-04, H-FELCC-05, H-SLIM-04, H-SERECI-04, H-LSB-01.
- No se pueden mostrar:
  - H-DDRR-01: vigencia sin confirmar
  - H-DDRR-02: vigencia sin confirmar
  - H-DDRR-03: vigencia sin confirmar
  - H-DDRR-04: vigencia sin confirmar
  - H-DDRR-05: vigencia sin confirmar
  - H-DDRR-06: sin verificar
  - H-DDRR-07: sin verificar
  - H-IMP-07: vencido
  - H-IMP-12: sin verificar
  - H-OJ-07: vigencia sin confirmar
  - H-OJ-08: vigencia sin confirmar
  - H-SEPDEP-06: sin verificar
  - H-FELCC-03: vigencia sin confirmar
  - H-FELCC-04: vigencia sin confirmar
  - H-FELCC-05: sin verificar
  - H-FELCV-04: sin verificar
  - H-SLIM-04: vigencia sin confirmar
  - H-DNA-01: vigencia sin confirmar
  - H-DNA-02: vigencia sin confirmar
  - H-DNA-04: sin verificar
  - H-NOT-04: sin verificar
  - H-SEGIP-05: sin verificar
  - H-SERECI-04: vigencia sin confirmar
  - H-SERECI-05: sin verificar
  - H-DISC-05: vigencia sin confirmar
  - H-DISC-06: sin verificar
