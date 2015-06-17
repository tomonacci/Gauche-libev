;;;
;;; libev
;;;

(define-module control.libev
  (export EV_READ EV_WRITE
          <ev-loop>
          ev-default-loop
          ev-loop-new
          ev-run
          <ev-watcher>
          ev-watcher-active?
          ev-watcher-pending?
          <ev-io>
          ev-io-init
          ev-io-set
          ev-io-start
          ev-io-stop
          <ev-timer>
          ev-timer-init
          ev-timer-start
          ev-timer-stop
          )
  )
(select-module control.libev)

;; Loads extension
(dynamic-load "libev")

;;
;; Put your Scheme definitions here
;;

(define (ev-io-start watcher :optional (loop (~ watcher'loop)))
  (%ev-io-start watcher loop))
