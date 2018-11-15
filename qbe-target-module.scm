;;; QBE backend/target for CHICKEN (module definition)


(module (chicken compiler target) (init-target
                                   finalize-target
                                   generate-target-code)
(import (scheme) 
        (chicken base)
	(chicken internal)
	(chicken platform)
        (chicken string)
        (chicken foreign)
        (chicken pretty-print)
        (chicken fixnum)
	(chicken compiler core)
	(chicken compiler c-platform)
	(chicken compiler support))
(import (srfi 1))

(include "qbe-target.scm")

)
