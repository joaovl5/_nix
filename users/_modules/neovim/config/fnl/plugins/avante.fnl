(import-macros {: plugin : key} :./lib/init-macros)

(let [img-clip (plugin :HakonHarnes/img-clip.nvim
                       {:event :VeryLazy
                        :opts {:default {:embed_image_as_base64 false
                                         :prompt_for_file_name false
                                         :drag_and_drop {:insert_mode true}}}
                        :keys [(key :<leader>p :<cmd>PasteImage<cr>
                                    {:desc "Paste image from clipboard"})]})]
  (plugin :yetone/avante.nvim
          {:version false
           :event :VeryLazy
           :dependencies [:nvim-lua/plenary.nvim
                          :MunifTanjim/nui.nvim
                          :echasnovski/mini.icons
                          img-clip]
           :build #(vim.cmd :make)
           :opts {:provider :openai
                  :providers {:openai {:model :gpt-5.1}}
                  :selector {:provider :snacks :provider_opts {}}}}))
