#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <assert.h>
#include <caml/mlvalues.h>
#include <caml/callback.h>

CAMLprim value thread_id()
{
  pthread_t id = pthread_self();
  return Val_int(id);
}

CAMLprim value send_signal(value pthread_id)
{
  pthread_t id = Long_val(pthread_id);
  /* See https://github.com/golang/proposal/blob/master/design/24543-non-cooperative-preemption.md
    why SIGURG. */
  pthread_kill(id, SIGURG);

  return Val_unit;
}

/* try performing from C */

value yield_eff;
extern void caml_perform(value eff);

static void sig_handler(int signo)
{
  switch (signo)
  {
  case SIGURG:
    assert(yield_eff);

    __asm__ __volatile__("movq %0, %%rax  \n\t"
                         :
                         : "r"(yield_eff)
                         : "%rax");

    caml_perform(yield_eff);
    break;
  }
}

CAMLprim value install_handler(value user_eff)
{
  yield_eff = user_eff;

  struct sigaction psa;
  psa.sa_handler = sig_handler;
  // psa.sa_flags = SA_NODEFER;
  sigaction(SIGURG, &psa, NULL);
  return Val_unit;
}

/* try calling back into ocaml */

typedef value(callback_stub)(caml_domain_state *state,
                             value closure,
                             value *args);

callback_stub caml_callback_asm;

static void sig_handler2(int signo)
{

  switch (signo)
  {
  case SIGURG:
    static const value *closure = NULL;

    closure = caml_named_value("yield_closure");
    assert(closure);

    Caml_check_caml_state();
    
    caml_domain_state* domain_state = Caml_state;
    assert(domain_state);
    
    //caml_maybe_expand_stack();
    
    value arg = Val_unit;
    caml_callback_asm(domain_state, closure, &arg);

    //caml_callback(*closure, Val_unit);
    break;
  }
}

CAMLprim value install_handler2()
{
  struct sigaction psa;
  psa.sa_handler = sig_handler2;
  // psa.sa_flags = SA_NODEFER;
  sigaction(SIGURG, &psa, NULL);
  return Val_unit;
}