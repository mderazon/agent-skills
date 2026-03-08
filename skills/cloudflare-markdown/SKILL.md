---
name: cloudflare-markdown
description: Convert URLs, images, PDFs, and documents to clean Markdown using Cloudflare APIs. Scraping tool with image AI summarization and JS-rendering fallback.
references:
  - cloudflare@workers-ai
  - cloudflare@browser-rendering
---

# Cloudflare Markdown Conversion

Use this skill to convert URLs or local files (PDFs, Images, HTML, CSV, Office docs) into clean, structured Markdown for text analysis, RAG, and LLMs.

## Features & Supported Formats

- **Scraping URLs**: Extracts HTML, resolves relative links, handles JSON-LD, extracts title/description.
- **Images**: Automatically runs object-detection and uses an LLM (`gemma-3-12b-it`) to generate image descriptions. Converts SVG to raster.
- **PDFs**: Parses internal `StructTree` tagging for high-fidelity semantic Markdown extraction.
- **Office Docs**: Supports `.docx`, `.xlsx`, `.csv`, `.ods`, `.odt`, and more.

## Usage

## Setup & Authentication

This skill requires `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` to be configured as environment variables. 

**Instruction for the Agent:** If you attempt to use this skill and it fails due to missing environment variables, STOP and explicitly ask the user to provide their Cloudflare Account ID and API Token. You can suggest they export them in their shell or add them to their project's `.env` file.

### Scraping a URL

```bash
# Basic usage (defaults to 'auto' method, trying AI parsing first, then browser rendering)
bash scripts/render.sh --url "https://example.com"
```

### Scraping with Options (CSS Selectors, etc.)

Cloudflare allows filtering elements using `cssSelector` or providing a `hostname`.

```bash
# Only extract the main content container
bash scripts/render.sh --url "https://developer.cloudflare.com" \
  --options '{"html": {"cssSelector": "main.content"}}'
```

### Converting a Local File (PDFs, Images, Office Docs)

```bash
bash scripts/render.sh --file "report.pdf"
```

### Converting Images with Language Options

Image descriptions are generated via AI. You can specify a desired output language for the description (`en`, `it`, `de`, `es`, `fr`, `pt`).

```bash
bash scripts/render.sh --file "cat.jpeg" \
  --options '{"image": {"descriptionLanguage": "es"}}'
```

### Excluding PDF Metadata

Sometimes PDFs contain messy metadata that you want to ignore.

```bash
bash scripts/render.sh --file "presentation.pdf" \
  --options '{"pdf": {"metadata": false}}'
```

## How It Works Intelligently

The `--method auto` capability tests two separate rendering paths:

1. **Workers AI `tomarkdown` (Primary)**: Ideal for documents, standard web pages, extracting JSON-LD structured data, and resolving standard HTML features. Uses multipart form data.
2. **Browser Rendering API (Fallback)**: If the page uses complex JavaScript (e.g. Single Page Apps) and the AI path cannot see the content, the Browser Rendering engine opens a headless real browser for accurate conversion.

## Calling the REST API Directly (Advanced)

If you'd prefer not to use `scripts/render.sh`, here is the curl equivalent for a local file using the `tomarkdown` REST API:

```bash
curl https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/tomarkdown \
  -X POST \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -F "files=@document.pdf" \
  -F 'conversionOptions={"pdf":{"metadata":false}}'
```

**Note:** For URLs, you should use `curl` to fetch the source to a local file first before uploading it as `files=@<temp.html>`. The `tomarkdown` REST API does not directly ingest a `--data url="https..."`.
