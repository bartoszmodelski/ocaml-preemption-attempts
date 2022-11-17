
let print_here () = print_string "here\n"; Stdlib.flush_all ();;


let () = 
  let id = Atomic.make None in 

  (* thr 1 *)
  let domain = Domain.spawn (fun () -> 
    Handlers.with_effects_handler 
    ~yielded_f:(fun () -> print_string "got control!\n"; Stdlib.flush_all ())
    (fun () ->  
      
      Handlers.yield ();

      Sys.signal 
        Sys.sigurg 
        (Sys.Signal_handle (fun _ -> 
          print_here ();
          Handlers.yield ())) 
      |> ignore;
      Atomic.set id (Some (Preempt.thread_id ()));
      while 1 = 1 do Sys.opaque_identity () done) 
    )
  in

  (* thr 2 *)
  while Atomic.get id |> Option.is_none do () done;
  match Atomic.get id with 
  | None -> assert false;
  | Some id -> 
    (Preempt.send_signal id;
    Sys.opaque_identity (print_string "hello\n");
    Domain.join domain);    
;;