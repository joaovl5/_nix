(define (render-form form-name children attrs)
  (string-append
    "<" form-name
    (apply
      string-append
      (map (lambda (pair)
             (let ((k (car pair))
                   (v (cadr pair)))
               (string-append " "
                              k
                              "=\""
                              (if
                                (string? v)
                                v
                                (number->string v))
                              "\"")))
           attrs))
    ">"
    (apply string-append children)
    "</" form-name ">"))
(define-syntax html-form
 (lambda (x)
  (syntax-case x (quote)
   [(_ tag children '((k v) ...))
    #'(render-form tag children (list (list k v) ...))])))

(define (p . text) (html-form "p" text '()))
(define (i . text) (html-form "i" text '()))
(define (h1 . text) (html-form "h1" text '()))
(define (h2 . text) (html-form "h2" text '()))
(define (h3 . text) (html-form "h3" text '()))
(define (h4 . text) (html-form "h4" text '()))
(define (sub . text) (html-form "sub" text '()))
(define (sup . text) (html-form "sup" text '()))

(define (br) "<br>")
(define (br* num)
  (let loop ((i 0) (acc '()))
    (if (= i num)
        (apply string-append acc)
        (loop (+ i 1) (cons (br) acc)))))

(define (anchor x children) (html-form "a" children '(("name" x))))
(define (link-to x children) (html-form "a" children '(("href" x))))
(define (center . children) (html-form "div" children '(("align" "center"))))

(define (amb a b c)
  '((sub a) b (sup c)))
; (define-syntax amb
;   (syntax-rules ()
;     ((amb a b c)
;      )))

; ---------------------
; start of the document
; ---------------------

(display
  (string-append
    (anchor "start" '())
    (h1 (link-to "#end" '("The abomination")))
    (center
      (br* 1)
      (p (i "This project is currently undergoing a complete rewrite. Intense amounts of technical debt were made when trying to build things for the infrastructure here, especially in the start of 2026, when experimenting with LLM-assisted coding, which has proven... unwieldly. The author, like many, is concerned with moral, environmental, and legal issues of modern \"AI\" tooling, such as the amounts of illegal scraping conducted to train such models being of colossal harm to humanity, and whether there is or there isn't a practical way to use them properly, this was not the case here. The rewrite is currently pending, and the reader is advised to take whatever nuggets of information on this repository with a grain of salt. The text below is a dramaticized expression of such mistakes."))
      (br* 8)
      (p "All minds are composed of a thousand choices.")
      (p "Those that authored the present"
         (amb "MESSAGE" "TALE" "LIE")))))

