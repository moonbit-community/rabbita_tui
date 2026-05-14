#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include <moonbit.h>

static struct termios saved_termios;
static int saved_fd = -1;
static volatile sig_atomic_t resize_pending = 0;

static void handle_winch(int signo) {
  (void)signo;
  resize_pending = 1;
}

static int32_t env_dimension(const char *name) {
  const char *value = getenv(name);
  if (value == NULL || *value == '\0') {
    return -1;
  }
  char *end = NULL;
  errno = 0;
  long parsed = strtol(value, &end, 10);
  if (errno != 0 || end == value || parsed <= 0 || parsed > INT32_MAX) {
    return -1;
  }
  return (int32_t)parsed;
}

static int32_t terminal_dimension(int32_t fd, int want_width) {
  struct winsize ws;
  if (ioctl(fd, TIOCGWINSZ, &ws) == 0) {
    uint16_t value = want_width ? ws.ws_col : ws.ws_row;
    if (value > 0) {
      return (int32_t)value;
    }
  }
  return env_dimension(want_width ? "COLUMNS" : "LINES");
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_is_tty(int32_t fd) {
  return isatty(fd) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_enable_raw(int32_t fd) {
  struct termios raw;
  if (tcgetattr(fd, &saved_termios) < 0) {
    return -1;
  }
  raw = saved_termios;
  raw.c_iflag &= (tcflag_t)~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
  raw.c_oflag &= (tcflag_t)~(OPOST);
  raw.c_cflag |= (CS8);
  raw.c_lflag &= (tcflag_t)~(ECHO | ICANON | IEXTEN | ISIG);
  raw.c_cc[VMIN] = 0;
  raw.c_cc[VTIME] = 1;
  if (tcsetattr(fd, TCSAFLUSH, &raw) < 0) {
    return -1;
  }
  saved_fd = fd;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_restore(int32_t fd) {
  if (saved_fd < 0) {
    return 0;
  }
  return tcsetattr(fd, TCSAFLUSH, &saved_termios);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_width(int32_t fd) {
  return terminal_dimension(fd, 1);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_height(int32_t fd) {
  return terminal_dimension(fd, 0);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_write(int32_t fd, moonbit_bytes_t bytes, int32_t offset,
                          int32_t len) {
  if (len <= 0) {
    return 0;
  }
  ssize_t written = write(fd, bytes + offset, (size_t)len);
  if (written < 0) {
    return errno == EINTR ? 0 : -1;
  }
  return (int32_t)written;
}

MOONBIT_FFI_EXPORT
void moonbit_tui_install_resize_handler(void) {
  struct sigaction action;
  memset(&action, 0, sizeof(action));
  action.sa_handler = handle_winch;
  sigemptyset(&action.sa_mask);
  sigaction(SIGWINCH, &action, NULL);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_system(moonbit_bytes_t bytes, int32_t offset, int32_t len) {
  if (len < 0) {
    return -1;
  }
  char *command = (char *)malloc((size_t)len + 1);
  if (command == NULL) {
    return -1;
  }
  memcpy(command, bytes + offset, (size_t)len);
  command[len] = '\0';
  int status = system(command);
  free(command);
  if (status == -1) {
    return -1;
  }
  if (WIFEXITED(status)) {
    return (int32_t)WEXITSTATUS(status);
  }
  if (WIFSIGNALED(status)) {
    return 128 + (int32_t)WTERMSIG(status);
  }
  return status;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_tui_take_resize_pending(void) {
  int32_t pending = resize_pending ? 1 : 0;
  resize_pending = 0;
  return pending;
}
