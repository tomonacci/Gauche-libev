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
          <ev-io-watcher>
          ev-io-new
          ev-io-init
          ev-io-start
          ev-io-stop
          <ev-signal-watcher>
          ev-signal-new
          ev-signal-init
          ev-signal-start
          ev-signal-stop
          <ev-timer-watcher>
          ev-timer-new
          ev-timer-init
          ev-timer-start
          ev-timer-stop
          <ev-stat>
          )
  )
(select-module control.libev)

;; Loads extension
(dynamic-load "libev")

;;
;; Put your Scheme definitions here
;;



