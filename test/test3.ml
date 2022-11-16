let () =
  let id = Atomic.make None in
  let write_something = ref false in
  let counter = ref 0 in 

  (* thr 1 *)
  let domain =
    Domain.spawn (fun () ->
        Handlers.with_effects_handler
          ~yielded_f:(fun () ->
            (* reinstall our handler (I think OCaml runtime might be resetting its own in some cases) *)
            (* Printf.printf "got control!\n";
            Stdlib.flush_all (); *)
            write_something := true)
          (fun () ->
            Preempt.setup Handlers.Yield;
            Atomic.set id (Some (Preempt.thread_id ()));
            while true do
              if !write_something then (
                counter := Sys.opaque_identity (!counter + 1);
                Printf.printf "\n!!!got back in (n:%d)!!!\n" !counter;
                Stdlib.flush_all ();
                Preempt.setup Handlers.Yield; 
                write_something := false);
            done))
  in

  (* thr 2 *)
  while Atomic.get id |> Option.is_none do
    ()
  done;
  match Atomic.get id with
  | None -> assert false
  | Some id ->
      while true do
        Printf.printf "awaiting keypress\n";
        Stdlib.read_line () |> ignore; 
        Preempt.send_signal id;
        Printf.printf "sent signal\n";
        Stdlib.flush_all ()
      done;

      Stdlib.flush_all ();
      Sys.opaque_identity (print_string "hello\n");
      Domain.join domain
