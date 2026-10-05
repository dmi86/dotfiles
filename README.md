# dotfiles

Shared dev-environment configuration for macOS/zsh, managed with
[chezmoi](https://www.chezmoi.io/). Identity and machine-specific values come from `chezmoi init`
prompts, so the same repo works for anyone on the team.

Tracked work: [SQA-3887](https://launchmetrics.atlassian.net/browse/SQA-3887) (initial setup) ·
[SQA-3901](https://launchmetrics.atlassian.net/browse/SQA-3901) (follow-ups) ·
[SQA-3939](https://launchmetrics.atlassian.net/browse/SQA-3939) (fresh-Mac install fixes)

> **Keep this repo private.** `.chezmoidata/leapp.yaml` lists the org's AWS SSO portal URL and
> every internal AWS account name, and `dot_config/iterm2/` (git-ignored) embeds internal host
> references. No credentials are committed: secrets are `REPLACE_WITH_*` placeholders or
> `chezmoi init` answers stored outside the repo.

## Setup

```sh
# 1. Homebrew (run the "Next steps" it prints), then chezmoi
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi

# 2. Only if the Leapp CLI was ever installed through npm: it owns
#    /opt/homebrew/bin/leapp and makes `brew install leapp-cli` fail to link
npm uninstall -g @noovolari/leapp-cli 2>/dev/null

# 3. Pull the repo, review what would be written, apply
chezmoi init <this-repo-url>
chezmoi diff
chezmoi apply
exec zsh                # pick up the new PATH

# 4. Finish the parts that need a login
gh auth login           # then `chezmoi apply` again: installs LM-Build (private release)
chezmoi apply
lm github-setup         # each asks for a browser session cookie
lm jira-setup
leapp-bootstrap --login # after opening Leapp.app once, see Leapp below
```

`chezmoi init` asks once and stores the answers in `~/.config/chezmoi/chezmoi.toml`, never
committed. Nothing is pre-filled, so nobody inherits someone else's identity. Re-ask with
`chezmoi init --prompt`.

| Prompt | Used for |
|---|---|
| Full name / work email | `user.name` / `user.email` in `.gitconfig` |
| Short handle | Branch names from `gbranch()` — `jdoe` gives `m-jdoe_20260916_a1b2c3d_04217` |
| GPG signing key | `user.signingkey`; blank skips commit signing |
| Shared Dock | Opt-in, default no — see [Dock](#dock) |

`chezmoi apply` overwrites the files it manages (hence `chezmoi diff` first on a machine that
already has a `.zshrc`, `.gitconfig` or `.scripts`) and removes `.vimrc` (`.chezmoiremove`).

After apply, fill in the `REPLACE_WITH_*` placeholders in `~/.npmrc` (GitHub Packages token) and
`~/.databrickscfg` (host/token).

## What gets installed

[`.chezmoidata/packages.yaml`](.chezmoidata/packages.yaml) is the list. `run_20-install-packages`
turns it into a Brewfile and runs `brew bundle install` on every apply: missing packages are
installed, outdated ones upgraded (self-updating casks like Chrome are left to their own updater),
and a failed entry is reported without stopping the apply, so the next apply retries it. An app
installed by hand before the first apply (Chrome, Slack) shows up as failed but keeps working; to
hand it to Homebrew, `brew install --cask --force <name>`.

| Group | Packages | Notes |
|---|---|---|
| Shell & prompt | `starship`, Prezto, `vim` | starship is the prompt (`dot_config/starship.toml`); Prezto is cloned and pulled on every apply by `run_before_15-install-prezto`; vim is `$EDITOR` |
| Terminal | `eza`, `bat`, `git-delta`, `fzf`, `fd`, `btop`, `htop`, `ripgrep`, `coreutils`, `jq`, `yq` | `ls`/`ll`/`la`/`lt`, the `cat` alias and fzf's preview, git's pager, Ctrl-R/Ctrl-T/Alt-C pickers (fd is their source), dashboards (htop for kill/renice). `gbranch()` needs `gdate`, `pr_stats` needs jq, lm-build needs yq |
| Git | `git`, `gh`, `gnupg`, `pinentry-mac`, `pre-commit` | `gh` backs the git credential helper; commits are GPG-signed with a GUI passphrase prompt |
| Node | `nodenv`, `yarn`, `npm-check-updates` | |
| Python | `pyenv`, `btrachey/pyenv/pyenv-default-packages` | Installs `dot_pyenv/default-packages` into every Python version |
| Java | `jenv`, `openjdk@17`, `openjdk@21`, `microsoft-openjdk@11` | `run_onchange_after_22-register-jdks` registers the JDKs with jenv, so `jenv local <version>` just works |
| AWS & data | `awscli`, `leapp-cli` + `leapp`, `session-manager-plugin`, `databricks/tap/databricks` | The Leapp CLI and desktop app are separate packages |
| Apps | `iterm2`, `font-meslo-lg-nerd-font`, `visual-studio-code`, `google-chrome`, `firefox`, `postman`, `slack`, `zoom`, `spotify`, `twingate`, `dockutil` | The Nerd Font supplies the glyphs eza and starship draw |
| AI tooling | `claude-code`, `claude`, `antigravity-cli`, `skills` | CLI and desktop app; `antigravity-cli` provides `antigravity` (`agy`), not `gemini` |
| VS Code extensions | AWS Toolkit, Claude Code, Python, Pylance, Databricks | |
| Launchmetrics | GIS-lm-build | See [LM-Build](#lm-build) |

Decisions behind the list (full audit in SQA-3887): **nodenv**, not NVM · **jenv with real JDKs**,
three rather than one generic `openjdk` · **Homebrew over npm/pipx globals**, so updates happen in
one place · **IntelliJ dropped**, VS Code is the editor · **vim and starship kept** — in daily use
· **direnv, dbx and fasd dropped** (fasd left Homebrew core, and its `z` alias with it).

## LM-Build

`run_after_35-install-lm-build` follows the GIS-lm-build README: download the latest macOS
release, extract it into `~/.GIS-lm-build` (on `PATH` via `.zshrc`), check `lm version -v`. The
release is private, so until `gh auth login` each apply just prints a hint. Once installed it is
left alone — lm updates itself (`lm update`). `lm install-hooks` is not needed:
`dot_gitconfig.tmpl` already sets the same `core.hooksPath`. `lm github-setup` and
`lm jira-setup` stay manual (browser session cookie).

## Leapp / AWS SSO

`~/.Leapp/Leapp-lock.json` cannot be tracked — it is encrypted with a machine-local Keychain
secret and holds live session tokens — and the session list itself comes from AWS SSO on every
sync. What a sync does *not* restore is ours: the integration, the AWS named profiles and the
profile/region of each session. Without them all 20 sessions share the `default` profile, breaking
`aws --profile <name>` and the AWS VS Code toolkit. That lives in `.chezmoidata/leapp.yaml` and
is replayed by `~/.local/bin/leapp-bootstrap`.

`chezmoi apply` installs the command but does not run it: Leapp needs the workspace `Leapp.app`
creates on first launch, and the login opens a browser. Open Leapp once, then
`leapp-bootstrap --login` (without `--login` it does everything except the browser login). Every
step is a no-op when already done, so re-run it freely, e.g. after a `leapp.yaml` change. To
refresh that file after AWS SSO accounts change:

```sh
leapp session list --output=csv --columns="Session Name,Named Profile,Region/Location"
```

## Dock

Opt-in (the `chezmoi init` question), because a Dock is personal. `run_after_40-configure-dock`
pins iTerm, VS Code, Chrome, 1Password, Slack, zoom, Leapp, Claude and Spotify, adds a Downloads
stack, and sets auto-hide, size 61, no recents, no Spaces reordering and a bottom-right hot
corner to the Desktop. It waits until every pinned app is installed, then runs **once**: a
marker file (`~/.local/state/dotfiles/dock-configured`) keeps later applies, and later edits to
the script, away from a Dock already set up. `DOTFILES_DOCK_FORCE=1 chezmoi apply` applies it
without the apps still missing; delete the marker to apply it again.

## Still manual

- Laptop language/region and Jamf enrollment.
- Twingate device authorization (Twingate wiki page) and 1Password sign-in (invite email; the app
  is preinstalled).
- SSH/GPG key generation and the GitHub Packages token.
- iTerm2 preferences: loaded from `~/.config/iterm2`, which is git-ignored. To point iTerm2 at it:

  ```sh
  defaults write com.googlecode.iterm2 PrefsCustomFolder "$HOME/.config/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  ```

## Repo layout

| Path | Becomes / does |
|---|---|
| `.chezmoi.toml.tmpl` | The `chezmoi init` prompts |
| `.chezmoidata/` | `packages.yaml` (install list), `leapp.yaml` (Leapp config) |
| `.chezmoiscripts/` | Prezto, packages, jenv, LM-Build, Dock |
| `dot_*`, `private_dot_*`, `Library/…` | The dotfiles themselves (`~/.zshrc`, `~/.gitconfig`, `~/.aws/config`, VS Code settings, …) |
| `dot_local/bin/` | `~/.local/bin/leapp-bootstrap` |
| `Develop/.keep` | Creates `~/Develop` (the `.keep` file itself is not written) |
| `.chezmoiignore` / `.chezmoiremove` | Keep `README.md` out of `~`; remove `~/.vimrc` |
