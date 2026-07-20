-- F# language support.
--
-- LSP is fsautocomplete, driven through Neovim's native vim.lsp so it attaches
-- asynchronously: the editor stays responsive while fsac loads the project (the
-- heavy first-load that froze the UI under Ionide-vim's synchronous project
-- init). Installed as a global dotnet tool (`dotnet tool install --global
-- fsautocomplete`), not a mason package. Treesitter parser (fsharp) is in the
-- init.lua ensure_installed list.
--
-- Tradeoff vs Ionide-vim: no built-in FSI REPL. Use a terminal with `dotnet fsi`.

-- Ionide-vim handled .fs filetype detection; without it, map the F# extensions
-- explicitly so the FileType autocmd below (and treesitter) fire reliably.
vim.filetype.add {
  extension = {
    fs = 'fsharp',
    fsx = 'fsharp',
    fsi = 'fsharp',
  },
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'fsharp',
  once = true,
  callback = function()
    require 'lspconfig' -- puts nvim-lspconfig's lsp/ configs on the runtimepath
    vim.lsp.config('fsautocomplete', {
      -- Absolute path: fsac resolves regardless of how nvim's PATH was set up.
      cmd = {
        vim.fn.expand '~/.dotnet/tools/fsautocomplete',
        '--adaptive-lsp-server-enabled',
      },
      capabilities = require('cmp_nvim_lsp').default_capabilities(),
      on_attach = function(client, _bufnr)
        -- fsautocomplete's semantic tokens over a heavy project (the ASP.NET
        -- shared framework plus a dozen packages) stall the UI thread for
        -- seconds on first display. Treesitter does the highlighting; drop the
        -- LSP token layer so opening a .fs file stays snappy.
        client.server_capabilities.semanticTokensProvider = nil
      end,
    })
    vim.lsp.enable 'fsautocomplete'
  end,
})

return {}
