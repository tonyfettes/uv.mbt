#include "moonbit.h"
#include <uv.h>
#include <stdlib.h>

#define auv_decl_wrap_type(name)                                               \
  typedef struct auv_##name {                                                  \
    struct moonbit_object header;                                              \
    uv_##name##_t name;                                                        \
  } auv_##name##_t

#define container_of(ptr, type, member)                                        \
  (type *)((char *)(ptr) - offsetof(type, member));

typedef struct auv_loop {
  struct moonbit_object header;
  uv_loop_t loop;
} auv_loop_t;

auv_loop_t *auv_loop_new() {
  auv_loop_t *loop = (auv_loop_t *)moonbit_malloc(sizeof(auv_loop_t));
  uv_loop_init(&loop->loop);
  return loop;
}

int auv_loop_run(auv_loop_t *loop, uv_run_mode mode) {
  return uv_run(&loop->loop, mode);
}

int auv_loop_close(auv_loop_t *loop) {
  abort();
  printf("loop->rc: %d\n", loop->header.rc);
  int rc = uv_loop_close(&loop->loop);
  printf("loop->rc: %d\n", loop->header.rc);
  moonbit_decref(loop);
  return rc;
}

typedef struct auv_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_cb *, ...);
} auv_cb_t;

auv_cb_t *moonbit_ffi_make_closure(int32_t (*code)(auv_cb_t *, ...),
                                   auv_cb_t *data) {
  return data;
}

typedef struct auv_idle_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_idle_cb *, void *);
} auv_idle_cb_t;

typedef struct auv_idle {
  struct moonbit_object header;
  uv_idle_t idle;
  auv_idle_cb_t *cb;
} auv_idle_t;

auv_idle_t *auv_idle_new(auv_loop_t *loop) {
  auv_idle_t *idle = (auv_idle_t *)moonbit_malloc(sizeof(auv_idle_t));
  uv_idle_init(&loop->loop, &idle->idle);
  return idle;
}

void auv_idle_cb(uv_idle_t *idle) {
  auv_idle_t *auv_idle = container_of(idle, auv_idle_t, idle);
  auv_idle_cb_t *auv_idle_cb = auv_idle->cb;
  printf("auv_idle_cb->rc: %d\n", auv_idle_cb->header.rc);
  moonbit_incref(auv_idle_cb);
  auv_idle_cb->code(auv_idle_cb, auv_idle);
}

int auv_idle_start(auv_idle_t *idle, auv_idle_cb_t *cb) {
  idle->cb = cb;
  return uv_idle_start(&idle->idle, auv_idle_cb);
}

void auv_idle_stop(auv_idle_t *idle) {
  printf("idle->rc: %d\n", idle->header.rc);
  uv_idle_stop(&idle->idle);
  moonbit_decref(idle);
}
