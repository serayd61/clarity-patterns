;; Price Oracle Pattern
;; A decentralized price feed pattern for DeFi applications
;; Supports multiple price sources and weighted averages

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))
(define-constant ERR_STALE_PRICE (err u102))
(define-constant ERR_SOURCE_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))

;; Price staleness threshold (in blocks) - ~2 hours
(define-constant STALENESS_THRESHOLD u120)

;; Data structures
(define-map prices
  { asset: (string-ascii 12) }
  {
    price: uint,           ;; Price in micro-units (6 decimals)
    last-update: uint,     ;; Block height of last update
    source-count: uint     ;; Number of sources that contributed
  }
)

(define-map price-sources
  { asset: (string-ascii 12), source: principal }
  {
    price: uint,
    weight: uint,          ;; Weight for weighted average (1-100)
    last-update: uint,
    active: bool
  }
)

(define-map authorized-sources
  { source: principal }
  { authorized: bool }
)

;; Data variables
(define-data-var min-sources uint u1)

;; Authorization check
(define-private (is-authorized (source principal))
  (default-to false (get authorized (map-get? authorized-sources { source: source })))
)

;; Admin functions
(define-public (add-authorized-source (source principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-sources { source: source } { authorized: true }))
  )
)

(define-public (remove-authorized-source (source principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-sources { source: source } { authorized: false }))
  )
)

(define-public (set-min-sources (min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> min u0) ERR_INVALID_PRICE)
    (ok (var-set min-sources min))
  )
)

;; Price submission
(define-public (submit-price (asset (string-ascii 12)) (price uint) (weight uint))
  (let
    (
      (source tx-sender)
      (current-block block-height)
    )
    ;; Validate
    (asserts! (is-authorized source) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (and (>= weight u1) (<= weight u100)) ERR_INVALID_PRICE)
    
    ;; Update source price
    (map-set price-sources
      { asset: asset, source: source }
      {
        price: price,
        weight: weight,
        last-update: current-block,
        active: true
      }
    )
    
    ;; Recalculate aggregate price
    (ok (update-aggregate-price asset))
  )
)

;; Calculate weighted average price
(define-private (update-aggregate-price (asset (string-ascii 12)))
  (let
    (
      (current-block block-height)
      ;; In production, iterate through all sources
      ;; This is simplified for the pattern
      (source-data (map-get? price-sources { asset: asset, source: CONTRACT_OWNER }))
    )
    (match source-data
      data
      (map-set prices
        { asset: asset }
        {
          price: (get price data),
          last-update: current-block,
          source-count: u1
        }
      )
      false
    )
  )
)

;; Read functions
(define-read-only (get-price (asset (string-ascii 12)))
  (let
    (
      (price-data (map-get? prices { asset: asset }))
    )
    (match price-data
      data
      (begin
        ;; Check staleness
        (asserts! 
          (<= (- block-height (get last-update data)) STALENESS_THRESHOLD)
          ERR_STALE_PRICE
        )
        (ok (get price data))
      )
      ERR_SOURCE_NOT_FOUND
    )
  )
)

(define-read-only (get-price-data (asset (string-ascii 12)))
  (map-get? prices { asset: asset })
)

(define-read-only (get-source-price (asset (string-ascii 12)) (source principal))
  (map-get? price-sources { asset: asset, source: source })
)

(define-read-only (is-price-fresh (asset (string-ascii 12)))
  (let
    (
      (price-data (map-get? prices { asset: asset }))
    )
    (match price-data
      data
      (<= (- block-height (get last-update data)) STALENESS_THRESHOLD)
      false
    )
  )
)

(define-read-only (get-min-sources)
  (var-get min-sources)
)

;; Price conversion helpers
(define-read-only (convert-amount (asset-from (string-ascii 12)) (asset-to (string-ascii 12)) (amount uint))
  (let
    (
      (price-from (unwrap! (get-price asset-from) ERR_SOURCE_NOT_FOUND))
      (price-to (unwrap! (get-price asset-to) ERR_SOURCE_NOT_FOUND))
    )
    ;; amount * price-from / price-to
    (ok (/ (* amount price-from) price-to))
  )
)

;; Emergency functions
(define-public (pause-source (asset (string-ascii 12)) (source principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? price-sources { asset: asset, source: source })
      data
      (ok (map-set price-sources
        { asset: asset, source: source }
        (merge data { active: false })
      ))
      ERR_SOURCE_NOT_FOUND
    )
  )
)
