import json
import csv
import re
import unicodedata

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

# 1. Cargar official_dictionary.json (Tarjetas UI de Flutter y Avatar)
with open("assets/dictionary/official_dictionary.json", "r", encoding="utf-8") as f:
    off_data = json.load(f)

official_entries = off_data["entries"]
official_glosses = set(e["gloss"] for e in official_entries)
official_glosses_no_acc = set(strip_accents(e["gloss"]) for e in official_entries)

# 2. Cargar motor ensamblador (lib/core/domain/services/local_sentence_assembler.dart)
with open("lib/core/domain/services/local_sentence_assembler.dart", "r", encoding="utf-8") as f:
    dart_text = f.read()

assembler_matches = re.findall(r"'([A-ZÑ_0-9]+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'", dart_text)
assembler_map = {m[0]: {"role": m[1], "es_text": m[2].replace(r"\'", "'")} for m in assembler_matches}

ROLE_DISPLAY = {
    'sujeto': 'Sujeto',
    'personaDesc': 'Descriptor Persona',
    'rasgo': 'Descriptor Físico',
    'descriptor': 'Descriptor',
    'verboAgresion': 'Verbo Agresión',
    'testigo': 'Testigo',
    'verboAccion': 'Verbo Acción',
    'arma': 'Arma / Objeto',
    'objeto': 'Objeto',
    'documento': 'Documento',
    'lugar': 'Lugar',
    'institucion': 'Institución',
    'servicio': 'Servicio',
    'emocion': 'Emoción / Estado',
    'urgencia': 'Urgencia',
    'tramite': 'Trámite',
    'motivo': 'Motivo / Estado',
    'tiempo': 'Tiempo',
    'marcador': 'Marcador Diálogo',
    'interrogativa': 'Pregunta / Interrogativa',
}

# 3. Cargar Sección 12 del Corpus Maestro Auditado
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
                "priority": parts[6].strip(),
                "audit": parts[7].strip()
            }
            s12_map[g] = item
            s12_map[strip_accents(g)] = item

all_rows = []
seen_glosses = set()
nro = 1

# Procesar las 346 del Catálogo Oficial
for e in official_entries:
    gloss = e.get("gloss", "")
    display_text = e.get("displayText", gloss)
    category = e.get("categoryId", "")
    priority_num = e.get("priority", 1)
    priority_str = f"P{priority_num}" if isinstance(priority_num, int) else str(priority_num)
    contexts = ", ".join(e.get("contexts", []))
    source = e.get("source") or e.get("corpusCategory") or "Catálogo Oficial OpenSoul"
    entry_id = e.get("id", "")

    g_no_acc = strip_accents(gloss)
    lex = assembler_map.get(gloss) or assembler_map.get(g_no_acc) or {}
    role_raw = lex.get("role", "")
    role = ROLE_DISPLAY.get(role_raw, role_raw.capitalize() if role_raw else "Vocabulario")
    es_assembler = lex.get("es_text", "")

    s12 = s12_map.get(gloss) or s12_map.get(g_no_acc) or {}
    spanish_def = s12.get("spanish_def") or display_text

    all_rows.append({
        "Nro": nro,
        "Glosa_LSB": gloss,
        "Palabra_Espanol": spanish_def,
        "Categoria": category,
        "Estado_Tengo_NoTengo": "",  # Para que el usuario escriba en Excel
        "En_Tarjetas_UI": "SÍ",
        "En_Avatar_3D": "SÍ",
        "En_Motor_Traduccion": "SÍ",
        "Tipo_Entrada": "Catálogo Oficial (Tarjeta y Avatar)",
        "Prioridad": priority_str,
        "Rol_Gramatical": role,
        "Frase_En_Oracion": es_assembler,
        "Contextos_Uso": contexts,
        "Fuente_Oficial": source,
        "ID_Sistema": entry_id,
        "Observaciones": ""
    })
    nro += 1
    seen_glosses.add(gloss)
    seen_glosses.add(g_no_acc)

# Procesar las 51 variantes / alias del ensamblador
for k, v in assembler_map.items():
    if k not in seen_glosses and strip_accents(k) not in seen_glosses:
        role_raw = v.get("role", "")
        role = ROLE_DISPLAY.get(role_raw, role_raw.capitalize() if role_raw else "Vocabulario")
        es_assembler = v.get("es_text", "")
        
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
            "Nro": nro,
            "Glosa_LSB": k,
            "Palabra_Espanol": es_assembler if es_assembler else k.lower(),
            "Categoria": cat_guess,
            "Estado_Tengo_NoTengo": "",
            "En_Tarjetas_UI": "NO",
            "En_Avatar_3D": "NO",
            "En_Motor_Traduccion": "SÍ",
            "Tipo_Entrada": "Variante / Alias Semántico del Motor",
            "Prioridad": "P2",
            "Rol_Gramatical": role,
            "Frase_En_Oracion": es_assembler,
            "Contextos_Uso": "denuncia_robo, seguimiento, otro",
            "Fuente_Oficial": "Lexicón Ensamblador / Corpus Conversacional 2026",
            "ID_Sistema": f"alias_{k.lower()}",
            "Observaciones": "Reconocida por el motor para armar oraciones en español"
        })
        nro += 1
        seen_glosses.add(k)

fieldnames = [
    "Nro",
    "Glosa_LSB",
    "Palabra_Espanol",
    "Categoria",
    "Estado_Tengo_NoTengo",
    "En_Tarjetas_UI",
    "En_Avatar_3D",
    "En_Motor_Traduccion",
    "Tipo_Entrada",
    "Prioridad",
    "Rol_Gramatical",
    "Frase_En_Oracion",
    "Contextos_Uso",
    "Fuente_Oficial",
    "ID_Sistema",
    "Observaciones"
]

target_file = "glosas_analisis_excel.csv"
with open(target_file, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(all_rows)

import shutil
shutil.copy(target_file, "../glosas_analisis_excel.csv")
shutil.copy(target_file, "docs/glosas_analisis_excel.csv")
print(f"Archivo actualizado exitosamente: {target_file} con {len(all_rows)} filas.")
