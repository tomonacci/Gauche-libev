;;;
;;; libev
;;;

(define-module control.libev
  (use gauche.parameter)
  (export EV_READ EV_WRITE
          EVRUN_NOWAIT EVRUN_ONCE
          EVFLAG_AUTO
          EVFLAG_NOENV
          EVFLAG_FORKCHECK
          EVFLAG_NOINOTIFY
          EVFLAG_SIGNALFD
          EVFLAG_NOSIGMASK
          EVBACKEND_SELECT
          EVBACKEND_POLL
          EVBACKEND_EPOLL
          EVBACKEND_KQUEUE
          EVBACKEND_DEVPOLL
          EVBACKEND_PORT
          EVBACKEND_ALL
          EVBACKEND_MASK
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
          ev-timer-set
          ev-timer-start
          ev-timer-stop
          ev-timer-again
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

(define (ev-run . args)
  (let* ((loop (if (and (not (null? args)) (is-a? (car args) <ev-loop>)) (pop! args) (ev-thread-local-loop)))
         (flags (if (and (not (null? args)) (integer? (car args))) (pop! args) 0)))
    (unless (null? args)
      (error "too many arguments given"))
    (%ev-run loop flags)))

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
    (when (not (or (null? args) (keyword? (car args))))
      (set! (~ watcher'callback) (pop! args)))
    (unless (null? args)
      (let ((%after
             (if (keyword? (car args))
               0
               (pop! args)))
            (%repeat
             (if (or (null? args) (keyword? (car args)))
               (~ watcher'repeat)
               (pop! args)))
            )
        (let-keywords args ((after %after) (repeat %repeat))
          (when (ev-watcher-active? watcher)
            (ev-timer-stop watcher))
          (ev-timer-set watcher after repeat)
          )))
    (%ev-timer-start (or loop (~ watcher'loop)) watcher)))

(define (ev-timer-again loop-or-watcher :optional watcher)
  (if (undefined? watcher)
    (%ev-timer-again (~ loop-or-watcher'loop) loop-or-watcher)
    (%ev-timer-again loop-or-watcher watcher)))
