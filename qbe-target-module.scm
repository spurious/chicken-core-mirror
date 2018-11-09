;;; QBE backend/target for CHICKEN (module definition)


(module (chicken compiler target) (init-target
                                   finalize-target
                                   generate-target-code)
(import (scheme) 
        (chicken base)
	(chicken nternal)
	(chicken platform)
        (chicken string)
        (chicken pretty-print)
	(chicken compiler core)
	(chicken compiler c-platform)
	(chicken compiler support))

(include "qbe-target.scm")

)
