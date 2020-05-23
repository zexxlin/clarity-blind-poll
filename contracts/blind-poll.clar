;; === constants (unused)===
(define-constant max-len-questions (* 5 1024)) ;; max length of "questions" field in bytes
(define-constant max-len-subject 128) ;; max length of "subject" field in bytes
(define-constant max-len-answer 512) ;; max length of "answer" field in bytes

;; === data structures ===
(define-data-var pid-counter uint u0)

(define-map poll-owned-by ((addr principal)) ((last-pid uint)))
(define-map poll-closed ((poll-id uint)) ((closed bool)))

;; struct for pollDetail
(define-map poll-detail 
  ((poll-id uint))
  (
    (owner principal) ;; poll creator
    (subject (buff 128))
    (start-time uint) ;; (preserved) Unix epoch timestamp in second
    (duration uint) ;; (preserved) in seconds, period of time the poll lasts for
    (claim-duration uint) ;; (preserved) in seconds, period of time within which a participant could claim rewards
    (rewards uint) ;; in STX
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

(define-private (panic-if-poll-closed (pid uint))
  (unwrap-panic
    (if (is-poll-closed pid)
      (err 0)
      (ok 1)
    )
  )
)

(define-private (panic-if-poll-not-closed (pid uint))
  (unwrap-panic
    (if (is-poll-closed pid)
      (ok 1)
      (err 0)
    )
  )
)

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

;; (define-private (is-poll-closed (pid uint))
;;   (let ((poll (query-poll-full-by-id pid)))
;;     (>
;;       (get-curr-block-time)
;;       (+ (get start-time poll) (get duration poll))
;;   ))
;; )

;; chekc if specific poll has closed
(define-private (is-poll-closed (pid uint))
  (get closed (unwrap-panic (map-get? poll-closed ((poll-id pid)))))
)

;; negation of is-poll-closed
(define-private (is-poll-not-closed (id uint)) (not (is-poll-closed id)))

;; query specified poll detail by ID
(define-private (query-poll-full-by-id (pid uint)) 
  (unwrap-panic (map-get? poll-detail ((poll-id pid))))
)

(define-private (query-answer-counter-by-id (pid uint))
  (unwrap-panic (map-get? answer-counter ((poll-id pid))))
)

;; === read-only functions ===

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

;; query last poll initiated by the sender
(define-read-only (query-last-poll-id)
  (begin
    (print tx-sender)
    (ok
      (get last-pid
        (unwrap! (map-get? poll-owned-by ((addr tx-sender))) (err -1004))
      )
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
        (err -1001)
      )
      (begin 
        (create-poll next-id subject u0 u0 rewards max-count questions)        
      )
    )
  )
)

;; create poll without checks
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
    )
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
    ))
    (ok id)
  )
)

;; close poll
(define-public (close-poll (pid uint))
  (begin
    (panic-if-not-poll-owner pid)
    (ok (map-set poll-closed ((poll-id pid)) ((closed true))))
  )
)

;; submit sealed answers
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
        (err -1002))  
    )
  )
)
  
;; reveal submitted answer and claim rewards
(define-public (reveal-answer
  (pid uint)
  (sealed (buff 32))
  (answer (buff 512))
)
  (begin
    ;; (panic-if-not-within-claim-period pid)
    (panic-if-poll-not-closed pid)
    ;; (print (get answer-sealed (unwrap-panic (map-get? poll-answers-sealed ((poll-id pid) (addr tx-sender))))))
    ;; (print sealed)

    (if (and
        ;; tx sender should've submitted identical sealed answer before
        (is-eq (get answer-sealed (unwrap-panic (map-get? poll-answers-sealed ((poll-id pid) (addr tx-sender))))) sealed)
        ;; hash of answer and sealed answer should match
        (is-eq (keccak256 answer) sealed)
      )
      (let ((counter (query-answer-counter-by-id pid)))
        (begin
          ;; store revealed answer
          (map-insert answer-indexer ((poll-id pid) (i (get count-revealed counter))) ((sender tx-sender)))
          (map-set poll-answers-revealed ((poll-id pid) (addr tx-sender)) ((answer answer)))
          (map-set answer-counter ((poll-id pid)) ((count-sealed (get count-sealed counter)) (count-revealed (+ (get count-revealed counter) u1))))
          (ok 1)
        )
      )
      (err -1003)
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

