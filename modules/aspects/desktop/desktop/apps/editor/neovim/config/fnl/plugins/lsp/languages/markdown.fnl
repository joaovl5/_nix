(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)

(let [fts [:markdown
           :codecompanion]]
  [; adijad
   ; (plugin :satozawa/graft.nvim {:ft fts :opts {}})
   (p! :joaovl5/follow-md-links.nvim
       (lazy false))
   (plugin :MeanderingProgrammer/render-markdown.nvim
           {:dependencies [:nvim-treesitter/nvim-treesitter
                           :nvim-mini/mini.nvim]
            :ft fts
            :opts {:completions {:lsp {:enabled true}}
                   :file_types fts
                   :overrides {:buftype {"" {:enabled false}}}
                   :render_modes [:n]
                   :debounce 50
                   :preset :none
                   :restart_highlighter true
                   :code {:sign false
                          :border :hide}
                   :pipe_table {:enabled false
                                :preset :none
                                :cell :trimmed
                                :padding 0
                                :border_enabled false}
                   :heading {:setext true
                             :atx true
                             :border true
                             :border_virtual true
                             :above "▁"
                             :below "▔"
                             :border_prefix true
                             :backgrounds [:RenderMarkdownH2Bg
                                           :RenderMarkdownH3Bg
                                           :RenderMarkdownH4Bg
                                           :RenderMarkdownH5Bg
                                           :RenderMarkdownH6Bg]}
                   :indent {:enabled true
                            :per_level 2
                            :skip_heading false}}})
   (plugin :tadmccorkle/markdown.nvim
           {:event :VeryLazy
            :opts {:mappings {:link_add :-a
                              :link_follow :-f
                              :inline_surround_toggle :-s
                              :inline_surround_toggle_line :-S
                              :go_curr_heading :-k
                              :go_parent_heading :-K
                              :go_next_heading :-h
                              :go_prev_heading :-l}}})])
