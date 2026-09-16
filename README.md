# dotfiles

Shared dev-environment configuration for macOS/zsh, managed with
[chezmoi](https://www.chezmoi.io/). Identity and machine-specific values come from `chezmoi init`
prompts, so the same repo works for anyone on the team.

Tracked work: [SQA-3887](https://launchmetrics.atlassian.net/browse/SQA-3887) (initial setup) ·
[SQA-3901](https://launchmetrics.atlassian.net/browse/SQA-3901) (open follow-ups: secrets backend,
unmanaged tooling, first real apply)

## This repo must stay private

`.chezmoidata/leapp.yaml` lists the org's AWS SSO portal URL and the name of every internal AWS
account, which together form an infrastructure map. `dot_config/iterm2/` is excluded from git for
the same reason and stays excluded. No credentials are committed — every secret is a
`REPLACE_WITH_*` placeholder or comes from a `chezmoi init` prompt stored outside the repo — but
the account inventory alone is enough that this repo should not be made public.

## What gets installed

[`.chezmoidata/packages.yaml`](.chezmoidata/packages.yaml) is the source of truth — edit it, not
the scripts. `run_onchange_20-install-packages` installs whatever is missing on every apply, so
adding a line there is all that is needed.

| Group | Package | Purpose |
|---|---|---|
| Prompt & shell | `starship` | Prompt theme, configured in `dot_config/starship.toml` |
| | Prezto | zsh framework — cloned by `run_once_before_15-install-prezto`, not by Homebrew |
| | `vim` | `$EDITOR`. The binary only; vim config and plugins are out of scope |
| Terminal legibility | `eza` | `ls`/`ll`/`la`/`lt` with icons, colours and inline git status |
| | `bat` | Backs the `cat` alias and fzf's file preview |
| | `git-delta` | Git's pager and `diffFilter`, wired up in `dot_gitconfig.tmpl` |
| | `fzf` | Ctrl-R history search, Ctrl-T file picker, Alt-C directory jump |
| | `fd` | Fast file finder; also fzf's file/directory source |
| | `btop` | Process and resource viewer |
| | `jq` | JSON processor — required by `pr_stats` in `dot_scripts/functions.zsh` |
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
| | `openjdk@17`, `openjdk@21`, `microsoft-openjdk@11` | The JDKs jenv manages; kept to compile the remaining Selenium repos |
| AWS & data | `awscli` | AWS CLI |
| | `leapp-cli` + `leapp` | AWS SSO session manager — CLI and desktop app are separate packages |
| | `session-manager-plugin` | Lets the AWS CLI open SSM sessions to managed instances |
| | `databricks` | Databricks CLI, configured by `private_dot_databrickscfg.tmpl` |
| Terminal & fonts | `iterm2` | Terminal |
| | `font-meslo-lg-nerd-font` | The glyphs `eza --icons` and starship draw; without it both render as tofu |
| Apps | `visual-studio-code` | Primary editor |
| | `google-chrome`, `firefox` | Browsers |
| | `postman` | API client |
| | `slack`, `zoom` | Comms |
| | `twingate` | Zero-trust network access |
| AI tooling | `claude-code` | Claude Code CLI |
| | `antigravity-cli` | Antigravity agents — provides `antigravity` (aliased `agy`), not `gemini` |
| | `skills` | Agent skills ecosystem ([skills.sh](https://skills.sh)) |
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

Nothing is pre-filled, so you cannot accidentally inherit someone else's identity. There is no
work/personal identity split — everything uses the work identity.

`chezmoi apply` overwrites the files it manages, so step 4 is not optional on a machine that
already has a `.zshrc`, `.gitconfig`, or `.scripts`. It also *removes* `.vimrc`, declared in
`.chezmoiremove`.

Two things need a follow-up after the first apply:

- **Leapp** — finish the AWS SSO setup with `leapp-bootstrap --login` (see below).
- **Placeholder secrets** — `.npmrc` and `.databrickscfg` are written with `REPLACE_WITH_*`
  values. Fill in your own GitHub Packages token and Databricks host/token by hand; no real
  credential is ever committed to this repo.

## Structure

| Path | Purpose |
|---|---|
| `.chezmoi.toml.tmpl` | Generates `~/.config/chezmoi/chezmoi.toml`; prompts for git name/work email/signing key |
| `.chezmoidata/packages.yaml` | Source of truth for Homebrew formulae/casks and VS Code extensions |
| `.chezmoidata/leapp.yaml` | Leapp AWS SSO integration, named profiles, and the session -> profile/region mapping |
| `.chezmoiscripts/` | Bootstrap Prezto, install everything in `packages.yaml`, configure Leapp, create `~/Develop` |
| `.chezmoiremove` | Declares `.vimrc` removed — not managed here |
| `dot_local/bin/executable_leapp-bootstrap.tmpl` | Becomes `~/.local/bin/leapp-bootstrap`; replays `leapp.yaml` through the `leapp` CLI, safe to re-run |
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

`chezmoi apply` runs `~/.local/bin/leapp-bootstrap`, which creates the integration, sets the
default region, and creates the named profiles. Mapping sessions needs the integration online,
and the SSO login opens a browser, so that step is opt-in:

```sh
leapp-bootstrap --login
```

Every step is a no-op when already in the desired state, so re-running is free. To refresh the
mapping in this repo after accounts are added or renamed in AWS SSO, regenerate the `sessions`
list in `.chezmoidata/leapp.yaml` from:

```sh
leapp session list --output=csv --columns="Session Name,Named Profile,Region/Location"
```

## Still manual

Not automatable, and not attempted:

- Laptop language/region and Jamf enrollment.
- VPN device authorization (Twingate) and 1Password account sign-in.
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
