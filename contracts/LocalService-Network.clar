;; LocalService Network - Community service verification and provider reputation platform
;; Service providers earn tokens through verified local service delivery

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_SERVICE_ID (err u109))
(define-constant ERR_EMPTY_PROOF (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant VERIFICATION_REWARD u8)
(define-constant EXCELLENCE_REWARD u20)
(define-constant TRUSTED_REWARD u40)

;; Data maps
(define-map providers
  { provider-id: principal }
  { business-name: (string-ascii 50), service-type: (string-ascii 20), reputation: uint, tokens: uint, trusted: bool }
)

(define-map services
  { service-id: uint }
  { 
    provider: principal, 
    description: (string-ascii 500), 
    proof-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    verification-count: uint,
    endorsement-count: uint,
    quality-rating: uint,
    rating-count: uint
  }
)

(define-map service-verification
  { service-id: uint, verifier: principal }
  { verified: bool }
)

(define-map service-endorsements
  { service-id: uint, endorser: principal }
  { endorsement-level: uint, endorsement-date: uint }
)

(define-map quality-ratings
  { service-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-service-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-service-id (service-id uint))
  (< service-id (var-get next-service-id))
)

;; Provider functions
(define-public (register-provider (business-name (string-ascii 50)) (service-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len business-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq service-type "plumbing") (is-eq service-type "electrical") (is-eq service-type "repairs")) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? providers {provider-id: caller})) ERR_ALREADY_EXISTS)
    (ok (map-set providers 
      {provider-id: caller} 
      {business-name: business-name, service-type: service-type, reputation: u0, tokens: u100, trusted: false}))
  )
)

(define-public (update-provider (business-name (string-ascii 50)) (service-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len business-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq service-type "plumbing") (is-eq service-type "electrical") (is-eq service-type "repairs")) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    (ok (map-set providers 
      {provider-id: caller} 
      (merge (unwrap! (map-get? providers {provider-id: caller}) ERR_NOT_FOUND)
             {business-name: business-name, service-type: service-type})))
  )
)

;; Service functions
(define-public (register-service (description (string-ascii 500)) (proof-hash (buff 32)))
  (let ((caller tx-sender)
        (service-id (var-get next-service-id)))
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    (asserts! (> (len proof-hash) u0) ERR_EMPTY_PROOF)
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    (var-set action-counter (+ (var-get action-counter) u1))
    
    (map-set services 
      {service-id: service-id} 
      { 
        provider: caller, 
        description: description, 
        proof-hash: proof-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        verification-count: u0,
        endorsement-count: u0,
        quality-rating: u0,
        rating-count: u0
      })
    (var-set next-service-id (+ service-id u1))
    (ok service-id)
  )
)

(define-public (verify-service (service-id uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-service-id service-id) ERR_INVALID_SERVICE_ID)
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? services {service-id: service-id})) ERR_NOT_FOUND)
    
    (let ((service (unwrap! (map-get? services {service-id: service-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get provider service))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? service-verification {service-id: service-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      (map-set service-verification 
        {service-id: service-id, verifier: caller} 
        {verified: true})
      
      (let ((new-verification-count (+ (get verification-count service) u1))
            (service-provider (unwrap! (map-get? providers {provider-id: (get provider service)}) ERR_NOT_FOUND))
            (verifier-provider (unwrap! (map-get? providers {provider-id: caller}) ERR_NOT_FOUND)))
        
        (map-set services 
          {service-id: service-id} 
          (merge service {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u3)
          }))
        
        (map-set providers 
          {provider-id: caller} 
          (merge verifier-provider {
            tokens: (+ (get tokens verifier-provider) u5),
            reputation: (+ (get reputation verifier-provider) u1)
          }))
        
        (if (and (>= new-verification-count u3) (not (get verified service)))
          (map-set providers 
            {provider-id: (get provider service)} 
            (merge service-provider {
              tokens: (+ (get tokens service-provider) TRUSTED_REWARD),
              reputation: (+ (get reputation service-provider) u10),
              trusted: true
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (endorse-service (service-id uint) (endorsement-level uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-service-id service-id) ERR_INVALID_SERVICE_ID)
    (asserts! (> endorsement-level u0) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? services {service-id: service-id})) ERR_NOT_FOUND)
    
    (let ((service (unwrap! (map-get? services {service-id: service-id}) ERR_NOT_FOUND)))
      (asserts! (get verified service) ERR_UNAUTHORIZED)
      
      (map-set service-endorsements 
        {service-id: service-id, endorser: caller} 
        {endorsement-level: endorsement-level, endorsement-date: (var-get action-counter)})
      
      (let ((new-endorsement-count (+ (get endorsement-count service) endorsement-level))
            (service-provider (unwrap! (map-get? providers {provider-id: (get provider service)}) ERR_NOT_FOUND)))
        
        (map-set services 
          {service-id: service-id} 
          (merge service {endorsement-count: new-endorsement-count}))
        
        (map-set providers 
          {provider-id: (get provider service)} 
          (merge service-provider {
            tokens: (+ (get tokens service-provider) (* VERIFICATION_REWARD endorsement-level))
          }))
        
        (ok new-endorsement-count)
      )
    )
  )
)

(define-public (rate-service-quality (service-id uint) (rating uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-service-id service-id) ERR_INVALID_SERVICE_ID)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? services {service-id: service-id})) ERR_NOT_FOUND)
    
    (let ((service (unwrap! (map-get? services {service-id: service-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get provider service))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? quality-ratings {service-id: service-id, rater: caller})) ERR_ALREADY_RATED)
      
      (map-set quality-ratings 
        {service-id: service-id, rater: caller} 
        {rating: rating})
      
      (let ((current-total-rating (* (get quality-rating service) (get rating-count service)))
            (new-rating-count (+ (get rating-count service) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (service-provider (unwrap! (map-get? providers {provider-id: (get provider service)}) ERR_NOT_FOUND))
            (rater-provider (unwrap! (map-get? providers {provider-id: caller}) ERR_NOT_FOUND)))
        
        (map-set services 
          {service-id: service-id} 
          (merge service {
            quality-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        (map-set providers 
          {provider-id: caller} 
          (merge rater-provider {
            tokens: (+ (get tokens rater-provider) u2),
            reputation: (+ (get reputation rater-provider) u1)
          }))
        
        (if (>= rating u4)
          (map-set providers 
            {provider-id: (get provider service)} 
            (merge service-provider {
              tokens: (+ (get tokens service-provider) EXCELLENCE_REWARD),
              reputation: (+ (get reputation service-provider) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-provider-info (provider-id principal))
  (map-get? providers {provider-id: provider-id})
)

(define-read-only (get-service (service-id uint))
  (map-get? services {service-id: service-id})
)

(define-read-only (get-service-verification (service-id uint) (verifier principal))
  (map-get? service-verification {service-id: service-id, verifier: verifier})
)

(define-read-only (get-service-endorsement (service-id uint) (endorser principal))
  (map-get? service-endorsements {service-id: service-id, endorser: endorser})
)

(define-read-only (get-quality-rating (service-id uint) (rater principal))
  (map-get? quality-ratings {service-id: service-id, rater: rater})
)

(define-read-only (get-total-services)
  (- (var-get next-service-id) u1)
)