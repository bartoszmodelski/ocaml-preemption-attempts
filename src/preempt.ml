type t = int

external thread_id : unit -> t = "thread_id"
external send_signal : t -> unit = "send_signal"
external install_handler : unit Effect.t -> unit = "install_handler"
external install_handler2 : unit -> unit = "install_handler2"
external install_handler3 : unit -> unit = "install_handler3"

let setup (eff : unit Effect.t) = install_handler eff


let setup2 (eff : unit Effect.t) =
  let f () = 
    (* Printf.eprintf "hiya!\n"; *)
    Effect.perform eff 
  in
  Callback.register "yield_callback" f;
  install_handler2 ()
;;

let setup3 = install_handler3