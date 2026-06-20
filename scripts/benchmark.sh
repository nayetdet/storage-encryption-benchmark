#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"
OUTPUT="${OUTPUT:-$RESULTS_DIR/benchmark.csv}"
GRAPH_DIR="${GRAPH_DIR:-$RESULTS_DIR/graficos}"
FILE_SIZE_MB="${FILE_SIZE_MB:-512}"
ITERATIONS="${ITERATIONS:-5}"
BLOCK_MB="${BLOCK_MB:-4}"
PYTHON_BIN="${PYTHON_BIN:-}"

NORMAL_PATH="${NORMAL_PATH:-${PLAIN_PATH:-/mnt/plain_container}}"
LUKS_PATH="${LUKS_PATH:-/mnt/luks_container}"
VERACRYPT_PATH="${VERACRYPT_PATH:-$HOME/veracrypt_container}"

if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x ".venv/bin/python" ]]; then
    PYTHON_BIN=".venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

if (( FILE_SIZE_MB <= 0 || ITERATIONS <= 0 || BLOCK_MB <= 0 )); then
  echo "FILE_SIZE_MB, ITERATIONS e BLOCK_MB precisam ser maiores que zero." >&2
  exit 1
fi

if (( FILE_SIZE_MB % BLOCK_MB != 0 )); then
  echo "FILE_SIZE_MB precisa ser multiplo de BLOCK_MB para usar I/O direto com dd." >&2
  echo "Exemplo: FILE_SIZE_MB=512 BLOCK_MB=4" >&2
  exit 1
fi

if ! command -v dd >/dev/null 2>&1; then
  echo "dd nao encontrado." >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR" "$GRAPH_DIR"
export MPLCONFIGDIR="${MPLCONFIGDIR:-$RESULTS_DIR/matplotlib-cache}"
mkdir -p "$MPLCONFIGDIR"
rm -f "$OUTPUT"

run_case() {
  local name="$1"
  local path="$2"

  if [[ ! -d "$path" ]]; then
    echo "Ignorando $name: caminho nao existe ($path)." >&2
    return 0
  fi

  if [[ ! -w "$path" ]]; then
    echo "Ignorando $name: caminho sem permissao de escrita ($path)." >&2
    return 0
  fi

  echo "Executando $name em $path..."
  "$PYTHON_BIN" scripts/medir_io.py \
    --scenario "$name" \
    --target "$path" \
    --file-size-mb "$FILE_SIZE_MB" \
    --iterations "$ITERATIONS" \
    --block-mb "$BLOCK_MB" \
    --output "$OUTPUT"
}

run_case "Sem criptografia" "$NORMAL_PATH"
run_case "LUKS" "$LUKS_PATH"
run_case "VeraCrypt" "$VERACRYPT_PATH"

if [[ ! -s "$OUTPUT" ]]; then
  echo "Nenhum cenario foi executado. Verifique os caminhos e permissoes." >&2
  exit 1
fi

echo "Resultados salvos em: $OUTPUT"
echo "Cenarios registrados:"
tail -n +2 "$OUTPUT" | cut -d, -f2 | awk '!vistos[$0]++ { print "  - " $0 }'

"$PYTHON_BIN" scripts/gerar_graficos.py --input "$OUTPUT" --output-dir "$GRAPH_DIR"
