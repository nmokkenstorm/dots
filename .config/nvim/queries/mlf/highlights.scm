; Keywords
[
  "use"
  "as"
  "main"
  "record"
  "def"
  "inline"
  "type"
  "token"
  "query"
  "procedure"
  "subscription"
  "error"
  "constrained"
] @keyword

; Primitive types
[
  "null"
  "boolean"
  "integer"
  "string"
  "bytes"
  "blob"
  "unknown"
] @type.builtin

; Type references
(reference_type
  (type_path) @type)

; Import paths
(use_statement
  path: (type_path) @namespace)

; Import items
(import_item
  name: (identifier) @type)

(import_item
  alias: (identifier) @type)

; Function/method names
(query_definition
  name: (identifier) @function)

(procedure_definition
  name: (identifier) @function)

(subscription_definition
  name: (identifier) @function)

; Record names
(record_definition
  name: (identifier) @type)

; Type definition names
(def_type_definition
  name: (identifier) @type)

(inline_type_definition
  name: (identifier) @type)

; Token names
(token_definition
  name: (identifier) @constant)

; Field names
(field
  name: (identifier) @property)

; Parameter names
(parameter
  name: (identifier) @variable.parameter)

; Error names
(error_definition
  name: (identifier) @constant)

; Literals
(string) @string
(number) @number
(boolean) @constant.builtin

; Comments
(doc_comment) @comment.documentation
(comment) @comment

; Annotations
"@" @punctuation.special

(annotation
  name: (identifier) @attribute)

(annotation_selectors
  (identifier) @namespace)

(annotation_arg
  name: (identifier) @property)

; Operators
[
  ":"
  "="
  "|"
  "*"
] @operator

; Delimiters
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
  "."
] @punctuation.delimiter
