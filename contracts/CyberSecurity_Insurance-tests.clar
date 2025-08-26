;; CyberSecurity Insurance: DeFi Protocol Coverage Contract
;; Provides insurance coverage against smart contract exploits and hacking incidents
;; with community-based assessment and claims processing

;; Define the insurance coverage token
(define-fungible-token coverage-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-policy-not-found (err u103))
(define-constant err-claim-already-exists (err u104))
(define-constant err-unauthorized (err u105))

;; Data Variables
(define-data-var total-pool-balance uint u0)
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)

;; Insurance Policy Structure
(define-map insurance-policies
  { policy-id: uint }
  {
    protocol-address: principal,
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  })

;; Claims Structure
(define-map insurance-claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    incident-type: (string-ascii 50),
    claimed-amount: uint,
    evidence-hash: (buff 32),
    community-votes: uint,
    status: (string-ascii 20),
    created-block: uint
  })

;; Community Assessment Votes
(define-map claim-votes
  { claim-id: uint, voter: principal }
  { vote: bool, stake-amount: uint })

;; Protocol Coverage Pool
(define-map coverage-pools principal uint)

;; Function 1: Purchase Insurance Coverage
;; Allows DeFi protocols to purchase cyber security insurance coverage
(define-public (purchase-coverage (coverage-amount uint) (coverage-duration uint) (premium-amount uint))
  (let
    (
      (policy-id (+ (var-get policy-counter) u1))
      (start-block block-height)
      (end-block (+ block-height coverage-duration))
    )
    (begin
      ;; Validate inputs
      (asserts! (> coverage-amount u0) err-invalid-amount)
      (asserts! (> premium-amount u0) err-invalid-amount)
      (asserts! (> coverage-duration u0) err-invalid-amount)
      
      ;; Transfer premium to contract
      (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
      
      ;; Create insurance policy
      (map-set insurance-policies
        { policy-id: policy-id }
        {
          protocol-address: tx-sender,
          coverage-amount: coverage-amount,
          premium-paid: premium-amount,
          start-block: start-block,
          end-block: end-block,
          active: true
        })
      
      ;; Update pool balance and policy counter
      (var-set total-pool-balance (+ (var-get total-pool-balance) premium-amount))
      (var-set policy-counter policy-id)
      
      ;; Update protocol coverage pool
      (map-set coverage-pools tx-sender coverage-amount)
      
      (print {
        event: "coverage-purchased",
        policy-id: policy-id,
        protocol: tx-sender,
        coverage-amount: coverage-amount,
        premium: premium-amount
      })
      
      (ok policy-id))))

;; Function 2: Submit Insurance Claim with Community Assessment
;; Allows insured protocols to submit claims for cyber incidents with community verification
(define-public (submit-claim (policy-id uint) (incident-type (string-ascii 50)) (claimed-amount uint) (evidence-hash (buff 32)))
  (let
    (
      (policy-data (unwrap! (map-get? insurance-policies { policy-id: policy-id }) err-policy-not-found))
      (claim-id (+ (var-get claim-counter) u1))
    )
    (begin
      ;; Verify policy exists and is active
      (asserts! (get active policy-data) err-policy-not-found)
      (asserts! (is-eq (get protocol-address policy-data) tx-sender) err-unauthorized)
      (asserts! (>= (get end-block policy-data) block-height) err-policy-not-found)
      
      ;; Validate claim amount doesn't exceed coverage
      (asserts! (<= claimed-amount (get coverage-amount policy-data)) err-invalid-amount)
      (asserts! (> claimed-amount u0) err-invalid-amount)
      
      ;; Check if claim already exists for this policy
      (asserts! (is-none (map-get? insurance-claims { claim-id: policy-id })) err-claim-already-exists)
      
      ;; Create insurance claim
      (map-set insurance-claims
        { claim-id: claim-id }
        {
          policy-id: policy-id,
          claimant: tx-sender,
          incident-type: incident-type,
          claimed-amount: claimed-amount,
          evidence-hash: evidence-hash,
          community-votes: u0,
          status: "pending-assessment",
          created-block: block-height
        })
      
      ;; Update claim counter
      (var-set claim-counter claim-id)
      
      (print {
        event: "claim-submitted",
        claim-id: claim-id,
        policy-id: policy-id,
        claimant: tx-sender,
        incident-type: incident-type,
        amount: claimed-amount
      })
      
      (ok claim-id))))

;; Read-only functions for querying contract state

;; Get policy details
(define-read-only (get-policy (policy-id uint))
  (map-get? insurance-policies { policy-id: policy-id }))

;; Get claim details
(define-read-only (get-claim (claim-id uint))
  (map-get? insurance-claims { claim-id: claim-id }))

;; Get total pool balance
(define-read-only (get-pool-balance)
  (var-get total-pool-balance))

;; Get protocol coverage amount
(define-read-only (get-protocol-coverage (protocol principal))
  (default-to u0 (map-get? coverage-pools protocol)))

;; Get policy counter
(define-read-only (get-total-policies)
  (var-get policy-counter))

;; Get claim counter
(define-read-only (get-total-claims)
  (var-get claim-counter))