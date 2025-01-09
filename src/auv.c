#include "moonbit.h"
#include <stdlib.h>
#include <uv.h>

#define auv_decl_wrap_type(name)                                               \
  typedef struct auv_##name {                                                  \
    struct moonbit_object header;                                              \
    uv_##name##_t name;                                                        \
  } auv_##name##_t

#define container_of(ptr, type, member)                                        \
  (type *)((char *)(ptr) - offsetof(type, member));

typedef uv_loop_t auv_loop_t;

auv_loop_t *auv_loop_new() {
  uv_loop_t *loop = malloc(sizeof(uv_loop_t));
  uv_loop_init(loop);
  return loop;
}

int auv_loop_run(auv_loop_t *loop, uv_run_mode mode) {
  return uv_run(loop, mode);
}

int auv_loop_close(auv_loop_t *loop) {
  int rc = uv_loop_close(loop);
  free(loop);
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
  int32_t (*code)(struct auv_idle_cb *, uv_idle_t *);
} auv_idle_cb_t;

typedef struct auv_idle {
  uv_idle_t idle;
  auv_idle_cb_t *cb;
} auv_idle_t;

auv_idle_t *auv_idle_new(auv_loop_t *loop) {
  auv_idle_t *idle = malloc(sizeof(auv_idle_t));
  uv_idle_init(loop, &idle->idle);
  return idle;
}

void auv_idle_cb(uv_idle_t *idle) {
  auv_idle_t *auv_idle = container_of(idle, auv_idle_t, idle);
  auv_idle_cb_t *auv_idle_cb = auv_idle->cb;
  moonbit_incref(auv_idle_cb);
  auv_idle_cb->code(auv_idle_cb, idle);
}

int auv_idle_start(auv_idle_t *idle, auv_idle_cb_t *cb) {
  idle->cb = cb;
  return uv_idle_start(&idle->idle, auv_idle_cb);
}

void auv_idle_stop(auv_idle_t *idle) {
  uv_idle_stop(&idle->idle);
  moonbit_decref(idle->cb);
  free(idle);
}
