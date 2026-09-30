;; extends

; gc/gcc in a Helm template: comment with a TEMPLATE comment, {{/* ... */}},
; which renders to nothing. Neovim's commenting takes 'commentstring' from the
; deepest injected language at the cursor -- the YAML injected into the
; template's text -- so on a YAML line it used YAML's `# %s`, which the template
; still renders into its output. A capture's `bo.commentstring` metadata comes
; first, so it is set on the whole template (the root node). The `_` prefix
; keeps the capture out of highlighting.
((template) @_helm_template
  (#set! bo.commentstring "{{/* %s */}}"))
