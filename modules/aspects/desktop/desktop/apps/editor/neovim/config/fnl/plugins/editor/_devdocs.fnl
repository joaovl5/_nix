; TODO: refactor all of this later, this is not good and deserves much
; scrutiny, was AI generated
(local {: v/$ : v/n : v/later} (require :lib/nvim))

(local M {})

(local _filetype_aliases
       {:fennel :lua
        :javascriptreact :javascript
        :sh :bash
        :tsx :typescript
        :typescriptreact :typescript})

(local _spinner_id :devdocs-download)
(local _progress_namespace
       (vim.api.nvim_create_namespace :devdocs-download-progress))

(local _progress_inactive "▱▱▱▱▱▱▱")
(local _progress_complete "▰▰▰▰▰▰▰")
(local _download_worker_count 4)
(local _line_similarity_weight 40)
(var _active_progress nil)

(fn _text [value]
  (if (= (type value) :string)
      (string.lower value)
      ""))

(fn _registry_matches_filetype? [registry filetype]
  (let [filetype (or (. _filetype_aliases filetype) filetype)
        filetype (_text filetype)
        slug (_text registry.slug)
        alias (_text registry.alias)
        registry_type (_text registry.type)
        name (_text registry.name)]
    (and (not= filetype "")
         (or (= slug filetype)
             (= alias filetype)
             (= registry_type filetype)
             (= name filetype)
             (vim.startswith slug (.. filetype "~"))))))

(fn _registries_for_filetype [filetype]
  (let [registries_usecase
        (require :devdocs.application.usecases.registries_usecase)
        registries (or (registries_usecase.list) [])
        matches []]
    (each [_ registry (ipairs registries)]
      (when (_registry_matches_filetype? registry filetype)
        (table.insert matches registry)))
    matches))

(fn _tailwind_context? [parser range]
  (var node
       (parser:named_node_for_range range {:ignore_injections false}))
  (var matches? false)
  (while (and node (not matches?))
    (when (string.find (node:type) "attribute" 1 true)
      (let [text (vim.treesitter.get_node_text node 0)]
        (set matches?
             (or (string.match text "^%s*class%s*=")
                 (string.match text "^%s*className%s*=")
                 (string.match text "^%s*:class%s*=")
                 (string.match text "^%s*v%-bind:class%s*=")))))
    (set node (node:parent)))
  matches?)

(fn _cursor_filetypes []
  (let [[row col] (vim.api.nvim_win_get_cursor 0)
        range [(- row 1) col (- row 1) col]
        (ok? filetypes)
        (pcall
          (fn []
            (let [parser (vim.treesitter.get_parser 0)]
              (when (not (parser:is_valid false range))
                (parser:parse range))
              (let [language_tree (parser:language_for_range range)
                    filetypes [(language_tree:lang)]]
                (when (_tailwind_context? parser range)
                  (table.insert filetypes :tailwindcss))
                filetypes))))]
    (if ok? filetypes [vim.bo.filetype])))

(fn _registry_matches_filetypes? [registry filetypes]
  (accumulate [matches? false
               _ filetype (ipairs filetypes)]
    (or matches? (_registry_matches_filetype? registry filetype))))

(fn _progress_window_valid? [progress]
  (and progress.win
       (vim.api.nvim_win_is_valid progress.win)
       (= (vim.api.nvim_win_get_buf progress.win) progress.buf)))

(fn _close_progress [progress]
  (when (_progress_window_valid? progress)
    (vim.api.nvim_win_close progress.win true)))

(fn _focus_progress_line [progress line]
  (when (_progress_window_valid? progress)
    (pcall vim.api.nvim_win_set_cursor progress.win [line 0])))

(fn _progress_lines [progress spinner_text]
  (let [lines []
        header
        (if progress.running
            (.. (or spinner_text _progress_inactive)
                " Downloading DevDocs documentation")
            (> progress.failed 0)
            (string.format "Finished with %d failed download(s)"
                           progress.failed)
            "All DevDocs downloads completed")]
    (table.insert lines header)
    (table.insert lines "")
    (each [_ row (ipairs progress.rows)]
      (let [marker
            (match row.status
              :active (or spinner_text _progress_inactive)
              :done _progress_complete
              :failed _progress_inactive
              _ _progress_inactive)]
        (table.insert lines (string.format "%s %s" marker row.registry.name))))
    lines))

(fn _render_progress [progress spinner_text]
  (when (and (vim.api.nvim_buf_is_valid progress.buf)
             (_progress_window_valid? progress))
    (let [lines (_progress_lines progress spinner_text)]
      (vim.api.nvim_set_option_value :modifiable true {:buf progress.buf})
      (vim.api.nvim_buf_set_lines progress.buf 0 -1 false lines)
      (vim.api.nvim_buf_clear_namespace
        progress.buf
        _progress_namespace
        0
        -1)
      (each [index row (ipairs progress.rows)]
        (let [hl_group
              (match row.status
                :done :DiagnosticOk
                :failed :DiagnosticError
                _ nil)]
          (when hl_group
            (vim.api.nvim_buf_add_highlight
              progress.buf
              _progress_namespace
              hl_group
              (+ index 1)
              0
              (length _progress_complete)))))
      (vim.api.nvim_set_option_value :modifiable false {:buf progress.buf}))))

(fn _open_progress [registries]
  (when (and _active_progress _active_progress.running)
    (when (_progress_window_valid? _active_progress)
      (vim.api.nvim_set_current_win _active_progress.win))
    (v/n "A DevDocs download is already in progress" vim.log.levels.WARN))
  (if (and _active_progress _active_progress.running)
      nil
      (do
        (when _active_progress
          (_close_progress _active_progress))
        (let [buf (vim.api.nvim_create_buf false true)
              rows
              (icollect [_ registry (ipairs registries)]
                {:registry registry :status :pending})
              max_name_width
              (accumulate [width 0
                           _ registry (ipairs registries)]
                (math.max width (vim.fn.strdisplaywidth registry.name)))
              width (math.max 44
                              (math.min (+ max_name_width 10)
                                        (- vim.o.columns 4)))
              height (math.max 3
                               (math.min (+ (length rows) 2)
                                         (- vim.o.lines 4)))
              row (math.max 0 (math.floor (/ (- vim.o.lines height) 2)))
              col (math.max 0 (math.floor (/ (- vim.o.columns width) 2)))
              win
              (vim.api.nvim_open_win
                buf
                true
                {:relative :editor
                 :row row
                 :col col
                 :width width
                 :height height
                 :style :minimal
                 :focusable true
                 :border :rounded
                 :title " DevDocs Downloads "
                 :title_pos :center})
              progress
              {:buf buf
               :win win
               :rows rows
               :running true
               :failed 0}]
          (vim.api.nvim_set_option_value :buftype :nofile {:buf buf})
          (vim.api.nvim_set_option_value :bufhidden :wipe {:buf buf})
          (vim.api.nvim_set_option_value :swapfile false {:buf buf})
          (vim.api.nvim_set_option_value :undolevels -1 {:buf buf})
          (vim.api.nvim_set_option_value :filetype :devdocs-progress {:buf buf})
          (each [_ key (ipairs [:q :<Esc>])]
            (vim.keymap.set
              :n
              key
              (fn [] (_close_progress progress))
              {:buffer buf :nowait true :silent true}))
          (let [spinner (require :spinner)]
            (spinner.config
              _spinner_id
              {:kind :custom
               :pattern :aesthetic
               :placeholder _progress_inactive
               :ui_scope _spinner_id
               :on_update_ui
               (fn [event]
                 (_render_progress progress event.text))}))
          (set _active_progress progress)
          (_render_progress progress _progress_inactive)
          progress))))

(fn _finish_progress [progress]
  (let [spinner (require :spinner)]
    (set progress.running false)
    (spinner.stop _spinner_id true)
    (_focus_progress_line progress 1)
    (_render_progress progress _progress_inactive)
    (when (= progress.failed 0)
      (vim.defer_fn (fn []
                      (when (and (= _active_progress progress)
                                 (not progress.running))
                        (_close_progress progress)
                        (set _active_progress nil)))
        1500))))

(fn _install_registry [registry on_done]
  (let [container (require :devdocs.application.ports.dependency_registry)
        locks_repository (container.locks_repository)
        entries_usecase (require :devdocs.application.usecases.entries_usecase)
        setup_config (require :devdocs.domain.defaults.setup_config)
        installer
        (vim.fs.joinpath
          (vim.fn.stdpath :config)
          :scripts
          :devdocs_install.py)
        destination
        (vim.fs.joinpath
          (vim.fn.stdpath :data)
          :devdocs
          setup_config.plataform
          registry.slug)
        url
        (string.format
          "https://documents.devdocs.io/%s/db.json"
          registry.slug)]
    (vim.system
      [:python3 installer url destination]
      {:text true}
      (vim.schedule_wrap
        (fn [result]
          (if (not= result.code 0)
              (let [error_text (vim.trim (or result.stderr ""))]
                (v/n
                  (.. "Failed to install "
                      registry.name
                      " documentation"
                      (if (= error_text "") "" (.. ": " error_text)))
                  vim.log.levels.ERROR)
                (on_done false))
              (entries_usecase.install_async
                registry.slug
                (fn []
                  (locks_repository.save
                    {:id registry.slug :name registry.name})
                  (on_done true)))))))))

(fn _install_queue [registries]
  (let [progress (_open_progress registries)]
    (when progress
      (let [spinner (require :spinner)]
        (var next_index 1)
        (var active 0)
        (var completed 0)
        (var start_available nil)
        (set start_available
             (fn []
               (while (and (< active _download_worker_count)
                           (<= next_index (length registries)))
                 (let [index next_index
                       row (. progress.rows index)]
                   (set next_index (+ next_index 1))
                   (set active (+ active 1))
                   (set row.status :active)
                   (_focus_progress_line progress (+ index 2))
                   (_install_registry
                     row.registry
                     (fn [success]
                       (set row.status (if success :done :failed))
                       (when (not success)
                         (set progress.failed (+ progress.failed 1)))
                       (vim.schedule
                         (fn []
                           (collectgarbage :collect)
                           (set active (- active 1))
                           (set completed (+ completed 1))
                           (if (= completed (length registries))
                               (_finish_progress progress)
                               (start_available))))))))
               (_render_progress progress (spinner.render _spinner_id))))
        (spinner.start _spinner_id)
        (start_available)))))

(fn _install_selected_registry [registry]
  (_install_queue [registry]))

(fn M.ui_call [fn_name ...]
  (let [dvd (require :devdocs)
        dvd_ui dvd.ui.documentations]
    ((. dvd_ui fn_name) ...)))

(fn M.install_for_filetype []
  (let [filetype vim.bo.filetype
        registries (_registries_for_filetype filetype)]
    (if (= (length registries) 0)
        (v/n (.. "No DevDocs entries match filetype `" filetype "`")
             vim.log.levels.WARN)
        (= (length registries) 1)
        (_install_queue registries)
        (let [container
              (require :devdocs.application.ports.dependency_registry)
              picker (container.picker)]
          (picker.registries _install_selected_registry registries)))))

(fn M.install_browse []
  (let [container (require :devdocs.application.ports.dependency_registry)
        picker (container.picker)
        registries_usecase
        (require :devdocs.application.usecases.registries_usecase)
        registries (or (registries_usecase.list) [])]
    (if (= (length registries) 0)
        (v/n "No DevDocs documentation is available" vim.log.levels.WARN)
        (picker.registries _install_selected_registry registries))))

(fn M.install_all []
  (let [registries_usecase
        (require :devdocs.application.usecases.registries_usecase)
        latest_registries {}
        queue []]
    (each [_ registry (ipairs (or (registries_usecase.list) []))]
      (let [latest (. latest_registries registry.name)]
        (when (or (not latest)
                  (> (or registry.mtime 0) (or latest.mtime 0)))
          (tset latest_registries registry.name registry))))
    (each [_ registry (pairs latest_registries)]
      (table.insert queue registry))
    (table.sort queue (fn [a b] (< a.name b.name)))
    (if (= (length queue) 0)
        (v/n "No DevDocs documentation is available" vim.log.levels.WARN)
        (_install_queue queue))))

(fn _normalize_heading [text]
  (let [normalized (string.gsub (string.lower text) "[^%w]+" "-")
        without_prefix (string.gsub normalized "^%-+" "")]
    (string.gsub without_prefix "%-+$" "")))

(fn _trigram_counts [text]
  (let [normalized (string.lower text)
        grams {}
        size (length normalized)]
    (if (= size 0)
        [grams 0]
        (< size 3)
        (do
          (tset grams normalized 1)
          [grams 1])
        (let [count (- size 2)]
          (for [index 1 count]
            (let [gram (string.sub normalized index (+ index 2))]
              (tset grams gram (+ (or (. grams gram) 0) 1))))
          [grams count]))))

(fn _trigram_similarity [left_grams left_count right]
  (let [[right_grams right_count] (_trigram_counts right)]
    (if (or (= left_count 0) (= right_count 0))
        0
        (let [shared
              (accumulate [total 0
                           gram count (pairs left_grams)]
                (+ total (math.min count (or (. right_grams gram) 0))))]
          (/ (* 2 shared) (+ left_count right_count))))))

(fn _without_cursor_word [line cursor_word]
  (if (= cursor_word "")
      line
      (let [context (string.gsub line (vim.pesc cursor_word) "" 1)]
        context)))

(fn _pattern_matches_any? [pattern items]
  (if (= pattern "")
      true
      (let [Matcher (require :snacks.picker.core.matcher)
            matcher (Matcher.new)]
        (matcher:init pattern)
        (accumulate [matches? false
                     _ item (ipairs items)]
          (or matches? (> (matcher:match item) 0))))))

(fn _target_line [lines entry]
  (let [path_parts (vim.split entry.path "#" {:plain true})
        anchor (_normalize_heading (or (. path_parts 2) ""))
        name (_normalize_heading entry.name)]
    (or
      (accumulate [target nil
                   index line (ipairs lines)]
        (if target
            target
            (let [heading? (vim.startswith line "#")
                  normalized (_normalize_heading line)
                  anchor_match?
                  (and (not= anchor "")
                       (string.find normalized anchor 1 true))
                  name_match?
                  (and (not= name "")
                       (string.find normalized name 1 true))]
              (and heading?
                   (or anchor_match? name_match?)
                   index))))
      1)))

(fn _cached_document [repository document_cache lock_id path]
  (let [cache_key (.. lock_id ":" path)]
    (or (. document_cache cache_key)
        (let [document (repository.find lock_id path)]
          (when document
            (let [cached
                  {:text document
                   :lines (vim.split document "\n" {:plain true})}]
              (tset document_cache cache_key cached)
              cached))))))

(fn _resolve_item [repository document_cache item]
  (let [path_parts (vim.split item.entry.path "#" {:plain true})
        path (. path_parts 1)
        cached
        (_cached_document repository document_cache item.lock.id path)]
    (when cached
      (set item.preview {:text cached.text :ft :markdown})
      (set item.pos [(_target_line cached.lines item.entry) 0]))))

(fn _heading_matches [repository document_cache items pattern]
  (let [Matcher (require :snacks.picker.core.matcher)
        matcher (Matcher.new)
        seen {}
        matches []]
    (matcher:init pattern)
    (each [_ source_item (ipairs items)]
      (let [path_parts
            (vim.split source_item.entry.path "#" {:plain true})
            path (. path_parts 1)
            cache_key (.. source_item.lock.id ":" path)]
        (when (not (. seen cache_key))
          (tset seen cache_key true)
          (let [cached
                (_cached_document
                  repository
                  document_cache
                  source_item.lock.id
                  path)]
            (when cached
              (var in_fence? false)
              (each [_ line (ipairs cached.lines)]
                (if (or (string.match line "^%s*```")
                        (string.match line "^%s*~~~"))
                    (set in_fence? (not in_fence?))
                    (not in_fence?)
                    (let [heading (string.match line "^#+%s+(.+)$")]
                      (when heading
                        (let [without_suffix
                              (string.gsub heading "%s+#+%s*$" "")
                              name (string.gsub without_suffix "`" "")
                              item
                              {:idx (+ (length items)
                                       (length matches)
                                       1)
                               :text
                               (string.format "[%s] %s · Heading"
                                              source_item.lock.name
                                              name)
                               :entry
                               {:name name :path path :type :Heading}
                               :lock source_item.lock}]
                          (when (> (matcher:match item) 0)
                            (set item.resolve
                                 (fn [resolved]
                                   (_resolve_item
                                     repository
                                     document_cache
                                     resolved)))
                            (table.insert matches item))))))))))))
    matches))

(fn _preview [ctx]
  (ctx.preview:reset)
  (ctx.preview:set_lines
    (vim.split ctx.item.preview.text "\n" {:plain true}))
  (let [buf ctx.preview.win.buf
        eventignore vim.o.eventignore]
    (set vim.o.eventignore :all)
    (vim.api.nvim_set_option_value :filetype :markdown {:buf buf})
    (set vim.o.eventignore eventignore)
    (when (not (pcall vim.treesitter.start buf :markdown))
      (vim.api.nvim_set_option_value :syntax :markdown {:buf buf})))
  (ctx.preview:loc))

(fn _open_item [renderer item]
  (when item.resolve
    (item.resolve item)
    (set item.resolve nil))
  (when item.preview
    (v/$ :vsplit)
    (renderer.create_scratch_buffer
      (vim.split item.preview.text "\n" {:plain true})
      :markdown)
    (v/later
      (fn []
        (vim.api.nvim_win_set_cursor 0 item.pos)
        (v/$ "normal! zz")))))

(fn _lookup [query]
  (let [container (require :devdocs.application.ports.dependency_registry)
        entries_usecase (require :devdocs.application.usecases.entries_usecase)
        registries_usecase
        (require :devdocs.application.usecases.registries_usecase)
        repository (container.documentations_repository)
        renderer (container.buffer)
        locks_repository (container.locks_repository)
        locks (or (locks_repository.list) {})
        snacks (require :snacks)
        registries_by_slug {}
        filetypes (_cursor_filetypes)
        relevant_locks []
        cursor_word query
        line_context
        (_without_cursor_word (vim.api.nvim_get_current_line) cursor_word)
        [context_grams context_count] (_trigram_counts line_context)
        items []
        document_cache {}]
    (each [_ registry (ipairs (or (registries_usecase.list) []))]
      (tset registries_by_slug registry.slug registry))
    (each [_ lock (pairs locks)]
      (let [registry (. registries_by_slug lock.id)]
        (when (and registry
                   (_registry_matches_filetypes? registry filetypes))
          (table.insert relevant_locks lock))))
    (each [_ lock (ipairs relevant_locks)]
      (each [_ entry (ipairs (or (entries_usecase.find lock.id) []))]
        (let [item
              {:idx (+ (length items) 1)
               :text (string.format "[%s] %s · %s"
                                    lock.name
                                    entry.name
                                    (or entry.type ""))
               :entry entry
               :lock lock}]
          (set item.resolve
               (fn [resolved]
                 (_resolve_item repository document_cache resolved)))
          (table.insert items item))))
    (var pattern_matches? (_pattern_matches_any? cursor_word items))
    (when (and (not pattern_matches?) (not= cursor_word ""))
      (let [heading_items
            (_heading_matches repository document_cache items cursor_word)]
        (each [_ item (ipairs heading_items)]
          (table.insert items item))
        (set pattern_matches? (> (length heading_items) 0))))
    (if (= (length items) 0)
        (v/n "No DevDocs documentation is installed" vim.log.levels.WARN)
        (not pattern_matches?)
        (v/n (.. "No DevDocs entries or headings match `"
                 cursor_word
                 "`")
             vim.log.levels.WARN)
        (snacks.picker.pick
          {:source :select
           :title "DevDocs"
           :items items
           :pattern cursor_word
           :matcher
           {:sort_empty true
            :on_match
            (fn [_ item]
              (let [similarity
                    (or item.line_similarity
                        (_trigram_similarity
                          context_grams
                          context_count
                          item.text))]
                (set item.line_similarity similarity)
                (set item.score
                     (+ item.score
                        (* _line_similarity_weight similarity)))))}
           :format :text
           :preview _preview
           :layout {:preset :default}
           :confirm
           (fn [picker item]
             (picker:close)
             (_open_item renderer item))}))))

(fn M.cursor_lookup []
  (_lookup (vim.fn.expand "<cword>")))

(fn M.selection_lookup []
  (let [lines
        (vim.fn.getregion
          (vim.fn.getpos :v)
          (vim.fn.getpos ".")
          {:type (vim.fn.mode)})
        selection (vim.trim (table.concat lines " "))]
    (when (not= selection "")
      (_lookup selection))))

M
