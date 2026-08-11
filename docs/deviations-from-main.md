# Deviations from main

Written 2026-08-03, updated 2026-08-04. Records what was changed on this machine
and **why**, so a future session doesn't have to re-derive it.

Two very different kinds of deviation are recorded here:

- **[Part A](#part-a--in-repo-changes)** — changes to *this repo*, which git tracks.
- **[Part B](#part-b--machine-setup-deviations-from-the-readme)** — changes to *this machine*, which git does not track at all. This is the part that is easy to lose.

**Context.** Personal Windows PC, WSL2 Debian 13 (trixie), `amd64`. The repo is
cloned to `~/.config/nvim` from `https://github.com/TajBanana/nvim` and checked
out on **`windows-config`**. The readme's setup instructions assume **macOS +
Homebrew**; almost none of them apply verbatim here, which is what Part B is
about.

**Branch lineage.** The work described here started as uncommitted changes on
`feat/per-line-blame-images-gotmpl`, moved to `fix/audit-findings-2026-08` while
the audit fixes landed, and now lives on **`windows-config`** — a branch created
specifically to hold "make this repo work on this Windows/WSL2 box", which is
the subject of A1-A3 (A4 is audit follow-up that simply landed here too).
Earlier revisions of this document named
those older branches; `windows-config` supersedes them. Historical records under
`docs/reviews/` still name the branch they ran on, deliberately — see the note
in [A1](#a1-gitlab--github-port).

---

## Part A — in-repo changes

### A1. GitLab → GitHub port

**Status:** committed on `windows-config` as `2536588`
(*feat(git): port the forge shortcuts from GitLab to GitHub*).

**Why.** This is a personal machine with no access to `gitlab.thalesdigital.io`
and no reason to acquire it — work and personal identities are deliberately kept
apart here. Every remote reachable from this box is GitHub, so the GitLab module
was dead code that produced 404s. Rather than delete the feature, it was ported.

**Why it was a small change.** Both forges publish change-request heads as
fetchable refs — GitLab as `refs/merge-requests/<iid>/head`, GitHub as
`refs/pull/<n>/head`. The original module's best property (resolve an existing
MR with **no CLI and no API token**) therefore carried over unchanged. Only the
URL shapes and the CLI invocation differed.

**URL / API mapping applied:**

| Concern | GitLab (before) | GitHub (after) |
|---|---|---|
| Existing change request | `/-/merge_requests/<iid>` | `/pull/<n>` |
| Create page | `/-/merge_requests/new?merge_request%5Bsource_branch%5D=<branch>` | `/compare/<branch>?expand=1` |
| File blob | `/-/blob/<ref>/<path>` | `/blob/<ref>/<path>` |
| Line range anchor | `#L10-20` | `#L10-L20` |
| ls-remote ref glob | `refs/merge-requests/*/head` | `refs/pull/*/head` |
| CLI lookup | `glab mr view --output json --jq .web_url` | `gh pr view --json url --jq .url` |

The **range anchor is the trap**: GitHub repeats the `L`. A port that misses this
produces a URL that loads but silently highlights the wrong thing — it fails
soft, so it won't show up in casual testing.

**Files touched:**

| File | Change |
|---|---|
| `lua/tajbanana/github.lua` | **New.** Port of `gitlab.lua`; structure, helpers and comment style preserved so the diff against the original stays legible. |
| `lua/tajbanana/gitlab.lua` | **Deleted** (`git rm`). |
| `lua/tajbanana/set.lua` | `require("tajbanana.gitlab").setup()` → `require("tajbanana.github").setup()`, plus the comment above it. |
| `lua/tajbanana/gitutil.lua` | Header comment now names `github.lua`. |
| `CLAUDE.md` | Module list entries for `github.lua` and `gitutil.lua`. |
| `docs/architecture.md` | Module list entry. |
| `docs/design-decisions.md` | Section retitled and rewritten; notes the port and the `#L-L` difference. |
| `readme.md` | Keymap table section, prerequisites (`glab` → `gh`), layout bullet, brew quick-start, and the three prose paragraphs of the forge section. |

Keymaps are unchanged (`<leader>gm`, `<leader>gl` in normal and visual); only
their `desc` strings now say GitHub/PR.

**Deliberately NOT changed:**

- **`docs/reviews/*.md`** still say "GitLab" and reference `open_gitlab_mr`.
  These are historical review records — statements about what was true when the
  review ran. Rewriting them would falsify the record.
- **`lua/plugins/telescope.lua`** still lists `.gitlab/` in
  `file_ignore_patterns`. It was left rather than swapped to `.github/` on
  purpose: `.github/` holds workflow files you often *do* want to open, so
  ignoring it would be an unwanted behaviour change. The `.gitlab/` entry is
  inert here (no such directory) and costs nothing.

**To reverse this** (e.g. on a work machine): `git checkout main -- lua/tajbanana/gitlab.lua`,
restore the `require` line in `set.lua`, delete `github.lua`. The forge
assumption lives in exactly one module by design, which is what made both
directions cheap.

### A2. `.wezterm.lua` — merged into one cross-platform file

**Status:** committed on `windows-config` as `1fa5679`
(*feat(wezterm): merge the macOS and Windows configs into one cross-platform file*).
Also **copied** to `C:\Users\TajBanana\.wezterm.lua` (previous version backed up
alongside it as `.wezterm.lua.bak-20260803`).

> **This copy has already drifted once.** By 2026-08-04 it had fallen behind the
> `shells[proc]` filter in the window-title function, so on the Windows side the
> *window* title read `[zsh] nvim` while the tab for the same pane read `nvim`.
> Re-copied 2026-08-09 and verified identical; the pre-overwrite version is kept
> as `.wezterm.lua.bak-20260809-143935`. Expect this to recur — see the
> deployment note at the end of this section.

**Why.** The repo file was macOS-only; the Windows machine kept a hand-edited
fork. They had drifted **in both directions**:

| | Repo copy had | Windows copy had |
|---|---|---|
| `enable_kitty_graphics` | ✅ | ❌ |
| task-aware `[app] dir` tab titles | ✅ | ❌ |
| WSL boot | ❌ | ✅ (`default_prog`) |
| Windows `Ctrl`/`Alt` key remaps | ❌ | ✅ |
| WSL `/home/*` path handling | ❌ | ✅ |

The missing `enable_kitty_graphics` is the reason this mattered: WezTerm ships
the kitty graphics protocol **off**, so snacks.nvim's inline images were
rendering blank on Windows — with no error. A fork silently losing a feature is
the failure mode this merge exists to prevent.

**How.** One file branching on `wezterm.target_triple`. Only three things differ
per platform: modifier set, font sizes, and the WSL domain block.

**Two Windows fixes applied while merging:**

- `default_prog = { 'wsl.exe', '-d', 'Debian' }` → `wsl_domains` + `default_domain`.
  `default_prog` spawns wsl.exe as an opaque process so WezTerm cannot track a
  pane's cwd — and the tab-title function reads exactly that. A declared domain
  reports cwd properly.
- `default_cwd = '/home/TajBanana'`. Panes previously opened in the Windows cwd
  (`/mnt/c/Users/...`), i.e. the Windows filesystem over the 9p bridge, which is
  markedly slower for git than the distro's ext4.

**Tab titles showed `[wslhost.exe]` instead of `[claude]`.** WezTerm runs on the
Windows side, so a WSL pane's `foreground_process_name` is the Windows *host*
process; it can't see into the distro's process tree. Fixed by inverting the
direction — zsh `preexec`/`precmd` hooks in `~/.zshrc` publish the command line
as the `WEZTERM_PROG` user var (OSC 1337, base64) plus the cwd via OSC 7, and
`pane_prog()` in `.wezterm.lua` prefers that. Verified under a pty: the var
cycles `'' → 'sleep 1' → ''`, and OSC 7 reports
`DESKTOP-3P3GIJ3/home/TajBanana`. This install ships no
`shell-integration/wezterm.sh`, hence the hand-rolled hooks.

**Deployment is a copy, not a symlink** — WezTerm runs on Windows and reads
`C:\Users\<you>\.wezterm.lua`; a WSL symlink into `~/.config/nvim` isn't
resolvable from there. Re-copy after editing the repo file:

```bash
cp ~/.config/nvim/.wezterm.lua /mnt/c/Users/TajBanana/.wezterm.lua
# check first:
diff ~/.config/nvim/.wezterm.lua /mnt/c/Users/TajBanana/.wezterm.lua
```

Nothing automates this and nothing warns you, so the two drift silently — which
is exactly how the fork this section exists to undo came about in the first
place. The `diff` above is the cheap guard; run it after any `.wezterm.lua` edit.

### A3. `lazy-lock.json` — resolved conflict, no net change

Recorded because the *cause* will recur.

A `Lazy! sync` run on `main` dropped a stale `undotree` entry from the lockfile.
Switching to the feature branch auto-stashed that edit; popping it conflicted,
leaving an unmerged `lazy-lock.json` with **no `MERGE_HEAD`** — the signature of
a conflicted `git stash pop`, not a merge. Resolved by taking the branch's
committed version (`git checkout HEAD -- lazy-lock.json`), confirmed correct
because `lua/plugins/git.lua` carries an explicit comment that fugitive was
removed in favour of lazygit. The stash was dropped; its only content was that
one artifact line.

**Lesson:** on a fresh clone use **`:Lazy restore`** (installs at the pinned
commits), never `:Lazy sync` (updates *past* them and rewrites the lockfile).

**A related lockfile gap, since fixed.** `cmp-buffer` was declared as an
nvim-cmp dependency in `lua/plugins/lsp.lua` but was absent from both
`lazy-lock.json` and the plugin directory — so nvim-cmp advertised a `buffer`
source that nothing provided and word-from-buffer completion silently did
nothing. It surfaced only when a headless boot installed the missing plugin and
lazy wrote the new lockfile line. Both are now present.

**Worth generalising:** a spec/lockfile mismatch fails *silently* here, because
lazy just installs the missing plugin on the next start and says nothing. After
adding a dependency, confirm it reached the lockfile (`grep <plugin> lazy-lock.json`)
rather than assuming the spec edit was enough.

### A4. Audit fixes and git-delta

**Status:** committed on `windows-config`.

Not machine-specific deviations, but they landed on this branch and a future
reader will otherwise wonder why it carries more than a forge port and a
terminal config. All but the last come from the audit recorded in
`docs/reviews/audit_004_outstanding_findings.md`.

| Commit | Change |
|---|---|
| `3b49cfb` | lspconfig loads eagerly; servers that cannot run on this box are no longer enabled (the missing Rust toolchain made every `.rs` buffer throw). |
| `66d854b` | Real Helm chart templates (`*/templates/*.yaml`) route to the `helm` filetype instead of drawing thousands of bogus `yamlls` diagnostics. |
| `da39112` | `<M-Up>` no longer errors at the treesitter root, and no longer reuses a stale node stack. |
| `393b3ad` | `GitSignsUpdate` handler guarded; merge-base cache keyed by repo *and* HEAD so a branch switch recomputes it. |
| `adb5ed0` | ktlint's exit 1 accepted (it still writes valid output), and `jsonc` routed through prettier. |
| `63002d9` | Assorted correctness fixes from the same audit. |
| `6f8ddc5` | git-delta for side-by-side diffs. |

**git-delta is wired by `include`, not by symlink** — `git/delta.gitconfig` is
pulled in with `git config --global --add include.path ~/.config/nvim/git/delta.gitconfig`,
so `git config --global` edits and this repo can never overwrite each other.
Verified present in the global config on this machine, with `delta` on PATH at
`/usr/bin/delta`.

**The audit is not finished.** `docs/reviews/audit_004_outstanding_findings.md`
still lists outstanding findings that were confirmed but not fixed, plus a
"Refuted — do not spend time on these" section listing 25 plausible-sounding
candidates already disproven. Read that section before opening a new audit; a
fresh static pass will re-raise several of them.

---

## Part B — machine setup, deviations from the readme

The readme's prerequisites are written for macOS/Homebrew. Here is what was
actually done, and why the obvious command was wrong.

Note on the "macOS equivalent" column: the readme's prerequisites table only
covers Neovim, ripgrep, the tree-sitter CLI, lazygit, ImageMagick, a Nerd Font
and (optionally) `gh`. The `fd`, `bat` and `glab` rows below are *not* from the
readme — they are shell-environment tools this machine needed alongside it, and
the command shown is the Homebrew one they would have used on macOS.

| Tool | macOS equivalent | Done here | Why |
|---|---|---|---|
| **Neovim** | `brew install neovim` | GitHub release tarball → `~/.local/share/nvim-linux-x86_64`, symlinked into `~/.local/bin` | **Critical.** Debian trixie ships **0.10.4**; this config requires **0.11+** (native `vim.lsp.config`/`vim.lsp.enable`). `apt install neovim` produces a config that errors on startup. Installed **0.12.4**. |
| **tree-sitter CLI** | `brew install tree-sitter-cli` | `npm install -g tree-sitter-cli` (0.26.11) | apt has **0.22.6**; nvim-treesitter is pinned to its **`main`** branch, which needs **≥ 0.25** to install parsers. |
| **fd** | `brew install fd` | `apt install fd-find` + symlink `~/.local/bin/fd` | Debian installs the binary as **`fdfind`**. `.zshrc` guards on `command -v fd`, so without the symlink it fails **silently** — fzf just quietly stops respecting `.gitignore`. |
| **bat** | `brew install bat` | `apt install bat` + symlink `~/.local/bin/bat` | Same trap: Debian installs **`batcat`**. Silently disables the `cat` alias and both fzf previews. |
| **node** | nvm or system | **nvm 0.40.6**, Node **24.19.0** | apt's Node 20 was removed (**154 packages**, all Debian's JS ecosystem). Left installed it would shadow nvm for nvim, because `env.lua` only reaches for nvm's node when `node` is *absent* from PATH. |
| **java** | a JDK | **SDKMAN** + Temurin **21.0.12** | jdtls needs 21+. Kotlin's kotlin-lsp bundles its own runtime and needs none. |
| **go** | `brew install go` | `apt install golang-go` (1.24.4) | Mason builds gopls via `go install`; without a toolchain it fails with "cannot find go in path". |
| **ruff** | `python3 + ruff` | `uv tool install ruff` (0.16.1) | `pip3` isn't installed; `uv` (also in `~/.local`) avoids needing it or a venv. |
| **gh** | `brew install gh` | GitHub release tarball → `~/.local` (2.97.0) | apt has **2.46** (early 2024). Needed by the new `github.lua` fast path. |
| **glab** | `brew install glab` | **not installed** | Superseded by the GitHub port (A1). |
| **Nerd Font** | `brew install --cask …` | installed on the **Windows** side | WSL has no font rendering; the Windows terminal draws the glyphs. Nothing inside WSL can fix garbled icons. |

**Pattern worth remembering:** every tool that had to bypass `apt` did so for the
same reason — Debian stable's version was too old for a pinned dependency. The
fallback in each case was the project's own release tarball into `~/.local`,
which needs no `sudo` and no PPA.

### The `~/.npmrc` / nvm interaction

`npm install -g` originally failed with `EACCES` on `/usr/local/lib/node_modules`.
Fixed with `npm config set prefix ~/.local` — but **nvm refuses to run with a
global npm prefix set**, so that line was deleted again when nvm was installed.
Global installs now follow the active nvm version, which is the desired
behaviour. Do not re-add it.

`~/.local/bin/tree-sitter` survived the prefix change because it's a prebuilt
native binary, not a node script.

### Undercurl needs the WezTerm **nightly** on Windows

**Status: RESOLVED 2026-08-11** by installing the nightly (`20260810-043511-e723cf50`);
the `printf` reproducer below now renders a red wavy underline. Kept because the
diagnosis took a long time, the symptom is silent, and the requirement returns on
any fresh Windows box — stable WezTerm still cannot render these on WSL2.

`colorscheme.lua` styles `DiagnosticUnderlineError`/`Warn` as red and orange
undercurl. On this box the underlines simply do not appear, and everything on the
Neovim side is provably correct:

- `vim.diagnostic.config().underline` is `true`; the extmarks carry
  `DiagnosticUnderlineError` over the right columns with `sp=#f07178 undercurl=true`.
- Captured through a pty, nvim emits `ESC[4:3m` (undercurl) and
  `ESC[58:2::r:g:b` (underline colour) exactly as it should.

The terminal drops them. Test it in one command:

```bash
printf '\e[4mA  legacy underline\e[0m\n'          # renders
printf '\e[9mB  strikethrough\e[0m\n'             # renders
printf '\e[4:3mC  undercurl\e[0m\n'               # NOTHING
printf '\e[4m\e[58:2::255:0:0mD  red underline\e[0m\n'  # underline, but NOT red
```

Legacy SGR renders; anything with a **subparameter** (`4:1`, `4:3`, `58:...`) is
discarded. That rules out the font and `line_height`, which were the first
suspects.

**Cause: WezTerm's bundled ConPTY, not WezTerm itself.** WezTerm has supported
undercurl for years (upstream `wezterm#415`, closed). On Windows every pane runs
through ConPTY — `config.default_domain = 'WSL:Debian'` spawns `wsl.exe`, and
WezTerm ships `conpty.dll`/`OpenConsole.exe` — and the bundled ConPTY strips
subparameter SGR. Upstream `wezterm#4400` ("Colored undercurl and underline on
WSL2 / updated ConPTY") is labelled `conpty limitation` + **`fixed-in-nightly`**;
the note there is that Microsoft's fix "did not make [it] into a release", so
WezTerm vendored it into nightlies only.

**Fix: install the nightly and pin it.** Stable is a dead end — winget's
`wez.wezterm` *is* `20240203-110809-5046fc22`, the newest stable, and there has
been no stable release since Feb 2024.

```powershell
winget uninstall wez.wezterm
winget install wez.wezterm.nightly --source winget
winget pin add wez.wezterm.nightly     # freeze it; nightly otherwise rolls forward
```

Run it from PowerShell, **not from inside WezTerm** — the installer needs it
closed. Config at `C:\Users\<you>\.wezterm.lua` is untouched.

**This is Windows-only.** ConPTY does not exist on macOS, so undercurl works on
stable WezTerm there. The `colorscheme.lua` highlights need **no platform guard** —
they are correct on both, merely inert here until the nightly is installed.

**Dead ends, recorded so they are not retried:** `config.term = 'wezterm'` cannot
help — the failure reproduces from a bare `printf`, where `$TERM` plays no part —
and the `wezterm` terminfo is not installed in this distro, so setting it would
break TUI key handling.

---

### Clipboard: `wl-clipboard` is required — RESOLVED

**Status: fixed 2026-08-09** by `sudo apt install wl-clipboard`. Verified: a path
set in nvim's `+` register was read back by PowerShell's `Get-Clipboard`. Kept
because the diagnosis is not obvious and the same symptom will recur on any fresh
WSL box — and because installing it had a side effect, recorded at the end.

Before the fix, yanking put nothing on the Windows clipboard. The config was
**not** at fault — `lua/tajbanana/set.lua` sets `clipboard:append("unnamedplus")`,
which correctly routes `y` to the `+` register. The gap was that nvim never talks
**not** at fault — `lua/tajbanana/set.lua` sets `clipboard:append("unnamedplus")`,
to the OS clipboard itself; it shells out to a helper binary, and none of the
ones it probes existed on this box:

```
:lua print(vim.fn['provider#clipboard#Error']())
clipboard: No clipboard tool. :help clipboard

has('clipboard') = 0        provider#clipboard#Executable() = ''
```

| Helper nvim probes | Present here |
|---|---|
| `wl-copy` / `wl-paste` | ❌ — despite WSLg running (`WAYLAND_DISPLAY=wayland-0`) |
| `xclip` / `xsel` | ❌ — despite `DISPLAY=:0` |
| `win32yank.exe` | ❌ — the usual WSL helper |

**The trap:** `WAYLAND_DISPLAY` and `DISPLAY` are both set, so this *looks* like
a working graphical session and the failure reads as an nvim bug. It isn't —
WSLg provides the display sockets but installs no clipboard CLI, and nvim has
nothing to exec. Nothing in Lua can fix it; the fix is a package.

**The fix applied: `sudo apt install wl-clipboard`.** nvim probes
`wl-copy`/`wl-paste` *first* when `WAYLAND_DISPLAY` is set, so it is auto-detected
with **no config change**, and it fixes the clipboard for every other terminal
program too. `provider#clipboard#Executable()` now returns `wl-copy`.

**⚠ It had a side effect that broke something else.** `wl-clipboard` pulls in
`xdg-utils` as a dependency — same dpkg transaction, `2026-08-09 19:25:52` — which
put `xdg-open` on `PATH`. `vim.ui.open` prefers `xdg-open` over `explorer.exe`, and
this box has no desktop session, so `xdg-open` exits 4 for every file and
`<leader>go` silently stopped working. Fixed in `set.lua` by choosing the launcher
explicitly; see the `<leader>go` section in `docs/design-decisions.md`.

**The generalisable lesson:** an apt dependency of an unrelated package changed
nvim's behaviour with no config change, and failed silently. When installing a
package to fix one thing here, check what it dragged in:
`grep " install " /var/log/dpkg.log | tail`.

**Rejected alternatives**, recorded so they are not re-litigated:

1. **`win32yank.exe`** into `~/.local/bin` — no sudo, also auto-detected, and
   independent of WSLg. A reasonable second choice; unnecessary once apt worked.
2. **`clip.exe` + PowerShell via an explicit `vim.g.clipboard`** — needs no
   install and the round trip was verified working, but it was also *measured*
   and is the reason it ranked last:

   | operation | measured |
   |---|---|
   | `clip.exe` write (yank) | ~27 ms |
   | `powershell Get-Clipboard` (paste) | **~225 ms** |

   With `unnamedplus` that quarter-second lands on paste operations, and
   PowerShell additionally appends a trailing newline and mangles CRLF.

---

## Part C — `~/.zshrc` deviations from the work-machine version

The config was carried over from the work machine. Five changes were required to
make it work here; each was a silent failure, not a loud one.

| Change | Why |
|---|---|
| Added `export PATH="$HOME/.local/bin:$PATH"` near the top | The original never had it. nvim, gh, tree-sitter, ruff and uv all live there — the `vim`/`vi`/`nv` aliases would all have been broken. |
| Removed the bare `kproxy` call at the bottom | It exported `http_proxy=127.0.0.1:9000` in **every** shell. Nothing listens on 9000 here, so apt/curl/git/npm would all break. The **alias** is kept — run it by hand when the proxy is up. |
| Guarded the `DEV_TOOLS_HOME` block | Unset on this machine, so it prepended a bare `/bin` to PATH and sourced `/bin/setup-dev-env.sh`, erroring on every startup. |
| `stat -f %Sm -t %j` → `date -r "$cache" +%j` | BSD/macOS syntax. On GNU coreutils it errors, and `2>/dev/null` swallowed it — so the kubectl/helm/docker completion caches regenerated on **every** shell start, the exact opposite of the intent. |
| Wrapped the nvm lazy-loaders in `[[ -s "$NVM_DIR/nvm.sh" ]]` | Before nvm was installed, those stubs shadowed the system `node`/`npm`: each call unset itself, found no `nvm.sh`, then failed. |

Plus three additions:

- **WezTerm shell-integration hooks**, gated on `TERM_PROGRAM == "WezTerm"`
  (which does propagate into WSL). They publish `WEZTERM_PROG` and OSC 7 so tab
  titles can name the running program and the project directory — see
  [A2](#a2-weztermlua--merged-into-one-cross-platform-file). Without them a WSL
  tab reads `[wslhost.exe]`.

- **Eager `JAVA_HOME`** after the lazy `sdk()` function. SDKMAN's lazy-load means
  `java` isn't on PATH until you run `sdk` once in a session — so a shell that
  never ran `sdk` hands nvim a PATH with no SDKMAN JDK on it. `env.lua`'s
  `fix_sdkman_path()` does cover this from nvim's side (it prepends each
  candidate's `current/bin` and sets `JAVA_HOME` when unset), so this shell-side
  export is belt-and-braces rather than the only line of defence: it also fixes
  `java` for everything *else* launched from that shell. Pointing at SDKMAN's stable
  `candidates/java/current` symlink costs a `stat` instead of the ~150ms to
  source `sdkman-init.sh`, so the startup saving is kept. `sdk use` still
  overrides per-shell.
- **skillforge block commented out**, not deleted — it installs from
  `git@gitlab.thalesdigital.io`, unreachable here. The original lines are kept
  verbatim in the comment for restoration on a work machine.

Oh My Zsh was installed early on and is now **orphaned** — this config replaced
it with zinit. Nothing sources `~/.oh-my-zsh`. Backup of the pre-existing OMZ
zshrc is at `~/.zshrc.omz-backup`.

---

## Part D — git identity

Global `user.email` is the **GitHub noreply** address
(`95390298+TajBanana@users.noreply.github.com`), *not* the Thales work address —
even though 19 of this repo's existing commits use the work address. That was a
deliberate call: work and personal identities are kept apart, and public repos
should not carry the employer domain.

Set the work email **per-repository** inside work checkouts; never globally.
(The existing 19 commits are already public; changing the config only affects
new ones.)

Auth is `gh` with an OAuth token (HTTPS protocol), scopes `gist`, `read:org`,
`repo`, `workflow`.

---

## Part E — still open

State verified 2026-08-04 on `windows-config`.

**Open:**

- **The `.wezterm.lua` copy on the Windows side drifts silently.** Nothing
  automates or warns about it, and it has already gone stale once — see
  [A2](#a2-weztermlua--merged-into-one-cross-platform-file). It is in sync as of
  2026-08-09; `diff` the two after any edit to the repo file.
- **`docs/reviews/backlog_005_code_review.md`** — deferred findings from the
  2026-08-11 review. Four are High: a merge-base cache key that collapses to
  `"HEAD"` when detached, a blame guard that disables its own handler during a
  diff, a `ts_ls` root_dir override that drops upstream's Deno veto and cwd
  fallback, and POSIX-only PATH joining in `env.lua`.
- **`docs/reviews/audit_004_outstanding_findings.md` has unfixed findings.**
  Triage what is left; several are one-line changes, and the doc groups them by
  root cause so clusters can be swept together.
- **`.ideavimrc` is not symlinked** to `~/.ideavimrc`. Only matters if IntelliJ
  is run inside WSL, which it isn't here — the readme's symlink instruction is
  therefore correct but not applicable on this box.

**Closed since this document was written:**

- ~~`p10k configure` has not been run~~ — `~/.p10k.zsh` now exists (90K) and is
  sourced from `.zshrc`.
- ~~Part A's changes are uncommitted~~ — all committed, and the "which branch do
  these belong on?" question is answered: they are on `windows-config`, created
  for exactly this subject.
- ~~Undercurl does not render~~ — WezTerm nightly `20260810-043511` installed
  2026-08-11; see [Part B](#undercurl-needs-the-wezterm-nightly-on-windows).

**Confirmed set up** (checked while updating this document, so nobody re-checks):
the lazygit config symlink (`~/.config/lazygit/config.yml` →
`~/.config/nvim/lazygit/config.yml`) and the delta `include.path` entry in the
global gitconfig are both in place.
