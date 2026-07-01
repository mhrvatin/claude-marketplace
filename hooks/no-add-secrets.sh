#!/usr/bin/env bash
# PreToolUse (Bash): best-effort early block of `git add` on secret files.
# The robust gate is the pre-commit no-secrets-commit.sh; this just fails sooner.
# Uses a denylist of secret names/suffixes, matched case-insensitively (-i) so
# uppercase variants don't slip on case-insensitive filesystems (macOS).
# No PCRE lookahead — BSD grep has no -P.
set -euo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // ""')
[ -z "$CMD" ] && exit 0
# Skip leading git flags (incl. `-C <path>` with a separate value token) so a form
# like `git -C /repo add .env` still trips the gate instead of slipping past it.
echo "$CMD" | grep -qE 'git([[:space:]]+-[^[:space:]]+(=[^[:space:]]+)?([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+add' || exit 0

if echo "$CMD" | grep -iqE '\.(pem|key|p12|pfx|p8|ppk|keystore|jks)([[:space:]]|$)|(^|[[:space:]/])id_(rsa|dsa|ecdsa|ed25519)([[:space:]]|$)|(^|[[:space:]/])\.env([[:space:]]|$)|(^|[[:space:]/])\.env\.(local|prod|production|dev|development|staging|secret|secrets)|(^|[[:space:]/])(credentials|secrets|service[-_]account)\.json([[:space:]]|$)|(^|[[:space:]/])\.(secrets|npmrc)([[:space:]]|$)'; then
  cat <<'EOF'
{"decision":"block","reason":"Do not `git add` secret/credential files (.env, *.pem, *.key, id_rsa, credentials.json, .npmrc, etc.). Stage only non-secret files by name — secrets belong in .gitignore. Sample files should be named *.example."}
EOF
  exit 0
fi
exit 0
