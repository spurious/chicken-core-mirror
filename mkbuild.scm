;;;; build-script generator

(import (chicken) (chicken data-structures)
        (chicken plist) (chicken sort)
        (chicken pretty-print) (chicken format)
        (chicken port))


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
  (let ((x (->string (vector ref x 0))))
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
(define o-file (extension '.o))
(define so-file (extension '.so))
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
                 (printf "%CC% ~a -o ~a ~a" 
                         (real-name cf)
                         (real-name outf)
                         (join opts))
                 (printf "${CC} ~a -o ~a ~a"
                         (real-name cf)
                         (real-name outf)
                         (join opts)))))))

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
                         "%{LINKER} ~a ~a -o ~a")
                     (join (map (o real-name o-file) fs))
                     (join opts)
                     (real-name lib))))))

(define (static-ld lib fs)
  (build lib
         (lambda ()
           (printf (if WINDOWS 
                       "%LIBRARIAN% %LIBRARIAN_OPTIONS% ~a ~a"
                       "%{LIBRARIAN} ${LIBRARIAN_OPTIONS} ~a ~a")
                   (real-name lib)
                   (join (map (o real-name static-o-file) 
                           fs))))))


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
        ((eq? '/ part) 
         (if WINDOWS 
             "\\"
             "/"))
        (else (->string name))))

(define (real-name x)
  (cond ((assq x name-map) =>
         (lambda (a) (combine (cadr a))))
        (else (->string x))))

(define (sort-targets)
  (let ((dag (map (lambda (t)
                    (let ((deps (get t 'depends)))
                      (cons t deps)))
               toplevel-targets)))
    (reverse (topological-sort dag eq?))))

(define (emit-build-script name)
  (let ((dag (sort-targets))
        (out (open-output-file name)))
    (when WINDOWS (set! nl "\r\n"))
    (if WINDOWS
        (display "#!/bin/sh\nset -e\nif test \"${SRCDIR}\" == \"\"; then\n  SRCDIR=.\nfi\n" out)
        (display "@echo off\r\nif %SRCDIR == \"\" set SRCDIR=.\r\"" out))
    (fprintf out "# GENERATED BY mkbuild.scm~a" nl)
    (for-each
      (lambda (t)
        (emit-build-rule t
                         (get t 'command) 
                         (get t 'depends) 
                         out))
      dag)
    (fprintf out "# END OF GENERATED FILE~a" nl)
    (close-output-port out)))

(define (emit-build-rule t cmd deps out)
  (unless cmd 
    (error "missing command for target" t))
  (if WINDOWS
      (fprintf out "chicken-do ~a " t)
      (fprintf out "./chicken-do ~a " t))
  (with-output-to-port out cmd)
  (display " :" out)
  (for-each 
    (lambda (dep)
      (fprintf out " ~a" dep))
    deps)
  (display nl out))


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
