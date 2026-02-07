;; Roles Pattern - Role-based access control
;;
;; This pattern provides flexible access control with:
;; - Multiple named roles
;; - Role assignment/revocation
;; - Role-based permission checks

;; ==================== Constants ====================

;; Role identifiers
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-MINTER u2)
(define-constant ROLE-PAUSER u3)
(define-constant ROLE-OPERATOR u4)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ROLE-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-HAS-ROLE (err u403))

;; ==================== Storage ====================

;; Admin who can manage roles
(define-data-var admin principal tx-sender)

;; Role assignments: (account, role) => bool
(define-map roles { account: principal, role: uint } bool)

;; Role member count
(define-map role-count uint uint)

;; ==================== Read-Only Functions ====================

;; Check if account has specific role
(define-read-only (has-role (account principal) (role uint))
  (default-to false (map-get? roles { account: account, role: role }))
)

;; Check if account is admin
(define-read-only (is-admin (account principal))
  (is-eq account (var-get admin))
)

;; Get admin address
(define-read-only (get-admin)
  (var-get admin)
)

;; Get role member count
(define-read-only (get-role-count (role uint))
  (default-to u0 (map-get? role-count role))
)

;; ==================== Public Functions ====================

;; Grant role to account
(define-public (grant-role (account principal) (role uint))
  (begin
    ;; Only admin can grant roles
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    ;; Check not already has role
    (asserts! (not (has-role account role)) ERR-ALREADY-HAS-ROLE)
    ;; Grant role
    (map-set roles { account: account, role: role } true)
    ;; Update count
    (map-set role-count role (+ (get-role-count role) u1))
    (print { event: "role-granted", account: account, role: role, by: tx-sender })
    (ok true)
  )
)

;; Revoke role from account
(define-public (revoke-role (account principal) (role uint))
  (begin
    ;; Only admin can revoke roles
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    ;; Check has role
    (asserts! (has-role account role) ERR-ROLE-NOT-FOUND)
    ;; Revoke role
    (map-delete roles { account: account, role: role })
    ;; Update count
    (map-set role-count role (- (get-role-count role) u1))
    (print { event: "role-revoked", account: account, role: role, by: tx-sender })
    (ok true)
  )
)

;; Transfer admin to new account
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (print { event: "admin-transferred", from: tx-sender, to: new-admin })
    (ok true)
  )
)

;; Renounce a role (self)
(define-public (renounce-role (role uint))
  (begin
    (asserts! (has-role tx-sender role) ERR-ROLE-NOT-FOUND)
    (map-delete roles { account: tx-sender, role: role })
    (map-set role-count role (- (get-role-count role) u1))
    (print { event: "role-renounced", account: tx-sender, role: role })
    (ok true)
  )
)
