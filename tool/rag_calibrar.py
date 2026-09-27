"""Calibra el umbral de similitud del RAG por significado con la Lambda real.

    python tool/rag_calibrar.py

Envía a `action: "consulta"` paráfrasis que no comparten palabras con el
corpus (y el área que deberían encontrar) y frases sin relación (que no
deberían encontrar nada), con el umbral mínimo permitido para ver todas las
similitudes. Propone el umbral que acepta más paráfrasis sin aceptar ninguna
frase sin relación. Se aplica con la variable de entorno `RAG_MIN_SIMILARITY`
de la Lambda (sin redesplegar) y como valor por defecto en
`aws/rag_consulta.py`.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rag_indexar_embeddings import endpoint, llamar  # noqa: E402

# (frase del funcionario, áreas que la responden). Paráfrasis escritas sin
# copiar el corpus: justo lo que la búsqueda por palabras no encuentra.
PARAFRASIS = [
    ("¿Usted está en peligro ahorita?", {"FELCV", "SLIM"}),
    ("¿Se encuentra a salvo en este momento?", {"FELCV", "SLIM"}),
    ("¿Cuenta con un letrado que lo represente?", {"SEPDEP", "SEPDAVI"}),
    ("¿Sabe los códigos de su expediente judicial?", {"OJ"}),
    ("¿Cuánto adeuda de su motocicleta?", {"IMP"}),
    ("¿Desea pagar lo que debe en partes?", {"IMP"}),
    ("¿Extravió su documento de identidad?", {"SEGIP"}),
    ("¿Necesita que alguien le traduzca a señas?", {"LSB", "FELCV", "SLIM"}),
    ("¿El chico todavía es menor de edad?", {"DNA"}),
    ("¿Van a legalizar las firmas del documento?", {"NOT"}),
    ("¿Requiere otra copia de su acta de casamiento?", {"SERECI"}),
    ("¿Qué grado figura en su credencial de discapacidad?", {"DISC"}),
    ("¿Lo engañaron por redes sociales y transfirió plata?", {"FELCC"}),
    ("¿Prefiere hablar primero con la psicóloga o con la abogada?", {"SLIM", "SEPDAVI"}),
    ("¿Desea formalizar la denuncia hablando, sin escrito?", {"FIS"}),
]

SIN_RELACION = [
    "¿Le gusta el fútbol?",
    "¿Qué comió hoy?",
    "Hace mucho calor esta tarde",
    "¿Cuál es su color favorito?",
    "El partido empieza a las ocho",
    "¿Tiene hermanos que toquen guitarra?",
    "Mañana voy al cine con mi familia",
]


def mejor(url: str, texto: str) -> dict:
    r = llamar(url, {"action": "consulta", "text": texto, "limit": 1,
                     "minSimilarity": 0.3})
    if r.get("generated") is not True:
        raise SystemExit(f"La consulta no está disponible: {r.get('reason')}")
    return r.get("best") or {}


def main() -> int:
    url = endpoint()
    aciertos, fallos = [], []
    print("Paráfrasis (debe encontrar su área):")
    for texto, areas in PARAFRASIS:
        b = mejor(url, texto)
        area = (b.get("scenarioId") or "--").split("-")[1]
        ok = area in areas
        (aciertos if ok else fallos).append(b.get("score", 0))
        print(f"  {b.get('score', 0):.3f} {'OK ' if ok else 'MAL'} {area:<7} «{texto}»"
              f"  → «{b.get('question', '')}»")
    ruido = []
    print("Sin relación (no debe encontrar nada):")
    for texto in SIN_RELACION:
        b = mejor(url, texto)
        ruido.append(b.get("score", 0))
        print(f"  {b.get('score', 0):.3f}     «{texto}»  → «{b.get('question', '')}»")

    techo_ruido = max(ruido)
    # Umbral: justo por encima de la frase sin relación más parecida, sin
    # bajar de 0.3 (el mínimo que acepta la Lambda).
    umbral = round(max(0.3, techo_ruido + 0.02), 2)
    aceptadas = sum(s >= umbral for s in aciertos)
    colados = sum(s >= umbral for s in fallos)
    print()
    print(f"Frase sin relación más parecida: {techo_ruido:.3f}")
    print(f"Umbral propuesto: {umbral}  → acepta {aceptadas}/{len(PARAFRASIS)} "
          f"paráfrasis bien encaminadas; {colados} mal encaminadas pasarían.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
