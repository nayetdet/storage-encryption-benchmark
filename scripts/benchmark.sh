#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"
OUTPUT="${OUTPUT:-$RESULTS_DIR/benchmark.csv}"
ERROR_OUTPUT="${ERROR_OUTPUT:-$RESULTS_DIR/benchmark_errors.csv}"
GRAPH_DIR="${GRAPH_DIR:-$RESULTS_DIR/graficos}"
FILE_SIZE_MB="${FILE_SIZE_MB:-512}"
ITERATIONS="${ITERATIONS:-5}"
BLOCK_MB="${BLOCK_MB:-4}"
WARMUP_ITERATIONS="${WARMUP_ITERATIONS:-1}"
PAUSE_SECONDS="${PAUSE_SECONDS:-0.2}"
MIN_FILE_SIZE_MB="${MIN_FILE_SIZE_MB:-512}"
MIN_ITERATIONS="${MIN_ITERATIONS:-5}"
PYTHON_BIN="${PYTHON_BIN:-}"

NORMAL_PATH="${NORMAL_PATH:-${PLAIN_PATH:-/mnt/plain_container}}"
LUKS_PATH="${LUKS_PATH:-/mnt/luks_container}"
VERACRYPT_PATH="${VERACRYPT_PATH:-$HOME/veracrypt_container}"
GOCRYPTFS_PATH="${GOCRYPTFS_PATH:-$HOME/gocryptfs_plain}"

if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x ".venv/bin/python" ]]; then
    PYTHON_BIN=".venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

if (( FILE_SIZE_MB <= 0 || ITERATIONS <= 0 || BLOCK_MB <= 0 || WARMUP_ITERATIONS < 0 )); then
  echo "FILE_SIZE_MB, ITERATIONS e BLOCK_MB precisam ser maiores que zero; WARMUP_ITERATIONS nao pode ser negativo." >&2
  exit 1
fi

if (( FILE_SIZE_MB < MIN_FILE_SIZE_MB )); then
  echo "FILE_SIZE_MB=$FILE_SIZE_MB e pequeno para uma metrica estavel." >&2
  echo "Use pelo menos MIN_FILE_SIZE_MB=$MIN_FILE_SIZE_MB MB, ou ajuste MIN_FILE_SIZE_MB explicitamente se souber o risco." >&2
  exit 1
fi

if (( ITERATIONS < MIN_ITERATIONS )); then
  echo "ITERATIONS=$ITERATIONS gera poucas amostras para estatistica confiavel." >&2
  echo "Use pelo menos MIN_ITERATIONS=$MIN_ITERATIONS repeticoes, ou ajuste MIN_ITERATIONS explicitamente se souber o risco." >&2
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
rm -f "$OUTPUT" "$ERROR_OUTPUT"

csv_escape() {
  local value="${1//\"/\"\"}"
  printf '"%s"' "$value"
}

write_error() {
  local scenario="$1"
  local target="$2"
  local stage="$3"
  local message="$4"

  if [[ ! -e "$ERROR_OUTPUT" ]]; then
    printf "timestamp,scenario,target,stage,message\n" > "$ERROR_OUTPUT"
  fi

  {
    csv_escape "$(date --iso-8601=seconds)"
    printf ","
    csv_escape "$scenario"
    printf ","
    csv_escape "$target"
    printf ","
    csv_escape "$stage"
    printf ","
    csv_escape "$message"
    printf "\n"
  } >> "$ERROR_OUTPUT"
}

validate_case() {
  local name="$1"
  local path="$2"
  local precheck_file="$path/.benchmark_direct_precheck_$$.bin"

  if [[ ! -d "$path" ]]; then
    write_error "$name" "$path" "precheck" "caminho nao existe"
    return 1
  fi

  if [[ ! -w "$path" ]]; then
    write_error "$name" "$path" "precheck" "caminho sem permissao de escrita"
    return 1
  fi

  if ! dd if=/dev/zero of="$precheck_file" bs="${BLOCK_MB}M" count=1 oflag=direct conv=fdatasync status=none >/dev/null 2>&1; then
    rm -f "$precheck_file"
    write_error "$name" "$path" "precheck" "escrita com I/O direto falhou; comparacao ficaria invalida"
    return 1
  fi

  if ! dd if="$precheck_file" of=/dev/null bs="${BLOCK_MB}M" count=1 iflag=direct status=none >/dev/null 2>&1; then
    rm -f "$precheck_file"
    write_error "$name" "$path" "precheck" "leitura com I/O direto falhou; comparacao ficaria invalida"
    return 1
  fi

  rm -f "$precheck_file"
  return 0
}

run_case() {
  local name="$1"
  local path="$2"
  local error_log

  echo "Executando $name em $path..."
  error_log="$(mktemp)"

  if ! "$PYTHON_BIN" scripts/medir_io.py \
    --scenario "$name" \
    --target "$path" \
    --file-size-mb "$FILE_SIZE_MB" \
    --iterations "$ITERATIONS" \
    --block-mb "$BLOCK_MB" \
    --warmup-iterations "$WARMUP_ITERATIONS" \
    --pause-seconds "$PAUSE_SECONDS" \
    --output "$OUTPUT" 2>"$error_log"; then
    local message
    message="$(tr '\n' ' ' < "$error_log")"
    write_error "$name" "$path" "execution" "${message:-medicao falhou}"
    cat "$error_log" >&2
    rm -f "$error_log"
    echo "Benchmark interrompido por erro em $name. Detalhes em: $ERROR_OUTPUT" >&2
    exit 1
  fi

  rm -f "$error_log"
}

validation_errors=0
validate_case "Sem criptografia" "$NORMAL_PATH" || validation_errors=$((validation_errors + 1))
validate_case "LUKS" "$LUKS_PATH" || validation_errors=$((validation_errors + 1))
validate_case "VeraCrypt" "$VERACRYPT_PATH" || validation_errors=$((validation_errors + 1))
validate_case "gocryptfs" "$GOCRYPTFS_PATH" || validation_errors=$((validation_errors + 1))

if (( validation_errors > 0 )); then
  echo "Benchmark interrompido: $validation_errors cenario(s) indisponivel(is)." >&2
  echo "Detalhes em: $ERROR_OUTPUT" >&2
  exit 1
fi

run_case "Sem criptografia" "$NORMAL_PATH"
run_case "LUKS" "$LUKS_PATH"
run_case "VeraCrypt" "$VERACRYPT_PATH"
run_case "gocryptfs" "$GOCRYPTFS_PATH"

if [[ ! -s "$OUTPUT" ]]; then
  echo "Nenhum cenario foi executado. Verifique os caminhos e permissoes." >&2
  exit 1
fi

echo "Resultados salvos em: $OUTPUT"
echo "Cenarios registrados:"
tail -n +2 "$OUTPUT" | cut -d, -f2 | awk '!vistos[$0]++ { print "  - " $0 }'

"$PYTHON_BIN" scripts/gerar_graficos.py --input "$OUTPUT" --output-dir "$GRAPH_DIR"
echo "Resumo estatistico salvo em: $RESULTS_DIR/resumo_estatistico.csv"
