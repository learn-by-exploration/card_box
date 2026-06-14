#!/usr/bin/env bash
# generate-keystore.sh
#
# Generate the upload keystore for Card Box and write the four
# ANDROID_* GitHub Secrets into keystore-details.txt (mode 600).
#
# Run this ONCE on a secure machine, then:
#   1. Move upload-keystore.jks to a long-term backup
#      (1Password / sealed envelope / offline USB).
#      Losing it means losing the ability to publish updates to
#      the same Play Store listing.
#   2. Paste the four values from keystore-details.txt into
#      GitHub → Settings → Secrets and variables → Actions.
#   3. Delete keystore-details.txt from the machine.
#
# The script NEVER commits anything and NEVER prints the keystore
# or the password to stdout.
#
# Requirements: keytool (ships with the JDK on most systems; install
# via `apt install default-jdk` / `brew install openjdk`).

set -euo pipefail

# ── Args ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYSTORE_DIR="${KEYSTORE_DIR:-$SCRIPT_DIR/../android}"
KEYSTORE_FILE="$KEYSTORE_DIR/upload-keystore.jks"
DETAILS_FILE="$KEYSTORE_DIR/keystore-details.txt"
KEY_ALIAS="upload"
KEY_SIZE=2048
VALIDITY_DAYS=10000
DNAME="CN=Card Box, OU=Mobile, O=Common Games, L=NA, S=NA, C=US"

# ── Sanity checks ────────────────────────────────────────────
if [ -e "$KEYSTORE_FILE" ]; then
  echo "ERROR: $KEYSTORE_FILE already exists." >&2
  echo "Refusing to overwrite. If this is intentional, move or delete" >&2
  echo "the existing file first." >&2
  exit 1
fi

command -v keytool >/dev/null 2>&1 || {
  echo "ERROR: 'keytool' not found. Install a JDK and try again." >&2
  exit 1
}

command -v base64 >/dev/null 2>&1 || {
  echo "ERROR: 'base64' not found. Install coreutils and try again." >&2
  exit 1
}

mkdir -p "$KEYSTORE_DIR"

# ── Prompt for password (no echo) ────────────────────────────
read_pw() {
  local pw1 pw2
  while true; do
    read -r -s -p "Enter a keystore password (≥6 chars; recommend ≥16): " pw1
    echo
    read -r -s -p "Confirm password: " pw2
    echo
    if [ "$pw1" != "$pw2" ]; then
      echo "Passwords do not match. Try again." >&2
      continue
    fi
    if [ "${#pw1}" -lt 6 ]; then
      echo "Password is too short (need ≥6 chars)." >&2
      continue
    fi
    PASSWORD="$pw1"
    return 0
  done
}

read_pw

# ── Generate the keystore ────────────────────────────────────
echo "Generating keystore at $KEYSTORE_FILE (RSA-$KEY_SIZE, $VALIDITY_DAYS days)..."

keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -keyalg RSA -keysize "$KEY_SIZE" \
  -validity "$VALIDITY_DAYS" \
  -alias "$KEY_ALIAS" \
  -storepass "$PASSWORD" \
  -keypass "$PASSWORD" \
  -dname "$DNAME" \
  >/dev/null

# ── Write keystore-details.txt ───────────────────────────────
KEYSTORE_BASE64="$(base64 < "$KEYSTORE_FILE" | tr -d '\n')"

umask 077
cat > "$DETAILS_FILE" <<EOF
# Card Box — upload keystore secrets
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Alias: $KEY_ALIAS
# Validity: $VALIDITY_DAYS days
#
# Paste each value below into GitHub → Settings → Secrets and
# variables → Actions → New repository secret. Delete this file
# from the machine once the secrets are in GitHub.
#
# DO NOT commit this file. It is in android/.gitignore.

ANDROID_KEYSTORE_BASE64=$KEYSTORE_BASE64
ANDROID_KEY_ALIAS=$KEY_ALIAS
ANDROID_KEY_PASSWORD=$PASSWORD
ANDROID_STORE_PASSWORD=$PASSWORD
EOF
chmod 600 "$DETAILS_FILE"

# ── Done ─────────────────────────────────────────────────────
echo
echo "✓ Keystore generated: $KEYSTORE_FILE"
echo "✓ Secrets written to:  $DETAILS_FILE  (mode 600)"
echo
echo "Next steps (do these in order):"
echo "  1. Move $KEYSTORE_FILE to a long-term backup"
echo "     (1Password / sealed envelope / offline USB)."
echo "     Losing it means losing the ability to publish updates"
echo "     to the same Play Store listing."
echo "  2. Open $DETAILS_FILE and paste each of the four"
echo "     ANDROID_* values into GitHub → Settings → Secrets and"
echo "     variables → Actions → New repository secret."
echo "  3. Delete $DETAILS_FILE from the machine."
echo "  4. Verify by pushing a small commit to main and watching"
echo "     the 'build-android-release' job log into the"
echo "     'Decode keystore' step successfully."
