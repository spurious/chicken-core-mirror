;;;; build dependency tree
;
; Copyright (c) 2017, The CHICKEN Team
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following
; conditions are met:
;
;   Redistributions of source code must retain the above copyright notice, this list of conditions and the following
;     disclaimer. 
;   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
;     disclaimer in the documentation and/or other materials provided with the distribution. 
;   Neither the name of the author nor the names of its contributors may be used to endorse or promote
;     products derived from this software without specific prior written permission. 
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
; AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.


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
  '(chicken 
    batch-driver
    core
    optimizer
    lfa2
    compiler-syntax
    scrutinizer
    support
    c-backend
    c-platform
    user-pass))

(define programs 
  '(chicken
    csc
    csi
    chicken-install
    chicken-uninstall
    chicken-status
    chicken-profile))

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
    eval-modules
    user-pass))

(define primitive-import-libraries
  '(chicken.base
    chicken.condition
    chicken.csi
    chicken.syntax
    chicken.time
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
    chicken.internal
    chicken.gc
    chicken.io
    chicken.keyword
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
    chicken.process-context.posix
    chicken.random 
    chicken.sort 
    chicken.string
    chicken.time.posix
    chicken.continuation
    chicken.eval
    chicken.file
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
  (append '(libchicken.a libchicken.so libchicken.so.symlink 
                         feathers)
          programs
          (map (o o-file rc-file) resource-files)
          (so-file (import-library import-libraries))))

;;XXX cygwin specifics

(abstract 'primary-libchicken)

(depends primary-libchicken
  libchicken.a libchicken.so)

(depends libchicken.a 
  ,(static-o-file (cons* 'runtime 'eval-modules 
                        libchicken-objects)))

(depends libchicken.so
  ,(o-file (cons 'runtime libchicken-objects)))

(depends libchicken-import-library libchicken.so)
    
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
  (append '(runtime eval-modules) libchicken-objects))
          
(for-each
  (lambda (f) (depends ,(c-file f) ,(scm-file f)))
  (append compiler-objects
          '(eval-modules)
          libchicken-objects
          programs
          (import-library import-libraries)))

(for-each
  (lambda (f)
    (depends ,(so-file f) ,(o-file f) libchicken.so))
  (import-library import-libraries))

(depends feathers feathers.in)
(depends chicken ,(o-file compiler-objects))

(for-each
  (lambda (f)
    (depends ,f ,(o-file (rc-file f)))
    (depends ,(o-file (rc-file f)) ,(rc-file f)))
  resource-files)

(depends chicken-uninstall 
  ,(o-file (rc-file 'chicken-uninstall)))

(depends chicken.c
  mini-srfi-1.scm
  chicken.compiler.batch-driver.import.scm
  chicken.compiler.c-platform.import.scm
  chicken.compiler.support.import.scm
  chicken.compiler.user-pass.import.scm
  chicken.process-context.import.scm
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
  chicken.process-context.import.scm
  chicken.pretty-print.import.scm 
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends c-platform.c
  mini-srfi-1.scm
  chicken.compiler.optimizer.import.scm
  chicken.compiler.support.import.scm
  chicken.compiler.core.import.scm
  chicken.process-context.import.scm
  chicken.internal.import.scm)

(depends c-backend.c
  mini-srfi-1.scm 
  chicken.compiler.c-platform.import.scm 
  chicken.compiler.support.import.scm 
  chicken.compiler.core.import.scm 
  chicken.bitwise.import.scm 
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
  chicken.internal.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm)

(depends scheduler.c	
  common-declarations.scm
  chicken.format.import.scm)

(depends scrutinizer.c
  mini-srfi-1.scm
  chicken.compiler.support.import.scm 
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
  chicken.format.import.scm)

(depends chicken-ffi-syntax.c
  common-declarations.scm
  mini-srfi-1.scm
  chicken.format.import.scm 
  chicken.internal.import.scm 
  chicken.string.import.scm)

(depends support.c
  mini-srfi-1.scm 
  chicken.bitwise.import.scm 
  chicken.blob.import.scm 
  chicken.condition.import.scm 
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
  common-declarations.scm
  mini-srfi-1.scm
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
  chicken.process-context.import.scm
  chicken.posix.import.scm 
  chicken.process.import.scm 
  chicken.string.import.scm)

(depends csi.c
  chicken.condition.import.scm 
  chicken.foreign.import.scm 
  chicken.format.import.scm 
  chicken.gc.import.scm 
  chicken.internal.import.scm 
  chicken.io.import.scm 
  chicken.keyword.import.scm 
  chicken.load.import.scm 
  chicken.platform.import.scm 
  chicken.port.import.scm 
  chicken.process-context.import.scm
  chicken.pretty-print.import.scm 
  chicken.repl.import.scm 
  chicken.sort.import.scm 
  chicken.string.import.scm 
  chicken.syntax.import.scm)

(depends chicken-profile.c
  chicken.internal.import.scm 
  chicken.posix.import.scm 
  chicken.sort.import.scm 
  chicken.process-context.import.scm
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
  chicken.process-context.import.scm
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
  egg-environment.scm 
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
  common-declarations.scm
  mini-srfi-1.scm
  chicken.platform.import.scm 
  chicken.internal.import.scm)

(depends srfi-4.c
  common-declarations.scm
  chicken.bitwise.import.scm 
  chicken.foreign.import.scm 
  chicken.gc.import.scm 
  chicken.platform.import.scm 
  chicken.syntax.import.scm)

(depends posixunix.c
  posix-common.scm
  posixunix.scm
  common-declarations.scm
  chicken.bitwise.import.scm 
  chicken.condition.import.scm 
  chicken.foreign.import.scm 
  chicken.memory.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.process-context.import.scm
  chicken.port.import.scm 
  chicken.time.import.scm)

(depends posixwin.c
  posix-common.scm
  posixwin.scm
  common-declarations.scm
  chicken.condition.import.scm 
  chicken.bitwise.import.scm 
  chicken.foreign.import.scm 
  chicken.memory.import.scm 
  chicken.pathname.import.scm 
  chicken.platform.import.scm 
  chicken.process-context.import.scm
  chicken.port.import.scm 
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends data-structures.c
  common-declarations.scm
  chicken.condition.import.scm 
  chicken.foreign.import.scm)

(depends expand.c
  synrules.scm
  common-declarations.scm
  chicken.blob.import.scm 
  chicken.condition.import.scm 
  chicken.keyword.import.scm 
  chicken.platform.import.scm 
  chicken.internal.import.scm)

(depends extras.c
  common-declarations.scm
  chicken.string.import.scm 
  chicken.time.import.scm)

(depends eval.c
  mini-srfi-1.scm
  egg-information.scm
  common-declarations.scm
  chicken.blob.import.scm 
  chicken.condition.import.scm 
  chicken.foreign.import.scm 
  chicken.internal.import.scm 
  chicken.keyword.import.scm 
  chicken.platform.import.scm 
  chicken.syntax.import.scm)

(depends irregex.c 
  irregex-core.scm
  irregex-utils.scm
  common-declarations.scm
  chicken.syntax.import.scm)

(depends repl.c	
  common-declarations.scm
  chicken.eval.import.scm)

(depends stub.c common-declarations.scm)
(depends profiler.c common-declarations.scm)
(depends pathname.c common-declarations.scm)

(depends debugger-client.c 
  common-declarations.scm
  dbg-stub.c)

(depends file.c
  common-declarations.scm
  chicken.io.import.scm 
  chicken.irregex.import.scm 
  chicken.foreign.import.scm 
  chicken.pathname.import.scm 
  chicken.process-context.import.scm
  chicken.condition.import.scm)

(depends lolevel.c	
  common-declarations.scm
  chicken.foreign.import.scm)

(depends pathname.c
  common-declarations.scm
  chicken.irregex.import.scm 
  chicken.platform.import.scm 
  chicken.string.import.scm)

(depends port.c	
  common-declarations.scm
  chicken.io.import.scm)

(depends read-syntax.c
  chicken.internal.import.scm 
  chicken.platform.import.scm)

(depends tcp.c
  common-declarations.scm
  chicken.foreign.import.scm 
  chicken.port.import.scm 
  chicken.time.import.scm)

(depends continuation.c common-declarations.scm)

(depends internal.c mini-srfi-1.scm)
(depends read-syntax.c common-declarations.scm)

(depends eval-modules.c
  ,(scm-file (cons* 'eval-modules 
                    'common-declarations
                    (import-library import-libraries))))

(depends chicken.compiler.user-pass.import.c user-pass.c)
(depends srfi-4.import.c srfi-4.c)

(depends ,(scm-file (import-library '(chicken.bitwise
                                    chicken.fixnum
                                    chicken.flonum
                                    chicken.gc
                                    chicken.keyword
                                    chicken.blob
                                    chicken.platform 
                                    chicken.process-context
                                    chicken.plist)))
  library.c)

(depends ,(scm-file (import-library '(chicken.file.posix
                                    chicken.posix 
                                    chicken.process 
                                    chicken.process.signal
                                    chicken.process-context.posix
                                    chicken.time.posix
                                    chicken.errno)))
  ,(if WINDOWS 'posixwin.c 'posixunix.c))

(depends ,(scm-file (import-library '(chicken.format
                                    chicken.io
                                    chicken.pretty-print
                                    chicken.random )))
  extras.c)

(depends chicken.internal.import.scm internal.c)

(depends (chicken.eval.import.scm chicken-load.import.scm)
  eval.c)

(depends (chicken.locative.import.scm
          chicken.memory.import.scm
          chicken.memory.representation.import.scm)
  lolevel.c)

(depends (chicken.sort.import.scm
          chicken.string.import.scm
          chicken.data-structures.scm)
  data-structures.c)

(depends chicken.continuation.import.scm continuation.c)
(depends chicken.file.import.scm file.c)
(depends chicken.irregex.import.scm irregex.c)
(depends chicken.pathname.import.scm pathname.c)
(depends chicken.port.import.scm port.c)
(depends chicken.read-syntax.import.scm read-syntax.c)
(depends chicken.repl.import.scm repl.c)
(depends chicken.tcp.import.scm tcp.c)
(depends chicken.compiler.support.scm support.c)
(depends chicken.compiler.compiler-syntax.import.scm compiler-syntax.c)
(depends chicken.compiler.core.import.scm core.c)
(depends chicken.compiler.batch-driver.import.scm batch-driver.c)
(depends chicken.compiler.optimizer.import.scm optimizer.c)
(depends chicken.compiler.scrutinizer.import.scm scrutinizer.c)
(depends chicken.compiler.lfa2.import.scm lfa2.c)
(depends chicken.compiler.c-platform.import.scm c-platform.c)
(depends chicken.compiler.c-backend.import.scm c-backend.c)
(depends chicken.compiler.user-pass.import.scm user-pass.c)
(depends chicken.compiler.support.import.scm support.c)

(depends build-version.c buildversion)


;;XXX windows implib (.dll.a)


;; build commands

(ld 'libchicken.so
  (map o-file (cons 'runtime libchicken-objects)))

(static-ld 'libchicken.a
  (map static-o-file (cons* 'runtime 'eval-modules 
                           libchicken-objects)))

(for-each (cut rc <>) resource-files)

(define (sans lst . xs)
  (remove (cut memq <> xs) lst))

(for-each
  (lambda (p)
    (ld p (list (o-file p) 'primary-libchicken)))
  (sans programs 'chicken))

(ld 'chicken 
  (append (o-file compiler-objects) '(primary-libchicken)))

(for-each
  (lambda (f)
    (let ((f (import-library f)))
      (cc f)
      (ld (so-file f) (cons (o-file f) 'primary-libchicken))))
  import-libraries)

(for-each
  (lambda (f)
    (cc f)
    (cc f (static-o-file f)))
  (append (sans programs 'chicken)
          '(runtime)
          libchicken-objects
          compiler-objects))

(cc 'eval-modules (static-o-file 'eval-modules))

(for-each chicken
  (append (sans programs 'chicken)
          compiler-objects
          '(eval-modules)
          (import-library import-libraries)
          libchicken-objects))

(put! 'posixunix.c 'source-file 'posix)
(put! 'posixwin.c 'source-file 'posix)

(construct 'feathers 'feathers.in)

(symlink 'libchicken.so 'libchicken.so.symlink)


;; conditionals

(conditional (! STATICBUILD) libchicken.so)

(conditional (! STATICBUILD) 
  ,@(so-file (import-library import-libraries)))

(unless WINDOWS
  (conditional NEEDS_RC
    ,@(o-file (rc-file resource-files))))

(conditional (! LIBCHICKEN_IMPORT_LIB)
  libchicken-import-library)

(conditional USES_SONAME
  libchicken.so.symlink)


;; options

(set! default-cc-options 
  '(#(C_COMPILER_OPTIONS) #(C_COMPILER_OPTIMIZATION_OPTIONS)))

(set! default-chicken-options
  '("-optimize-level" "2" "-include-path" "." 
                      "-include-path" #(SRCDIR)
                      "-inline" "-ignore-repository"
                      "-feature" "chicken-bootstrap"
                      #(EXTRA_CHICKEN_OPTIONS)))

(set! default-ld-options '(#(LINKER_OPTIONS)))

(chicken-options ,libchicken-objects
  "-explicit-use" "-no-trace")

(chicken-options library
  "-no-module-registration"
  "-emit-import-library" "chicken.bitwise"
  "-emit-import-library" "chicken.blob"
  "-emit-import-library" "chicken.fixnum"
  "-emit-import-library" "chicken.flonum"
  "-emit-import-library" "chicken.gc"
  "-emit-import-library" "chicken.keyword"
  "-emit-import-library" "chicken.platform"
  "-emit-import-library" "chicken.plist"
  "-emit-import-library" "chicken.process-context")

(chicken-options internal
  "-emit-import-library" "chicken.internal")

(chicken-options eval
  "-emit-import-library" "chicken.eval"
  "-emit-import-library" "chicken.load")

(chicken-options repl
  "-emit-import-library" "chicken.repl")

(chicken-options read-syntax
  "-emit-import-library" "chicken.read-syntax")

(chicken-options file
  "-emit-import-library" "chicken.file")

(chicken-options port
  "-emit-import-library" "chicken.port")

(chicken-options expand "-no-module-registration")

(chicken-options irregex
  "-emit-import-library" "chicken.irregex")

(chicken-options extras
  "-emit-import-library" "chicken.format"
  "-emit-import-library" "chicken.io"
  "-emit-import-library" "chicken.pretty-print"
  "-emit-import-library" "chicken.random")  

(chicken-options posixunix
  "-feature" "platform-unix"
  "-emit-import-library" "chicken.errno"
  "-emit-import-library" "chicken.file.posix"
  "-emit-import-library" "chicken.time.posix"
  "-emit-import-library" "chicken.process"
  "-emit-import-library" "chicken.process.signal"  
  "-emit-import-library" "chicken.process-context.posix"  
  "-emit-import-library" "chicken.posix")   

(chicken-options posixunix
  "-feature" "platform-windows"
  "-emit-import-library" "chicken.errno"
  "-emit-import-library" "chicken.file.posix"
  "-emit-import-library" "chicken.time.posix"
  "-emit-import-library" "chicken.process"
  "-emit-import-library" "chicken.process.signal"  
  "-emit-import-library" "chicken.process-context.posix"  
  "-emit-import-library" "chicken.posix")   

(chicken-options continuation
  "-emit-import-library" "chicken.continuation")

(chicken-options data-structures
  "-emit-import-library" "chicken.sort"
  "-emit-import-library" "chicken.string")

(chicken-options pathname
  "-emit-import-library" "chicken.pathname")

(chicken-options tcp
  "-emit-import-library" "chicken.tcp")

(chicken-options lolevel
  "-emit-import-library" "chicken.locative"
  "-emit-import-library" "chicken.memory"
  "-emit-import-library" "chicken.memory.representation")

(chicken-options pathname
  "-emit-import-library" "chicken.pathname")

(chicken-options srfi-4
  "-emit-import-library" "srfi-4")

(chicken-options ,programs
  "-no-lambda-info" #(EXTRA_CHICKEN_PROGRAM_OPTIONS))

(chicken-options ,(import-library import-libraries)
  "-feature" "chicken-compile-shared" "-dynamic" 
  "-no-trace")

(for-each
  (lambda (cf)
    (chicken-options ,cf
                     "-emit-import-library"
                     ,(symbol-append 'chicken.compiler. cf)))
  '(batch-driver c-backend compiler-syntax chicken
    core c-platform lfa2 optimizer scrutinizer support
    user-pass))

(ld-options libchicken.so
  #(LINKER_LINK_SHARED_LIBRARY_OPTIONS)
  #(LIBCHICKEN_SO_LINKER_OPTIONS)
  #(LIBRARIES))

(ld-options ,programs
  #(LINKER_LINK_SHARED_PROGRAM_OPTIONS)
  #(LINK_LIBCHICKEN)
  #(LIBRARIES))

(ld-options chicken-install #(CHICKEN_INSTALL_RC_O))
(ld-options chicken-uninstall #(CHICKEN_UNINSTALL_RC_O))

(ld-options ,(so-file (import-library import-libraries))
  #(LINKER_LINK_SHARED_DLOADABLE_OPTIONS))

(cc-options ,(append (o-file (cons 'runtime 
                                   libchicken-objects))
                     (static-o-file (cons 'runtime 
                                          libchicken-objects)))
  "-DC_BUILDING_LIBCHICKEN")

(cc-options ,(o-file (cons 'runtime libchicken-objects))
  #(C_COMPILER_SHARED_OPTIONS))

(cc-options ,(o-file (import-library import-libraries))
  "-DC_SHARED" #(C_COMPILER_SHARED_OPTIONS))


;; name mapping

(define (build-name-map)
  `((libchicken.a (lib #(PROGRAM_PREFIX) chicken
                       #(PROGRAM_SUFFIX) 
                       ,(if WINDOWS '.lib '.a)))
    (primary-libchicken (#(PRIMARY_LIBCHICKEN)))
    (libchicken-import-library (#(LIBCHICKEN_IMPORT_LIB)))
    (libchicken.so (#(LIBCHICKEN)))
    (libchicken.so.symlink (#(LIBCHICKEN) |.| #(BINARYVERSION)))
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
                '(chicken.h)
                (map rc-file resource-files)
                (map scm-file scheme-files)
                (map (o scm-file import-library) 
                  primitive-import-libraries)))
    ))
