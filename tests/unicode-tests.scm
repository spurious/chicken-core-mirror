;;; unicode tests, taken from Chibi

(include "test.scm")
                           
(test-begin "unicode")

(test-equal #\Р (string-ref "Русский" 0))
(test-equal #\и (string-ref "Русский" 5))
(test-equal #\й (string-ref "Русский" 6))

(test-equal 7 (string-length "Русский"))

(test-equal #\日 (string-ref "日本語" 0))
(test-equal #\本 (string-ref "日本語" 1))
(test-equal #\語 (string-ref "日本語" 2))

(test-equal 3 (string-length "日本語"))

(test-equal '(#\日 #\本 #\語) (string->list "日本語"))
(test-equal "日本語" (list->string '(#\日 #\本 #\語)))

(test-equal "日本" (substring "日本語" 0 2))
(test-equal "本語" (substring "日本語" 1 3))

(test-equal "日-語"
      (let ((s (substring "日本語" 0 3)))
        (string-set! s 1 #\-)
        s))

(test-equal "日本人"
      (let ((s (substring "日本語" 0 3)))
        (string-set! s 2 #\人)
        s))

(test-equal "字字字" (make-string 3 #\字))

(test-equal "字字字"
      (let ((s (make-string 3)))
        (string-fill! s #\字)
        s))

(test-end)
(test-exit)
