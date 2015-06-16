#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

#include <ev.h>

#include "../Gauche-picohttpparser/picohttpparser/picohttpparser.h"

#define SERVER_PORT 4567
#define MAX_BACKLOG 128

struct cs_io {
  struct ev_io io;
  char buf[4096];
  size_t len, last_len;
  int recv_count;
  char response[4096];
  size_t response_len, response_last_len;
};

void die(const char* msg) {
  perror(msg);
  exit(EXIT_FAILURE);
}

void setnonblocking(int s) {
  fcntl(s, F_SETFL, fcntl(s, F_GETFL, 0) | O_NONBLOCK);
}

// Setup server socket
int setup_ss() {
  struct sockaddr_in sin;
  int ss, yes = 1;
  ss = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
  if (ss < 0) die("socket");
  setsockopt(ss, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
  memset(&sin, 0, sizeof sin);
  sin.sin_family = AF_INET;
  sin.sin_addr.s_addr = htonl(INADDR_ANY);
  sin.sin_port = htons(SERVER_PORT);
  if (bind(ss, (struct sockaddr *) &sin, sizeof sin) < 0) {
    perror("bind");
    if (close(ss) < 0) perror("close");
    exit(EXIT_FAILURE);
  }
  if (listen(ss, MAX_BACKLOG) < 0) {
    perror("listen");
    if (close(ss) < 0) perror("close");
    exit(EXIT_FAILURE);
  }
  return ss;
}

// Just echo back the request header for now
static void setup_response(struct cs_io *cs_w) {
  static const char response_header[] =
    "HTTP/1.1 200 OK\r\n"
    "Connection: close\r\n"
    "Date: 1234567890123456789012345 GMT\r\n"
    "Content-Type: text/plain\r\n"
    "Content-Length: "
    ;
  time_t t;
  struct tm *gmt;

  t = time(NULL);
  gmt = gmtime(&t);
  memcpy(cs_w->response, response_header, sizeof response_header);
  // "Fri, 05 Jun 2015 12:26:01 GMT" <- length = 26 bytes
  strftime(cs_w->response + 42, 26, "%a, %d %b %Y %H:%M:%S", gmt);
  // override the null inserted by strftime
  cs_w->response[67] = ' ';
  // -1 is for null termination
  cs_w->response_len = sizeof response_header - 1 + sprintf(cs_w->response + sizeof response_header - 1, "%4d\r\n\r\n", cs_w->len) + cs_w->len;
  memcpy(cs_w->response + cs_w->response_len - cs_w->len, cs_w->buf, cs_w->len);
  cs_w->response_last_len = 0;
  assert(cs_w->response_len < 4096);
}

// returns 1 if finished sending, 0 otherwise
static int write_response(struct cs_io *cs_w) {
  ssize_t sret;

  sret = send(cs_w->io.fd, cs_w->response + cs_w->response_last_len, cs_w->response_len - cs_w->response_last_len, 0);
  if (sret < 0) {
    perror("send");
    if (close(cs_w->io.fd) < 0) {
      perror("close");
    }
    exit(EXIT_FAILURE);
  }
  cs_w->response_last_len += sret;
  if (cs_w->response_len == cs_w->response_last_len) {
    if (close(cs_w->io.fd) < 0) {
      perror("close");
      exit(EXIT_FAILURE);
    }
    free(cs_w);
    return 1;
  }
  return 0;
}

static void cs_w_cb(EV_P_ struct ev_io *w, int revents) {
  if (write_response((struct cs_io *)w)) ev_io_stop(EV_A_ w);
}

static void init_write(EV_P_ struct cs_io *cs_w) {
  if (!write_response(cs_w)) {
    int cs = cs_w->io.fd;
    ev_io_init(&cs_w->io, cs_w_cb, cs, EV_WRITE);
    ev_io_start(EV_A_ &cs_w->io);
  }
}

// returns 1 on successful parsing, 0 on parsing incomplete, -1 on connection close
static int read_request(struct cs_io *cs_w) {
  const char *method, *path;
  int minor_version;
  struct phr_header headers[100];
  size_t method_len, path_len, num_headers;
  int pret;
  ssize_t rret;

  /* read the request */
  rret = recv(cs_w->io.fd, cs_w->buf + cs_w->len, sizeof cs_w->buf - cs_w->len, MSG_DONTWAIT);
  if (rret < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
    perror("recv");
    exit(EXIT_FAILURE);
  }
  if (rret == 0) {
    fprintf(stderr, "connection closed by peer, len = %d\n", sizeof cs_w->buf - cs_w->len);
    fflush(stderr);
    return -1;
  }
  cs_w->last_len = cs_w->len;
  cs_w->len += rret;
  num_headers = sizeof headers / sizeof headers[0];
  /* parse the request */
  pret = phr_parse_request(
    cs_w->buf,
    cs_w->len,
    &method,
    &method_len,
    &path,
    &path_len,
    &minor_version,
    headers,
    &num_headers,
    cs_w->last_len
  );
  // puts("finished parsing");
  if (pret > 0) {
    /* successfully parsed the request */
    cs_w->len = pret;
    setup_response(cs_w);
    // printf("response was setup: %d\n", cs_w->response_len);
    return 1;
  }
  if (pret == -1) {
    puts("parse error");
    exit(EXIT_FAILURE);
  }
  /* request is incomplete, continue the loop */
  assert(pret == -2);
  if (cs_w->len == sizeof cs_w->buf) {
    puts("request is too long");
    exit(EXIT_FAILURE);
  }
  return 0;
}

// Process events from clients
static void cs_r_cb(EV_P_ struct ev_io *w, int revents) {
  switch (read_request((struct cs_io *)w)) {
    case 0:
      if (((struct cs_io *)w)->recv_count++ >= 500) {
        fputs("watcher should have been stopped!\n", stderr);
        fflush(stderr);
        ev_io_stop(EV_A_ w);
      }
      break;
    case 1:
      ev_io_stop(EV_A_ w);
      init_write(EV_A_ (struct cs_io *)w);
      break;
    default:
      ev_io_stop(EV_A_ w);
      break;
  }
}

static void init_read(EV_P_ struct cs_io *cs_w) {
  int cs;
  switch (read_request(cs_w)) {
    case 0:
      cs = cs_w->io.fd;
      ev_io_init(&cs_w->io, cs_r_cb, cs, EV_READ);
      ev_io_start(EV_A_ &cs_w->io);
      break;
    case 1:
      init_write(EV_A_ cs_w);
      break;
    default:
      fputs("first read was null\n", stderr);
      fflush(stderr);
      break;
  }
}

// Process connection requests to the server
static void ss_cb(EV_P_ struct ev_io *w, int revents) {
  struct sockaddr_in cs_addr;
  socklen_t cs_addr_len = sizeof cs_addr;
  struct cs_io *cs_w;
  int cs;

  cs = accept4(w->fd, (struct sockaddr *)&cs_addr, &cs_addr_len, SOCK_NONBLOCK);
  if (cs < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) return;
    die("accept");
  }
  printf("%d\n", cs_addr.sin_port);
  fflush(stdout);
  // puts("accepted!");
  cs_w = malloc(sizeof(struct cs_io));
  if (!cs_w) {
    puts("out of memory");
    exit(EXIT_FAILURE);
  }
  cs_w->len = 0;
  cs_w->recv_count = 0;
  cs_w->io.fd = cs;
  init_read(EV_A_ cs_w);
}

int main() {
  struct ev_loop *loop;
  ev_io ss_watcher;
  int ss;
  ss = setup_ss();
  loop = ev_default_loop(EVBACKEND_EPOLL);
  ev_io_init(&ss_watcher, ss_cb, ss, EV_READ);
  ev_io_start(loop, &ss_watcher);
  ev_loop(loop, 0);
  if (close(ss) < 0) die("close");
  return 0;
}
