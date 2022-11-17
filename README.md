Repo documenting attempts to force OCaml into preemption. 

# Log
## Perform effect in signal handler

Unhandled effect. Runtime purposefully removes effect handlers when entering OCaml from C (handler actions are executed from safepoint). 

## Perform effect in a finalizer

Unhandled effect. As above. 

Something that works here is to call `finalise_release` and re-enter the scheduler to run the next task. But that's going to blow through the stack and tasks buried under a never-yielding stack are inaccessible. 

## Perform effect in true signal handler

OCaml does not deliver signals as they happen. Instead runtime signal handler puts the signals into pending actions, which are then executed at safepoints. Thus try the following: override runtime handler, throw effect from the signal-frame set up by OS. Requires a little inline asm to put effect where `caml_perform` expects it. 

This **kinda works**. Allocation inside handler breaks things, but if there's no allocations, it survives 70-800 perform-continue cycles before segfault. Further, the segfaults seem to happen due to signal arriving over OCaml's runtime logic. 

The good part here is that we make use of OS-provided signal-frame. The sig handler gets called with mostly-OCaml-valid registers, we immediately jump into OCaml code, and on the way back, we just need to survive until end of signal-frame (afterwards pre-signal registers are restored). 

## Perform effect in true signal handler after calling back into OCaml

Do all above, but don't perform effect from C. Instead, call OCaml closure performing an effect by invoking `caml_callback_asm` (to skip the pesky handlers-removing code). 

**Kinda works** but **a lot better**. Goes into many thousands of perform-continue cycles, even nearing 1 million. Still cannot allocate in the handlers. 

Lots of the failures are deadlock that look like some signal mismanagement. Segfaults also happen. Again, I don't think we can eliminate segfaults as long as there's no runtime-logic detection.

## Perform effect from `caml_domain_external_interrupt_hook` after calling back into OCaml

**Great success!**. Reached over 30m+ perform-resume cycles before I stopped it. No segfaults witnessed. Allocations in handlers are fine.


# Other things here

* Bindings for sending signals to threads (rather than processes), mimicking the way Go does that.