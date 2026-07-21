;; extends

; Same as the tsx variant: setter half of a useState/useReducer destructure
; is function-typed — render blue at the declaration site, above
; semantic-token priority.
(lexical_declaration
  (variable_declarator
    name: (array_pattern
      (identifier)
      (identifier) @function.setter)
    value: (call_expression
      function: (identifier) @_hook
      (#match? @_hook "^(useState|useReducer)$")
      (#set! priority 130))))
