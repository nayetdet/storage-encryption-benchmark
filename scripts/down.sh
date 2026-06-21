#!/usr/bin/env bash
set -euo pipefail

PLAIN_PATH="${PLAIN_PATH:-/mnt/plain_container}"
LUKS_MAPPER_NAME="${LUKS_MAPPER_NAME:-luks_bench}"
LUKS_PATH="${LUKS_PATH:-/mnt/luks_container}"
VERACRYPT_PATH="${VERACRYPT_PATH:-$HOME/veracrypt_container}"
GOCRYPTFS_PATH="${GOCRYPTFS_PATH:-$HOME/gocryptfs_plain}"

if mountpoint -q "$GOCRYPTFS_PATH"; then
  echo "Desmontando gocryptfs em $GOCRYPTFS_PATH..."
  if command -v fusermount3 >/dev/null 2>&1; then
    fusermount3 -u "$GOCRYPTFS_PATH"
  elif command -v fusermount >/dev/null 2>&1; then
    fusermount -u "$GOCRYPTFS_PATH"
  else
    sudo umount "$GOCRYPTFS_PATH"
  fi
else
  echo "gocryptfs nao esta montado em $GOCRYPTFS_PATH."
fi

echo

if command -v veracrypt >/dev/null 2>&1; then
  if mountpoint -q "$VERACRYPT_PATH"; then
    echo "Desmontando VeraCrypt em $VERACRYPT_PATH..."
    veracrypt --text --dismount "$VERACRYPT_PATH"
  else
    echo "VeraCrypt nao esta montado em $VERACRYPT_PATH."
  fi
else
  echo "VeraCrypt nao encontrado. Pulando desmontagem do VeraCrypt."
fi

echo

if mountpoint -q "$PLAIN_PATH"; then
  echo "Desmontando container sem criptografia em $PLAIN_PATH..."
  sudo umount "$PLAIN_PATH"
else
  echo "Container sem criptografia nao esta montado em $PLAIN_PATH."
fi

echo

if mountpoint -q "$LUKS_PATH"; then
  echo "Desmontando LUKS em $LUKS_PATH..."
  sudo umount "$LUKS_PATH"
else
  echo "LUKS nao esta montado em $LUKS_PATH."
fi

if [[ -e "/dev/mapper/$LUKS_MAPPER_NAME" ]]; then
  echo "Fechando /dev/mapper/$LUKS_MAPPER_NAME..."
  sudo cryptsetup close "$LUKS_MAPPER_NAME"
fi

echo
echo "Volumes desmontados."
