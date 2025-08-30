-- Alternative: Replace mini.pairs with nvim-autopairs
-- Add this to a new file or replace the mini.pairs section

return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  dependencies = { "hrsh7th/nvim-cmp" },
  config = function()
    local autopairs = require("nvim-autopairs")
    local cmp = require("cmp")
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")

    autopairs.setup({
      check_ts = true, -- treesitter integration
      ts_config = {
        lua = { "string", "source" },
        javascript = { "string", "template_string" },
        java = false,
      },
      disable_filetype = { "TelescopePrompt", "spectre_panel" },
      fast_wrap = {
        map = "<M-e>",
        chars = { "{", "[", "(", '"', "'" },
        pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
        offset = 0,
        end_key = "$",
        keys = "qwertyuiopzxcvbnmasdfghjkl",
        check_comma = true,
        highlight = "PmenuSel",
        highlight_grey = "LineNr",
      },
    })

    -- Integration with nvim-cmp
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

    -- Better CR (Enter) behavior
    local Rule = require("nvim-autopairs.rule")
    local npairs = require("nvim-autopairs")

    -- Add spaces inside curly braces for some languages
    npairs.add_rules({
      Rule(" ", " "):with_pair(function(opts)
        local pair = opts.line:sub(opts.col - 1, opts.col)
        return vim.tbl_contains({ "()", "[]", "{}" }, pair)
      end),
      Rule("( ", " )")
        :with_pair(function() return false end)
        :with_move(function(opts) return opts.prev_char:match(".%)") ~= nil end)
        :use_key(")"),
      Rule("{ ", " }")
        :with_pair(function() return false end)
        :with_move(function(opts) return opts.prev_char:match(".%}") ~= nil end)
        :use_key("}"),
      Rule("[ ", " ]")
        :with_pair(function() return false end)
        :with_move(function(opts) return opts.prev_char:match(".%]") ~= nil end)
        :use_key("]"),
    })
  end,
}
