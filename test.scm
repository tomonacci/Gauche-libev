;;;
;;; Test control.libev
;;;

(use gauche.test)

(test-start "control.libev")
(use control.libev)
(test-module 'control.libev)

(test* "make <ev-io>" #t (is-a? (make <ev-io>) <ev-io>))
(test* "ev-default-loop" #t (is-a? (ev-default-loop 0) <ev-loop>))
(test* "ev-loop-new" #t (is-a? (ev-loop-new 0) <ev-loop>))
(test* "<ev-watcher>" #t (is-a? <ev-watcher> <class>))
(test* "make <ev-signal>" #t (is-a? (make <ev-signal>) <ev-signal>))
(test* "make <ev-timer>" #t (is-a? (make <ev-timer>) <ev-timer>))
(test* "<ev-stat>" #t (is-a? <ev-stat> <class>))
(test* "make <ev-stat>" #t (is-a? (make <ev-stat>) <ev-stat>))
(test* "ev-watcher-active? (inactive)" #f (ev-watcher-active? (make <ev-timer>)))
(test* "ev-watcher-active? (active)" #t
  (let1 timer (make <ev-timer>)
    (ev-timer-init timer values 0 0)
    (ev-timer-start (ev-default-loop 0) timer)
    (ev-watcher-active? timer)))
(test* "constants" #t (and (integer? EV_READ) (integer? EV_WRITE)))

;; If you don't want `gosh' to exit with nonzero status even if
;; the test fails, pass #f to :exit-on-failure.
(test-end :exit-on-failure #t)
