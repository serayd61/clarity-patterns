;; Voting Pattern - On-chain governance voting
;;
;; Features:
;; - Create proposals
;; - Vote with token weight
;; - Quorum requirements
;; - Time-limited voting periods

;; ==================== Constants ====================

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-VOTED (err u403))
(define-constant ERR-VOTING-ENDED (err u404))
(define-constant ERR-VOTING-ACTIVE (err u405))
(define-constant ERR-QUORUM-NOT-MET (err u406))

;; Voting period: 144 blocks (~1 day)
(define-constant VOTING-PERIOD u144)

;; Quorum: 10% of total votes needed
(define-constant QUORUM-PERCENTAGE u10)

;; ==================== Storage ====================

;; Contract owner
(define-data-var owner principal tx-sender)

;; Proposal counter
(define-data-var proposal-count uint u0)

;; Proposals
(define-map proposals 
  uint 
  {
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool
  }
)

;; Vote records: (proposal-id, voter) => vote
(define-map votes 
  { proposal-id: uint, voter: principal }
  { support: bool, weight: uint }
)

;; ==================== Read-Only Functions ====================

;; Get proposal
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; Get vote for user on proposal
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Check if proposal passed
(define-read-only (proposal-passed (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal 
      (let (
        (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
        (quorum-votes (/ (* total-votes QUORUM-PERCENTAGE) u100))
      )
        (and 
          (>= block-height (get end-block proposal))
          (> (get votes-for proposal) (get votes-against proposal))
          (>= total-votes quorum-votes)
        )
      )
    false
  )
)

;; Get proposal count
(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

;; ==================== Public Functions ====================

;; Create a new proposal
(define-public (create-proposal (title (string-utf8 128)) (description (string-utf8 512)))
  (let (
    (proposal-id (+ (var-get proposal-count) u1))
  )
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      start-block: block-height,
      end-block: (+ block-height VOTING-PERIOD),
      votes-for: u0,
      votes-against: u0,
      executed: false
    })
    (var-set proposal-count proposal-id)
    (print { event: "proposal-created", id: proposal-id, proposer: tx-sender })
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (support bool) (weight uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
  )
    ;; Check voting is active
    (asserts! (<= block-height (get end-block proposal)) ERR-VOTING-ENDED)
    ;; Check hasn't voted
    (asserts! (is-none (get-vote proposal-id tx-sender)) ERR-ALREADY-VOTED)
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: tx-sender }
      { support: support, weight: weight }
    )
    ;; Update proposal totals
    (if support
      (map-set proposals proposal-id 
        (merge proposal { votes-for: (+ (get votes-for proposal) weight) }))
      (map-set proposals proposal-id 
        (merge proposal { votes-against: (+ (get votes-against proposal) weight) }))
    )
    (print { event: "vote", proposal-id: proposal-id, voter: tx-sender, support: support, weight: weight })
    (ok true)
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
  )
    ;; Check voting ended
    (asserts! (>= block-height (get end-block proposal)) ERR-VOTING-ACTIVE)
    ;; Check passed
    (asserts! (proposal-passed proposal-id) ERR-QUORUM-NOT-MET)
    ;; Mark as executed
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (print { event: "proposal-executed", id: proposal-id })
    (ok true)
  )
)
