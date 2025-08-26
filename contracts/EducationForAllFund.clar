;; EducationForAll Fund Smart Contract
;; A decentralized education funding platform for underserved areas
;; with donor tracking and outcome measurement

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-project-not-found (err u103))
(define-constant err-unauthorized (err u104))

;; Data Variables
(define-data-var total-donations uint u0)
(define-data-var project-counter uint u0)

;; Data Maps
;; Track donations by donor address
(define-map donor-contributions principal uint)

;; Track education projects with their details and funding status
(define-map education-projects 
  uint 
  {
    project-name: (string-ascii 50),
    target-amount: uint,
    current-funding: uint,
    beneficiaries: uint,
    location: (string-ascii 30),
    is-active: bool,
    creator: principal
  })

;; Track project outcomes and impact metrics
(define-map project-outcomes
  uint
  {
    students-enrolled: uint,
    completion-rate: uint,
    satisfaction-score: uint,
    is-completed: bool
  })

;; Function 1: Donate to Education Fund
;; Allows donors to contribute STX to support education projects
(define-public (donate-to-education (project-id uint) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-some (map-get? education-projects project-id)) err-project-not-found)
    
    ;; Get project details
    (let ((project (unwrap! (map-get? education-projects project-id) err-project-not-found)))
      ;; Check if project is still active
      (asserts! (get is-active project) err-unauthorized)
      
      ;; Transfer STX from donor to contract
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Update donor contributions
      (map-set donor-contributions tx-sender
               (+ (default-to u0 (map-get? donor-contributions tx-sender)) amount))
      
      ;; Update project funding
      (map-set education-projects project-id
               (merge project {current-funding: (+ (get current-funding project) amount)}))
      
      ;; Update total donations
      (var-set total-donations (+ (var-get total-donations) amount))
      
      ;; Print donation event for tracking
      (print {
        event: "donation-made",
        donor: tx-sender,
        project-id: project-id,
        amount: amount,
        total-project-funding: (+ (get current-funding project) amount)
      })
      
      (ok true))))

;; Function 2: Report Education Outcomes
;; Allows authorized users to update project outcomes and impact metrics
(define-public (report-education-outcomes 
                (project-id uint) 
                (students-enrolled uint) 
                (completion-rate uint) 
                (satisfaction-score uint))
  (begin
    ;; Validate project exists
    (asserts! (is-some (map-get? education-projects project-id)) err-project-not-found)
    
    ;; Get project details to verify authorization
    (let ((project (unwrap! (map-get? education-projects project-id) err-project-not-found)))
      ;; Only project creator or contract owner can report outcomes
      (asserts! (or (is-eq tx-sender (get creator project)) 
                    (is-eq tx-sender contract-owner)) err-unauthorized)
      
      ;; Validate satisfaction score (0-100 scale)
      (asserts! (<= satisfaction-score u100) err-invalid-amount)
      (asserts! (<= completion-rate u100) err-invalid-amount)
      
      ;; Update project outcomes
      (map-set project-outcomes project-id
               {
                 students-enrolled: students-enrolled,
                 completion-rate: completion-rate,
                 satisfaction-score: satisfaction-score,
                 is-completed: (>= completion-rate u90) ;; Consider 90%+ completion as successful
               })
      
      ;; Print outcome report event
      (print {
        event: "outcomes-reported",
        project-id: project-id,
        students-enrolled: students-enrolled,
        completion-rate: completion-rate,
        satisfaction-score: satisfaction-score,
        reporter: tx-sender
      })
      
      (ok true))))

;; Read-only functions for data access

;; Get donor total contributions
(define-read-only (get-donor-contributions (donor principal))
  (ok (default-to u0 (map-get? donor-contributions donor))))

;; Get project details
(define-read-only (get-project-details (project-id uint))
  (ok (map-get? education-projects project-id)))

;; Get project outcomes
(define-read-only (get-project-outcomes (project-id uint))
  (ok (map-get? project-outcomes project-id)))

;; Get total platform donations
(define-read-only (get-total-donations)
  (ok (var-get total-donations)))

;; Get contract balance
(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))) 