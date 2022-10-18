#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <caml/mlvalues.h>

CAMLprim value thread_id() {
  pthread_t id = pthread_self();
  return Val_int(id);
}

CAMLprim value send_signal(value pthread_id) {

  pthread_t id = Long_val(pthread_id);
  /* See https://github.com/golang/proposal/blob/master/design/24543-non-cooperative-preemption.md 
    why SIGURG. */
  pthread_kill(id, SIGURG);;
  return Val_unit;
} 