type t = int
external thread_id : unit -> t = "thread_id"

external send_signal : t -> unit = "send_signal"

