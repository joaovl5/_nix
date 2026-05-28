(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/stdpath : v/cwd} (require :lib/nvim))

(fn setup_cc []
  (local
    models
    {:base "minimax/minimax-m2.7"})
  (local
    interactions
    (let [adap #{:adapter $1}]
      {:chat {:adapter :openrouter
              :model models.base
              :tools {:opts {:auto_submit_errors true}}}
       :inline (adap :openrouter)
       :cmd (adap :openrouter)
       :background (adap :openrouter)}))
  (local
    extensions
    {:spinner {}
     :history
     {:enabled true
      :dir_to_save (..
                     (v/stdpath :data)
                     :/codecompanion_chats.json)
      :opts {:expiration_days 7
             :chat_filter #(= $1.cwd (v/cwd))}}})
  (local
    adapters
    {:http
     {:openrouter
      #(do-req :codecompanion.adapters
               :extend
               :openai_compatible
               {:env {:api_key :OPENROUTER_API_KEY
                      :url "https://openrouter.ai/api"}
                :name :openrouter
                :formatted_name "Openrouter API"})}})
  {: interactions : extensions : adapters})

(p!
  :olimorris/codecompanion.nvim
  (version "^18.0.0")
  (deps [:nvim-lua/plenary.nvim
         :nvim-treesitter/nvim-treesitter
         :ravitemer/codecompanion-history.nvim
         :franco-ruggeri/codecompanion-spinner.nvim])
  (keys
    (group
      :ai
      (bind :a (cmd "CodeCompanionActions") (desc "Actions") (m :n :v))
      (bind :c (cmd "CodeCompanionChat Toggle") (desc "Chat") (m :n :v))
      (bind :r (cmd "CodeCompanionCmd") (desc "Run command") (m :n :v))
      (bind :l (cmd "CodeCompanion") (desc "Inline Assist") (m :n :v))))
  (opts setup_cc))
