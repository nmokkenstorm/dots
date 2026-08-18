local M = {}

local pipeline_icons = {
  failed = '✗',
  loading = '…',
  none = '-',
  passed = '✓',
  pending = '○',
  running = '●',
  unknown = '?',
}

local pipeline_highlights = {
  failed = 'DiagnosticError',
  loading = 'Comment',
  none = 'Comment',
  passed = 'DiagnosticOk',
  pending = 'DiagnosticWarn',
  running = 'DiagnosticInfo',
  unknown = 'Comment',
}

local dotenv_names = {
  BITBUCKET_ACCESS_TOKEN = true,
  BITBUCKET_API_TOKEN = true,
  BITBUCKET_APP_PASSWORD = true,
  BITBUCKET_USERNAME = true,
  GH_TOKEN = true,
  GITHUB_TOKEN = true,
  GITLAB_TOKEN = true,
  WORKTREE_CI_REMOTE = true,
}

local function git(args, cwd)
  local command = vim.list_extend({ 'git' }, args)
  local result = vim.system(command, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or 'Git command failed')
  end

  return result.stdout
end

local function decode_json(value)
  local ok, decoded = pcall(vim.json.decode, value)
  if not ok then
    return nil
  end

  return decoded
end

local function lower_string(value)
  if type(value) ~= 'string' then
    return nil
  end

  return value:lower()
end

local function curl_config_value(value)
  return value:gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function dotenv_credentials(repo)
  local path = repo .. '/.env'
  local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  local result = {}

  for _, line in ipairs(lines) do
    local assignment = line:gsub('^%s*export%s+', '')
    local name, value = assignment:match '^%s*([%w_]+)%s*=%s*(.-)%s*$'
    local existing = name and vim.env[name]
    if name and dotenv_names[name] and (not existing or existing == '') then
      local quote = value:sub(1, 1)
      if (quote == '"' or quote == "'") and value:sub(-1) == quote then
        value = value:sub(2, -2)
      else
        value = value:gsub('%s+#.*$', '')
      end
      result[name] = value
    end
  end

  return result
end

local function credential(credentials, name)
  local existing = vim.env[name]
  if existing and existing ~= '' then
    return existing
  end

  return credentials[name]
end

local function remote_provider(repo, settings)
  local remote = credential(settings, 'WORKTREE_CI_REMOTE') or 'origin'
  local output = git({ 'remote', 'get-url', remote }, repo)
  if not output then
    return nil
  end

  local url = vim.trim(output):gsub('%.git$', '')
  local host, path = url:match '^git@([^:]+):(.+)$'
  if not host then
    host, path = url:match '^https?://([^/]+)/(.+)$'
  end
  if not host then
    host, path = url:match '^ssh://git@([^/]+)/(.+)$'
  end
  if not host or not path then
    return nil
  end

  if host == 'github.com' then
    return { kind = 'github', repo = path }
  end

  if host == 'bitbucket.org' then
    return { kind = 'bitbucket', repo = path }
  end

  if host == 'tangled.sh' or host == 'tangled.org' then
    return { kind = 'tangled', repo = path }
  end

  if host == 'gitlab.com' or host:find('gitlab', 1, true) then
    return { kind = 'gitlab', repo = url }
  end

  return nil
end

local function normalize_pipeline_status(status, conclusion)
  local value = (conclusion and conclusion ~= '') and conclusion or status
  local statuses = {
    action_required = 'failed',
    canceled = 'failed',
    cancelled = 'failed',
    completed = 'passed',
    created = 'pending',
    error = 'failed',
    failed = 'failed',
    failure = 'failed',
    in_progress = 'running',
    manual = 'pending',
    neutral = 'passed',
    paused = 'pending',
    pending = 'pending',
    preparing = 'pending',
    queued = 'pending',
    requested = 'pending',
    running = 'running',
    skipped = 'passed',
    stale = 'failed',
    stopped = 'failed',
    success = 'passed',
    successful = 'passed',
    timed_out = 'failed',
    waiting = 'pending',
    waiting_for_resource = 'pending',
  }

  return statuses[value] or 'unknown'
end

local function pipeline_command(provider, credentials)
  if provider.kind == 'github' then
    return {
      'gh',
      'run',
      'list',
      '--repo',
      provider.repo,
      '--limit',
      '100',
      '--json',
      'headBranch,status,conclusion,createdAt',
    }
  end

  if provider.kind == 'gitlab' then
    return { 'glab', 'ci', 'list', '--repo', provider.repo, '--per-page', '100', '--output', 'json' }
  end

  local endpoint
  if provider.kind == 'bitbucket' then
    endpoint = 'https://api.bitbucket.org/2.0/repositories/' .. provider.repo .. '/pipelines/?pagelen=100&sort=-created_on'
  else
    endpoint = 'https://tangled.org/' .. provider.repo .. '/pipelines?trigger=push'
  end
  local config = table.concat({ 'url = "' .. curl_config_value(endpoint) .. '"', 'fail', 'silent', 'show-error' }, '\n')

  if provider.kind == 'tangled' then
    return { 'curl', '--config', '-' }, config
  end

  local access_token = credential(credentials, 'BITBUCKET_ACCESS_TOKEN')
  if access_token and access_token ~= '' then
    local authorization = curl_config_value('Authorization: Bearer ' .. access_token)
    return { 'curl', '--config', '-' }, config .. '\nheader = "' .. authorization .. '"'
  end

  local username = credential(credentials, 'BITBUCKET_USERNAME')
  local api_token = credential(credentials, 'BITBUCKET_API_TOKEN') or credential(credentials, 'BITBUCKET_APP_PASSWORD')
  if username and username ~= '' and api_token and api_token ~= '' then
    local credentials = curl_config_value(username .. ':' .. api_token)
    return { 'curl', '--config', '-' }, config .. '\nuser = "' .. credentials .. '"'
  end

  return nil
end

local function parse_tangled_pipelines(output)
  local card_start = '<div class="relative rounded drop%-shadow%-sm'
  local cards = output .. '\n  <div class="relative rounded drop-shadow-sm'
  local result = {}

  for card in cards:gmatch('(' .. card_start .. '.-)\n  ' .. card_start) do
    local branch = card:match 'Push to</span>%s*<span class="font%-semibold[^>]*>([^<]+)</span>'
    if branch and not result[branch] then
      local status = 'unknown'
      for workflow_status in card:gmatch '<span class="font%-bold">([^<]+)</span>' do
        local normalized = normalize_pipeline_status(lower_string(workflow_status))
        if normalized == 'failed' then
          status = 'failed'
          break
        end
        if normalized == 'running' or (normalized == 'pending' and status ~= 'running') then
          status = normalized
        elseif normalized == 'passed' and status == 'unknown' then
          status = 'passed'
        end
      end
      result[branch] = status
    end
  end

  return result
end

local function parse_pipelines(provider, output)
  if provider.kind == 'tangled' then
    return parse_tangled_pipelines(output)
  end

  local decoded = decode_json(output)
  if not decoded then
    return nil
  end

  local pipelines = provider.kind == 'bitbucket' and decoded.values or decoded
  if type(pipelines) ~= 'table' then
    return nil
  end

  local result = {}
  for _, pipeline in ipairs(pipelines) do
    local branch
    local status
    local conclusion

    if provider.kind == 'github' then
      branch = pipeline.headBranch
      status = pipeline.status
      conclusion = pipeline.conclusion
    elseif provider.kind == 'gitlab' then
      branch = pipeline.ref
      status = pipeline.status
    else
      branch = pipeline.target and pipeline.target.ref_name
      status = pipeline.state and pipeline.state.name
      conclusion = pipeline.state and pipeline.state.result and pipeline.state.result.name
    end

    if branch and not result[branch] then
      result[branch] = normalize_pipeline_status(lower_string(status), lower_string(conclusion))
    end
  end

  return result
end

local function fetch_pipelines(repo, callback)
  local credentials = dotenv_credentials(repo)
  local provider = remote_provider(repo, credentials)
  if not provider then
    callback(nil)
    return
  end

  local command, stdin = pipeline_command(provider, credentials)
  if not command or vim.fn.executable(command[1]) ~= 1 then
    callback(nil)
    return
  end

  vim.system(command, { cwd = repo, text = true, timeout = 10000, stdin = stdin, env = credentials }, function(process)
    vim.schedule(function()
      if process.code ~= 0 then
        callback(nil)
        return
      end

      callback(parse_pipelines(provider, process.stdout))
    end)
  end)
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
    worktree.pipeline = 'loading'
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
      pipeline = 'loading',
      worktree = checked_out[branch.name],
    })
  end

  return result
end

local function entry_display(item, displayer)
  local selected = item.current and '●' or ' '
  local kind = item.kind == 'worktree' and 'WT' or 'BR'
  local state = item.kind == 'worktree' and (item.dirty and '*' or '✓') or ' '
  local location = item.kind == 'worktree' and item.path or (item.worktree and '@ ' .. item.worktree.path or '')
  local pipeline = item.pipeline or 'unknown'
  local freshness_highlight = item.freshness:find('↓', 1, true) and 'DiagnosticWarn' or 'DiagnosticInfo'

  return displayer {
    { string.format('%s ', selected), item.current and 'DiagnosticInfo' or 'Comment' },
    { string.format('%-2s ', kind), item.kind == 'worktree' and 'Type' or 'Identifier' },
    { string.format('%s  ', state), item.dirty and 'DiagnosticWarn' or 'DiagnosticOk' },
    { string.format('%-28s  ', item.name), item.current and 'TelescopeSelection' or 'Normal' },
    { string.format('%-7s  ', item.freshness), freshness_highlight },
    { string.format('%-5s  ', item.age), 'Comment' },
    { string.format('%s %-8s  ', pipeline_icons[pipeline], pipeline), pipeline_highlights[pipeline] },
    { location, 'Directory' },
  }
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
  local displayer = require('telescope.pickers.entry_display').create {
    separator = '',
    items = {
      { width = 2 },
      { width = 3 },
      { width = 3 },
      { width = 30 },
      { width = 9 },
      { width = 7 },
      { width = 12 },
      { remaining = true },
    },
  }

  local picker
  picker = pickers.new(require('telescope.themes').get_dropdown { width = 0.95, previewer = false }, {
    prompt_title = 'Worktrees and branches  [<C-r> fetch]  CI: ✓ pass  ✗ fail  ● run',
    finder = finders.new_table {
      results = picker_entries,
      entry_maker = function(item)
        return {
          value = item,
          display = function()
            return entry_display(item, displayer)
          end,
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
  picker:find()

  fetch_pipelines(repo, function(pipelines)
    if not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
      return
    end

    for _, item in ipairs(picker_entries) do
      item.pipeline = pipelines and (pipelines[item.name] or 'none') or 'unknown'
    end
    picker:refresh(picker.finder, { reset_prompt = false })
  end)
end

return M
