;;;; build dependency tree


;;; leaf objects

(define headers '(chicken chicken-config))


;;; binaries

(define libchicken-objects
  `(library eval read-syntax repl data-structures pathname 
            port file extras lolevel tcp srfi-4 continuation
            ,@(windows 'posixwin) ,@(unix 'posixunix)
            internal irregex scheduler 
            debugger-client profiler stub expand modules 
            chicken-syntax chicken-ffi-syntax build-version
            runtime))

(define compiler-objects
  '(chicken batch-driver core optimizer lfa2 compiler-syntax
            scrutinizer support c-platform user-pass))

(define programs 
  '(chicken csc csi chicken-install chicken-uninstall
            chicken-status chicken-profile))

(define c-files '(dbg-stub runtime))

(define scheme-files
  '(banner
    batch-driver
    build-version
    c-backend
    c-platform
    chicken-ffi-syntax
    chicken-install
    chicken-profile
    chicken-status
    chicken-syntax
    chicken-uninstall
    chicken
    common-declarations
    compiler-syntax
    continuation
    core
    csc
    csi
    data-structures
    debugger-client
    egg-compile
    egg-download
    egg-environment
    egg-information
    eval
    expand
    extras
    file
    internal
    irregex-core
    irregex-utils
    irregex
    lfa2
    library
    lolevel
    mini-srfi-1
    modules
    optimizer
    pathname
    port
    posix-common
    posix
    posixunix
    posixwin
    profiler
    read-syntax
    repl
    scheduler
    scrutinizer
    srfi-4
    stub
    support
    synrules
    tcp
    tweaks
    user-pass))

(define import-libraries
  '(chicken.bitwise 
    chicken.blob
    chicken.errno
    chicken.file.posix
    chicken.fixnum
    chicken.flonum
    chicken.format
    chicken.gc
    chicken.io
    chicken.keyword
    chicken.base
    chicken.import
    chicken.load 
    chicken.locative
    chicken.memory
    chicken.memory.representation 
    chicken.platform 
    chicken.plist
    chicken.posix 
    chicken.pretty-print
    chicken.process 
    chicken.process.signal
    chicken.process-context
    chicken.random 
    chicken.syntax
    chicken.sort 
    chicken.string
    chicken.time 
    chicken.time.posix
    chicken 
    chicken.condition
    chicken.csi
    chicken.foreign
    srfi-4
    chicken.user-pass
    chicken.continuation
    chicken.data-structures
    chicken.eval
    chicken.file
    chicken.internal 
    chicken.irregex
    chicken.pathname
    chicken.port
    chicken.read-syntax
    chicken.repl
    chicken.tcp))

(define resource-files '())

(define toplevel-targets
  (append '(libchicken.a libchicken.so feathers)
          programs
          (so-file (import-library import-libraries))))

;;XXX manpages for programs (mangled) + feathers

;;XXX distfiles (generate here or separate script?)

;;XXX platform/arch-specific compiler options

;;XXX map symbolic names to composite names that are 
;;    parameterized/mangled (including "cyg...")

;;XXX distfiles

;;XXX USES_SONAME
;;XXX relinking
;;XXX cygwin specifics

(depends libchicken.a 
  ,(static-o-file libchicken-objects))

(depends libchicken.so
  ,(o-file libchicken-objects))
    
(depends ,programs ,(o-file prg) primary-libchicken)

(for-each
  (lambda (p)
    (depends ,(o-file f) ,(c-file f) ,@headers))
  (append '(runtime) 
          libchicken-objects
          programs
          compiler-objects
          (import-library import-libraries)))

(for-each
  (lambda (f) (depends ,(c-file f) ,(scm-file f)))
  (append compiler-objects
          libchicken-objects
          programs
          (import-library import-libraries)))

(depends feathers feathers.in)

(depends chicken (o-file compiler-objects))

;;XXX extra-dependencies (mostly .scm include files)

;;XXX windows implib (.dll.a)

;; build commands

;;XXX compiler, with differing options

(ld libchicken.so
  (map o-file libchicken-objects))

(static-ld libchicken.a
  (map static-o-file libchicken-objects))

;;XXX primary-libchicken

(for-each
  (lambda (p)
    (ld p (list (o-file p) primary-libchicken)))
  programs)

(for-each
  (lambda (f)
    (cc f)
    (cc f (static-o-file f)))
  (append programs
          libchicken-objects
          compiler-objects))

(for-each chicken
  (append programs
          (import-library import-libraries)
          libchicken-objects))


;; options

(set! default-cc-options 
  '("-DHAVE_CONFIG_H" "-I."))

(set! default-chicken-options
  '("-optimize-level" "2" "-include-path" "." 
                      "-include-path" #(SRCDIR))
                      "-inline" "-ignore-repository"
                      "-feature" "chicken-bootstrap"))

;; name mapping

(define (build-name-map)
  `((primary-libchicken (#(PRIMARY_LIBCHICKEN)))
    (libchicken.a (lib #(PROGRAM_PREFIX) chicken
                       #(PROGRAM_SUFFIX) 
                       ,(if WINDOWS '.lib '.a)))
    (libchicken.so (lib #(PROGRAM_PREFIX) chicken 
                        #(PROGRAM_SUFFIX) 
                        ,(if WINDOWS '.dll '(#(DYLIB)))))
    (chicken (#(PROGRAM_PREFIX) chicken #(PROGRAM_SUFFIX) #(EXE)))
    (csc (#(PROGRAM_PREFIX) csc #(PROGRAM_SUFFIX) #(EXE)))
    (csi (#(PROGRAM_PREFIX) csi #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-profile (#(PROGRAM_PREFIX) chicken-profile #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-status (#(PROGRAM_PREFIX) chicken-status #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-install (#(PROGRAM_PREFIX) chicken-install #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-uninstall (#(PROGRAM_PREFIX) chicken-uninstall #(PROGRAM_SUFFIX) #(EXE)))
    (feathers (#(PROGRAM_PREFIX) feathers #(PROGRAM_SUFFIX) #(EXE)))
    (feathers.in (#(SRCDIR) / feathers.in))
    ,@(map (lambda (f) (list f `(#(SRCDIR) / ,f)))
        (append (map c-file c-files) 
                (map scm-file scheme-files)))
    ))
