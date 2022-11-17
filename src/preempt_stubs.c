#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <assert.h>

#include <caml/mlvalues.h>
#include <caml/callback.h>
#include <caml/fiber.h>
#include <caml/domain.h>




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
  /*switch (signo)
  {
  case SIGURG:
    assert(yield_eff);*/

    __asm__ __volatile__("movq %0, %%rax  \n\t"
                         :
                         : "r"(yield_eff)
                         : "%rax");

    caml_perform(yield_eff);
  /*  break;
  }*/
}

CAMLprim value install_handler(value user_eff)
{
  yield_eff = user_eff;

  struct sigaction psa = {};
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



value *closure = NULL;
value arg = Val_unit;

void set_closure() {
  closure = caml_named_value("yield_callback");
  assert(closure != NULL);
}

static void sig_handler2(int signo)
{
  Caml_check_caml_state();
  caml_domain_state *domain_state = Caml_state;
  assert(domain_state);

  caml_maybe_expand_stack();

  caml_callback_asm(domain_state, *closure, &arg); 

  set_closure();
}

CAMLprim value install_handler2()
{
  set_closure();

  struct sigaction psa;
  psa.sa_handler = sig_handler2;
  // psa.sa_flags = SA_NODEFER;
  sigaction(SIGURG, &psa, NULL);
  return Val_unit;
}

/* use interruptor */


CAMLextern void (*caml_domain_external_interrupt_hook)(void);
void (*hook_previous)(void);


static void caml_domain_external_interrupt_hook_hacked(void)
{
  Caml_check_caml_state();
  
  caml_domain_state *domain_state = Caml_state;
  assert(domain_state);
  domain_state->requested_external_interrupt = 0;

  caml_maybe_expand_stack();

  caml_callback_asm(domain_state, *closure, &arg); 
  
  //fprintf(stderr, "called!\n");
  return;
}


CAMLprim value enable() {
  set_closure();

  caml_domain_state *domain_state = Caml_state;
  assert(domain_state);
  domain_state->requested_external_interrupt = 1;
  caml_interrupt_self();
}


CAMLprim value install_handler3()
{
  hook_previous = caml_domain_external_interrupt_hook;
  caml_domain_external_interrupt_hook = caml_domain_external_interrupt_hook_hacked;

  enable();

  return Val_unit;
}