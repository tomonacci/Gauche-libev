;;;
;;; Test control.libev
;;;

(use gauche.parameter)
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
(test* "fd (ro slot)" #t
  (let1 watcher (make <ev-io> :fd 5 :events 0)
    (and
      (= (~ watcher'fd) 5)
      (guard (e (else #t))
        (set! (~ watcher'fd) 0)
        #f
        ))))
(test* "events (ro slot)" #t
  (let1 watcher (make <ev-io> :fd 0 :events EV_WRITE)
    (and
      (logtest (~ watcher'events) EV_WRITE)
      (guard (e (else #t))
        (set! (~ watcher'events) EV_READ)
        #f
        ))))
(test* "ev-io-set" (list 7 129)
  (let1 watcher (make <ev-io>)
    (ev-io-set watcher 7 EV_READ)
    (list (~ watcher'fd) (~ watcher'events))))
(test* "ev-io-init" (undefined)
  (ev-io-init (make <ev-io>) (^ _) 0 EV_READ))
(test* "ev-io-start (pre-set loop)" #t
  (let1 watcher (make <ev-io> :loop (ev-default-loop 0))
    (ev-io-init watcher (^ _) 0 EV_READ)
    (ev-io-start watcher)
    #t))
(test* "ev-io-start (with loop)" #t
  (let ((watcher (make <ev-io>))
        (loop (ev-default-loop 0)))
    (ev-io-init watcher (^ _) 0 EV_READ)
    (ev-io-start loop watcher)
    (eq? (~ watcher'loop) loop)))
(test* "ev-io-start (without loop)" #t
  (let1 watcher (make <ev-io>)
    (ev-io-init watcher (^ _) 0 EV_READ)
    (guard (e (else #t))
      (parameterize ((ev-thread-local-loop (undefined))) (ev-io-start watcher))
      #f)))
(test* "ev-io-stop (pre-set loop)" #t
  (let1 watcher (make <ev-io> :loop (ev-default-loop 0))
    (ev-io-stop watcher)
    #t))
(test* "ev-io-stop (without loop)" #t
  (let1 watcher (make <ev-io>)
    (guard (e (else #t))
      (ev-io-stop watcher)
      #f)))

(test* "make <ev-timer>" #t (is-a? (make <ev-timer>) <ev-timer>))
(test* "ev-timer-set" 0.1
  (let1 watcher (make <ev-timer>)
    (ev-timer-set watcher 0.5 0.1)
    (~ watcher'repeat)))
(test* "ev-timer-start (pre-set loop)" #t
  (let1 watcher (make <ev-timer> :loop (ev-default-loop 0))
    (ev-timer-init watcher (^ _) 0 EV_READ)
    (ev-timer-start watcher)
    #t))
(test* "ev-timer-start (with loop)" #t
  (let ((watcher (make <ev-timer>))
        (loop (ev-default-loop 0)))
    (ev-timer-init watcher (^ _) 0 EV_READ)
    (ev-timer-start loop watcher)
    (eq? (~ watcher'loop) loop)))
(test* "ev-timer-start (without loop)" #t
  (let1 watcher (make <ev-timer>)
    (ev-timer-init watcher (^ _) 0 EV_READ)
    (guard (e (else #t))
      (parameterize ((ev-thread-local-loop (undefined))) (ev-timer-start watcher))
      #f)))
(test* "ev-watcher-active? (inactive)" #f (ev-watcher-active? (make <ev-timer>)))
(test* "ev-watcher-active? (active)" #t
  (let1 timer (make <ev-timer>)
    (ev-timer-init timer values 0 0)
    (ev-timer-start (ev-default-loop 0) timer)
    (ev-watcher-active? timer)))
(test* "ev-watcher-clear-pending" 0
  (let1 timer (make <ev-io> :loop (ev-default-loop 0))
    (ev-watcher-clear-pending timer)))
(test* "constants" #t (and (integer? EV_READ) (integer? EV_WRITE)))

;; If you don't want `gosh' to exit with nonzero status even if
;; the test fails, pass #f to :exit-on-failure.
(test-end :exit-on-failure #t)
