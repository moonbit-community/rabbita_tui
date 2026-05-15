#include <errno.h>
#include <spawn.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include <moonbit.h>

extern char **environ;

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
  ssize_t written;
  do {
    written = write(fd, bytes + offset, (size_t)len);
  } while (written < 0 && errno == EINTR);
  if (written < 0) {
    return -1;
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
int32_t moonbit_tui_exec_process(moonbit_bytes_t command_bytes,
                                  int32_t command_offset, int32_t command_len,
                                  moonbit_bytes_t args_bytes,
                                  int32_t args_offset, int32_t args_len,
                                  int32_t argc) {
  if (command_len <= 0 || args_len < 0 || argc < 0) {
    return -1;
  }
  char *command = (char *)malloc((size_t)command_len + 1);
  if (command == NULL) {
    return -1;
  }
  memcpy(command, command_bytes + command_offset, (size_t)command_len);
  command[command_len] = '\0';

  char **argv = (char **)calloc((size_t)argc + 2, sizeof(char *));
  if (argv == NULL) {
    free(command);
    return -1;
  }
  argv[0] = command;
  int32_t cursor = 0;
  for (int32_t index = 0; index < argc; index++) {
    int32_t start = cursor;
    while (cursor < args_len && args_bytes[args_offset + cursor] != '\0') {
      cursor++;
    }
    int32_t len = cursor - start;
    char *arg = (char *)malloc((size_t)len + 1);
    if (arg == NULL) {
      for (int32_t cleanup = 1; cleanup < index + 1; cleanup++) {
        free(argv[cleanup]);
      }
      free(argv);
      free(command);
      return -1;
    }
    memcpy(arg, args_bytes + args_offset + start, (size_t)len);
    arg[len] = '\0';
    argv[index + 1] = arg;
    if (cursor < args_len) {
      cursor++;
    }
  }

  pid_t pid;
  int spawn_status = posix_spawnp(&pid, command, NULL, NULL, argv, environ);
  if (spawn_status != 0) {
    for (int32_t index = 1; index <= argc; index++) {
      free(argv[index]);
    }
    free(argv);
    free(command);
    return spawn_status == ENOENT ? 127 : -1;
  }

  int status = 0;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) {
      for (int32_t index = 1; index <= argc; index++) {
        free(argv[index]);
      }
      free(argv);
      free(command);
      return -1;
    }
  }
  for (int32_t index = 1; index <= argc; index++) {
    free(argv[index]);
  }
  free(argv);
  free(command);
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
