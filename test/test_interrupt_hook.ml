let () =
  let id = Atomic.make None in
  let write_something = Atomic.make false in
  let counter = ref 0 in
  (* thr 1 *)
  let domain =
    Domain.spawn (fun () ->
        Handlers.with_effects_handler
          ~yielded_f:(fun () -> 
            Printf.eprintf "in handler!\n";
            Atomic.set write_something true)
          (fun () ->
            Preempt.setup3 Handlers.Yield;
            Atomic.set id (Some (Preempt.thread_id ()));
            while true do
              if Atomic.get write_something then (
                counter := Sys.opaque_identity (!counter + 1);
                Printf.eprintf "\n!!!got back in (n:%d)!!!\n" !counter;
                Atomic.set write_something false;
                Preempt.setup3_enable ())
            done))
  in

  (* thr 2 - keeping it in to be in multicore mode *)
  while Atomic.get id |> Option.is_none do
    ()
  done;
  match Atomic.get id with
  | None -> assert false
  | Some _ ->
      while true do
        Printf.printf "awaiting keypress\n";
        Stdlib.flush_all ();
        Stdlib.read_line () |> ignore
      done;

      Stdlib.flush_all ();
      Sys.opaque_identity (print_string "hello\n");
      Domain.join domain
