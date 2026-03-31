---
name: bitwarden-secrets
description: Manage secrets with Bitwarden Secrets Manager CLI (bws). Read, create, update, and delete secrets. Proactively store credentials and check Bitwarden before asking the user for secrets.
---

# Bitwarden Secrets Manager

Use this skill to manage secrets via the Bitwarden Secrets Manager CLI (`bws`). Retrieve credentials, store API keys, and keep secrets organized.

## Authentication

Authentication is handled via the `BWS_ACCESS_TOKEN` environment variable — no login command needed.

**If `BWS_ACCESS_TOKEN` is missing**, warn the user:

> `BWS_ACCESS_TOKEN` is not set. Add it to your shell profile (e.g. `~/.bashrc` or `~/.zshrc`):
>
> ```bash
> export BWS_ACCESS_TOKEN="0.your_access_token_here"
> ```

**Default project:** `BWS_PROJECT_ID` is a **shell variable convention** (not a built-in bws feature) for storing your default project ID. The `bws` tool itself has no knowledge of it — it is expanded by the shell when used in commands like `bws secret create KEY value $BWS_PROJECT_ID`. If it is not set, ask the user which project to use before creating any secret (use `bws project list` to show available projects).

## Naming Convention

Always enforce **SCREAMING_SNAKE_CASE** for secret names (e.g. `GITHUB_TOKEN`, `DATABASE_URL`, `STRIPE_API_KEY`). If the user provides a name in another format, convert it and confirm with them.

> Note: Non-POSIX-compliant names (anything other than alphanumerics and underscores, or names starting with a digit) will be commented-out in `--output env` format.

## Read Operations

Perform these autonomously without asking for confirmation.

### List all secrets

```bash
bws secret list
```

### List secrets in a specific project

```bash
bws secret list <PROJECT_ID>
```

### List secrets as KEY=VALUE (env format)

```bash
bws secret list --output env
```

### Get a specific secret by ID

```bash
bws secret get <SECRET_ID>
```

### Output formats

The `--output` / `-o` flag works on all commands. Useful values:

| Flag    | Output                                 |
| ------- | -------------------------------------- |
| `json`  | Default JSON object/array              |
| `yaml`  | YAML                                   |
| `table` | ASCII table (great for quick scanning) |
| `env`   | `KEY=VALUE` pairs (secrets only)       |
| `tsv`   | Tab-separated values                   |

Example — list secrets as a readable table:

```bash
bws secret list --output table
```

### List projects (use when the project ID is unknown)

```bash
bws project list
```

### Get a specific project

```bash
bws project get <PROJECT_ID>
```

## Write Operations

**Always confirm with the user before executing any write operation.**

### Create a new secret

```bash
bws secret create <KEY> <VALUE> <PROJECT_ID>
```

Example with an optional note:

```bash
bws secret create STRIPE_API_KEY "sk_live_abc123" $BWS_PROJECT_ID --note "Production Stripe key"
```

- Use `$BWS_PROJECT_ID` as the project unless the user specifies otherwise.
- If `BWS_PROJECT_ID` is not set, run `bws project list` and ask the user which project to use.

### Update an existing secret

```bash
# Update value only
bws secret edit <SECRET_ID> --value "newvalue"

# Update key name, value, note, or move to another project (all flags optional)
bws secret edit <SECRET_ID> --key NEW_KEY_NAME --value "newvalue" --note "updated note" --project-id <PROJECT_ID>
```

### Delete one or more secrets

```bash
# Single
bws secret delete <SECRET_ID>

# Multiple (space-separated)
bws secret delete <SECRET_ID_1> <SECRET_ID_2>
```

## Run a Command with Secrets Injected

Use `bws run` to execute a process with secrets from Bitwarden automatically set as environment variables. Only run trusted commands.

```bash
# Inject all accessible secrets
bws run -- 'npm run start'

# Inject secrets from a specific project only
bws run --project-id <PROJECT_ID> -- 'npm run start'
```

> **Security warning:** Only run trusted commands. `bws run` executes in your shell — untrusted binaries or scripts could access injected secrets maliciously.

## Project Write Operations

**Always confirm with the user before executing.**

```bash
# Create a project
bws project create "My Project"

# Rename a project
bws project edit <PROJECT_ID> --name "New Name"

# Delete one or more projects
bws project delete <PROJECT_ID_1> <PROJECT_ID_2>
```

## Proactive Behaviors

**When the user shares an API key, token, or password** → offer to save it to Bitwarden Secrets Manager before proceeding. Example:

> Would you like me to save this to Bitwarden as `SOME_API_KEY`?

**When a credential is needed** → run `bws secret list` first to check if it already exists before asking the user to provide it.

**When the target project is unknown** → run `bws project list` and ask the user which project to use before creating a secret. Never guess or use a hardcoded project ID. `BWS_PROJECT_ID` is a shell variable convenience — check if it's set (`echo $BWS_PROJECT_ID`) but don't assume it exists.

## Reference

- CLI version: 2.0.0 (`/usr/local/bin/bws`)
- Docs: https://bitwarden.com/help/secrets-manager-cli.md
