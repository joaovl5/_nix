(import spork/argparse :as argparse)
(import spork/sh :as sh)

(def emacs-vendored-nix-root "users/_modules/desktop/apps/editor/emacs/config")
(def cli-options
  (or (argparse/argparse
        "Format repository files."
        "quiet" {:kind :flag
                 :short "q"
                 :help "Only print command output when a command fails."})
      (os/exit 1)))

(def quiet? (cli-options "quiet"))

(defn files-under [root keep?]
  (def files @[])
  (defn walk [path]
    (case (os/lstat path :mode)
      :directory
      (each child (os/dir path)
        (walk (string path "/" child)))
      :file
      (when (keep? path)
        (array/push files path))
      nil))
  (walk root)
  (sort files))

(defn nix-files-under [root]
  (files-under root (fn [path] (string/has-suffix? ".nix" path))))

(def emacs-vendored-nix (nix-files-under emacs-vendored-nix-root))

(defn flag-each [flag values]
  (def args @[])
  (each value values
    (array/push args flag)
    (array/push args value))
  args)

(defn flag-values [flag values]
  (def args @[])
  (when (not (empty? values))
    (array/push args flag)
    (each value values
      (array/push args value)))
  args)
(var exit-status 0)

(defn with-files [& patterns]
  (def out (sh/exec-slurp "git" "ls-files" "-z" ;patterns))
  (if (= out "")
    nil
    (string/split "\0" (string/slice out 0 (dec (length out))))))

(defn print-output [out err]
  (when (not= out "")
    (print out))
  (when (not= err "")
    (eprint err)))

(defn run! [& args]
  (def code
    (if quiet?
      (let [{:out out :err err :status status} (sh/exec-slurp-all ;args)]
        (when (not= status 0)
          (print-output out err))
        status)
      (sh/exec ;args)))
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
    (run! "alejandra" ;(flag-each "--exclude" emacs-vendored-nix) "-q" "-q" ;files)
    (run! "deadnix" "-_" "-L" "--edit" ;(flag-values "--exclude" emacs-vendored-nix))
    (run! "statix" "fix" ;(flag-values "--ignore" emacs-vendored-nix) "--" ".")))

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
(let [files (with-files
              "*.sh" "*.bash" "*.envrc" "*.envrc.*")]
  (when files
    (run! "shfmt" "-w" "-i" "2" "-s" ;files)))

# toml
(let [files (with-files "*.toml")]
  (when files
    (run! "taplo" "format" ;files)))

# yaml
(let [files (with-files "*.yaml" "*.yml")]
  (when files
    (run! "yamlfmt" ;files)))

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
