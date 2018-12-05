;;; c-backend.scm - C-generating backend for the CHICKEN compiler
;
; Copyright (c) 2008-2018, The CHICKEN Team
; Copyright (c) 2000-2007, Felix L. Winkelmann
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


(declare
  (unit c-backend)
  (uses data-structures extras c-platform compiler internal support
        target))

(module chicken.compiler.c-backend
    (generate-code
     ;; For "foreign" (aka chicken-ffi-syntax):
     foreign-type-declaration)

(import scheme
	chicken.base
	chicken.bitwise
	chicken.fixnum
	chicken.flonum
	chicken.foreign
	chicken.format
	chicken.internal
	chicken.platform
	chicken.sort
	chicken.string
	chicken.time
	chicken.compiler.core
	chicken.compiler.c-platform
	chicken.compiler.support
        chicken.compiler.target)

(include "mini-srfi-1.scm")

;;; Write backend language forms to output-port:

(define (gen . data)
  (for-each generate-target-code data))

;; Hacky procedures to make certain names more suitable for use in C.
(define (backslashify s) (string-translate* (->string s) '(("\\" . "\\\\"))))
(define (uncommentify s) (string-translate* (->string s) '(("*/" . "*_/"))))
(define (c-identifier s) (string->c-identifier (->string s)))

;; Generate a sorted alist out of a symbol table
(define (table->sorted-alist t)
  (let ((alist '()))
    (hash-table-for-each
      (lambda (id ll)
	(set! alist
	  (cons (cons id ll) alist)))
      t)

    (sort! alist (lambda (p1 p2) (string<? (symbol->string (car p1))
					   (symbol->string (car p2)))))))

(define (name . parts)
  (string->symbol (apply conc parts)))

(define (tvar i)
  (string->symbol (conc "t" i)))

(define (->symbol x)
  (if (symbol? x) 
      x
      (string->symbol x)))

(define av-count 0)

(define (av-var)
  (let ((av (name "av" av-count)))
    (set! av-count (add1 av-count))
    av))

(define (tempvar)
  (let ((t (name "tp" av-count)))
    (set! av-count (add1 av-count))
    t))


;;; Generate target code:

(define (generate-code literals lliterals lambda-table out
                       source-file
                       user-supplied-options dynamic db 
                       dbg-info-table)
  (let ((lambda-table* (table->sorted-alist lambda-table)) ;; sort the symbol table to make the compiler output deterministic.
	(non-av-proc #f))

    ;; Some helper procedures
    (define (find-lambda id)
      (or (hash-table-ref lambda-table id)
	  (bomb "can't find lambda" id) ) )
    
    (define (expression node temps ll)
      
      (define (top-expr n i)
	(let ((subs (node-subexpressions n))
	      (params (node-parameters n)) )
	  (case (node-class n)

	    ((if)
	     (gen `(if (!= C_SCHEME_FALSE ,(expr (car subs) i))))
             (top-expr (cadr subs) i)
             (gen '(else))
             (top-expr (caddr subs) i)
             (gen '(endif)))

	    ((##core#bind) 
	     (let loop ((bs subs) (i i) (count (first params)))
	       (cond ((> count 0)
		      (gen `(set ,(tvar i) ,(expr (car bs) i)))
                      (loop (cdr bs) (add1 i) (sub1 count)) )
		     (else (top-expr (car bs) i))) ) ) 

	    ((##core#let_unboxed)
	     (gen `(set ,(first params) ,(expr (first subs) i)))
	     (top-expr (second subs) i))

	    ((##core#call) 
	     (let* ((args (cdr subs))
		    (n (length args))
		    (nc i)
		    (nf (add1 n)) 
		    (dbi (first params))
		    (safe-to-call (second params))
		    (p2 (pair? (cddr params)))
		    (name (and p2 (third params)))
		    (name-str (->string (source-info->string name)))
		    (call-id (and p2 (pair? (cdddr params)) (fourth params)))
		    (customizable (and call-id (fifth params)))
		    (empty-closure (and customizable (zero? (lambda-literal-closure-size (find-lambda call-id)))))
		    (fn (car subs)) )
	       (when name
		 (cond (emit-debug-info
			(when dbi
			  (gen `(call C_debugger (adr (elt ($ C_debug_info) ,dbi)) 
                                   c 
                                   ,(if non-av-proc '0 'av)))))
		       (emit-trace-info
			(gen `(call ($ C_trace) (string ,name-str))))))
	       (cond ((eq? '##core#proc (node-class fn))
		      (let* ((av2 (push-args args i 0))
                             (fpars (node-parameters fn)))
			(gen `(tailcall ($ ,(first fpars)) ,nf ,av2))))
		     (call-id
		      (cond ((and (eq? call-id (lambda-literal-id ll))
				  (lambda-literal-looping ll) )
			     (let* ((temps (lambda-literal-temporaries ll))
				    (ts (list-tabulate n (lambda (i) (+ temps nf i)))))
			       (for-each
				(lambda (arg tr)
				  (gen `(set ,(tvar tr) ,(expr arg i))))
				args ts)
			       (for-each
				(lambda (from to)
                                  (gen `(set ,(tvar to) ,(tvar from))))
				ts (list-tabulate n add1))
			       (unless customizable
                                 (gen `(set c ,nf)))
			       (gen '(goto loop))))
			    (else
			     (unless empty-closure
			       (gen `(set ,(tvar nc) ,(expr fn i))))
			     (cond (customizable
				    (gen `(tailcall ($ ,call-id)
                                             ,@(if empty-closure
                                                   '()
                                                   (list (tvar nc)))
                                             ,@(expr-args args i))))
				   (else
				    (let ((av2 (push-args args i (and (not empty-closure) (tvar nc)))))
				      (gen `(tailcall ($ ,call-id) ,nf ,av2))))))))
		     ((and (eq? '##core#global (node-class fn))
			   (not unsafe) 
			   (not no-procedure-checks)
			   (not safe-to-call))
		      (let* ((gparams (node-parameters fn))
			     (index (first gparams))
			     (safe (second gparams)) 
			     (block (third gparams)) 
			     (carg #f)
                             (tp (tempvar)))
			(gen `(let/proc ,tp
                                ,(cond (no-global-procedure-checks
                                        (set! carg
                                          (if block
                                              `(elt ($ lf) ,index)
                                              `(slot (elt ($ lf) ,index) 0)))
                                        `(slot ,carg 1))
                                      (block
                                        (set! carg `(elt ($ lf) ,index))
			                (if safe
				           `(C_fast_retrieve_proc ,carg)
				           `(C_retrieve2_symbol_proc ,carg 
                                              (string ,(##sys#symbol->qualified-string (fourth gparams))))))
                                      (safe
                                       (set! carg `(slot (elt ($ lf) ,index) 0)) 
                                       `(C_fast_retrieve_proc ,carg))
                                      (else
                                        (set! carg `(slot (elt ($ lf) ,index) 0)) 
                                        `(C_fast_retrieve_symbol_proc (elt ($ lf) ,index))))))
			(let ((av2 (push-args args i carg)))
  			  (gen `(tailcall ,tp ,nf ,av2)))))
		     (else
		      (gen `(set ,(tvar nc) ,(expr fn i)))
		      (let ((av2 (push-args args i (tvar nc))))
  		        (if (or unsafe no-procedure-checks safe-to-call)
			  (gen `(tailcall (cast proc (slot ,(tvar nc) 0)) ,nf ,av2))
			  (gen `(tailcall (cast proc (C_fast_retrieve_proc ,(tvar nc))) ,nf ,av2))))))))
	  
	    ((##core#recurse) 
	     (let* ([n (length subs)]
		    [nf (add1 n)]
		    [tailcall (first params)]
		    [call-id (second params)] 
		    [empty-closure (zero? (lambda-literal-closure-size ll))] )
	       (cond (tailcall
		      (let* ((temps (lambda-literal-temporaries ll))
			     (ts (list-tabulate n (cut + temps nf <>))))
			(for-each
			 (lambda (arg tr)
			   (gen `(set ,(tvar tr) ,(expr arg i))))
			 subs ts)
			(for-each
			 (lambda (from to)
                           (gen `(set ,(tvar to) ,(tvar from))))
			 ts (list-tabulate n add1))
			(gen '(goto loop))))
		     (else
		      (gen `(tailcall ($ ,call-id)
                                   ,(if empty-closure '() '(t0))
                                   ,@(expr-args subs i)))))))

	    ((##core#callunit)
	     ;; The code generated here does not use the extra temporary needed for standard calls, so we have
	     ;;  one unused variable:
	     (let* ((n (length subs))
		    (nf (+ n 1)) 
	            (av2 (push-args subs i 'C_SCHEME_UNDEFINED)))
	       (gen `(tailcall ($ ,(name "C_" (toplevel (first params))))
                           ,nf ,av2))))

	    ((##core#return)
	     (gen `(return ,(expr (first subs) i))))

            ((##core#debug-event)
	     (gen `(call ($ C_debugger) (adr (elt ($ C_debug_info) ,(first params)))
                           c ,(if non-av-proc '0 'av))))

	    ((##core#inline_update)
	     (let ((t (second params)))
	       (gen `(set ,(first params) (cast ,(foreign-type-declaration t) 
                                                ,((foreign-argument-conversion 
                                                   t)
                                                   (expr (first subs) i)))))))

	    ((##core#unboxed_set!)
	     (gen `(set ,(first params) ,(expr (first subs) i))))

	    ((##core#switch)
	     (gen `(switch ,(expr (first subs) i)))
             (do ((j (first params) (sub1 j))
                  (ps (cdr subs) (cddr ps)))
                 ((zero? j)
                  (gen '(default))
                  (top-expr (car ps) i)
                  (gen `(endswitch)))
                 (gen `(case ,(expr (car ps) i)))
                 (top-expr (cadr ps) i)))

            (else (bomb "bad toplevel expr" (node-class n))))))

      (define (expr n i)
	(let ((subs (node-subexpressions n))
	      (params (node-parameters n)) )
	  (case (node-class n)

	    ((##core#immediate)
	     (case (first params)
	       ((bool) (if (second params) 'C_SCHEME_TRUE 'C_SCHEME_FALSE))
	       ((char) `(C_make_character ,(char->integer (second params))))
	       ((nil) 'C_SCHEME_END_OF_LIST)
	       ((fix) `(C_fix ,(second params)))
	       ((eof) 'C_SCHEME_END_OF_FILE)
	       (else (bomb "bad immediate")) ) )

	    ((##core#literal) 
	     (let ((lit (first params)))
	       (if (vector? lit)
		   `(cast word ($ ,(name "li" (vector-ref lit 0))))
		   `(elt ($ lf) ,(first params)))))

	    ((##core#proc)
	     `(cast word ($ ,(first params))))

	    ((##core#provide)
             `(C_a_i_provide (adr a) 1 (elt ($ lf) ,(first params))))
	    ((##core#ref) 
             `(slot ,(expr (car subs) i) ,(first params)))

	    ((##core#unbox) 
	     `(slot ,(expr (car subs) i) 0))

	    ((##core#update_i)
	     `(set (slot ,(expr (car subs) i) ,(first params))
                ,(expr (cadr subs) i) ))

	    ((##core#update)
	     `(mutate ,(expr (car subs) i)
               ,(add1 (first params))
               ,(expr (cadr subs) i) ))

	    ((##core#updatebox_i)
	     `(set (slot ,(expr (car subs) i) 0)
                ,(expr (cadr subs) i)))

	    ((##core#updatebox)
	     `(mutate ,(expr (car subs) i) 1
               ,(expr (cadr subs) i) ))

	    ((##core#closure)
	     (let ((n (first params)))
	       `(closure ,n a ,@(map (cut expr <> i) subs))))

	    ((##core#box) 
	     `(box a ,(expr (car subs) i)))

	    ((##core#local)
             (tvar (first params)))

            ((##core#setlocal) 
	     `(set ,(tvar (first params)) ,(expr (car subs) i)))

	    ((##core#global)
	     (let ((index (first params))
		   (safe (second params)) 
		   (block (third params)) )
	       (cond (block
		      (if safe
			  `(elt ($ lf) ,index)
			  `(C_retrieve2 (elt ($ lf) ,index) 
                              (string ,(##sys#symbol->qualified-string
                                 (fourth params))))))
		     (safe `(slot (elt ($ lf) ,index) 0))
		     (else `(C_fast_retrieve (elt ($ lf) ,index))))))

	    ((##core#setglobal)
	     (let ((index (first params))
		   (block (second params)) 
		   (var (third params))
                   (exp (expr (car subs) i)))
	       (if block
		   `(mutate (adr (elt ($ lf) ,index)) 0 ,exp)
                   `(mutate (elt ($ lf) ,index) 1 ,exp))))

	    ((##core#setglobal_i)
	     (let ((index (first params))
		   (block (second params)) 
		   (var (third params)) )
	       (cond (block
		      `(set (elt ($ lf) ,index) ,(expr (car subs) i)))
		     (else
		      `(set (slot (elt ($ lf) ,index) 0)
                          ,(expr (car subs) i))))))

	    ((##core#undefined) 'C_SCHEME_UNDEFINED)

            ((##core#inline)
	     (cons (->symbol (first params)) (expr-args subs i)))

	    ((##core#inline_allocate)
	     (cons* (->symbol (first params))
                    '(adr a) (length subs)
                    (expr-args subs i)))

	    ((##core#inline_ref)
	     ((foreign-result-conversion (second params) 'a)
               `(inline ,(first params))))

	    ((##core#inline_loc_ref)
	     (let ((t (first params)))
	       ((foreign-result-conversion t 'a)
                 `(deref (cast (ptr ,(foreign-type-declaration t))
                               (C_data_pointer ,(expr (first subs) i)))))))
     
	    ((##core#inline_loc_update)
	     (let ((t (first params)))
	       `(begin 
                  (set (deref (cast (ptr ,(foreign-type-declaration t))
                                    (C_data_pointer ,(expr (first subs) i))))
                       ,((foreign-argument-conversion t) (expr (second subs) i)))
                  C_SCHEME_UNDEFINED)))

	    ((##core#unboxed_ref)
	     (first params))

	    ((##core#cond)
	     `(cond (!= C_SCHEME_FALSE ,(expr (first subs) i))
                    ,(expr (second subs) i)
                    ,(expr (third subs) i)))

     	    ((##core#direct_call) 
	     (let* ((args (cdr subs))
		    (n (length args))
		    (nf (add1 n))
		    (dbi (first params))
		    ;; (safe-to-call (second params))
		    (name (third params))
		    (name-str (->string (source-info->string name)))
		    (call-id (fourth params))
		    (demand (fifth params))
		    (allocating (not (zero? demand)))
		    (empty-closure (zero? (lambda-literal-closure-size (find-lambda call-id))))
		    (fn (car subs)) )
               `(call ,call-id
                      ,@(if allocating (list `(C_a_i (adr a) 
                                                     ,demand))
                            '())
                      ,@(if (not empty-closure)
                            (list (expr fn i))
                            '())
                      ,@(if (pair? args) (expr-args args i) '()))))

	    (else (bomb "bad expr" (node-class n))) ) ) )
    
      (define (expr-args args i)
        (map (cut expr <> i) args))

      (define (push-args args i selfarg)
	(let* ((n (length args))
               (av2 (av-var))
	       (avl (+ n (if selfarg 1 0)))
	       (caller-has-av? (not (or (lambda-literal-customizable ll)
					(lambda-literal-direct ll))))
	       (caller-argcount (lambda-literal-argument-count ll))
	       (caller-rest-mode (lambda-literal-rest-argument-mode ll)))
	  ;; Try to re-use argvector from current function if it is
	  ;; large enough.  push-args gets used only for functions in
	  ;; CPS context, so callee never returns to current function.
	  ;; And even so, av[] is already copied into temporaries.
	  (cond
	   ((or (not caller-has-av?)	     ; Argvec missing or
		(and (< caller-argcount avl) ; known to be too small?
		     (eq? caller-rest-mode 'none)))
	    (gen `(let/array ,av2 ,avl)))
	   ((>= caller-argcount avl)   ; Argvec known to be re-usable?
	    (gen `(let/ptr ,av2 av))) ; Re-use our own argvector
	   (else      ; Need to determine dynamically. This is slower.
	    (gen `(let/ptr ,av2))
	    (gen `(if (>= c ,avl))
                	`(set ,av2 av) ; Re-use our own argvector
	         '(else)
                 `(set ,av2 (C_alloc ,avl))
                 '(endif))))
	  (when selfarg (gen `(set (elt ,av2 0) ,selfarg)))
	  (do ((j (if selfarg 1 0) (add1 j))
	       (args args (cdr args)))
	      ((null? args))
	    (gen `(set (elt ,av2 ,j) ,(expr (car args) i))))
          av2))

      (top-expr node temps) )

    (define (header)
      (when external-protos-first
	(generate-foreign-callback-stub-prototypes foreign-callback-stubs) )
      (when (pair? foreign-declarations)
	(for-each (lambda (x) (gen `(inline ,x)))
           foreign-declarations) )
      (unless external-protos-first
	(generate-foreign-callback-stub-prototypes foreign-callback-stubs) ) )

    (define (declarations)
      (let ((n (length literals)))
        (gen `(declare static (ptr C_PTABLE_ENTRY) create_ptable))
	(for-each
	 (lambda (uu)
	   (gen `(declare extern noreturn void ,(name "C_" uu) (word c) ((ptr word) av))))
	 (map toplevel used-units))
	(unless (zero? n)
	  (gen `(define/array static word lf ,n)))
	(do ((i 0 (add1 i))
	     (llits lliterals (cdr llits)))
	    ((null? llits))
	  (let* ((ll (##sys#lambda-info->string (car llits)))
		 (llen (string-length ll)))
	    (gen `(define/array static aligned char ,(name "li" i)
                     ()
                     (C_lihdr ,(arithmetic-shift llen -16)
                              ,(bitwise-and #xff (arithmetic-shift llen -8))
                              ,(bitwise-and #xff llen))
                     ,@(let loop ((n 0))
                         (if (>= n llen)
                             '()
                             (cons (char->integer (string-ref ll n))
                                   (loop (add1 n)))))
                     ;; fill up with zeros to align following entry
                     ,@(make-list (- (bitwise-and #xfffff8 (+ llen 7)) llen) 0)))))))

    (define (prototypes)
      (for-each
       (lambda (p)
	 (let* ((id (car p))
		(ll (cdr p))
		(n (lambda-literal-argument-count ll))
		(customizable (lambda-literal-customizable ll))
		(empty-closure (and customizable (zero? (lambda-literal-closure-size ll))))
		(varlist (make-variable-list (if empty-closure (sub1 n) n) "t"))
		(rest (lambda-literal-rest-argument ll))
		(rest-mode (lambda-literal-rest-argument-mode ll))
		(direct (lambda-literal-direct ll))
		(allocated (lambda-literal-allocated ll)) )
            (define (args)
              (append
                (if customizable '() '((word c)))
                (if (and direct (not (zero? allocated)))
                    '(((ptr word) a))
                    '())
                (if (or customizable direct)
                      varlist
                      '(((ptr word) av)))))
            (cond ((not (eq? 'toplevel id))
                   (gen `(declare static 
                                  ,@(if direct '() '(noreturn))
                                  ,(if direct 'word 'void)
                                  ,id
                                  ,@(args))))
                  (else
                    (let ((uname (toplevel unit-name)))
                      (gen `(declare extern void ,(name "C_" uname)
                                     ,@(args))))))))
        lambda-table*))
 
    (define (trampolines)
      (let ([ns '()]
	    [nsr '()] 
	    [nsrv '()] )
	(define (restore n)
	  (do ((i 0 (add1 i))
	       (j (sub1 n) (sub1 j)))
	      ((>= i n))
	    (gen `(let ,(tvar i) (elt av ,j)))))
	(for-each
	 (lambda (p)
	   (let* ([id (car p)]
		  [ll (cdr p)]
		  [argc (lambda-literal-argument-count ll)]
		  [rest (lambda-literal-rest-argument ll)]
		  [rest-mode (lambda-literal-rest-argument-mode ll)]
		  [customizable (lambda-literal-customizable ll)]
		  [empty-closure (and customizable (zero? (lambda-literal-closure-size ll)))] )
	     (when empty-closure (set! argc (sub1 argc)))
	     (when (and (not (lambda-literal-direct ll)) customizable)
	       (gen `(define static void ,(name "tr" id)
                             (word c) ((ptr word) av)))
	       (restore argc)
	       (gen `(tailcall ($ ,id) ,@(make-argument-list argc 't))
                    '(end)))))
	 lambda-table*)))
  
    (define (literal-frame)
      (do ([i 0 (add1 i)]
	   [lits literals (cdr lits)] )
	  ((null? lits))
	(gen-lit (car lits) `(elt ($ lf) ,i))))

    (define (bad-literal lit)
      (bomb "type of literal not supported" lit) )

    (define (literal-size lit)
      (cond ((immediate? lit) 0)
	    ((big-fixnum? lit) 2)       ; immediate if fixnum, bignum see below
	    ((string? lit) 0)		; statically allocated
	    ((bignum? lit) 2)		; internal vector statically allocated
	    ((flonum? lit) words-per-flonum)
	    ((symbol? lit) 7)           ; size of symbol, and possibly a bucket
	    ((pair? lit) (+ 3 (literal-size (car lit)) (literal-size (cdr lit))))
	    ((vector? lit)
	     (+ 1 (vector-length lit)
                (foldl + 0 (map literal-size (vector->list lit)))))
	    ((block-variable-literal? lit) 0) ; excluded from generated code
	    ((##sys#immediate? lit) (bad-literal lit))
	    ((##core#inline "C_lambdainfop" lit) 0) ; statically allocated
	    ((##sys#bytevector? lit) (+ 2 (bytes->words (##sys#size lit))) ) ; drops "permanent" property!
	    ((##sys#generic-structure? lit)
	     (let ([n (##sys#size lit)])
	       (let loop ([i 0] [s (+ 2 n)])
		 (if (>= i n)
		     s
		     (loop (add1 i) (+ s (literal-size (##sys#slot lit i)))) ) ) ) )
	    ;; We could access rat/cplx slots directly, but let's not.
	    ((ratnum? lit) (+ (##sys#size lit)
			      (literal-size (numerator lit))
			      (literal-size (denominator lit))))
	    ((cplxnum? lit) (+ (##sys#size lit)
			       (literal-size (real-part lit))
			       (literal-size (imag-part lit))))
	    (else (bad-literal lit))) )

    (define (gen-lit lit to)
      ;; we do simple immediate literals directly to avoid a function call:
      (cond ((and (fixnum? lit) (not (big-fixnum? lit)))
	     (gen `(set ,to (C_fix ,lit))))
	    ((block-variable-literal? lit))
	    ((eq? lit (void))
	     (gen `(set ,to C_SCHEME_UNDEFINED)))
	    ((boolean? lit) 
	     (gen `(set ,to ,(if lit 'C_SCHEME_TRUE 'C_SCHEME_FALSE))))
	    ((char? lit)
	     (gen `(set ,to (C_make_character ,(char->integer lit)))))
	    ((symbol? lit)		; handled slightly specially (see C_h_intern_in)
	     (let* ([str (##sys#slot lit 1)]
		    [len (##sys#size str)] )
	       (gen `(set ,to (call ($ C_h_intern) 
                             (adr ,to) ,len (string ,str))))))
	    ((null? lit) 
	     (gen `(set ,to C_SCHEME_END_OF_LIST)))
	    ((and (not (##sys#immediate? lit)) ; nop
		  (##core#inline "C_lambdainfop" lit)))
	    ((or (fixnum? lit) (not (##sys#immediate? lit)))
	     (gen `(set ,to (C_decode_literal C_heaptop (string ,(encode-literal lit))))))
	    (else (bad-literal lit))))

    (define (utype t)
      (case t
	((fixnum) 'int)
	((flonum) 'double)
	((char) 'char)
	((pointer) 'ptr)
	((int) 'int)
	((bool) 'int)
	(else (bomb "invalid unboxed type" t))))

    (define (procedures)
      (for-each
       (lambda (p)
	 (let* ((id (car p))
		(ll (cdr p))
		(n (lambda-literal-argument-count ll))
		(rname (real-name id db))
		(demand (lambda-literal-allocated ll))
		(max-av (apply max 0 (lambda-literal-callee-signatures ll)))
		(rest (lambda-literal-rest-argument ll))
		(customizable (lambda-literal-customizable ll))
		(empty-closure (and customizable (zero? (lambda-literal-closure-size ll))))
		(nec (- n (if empty-closure 1 0)))
		(vlist0 (make-variable-list n 't))
		(alist0 (make-argument-list n 't))
		(varlist (if empty-closure (cdr vlist0) vlist0))
		(arglist (if empty-closure (cdr alist0) alist0))
		(external (lambda-literal-external ll))
		(looping (lambda-literal-looping ll))
		(direct (lambda-literal-direct ll))
		(rest-mode (lambda-literal-rest-argument-mode ll))
		(temps (lambda-literal-temporaries ll))
		(ubtemps (lambda-literal-unboxed-temporaries ll))
		(topname (toplevel unit-name)))
           (when empty-closure 
             (debugging 'o "dropping unused closure argument" id))
           (when (eq? 'toplevel id)
             (gen `(define/variable static int toplevel_initialized 0))
             (unless unit-name
               (gen '(main_entry_point))))
           (gen `(define ,(if direct 'word 'void)
                   ,(if (eq? 'toplevel id) (name "C_" topname) id)
                   ,@(if customizable '() '((word c)))
                   ,@(if (and direct (not (zero? demand))) 
                        '(((ptr word) a)) 
                        '())
                   ,@(if (or customizable direct)
                         varlist
                         '(((ptr word) av)))))
	   (gen `(comment ,rname))
	   (when (eq? rest-mode 'none) (set! rest #f))
	   (unless (or customizable direct)
	     (do ((i 0 (add1 i)))
		 ((>= i n))
	       (gen `(let ,(tvar i) (elt av ,i)))))
	   (if rest
	       (gen `(let ,(tvar n))) ; To hold rest-list if demand is met
	       (begin
		 (do ((i n (add1 i))
		      (j (+ temps (if looping (sub1 n) 0)) (sub1 j)) )
		     ((zero? j))
		   (gen `(let ,(tvar i))))
		 (for-each
		  (lambda (ubt)
		    (gen `(let/unboxed ,(utype (cdr ubt)) ,(car ubt))))
		  ubtemps)))

           (cond ((eq? 'toplevel id)
                  ;; toplevel procedure
                  (assert (not rest))
                  (assert (not direct))
		  (let ((ldemand (foldl (lambda (n lit) (+ n (literal-size lit))) 0 literals))
			(llen (length literals)) )
		    (gen '(let/cell a)
			 `(if (ref ($ toplevel_initialized)))
                         `(continue t1 C_SCHEME_UNDEFINED)
                         '(else)
                         `(call ($ C_toplevel_entry) (string ,(->string (or unit-name topname))))
                         '(endif))
		    (when emit-debug-info
		      (gen `(call ($ C_register_debug_info) ($ C_debug_info))))
		    (when disable-stack-overflow-checking
		      (gen `(set ($ C_disable_overflow_check) 1)))
		    (unless unit-name
		      (when target-heap-size
			(gen `(call ($ C_set_or_change_heap_size) ,target-heap-size 1)
                             '(set ($ C_heap_size_is_fixed) 1)))
		      (when target-stack-size
			(gen `(call ($ C_resize_stack) ,target-stack-size))))
		    (gen `(call ($ C_check_nursery_minimum) (C_calculate_demand ,demand c ,max-av))
			 `(if (unlikely (! (C_demand (C_calculate_demand ,demand c ,max-av)))))
                         `(tailcall ($ C_save_and_reclaim) ($ ,(name "C_" topname)) c av)
                         '(endif)
                         '(set ($ toplevel_initialized) 1)
			 `(if (unlikely (! (C_demand_2 ,ldemand))))
                         '(save (cast word t1))
			 `(call ($ C_rereclaim2) (words ,ldemand) 1)
			 '(set t1 (restore))
                         '(endif)
			 `(set a (C_alloc ,demand)))
		    (unless (zero? llen)
		      (gen `(call ($ C_initialize_lf) ($ lf) ,llen))
		      (literal-frame)
		      (gen `(call ($ C_register_lf2) ($ lf) ,llen (call ($ create_ptable)))))
                    (set! non-av-proc #f)
                	   (expression (lambda-literal-body ll) n ll)))

                (rest
                  ;; non-toplevel procedure with rest arguments
                  (assert (not customizable)) ;;XXX is it?
		  (gen `(let/cell a))
		  (when (and (not unsafe) 
                             (not no-argc-checks) 
                             (> n 2) 
                             (not empty-closure))
		    (gen `(if (< c ,n))
                         `(tailcall ($ C_bad_min_argc_2) c ,n t0)
                         '(endif)))
		  (when insert-timer-checks 
                    (gen '(set ($ C_timer_interrupt_counter) (- (ref ($ C_timer_interrupt_counter)) 1))
                         '(if (<= (ref ($ C_timer_interrupt_counter)) 0))
                         '(call ($ C_raise_interrupt) C_TIMER_INTERRUPT_NUMBER)
                         '(endif)))
		  (gen `(if (unlikely (! (C_demand (C_calculate_demand (+ (* (- c ,n) C_SIZEOF_PAIR) ,demand) c ,max-av))))))
                  (when looping
                    ;; Loop will update t_n copy of av[n]; refresh av.
                    (let loop ((i 0))
                      (if (>= i n)
                          (gen `(set (elt av ,i) ,(tvar i)))
                          (loop (add1 i)))))
                  (gen `(tailcall ($ C_save_and_reclaim) ,id c av)
                       '(endif)
                       `(set a (C_alloc (+ (* (- c ,n) C_SIZEOF_PAIR) ,demand)))
		       `(set ,(tvar n) (C_build_rest (adr a) c ,n av)))
                  (do ((i (+ n 1) (+ i 1))
                       (j temps (- j 1)))
                      ((zero? j))
                      (gen `(let ,(tvar i))))
                  (set! non-av-proc #f)
	          (expression (lambda-literal-body ll)
                              (add1 n) ; One temporary is needed to hold the rest-list
                         	    ll))

                (direct
                  ;; non-toplevel, non-rest, directly callable procedure
		  (when (and (not unsafe)
                             (not disable-stack-overflow-checking))
		    (gen '(stack_overflow_check)))
		  (when looping (gen '(label loop)))  ;XXX needed?
                  (set! non-av-proc #f) ; XXX ???
              	   (expression (lambda-literal-body ll)
                              n
                              ll))

                (else
                  ;; non-toplevel, non-rest, non-direct procedure
    		  (gen '(let/cell a))
		  (when looping (gen '(label loop)))
		  (when (and external 
                             (not unsafe) 
                             (not no-argc-checks)
                             (not customizable))
		    ;; (not customizable) implies empty-closure
		    (if (eq? rest-mode 'none)
			(when (> n 2)
                          (gen `(if (< c ,n))
                               `(tailcall ($ C_bad_min_argc_2) c ,n t0)
                               '(endif)))
			(gen `(if (!= c ,n))
                             `(tailcall ($ C_bad_argc_2) c ,n t0)
                             '(endif))))
                  ;; The interrupt handler may fill the stack, so we only
                  ;; check for an interrupt when the procedure is restartable
                  (when insert-timer-checks
                    (gen '(set ($ C_timer_interrupt_counter) (- (ref ($ C_timer_interrupt_counter)) 1))
                         '(if (<= (ref ($ C_timer_interrupt_counter)) 0))
                         '(call ($ C_raise_interrupt) C_TIMER_INTERRUPT_NUMBER)
                         '(endif)))
                  (gen `(if (unlikely (! (C_demand (C_calculate_demand ,demand
                                                                       ,(if customizable 0 'c)
                                                                       ,max-av))))))
                  (when (and looping (not customizable))
                    ;; Loop will update t_n copy of av[n]; refresh av.
                    (let loop ((i 0))
                      (if (>= i n)
                          (gen `(set (elt av ,i) ,(tvar i)))
                          (loop (add1 i)))))
                  (if (and customizable (> nec 0))
                      (gen `(tailcall ($ C_save_and_reclaim_args) 
                                      ($ ,(name "tr" id)) ,nec
                                      ,@arglist))
                      (gen `(tailcall ($ C_save_and_reclaim) ($ ,id)
                                      ,n av)))
                  (gen '(endif))
                  (when (> demand 0)
                    (gen `(set a (C_alloc ,demand))))
                  (set! non-av-proc customizable)
              	   (expression (lambda-literal-body ll)
                              n
                              ll)))
               (gen '(end))))
       lambda-table*))
  
    ;; Don't truncate floating-point precision!
    (flonum-print-precision (+ flonum-maximum-decimal-exponent 1))
    (init-target out user-supplied-options source-file)
    (debugging 'p "code generation phase...")
    (header)
    (declarations)
    (generate-external-variables external-variables)
    (generate-foreign-stubs foreign-lambda-stubs db)
    (prototypes)
    (generate-foreign-callback-stubs foreign-callback-stubs db)
    (trampolines)
    (when emit-debug-info
      (emit-debug-table dbg-info-table))
    (procedures)
    (emit-procedure-table lambda-table* source-file)
    (finalize-target)))


;;; Emit global tables for debug-info

(define (emit-debug-table dbg-info-table)
  (gen `(define/array static C_DEBUG_INFO C_debug_info ()
                 ,@(map (lambda (info)
                          (list->vector
                            (cons* (second info) 0
                                   (map ->string (cddr info)))))
                     (sort dbg-info-table (lambda (i1 i2)
                                            (< (car i1) (car i2)))))
                 (0 0 0 0))))


;;; Emit procedure table:

(define (emit-procedure-table lambda-table* sf)
  (gen `(define/array static C_PTABLE_ENTRY ptable
                 ,(add1 (length lambda-table*))
                 ,@(map (lambda (p)
                          (let ((id (car p))
                                (ll (cdr p)))
                            (vector `(string ,(conc id ":" (string->c-identifier sf)))
                                    `($ ,(if (eq? 'toplevel id)
                                             (conc "C_" (toplevel unit-name))
                                             id)))))
                     lambda-table*)
                 #(0 0)))
  (gen `(define static (ptr C_PTABLE_ENTRY) create_ptable)
       '(return ($ ptable))
       '(end)))


;;; Generate top-level procedure name:

(define (toplevel name)
  (if (not name)
      "toplevel"
      (string-append (c-identifier name) "_toplevel")))


;;; Create list of variables/parameters, interspersed with a special token:

(define (make-variable-list n prefix)
  (list-tabulate
   n
   (lambda (i) (list 'word (name prefix i)))))
  
(define (make-argument-list n prefix)
  (list-tabulate
   n
   (lambda (i) (name prefix i))))


;;; Generate external variable declarations:

(define (generate-external-variables vars)
  (for-each
   (lambda (v)
     (let ((name (vector-ref v 0))
	   (type (vector-ref v 1))
	   (exported (vector-ref v 2)) )
       (gen `(declare/variable ,@(if exported '() '(static))
                      ,(foreign-type-declaration type) ,name))))
   vars) )


;;; Generate foreign stubs:

(define (generate-foreign-callback-stub-prototypes stubs)
  (for-each
   (lambda (stub)
     (generate-foreign-callback-header 'declare '(extern) stub))
   stubs) )

(define (generate-foreign-stubs stubs db)
  (for-each
   (lambda (stub)
     (let* ([id (foreign-stub-id stub)]
	    [rname (real-name2 id db)]
	    [types (foreign-stub-argument-types stub)]
	    [n (length types)]
	    [rtype (foreign-stub-return-type stub)] 
	    [sname (foreign-stub-name stub)] 
	    [body (foreign-stub-body stub)]
	    [names (or (foreign-stub-argument-names stub) (make-list n #f))]
	    [rconv (foreign-result-conversion rtype 'C_a)] 
	    [cps (foreign-stub-cps stub)]
	    [callback (foreign-stub-callback stub)] )
       (when rname
	 (gen `(comment ,(conc "from " rname))))
       (cond (cps
	      (gen `(define static void ,id (word C_c) ((ptr word) C_av))
                   '(let C_k (elt C_av 1))
                   '(let C_buf (elt C_av 2)))
	      (do ((i 0 (add1 i)))
		  ((>= i n))
		(gen `(let ,(name "C_a" i) (elt C_av ,(+ i 3))))))
	     (else
	      (gen `(define static word ,id (word C_buf)
                       ,@(make-variable-list n "C_a")))))
       (gen `(let C_r C_SCHEME_UNDEFINED)
            '(let/cell C_a (cast (ptr word) C_buf)))
       (for-each
	(lambda (type index vname)
	  (gen `(let/unboxed ,(foreign-type-declaration type)
                        ,(or vname (tvar index))
	             (cast ,(foreign-type-declaration type)
                           ,((foreign-argument-conversion type)
                             (name "C_a" index))))))
         types (iota n) names)
       (when callback
         (gen '(let C_level (C_save_callback_continuation (adr C_a) C_k))))
       (cond (body
               (gen `(let/unboxed ,(foreign-type-declaration 
                                     (if (eq? 'void rtype)
                                         'scheme-object
                                         rtype)
                                     #f #t)
                       C_r1)
                    `(trampoline C_r1 C_ret)
                    `(inline ,body)
                    '(label C_ret)
                    `(set C_r ,(rconv 'C_r1))))
	     (else
	      (if (not (eq? rtype 'void))
                  (gen `(set C_r ,(rconv (cons sname
                                               (make-argument-list n "t")))))
                  (gen `(call ($ ,sname) ,@(make-argument-list n "t"))))))
       (cond (callback
               (gen '(set C_k (C_restore_callback_continuation2 C_level))
                    '(continue C_k C_r)))
             (cps (gen '(continue C_k C_r)))
             (else (gen '(return C_r)) ) )
       (gen '(end))))
   stubs) )

(define (generate-foreign-callback-stubs stubs db)
  (for-each
   (lambda (stub)
     (let* ((id (foreign-callback-stub-id stub))
	    (rname (real-name2 id db))
	    (rtype (foreign-callback-stub-return-type stub))
	    (argtypes (foreign-callback-stub-argument-types stub))
	    (n (length argtypes))
	    (vlist (make-argument-list n "t")) )

       (define (compute-size type var ns)
	 (case type
	   ((char int int32 short bool void unsigned-short scheme-object unsigned-char unsigned-int unsigned-int32
		  byte unsigned-byte)
	    ns)
	   ((float double c-pointer nonnull-c-pointer
		   c-string-list c-string-list*)
	    `(+ ,ns 3))
	   ((unsigned-integer unsigned-integer32 long integer integer32 
			      unsigned-long number)
	    `(+ ,ns C_SIZEOF_FIX_BIGNUM))
	   ((unsigned-integer64 integer64 size_t ssize_t)
	    ;; On 32-bit systems, needs 2 digits
	    `(+ ,ns (C_SIZEOF_BIGNUM 2)))
	   ((c-string c-string* unsigned-c-string unsigned-c-string unsigned-c-string*)
	    `(+ ,ns 2 (cond (== ,var 0) 
                       1
                       (C_bytestowords (C_strlen ,var)))))
	   ((nonnull-c-string nonnull-c-string* nonnull-unsigned-c-string nonnull-unsigned-c-string* symbol)
	    `(+ ,ns 2 (C_bytestowords (C_strlen ,var))))
	   (else
	    (cond ((and (symbol? type) (lookup-foreign-type type)) 
		   => (lambda (t) 
                        (compute-size (vector-ref t 0) var ns) ) )
		  ((pair? type)
		   (case (car type)
		     ((ref pointer c-pointer nonnull-pointer nonnull-c-pointer function instance 
			   nonnull-instance instance-ref)
		      `(+ ,ns 3))
		     ((const) (compute-size (cadr type) var ns))
		     (else ns) ) )
		  (else ns) ) ) ) )

       (let ((size (let loop ((types argtypes) (vars vlist) (ns 0))
			(if (null? types)
			    ns
			    (loop (cdr types) (cdr vars) 
				  (compute-size (car types) 
                                                (car vars) ns))))))
	 (when rname
	   (gen `(comment ,(conc "from " rname))))
	 (generate-foreign-callback-header 'define '() stub)
	 (gen '(let x)
              `(let s ,size)
              `(let/cell a ,(if (eq? 0 size)
                                 'C_stack_pointer
                                 '(C_alloc s))))
	 (gen '(call ($ C_callback_adjust_stack) a s)) ; make sure content is below stack_bottom as well
	 (for-each
	  (lambda (v t)
	    (gen `(set x ,((foreign-result-conversion t 'a) v))
                 '(save (cast word x))))
	  (reverse vlist)
	  (reverse argtypes))
	 (if (eq? 'void rtype)
             (gen `(call ($ C_callback_wrapper) ($ ,id) ,n))
	     (gen `(return ,((foreign-argument-conversion rtype)
                      `(C_callback_wrapper ,id ,n)))))
         (gen '(end)))))
   stubs) )

(define (generate-foreign-callback-header def cls stub)
  (let* ((name (foreign-callback-stub-name stub))
	 (quals (foreign-callback-stub-qualifiers stub))
	 (rtype (foreign-callback-stub-return-type stub))
	 (argtypes (foreign-callback-stub-argument-types stub))
	 (n (length argtypes))
	 (vlist (make-argument-list n "t")) )
    (gen `(,def ,@cls ,@(string-split (->string quals))
                   ,(foreign-type-declaration rtype)
                   ,name
                   ,@(map (lambda (v t)
                            (foreign-type-declaration t v))
                       vlist argtypes)))))


;; Create type declarations

(define (foreign-type-declaration type #!optional target nonconst)
  (let ((err (lambda () (quit-compiling "illegal foreign type `~A'" type)))
	(str (lambda (ts) (if target (list ts target) ts))))
    (case type
      ((scheme-object) (str 'word))
      ((char byte) (str 'char))
      ((unsigned-char unsigned-byte) (str 'uchar))
      ((unsigned-int unsigned-integer) (str 'uint))
      ((unsigned-int32 unsigned-integer32) (str 'u32))
      ((int integer bool) (str 'int))
      ((size_t) (str 'size_t))
      ((ssize_t) (str 'ssize_t))
      ((int32 integer32) (str 's32))
      ((integer64) (str 's64))
      ((unsigned-integer64) (str 'u64))
      ((short) (str 'short))
      ((long) (str 'long))
      ((unsigned-short) (str 'ushort))
      ((unsigned-long) (str 'ulong))
      ((float) (str 'float))
      ((double number) (str 'double))
      ((c-pointer nonnull-c-pointer scheme-pointer nonnull-scheme-pointer) (str 'ptr))
      ((c-string-list c-string-list*) (str '(ptr (ptr char))))
      ((blob nonnull-blob u8vector nonnull-u8vector) 
       (str '(ptr uchar)))
      ((u16vector nonnull-u16vector) (str '(ptr ushort)))
      ((s8vector nonnull-s8vector) (str '(ptr char)))
      ((u32vector nonnull-u32vector) (str '(ptr u32)))
      ((u64vector nonnull-u64vector) (str '(ptr u64)))
      ((s16vector nonnull-s16vector) (str '(ptr short)))
      ((s32vector nonnull-s32vector) (str '(ptr s32)))
      ((s64vector nonnull-s64vector) (str '(ptr s64)))
      ((f32vector nonnull-f32vector) (str '(ptr float)))
      ((f64vector nonnull-f64vector) (str '(ptr double)))
      ((pointer-vector nonnull-pointer-vector) (str '(ptr ptr)))
      ((nonnull-c-string c-string nonnull-c-string* c-string* symbol) 
       (str '(ptr char)))
      ((nonnull-unsigned-c-string nonnull-unsigned-c-string* unsigned-c-string unsigned-c-string*)
       (str '(ptr uchar)))
      ((void) (str 'void))
      (else
       (cond ((and (symbol? type) (lookup-foreign-type type))
	      => (lambda (t)
		   (foreign-type-declaration (vector-ref t 0) target)) )
	     ((string? type) (str type))
	     ((list? type)
	      (let ((len (length type)))
		(cond 
		 ((and (= 2 len)
		       (memq (car type) '(pointer nonnull-pointer c-pointer 
						  scheme-pointer nonnull-scheme-pointer
						  nonnull-c-pointer) ) )
		  (str `(ptr ,(foreign-type-declaration (cadr type)))))
		 ((and (= 2 len)
		       (eq? 'ref (car type)))
		  (str `(ref ,(foreign-type-declaration (cadr type)))))
		 ((and (> len 2)
		       (eq? 'template (car type)))
		  (str
                    `(template-instance
                       ,(foreign-type-declaration (cadr type))
		       ,@(map foreign-type-declaration (cddr type)))))
		 ((and (= len 2)
                       (eq? 'const (car type)))
                  (if nonconst
                      (foreign-type-declaration (cadr type) target)
   	    	      (str `(const ,(foreign-type-declaration (cadr type))))))
		 ((and (= len 2) (eq? 'struct (car type)))
		  (str `(struct ,(cadr type))))
		 ((and (= len 2) (eq? 'union (car type)))
		  (str `(union ,(cadr type))))
		 ((and (= len 2) (eq? 'enum (car type)))
		  (str `(enum ,(cadr type))))
		 ((and (= len 3) (memq (car type) '(instance nonnull-instance)))
		  (str `(ptr ,(cadr type))))
		 ((and (= len 3) (eq? 'instance-ref (car type)))
		  (str `(ref ,(cadr type))))
		 ((and (>= len 3) (eq? 'function (car type)))
		  (let ((rtype (cadr type))
			(argtypes (caddr type))
			(callconv (cdddr type)))
		    (str `(function
                            ,(foreign-type-declaration rtype)
		            ,@callconv
		            ,@(map (lambda (at)
                                 (if (eq? '... at) 
				    '...
				    (foreign-type-declaration at) ) )
			        argtypes) ))))
		 (else (err)) ) ) )
	     (else (err)) ) ) ) ) )


;; Generate expression to convert argument from Scheme data

(define (foreign-argument-conversion type)
  (let ((err (lambda ()
	       (quit-compiling "illegal foreign argument type `~A'" type)))
        (wrap (lambda (x) (lambda (y) (list x y)))))
    (case type
      ((scheme-object) identity)
      ((char unsigned-char) (wrap 'char))
      ((byte int int32 unsigned-int unsigned-int32 unsigned-byte)
       (wrap 'C_unfix))
      ((short) (wrap 'C_unfix))
      ((unsigned-short) 
       (lambda (x) `(cast ushort (C_unfix ,x))))
      ((unsigned-long) (wrap 'C_num_to_unsigned_long))
      ((double number float) (wrap 'C_c_double))
      ((integer integer32) (wrap 'C_num_to_int))
      ((integer64 size_t ssize_t unsigned-integer64) 
       (wrap 'C_num_to_int64))
      ((long) (wrap 'C_num_to_long))
      ((unsigned-integer unsigned-integer32)
       (wrap 'C_num_to_unsigned_int))
      ((scheme-pointer) (wrap 'C_data_pointer_or_null))
      ((nonnull-scheme-pointer) (wrap 'C_data_pointer))
      ((c-pointer) (wrap 'C_c_pointer_or_null))
      ((nonnull-c-pointer) (wrap 'C_c_pointer_nn))
      ((blob) (wrap 'C_c_bytevector_or_null))
      ((nonnull-blob) (wrap 'C_c_bytevector))
      ((u8vector) (wrap 'C_c_u8vector_or_null))
      ((nonnull-u8vector) (wrap 'C_c_u8vector))
      ((u16vector) (wrap 'C_c_u16vector_or_null))
      ((nonnull-u16vector) (wrap 'C_c_u16vector))
      ((u32vector) (wrap 'C_c_u32vector_or_null))
      ((nonnull-u32vector) (wrap 'C_c_u32vector))
      ((u64vector) (wrap 'C_c_u64vector_or_null))
      ((nonnull-u64vector) (wrap 'C_c_u64vector))
      ((s8vector) (wrap 'C_c_s8vector_or_null))
      ((nonnull-s8vector) (wrap 'C_c_s8vector))
      ((s16vector) (wrap 'C_c_s16vector_or_null))
      ((nonnull-s16vector) (wrap 'C_c_s16vector))
      ((s32vector) (wrap 'C_c_s32vector_or_null))
      ((nonnull-s32vector) (wrap 'C_c_s32vector))
      ((s64vector) (wrap 'C_c_s64vector_or_null))
      ((nonnull-s64vector) (wrap 'C_c_s64vector))
      ((f32vector) (wrap 'C_c_f32vector_or_null))
      ((nonnull-f32vector) (wrap 'C_c_f32vector))
      ((f64vector) (wrap 'C_c_f64vector_or_null))
      ((nonnull-f64vector) (wrap 'C_c_f64vector))
      ((pointer-vector) (wrap 'C_c_pointer_vector_or_null))
      ((nonnull-pointer-vector) (wrap 'C_c_pointer_vector))
      ((c-string c-string* unsigned-c-string unsigned-c-string*)
       (wrap 'C_string_or_null))
      ((nonnull-c-string nonnull-c-string* nonnull-unsigned-c-string 
			 nonnull-unsigned-c-string* symbol) 
       (wrap 'C_c_string))
      ((bool) (wrap 'C_truep))
      (else
       (cond ((and (symbol? type) (lookup-foreign-type type))
	      => (lambda (t)
		   (foreign-argument-conversion (vector-ref t 0)) ) )
	     ((and (list? type) (>= (length type) 2))
	      (case (car type)
		((c-pointer) (wrap 'C_c_pointer_or_null))
		((nonnull-c-pointer) (wrap 'C_c_pointer_nn))
		((instance) (wrap 'C_c_pointer_or_null))
		((nonnull-instance) (wrap 'C_c_pointer_nn))
		((scheme-pointer) (wrap 'C_data_pointer_or_null))
		((nonnull-scheme-pointer) (wrap 'C_data_pointer))
		((function) (wrap 'C_c_pointer_or_null))
		((const) (foreign-argument-conversion (cadr type)))
		((enum) (wrap 'C_num_to_int))
		((ref)
                 (lambda (x)
                   `(deref (cast (ptr ,(foreign-type-declaration (cadr type)))
                                  (C_c_pointer_nn ,x)))))
		((instance-ref)
                 (lambda (x)
                   `(deref (cast (ptr ,(cadr type))
                                 (C_c_pointer_nn ,x)))))
		(else (err)) ) )
	     (else (err)) ) ) ) ) )


;; Generate suitable conversion of a result value into Scheme data
	   
(define (foreign-result-conversion type dest)
  (let ((err (lambda ()
	       (quit-compiling "illegal foreign return type `~A'" type)))
        (wrap (lambda (x) (lambda (y) (list x y)))))
    (case type
      ((char unsigned-char) (wrap 'C_make_character))
      ((int int32) (wrap 'C_fix))
      ((unsigned-int unsigned-int32) 
       (lambda (x) `(C_fix (& C_MOST_POSITIVE_FIXNUM ,x))))
      ((short) 
       (lambda (x) `(C_fix (cast short ,x))))
      ((unsigned-short) 
       (lambda (x) `(C_fix (& 0xffff ,x))))
      ((byte) 
       (lambda (x) `(C_fix (cast char ,x))))
      ((unsigned-byte) 
       (lambda (x) `(C_fix (& 0xff ,x))))
      ((float double) 
       (lambda (x)
         `(C_flonum (adr ,dest) ,x)))	;XXX suboptimal for int64
      ((number) 
       (lambda (x) `(C_number (adr ,dest) ,x)))
      ((nonnull-c-string c-string nonnull-c-pointer c-string* nonnull-c-string* 
			 unsigned-c-string unsigned-c-string* nonnull-unsigned-c-string
			 nonnull-unsigned-c-string* symbol c-string-list c-string-list*) 
       (lambda (x)
         `(C_mpointer (adr ,dest) ,x)))
      ((c-pointer) 
       (lambda (x) `(C_mpointer_or_false (adr ,dest) ,x)))
      ((integer integer32)
       (lambda (x) `(C_int_to_num (adr ,dest) ,x)))
      ((integer64 ssize_t) 
       (lambda (x)
         `(C_int64_to_num (adr ,dest) ,x)))
      ((unsigned-integer64 size_t) 
       (lambda (x) `(C_uint64_to_num (adr ,dest) ,x)))
      ((unsigned-integer unsigned-integer32) 
       (lambda (x) `(C_unsigned_int_to_num (adr ,dest) ,x)))
      ((long) 
       (lambda (x)
         `(C_long_to_num (adr ,dest) ,x)))
      ((unsigned-long) 
       (lambda (x)
         `(C_unsigned_long_to_num (adr ,dest) ,x)))
      ((bool) (wrap 'C_mk_bool))
      ((void scheme-object) 
       (lambda (x) `(cast word ,x)))
      (else
       (cond ((and (symbol? type) (lookup-foreign-type type))
	      => (lambda (x)
		   (foreign-result-conversion (vector-ref x 0) dest)) )
	     ((and (list? type) (>= (length type) 2))
	      (case (car type)
		((nonnull-pointer nonnull-c-pointer)
		 (lambda (x) `(C_mpointer (adr ,dest) ,x)))
		((ref)
		 (lambda (x) `(C_mpointer (adr ,dest) (adr ,x))))
		((instance)
		 (lambda (x) `(C_mpointer_or_false (adr ,dest) ,x)))
		((nonnull-instance)
		 (lambda (x) `(C_mpointer (adr ,dest) ,x)))
		((instance-ref)
		 (lambda (x) `(C_mpointer (adr ,dest) (adr ,dest))))
		((const)
                 (foreign-result-conversion (cadr type) dest))
		((pointer c-pointer)
		 (lambda (x) `(C_mpointer_or_false (adr ,dest) ,x)))
		((function) 
                 (lambda (x) `(C_mpointer (adr ,dest) ,x)))
		((enum) 
                 (lambda (x) `(C_int_to_num (adr ,dest) ,x)))
		(else (err)) ) )
	     (else (err)) ) ) ) ) )


;;; Encoded literals as strings, to be decoded by "C_decode_literal()"
;; 
;; - everything hardcoded, using the FFI would be the ugly, but safer method.

(define (encode-literal lit)
  (define getbits
    (foreign-lambda* int ((scheme-object lit))
      "
#ifdef C_SIXTY_FOUR
return((C_header_bits(lit) >> (24 + 32)) & 0xff);
#else
return((C_header_bits(lit) >> 24) & 0xff);
#endif
") )
  (define getsize
    (foreign-lambda* int ((scheme-object lit))
      "return(C_header_size(lit));"))
  (define (encode-size n)
    (if (fx> (fxlen n) 24)
	;; Unfortunately we can't do much more to help the user.
	;; Printing the literal is not helpful because it's *huge*,
	;; and we have no line number information here.
	(quit-compiling
	 "Encoded literal size of ~S is too large (must fit in 24 bits)" n)
	(string
	 (integer->char (bitwise-and #xff (arithmetic-shift n -16)))
	 (integer->char (bitwise-and #xff (arithmetic-shift n -8)))
	 (integer->char (bitwise-and #xff n)))))
  (define (finish str)		   ; can be taken out at a later stage
    (string-append (string #\xfe) str))
  (finish
   (cond ((eq? #t lit) "\xff\x06\x01")
	 ((eq? #f lit) "\xff\x06\x00")
	 ((char? lit) (string-append "\xff\x0a" (encode-size (char->integer lit))))
	 ((null? lit) "\xff\x0e")
	 ((eof-object? lit) "\xff\x3e")
	 ((eq? (void) lit) "\xff\x1e")
	 ;; The big-fixnum? check can probably be simplified
	 ((and (fixnum? lit) (not (big-fixnum? lit)))
	  (string-append
	   "\xff\x01"
	   (string (integer->char (bitwise-and #xff (arithmetic-shift lit -24)))
		   (integer->char (bitwise-and #xff (arithmetic-shift lit -16)))
		   (integer->char (bitwise-and #xff (arithmetic-shift lit -8)))
		   (integer->char (bitwise-and #xff lit)) ) ) )
	 ((exact-integer? lit)
	  ;; Encode as hex to save space and get exact size
	  ;; calculation.  We could encode as base 32 to save more
	  ;; space, but that makes debugging harder.  The type tag is
	  ;; a bit of a hack: we encode as "GC forwarded" string to
	  ;; get a unique new type, as bignums don't have their own
	  ;; type tag (they're encoded as structures).
	  (let ((str (number->string lit 16)))
	    (string-append "\xc2" (encode-size (string-length str)) str)))
	 ((flonum? lit)
	  (string-append "\x55" (number->string lit) "\x00") )
	 ((symbol? lit)
	  (let ((str (##sys#slot lit 1)))
	    (string-append 
	     "\x01" 
	     (encode-size (string-length str))
	     str) ) )
	 ((##sys#immediate? lit)
	  (bomb "invalid literal - cannot encode" lit))
	 ((##core#inline "C_byteblockp" lit)
	  (##sys#string-append ; relies on the fact that ##sys#string-append doesn't check
	   (string-append
	    (string (integer->char (getbits lit)))
	    (encode-size (getsize lit)) )
	   lit) )
	 (else
	  (let ((len (getsize lit)))
	    (string-intersperse
	     (cons*
	      (string (integer->char (getbits lit)))
	      (encode-size len)
	      (list-tabulate len (lambda (i) (encode-literal (##sys#slot lit i)))))
	     ""))))) )
)
