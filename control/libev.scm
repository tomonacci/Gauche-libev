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
          <ev-stat>
          ev-stat-set
          ev-stat-start
          ev-stat-stop
          ev-stat-stat
          <ev-signal>
          ev-signal-set
          ev-signal-start
          ev-signal-stop
          )
  )
(select-module control.libev)

;; Loads extension
(dynamic-load "gauche-libev")

;;
;; Put your Scheme definitions here
;;

(define ev-thread-local-loop
  (make-parameter (undefined)))

(define-inline (optional-loop watcher)
  (if (slot-bound? watcher 'loop)
    (slot-ref watcher 'loop)
    (ev-thread-local-loop)))

(define (ev-run . args)
  (let* ((loop (if (and (not (null? args)) (is-a? (car args) <ev-loop>)) (pop! args) (ev-thread-local-loop)))
         (flags (if (and (not (null? args)) (integer? (car args))) (pop! args) 0)))
    (unless (null? args)
      (error "too many arguments given"))
    (%ev-run loop flags)))

(define (ev-watcher-clear-pending loop-or-watcher :optional watcher)
  (if (undefined? watcher)
    (%ev-watcher-clear-pending (optional-loop loop-or-watcher) loop-or-watcher)
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
    (%ev-io-start (or loop (optional-loop watcher)) watcher)))

(define (ev-timer-set watcher after repeat)
  (when (ev-watcher-active? watcher)
    (ev-timer-stop (~ watcher'loop)))
  (%ev-timer-set watcher after repeat))

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
          (ev-timer-set watcher after repeat)
          )))
    (%ev-timer-start (or loop (optional-loop watcher)) watcher)))

(define (ev-timer-again loop-or-watcher :optional watcher)
  (if (undefined? watcher)
    (%ev-timer-again (optional-loop loop-or-watcher) loop-or-watcher)
    (%ev-timer-again loop-or-watcher watcher)))

(define (ev-stat-set watcher path interval)
  (when (ev-watcher-active? watcher)
    (ev-stat-stop (~ watcher'loop)))
  (%ev-stat-set watcher path interval))

(define (ev-stat-start . args)
  (let* ((loop (and (is-a? (car args) <ev-loop>) (pop! args)))
         (watcher (pop! args)))
    (when (not (or (null? args) (keyword? (car args))))
      (set! (~ watcher'callback) (pop! args)))
    (unless (null? args)
      (let ((%path
             (if (keyword? (car args))
               0
               (pop! args)))
            (%interval
             (if (or (null? args) (keyword? (car args)))
               (~ watcher'interval)
               (pop! args)))
            )
        (let-keywords args ((path %path) (interval %interval))
          (ev-stat-set watcher path interval)
          )))
    (%ev-stat-start (or loop (optional-loop watcher)) watcher)))

(define (ev-signal-set watcher signum)
  (when (ev-watcher-active? watcher)
    (ev-signal-stop (~ watcher'loop)))
  (%ev-signal-set watcher signum))

(define (ev-signal-start . args)
  (let* ((loop (and (is-a? (car args) <ev-loop>) (pop! args)))
         (watcher (pop! args)))
    (when (not (or (null? args) (keyword? (car args))))
      (set! (~ watcher'callback) (pop! args)))
    (unless (null? args)
      (let ((%signum
             (if (keyword? (car args))
               0
               (pop! args)))
            )
        (let-keywords args ((signum %signum))
          (ev-signal-set watcher signum)
          )))
    (%ev-signal-start (or loop (optional-loop watcher)) watcher)))
