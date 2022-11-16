let log s = 
  Printf.printf "%s\n" s;
  Stdlib.flush_all ();;


let () = 
  Handlers.with_effects_handler 
    ~yielded_f:(fun () -> log "yielded") 
    (fun () ->
      log "in handlers";
      (* trigger gc *)
      while true do Atomic.make 0 |> Sys.opaque_identity |> ignore done;
      Handlers.yield ());
  log "outside";;

