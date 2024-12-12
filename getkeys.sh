#!/bin/bash

# Variables
GITHUB_KEYS_URL="https://raw.githubusercontent.com/yourusername/yourrepo/main/authorized_keys"
GITHUB_CHECKSUM_URL="https://raw.githubusercontent.com/yourusername/yourrepo/main/authorized_keys.sha256"
LOCAL_KEYS_FILE="$HOME/.ssh/authorized_keys"
TEMP_KEYS_FILE="/tmp/authorized_keys"
TEMP_CHECKSUM_FILE="/tmp/authorized_keys.sha256"
SECTION_START="####### Place keys Below this line. They will be overwritten! ########"
SECTION_END="####### Above this line ########"

# Ensure necessary directories exist
mkdir -p "$HOME/.ssh"

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
CHECKSUM_VALID=$(sha256sum -c "$TEMP_CHECKSUM_FILE" 2>/dev/null)

if [[ "$CHECKSUM_VALID" != "$TEMP_KEYS_FILE: OK" ]]; then
  echo "Error: Checksum validation failed."
  rm -f "$TEMP_KEYS_FILE" "$TEMP_CHECKSUM_FILE"
  exit 1
fi

# Prepare the new section content
NEW_KEYS_CONTENT=$(cat "$TEMP_KEYS_FILE")

# Read or create the local authorized_keys file if it doesn't exist
if [[ ! -f "$LOCAL_KEYS_FILE" ]]; then
  echo "Local authorized_keys file not found. Creating a new one."
  echo -e "$SECTION_START\n\n$SECTION_END" > "$LOCAL_KEYS_FILE"
fi

# Backup the local authorized_keys file
cp "$LOCAL_KEYS_FILE" "${LOCAL_KEYS_FILE}.bak"

# Replace the section within the file
echo "Updating section within authorized_keys..."
awk -v start="$SECTION_START" -v end="$SECTION_END" -v newkeys="$NEW_KEYS_CONTENT" '
  BEGIN { inside = 0 }
  $0 == start { print; inside = 1; print newkeys; next }
  $0 == end { inside = 0 }
  !inside { print }
' "$LOCAL_KEYS_FILE" > "${LOCAL_KEYS_FILE}.tmp" && mv "${LOCAL_KEYS_FILE}.tmp" "$LOCAL_KEYS_FILE"

# Set secure permissions
chmod 600 "$LOCAL_KEYS_FILE"

# Cleanup
rm -f "$TEMP_KEYS_FILE" "$TEMP_CHECKSUM_FILE"

echo "authorized_keys file successfully updated."
