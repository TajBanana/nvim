;; extends

; Annotation names get a semantic `function` token from kotlin-lsp (blue);
; IntelliJ Material Darker shows annotations purple italic. Re-capture them
; above semantic-token priority (125).
((annotation
  "@" @attribute
  (use_site_target)? @attribute)
 (#set! priority 130))

((annotation
  (user_type
    (type_identifier) @attribute))
 (#set! priority 130))

((annotation
  (constructor_invocation
    (user_type
      (type_identifier) @attribute)))
 (#set! priority 130))
