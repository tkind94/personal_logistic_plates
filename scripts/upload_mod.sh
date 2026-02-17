#!/bin/bash
set -euo pipefail

MOD_NAME="$1"
FILE_PATH="$2"
TOKEN="$3"

if [ -z "$MOD_NAME" ] || [ -z "$FILE_PATH" ] || [ -z "$TOKEN" ]; then
    echo "Usage: $0 <mod_name> <file_path> <token>"
    exit 1
fi

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

echo "Initializing release upload for '$MOD_NAME'..."
INIT_RESPONSE=$(curl -s -X POST "https://mods.factorio.com/api/v2/mods/releases/init_upload" \
    -H "Authorization: Bearer $TOKEN" \
    -d "mod=$MOD_NAME")

UPLOAD_URL=$(echo "$INIT_RESPONSE" | jq -r '.upload_url')

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" == "null" ]; then
    echo "Failed to initialize upload."
    echo "Response: $INIT_RESPONSE"
    exit 1
fi

echo "Uploading to $UPLOAD_URL..."
# The upload endpoint expects the file in a multipart form field named 'file'.
# Capture response body for better CI diagnostics.
RESPONSE_TMP=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_TMP" -X POST "$UPLOAD_URL" -F "file=@$FILE_PATH")

if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Upload failed with status code $HTTP_CODE"
    echo "Response from mod portal:"
    cat "$RESPONSE_TMP" || true
    rm -f "$RESPONSE_TMP"
    exit 1
fi

rm -f "$RESPONSE_TMP"

echo "Upload successful!"
