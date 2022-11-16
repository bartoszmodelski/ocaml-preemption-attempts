
type _ Effect.t += Yield : unit Effect.t

val yield : unit -> unit
val with_effects_handler : yielded_f : (unit -> unit) -> (unit -> unit) -> unit