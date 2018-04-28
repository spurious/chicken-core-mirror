;;; csc interface tests

(import (chicken file)
        (chicken pathname)
        (chicken process)
        (chicken process-context)
        (chicken string))

(define-values (srcdir bindir testdir)
  (apply values (command-line-arguments)))

(define (realpath x #!optional (base (current-directory)))
  (normalize-pathname (make-pathname base x)))

(define (run x . args)
  (system* (string-intersperse (cons x args))))

(define cscp (realpath "csc" bindir))
(define chickenp (realpath "chicken" bindir))

(define (csc . args)
  (apply run cscp "-v" "-I.." 
         (string-append "-I" srcdir)
         "-compiler" chickenp 
         "-libdir" bindir args))

(csc (realpath "null.scm" testdir) "-t" "-o" "null.c")
(assert (file-exists? "null.c"))

(csc "null.c" "-c")
(assert (file-exists? "null.o"))

(csc "null.o")
(run (realpath "null"))
