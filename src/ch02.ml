(** Chapter 2 - Persistence *)

open Sigs
module L = List

(** Page 8 - Implementation of stacks using the built-in type of lists. *)
module List : STACK = struct
  type 'a stack = 'a list

  let empty = []

  let isEmpty s = L.length s = 0

  let cons x s = x :: s

  let head s = L.hd s

  let tail s = L.tl s
end

(** Page 8 - Implementation of stacks using a custom datatype. *)
module CustomStack : STACK = struct
  type 'a stack = Nil | Cons of 'a * 'a stack

  let empty = Nil

  let isEmpty = function Nil -> true | _ -> false

  let cons x s = Cons (x, s)

  let head = function Nil -> raise Empty | Cons (x, _) -> x

  let tail = function Nil -> raise Empty | Cons (_, s) -> s
end

let rec ( ++ ) xs ys = match xs with [] -> ys | x :: xs' -> x :: (xs' ++ ys)

let rec update = function
  | [], _, _ -> failwith "Subscript"
  | _ :: xs, 0, y -> y :: xs
  | _ :: xs, i, y -> update (xs, i - 1, y)

(** Page 11 - Exercise 2.1
    Write a function suffixes of type ['a list -> 'a list list] that
    takes a list [xs] and returns a list of all the suffixes of [xs]
    in decreasing order of length. For example,
    [{
    suffixes [1;2;3;4] = [[1;2;3;4]; [2;3;4]; [3;4]; [4]; []]
    }]
    Show that the resulting list of suffixes can be generated in [O(n)]
    time and represented in [O(n)] space.
*)
let rec suffixes = function
  | [] -> [ [] ]
  | _ :: xs' as xs -> xs :: suffixes xs'

module UnbalancedSet (Element : ORDERED) : SET with type elem = Element.t =
struct
  type elem = Element.t

  type tree = E | T of tree * elem * tree

  type set = tree

  let empty = E

  let rec member = function
    | _, E -> false
    | x, T (a, y, b) ->
        if Element.lt x y then member (x, a)
        else if Element.lt y x then member (x, b)
        else true

  (** Page 14 - Exercise 2.2
      In the worse case, [member] performs approximately [2d] comparisons,
      where [d] is the depth of the tree. Rewrite [member] to take no
      more than [d + 1] comparisons by keeping track of a candidate
      element that {i might} be equal to the query element (say, the last
      element for which [<] returned false or [<=] returned true) and
      checking for equality only when you hit the bottom of the tree.
  *)
  let member x s =
    let rec go z = function
      | E -> ( match z with Some y -> x = y | None -> false)
      | T (a, y, b) -> if Element.lt x y then go z a else go (Some y) b
    in
    go None s

  let rec insert x s =
    match (x, s) with
    | x, E -> T (E, x, E)
    | x, (T (a, y, b) as s) ->
        if Element.lt x y then T (insert x a, y, b)
        else if Element.lt y x then T (a, y, insert x b)
        else s

  (** Page 15 - Exercise 2.3
      Inserting an existing element into a binary search tree copies
      the entire search path even though the copied nodes are indistinguishable
      from the originals. Rewrite [insert] using exceptions to avoid
      this copying. Establish only one handler per insertion rather
      than one handler per iteration.
  *)
  let insert x s =
    let go = function
      | x, E -> T (E, x, E)
      | x, T (a, y, b) ->
          if Element.lt x y then T (insert x a, y, b)
          else if Element.lt y x then T (a, y, insert x b)
          else failwith "Found"
    in
    try go (x, s) with Failure _ -> s

  (** Page 15 - Exercise 2.4
      Combine the ideas of the previous two exercises to obtain a
      version of [insert] that performs no necessary copying and uses
      no more than [d + 1] comparisons
  *)
  let insert x s =
    let rec go z = function
      | E -> (
          match z with Some y when x = y -> failwith "Found" | _ -> T (E, x, E))
      | T (a, y, b) ->
          if Element.lt x y then T (go z a, y, b) else T (a, y, go (Some y) b)
    in
    try go None s with Failure _ -> s
end

(** Page 15 - Exercise 2.5
    Sharing can also be useful within a single object, not just between
    objects. For example, if the two subtrees of a given node are identical,
    then they can be represented by the same tree.

    (a) Using this idea, write a function [complete] of type [elem * int -> tree]
    where [complete (x, d)] creates a complete binary tree of depth [d]
    with [x] stored in every node. (Of course, this function makes no
    sense for the set abstraction, but it can be useful as an auxiliary
    function for other abstractions, such as bags.) This function should
    run in [O(d)] tim.
    (b) Extend this function to create balanced trees of arbitary size. These
    trees will not always be complete binary trees, but should be as
    balanced as possible: for any given node, the two subtrees should
    either differ in size by at most one. This function should run in
    [O(log n)] time. (Hint: use a helper function [create2] that, given
    a size [m], creates a pair of trees, one of size [m] and one of size
    [m + 1].)
*)
type 'a tree = E | T of 'a tree * 'a * 'a tree

let rec complete x d =
  match d with
  | 0 -> E
  | d ->
      let a = complete x (d - 1) in
      T (a, x, a)

let rec create x n =
  match n with
  | 0 -> E
  | n when n mod 2 <> 0 ->
      let m = (n - 1) / 2 in
      let a = create x m in
      T (a, x, a)
  | n ->
      let m = (n - 1) / 2 in
      let a = create x m in
      let b = create x (m + 1) in
      T (a, x, b)

(** Page 15 - Exercise 2.6
    Adapt the [UnbalancedSet] functor to support finite maps rather than
    sets.
*)

(** Page 16 - Signature for finite maps *)
module type FiniteMap = sig
  type key

  type 'a map

  val empty : 'a map

  val bind : key * 'a * 'a map -> 'a map

  val lookup : key * 'a map -> 'a (* raise Not_found if key is not found *)
end

module UnbalancedMap (Key : ORDERED) : FiniteMap with type key = Key.t = struct
  type key = Key.t

  type 'a tree = E | T of 'a tree * (key * 'a) * 'a tree

  type 'a map = 'a tree

  let empty = E

  let rec bind = function
    | k, x, E -> T (E, (k, x), E)
    | k, x, T (a, (k', y), b) ->
        if Key.lt k k' then T (bind (k, x, a), (k', y), b)
        else if Key.lt k' k then T (a, (k', y), bind (k, x, b))
        else T (a, (k, x), b)

  let rec lookup = function
    | _, E -> raise Not_found
    | k, T (a, (k', y), b) ->
        if Key.lt k k' then lookup (k, a)
        else if Key.lt k' k then lookup (k, b)
        else y
end
