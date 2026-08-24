#!/usr/bin/env bash
# Lista las imágenes de seña que todavía no están en S3.
#
# El catálogo manda: pregunta al bucket por cada glosa y separa las que ya
# están de las que faltan. Sirve para retomar la subida sin llevar la cuenta
# a mano y para saber, antes de una demo, qué tarjetas van a salir con ícono.
#
#   ./tool/imagenes_pendientes.sh              # solo las P1 (las indispensables)
#   ./tool/imagenes_pendientes.sh --todas      # las 245
#   ./tool/imagenes_pendientes.sh --glb        # el alfabeto y números del avatar
set -uo pipefail

ENV_FILE="${ENV_FILE:-.env}"
BASE=""
[ -f "$ENV_FILE" ] && BASE="$(grep -E '^LSB_SIGN_IMAGES_BASE_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')"
if [ -z "$BASE" ]; then
  echo "Falta LSB_SIGN_IMAGES_BASE_URL en $ENV_FILE" >&2
  exit 1
fi
BASE="${BASE%/}/"

MODO="${1:-p1}"

# S3 devuelve 503 si se le pregunta demasiado seguido: con pausa y reintento
# un 'falta' es de verdad un 'falta' y no una respuesta perdida.
consultar() {
  local url="$1" c
  for _ in 1 2 3; do
    c=$(curl -s -o /dev/null -w '%{http_code}' -I "$url" --max-time 15)
    case "$c" in 200|403|404) echo "$c"; return ;; esac
    sleep 1
  done
  echo "$c"
}

if [ "$MODO" = "--glb" ]; then
  RAIZ="$(dirname "$(dirname "${BASE%/}")")/"
  echo "Animaciones del avatar en ${RAIZ}"
  archivos=$(python3 -c "
import json
d = json.load(open('assets/dictionary/official_dictionary.json'))
for e in d['entries']:
    if e.get('mechanism'):
        print(e['gloss'])")
  sufijo=".glb"; url_base="$RAIZ"
else
  echo "Imágenes de tarjeta en ${BASE}"
  filtro="e['priority'] == 1"
  [ "$MODO" = "--todas" ] && filtro="True"
  archivos=$(python3 -c "
import json
d = json.load(open('assets/dictionary/official_dictionary.json'))
for e in sorted(d['entries'], key=lambda x: (x['priority'], x['gloss'])):
    if not e.get('mechanism') and ($filtro):
        print(e['gloss'])")
  sufijo=".png"; url_base="$BASE"
fi

hay=0; falta=0; pendientes=""
for g in $archivos; do
  sleep 0.35
  if [ "$(consultar "${url_base}${g}${sufijo}")" = "200" ]; then
    hay=$((hay + 1))
  else
    falta=$((falta + 1)); pendientes="$pendientes $g"
  fi
done

echo
echo "  ya están: $hay"
echo "  faltan:   $falta"
if [ "$falta" -gt 0 ]; then
  echo
  echo "Pendientes:"
  for g in $pendientes; do echo "  ${g}${sufijo}"; done
fi
