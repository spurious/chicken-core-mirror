;;;; build-script generator

(import (chicken))


;; utilities

(define (join . args)
  (string-intersperse (map ->string (flatten args))))


;; configuration

(define WINDOWS #f)
(define EXE '||)
(define LIB '.a)
(define OBJ '.o)
(define DYLIB '#(DYLIB))
(define SO '.so)

(define (set-platform-vars)
  (cond (WINDOWS (set! EXE '.exe)
                 (set! LIB '.lib)
                 (set! OBJ '.obj)
                 (set! DYLIB '.dll)
                 (set! SO '.dll))))
  

;; platform properties

(define (windows . files)
  (if WINDOWS files '()))

(define (unix . files)
  (if (not WINDOWS) files '()))

(define ((extension ext) . files)
  (map (lambda (f) (symbol-append f ext))
    (flatten files)))

(define c-file (extension '.c))
(define o-file (extension '.o))
(define scm-file (extension '.scm))
(define static-o-file (extension'-static.o))


;;; Build commands

(define (build t proc)
  (when (get t 'command)
    (error "multiple commands assigned" t))
  (put! t 'command proc))

(define (cc cf #!key (out (o-file cf)) (options '()))
  (build outf 
         (lambda ()
           (let ((cf (c-file cf)))
             (if WINDOWS
                 (printf "%CC% ~a -o ~a -I. ~a" 
                         (real-name cf)
                         (real-name outf)
                         (join options))
                 (printf "${CC} ~a -o ~a -I. ~a"
                         (real-name cf)
                         (real-name outf)
                         (join options)))))))

(define (csc cf #!key (out (c-file cf)) (options '()))
  (build outf 
         (lambda ()
           (if WINDOWS
               (printf "%CHICKEN% ~a -optimize-level 2 -include-path . -include-path %SRCDIR% -inline -ignore-repository -feature chicken-bootstrap -output-file ~a -I. ~a" 
                       (real-name cf)
                       (real-name outf)
                       (join options))
               (printf "${CHICKEN} ~a -optimize-level 2 -include-path . -include-path ${SRCDIR} -inline -ignore-repository -feature chicken-bootstrap-output-file ~a -I. ~a"
                       (real-name cf)
                       (real-name outf)
                       (join options))))))

(define (link lib fs #!key (options '()))
  (build lib
         (lambda ()
           (if WINDOWS
               (printf "%LD% ~a -o ~a"
                       (join (map (o real-name o-file) fs))
                       (real-name lib))))))


;;; dependency buildup

(define (depends target . sources)
  (put! target 'depends
        (lset-union eq? (get target 'depends '())
                    (flatten sources))))


;;XXX parameters:
;
; mkbuild: WINDOWS
;
; build: SRCDIR ARCH PLATFORM DEBUGBUILD PREFIX
;        <prgnames> <libname> STATICBUILD


;XXX chicken-config.h generation


  
(define name-map #f)

(define (combine name)
  (define (var x)
    (let ((x (->string (vector ref x 0))))
      (if WINDOWS
          (string-append "%" x "%")
          (string-append "${" x "}"))))
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
    (topological-sort dag eq?)))

(define (emit-build-script name prefix)
  (let ((targets (sort-targets))
        (out (open-output-file name)))
    (with-input-from-file prefix
      (lambda ()
        (display (read-string #f) out)))
    (display "# GENERATED\n" out)
    (for-each
      (lambda (t)
        (emit-build-rule t
                         (get t 'command) 
                         (get t 'depends) 
                         out))
      targets)
    (display "# END OF GENERATED FILE\n" out)
    (close-output-port out)))

(define (emit-build-rule t cmd deps out)
  (if WINDOWS
      (fprintf out "chicken-do ~a " t)
      (fprintf out "./chicken-do ~a " t))
  (with-output-to-port out cmd)
  (display " :" out)
  (for-each 
    (lambda (dep)
      (fprintf out " ~a" dep))
    deps)
  (newline out))


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
    (set-platform-vars)
    (load "dependencies.scm")
    (set! name-map (build-name-map))
    (if WINDOWS
        (emit-build-script "build.bat"
                           "build-prefix-windows.bat")
        (emit-build-script "build.sh"
                           "build-prefix-unix.sh"))))


(mkbuild (command-line-arguments))
