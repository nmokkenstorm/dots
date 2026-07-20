-- Racket language support.
--
-- LSP is racket-langserver, installed out-of-band via `raco pkg install
-- racket-langserver` (it is not a mason package). It ships with the brew
-- `racket` cask and provides hover, completion, go-to-def, and formatting.
-- The treesitter parser (racket) lives in the init.lua ensure_installed list.
--
-- Structural editing is nvim-paredit; REPL interaction is conjure over the
-- racket stdio client (<localleader>ee eval form, <localleader>eb eval buffer).

-- racket-langserver is not mason-managed, so enable it through the native
-- vim.lsp API instead of the mason-lspconfig handler block in init.lua. Done
-- once, lazily, the first time a Racket buffer is opened.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'racket',
  once = true,
  callback = function()
    require 'lspconfig' -- puts nvim-lspconfig's lsp/ configs on the runtimepath
    vim.lsp.config('racket_langserver', {
      capabilities = require('cmp_nvim_lsp').default_capabilities(),
    })
    vim.lsp.enable 'racket_langserver'
  end,
})

return {
  {
    'julienvincent/nvim-paredit',
    ft = { 'racket', 'scheme' },
    opts = {},
  },
  {
    'Olical/conjure',
    ft = { 'racket', 'scheme' },
    init = function()
      vim.g['conjure#filetype#racket'] = 'conjure.client.racket.stdio'
    end,
  },
}
