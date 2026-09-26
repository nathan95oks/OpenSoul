"""Probe manual del ruteo real de Bedrock, ejecutado en un proceso limpio.

No se descubre como test por sí solo. ``test_bedrock_real_opt_in.py`` lo
ejecuta cuando RUN_BEDROCK_REAL_TESTS=1, con las credenciales y región del
entorno. Así la suite normal conserva los dobles deterministas de Bedrock.
"""

import json
import os
import sys

AWS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, AWS_DIR)

import lambda_function as backend  # noqa: E402


TURN = {
    "turnId": "bedrock-real-probe",
    "text": "¿Viene a consultar un trámite o a presentar una denuncia?",
    "speechAct": "question",
    "intent": "mentionContext",
    "entities": ["TU", "VENIR", "CONSULTAR", "QUEJAR"],
    "mentionedContexts": [
        {"id": "seguimiento"},
        {"id": "denuncia_robo"},
    ],
    "requestedSlots": [],
}

CANDIDATES = [
    {
        "id": "DIRECT_CONTEXT|consultas|seguimiento|",
        "routeType": "DIRECT_CONTEXT",
        "targetContextId": "seguimiento",
        "targetFamilyId": "consultas",
        "targetQuestionIds": [],
        "requestedSlots": [],
        "label": "Abrir Consultar trámite",
    },
    {
        "id": "DIRECT_CONTEXT|denuncias||",
        "routeType": "DIRECT_CONTEXT",
        "targetFamilyId": "denuncias",
        "targetQuestionIds": [],
        "requestedSlots": [],
        "label": "Abrir Denuncias",
    },
]


def main():
    bank = backend._guided_bank()
    clean = []
    for candidate in CANDIDATES:
        validated, error = backend.validate_route_candidate(candidate, bank)
        if error:
            raise AssertionError(error)
        clean.append(validated)

    result = backend.invoke_bedrock_json(
        backend.build_route_prompt(TURN, clean, None)
    )
    allowed = {candidate["id"] for candidate in clean}
    selected = result.get("candidateId")
    if selected is not None and selected not in allowed:
        raise AssertionError(f"Bedrock devolvió una ruta no permitida: {selected!r}")
    confidence = float(result.get("confidence", 0))
    if not 0 <= confidence <= 1:
        raise AssertionError(f"Confianza fuera de rango: {confidence!r}")

    print(json.dumps({
        "modelId": backend.BEDROCK_MODEL_ID,
        "candidateId": selected,
        "confidence": confidence,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
