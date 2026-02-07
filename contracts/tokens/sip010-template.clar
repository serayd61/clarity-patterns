;; SIP-010 Token Template
;;
;; Standard fungible token implementation following SIP-010
;; https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md

;; ==================== Trait Implementation ====================

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ==================== Token Configuration ====================

;; Token metadata
(define-constant TOKEN-NAME "Template Token")
(define-constant TOKEN-SYMBOL "TMPL")
(define-constant TOKEN-DECIMALS u6)

;; Token supply
(define-constant MAX-SUPPLY u1000000000000000) ;; 1 billion with 6 decimals

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))

;; ==================== Storage ====================

;; Define the token
(define-fungible-token template-token MAX-SUPPLY)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Token URI
(define-data-var token-uri (optional (string-utf8 256)) none)

;; ==================== SIP-010 Required Functions ====================

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-transfer? template-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; Get token name
(define-read-only (get-name)
  (ok TOKEN-NAME)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

;; Get decimals
(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

;; Get balance
(define-read-only (get-balance (account principal))
  (ok (ft-get-balance template-token account))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply template-token))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; ==================== Admin Functions ====================

;; Mint tokens (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ft-mint? template-token amount recipient)
  )
)

;; Burn tokens (from own balance)
(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-burn? template-token amount tx-sender)
  )
)

;; Set token URI
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
