return {
	-- mini.nvim
	{
		'echasnovski/mini.nvim',
		version = false
	},
	-- {
	-- 	'echasnovski/mini.pick',
	-- 	version = false,
	-- 	config = true,
	-- 	lazy = true,
	-- 	keys = {
	-- 		{ '<leader>ff', '<cmd>Pick files<cr>' },
	-- 		{ '<leader>fw', '<cmd>Pick grep_live<cr>' },
	-- 		{ '<leader>fb', '<cmd>Pick buffers<cr>' },
	-- 	},
	-- },
	{
		'echasnovski/mini.icons',
		version = false,
		config = true,
	},
	{
		'echasnovski/mini.starter',
		version = false,
		config = function()
			local logo = table.concat({
				'██████╗  █████╗ ███████╗███████╗██████╗ ██████╗ ',
				'██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗',
				'██████╔╝███████║███████╗█████╗  ██║  ██║██║  ██║',
				'██╔══██╗██╔══██║╚════██║██╔══╝  ██║  ██║██║  ██║',
				'██████╔╝██║  ██║███████║███████╗██████╔╝██████╔╝',
				'╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ ╚═════╝ ',
				'                                                ',
			}, '\n')

			require('mini.starter').setup({
				header = logo,
			})
		end,
	},
	-- {
	-- 	'echasnovski/mini.basics',
	-- 	version = false,
	-- 	opts = {
	-- 		mappings = {
	-- 			windows = true,
	-- 			move_with_alt = true,
	-- 		},
	-- 	},
	-- },
    -- {
    -- 	'echasnovski/mini.files',
    -- 	version = false,
    -- 	keys = function()
    -- 		local MiniFiles = require('mini.files')
    -- 
    -- 		return {
    -- 			{ '<leader>e', function() MiniFiles.open() end },
    -- 		}
    -- 	end,
    -- },
	{
		'echasnovski/mini.statusline',
		version = false,
		config = true,
	},
	-- {
	-- 	'echasnovski/mini.tabline',
	-- 	version = false,
	-- 	config = true,
	-- },
	{
		'echasnovski/mini.comment',
		version = false,
		event = "BufReadPre",
		opts = {
			mappings = {
				comment = '<leader>/',
				comment_line = '<leader>/',
				comment_visual = '<leader>/',
				textobject = '<leader>/', -- This can remain as <leader>/ or be changed as desired.
			}
		},
	},
	-- {
	-- 	'echasnovski/mini.notify',
	-- 	version = false,
	-- 	config = true,
	-- },
	{
		'echasnovski/mini.trailspace',
		version = false,
		event = "BufReadPre",
		config = true,
	},
	{
		'echasnovski/mini.diff',
		version = false,
		config = true,
	},
	{
		'echasnovski/mini.ai',
		version = false,
		config = true,
	}
}
