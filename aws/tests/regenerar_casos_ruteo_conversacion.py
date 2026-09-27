"""Regenera casos_ruteo_conversacion.json: preguntas del oyente → lectura real.

Cada caso es una pregunta que el funcionario puede hacer en el módulo
Conversación y la pregunta del banco que la persona sorda debe ver para
responder. La lectura (`semanticTurn`) y las glosas finales NO se escriben a
mano: salen de `post_process_glosses` y `build_semantic_turn` de la Lambda
Audio/Texto→LSB. Solo la traducción de Bedrock se sustituye, sin red:

  * `corpus`: las preguntas del funcionario del grafo de diálogo, con su
    traducción LSB del corpus (§6) como salida del modelo;
  * `banco`: la formulación de cada paso de cada recorrido, con su
    formulación LSB (o, si el banco no tiene seña, las palabras del texto,
    que la Lambda deletrea como haría con una salida real);
  * `parafrasis`: formas naturales de pedir los datos más frecuentes, con
    una traducción plausible escrita a mano (`glosasSimuladas`).

La prueba de Flutter `conversation_routing_exhaustive_test.dart` enruta cada
caso con el router real del cliente.

    python aws/tests/regenerar_casos_ruteo_conversacion.py
"""
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(RAIZ, "aws"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install  # noqa: E402

install()
import lambda_text_to_lsb as T  # noqa: E402

GRAFO = os.path.join(RAIZ, "assets", "dialogue", "dialogue_graph.json")
BANCO = os.path.join(RAIZ, "aws", "question_bank.json")
SALIDA = os.path.join(RAIZ, "aws", "tests", "casos_ruteo_conversacion.json")

# (texto del oyente, glosas plausibles de Bedrock, contexto, pregunta esperada)
PARAFRASIS = [
    # Descripción de la persona (el caso reportado y sus variantes).
    ("¿Puedes describir a los agresores?", ["TÚ", "PUEDO", "EXPLICAR", "CÓMO", "ÉL"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("¿Puedes describir a los agresores?", ["TÚ", "PODER", "DESCRIBIR", "AGRESOR"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("¿Puede describir al ladrón?", ["TÚ", "PUEDO", "DESCRIBIR", "LADRÓN"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("puedes describir a los agresores", ["TÚ", "PUEDO", "DESCRIBIR", "HOMBRE"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("Describa a la persona que le robó", ["DESCRIBIR", "PERSONA", "ROBAR", "TÚ"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("¿Cómo era el ladrón?", ["LADRÓN", "CÓMO"], "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("¿Cómo eran los que te robaron?", ["ÉL", "ROBAR", "TÚ", "CÓMO"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    ("¿Qué características tenía?", ["CARACTERÍSTICA", "TENER", "QUÉ"],
     "denuncia_robo", "Q.PER.DESCRIBIR"),
    # Rasgos concretos: van directo a su pregunta.
    ("¿Era hombre o mujer?", ["HOMBRE", "MUJER", "CUÁL"], "denuncia_robo",
     "Q.PER.DESC.SEXO"),
    ("¿Era alto o bajo?", ["ALTO", "BAJO", "CUÁL"], "denuncia_robo",
     "Q.PER.DESC.ESTATURA"),
    ("¿Era flaco o gordo?", ["FLACO", "GORDO", "CUÁL"], "denuncia_robo",
     "Q.PER.DESC.CONTEXTURA"),
    ("¿Qué ropa llevaba?", ["ROPA", "QUÉ", "LLEVAR"], "denuncia_robo",
     "Q.PER.DESC.ROPA"),
    # Tiempo y lugar, con y sin signos.
    ("¿Cuándo te robaron?", ["CUÁNDO", "ROBAR", "TÚ"], "denuncia_robo", "Q.TIE.CUANDO"),
    ("cuando te robaron el celular", ["CUÁNDO", "ROBAR", "CELULAR"], "denuncia_robo",
     "Q.TIE.CUANDO"),
    ("¿A qué hora pasó?", ["HORA", "QUÉ", "PASAR"], "denuncia_robo", "Q.TIE.CUANDO"),
    ("¿Dónde fue?", ["DÓNDE"], "denuncia_robo", "Q.LUG.DONDE"),
    ("donde te robaron", ["PLAZA", "ROBAR"], "denuncia_robo", "Q.LUG.DONDE"),
    ("¿En qué lugar ocurrió?", ["LUGAR", "QUÉ", "PASAR"], "denuncia_robo", "Q.LUG.DONDE"),
    ("¿Dónde te agredieron?", ["DÓNDE", "PEGAR", "TÚ"], "violencia", "Q.LUG.DONDE"),
    ("¿Cuándo ocurrió la agresión?", ["CUÁNDO", "PEGAR"], "violencia", "Q.TIE.CUANDO"),
    # Personas.
    ("¿Quién te agredió?", ["QUIÉN", "PEGAR", "TÚ"], "violencia", "Q.VIO.AGRESOR"),
    ("¿Conoces a la persona que te robó?", ["TÚ", "CONOCER", "PERSONA", "ROBAR"],
     "denuncia_robo", "Q.PER.CONOCE"),
    # Testigos y pruebas.
    ("¿Hubo testigos?", ["TESTIGO", "HABER"], "denuncia_robo", "Q.TES.EXISTE"),
    ("¿Cuántos testigos hubo?", ["TESTIGO", "CUÁNTOS"], "denuncia_robo",
     "Q.TES.CANTIDAD"),
    ("¿Tienes alguna prueba?", ["TÚ", "PRUEBA", "TENER"], "denuncia_robo",
     "Q.EVI.QUE_TIENE"),
    # Qué pasó / qué se llevaron.
    ("¿Qué te robaron?", ["QUÉ", "ROBAR", "TÚ"], "denuncia_robo", "Q.ROB.QUE"),
    ("¿Estás herido?", ["TÚ", "HERIDA", "TENER"], "violencia", "Q.SAL.HERIDO"),
    # Dinero.
    ("¿Cuánto dinero perdiste?", ["BILLETES", "CUÁNTOS", "PERDER"], "engano_dinero",
     "Q.DIN.MONTO"),
]


# Frases probadas en el teléfono (2026-09-27), escritas tal cual, con una
# traducción plausible de Bedrock. `sinTema` es lo que debe pasar si es la
# primera pregunta de la conversación: "directa" (abre la pregunta),
# "selector" (elegir contexto) o "segura" (abre la pregunta o deja que el
# modelo elija entre candidatas reales, nunca otra pregunta).
DISPOSITIVO = [
    ("las amenzas le llegaron por algun medio?",
     ["AMENAZAR", "ESCRIBIR", "LLEGAR", "QUÉ"], "amenaza_digital", "Q.DIG.CANAL", "segura"),
    ("las amenzas le llegaron por algun medio?",
     ["AMENAZAR", "LLEGAR", "CÓMO"], "amenaza_digital", "Q.DIG.CANAL", "segura"),
    ("conoce el numero desde el que le escribieron?",
     ["NÚMERO", "ESCRIBIR", "CONOCER"], "amenaza_digital", "Q.DIG.NUMERO_CONOCE", "directa"),
    ("sigue recibiendo mensajes?", ["AÚN", "MENSAJE", "RECIBIR"],
     "amenaza_digital", "Q.DIG.CONTINUA", "directa"),
    ("sigue recibiendo mensajes?", ["SEGUIR", "ESCRIBIR", "RECIBIR"],
     "amenaza_digital", "Q.DIG.CONTINUA", "directa"),
    ("tiene fotos o videos?", ["FOTOS", "VIDEO", "TENER"], "denuncia_robo",
     "Q.EVI.QUE_TIENE", "segura"),
    # Sin tema, «fotos o videos» abre las pruebas del robo (caso anterior).
    ("tiene fotos o videos?", ["FOTOS", "VIDEO", "TENER"], "amenaza_digital",
     "Q.DIG.CAPTURAS", "libre"),
    ("que tramite desea realizar", ["TRÁMITE", "HACER", "QUERER", "QUÉ"],
     None, "SELECTOR", "selector"),
    ("vino a consultar el estado de su caso", ["VENIR", "SABER", "QUERER"],
     "seguimiento", "Q.SEG.ESTADO_CASO", "directa"),
    ("puede indicar que llevaba puesto el individuo",
     ["HOMBRE", "LLEVAR", "QUÉ", "PUEDO"], "denuncia_robo", "Q.PER.DESC.ROPA", "directa"),
    ("puede decirme la ropa que llevaba puesta o sus colores",
     ["ROPA", "COLOR", "LLEVAR", "DECIR", "PUEDO"], "denuncia_robo",
     "Q.PER.DESC.ROPA", "directa"),
    ("usted fue testigo de un crimen?", ["TÚ", "TESTIGO", "CRIMEN"], "otro",
     "Q.TES.QUE_VIO", "directa"),
    # El color de la ropa (pedido del 2026-09-27).
    ("¿De qué color era su ropa?", ["ROPA", "COLOR", "CUÁL"], "denuncia_robo",
     "Q.PER.DESC.ROPA_COLOR", "directa"),
    ("de que color era la ropa que llevaba", ["ROPA", "COLOR", "LLEVAR", "QUÉ"],
     "denuncia_robo", "Q.PER.DESC.ROPA_COLOR", "directa"),
    # Las que ya funcionaban en el teléfono no pueden romperse.
    ("necesita hablar con el fiscal?", ["FISCAL", "HABLAR", "NECESITAR"],
     "seguimiento", "Q.SEG.HABLAR_FISCAL", "directa"),
    ("tiene su carnet de identidad?", ["TÚ", "CARNET", "TENER"],
     "identificacion", "Q.ID.DOC_TIENE", "directa"),
    ("vino solo o acompañado?", ["VENIR", "SOLO", "ACOMPAÑAR", "CUÁL"],
     "identificacion", "Q.ID.ACOMPANANTE", "directa"),
    ("cuando presento su denuncia", ["QUEJAR", "PRESENTAR", "CUÁNDO"],
     "seguimiento", "Q.SEG.FECHA_DENUNCIA", "directa"),
    ("le sustrajeron o robaron algo de dinero?", ["BILLETES", "ROBAR", "QUÉ"],
     "denuncia_robo", "Q.ROB.QUE", "segura"),
]


def _nodos_oyente(grafo):
    for n in grafo["nodes"]:
        if n.get("speaker") == "hearing" and n.get("bankQuestion") and "C" in n.get("modes", []):
            yield n


def _pasos(banco):
    preguntas = {q["id"]: q for q in banco["preguntas"]}
    for contexto, rec in banco["recorridos"].items():
        for paso in rec["pasos"]:
            q = preguntas.get(paso["pregunta"])
            if q is None or q.get("control") == "derivacion":
                continue
            yield contexto, paso, q


def _sin_notacion(glosas):
    """La notación del corpus como la emitiría el modelo: d(SIGLA) es la
    sigla deletreada y NÚM(...) un número sin valor, que no se traduce."""
    out = []
    for g in glosas or []:
        m = re.fullmatch(r"d\((.+)\)", g)
        if m:
            out.append(m.group(1))
        elif not g.startswith("NÚM("):
            out.append(g)
    return out


def _glosas_de_texto(texto):
    """Las palabras de contenido del texto: lo que la Lambda deletrearía."""
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,}", texto)
    claves = [T.strip_gloss_accents(p.upper()) for p in palabras]
    return [c for c in claves if c not in T._PALABRAS_FUNCION]


def _caso(id_, origen, texto, glosas_modelo, contexto, pregunta, simuladas=False):
    resultado = T.post_process_glosses(
        {"glosses": glosas_modelo, "disambiguation": []}, texto, {})
    caso = {
        "id": id_,
        "origen": origen,
        "texto": texto,
        "contexto": contexto,
        "preguntaEsperada": pregunta,
        "glosasModelo": glosas_modelo,
        "glosas": resultado["glosses"],
        "semanticTurn": T.build_semantic_turn(texto, resultado),
    }
    if simuladas:
        caso["glosasSimuladas"] = True
    return caso


def generar():
    with open(GRAFO, encoding="utf-8") as f:
        grafo = json.load(f)
    with open(BANCO, encoding="utf-8") as f:
        banco = json.load(f)

    casos = []
    for n in _nodos_oyente(grafo):
        texto = n["provenance"].get("spanish") or n["entry"]["phrase"]
        glosas = _sin_notacion(n.get("formulationGlosses")) or _glosas_de_texto(texto)
        casos.append(_caso(n["id"], "corpus", texto, glosas, n["scope"],
                           n["bankQuestion"]))

    for contexto, paso, q in _pasos(banco):
        texto = paso.get("formulacion") or q["formulacion"]
        lsb = q.get("formulacionLsb") or {}
        # La formulación LSB del banco, aunque sea provisional, es más fiel
        # que las palabras sueltas del español.
        glosas = _sin_notacion(lsb.get("glosas"))
        casos.append(_caso(f"banco:{q['id']}@{contexto}", "banco", texto,
                           glosas or _glosas_de_texto(texto), contexto, q["id"],
                           simuladas=not glosas))

    for i, (texto, glosas, contexto, pregunta) in enumerate(PARAFRASIS, 1):
        casos.append(_caso(f"parafrasis-{i:02d}", "parafrasis", texto, glosas,
                           contexto, pregunta, simuladas=True))
    for i, (texto, glosas, contexto, pregunta, sin_tema) in enumerate(DISPOSITIVO, 1):
        caso = _caso(f"dispositivo-{i:02d}", "dispositivo", texto, glosas,
                     contexto, pregunta, simuladas=True)
        caso["sinTema"] = sin_tema
        casos.append(caso)
    return casos


def main():
    casos = generar()
    with open(SALIDA, "w", encoding="utf-8") as f:
        json.dump({"_nota": __doc__.strip().splitlines()[0], "casos": casos},
                  f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{len(casos)} casos generados")


if __name__ == "__main__":
    main()
