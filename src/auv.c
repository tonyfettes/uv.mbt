#include "moonbit.h"
#include <netinet/in.h>
#include <stdlib.h>
#include <uv.h>

#define auv_decl_t(name)                                                       \
  typedef struct auv_##name {                                                  \
    uv_##name##_t name;                                                        \
  } auv_##name##_t

#define auv_decl_cb_t(name, ...)                                               \
  typedef struct auv_##name##_cb {                                             \
    struct moonbit_object header;                                              \
    int32_t (*code)(struct auv_##name##_cb *, __VA_ARGS__);                    \
  } auv_##name##_cb_t

#define container_of(ptr, type, member)                                        \
  (type *)((char *)(ptr)-offsetof(type, member));

uv_loop_t *auv_loop_alloc() { return (uv_loop_t *)malloc(sizeof(uv_loop_t)); }

int auv_loop_init(uv_loop_t *loop) { return uv_loop_init(loop); }

int auv_loop_run(uv_loop_t *loop, uv_run_mode mode) {
  return uv_run(loop, mode);
}

int auv_loop_close(uv_loop_t *loop) { return uv_loop_close(loop); }

void auv_loop_free(uv_loop_t *loop) { free(loop); }

typedef struct auv_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_cb *);
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

int auv_idle_init(uv_loop_t *loop, auv_idle_t *idle) {
  return uv_idle_init(loop, &idle->idle);
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

uv_buf_t *auv_buf_alloc() { return auv_malloc(uv_buf_t); }

void auv_buf_init(uv_buf_t *buf, struct moonbit_bytes *bytes) {
  *buf = uv_buf_init((char *)bytes->data, Moonbit_array_length(bytes));
}

void auv_buf_set_len(uv_buf_t *buf, size_t len) { buf->len = len; }

void auv_buf_free(uv_buf_t *buf) { free(buf); }

static inline uv_buf_t *auv__refs_to_bufs(uv_buf_t *refs[], unsigned int size) {
  uv_buf_t *bufs = malloc(sizeof(uv_buf_t) * size);
  for (int i = 0; i < size; i++) {
    bufs[i] = *refs[i];
  }
  return bufs;
}

typedef struct auv_fs_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_fs_cb *, uv_fs_t *);
} auv_fs_cb_t;

void auv_fs_cb(uv_fs_t *req) {
  auv_fs_cb_t *auv_fs_cb = req->data;
  moonbit_incref(auv_fs_cb);
  auv_fs_cb->code(auv_fs_cb, req);
}

uv_fs_t *auv_fs_alloc() { return malloc(sizeof(uv_fs_t)); }

ssize_t auv_fs_get_result(uv_fs_t *fs) { return fs->result; }

static inline const char *auv__bytes_to_str(struct moonbit_bytes *bytes) {
  int len = Moonbit_array_length(bytes);
  return strndup((char *)bytes->data, len);
}

int auv_fs_open(uv_loop_t *loop, uv_fs_t *fs, struct moonbit_bytes *path,
                int flags, int mode, auv_fs_cb_t *cb) {
  const char *path_str = auv__bytes_to_str(path);
  fs->data = cb;
  return uv_fs_open(loop, fs, path_str, flags, mode, auv_fs_cb);
}

int auv_fs_close(uv_loop_t *loop, uv_fs_t *fs, uv_file file, auv_fs_cb_t *cb) {
  fs->data = cb;
  return uv_fs_close(loop, fs, file, auv_fs_cb);
}

int auv_fs_read(uv_loop_t *loop, uv_fs_t *fs, uv_file file,
                struct moonbit_ref_array *bufs, int64_t offset,
                auv_fs_cb_t *cb) {
  uint32_t bufs_len = Moonbit_array_length(bufs);
  uv_buf_t *bufs_val = auv__refs_to_bufs((uv_buf_t **)bufs->data, bufs_len);
  fs->data = cb;
  int rc = uv_fs_read(loop, fs, file, bufs_val, bufs_len, offset, auv_fs_cb);
  free(bufs_val);
  return rc;
}

int auv_fs_write(uv_loop_t *loop, uv_fs_t *fs, uv_file file,
                 struct moonbit_ref_array *bufs, int64_t offset,
                 auv_fs_cb_t *cb) {
  uint32_t bufs_len = Moonbit_array_length(bufs);
  uv_buf_t *bufs_val = auv__refs_to_bufs((uv_buf_t **)bufs->data, bufs_len);
  fs->data = cb;
  int rc = uv_fs_write(loop, fs, file, bufs_val, bufs_len, offset, auv_fs_cb);
  free(bufs_val);
  return rc;
}

int auv_accept(uv_stream_t *server, uv_stream_t *client) {
  return uv_accept(server, client);
}

typedef struct auv_connection_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_connection_cb *, uv_stream_t *server, int status);
} auv_connection_cb_t;

void auv_listen_cb(uv_stream_t *server, int status) {
  auv_connection_cb_t *cb = server->data;
  moonbit_incref(cb);
  cb->code(cb, server, status);
}

int auv_listen(uv_stream_t *stream, int backlog, auv_connection_cb_t *cb) {
  stream->data = cb;
  return uv_listen(stream, backlog, auv_listen_cb);
}

typedef struct auv_close_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_close_cb *, uv_handle_t *handle);
} auv_close_cb_t;

static inline void auv__close_cb(uv_handle_t *handle) {
  auv_close_cb_t *auv_cb = handle->data;
  moonbit_incref(auv_cb);
  auv_cb->code(auv_cb, handle);
}

void auv_close(uv_handle_t *handle, auv_close_cb_t *close_cb) {
  handle->data = close_cb;
  uv_close(handle, auv__close_cb);
}

struct sockaddr_in *auv_sockaddr_in_alloc() {
  return malloc(sizeof(struct sockaddr_in));
}

void auv_ip4_addr(struct moonbit_bytes *ip, int port,
                  struct sockaddr_in *addr) {
  const char *ip_str = auv__bytes_to_str(ip);
  uv_ip4_addr(ip_str, port, addr);
}

uv_tcp_t *auv_tcp_alloc() { return auv_malloc(uv_tcp_t); }

int auv_tcp_init(uv_loop_t *loop, uv_tcp_t *tcp) {
  return uv_tcp_init(loop, tcp);
}

int auv_tcp_bind(uv_tcp_t *tcp, const struct sockaddr *addr,
                 unsigned int flags) {
  return uv_tcp_bind(tcp, addr, flags);
}

typedef struct auv_alloc_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_alloc_cb *, uv_handle_t *, size_t suggested_size, uv_buf_t *buf);
} auv_alloc_cb_t;

typedef struct auv_read_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_read_cb *, uv_stream_t *, ssize_t nread, const uv_buf_t *buf);
} auv_read_cb_t;

typedef struct auv_stream_cb {
  auv_alloc_cb_t *alloc_cb;
  auv_read_cb_t *read_cb;
} auv_stream_cb_t;

static inline void auv_alloc_cb(uv_handle_t *handle, size_t suggested_size,
                                uv_buf_t *buf) {
  auv_stream_cb_t *stream_cb = handle->data;
  auv_alloc_cb_t *alloc_cb = stream_cb->alloc_cb;
  moonbit_incref(alloc_cb);
  alloc_cb->code(alloc_cb, handle, suggested_size, buf);
}

static inline void auv_read_cb(uv_stream_t *stream, ssize_t nread,
                               const uv_buf_t *buf) {
  printf("auv_read_cb: nread = %ld\n", nread);
  printf("auv_read_cb: buf = %p\n", buf);
  auv_stream_cb_t *stream_cb = stream->data;
  auv_read_cb_t *read_cb = stream_cb->read_cb;
  moonbit_incref(read_cb);
  read_cb->code(read_cb, stream, nread, buf);
}

void auv_read_start(uv_stream_t *stream, auv_alloc_cb_t *alloc_cb,
                    auv_read_cb_t *read_cb) {
  auv_stream_cb_t *cb = auv_malloc(auv_stream_cb_t);
  cb->read_cb = read_cb;
  cb->alloc_cb = alloc_cb;
  stream->data = cb;
  uv_read_start(stream, auv_alloc_cb, auv_read_cb);
}

uv_write_t *auv_write_alloc() { return auv_malloc(uv_write_t); }

typedef struct auv_write_cb {
  struct moonbit_object header;
  int32_t (*code)(struct auv_write_cb *, uv_write_t *req, int status);
} auv_write_cb_t;

static inline void auv_write_cb(uv_write_t *req, int status) {
  auv_write_cb_t *auv_cb = req->data;
  moonbit_incref(auv_cb);
  auv_cb->code(auv_cb, req, status);
}

int auv_write(uv_write_t *req, uv_stream_t *handle,
              struct moonbit_ref_array *bufs, auv_write_cb_t *cb) {
  uint32_t bufs_len = Moonbit_array_length(bufs);
  uv_buf_t *bufs_val = auv__refs_to_bufs((uv_buf_t **)bufs->data, bufs_len);
  req->data = cb;
  return uv_write(req, handle, bufs_val, bufs_len, auv_write_cb);
}
