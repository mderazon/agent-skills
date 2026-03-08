#!/bin/bash
# Cloudflare Markdown Scraper/Converter (Linux/macOS)
# Supports converting files and fetching URLs to Markdown via Cloudflare AI tomarkdown API.

set -euo pipefail

usage() {
  echo "Usage: $0 [--url <URL> | --file <FILE>] [options]"
  echo "Credentials:"
  echo "  --account   Cloudflare Account ID (optional if CLOUDFLARE_ACCOUNT_ID is set)"
  echo "  --token     Cloudflare API Token (optional if CLOUDFLARE_API_TOKEN is set)"
  echo ""
  echo "Sources:"
  echo "  --url       Fetch this URL and convert to markdown"
  echo "  --file      Convert this local file to markdown"
  echo ""
  echo "Options:"
  echo "  --method    auto (default), browser (for SPAs), ai (for static/files)"
  echo "  --options   conversionOptions JSON for AI (e.g. '{\"html\":{\"cssSelector\":\"main\"}}')"
  echo "  --wait      Wait condition for browser: load, domcontentloaded (default), networkidle0, networkidle2"
  echo "  --selector  Wait for this CSS selector to appear in browser mode before converting"
  echo "  --timeout   Maximum time to wait (ms, default 30000)"
  exit 1
}

error_exit() {
  local msg="$1"
  local resp="$2"
  echo -e "\033[0;31mError: $msg\033[0m" >&2
  if [[ -n "$resp" ]]; then
    local cf_err=$(echo "$resp" | jq -r '.errors[0].message // empty')
    local cf_code=$(echo "$resp" | jq -r '.errors[0].code // empty')
    if [[ -n "$cf_err" ]]; then
      echo "Cloudflare API Error ($cf_code): $cf_err" >&2
    else
      local res_err=$(echo "$resp" | jq -r '.result[0].error // empty')
      [[ -n "$res_err" ]] && echo "Result Error: $res_err" >&2
    fi
    # If no specific error extracted, show raw JSON (compact)
    [[ -z "$cf_err" && -z "$res_err" ]] && echo "$resp" | jq -c . >&2
  fi
  exit 1
}

URL=""
FILE=""
OPTIONS="{}"
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
METHOD="auto"
WAIT_UNTIL="domcontentloaded"
SELECTOR=""
TIMEOUT=30000

# Automatically load from .env if variables are missing
if [[ -z "$ACCOUNT_ID" || -z "$API_TOKEN" ]]; then
  # Search in current directory and up to 2 levels up
  for env_file in ".env" "../.env" "../../.env"; do
    if [[ -f "$env_file" ]]; then
      while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Remove 'export ' prefix, trim spaces, ignore comments
        key="${key#export }"
        key=$(echo "$key" | xargs)
        [[ "$key" =~ ^#.* ]] || [[ -z "$key" ]] && continue
        
        # Trim spaces and remove surrounding quotes from value
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "'$//")
        
        if [[ "$key" == "CLOUDFLARE_ACCOUNT_ID" && -z "$ACCOUNT_ID" ]]; then
          ACCOUNT_ID="$value"
        elif [[ "$key" == "CLOUDFLARE_API_TOKEN" && -z "$API_TOKEN" ]]; then
          API_TOKEN="$value"
        fi
      done < "$env_file"
      # Stop if we found what we need
      [[ -n "$ACCOUNT_ID" && -n "$API_TOKEN" ]] && break
    fi
  done
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --account) ACCOUNT_ID="$2"; shift 2 ;;
    --token) API_TOKEN="$2"; shift 2 ;;
    --wait) WAIT_UNTIL="$2"; shift 2 ;;
    --selector) SELECTOR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$URL" && -z "$FILE" ]]; then
  error_exit "Must provide either --url or --file." ""
fi

if [[ -n "$URL" && -n "$FILE" ]]; then
  error_exit "Cannot provide both --url and --file." ""
fi

[[ -z "$ACCOUNT_ID" ]] && error_exit "Missing Account ID. Ensure CLOUDFLARE_ACCOUNT_ID is set or use --account." ""
[[ -z "$API_TOKEN" ]] && error_exit "Missing API Token. Ensure CLOUDFLARE_API_TOKEN is set or use --token." ""

# If file is provided, only AI method works
if [[ -n "$FILE" ]]; then
  if [[ ! -f "$FILE" ]]; then
    error_exit "File not found: $FILE" ""
  fi
  
  RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/tomarkdown" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -F "files=@$FILE" \
    -F "conversionOptions=$OPTIONS")

  if echo "$RESP" | grep -q '"success":true'; then
    FORMAT=$(echo "$RESP" | jq -r '.result[0].format // empty')
    if [[ "$FORMAT" == "error" ]]; then
      ERR=$(echo "$RESP" | jq -r '.result[0].error // "Unknown error"')
      error_exit "Conversion Error: $ERR" "$RESP"
    fi
    echo "$RESP" | jq -r '.result[0].data // empty'
    exit 0
  else
    error_exit "API Error" "$RESP"
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
    # Construct browser payload with gotoOptions for better JS handling
    JSON_DATA=$(jq -n \
      --arg url "$URL" \
      --arg wait "$WAIT_UNTIL" \
      --arg timeout "$TIMEOUT" \
      --arg selector "$SELECTOR" \
      '{url: $url, gotoOptions: {waitUntil: $wait, timeout: ($timeout | tonumber)}} + (if $selector != "" then {waitForSelector: {selector: $selector}} else {} end)')

    RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/browser-rendering/markdown" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$JSON_DATA")
    
    if echo "$RESP" | grep -q '"success":true'; then
      RESULT=$(echo "$RESP" | jq -r '.result // empty')
      if [[ -z "$RESULT" || "$RESULT" == "null" ]]; then
         error_exit "Browser rendering succeeded but returned empty content." "$RESP"
      fi
      echo "$RESULT"
      exit 0
    else
      error_exit "Browser Rendering failed." "$RESP"
    fi
  fi
  
  error_exit "Failed to convert page using any available method." ""
fi
