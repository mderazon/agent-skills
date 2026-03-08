#!/bin/bash
# Cloudflare Markdown Scraper/Converter (Linux/macOS)
# Supports converting files and fetching URLs to Markdown via Cloudflare AI tomarkdown API.

set -euo pipefail

usage() {
  echo "Usage: $0 [--url <URL>] [--file <FILE>] [--options <JSON>] [--method <auto|browser|ai>]"
  echo "  --url       Fetch this URL and convert to markdown"
  echo "  --file      Convert this local file to markdown"
  echo "  --options   conversionOptions JSON string (e.g. '{\"html\":{\"cssSelector\":\"main\"}}')"
  echo "  --method    auto (default), browser (for SPAs), ai (for static/files)"
  exit 1
}

URL=""
FILE=""
OPTIONS="{}"
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
METHOD="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --account) ACCOUNT_ID="$2"; shift 2 ;;
    --token) API_TOKEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$URL" && -z "$FILE" ]]; then
  echo "Error: Must provide either --url or --file." >&2
  usage
fi

if [[ -n "$URL" && -n "$FILE" ]]; then
  echo "Error: Cannot provide both --url and --file." >&2
  usage
fi

[[ -z "$ACCOUNT_ID" ]] && echo "Error: Missing Account ID. Ensure CLOUDFLARE_ACCOUNT_ID is set." >&2 && exit 1
[[ -z "$API_TOKEN" ]] && echo "Error: Missing API Token. Ensure CLOUDFLARE_API_TOKEN is set." >&2 && exit 1

# If file is provided, only AI method works
if [[ -n "$FILE" ]]; then
  if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
  fi
  
  RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/tomarkdown" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -F "files=@$FILE" \
    -F "conversionOptions=$OPTIONS")

  if echo "$RESP" | grep -q '"success":true'; then
    FORMAT=$(echo "$RESP" | jq -r '.result[0].format // empty')
    if [[ "$FORMAT" == "error" ]]; then
      ERR=$(echo "$RESP" | jq -r '.result[0].error // "Unknown error"')
      echo "Conversion Error: $ERR" >&2
      exit 1
    fi
    echo "$RESP" | jq -r '.result[0].data // empty'
    exit 0
  else
    echo "API Error:" >&2
    echo "$RESP" | jq . >&2
    exit 1
  fi
fi

# If URL is provided
if [[ -n "$URL" ]]; then
  # Try Workers AI first (if auto or ai)
  if [[ "$METHOD" == "auto" || "$METHOD" == "ai" ]]; then
    HTML_FILE=$(mktemp --suffix=".html")
    if curl -sL "$URL" -o "$HTML_FILE"; then
      RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/tomarkdown" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -F "files=@$HTML_FILE" \
        -F "conversionOptions=$OPTIONS")
      
      if echo "$RESP" | grep -q '"success":true'; then
        FORMAT=$(echo "$RESP" | jq -r '.result[0].format // empty')
        if [[ "$FORMAT" != "error" ]]; then
          echo "$RESP" | jq -r '.result[0].data // empty'
          rm -f "$HTML_FILE"
          exit 0
        fi
      fi
    fi
    rm -f "$HTML_FILE"
  fi

  # Fallback to Browser Rendering (if auto or browser)
  if [[ "$METHOD" == "auto" || "$METHOD" == "browser" ]]; then
    RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/browser-rendering/markdown" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"url\": \"$URL\"}")
    
    if echo "$RESP" | grep -q '"success":true'; then
      echo "$RESP" | jq -r '.result // empty'
      exit 0
    else
      echo "Browser Rendering Error:" >&2
      echo "$RESP" | jq . >&2
      exit 1
    fi
  fi
  
  echo "Error: Failed to convert page using any available method." >&2
  exit 1
fi
