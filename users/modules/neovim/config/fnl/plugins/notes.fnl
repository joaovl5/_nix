(import-macros {: plugin : key} :./lib/init-macros)

(plugin :obsidian-nvim/obsidian.nvim
        {:opts {:legacy_commands false
                :workspaces [{:name :wiki :path "~/wiki/"}]}})
