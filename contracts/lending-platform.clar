;; NebulaTrust: Bitcoin-Backed Lending Platform
;; A decentralized lending platform allowing users to take loans using Bitcoin as collateral

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-INSUFFICIENT-FUNDS (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-TRUST-NOT-FOUND (err u102))
(define-constant ERR-TRUST-ALREADY-EXISTS (err u103))
(define-constant ERR-TRUST-REPAYMENT-FAILED (err u104))
(define-constant ERR-FORECLOSURE-NOT-ALLOWED (err u105))
(define-constant ERR-INVALID-PARAMETER (err u106))
(define-constant ERR-INSUFFICIENT-SECURITY (err u107))

;; Maximum values to prevent overflow
(define-constant MAX-INTEREST-RATE u10000) ;; 100.00%
(define-constant MAX-TRUST-DURATION u52560) ;; Approximately 1 year in blocks
(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant SECURITY-RATIO u150) ;; 150% minimum security ratio

;; Data Maps
(define-map trusts 
  {
    trust-id: uint,
    beneficiary: principal
  }
  {
    security-amount: uint,
    credit-amount: uint,
    yield-rate: uint,
    trust-start-block: uint,
    trust-duration: uint,
    is-active: bool
  }
)

(define-map trust-settlements
  {
    trust-id: uint,
    beneficiary: principal
  }
  {
    total-settled: uint
  }
)

;; Variables
(define-data-var next-trust-id uint u0)

;; Internal Functions
(define-private (validate-trust-parameters 
    (security-amount uint)
    (credit-amount uint)
    (yield-rate uint)
    (trust-duration uint)
  )
  (and
    (> security-amount u0)
    (<= security-amount MAX-UINT)
    (> credit-amount u0)
    (<= credit-amount MAX-UINT)
    (<= yield-rate MAX-INTEREST-RATE)
    (> trust-duration u0)
    (<= trust-duration MAX-TRUST-DURATION)
  )
)

;; Validate trust ID exists and belongs to the beneficiary
(define-private (validate-trust-ownership (trust-id uint))
  (is-some 
    (map-get? trusts {
      trust-id: trust-id, 
      beneficiary: tx-sender
    })
  )
)

;; Calculate minimum required security for a trust
(define-private (calculate-min-security (credit-amount uint))
  (/ (* credit-amount SECURITY-RATIO) u100)
)

;; Read-only Functions
(define-read-only (get-trust-details (trust-id uint) (beneficiary principal))
  (map-get? trusts {trust-id: trust-id, beneficiary: beneficiary})
)

(define-read-only (get-trust-settlement-status (trust-id uint) (beneficiary principal))
  (map-get? trust-settlements {trust-id: trust-id, beneficiary: beneficiary})
)

;; Public Functions
(define-public (create-trust 
    (security-amount uint)
    (credit-amount uint)
    (yield-rate uint)
    (trust-duration uint)
  )
  (let 
    (
      (current-trust-id (var-get next-trust-id))
      (new-trust-id (+ current-trust-id u1))
    )
    ;; Validate trust parameters
    (asserts! 
      (validate-trust-parameters 
        security-amount 
        credit-amount 
        yield-rate 
        trust-duration
      ) 
      ERR-INVALID-PARAMETER
    )
    
    ;; Check if trust already exists
    (asserts! 
      (is-none 
        (map-get? trusts {trust-id: new-trust-id, beneficiary: tx-sender})
      ) 
      ERR-TRUST-ALREADY-EXISTS
    )
    
    ;; Validate security amount
    (asserts! 
      (>= security-amount (calculate-min-security credit-amount)) 
      ERR-INSUFFICIENT-SECURITY
    )
    
    ;; Create trust entry
    (map-set trusts 
      {trust-id: new-trust-id, beneficiary: tx-sender}
      {
        security-amount: security-amount,
        credit-amount: credit-amount,
        yield-rate: yield-rate,
        trust-start-block: block-height,
        trust-duration: trust-duration,
        is-active: true
      }
    )
    
    ;; Update next trust ID
    (var-set next-trust-id new-trust-id)
    
    ;; Return trust ID
    (ok new-trust-id)
  )
)

(define-public (add-security (trust-id uint) (additional-amount uint))
  (let
    (
      ;; Validate trust ownership first
      (trust-exists (asserts! 
        (validate-trust-ownership trust-id) 
        ERR-UNAUTHORIZED
      ))
      
      (trust (unwrap! 
        (map-get? trusts {trust-id: trust-id, beneficiary: tx-sender}) 
        ERR-TRUST-NOT-FOUND
      ))
    )
    ;; Validate trust is active
    (asserts! (get is-active trust) ERR-UNAUTHORIZED)
    
    ;; Validate additional security amount
    (asserts! (> additional-amount u0) ERR-INVALID-PARAMETER)
    
    ;; Check that new total security won't overflow
    (let
      (
        (new-security-amount (+ (get security-amount trust) additional-amount))
      )
      (asserts! (<= new-security-amount MAX-UINT) ERR-INVALID-PARAMETER)
      
      ;; Update trust with new security amount
      (map-set trusts 
        {trust-id: trust-id, beneficiary: tx-sender}
        (merge trust {security-amount: new-security-amount})
      )
      
      (ok new-security-amount)
    )
  )
)

(define-public (withdraw-security (trust-id uint) (withdraw-amount uint))
  (let
    (
      ;; Validate trust ownership first
      (trust-exists (asserts! 
        (validate-trust-ownership trust-id) 
        ERR-UNAUTHORIZED
      ))
      
      (trust (unwrap! 
        (map-get? trusts {trust-id: trust-id, beneficiary: tx-sender}) 
        ERR-TRUST-NOT-FOUND
      ))
    )
    ;; Validate trust exists and is active
    (asserts! (get is-active trust) ERR-UNAUTHORIZED)
    
    ;; Validate withdrawal amount
    (asserts! (> withdraw-amount u0) ERR-INVALID-PARAMETER)
    (asserts! (<= withdraw-amount (get security-amount trust)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Calculate new security amount after withdrawal
    (let
      (
        (new-security-amount (- (get security-amount trust) withdraw-amount))
        (min-required-security (calculate-min-security (get credit-amount trust)))
      )
      ;; Ensure remaining security meets minimum requirement
      (asserts! (>= new-security-amount min-required-security) ERR-INSUFFICIENT-SECURITY)
      
      ;; Update trust with new security amount
      (map-set trusts 
        {trust-id: trust-id, beneficiary: tx-sender}
        (merge trust {security-amount: new-security-amount})
      )
      
      (ok withdraw-amount)
    )
  )
)

(define-public (settle-trust (trust-id uint))
  (let 
    (
      ;; Validate trust ownership first
      (trust-exists (asserts! 
        (validate-trust-ownership trust-id) 
        ERR-UNAUTHORIZED
      ))
      
      (trust (unwrap! 
        (map-get? trusts {trust-id: trust-id, beneficiary: tx-sender}) 
        ERR-TRUST-NOT-FOUND
      ))
      (current-settlements (default-to 
        {total-settled: u0} 
        (map-get? trust-settlements {trust-id: trust-id, beneficiary: tx-sender})
      ))
    )
    ;; Validate trust exists and is active
    (asserts! (get is-active trust) ERR-UNAUTHORIZED)
    
    ;; Calculate total settlement amount with yield
    (let 
      (
        (total-settlement (+ 
          (get credit-amount trust)
          (/ (* (get credit-amount trust) (get yield-rate trust)) u100)
        ))
      )
      ;; Validate settlement amount doesn't overflow
      (asserts! (<= total-settlement MAX-UINT) ERR-TRUST-REPAYMENT-FAILED)
      
      ;; Update trust status
      (map-set trusts 
        {trust-id: trust-id, beneficiary: tx-sender}
        (merge trust {is-active: false})
      )
      
      ;; Track settlements
      (map-set trust-settlements
        {trust-id: trust-id, beneficiary: tx-sender}
        {total-settled: total-settlement}
      )
      
      (ok total-settlement)
    )
  )
)

(define-public (foreclose-trust (trust-id uint))
  (let 
    (
      ;; Validate trust ownership first
      (trust-exists (asserts! 
        (validate-trust-ownership trust-id) 
        ERR-UNAUTHORIZED
      ))
      
      (trust (unwrap! 
        (map-get? trusts {trust-id: trust-id, beneficiary: tx-sender}) 
        ERR-TRUST-NOT-FOUND
      ))
    )
    ;; Validate trust exists
    (asserts! (get is-active trust) ERR-UNAUTHORIZED)
    
    ;; Check if trust is past due
    (asserts! 
      (> (- block-height (get trust-start-block trust)) 
         (get trust-duration trust)) 
      ERR-FORECLOSURE-NOT-ALLOWED
    )
    
    ;; Mark trust as inactive and allow foreclosure
    (map-set trusts 
      {trust-id: trust-id, beneficiary: tx-sender}
      (merge trust {is-active: false})
    )
    
    (ok true)
  )
)