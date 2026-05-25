(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/autocmd : v/uv} (require :./lib/nvim))

(local lsp-status-width 40)
(local lsp-status-timeout-ms 1500)
(local spinner-frames ["⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷"])
(local lsp-notification {:record nil
                         :message nil
                         :icon 1
                         :last-update 0
                         :spinning false})

(fn now-ms []
  (/ (v/uv.hrtime) 1000000))

(fn non-empty? [value]
  (and (= :string (type value))
       (< 0 (length value))))

(fn contains-plain? [value needle]
  (and (non-empty? value)
       (not= nil (string.find value needle 1 true))))

(fn ignored-lsp-status? [data message]
  (let [params (and data data.params)
        value (and params params.value)
        title (and (= :table (type value)) value.title)
        value-message (and (= :table (type value)) value.message)]
    (or (contains-plain? message "diagnostics_on_open")
        (contains-plain? title "diagnostics_on_open")
        (contains-plain? value-message "diagnostics_on_open")
        (contains-plain? title "diagnostics")
        (contains-plain? value-message "diagnostics"))))

(fn fit-line [line width]
  (var text (or line ""))
  (while (> (vim.api.nvim_strwidth text) width)
    (let [chars (vim.fn.strchars text)]
      (set
        text
        (if (<= chars 2)
            ""
            (.. (vim.fn.strcharpart text 0 (- chars 2)) "…")))))
  (.. text
      (string.rep " " (math.max 0 (- width (vim.api.nvim_strwidth text))))))

(fn render-lsp-status [bufnr notif highlights config]
  ((require :notify.render.compact) bufnr notif highlights config)
  (let [lines (vim.api.nvim_buf_get_lines bufnr 0 -1 false)]
    (vim.api.nvim_buf_set_lines
      bufnr
      0
      -1
      false
      (icollect [_ line (ipairs lines)]
        (fit-line line lsp-status-width)))))

(fn set-lsp-record [record]
  (set lsp-notification.record record))

(fn notify-lsp-status-message [icon]
  (set-lsp-record
    (vim.notify
      lsp-notification.message
      :info
      {:id :lsp-status-updates
       :replace lsp-notification.record
       :title "LSP"
       :icon icon
       :timeout lsp-status-timeout-ms
       :hide_from_history true
       :render render-lsp-status
       :on_close #(set-lsp-record nil)})))

(fn update-lsp-spinner []
  (if (and lsp-notification.spinning
           lsp-notification.record
           lsp-notification.message
           (< (- (now-ms) lsp-notification.last-update)
              lsp-status-timeout-ms))
      (do
        (set lsp-notification.icon
             (+ (% lsp-notification.icon (length spinner-frames)) 1))
        (notify-lsp-status-message (. spinner-frames lsp-notification.icon))
        (vim.defer_fn update-lsp-spinner 100))
      (set lsp-notification.spinning false)))

(fn start-lsp-spinner []
  (when (not lsp-notification.spinning)
    (set lsp-notification.spinning true)
    (vim.defer_fn update-lsp-spinner 100)))

(fn notify-lsp-status [data]
  (let [message (vim.lsp.status)]
    (when (and (non-empty? message)
               (not (ignored-lsp-status? data message)))
      (set lsp-notification.message message)
      (set lsp-notification.last-update (now-ms))
      (notify-lsp-status-message (. spinner-frames lsp-notification.icon))
      (start-lsp-spinner))))

(fn setup-lsp-status-updates []
  (let [group (vim.api.nvim_create_augroup :lsp-notify-status-updates
                                           {:clear true})]
    (v/autocmd
      :LspProgress
      {:group group
       :callback
       (fn [ev]
         (let [data ev.data]
           (vim.schedule #(notify-lsp-status data))))})))

(fn setup_notify []
  (let [notify (require :notify)]
    (notify.setup
      {:render :wrapped-compact
       :minimum_width 40
       :stages :static})
    (set vim.notify notify)
    (setup-lsp-status-updates)))

(p! :rcarriga/nvim-notify
    (lazy false)
    (priority 999)
    (keys
      (group
        :diagnostics
        (bind :j
              (cmd :Notifications)
              (desc "Notifications"))))
    (config setup_notify))
