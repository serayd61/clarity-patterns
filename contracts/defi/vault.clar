;; Vault Pattern - Secure token storage
;;
;; A vault contract for secure STX storage with:
;; - Deposit and withdrawal
;; - Balance tracking per user
;; - Emergency withdrawal

;; ==================== Constants ====================

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-PAUSED (err u404))

;; ==================== Storage ====================

;; Contract owner
(define-data-var owner principal tx-sender)

;; Pause state
(define-data-var paused bool false)

;; User balances
(define-map balances principal uint)

;; Total deposited
(define-data-var total-deposited uint u0)

;; ==================== Read-Only Functions ====================

;; Get user balance
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? balances user))
)

;; Get total deposited
(define-read-only (get-total-deposited)
  (var-get total-deposited)
)

;; Check if paused
(define-read-only (is-paused)
  (var-get paused)
)

;; Get contract STX balance
(define-read-only (get-vault-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; ==================== Public Functions ====================

;; Deposit STX into vault
(define-public (deposit (amount uint))
  (begin
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-PAUSED)
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    ;; Update user balance
    (map-set balances tx-sender (+ (get-balance tx-sender) amount))
    ;; Update total
    (var-set total-deposited (+ (var-get total-deposited) amount))
    (print { event: "deposit", user: tx-sender, amount: amount })
    (ok amount)
  )
)

;; Withdraw STX from vault
(define-public (withdraw (amount uint))
  (let ((user-balance (get-balance tx-sender)))
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-PAUSED)
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check sufficient balance
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
    ;; Transfer STX to user
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    ;; Update user balance
    (map-set balances tx-sender (- user-balance amount))
    ;; Update total
    (var-set total-deposited (- (var-get total-deposited) amount))
    (print { event: "withdraw", user: tx-sender, amount: amount })
    (ok amount)
  )
)

;; ==================== Admin Functions ====================

;; Pause/unpause contract
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (var-set paused new-paused)
    (print { event: "pause-changed", paused: new-paused })
    (ok true)
  )
)

;; Emergency withdraw all (owner only)
(define-public (emergency-withdraw)
  (let ((balance (get-vault-balance)))
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (try! (as-contract (stx-transfer? balance tx-sender tx-sender)))
    (print { event: "emergency-withdraw", amount: balance })
    (ok balance)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  )
)
