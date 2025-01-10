#include "moonbit.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <uv.h>

#define auv_decl_t(name)                                                       \
  typedef struct auv_##name {                                                  \
    uv_##name##_t name;                                                        \
  } auv_##name##_t

#define auv_decl_cb_t(name)                                                    \
  typedef struct auv_##name##_cb {                                             \
    struct moonbit_object header;                                              \
    int32_t (*code)(struct auv_##name##_cb *, ...);                            \
  } auv_##name##_cb_t

#define container_of(ptr, type, member)                                        \
  (type *)((char *)(ptr)-offsetof(type, member));

typedef struct auv_loop {
  uv_loop_t loop;
} auv_loop_t;

auv_loop_t *auv_loop_alloc() { return (auv_loop_t *)malloc(sizeof(uv_loop_t)); }

int auv_loop_init(auv_loop_t *loop) { return uv_loop_init(&loop->loop); }

int auv_loop_run(auv_loop_t *loop, uv_run_mode mode) {
  return uv_run(&loop->loop, mode);
}

int auv_loop_close(auv_loop_t *loop) { return uv_loop_close(&loop->loop); }

void auv_loop_free(auv_loop_t *loop) { free(loop); }

typedef struct auv_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_cb *, ...);
} auv_cb_t;

auv_cb_t *moonbit_ffi_make_closure(int32_t (*code)(auv_cb_t *, ...),
                                   auv_cb_t *data) {
  return data;
}

typedef struct auv_idle auv_idle_t;

typedef struct auv_idle_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_idle_cb *, auv_idle_t *);
} auv_idle_cb_t;

struct auv_idle {
  uv_idle_t idle;
  auv_idle_cb_t *cb;
};

#define auv_malloc(type) ((type *)malloc(sizeof(type)))

auv_idle_t *auv_idle_alloc() { return auv_malloc(auv_idle_t); }

int auv_idle_init(auv_loop_t *loop, auv_idle_t *idle) {
  return uv_idle_init(&loop->loop, &idle->idle);
}

void auv_idle_cb(uv_idle_t *idle) {
  auv_idle_t *auv_idle = container_of(idle, auv_idle_t, idle);
  auv_idle_cb_t *auv_idle_cb = auv_idle->cb;
  moonbit_incref(auv_idle_cb);
  auv_idle_cb->code(auv_idle_cb, auv_idle);
}

int auv_idle_start(auv_idle_t *idle, auv_idle_cb_t *cb) {
  idle->cb = cb;
  return uv_idle_start(&idle->idle, auv_idle_cb);
}

int auv_idle_stop(auv_idle_t *idle) { return uv_idle_stop(&idle->idle); }

void auv_idle_free(auv_idle_t *idle) {
  if (idle->cb) {
    moonbit_decref(idle->cb);
  }
  free(idle);
}

typedef struct auv_buf {
  uv_buf_t buf;
} auv_buf_t;

auv_buf_t *auv_buf_alloc() { return auv_malloc(auv_buf_t); }

void auv_buf_init(auv_buf_t *buf, struct moonbit_bytes *bytes) {
  buf->buf = uv_buf_init((char *)bytes->data, Moonbit_array_length(bytes));
}

void auv_buf_set_len(auv_buf_t *buf, size_t len) { buf->buf.len = len; }

static inline uv_buf_t *auv__refs_to_bufs(auv_buf_t *refs[],
                                          unsigned int size) {
  uv_buf_t *bufs = malloc(sizeof(uv_buf_t) * size);
  for (int i = 0; i < size; i++) {
    bufs[i] = refs[i]->buf;
  }
  return bufs;
}

typedef struct auv_fs auv_fs_t;

typedef struct auv_fs_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_fs_cb *, auv_fs_t *);
} auv_fs_cb_t;

struct auv_fs {
  uv_fs_t fs;
  auv_fs_cb_t *cb;
};

void auv_fs_cb(uv_fs_t *req) {
  auv_fs_t *auv_fs = container_of(req, auv_fs_t, fs);
  auv_fs_cb_t *auv_fs_cb = auv_fs->cb;
  moonbit_incref(auv_fs_cb);
  auv_fs_cb->code(auv_fs_cb, auv_fs);
}

auv_fs_t *auv_fs_alloc() { return malloc(sizeof(auv_fs_t)); }

ssize_t auv_fs_get_result(auv_fs_t *fs) { return fs->fs.result; }

int auv_fs_open(auv_loop_t *loop, auv_fs_t *fs, struct moonbit_bytes *path,
                int flags, int mode, auv_fs_cb_t *cb) {
  int n_path = Moonbit_array_length(path);
  const char *c_path = strndup((char *)path->data, n_path);
  fs->cb = cb;
  return uv_fs_open(&loop->loop, &fs->fs, c_path, flags, mode, auv_fs_cb);
}

int auv_fs_close(auv_loop_t *loop, auv_fs_t *fs, uv_file file,
                 auv_fs_cb_t *cb) {
  fs->cb = cb;
  return uv_fs_close(&loop->loop, &fs->fs, file, auv_fs_cb);
}

int auv_fs_read(auv_loop_t *loop, auv_fs_t *fs, uv_file file,
                struct moonbit_ref_array *bufs, int64_t offset,
                auv_fs_cb_t *cb) {
  static_assert(sizeof(auv_buf_t) == sizeof(uv_buf_t),
                "auv_buf_t and uv_buf_t must have the same size");
  uint32_t bufs_len = Moonbit_array_length(bufs);
  uv_buf_t *bufs_val = auv__refs_to_bufs((auv_buf_t **)bufs->data, bufs_len);
  fs->cb = cb;
  int rc = uv_fs_read(&loop->loop, &fs->fs, file, bufs_val, bufs_len, offset,
                      auv_fs_cb);
  free(bufs_val);
  return rc;
}

int auv_fs_write(auv_loop_t *loop, auv_fs_t *fs, uv_file file,
                 struct moonbit_ref_array *bufs, int64_t offset,
                 auv_fs_cb_t *cb) {
  static_assert(sizeof(auv_buf_t) == sizeof(uv_buf_t),
                "auv_buf_t and uv_buf_t must have the same size");
  uint32_t bufs_len = Moonbit_array_length(bufs);
  uv_buf_t *bufs_val = auv__refs_to_bufs((auv_buf_t **)bufs->data, bufs_len);
  fs->cb = cb;
  int rc = uv_fs_write(&loop->loop, &fs->fs, file, bufs_val, bufs_len, offset,
                       auv_fs_cb);
  free(bufs_val);
  return rc;
}
