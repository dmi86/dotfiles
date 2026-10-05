# dotfiles

Shared dev-environment configuration for macOS/zsh, managed with
[chezmoi](https://www.chezmoi.io/). Identity and machine-specific values come from `chezmoi init`
prompts, so the same repo works for anyone on the team.

Tracked work: [SQA-3887](https://launchmetrics.atlassian.net/browse/SQA-3887) (initial setup) ·
[SQA-3901](https://launchmetrics.atlassian.net/browse/SQA-3901) (open follow-ups: secrets backend,
unmanaged tooling, first real apply) ·
[SQA-3939](https://launchmetrics.atlassian.net/browse/SQA-3939) (fixes from the first fresh-Mac
install)

## This repo must stay private

`.chezmoidata/leapp.yaml` lists the org's AWS SSO portal URL and the name of every internal AWS
account, which together form an infrastructure map. `dot_config/iterm2/` is excluded from git for
the same reason and stays excluded. No credentials are committed — every secret is a
`REPLACE_WITH_*` placeholder or comes from a `chezmoi init` prompt stored outside the repo — but
the account inventory alone is enough that this repo should not be made public.

## What gets installed

[`.chezmoidata/packages.yaml`](.chezmoidata/packages.yaml) is the source of truth — edit it, not
the scripts. `run_20-install-packages` turns it into a Brewfile and runs `brew bundle install` on
every `chezmoi apply`, so adding a line there is all that is needed. `brew bundle` installs what
is missing, upgrades what is outdated (casks that update themselves, like Chrome or Slack, are
left to their own updater) and carries on past a failed entry. A failure is reported but never
stops the apply, and the next apply retries it.

Prezto is cloned when missing and pulled on every apply. GIS-lm-build is installed once and
then updates itself (`lm update`).

| Group | Package | Purpose |
|---|---|---|
| Prompt & shell | `starship` | Prompt theme, configured in `dot_config/starship.toml` |
| | Prezto | zsh framework — cloned, and kept updated, by `run_before_15-install-prezto`, not by Homebrew |
| | `vim` | `$EDITOR`. The binary only; vim config and plugins are out of scope |
| Terminal legibility | `eza` | `ls`/`ll`/`la`/`lt` with icons, colours and inline git status |
| | `bat` | Backs the `cat` alias and fzf's file preview |
| | `git-delta` | Git's pager and `diffFilter`, wired up in `dot_gitconfig.tmpl` |
| | `fzf` | Ctrl-R history search, Ctrl-T file picker, Alt-C directory jump |
| | `fd` | Fast file finder; also fzf's file/directory source |
| | `btop` | Resource dashboard (CPU/memory/disk/network) |
| | `htop` | Process management — killing and renicing, which `btop`'s TUI handles poorly |
| | `jq` | JSON processor — required by `pr_stats` in `dot_scripts/functions.zsh` |
| | `yq` | YAML processor — required by the `lm-build` integration |
| | `ripgrep` | Recursive search |
| | `coreutils` | GNU utilities — `gbranch()` needs `gdate` |
| Git | `git` | Version control |
| | `gh` | GitHub CLI; also backs the `credential.helper` in `dot_gitconfig.tmpl` |
| | `gnupg` + `pinentry-mac` | Commit signing (`commit.gpgsign = true`) with a GUI passphrase prompt |
| | `pre-commit` | Multi-language pre-commit hook runner |
| Node | `nodenv` | Node version manager (chosen over NVM) |
| | `yarn` | Package manager |
| | `npm-check-updates` | Finds newer dependency versions than `package.json` allows |
| Python | `pyenv` | Python version manager |
| | `btrachey/pyenv/pyenv-default-packages` | Tap formula; installs `dot_pyenv/default-packages` (`pylint`, `autopep8`) into every version |
| Java | `jenv` | JDK version manager |
| | `openjdk@17`, `openjdk@21`, `microsoft-openjdk@11` | The JDKs jenv manages; kept to compile the remaining Selenium repos. Registered with jenv by `run_onchange_after_22-register-jdks` (re-runs when the JDK list changes), so `jenv local <version>` works straight away |
| AWS & data | `awscli` | AWS CLI |
| | `leapp-cli` + `leapp` | AWS SSO session manager — CLI and desktop app are separate packages |
| | `session-manager-plugin` | Lets the AWS CLI open SSM sessions to managed instances |
| | `databricks/tap/databricks` | Databricks CLI, configured by `private_dot_databrickscfg.tmpl`. Not in Homebrew core, hence the tap |
| Terminal & fonts | `iterm2` | Terminal |
| | `font-meslo-lg-nerd-font` | The glyphs `eza --icons` and starship draw; without it both render as tofu |
| Apps | `visual-studio-code` | Primary editor |
| | `google-chrome`, `firefox` | Browsers |
| | `postman` | API client |
| | `slack`, `zoom` | Comms |
| | `spotify` | Music — pinned in the opt-in shared Dock |
| | `dockutil` | Builds the opt-in shared Dock (see [Dock](#dock)) |
| | `twingate` | Zero-trust network access |
| AI tooling | `claude-code` | Claude Code CLI |
| | `claude` | Claude desktop app |
| | `antigravity-cli` | Antigravity agents — provides `antigravity` (aliased `agy`), not `gemini` |
| | `skills` | Agent skills ecosystem ([skills.sh](https://skills.sh)) |
| Launchmetrics | GIS-lm-build | The `lm` CLI and the git hooks `core.hooksPath` points at. Not a Homebrew package — `run_after_35-install-lm-build` downloads the latest GitHub release (see below) |
| VS Code extensions | `aws-toolkit-vscode`, `claude-code`, `python`, `vscode-pylance`, `databricks-vscode` | Installed with `code --install-extension` |

Key decisions worth knowing (see SQA-3887 for the full audit):

- **nodenv**, not NVM, for Node versions.
- **jenv needs real JDKs to manage**, hence three of them rather than one generic `openjdk`.
- **Homebrew over npm/pipx globals**, so updates are handled in one place.
- **IntelliJ IDEA dropped** — VS Code is the primary editor.
- **`vim` and `starship` kept** despite the original audit marking them DROP: both are in daily
  use and unrelated to the Selenium/Java toolchain that was actually being retired.
- **`direnv`, `dbx` and `fasd` dropped.** `fasd` is gone from Homebrew core, so the `z` alias
  that used it went too.

## Bootstrap

Homebrew and chezmoi come first — there is no point bootstrapping Homebrew from inside a chezmoi
script.

```sh
# 1. Homebrew, then chezmoi
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi

# 2. If the Leapp CLI was ever installed through npm, remove it first: the npm
#    global owns /opt/homebrew/bin/leapp and makes `brew install leapp-cli` fail
#    to link.
npm uninstall -g @noovolari/leapp-cli 2>/dev/null

# 3. Pull the repo without touching the home directory yet
chezmoi init <this-repo-url>

# 4. Review every file that would be written, then apply
chezmoi diff
chezmoi apply
```

`chezmoi init` prompts once for your own identity and stores it in
`~/.config/chezmoi/chezmoi.toml`, which is never committed (see `.chezmoi.toml.tmpl`):

| Prompt | Used for |
|---|---|
| Full name | `user.name` in `.gitconfig` |
| Short handle | Branch names built by `gbranch()` — `jdoe` gives `m-jdoe_20260916_a1b2c3d_04217` |
| Work email | `user.email` in `.gitconfig` |
| GPG signing key | `user.signingkey`; leave blank to skip commit signing |
| Shared Dock | Opt-in, default no — applies the team Dock layout once (see [Dock](#dock)) |

Nothing is pre-filled, so you cannot accidentally inherit someone else's identity. There is no
work/personal identity split — everything uses the work identity.

`chezmoi apply` overwrites the files it manages, so step 4 is not optional on a machine that
already has a `.zshrc`, `.gitconfig`, or `.scripts`. It also *removes* `.vimrc`, declared in
`.chezmoiremove`.

Apps you installed by hand before the first apply (Chrome and Slack are the usual ones) show up
as failed in the `brew bundle` output, but the apply carries on and the app keeps working and
updating itself. To hand one over to Homebrew, run `brew install --cask --force <name>`.

### After the first apply

```sh
exec zsh              # first apply only: pick up ~/.local/bin and lm on PATH

# Leapp — open Leapp.app once so it creates its workspace, then:
leapp-bootstrap --login

# LM build — the release is in a private repo, so it installs on the apply after gh is logged in
gh auth login
chezmoi apply
lm github-setup       # paste a GitHub session cookie, following the prompts
lm jira-setup         # same, with a Jira session cookie
```

- **Leapp.** `chezmoi apply` installs Leapp and the `leapp-bootstrap` command but does not run
  it: Leapp needs its workspace, which only exists once `Leapp.app` has been opened. Open it once,
  then run `leapp-bootstrap --login`, which configures everything and opens the SSO browser login
  to finish the session mapping (see [Leapp / AWS SSO](#leapp--aws-sso)).
- **LM build.** Its release is in a private repo, so until `gh auth login` has run every apply
  prints a hint and carries on; the next `chezmoi apply` after it installs lm (the README steps
  of GIS-lm-build: download, extract, `lm version -v`). From then on lm updates itself with
  `lm update`. `lm install-hooks` is not needed — `dot_gitconfig.tmpl` already sets the same
  `core.hooksPath`. `lm github-setup` and `lm jira-setup` stay manual: each needs a browser
  session cookie.
- **Placeholder secrets** — `.npmrc` and `.databrickscfg` are written with `REPLACE_WITH_*`
  values. Fill in your own GitHub Packages token and Databricks host/token by hand; no real
  credential is ever committed to this repo.

## Structure

| Path | Purpose |
|---|---|
| `.chezmoi.toml.tmpl` | Generates `~/.config/chezmoi/chezmoi.toml`; prompts for git name/work email/signing key |
| `.chezmoidata/packages.yaml` | Source of truth for Homebrew formulae/casks and VS Code extensions |
| `.chezmoidata/leapp.yaml` | Leapp AWS SSO integration, named profiles, and the session -> profile/region mapping |
| `.chezmoiscripts/` | Bootstrap Prezto, install everything in `packages.yaml`, register the JDKs with jenv, install GIS-lm-build, lay out the opt-in Dock (apps and settings live in the script) |
| `Develop/.keep` | Creates `~/Develop`; chezmoi creates the directory without writing the `.keep` file |
| `.chezmoiremove` | Declares `.vimrc` removed — not managed here |
| `.chezmoiignore` | Excludes `README.md` from the apply; it is repo docs, not a dotfile |
| `dot_local/bin/executable_leapp-bootstrap.tmpl` | Becomes `~/.local/bin/leapp-bootstrap`: replays `leapp.yaml` through the `leapp` CLI, safe to re-run |
| `dot_pyenv/default-packages` | Python tools installed into every pyenv-managed version |
| `dot_gitconfig.tmpl` | Identity, `hooksPath` (LM git-hooks), `gh`-backed credential helpers, delta as pager |
| `dot_gitignore` | Global gitignore |
| `dot_zprofile` / `dot_zshrc` | Homebrew shellenv, Prezto init, pyenv/jenv/nodenv init, iTerm tab-title hook, starship hookup, bat theme, fzf keybindings |
| `dot_zpreztorc` | Prezto module config (autosuggestions, starship prompt theme, syntax highlighting) |
| `dot_scripts/*.zsh` | Aliases (including the `eza` ls set), git helpers, and the `help-*` functions, sourced from `.zshrc`. `aliases.zsh.tmpl` is templated for the `gbranch()` handle |
| `dot_config/starship.toml` | Prompt theme, at the path starship actually reads |
| `Library/Application Support/Code/User/settings.json` | VS Code settings |
| `private_dot_gnupg/gpg-agent.conf` | Points GPG at `pinentry-mac` |
| `private_dot_aws/config` | Default AWS CLI region/output, from the "First steps QA" wiki guide |
| `private_dot_npmrc.tmpl` | GitHub Packages registry — token is a placeholder, fill in after apply |
| `private_dot_databrickscfg.tmpl` | Databricks staging/prod — host/token are placeholders, fill in after apply |

## Leapp / AWS SSO

Partially automated. The split matters:

- **Not committable.** `~/.Leapp/Leapp-lock.json` is an openssl-encrypted blob (`openssl enc`,
  salted, base64) whose password lives in the macOS Keychain. It cannot be decrypted on another
  machine, and it holds session tokens — so it is neither portable nor safe to track.
- **Not ours to declare.** Every session is *generated* by Leapp when it syncs the AWS SSO
  integration. The account/role list is owned by AWS SSO; duplicating it here would just go
  stale.
- **Ours, and therefore tracked.** The integration definition, the AWS named profiles, and the
  profile/region each session is pinned to. Without these a fresh sync leaves all 20 sessions
  sharing the `default` profile, which breaks every `aws --profile <name>` call and the AWS
  VS Code toolkit. That mapping lives in `.chezmoidata/leapp.yaml`.

`chezmoi apply` installs `~/.local/bin/leapp-bootstrap` but does not run it — Leapp needs the
workspace `Leapp.app` creates on first launch, and the SSO login opens a browser. Run it by hand
once Leapp has been opened, and again after pulling a change to `leapp.yaml`:

```sh
leapp-bootstrap --login   # creates the integration, default region and named profiles,
                          # logs in, syncs and maps every session
```

Without `--login` it does everything except the browser login. Every step is a no-op when
already in the desired state, so re-running is free. To refresh the
mapping in this repo after accounts are added or renamed in AWS SSO, regenerate the `sessions`
list in `.chezmoidata/leapp.yaml` from:

```sh
leapp session list --output=csv --columns="Session Name,Named Profile,Region/Location"
```

## Dock

**Opt-in.** The Dock is personal, so this only runs if you answered yes to the "shared Dock"
question in `chezmoi init` (to change your answer later: `chezmoi init --prompt`).
`run_after_40-configure-dock` then lays out the team Dock (the app list and settings are in the
script itself):

- **Pinned, left to right:** iTerm, Visual Studio Code, Google Chrome, 1Password, Slack, zoom,
  Leapp, Claude, Spotify.
- **Right-hand side:** Downloads as a stack, sorted by date added, fan view.
- **Settings:** bottom, auto-hide on, icon size 61, no magnification, no recent apps, Spaces
  not reordered by recent use, bottom-right hot corner shows the Desktop.

It replaces the whole Dock, **once per machine, after every pinned app is installed**:

- It runs after the package install on every apply, but does nothing until all the apps above
  are in `/Applications` — until then it prints which ones it is waiting for.
- Once it has laid out the Dock it writes `~/.local/state/dotfiles/dock-configured` and never
  runs again. Whatever you change in your own Dock afterwards is kept, and a later change to
  the script only shapes machines set up after it. (Not `run_once_`: chezmoi keys that on the
  script's content, so every edit would reset every Dock again.)
- `DOTFILES_DOCK_FORCE=1 chezmoi apply` lays it out now, without the apps still missing.
  Delete the marker file to have the shared layout applied again.

## Still manual

Not automatable, and not attempted:

- Laptop language/region and Jamf enrollment.
- VPN device authorization — follow the Twingate wiki page.
- 1Password account sign-in — follow the invite email; the app itself comes preinstalled.
- `lm github-setup` and `lm jira-setup` — each needs a browser session cookie.
- GPG/SSH private key generation, and creating the GitHub Packages token.
- The AWS SSO browser login — everything around it is scripted, see above.
- **iTerm2 preferences.** iTerm2 loads them from `~/.config/iterm2` via its "Load preferences
  from a custom folder" setting, and the plist is deliberately untracked: its profiles embed
  internal host references that should not live in a public repo. `.gitignore` excludes
  `dot_config/iterm2/` so it cannot be committed by accident. To repoint iTerm2 on a new
  machine:

  ```sh
  defaults write com.googlecode.iterm2 PrefsCustomFolder "$HOME/.config/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  ```
