(define-syntax when
  (syntax-rules ()
    ((when test expr ...)
     (if test
         (begin
           expr ...)))))

(when true
  (display "Hello, World!")
  (newline))
