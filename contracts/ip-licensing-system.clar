;; IP Licensing System Smart Contract
;; Manages intellectual property licenses, usage tracking, and royalty distributions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-ASSET-NOT-FOUND (err u1002))
(define-constant ERR-LICENSE-NOT-FOUND (err u1003))
(define-constant ERR-LICENSE-EXPIRED (err u1004))
(define-constant ERR-INVALID-INPUT (err u1005))
(define-constant ERR-ASSET-ALREADY-EXISTS (err u1006))
(define-constant ERR-LICENSE-INACTIVE (err u1007))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1008))
(define-constant ERR-USAGE-LIMIT-EXCEEDED (err u1009))
(define-constant MAX-ROYALTY-RATE u10000) ;; 100% in basis points
(define-constant MIN-ROYALTY-RATE u0)
(define-constant SECONDS-PER-DAY u86400)

;; Data Variables
(define-data-var next-license-id uint u1)
(define-data-var contract-admin principal CONTRACT-OWNER)

;; Data Maps

;; IP Assets storage
(define-map ip-assets
  (string-ascii 50) ;; asset-id
  {
    owner: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    royalty-rate: uint, ;; basis points (e.g., 500 = 5%)
    created-at: uint,
    updated-at: uint,
    active: bool,
    total-licenses: uint,
    total-revenue: uint
  }
)

;; Licenses storage
(define-map licenses
  uint ;; license-id
  {
    id: uint,
    ip-asset-id: (string-ascii 50),
    licensee: principal,
    licensor: principal,
    royalty-rate: uint, ;; basis points
    start-time: uint,
    end-time: uint,
    usage-limit: (optional uint),
    current-usage: uint,
    license-fee: uint,
    active: bool,
    exclusive: bool
  }
)

;; Usage records
(define-map usage-records
  uint ;; record-id
  {
    license-id: uint,
    ip-asset-id: (string-ascii 50),
    timestamp: uint,
    quantity: uint,
    reported-by: principal,
    royalty-paid: uint
  }
)

;; License lookup by asset and licensee
(define-map asset-licensee-lookup
  { asset-id: (string-ascii 50), licensee: principal }
  uint ;; license-id
)

;; Asset ownership history
(define-map ownership-history
  { asset-id: (string-ascii 50), block-height: uint }
  { previous-owner: principal, new-owner: principal, timestamp: uint }
)

;; Royalty escrow for disputed payments
(define-map royalty-escrow
  uint ;; escrow-id
  {
    license-id: uint,
    amount: uint,
    created-at: uint,
    resolved: bool,
    beneficiary: principal
  }
)

;; Revenue tracking per asset
(define-map asset-revenue
  (string-ascii 50) ;; asset-id
  {
    total-earned: uint,
    total-paid: uint,
    pending-payments: uint
  }
)

;; Public Functions

;; Register a new IP asset
(define-public (register-ip-asset (asset-id (string-ascii 50)) 
                                  (title (string-utf8 100))
                                  (description (string-utf8 500))
                                  (royalty-rate uint))
  (let ((current-time (unwrap! (get-block-info? time (- block-height u1)) (err u9999))))
    (asserts! (> (len asset-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (<= royalty-rate MAX-ROYALTY-RATE) ERR-INVALID-INPUT)
    (asserts! (>= royalty-rate MIN-ROYALTY-RATE) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? ip-assets asset-id)) ERR-ASSET-ALREADY-EXISTS)
    
    ;; Create the IP asset
    (map-set ip-assets asset-id {
      owner: tx-sender,
      title: title,
      description: description,
      royalty-rate: royalty-rate,
      created-at: current-time,
      updated-at: current-time,
      active: true,
      total-licenses: u0,
      total-revenue: u0
    })
    
    ;; Initialize revenue tracking
    (map-set asset-revenue asset-id {
      total-earned: u0,
      total-paid: u0,
      pending-payments: u0
    })
    
    ;; Record ownership history
    (map-set ownership-history 
      { asset-id: asset-id, block-height: block-height }
      { previous-owner: tx-sender, new-owner: tx-sender, timestamp: current-time })
    
    (ok asset-id)
  )
)

;; Create a license for an IP asset
(define-public (create-license (asset-id (string-ascii 50))
                               (licensee principal)
                               (duration-days uint)
                               (custom-royalty-rate (optional uint))
                               (usage-limit (optional uint))
                               (license-fee uint)
                               (exclusive bool))
  (let ((asset-info (unwrap! (map-get? ip-assets asset-id) ERR-ASSET-NOT-FOUND))
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u9999)))
        (license-id (var-get next-license-id))
        (end-time (+ current-time (* duration-days SECONDS-PER-DAY)))
        (final-royalty-rate (default-to (get royalty-rate asset-info) custom-royalty-rate)))
    
    ;; Validations
    (asserts! (get active asset-info) ERR-ASSET-NOT-FOUND)
    (asserts! (or (is-eq tx-sender (get owner asset-info)) (is-eq tx-sender (var-get contract-admin))) ERR-NOT-AUTHORIZED)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (<= final-royalty-rate MAX-ROYALTY-RATE) ERR-INVALID-INPUT)
    
    ;; Check if exclusive license already exists for this asset
    (if exclusive
      (asserts! (is-eq (get total-licenses asset-info) u0) ERR-INVALID-INPUT)
      true
    )
    
    ;; Create the license
    (map-set licenses license-id {
      id: license-id,
      ip-asset-id: asset-id,
      licensee: licensee,
      licensor: (get owner asset-info),
      royalty-rate: final-royalty-rate,
      start-time: current-time,
      end-time: end-time,
      usage-limit: usage-limit,
      current-usage: u0,
      license-fee: license-fee,
      active: true,
      exclusive: exclusive
    })
    
    ;; Update asset license count
    (map-set ip-assets asset-id
      (merge asset-info { 
        total-licenses: (+ (get total-licenses asset-info) u1),
        updated-at: current-time
      })
    )
    
    ;; Create lookup mapping
    (map-set asset-licensee-lookup 
      { asset-id: asset-id, licensee: licensee }
      license-id
    )
    
    ;; Increment license counter
    (var-set next-license-id (+ license-id u1))
    
    (ok license-id)
  )
)

;; Record usage of licensed IP
(define-public (record-usage (license-id uint) (quantity uint))
  (let ((license-info (unwrap! (map-get? licenses license-id) ERR-LICENSE-NOT-FOUND))
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u9999)))
        (record-id (+ license-id (* current-time u1000)))) ;; Generate unique record ID
    
    ;; Validations
    (asserts! (get active license-info) ERR-LICENSE-INACTIVE)
    (asserts! (< current-time (get end-time license-info)) ERR-LICENSE-EXPIRED)
    (asserts! (or (is-eq tx-sender (get licensee license-info)) 
                  (is-eq tx-sender (get licensor license-info))
                  (is-eq tx-sender (var-get contract-admin))) ERR-NOT-AUTHORIZED)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    
    ;; Check usage limits
    (match (get usage-limit license-info)
      limit (asserts! (<= (+ (get current-usage license-info) quantity) limit) ERR-USAGE-LIMIT-EXCEEDED)
      true
    )
    
    ;; Calculate royalty
    (let ((royalty-amount (/ (* quantity (get royalty-rate license-info)) u10000)))
      
      ;; Update license usage
      (map-set licenses license-id
        (merge license-info {
          current-usage: (+ (get current-usage license-info) quantity)
        })
      )
      
      ;; Record the usage
      (map-set usage-records record-id {
        license-id: license-id,
        ip-asset-id: (get ip-asset-id license-info),
        timestamp: current-time,
        quantity: quantity,
        reported-by: tx-sender,
        royalty-paid: royalty-amount
      })
      
      ;; Update asset revenue tracking
      (let ((asset-id (get ip-asset-id license-info))
            (current-revenue (default-to { total-earned: u0, total-paid: u0, pending-payments: u0 }
                                        (map-get? asset-revenue asset-id))))
        (map-set asset-revenue asset-id
          (merge current-revenue {
            total-earned: (+ (get total-earned current-revenue) royalty-amount),
            pending-payments: (+ (get pending-payments current-revenue) royalty-amount)
          })
        )
      )
      
      (ok record-id)
    )
  )
)

;; Distribute royalty payment to IP owner
(define-public (distribute-royalty (asset-id (string-ascii 50)) (amount uint))
  (let ((asset-info (unwrap! (map-get? ip-assets asset-id) ERR-ASSET-NOT-FOUND))
        (revenue-info (unwrap! (map-get? asset-revenue asset-id) ERR-ASSET-NOT-FOUND)))
    
    ;; Validations
    (asserts! (get active asset-info) ERR-ASSET-NOT-FOUND)
    (asserts! (>= (get pending-payments revenue-info) amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX to asset owner
    (try! (stx-transfer? amount tx-sender (get owner asset-info)))
    
    ;; Update revenue tracking
    (map-set asset-revenue asset-id
      (merge revenue-info {
        total-paid: (+ (get total-paid revenue-info) amount),
        pending-payments: (- (get pending-payments revenue-info) amount)
      })
    )
    
    ;; Update asset total revenue
    (map-set ip-assets asset-id
      (merge asset-info {
        total-revenue: (+ (get total-revenue asset-info) amount)
      })
    )
    
    (ok amount)
  )
)

;; Transfer IP asset ownership
(define-public (transfer-ownership (asset-id (string-ascii 50)) (new-owner principal))
  (let ((asset-info (unwrap! (map-get? ip-assets asset-id) ERR-ASSET-NOT-FOUND))
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u9999))))
    
    ;; Only current owner can transfer
    (asserts! (is-eq tx-sender (get owner asset-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get active asset-info) ERR-ASSET-NOT-FOUND)
    (asserts! (not (is-eq (get owner asset-info) new-owner)) ERR-INVALID-INPUT)
    
    ;; Update ownership
    (map-set ip-assets asset-id
      (merge asset-info {
        owner: new-owner,
        updated-at: current-time
      })
    )
    
    ;; Record ownership change
    (map-set ownership-history
      { asset-id: asset-id, block-height: block-height }
      { 
        previous-owner: (get owner asset-info), 
        new-owner: new-owner, 
        timestamp: current-time 
      }
    )
    
    (ok new-owner)
  )
)

;; Update asset information (owner only)
(define-public (update-asset-info (asset-id (string-ascii 50))
                                  (new-title (optional (string-utf8 100)))
                                  (new-description (optional (string-utf8 500)))
                                  (new-royalty-rate (optional uint)))
  (let ((asset-info (unwrap! (map-get? ip-assets asset-id) ERR-ASSET-NOT-FOUND))
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u9999))))
    
    ;; Only owner can update
    (asserts! (is-eq tx-sender (get owner asset-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get active asset-info) ERR-ASSET-NOT-FOUND)
    
    ;; Validate new royalty rate if provided
    (match new-royalty-rate
      rate (asserts! (<= rate MAX-ROYALTY-RATE) ERR-INVALID-INPUT)
      true
    )
    
    ;; Update asset information
    (map-set ip-assets asset-id
      (merge asset-info {
        title: (default-to (get title asset-info) new-title),
        description: (default-to (get description asset-info) new-description),
        royalty-rate: (default-to (get royalty-rate asset-info) new-royalty-rate),
        updated-at: current-time
      })
    )
    
    (ok asset-id)
  )
)

;; Deactivate a license
(define-public (deactivate-license (license-id uint))
  (let ((license-info (unwrap! (map-get? licenses license-id) ERR-LICENSE-NOT-FOUND)))
    
    ;; Only licensor or admin can deactivate
    (asserts! (or (is-eq tx-sender (get licensor license-info))
                  (is-eq tx-sender (var-get contract-admin))) ERR-NOT-AUTHORIZED)
    (asserts! (get active license-info) ERR-LICENSE-INACTIVE)
    
    ;; Deactivate license
    (map-set licenses license-id
      (merge license-info { active: false })
    )
    
    (ok license-id)
  )
)

;; Read-Only Functions

;; Get IP asset information
(define-read-only (get-ip-asset (asset-id (string-ascii 50)))
  (map-get? ip-assets asset-id)
)

;; Get license information
(define-read-only (get-license (license-id uint))
  (map-get? licenses license-id)
)

;; Get usage record
(define-read-only (get-usage-record (record-id uint))
  (map-get? usage-records record-id)
)

;; Get license ID for asset and licensee
(define-read-only (get-license-by-asset-licensee (asset-id (string-ascii 50)) (licensee principal))
  (map-get? asset-licensee-lookup { asset-id: asset-id, licensee: licensee })
)

;; Get asset revenue information
(define-read-only (get-asset-revenue (asset-id (string-ascii 50)))
  (map-get? asset-revenue asset-id)
)

;; Check if license is valid and active
(define-read-only (is-license-valid (license-id uint))
  (match (map-get? licenses license-id)
    license-info (let ((current-time (default-to u0 (get-block-info? time (- block-height u1)))))
                   (and (get active license-info)
                        (< current-time (get end-time license-info))))
    false
  )
)

;; Get ownership history
(define-read-only (get-ownership-history (asset-id (string-ascii 50)) (block-height-lookup uint))
  (map-get? ownership-history { asset-id: asset-id, block-height: block-height-lookup })
)

;; Calculate royalty for given usage
(define-read-only (calculate-royalty (license-id uint) (usage-quantity uint))
  (match (map-get? licenses license-id)
    license-info (ok (/ (* usage-quantity (get royalty-rate license-info)) u10000))
    ERR-LICENSE-NOT-FOUND
  )
)

;; Get contract admin
(define-read-only (get-contract-admin)
  (var-get contract-admin)
)
