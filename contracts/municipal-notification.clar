;; Municipal Notification Contract
;; Reports sidewalk issues to city maintenance departments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_DEPARTMENT (err u201))
(define-constant ERR_NOTIFICATION_EXISTS (err u202))
(define-constant ERR_NOTIFICATION_NOT_FOUND (err u203))
(define-constant ERR_INVALID_STATUS (err u204))

;; Status constants
(define-constant STATUS_PENDING u1)
(define-constant STATUS_ACKNOWLEDGED u2)
(define-constant STATUS_IN_PROGRESS u3)
(define-constant STATUS_COMPLETED u4)
(define-constant STATUS_REJECTED u5)

;; Data Variables
(define-data-var notification-counter uint u0)
(define-data-var response-timeout uint u2016) ;; ~2 weeks in blocks

;; Data Maps
(define-map notifications
  { notification-id: uint }
  {
    location: (string-ascii 100),
    reporter: principal,
    department: (string-ascii 50),
    priority-level: uint,
    description: (string-ascii 500),
    timestamp: uint,
    status: uint,
    municipal-response: (optional (string-ascii 500)),
    response-timestamp: (optional uint),
    escalated: bool
  }
)

(define-map department-notifications
  { department: (string-ascii 50) }
  { pending-count: uint, total-notifications: uint }
)

(define-map reporter-stats
  { reporter: principal }
  { total-reports: uint, acknowledged-reports: uint, tokens-earned: uint }
)

(define-map token-balances
  { holder: principal }
  { balance: uint }
)

;; Public Functions

;; Submit notification to municipal department
(define-public (submit-notification (location (string-ascii 100)) (department (string-ascii 50)) (priority-level uint) (description (string-ascii 500)))
  (let
    (
      (notification-id (+ (var-get notification-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (and (>= priority-level u1) (<= priority-level u5)) ERR_INVALID_STATUS)
    (asserts! (> (len department) u0) ERR_INVALID_DEPARTMENT)

    ;; Store notification
    (map-set notifications
      { notification-id: notification-id }
      {
        location: location,
        reporter: tx-sender,
        department: department,
        priority-level: priority-level,
        description: description,
        timestamp: current-time,
        status: STATUS_PENDING,
        municipal-response: none,
        response-timestamp: none,
        escalated: false
      }
    )

    ;; Update department stats
    (update-department-stats department)

    ;; Update reporter stats
    (update-reporter-stats tx-sender)

    ;; Update counter
    (var-set notification-counter notification-id)

    (ok notification-id)
  )
)

;; Municipal response (admin function)
(define-public (municipal-response (notification-id uint) (new-status uint) (response-message (string-ascii 500)))
  (let
    (
      (notification (unwrap! (map-get? notifications { notification-id: notification-id }) ERR_NOTIFICATION_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (>= new-status u1) (<= new-status u5)) ERR_INVALID_STATUS)

    ;; Update notification
    (map-set notifications
      { notification-id: notification-id }
      (merge notification {
        status: new-status,
        municipal-response: (some response-message),
        response-timestamp: (some current-time)
      })
    )

    ;; Award tokens for acknowledged reports
    (if (is-eq new-status STATUS_ACKNOWLEDGED)
      (award-tokens (get reporter notification) u50)
      true
    )

    ;; Award bonus tokens for completed repairs
    (if (is-eq new-status STATUS_COMPLETED)
      (award-tokens (get reporter notification) u100)
      true
    )

    (ok true)
  )
)

;; Escalate overdue notifications
(define-public (escalate-notification (notification-id uint))
  (let
    (
      (notification (unwrap! (map-get? notifications { notification-id: notification-id }) ERR_NOTIFICATION_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (time-diff (- current-time (get timestamp notification)))
    )
    (asserts! (> time-diff (var-get response-timeout)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status notification) STATUS_PENDING) ERR_INVALID_STATUS)

    ;; Mark as escalated
    (map-set notifications
      { notification-id: notification-id }
      (merge notification { escalated: true })
    )

    ;; Award escalation tokens
    (award-tokens tx-sender u25)

    (ok true)
  )
)

;; Read-only Functions

;; Get notification details
(define-read-only (get-notification (notification-id uint))
  (map-get? notifications { notification-id: notification-id })
)

;; Get department statistics
(define-read-only (get-department-stats (department (string-ascii 50)))
  (default-to
    { pending-count: u0, total-notifications: u0 }
    (map-get? department-notifications { department: department })
  )
)

;; Get reporter statistics
(define-read-only (get-reporter-stats (reporter principal))
  (default-to
    { total-reports: u0, acknowledged-reports: u0, tokens-earned: u0 }
    (map-get? reporter-stats { reporter: reporter })
  )
)

;; Get token balance
(define-read-only (get-token-balance (holder principal))
  (default-to u0 (get balance (map-get? token-balances { holder: holder })))
)

;; Check if notification is overdue
(define-read-only (is-notification-overdue (notification-id uint))
  (match (map-get? notifications { notification-id: notification-id })
    notification
      (let
        (
          (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
          (time-diff (- current-time (get timestamp notification)))
        )
        (and
          (is-eq (get status notification) STATUS_PENDING)
          (> time-diff (var-get response-timeout))
        )
      )
    false
  )
)

;; Private Functions

;; Update department statistics
(define-private (update-department-stats (department (string-ascii 50)))
  (let
    (
      (current-stats (get-department-stats department))
      (new-pending (+ (get pending-count current-stats) u1))
      (new-total (+ (get total-notifications current-stats) u1))
    )
    (map-set department-notifications
      { department: department }
      { pending-count: new-pending, total-notifications: new-total }
    )
  )
)

;; Update reporter statistics
(define-private (update-reporter-stats (reporter principal))
  (let
    (
      (current-stats (get-reporter-stats reporter))
      (new-total (+ (get total-reports current-stats) u1))
    )
    (map-set reporter-stats
      { reporter: reporter }
      (merge current-stats { total-reports: new-total })
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

    ;; Update reporter stats if applicable
    (let
      (
        (current-stats (get-reporter-stats recipient))
        (new-acknowledged (+ (get acknowledged-reports current-stats) u1))
        (new-tokens (+ (get tokens-earned current-stats) amount))
      )
      (map-set reporter-stats
        { reporter: recipient }
        (merge current-stats {
          acknowledged-reports: new-acknowledged,
          tokens-earned: new-tokens
        })
      )
    )
  )
)
