(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :folke/noice.nvim
        {:dependencies [:MunifTanjim/nui.nvim]
         :opts {:views {:cmdline_popup {:border {:style :none
                                                 :padding [1 1]
                                                 :position {:row 19 :col "60%"}}
                                        :filter_options {}
                                        :win_options {:winhighlight "NormalFloat:NormalFloat,FloatBorder:FloatBorder"}}
                        :popupmenu {:relative :editor
                                    :position {:row 19 :col "50%"}
                                    :size {:width 60 :height 10}
                                    :border {:style :solid :padding [0 1]}
                                    :win_options {:winhighlight {:Normal :Normal
                                                                 :FloatBorder :DiagnosticInfo}}}}
                :lsp {:override {:vim.lsp.util.convert_input_to_markdown_lines true
                                 :vim.lsp.util.stylize_markdown true
                                 :cmp.entry.get_documentation true}}
                :cmdline {:enabled true :view :cmdline_popup}
                :presets {:bottom_search true
                          :command_palette false
                          :long_message_to_split true
                          :inc_rename false
                          :lsp_doc_border false}}})
