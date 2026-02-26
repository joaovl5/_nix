(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :olimorris/codecompanion.nvim
        {:version :^18.0.0
         :dependencies [:nvim-lua/plenary.nvim
                        :nvim-treesitter/nvim-treesitter
                        :ravitemer/codecompanion-history.nvim
                        :franco-ruggeri/codecompanion-spinner.nvim]
         :opts (fn []
                 (let [base_model :minimax/minimax-m2.5]
                   {:interactions (let [adap_cfg {:adapter :openrouter}]
                                    {:chat {:adapter :openrouter
                                            :model base_model
                                            :tools {:opts {:auto_submit_errors true}}}
                                     ; :roles {:llm (fn [adapter]
                                     ;                (.. "󰚩 "
                                     ;                    adapter.formatted_name))
                                     ;         :user (fn [_] " User")}}
                                     :inline adap_cfg
                                     :cmd adap_cfg
                                     :background adap_cfg})
                    :extensions {:history {:enabled true
                                           :dir_to_save (.. (vim.fn.stdpath :data)
                                                            :/codecompanion_chats.json)
                                           :opts {:expiration_days 7
                                                  :chat_filter (fn [data]
                                                                 (= data.cwd
                                                                    (vim.fn.getcwd)))
                                                  :title_generation_opts {:adapter :openrouter
                                                                          :model base_model}
                                                  :summary {:generation_opts {:adapter :openrouter
                                                                              :model base_model}}}}
                                 :spinner {}}
                    :adapters {:http {:openrouter (fn []
                                                    (do-req :codecompanion.adapters
                                                            :extend
                                                            :openai_compatible
                                                            {:env {:api_key :OPENROUTER_API_KEY
                                                                   :url "https://openrouter.ai/api"}
                                                             :name :openrouter
                                                             :formatted_name "Openrouter API"}))}}}))})
