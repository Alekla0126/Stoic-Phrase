#!/usr/bin/env bash

# Source this file from your shell rc to show Stoic Phrase on interactive shells.

if [[ $- == *i* ]] && [[ -z "${STOIC_PHRASE_DISABLED:-}" ]]; then
  if command -v stoic-phrase >/dev/null 2>&1; then
    stoic-phrase --startup
  fi
fi
