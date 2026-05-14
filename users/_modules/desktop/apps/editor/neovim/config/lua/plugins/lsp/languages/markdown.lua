-- [nfnl] fnl/plugins/lsp/languages/markdown.fnl
local fts = { "markdown", "codecompanion" }
return {
  { "satozawa/graft.nvim", ft = fts, opts = {} },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.nvim",
    },
    ft = fts,
    opts = {
      completions = { lsp = { enabled = true } },
      render_modes = { "n", "i", "c", "t" },
      debounce = 50,
      preset = "obsidian",
      restart_highlighter = true,
      code = { border = "hide", sign = false },
      pipe_table = {
        preset = "none",
        cell = "trimmed",
        padding = 0,
        border_enabled = false,
        enabled = false,
      },
      heading = {
        setext = true,
        atx = true,
        border = true,
        border_virtual = true,
        above = "\226\150\129",
        below = "\226\150\148",
        border_prefix = true,
        backgrounds = {
          "RenderMarkdownH2Bg",
          "RenderMarkdownH3Bg",
          "RenderMarkdownH4Bg",
          "RenderMarkdownH5Bg",
          "RenderMarkdownH6Bg",
        },
      },
      indent = { enabled = true, per_level = 2, skip_heading = false },
    },
  },
  {
    "tadmccorkle/markdown.nvim",
    event = "VeryLazy",
    opts = {
      mappings = {
        link_add = "-a",
        link_follow = "-f",
        inline_surround_toggle = "-s",
        inline_surround_toggle_line = "-S",
        go_curr_heading = "-k",
        go_parent_heading = "-K",
        go_next_heading = "-h",
        go_prev_heading = "-l",
      },
    },
  },
}
