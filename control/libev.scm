;;;
;;; libev
;;;

(define-module control.libev
  (export EV_READ EV_WRITE
          <ev-loop>
          <ev-io-watcher>
          ev-default-loop
          ev-loop-new
          ev-is-active
          ev-io-new
          ev-io-init
          ev-io-start
          ev-io-stop
          ev-run
          )
  )
(select-module control.libev)

;; Loads extension
(dynamic-load "libev")

;;
;; Put your Scheme definitions here
;;



