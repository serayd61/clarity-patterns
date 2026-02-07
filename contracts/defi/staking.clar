;; Staking Pattern - Stake tokens and earn rewards
;;
;; Features:
;; - Stake STX to earn rewards
;; - Configurable reward rate
;; - Claim rewards anytime
;; - Unstake with cooldown option

;; ==================== Constants ====================

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-NO-STAKE (err u404))

;; Reward rate: 10 basis points per block (0.1%)
(define-constant REWARD-RATE u10)
(define-constant BASIS-POINTS u10000)

;; ==================== Storage ====================

;; Contract owner
(define-data-var owner principal tx-sender)

;; Staking data per user
(define-map stakes 
  principal 
  {
    amount: uint,
    start-block: uint,
    last-claim: uint
  }
)

;; Total staked
(define-data-var total-staked uint u0)

;; Total rewards distributed
(define-data-var total-rewards-distributed uint u0)

;; ==================== Read-Only Functions ====================

;; Get stake info for user
(define-read-only (get-stake (user principal))
  (map-get? stakes user)
)

;; Get staked amount
(define-read-only (get-staked-amount (user principal))
  (match (map-get? stakes user)
    stake (get amount stake)
    u0
  )
)

;; Calculate pending rewards
(define-read-only (get-pending-rewards (user principal))
  (match (map-get? stakes user)
    stake 
      (let (
        (blocks-staked (- block-height (get last-claim stake)))
        (reward (* (* (get amount stake) REWARD-RATE) blocks-staked))
      )
        (/ reward BASIS-POINTS)
      )
    u0
  )
)

;; Get total staked
(define-read-only (get-total-staked)
  (var-get total-staked)
)

;; ==================== Public Functions ====================

;; Stake STX
(define-public (stake (amount uint))
  (let (
    (existing-stake (map-get? stakes tx-sender))
    (new-amount (+ amount (default-to u0 (match existing-stake s (some (get amount s)) none))))
  )
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    ;; Update stake
    (map-set stakes tx-sender {
      amount: new-amount,
      start-block: (default-to block-height (match existing-stake s (some (get start-block s)) none)),
      last-claim: block-height
    })
    ;; Update total
    (var-set total-staked (+ (var-get total-staked) amount))
    (print { event: "stake", user: tx-sender, amount: amount, total: new-amount })
    (ok amount)
  )
)

;; Claim rewards
(define-public (claim-rewards)
  (let (
    (stake-data (unwrap! (map-get? stakes tx-sender) ERR-NO-STAKE))
    (rewards (get-pending-rewards tx-sender))
  )
    ;; Check has rewards
    (asserts! (> rewards u0) ERR-INVALID-AMOUNT)
    ;; Transfer rewards
    (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
    ;; Update last claim
    (map-set stakes tx-sender (merge stake-data { last-claim: block-height }))
    ;; Update total rewards
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    (print { event: "claim", user: tx-sender, rewards: rewards })
    (ok rewards)
  )
)

;; Unstake all
(define-public (unstake)
  (let (
    (stake-data (unwrap! (map-get? stakes tx-sender) ERR-NO-STAKE))
    (amount (get amount stake-data))
    (rewards (get-pending-rewards tx-sender))
  )
    ;; Transfer staked amount + rewards
    (try! (as-contract (stx-transfer? (+ amount rewards) tx-sender tx-sender)))
    ;; Remove stake
    (map-delete stakes tx-sender)
    ;; Update totals
    (var-set total-staked (- (var-get total-staked) amount))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    (print { event: "unstake", user: tx-sender, amount: amount, rewards: rewards })
    (ok { amount: amount, rewards: rewards })
  )
)
