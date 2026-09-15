import json
import csv
import re
import unicodedata

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

# 1. Official Dictionary JSON (Flutter Cards & UI)
with open("assets/dictionary/official_dictionary.json", "r", encoding="utf-8") as f:
    official_data = json.load(f)

official_entries = official_data["entries"]
official_glosses = set(e["gloss"] for e in official_entries)
official_glosses_no_acc = set(strip_accents(e["gloss"]) for e in official_entries)

# 2. Local Sentence Assembler (Dart client engine)
with open("lib/core/domain/services/local_sentence_assembler.dart", "r", encoding="utf-8") as f:
    dart_text = f.read()

assembler_matches = re.findall(r"'([A-ZÑ_0-9]+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'", dart_text)
assembler_glosses = set(m[0] for m in assembler_matches)

# 3. Avatar 3D Lambda (AVAILABLE_GLOSSES)
with open("aws/lambda_text_to_lsb.py", "r", encoding="utf-8") as f:
    lambda_text = f.read()

m_avail = re.search(r"AVAILABLE_GLOSSES = \{(.*?)\n\}", lambda_text, re.DOTALL)
lambda_avail_glosses = set()
if m_avail:
    for line in m_avail.group(1).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            tokens = [t.strip().strip('"') for t in line.split(",") if t.strip().strip('"')]
            lambda_avail_glosses.update(tokens)

# 4. Backend Cards Lambda (GLOSS_LEXICON)
with open("aws/lambda_function.py", "r", encoding="utf-8") as f:
    lambda_func = f.read()

m_lex = re.search(r"GLOSS_LEXICON = \{(.*?)\n\}", lambda_func, re.DOTALL)
lambda_lex_glosses = set()
if m_lex:
    for line in m_lex.group(1).splitlines():
        line = line.strip()
        if line.startswith('"'):
            km = re.match(r'^"([^"]+)":', line)
            if km:
                lambda_lex_glosses.add(km.group(1))

# Read CSV
with open("glosas_analisis_excel.csv", "r", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    csv_rows = list(reader)

print(f"Total CSV rows: {len(csv_rows)}")
print(f"Official dictionary (Flutter Cards UI): {len(official_glosses)}")
print(f"Local sentence assembler (Flutter engine): {len(assembler_glosses)}")
print(f"Avatar Lambda (AVAILABLE_GLOSSES): {len(lambda_avail_glosses)}")
print(f"Backend Lambda (GLOSS_LEXICON): {len(lambda_lex_glosses)}")

# Analyze each row in CSV
in_cards = 0
in_assembler = 0
in_lambda_avatar = 0
in_lambda_backend = 0

only_assembler = []

for r in csv_rows:
    g = r["Glosa_LSB"]
    g_no_acc = strip_accents(g)
    
    # Check cards
    has_card = (g in official_glosses) or (g_no_acc in official_glosses_no_acc)
    # Check assembler
    has_assembler = (g in assembler_glosses) or (g_no_acc in assembler_glosses)
    # Check avatar lambda
    has_avatar = (g in lambda_avail_glosses) or (g_no_acc in lambda_avail_glosses)
    # Check backend lambda
    has_backend = (g in lambda_lex_glosses) or (g_no_acc in lambda_lex_glosses)

    if has_card: in_cards += 1
    if has_assembler: in_assembler += 1
    if has_avatar: in_lambda_avatar += 1
    if has_backend: in_lambda_backend += 1

    if not has_card:
        only_assembler.append(g)

print(f"\nPresentes en Tarjetas UI Flutter: {in_cards}/397")
print(f"Presentes en Motor Ensamblador Flutter: {in_assembler}/397")
print(f"Presentes en Lambda Avatar 3D: {in_lambda_avatar}/397")
print(f"Presentes en Lambda Backend Oraciones: {in_lambda_backend}/397")

print(f"\nLas 51 que están en el motor/oraciones pero NO como tarjeta visual directa:")
print(only_assembler)
