;;; csc interface tests

(import (chicken file)
        (chicken pathname)
        (chicken process)
        (chicken process-context)
        (chicken string))

(define-values (srcdir testdir)
  (let ((args (command-line-arguments)))
    (values (car args) (cadr args))))

(define (realpath x #!optional (base (current-directory)))
  (normalize-pathname (make-pathname base x)))

(define (run x . args)
  (system* (string-intersperse (cons x args))))

(define cscp (realpath "csc" srcdir))
(define chickenp (realpath "chicken" srcdir))

(define (csc . args)
  (apply run cscp "-v" "-I.." "-compiler" chickenp 
         "-libdir" srcdir args))

(csc (realpath "null.scm" testdir) "-t" "-o" "null.c")
(assert (file-exists? "null.c"))

(csc "null.c" "-c")
(assert (file-exists? "null.o"))

(csc "null.o")
(run (realpath "null"))
