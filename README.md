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

## Tools (bin/)

- `statmon`: sampler daemon behind the tmux status bar. It writes files under
  `~/.statmon/` and the bar cats them; samplers are never forked from `#()`.
- `throb`: rainbow throbber for the tmux status bar with room for a passing
  thought (`throb -t "..."`); `prefix+T` toggles it, log in `~/.throb/`.
- `train`: merge/release train runner and curses watcher (python3 >= 3.11).
  A train is a plan of `key|label|command` steps stored under
  `~/.local/state/train/<id>/`. Step exit 0 marks it done, 75 hands it to a
  human (needs-user), anything else stalls the train; rerunning `train run`
  resumes past done steps. Step stderr streams through while a tail is kept
  as the failure detail. For steps driven externally via `train mark`
  (another agent session), use `exit 75` as the placeholder command so
  `train run` hands them over instead of completing them. Marks mirror to
  the reeds whisper network on
  `train.<id>.<key>` when the daemon is reachable. The watcher's
  `--whispers [prefix]` flag splits the screen 50/50 with a live reeds feed
  (default prefix `train`, stacked instead of side-by-side on narrow
  windows). In tmux, `prefix+M` pops up that split view, which shows every
  incomplete train as its own section (falling back to the latest train when
  all are done, idling when there are none) and closes itself when the shown
  trains complete on its watch; `q` or `Esc` dismisses it. A popup swallows all
  keys including the tmux prefix, so if one ever refuses to die, run
  `tmux display-popup -C` from any other terminal to close it.
- `glab-merge <project> <iid>`: waits for a GitLab MR to become mergeable,
  then merges it. Exits 75 on human-shaped blocks (conflicts, approvals, tag
  protection) so it slots straight into a train step. `GLAB_MERGE_TIMEOUT`
  caps the wait in seconds (default 600).

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
