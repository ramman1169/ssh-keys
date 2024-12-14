#!/bin/bash

# Variables
GITHUB_KEYS_URL="https://raw.githubusercontent.com/ramman1169/ssh-keys/main/authorized_keys"
GITHUB_CHECKSUM_URL="https://raw.githubusercontent.com/ramman1169/ssh-keys/main/authorized_keys.sha256"
ROOT_KEYS_FILE="/root/.ssh/authorized_keys"
TEMP_KEYS_FILE="/tmp/authorized_keys"
TEMP_CHECKSUM_FILE="/tmp/authorized_keys.sha256"
SECTION_START="####### Place keys Below this line. They will be overwritten! ########"
SECTION_END="####### Above this line ########"

# Ensure necessary directories exist
mkdir -p "/root/.ssh"

# Download the authorized_keys file and checksum from GitHub
echo "Downloading authorized_keys and checksum from GitHub..."
curl -s -o "$TEMP_KEYS_FILE" "$GITHUB_KEYS_URL"
curl -s -o "$TEMP_CHECKSUM_FILE" "$GITHUB_CHECKSUM_URL"

# Verify if downloads succeeded
if [[ ! -f "$TEMP_KEYS_FILE" || ! -f "$TEMP_CHECKSUM_FILE" ]]; then
  echo "Error: Failed to download authorized_keys or checksum file."
  exit 1
fi

# Validate checksum
echo "Validating checksum..."
EXPECTED_CHECKSUM=$(cat "$TEMP_CHECKSUM_FILE")
ACTUAL_CHECKSUM=$(sha256sum "$TEMP_KEYS_FILE" | awk '{print $1}')

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
  echo "Error: Checksum mismatch!"
  echo "Expected: $EXPECTED_CHECKSUM"
  echo "Actual:   $ACTUAL_CHECKSUM"
  exit 1
else
  echo "Checksum validated successfully."
fi

# Backup the root authorized_keys file
if [[ -f "$ROOT_KEYS_FILE" ]]; then
  cp "$ROOT_KEYS_FILE" "${ROOT_KEYS_FILE}.bak"
fi

# Merge the content of the files
echo "Merging content into root authorized_keys file..."
awk -v start="$SECTION_START" -v end="$SECTION_END" -v newkeys="$(cat "$TEMP_KEYS_FILE")" '
  BEGIN { inside = 0 }
  FNR == NR { original_lines[FNR] = $0; next }
  $0 == start { 
    print; inside = 1; 
    print newkeys; 
    next 
  }
  $0 == end { inside = 0 }
  !inside { print }
' "$ROOT_KEYS_FILE" /dev/null > "${ROOT_KEYS_FILE}.tmp"

# Move the updated file into place
mv "${ROOT_KEYS_FILE}.tmp" "$ROOT_KEYS_FILE"

# Set secure permissions
chmod 600 "$ROOT_KEYS_FILE"
chown root:root "$ROOT_KEYS_FILE"

# Cleanup
rm -f "$TEMP_KEYS_FILE" "$TEMP_CHECKSUM_FILE"

echo "Root authorized_keys file successfully updated."
