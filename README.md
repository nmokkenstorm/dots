# dots

Personal dotfiles: zsh, git, tmux, alacritty, nvim, starship, btop, and a few
homegrown tools in `bin/`.

## Install

```sh
./install.sh
```

Installs brew deps, oh-my-zsh, TPM, clones alacritty themes, and symlinks
configs into place, including `bin/` tools into `~/.local/bin`. Idempotent;
rerun after adding a tool or config.

## Neovim worktree picker

Press `<leader>gw` inside a Git repository to open the Telescope worktree and
branch picker. It shows the current and checked-out worktrees, dirty state,
upstream divergence, branch age, and the latest CI pipeline status. Press
`<C-r>` in the picker to fetch and refresh Git state.

Pipeline status loads asynchronously and supports GitHub Actions, GitLab CI,
Bitbucket Pipelines, and public Tangled Spindle pipelines. The picker uses the
`origin` remote by default. Select another remote per repository with a `.env`
file at that repository's root:

```dotenv
WORKTREE_CI_REMOTE=tangled
```

Provider credentials can be supplied in the same project-level `.env` file:

```dotenv
# GitHub, either name is accepted
GH_TOKEN=
GITHUB_TOKEN=

# GitLab
GITLAB_TOKEN=

# Bitbucket, use an access token or username with an API token/app password
BITBUCKET_ACCESS_TOKEN=
BITBUCKET_USERNAME=
BITBUCKET_API_TOKEN=
BITBUCKET_APP_PASSWORD=
```

GitHub requires an authenticated `gh` CLI, GitLab requires an authenticated
`glab` CLI, and Bitbucket and Tangled require `curl`. Tangled status currently
supports public repositories only. Provider queries time out after 10 seconds
and inspect up to 100 recent runs.

Pipeline states are shown as `✓ passed`, `✗ failed`, `● running`, `○ pending`,
`- none`, or `? unknown`. The initial `… loading` state is replaced when the
provider query finishes.

Existing shell environment variables take precedence over `.env`. Only the
listed variables are loaded, and they are passed to the provider subprocess
without changing Neovim's global environment. Missing tools, credentials, or
network access produce an unknown status without blocking the picker. Values
are read as simple dotenv literals; variable expansion is not supported. Keep
the project `.env` ignored by Git.

## Tools (bin/)

- `bar`: second tmux status row built from modules. A module publishes its
  segment into the tmux option `@bar_<name>` (daemons via `bin/bar-lib`, one-shots
  via `bar set <name> <text>`); `bar mount` builds `status-format[1]` from
  `~/.config/tmux/bar/modules`, so no `#()` runs on the row. Modules: `bar-sys`
  (statmon's samples plus cpu and battery), `bar-pr` (open PRs per repo from
  `~/.config/tmux/bar/repos`), `bar-reeds` (whisper topics waiting on a human).
- `researchmon`: tracks explicitly selected Codex research threads on the shared
  local app server. `researchmon track <thread-id>` adds a thread; `untrack`
  removes it, and `list` prints tracked IDs. Inside a Codex tool shell, the ID
  defaults to `CODEX_THREAD_ID`. The tmux bar refreshes a cached summary every
  status interval; the sampler polls every five seconds. Waiting, idle, unloaded,
  and error states are shown separately. Idle does not imply research is done.
  `researchmon sample` queries live status; `status` only reads the cache.
  The sampler starts with tmux and reports disconnected if its cache goes stale.
  It uses the existing daemon socket without starting or resuming Codex tasks.
  Override `RESEARCHMON_SOCKET` for a different Unix socket or
  `RESEARCHMON_HOME` for a different state directory. Requires Python 3 and
  a Codex daemon with the local WebSocket control interface.
- `statmon`: sampler daemon behind the tmux status bar. It writes files under
  `~/.statmon/` and the bar cats them; samplers are never forked from `#()`.
- `throb`: rainbow throbber for the tmux status bar with room for a passing
  thought (`throb -t "..."`); `prefix+T` toggles it, log in `~/.throb/`.
- `train`: merge/release train runner and curses watcher (python3 >= 3.11).
  A train is a plan of `key|label|command` steps stored under
  `~/.local/state/train/<id>/`. Step exit 0 marks it done, 75 hands it to a
  human (needs-user), anything else stalls the train; rerunning `train run`
  resumes past done steps; `train run --parallel` runs every unfinished
  step at once, for steps that wait on independent outcomes. Step stderr streams through while a tail is kept
  as the failure detail. For steps driven externally via `train mark`
  (another agent session), use `exit 75` as the placeholder command so
  `train run` hands them over instead of completing them. Marks mirror to
  the reeds whisper network on
  `train.<id>.<key>` when the daemon is reachable. The watcher's
  `--whispers [prefix]` flag splits the screen 50/50 with a live reeds feed
  (default prefix `train`, stacked instead of side-by-side on narrow
  windows). In tmux, `prefix+M` pops up that split view, which shows every
  attended incomplete train as its own section (falling back to the latest
  train when all are done, idling when there are none) and closes itself when
  the shown trains complete on its watch; `q` or `Esc` dismisses it. Attended
  means: a fresh runner heartbeat (`train run` touches one every 15s), or
  marks within 4h, stretched to 24h while a step waits on a human. A section
  whose live step has a stale heartbeat shows "runner heartbeat lost".
  Steps waiting on a human get numbered badges: press the digit to select,
  then `d` marks done or `s` skips (Esc cancels the selection); rerun
  `train run` afterwards if the runner had exited. A popup swallows all
  keys including the tmux prefix, so if one ever refuses to die, run
  `tmux display-popup -C` from any other terminal to close it.
- `glab-merge <project> <iid>`: waits for a GitLab MR to become mergeable,
  then merges it. Exits 75 on human-shaped blocks (conflicts, approvals, tag
  protection) so it slots straight into a train step. `GLAB_MERGE_TIMEOUT`
  caps the wait in seconds (default 600).

- `transcribe-call [lang] [device]`: live call transcription with whisper.cpp's
  `whisper-stream`, capturing from the `Call Capture` aggregate device (mic plus
  BlackHole) into `~/Documents/calls/<date>_<time>/transcript.txt`. Route the
  call's speaker to `Call Output` (speakers plus BlackHole) first, e.g.
  `setout dev.mokkenstorm.call-output`, and back with
  `setout BuiltInSpeakerDevice`. One-time setup: `brew install --cask
blackhole-2ch`, then `call-devices` creates both devices; whisper.cpp lives in
  `~/Developer/personal/whisper.cpp` built with `-DWHISPER_SDL2=ON` and
  `patches/whisper-cpp-multichannel.patch` (downmixes multichannel capture
  instead of reading channel one) and the `large-v3-turbo` model.

## peon-ping

`install.sh` links `.claude/hooks/peon-ping/config.json` and applies
`patches/peon-ping-*.patch` to the Homebrew `peon.sh`. `brew upgrade` overwrites
that file, so rerun `install.sh` after upgrading; it reports a patch that no
longer applies. `peon-ping-headphones.patch` makes `headphones_only` inspect
the device sounds actually play on and count only Bluetooth, USB and
headphone-named outputs, so aggregate, virtual and display outputs stay quiet.

## A train in one sitting

```sh
train new demo "release demo" <<'EOF'
685|!685 -> main|glab-merge web/app 685
tag|tag rc/demo|git push origin refs/tags/rc/demo
EOF
train run demo      # stops on fail/needs-user; rerun to resume
train watch         # curses table; q quits, exits 0 on completion
train ls
```

## Stale host routes

A VPN or filter client pins per-destination host routes to the gateway of the network it saw them on and
leaves them behind on a network change, so those addresses (Slack, more than once) fail locally. A root job
deletes static host routes whose gateway is no longer on-link on the route's interface, on every network
change and every 5 minutes, and logs each removal to `/var/log/stale-routes.log`.

```sh
sudo macos/stale-routes/install            # --remove to uninstall
STALE_ROUTES_DRY=1 macos/stale-routes/stale-routes   # show what it would delete
```

## Zscaler schedule

A root launchd job ticks every 5 minutes and switches Zscaler off in the evening
and on in the morning. It runs a root-owned copy of
`macos/zscaler-schedule/zscaler-schedule`, installed once with:

```sh
sudo macos/zscaler-schedule/install            # --remove to uninstall
```

The times and holds live in `~/.config/zscaler-schedule/config`, which the root
job reads as data, never as code, so changing them needs no sudo:

```sh
zscaler-hold                       # keep Zscaler on tonight
zscaler-hold 2026-11-20            # keep it on up to and including that day
zscaler-hold --never               # disable the switch-off (--resume undoes it)
zscaler-hold --off-at 18:30,20:00  # default 18:00,19:00,20:00,21:00
zscaler-hold --on-at 07:45         # default 08:00
zscaler-hold --on-days 1,2,3,4,5   # ISO weekdays, 1 = Monday
zscaler-hold --status
```

Each tick runs the latest slot of the day that is due and not yet done, so a
slot missed while the laptop slept runs once on wake. A hold only stops the
switch-off; once Zscaler is off, the next on slot or
`sudo /usr/local/libexec/zscaler-schedule on ~/.config/zscaler-schedule $(id -u)`
brings it back.
