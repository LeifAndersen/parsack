#lang racket
(require feature-profile
         feature-profile/plug-in-lib
         profile/analyzer
         (only-in profile/render-text render))

(provide (all-defined-out))

(define parsack-features
  (list
   (feature "Parsack Backtracking" 'feature-profile:parsack-backtracking
            values ;; No sorting
            ;; Idea from https://github.com/stamourv/marketplace
            ;; commit c3574966bc
            (λ (f-p)
              (define items ; Non Terminals
                (for/fold ([l '()])
                          ([i (feature-report-core-samples f-p)])
                  (append i l)))
              (define nt-b ; Non Terminal -> Backtracking Count
                (for/fold ([table (hash)])
                          ([i items])
                  (match i
                    [`(,or ,bt ,id ...) (hash-update table id (λ (x) (max bt x)) bt)]
                    [else           table])))
              (define intern (make-interner))
              (define post-processed
                (for/list ([c-s (feature-report-core-samples f-p)]
                           [p-s (cdr (feature-report-raw-samples f-p))])
                  (define processed
                      (for/list ([i c-s])
                        (match i
                          [`(,or ,bt ,md ,sc)
                           #:when (bt . < . (hash-ref nt-b `(,md ,sc)))
                           `((bt-<or> ,bt) . ,sc)]
                          [`(,or ,bt ,md ,sc) `((<or> ,bt) . ,sc)])))
                  (list* (car p-s) (cadr p-s) ; thread id and timestamp
                         (for/list ([v processed])
                           (intern v)))))
              ;; Call edge profiler
              (define analyzed
                (analyze-samples
                 (cons (feature-report-total-time f-p) post-processed)))

              (define analyzed/filtered
                (sort
                 (for/fold ([l '()])
                     ([n (profile-nodes analyzed)])
                   (match (node-id n)
                     [`(bt-<or> . ,rest) (cons n l)]
                     [else               l]))
                 (λ (x y) ((node-total x) . > . (node-total y)))))

              ;; Render results
              (newline) (newline) (displayln "Parsack Backtracking")
              (for ([i analyzed/filtered])
                (printf "~a / ~a\t~a\t~a~n"
                        (node-total i)
                        (feature-report-total-time f-p)
                        (srcloc->string (node-src i))
                        (cadr (node-id i))))))))