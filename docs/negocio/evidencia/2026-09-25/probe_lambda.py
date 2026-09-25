"""Sonda de solo lectura: qué redacta generate_structured_sentence con los
borradores que la app envía hoy (claves camelCase de DeclarationDraft.toJson)."""
import json, os, sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "aws"))
sys.path.insert(0, os.path.join(REPO, "aws", "tests"))
from boto3_stub import install
install()
import lambda_function as L  # noqa

def base(ctx, **kw):
    d = {"contextId": ctx, "speechAct": "statement", "facts": [], "persons": [],
         "objects": [], "location": {"isVehicleTransport": False, "pending": False},
         "time": {"unknown": False}, "witnesses": {"existence": "pending", "willIdentify": False},
         "evidence": [], "injured": False, "medicalHelpRequested": False,
         "willFileComplaint": "pending", "needsLegalSupport": False}
    d.update(kw)
    return d

casos = {
 "A_robo_escapar_victima": base("denuncia_robo",
    facts=[{"id": "f1", "action": "ROBAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"},
           {"id": "f2", "action": "ESCAPAR", "actorRole": "victim", "negated": False, "certainty": "confirmed"}],
    objects=[{"id": "o1", "concept": "CELULAR", "role": "stolen"}]),
 "B_respuesta_celular_sin_hecho": base("denuncia_robo", speechAct="reply",
    objects=[{"id": "o1", "concept": "CELULAR", "role": "stolen"}]),
 "E_engano_monto_banco": base("engano_dinero",
    facts=[{"id": "f1", "action": "ENVIAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}],
    objects=[{"id": "o1", "concept": "BILLETES", "role": "stolen", "quantity": "150", "unit": "bolivianos"}],
    fraud={"currency": "bolivianos", "deliveryMethod": "banco"}),
 "E2_engano_hecho_billetes": base("engano_dinero",
    facts=[{"id": "f1", "action": "BILLETES", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}],
    fraud={"currency": "bolivianos", "deliveryMethod": "celular"}),
 "C_amenaza_celular": base("amenaza_digital",
    facts=[{"id": "f1", "action": "CELULAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}],
    evidence=[{"id": "ev_TOTAL", "concept": "TOTAL", "availability": "confirmed", "offeredToShow": False},
              {"id": "ev_AHORA", "concept": "AHORA", "availability": "confirmed", "offeredToShow": False}],
    digitalThreat={"channel": "WhatsApp", "messageType": "texto", "hasSavedEvidence": True}),
 "H_identificacion_nombre": base("identificacion",
    objects=[{"id": "o1", "concept": "PAPEL", "role": "evidenceSupport", "docType": "Carnet de Identidad (C.I.)"}]),
 "G_preguntas_cuando_volver": base("preguntas", speechAct="question"),
 "violencia_amenazar": base("violencia",
    facts=[{"id": "f1", "action": "AMENAZAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}],
    violence={"aggressionType": "AMENAZAR", "physicalInjury": False, "medicalCareRequested": False, "protectionRequested": False}),
 "otro_aumentar": base("otro",
    facts=[{"id": "f1", "action": "AUMENTAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}]),
 "seguimiento_volver": base("seguimiento"),
 "engano_institucion_abogado": base("engano_dinero", receivingInstitution="ABOGADO",
    facts=[{"id": "f1", "action": "ENGAÑAR", "actorRole": "unknown", "negated": False, "certainty": "confirmed"}]),
}
out = {k: L.generate_structured_sentence(v) for k, v in casos.items()}
out["_casos"] = casos
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_lambda.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for k, v in out.items():
    if k != "_casos":
        print(f"{k}: {v}")
