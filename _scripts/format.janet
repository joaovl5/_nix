#!/run/current-system/sw/bin/env janet
# Proof-of-concept formatter runner.
# Not wired into justfile; requires Janet + Spork on PATH.

(import spork/sh :as sh)

(def emacs-vendored-nix "**/emacs/config/**.nix")
(var exit-status 0)

# Like the fish helper: return tracked files for the given globs, or nil.
# Use git's NUL output so paths stay exact.
(defn with-files [& patterns]
  (def out (sh/exec-slurp "git" "ls-files" "-z" ;patterns))
  (if (= out "")
    nil
    (string/split "\0" (string/slice out 0 (dec (length out))))))

(defn run! [& args]
  (def code (sh/exec ;args))
  (when (and (= exit-status 0) (not= code 0))
    (set exit-status code))
  code)

# markdown / rumdl
(let [files (with-files "*.md")]
  (when files
    (run! "nix" "--quiet" "--log-format" "raw" "run" ".#rumdl" "--"
          "fmt" "--no-cache" "--silent")))

# nix / alejandra + deadnix + statix
(let [files (with-files "*.nix")]
  (when files
    (run! "alejandra" "--exclude" emacs-vendored-nix "-q" "-q" ;files)
    (run! "deadnix" "-_" "-L" "--edit" "--exclude" emacs-vendored-nix ;files)
    (run! "statix" "fix" "--ignore" emacs-vendored-nix "--" ".")))

# fennel / fnlfmt
(let [files (with-files "*.fnl")]
  (when files
    (run! "fnlfmt" "--fix" ;files)))

# python / ruff
(let [files (with-files "*.py" "*.pyi")]
  (when files
    (run! "ruff" "format" ;files)))

# js-like / biome
(let [files (with-files
              "*.js" "*.ts" "*.mjs" "*.mts" "*.cjs" "*.cts"
              "*.jsx" "*.tsx" "*.d.ts" "*.d.cts" "*.d.mts"
              "*.json" "*.jsonc" "*.css")]
  (when files
    (run! "biome" "format"
           "--write"
           "--no-errors-on-unmatched"
           "--config-path" "biome.json"
           "--skip-parse-errors"
           "--diagnostic-level=warn"
           ;files)))

# fish
(let [files (with-files "*.fish")]
  (when files
    (run! "fish_indent" "--write" ;files)))

# sh
(let [files (with-files "*.sh" "*.bash" "*.envrc" "*.envrc.*")]
  (when files
    (run! "shfmt" "-w" "-i" "2" "-s" ;files)))

# toml
(let [files (with-files "*.toml")]
  (when files
    (run! "taplo" "format" ;files)))

# json
(let [files (with-files "*.json")]
  (when files
    (run! "jsonfmt" "-w" ;files)))

# kdl
(let [files (with-files "*.kdl")]
  (when files
    (run! "kdlfmt" "format" "--kdl-version" "v1" ;files)))

# sql
(let [files (with-files "*.sql")]
  (when files
    (run! "sqruff" "fix" ;files)))

# keep-sorted
(let [files (with-files)]
  (when files
    (run! "keep-sorted" ;files)))

(run! "just" "--fmt")
(os/exit exit-status)
