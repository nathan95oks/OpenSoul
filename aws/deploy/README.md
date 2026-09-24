# Despliegue de `lambda_function.py` — contrato v3

**Preparado, no ejecutado.** Este paquete espera tu aprobación.

Genera el ZIP con:

```bash
python aws/deploy/build_package.py
```

---

## 1. Qué cambia y por qué importa el orden

| Versión | Lee los hechos | Redacta ESCAPAR como robo | Lee `actorRole` |
|---|---|---|---|
| Desplegada hoy (v2) | `declaration.fact`, uno solo | **Sí** | No (solo `actor_role`) |
| Este paquete (v3) | `declaration.facts`, colección | No | Sí |

**El orden correcto es backend primero, cliente después.**

Un cliente v3 contra la Lambda v2 no falla: responde 200 y redacta **habiendo
perdido el segundo hecho y el protagonista de cada uno**. No devolver error no
es compatibilidad — la petición se acepta y el significado se pierde.

Mientras esa combinación exista, la compuerta del cliente la cubre:
`BackendCompatibility` lee `contractVersion` de la respuesta, avisa de qué se
perdería y usa la redacción local en vez de la remota. **Nunca reduce dos
hechos a uno en silencio.** Pero es una red, no una solución: despliega el
backend primero.

La Lambda v3 sí lee el formato v2, así que un cliente sin actualizar sigue
funcionando (`test_cliente_v2_con_backend_nuevo_sigue_funcionando`).

## 2. Identificación de versión

La respuesta anuncia:

```json
{ "contractVersion": 3, "generatorVersion": 2 }
```

`GENERATOR_VERSION` entra además en la clave de caché. Sin eso, las respuestas
guardadas por el generador con el fallo de ESCAPAR se seguirían sirviendo tras
desplegar la corrección, justo en los casos más frecuentes, que son los que
están en caché.

## 3. Dependencias

Ninguna nueva. `lambda_function.py` usa solo la biblioteca estándar más
`boto3`, que el entorno de Lambda ya provee. El paquete es un único archivo.

## 4. Procedimiento

```bash
# 1. Construir y verificar el paquete
python aws/deploy/build_package.py

# 2. Guardar la versión actual para poder volver
aws lambda get-function --function-name <NOMBRE> \
  --query 'Configuration.Version' --output text > aws/deploy/.version-previa

# 3. Publicar como versión nueva, sin mover el alias todavía
aws lambda update-function-code \
  --function-name <NOMBRE> \
  --zip-file fileb://aws/deploy/lambda_function.zip \
  --publish

# 4. Comprobar contra la versión publicada, NO contra producción
python aws/deploy/smoke_check.py --endpoint <URL-DE-LA-VERSION>

# 5. Solo si el paso 4 pasa entero, mover el alias de producción
aws lambda update-alias --function-name <NOMBRE> \
  --name produccion --function-version <NUEVA>
```

## 5. Comprobación

`aws/deploy/smoke_check.py` envía los fixtures que genera el cliente real
(`test/fixtures/contract/`) y comprueba:

1. `contractVersion: 3` en la respuesta.
2. `solo_escapar` **no** produce una denuncia de robo.
3. `robo_y_huida_sospechoso` dice que huyó el sospechoso.
4. `robo_y_huida_victima` dice que escapó la persona declarante.
5. Los dos anteriores **no** producen el mismo texto.
6. `violencia_estructurada` usa la declaración estructurada.
7. Un `actorRole` inválido devuelve 400.
8. El audio corresponde al texto devuelto.

## 6. Reversión

```bash
aws lambda update-alias --function-name <NOMBRE> \
  --name produccion \
  --function-version $(cat aws/deploy/.version-previa)
```

Revertir es inmediato y no deja rastro en los datos: la Lambda no escribe
estado propio salvo la caché en S3, y las entradas nuevas llevan `g2` en la
clave, así que no colisionan con las que leía la versión anterior. **No hace
falta vaciar el bucket** ni al desplegar ni al revertir.

## 7. Lo que este procedimiento NO verifica

- **Bedrock real.** Todas las pruebas locales usan un doble. El
  comportamiento del modelo ante los prompts nuevos no está medido. El paso 4
  lo ejerce de verdad si el endpoint tiene Bedrock habilitado.
- **Polly real.** Igual: localmente devuelve bytes falsos.
- **Latencia.** No medida.
