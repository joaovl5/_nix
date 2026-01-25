(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(now (fn []
       (let-req [icons :mini.icons] ;
                ;; set up to avoid icon for some extensions
                (let [ext3_bl {:scm true :txt true :yml true}
                      ext4_bl {:json true :yaml true}]
                  (icons.setup {:use_file_extension #(not (or (. ext3_bl
                                                                 ($1:sub -3))
                                                              (. ext4_bl
                                                                 ($1:sub -4))))})))
       ;; mock nvim-web-devicons
       (later MiniIcons.mock_nvim_web_devicons)
       ;; add lsp kind icons
       (later MiniIcons.tweak_lsp_kind)))
