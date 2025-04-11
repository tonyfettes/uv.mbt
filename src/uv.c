#include "moonbit.h"
#include "uv#include#uv.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifdef DEBUG
#include <stdio.h>
#define moonbit_uv_trace(format, ...)                                          \
  fprintf(stdout, "%s: " format, __func__ __VA_OPT__(, ) __VA_ARGS__)
#else
#define moonbit_uv_trace(...)
#endif

#define containerof(ptr, type, member)                                         \
  ((type *)((char *)(ptr) - offsetof(type, member)))

uv_loop_t *
moonbit_uv_default_loop(void) {
  return uv_default_loop();
}

uv_loop_t *
moonbit_uv_loop_make(void) {
  uv_loop_t *loop = (uv_loop_t *)moonbit_make_bytes(sizeof(uv_loop_t), 0);
  memset(loop, 0, sizeof(uv_loop_t));
  return loop;
}

int
moonbit_uv_loop_init(uv_loop_t *loop) {
  int result = uv_loop_init(loop);
  moonbit_decref(loop);
  return result;
}

int
moonbit_uv_loop_close(uv_loop_t *loop) {
  int result = uv_loop_close(loop);
  moonbit_decref(loop);
  return result;
}

void
moonbit_uv_stop(uv_loop_t *loop) {
  uv_stop(loop);
  moonbit_decref(loop);
}

int
moonbit_uv_run(uv_loop_t *loop, uv_run_mode mode) {
  int rc = uv_run(loop, mode);
  moonbit_decref(loop);
  return rc;
}

int
moonbit_uv_loop_alive(uv_loop_t *loop) {
  int alive = uv_loop_alive(loop);
  moonbit_decref(loop);
  return alive;
}

typedef struct moonbit_uv_idle_cb {
  int32_t (*code)(struct moonbit_uv_idle_cb *, uv_idle_t *);
} moonbit_uv_idle_cb_t;

uv_idle_t *
moonbit_uv_idle_alloc(void) {
  return (uv_idle_t *)moonbit_make_bytes(sizeof(uv_idle_t), 0);
}

int
moonbit_uv_idle_init(uv_loop_t *loop, uv_idle_t *idle) {
  int rc = uv_idle_init(loop, idle);
  moonbit_decref(loop);
  moonbit_decref(idle);
  return rc;
}

void
moonbit_uv_idle_cb(uv_idle_t *idle) {
  moonbit_uv_idle_cb_t *cb = idle->data;
  moonbit_incref(cb);
  moonbit_incref(idle);
  cb->code(cb, idle);
}

int
moonbit_uv_idle_start(uv_idle_t *idle, moonbit_uv_idle_cb_t *cb) {
  idle->data = cb;
  int rc = uv_idle_start(idle, moonbit_uv_idle_cb);
  moonbit_decref(idle);
  return rc;
}

int
moonbit_uv_idle_stop(uv_idle_t *idle) {
  int rc = uv_idle_stop(idle);
  moonbit_decref(idle);
  return rc;
}

typedef struct moonbit_uv_buf_s {
  uv_buf_t buf;
} moonbit_uv_buf_t;

static inline void
moonbit_uv_buf_finalize(void *object) {
  moonbit_uv_buf_t *buf = object;
  if (buf->buf.base) {
    moonbit_decref((void *)buf->buf.base);
  }
}

moonbit_uv_buf_t *
moonbit_uv_buf_make(void) {
  moonbit_uv_buf_t *buf = (moonbit_uv_buf_t *)moonbit_make_external_object(
    moonbit_uv_buf_finalize, sizeof(uv_buf_t)
  );
  memset(&buf->buf, 0, sizeof(uv_buf_t));
  return buf;
}

void
moonbit_uv_buf_init(
  moonbit_uv_buf_t *buf,
  moonbit_bytes_t bytes,
  int32_t start_offset,
  uint32_t length
) {
  if (buf->buf.base) {
    moonbit_decref((void *)buf->buf.base);
  }
  buf->buf = uv_buf_init((char *)bytes + start_offset, length);
  moonbit_decref(buf);
}

void
moonbit_uv_buf_set_len(moonbit_uv_buf_t *buf, size_t len) {
  buf->buf.len = len;
  moonbit_decref(buf);
}

void
moonbit_uv_buf_set_base(moonbit_uv_buf_t *buf, moonbit_bytes_t bytes) {
  if (buf->buf.base) {
    moonbit_decref((void *)buf->buf.base);
  }
  buf->buf.base = (char *)bytes;
  moonbit_incref((void *)bytes);
  moonbit_decref(buf);
}

moonbit_bytes_t
moonbit_uv_buf_get_base(moonbit_uv_buf_t *buf) {
  moonbit_bytes_t bytes = (moonbit_bytes_t)buf->buf.base;
  moonbit_incref((void *)bytes);
  moonbit_decref(buf);
  return bytes;
}

typedef struct moonbit_uv_fs_s {
  uv_fs_t fs;
  moonbit_bytes_t *bufs_base;
} moonbit_uv_fs_t;

typedef struct moonbit_uv_fs_cb_s {
  int32_t (*code)(struct moonbit_uv_fs_cb_s *, moonbit_uv_fs_t *);
} moonbit_uv_fs_cb_t;

static inline void
moonbit_uv_fs_cb(uv_fs_t *req) {
  moonbit_uv_fs_t *fs = containerof(req, moonbit_uv_fs_t, fs);
  moonbit_uv_fs_cb_t *cb = fs->fs.data;
  fs->fs.data = NULL;
  cb->code(cb, fs);
}

static inline void
moonbit_uv_fs_finalize(void *object) {
  moonbit_uv_fs_t *fs = (moonbit_uv_fs_t *)object;
  if (fs->fs.data) {
    moonbit_decref(fs->fs.data);
  }
  if (fs->bufs_base) {
    moonbit_decref(fs->bufs_base);
  }
  uv_fs_req_cleanup(&fs->fs);
}

moonbit_uv_fs_t *
moonbit_uv_fs_make(void) {
  moonbit_uv_fs_t *fs = (moonbit_uv_fs_t *)moonbit_make_external_object(
    moonbit_uv_fs_finalize, sizeof(moonbit_uv_fs_t)
  );
  memset(&fs->fs, 0, sizeof(uv_fs_t));
  fs->bufs_base = NULL;
  return fs;
}

int64_t
moonbit_uv_fs_result(moonbit_uv_fs_t *fs) {
  ssize_t result = fs->fs.result;
  moonbit_decref(fs);
  return result;
}

static inline void
moonbit_uv_fs_set_data(moonbit_uv_fs_t *fs, moonbit_uv_fs_cb_t *cb) {
  if (fs->fs.data) {
    moonbit_decref(fs->fs.data);
  }
  fs->fs.data = cb;
}

static inline void
moonbit_uv_fs_set_bufs(moonbit_uv_fs_t *fs, moonbit_bytes_t *bufs_base) {
  if (fs->bufs_base) {
    moonbit_decref(fs->bufs_base);
  }
  fs->bufs_base = bufs_base;
}

int32_t
moonbit_uv_fs_O_RDONLY(void) {
  return UV_FS_O_RDONLY;
}

int32_t
moonbit_uv_fs_O_WRONLY(void) {
  return UV_FS_O_WRONLY;
}

int32_t
moonbit_uv_fs_O_RDWR(void) {
  return UV_FS_O_RDWR;
}

int
moonbit_uv_fs_open(
  uv_loop_t *loop,
  moonbit_uv_fs_t *fs,
  moonbit_bytes_t path,
  int flags,
  int mode,
  moonbit_uv_fs_cb_t *cb
) {
  moonbit_uv_fs_set_data(fs, cb);
  int result = uv_fs_open(
    loop, &fs->fs, (const char *)path, flags, mode, moonbit_uv_fs_cb
  );
  moonbit_decref(loop);
  moonbit_decref(path);
  return result;
}

int
moonbit_uv_fs_close(
  uv_loop_t *loop,
  moonbit_uv_fs_t *fs,
  uv_file file,
  moonbit_uv_fs_cb_t *cb
) {
  moonbit_uv_fs_set_data(fs, cb);
  int result = uv_fs_close(loop, &fs->fs, file, moonbit_uv_fs_cb);
  moonbit_decref(loop);
  return result;
}

int
moonbit_uv_fs_read(
  uv_loop_t *loop,
  moonbit_uv_fs_t *fs,
  uv_file file,
  moonbit_bytes_t *bufs_base,
  uint64_t *bufs_offset,
  uint32_t *bufs_length,
  int64_t offset,
  moonbit_uv_fs_cb_t *cb
) {
  int bufs_size = Moonbit_array_length(bufs_base);
  uv_buf_t *bufs = malloc(sizeof(uv_buf_t) * bufs_size);
  for (int i = 0; i < bufs_size; i++) {
    bufs[i] =
      uv_buf_init((char *)bufs_base[i] + bufs_offset[i], bufs_length[i]);
  }
  // The ownership of `cb` is transferred into `fs`.
  moonbit_uv_fs_set_data(fs, cb);
  // The ownership of `bufs_base` is transferred into `fs`.
  moonbit_uv_fs_set_bufs(fs, bufs_base);
  // The ownership of `fs` is transferred into `loop`.
  int result =
    uv_fs_read(loop, &fs->fs, file, bufs, bufs_size, offset, moonbit_uv_fs_cb);
  // Releasing `bufs` here, as it is only a box for the `bufs` array and should
  // not causing the bufs to be decref'ed.
  free(bufs);
  moonbit_decref(loop);
  moonbit_decref(bufs_offset);
  moonbit_decref(bufs_length);
  return result;
}

int
moonbit_uv_fs_write(
  uv_loop_t *loop,
  moonbit_uv_fs_t *fs,
  uv_file file,
  moonbit_bytes_t *bufs_base,
  uint64_t *bufs_offset,
  uint32_t *bufs_length,
  int64_t offset,
  moonbit_uv_fs_cb_t *cb
) {
  int bufs_size = Moonbit_array_length(bufs_base);
  uv_buf_t *bufs = malloc(sizeof(uv_buf_t) * bufs_size);
  for (int i = 0; i < bufs_size; i++) {
    bufs[i] =
      uv_buf_init((char *)bufs_base[i] + bufs_offset[i], bufs_length[i]);
  }
  moonbit_uv_fs_set_data(fs, cb);
  moonbit_uv_fs_set_bufs(fs, bufs_base);
  int result =
    uv_fs_write(loop, &fs->fs, file, bufs, bufs_size, offset, moonbit_uv_fs_cb);
  free(bufs);
  moonbit_decref(loop);
  moonbit_decref(bufs_offset);
  moonbit_decref(bufs_length);
  return result;
}

int
moonbit_uv_accept(uv_stream_t *server, uv_stream_t *client) {
  return uv_accept(server, client);
}

typedef struct moonbit_uv_connection_cb {
  int32_t (*code)(
    struct moonbit_uv_connection_cb *,
    uv_stream_t *server,
    int status
  );
} moonbit_uv_connection_cb_t;

void
moonbit_uv_listen_cb(uv_stream_t *server, int status) {
  moonbit_uv_connection_cb_t *cb = server->data;
  moonbit_incref(cb);
  cb->code(cb, server, status);
}

int
moonbit_uv_listen(
  uv_stream_t *stream,
  int backlog,
  moonbit_uv_connection_cb_t *cb
) {
  stream->data = cb;
  return uv_listen(stream, backlog, moonbit_uv_listen_cb);
}

typedef struct moonbit_uv_close_cb {
  int32_t (*code)(struct moonbit_uv_close_cb *, uv_handle_t *handle);
} moonbit_uv_close_cb_t;

static inline void
moonbit_uv_close_cb(uv_handle_t *handle) {
  moonbit_uv_close_cb_t *cb = handle->data;
  handle->data = NULL;
  // The cb will be only called once, so there is no need to incref here.
  cb->code(cb, handle);
}

void
moonbit_uv_close(uv_handle_t *handle, moonbit_uv_close_cb_t *close_cb) {
  handle->data = close_cb;
  uv_close(handle, moonbit_uv_close_cb);
}

int32_t
moonbit_uv_is_closing(uv_handle_t *handle) {
  int32_t is_closing = uv_is_closing(handle);
  return is_closing;
}

uv_loop_t *
moonbit_uv_handle_loop(uv_handle_t *handle) {
  uv_loop_t *loop = handle->loop;
  moonbit_decref(loop);
  return loop;
}

struct sockaddr_in *
moonbit_uv_sockaddr_in_make(void) {
  return (struct sockaddr_in *)moonbit_make_bytes(
    sizeof(struct sockaddr_in), 0
  );
}

void
moonbit_uv_ip4_addr(moonbit_bytes_t ip, int port, struct sockaddr_in *addr) {
  uv_ip4_addr((const char *)ip, port, addr);
  moonbit_decref(addr);
}

uv_tcp_t *
moonbit_uv_tcp_alloc(void) {
  return ((uv_tcp_t *)malloc(sizeof(uv_tcp_t)));
}

int
moonbit_uv_tcp_init(uv_loop_t *loop, uv_tcp_t *tcp) {
  int result = uv_tcp_init(loop, tcp);
  moonbit_decref(loop);
  return result;
}

int
moonbit_uv_tcp_bind(uv_tcp_t *tcp, struct sockaddr *addr, unsigned int flags) {
  int result = uv_tcp_bind(tcp, addr, flags);
  moonbit_decref(addr);
  return result;
}

uv_connect_t *
moonbit_uv_connect_alloc(void) {
  uv_connect_t *connect =
    (uv_connect_t *)moonbit_make_bytes(sizeof(uv_connect_t), 0);
  return connect;
}

typedef struct moonbit_uv_connect_cb_s {
  int32_t (*code)(
    struct moonbit_uv_connect_cb_s *,
    uv_connect_t *req,
    int status
  );
} moonbit_uv_connect_cb_t;

static inline void
moonbit_uv_connect_cb(uv_connect_t *req, int status) {
  moonbit_uv_connect_cb_t *cb = req->data;
  moonbit_incref(cb);
  cb->code(cb, req, status);
}

int
moonbit_uv_tcp_connect(
  uv_connect_t *connect,
  uv_tcp_t *tcp,
  struct sockaddr *addr,
  moonbit_uv_connection_cb_t *cb
) {
  connect->data = cb;
  int result = uv_tcp_connect(connect, tcp, addr, moonbit_uv_connect_cb);
  moonbit_decref(addr);
  return result;
}

typedef struct moonbit_uv_alloc_cb_s {
  moonbit_bytes_t (*code)(
    struct moonbit_uv_alloc_cb_s *,
    uv_handle_t *handle,
    size_t suggested_size,
    int32_t *buf_offset,
    int32_t *buf_length
  );
} moonbit_uv_alloc_cb_t;

typedef struct moonbit_uv_read_cb {
  int32_t (*code)(
    struct moonbit_uv_read_cb *,
    uv_stream_t *stream,
    ssize_t nread,
    moonbit_bytes_t buf,
    int32_t buf_offset,
    int32_t buf_length
  );
} moonbit_uv_read_cb_t;

typedef struct moonbit_uv_read_start_cb_s {
  moonbit_bytes_t bytes;
  moonbit_uv_alloc_cb_t *alloc_cb;
  moonbit_uv_read_cb_t *read_cb;
} moonbit_uv_read_start_cb_t;

static inline void
moonbit_uv_read_start_alloc_cb(
  uv_handle_t *handle,
  size_t suggested_size,
  uv_buf_t *buf
) {
  moonbit_uv_read_start_cb_t *read_start_cb = handle->data;
  moonbit_uv_alloc_cb_t *alloc_cb = read_start_cb->alloc_cb;
  moonbit_incref(alloc_cb);
  int32_t buf_offset = 0;
  int32_t buf_length = 0;
  moonbit_bytes_t buf_base =
    alloc_cb->code(alloc_cb, handle, suggested_size, &buf_offset, &buf_length);
  read_start_cb->bytes = buf_base;
  buf->base = (char *)buf_base + buf_offset;
  buf->len = buf_length;
}

static inline void
moonbit_uv_read_start_read_cb(
  uv_stream_t *stream,
  ssize_t nread,
  const uv_buf_t *buf
) {
  moonbit_uv_read_start_cb_t *read_start_cb = stream->data;
  moonbit_uv_read_cb_t *read_cb = read_start_cb->read_cb;
  moonbit_incref(read_cb);
  moonbit_bytes_t buf_base = read_start_cb->bytes;
  int32_t buf_offset = buf->base - (char *)read_start_cb->bytes;
  int32_t buf_length = buf->len;
  read_cb->code(read_cb, stream, nread, buf_base, buf_offset, buf_length);
}

int
moonbit_uv_read_start(
  uv_stream_t *stream,
  moonbit_uv_alloc_cb_t *alloc_cb,
  moonbit_uv_read_cb_t *read_cb
) {
  moonbit_uv_read_start_cb_t *cb = malloc(sizeof(moonbit_uv_read_start_cb_t));
  memset(cb, 0, sizeof(moonbit_uv_read_start_cb_t));
  cb->read_cb = read_cb;
  cb->alloc_cb = alloc_cb;
  stream->data = cb;
  return uv_read_start(
    stream, moonbit_uv_read_start_alloc_cb, moonbit_uv_read_start_read_cb
  );
}

int
moonbit_uv_read_stop(uv_stream_t *stream) {
  if (stream->data) {
    moonbit_uv_read_start_cb_t *cb = stream->data;
    // moonbit_decref(cb->bytes);
    moonbit_decref(cb->read_cb);
    moonbit_decref(cb->alloc_cb);
    free(cb);
    stream->data = NULL;
  }
  return uv_read_stop(stream);
}

typedef struct moonbit_uv_write_s {
  uv_write_t write;
  uv_buf_t *bufs_data;
  size_t bufs_size;
} moonbit_uv_write_t;

void
moonbit_uv_write_finalize(void *object) {
  moonbit_uv_write_t *write = object;
  if (write->write.data) {
    moonbit_decref(write->write.data);
  }
  if (write->bufs_data) {
    for (size_t i = 0; i < write->bufs_size; i++) {
      moonbit_decref(write->bufs_data[i].base);
    }
    free(write->bufs_data);
  }
}

moonbit_uv_write_t *
moonbit_uv_write_make(void) {
  moonbit_uv_write_t *write =
    (moonbit_uv_write_t *)moonbit_make_external_object(
      moonbit_uv_write_finalize, sizeof(moonbit_uv_write_t)
    );
  memset(&write->write, 0, sizeof(uv_write_t));
  write->bufs_data = NULL;
  write->bufs_size = 0;
  return write;
}

typedef struct moonbit_uv_write_cb {
  int32_t (*code)(
    struct moonbit_uv_write_cb *,
    moonbit_uv_write_t *req,
    int32_t status
  );
} moonbit_uv_write_cb_t;

static inline void
moonbit_uv_write_cb(uv_write_t *req, int status) {
  moonbit_uv_write_cb_t *moonbit_uv_cb = req->data;
  moonbit_uv_write_t *write = containerof(req, moonbit_uv_write_t, write);
  moonbit_uv_cb->code(moonbit_uv_cb, write, status);
}

static inline void
moonbit_uv_write_set_data(moonbit_uv_write_t *req, moonbit_uv_write_cb_t *cb) {
  if (req->write.data) {
    moonbit_decref(req->write.data);
  }
  req->write.data = cb;
}

static inline void
moonbit_uv_write_set_bufs(
  moonbit_uv_write_t *req,
  uv_buf_t *bufs_data,
  size_t bufs_size
) {
  if (req->bufs_data) {
    for (size_t i = 0; i < req->bufs_size; i++) {
      moonbit_decref(req->bufs_data[i].base);
    }
    free(req->bufs_data);
  }
  req->bufs_data = bufs_data;
  req->bufs_size = bufs_size;
}

int
moonbit_uv_write(
  moonbit_uv_write_t *req,
  uv_stream_t *handle,
  moonbit_bytes_t *bufs_base,
  int32_t *bufs_offset,
  int32_t *bufs_length,
  moonbit_uv_write_cb_t *cb
) {
  int bufs_size = Moonbit_array_length(bufs_base);
  uv_buf_t *bufs_data = malloc(sizeof(uv_buf_t) * bufs_size);
  for (int i = 0; i < bufs_size; i++) {
    bufs_data[i] =
      uv_buf_init((char *)bufs_base[i] + bufs_offset[i], bufs_length[i]);
  }
  moonbit_uv_write_set_data(req, cb);
  moonbit_uv_write_set_bufs(req, bufs_data, bufs_size);
  int result =
    uv_write(&req->write, handle, bufs_data, bufs_size, moonbit_uv_write_cb);
  moonbit_decref(handle);
  free(bufs_data);
  return result;
}

void
moonbit_uv_strerror_r(int err, moonbit_bytes_t bytes) {
  size_t bytes_len = Moonbit_array_length(bytes);
  char *bytes_ptr = (char *)bytes;
  uv_strerror_r(err, bytes_ptr, bytes_len);
  moonbit_decref(bytes);
}

typedef struct moonbit_uv_timer_cb {
  int32_t (*code)(struct moonbit_uv_timer_cb *, uv_timer_t *timer);
} moonbit_uv_timer_cb_t;

uv_timer_t *
moonbit_uv_timer_alloc(void) {
  return ((uv_timer_t *)malloc(sizeof(uv_timer_t)));
}

static inline void
moonbit_uv_timer_cb(uv_timer_t *timer) {
  moonbit_uv_timer_cb_t *cb = timer->data;
  moonbit_incref(cb);
  cb->code(cb, timer);
}

int
moonbit_uv_timer_start(
  uv_timer_t *handle,
  moonbit_uv_timer_cb_t *cb,
  uint64_t timeout,
  uint64_t repeat
) {
  handle->data = cb;
  return uv_timer_start(handle, moonbit_uv_timer_cb, timeout, repeat);
}

typedef struct moonbit_uv_process_s {
  uv_process_t process;
} moonbit_uv_process_t;

static inline void
moonbit_uv_process_finalize(void *object) {
  moonbit_uv_process_t *process = object;
  if (process->process.data) {
    moonbit_decref(process->process.data);
  }
}

moonbit_uv_process_t *
moonbit_uv_process_make(void) {
  moonbit_uv_process_t *process =
    (moonbit_uv_process_t *)moonbit_make_external_object(
      moonbit_uv_process_finalize, sizeof(moonbit_uv_process_t)
    );
  memset(process, 0, sizeof(moonbit_uv_process_t));
  return process;
}

int
moonbit_uv_process_get_pid(moonbit_uv_process_t *process) {
  int pid = process->process.pid;
  moonbit_decref(process);
  return pid;
}

typedef struct moonbit_uv_exit_cb_s {
  int32_t (*code)(
    struct moonbit_uv_exit_cb_s *,
    moonbit_uv_process_t *,
    int64_t,
    int
  );
} moonbit_uv_exit_cb_t;

static inline void
moonbit_uv_exit_cb(
  uv_process_t *process,
  int64_t exit_status,
  int term_signal
) {
  moonbit_uv_process_t *moonbit_process =
    containerof(process, moonbit_uv_process_t, process);
  if (process->data) {
    moonbit_uv_exit_cb_t *cb = process->data;
    process->data = NULL;
    cb->code(cb, moonbit_process, exit_status, term_signal);
  } else {
    moonbit_decref(moonbit_process);
  }
}

uv_stdio_container_t *
moonbit_uv_stdio_container_ignore(void) {
  uv_stdio_container_t *container =
    (uv_stdio_container_t *)moonbit_make_bytes(sizeof(uv_stdio_container_t), 0);
  container->flags = UV_IGNORE;
  return container;
}

uv_stdio_container_t *
moonbit_uv_stdio_container_create_pipe(
  uv_stream_t *stream,
  bool readable,
  bool writable,
  bool non_block
) {
  uv_stdio_container_t *container =
    (uv_stdio_container_t *)moonbit_make_bytes(sizeof(uv_stdio_container_t), 0);
  container->flags = UV_CREATE_PIPE;
  if (readable) {
    container->flags |= UV_READABLE_PIPE;
  }
  if (writable) {
    container->flags |= UV_WRITABLE_PIPE;
  }
  if (non_block) {
    container->flags |= UV_NONBLOCK_PIPE;
  }
  container->data.stream = stream;
  return container;
}

uv_stdio_container_t *
moonbit_uv_stdio_container_inherit_fd(int fd) {
  uv_stdio_container_t *container =
    (uv_stdio_container_t *)moonbit_make_bytes(sizeof(uv_stdio_container_t), 0);
  container->flags = UV_INHERIT_FD;
  container->data.fd = fd;
  return container;
}

uv_stdio_container_t *
moonbit_uv_stdio_container_inherit_stream(uv_stream_t *stream) {
  uv_stdio_container_t *container =
    (uv_stdio_container_t *)moonbit_make_bytes(sizeof(uv_stdio_container_t), 0);
  container->flags = UV_INHERIT_STREAM;
  container->data.stream = stream;
  return container;
}

typedef struct moonbit_uv_process_options_s {
  uv_process_options_t options;
} moonbit_uv_process_options_t;

static inline void
moonbit_uv_process_options_finalize(void *object) {
  moonbit_uv_process_options_t *options =
    (moonbit_uv_process_options_t *)object;
  if (options->options.exit_cb) {
    moonbit_decref((moonbit_uv_exit_cb_t *)options->options.exit_cb);
  }
  if (options->options.file) {
    moonbit_decref((void *)options->options.file);
  }
  if (options->options.args) {
    moonbit_decref(options->options.args);
  }
  if (options->options.env) {
    moonbit_decref(options->options.env);
  }
  if (options->options.cwd) {
    moonbit_decref((void *)options->options.cwd);
  }
  if (options->options.stdio) {
    free(options->options.stdio);
  }
}

moonbit_uv_process_options_t *
moonbit_uv_process_options_make(void) {
  moonbit_uv_process_options_t *options =
    (moonbit_uv_process_options_t *)moonbit_make_external_object(
      moonbit_uv_process_options_finalize, sizeof(moonbit_uv_process_options_t)
    );
  memset(options, 0, sizeof(moonbit_uv_process_options_t));
  return options;
}

void
moonbit_uv_process_options_set_exit_cb(
  moonbit_uv_process_options_t *options,
  moonbit_uv_exit_cb_t *exit_cb
) {
  if (options->options.exit_cb) {
    moonbit_decref((moonbit_uv_exit_cb_t *)options->options.exit_cb);
  }
  options->options.exit_cb = (uv_exit_cb)exit_cb;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_file(
  moonbit_uv_process_options_t *options,
  moonbit_bytes_t file
) {
  if (options->options.file) {
    moonbit_decref((void *)options->options.file);
  }
  options->options.file = (const char *)file;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_args(
  moonbit_uv_process_options_t *options,
  moonbit_bytes_t *args
) {
  if (options->options.args) {
    moonbit_decref(options->options.args);
  }
  options->options.args = (char **)args;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_env(
  moonbit_uv_process_options_t *options,
  moonbit_bytes_t *env
) {
  if (options->options.env) {
    moonbit_decref(options->options.env);
  }
  options->options.env = (char **)env;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_cwd(
  moonbit_uv_process_options_t *options,
  moonbit_bytes_t cwd
) {
  if (options->options.cwd) {
    moonbit_decref((void *)options->options.cwd);
  }
  options->options.cwd = (const char *)cwd;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_flags(
  moonbit_uv_process_options_t *options,
  unsigned int flags
) {
  options->options.flags = flags;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_stdio(
  moonbit_uv_process_options_t *options,
  uv_stdio_container_t **stdio
) {
  if (options->options.stdio) {
    free(options->options.stdio);
  }
  options->options.stdio_count = Moonbit_array_length(stdio);
  moonbit_uv_trace("stdio_count = %d\n", options->options.stdio_count);
  options->options.stdio =
    malloc(sizeof(uv_stdio_container_t) * (size_t)options->options.stdio_count);
  for (int i = 0; i < options->options.stdio_count; i++) {
    options->options.stdio[i] = *stdio[i];
  }
  moonbit_decref(stdio);
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_uid(
  moonbit_uv_process_options_t *options,
  uv_uid_t uid
) {
  options->options.uid = uid;
  moonbit_decref(options);
}

void
moonbit_uv_process_options_set_gid(
  moonbit_uv_process_options_t *options,
  uv_gid_t gid
) {
  options->options.gid = gid;
  moonbit_decref(options);
}

int
moonbit_uv_spawn(
  uv_loop_t *loop,
  moonbit_uv_process_t *process,
  moonbit_uv_process_options_t *options
) {
  if (options->options.exit_cb) {
    if (process->process.data) {
      moonbit_decref((moonbit_uv_exit_cb_t *)process->process.data);
    }
    process->process.data = (void *)options->options.exit_cb;
  }
  options->options.exit_cb = moonbit_uv_exit_cb;
  int result = uv_spawn(loop, &process->process, &options->options);
  // The ownership of `options` is transferred into `loop`.
  // We need to set the exit_cb to NULL so it doesn't get decref'd.
  options->options.exit_cb = NULL;
  moonbit_decref(loop);
  moonbit_decref(options);
  // moonbit_uv_trace("spawn: %d\n", Moonbit_object_header(options)->rc);
  return result;
}

uv_tty_t *
moonbit_uv_tty_make(void) {
  uv_tty_t *tty = (uv_tty_t *)moonbit_make_bytes(sizeof(uv_tty_t), 0);
  memset(tty, 0, sizeof(uv_tty_t));
  return tty;
}

int
moonbit_uv_tty_init(uv_loop_t *loop, uv_tty_t *handle, uv_file fd) {
  int result = uv_tty_init(loop, handle, fd, 0);
  moonbit_decref(loop);
  moonbit_decref(handle);
  return result;
}

int
moonbit_uv_tty_set_mode(uv_tty_t *handle, uv_tty_mode_t mode) {
  int result = uv_tty_set_mode(handle, mode);
  moonbit_decref(handle);
  return result;
}

uv_pipe_t *
moonbit_uv_pipe_make(void) {
  uv_pipe_t *pipe = (uv_pipe_t *)moonbit_make_bytes(sizeof(uv_pipe_t), 0);
  memset(pipe, 0, sizeof(uv_pipe_t));
  return pipe;
}

int32_t
moonbit_uv_pipe_init(uv_loop_t *loop, uv_pipe_t *handle, int32_t ipc) {
  int result = uv_pipe_init(loop, handle, ipc);
  moonbit_decref(loop);
  moonbit_decref(handle);
  return result;
}

int32_t
moonbit_uv_pipe_open(uv_pipe_t *handle, uv_file fd) {
  int result = uv_pipe_open(handle, fd);
  moonbit_decref(handle);
  return result;
}

int32_t
moonbit_uv_pipe_bind(uv_pipe_t *handle, moonbit_bytes_t name, uint32_t flags) {
  size_t name_length = Moonbit_array_length(name);
  int result = uv_pipe_bind2(handle, (const char *)name, name_length, flags);
  moonbit_decref(name);
  return result;
}

int32_t
moonbit_uv_pipe(int32_t *fds, int32_t read_flags, int32_t write_flags) {
  return uv_pipe(fds, read_flags, write_flags);
}

#define XX(code, _)                                                            \
  int32_t uv_##code(void) { return UV_##code; }
UV_ERRNO_MAP(XX)
#undef XX
