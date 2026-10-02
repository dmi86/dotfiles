#!/bin/bash
# Install GIS-lm-build, or update it when a newer release is out: the `lm` CLI
# (on $PATH via dot_zshrc) and the git hooks that dot_gitconfig.tmpl points
# core.hooksPath at. Follows the install steps in the GIS-lm-build README.
# `lm install-hooks` is deliberately not run: all it does is set that same
# global core.hooksPath, which chezmoi already owns.
#
# run_after_ (every apply): the release lives in a private repo, so the
# download needs `gh auth login`, which a fresh machine has not done yet on its
# first apply. Running on every apply means the next `chezmoi apply` after
# logging in picks it up, and later applies keep it on the latest release.
#
# The update mirrors `lm update` (swap the folder, then `lm post-update`)
# rather than calling it, because `lm update` downloads with lm's own GitHub
# token, which only exists after the manual `lm github-setup`.
#
# Never aborts the apply: every failure is reported and retried next time.
set -uo pipefail

eval "$(/opt/homebrew/bin/brew shellenv)"

LM_ROOT="$HOME/.GIS-lm-build"
REPO="Launchmetrics/GIS-lm-build"

if ! gh auth status >/dev/null 2>&1; then
  if [ ! -x "$LM_ROOT/bin/lm" ]; then
    echo "lm-build: not installed yet — $REPO is private. Run 'gh auth login', then 'chezmoi apply' again" >&2
  fi
  exit 0
fi

latest=$(gh release view --repo "$REPO" --json tagName --jq .tagName 2>/dev/null)
if [ -z "$latest" ]; then
  echo "lm-build: could not read the latest release of $REPO, skipping" >&2
  exit 0
fi

current=""
if [ -x "$LM_ROOT/bin/lm" ]; then
  # First line: "GIS LM Build version: v0.132"
  current=$("$LM_ROOT/bin/lm" version 2>/dev/null | awk '/version:/ { print $NF; exit }')
  [ "$current" = "$latest" ] && exit 0
fi

# A git checkout is a dev install; `lm update` refuses those too
if [ -e "$LM_ROOT/.git" ]; then
  echo "lm-build: $LM_ROOT is a git checkout (dev install), not touching it" >&2
  exit 0
fi

echo "==> GIS-lm-build ${current:-not installed} -> $latest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "$LM_ROOT.update"' EXIT

# Release assets are named GIS-lm-build-<tag>-macOS-<arm64|x86_64>.tar.gz,
# which is exactly what `uname -m` prints.
if ! gh release download "$latest" --repo "$REPO" \
  --pattern "GIS-lm-build-*-macOS-$(uname -m).tar.gz" --dir "$tmp"; then
  echo "lm-build: download failed, the next chezmoi apply retries it" >&2
  exit 0
fi

rm -rf "$LM_ROOT.update" && mkdir -p "$LM_ROOT.update"
if ! tar -C "$LM_ROOT.update" --strip-components=1 -xzf "$tmp"/GIS-lm-build-*.tar.gz; then
  echo "lm-build: could not extract the release, keeping the current install" >&2
  exit 0
fi

# Swap in the new release only once it is fully extracted, so a failure
# above never leaves a half-installed lm behind.
rm -rf "$LM_ROOT.old"
[ -d "$LM_ROOT" ] && mv "$LM_ROOT" "$LM_ROOT.old"
if ! mv "$LM_ROOT.update" "$LM_ROOT"; then
  [ -d "$LM_ROOT.old" ] && mv "$LM_ROOT.old" "$LM_ROOT"
  echo "lm-build: could not swap in $latest, kept the current install" >&2
  exit 0
fi
rm -rf "$LM_ROOT.old"

# The README clears this for browser downloads; gh does not set it, but a
# leftover bit would make Gatekeeper block the bundled binaries.
xattr -r -d com.apple.quarantine "$LM_ROOT" 2>/dev/null || true

if [ -n "$current" ]; then
  (cd && "$LM_ROOT/bin/lm" post-update "$current") || echo "lm-build: 'lm post-update' failed" >&2
else
  echo "    Finish with 'lm github-setup' and 'lm jira-setup' (see README)"
fi
"$LM_ROOT/bin/lm" version -v | head -1
exit 0
