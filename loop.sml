(* Infinite loop with no recursion or recursive types.
 *
 * From:
 *   Mark Lillibridge
 *   "Exceptions Are Strictly More Powerful than Call/CC"
 *   Technical Report CMU-CS-95-178
 *   Carnegie Mellon University, July 1995.
 *)

exception E of (unit -> unit) -> (unit -> unit)

fun roll x = fn () => (raise E x; ())
fun unroll x = ((x (); fn y => y) handle (E e) => e)

fun hang () = let val w = roll (fn x => unroll x x)
                   in unroll w w end
