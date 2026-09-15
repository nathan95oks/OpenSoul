import json
import csv
import re
import unicodedata

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

# 1. Load official_dictionary.json
with open("assets/dictionary/official_dictionary.json", "r", encoding="utf-8") as f:
    off_data = json.load(f)

official_entries = off_data["entries"]

# 2. Load assembler lexicon
with open("lib/core/domain/services/local_sentence_assembler.dart", "r", encoding="utf-8") as f:
    dart_text = f.read()

assembler_matches = re.findall(r"'([A-ZÑ_0-9]+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'", dart_text)
assembler_map = {m[0]: {"role": m[1], "es_text": m[2].replace(r"\'", "'")} for m in assembler_matches}

# Role mapping to human readable / backend format
ROLE_DISPLAY = {
    'sujeto': 'SUJETO',
    'personaDesc': 'DESCRIPTOR_PERSONA',
    'rasgo': 'DESCRIPTOR_FISICO',
    'descriptor': 'DESCRIPTOR',
    'verboAgresion': 'VERBO_AGRESION',
    'testigo': 'TESTIGO',
    'verboAccion': 'VERBO_ACCION',
    'arma': 'OBJETO_ARMA',
    'objeto': 'OBJETO',
    'documento': 'DOCUMENTO',
    'lugar': 'LUGAR',
    'institucion': 'INSTITUCION',
    'servicio': 'SERVICIO',
    'emocion': 'ESTADO_EMOCION',
    'urgencia': 'URGENCIA',
    'tramite': 'TRAMITE',
    'motivo': 'ESTADO_MOTIVO',
    'tiempo': 'TIEMPO',
    'marcador': 'MARCADOR_DIALOGO',
    'interrogativa': 'INTERROGATIVA',
}

# 3. Load Section 12 from Corpus_Maestro_Unificado_LSB_v4_Auditado.md
with open("docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md", "r", encoding="utf-8") as f:
    lines = f.readlines()

s12_map = {}
in_s12 = False
for line in lines:
    if "12. Diccionario maestro" in line:
        in_s12 = True
        continue
    if in_s12 and line.startswith("# **13."):
        break
    if in_s12 and line.startswith("|") and not line.startswith("| :-") and not "**Glosa**" in line and not "Glosa" in line:
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 8 and parts[1]:
            g = parts[1].strip()
            item = {
                "spanish_def": parts[2].strip(),
                "id": parts[3].strip(),
                "source": parts[4].strip(),
                "max_uses": parts[5].strip(),
                "priority": parts[6].strip(),
                "audit": parts[7].strip()
            }
            s12_map[g] = item
            s12_map[strip_accents(g)] = item

# Build complete rows
all_rows = []
seen_glosses = set()

# Process official dictionary entries first
for e in official_entries:
    gloss = e.get("gloss", "")
    canonical = e.get("canonicalGloss", gloss)
    display_text = e.get("displayText", gloss)
    category = e.get("categoryId", "")
    priority_num = e.get("priority", 1)
    priority_str = f"P{priority_num}" if isinstance(priority_num, int) else str(priority_num)
    is_frequent = "Sí" if e.get("isFrequent") else "No"
    is_emergency = "Sí" if e.get("isEmergency") else "No"
    contexts = ", ".join(e.get("contexts", []))
    source = e.get("source") or e.get("corpusCategory") or ""
    audit = e.get("audit") or ""
    entry_id = e.get("id", "")

    # Lookup assembler
    g_no_acc = strip_accents(gloss)
    lex = assembler_map.get(gloss) or assembler_map.get(g_no_acc) or {}
    role_raw = lex.get("role", "")
    role = ROLE_DISPLAY.get(role_raw, role_raw.upper() if role_raw else "VOCABULARIO")
    es_assembler = lex.get("es_text", "")

    # Lookup Section 12
    s12 = s12_map.get(gloss) or s12_map.get(g_no_acc) or {}
    spanish_def = s12.get("spanish_def") or display_text.lower()
    if not audit:
        audit = s12.get("audit", "Oficial")
    if not source:
        source = s12.get("source", "Catálogo Oficial OpenSoul")

    all_rows.append({
        "ID": entry_id,
        "Glosa": gloss,
        "Glosa_Canonica": canonical,
        "Significado_Espanol": spanish_def,
        "Forma_Espanol_Oracion": es_assembler,
        "Categoria": category,
        "Rol_Gramatical": role,
        "Prioridad": priority_str,
        "Contextos_Uso": contexts,
        "Fuente_Referencia": source,
        "Es_Frecuente": is_frequent,
        "Es_Emergencia": is_emergency,
        "Tipo_Entrada": "Catálogo Oficial",
        "Estado_Auditoria": audit
    })
    seen_glosses.add(gloss)
    seen_glosses.add(g_no_acc)

# Process remaining assembler / alias entries (not in official dictionary)
alias_count = 0
for k, v in assembler_map.items():
    if k not in seen_glosses and strip_accents(k) not in seen_glosses:
        alias_count += 1
        role_raw = v.get("role", "")
        role = ROLE_DISPLAY.get(role_raw, role_raw.upper() if role_raw else "VOCABULARIO")
        es_assembler = v.get("es_text", "")
        
        # Category estimation from role
        cat_guess = "General"
        if "verbo" in role_raw.lower():
            cat_guess = "Acciones"
        elif "sujeto" in role_raw.lower() or "persona" in role_raw.lower():
            cat_guess = "Identificación"
        elif "institucion" in role_raw.lower():
            cat_guess = "Instituciones"
        elif "objeto" in role_raw.lower() or "arma" in role_raw.lower():
            cat_guess = "Objetos"
        elif "documento" in role_raw.lower():
            cat_guess = "Documentos"
        elif "lugar" in role_raw.lower():
            cat_guess = "Lugares"
        elif "tiempo" in role_raw.lower():
            cat_guess = "Tiempo"
        elif "tramite" in role_raw.lower():
            cat_guess = "Conceptos jurídicos"
        elif "urgencia" in role_raw.lower() or "agresion" in role_raw.lower():
            cat_guess = "Hechos y urgencia"
        elif "emocion" in role_raw.lower() or "estado" in role_raw.lower():
            cat_guess = "Estado y emoción"
        elif "descriptor" in role_raw.lower():
            cat_guess = "Descripción"
        elif "marcador" in role_raw.lower() or "interrogativa" in role_raw.lower():
            cat_guess = "Respuesta"

        all_rows.append({
            "ID": f"alias_{alias_count:03d}",
            "Glosa": k,
            "Glosa_Canonica": k,
            "Significado_Espanol": es_assembler if es_assembler else k.lower(),
            "Forma_Espanol_Oracion": es_assembler,
            "Categoria": cat_guess,
            "Rol_Gramatical": role,
            "Prioridad": "P2",
            "Contextos_Uso": "denuncia_robo, seguimiento, otro",
            "Fuente_Referencia": "Lexicón Ensamblador / Corpus Conversacional 2026",
            "Es_Frecuente": "No",
            "Es_Emergencia": "No",
            "Tipo_Entrada": "Variante / Alias Semántico",
            "Estado_Auditoria": "Regla de Ensamblado"
        })
        seen_glosses.add(k)

print(f"Total rows generated: {len(all_rows)}")
print(f"Official: {len(official_entries)}, Extra Aliases: {alias_count}")

# Fieldnames
fieldnames = [
    "ID",
    "Glosa",
    "Glosa_Canonica",
    "Significado_Espanol",
    "Forma_Espanol_Oracion",
    "Categoria",
    "Rol_Gramatical",
    "Prioridad",
    "Contextos_Uso",
    "Fuente_Referencia",
    "Es_Frecuente",
    "Es_Emergencia",
    "Tipo_Entrada",
    "Estado_Auditoria"
]

# Write to multiple convenient locations:
# 1. assets/dictionary/glosas_opensoul.csv
# 2. docs/glosas_opensoul.csv
# 3. glosas_opensoul.csv (workspace root)
# 4. OpenSoul/glosas_opensoul.csv

paths = [
    "assets/dictionary/glosas_opensoul.csv",
    "docs/glosas_opensoul.csv",
    "glosas_opensoul.csv",
    "../glosas_opensoul.csv"
]

for p in paths:
    with open(p, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_rows)
    print(f"Saved CSV to {p}")
