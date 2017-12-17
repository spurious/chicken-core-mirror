;;;; build dependency tree


;;; leaf objects

(define headers '(chicken chicken-config))


;;; binaries

(define libchicken-objects
  `(library 
    eval 
    read-syntax
    repl 
    data-structures
    pathname 
    port
    file 
    extras
    lolevel 
    tcp srfi-4 continuation
    ,@(windows 'posixwin) 
    ,@(unix 'posixunix)
    internal
    irregex 
    scheduler 
    debugger-client
    profiler
    stub 
    expand 
    modules 
    chicken-syntax 
    chicken-ffi-syntax
    build-version))

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

(define primitive-import-libraries
  '(chicken
    chicken.base
    chicken.condition
    chicken.csi
    chicken.foreign))

(define dynamic-import-libraries
  '(srfi-4
    chicken.bitwise 
    chicken.blob
    chicken.errno
    chicken.file.posix
    chicken.fixnum
    chicken.flonum
    chicken.format
    chicken.gc
    chicken.io
    chicken.keyword
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
    chicken.tcp
    chicken.compiler.user-pass))

(define compiler-import-libraries
  '(chicken.compiler.batch-driver
    chicken.compiler.c-backend
    chicken.compiler.chicken
    chicken.compiler.compiler-syntax
    chicken.compiler.core
    chicken.compiler.c-platform
    chicken.compiler.lfa2
    chicken.compiler.optimizer
    chicken.compiler.scrutinizer
    chicken.compiler.support
    chicken.compiler.user-pass))

(define import-libraries
  (append primitive-import-libraries 
          dynamic-import-libraries))

(define resource-files '(chicken-install chicken-uninstall))

(define toplevel-targets
  (append '(libchicken.a libchicken.so feathers)
          programs
          (map (o o-file rc-file) resource-files)
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
    
(for-each
  (lambda (prg)
    (depends ,prg ,(o-file prg) primary-libchicken))
  programs)

(for-each
  (lambda (f)
    (depends ,(o-file f) ,(c-file f) ,@(h-file headers)))
  (append '(runtime) 
          libchicken-objects
          programs
          compiler-objects
          (import-library import-libraries)))

(for-each
  (lambda (f)
    (depends ,(static-o-file f) ,(c-file f) 
             ,@(h-file headers)))
  (append '(runtime) libchicken-objects))
          
(for-each
  (lambda (f) (depends ,(c-file f) ,(scm-file f)))
  (append compiler-objects
          libchicken-objects
          programs
          (import-library import-libraries)))

(for-each
  (lambda (f)
    (depends ,(so-file f) ,(c-file f)))
  (import-library import-libraries))

(for-each
  (lambda (f)
    (depends ,(static-o-file f) ,(c-file f)))
  libchicken-objects)

(depends feathers feathers.in)
(depends chicken ,(o-file compiler-objects))
(depends libchicken.so.link libchicken.so)

(for-each
  (lambda (f)
    (depends ,f ,(o-file (rc-file f)))
    (depends ,(o-file (rc-file f)) ,(rc-file f)))
  resource-files)

(depends chicken-uninstall 
  ,(o-file (rc-file 'chicken-uninstall)))

(depends ,(map (o c-file import-library)
            '(chicken.posix
              chicken.errno
              chicken.process
              chicken.process.signal
              chicken.file.posix))
  ,(scm-file (if WINDOWS 'posixwin 'posixunix)))

(depends ,(map (o c-file import-library)
            '(chicken.bitwise
              chicken.blob
              chicken.fixnum
              chicken.flonum
              chicken.gc
              chicken.keyword
              chicken.platform
              chicken.plist
              chicken.time))
  ,(scm-file 'library))

(depends ,(c-file (import-library 'chicken.load))
  ,(scm-file 'eval))

(depends ,(c-file (import-library 'chicken.syntax))
  ,(scm-file 'expand))

(depends ,(map (o c-file import-library)
            '(chicken.format
              chicken.io
              chicken.pretty-print
              chicken.random))
  ,(scm-file 'extras))

(depends ,(map (o c-file import-library)
            '(chicken.sort
              chicken.string))
  ,(scm-file 'data-structures))

(depends ,(map (o c-file import-library)
            '(chicken.locative
              chicken.memory
              chicken.memory.representation
              chicken.random))
  ,(scm-file 'lolevel))

(depends chicken.c
  mini-srfi-1.scm
  chicken.compiler.batch-driver.import.scm
  chicken.compiler.c-platform.import.scm
  chicken.compiler.support.import.scm
  chicken.compiler.user-pass.import.scm
  chicken.string.import.scm)

(depends batch-driver.c
  mini-srfi-1.scm 
  chicken.compiler.core.import.scm 
  chicken.compiler.compiler-syntax.import.scm 
  chicken.compiler.optimizer.import.scm 
  chicken.compiler.scrutinizer.import.scm 
  chicken.compiler.c-platform.import.scm 
  chicken.compiler.lfa2.import.scm 
  chicken.compiler.c-backend.import.scm 
  chicken.compiler.support.import.scm 
  chicken.compiler.user-pass.import.scm 
  chicken.format.import.scm 
  chicken.gc.import.scm 
  chicken.internal.import.scm 
  chicken.load.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.pretty-print.import.scm 
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends c-platform.c
  mini-srfi-1.scm
  chicken.compiler.optimizer.import.scm
  chicken.compiler.support.import.scm
  chicken.compiler.core.import.scm
  chicken.data-structures.import.scm)

(depends c-backend.c
  mini-srfi-1.scm 
  chicken.compiler.c-platform.import.scm 
  chicken.compiler.support.import.scm 
  chicken.compiler.core.import.scm 
  chicken.bitwise.import.scm 
  chicken.data-structures.import.scm 
  chicken.flonum.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.internal.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends core.c
  mini-srfi-1.scm
  chicken.compiler.scrutinizer.import.scm 
  chicken.compiler.support.import.scm 
  chicken.data-structures.import.scm 
  chicken.eval.import.scm 
  chicken.format.import.scm 
  chicken.io.import.scm 
  chicken.keyword.import.scm 
  chicken.load.import.scm 
  chicken.pretty-print.import.scm 
  chicken.string.import.scm 
  chicken.syntax.import.scm)

(depends optimizer.c
  mini-srfi-1.scm 
  chicken.compiler.support.import.scm 
  chicken.data-structures.import.scm 
  chicken.internal.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm)

(depends scheduler.c	chicken.format.import.scm)

(depends scrutinizer.c
  mini-srfi-1.scm
  chicken.compiler.support.import.scm 
  chicken.data-structures.import.scm 
  chicken.format.import.scm 
  chicken.internal.import.scm 
  chicken.io.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.port.import.scm 
  chicken.pretty-print.import.scm 
  chicken.string.import.scm 
  chicken.syntax.import.scm)

(depends lfa2.c
  mini-srfi-1.scm 
  chicken.compiler.support.import.scm 
  chicken.format.import.scm)

(depends compiler-syntax.c
  mini-srfi-1.scm 
  chicken.compiler.support.import.scm 
  chicken.compiler.core.import.scm 
  chicken.data-structures.import.scm 
  chicken.format.import.scm)

(depends chicken-ffi-syntax.c
  chicken.format.import.scm 
  chicken.internal.import.scm 
  chicken.string.import.scm)

(depends support.c
  mini-srfi-1.scm 
  chicken.bitwise.import.scm 
  chicken.blob.import.scm 
  chicken.condition.import.scm 
  chicken.data-structures.import.scm 
  chicken.file.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.internal.import.scm 
  chicken.io.import.scm 
  chicken.keyword.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.plist.import.scm 
  chicken.port.import.scm 
  chicken.pretty-print.import.scm 
  chicken.random.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm 
  chicken.syntax.import.scm 
  chicken.time.import.scm)

(depends modules.c
  chicken.internal.import.scm 
  chicken.keyword.import.scm 
  chicken.load.import.scm 
  chicken.platform.import.scm 
  chicken.syntax.import.scm)

(depends csc.c
  chicken.file.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.io.import.scm 
  chicken.pathname.import.scm 
  chicken.posix.import.scm 
  chicken.process.import.scm 
  chicken.string.import.scm)

(depends csi.c
  chicken.condition.import.scm 
  chicken.data-structures.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.gc.import.scm 
  chicken.internal.import.scm 
  chicken.io.import.scm 
  chicken.keyword.import.scm 
  chicken.load.import.scm 
  chicken.platform.import.scm 
  chicken.port.import.scm 
  chicken.pretty-print.import.scm 
  chicken.repl.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm 
  chicken.syntax.import.scm)

(depends chicken-profile.c
  chicken.internal.import.scm 
  chicken.posix.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm)

(depends chicken-status.c
  mini-srfi-1.scm
  egg-environment.scm
  egg-information.scm
  chicken.file.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.irregex.import.scm 
  chicken.pathname.import.scm 
  chicken.port.import.scm 
  chicken.posix.import.scm 
  chicken.pretty-print.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm)

(depends chicken-install.c
  mini-srfi-1.scm
  egg-environment.scm
  egg-compile.scm
  egg-download.scm
  egg-information.scm
  chicken.condition.import.scm 
  chicken.data-structures.import.scm 
  chicken.file.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.io.import.scm 
  chicken.irregex.import.scm 
  chicken.pathname.import.scm 
  chicken.port.import.scm 
  chicken.posix.import.scm 
  chicken.pretty-print.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm 
  chicken.tcp.import.scm)

(depends chicken-uninstall.c
  mini-srfi-1.scm 
  egg-environment-scm 
  egg-information.scm
  chicken.file.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.irregex.import.scm 
  chicken.pathname.import.scm 
  chicken.port.import.scm 
  chicken.posix.import.scm 
  chicken.string.import.scm)

(depends chicken-syntax.c
  chicken.platform.import.scm 
  chicken.internal.import.scm)

(depends srfi-4.c
  chicken.bitwise.import.scm 
  chicken.foreign.import.scm 
  chicken.gc.import.scm 
  chicken.platform.import.scm 
  chicken.syntax.import.scm)

(depends posixunix.c
  chicken.bitwise.import.scm 
  chicken.condition.import.scm 
  chicken.foreign.import.scm 
  chicken.memory.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.port.import.scm 
  chicken.time.import.scm)

(depends posixwin.c
  chicken.condition.import.scm 
  chicken.bitwise.import.scm 
  chicken.foreign.import.scm 
  chicken.memory.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.port.import.scm 
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends data-structures.c
  chicken.condition.import.scm 
  chicken.foreign.import.scm)

(depends expand.c
  chicken.blob.import.scm 
  chicken.condition.import.scm 
  chicken.keyword.import.scm 
  chicken.platform.import.scm 
  chicken.internal.import.scm)

(depends extras.c
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends eval.c
  chicken.blob.import.scm 
  chicken.condition.import.scm 
  chicken.foreign.import.scm 
  chicken.internal.import.scm 
  chicken.keyword.import.scm 
  chicken.platform.import.scm 
  chicken.syntax.import.scm)

(depends irregex.c chicken.syntax.import.scm)

(depends repl.c	chicken.eval.import.scm)

(depends file.c
  chicken.io.import.scm 
  chicken.irregex.import.scm 
  chicken.foreign.import.scm 
  chicken.pathname.import.scm 
  chicken.posix.import.scm)

(depends lolevel.c	chicken.foreign.import.scm)

(depends pathname.c
  chicken.irregex.import.scm 
  chicken.platform.import.scm 
  chicken.string.import.scm)

(depends port.c	chicken.io.import.scm)

(depends read-syntax.c
  chicken.internal.import.scm 
  chicken.platform.import.scm)

(depends tcp.c
  chicken.foreign.import.scm 
  chicken.port.import.scm 
  chicken.time.import.scm)


;;XXX windows implib (.dll.a)


;; build commands

;;XXX compiler, with differing options

(ld 'libchicken.so
  (map o-file libchicken-objects))

(static-ld 'libchicken.a
  (map static-o-file libchicken-objects))

(for-each (cut rc <>) resource-files)

(unless WINDOWS
  (symlink 'libchicken.so.link 'libchicken.so))

(for-each
  (lambda (p)
    (ld p (list (o-file p) 'primary-libchicken)))
  programs)

(for-each
  (lambda (f)
    (cc f)
    (cc f (static-o-file f)))
  (append (remove (cut eq? <> 'chicken) programs)
          libchicken-objects
          compiler-objects))

(for-each chicken
  (append (remove (cut eq? <> 'chicken) programs)
          compiler-objects
          (import-library import-libraries)
          libchicken-objects))

(construct 'feathers 'feathers.in)


;; conditionals

(conditional (STATICBUILD) libchicken.so)

(conditional (STATICBUILD) 
  ,@(so-file (import-library import-libraries)))

(conditional USES_SONAME libchicken.so.link)

(unless WINDOWS
  (conditional NEEDS_RC
    ,@(o-file (rc-file resource-files))))


;; options

;;XXX mac specific options, file extensions, commands

(set! default-cc-options 
  '(#(C_COMPILER_OPTIONS) #(C_COMPILER_OPTIMIZATION_OPTIONS)))

(set! default-chicken-options
  '("-optimize-level" "2" "-include-path" "." 
                      "-include-path" #(SRCDIR)
                      "-inline" "-ignore-repository"
                      "-feature" "chicken-bootstrap"))

(set! default-ld-options '(#(LINKER_OPTIONS)))

(ld-options libchicken-so
  #(LINKER_LINK_SHARED_LIBRARY_OPTIONS)
  #(LIBRARIES))

(ld-options ,programs
  #(LINKER_LINK_SHARED_PROGRAM_OPTIONS)
  #(STATIC_EXTRALIBS))

(ld-options chicken-install #(CHICKEN_INSTALL_RC_O))
(ld-options chicken-uninstall #(CHICKEN_UNINSTALL_RC_O))

(ld-options ,(so-file (import-library import-libraries))
  "-DC_SHARED" #(LINKER_LINK_SHARED_DLOADABLE_OPTIONS))

(cc-options ,(append (o-file libchicken-objects)
                     (static-o-file libchicken-objects))
  "-DC_BUILDING_LIBCHICKEN")

;;XXX install
;;XXX uninstall
    

;; name mapping

(define (build-name-map)
  `((primary-libchicken (#(PRIMARY_LIBCHICKEN)))
    (libchicken.a (lib #(PROGRAM_PREFIX) chicken
                       #(PROGRAM_SUFFIX) 
                       ,(if WINDOWS '.lib '.a)))
    (libchicken.so (lib #(PROGRAM_PREFIX) chicken 
                        #(PROGRAM_SUFFIX) 
                        ,(if WINDOWS '.dll '(#(DYLIB)))))
    (libchicken.so.link (lib #(PROGRAM_PREFIX) chicken
                             #(PROGRAM_SUFFIX)
                             #(BINARYVERSION)))
    (chicken (#(PROGRAM_PREFIX) chicken #(PROGRAM_SUFFIX) #(EXE)))
    (csc (#(PROGRAM_PREFIX) csc #(PROGRAM_SUFFIX) #(EXE)))
    (csi (#(PROGRAM_PREFIX) csi #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-profile (#(PROGRAM_PREFIX) chicken-profile #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-status (#(PROGRAM_PREFIX) chicken-status #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-install (#(PROGRAM_PREFIX) chicken-install #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-uninstall (#(PROGRAM_PREFIX) chicken-uninstall #(PROGRAM_SUFFIX) #(EXE)))
    (chicken-install.rc.o (#(CHICKEN_INSTALL_RC_O)))
    (chicken-uninstall.rc.o (#(CHICKEN_UNINSTALL_RC_O)))
    (feathers (#(PROGRAM_PREFIX) feathers #(PROGRAM_SUFFIX) #(BAT)))
    (feathers.in (#(SRCDIR) / feathers.in))
    (identify.sh (#(SRCDIR) / config / identify.sh))
    ,@(map (lambda (f) (list f `(#(SRCDIR) / ,f)))
        (append (map c-file c-files) 
                (map rc-file resource-files)
                (map scm-file scheme-files)))
    ))
