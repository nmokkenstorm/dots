-- Copilot-style inline (ghost-text) completion via minuet-ai.nvim.
--
-- Backend is a local code model on the DGX Spark exposed over an
-- OpenAI-compatible FIM endpoint (fill-in-the-middle: the model sees code on
-- both sides of the cursor). FIM-capable code models (Qwen2.5-Coder, Codestral,
-- DeepSeek-Coder, StarCoder2) are the right tool here, not chat models like
-- Claude: low latency, free per token, and they understand suffix context.
-- Chat/agentic work stays in claudecode.nvim (see init.lua).
--
-- Connection is env-configurable so this file needs no editing per machine:
--   MINUET_HOST   tailscale host / ip of the spark  (default: dgx-riotbyte)
--   MINUET_PORT   serving port                       (default: 8080, llama.cpp)
--   MINUET_MODEL  served model id                    (default: qwen-coder-32b)
--
-- Graceful degradation when the spark / tailscale / internet is down: requests
-- are async with a 2s timeout and notifications are off, so a dead endpoint
-- never blocks typing or spams errors. A 1s curl probe of /health runs every
-- 15s and toggles inline completion off while the server is down or its model
-- is unloaded/crashed (non-200), back on once it reports healthy again.

local host = vim.env.MINUET_HOST or 'dgx-riotbyte'
local port = vim.env.MINUET_PORT or '8080'
local model = vim.env.MINUET_MODEL or 'qwen-coder-32b'
local base_url = ('http://%s:%s'):format(host, port)

return {
  {
    'milanglacier/minuet-ai.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = 'InsertEnter',
    config = function()
      require('minuet').setup {
        provider = 'openai_fim_compatible',
        request_timeout = 3,
        throttle = 1000,
        debounce = 150,
        notify = false,
        provider_options = {
          openai_fim_compatible = {
            -- Local server needs no real key; minuet reads the *name* of an env
            -- var, so point it at TERM (always set) as a harmless dummy.
            api_key = 'TERM',
            name = 'DGX',
            end_point = base_url .. '/v1/completions',
            model = model,
            optional = {
              max_tokens = 256,
              top_p = 0.9,
            },
          },
        },
        virtualtext = {
          auto_trigger_ft = { '*' },
          keymap = {
            accept = false, -- handled by the <Tab> mapping below (fallthrough-aware)
            accept_line = '<A-l>',
            accept_n_lines = '<A-z>',
            prev = '<A-[>',
            next = '<A-]>',
            dismiss = '<A-e>',
          },
          show_on_completion_menu = false,
        },
      }

      -- Accept on <Tab> when ghost text is showing, otherwise fall through to a
      -- normal Tab. Sidesteps the macOS/Alacritty Option-as-Alt issue and keeps
      -- the Copilot muscle memory.
      local vt = require 'minuet.virtualtext'
      vim.keymap.set('i', '<Tab>', function()
        if vt.action.is_visible() then
          vt.action.accept()
          return
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
      end, { desc = 'minuet: accept suggestion or insert Tab' })

      -- Reachability watcher: keep inline completion off unless the spark
      -- answers, so an offline machine is silent rather than erroring.
      local state = { up = nil }

      local function set_status(up)
        if up == state.up then
          return
        end
        local first = state.up == nil
        state.up = up
        pcall(vim.cmd, up and 'Minuet virtualtext enable' or 'Minuet virtualtext disable')
        if first then
          return
        end
        vim.notify(
          up and '[minuet] DGX reachable: inline completion ON' or '[minuet] DGX unreachable: inline completion OFF',
          up and vim.log.levels.INFO or vim.log.levels.WARN
        )
      end

      -- Probe /health, not just the socket: llama.cpp answers 200 only when a
      -- model is loaded, 503 while loading/crashed (e.g. an OOM), so a wedged
      -- server flips completion off too instead of failing silently.
      local function check()
        vim.system(
          { 'curl', '-sS', '-o', '/dev/null', '-m', '1', '-w', '%{http_code}', base_url .. '/health' },
          { text = true },
          vim.schedule_wrap(function(res)
            set_status(res.code == 0 and vim.trim(res.stdout or '') == '200')
          end)
        )
      end

      vim.defer_fn(check, 500)
      local timer = vim.uv.new_timer()
      timer:start(15000, 15000, vim.schedule_wrap(check))
    end,
  },
}
