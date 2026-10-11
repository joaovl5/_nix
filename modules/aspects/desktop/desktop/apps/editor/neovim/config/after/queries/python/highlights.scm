; extends

; Temporary support until the Python parser recognizes lazy imports.
(_
  (ERROR
    . (identifier) @keyword.import .)
  .
  [
    (import_statement)
    (import_from_statement)
    (block
      . [
        (import_statement)
        (import_from_statement)
      ])
  ]
  (#eq? @keyword.import "lazy"))
