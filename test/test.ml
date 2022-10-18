let log s = 
  Printf.printf "%s" s;
  Stdlib.flush_all ();;

let install_handler () = 
  Sys.signal Sys.sigurg (Sys.Signal_handle (fun _ -> log "got signal!")) 
  |> ignore;;



let new_domain () =  
  let thread_id = Atomic.make None in 
  Domain.spawn (fun () -> 
    let my_id = Preempt.thread_id () in 
    install_handler ();
    Atomic.set thread_id (Some my_id); 
    while true do Stdlib.flush_all () done)
  |> Sys.opaque_identity |> ignore;

  while Option.is_none (Atomic.get thread_id) do () done;
  match Atomic.get thread_id with
  | None -> assert false
  | Some id -> id
;;

let () = 
  let thread_id = new_domain () in 
  Stdlib.read_line () |> ignore; 
  Preempt.send_signal thread_id;
  while true do Stdlib.flush_all () done;;