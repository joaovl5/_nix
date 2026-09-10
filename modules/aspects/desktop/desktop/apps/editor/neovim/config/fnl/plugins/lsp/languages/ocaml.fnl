(import-macros {: plugin} :./lib/init-macros)

(local {: v/autocmd : v/map} (require :lib/nvim))

(fn hover [client bufnr]
  (let [win (vim.api.nvim_get_current_win)
        cursor (vim.api.nvim_win_get_cursor win)
        params (vim.lsp.util.make_position_params win client.offset_encoding)]
    ;; No named maximum: request the largest signed LSP integer.
    (set params.verbosity 2147483647)
    (client:request
      :ocamllsp/hoverExtended
      params
      (fn [err result]
        (when (and (= bufnr (vim.api.nvim_get_current_buf))
                   (= win (vim.api.nvim_get_current_win))
                   (vim.deep_equal cursor (vim.api.nvim_win_get_cursor win)))
          (if err
              (vim.notify err.message vim.log.levels.ERROR)
              (or (not result) (not result.contents))
              (vim.notify "No information available" vim.log.levels.INFO)
              (let [lines (vim.lsp.util.convert_input_to_markdown_lines result.contents)]
                (if (= 0 (length lines))
                    (vim.notify "No information available" vim.log.levels.INFO)
                    (vim.lsp.util.open_floating_preview
                      lines
                      :markdown
                      {:border :none :focus_id :ocaml_hover}))))))
      bufnr)))

(fn setup []
  ;; ocaml.nvim adds commands and mappings; lsp/config.fnl owns the server.
  ((. (require :ocaml) :setup) {})
  (v/autocmd :LspAttach
             {:group (vim.api.nvim_create_augroup :ocaml_hover {:clear true})
              :callback
              (fn [event]
                (let [client (vim.lsp.get_client_by_id event.data.client_id)]
                  (when (and client (= client.name :ocamllsp))
                    (v/map :n
                           :K
                           #(hover client event.buf)
                           {:buffer event.buf
                            :desc "OCaml hover (maximum verbosity)"}))))}))

[(plugin :tarides/ocaml.nvim {:lazy false :config setup})]
