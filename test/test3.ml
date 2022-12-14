let () =
  let id = Atomic.make None in
  let write_something = Atomic.make false in
  let counter = ref 0 in 
  (* thr 1 *)
  let domain =
    Domain.spawn (fun () ->
        Handlers.with_effects_handler
          ~yielded_f:(fun () ->
            (*Printf.printf "got control!\n";
            Stdlib.flush_all (); *)
            Atomic.set write_something true)
          (fun () ->
            Preempt.setup2 Handlers.Yield;
            Atomic.set id (Some (Preempt.thread_id ()));
            while true do
              if Atomic.get write_something then (
                counter := Sys.opaque_identity (!counter + 1);
                Printf.printf "\n!!!got back in (n:%d)!!!\n" !counter;
                Stdlib.flush_all ();
                Preempt.setup2 Handlers.Yield; 
                Atomic.set write_something false);
            done))
  in

  (* thr 2 *)
  while Atomic.get id |> Option.is_none do
    ()
  done;
  match Atomic.get id with
  | None -> assert false
  | Some id ->
      Printf.printf "awaiting keypress\n";
      Stdlib.read_line () |> ignore; 
      while true do
        Unix.sleepf 0.001;
        Preempt.send_signal id;
        Printf.printf "sent signal\n";
        Stdlib.flush_all ();
      done;

      Stdlib.flush_all ();
      Sys.opaque_identity (print_string "hello\n");
      Domain.join domain
