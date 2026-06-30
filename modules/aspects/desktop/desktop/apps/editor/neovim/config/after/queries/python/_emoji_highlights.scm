; extends

(not_operator
 "not" @keyword.operator
 (#set! conceal "🙅"))

(boolean_operator
 "and" @keyword.operator
 (#set! conceal "🤝"))

(boolean_operator
 "or" @keyword.operator
 (#set! conceal "🤷"))

; Control flow
(if_statement "if" @keyword.conditional
 (#set! conceal "🚦"))

(for_statement "for" @keyword.repeat
 (#set! conceal "🔁"))

(while_statement "while" @keyword.repeat
 (#set! conceal "🔄"))

(match_statement "match" @keyword.conditional
 (#set! conceal "❔"))

(elif_clause "elif" @keyword.conditional
 (#set! conceal "🚧"))

(else_clause "else" @keyword.conditional
 (#set! conceal "🛑"))

(case_clause "case" @keyword.conditional
 (#set! conceal "🧩"))

(try_statement "try" @keyword.exception
 (#set! conceal "🧪"))

(except_clause "except" @keyword.exception
 (#set! conceal "🧯"))

(finally_clause "finally" @keyword.exception
 (#set! conceal "🏁"))

(with_statement "with" @keyword
 (#set! conceal "📦"))

(assert_statement "assert" @keyword
 (#set! conceal "✅"))

(pass_statement "pass" @keyword
 (#set! conceal "💤"))

(continue_statement "continue" @keyword
 (#set! conceal "🔂"))

(break_statement "break" @keyword
 (#set! conceal "✋"))

(delete_statement "del" @keyword
 (#set! conceal "❌"))

(global_statement "global" @keyword
 (#set! conceal "🌐"))

(nonlocal_statement "nonlocal" @keyword
 (#set! conceal "🏠"))

; Membership / identity
(comparison_operator
 "not in" @keyword.operator
 (#set! conceal "🚫"))

(comparison_operator
 "in" @keyword.operator
 (#set! conceal "📍"))

(for_statement
 "in" @keyword.operator
 (#set! conceal "📍"))

(comparison_operator
 "is not" @keyword.operator
 (#set! conceal "🚷"))

(comparison_operator
 "is" @keyword.operator
 (#set! conceal "🆔"))

; Function-ish things
(lambda
 "lambda" @keyword.function
 (#set! conceal "🐑"))

(function_definition
 "def" @keyword.function
 (#set! conceal "🔧"))

(function_definition
 "->" @punctuation.special
 (#set! conceal "🎯"))

(class_definition
 "class" @keyword.type
 (#set! conceal "🏛"))

(type_alias_statement
 "type" @keyword.type
 (#set! conceal "🏷"))

(return_statement
 "return" @keyword.return
 (#set! conceal "🔙"))

(yield "yield" @keyword.return
 (#set! conceal "🎁"))

(raise_statement
 "raise" @keyword.exception
 (#set! conceal "🚀"))

; Async / await
(function_definition "async" @keyword.coroutine
 (#set! conceal "🌀"))

(for_statement "async" @keyword.coroutine
 (#set! conceal "🌀"))

(with_statement "async" @keyword.coroutine
 (#set! conceal "🌀"))

(await "await" @keyword.coroutine
 (#set! conceal "⏳"))

; Imports / aliasing
(import_from_statement "from" @keyword.import
 (#set! conceal "📥"))

(import_from_statement "import" @keyword.import
 (#set! conceal "📦"))

(import_statement "import" @keyword.import
 (#set! conceal "📦"))

(aliased_import "as" @keyword
 (#set! conceal "🏷"))

; Constants
((none) @constant.builtin
 (#set! conceal "🕳"))

((true) @boolean
 (#set! conceal "👍"))

((false) @boolean
 (#set! conceal "👎"))

((ellipsis) @punctuation.special
 (#set! conceal "🔜"))

; Type constructors
(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "list")
 (#set! conceal "📋"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "dict")
 (#set! conceal "🗺"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Union")
 (#set! conceal "🤷"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "tuple")
 (#set! conceal "📎"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "set")
 (#set! conceal "🧺"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "frozenset")
 (#set! conceal "🧊"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Callable")
 (#set! conceal "☎"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Iterator")
 (#set! conceal "🔄"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Iterable")
 (#set! conceal "🔄"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Literal")
 (#set! conceal "🏷"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Any")
 (#set! conceal "🌟"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Self")
 (#set! conceal "🪞"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Final")
 (#set! conceal "🔒"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "ClassVar")
 (#set! conceal "🧰"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Protocol")
 (#set! conceal "📜"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "ABC")
 (#set! conceal "🧱"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Optional")
 (#set! conceal "❓"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Annotated")
 (#set! conceal "📝"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Mapping")
 (#set! conceal "🗺"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Sequence")
 (#set! conceal "📋"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Generator")
 (#set! conceal "🌊"))

(subscript
 value: (identifier) @type.builtin
 (#eq? @type.builtin "Awaitable")
 (#set! conceal "⏳"))

; Python type annotations use generic_type instead of expression subscript.
(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "list")
 (#set! conceal "📋"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "dict")
 (#set! conceal "🗺"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Union")
 (#set! conceal "🤷"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "tuple")
 (#set! conceal "📎"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "set")
 (#set! conceal "🧺"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "frozenset")
 (#set! conceal "🧊"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Callable")
 (#set! conceal "☎"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Iterator")
 (#set! conceal "🔄"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Iterable")
 (#set! conceal "🔄"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Literal")
 (#set! conceal "🏷"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Any")
 (#set! conceal "🌟"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Self")
 (#set! conceal "🪞"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Final")
 (#set! conceal "🔒"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "ClassVar")
 (#set! conceal "🧰"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Protocol")
 (#set! conceal "📜"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "ABC")
 (#set! conceal "🧱"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Optional")
 (#set! conceal "❓"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Annotated")
 (#set! conceal "📝"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Mapping")
 (#set! conceal "🗺"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Sequence")
 (#set! conceal "📋"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Generator")
 (#set! conceal "🌊"))

(generic_type
 (identifier) @type.builtin
 (#eq? @type.builtin "Awaitable")
 (#set! conceal "⏳"))

; Bare typing names.
((identifier) @type.builtin
 (#eq? @type.builtin "Any")
 (#set! conceal "🌟"))

((identifier) @type.builtin
 (#eq? @type.builtin "Self")
 (#set! conceal "🪞"))

((identifier) @type.builtin
 (#eq? @type.builtin "Final")
 (#set! conceal "🔒"))

((identifier) @type.builtin
 (#eq? @type.builtin "ClassVar")
 (#set! conceal "🧰"))

((identifier) @type.builtin
 (#eq? @type.builtin "Protocol")
 (#set! conceal "📜"))

((identifier) @type.builtin
 (#eq? @type.builtin "ABC")
 (#set! conceal "🧱"))

((identifier) @type.builtin
 (#eq? @type.builtin "Optional")
 (#set! conceal "❓"))

((identifier) @type.builtin
 (#eq? @type.builtin "Annotated")
 (#set! conceal "📝"))

((identifier) @type.builtin
 (#eq? @type.builtin "Mapping")
 (#set! conceal "🗺"))

((identifier) @type.builtin
 (#eq? @type.builtin "Sequence")
 (#set! conceal "📋"))

((identifier) @type.builtin
 (#eq? @type.builtin "Generator")
 (#set! conceal "🌊"))

((identifier) @type.builtin
 (#eq? @type.builtin "Awaitable")
 (#set! conceal "⏳"))

; Optional unions.
(binary_operator
 left: (_)
 "|" @operator
 right: (none) @constant.builtin
 (#set! @operator conceal "❓")
 (#set! @constant.builtin conceal "")
 (#offset! @constant.builtin 0 -1 0 0)
 (#set! priority 130))

(binary_operator
 left: (none) @constant.builtin
 "|" @operator
 right: (_)
 (#set! @operator conceal "❓")
 (#set! @constant.builtin conceal "")
 (#offset! @constant.builtin 0 0 0 1)
 (#set! priority 130))

(union_type
 (type)
 "|" @operator
 (type (none) @constant.builtin)
 (#set! @operator conceal "❓")
 (#set! @constant.builtin conceal "")
 (#offset! @constant.builtin 0 -1 0 0)
 (#set! priority 130))

(union_type
 (type (none) @constant.builtin)
 "|" @operator
 (type)
 (#set! @operator conceal "❓")
 (#set! @constant.builtin conceal "")
 (#offset! @constant.builtin 0 0 0 1)
 (#set! priority 130))

; Type unions
(union_type
 (type (_) @_left)
 "|" @operator
 (type (_) @_right)
 (#not-eq? @_left "None")
 (#not-eq? @_right "None")
 (#set! @operator conceal "🤷"))

; Fallback for nested/generic annotation unions.
(binary_operator
 left: (_) @_left
 "|" @operator
 right: (_) @_right
 (#not-eq? @_left "None")
 (#not-eq? @_right "None")
 (#set! @operator conceal "🤷"))

; Operators
(assignment "=" @operator
 (#set! conceal "📌"))

(type_alias_statement "=" @operator
 (#set! conceal "📌"))

(default_parameter "=" @operator
 (#set! conceal "📌"))

(keyword_argument "=" @operator
 (#set! conceal "📌"))

(named_expression ":=" @operator
 (#set! conceal "🦭"))

(augmented_assignment "+=" @operator
 (#set! conceal "➕"))

(augmented_assignment "-=" @operator
 (#set! conceal "➖"))

(augmented_assignment "*=" @operator
 (#set! conceal "✖"))

(augmented_assignment "/=" @operator
 (#set! conceal "➗"))

(binary_operator "**" @operator
 (#set! conceal "🚀"))

(decorator
 "@" @punctuation.special
 (#set! conceal "🎩"))

; Comparisons
(comparison_operator "!=" @operator
 (#set! conceal "🙅"))

(comparison_operator "==" @operator
 (#set! conceal "🆔"))

(comparison_operator "<=" @operator
 (#set! conceal "📉"))

(comparison_operator ">=" @operator
 (#set! conceal "📈"))

; Builtin calls
(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "len")
 (#set! conceal "🔢"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "range")
 (#set! conceal "🔜"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "enumerate")
 (#set! conceal "🎫"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "zip")
 (#set! conceal "🧷"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "map")
 (#set! conceal "🗺"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "filter")
 (#set! conceal "🧹"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "sum")
 (#set! conceal "🧮"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "all")
 (#set! conceal "🔁"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "any")
 (#set! conceal "∃"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "isinstance")
 (#set! conceal "🪪"))

(call
 function: (identifier) @function.builtin
 (#eq? @function.builtin "issubclass")
 (#set! conceal "🪆"))

; Common receiver names
((identifier) @variable.builtin
 (#eq? @variable.builtin "self")
 (#set! conceal "🧍"))

((identifier) @variable.builtin
 (#eq? @variable.builtin "cls")
 (#set! conceal "🏫"))

; ; Optional: name-based helper conceal, can be noisy.
; ((identifier) @function.builtin
;  (#eq? @function.builtin "exists")
;  (#set! conceal "∃"))
