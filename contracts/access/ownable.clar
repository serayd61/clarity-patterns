;; Ownable Pattern - Single owner access control
;; 
;; This pattern provides basic ownership management with:
;; - Single owner storage
;; - Ownership transfer
;; - Owner verification

;; Owner storage
(define-data-var owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-OWNER (err u401))
(define-constant ERR-INVALID-ADDRESS (err u402))

;; ==================== Read-Only Functions ====================

;; Get current owner
(define-read-only (get-owner)
  (var-get owner)
)

;; Check if account is owner
(define-read-only (is-owner (account principal))
  (is-eq account (var-get owner))
)

;; ==================== Public Functions ====================

;; Transfer ownership to new address
;; @param new-owner: New owner principal
;; @returns: (ok true) on success
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Only current owner can transfer
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
    ;; Cannot transfer to zero address (use contract principal)
    (asserts! (not (is-eq new-owner tx-sender)) ERR-INVALID-ADDRESS)
    ;; Update owner
    (var-set owner new-owner)
    (print { event: "ownership-transferred", from: tx-sender, to: new-owner })
    (ok true)
  )
)

;; Renounce ownership (no owner after this)
;; Warning: This is irreversible!
(define-public (renounce-ownership)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
    ;; Set owner to contract itself (effectively disabling owner functions)
    (var-set owner (as-contract tx-sender))
    (print { event: "ownership-renounced", previous-owner: tx-sender })
    (ok true)
  )
)

;; ==================== Trait for use in other contracts ====================
;; 
;; To use this pattern:
;; 1. Copy the code above into your contract
;; 2. Add owner checks to protected functions:
;;    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
