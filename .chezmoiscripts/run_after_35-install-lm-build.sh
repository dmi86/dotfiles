#!/bin/bash
# Install GIS-lm-build, following the steps in its README. Updates are lm's own
# job: it announces new releases and upgrades itself with `lm update`.
# `lm install-hooks` is not needed: dot_gitconfig.tmpl already sets the
# core.hooksPath it would set.
#
# run_after_ (every apply) because the release is in a private repo: until
# `gh auth login` it only prints a hint, and the next apply installs it. Once
# ~/.GIS-lm-build exists it is left alone.
set -o pipefail
LM_ROOT="$HOME/.GIS-lm-build"
[ -e "$LM_ROOT" ] && exit 0

if ! gh auth status >/dev/null 2>&1; then
  echo "lm-build: run 'gh auth login', then 'chezmoi apply' again to install it" >&2
  exit 0
fi

mkdir -p "$LM_ROOT"
if gh release download --repo Launchmetrics/GIS-lm-build --pattern "*-macOS-$(uname -m).tar.gz" --output - |
  tar -xz -C "$LM_ROOT" --strip-components=1; then
  "$LM_ROOT/bin/lm" version -v | head -1
  echo "    Finish with 'lm github-setup' and 'lm jira-setup'"
else
  rm -rf "$LM_ROOT"
  echo "lm-build: install failed, the next chezmoi apply retries it" >&2
fi
exit 0
