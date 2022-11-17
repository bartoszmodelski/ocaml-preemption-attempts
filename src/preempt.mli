type t = int

val thread_id : unit -> t 

val send_signal : t -> unit

val setup : unit Effect.t -> unit

val setup2 : unit Effect.t -> unit

val setup3 : unit -> unit