# Stoic Phrase

**Stoic Phrase** is a Bash CLI that prints a configurable ASCII banner, stores a chosen username and style, and then fetches a Stoic quote from the public API. It can also enable itself in your shell startup so the banner appears when you open a terminal.

## What it does

- Shows a banner with your chosen username.
- Prompts for a username and ASCII style on the first interactive run and saves them under `~/.config/stoic-phrase/`.
- Can add itself to your shell startup so the banner appears automatically.
- Fetches a Stoic quote from [Stoic Quotes API](https://stoic-quotes.com/api/quote).
- Colors the output with [lolcat](https://github.com/busyloop/lolcat) when available.
- Falls back to a local quote if the API is unavailable.

## Requirements

- `bash`
- `curl`
- `jq`
- `lolcat`

## Run locally

```bash
chmod +x stoic-phrase.sh
./stoic-phrase.sh
```

On the first interactive run, the script asks for a username and saves it for later sessions.
It also asks which ASCII style you want and whether it should open automatically in new terminals.

## Homebrew

This repository already contains a Homebrew formula in `Formula/stoic-phrase.rb`.

```bash
brew tap Alekla0126/stoic-phrase https://github.com/Alekla0126/Stoic-Phrase
brew install stoic-phrase
```

Homebrew installs the command into your `PATH` automatically. If you want the
banner to appear every time a terminal opens, run:

```bash
stoic-phrase --enable-startup
```

The first interactive launch can also offer to enable startup for you.

## Commands

```bash
stoic-phrase               # banner + quote
stoic-phrase --configure   # set or change the saved username and style
stoic-phrase --enable-startup  # add the startup hook
stoic-phrase --disable-startup # remove the startup hook
stoic-phrase --banner-only # only show the banner
stoic-phrase --quote-only  # only show the quote
```

## Environment variables

```bash
STOIC_PHRASE_USERNAME="Alex" stoic-phrase
STOIC_PHRASE_STYLE="bold" stoic-phrase
STOIC_PHRASE_QUOTE="La disciplina es libertad." stoic-phrase
STOIC_PHRASE_DISABLED=1 source "$(brew --prefix)/opt/stoic-phrase/share/stoic-phrase/stoic-phrase.sh"
```

## Release flow

When you are ready to publish a new version:

1. Update the script or formula.
2. Tag the release, for example `v1.2.0`.
3. Push the tag to GitHub.
4. Update `Formula/stoic-phrase.rb` so the `tag` points to that release.
5. Create or update the GitHub release notes.

## Open source

MIT licensed. See [`LICENSE`](LICENSE).
