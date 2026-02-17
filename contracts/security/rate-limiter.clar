;; ============================================
;; Rate Limiter Pattern
;; ============================================
;; Prevents abuse by limiting transaction frequency
;; Useful for protecting against spam and DoS attacks
;; ============================================

;; Constants
(define-constant ERR-RATE-LIMITED (err u3001))
(define-constant ERR-NOT-AUTHORIZED (err u3002))
(define-constant ERR-INVALID-PARAMS (err u3003))

;; Default limits
(define-constant DEFAULT-WINDOW u144) ;; ~24 hours in blocks
(define-constant DEFAULT-MAX-CALLS u10)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var global-window uint DEFAULT-WINDOW)
(define-data-var global-max-calls uint DEFAULT-MAX-CALLS)

;; ============================================
;; User Rate Tracking
;; ============================================

;; Track user's last action and count
(define-map user-rate-data principal {
  window-start: uint,
  call-count: uint,
  last-call: uint
})

;; Per-function rate limits
(define-map function-limits (string-ascii 64) {
  window: uint,
  max-calls: uint,
  enabled: bool
})

;; Per-function user tracking
(define-map function-user-data { function: (string-ascii 64), user: principal } {
  window-start: uint,
  call-count: uint
})

;; ============================================
;; Global Rate Limiting
;; ============================================

(define-private (check-global-rate-limit)
  (let (
    (user tx-sender)
    (current-block block-height)
    (user-data (default-to 
      { window-start: current-block, call-count: u0, last-call: u0 }
      (map-get? user-rate-data user)))
    (window-start (get window-start user-data))
    (call-count (get call-count user-data))
    (window (var-get global-window))
    (max-calls (var-get global-max-calls))
  )
    ;; Check if we're in a new window
    (if (>= (- current-block window-start) window)
      ;; New window - reset count
      (begin
        (map-set user-rate-data user {
          window-start: current-block,
          call-count: u1,
          last-call: current-block
        })
        (ok true))
      ;; Same window - check limit
      (if (< call-count max-calls)
        (begin
          (map-set user-rate-data user {
            window-start: window-start,
            call-count: (+ call-count u1),
            last-call: current-block
          })
          (ok true))
        ERR-RATE-LIMITED))))

;; ============================================
;; Per-Function Rate Limiting
;; ============================================

(define-public (set-function-limit 
  (fn-name (string-ascii 64)) 
  (window uint) 
  (max-calls uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> window u0) ERR-INVALID-PARAMS)
    (asserts! (> max-calls u0) ERR-INVALID-PARAMS)
    (map-set function-limits fn-name {
      window: window,
      max-calls: max-calls,
      enabled: true
    })
    (ok true)))

(define-public (disable-function-limit (fn-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (match (map-get? function-limits fn-name)
      limit (begin
        (map-set function-limits fn-name (merge limit { enabled: false }))
        (ok true))
      ERR-INVALID-PARAMS)))

(define-private (check-function-rate-limit (fn-name (string-ascii 64)))
  (match (map-get? function-limits fn-name)
    limit 
      (if (not (get enabled limit))
        (ok true)
        (let (
          (user tx-sender)
          (current-block block-height)
          (key { function: fn-name, user: user })
          (user-data (default-to 
            { window-start: current-block, call-count: u0 }
            (map-get? function-user-data key)))
          (window-start (get window-start user-data))
          (call-count (get call-count user-data))
          (window (get window limit))
          (max-calls (get max-calls limit))
        )
          (if (>= (- current-block window-start) window)
            (begin
              (map-set function-user-data key {
                window-start: current-block,
                call-count: u1
              })
              (ok true))
            (if (< call-count max-calls)
              (begin
                (map-set function-user-data key {
                  window-start: window-start,
                  call-count: (+ call-count u1)
                })
                (ok true))
              ERR-RATE-LIMITED))))
    ;; No limit set - allow
    (ok true)))

;; ============================================
;; Cooldown Pattern
;; ============================================

(define-map user-cooldowns { user: principal, action: (string-ascii 64) } uint)

(define-private (check-cooldown (action (string-ascii 64)) (cooldown-blocks uint))
  (let (
    (key { user: tx-sender, action: action })
    (last-action (default-to u0 (map-get? user-cooldowns key)))
  )
    (if (>= (- block-height last-action) cooldown-blocks)
      (begin
        (map-set user-cooldowns key block-height)
        (ok true))
      ERR-RATE-LIMITED)))

;; ============================================
;; Sliding Window Rate Limiter
;; ============================================

;; Store timestamps of recent calls (simplified - stores last N)
(define-map sliding-window-data principal (list 20 uint))

(define-private (check-sliding-window (max-calls uint) (window uint))
  (let (
    (user tx-sender)
    (current-block block-height)
    (timestamps (default-to (list) (map-get? sliding-window-data user)))
    ;; Filter timestamps within window
    (valid-timestamps (filter is-within-window timestamps))
    (count (len valid-timestamps))
  )
    (if (< count max-calls)
      (begin
        ;; Add current timestamp
        (map-set sliding-window-data user 
          (unwrap-panic (as-max-len? (append valid-timestamps current-block) u20)))
        (ok true))
      ERR-RATE-LIMITED)))

(define-private (is-within-window (timestamp uint))
  (>= (- block-height timestamp) (var-get global-window)))

;; ============================================
;; Example Protected Functions
;; ============================================

(define-public (rate-limited-action (data uint))
  (begin
    (try! (check-global-rate-limit))
    ;; Your logic here
    (ok data)))

(define-public (function-limited-transfer (amount uint) (recipient principal))
  (begin
    (try! (check-function-rate-limit "transfer"))
    (stx-transfer? amount tx-sender recipient)))

(define-public (cooldown-claim)
  (begin
    (try! (check-cooldown "claim" u144)) ;; 24 hour cooldown
    ;; Claim logic here
    (ok true)))

;; ============================================
;; Admin Functions
;; ============================================

(define-public (set-global-limits (window uint) (max-calls uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> window u0) ERR-INVALID-PARAMS)
    (asserts! (> max-calls u0) ERR-INVALID-PARAMS)
    (var-set global-window window)
    (var-set global-max-calls max-calls)
    (ok true)))

(define-public (reset-user-limit (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-delete user-rate-data user)
    (ok true)))

;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-user-rate-info (user principal))
  (default-to 
    { window-start: u0, call-count: u0, last-call: u0 }
    (map-get? user-rate-data user)))

(define-read-only (get-remaining-calls (user principal))
  (let (
    (user-data (get-user-rate-info user))
    (window-start (get window-start user-data))
    (call-count (get call-count user-data))
    (max-calls (var-get global-max-calls))
    (window (var-get global-window))
  )
    (if (>= (- block-height window-start) window)
      max-calls
      (if (> max-calls call-count)
        (- max-calls call-count)
        u0))))

(define-read-only (get-function-limit (fn-name (string-ascii 64)))
  (map-get? function-limits fn-name))

(define-read-only (get-global-limits)
  {
    window: (var-get global-window),
    max-calls: (var-get global-max-calls)
  })

(define-read-only (can-call (user principal))
  (let (
    (remaining (get-remaining-calls user))
  )
    (> remaining u0)))
