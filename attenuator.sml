let
  val pow = Math.pow
  val isFinite = Real.isFinite
  val r = Real.toString
  infix 8 pow

  val rInput = 100.0

  val rLoad = 15000.0

  val stageAttenuations = List.tabulate (7, fn n => 0.5 * 2.0 pow (Real.fromInt n))
  fun desired n = Real.fromInt n * ~0.5

  (*
              +-- RSeries --+
              |             |
    Input ----+---o    ,0---+---- (Output) --+
                      /                      |
                     o                     RLoad
                     |                       |
                   RShunt                   Gnd
                     |       
                    Gnd
  *)

  (* * * * * * * * * * * * * * * *)

  fun ratioFor dB = 10.0 pow (dB / ~20.0)
  fun dbFor ratio = 20.0 * Math.log10 ratio


  (*
   * || and ||-: Resistor-in-parallel helper functions.
   *)
  fun || (a:real, b:real) = if isFinite a then (if isFinite b then (a*b) / (a+b) else a) else b
  fun ||- (a:real, b:real) = if isFinite b then (a*b) / (b-a) else a
  infix 8 ||
  infix 8 ||-


  (* 
   * Standard E96 resistor values.
   *)
  val e96 = map Real.fromInt [
    100, 102, 105, 107, 110, 113, 115, 118, 121, 124, 127, 130, 133, 137, 140, 143,
    147, 150, 154, 158, 162, 165, 169, 174, 178, 182, 187, 191, 196, 200, 205, 210,
    215, 221, 226, 232, 237, 243, 249, 255, 261, 267, 274, 280, 287, 294, 301, 309,
    316, 324, 332, 340, 348, 357, 365, 374, 383, 392, 402, 412, 422, 432, 442, 453,
    464, 475, 487, 499, 511, 523, 536, 549, 562, 576, 590, 604, 619, 634, 649, 665,
    681, 698, 715, 732, 750, 768, 787, 806, 825, 845, 866, 887, 909, 931, 953, 976, 1000
  ]


  (* 
   * round: int list -> real -> real
   *
   * Round a value to the nearest standard resistor value.
   *)
  fun round values n = if isFinite n then let
        val exp = Real.ceil (Math.log10 n) - 3
        val eoff = n / (10.0 pow Real.fromInt exp)
        fun find (a::b::r) = if eoff < a then a
                        else if eoff < b then (if (eoff-a) < (b-eoff) then a else b)
                        else find (b::r)
          | find (a::nil) = a
          | find nil = raise Empty
      in
        find values * (10.0 pow Real.fromInt exp)
      end
      else n

  val round_e96 = round e96


  (*
   * enumerate: 'a list -> (int * 'a) list
   *
   * Assign a 0-indexed, ascending integer to each element in the input.
   *)
  fun enumerate l = let fun en' n acc nil = rev acc
                          | en' n acc (x::xs) = en' (n+1) ((n, x)::acc) xs
                    in en' 0 nil l end


  (*
   * foldMap: ('a * 'b -> 'a * 'c) -> 'a -> 'b list -> 'a * 'c list
   *
   * "map" plus an accumulator.
   *)
  fun foldMap f acc list = let
        fun fm' acc ys nil = (acc, rev ys)
          | fm' acc ys (x::xs) = let val (acc, y) = f (acc, x)
                                  in fm' acc (y::ys) xs end
      in
        fm' acc nil list
     end


  (*
   * rms: real list -> real
   *
   * Calculate the RMS average of a list.
   *)
  fun rms list = Math.sqrt ((foldl Real.+ 0.0 (map (fn x => x*x) list))
                            / Real.fromInt (length list))


  (*
   * strs: int -> bool list
   *
   * Produce all binary strings of length n.
   *
   * This produces output in the correct order, but "little-endian": where false
   * is 0 and true is 1, "strs 3" returns 000, 100, 010, 110, 001...
   *)
  fun strs 0 = [ nil ]
    | strs n = foldr (fn (t, out) => (false::t) :: (true::t) :: out) nil (strs (n-1))


  (*
   * type stage
   *
   * Store a calculated attenuator stage. Series and shunt values are calculated
   * in the "stage" function based on theoretical input and desired output impedance,
   * then rounded to E96. inLoad is stored in the stage record for printing later.
   *)
  type stage = { dB: real, inLoad: real, rSeriesIdeal: real, rShuntIdeal: real,
                 rSeries: real, rShunt: real }


  (*
   * outOpen: real -> stage -> real
   * attenOpen: real -> stage -> real
   *
   * Calculate the *actual* output impedance and attenuation factor of a stage
   * when it has a given load impedance on its output.
   *)
  fun outOpen load ({ rSeries, rShunt, ... } : stage) = load || rShunt + rSeries
  fun attenOpen load ({ rSeries, rShunt, ... } : stage) = (load || rShunt) / (load || rShunt + rSeries)


  (*
   * stage: real * real -> real * stage
   *
   * Given a number of dB to attenuate and theoretical input impedance, calculate
   * series and shunt resistances.
   *)
  fun stage (inLoad, dB) = let
    val ratio = ratioFor dB

    val rShuntIdeal = (~rLoad) * ratio / (ratio - 1.0)
    val rSeriesIdeal = (inLoad||rShuntIdeal / ratio) - inLoad||rShuntIdeal

    val rSeries = round_e96 rSeriesIdeal
    val rShunt = round_e96 rShuntIdeal

    val s = { dB = dB, inLoad = inLoad, rSeriesIdeal = rSeriesIdeal, rShuntIdeal = rShuntIdeal,
          rSeries = rSeries, rShunt = rShunt }

    val outAverage = (outOpen inLoad s + inLoad) / 2.0
  in
    (outAverage, s)
  end


  (*
   * printStage: stage -> string
   *
   * Format information about a stage.
   *)
  fun printStage (s as { dB, inLoad, rSeriesIdeal, rShuntIdeal, rSeries, rShunt }) =
           "Attenuating " ^ r dB ^ " dB, input " ^ r inLoad ^ ":\n"
         ^ "  Ideal: series " ^ r rSeriesIdeal ^ ", shunt " ^ r rShuntIdeal ^ "\n"
         ^ "  E96: series " ^ r rSeries ^ ", shunt " ^ r rShunt ^ "\n"
         ^ "  Theoretical ratio " ^ r (attenOpen inLoad s)
         ^ " (" ^ r (dbFor (attenOpen inLoad s)) ^" dB)\n"
         ^ "  Open " ^ r (outOpen inLoad s) ^ ", closed " ^ r inLoad ^ "\n"


  (*
   * foldStage: (bool * stage) * (real * real) -> real * real
   *
   * This is intended to be folded over a list of (configuration * stage) tuples: for each
   * stage, calculate the new load impedance and attenuation factor based on whether it is
   * open or closed.
   *)
  fun foldStage ((stage, true), (load, atten, oimp)) = (outOpen load stage, atten * (attenOpen load stage), oimp)
    | foldStage ((stage, false), (load, atten, oimp)) = (load, atten, oimp)


  (* 
   * printConfig: int * (real * real) -> string
   *
   * Print out the actual results of setting the attenuator in position n.
   *)
  fun printConfig (n, (load, amt)) =
        Int.toString n ^ ": impedance " ^ r load ^ ", attenuation "
   (* ^ r amt ^ ": " *)
      ^ r (dbFor amt) ^ " dB, should be " ^ r (desired n) ^ " dB, off "
      ^ r (dbFor amt - desired n) ^ "\n"


  (*
   * error: int * (real * real) -> real
   *
   * Just like the name says: return the error (in dB) of the given stage.
   *)
  fun error (n, (load, amt)) = dbFor amt - desired n


  (* Calculate the actual stages we want. *)
  val (_, stages) = foldMap stage rLoad stageAttenuations

  (* Pull out the needed resistor values *)
  val resistors =
        ListMergeSort.sort
        (fn (a, b) => a > b)
        (foldl (fn ({ rSeries, rShunt, ... }: stage, l) => rSeries :: rShunt :: l) nil stages)

  (* Determine the actual result of setting each switch configuration *)
  fun calculateConfig conf =
        foldl foldStage (rLoad, 1.0) (ListPair.zip (stages, conf))
  val configs = enumerate (map calculateConfig (strs (length stages)))

in
  app (print o printStage) stages;
  print ("\nResistor values: " ^ String.concatWith ", " (map r resistors) ^ "\n\n");
  app print (map printConfig configs);
  print ("\nRMS error: " ^ r (rms (map error configs)) ^ " dB\n\n")
end
