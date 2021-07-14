;;; export of syntax referring to reexported syntax binding
(import reexport-m4)
(print (baz))

;;; reexport of renamed syntax
(import reexport-m6)
(f:s1)                ; expands to s2, which is reexported and refers to "s2", which is also visible in this context as "f:s2"
(f:s2)

;; reexport of syntax using shadowed identifiers in new module (#1757)
(import reexport-m8)
(assert (equal? '(d c b a) (reexported-reverse '(a b c d))))
(assert (equal? '(d c b a) (reexported-local-reverse '(a b c d))))
