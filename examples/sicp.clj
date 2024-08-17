(def run-1.1.1 () (do

    (+ 137 349)
    (- 1000 334)
    (* 5 99)
    (/ 10 5)
    (+ 2.7 10)
    (+ 21 35 12 7)
    (* 25 4 12)
    (+ (* 3 5) (- 10 6))
    (+ (* 3
            (+ (* 2 4)
                (+ 3 5)))
            (+ (- 10 7)
                6))
    (def size 2)
    (print size)
    (* 5 size)
    (def pi 3.14159)
    (def radius 10)
    (* pi (* radius radius))
    (def circumference (* 2 pi radius))
    (print circumference)
))
# (run-1.1.1)

(def run-1.1.5 () (do 
    (def square (x) (* x x))
    (square 21)
    (square (+ 2 5))
    (square (square 3))
    (def sum-of-squares (x y) (+ (square x) (square y)))
    (sum-of-squares 3 4)
    (def f (a) (sum-of-squares (+ a 1) (* a 2)))
    (f 5)
))
# (run-1.1.5)

(def run-1.1.6 () (do
    (def abs (x)
        (cond   (> x 0) x
                (= x 0) 0
                (< x 0) (- x)))

    (abs -123)

    (def abs-with-else (x)
        (cond   (>= x 0) x
                else (- x)))

    (abs-with-else-123)

))

# (run-1.1.6)

(def run-1.2 ()
  (do 

    (def factorial (n)
      (if (= n 1)
        1
        (* n (factorial (- n 1)))))

    (factorial 10)

    (def fibb (n) 
      (cond (= n 0) 0
            (= n 1) 1
            else (+ (fibb (- n 1))
                     (fibb (- n 2)))))

    (fibb 10)
    ))

# (run-1.2)

(def run-1.3.2 ()
  (do

    (def square (x) (* x x))

    (def f (x y) 
      ((lambda (a b)
               (+ (* x (square a))
                  (* y b)
                  (* a b)))
       (+ 1 (* x y))
       (- 1 y)))

    (f 5 5)

    ))

(run-1.3.2)
