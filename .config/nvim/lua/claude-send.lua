--- claude-send.lua
--- Send visual selections to Claude Code via file + clipboard.
---
--- Usage:
---   :'<,'>ClaudeSend [prompt]
---
--- Writes selection to .claude/buffers/{normalized-prompt}.{ext} and copies
--- "{prompt}\n\n@{absolute-path}" to clipboard for pasting into Claude.

local M = {}

--- Directory where buffer files are stored (relative to git root)
M.buffer_dir = '.claude/buffers'

--- Track whether we've warned about missing git repo
local warned_no_git = false

--- Get git repository root, or nil if not in a repo
--- @return string|nil Git root path or nil
local function get_git_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error == 0 and result[1] then
    return result[1]
  end
  return nil
end

--- Get base directory for buffer files (git root or cwd fallback)
--- Warns once if falling back to cwd
--- @return string Base directory path
local function get_base_dir()
  local git_root = get_git_root()
  if git_root then
    return git_root
  end
  if not warned_no_git then
    warned_no_git = true
    vim.notify('ClaudeSend: not in a git repo, using cwd', vim.log.levels.WARN)
  end
  return vim.fn.getcwd()
end

--- Maps filetype to file extension
local ext_map = {
  typescript = 'ts',
  javascript = 'js',
  typescriptreact = 'tsx',
  javascriptreact = 'jsx',
  lua = 'lua',
  python = 'py',
  rust = 'rs',
  go = 'go',
  ruby = 'rb',
  php = 'php',
  java = 'java',
  c = 'c',
  cpp = 'cpp',
  css = 'css',
  html = 'html',
  json = 'json',
  yaml = 'yml',
  markdown = 'md',
  sql = 'sql',
  sh = 'sh',
  bash = 'sh',
}

--- Maps filetype to comment prefix
local comment_map = {
  typescript = '//',
  javascript = '//',
  typescriptreact = '//',
  javascriptreact = '//',
  lua = '--',
  python = '#',
  rust = '//',
  go = '//',
  ruby = '#',
  php = '//',
  java = '//',
  c = '//',
  cpp = '//',
  css = '/*',
  html = '<!--',
  json = '//',
  yaml = '#',
  markdown = '<!--',
  sql = '--',
  sh = '#',
  bash = '#',
}

--- Get file extension from current buffer's filetype
local function get_extension()
  local ft = vim.bo.filetype
  return ext_map[ft] or ft or 'txt'
end

--- Get comment prefix for current buffer's filetype
local function get_comment_prefix()
  local ft = vim.bo.filetype
  return comment_map[ft] or '#'
end

--- Get comment suffix (for languages that need closing comments)
local function get_comment_suffix()
  local ft = vim.bo.filetype
  local suffix_map = {
    css = ' */',
    html = ' -->',
    markdown = ' -->',
  }
  return suffix_map[ft] or ''
end

--- Normalize prompt to a valid filename (alphanumeric + dashes)
--- @param prompt string The prompt to normalize
--- @return string Normalized filename (without extension)
local function normalize_prompt(prompt)
  return prompt
    :lower()
    :gsub('[^%w%s-]', '') -- remove non-alphanumeric except spaces/dashes
    :gsub('%s+', '-') -- spaces to dashes
    :gsub('%-+', '-') -- collapse multiple dashes
    :gsub('^%-', '') -- trim leading dash
    :gsub('%-$', '') -- trim trailing dash
    :sub(1, 50) -- cap at 50 chars
end

--- Ensure buffer directory exists and has a .gitignore
--- @return string The absolute path to the buffer directory
local function ensure_dir()
  local dir = get_base_dir() .. '/' .. M.buffer_dir
  vim.fn.mkdir(dir, 'p')

  -- Auto-create .gitignore to exclude all buffer files
  local gitignore = dir .. '/.gitignore'
  if vim.fn.filereadable(gitignore) == 0 then
    vim.fn.writefile({ '*' }, gitignore)
  end

  return dir
end

--- Get the current visual selection and source info
--- @return string code The selected code
--- @return number start_line Starting line number
--- @return number end_line Ending line number
local function get_selection()
  local start_pos = vim.fn.getpos "'<"
  local end_pos = vim.fn.getpos "'>"
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local lines = vim.fn.getline(start_line, end_line)

  -- Handle single-line selection (getline returns string instead of table)
  if type(lines) == 'string' then
    lines = { lines }
  end

  return table.concat(lines, '\n'), start_line, end_line
end

--- Get the source file path relative to git root (or cwd)
--- @return string Relative path to source file
local function get_source_path()
  local abs_path = vim.fn.expand '%:p'
  local base = get_base_dir()
  -- Make path relative to base if possible
  if abs_path:sub(1, #base) == base then
    return abs_path:sub(#base + 2) -- +2 to skip the trailing slash
  end
  return abs_path
end

--- Format source reference string
--- @param start_line number Starting line
--- @param end_line number Ending line
--- @return string Source reference (e.g., "src/foo.ts:42-58")
local function format_source_ref(start_line, end_line)
  local path = get_source_path()
  if start_line == end_line then
    return path .. ':' .. start_line
  end
  return path .. ':' .. start_line .. '-' .. end_line
end

--- Copy text to system clipboard
local function copy_to_clipboard(text)
  vim.fn.setreg('+', text)
end

--- Core function: write selection to file and copy prompt+path to clipboard
--- Filename is derived from the prompt (normalized). Overwrites existing files.
--- Includes source file path and line numbers in both file and clipboard.
--- @param prompt string The prompt/question to attach
local function send(prompt)
  local dir = ensure_dir()
  local ext = get_extension()
  local name = normalize_prompt(prompt)
  local filename = name .. '.' .. ext
  local filepath = dir .. '/' .. filename
  local abs_path = vim.fn.fnamemodify(filepath, ':p')

  -- Get selection with line info
  local code, start_line, end_line = get_selection()
  local source_ref = format_source_ref(start_line, end_line)

  -- Build source comment for the file
  local comment_prefix = get_comment_prefix()
  local comment_suffix = get_comment_suffix()
  local source_comment = comment_prefix .. ' Source: ' .. source_ref .. comment_suffix

  -- Write selection to file with source header (overwrites if exists)
  local file_content = source_comment .. '\n' .. code
  vim.fn.writefile(vim.split(file_content, '\n'), filepath)

  -- Format clipboard: prompt, source reference, then @path
  local clipboard = prompt .. '\n\nSource: ' .. source_ref .. '\n\n@' .. abs_path
  copy_to_clipboard(clipboard)

  -- Brief feedback that auto-dismisses
  vim.cmd('redraw')
  print('Claude: ' .. filename)
end

--- Prompt user for input, then send
local function prompt_and_send()
  vim.ui.input({ prompt = 'Claude prompt: ' }, function(input)
    if not input or input == '' then
      return
    end
    -- Defer to let the input window close first
    vim.schedule(function()
      send(input)
    end)
  end)
end

--- Command handler for :ClaudeSend [prompt]
--- If prompt is provided as argument, uses it directly.
--- Otherwise, opens a popup to ask for prompt.
function M.claude_send(opts)
  local prompt = opts.args ~= '' and opts.args or nil
  if prompt then
    send(prompt)
  else
    prompt_and_send()
  end
end

--- Setup function: creates the user command
function M.setup()
  vim.api.nvim_create_user_command('ClaudeSend', M.claude_send, { range = true, nargs = '*' })
end

return M
