-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'coder/claudecode.nvim',
    config = function()
      require('claudecode').setup {
        keymaps = {
          toggle_chat = '<leader>ac',
          send_selection = '<leader>as',
        },
      }
    end,
  },
}
