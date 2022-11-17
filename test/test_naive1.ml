let log s = 
  Printf.printf "%s\n" s;
  Stdlib.flush_all ();;


let do_stuff () = while true do Stdlib.flush_all () done;;
let work () = 
  Handlers.with_effects_handler 
    ~yielded_f:(fun () -> log "yielded!")
    (fun () ->
      do_stuff ())

let install_handler () = 
  Sys.signal Sys.sigurg (Sys.Signal_handle (fun _ -> 
    log "in signal handler";
    work ();
    log "leaving signal handler")) 
  |> ignore;;


let new_domain () =  
  let thread_id = Atomic.make None in 
  Domain.spawn (fun () -> 
    Domain.at_exit (fun () -> log "died");
    install_handler ();
    let my_id = Preempt.thread_id () in 
    Atomic.set thread_id (Some my_id); 
    work ())
  |> Sys.opaque_identity |> ignore;

  while Option.is_none (Atomic.get thread_id) do () done;
  match Atomic.get thread_id with
  | None -> assert false
  | Some id -> id
;;

let () = 
  let thread_id = new_domain () in 
  while true do 
    Stdlib.read_line () |> ignore; 
    Preempt.send_signal thread_id;
  done;;
