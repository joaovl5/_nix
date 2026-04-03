; extends

(import_clause
  (identifier) @variable)

(import_specifier
  name: (identifier) @variable)

(import_specifier
  alias: (identifier) @variable)

(namespace_import
  (identifier) @module)

(import_statement
  "type"
  (import_clause
    (identifier) @type))

(import_statement
  "type"
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @type))))

(import_statement
  "type"
  (import_clause
    (named_imports
      (import_specifier
        alias: (identifier) @type))))


(import_statement
  "import" @keyword.import
  "from" @keyword.import)

(export_statement
  "export" @keyword.export)

(function_declaration
  "function" @keyword.function)