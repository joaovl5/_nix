(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(local n (require :lib/nvim))

(now (fn []
       (let-req [files :mini.files] ;
                (files.setup {:windows {:preview true
                                        :width_focus 40
                                        :width_nofocus 30}
                              ; mappings are derfined in keymaps.fnl
                              :mappings _G.MiniFilesMappings}))))

; customize window 

(n.autocmd :User
           {:pattern :MiniFilesWindowOpen
            :callback (fn [args]
                        (let [win_id args.data.win_id
                              config (vim.api.nvim_win_get_config win_id)]
                          (set config.border :rounded)
                          (set config.title_pos :center)
                          (vim.api.nvim_win_set_config win_id config)))})

(fn get_idx [win_id win_ids]
  (var res nil)
  (each [i id (ipairs win_ids)]
    (if (= id win_id)
        (set res i)))
  res)

; (n.autocmd :User
;            {:pattern :MiniFilesWindowUpdate
;             :callback (fn [args]
;                         (let [config (vim.api.nvim_win_get_config args.data.win_id)
;                               state (or (MiniFiles.get_explorer_state) {})
;                               win_ids (vim.tbl_map (fn [t]
;                                                      t.win_id)
;                                                    (or state.windows {}))
;                               this_win_idx (get_idx args.data.win_id win_ids)
;                               focused_win_idx (get_idx (vim.api.nvim_get_current_win)
;                                                        win_ids)]
;                           (when (and this_win_idx focused_win_idx)
;                             (let [idx_delta (- this_win_idx focused_win_idx)
;                                   widths [60 20 10]
;                                   i (+ (math.abs idx_delta) 1)]
;                               (set config.width
;                                    (if (<= i (length widths))
;                                        (. widths i)
;                                        (. widths (length widths))))
;                               (var offset 0)
;                               (for [j 1 (math.abs idx_delta)]
;                                 (let [w (or (. widths j)
;                                             (. widths (length widths)))
;                                       _offset (+ (* 0.5 (+ w config.width)) 2)]
;                                   (if (> idx_delta 0)
;                                       (set offset (+ offset _offset))
;                                       (< idx_delta 0)
;                                       (set offset (- offset _offset)))))
;                               (set config.height (if (= idx_delta 0) 25 20))
;                               (set config.row
;                                    (math.floor (* 0.5
;                                                   (- vim.o.lines config.height))))
;                               (set config.col
;                                    (math.floor (+ (* 0.5)
;                                                   (- vim.o.columns config.width))
;                                                offset))
;                               (vim.api.nvim_win_set_config args.data.win_id
;                                                            config)))))})
