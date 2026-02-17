;; ============================================
;; Reentrancy Guard Pattern
;; ============================================
;; Prevents reentrancy attacks in Clarity smart contracts
;; Essential for any contract handling external calls
;; ============================================

;; Constants
(define-constant ERR-REENTRANCY (err u1001))
(define-constant ERR-NOT-AUTHORIZED (err u1002))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var guard-status bool false)
(define-data-var call-depth uint u0)

;; ============================================
;; Guard Modifiers
;; ============================================

;; Simple reentrancy guard - single entry
(define-private (enter-guard)
  (begin
    (asserts! (not (var-get guard-status)) ERR-REENTRANCY)
    (var-set guard-status true)
    (ok true)))

(define-private (exit-guard)
  (begin
    (var-set guard-status false)
    (ok true)))

;; ============================================
;; Depth-based Guard (for nested calls)
;; ============================================

(define-constant MAX-CALL-DEPTH u3)

(define-private (enter-depth-guard)
  (let ((current-depth (var-get call-depth)))
    (asserts! (< current-depth MAX-CALL-DEPTH) ERR-REENTRANCY)
    (var-set call-depth (+ current-depth u1))
    (ok current-depth)))

(define-private (exit-depth-guard)
  (let ((current-depth (var-get call-depth)))
    (if (> current-depth u0)
      (begin
        (var-set call-depth (- current-depth u1))
        (ok true))
      (ok true))))

;; ============================================
;; Function-specific Guards
;; ============================================

(define-map function-locks (string-ascii 64) bool)

(define-private (lock-function (fn-name (string-ascii 64)))
  (begin
    (asserts! (not (default-to false (map-get? function-locks fn-name))) ERR-REENTRANCY)
    (map-set function-locks fn-name true)
    (ok true)))

(define-private (unlock-function (fn-name (string-ascii 64)))
  (begin
    (map-delete function-locks fn-name)
    (ok true)))

;; ============================================
;; Example Protected Functions
;; ============================================

;; Protected STX transfer with reentrancy guard
(define-public (protected-transfer (amount uint) (recipient principal))
  (begin
    (try! (enter-guard))
    (let ((result (stx-transfer? amount tx-sender recipient)))
      (try! (exit-guard))
      result)))

;; Protected function with depth guard
(define-public (protected-nested-call (data uint))
  (begin
    (try! (enter-depth-guard))
    ;; Your logic here
    (let ((processed-data (* data u2)))
      (try! (exit-depth-guard))
      (ok processed-data))))

;; Protected function with named lock
(define-public (protected-withdraw (amount uint))
  (begin
    (try! (lock-function "withdraw"))
    (let ((result (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      (try! (unlock-function "withdraw"))
      result)))

;; ============================================
;; Mutex Pattern for Cross-Contract Calls
;; ============================================

(define-map mutex-locks principal bool)

(define-private (acquire-mutex (caller principal))
  (begin
    (asserts! (not (default-to false (map-get? mutex-locks caller))) ERR-REENTRANCY)
    (map-set mutex-locks caller true)
    (ok true)))

(define-private (release-mutex (caller principal))
  (begin
    (map-delete mutex-locks caller)
    (ok true)))

;; Example: Protected external call
(define-public (safe-external-call (target principal) (amount uint))
  (begin
    (try! (acquire-mutex tx-sender))
    ;; Perform external call here
    (let ((result (stx-transfer? amount tx-sender target)))
      (try! (release-mutex tx-sender))
      result)))

;; ============================================
;; Check-Effects-Interactions Pattern
;; ============================================

(define-map balances principal uint)

;; Safe withdrawal following CEI pattern
(define-public (safe-withdraw (amount uint))
  (let (
    ;; 1. CHECKS
    (sender tx-sender)
    (current-balance (default-to u0 (map-get? balances sender)))
  )
    (asserts! (>= current-balance amount) (err u1003))
    
    ;; 2. EFFECTS (update state before external call)
    (map-set balances sender (- current-balance amount))
    
    ;; 3. INTERACTIONS (external call last)
    (match (as-contract (stx-transfer? amount tx-sender sender))
      success (ok amount)
      error (begin
        ;; Revert state on failure
        (map-set balances sender current-balance)
        (err u1004)))))

;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-guard-status)
  (var-get guard-status))

(define-read-only (get-call-depth)
  (var-get call-depth))

(define-read-only (is-function-locked (fn-name (string-ascii 64)))
  (default-to false (map-get? function-locks fn-name)))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances account)))
