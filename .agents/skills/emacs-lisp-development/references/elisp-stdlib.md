# Emacs Lisp Standard Library Reference

## Strings

| Function                                                        | Notes                                               |
| --------------------------------------------------------------- | --------------------------------------------------- |
| `(substring str start &optional end)`                           | Extract substring; end defaults to end of string    |
| `(concat &rest strings)`                                        | Join strings                                        |
| `(format fmt &rest args)`                                       | Printf-style formatting                             |
| `(string-match-p regexp str &optional start)`                   | Return non-nil if match; does not modify match data |
| `(string-match regexp str &optional start)`                     | Return match start index; sets match data           |
| `(match-string n &optional string)`                             | Return nth subexp from last match                   |
| `(replace-regexp-in-string regexp rep str)`                     | Return new string with replacements                 |
| `(replace-match replacement &optional fixedcase subexp string)` | Replace last match                                  |
| `(split-string str &optional separators omit-nulls)`            | Split into list                                     |
| `(string-trim str &optional trim-left trim-right)`              | Trim whitespace                                     |
| `(string-trim-left str)`                                        | Trim leading                                        |
| `(string-trim-right str)`                                       | Trim trailing                                       |
| `(string-prefix-p prefix str &optional ignore-case)`            | Predicate                                           |
| `(string-suffix-p suffix str &optional ignore-case)`            | Predicate                                           |
| `(string-equal s1 s2)`                                          | `string=` alias                                     |
| `(string-lessp s1 s2)`                                          | `string<` alias                                     |
| `(string-to-number str &optional base)`                         | Parse number                                        |
| `(number-to-string n)`                                          | Format number                                       |
| `(upcase str)` / `(downcase str)` / `(capitalize str)`          | Case conversion                                     |
| `(length str)`                                                  | Character length                                    |
| `(char-to-string c)` / `(string-to-char str)`                   | Character conversion                                |

`s.el` (if available): `s-split`, `s-join`, `s-trim`, `s-replace`, `s-match`, `s-contains?`, `s-starts-with?`, `s-ends-with?`.

## Lists

| Function                                              | Notes                                   |
| ----------------------------------------------------- | --------------------------------------- |
| `(car list)` / `(cdr list)`                           | First element / rest                    |
| `(cons a b)`                                          | Prepend or make pair                    |
| `(list &rest args)`                                   | Build proper list                       |
| `(append &rest lists)`                                | Concatenate lists (copies all but last) |
| `(push item place)`                                   | Macro: prepend to list variable         |
| `(pop place)`                                         | Macro: remove and return first element  |
| `(nth n list)`                                        | Zero-indexed access                     |
| `(last list &optional n)`                             | Last cons cell                          |
| `(butlast list &optional n)`                          | All but last n elements                 |
| `(reverse list)`                                      | Shallow copy reversed                   |
| `(sort list predicate)`                               | Destructive sort                        |
| `(mapcar fn list)`                                    | Apply fn, return new list               |
| `(mapc fn list)`                                      | Apply fn for side effects, return list  |
| `(mapconcat fn list sep)`                             | Map then join strings                   |
| `(alist-get key alist &optional remove default test)` | Lookup in alist                         |
| `(assoc key alist)`                                   | `(key . value)` pair                    |
| `(assq key alist)`                                    | `assoc` with `eq` test                  |
| `(rassoc value alist)`                                | Lookup by value                         |
| `(plist-get plist prop)`                              | Lookup in plist                         |
| `(plist-put plist prop val)`                          | Return new plist with value set         |

`seq.el` (works on lists, vectors, strings):

| Function                                | Notes                  |
| --------------------------------------- | ---------------------- |
| `(seq-map fn seq)`                      | Map over any sequence  |
| `(seq-filter pred seq)`                 | Keep matching          |
| `(seq-remove pred seq)`                 | Remove matching        |
| `(seq-reduce fn seq init)`              | Fold/reduce            |
| `(seq-find pred seq &optional default)` | First match            |
| `(seq-some pred seq)`                   | Non-nil if any match   |
| `(seq-every-p pred seq)`                | Non-nil if all match   |
| `(seq-contains seq elt &optional test)` | Membership test        |
| `(seq-length seq)`                      | Length of any sequence |
| `(seq-into seq type)`                   | Convert sequence type  |
| `(seq-concatenate type &rest seqs)`     | Concatenate into type  |

`cl-seq` (from `cl-lib`): `cl-remove-if`, `cl-remove-if-not`, `cl-sort`, `cl-position`, `cl-count`, `cl-substitute`.

## Buffers

| Function                                     | Notes                                  |
| -------------------------------------------- | -------------------------------------- |
| `(current-buffer)`                           | Return current buffer                  |
| `(get-buffer name)`                          | Find buffer by name (string or buffer) |
| `(get-buffer-create name)`                   | Find or create                         |
| `(with-current-buffer buffer &rest body)`    | Execute in buffer context              |
| `(save-excursion &rest body)`                | Save/restore point and buffer          |
| `(with-temp-buffer &rest body)`              | Execute in fresh temp buffer           |
| `(point)`                                    | Current position                       |
| `(point-min)` / `(point-max)`                | Accessible region bounds               |
| `(region-beginning)` / `(region-end)`        | Active region                          |
| `(goto-char pos)`                            | Move point                             |
| `(forward-char n)` / `(backward-char n)`     | Move by characters                     |
| `(forward-line n)`                           | Move by lines                          |
| `(insert &rest args)`                        | Insert at point                        |
| `(delete-region start end)`                  | Delete text                            |
| `(buffer-substring start end)`               | Extract text with properties           |
| `(buffer-substring-no-properties start end)` | Extract plain text                     |
| `(buffer-string)`                            | Entire buffer contents                 |
| `(buffer-name &optional buffer)`             | Buffer name                            |
| `(buffer-file-name &optional buffer)`        | Associated file path                   |
| `(kill-buffer buffer)`                       | Close buffer                           |
| `(set-buffer buffer)`                        | Switch (prefer `with-current-buffer`)  |
| `(bury-buffer &optional buffer)`             | Move to end of buffer list             |

## Files

| Function                                                                 | Notes                           |
| ------------------------------------------------------------------------ | ------------------------------- |
| `(expand-file-name name &optional dir)`                                  | Absolute path                   |
| `(file-exists-p filename)`                                               | Predicate                       |
| `(file-directory-p filename)`                                            | Predicate                       |
| `(file-readable-p filename)`                                             | Predicate                       |
| `(file-writable-p filename)`                                             | Predicate                       |
| `(directory-files dir &optional full match nosort)`                      | List directory                  |
| `(directory-files-recursively dir regexp &optional include-directories)` | Recursive listing               |
| `(find-file-noselect filename &optional nowarn rawfile wildcards)`       | Open without selecting          |
| `(write-region start end filename &optional append visit)`               | Write to file                   |
| `(insert-file-contents filename)`                                        | Insert file at point            |
| `(file-name-directory filename)`                                         | Directory part                  |
| `(file-name-nondirectory filename)`                                      | Filename part                   |
| `(file-name-extension filename &optional period)`                        | Extension                       |
| `(file-name-sans-extension filename)`                                    | Without extension               |
| `(file-name-base filename)`                                              | Without directory and extension |
| `(make-directory dir &optional parents)`                                 | Create directory                |

## Hash tables

| Function                                | Notes                                                      |
| --------------------------------------- | ---------------------------------------------------------- |
| `(make-hash-table &rest keyword-args)`  | Create; `:test` (`eq`/`eql`/`equal`), `:size`, `:weakness` |
| `(gethash key table &optional default)` | Lookup                                                     |
| `(puthash key value table)`             | Set                                                        |
| `(remhash key table)`                   | Remove                                                     |
| `(clrhash table)`                       | Clear all                                                  |
| `(maphash fn table)`                    | Iterate `(lambda (key value) ...)`                         |
| `(hash-table-count table)`              | Number of entries                                          |
| `(hash-table-p table)`                  | Predicate                                                  |
| `(copy-hash-table table)`               | Shallow copy                                               |

## Sequences (general)

| Function                   | Notes                             |
| -------------------------- | --------------------------------- |
| `(length seq)`             | Length of list, vector, or string |
| `(elt seq n)`              | Element at index                  |
| `(seq-length seq)`         | Works on any sequence             |
| `(seq-elt seq n)`          | Works on any sequence             |
| `(seq-map fn seq)`         | Map                               |
| `(seq-filter pred seq)`    | Filter                            |
| `(seq-reduce fn seq init)` | Reduce                            |

## Predicates

| Predicate                                           | True when                                    |
| --------------------------------------------------- | -------------------------------------------- |
| `(stringp obj)`                                     | String                                       |
| `(listp obj)`                                       | List (including nil)                         |
| `(consp obj)`                                       | Cons cell (excludes nil)                     |
| `(null obj)`                                        | nil                                          |
| `(vectorp obj)`                                     | Vector                                       |
| `(bufferp obj)`                                     | Buffer                                       |
| `(functionp obj)`                                   | Callable (function, lambda, byte-code, subr) |
| `(boundp symbol)`                                   | Symbol has a value                           |
| `(fboundp symbol)`                                  | Symbol has a function binding                |
| `(featurep feature)`                                | Feature is loaded                            |
| `(keywordp obj)`                                    | Keyword symbol (`:foo`)                      |
| `(integerp obj)` / `(floatp obj)` / `(numberp obj)` | Number types                                 |
| `(char-or-string-p obj)`                            | Character or string                          |
| `(hash-table-p obj)`                                | Hash table                                   |
| `(processp obj)`                                    | Process object                               |
| `(windowp obj)` / `(framep obj)`                    | Window or frame                              |
| `(file-exists-p filename)`                          | File exists                                  |
