(** Chapter 5 - Fundamentals of Amortization *)

open Sigs

(** Page 43 - Figure 5.2.
    A common implementation of purely functional queues. *)
module BatchedQueue : QUEUE = struct
  type 'a queue = 'a list * 'a list

  let empty = ([], [])

  let isEmpty (f, _) = match f with [] -> true | _ -> false

  let checkf (f, r) = match (f, r) with [], r -> (List.rev r, []) | q -> q

  let snoc (f, r) x = checkf (f, x :: r)

  let head (f, _) = match f with [] -> raise Empty | x :: _ -> x

  let tail (f, r) = match f with [] -> raise Empty | _ :: f -> checkf (f, r)
end

(** Page 44 - Exercise 5.1
    This design can easily be extended to support the double-ended queue, or
    deque, abstraction, which allows reads and writes to both ends of the queue
    (see Figure 5.3). The invariant is updated to be symmetric in its treatment
    of f and r: both are required to be non-empty whenever the deque contains
    two or more elements. When one list becomes empty, we split the other list
    in half and reverse one of the halves.

    (a) Implement this version of the deques.
    (b) Prove that each operatino takes O(1) amortized time using the potential
        function phi(f, r) = abs(|f| - |r|), where abs is the absolute value
        function. *)
module BatchedDeque : DEQUE = struct
  type 'a queue = 'a list * 'a list

  let empty = ([], [])

  let isEmpty (f, _) = match f with [] -> true | _ -> false

  let rec splitAt n xs =
    match (n, xs) with
    | _, [] -> ([], [])
    | 1, x :: xs -> ([ x ], xs)
    | n, x :: xs ->
        let xs', ys = splitAt (n - 1) xs in
        (x :: xs', ys)

  let splitInHalf xs =
    let n = List.length xs in
    splitAt (n / 2) xs

  let checkf (f, r) =
    match (f, r) with
    | [], _ :: _ :: _ ->
        let r, f = splitInHalf r in
        (List.rev f, r)
    | _ :: _ :: _, [] ->
        let f, r = splitInHalf f in
        (f, List.rev r)
    | q -> q

  let cons x (f, r) = checkf (x :: f, r)

  let head (f, _) = match f with [] -> raise Empty | x :: _ -> x

  let tail (f, r) = match f with [] -> raise Empty | _ :: f -> checkf (f, r)

  let snoc (f, r) x = checkf (f, x :: r)

  let last (_, r) = match r with [] -> raise Empty | x :: _ -> x

  let init (f, r) = match r with [] -> raise Empty | _ :: r -> checkf (f, r)
end

(** Page 50 - Figure 5.5.
    Implementaiton of heaps using splay trees. *)
module SplayHeap (Element : ORDERED) : HEAP with module Elem = Element = struct
  module Elem = Element

  type heap = E | T of heap * Elem.t * heap

  let empty = E

  let isEmpty = function E -> true | _ -> false

  let rec partition pivot = function
    | E -> (E, E)
    | T (a, x, b) as t -> (
        if Elem.leq x pivot then
          match b with
          | E -> (t, E)
          | T (a', y, b') ->
              if Elem.leq y pivot then
                let small, big = partition pivot b' in
                (T (T (a, x, a'), y, small), big)
              else
                let small, big = partition pivot a' in
                (T (a, x, small), T (big, y, b'))
        else
          match a with
          | E -> (E, t)
          | T (a', y, b') ->
              if Elem.leq y pivot then
                let small, big = partition pivot b' in
                (T (a', y, small), T (big, x, b))
              else
                let small, big = partition pivot a' in
                (small, T (big, y, T (b', x, b))))

  let insert x t =
    let a, b = partition x t in
    T (a, x, b)

  let rec merge t1 t2 =
    match (t1, t2) with
    | E, t -> t
    | T (a, x, b), t ->
        let ta, tb = partition x t in
        T (merge ta a, x, merge tb b)

  let rec findMin = function
    | E -> raise Empty
    | T (E, x, _) -> x
    | T (a, _, _) -> findMin a

  let rec deleteMin = function
    | E -> raise Empty
    | T (E, _, b) -> b
    | T (T (E, _, b), y, c) -> T (b, y, c)
    | T (T (a, x, b), y, c) -> T (deleteMin a, x, T (b, y, c))
end