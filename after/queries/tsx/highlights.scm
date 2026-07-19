;; extends

; Setter half of a useState/useReducer destructure is function-typed:
; IntelliJ colors it blue at the declaration site. ts_ls only reports it
; as a plain variable there, so mark it via treesitter with a priority
; above semantic tokens (125).
(lexical_declaration
  (variable_declarator
    name: (array_pattern
      (identifier)
      (identifier) @function.setter)
    value: (call_expression
      function: (identifier) @_hook
      (#match? @_hook "^(useState|useReducer)$")
      (#set! priority 130))))
