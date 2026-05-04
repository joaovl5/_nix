# Emacs Lisp Standard Library Reference

## Strings

- **Basics:** `substring`, `concat`, `format`
- **Regex predicate:** `string-match-p` for boolean checks without match-data mutation
- **Captures:** `string-match` with `match-string` when you need capture groups
- **Replacement:** `replace-regexp-in-string`, `replace-match`
- **Splitting:** `split-string`, `string-trim`, `string-trim-left`, `string-trim-right`
- **Comparison:** `string-prefix-p`, `string-suffix-p`, `string-equal` (`string=`), `string-lessp` (`string<`)
- **Conversion:** `string-to-number`, `number-to-string`, `char-to-string`, `string-to-char`
- **Case:** `upcase`, `downcase`, `capitalize`
- **Length:** `length` returns character length for strings

## Lists

- **Basics:** `car`, `cdr`, `cons`, `list`
- **Append:** `append` copies all but the last list
- **Stack mutation:** `push`, `pop`
- **Access:** `nth`, `last`, `butlast`
- **Transforms:** `reverse`, `sort` where `sort` is destructive
- **Mapping:** `mapcar` returns a list
- **Side effects:** `mapc`
- **Map and join:** `mapconcat`
- **Alists:** `alist-get`, `assoc`, `assq`, `rassoc`
- **Plists:** `plist-get`, `plist-put`
- **`seq.el`:** `seq-map`, `seq-filter`, `seq-remove`, `seq-reduce`, `seq-find`
- **`seq.el`:** `seq-some`, `seq-every-p`, `seq-contains`, `seq-length`, `seq-into`, `seq-concatenate`
- **`cl-lib`:** `cl-remove-if`, `cl-remove-if-not`, `cl-sort`, `cl-position`, `cl-count`, `cl-substitute`

## Buffers

- **Lookup:** `current-buffer`, `get-buffer`, `get-buffer-create`
- **Context:** `with-current-buffer`, `set-buffer`; prefer `with-current-buffer`
- **Temporary state:** `save-excursion`, `with-temp-buffer`
- **Positions:** `point`, `point-min`, `point-max`, `region-beginning`, `region-end`
- **Movement:** `goto-char`, `forward-char`, `backward-char`, `forward-line`
- **Text changes:** `insert`, `delete-region`
- **Text reads:** `buffer-substring`, `buffer-substring-no-properties`, `buffer-string`
- **Lifecycle:** `buffer-name`, `buffer-file-name`, `kill-buffer`, `bury-buffer`

## Files

- **Paths:** `expand-file-name`, `file-name-directory`, `file-name-nondirectory`
- **Path parts:** `file-name-extension`, `file-name-sans-extension`, `file-name-base`
- **Predicates:** `file-exists-p`, `file-directory-p`, `file-readable-p`, `file-writable-p`
- **Listing:** `directory-files`, `directory-files-recursively`
- **Reading:** `find-file-noselect`, `insert-file-contents`
- **Writing:** `write-region`, `make-directory`

## Hash tables

- **Create:** `make-hash-table` with `:test`, `:size`, `:weakness`
- **Copy:** `copy-hash-table`
- **Access:** `gethash`, `puthash`, `remhash`, `clrhash`
- **Iteration:** `maphash`, `hash-table-count`
- **Predicate:** `hash-table-p`

## Sequences

- **Access:** `length`, `elt`, `seq-length`, `seq-elt`
- **Transforms:** `seq-map`, `seq-filter`, `seq-reduce`

## Predicates

- **Core types:** `stringp`, `listp`, `consp`, `null`, `vectorp`
- **Runtime objects:** `bufferp`, `hash-table-p`, `processp`, `windowp`, `framep`
- **Callable state:** `functionp`, `boundp`, `fboundp`, `featurep`
- **Symbol and number:** `keywordp`, `integerp`, `floatp`, `numberp`, `char-or-string-p`
- **Files:** `file-exists-p`
