#!/usr/bin/env bash
set -euo pipefail

PLAIN_CONTAINER="${PLAIN_CONTAINER:-containers/plain_container.img}"
PLAIN_PATH="${PLAIN_PATH:-/mnt/plain_container}"
PLAIN_SIZE="${PLAIN_SIZE:-1G}"

LUKS_CONTAINER="${LUKS_CONTAINER:-containers/luks_container.img}"
LUKS_MAPPER_NAME="${LUKS_MAPPER_NAME:-luks_bench}"
LUKS_PATH="${LUKS_PATH:-/mnt/luks_container}"
LUKS_SIZE="${LUKS_SIZE:-1G}"

VERACRYPT_CONTAINER="${VERACRYPT_CONTAINER:-containers/veracrypt_container.hc}"
VERACRYPT_PATH="${VERACRYPT_PATH:-$HOME/veracrypt_container}"
VERACRYPT_SIZE="${VERACRYPT_SIZE:-1G}"

setup_plain() {
  mkdir -p "$(dirname "$PLAIN_CONTAINER")"

  if [[ ! -f "$PLAIN_CONTAINER" ]]; then
    echo "Criando container sem criptografia em $PLAIN_CONTAINER com tamanho $PLAIN_SIZE..."
    truncate -s "$PLAIN_SIZE" "$PLAIN_CONTAINER"
  else
    echo "Container sem criptografia ja existe: $PLAIN_CONTAINER"
  fi

  if ! sudo blkid "$PLAIN_CONTAINER" >/dev/null 2>&1; then
    echo "Criando filesystem ext4 no container sem criptografia..."
    sudo mkfs.ext4 -F "$PLAIN_CONTAINER"
  fi

  sudo mkdir -p "$PLAIN_PATH"

  if ! mountpoint -q "$PLAIN_PATH"; then
    echo "Montando container sem criptografia em $PLAIN_PATH..."
    sudo mount -o loop "$PLAIN_CONTAINER" "$PLAIN_PATH"
  fi

  sudo chown "$USER:$USER" "$PLAIN_PATH"
  echo "Sem criptografia pronto em: $PLAIN_PATH"
}

setup_luks() {
  if ! command -v cryptsetup >/dev/null 2>&1; then
    echo "cryptsetup nao encontrado. Instale com: sudo apt install cryptsetup" >&2
    return 1
  fi

  mkdir -p "$(dirname "$LUKS_CONTAINER")"

  if [[ -f "$LUKS_CONTAINER" ]] && ! sudo cryptsetup isLuks "$LUKS_CONTAINER" >/dev/null 2>&1; then
    echo "O arquivo $LUKS_CONTAINER existe, mas nao e um volume LUKS valido."
    read -r -p "Apagar e recriar esse arquivo? [s/N]: " resposta

    if [[ "$resposta" == "s" || "$resposta" == "S" ]]; then
      rm -f "$LUKS_CONTAINER"
    else
      echo "Setup interrompido. Remova o arquivo invalido ou responda 's' para recriar."
      exit 1
    fi
  fi

  if [[ ! -f "$LUKS_CONTAINER" ]]; then
    echo "Criando container LUKS em $LUKS_CONTAINER com tamanho $LUKS_SIZE..."
    truncate -s "$LUKS_SIZE" "$LUKS_CONTAINER"

    echo "Formatando como LUKS. Quando perguntar, digite YES em maiusculo e crie uma senha."
    sudo cryptsetup luksFormat "$LUKS_CONTAINER"
  else
    echo "Container LUKS ja existe: $LUKS_CONTAINER"
  fi

  if [[ ! -e "/dev/mapper/$LUKS_MAPPER_NAME" ]]; then
    echo "Abrindo LUKS em /dev/mapper/$LUKS_MAPPER_NAME..."
    sudo cryptsetup open "$LUKS_CONTAINER" "$LUKS_MAPPER_NAME"
  else
    echo "LUKS ja esta aberto em /dev/mapper/$LUKS_MAPPER_NAME"
  fi

  if ! sudo blkid "/dev/mapper/$LUKS_MAPPER_NAME" >/dev/null 2>&1; then
    echo "Criando filesystem ext4 no LUKS..."
    sudo mkfs.ext4 "/dev/mapper/$LUKS_MAPPER_NAME"
  fi

  sudo mkdir -p "$LUKS_PATH"

  if ! mountpoint -q "$LUKS_PATH"; then
    echo "Montando LUKS em $LUKS_PATH..."
    sudo mount "/dev/mapper/$LUKS_MAPPER_NAME" "$LUKS_PATH"
  fi

  sudo chown "$USER:$USER" "$LUKS_PATH"
  echo "LUKS pronto em: $LUKS_PATH"
}

setup_veracrypt() {
  if ! command -v veracrypt >/dev/null 2>&1; then
    echo "VeraCrypt nao encontrado. Pulando VeraCrypt." >&2
    echo "Instale pelo pacote oficial: https://veracrypt.io/en/Downloads.html" >&2
    return 0
  fi

  mkdir -p "$(dirname "$VERACRYPT_CONTAINER")" "$VERACRYPT_PATH"

  if [[ ! -f "$VERACRYPT_CONTAINER" ]]; then
    echo "Criando container VeraCrypt em $VERACRYPT_CONTAINER com tamanho $VERACRYPT_SIZE..."
    echo "O VeraCrypt vai pedir senha e opcoes no terminal."
    veracrypt --text --create "$VERACRYPT_CONTAINER" --size "$VERACRYPT_SIZE" --encryption AES --hash SHA-512 --filesystem ext4
  else
    echo "Container VeraCrypt ja existe: $VERACRYPT_CONTAINER"
  fi

  if mountpoint -q "$VERACRYPT_PATH"; then
    echo "VeraCrypt ja esta montado em: $VERACRYPT_PATH"
  else
    echo "Montando VeraCrypt em $VERACRYPT_PATH..."
    veracrypt --text "$VERACRYPT_CONTAINER" "$VERACRYPT_PATH"
  fi

  if mountpoint -q "$VERACRYPT_PATH"; then
    sudo mount -o remount,rw "$VERACRYPT_PATH" 2>/dev/null || true
    sudo chown "$USER:$USER" "$VERACRYPT_PATH" 2>/dev/null || true
  fi

  if [[ ! -w "$VERACRYPT_PATH" ]]; then
    echo "Aviso: VeraCrypt montou, mas $VERACRYPT_PATH ainda nao esta com permissao de escrita." >&2
    echo "Rode ./scripts/down.sh e depois ./scripts/setup.sh novamente, conferindo as respostas do VeraCrypt." >&2
  fi

  echo "VeraCrypt pronto em: $VERACRYPT_PATH"
}

setup_plain
echo
setup_luks
echo
setup_veracrypt
echo
echo "Setup finalizado."

echo "Agora rode:"
echo "  FILE_SIZE_MB=64 ITERATIONS=3 ./scripts/benchmark.sh"
