structure Map = SplayMapFn(type ord_key = string val compare = String.compare)

signature MARKOV = sig
  type chain
  val new : unit -> chain
  val add : chain -> string * string -> unit
  val successor : chain -> string -> string
end

structure Markov (* MARKOV *) = struct

  val rng = Random.rand (42, 15410)

  datatype tree = T of {
    word : string,
    count : int ref,
    pr : int,
    left : tree option,
    right : tree option,
    weight : int ref
  }
  datatype side = RIGHT | LEFT

  type chain = tree ref Map.map ref

  fun new () : chain = ref Map.empty

  fun newLeaf word pr = T { word = word, count = ref 1, pr = pr,
                            left = NONE, right = NONE, weight = ref 1 }
  fun wt (NONE) = 0
    | wt (SOME (T { weight, ... })) = !weight

  fun addTree t newWord newPrio = let
        val T { word, count, pr, left, right, weight } = t
        val () = weight := !weight + 1

        (* Helper functions to get and update one side of this node *)
        fun descend RIGHT = right
          | descend LEFT = left

        fun update RIGHT t' = T { word = word, count = count, pr = pr,
                                  left = left, right = SOME t', weight = weight }
          | update LEFT t' =  T { word = word, count = count, pr = pr,
                                  left = SOME t', right = right, weight = weight }


        (* Descend down the tree. *)
        fun walk side = let
              val t' as T { word = word', count = count', pr = pr',
                            left = left', right = right', weight = weight' } =
                case descend side of SOME t' => addTree t' newWord newPrio
                                   | NONE => newLeaf newWord newPrio
            in
              if pr' > pr
              then update side t'
              else case side of
                  LEFT  => T { word = word', count = count', pr = pr', 
                               left = left', weight = weight, right = SOME (
                                 T { word = word, count = count, pr = pr,
                                     left = right', right = right,
                                     weight = ref (!count + wt right' + wt right) }) }
                | RIGHT => T { word = word', count = count', pr = pr', 
                               right = right', weight = weight, left = SOME (
                                 T { word = word, count = count, pr = pr,
                                     left = left, right = left',
                                     weight = ref (!count + wt left + wt left') }) }
            end

      in
        case String.compare (newWord, word) of
            EQUAL   => (count := !count + 1; t)
          | GREATER => walk RIGHT
          | LESS    => walk LEFT
      end

  fun walkTree NONE pos = ""
    | walkTree (SOME t) pos = let 
        val T { word, count, pr, left, right, weight } = t
        val wtLeft = wt left
      in
        if pos < wtLeft
          then walkTree left pos
        else if pos < (wtLeft + !count)
          then word
        else
          walkTree right (pos - wtLeft - !count)
      end

  fun addTree' t w' = addTree t w' (Random.randInt rng)

  fun add (cr as ref chain) (from, to) = let
        val prio = Random.randInt rng
      in
        case Map.find (chain, from) of
            NONE => (cr := Map.insert (chain, from, ref (newLeaf to prio)))
          | SOME t => (t := (addTree (!t) to prio))
       end

  fun successor (ref chain) word = (
        case Map.find (chain, word) of
            NONE => ""
          | SOME (ref (t as T { weight as ref w, ... })) =>
              walkTree (SOME t) (Random.randRange (0, w - 1) rng)
    )

end

val map : Markov.chain Map.map ref = ref Map.empty

fun getMap name = (case Map.find (!map, name) of
      SOME m => m
    | NONE => let val m = Markov.new () in
                  map := Map.insert (!map, name, m);
                  m end)

val _ = (_export "markov_add": (string * string * string -> int) -> unit; )
        (fn (chain, s1, s2) => (Markov.add (getMap chain) (s1, s2); 0) )

val _ = (_export "markov_successsor": (string * string -> string) -> unit; )
        (fn (c, s) => Markov.successor (getMap c) s)
