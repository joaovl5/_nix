(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add {:source :folke/noice.nvim :depends [:MunifTanjim/nui.nvim]})
(do-req :noice :setup {:views {:cmdline_popup {:border {:style :none
                                                        :padding [1 2]}
                                               :filter_options {}
                                               :win_options {:winhighlight "NormalFloat:NormalFloat,FloatBorder:FloatBorder"}}}
                       :lsp {:override {:vim.lsp.util.convert_input_to_markdown_lines true
                                        :vim.lsp.util.stylize_markdown true
                                        :cmp.entry.get_documentation true}}
                       :presets {:bottom_search true
                                 :command_palette true
                                 :long_message_to_split true
                                 :inc_rename false
                                 :lsp_doc_border false}})
