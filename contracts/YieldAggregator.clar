;; YieldAggregator - A yield aggregation contract
;; Functions:
;; - Admin registers strategy contracts with weights
;; - Users deposit STX to mint shares
;; - Aggregator distributes deposits to strategies
;; - Users can withdraw by redeeming shares

;; --- Constants
(define-constant BP_SCALE u10000)  ;; basis points scale
(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-ZERO (err u101))
(define-constant ERR-STRAT-NOT-FOUND (err u102))
(define-constant ERR-STRAT-REJECT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-TRANSFER_FAIL (err u105))
(define-constant ERR-WITHDRAW_FAIL (err u106))
(define-constant ERR-INVALID-WEIGHT (err u107))
(define-constant ERR-INVALID-STRATEGY (err u108))

;; --- Strategy trait that each strategy must implement
(define-trait strategy-trait
  (
    (receive-deposit (uint) (response bool uint))        ;; called after aggregator transfers STX to strategy account
    (withdraw-to (uint principal) (response bool uint))  ;; instruct strategy to send STX back to `principal`
    (report-balance () (response uint uint))             ;; optional: returns STX balance the strategy controls
  )
)

;; --- Data vars and maps
(define-data-var admin principal tx-sender)
(define-data-var strategy-count uint u0)
(define-data-var total-shares uint u0)
(define-data-var total-deposited uint u0)

(define-map strategies {idx: uint} {addr: principal, weight: uint})
(define-map shares {owner: principal} {amount: uint})

;; --- Read-only functions
(define-read-only (get-shares (who principal))
  (default-to u0 (get amount (map-get? shares {owner: who}))))

(define-read-only (get-strategy (idx uint))
  (map-get? strategies {idx: idx}))

(define-read-only (get-strategy-balance (idx uint))
  (stx-get-balance tx-sender))

(define-read-only (sum-all-assets)
  (stx-get-balance tx-sender))

;; --- Public functions
(define-public (register-strategy (strategy-principal <strategy-trait>) (weight uint))
  (let ((count (var-get strategy-count)))
    (begin 
      (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
      (asserts! (> weight u0) ERR-INVALID-WEIGHT)
      (asserts! (map-insert strategies 
                          {idx: count}
                          {addr: tx-sender, weight: weight}) 
                ERR-INVALID-STRATEGY)
      (var-set strategy-count (+ count u1))
      (ok true))))

(define-public (update-weight (idx uint) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
    (asserts! (> weight u0) ERR-INVALID-WEIGHT)
    (asserts! (<= idx (var-get strategy-count)) ERR-STRAT-NOT-FOUND)
    (let ((existing-strat (unwrap! (map-get? strategies {idx: idx}) ERR-STRAT-NOT-FOUND)))
      (map-set strategies 
               {idx: idx}
               {addr: (get addr existing-strat), weight: weight})
      (ok true))))

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR-ZERO)
    (asserts! (is-ok (stx-transfer? amount tx-sender tx-sender)) ERR-INSUFFICIENT-FUNDS)
    (let ((prev (default-to u0 (get amount (map-get? shares {owner: tx-sender})))))
      ;; mint shares 1:1 with STX (simple)
      (map-set shares {owner: tx-sender} {amount: (+ prev amount)})
      (var-set total-shares (+ (var-get total-shares) amount))
      ;; Note: distribution to strategies is now handled separately
      (ok amount))))

(define-public (withdraw (share-amount uint))
  (begin
    (asserts! (> share-amount u0) ERR-ZERO)
    (let ((user-shares (default-to u0 (get amount (map-get? shares {owner: tx-sender})))))
      (asserts! (>= user-shares share-amount) ERR-INSUFFICIENT-FUNDS)
      (let ((total-sh (var-get total-shares)))
        (asserts! (> total-sh u0) ERR-INSUFFICIENT-FUNDS)
        (let ((need (/ (* (sum-all-assets) share-amount) total-sh)))
          ;; Send assembled amount to user
          (asserts! (is-ok (stx-transfer? need tx-sender tx-sender)) ERR-TRANSFER_FAIL)
          (begin
            ;; burn shares
            (map-set shares {owner: tx-sender} {amount: (- user-shares share-amount)})
            (var-set total-shares (- total-sh share-amount))
            (ok need)))))))