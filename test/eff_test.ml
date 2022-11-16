
let i = ref 0;;

let log s = 
  Printf.printf "%s\n" s;
  Stdlib.flush_all ();;
let[@no_inline] work () = 
  log (Printf.sprintf "work: %d" !i);
  i := !i + 1;
  while true do 
    let l = List.init 1 (fun _ -> 0) in 
    Sys.opaque_identity l |> ignore; 
  done;
  ();;


let with_handlers b f =
  match b with 
 | true -> 
    Handlers.with_effects_handler 
      ~yielded_f:(fun () -> log "yielded") f
 | false -> f ();;

let rec _alarm () = 
  
  (* Handlers.with_effects_handler 
  ~yielded_f:(fun () -> log "yielded") 
    (fun () -> *)
with_handlers (!i==500) (fun () ->


  if !i > 1000 then 
    Handlers.yield ();

  log (Printf.sprintf "alarmed: %d" !i);
  Gc.finalise_release ();
  Gc.finalise_last _alarm (Sys.opaque_identity (Atomic.make 0));
  work ());;

let () = 
  Handlers.with_effects_handler 
    ~yielded_f:(fun () -> log "yielded") 
    (fun () ->
      Gc.create_alarm _alarm |> ignore;
      work ();)

