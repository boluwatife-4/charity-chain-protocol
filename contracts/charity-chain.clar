;; Title: CharityChain Protocol
;;
;; Summary: 
;; Decentralized Charitable Giving Infrastructure with Bitcoin-Grade Security
;;
;; Description: 
;; CharityChain revolutionizes humanitarian aid through cryptographic transparency
;; and decentralized accountability. Built on Stacks' Bitcoin-anchored architecture,
;; this protocol creates an immutable foundation where every donation is tracked
;; from inception to impact. Smart contracts enforce milestone-based fund releases,
;; ensuring donors witness tangible outcomes while empowering verified beneficiaries
;; to demonstrate real-world progress. Through programmable philanthropy, we eliminate
;; the black box of traditional charity, replacing institutional promises with
;; mathematical certainty backed by Bitcoin's unbreakable consensus.

;; SYSTEM CONSTANTS & ERROR HANDLING

;; Contract ownership state management
(define-data-var contract-owner principal tx-sender)

;; Comprehensive error code definitions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-BENEFICIARY-NOT-FOUND (err u104))
(define-constant ERR-UTILIZATION-NOT-FOUND (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Hierarchical permission system
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-MODERATOR u2)
(define-constant ROLE-BENEFICIARY u3)

;; DATA STRUCTURES & STORAGE MAPS

;; Role-based access control mapping
(define-map roles
  { user: principal }
  { role: uint }
)

;; Verified charitable organization registry
(define-map beneficiaries
  { id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 255),
    target-amount: uint,
    received-amount: uint,
    status: (string-ascii 20),
  }
)

;; Immutable donation transaction ledger
(define-map donations
  { id: uint }
  {
    donor: principal,
    beneficiary-id: uint,
    amount: uint,
    timestamp: uint,
  }
)

;; Milestone-driven fund allocation tracker
(define-map utilization
  { id: uint }
  {
    beneficiary-id: uint,
    milestone: uint,
    description: (string-utf8 255),
    amount: uint,
    status: (string-ascii 20),
  }
)

;; STATE MANAGEMENT VARIABLES

;; Global entity identification counters
(define-data-var beneficiary-count uint u0)
(define-data-var donation-count uint u0)
(define-data-var utilization-count uint u0)

;; HELPER FUNCTIONS & UTILITIES

;; Permission validation mechanism
(define-private (is-authorized
    (user principal)
    (required-role uint)
  )
  (let ((role-data (default-to { role: u0 } (map-get? roles { user: user }))))
    (>= (get role role-data) required-role)
  )
)

;; Milestone progression calculator
(define-private (get-last-milestone (beneficiary-id uint))
  (var-get utilization-count)
)

;; ACCESS CONTROL MANAGEMENT

;; User role assignment functionality
(define-public (set-role
    (user principal)
    (new-role uint)
  )
  (let ((existing-role (default-to u0 (get role (map-get? roles { user: user })))))
    (if (and
        (is-eq tx-sender (var-get contract-owner))
        (<= new-role ROLE-BENEFICIARY)
        (not (is-eq user tx-sender))
        (or
          (is-eq new-role ROLE-ADMIN)
          (is-eq new-role ROLE-MODERATOR)
          (is-eq new-role ROLE-BENEFICIARY)
        )
      )
      (ok (map-set roles { user: user } { role: new-role }))
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Role revocation mechanism
(define-public (remove-role (user principal))
  (if (and
      (is-eq tx-sender (var-get contract-owner))
      (is-some (map-get? roles { user: user }))
      (not (is-eq user tx-sender))
    )
    (ok (map-delete roles { user: user }))
    ERR-NOT-AUTHORIZED
  )
)

;; BENEFICIARY MANAGEMENT SYSTEM

;; Charitable organization registration
(define-public (register-beneficiary
    (name (string-utf8 50))
    (description (string-utf8 255))
    (target-amount uint)
  )
  (let ((beneficiary-id (+ (var-get beneficiary-count) u1)))
    (if (and
        (is-authorized tx-sender ROLE-MODERATOR)
        (> (len name) u0)
        (> (len description) u0)
        (> target-amount u0)
      )
      (begin
        (map-set beneficiaries { id: beneficiary-id } {
          name: name,
          description: description,
          target-amount: target-amount,
          received-amount: u0,
          status: "active",
        })
        (var-set beneficiary-count beneficiary-id)
        (ok beneficiary-id)
      )
      ERR-INVALID-INPUT
    )
  )
)

;; Beneficiary information retrieval
(define-read-only (get-beneficiary (id uint))
  (match (map-get? beneficiaries { id: id })
    beneficiary (ok beneficiary)
    ERR-BENEFICIARY-NOT-FOUND
  )
)

;; DONATION PROCESSING ENGINE

;; Secure donation transaction handler
(define-public (donate
    (beneficiary-id uint)
    (amount uint)
  )
  (let ((beneficiary (unwrap! (get-beneficiary beneficiary-id) ERR-BENEFICIARY-NOT-FOUND)))
    (if (and
        (> amount u0)
        (< beneficiary-id (+ (var-get beneficiary-count) u1))
        (is-some (map-get? beneficiaries { id: beneficiary-id }))
      )
      (match (stx-transfer? amount tx-sender (as-contract tx-sender))
        success (begin
          (map-set beneficiaries { id: beneficiary-id }
            (merge beneficiary { received-amount: (+ (get received-amount beneficiary) amount) })
          )
          (map-set donations { id: (+ (var-get donation-count) u1) } {
            donor: tx-sender,
            beneficiary-id: beneficiary-id,
            amount: amount,
            timestamp: stacks-block-height,
          })
          (var-set donation-count (+ (var-get donation-count) u1))
          (ok true)
        )
        error
        ERR-INSUFFICIENT-FUNDS
      )
      ERR-INVALID-INPUT
    )
  )
)

;; Individual donation record retrieval
(define-read-only (get-donation-by-id (donation-id uint))
  (match (map-get? donations { id: donation-id })
    donation (ok donation)
    ERR-NOT-FOUND
  )
)

;; Total donation statistics accessor
(define-read-only (get-donation-count)
  (ok (var-get donation-count))
)

;; FUND UTILIZATION TRACKING SYSTEM

;; Impact milestone creation for transparent fund allocation
(define-public (add-utilization
    (beneficiary-id uint)
    (description (string-utf8 255))
    (amount uint)
  )
  (let ((beneficiary (unwrap! (get-beneficiary beneficiary-id) ERR-BENEFICIARY-NOT-FOUND)))
    (if (and
        (is-authorized tx-sender ROLE-ADMIN)
        (> (len description) u0)
        (> amount u0)
        (< beneficiary-id (+ (var-get beneficiary-count) u1))
      )
      (let (
          (milestone (+ (get-last-milestone beneficiary-id) u1))
          (utilization-id (+ (var-get utilization-count) u1))
        )
        (begin
          (map-set utilization { id: utilization-id } {
            beneficiary-id: beneficiary-id,
            milestone: milestone,
            description: description,
            amount: amount,
            status: "pending",
          })
          (var-set utilization-count utilization-id)
          (ok milestone)
        )
      )
      ERR-INVALID-INPUT
    )
  )
)

;; Milestone verification and fund release authorization
(define-public (approve-utilization
    (utilization-id uint)
    (beneficiary-id uint)
  )
  (let (
      (utilization-entry (unwrap! (map-get? utilization { id: utilization-id })
        ERR-UTILIZATION-NOT-FOUND
      ))
      (beneficiary (unwrap! (get-beneficiary beneficiary-id) ERR-BENEFICIARY-NOT-FOUND))
    )
    (if (and
        (is-authorized tx-sender ROLE-ADMIN)
        (is-eq (get beneficiary-id utilization-entry) beneficiary-id)
        (< beneficiary-id (+ (var-get beneficiary-count) u1))
        (< utilization-id (+ (var-get utilization-count) u1))
      )
      (if (<= (get amount utilization-entry) (get received-amount beneficiary))
        (begin
          (map-set utilization { id: utilization-id }
            (merge utilization-entry { status: "approved" })
          )
          (ok true)
        )
        ERR-INSUFFICIENT-FUNDS
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Utilization milestone data retrieval
(define-read-only (get-utilization-by-id (utilization-id uint))
  (match (map-get? utilization { id: utilization-id })
    util (ok util)
    ERR-NOT-FOUND
  )
)

;; Total utilization tracking statistics
(define-read-only (get-utilization-count)
  (ok (var-get utilization-count))
)

;; CONTRACT INITIALIZATION PROTOCOL

;; System bootstrap and security configuration
(define-private (initialize-contract)
  (begin
    (map-set roles { user: tx-sender } { role: ROLE-ADMIN })
    (var-set contract-owner tx-sender)
  )
)

;; Contract deployment initialization sequence
(initialize-contract)
