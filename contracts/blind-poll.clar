;; === constants ===

(define-constant err-old-poll-not-closed (err -1001))
(define-constant err-answer-maximum-reached (err -1002))
(define-constant err-inconsistent-answer-hash (err -1003))
(define-constant err-claimed-already (err -1004))

;; === storage ===

(define-data-var pid-counter uint u0)

(define-map poll-owned-by ((addr principal)) ((last-pid uint)))

(define-map poll-closed ((poll-id uint)) ((closed bool)))

(define-map poll-detail 
  ((poll-id uint))
  (
    (owner principal) ;; poll creator
    (subject (buff 128))
    (start-time uint) ;; (preserved) Unix epoch timestamp in second
    (duration uint) ;; (preserved) in seconds, period of time the poll lasts for
    (claim-duration uint) ;; (preserved) in seconds, period of time within which a participant could claim rewards
    (rewards uint) ;; in BPT
    (max-count uint) ;; maximum count of participants
    (questions (buff 5120)) ;; encoded questions in raw bytes
  )
)

;; struct for submitted answers
(define-map answer-indexer ((poll-id uint) (i uint)) ((sender principal)))
(define-map answer-counter ((poll-id uint)) ((count-sealed uint) (count-revealed uint)))
(define-map poll-answers-sealed
  ((poll-id uint) (addr principal))
  ((answer-sealed (buff 32)))
)
(define-map poll-answers-revealed
  ((poll-id uint) (addr principal))
  ((answer (buff 512)))
)

;; === helper functions ===

;; reversed concat
(define-private (concat-reversed (a (buff 1024)) (b (buff 1024)))
  (concat b a)
)

;; get the mined time of the latest block
(define-private (get-curr-block-time)
  (begin
    (print block-height)
    (print (get-block-info? time u1))
    u1
  )
)

;; === access controls ===
(define-private (panic-if-not-poll-owner (pid uint))
  (let ((detail (query-poll-full-by-id pid)))
    (unwrap-panic
      (if (is-eq (get owner detail) tx-sender)
        (ok 1)
        (err 0)
      )
    )  
  )
)

;; panic if the specified poll is closed
(define-private (panic-if-poll-closed (pid uint))
  (unwrap-panic
    (if (is-poll-closed pid)
      (err 0)
      (ok 1)
    )
  )
)

;; panic if the specified poll is not closed
(define-private (panic-if-poll-not-closed (pid uint))
  (unwrap-panic
    (if (is-poll-closed pid)
      (ok 1)
      (err 0)
    )
  )
)

;; panic if it's not within the claim period
(define-private (panic-if-not-within-claim-period (pid uint))
  (let ((detail (query-poll-full-by-id pid)))
    (let 
      (
        (start-time (get start-time detail))
        (duration (get duration detail))
        (claim-duration (get claim-duration detail))
        (curr-time (get-curr-block-time))
      )
      (unwrap-panic
        (if (and
            (> curr-time (+ start-time duration))
            (< curr-time (+ start-time duration claim-duration))
          )
          (ok 1)
          (err 0)
        )
      )
    )
  )
)

;; panic if the poll is not concluded
(define-private (panic-if-poll-not-concluded (pid uint))
  (let ((detail (query-poll-full-by-id pid)))
    (unwrap-panic
      (if (< (get-curr-block-time) (+ (get start-time detail) (get duration detail) (get claim-duration detail)))
        (err 0)
        (ok 1)
      )
    )
  )
)

;; === private functions ===

;; check if specific poll has closed
(define-private (is-poll-closed (pid uint))
  (get closed (unwrap-panic (map-get? poll-closed ((poll-id pid)))))
)

;; negation of is-poll-closed
(define-private (is-poll-not-closed (id uint)) (not (is-poll-closed id)))

;; query specified poll detail by ID
(define-private (query-poll-full-by-id (pid uint)) 
  (unwrap-panic (map-get? poll-detail ((poll-id pid))))
)

;; query specified answer counter by poll ID
(define-private (query-answer-counter-by-id (pid uint))
  (unwrap-panic (map-get? answer-counter ((poll-id pid))))
)

;; === read-only functions ===

;; query poll detail by ID
(define-read-only (query-poll-by-id (id uint))
  (let ((detail (query-poll-full-by-id id)))
    (tuple
      (poll-id id)
      (subject (get subject detail))
      (rewards (get rewards detail))
      (max-count (get max-count detail))
      (questions (get questions detail))
    )
  )
)

;; query ID of the last poll created by the specified owner
(define-read-only (query-last-poll-id (owner principal))
  (default-to u0
    (get last-pid
      (map-get? poll-owned-by ((addr owner)))
    )
  )
)

;; === public functions ===

;; create new poll with rule checks
(define-public (create-poll-with-guard
  (subject (buff 128))
  ;; (duration uint)
  ;; (claim-duration uint)
  (rewards uint)
  (max-count uint)
  (questions (buff 5120)))
  (let 
    (
      (next-id (+ (var-get pid-counter) u1))
      (last-poll-id-from-sender (map-get? poll-owned-by ((addr tx-sender))))
    )
    ;; only one poll could be created by each principal before concluding
    (if (is-some last-poll-id-from-sender)
      (if (is-poll-closed (get last-pid (unwrap-panic last-poll-id-from-sender))) 
        (begin
          (create-poll next-id subject u0 u0 rewards max-count questions)
        )
        err-old-poll-not-closed
      )
      (begin 
        (create-poll next-id subject u0 u0 rewards max-count questions)        
      )
    )
  )
)

;; (internal) create poll without checks
(define-private (create-poll
  (id uint)
  (subject (buff 128))
  (duration uint)
  (claim-duration uint)
  (rewards uint)
  (max-count uint)
  (questions (buff 5120))
  )
  (let 
    (
      (last-poll-id-from-sender (map-get? poll-owned-by ((addr tx-sender))))
      ;; (start-time (get-curr-block-time))
      (start-time u0) ;; placeholder
      (this (as-contract tx-sender))
    )
    (if (and
        (var-set pid-counter id)
        (map-set poll-owned-by ((addr tx-sender)) ((last-pid id)))
        (map-insert poll-closed ((poll-id id)) ((closed false)))
        (map-insert answer-counter ((poll-id id)) ((count-sealed u0) (count-revealed u0)))
        (map-insert poll-detail ((poll-id id)) (
            (owner tx-sender)
            (subject subject)
            (start-time start-time)
            (duration duration)
            (claim-duration claim-duration)
            (rewards rewards)
            (max-count max-count)
            (questions questions)
          )
        ) 
      )
      (begin
        (unwrap-panic (contract-call? .token approve this (* max-count rewards)))
        (ok id)
      )
      (err 0)
    )
  )
)

;; close specified poll (poll owner only)
(define-public (close-poll (pid uint))
  (begin
    (panic-if-not-poll-owner pid)
    (ok (map-set poll-closed ((poll-id pid)) ((closed true))))
  )
)

;; submit sealed answers before the poll closes
(define-public (submit-answer-sealed
  (pid uint)
  (answer-sealed (buff 32))
)
  (begin
    (panic-if-poll-closed pid)
    (let ((detail (query-poll-full-by-id pid)) (counter (query-answer-counter-by-id pid)))
      (if (and
          (< (get count-sealed counter) (get max-count detail))
          (map-set answer-counter ((poll-id pid)) ((count-sealed (+ (get count-sealed counter) u1)) (count-revealed (get count-revealed counter))))
          (map-insert poll-answers-sealed ((poll-id pid) (addr tx-sender)) ((answer-sealed answer-sealed)))
        ) 
        (ok 1)
        err-answer-maximum-reached
      )  
    )
  )
)
  
;; reveal submitted answer and claim rewards after the poll closes
(define-public (reveal-answer
  (pid uint)
  (sealed (buff 32))
  (answer (buff 512))
)
  (begin
    ;; (panic-if-not-within-claim-period pid)
    (panic-if-poll-not-closed pid)

    (if 
      (and
        ;; tx sender should've submitted identical sealed answer before
        (is-eq (get answer-sealed (unwrap-panic (map-get? poll-answers-sealed ((poll-id pid) (addr tx-sender))))) sealed)
        ;; hash of answer and sealed answer should match
        (is-eq (keccak256 answer) sealed)
      )
      (let ((counter (query-answer-counter-by-id pid)) (detail (query-poll-full-by-id pid)) (recipient tx-sender))
        (if 
          (and
            (map-insert poll-answers-revealed ((poll-id pid) (addr tx-sender)) ((answer answer)))
            (map-insert answer-indexer ((poll-id pid) (i (get count-revealed counter))) ((sender tx-sender)))
            (map-set answer-counter ((poll-id pid)) ((count-sealed (get count-sealed counter)) (count-revealed (+ (get count-revealed counter) u1))))
          )
          (match (as-contract (contract-call? .token transfer-from (get owner detail) recipient (get rewards detail)))
            val
            (ok 1)
            err-code
            (err (to-int err-code))
          )
          err-claimed-already
        )
      )
      err-inconsistent-answer-hash
    )
  )
)

;; query sealed answers submitted already
(define-read-only (query-answer-count-sealed (pid uint))
  (begin
    (panic-if-not-poll-owner pid)
    (let ((counter (query-answer-counter-by-id pid)))
      (ok (get count-sealed counter))
    )
  )
)

;; query answers revealed already
(define-read-only (query-answer-count-revealed (pid uint))
  (begin
    (panic-if-not-poll-owner pid)
    (let ((counter (query-answer-counter-by-id pid)))
      (ok (get count-revealed counter))
    )
  )
)

;; collect query answer by index, providing the capacity of off-chain iteration
(define-read-only (query-answer-by-index (pid uint) (i uint))
  (begin
    (panic-if-not-poll-owner pid)
    (let ((sender (get sender (unwrap-panic (map-get? answer-indexer ((poll-id pid) (i i)))))))
      (ok (get answer (unwrap-panic (map-get? poll-answers-revealed ((poll-id pid) (addr sender))))))
    )  
  )
)

