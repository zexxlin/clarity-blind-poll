;; hard-coded contract-owner
(define-constant contract-owner 'ST37X0038BZV6YV0MQCJ0G6QMZZ75QS64KA69V9D)

(define-map allowances
  ((owner principal) (spender principal))
  ((allowance uint)))

;; stands for Blind Poll Token
(define-fungible-token bpt)

;; panic if the caller is not the contract owner
(define-private (panic-if-not-contract-owner)
  (unwrap-panic
    (if (is-eq tx-sender contract-owner) (ok 1) (err 0))
  )
)

;; panic if the caller is not token owner
(define-private (panic-if-not-token-owner (owner principal))
  (unwrap-panic
    (if (is-eq tx-sender owner) (ok 1) (err 0))
  )
)

;; query balance
(define-read-only (balance-of (owner principal))
  (ft-get-balance bpt owner)
)

;; query allowance
(define-read-only (allowance-of (owner principal) (spender principal))
  (default-to u0 (get allowance (map-get? allowances ((owner owner) (spender spender)))))
)

;; increase allowance of a specified spender.
(define-private (increase-allowance (owner principal) (spender principal) (amount uint))
  (let ((allowance (allowance-of spender owner)) (balance (balance-of owner)))
    (if (<= amount balance)
      (map-set allowances
        ((owner owner) (spender spender))
        ((allowance (+ allowance amount)))
      )
      false
    )
  )
)

;; increase allowance of a specified spender.
(define-private (decrease-allowance (owner principal) (spender principal) (amount uint))
  (let ((allowance (allowance-of owner spender)))
    (print allowance)
    (if (<= amount allowance)
      (map-set allowances
        ((owner owner) (spender spender))
        ((allowance (- allowance amount)))
      )    
      false
    )
  )
)

;; grant specified amout of allowance to spender
(define-public (approve (spender principal) (amount uint))
  (if (increase-allowance tx-sender spender amount) (ok 1) (err 0))
)

;; transfer from spender's allowance granted by owner
(define-public (transfer-from (owner principal) (recipient principal) (amount uint))
  (if (decrease-allowance owner tx-sender amount)
    (ft-transfer? bpt amount owner recipient)
    (err u0)
  )
)

;; transfer certain amount of token from tx-sender to recipient
(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? bpt amount tx-sender recipient)
)

;; mint specified amount of fungible tokens to recipient (contract owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (panic-if-not-contract-owner)
    (ft-mint? bpt amount recipient)
  )
)