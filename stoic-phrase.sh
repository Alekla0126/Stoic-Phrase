#!/usr/bin/env bash
set -euo pipefail

APP_NAME="stoic-phrase"
API_URL="https://stoic-quotes.com/api/quote"
DEFAULT_QUOTE="La disciplina de hoy se convierte en libertad mañana."
DEFAULT_AUTHOR="Anónimo"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
USERNAME_FILE="${CONFIG_DIR}/username"
STYLE_FILE="${CONFIG_DIR}/style"
STARTUP_MARKER_BEGIN="# Stoic Phrase start"
STARTUP_MARKER_END="# Stoic Phrase end"

USERNAME_OVERRIDE=""
STYLE_OVERRIDE=""
SHOW_BANNER=1
SHOW_QUOTE=1
STARTUP_MODE=0

usage() {
  cat <<'EOF'
Usage: stoic-phrase [options]

Options:
  --configure         Prompt for a username and ASCII style, then save them.
  --username NAME     Use NAME for this run without prompting.
  --style NAME        Use NAME for this run without prompting.
  --enable-startup    Add the shell hook for automatic terminal startup.
  --disable-startup   Remove the shell hook from your shell rc file.
  --banner-only       Print only the banner.
  --quote-only        Print only the Stoic quote.
  --startup           Run the startup flow used by the shell hook.
  --help, -h          Show this help message.

Environment:
  STOIC_PHRASE_USERNAME  Override the saved username.
  STOIC_PHRASE_STYLE     Override the saved banner style.
  STOIC_PHRASE_QUOTE     Use a fixed quote instead of calling the API.
  STOIC_PHRASE_DISABLED  Set to any value to skip shell-startup hooks.
EOF
}

colorize() {
  if command -v lolcat >/dev/null 2>&1; then
    lolcat --seed=42 2>/dev/null || lolcat
  else
    cat
  fi
}

repeat_char() {
  local char="$1" count="$2" output=""
  while [[ "$count" -gt 0 ]]; do
    output="${output}${char}"
    count=$((count - 1))
  done
  printf '%s' "$output"
}

center_text() {
  local text="$1" width="$2"
  local len="${#text}"
  if [[ "$len" -ge "$width" ]]; then
    printf '%s' "$text"
    return
  fi
  local pad=$(( (width - len) / 2 ))
  local rpad=$(( width - len - pad ))
  printf '%*s%s%*s' "$pad" '' "$text" "$rpad" ''
}

read_saved_value() {
  local file_path="$1" val=""
  if [[ -f "$file_path" ]]; then
    IFS= read -r val < "$file_path" || true
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

prompt_yes_no() {
  local answer=""
  printf '%s [Y/n]: ' "$1" >&2
  IFS= read -r answer || true
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    n|no) return 1 ;;
    *)    return 0 ;;
  esac
}

prompt_for_username() {
  local default_name="${USER:-stoic}" username=""
  printf 'Elige tu nombre de usuario [%s]: ' "$default_name" >&2
  IFS= read -r username || true
  printf '%s\n' "${username:-$default_name}"
}

prompt_for_style() {
  local answer=""
  cat >&2 <<'EOF'
Elige un estilo ASCII:
  1) classic   - caja centrada
  2) bold      - bordes fuertes
  3) minimal   - sin borde
EOF
  printf 'Estilo [classic]: ' >&2
  IFS= read -r answer || true
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    2|bold)    printf 'bold\n'    ;;
    3|minimal) printf 'minimal\n' ;;
    *)         printf 'classic\n' ;;
  esac
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
    printf 'El arranque automático ya está activado en %s\n' "$rc_file"
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

configure_profile() {
  local chosen_username chosen_style
  chosen_username="$(prompt_for_username)"
  chosen_style="$(prompt_for_style)"
  save_value "$USERNAME_FILE" "$chosen_username"
  save_value "$STYLE_FILE" "$chosen_style"
  printf 'Perfil guardado: %s / %s\n' "$chosen_username" "$chosen_style"
  enable_startup_hook
}

resolve_username() {
  [[ -n "$USERNAME_OVERRIDE" ]]           && { printf '%s\n' "$USERNAME_OVERRIDE"; return; }
  [[ -n "${STOIC_PHRASE_USERNAME:-}" ]]   && { printf '%s\n' "$STOIC_PHRASE_USERNAME"; return; }
  read_saved_value "$USERNAME_FILE"       && return
  if [[ -t 0 && -t 1 ]]; then
    local u; u="$(prompt_for_username)"
    save_value "$USERNAME_FILE" "$u"
    printf '%s\n' "$u"
    return
  fi
  printf '%s\n' "${USER:-stoic}"
}

resolve_style() {
  [[ -n "$STYLE_OVERRIDE" ]]            && { printf '%s\n' "$STYLE_OVERRIDE"; return; }
  [[ -n "${STOIC_PHRASE_STYLE:-}" ]]    && { printf '%s\n' "$STOIC_PHRASE_STYLE"; return; }
  read_saved_value "$STYLE_FILE"        && return
  if [[ -t 0 && -t 1 ]]; then
    local s; s="$(prompt_for_style)"
    save_value "$STYLE_FILE" "$s"
    printf '%s\n' "$s"
    return
  fi
  printf 'classic\n'
}

# ASCII art fallback (no figlet)
_box_banner() {
  local username="$1" style="$2"
  local title="STOIC PHRASE" greeting="Bienvenido, ${username}"
  local w="${#title}"
  [[ "${#greeting}" -gt "$w" ]] && w="${#greeting}"

  case "$style" in
    bold)
      local border="#$(repeat_char '=' $((w + 4)))#"
      printf '%s\n' "$border"
      printf '#%s#\n' "$(center_text " STOIC PHRASE " $((w + 4)))"
      printf '#%s#\n' "$(center_text "$greeting" $((w + 4)))"
      printf '%s\n' "$border"
      ;;
    minimal)
      printf '%s\n' "$title"
      printf '%s\n' "$greeting"
      ;;
    *)
      local border="+$(repeat_char '-' $((w + 4)))+"
      printf '%s\n' "$border"
      printf '|%s|\n' "$(center_text " STOIC PHRASE " $((w + 4)))"
      printf '|%s|\n' "$(center_text "$greeting" $((w + 4)))"
      printf '%s\n' "$border"
      ;;
  esac
}

print_banner() {
  local username="$1" style="$2"

  if command -v figlet >/dev/null 2>&1; then
    case "$style" in
      bold)
        figlet -f banner "STOIC" 2>/dev/null || figlet "STOIC"
        printf '\n'
        figlet -f small "$username" 2>/dev/null || figlet "$username"
        ;;
      minimal)
        figlet -f small "Stoic" 2>/dev/null || figlet "Stoic"
        printf '\n  %s\n' "$username"
        ;;
      *)
        figlet -f slant "Stoic" 2>/dev/null || figlet "Stoic"
        printf '\n  Bienvenido, %s\n' "$username"
        ;;
    esac
  else
    _box_banner "$username" "$style"
  fi
}

fetch_quote() {
  if [[ -n "${STOIC_PHRASE_QUOTE:-}" ]]; then
    printf '%s\n' "$STOIC_PHRASE_QUOTE"
    return
  fi

  local response="" quote="" author=""
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

  printf '"%s"\n\n    — %s\n' "$quote" "$author"
}

run_startup() {
  [[ "$STARTUP_MODE" -eq 1 && -n "${STOIC_PHRASE_DISABLED:-}" ]] && return 0

  local first_run=0
  if [[ ! -f "$USERNAME_FILE" || ! -f "$STYLE_FILE" ]]; then
    first_run=1
  fi

  local username style
  username="$(resolve_username)"
  style="$(resolve_style)"

  if [[ "$SHOW_BANNER" -eq 1 ]]; then
    print_banner "$username" "$style" | colorize
    printf '\n'
  fi

  if [[ "$SHOW_QUOTE" -eq 1 ]]; then
    fetch_quote | colorize
    printf '\n'
  fi

  # Auto-enable startup on first run (no prompt needed)
  if [[ "$first_run" -eq 1 ]]; then
    enable_startup_hook
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)        usage; return 0 ;;
      --configure)      configure_profile; return 0 ;;
      --enable-startup) enable_startup_hook; return 0 ;;
      --disable-startup)disable_startup_hook; return 0 ;;
      --banner-only)    SHOW_QUOTE=0 ;;
      --quote-only)     SHOW_BANNER=0 ;;
      --startup)        STARTUP_MODE=1 ;;
      --username)
        shift
        [[ $# -eq 0 ]] && { printf 'Error: --username necesita un valor.\n' >&2; return 1; }
        USERNAME_OVERRIDE="$1"
        ;;
      --style)
        shift
        [[ $# -eq 0 ]] && { printf 'Error: --style necesita un valor.\n' >&2; return 1; }
        STYLE_OVERRIDE="$1"
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
