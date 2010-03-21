(* amb2.sml
 * Copyright (c) 2009 Jacob Potter
 * based on a less-polymorphic version by Michael Sullivan
 * License: WTFPL *)

signature AMB =
sig
  exception AmbFail
  val amb : 'a list -> 'a
end

structure Amb :> AMB =
struct
  structure CC = SMLofNJ.Cont
  exception AmbFail
  val stack : exn CC.cont list ref = ref nil
  fun 'a amb nil =
      (case stack of
         ref nil => raise AmbFail
       | ref (last::rest) => (
           stack := rest;
           CC.throw last AmbFail
         )
      )
    | amb (x::xs) = let
           exception E of 'a
           fun next cont = (stack := cont :: (!stack); E x)
         in
           case CC.callcc next of E y => y | _ => amb xs
         end
end

fun test0 () =
    let
        val x = Amb.amb [1, 2, 3, 4, 5]
        val _ = if x <> 4 then Amb.amb nil else 0
    in
        x
    end

fun test1 () =
    let
        val x = Amb.amb [1, 2, 3]
        val y = Amb.amb [4, 5, 6]
        val _ = if x*y <> 10 then Amb.amb nil else 0
    in
        (x, y)
    end

fun test2 () =
    let
      val amb = Amb.amb
      val x = amb [ 2, 3, 4, 5 ]
      val y = amb [ "a", "aaaaa", "aaaaaaa" ]
    in
      if x <> (size y) then amb nil else y
    end



