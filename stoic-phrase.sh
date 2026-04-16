#!/usr/bin/env bash
set -euo pipefail

APP_NAME="stoic-phrase"
API_URL="https://stoic-quotes.com/api/quote"
DEFAULT_QUOTE="La disciplina de hoy se convierte en libertad mañana."
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

render_output() {
  if command -v lolcat >/dev/null 2>&1; then
    lolcat
  else
    cat
  fi
}

repeat_char() {
  local char="$1"
  local count="$2"
  local output=""

  while [[ "$count" -gt 0 ]]; do
    output="${output}${char}"
    count=$((count - 1))
  done

  printf '%s' "$output"
}

center_text() {
  local text="$1"
  local width="$2"
  local text_length="${#text}"

  if [[ "$text_length" -ge "$width" ]]; then
    printf '%s' "$text"
    return
  fi

  local total_padding=$((width - text_length))
  local left_padding=$((total_padding / 2))
  local right_padding=$((total_padding - left_padding))

  printf '%*s%s%*s' "$left_padding" '' "$text" "$right_padding" ''
}

read_saved_value() {
  local file_path="$1"
  local saved_value=""

  if [[ -f "$file_path" ]]; then
    IFS= read -r saved_value < "$file_path" || true
    if [[ -n "${saved_value// }" ]]; then
      printf '%s\n' "$saved_value"
      return 0
    fi
  fi

  return 1
}

save_value() {
  local file_path="$1"
  local value="$2"

  mkdir -p "$CONFIG_DIR"
  printf '%s\n' "$value" > "$file_path"
}

prompt_yes_no() {
  local prompt="$1"
  local answer=""

  printf '%s [Y/n]: ' "$prompt" >&2
  IFS= read -r answer || true

  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    n|no)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

prompt_for_username() {
  local default_name="${USER:-stoic}"
  local username=""

  printf 'Elige tu nombre de usuario [%s]: ' "$default_name" >&2
  IFS= read -r username || true
  username="${username:-$default_name}"

  printf '%s\n' "$username"
}

prompt_for_style() {
  local answer=""

  cat >&2 <<'EOF'
Elige un estilo ASCII:
  1) classic   - limpio y centrado
  2) bold      - bordes fuertes
  3) minimal   - sin borde
EOF
  printf 'Estilo [classic]: ' >&2
  IFS= read -r answer || true

  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    2|bold)
      printf '%s\n' "bold"
      ;;
    3|minimal)
      printf '%s\n' "minimal"
      ;;
    1|classic|"")
      printf '%s\n' "classic"
      ;;
    *)
      printf '%s\n' "classic"
      ;;
  esac
}

startup_rc_file() {
  case "${SHELL:-}" in
    */zsh)
      printf '%s\n' "$HOME/.zshrc"
      ;;
    */bash)
      printf '%s\n' "$HOME/.bashrc"
      ;;
    *)
      printf '%s\n' "$HOME/.profile"
      ;;
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

  {
    printf '\n'
    startup_hook_block
    printf '\n'
  } >> "$rc_file"

  printf 'Arranque automático activado en %s\n' "$rc_file"
}

offer_startup_hook() {
  if ! startup_hook_installed && [[ -t 0 && -t 1 ]]; then
    if prompt_yes_no "¿Quieres abrir Stoic Phrase automáticamente al abrir la terminal?"; then
      enable_startup_hook
    fi
  fi
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
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
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
  offer_startup_hook
}

resolve_username() {
  if [[ -n "$USERNAME_OVERRIDE" ]]; then
    printf '%s\n' "$USERNAME_OVERRIDE"
    return
  fi

  if [[ -n "${STOIC_PHRASE_USERNAME:-}" ]]; then
    printf '%s\n' "$STOIC_PHRASE_USERNAME"
    return
  fi

  if read_saved_value "$USERNAME_FILE"; then
    return
  fi

  if [[ -t 0 && -t 1 ]]; then
    local chosen_username
    chosen_username="$(prompt_for_username)"
    save_value "$USERNAME_FILE" "$chosen_username"
    printf '%s\n' "$chosen_username"
    return
  fi

  printf '%s\n' "${USER:-stoic}"
}

resolve_style() {
  if [[ -n "$STYLE_OVERRIDE" ]]; then
    printf '%s\n' "$STYLE_OVERRIDE"
    return
  fi

  if [[ -n "${STOIC_PHRASE_STYLE:-}" ]]; then
    printf '%s\n' "$STOIC_PHRASE_STYLE"
    return
  fi

  if read_saved_value "$STYLE_FILE"; then
    return
  fi

  if [[ -t 0 && -t 1 ]]; then
    local chosen_style
    chosen_style="$(prompt_for_style)"
    save_value "$STYLE_FILE" "$chosen_style"
    printf '%s\n' "$chosen_style"
    return
  fi

  printf '%s\n' "classic"
}

print_banner() {
  local username="$1"
  local style="$2"
  local title="STOIC PHRASE"
  local greeting="Bienvenido, ${username}"
  local content_width="${#title}"
  local border
  local vertical
  local corner_left
  local corner_right
  local fill
  local header_title
  local header_padding

  if [[ "${#greeting}" -gt "$content_width" ]]; then
    content_width="${#greeting}"
  fi

  case "$style" in
    bold)
      corner_left="#"
      corner_right="#"
      fill="="
      vertical="#"
      header_title=" STOIC PHRASE "
      ;;
    minimal)
      printf '%s\n' "$title"
      printf '%s\n' "$greeting"
      return
      ;;
    *)
      corner_left="+"
      corner_right="+"
      fill="-"
      vertical="|"
      header_title=" STOIC PHRASE "
      ;;
  esac

  border="${corner_left}$(repeat_char "$fill" $((content_width + 4)))${corner_right}"
  header_padding=$((content_width + 4))

  printf '%s\n' "$border"
  printf '%s%s%s\n' "$vertical" "$(center_text "$header_title" "$header_padding")" "$vertical"
  printf '%s%s%s\n' "$vertical" "$(center_text "$greeting" "$header_padding")" "$vertical"
  printf '%s\n' "$border"
}

fetch_quote() {
  local response quote author

  if [[ -n "${STOIC_PHRASE_QUOTE:-}" ]]; then
    printf '%s\n' "$STOIC_PHRASE_QUOTE"
    return
  fi

  if command -v curl >/dev/null 2>&1; then
    response="$(curl -fsS --max-time 10 "$API_URL" 2>/dev/null || true)"

    if [[ -n "$response" ]] && command -v jq >/dev/null 2>&1; then
      quote="$(printf '%s' "$response" | jq -r '.text // .quote // empty' 2>/dev/null || true)"
      author="$(printf '%s' "$response" | jq -r '.author // empty' 2>/dev/null || true)"

      if [[ -n "$quote" && "$quote" != "null" ]]; then
        if [[ -n "$author" && "$author" != "null" ]]; then
          printf '%s\n%s\n' "$quote" "— ${author}"
        else
          printf '%s\n' "$quote"
        fi
        return
      fi
    fi
  fi

  printf '%s\n' "$DEFAULT_QUOTE"
}

run_startup() {
  local username style quote_block initial_setup=0

  if [[ "$STARTUP_MODE" -eq 1 && -n "${STOIC_PHRASE_DISABLED:-}" ]]; then
    return 0
  fi

  if [[ ! -f "$USERNAME_FILE" || ! -f "$STYLE_FILE" ]]; then
    initial_setup=1
  fi

  username="$(resolve_username)"
  style="$(resolve_style)"

  if [[ "$SHOW_BANNER" -eq 1 ]]; then
    print_banner "$username" "$style" | render_output
  fi

  if [[ "$SHOW_BANNER" -eq 1 && "$SHOW_QUOTE" -eq 1 ]]; then
    printf '\n'
  fi

  if [[ "$SHOW_QUOTE" -eq 1 ]]; then
    quote_block="$(fetch_quote)"
    printf '%s\n' "$quote_block" | render_output
  fi

  if [[ "$initial_setup" -eq 1 ]]; then
    offer_startup_hook
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        return 0
        ;;
      --configure)
        configure_profile
        return 0
        ;;
      --username)
        shift
        if [[ $# -eq 0 ]]; then
          printf 'Error: --username needs a value.\n' >&2
          return 1
        fi
        USERNAME_OVERRIDE="$1"
        ;;
      --style)
        shift
        if [[ $# -eq 0 ]]; then
          printf 'Error: --style needs a value.\n' >&2
          return 1
        fi
        STYLE_OVERRIDE="$1"
        ;;
      --enable-startup)
        enable_startup_hook
        return 0
        ;;
      --disable-startup)
        disable_startup_hook
        return 0
        ;;
      --banner-only)
        SHOW_QUOTE=0
        ;;
      --quote-only)
        SHOW_BANNER=0
        ;;
      --startup)
        STARTUP_MODE=1
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        usage >&2
        return 1
        ;;
    esac
    shift
  done

  run_startup
}

main "$@"
