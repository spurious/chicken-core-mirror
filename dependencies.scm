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

(define c-files '(dbg-stub runtime'))

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

(define resource-files ...)

(define toplevel-files
  (append '(libchicken.a libchicken.so)
          '(feathers)
          programs))

;;XXX manpages for programs (mangled) + feathers

;;XXX distfiles (generate here or separate script?)

;;XXX platform/arch-specific compiler options

;;XXX map symbolic names to composite names that are 
;;    parameterized/mangled (including "cyg...")

;;XXX distfiles

;;XXX all .c files depend on chicken.h + chicken-config.h

;;XXX differentiate between static and nonstatic objects

;;XXX libs: libchicken.a .so

;;XXX USES_SONAME
;;XXX relinking
;;XXX cygwin specifics

(depends libchicken.a 
  (map static-o-file libchicken-objects))

(depends libchicken.so
  (map o-file libchicken-objects)
    
(for-each
  (lambda (prg) 
    (depends prg (o-file prg) 'primary-libchicken))
  programs)

(for-each 
  (lambda (f)
    (depends (o-file f) (c-file f) headers))
  (append '(runtime) libchicken-objects programs
          compiler-objects
          (map (cut symbol-append <> '.import)
            import-libraries)))

(for-each
  (lambda (f) (depends (c-file f) (scm-file f)))
  (append compiler-objects libchicken-objects programs
          (map (cut symbol-append <> '.import)
            import-libraries)))

(depends 'feathers 'feathers.in)


;; build commands

(


;; name mapping

(define (build-name-map)
  `((primary-libchicken (#(PRIMARY_LIBCHICKEN)))
    (libchicken.a (lib #(PROGRAM_PREFIX) chicken
                       #(PROGRAM_SUFFIX) 
                       ,(if WINDOWS '.lib '.a)))
    (libchicken.so (lib #(PROGRAM_PREFIX) chicken 
                        #(PROGRAM_SUFFIX) 
                        ,(if WINDOWS '.dll '(#(DYLIB)))))
    (chicken (#(PROGRAM_PREFIX) chicken #(PROGRAM_SUFFIX) ,EXE))
    (csc (#(PROGRAM_PREFIX) csc #(PROGRAM_SUFFIX) ,EXE))
    (csi (#(PROGRAM_PREFIX) csi #(PROGRAM_SUFFIX) ,EXE))
    (chicken-profile (#(PROGRAM_PREFIX) chicken-profile #(PROGRAM_SUFFIX) ,EXE))
    (chicken-status (#(PROGRAM_PREFIX) chicken-status #(PROGRAM_SUFFIX) ,EXE))
    (chicken-install (#(PROGRAM_PREFIX) chicken-install #(PROGRAM_SUFFIX) ,EXE))
    (chicken-uninstall (#(PROGRAM_PREFIX) chicken-uninstall #(PROGRAM_SUFFIX) ,EXE))
    (feathers (#(PROGRAM_PREFIX) feathers #(PROGRAM_SUFFIX) ,EXE))
    (feathers.in (#(SRCDIR) / feathers.in))
    ,@(map (lambda (f) (list f `(#(SRCDIR) / ,f)))
        (append (map c-file c-files) 
                (map scm-file scheme-files)))
    ))
