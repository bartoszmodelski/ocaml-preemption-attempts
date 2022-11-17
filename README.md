Repo documenting attempts to force OCaml into preemption. 

# Log
## Perform effect in signal handler

Unhandled effect. Runtime purposefully removes effect handlers when entering OCaml from C (handler actions are executed from safepoint). 

## Perform effect in a finalizer

Unhandled effect. As above. 

Something that works here is to call `finalise_release` and re-enter the scheduler to run the next task. But that can only be done a limited number of times before we blow through the stack limit. Also tasks buried under a never-yielding stack are not accessible. 

## Perform effect in true signal handler

OCaml does not actually run the signal handlers as they happen. Runtime signal handler puts the signals into pending actions, which are then executed from safepoint. Thus, try to override runtime handler, and throw effect from the frame set up by OS. The benefit here is that the important OCaml registers are still there. Requires a little inline asm to put effect where `caml_perform` expects it. 

This **somewhat works**. Allocation inside handler breaks things, but if there's no allocations, it's not survives 70-800 perform-continue cycles before segfault. Further, the segfaults seem to happen due to signal arriving during OCaml's runtime logic. 


The good part here is that we make good use of OS-provided signal-frame. The sig handler gets called with mostly-OCaml-valid registers, we immediately jump into OCaml code, then on the way back, we just need to survive until end of signal-frame (afterwards pre-signal registers are restored). Still, if allocating inside effect handler segfaults, something must be getting mangled in the minimal code preceding jump into asm.

## Perform effect in true signal handler after calling back into OCaml

Do all above, but don't try to perform effect from C. Instead, call OCaml closure performing an effect by invoking `caml_callback_asm` (to skip the pesky handlers-removing code). Here, resumption should not be this much different from normal order of things.

**Somewhat works** but **a lot better**. Goes into many thousands of perform-continue cycles, even 1 million. Still cannot allocate in the handlers. 

Most of the failures are deadlocks, perhaps signal mismanagement? Segfaults also happen. Again, I don't think we can eliminate segfaults as long as there's no runtime-logic detection.

# Not tried

* Suspend domain with the busy task and spawn a new one. 
  
* Call back into ocaml from the last thing in ocaml gc call

* Start a new task from signal handler allocated on a custom stack. Still the issue of entering mid gc, etc. 

# Other things here

* Bindings for sending signals to threads (rather than processes) mimicking the way Go does that.