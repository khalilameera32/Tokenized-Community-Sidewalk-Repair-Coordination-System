;; Accessibility Compliance Contract
;; Ensures sidewalk meets disability access standards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_LOCATION (err u501))
(define-constant ERR_COMPLIANCE_NOT_FOUND (err u502))
(define-constant ERR_INVALID_SCORE (err u503))
(define-constant ERR_ALREADY_VERIFIED (err u504))

;; Compliance criteria weights
(define-constant WEIGHT_SLOPE u20)
(define-constant WEIGHT_WIDTH u15)
(define-constant WEIGHT_SURFACE u25)
(define-constant WEIGHT_OBSTACLES u20)
(define-constant WEIGHT_SIGNAGE u20)

;; Data Variables
(define-data-var compliance-counter uint u0)
(define-data-var inspector-reward uint u200)

;; Data Maps
(define-map compliance-checks
  { check-id: uint }
  {
    location: (string-ascii 100),
    inspector: principal,
    slope-score: uint,
    width-score: uint,
    surface-score: uint,
    obstacle-score: uint,
    signage-score: uint,
    overall-score: uint,
    ada-compliant: bool,
    timestamp: uint,
    verified: bool,
    notes: (string-ascii 500)
  }
)

(define-map location-compliance
  { location: (string-ascii 100) }
  {
    latest-check-id: uint,
    compliance-status: bool,
    last-updated: uint
  }
)

(define-map inspector-stats
  { inspector: principal }
  {
    total-inspections: uint,
    verified-inspections: uint,
    compliance-rate: uint,
    tokens-earned: uint
  }
)

(define-map token-balances
  { holder: principal }
  { balance: uint }
)

;; Public Functions

;; Submit compliance check
(define-public (submit-compliance-check
  (location (string-ascii 100))
  (slope-score uint)
  (width-score uint)
  (surface-score uint)
  (obstacle-score uint)
  (signage-score uint)
  (notes (string-ascii 500))
)
  (let
    (
      (check-id (+ (var-get compliance-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (overall-score (calculate-overall-score slope-score width-score surface-score obstacle-score signage-score))
      (is-compliant (>= overall-score u70))
    )
    (asserts! (> (len location) u0) ERR_INVALID_LOCATION)
    (asserts! (and (<= slope-score u100) (<= width-score u100) (<= surface-score u100) (<= obstacle-score u100) (<= signage-score u100)) ERR_INVALID_SCORE)

    ;; Store compliance check
    (map-set compliance-checks
      { check-id: check-id }
      {
        location: location,
        inspector: tx-sender,
        slope-score: slope-score,
        width-score: width-score,
        surface-score: surface-score,
        obstacle-score: obstacle-score,
        signage-score: signage-score,
        overall-score: overall-score,
        ada-compliant: is-compliant,
        timestamp: current-time,
        verified: false,
        notes: notes
      }
    )

    ;; Update location compliance
    (map-set location-compliance
      { location: location }
      {
        latest-check-id: check-id,
        compliance-status: is-compliant,
        last-updated: current-time
      }
    )

    ;; Update inspector stats
    (update-inspector-stats tx-sender is-compliant)

    ;; Update counter
    (var-set compliance-counter check-id)

    (ok check-id)
  )
)

;; Verify compliance check (admin function)
(define-public (verify-compliance-check (check-id uint))
  (let
    (
      (check (unwrap! (map-get? compliance-checks { check-id: check-id }) ERR_COMPLIANCE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified check)) ERR_ALREADY_VERIFIED)

    ;; Update check as verified
    (map-set compliance-checks
      { check-id: check-id }
      (merge check { verified: true })
    )

    ;; Award tokens to inspector
    (let
      (
        (base-reward (var-get inspector-reward))
        (quality-bonus (if (>= (get overall-score check) u90) u50 u0))
        (total-reward (+ base-reward quality-bonus))
      )
      (award-tokens (get inspector check) total-reward)
    )

    (ok true)
  )
)

;; Report accessibility issue
(define-public (report-accessibility-issue (location (string-ascii 100)) (issue-description (string-ascii 300)))
  (begin
    (asserts! (> (len location) u0) ERR_INVALID_LOCATION)
    (asserts! (> (len issue-description) u0) ERR_INVALID_LOCATION)

    ;; Award tokens for reporting
    (award-tokens tx-sender u30)

    (ok true)
  )
)

;; Request compliance re-check
(define-public (request-recheck (location (string-ascii 100)))
  (begin
    (asserts! (> (len location) u0) ERR_INVALID_LOCATION)

    ;; Award tokens for requesting recheck
    (award-tokens tx-sender u20)

    (ok true)
  )
)

;; Read-only Functions

;; Get compliance check details
(define-read-only (get-compliance-check (check-id uint))
  (map-get? compliance-checks { check-id: check-id })
)

;; Get location compliance status
(define-read-only (get-location-compliance (location (string-ascii 100)))
  (map-get? location-compliance { location: location })
)

;; Get inspector statistics
(define-read-only (get-inspector-stats (inspector principal))
  (default-to
    { total-inspections: u0, verified-inspections: u0, compliance-rate: u0, tokens-earned: u0 }
    (map-get? inspector-stats { inspector: inspector })
  )
)

;; Get token balance
(define-read-only (get-token-balance (holder principal))
  (default-to u0 (get balance (map-get? token-balances { holder: holder })))
)

;; Check if location is ADA compliant
(define-read-only (is-ada-compliant (location (string-ascii 100)))
  (match (map-get? location-compliance { location: location })
    compliance-data (get compliance-status compliance-data)
    false
  )
)

;; Get compliance score breakdown
(define-read-only (get-compliance-breakdown (check-id uint))
  (match (map-get? compliance-checks { check-id: check-id })
    check
      (some {
        slope: (get slope-score check),
        width: (get width-score check),
        surface: (get surface-score check),
        obstacles: (get obstacle-score check),
        signage: (get signage-score check),
        overall: (get overall-score check)
      })
    none
  )
)

;; Private Functions

;; Calculate overall compliance score
(define-private (calculate-overall-score (slope uint) (width uint) (surface uint) (obstacles uint) (signage uint))
  (let
    (
      (weighted-slope (* slope WEIGHT_SLOPE))
      (weighted-width (* width WEIGHT_WIDTH))
      (weighted-surface (* surface WEIGHT_SURFACE))
      (weighted-obstacles (* obstacles WEIGHT_OBSTACLES))
      (weighted-signage (* signage WEIGHT_SIGNAGE))
      (total-weighted (+ weighted-slope (+ weighted-width (+ weighted-surface (+ weighted-obstacles weighted-signage)))))
    )
    (/ total-weighted u100)
  )
)

;; Update inspector statistics
(define-private (update-inspector-stats (inspector principal) (is-compliant bool))
  (let
    (
      (current-stats (get-inspector-stats inspector))
      (new-total (+ (get total-inspections current-stats) u1))
      (compliant-count (if is-compliant
        (+ (get verified-inspections current-stats) u1)
        (get verified-inspections current-stats)
      ))
      (new-rate (if (> new-total u0) (/ (* compliant-count u100) new-total) u0))
    )
    (map-set inspector-stats
      { inspector: inspector }
      {
        total-inspections: new-total,
        verified-inspections: compliant-count,
        compliance-rate: new-rate,
        tokens-earned: (get tokens-earned current-stats)
      }
    )
  )
)

;; Award tokens to user
(define-private (award-tokens (recipient principal) (amount uint))
  (let
    (
      (current-balance (get-token-balance recipient))
      (new-balance (+ current-balance amount))
    )
    (map-set token-balances
      { holder: recipient }
      { balance: new-balance }
    )

    ;; Update inspector stats
    (let
      (
        (current-stats (get-inspector-stats recipient))
        (new-tokens (+ (get tokens-earned current-stats) amount))
      )
      (map-set inspector-stats
        { inspector: recipient }
        (merge current-stats { tokens-earned: new-tokens })
      )
    )
  )
)
