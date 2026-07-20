-- C# / .NET language support.
--
-- LSP is roslyn.nvim, which drives Microsoft.CodeAnalysis.LanguageServer (the
-- same Roslyn engine as VS Code's C# Dev Kit) instead of the older OmniSharp.
-- The server binary, the csharpier formatter, and netcoredbg are installed via
-- mason (see the ensure_installed lists in init.lua / kickstart.plugins.debug).
-- Formatting (csharpier) is wired through conform in init.lua; treesitter
-- parsers (c_sharp, xml) are in the init.lua ensure_installed list.

return {
  {
    'seblyng/roslyn.nvim',
    ft = 'cs',
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
    config = function(_, opts)
      require('roslyn').setup(opts)
      -- Advertise nvim-cmp completion capabilities to the Roslyn server
      -- (Neovim 0.11 native LSP config; roslyn.nvim registers vim.lsp.config.roslyn).
      vim.lsp.config('roslyn', {
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
      })
    end,
  },
}
