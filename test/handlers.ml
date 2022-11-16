open Effect
open Effect.Deep

type _ Effect.t += Yield : unit Effect.t

let yield () = perform Yield

let[@no_inline] with_effects_handler ~yielded_f f =
  Printf.printf "setup handlers\n";
  Stdlib.flush_all ();        
  try_with f () 
  { effc = fun (type a) (e : a Effect.t) ->
    match e with
    | Yield -> 
      Some (fun (k : (a, unit) continuation) ->
        Printf.printf "in effects handler\n";
        Stdlib.flush_all ();        
        yielded_f (); continue k ())
    | _ -> 
      Printf.printf "wrong handler\n";
      Stdlib.flush_all ();        
      None}



