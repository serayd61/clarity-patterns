;; ============================================
;; Pausable Contract Pattern
;; ============================================
;; Emergency stop mechanism for smart contracts
;; Allows authorized parties to pause/unpause operations
;; ============================================

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-PAUSED (err u2002))
(define-constant ERR-NOT-PAUSED (err u2003))
(define-constant ERR-INVALID-GUARDIAN (err u2004))
(define-constant ERR-COOLDOWN-ACTIVE (err u2005))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var is-paused bool false)
(define-data-var pause-timestamp uint u0)
(define-data-var unpause-cooldown uint u144) ;; ~24 hours in blocks

;; Guardian system - multiple parties can pause
(define-map guardians principal bool)
(define-map pause-votes principal bool)
(define-data-var required-votes uint u1)
(define-data-var current-votes uint u0)

;; ============================================
;; Authorization
;; ============================================

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (is-guardian)
  (or (is-owner) (default-to false (map-get? guardians tx-sender))))

;; ============================================
;; Basic Pause Functions
;; ============================================

;; Simple pause - only owner
(define-public (pause)
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (var-set is-paused true)
    (var-set pause-timestamp block-height)
    (print { event: "paused", by: tx-sender, block: block-height })
    (ok true)))

;; Simple unpause - only owner with cooldown
(define-public (unpause)
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get is-paused) ERR-NOT-PAUSED)
    ;; Optional: enforce cooldown
    (var-set is-paused false)
    (var-set pause-timestamp u0)
    (print { event: "unpaused", by: tx-sender, block: block-height })
    (ok true)))

;; ============================================
;; Guardian System
;; ============================================

(define-public (add-guardian (guardian principal))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (map-set guardians guardian true)
    (print { event: "guardian-added", guardian: guardian })
    (ok true)))

(define-public (remove-guardian (guardian principal))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (map-delete guardians guardian)
    (print { event: "guardian-removed", guardian: guardian })
    (ok true)))

;; Guardian can emergency pause
(define-public (emergency-pause)
  (begin
    (asserts! (is-guardian) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (var-set is-paused true)
    (var-set pause-timestamp block-height)
    (print { event: "emergency-paused", by: tx-sender, block: block-height })
    (ok true)))

;; ============================================
;; Multi-sig Pause (requires multiple votes)
;; ============================================

(define-public (set-required-votes (votes uint))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (var-set required-votes votes)
    (ok true)))

(define-public (vote-pause)
  (begin
    (asserts! (is-guardian) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (asserts! (not (default-to false (map-get? pause-votes tx-sender))) ERR-NOT-AUTHORIZED)
    
    (map-set pause-votes tx-sender true)
    (var-set current-votes (+ (var-get current-votes) u1))
    
    ;; Auto-pause if threshold reached
    (if (>= (var-get current-votes) (var-get required-votes))
      (begin
        (var-set is-paused true)
        (var-set pause-timestamp block-height)
        (print { event: "multi-sig-paused", votes: (var-get current-votes) })
        (ok true))
      (begin
        (print { event: "pause-vote", by: tx-sender, total-votes: (var-get current-votes) })
        (ok true)))))

(define-public (reset-votes)
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (var-set current-votes u0)
    (ok true)))

;; ============================================
;; Modifiers for Protected Functions
;; ============================================

(define-private (when-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-PAUSED)))

(define-private (when-paused)
  (ok (asserts! (var-get is-paused) ERR-NOT-PAUSED)))

;; ============================================
;; Example Protected Functions
;; ============================================

(define-map balances principal uint)

;; Deposit - works when not paused
(define-public (deposit (amount uint))
  (begin
    (try! (when-not-paused))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set balances tx-sender 
      (+ (default-to u0 (map-get? balances tx-sender)) amount))
    (ok amount)))

;; Withdraw - works when not paused
(define-public (withdraw (amount uint))
  (begin
    (try! (when-not-paused))
    (let ((balance (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= balance amount) (err u2010))
      (map-set balances tx-sender (- balance amount))
      (as-contract (stx-transfer? amount tx-sender tx-sender)))))

;; Emergency withdraw - only when paused
(define-public (emergency-withdraw)
  (begin
    (try! (when-paused))
    (let ((balance (default-to u0 (map-get? balances tx-sender))))
      (asserts! (> balance u0) (err u2011))
      (map-set balances tx-sender u0)
      (as-contract (stx-transfer? balance tx-sender tx-sender)))))

;; ============================================
;; Timed Pause (auto-unpause)
;; ============================================

(define-data-var auto-unpause-block uint u0)

(define-public (timed-pause (duration uint))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (var-set is-paused true)
    (var-set pause-timestamp block-height)
    (var-set auto-unpause-block (+ block-height duration))
    (print { event: "timed-pause", duration: duration, unpause-at: (var-get auto-unpause-block) })
    (ok true)))

(define-public (check-auto-unpause)
  (begin
    (if (and 
          (var-get is-paused) 
          (> (var-get auto-unpause-block) u0)
          (>= block-height (var-get auto-unpause-block)))
      (begin
        (var-set is-paused false)
        (var-set auto-unpause-block u0)
        (print { event: "auto-unpaused", block: block-height })
        (ok true))
      (ok false))))

;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-paused)
  (var-get is-paused))

(define-read-only (get-pause-info)
  {
    paused: (var-get is-paused),
    paused-at: (var-get pause-timestamp),
    auto-unpause-at: (var-get auto-unpause-block),
    required-votes: (var-get required-votes),
    current-votes: (var-get current-votes)
  })

(define-read-only (is-guardian-check (account principal))
  (default-to false (map-get? guardians account)))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances account)))

(define-read-only (get-owner)
  (var-get contract-owner))
