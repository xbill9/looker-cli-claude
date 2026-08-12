#!/bin/bash

# Resolve this script's directory so paths don't depend on the current dir
# or a hardcoded sibling project.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Any file we create below (credential caches, .env) may hold secrets, so make
# new files owner-read/write only (0600) for the rest of this script.
umask 077

# read_secret_file VAR_NAME FILE PROMPT [--secret]
# Resolve a credential in order of preference:
#   1. an already-exported environment variable (e.g. from CI or the shell),
#   2. a cached file next to the user's home dir,
#   3. an interactive prompt (hidden input when --secret is passed).
# The resolved value is cached back to FILE with 0600 perms and echoed to stdout.
read_secret_file() {
    local var_name="$1" file="$2" prompt="$3" secret="$4"
    local value="${!var_name}"

    if [ -z "$value" ] && [ -f "$file" ]; then
        value=$(cat "$file")
    fi

    if [ -z "$value" ]; then
        if [ ! -t 0 ]; then
            echo "Error: $var_name is not set and no terminal is available to prompt." >&2
            return 1
        fi
        if [ "$secret" = "--secret" ]; then
            read -rsp "$prompt: " value
            echo >&2
        else
            read -rp "$prompt: " value
        fi
    fi

    if [ -z "$value" ]; then
        echo "Error: no value provided for $var_name." >&2
        return 1
    fi

    # Cache with restrictive perms (umask 077 already applies to the new file,
    # but chmod guards against a pre-existing looser file).
    printf '%s\n' "$value" > "$file" && chmod 600 "$file"
    printf '%s' "$value"
}

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "Warning: No active gcloud account found."
    echo "Please run 'gcloud auth login' if Google Cloud commands are needed."
fi

# Google Cloud project: prefer project_id.txt (written by init.sh),
# fall back to the active gcloud config.
PROJECT_ID=$(cat "$HOME/project_id.txt" 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

# Fallback to .env values first so an existing config is honored before we
# prompt. .env may contain secrets, so it is gitignored and 0600 (see umask).
if [ -f .env ]; then
    source .env
fi

# Looker Config — resolved securely: existing env var -> cached file -> prompt.
# The client secret is read with hidden input and never echoed back.
LOOKER_BASE_URL=$(read_secret_file LOOKER_BASE_URL "$HOME/looker_url.txt" "Looker Base URL (e.g. https://your-company.looker.com)") 
LOOKER_CLIENT_ID=$(read_secret_file LOOKER_CLIENT_ID "$HOME/looker_id.txt" "Looker Client ID") 
LOOKER_CLIENT_SECRET=$(read_secret_file LOOKER_CLIENT_SECRET "$HOME/looker_secret.txt" "Looker Client Secret" --secret) 

LOOKER_VERIFY_SSL=${LOOKER_VERIFY_SSL:-true}

# Endpoint of the Looker-managed MCP server (preview), served by the instance
# itself. Unlike the stdio server, .mcp.json expands this in Claude Code's own
# process, so it has to be exported here rather than read from .env at launch.
LOOKER_MCP_URL="${LOOKER_MCP_URL:-${LOOKER_BASE_URL%/}/mcp}"

# Write .env file
cat <<EOF > .env
GOOGLE_GENAI_USE_VERTEXAI=True
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=us-central1
GENAI_MODEL="gemini-2.5-flash"
LOOKER_BASE_URL=$LOOKER_BASE_URL
LOOKER_CLIENT_ID=$LOOKER_CLIENT_ID
LOOKER_CLIENT_SECRET=$LOOKER_CLIENT_SECRET
LOOKER_VERIFY_SSL=$LOOKER_VERIFY_SSL
LOOKER_MCP_URL=$LOOKER_MCP_URL
EOF

# Ensure .env is owner-only even if it pre-existed with looser permissions
# (the > redirect above truncates but keeps an existing file's mode).
chmod 600 .env

# Reload environment
source .env

# Export the variables so a child `claude` process can resolve the ${VAR}
# references in .mcp.json. Secrets are never written into .mcp.json itself —
# it is a committed, source-controlled file that only references these vars.
export GOOGLE_GENAI_USE_VERTEXAI GOOGLE_CLOUD_PROJECT GOOGLE_CLOUD_LOCATION GENAI_MODEL
export LOOKER_BASE_URL LOOKER_CLIENT_ID LOOKER_CLIENT_SECRET LOOKER_VERIFY_SSL LOOKER_MCP_URL

echo "Environment successfully set up. Looker MCP config lives in .mcp.json (Claude format)."
echo
echo "IMPORTANT: run this with 'source set_env.sh' (not './set_env.sh'). Claude Code"
echo "expands \${LOOKER_MCP_URL} in .mcp.json from its own environment, so that"
echo "variable must be exported in the shell that launches 'claude'."
echo
echo "Current Environment (.env) — secret masked:"
# Print .env but redact the client secret so it never lands in scrollback/logs.
sed 's/^\(LOOKER_CLIENT_SECRET=\).*/\1********/' .env
