# dotfiles

Personal dev-environment configuration, managed with [chezmoi](https://www.chezmoi.io/).

Tracked work: [SQA-3887](https://launchmetrics.atlassian.net/browse/SQA-3887)

## Scope

Targets macOS/zsh. Evaluated [ribugent/dotfiles](https://github.com/ribugent/dotfiles/) as a
reference — chezmoi-native and well structured, but tailored to Arch Linux/Fish/KDE — so this
repo started fresh, borrowing only the git-hooks, npmrc, and Databricks config template shapes.

**Replaces** `~/dotfiles`, which turned out to be a locally-modified clone of a colleague's
public dotfiles repo, with `origin` still pointing at their GitHub — `.zshrc`, `.gitconfig`,
`.vimrc`, `.zpreztorc`, and iTerm2/VS Code prefs were all symlinked or synced into it. This repo
now owns that content directly.

Key decisions (see SQA-3887 for full context):
- Node version manager: **nodenv**, not NVM
- **openjdk@17**, **openjdk@21** and **microsoft-openjdk@11** managed by **jenv**, kept to compile
  remaining Selenium repos (jenv only earns its place with multiple JDKs installed)
- **IntelliJ IDEA dropped** — VS Code is the primary editor
- Of the open MAYBE tools: **leapp** and **pre-commit** kept, **direnv** and **dbx** dropped
- **vim** and **starship** kept despite the original audit marking them DROP — both are actively
  used today (starship = prompt theme, vim = `$EDITOR`) and are unrelated to the Selenium/Java
  toolchain that was actually being retired
- **fasd** dropped — removed from Homebrew core, no longer installable; the `z` alias that used
  it was dropped too
- Secrets handling: **deferred** — templates ship with placeholder values, see below

## Action required: rotate an exposed credential

While migrating `~/dotfiles/zsh/zshrc`, a plaintext GitHub personal access token was found
hardcoded as an env var on its last line. It was **not** copied into this repo or anywhere
else, but it has been sitting unencrypted in the home directory. Treat it as exposed: revoke
and reissue it at github.com/settings/tokens, and once the secrets backend (below) is decided,
store its replacement there instead of in a shell file.

## Bootstrap

Install [Homebrew](https://brew.sh) first, then `brew install chezmoi` — chezmoi itself comes from
Homebrew, so there's no point bootstrapping Homebrew from inside a chezmoi script.

```sh
chezmoi init --apply git@github.com:dmi86/dotfiles.git
```

`chezmoi init` will prompt for your git name, work email, and GPG signing key (see
`.chezmoi.toml.tmpl`). There's no personal-identity split yet — everything uses the work
identity until a personal email is actually decided.

**Before running `chezmoi init --apply` for the first time**, remove the symlinks that currently
point into the legacy `~/dotfiles` (the colleague's repo), so chezmoi creates real files instead
of writing through the old symlinks:

```sh
rm ~/.zshrc ~/.gitconfig ~/.vimrc ~/.zpreztorc ~/.scripts
```

`chezmoi apply` will recreate `.zshrc`, `.gitconfig`, `.zpreztorc`, and `.scripts` (managed by
this repo) and will *not* recreate `.vimrc` (declared removed in `.chezmoiremove`, since vim
config/plugins are out of scope — only the `vim` binary itself is kept as `$EDITOR`). Run
`chezmoi diff` first to confirm before applying.

Once confirmed working, `~/dotfiles` (the old clone) is no longer referenced by anything and
can be archived or deleted.

## Structure

| Path | Purpose |
|---|---|
| `.chezmoi.toml.tmpl` | Generates `~/.config/chezmoi/chezmoi.toml`; prompts for git name/work email/signing key |
| `.chezmoidata/packages.yaml` | Source of truth for Homebrew formulae/casks, npm globals, VS Code extensions |
| `dot_pyenv/default-packages` | Python tools installed into every pyenv-managed version (via `pyenv-default-packages`) |
| `.chezmoiscripts/` | Bootstrap Prezto, install everything in `packages.yaml`, create `~/Develop` |
| `.chezmoiremove` | Declares `.vimrc` removed — not managed here |
| `dot_gitconfig.tmpl` | Git config: identity, `hooksPath` (LM git-hooks), `gh`-backed credential helpers |
| `dot_gitignore` | Global gitignore |
| `dot_zprofile` / `dot_zshrc` | Homebrew shellenv, Prezto init, pyenv/jenv/nodenv init, iTerm tab-title hook, starship hookup |
| `dot_zpreztorc` | Prezto framework module config (autosuggestions, starship prompt theme, syntax highlighting) |
| `dot_scripts/*.zsh` | Git aliases/functions/help scripts, sourced from `.zshrc` (migrated verbatim, `gbranch()` name fixed) |
| `dot_config/starship.toml` | Prompt theme — previously present in the old repo but never actually read (wrong path); now at the path starship expects |
| `Library/Application Support/Code/User/settings.json` | VS Code settings, cleaned of the colleague's hardcoded paths and dropped-tool references (Perl formatter, hadolint) |
| `private_dot_gnupg/gpg-agent.conf` | Points GPG at `pinentry-mac` |
| `private_dot_aws/config` | Default AWS CLI region/output, from the "First steps QA" wiki guide |
| `private_dot_npmrc.tmpl` | GitHub Packages registry config — token is a placeholder, see below |
| `private_dot_databrickscfg.tmpl` | Databricks staging/prod config — host/token are placeholders, see below |

## Deferred / not yet implemented

- **Secrets backend** — `.npmrc`, `.databrickscfg`, and the credential flagged above all need
  a real home. Decide macOS Keychain vs. `pass`+GPG vs. something else, then wire it in.
- **MCP server configuration for Claude Code** (Atlassian, GitHub, Helpjuice, Playwright,
  Databricks) — not covered by any brew/npm install, needs its own template.
- **`lm` CLI** (used by the `lm-pr` skill) — install source not confirmed.
- **Playwright browser binaries** — run `npx playwright install` per-repo; not a home-dir
  dotfile, so not scripted here.
- **`.env.local` convention** (`BASE_URL`, `HELPJUICE_API_KEY`, `TEST_USER_EMAIL`,
  `TEST_USER_PASSWORD`) — lives per-repo, not in home dotfiles.
- **`private_dot_claude`** — diff ribugent's version against your current Claude Code
  settings/hooks for anything worth adopting.

## Deliberately not managed here

**iTerm2 preferences.** iTerm2 is pointed at `~/.config/iterm2` (via its "Load preferences from a
custom folder" setting) rather than at this repo, and the plist is intentionally *not* tracked:
its profiles embed internal host references (bound hosts, an `ssh` command to an internal
address, hostname-trigger regexes for internal subnets) that shouldn't live in a public repo.
Back it up separately if you want it versioned.

To repoint iTerm2 on a new machine:

```sh
defaults write com.googlecode.iterm2 PrefsCustomFolder "$HOME/.config/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
```

## Still manual (not automatable)

Laptop language/region + Jamf enrollment, VPN device authorization (Twingate), 1Password
account sign-in, AWS SSO/Leapp account linking, GPG/SSH private key generation, GitHub
Packages token creation.
