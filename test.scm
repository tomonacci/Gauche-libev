;;;
;;; Test control.libev
;;;

(use gauche.test)

(test-start "control.libev")
(use control.libev)
(test-module 'control.libev)

(test* "ev-default-loop" #t (is-a? (ev-default-loop 0) <ev-loop>))
(test* "ev-loop-new" #t (is-a? (ev-loop-new 0) <ev-loop>))

(test* "<ev-watcher>" #t (is-a? <ev-watcher> <class>))

(test-section "<ev-io>")
(test* "<ev-io> is a subclass of <ev-watcher>" <ev-watcher> (car (member <ev-watcher> (class-direct-supers <ev-io>))))
(test* "make (minimal)" #t (is-a? (make <ev-io>) <ev-io>))
(test* "make (:fd only)" ":fd and :events must be supplied together, but got only :fd" (guard (e (else (~ e'message))) (make <ev-io> :fd 0)))
(test* "make (:events only)" ":fd and :events must be supplied together, but got only :events" (guard (e (else (~ e'message))) (make <ev-io> :events 0)))
(test* "make (full)" <ev-io>
  (class-of (make <ev-io> :loop (ev-default-loop 0) :callback (^(watcher revents)) :fd 0 :events EV_READ)))
(test* "callback (r/w slot)" #t
  (let1 watcher (make <ev-io>)
    (set! (~ watcher'callback) (^(watcher revents)))
    (procedure? (~ watcher'callback))
    ))
(test* "loop (ro slot)" #t
  (let1 watcher (make <ev-io> :loop (ev-default-loop 0))
    (and
      (is-a? (~ watcher'loop) <ev-loop>)
      (guard (e (else #t))
        (set! (~ watcher'loop) (ev-default-loop 0))
        #f
        ))))

(test* "make <ev-timer>" #t (is-a? (make <ev-timer>) <ev-timer>))
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
