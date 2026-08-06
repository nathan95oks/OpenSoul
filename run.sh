#!/usr/bin/env bash
# Lee .env y arranca `flutter run` con las variables como --dart-define.
#
# Uso:
#   ./run.sh                          # elige dispositivo automáticamente
#   ./run.sh -d emulator-5554         # dispositivo concreto
#   ./run.sh -d chrome --release      # cualquier flag extra pasa a flutter run
#
# Formato .env: una VARIABLE=valor por línea. # inicia comentario.

set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: no existe '$ENV_FILE'. Copia .env.example a .env y rellénalo." >&2
  exit 1
fi

dart_defines=()
while IFS= read -r raw || [ -n "$raw" ]; do
  line="$(echo "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  key="${line%%=*}"
  val="${line#*=}"
  val="${val%\"}"
  val="${val#\"}"
  val="${val%\'}"
  val="${val#\'}"
  dart_defines+=("--dart-define=${key}=${val}")
done < "$ENV_FILE"

echo "flutter run ${dart_defines[*]} $*" >&2
exec flutter run "${dart_defines[@]}" "$@"
