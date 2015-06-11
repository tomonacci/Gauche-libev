;;;
;;; Test control.libev
;;;

(use gauche.test)

(test-start "control.libev")
(use control.libev)
(test-module 'control.libev)

(test* "ev-io-new" #t (is-a? (ev-io-new) <ev-io-watcher>))
(test* "ev-default-loop" #t (is-a? (ev-default-loop 0) <ev-loop>))
(test* "ev-loop-new" #t (is-a? (ev-loop-new 0) <ev-loop>))
(test* "<ev-watcher>" #t (is-a? <ev-watcher> <class>))
(test* "ev-signal-new" #t (is-a? (ev-signal-new) <ev-signal-watcher>))
(test* "ev-timer-new" #t (is-a? (ev-timer-new) <ev-timer-watcher>))
(test* "constants" #t (and (integer? EV_READ) (integer? EV_WRITE)))

;; If you don't want `gosh' to exit with nonzero status even if
;; the test fails, pass #f to :exit-on-failure.
(test-end :exit-on-failure #t)
