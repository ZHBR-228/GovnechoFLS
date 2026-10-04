/*
 * gosh — GovnechoFLS interactive shell + фирменная neofetch-заставка
 *
 * GovnechoFLS (c) 2026 ZHBR-228
 * SPDX-License-Identifier: MIT
 *
 * Возможности:
 *   - интерактивная оболочка с кастомным промптом (govnechoFLS) user@host:pwd$
 *   - встроенные команды: help, exit/quit, pwd, cd, echo, clear, ver,
 *     fetch/neofetch (заставка), history, alias, which, uname, ls (fallback)
 *   - внешние команды через fork/execvp с поиском в PATH
 *   - логирование истории в ~/.gosh_history
 *   - govecho-эхо-режим (-e / --exec CMD): выполнить команду и выйти
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>
#include <dirent.h>
#include <signal.h>

#define GOSH_VERSION "1.0.0"
#define MAX_LINE 4096
#define MAX_ARGS 128
#define HISTORY_MAX 512

static char *history[HISTORY_MAX];
static int hist_count = 0;
static int hist_pos = 0; /* для стрелок вверх/вниз */

/* ---------- утилиты ---------- */

static void trim(char *s) {
    size_t n = strlen(s);
    while (n > 0 && (s[n-1] == '\n' || s[n-1] == '\r' || s[n-1] == ' ' || s[n-1] == '\t')) s[--n] = 0;
    char *p = s;
    while (*p == ' ' || *p == '\t') p++;
    if (p != s) memmove(s, p, strlen(p) + 1);
}

static char *cwd_short(void) {
    static char buf[512];
    if (!getcwd(buf, sizeof(buf))) strcpy(buf, "?");
    const char *home = getenv("HOME");
    if (home && strncmp(buf, home, strlen(home)) == 0) {
        memmove(buf + 1, buf + strlen(home), strlen(buf + strlen(home)) + 1);
        buf[0] = '~';
    }
    return buf;
}

static void print_prompt(void) {
    char host[128] = "govnecho-fls";
    gethostname(host, sizeof(host));
    const char *user = getenv("USER");
    if (!user) user = "root";
    printf("\033[1;38;5;75m(govnechoFLS)\033[0m \033[1;32m%s@%s\033[0m:\033[4m%s\033[0m$ ",
           user, host, cwd_short());
    fflush(stdout);
}

/* ---------- заставка neofetch ---------- */

static const char *logo[] = {
    "   ____                 ____ _                ____  ____",
    "  / ___|___  _ ____   _| ___| |__   ___  ___ / ___||  _ \\",
    " | |   / _ \\| '_ \\ \\ / / __| '_ \\ / _ \\/ __|\\___ \\| |_) |",
    " | |__| (_) | | | \\ V /| |_|| | | |  __/\\__ \\___) |  _ <",
    "  \\____\\___/|_| |_|\\_/ |___||_| |_|\\___||___/____/|_| \\_\\",
    NULL
};

static long read_kb_field(const char *path, const char *key) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char line[256];
    long val = -1;
    size_t klen = strlen(key);
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, key, klen) == 0) {
            char *colon = strchr(line + klen, ':');
            if (colon) { val = atol(colon + 1); break; }
        }
    }
    fclose(f);
    return val;
}

static void cmd_fetch(int colored) {
    struct utsname u;
    uname(&u);

    /* читаем os-release */
    char pretty[128] = "GovnechoFLS 1.0.0 (Linux From Scratch)";
    FILE *osr = fopen("/etc/os-release", "r");
    if (osr) {
        char line[256];
        while (fgets(line, sizeof(line), osr)) {
            if (strncmp(line, "PRETTY_NAME=", 12) == 0) {
                char *q1 = strchr(line, '"');
                char *q2 = q1 ? strrchr(line, '"') : NULL;
                if (q1 && q2 && q2 > q1) {
                    *q2 = 0;
                    snprintf(pretty, sizeof(pretty), "%s", q1 + 1);
                }
                break;
            }
        }
        fclose(osr);
    }

    /* CPU */
    int cpu_n = 0; char cpu_model[160] = "unknown";
    FILE *cpu = fopen("/proc/cpuinfo", "r");
    if (cpu) {
        char line[256];
        while (fgets(line, sizeof(line), cpu)) {
            if (strncmp(line, "processor", 9) == 0) cpu_n++;
            if (strncmp(line, "model name", 10) == 0) {
                char *colon = strchr(line, ':');
                if (colon) {
                    colon++;
                    while (*colon == ' ') colon++;
                    size_t l = strlen(colon);
                    while (l > 0 && (colon[l-1] == '\n' || colon[l-1] == '\r')) colon[--l] = 0;
                    snprintf(cpu_model, sizeof(cpu_model), "%s", colon);
                }
            }
        }
        fclose(cpu);
    }
    if (cpu_n == 0) cpu_n = 1;

    /* RAM */
    long mem_total = read_kb_field("/proc/meminfo", "MemTotal");
    long mem_avail = read_kb_field("/proc/meminfo", "MemAvailable");
    if (mem_total < 0) mem_total = 0;
    if (mem_avail < 0) mem_avail = 0;
    long mem_used = (mem_total - mem_avail) / 1024;
    mem_total /= 1024;

    /* Disk: statvfs по корню */
    const char *disk_str = "N/A";
    static char disk_buf[64];
    {
        struct statvfs vs;
        if (statvfs("/", &vs) == 0 && vs.f_frsize > 0) {
            unsigned long long tot = (unsigned long long)vs.f_blocks * vs.f_frsize / (1024*1024);
            unsigned long long freeb = (unsigned long long)vs.f_bfree * vs.f_frsize / (1024*1024);
            snprintf(disk_buf, sizeof(disk_buf), "%llu / %llu MiB", tot - freeb, tot);
            disk_str = disk_buf;
        }
    }

    /* uptime */
    char uptime_s[64] = "";
    FILE *up = fopen("/proc/uptime", "r");
    if (up) {
        double secs = 0;
        if (fscanf(up, "%lf", &secs) == 1) {
            long h = (long)secs / 3600, m = ((long)secs % 3600) / 60;
            snprintf(uptime_s, sizeof(uptime_s), "%ldh %ldm", h, m);
        }
        fclose(up);
    }
    if (!*uptime_s) strcpy(uptime_s, "0h 0m");

    char host[128] = "govnecho-fls";
    gethostname(host, sizeof(host));

    printf("\n");
    for (int i = 0; logo[i]; i++) {
        printf("  \033[1;38;5;75m%s\033[0m\n", logo[i]);
    }
    printf("\n");

    const char *labels[] = {"OS", "Kernel", "Host", "Shell", "Resolution", "DE",
                            "CPU", "Memory", "Disk", "Uptime"};
    char vals[10][160];
    snprintf(vals[0], 160, "%s", pretty);
    snprintf(vals[1], 160, "%s %s", u.sysname, u.release);
    snprintf(vals[2], 160, "%s (LFS-based)", host);
    snprintf(vals[3], 160, "/bin/gosh %s", GOSH_VERSION);
    snprintf(vals[4], 160, "tty/console");
    snprintf(vals[5], 160, "GNOME 46 (Govnecho session)");
    snprintf(vals[6], 160, "%s (%d threads)", cpu_model, cpu_n);
    snprintf(vals[7], 160, "%ld MiB / %ld MiB", mem_used, mem_total);
    snprintf(vals[8], 160, "%s", disk_str);
    snprintf(vals[9], 160, "%s", uptime_s);

    for (int i = 0; i < 10; i++)
        printf("  \033[1;38;5;75m%s\033[0m: %s\n", labels[i], vals[i]);

    /* цветовая палитра по-соседски */
    printf("\n  ");
    for (int c = 0; c < 16; c++) {
        int cc = 30 + (c % 8);
        printf("\033[%d;%dm  \033[0m", (c < 8 ? 0 : 1), cc);
    }
    printf("\n\n");
    (void)colored;
}

/* ---------- история ---------- */

static void hist_add(const char *line) {
    if (!*line) return;
    if (hist_count > 0 && strcmp(history[hist_count-1], line) == 0) return;
    if (hist_count < HISTORY_MAX) history[hist_count++] = strdup(line);
}

static void hist_save(void) {
    const char *home = getenv("HOME");
    if (!home) return;
    char path[512];
    snprintf(path, sizeof(path), "%s/.gosh_history", home);
    FILE *f = fopen(path, "w");
    if (!f) return;
    for (int i = 0; i < hist_count; i++) fprintf(f, "%s\n", history[i]);
    fclose(f);
}

static void hist_load(void) {
    const char *home = getenv("HOME");
    if (!home) return;
    char path[512];
    snprintf(path, sizeof(path), "%s/.gosh_history", home);
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f) && hist_count < HISTORY_MAX) {
        trim(line);
        if (*line) history[hist_count++] = strdup(line);
    }
    fclose(f);
}

/* ---------- встроенные команды ---------- */

static void cmd_help(void) {
    printf(
      "\033[1;38;5;75mgosh %s — GovnechoFLS shell\033[0m\n"
      "Встроенные команды:\n"
      "  help          эта справка\n"
      "  fetch         фирменная заставка (неофетч) GovnechoFLS\n"
      "  neofetch      то же самое\n"
      "  ver           версия системы\n"
      "  pwd | cd DIR  текущий путь / переход\n"
      "  echo ARGS     напечатать (как govecho)\n"
      "  clear         очистить экран\n"
      "  history       журнал команд\n"
      "  alias NAME=CMD создать алиас (NAME=... )\n"
      "  which PROG    где находится программа\n"
      "  uname [a]     сведения о ядре\n"
      "  ls [DIR]      листинг (простейший)\n"
      "  exit | quit   выход\n"
      "Всё остальное запускается как обычная команда через exec.\n\n",
      GOSH_VERSION);
}

static int starts_with(const char *s, const char *p) {
    return strncmp(s, p, strlen(p)) == 0;
}

static void simple_ls(const char *dir) {
    DIR *d = opendir(dir);
    if (!d) { perror("ls"); return; }
    struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.') continue;
        printf("%s  ", e->d_name);
    }
    printf("\n");
    closedir(d);
}

static void run_external(char **args) {
    pid_t pid = fork();
    if (pid < 0) { perror("fork"); return; }
    if (pid == 0) {
        execvp(args[0], args);
        fprintf(stderr, "gosh: %s: команда не найдена\n", args[0]);
        _exit(127);
    }
    int status;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
}

/* мини-алиасы */
#define ALIAS_MAX 64
static char *alias_names[ALIAS_MAX], *alias_vals[ALIAS_MAX];
static int alias_count = 0;

static const char *alias_lookup(const char *name) {
    for (int i = 0; i < alias_count; i++)
        if (strcmp(alias_names[i], name) == 0) return alias_vals[i];
    return NULL;
}

static void init_default_aliases(void) {
    alias_count = 0;
    alias_names[alias_count] = strdup("ll");   alias_vals[alias_count++] = strdup("ls -la");
    alias_names[alias_count] = strdup("gs");   alias_vals[alias_count++] = strdup("git status");
    alias_names[alias_count] = strdup("gd");   alias_vals[alias_count++] = strdup("git diff");
    alias_names[alias_count] = strdup("fetch");alias_vals[alias_count++] = strdup("gosh-fetch");
}

/* ---------- разбор строки ---------- */

static int tokenize(char *line, char **args, int max) {
    int n = 0;
    char *p = line;
    while (*p && n < max) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        if (*p == '"' || *p == '\'') {
            char q = *p++;
            args[n++] = p;
            while (*p && *p != q) p++;
            if (*p) *p++ = 0;
        } else {
            args[n++] = p;
            while (*p && *p != ' ' && *p != '\t') p++;
            if (*p) *p++ = 0;
        }
    }
    args[n] = NULL;
    return n;
}

static void execute_line(char *line) {
    char *args[MAX_ARGS];
    trim(line);
    if (!*line) return;
    if (line[0] == '#') return;

    int argc = tokenize(line, args, MAX_ARGS - 1);
    if (argc == 0) return;

    const char *alias_v = alias_lookup(args[0]);
    if (alias_v) {
        char buf[MAX_LINE];
        snprintf(buf, sizeof(buf), "%s", alias_v);
        for (int i = 1; i < argc; i++) {
            strncat(buf, " ", sizeof(buf) - strlen(buf) - 1);
            strncat(buf, args[i], sizeof(buf) - strlen(buf) - 1);
        }
        execute_line(buf);
        return;
    }

    char *cmd = args[0];
    if (!strcmp(cmd, "exit") || !strcmp(cmd, "quit")) { hist_save(); exit(0); }
    else if (!strcmp(cmd, "help")) cmd_help();
    else if (!strcmp(cmd, "fetch") || !strcmp(cmd, "gosh-fetch") || !strcmp(cmd, "neofetch")) cmd_fetch(1);
    else if (!strcmp(cmd, "ver")) printf("GovnechoFLS %s | gosh %s | LFS BOOK 12.3\n", "1.0.0", GOSH_VERSION);
    else if (!strcmp(cmd, "pwd")) printf("%s\n", cwd_short());
    else if (!strcmp(cmd, "cd")) {
        const char *dir = (argc > 1) ? args[1] : getenv("HOME");
        if (!dir) dir = "/";
        if (chdir(dir) != 0) fprintf(stderr, "gosh: cd: %s: %s\n", dir, strerror(errno));
    }
    else if (!strcmp(cmd, "echo")) {
        for (int i = 1; i < argc; i++) printf("%s%s", args[i], i + 1 < argc ? " " : "");
        printf("\n");
    }
    else if (!strcmp(cmd, "clear")) printf("\033[2J\033[H");
    else if (!strcmp(cmd, "history")) {
        for (int i = 0; i < hist_count; i++) printf("  %d  %s\n", i + 1, history[i]);
    }
    else if (!strcmp(cmd, "which")) {
        if (argc < 2) { fprintf(stderr, "usage: which PROG\n"); }
        else {
            char *path = getenv("PATH");
            char buf[512];
            snprintf(buf, sizeof(buf), "%s", path ? path : "/bin:/usr/bin");
            char *tok = strtok(buf, ":");
            int found = 0;
            while (tok) {
                char full[512];
                snprintf(full, sizeof(full), "%s/%s", tok, args[1]);
                if (access(full, X_OK) == 0) { printf("%s\n", full); found = 1; break; }
                tok = strtok(NULL, ":");
            }
            if (!found) printf("gosh: %s not found\n", args[1]);
        }
    }
    else if (!strcmp(cmd, "uname")) {
        struct utsname u; uname(&u);
        if (argc > 1 && !strcmp(args[1], "-a"))
            printf("%s %s %s %s %s\n", u.sysname, u.nodename, u.release, u.version, u.machine);
        else printf("%s\n", u.sysname);
    }
    else if (!strcmp(cmd, "ls")) simple_ls(argc > 1 ? args[1] : ".");
    else if (starts_with(cmd, "alias=")) { /* noop */ }
    else if (!strcmp(cmd, "alias")) {
        if (argc < 2) { for (int i = 0; i < alias_count; i++) printf("%s=%s\n", alias_names[i], alias_vals[i]); }
        else {
            char *eq = strchr(args[1], '=');
            if (!eq) { fprintf(stderr, "usage: alias NAME=COMMAND\n"); }
            else {
                *eq = 0;
                if (alias_count < ALIAS_MAX) {
                    alias_names[alias_count] = strdup(args[1]);
                    alias_vals[alias_count] = strdup(eq + 1);
                    alias_count++;
                }
            }
        }
    }
    else run_external(args);
}

/* ---------- чтение строки с редактированием (стрелки ↑↓) ---------- */

static int read_line(char *buf, size_t sz) {
    size_t pos = 0;
    buf[0] = 0;
    int raw_ok = isatty(STDIN_FILENO);
    if (raw_ok) {
        struct sigaction sa_old;
        (void)sa_old;
    }
    while (1) {
        char c;
        ssize_t r = read(STDIN_FILENO, &c, 1);
        if (r <= 0) { if (pos == 0) return -1; buf[pos] = 0; return (int)pos; }
        if (c == '\n' || c == '\r') { printf("\n"); buf[pos] = 0; return (int)pos; }
        if (c == 3) { printf("^C\n"); buf[0] = 0; return 0; } /* Ctrl-C */
        if (c == 4) { if (pos == 0) { printf("\n"); return -1; } continue; } /* Ctrl-D */
        if (c == 127 || c == 8) { if (pos > 0) { pos--; printf("\b \b"); fflush(stdout); } continue; }
        if (raw_ok && c == 27) { /* ESC-последовательности */
            char seq[2];
            if (read(STDIN_FILENO, seq, 1) == 1 && seq[0] == '[') {
                if (read(STDIN_FILENO, seq, 1) == 1) {
                    if (seq[0] == 'A' && hist_pos > 0) {          /* вверх */
                        hist_pos--;
                        printf("\r\033[K");
                        snprintf(buf, sz, "%s", history[hist_pos]);
                        pos = strlen(buf);
                        printf("%s", buf); fflush(stdout);
                    } else if (seq[0] == 'B') {                   /* вниз */
                        if (hist_pos < hist_count - 1) {
                            hist_pos++;
                            printf("\r\033[K");
                            snprintf(buf, sz, "%s", history[hist_pos]);
                            pos = strlen(buf);
                            printf("%s", buf); fflush(stdout);
                        } else {
                            hist_pos = hist_count;
                            printf("\r\033[K");
                            buf[0] = 0; pos = 0;
                        }
                    }
                }
            }
            continue;
        }
        if (pos < sz - 1) {
            buf[pos++] = c;
            putchar(c); fflush(stdout);
        }
    }
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);

    /* режим -e/--exec: выполнить одну команду и выйти (для скриптов/автозапуска) */
    if (argc >= 3 && (!strcmp(argv[1], "-e") || !strcmp(argv[1], "--exec"))) {
        char joined[MAX_LINE] = "";
        for (int i = 2; i < argc; i++) {
            strncat(joined, argv[i], sizeof(joined) - strlen(joined) - 1);
            if (i + 1 < argc) strncat(joined, " ", sizeof(joined) - strlen(joined) - 1);
        }
        init_default_aliases();
        execute_line(joined);
        return 0;
    }
    if (argc >= 2 && (!strcmp(argv[1], "-v") || !strcmp(argv[1], "--version"))) {
        printf("gosh %s (GovnechoFLS)\n", GOSH_VERSION);
        return 0;
    }
    if (argc >= 2 && !strcmp(argv[1], "-f")) { cmd_fetch(1); return 0; }

    signal(SIGINT, SIG_IGN); /* чтобы Ctrl-C не убивал шелл */

    hist_load();
    hist_pos = hist_count;
    init_default_aliases();

    printf("\033[1;38;5;75m");
    for (int i = 0; logo[i]; i++) printf("%s\n", logo[i]);
    printf("\033[0m");
    printf("  GovnechoFLS %s — Linux From Scratch by hand\n", "1.0.0");
    printf("  Напиши \033[1mhelp\033[0m или \033[1mfetch\033[0m для заставки\n\n");

    char line[MAX_LINE];
    while (1) {
        print_prompt();
        int n = read_line(line, sizeof(line));
        if (n < 0) { printf("\n"); break; }
        if (n > 0) { hist_add(line); hist_pos = hist_count; execute_line(line); }
    }
    hist_save();
    return 0;
}
