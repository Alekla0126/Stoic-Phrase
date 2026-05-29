#!/usr/bin/env bash
set -euo pipefail

APP_NAME="stoic-phrase"
API_URL="https://stoic-quotes.com/api/quote"
DEFAULT_QUOTE="La disciplina de hoy se convierte en libertad mañana."
DEFAULT_AUTHOR="Anónimo"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
USERNAME_FILE="${CONFIG_DIR}/username"
STARTUP_MARKER_BEGIN="# Stoic Phrase start"
STARTUP_MARKER_END="# Stoic Phrase end"

USERNAME_OVERRIDE=""
STARTUP_MODE=0

usage() {
  cat <<'EOF'
Usage: stoic-phrase [options]

Options:
  --configure         Prompt for a username, then save it.
  --username NAME     Use NAME for this run without prompting.
  --enable-startup    Add the shell hook for automatic terminal startup.
  --disable-startup   Remove the shell hook from your shell rc file.
  --startup           Run the startup flow used by the shell hook.
  --help, -h          Show this help message.

Environment:
  STOIC_PHRASE_USERNAME  Override the saved username.
  STOIC_PHRASE_QUOTE     Use a fixed quote instead of calling the API.
  STOIC_PHRASE_DISABLED  Set to any value to skip shell-startup hooks.
EOF
}

ascii_color() {
  local text="$1"
  if command -v toilet >/dev/null 2>&1; then
    printf '%s' "$text" | toilet -f term --gay 2>/dev/null \
      || printf '%s\n' "$text"
  elif command -v lolcat >/dev/null 2>&1; then
    printf '%s\n' "$text" | lolcat
  else
    printf '%s\n' "$text"
  fi
}

ascii_art() {
  local text="$1"
  if command -v toilet >/dev/null 2>&1; then
    printf '%s' "$text" | toilet -f smblock --gay 2>/dev/null \
      || printf '%s\n' "$text"
  elif command -v lolcat >/dev/null 2>&1; then
    printf '%s\n' "$text" | lolcat
  else
    printf '%s\n' "$text"
  fi
}

read_saved_value() {
  local val=""
  if [[ -f "$1" ]]; then
    IFS= read -r val < "$1" || true
    if [[ -n "${val// }" ]]; then
      printf '%s\n' "$val"
      return 0
    fi
  fi
  return 1
}

save_value() {
  mkdir -p "$CONFIG_DIR"
  printf '%s\n' "$2" > "$1"
}

prompt_for_username() {
  local default_name="${USER:-stoic}" username=""
  printf 'Elige tu nombre de usuario [%s]: ' "$default_name" >&2
  IFS= read -r username || true
  printf '%s\n' "${username:-$default_name}"
}

startup_rc_file() {
  case "${SHELL:-}" in
    */zsh)  printf '%s\n' "$HOME/.zshrc"   ;;
    */bash) printf '%s\n' "$HOME/.bashrc"  ;;
    *)      printf '%s\n' "$HOME/.profile" ;;
  esac
}

startup_hook_installed() {
  local rc_file
  rc_file="$(startup_rc_file)"
  [[ -f "$rc_file" ]] && grep -Fq "$STARTUP_MARKER_BEGIN" "$rc_file"
}

startup_hook_block() {
  cat <<'EOF'
# Stoic Phrase start
if command -v stoic-phrase >/dev/null 2>&1; then
  stoic-phrase --startup
fi
# Stoic Phrase end
EOF
}

enable_startup_hook() {
  local rc_file
  rc_file="$(startup_rc_file)"
  mkdir -p "$(dirname "$rc_file")"
  if startup_hook_installed; then
    return 0
  fi
  { printf '\n'; startup_hook_block; printf '\n'; } >> "$rc_file"
  printf 'Arranque automático activado en %s\n' "$rc_file"
}

disable_startup_hook() {
  local rc_file tmp_file
  rc_file="$(startup_rc_file)"
  if [[ ! -f "$rc_file" ]]; then
    printf 'No existe %s\n' "$rc_file"
    return 0
  fi
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/${APP_NAME}.XXXXXX")"
  awk -v begin="$STARTUP_MARKER_BEGIN" -v end="$STARTUP_MARKER_END" '
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    skip != 1   { print }
  ' "$rc_file" > "$tmp_file"
  mv "$tmp_file" "$rc_file"
  printf 'Arranque automático desactivado en %s\n' "$rc_file"
}

resolve_username() {
  [[ -n "$USERNAME_OVERRIDE" ]]         && { printf '%s\n' "$USERNAME_OVERRIDE"; return; }
  [[ -n "${STOIC_PHRASE_USERNAME:-}" ]] && { printf '%s\n' "$STOIC_PHRASE_USERNAME"; return; }
  read_saved_value "$USERNAME_FILE"     && return
  if [[ -t 0 && -t 1 ]]; then
    local u; u="$(prompt_for_username)"
    save_value "$USERNAME_FILE" "$u"
    printf '%s\n' "$u"
    return
  fi
  printf '%s\n' "${USER:-stoic}"
}

configure_profile() {
  local u
  u="$(prompt_for_username)"
  save_value "$USERNAME_FILE" "$u"
  printf 'Perfil guardado: %s\n' "$u"
  enable_startup_hook
}

fetch_quote() {
  local response="" quote="" author=""

  if [[ -n "${STOIC_PHRASE_QUOTE:-}" ]]; then
    quote="$STOIC_PHRASE_QUOTE"
    author="${STOIC_PHRASE_AUTHOR:-$DEFAULT_AUTHOR}"
  else
    if command -v curl >/dev/null 2>&1; then
      response="$(curl -fsS -L --max-time 10 "$API_URL" 2>/dev/null || true)"
    fi
    if [[ -n "$response" ]] && command -v jq >/dev/null 2>&1; then
      quote="$(printf '%s' "$response"  | jq -r '.text  // .quote  // empty' 2>/dev/null || true)"
      author="$(printf '%s' "$response" | jq -r '.author // empty' 2>/dev/null || true)"
    fi
    if [[ -z "$quote" || "$quote" == "null" ]]; then
      quote="$DEFAULT_QUOTE"
      author="$DEFAULT_AUTHOR"
    fi
    [[ -z "$author" || "$author" == "null" ]] && author="$DEFAULT_AUTHOR"
  fi

  # Return as two lines: quote \n author
  printf '%s\n%s\n' "$quote" "$author"
}

run_startup() {
  [[ "$STARTUP_MODE" -eq 1 && -n "${STOIC_PHRASE_DISABLED:-}" ]] && return 0

  local first_run=0
  [[ ! -f "$USERNAME_FILE" ]] && first_run=1

  resolve_username > /dev/null

  local raw quote author
  raw="$(fetch_quote)"
  quote="$(printf '%s' "$raw" | head -1)"
  author="$(printf '%s' "$raw" | tail -1)"

  printf '\n'
  ascii_art "$quote"
  printf '\n'
  ascii_color "  -- $author"
  printf '\n'

  if [[ "$first_run" -eq 1 ]]; then
    enable_startup_hook
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)         usage; return 0 ;;
      --configure)       configure_profile; return 0 ;;
      --enable-startup)  enable_startup_hook; return 0 ;;
      --disable-startup) disable_startup_hook; return 0 ;;
      --startup)         STARTUP_MODE=1 ;;
      --username)
        shift
        [[ $# -eq 0 ]] && { printf 'Error: --username necesita un valor.\n' >&2; return 1; }
        USERNAME_OVERRIDE="$1"
        ;;
      *)
        printf 'Opción desconocida: %s\n' "$1" >&2
        usage >&2
        return 1
        ;;
    esac
    shift
  done

  run_startup
}

main "$@"
