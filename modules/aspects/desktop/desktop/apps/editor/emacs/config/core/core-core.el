;; --- functions

(defun prelude-buffer-mode (buffer-or-name)
  "Retrieve the `major-mode' of BUFFER-OR-NAME."
  (with-current-buffer buffer-or-name
    major-mode))

(defun prelude-search (query-url prompt)
  "Open the search url constructed with the QUERY-URL.
PROMPT sets the `read-string prompt."
  (browse-url
   (concat query-url
           (url-hexify-string
            (if mark-active
                (buffer-substring (region-beginning) (region-end))
              (read-string prompt))))))

(defmacro prelude-install-search-engine (search-engine-name search-engine-url search-engine-prompt)
  "Given some information regarding a search engine, install the interactive command to search through them"
  `(defun ,(intern (format "prelude-%s" search-engine-name)) ()
       ,(format "Search %s with a query or region if any." search-engine-name)
       (interactive)
       (prelude-search ,search-engine-url ,search-engine-prompt)))

;; --- install search

(prelude-install-search-engine "duckduckgo" "https://duckduckgo.com/?t=lm&q="              "Search DuckDuckGo: ")
(prelude-install-search-engine "github"     "https://github.com/search?q="                 "Search GitHub: ")
(prelude-install-search-engine "youtube"    "http://www.youtube.com/results?search_query=" "Search YouTube:")

;; --- tweaks

;; include shell PATH in emacs
(straight-use-package 'exec-path-from-shell)
(require 'exec-path-from-shell)
(exec-path-from-shell-initialize)

;; --- opts/modes

(savehist-mode 1)
(save-place-mode 1)


(provide 'core-core)
