local M = {}

local function git(args, cwd)
  local command = vim.list_extend({ 'git' }, args)
  local result = vim.system(command, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or 'Git command failed')
  end

  return result.stdout
end

local function relative_age(timestamp)
  local elapsed = math.max(0, os.time() - timestamp)
  local units = {
    { seconds = 31 * 24 * 60 * 60, suffix = 'mo' },
    { seconds = 7 * 24 * 60 * 60, suffix = 'w' },
    { seconds = 24 * 60 * 60, suffix = 'd' },
    { seconds = 60 * 60, suffix = 'h' },
    { seconds = 60, suffix = 'm' },
  }

  for _, unit in ipairs(units) do
    if elapsed >= unit.seconds then
      return string.format('%d%s', math.floor(elapsed / unit.seconds), unit.suffix)
    end
  end

  return 'now'
end

local function upstream_indicator(upstream, track)
  if upstream == '' then
    return '?'
  end

  if track == '' then
    return '='
  end

  local ahead = track:match 'ahead (%d+)'
  local behind = track:match 'behind (%d+)'

  if ahead and behind then
    return string.format('↑%s↓%s', ahead, behind)
  end

  if ahead then
    return '↑' .. ahead
  end

  if behind then
    return '↓' .. behind
  end

  return track:gsub('^%[', ''):gsub('%]$', '')
end

local function branches(repo)
  local format = table.concat({ '%(refname:short)', '%(upstream:short)', '%(upstream:track)', '%(committerdate:unix)' }, '%09')
  local output, err = git({ 'for-each-ref', '--sort=-committerdate', '--format=' .. format, 'refs/heads' }, repo)
  if not output then
    return nil, err
  end

  local result = {}
  for line in output:gmatch '[^\n]+' do
    local name, upstream, track, timestamp = line:match '^([^\t]+)\t([^\t]*)\t([^\t]*)\t(%d+)$'
    if name then
      table.insert(result, {
        name = name,
        upstream = upstream,
        freshness = upstream_indicator(upstream, track),
        age = relative_age(tonumber(timestamp)),
        timestamp = tonumber(timestamp),
      })
    end
  end

  return result
end

local function worktrees(repo)
  local output, err = git({ 'worktree', 'list', '--porcelain' }, repo)
  if not output then
    return nil, err
  end

  local result = {}
  local current
  for line in (output .. '\n'):gmatch '(.-)\n' do
    local key, value = line:match '^(%S+)%s*(.*)$'
    if key == 'worktree' then
      current = { kind = 'worktree', path = value }
    elseif current and key == 'HEAD' then
      current.head = value
    elseif current and key == 'branch' then
      current.branch = value:gsub('^refs/heads/', '')
    elseif current and key == 'detached' then
      current.detached = true
    elseif current and line == '' then
      table.insert(result, current)
      current = nil
    end
  end

  return result
end

local function entries(repo)
  local branch_list, branch_err = branches(repo)
  local worktree_list, worktree_err = worktrees(repo)
  if not branch_list or not worktree_list then
    return nil, branch_err or worktree_err
  end

  local branch_by_name = {}
  for _, branch in ipairs(branch_list) do
    branch_by_name[branch.name] = branch
  end

  local current_root = vim.fs.normalize(repo)
  local checked_out = {}
  local result = {}

  for _, worktree in ipairs(worktree_list) do
    local branch = branch_by_name[worktree.branch]
    local status = git({ 'status', '--porcelain', '--untracked-files=normal' }, worktree.path)
    worktree.current = vim.fs.normalize(worktree.path) == current_root
    worktree.dirty = status ~= nil and status ~= ''
    worktree.name = worktree.branch or ('detached@' .. (worktree.head or ''):sub(1, 8))
    worktree.freshness = branch and branch.freshness or '-'
    worktree.age = branch and branch.age or '-'
    checked_out[worktree.name] = worktree
    table.insert(result, worktree)
  end

  for _, branch in ipairs(branch_list) do
    table.insert(result, {
      kind = 'branch',
      name = branch.name,
      upstream = branch.upstream,
      freshness = branch.freshness,
      age = branch.age,
      timestamp = branch.timestamp,
      worktree = checked_out[branch.name],
    })
  end

  return result
end

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = 'Git worktrees' })
end

local function change_directory(path)
  vim.cmd.tcd(vim.fn.fnameescape(path))
  vim.notify('Working directory: ' .. path, vim.log.levels.INFO, { title = 'Git worktrees' })
end

function M.open()
  local repo, repo_err = git({ 'rev-parse', '--show-toplevel' }, vim.uv.cwd())
  if not repo then
    notify_error(repo_err)
    return
  end
  repo = vim.trim(repo)

  local picker_entries, entries_err = entries(repo)
  if not picker_entries then
    notify_error(entries_err)
    return
  end

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local config = require('telescope.config').values

  pickers
    .new(require('telescope.themes').get_dropdown { width = 0.9, previewer = false }, {
      prompt_title = 'Worktrees and branches  [<C-r> fetch]',
      finder = finders.new_table {
        results = picker_entries,
        entry_maker = function(item)
          local selected = item.current and '●' or ' '
          local kind = item.kind == 'worktree' and 'WT' or 'BR'
          local state = item.kind == 'worktree' and (item.dirty and '*' or '✓') or ' '
          local location = item.kind == 'worktree' and item.path or (item.worktree and '@ ' .. item.worktree.path or '')
          local display = string.format('%s %-2s %s  %-28s  %-7s  %-5s  %s', selected, kind, state, item.name, item.freshness, item.age, location)

          return {
            value = item,
            display = display,
            ordinal = table.concat({ item.name, item.path or '', item.upstream or '' }, ' '),
          }
        end,
      },
      sorter = config.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection then
            return
          end

          local item = selection.value
          if item.kind == 'worktree' then
            change_directory(item.path)
            return
          end

          if item.worktree then
            change_directory(item.worktree.path)
            return
          end

          local _, switch_err = git({ 'switch', item.name }, repo)
          if switch_err then
            notify_error(switch_err)
            return
          end

          vim.cmd 'checktime'
          vim.notify('Switched to branch ' .. item.name, vim.log.levels.INFO, { title = 'Git worktrees' })
        end)

        local refresh = function()
          actions.close(prompt_bufnr)
          vim.notify('Fetching remotes...', vim.log.levels.INFO, { title = 'Git worktrees' })
          vim.system({ 'git', 'fetch', '--all', '--prune' }, { cwd = repo, text = true }, function(result)
            vim.schedule(function()
              if result.code ~= 0 then
                notify_error(vim.trim(result.stderr or 'Fetch failed'))
                return
              end

              M.open()
            end)
          end)
        end

        map('i', '<C-r>', refresh)
        map('n', '<C-r>', refresh)
        return true
      end,
    })
    :find()
end

return M
