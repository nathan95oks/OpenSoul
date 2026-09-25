# Evidencia de la auditoría del 2026-09-25

Todo lo que aquí se cita se obtuvo ejecutando el código de HEAD `031b821`, sin modificarlo.

## Archivos

| Archivo | Qué es |
|---|---|
| `probe_semantica_test.dart.txt` | Sonda Dart (17 casos, P01–P17). Toca tarjetas reales con `elegirGlosa`, pulsa opciones de las hojas y lee el borrador y la frase. Lleva extensión `.txt` para que `flutter analyze` no la recoja. |
| `probe_dart.json` | Resultado de la sonda Dart. |
| `probe_lambda.py` | Sonda Python: `generate_structured_sentence` con los borradores que envía la app (claves camelCase de `DeclarationDraft.toJson`). |
| `probe_lambda.json` | Resultado de la sonda Python. |

## Reproducir

```bash
# Sonda Dart: copiarla con extensión .dart fuera de test/ y ejecutarla desde la raíz
cp docs/negocio/evidencia/2026-09-25/probe_semantica_test.dart.txt /tmp/probe_semantica_test.dart
flutter test /tmp/probe_semantica_test.dart        # escribe probe_dart.json aquí

# Sonda Python
python docs/negocio/evidencia/2026-09-25/probe_lambda.py
```

La sonda no afirma nada: registra lo que observa. Por eso «pasa» aunque lo observado sea un
defecto. Las pruebas de aceptación están en `../../10_Defectos_Priorizados.md`.

## Casos

| Caso | Qué hace | Lo observado |
|---|---|---|
| P01 | ROBAR + ESCAPAR, elige «La víctima / Yo logré escapar» | «Una persona me robó. Hubo una huida, sin precisar de quién.» |
| P02 | PERDER, elige «Sospecho de robo» | Hechos finales `PERDER` sin tipo; «No sé con certeza qué ocurrió; puede que haya perdido algo.» |
| P03 | PAPEL en `comprobante`, cierra la hoja tocando fuera | PAPEL queda como respuesta; 0 objetos; nada en evidencia |
| P04 | BILLETES en «¿Cómo ocurrió el engaño…?», 150 Bs | Hecho `BILLETES`; objeto `BILLETES:stolen:150`; `fraud.amount = null`; frase sin monto |
| P05 | ENVIAR, BANCO, BILLETES 150 | BANCO abre «Deletrea el nombre de la banco»; «…engaño económico mediante banco.» |
| P06 | SÍ y NO en «¿Desea presentar…?»; tres hechos | `[SÍ, NO]` → `confirmed`; el tercer hecho se descarta |
| P07 | CELULAR en tipo de mensajes y en remitente; TOTAL y AHORA en evidencia | Teclado «Escribe el número»; asistente de sospechoso; canal WhatsApp; «Cuento con total y ahora mismo como prueba.» |
| P08 | NOMBRE en «¿Conoce el nombre o número…?» | Asistente de persona sin campo de texto |
| P09 | Mis datos: nombre Juan, edad 24 | Glosas `NOMBRE J U A N EDAD 2 4`; «El declarante se identifica ante la autoridad competente.» |
| P10 | Preguntas: CUÁNDO + VOLVER | «¿Dónde debo realizar esta consulta o presentar el trámite?» (el ensamblador por glosas daría «¿Cuándo debo volver?») |
| P11 | Respuesta a «¿Le robaron el celular?» | Zona `objetos` sin SÍ; «Quiero comunicar lo siguiente, aunque todavía no completé los detalles.» |
| P12 | HOMBRE en robo, cierra el asistente | HOMBRE queda; 1 persona creada |
| P13 | `CandidateEngine` en las zonas de las capturas y con perfil Policía | Ninguna tarjeta retirada; mismo orden; +30 a todas |
| P14 | `assembleStructured` por contexto | Frases fijas (tabla en `08 §4.7`) |
| P15 | Zona inferida para 20 preguntas del funcionario | Coincide con la réplica de `tool/build_question_matrix.py` en los 20 |
| P16 | Encargo nuevo con el mismo contexto | El objeto CELULAR del encargo anterior sigue en el borrador |
| P17 | CONTINUAR sucesivo en los 8 contextos | Orden real y zonas nunca visitadas (tabla en `08 §3.1`) |

## Capturas

Fotos originales en `C:\Users\LENOVO\Pictures\telegram\` (no se copian al repositorio).
Las diez de `Downloads\Telegram Desktop\photo_2026-09-25_13-13-*.jpg` son copias idénticas.

| Id | Archivo | MD5 |
|---|---|---|
| C01 | photo_2026-09-25_13-16-11.jpg | 2c64b3ae913112d03a3aa0fc97a36495 |
| C02 | photo_2026-09-25_13-16-32.jpg | 8ac17ca5a7ba2fb2dbd452297e6a26d6 |
| C03 | photo_2026-09-25_13-16-36.jpg | 025d205b1fdb0980f82159508216810b |
| C04 | photo_2026-09-25_13-16-41.jpg | 44105b96435b2005ee48acbdd4046d02 |
| C05 | photo_2026-09-25_13-16-46.jpg | 3b1951d78871439a24f9f04f8ba10997 |
| C06 | photo_2026-09-25_13-16-50.jpg | 279b3b2155d44c0c55c87bdb08bc7070 |
| C07 | photo_2026-09-25_13-16-53.jpg | 67d08dc076c0051ce897b04cae2d9c26 |
| C08 | photo_2026-09-25_13-17-01.jpg | 2c9c069591228279efac4c5b1196c2ba |
| C09 | photo_2026-09-25_13-17-06.jpg | 9b6bae02b2895229ee6b78ba6503a5f1 |
| C10 | photo_2026-09-25_13-17-12.jpg | bb236cd5ce141817a44b2152345102e5 |
| C11 | photo_2026-09-25_13-17-17.jpg | 2135a01d442a65050a91ccd68ff9edcf |
| C12 | photo_2026-09-25_13-17-21.jpg | 96e4b1a76d19ed91b0c9bb863cd7b82b |
