# Emacs Lisp Standard Library Reference

## Strings

- Extract/join/format: `substring`, `concat`, `format`.
- Regex and match data: `string-match-p` for predicates without match-data mutation; `string-match` + `match-string` when you need captures; `replace-regexp-in-string` and `replace-match` for replacements.
- Splitting/trimming: `split-string`, `string-trim`, `string-trim-left`, `string-trim-right`.
- Predicates/order: `string-prefix-p`, `string-suffix-p`, `string-equal` (`string=`), `string-lessp` (`string<`).
- Conversion/case: `string-to-number`, `number-to-string`, `upcase`, `downcase`, `capitalize`, `char-to-string`, `string-to-char`.
- Length: `length` returns character length for strings.

## Lists

- Basics: `car`, `cdr`, `cons`, `list`, `append` (copies all but the last list).
- Stack-style mutation: `push`, `pop`.
- Access and shape: `nth`, `last`, `butlast`, `reverse`, `sort` (destructive).
- Mapping: `mapcar` returns a list; `mapc` is for side effects; `mapconcat` maps then joins strings.
- Alists: `alist-get`, `assoc`, `assq`, `rassoc`.
- Plists: `plist-get`, `plist-put`.
- `seq.el` works on lists, vectors, and strings: `seq-map`, `seq-filter`, `seq-remove`, `seq-reduce`, `seq-find`, `seq-some`, `seq-every-p`, `seq-contains`, `seq-length`, `seq-into`, `seq-concatenate`.
- `cl-lib` sequence helpers: `cl-remove-if`, `cl-remove-if-not`, `cl-sort`, `cl-position`, `cl-count`, `cl-substitute`.

## Buffers

- Buffer lookup/context: `current-buffer`, `get-buffer`, `get-buffer-create`, `with-current-buffer`, `set-buffer` (prefer `with-current-buffer`).
- Temporary state: `save-excursion`, `with-temp-buffer`.
- Positions and movement: `point`, `point-min`, `point-max`, `region-beginning`, `region-end`, `goto-char`, `forward-char`, `backward-char`, `forward-line`.
- Text changes/extraction: `insert`, `delete-region`, `buffer-substring`, `buffer-substring-no-properties`, `buffer-string`.
- Metadata/lifecycle: `buffer-name`, `buffer-file-name`, `kill-buffer`, `bury-buffer`.

## Files

- Paths: `expand-file-name`, `file-name-directory`, `file-name-nondirectory`, `file-name-extension`, `file-name-sans-extension`, `file-name-base`.
- Predicates: `file-exists-p`, `file-directory-p`, `file-readable-p`, `file-writable-p`.
- Directory listing: `directory-files`, `directory-files-recursively`.
- Reading/opening: `find-file-noselect`, `insert-file-contents`.
- Writing/creating: `write-region`, `make-directory`.

## Hash tables

- Create/copy: `make-hash-table` (`:test`, `:size`, `:weakness`), `copy-hash-table`.
- Access/update: `gethash`, `puthash`, `remhash`, `clrhash`.
- Iterate/count: `maphash`, `hash-table-count`.
- Predicate: `hash-table-p`.

## Sequences

- Generic access: `length`, `elt`, `seq-length`, `seq-elt`.
- Generic transforms: `seq-map`, `seq-filter`, `seq-reduce`.

## Predicates

- Core types: `stringp`, `listp`, `consp`, `null`, `vectorp`, `bufferp`, `hash-table-p`, `processp`, `windowp`, `framep`.
- Callable/binding state: `functionp`, `boundp`, `fboundp`, `featurep`.
- Symbol/number helpers: `keywordp`, `integerp`, `floatp`, `numberp`, `char-or-string-p`.
- File existence: `file-exists-p`.
