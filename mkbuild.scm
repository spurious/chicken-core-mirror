;;;; build-script generator

(import (chicken) (chicken data-structures)
        (chicken plist) (chicken sort)
        (chicken pretty-print) (chicken format)
        (chicken port) (chicken string))


(include "mini-srfi-1.scm")


;; utilities

(define (join . args)
  (string-intersperse
    (map (lambda (part)
           (if (vector? part)
               (var part)
               (->string part)))
      (flatten args))))

(define (var x)
  (let ((x (->string (vector-ref x 0))))
    (if WINDOWS
        (string-append "%" x "%")
        (string-append "${" x "}"))))


;; configuration

(define WINDOWS #f)
  

;; platform properties

(define (windows . files)
  (if WINDOWS files '()))

(define (unix . files)
  (if (not WINDOWS) files '()))

(define ((extension ext) . files)
  (if (and (pair? files) (symbol? (car files)))
      (symbol-append (car files) ext)
      (map (lambda (f) (symbol-append f ext))
        (flatten files))))

(define c-file (extension '.c))
(define h-file (extension '.h))
(define o-file (extension '.o))
(define so-file (extension '.so))
(define rc-file (extension '.rc))
(define scm-file (extension '.scm))
(define static-o-file (extension '-static.o))
(define import-library (extension '.import))


;;; options

(define default-cc-options '())
(define default-chicken-options '())
(define default-ld-options '())

(define (add-options t opts prop defaults)
  (for-each
    (lambda (t)
      (put! t prop (append (get t prop defaults) opts)))
    (if (list? t) t (list t))))

(define-syntax cc-options
  (syntax-rules ()
    ((_ t opts ...)
     (add-options `t `(opts ...) 'cc-options 
                  default-cc-options))))

(define-syntax chicken-options
  (syntax-rules ()
    ((_ t opts ...)
     (add-options `t `(opts ...) 'chicken-options
                  default-chicken-options))))

(define-syntax ld-options
  (syntax-rules ()
    ((_ t opts ...)
     (add-options `t `(opts ...) 'ld-options
                  default-ld-options))))


;;; Build commands

(define (abstract . ts)
  (for-each (cut put! <> 'abstract #t) ts))

(define (build t proc)
  (for-each
    (lambda (t)
      (when (get t 'command)
        (error "multiple commands assigned" t))
      (put! t 'command proc))
    (if (list? t) t (list t))))

(define (cc f #!optional (outf (o-file f)))
  (build outf
         (lambda ()
           (let ((cf (c-file f))
                 (opts (get f 'cc-options
                            default-cc-options)))
             (if WINDOWS
                 (printf "%C_COMPILER% ~a -c -o ~a ~a" 
                         (join opts)
                         (real-name cf)
                         (real-name outf))
                 (printf "${C_COMPILER} ~a -c -o ~a ~a"
                         (join opts)
                         (real-name cf)
                         (real-name outf)))))))

(define (rc f #!optional (outf (o-file (rc-file f))))
  (build outf
         (lambda ()
           (if WINDOWS
               (printf "%RC_COMPILER% ~a ~a" 
                       (real-name (rc-file f))
                       (real-name outf))
               (printf "${RC_COMPILER} ~a ~a" 
                       (real-name (rc-file f))
                       (real-name outf))))))

(define (chicken f #!optional (outf (c-file f)))
  (build outf 
         (lambda ()
           (let ((opts (get f 'chicken-options 
                            default-chicken-options)))
             (if WINDOWS
                 (printf "%CHICKEN% ~a -output-file ~a ~a" 
                         (real-name (scm-file f))
                         (real-name outf)
                         (join opts))
                 (printf "${CHICKEN} ~a -output-file ~a ~a"
                         (real-name (scm-file f))
                         (real-name outf)
                         (join opts)))))))

(define (ld lib fs)
  (build lib
         (lambda ()
           (let ((opts (get lib 'ld-options 
                            default-ld-options)))
             (printf (if WINDOWS 
                         "%LINKER% ~a ~a -o ~a"
                         "${LINKER} ~a ~a -o ~a")
                     (join opts)
                     (join (map real-name fs))
                     (real-name lib))))))

(define (static-ld lib fs)
  (build lib
         (lambda ()
           (printf (if WINDOWS 
                       "%LIBRARIAN% %LIBRARIAN_OPTIONS% ~a ~a"
                       "${LIBRARIAN} ${LIBRARIAN_OPTIONS} ~a ~a")
                   (real-name lib)
                   (join (map (o real-name static-o-file) 
                           fs))))))

(define (symlink to from)
  (build to
         (lambda ()
           (printf "ln -sf ~a ~a"
                   (real-name from)
                   (real-name to)))))

(define (touch dest)
  (build dest
         (lambda ()
           (if WINDOWS
               (printf "cmd /c \"echo > ~a\""
                       (real-name dest))
               (printf "touch ~a" (real-name dest))))))

(define (generate dest script)
  (build dest
         (lambda ()
           (if WINDOWS
               (printf "cmd /c \"~a\"" (real-name script))
               (printf "~a" (real-name script))))))

(define (construct dest . pieces)
  (build dest
         (lambda ()
           (if WINDOWS
               (printf "cmd /c \"type ~a > ~a & echo wish %DATADIR%\\feathers.tcl %1 %2 %3 %4 %5 %6 %7 %8 %9 >> ~a\""
                       (join (map real-name pieces))
                       (real-name dest)
                       (real-name dest))
               (printf "sh -c \"cat ~a > ~a; echo exec wish ${DATADIR}/feathers.tcl -- >> ~a\""
                       (join (map real-name pieces))
                       (real-name dest)
                       (real-name dest))))))


;;; dependency buildup

(define (depends* target . sources)
  (for-each
    (lambda (t)
      (put! t 'depends
            (lset-union/eq? (get t 'depends '())
                            (flatten sources))))
    (if (list? target) (flatten target) (list target))))

(define-syntax depends
  (syntax-rules ()
    ((_ t sources ...)
     (depends* `t `(sources ...)))))


;;; conditional execution

(define-syntax conditional
  (syntax-rules ()
    ((_ (var) fs ...)
     (for-each (cut put! <> 'conditional '(var))
       `(fs ...)))
    ((_ (var val) fs ...)
     (for-each (cut put! <> 'conditional '(var val))
       `(fs ...)))
    ((_ var fs ...)
     (for-each (cut put! <> 'conditional 'var)
       `(fs ...)))))


;;XXX parameters:
;
; mkbuild: WINDOWS
;
; build: SRCDIR ARCH PLATFORM DEBUGBUILD PREFIX
;        <prgnames> <libname> STATICBUILD

(define name-map #f)
(define nl "\n")

(define (combine name)
  (cond ((pair? name)
         (apply string-append
                (map (lambda (part)
                       (if (vector? part)
                           (var part)
                           (combine part)))
                  name)))
        ((eq? '/ name) 
         (if WINDOWS 
             "\\"
             "/"))
        (else (->string name))))

(define (real-name x)
  (cond ((assq x name-map) =>
         (lambda (a) (combine (cadr a))))
        (else (->string x))))

(define (sort-targets)
  (let ((dag '()))
    (define (gather t seen)
      (when (memq t seen)
        (error "circular dependency" t seen))
      (let ((deps (get t 'depends '())))
        (set! dag (cons (cons t deps) dag))
        (let ((seen (cons t seen)))
          (for-each (cut gather <> seen) deps))))
    (for-each (cut gather <> '()) toplevel-targets)
    (reverse (topological-sort dag eq?))))

(define (emit-build-script name)
  (let ((dag (sort-targets))
        (out (open-output-file name #:binary)))
    (when WINDOWS (set! nl "\r\n"))
    (if WINDOWS
        (display "@echo off\r\nrem GENERATED BY mkbuild.scm\r\ncall config.bat\t\nif %SRCDIR == \"\" set SRCDIR=.\r\"\r\n" out))
        (display "#!/bin/sh\n# GENERATED BY mkbuild.scm\nset -e\n. config.sh\nif test \"${SRCDIR}\" = \"\"; then\n  SRCDIR=.\nfi\n" out)
    (for-each
      (lambda (t)
        (let ((cmd (get t 'command)))
          (when cmd
            (emit-build-rule t
                             (get t 'command) 
                             (get t 'depends '())
                             out))))
      dag)
    (if WINDOWS
        (display "rem END OF GENERATED FILE\r\n" out)
        (display "# END OF GENERATED FILE\n" out))
    (close-output-port out)))

(define (emit-build-rule t cmd deps out)
  (unless (get t 'abstract)
    (unless cmd 
      (error "missing command for target" t))
    (let ((c (get t 'conditional)))
      (when c
        (if (pair? c)
            (if (pair? (cdr c))
                (if WINDOWS
                    (fprintf out "if %~a% = ~a " (car c) (cadr c))
                    (fprintf out "test \"${~a}\" = ~a && " 
                             (car c) (cadr c)))
                (if WINDOWS
                    (fprintf out "if %~a% == \"\" " (car c))
                    (fprintf out "test -z \"${~a}\" && " (car c))))
            (if WINDOWS
                (fprintf out "if %~a% != \"\" " c)
                (fprintf out "test -n \"${~a}\" && " c)))))
    (if WINDOWS
        (fprintf out "chicken-do ~a " (real-name t))
        (fprintf out "./chicken-do ~a " (real-name t)))
    (with-output-to-port out cmd)
    (display " :" out)
    (for-each 
      (lambda (dep)
        (fprintf out " ~a" (real-name dep)))
      deps)
    (display nl out)))


;; command line

(define (mkbuild args)
  (let loop ((args args))
    (unless (null? args)
      (let ((arg (car args))
            (rest (cdr args)))
        (cond ((string=? "-windows" arg)
               (set! WINDOWS #t)
               (loop rest))
              ((string=? "-unix" arg)
               (set! WINDOWS #f)
               (loop rest))
              (else (error "unknown option" arg)))))
    (load "dependencies.scm")
    (set! name-map (build-name-map))
    (if WINDOWS
        (emit-build-script "build.bat")
        (emit-build-script "build.sh"))))


(mkbuild (command-line-arguments))
