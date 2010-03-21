(* nqueens.sml
 * Copyright (c) 2009 Jacob Potter
 * License: WTFPL *)

signature AMB =

val amb = Amb.amb

fun place _ = (amb [ 1, 2, 3, 4, 5, 6, 7, 8 ],
               amb [ 1, 2, 3, 4, 5, 6, 7, 8 ])

fun checkDifferent (f: 'a -> int) nil = ()
  | checkDifferent (f: 'a -> int) (x::xs) =
      let
        val xr = f x
        fun check x' = if xr <> f x' then () else amb nil
      in
        app check xs;
        checkDifferent f xs
      end

fun nqueens () = let
  val placements = List.tabulate (6, place)

  val () = checkDifferent (fn (r, c) => r) placements
  val () = checkDifferent (fn (r, c) => c) placements
  val () = checkDifferent (fn (r, c) => r - c) placements
  val () = checkDifferent (fn (r, c) => r + c) placements
in
  placements
end

val r = nqueens ()
