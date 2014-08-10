;;;; compiler-namespace.scm - private namespace declarations for compiler units
;
; Copyright (c) 2009-2014, The CHICKEN Team
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


(private
 compiler
 analyze-expression
 all-import-libraries
 block-compilation
 bootstrap-mode
 broken-constant-nodes
 callback-names
 canonicalize-expression
 compile-format-string
 compiler-arguments
 compiler-source-file
 compiler-syntax-enabled
 constant-table
 constants-used
 create-foreign-stub
 csc-control-file
 current-program-size
 data-declarations
 debug-info-index
 debug-info-vector-name
 debug-lambda-list
 debug-variable-list
 debugging-chicken
 debugging-executable
 default-default-target-heap-size
 default-extended-bindings
 default-optimization-iterations
 default-output-filename
 default-standard-bindings
 defconstant-bindings
 dependency-list
 direct-call-ids
 disable-stack-overflow-checking
 emit-closure-info
 emit-control-file-item
 emit-profile
 emit-trace-info
 enable-inline-files
 enable-specialization
 expand-debug-assignment
 expand-debug-call
 expand-debug-lambda
 expand-foreign-callback-lambda
 expand-foreign-callback-lambda*
 expand-foreign-lambda
 expand-foreign-lambda*
 expand-foreign-primitive
 explicit-use-flag
 export-dump-hook
 extended-bindings
 external-protos-first
 external-to-pointer
 external-variables
 file-io-only
 file-requirements
 find-early-refs
 find-inlining-candidates
 first-analysis
 foldable-bindings
 foreign-callback-stubs
 foreign-callback-stub-argument-types
 foreign-callback-stub-body
 foreign-callback-stub-callback
 foreign-callback-stub-cps
 foreign-callback-stub-id
 foreign-callback-stub-name
 foreign-callback-stub-qualifiers
 foreign-callback-stub-return-type
 foreign-declarations
 foreign-lambda-stubs
 foreign-string-result-reserve
 foreign-stub-argument-types
 foreign-stub-argument-names
 foreign-stub-body
 foreign-stub-callback
 foreign-stub-cps
 foreign-stub-id
 foreign-stub-name
 foreign-stub-qualifiers
 foreign-stub-return-type
 foreign-type-table
 foreign-variables
 immutable-constants
 import-libraries
 initialize-compiler
 inline-locally
 inline-max-size
 inline-substitutions-enabled
 inline-table
 inline-table-used
 inlining
 insert-timer-checks
 installation-home
 internal-bindings
 line-number-database-2
 line-number-database-size
 lambda-literal-id
 lambda-literal-external
 lambda-literal-arguments
 lambda-literal-argument-count
 lambda-literal-rest-argument
 lambda-literal-rest-argument-mode
 lambda-literal-temporaries
 lambda-literal-unboxed-temporaries
 lambda-literal-callee-signatures
 lambda-literal-allocated
 lambda-literal-directly-called
 lambda-literal-closure-size
 lambda-literal-looping
 lambda-literal-customizable
 rest-argument-mode
 lambda-literal-body
 lambda-literal-direct
 local-definitions
 location-pointer-map
 no-argc-checks
 no-bound-checks
 no-global-procedure-checks
 enable-module-registration
 no-procedure-checks
 nonwinding-call/cc
 number-type
 optimization-iterations
 optimize-leaf-routines
 original-program-size
 parenthesis-synonyms
 pending-canonicalizations
 perform-closure-conversion
 perform-cps-conversion
 perform-inlining!
 postponed-initforms
 prepare-for-code-generation
 process-command-line
 process-declaration
 profile-info-vector-name
 profile-lambda-index
 profile-lambda-list
 profiled-procedures
 real-name-table
 register-unboxed-op
 require-imports-flag
 rest-parameters-promoted-to-vector
 safe-globals-flag
 source-filename
 standalone-executable
 standard-bindings
 strict-variable-types
 target-heap-size
 target-stack-size
 toplevel-lambda-id
 toplevel-scope
 undefine-shadowed-macros
 unit-name
 unlikely-variables
 unsafe
 update-line-number-database
 update-line-number-database!
 used-units
 verbose-mode) 
