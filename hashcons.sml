(* Hash-consing library
 *
 * Based on http://www.lri.fr/~filliatr/ftp/publis/hash-consing2.pdf
 *)
functor HashCons(T : sig
                  type t
                  val equal : t * t -> bool
                  val hash : t -> int
                end)
:> sig
  type 'a hash_consed = {
    node : 'a,
    tag : int,
    hkey : int
  }
  type table
  val create : unit -> table
  val hashcons : table -> T.t -> T.t hash_consed
end =
struct
  type 'a hash_consed = {
    node : 'a,
    tag : int,
    hkey : int
  }

  structure M = IntBinaryMap
  structure W = SMLofNJ.Weak

  val tag = ref 0
  fun newtag () = !tag before (tag := !tag + 1)

  type table = T.t hash_consed W.weak list M.map

  fun create () = M.empty

  fun hashcons t d = let
      (* First, calculate the hash key of the new node *)
      val hashkey = T.hash d

      (* If we actually have to cons in the new node, we'll call this *)
      fun do_insert l = let
            val node = { hkey = hashkey, tag = newtag (), node = d }
          in
            M.insert (t, hashkey, W.weak node :: l); node
          end
    in
      case M.find (t, hashkey) of
       (* If we don't already have anything with this key, we'll have
          to add it *)
         NONE => do_insert nil
       (* Otherwise, check whether we do... *)
       | SOME l => let
           (* Walk through this bucket, looking for something equal to the
            * node we want. While we're at it, trim out any weakrefs that
            * have expired. *)
           fun walk_list (nil, found, acc) = (found, acc)
             | walk_list (w::ws, found, acc) =
               case W.strong (w : T.t hash_consed W.weak) of
                 SOME w' => if T.equal (d, #node w') 
                            then walk_list (ws, SOME w', w :: acc)
                            else walk_list (ws, found, w :: acc)
               | NONE => walk_list (ws, found, acc)
         in
           case walk_list (l, NONE, nil) of
             (SOME found, l') => (M.insert (t, hashkey, l'); found)
           | (NONE, l') => do_insert l'
         end
    end
end
