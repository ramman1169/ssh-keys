#!/bin/bash

# Variables
GITHUB_KEYS_URL="https://raw.githubusercontent.com/ramman1169/ssh-keys/main/authorized_keys"
GITHUB_CHECKSUM_URL="https://raw.githubusercontent.com/ramman1169/ssh-keys/main/authorized_keys.sha256"
ROOT_KEYS_FILE="/root/.ssh/authorized_keys"
TEMP_KEYS_FILE="/tmp/authorized_keys"
TEMP_CHECKSUM_FILE="/tmp/authorized_keys.sha256"
SECTION_START="####### Place keys Below this line. They will be overwritten! ########"
SECTION_END="####### Above this line ########"
SCRIPT_DIR="/root/scripts"
SCRIPT_NAME="update_authorized_keys.sh"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
CRON_HOURLY_SCRIPT="/etc/cron.hourly/update_authorized_keys"

# Ensure necessary directories exist
mkdir -p "/root/.ssh"
mkdir -p "$SCRIPT_DIR"

# Copy the script to /root/scripts
if [[ "$(realpath "$0")" != "$SCRIPT_PATH" ]]; then
  echo "Copying script to $SCRIPT_PATH"
  cp "$0" "$SCRIPT_PATH"
  chmod 700 "$SCRIPT_PATH"
fi

# Add the script to /etc/cron.hourly
if [[ "$(realpath "$0")" != "$CRON_HOURLY_SCRIPT" ]]; then
  echo "Adding script to /etc/cron.hourly"
  cp "$SCRIPT_PATH" "$CRON_HOURLY_SCRIPT"
  chmod 700 "$CRON_HOURLY_SCRIPT"
else
  echo "Script is already in /etc/cron.hourly."
fi

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

# Prepare the new section content
NEW_KEYS_CONTENT=$(cat "$TEMP_KEYS_FILE")
if [[ -z "$NEW_KEYS_CONTENT" ]]; then
  echo "Error: Downloaded authorized_keys file is empty."
  exit 1
fi

# Check if the file exists and has content
if [[ ! -s "$ROOT_KEYS_FILE" ]]; then
  # File does not exist or is empty; create a new one with markers
  echo "Root authorized_keys file is missing or empty. Creating a new one."
  echo -e "$SECTION_START\n$NEW_KEYS_CONTENT\n$SECTION_END" > "$ROOT_KEYS_FILE"
else
  # Backup the root authorized_keys file
  cp "$ROOT_KEYS_FILE" "${ROOT_KEYS_FILE}.bak"

  # Replace the section within the file
  echo "Updating section within root authorized_keys..."
  awk -v start="$SECTION_START" -v end="$SECTION_END" -v newkeys="$NEW_KEYS_CONTENT" '
    BEGIN { inside = 0; replaced = 0 }
    $0 == start {
      print start; print newkeys; inside = 1; replaced = 1; next
    }
    $0 == end && inside == 1 {
      print end; inside = 0; next
    }
    !inside { print }
    END {
      if (replaced == 0) {
        print start; print newkeys; print end
      }
    }
  ' "$ROOT_KEYS_FILE" > "${ROOT_KEYS_FILE}.tmp"

  # Replace the old file with the updated one
  mv "${ROOT_KEYS_FILE}.tmp" "$ROOT_KEYS_FILE"
fi

# Set secure permissions
chmod 600 "$ROOT_KEYS_FILE"
chown root:root "$ROOT_KEYS_FILE"

# Cleanup
rm -f "$TEMP_KEYS_FILE" "$TEMP_CHECKSUM_FILE"

echo "Root authorized_keys file successfully updated."
