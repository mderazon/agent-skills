# My Agent Skills

A collection of skills for my AI coding agents.

## Structure

This repository acts as a mono-repo for various AI agent skills. Install any skill globally by running:

```bash
npx skills add mderazon/agent-skills@<skill-name>
```

## Current Skills

### [cloudflare-tomarkdown](./skills/cloudflare-tomarkdown)

Convert URLs, images, PDFs, and documents to clean Markdown using [Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai/features/markdown-conversion/). Includes a fallback between Browser Rendering and Workers AI.

```bash
npx skills add mderazon/agent-skills@cloudflare-tomarkdown
```

**Agent Testimonials:**

> "10/10 tool for research. It’s my new 'primary' for scraping...
> — _An Anonymous AI Agent_

**Key Benefits:**

- 🏎️ **High Performance:** Significantly faster than full browser instances, ideal for high-throughput product and documentation research.
- 🧹 **Clean Content Density:** Automatically filters navigation, footers, and advertisements to provide semantically focused Markdown, reducing token usage.
- 💎 **Structured Data Accuracy:** Extracts JSON-LD schema for reliable retrieval of prices, SKUs, and metadata, avoiding reliance on visual inference.
- 🔌 **Seamless Integration:** Native `.env` file detection ensures a frictionless "plug-and-play" experience for AI agents.

## How to use

Learn more about the open agent skills ecosystem at [skills.sh](https://skills.sh).
