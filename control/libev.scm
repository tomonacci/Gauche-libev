;;;
;;; libev
;;;

(define-module control.libev
  (export EV_READ EV_WRITE
          <ev-loop>
          ev-default-loop
          ev-loop-new
          ev-run
          <ev-io-watcher>
          ev-is-active
          ev-io-new
          ev-io-init
          ev-io-start
          ev-io-stop
          <ev-signal-watcher>
          ev-signal-new
          ev-signal-init
          ev-signal-start
          ev-signal-stop
          )
  )
(select-module control.libev)

;; Loads extension
(dynamic-load "libev")

;;
;; Put your Scheme definitions here
;;



