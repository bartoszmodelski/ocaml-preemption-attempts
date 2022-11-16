Repo documenting attempts to force OCaml into preemption. 

# Log
## Perform effect in signal handler

Unhandled effect. Runtime purposefully removes effect handlers when entering OCaml from C (handler actions are executed from safepoint). 

## Perform effect in a finalizer

Unhandled effect. As above. 

Something that works here is to call `finalise_release` and re-enter the scheduler to run the next task. But that can only be done a limited number of times before we blow through the stack limit. Also tasks buried under a never-yielding stack are not accessible. 

## Perform effect in true signal handler

OCaml does not actually run the signal handlers as they happen. Runtime signal handler puts the signals into pending actions, which are then executed from safepoint. Thus, try to override runtime handler, and throw effect from the frame set up by OS. The benefit here is that the important OCaml registers are still there. Requires a little inline asm to put effect where `caml_perform` expects it. 

Effect gets caught, but continuation doesn't work. 

The nice part here is that returning from C signal-frame after resumption is set up by OS, so it's going to be fine. The not so nice are: 
* We're jumping back into C frame on resumption, so yeah - not quite something `caml_resume` was made for. 
* What happens when the signal is handled over a C frame (and important ocaml registers are not set)?

## Perform effect in true signal handler after calling back into OCaml

Do all above, but don't try to perform effect from C. Instead, call OCaml closure performing an effect by invoking `caml_callback_asm` (to skip the pesky handlers-removing code). Here, resumption should not be this much different from normal order of things.

**Works** (unless you allocate in the handler logic). Overall pretty promising given the amount of hackery. It fails quickly with gc error (`allocation failure during minor GC`) if the handler allocates memory. Otherwise, it segfaults at some point, which I think is expected, given that we may preempt while some critical runtime logic is happening. 

At some point here means  anywhere between 50 to 1000 preempts. Seems like exp distribution, so a good sign. 

# Not tried

* Suspend domain with the busy task and spawn a new one. 
  
* Call back into ocaml from the last thing in ocaml gc call

* Start a new task from signal handler allocated on a custom stack. Still the issue of entering mid gc, etc. 

# Other things here

* Bindings for sending signals to threads (rather than processes) mimicking the way Go does that.