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