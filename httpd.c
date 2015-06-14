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
#define MAX_BACKLOG 10

// TODO: get rid of all entries for phr_parse_request except for buf, len, and last_len
struct cs_io {
  struct ev_io io;
  char buf[4096];
  size_t len, last_len;
  int recv_count;
  char response[8192];
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
}

static void cs_w_cb(EV_P_ struct ev_io *w, int revents) {
  struct cs_io *cs_w = (struct cs_io *)w;
  ssize_t sret;

  sret = send(w->fd, cs_w->response + cs_w->response_last_len, cs_w->response_len - cs_w->response_last_len, 0);
  if (sret < 0) {
    perror("send");
    exit(EXIT_FAILURE);
  }
  cs_w->response_last_len += sret;
  if (cs_w->response_len == cs_w->response_last_len) {
    ev_io_stop(EV_A_ w);
    if (close(w->fd) < 0) {
      perror("close");
      exit(EXIT_FAILURE);
    }
    free(w);
  }
  /*
  printf("request is %d bytes long\n", pret);
  printf("method is %.*s\n", (int)method_len, method);
  printf("path is %.*s\n", (int)path_len, path);
  printf("HTTP version is 1.%d\n", minor_version);
  printf("headers:\n");
  for (i = 0; i != num_headers; ++i) {
      printf("%.*s: %.*s\n", (int)headers[i].name_len, headers[i].name,
             (int)headers[i].value_len, headers[i].value);
  }
  */
}

// Process events from clients
static void cs_r_cb(EV_P_ struct ev_io *w, int revents) {
  const char *method, *path;
  int minor_version;
  struct phr_header headers[100];
  size_t method_len, path_len, num_headers;
  struct cs_io *cs_w = (struct cs_io *)w;
  int pret;
  ssize_t rret;

  // while (1) {
  /* read the request */
  rret = recv(w->fd, cs_w->buf + cs_w->len, sizeof cs_w->buf - cs_w->len, MSG_DONTWAIT);
  if (rret < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) return;
    perror("read");
    exit(EXIT_FAILURE);
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
    int cs = w->fd;
    /* successfully parsed the request */
    cs_w->len = pret;
    setup_response(cs_w);
    // printf("response was setup: %d\n", cs_w->response_len);
    ev_io_stop(EV_A_ w);
    ev_io_init(w, cs_w_cb, cs, EV_WRITE);
    ev_io_start(EV_A_ w);
  } else {
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
  }
  if (cs_w->recv_count++ >= 500) {
    fputs("watcher should have stopped!\n", stderr);
    fflush(stderr);
    ev_io_stop(EV_A_ w);
    // exit(EXIT_FAILURE);
  }
  // }
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
  cs_w->len = 0;
  cs_w->recv_count = 0;
  ev_io_init(&cs_w->io, cs_r_cb, cs, EV_READ);
  ev_io_start(EV_A_ &cs_w->io);
}

int main() {
  /*
  struct cs_io *cs_w = malloc(sizeof(struct cs_io));
  ssize_t rret, pret;
  char buf[4096];
  printf("%d\n", sizeof(struct cs_io));
  cs_w->len = 0;
  rret = read(0, cs_w->buf + cs_w->len, sizeof cs_w->buf - cs_w->len);
  if (rret <= 0) {
    perror("read");
    exit(EXIT_FAILURE);
  }
  memcpy(buf, cs_w->buf, rret);
  buf[rret] = '\0';
  printf("request(%d): %s\n", rret, buf);
  cs_w->len += rret;
  cs_w->num_headers = sizeof cs_w->headers / sizeof cs_w->headers[0];
  pret = phr_parse_request(
    cs_w->buf,
    cs_w->len,
    &cs_w->method,
    &cs_w->method_len,
    &cs_w->path,
    &cs_w->path_len,
    &cs_w->minor_version,
    cs_w->headers,
    &cs_w->num_headers,
    cs_w->last_len
  );
  */
  /*
  struct cs_io *cs_w = malloc(sizeof(struct cs_io));
  printf("%d, %d, %d, %d\n", sizeof cs_w->buf, sizeof cs_w->headers, sizeof cs_w->headers[0], sizeof cs_w->headers / sizeof cs_w->headers[0]);
  */
  /*
  struct cs_io cs_w;
  cs_w.len = 38;
  memcpy(cs_w.buf, "Hello, world! Good-bye, good night : )", cs_w.len);
  setup_response(&cs_w);
  cs_w.response[cs_w.response_len] = '\0';
  printf("response(%d): %s\n", cs_w.response_len, cs_w.response);
  */
  struct ev_loop *loop;
  ev_io ss_watcher;
  int ss;
  ss = setup_ss();
  loop = ev_default_loop(0);
  ev_io_init(&ss_watcher, ss_cb, ss, EV_READ);
  ev_io_start(loop, &ss_watcher);
  ev_loop(loop, 0);
  if (close(ss) < 0) die("close");
  return 0;
}
