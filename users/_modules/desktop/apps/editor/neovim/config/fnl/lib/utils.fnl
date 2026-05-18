(local M {})

(fn M.nil? [x]
  (= nil x))

(fn M.str? [x]
  (= :string (type x)))

(fn M.num? [x]
  (= :number (type x)))

(fn M.bool? [x]
  (= :boolean (type x)))

(fn M.fn? [x]
  (= :function (type x)))

(fn M.tbl? [x]
  (= :table (type x)))

(fn M.->str [x]
  (tostring x))

(fn M.->lower [x]
  (string.lower (M.->str x)))

(fn M.->bool [x]
  (if x true false))

(fn M.merge [a b]
  (each [k v (pairs b)] (tset a k v)))

M
