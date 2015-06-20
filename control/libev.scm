;;;
;;; libev
;;;

(define-module control.libev
  (use gauche.parameter)
  (export EV_READ EV_WRITE
          <ev-loop>
          ev-default-loop
          ev-loop-new
          ev-run
          ev-thread-local-loop
          <ev-watcher>
          ev-watcher-active?
          ev-watcher-pending?
          ev-watcher-clear-pending
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

(define ev-thread-local-loop
  (make-parameter (undefined)))

(define-method slot-unbound ((class <class>) (watcher <ev-watcher>) slot)
  (if (eq? slot 'loop)
    (let1 loop (ev-thread-local-loop)
      (if (is-a? loop <ev-loop>)
        loop
        (next-method)))
    (next-method)))

(define (ev-watcher-clear-pending loop-or-watcher :optional watcher)
  (if (undefined? watcher)
    (%ev-watcher-clear-pending (~ loop-or-watcher'loop) loop-or-watcher)
    (%ev-watcher-clear-pending loop-or-watcher watcher)))

(define (ev-io-start . args)
  (let* ((loop (and (is-a? (car args) <ev-loop>) (pop! args)))
         (watcher (pop! args)))
    (when (not (or (null? args) (keyword? (car args))))
      (set! (~ watcher'callback) (pop! args)))
    (unless (null? args)
      (let ((%fd
             (if (keyword? (car args))
               (~ watcher'fd)
               (pop! args)))
            (%events
             (if (or (null? args) (keyword? (car args)))
               (~ watcher'events)
               (pop! args)))
            )
        (let-keywords args ((fd %fd) (events %events))
          (when (ev-watcher-active? watcher)
            (ev-io-stop watcher))
          (ev-io-set watcher fd events)
          )))
    (%ev-io-start (or loop (~ watcher'loop)) watcher)))

(define (ev-timer-start . args)
  (let* ((loop (and (is-a? (car args) <ev-loop>) (pop! args)))
         (watcher (pop! args)))
    (%ev-timer-start (or loop (~ watcher'loop)) watcher)))
