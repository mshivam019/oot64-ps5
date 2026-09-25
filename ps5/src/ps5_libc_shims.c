// Ship of Harkinian PS5: libc symbols that libc++ (locale/filesystem) and SoH reference
// but the native title's libc does not export. The title only ever runs in the "C"
// locale, so every *_l variant forwards to its plain counterpart.

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <strings.h>
#include <unistd.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <wchar.h>
#include <wctype.h>
#include <limits.h>
#include <locale.h>
#include <xlocale.h>
#include <runetype.h>
#include <sys/stat.h>

typedef locale_t ps5_locale_t;

extern const _RuneLocale _DefaultRuneLocale;

// ---- locale objects --------------------------------------------------------
static int ps5_c_locale;

ps5_locale_t newlocale(int mask, const char* name, ps5_locale_t base) {
    (void)mask;
    (void)name;
    (void)base;
    return &ps5_c_locale;
}

int freelocale(ps5_locale_t loc) {
    (void)loc;
    return 0;
}

struct lconv* localeconv_l(ps5_locale_t loc) {
    (void)loc;
    return localeconv();
}

int ___mb_cur_max_l(ps5_locale_t loc) {
    (void)loc;
    return 1;
}

// ---- ctype -----------------------------------------------------------------
_RuneLocale* __runes_for_locale(ps5_locale_t loc, int* mb_sb_limit) {
    (void)loc;
    if (mb_sb_limit != NULL) {
        *mb_sb_limit = _CACHED_RUNES;
    }
    return (_RuneLocale*)&_DefaultRuneLocale;
}

const _RuneLocale* __getCurrentRuneLocale(void) {
    return &_DefaultRuneLocale;
}

unsigned long ___runetype(__ct_rune_t c) {
    return (c >= 0 && c < _CACHED_RUNES) ? _DefaultRuneLocale.__runetype[c] : 0;
}

unsigned long ___runetype_l(int c, ps5_locale_t loc) {
    (void)loc;
    return (c >= 0 && c < _CACHED_RUNES) ? _DefaultRuneLocale.__runetype[c] : 0;
}

int ___tolower_l(int c, ps5_locale_t loc) {
    (void)loc;
    return (c >= 0 && c < _CACHED_RUNES) ? _DefaultRuneLocale.__maplower[c] : c;
}

int ___toupper_l(int c, ps5_locale_t loc) {
    (void)loc;
    return (c >= 0 && c < _CACHED_RUNES) ? _DefaultRuneLocale.__mapupper[c] : c;
}

int iswctype_l(wint_t wc, wctype_t desc, ps5_locale_t loc) {
    (void)loc;
    return iswctype(wc, desc);
}

// ---- strings / numbers -----------------------------------------------------
int strcoll_l(const char* a, const char* b, ps5_locale_t loc) {
    (void)loc;
    return strcoll(a, b);
}

size_t strxfrm_l(char* dst, const char* src, size_t n, ps5_locale_t loc) {
    (void)loc;
    return strxfrm(dst, src, n);
}

int wcscoll_l(const wchar_t* a, const wchar_t* b, ps5_locale_t loc) {
    (void)loc;
    return wcscoll(a, b);
}

size_t wcsxfrm_l(wchar_t* dst, const wchar_t* src, size_t n, ps5_locale_t loc) {
    (void)loc;
    return wcsxfrm(dst, src, n);
}

double strtod_l(const char* s, char** end, ps5_locale_t loc) {
    (void)loc;
    return strtod(s, end);
}

float strtof_l(const char* s, char** end, ps5_locale_t loc) {
    (void)loc;
    return strtof(s, end);
}

long double strtold_l(const char* s, char** end, ps5_locale_t loc) {
    (void)loc;
    return strtold(s, end);
}

long long strtoll_l(const char* s, char** end, int base, ps5_locale_t loc) {
    (void)loc;
    return strtoll(s, end, base);
}

unsigned long long strtoull_l(const char* s, char** end, int base, ps5_locale_t loc) {
    (void)loc;
    return strtoull(s, end, base);
}

size_t strftime_l(char* s, size_t max, const char* fmt, const struct tm* tm, ps5_locale_t loc) {
    (void)loc;
    return strftime(s, max, fmt, tm);
}

int snprintf_l(char* s, size_t n, ps5_locale_t loc, const char* fmt, ...) {
    (void)loc;
    va_list ap;
    va_start(ap, fmt);
    int r = vsnprintf(s, n, fmt, ap);
    va_end(ap);
    return r;
}

int asprintf_l(char** ret, ps5_locale_t loc, const char* fmt, ...) {
    (void)loc;
    va_list ap;
    va_start(ap, fmt);
    int r = vasprintf(ret, fmt, ap);
    va_end(ap);
    return r;
}

int sscanf_l(const char* s, ps5_locale_t loc, const char* fmt, ...) {
    (void)loc;
    va_list ap;
    va_start(ap, fmt);
    int r = vsscanf(s, fmt, ap);
    va_end(ap);
    return r;
}

// ---- multibyte -------------------------------------------------------------
wint_t btowc_l(int c, ps5_locale_t loc) {
    (void)loc;
    return btowc(c);
}

int wctob_l(wint_t c, ps5_locale_t loc) {
    (void)loc;
    return wctob(c);
}

size_t mbrlen_l(const char* s, size_t n, mbstate_t* ps, ps5_locale_t loc) {
    (void)loc;
    return mbrlen(s, n, ps);
}

size_t mbrtowc_l(wchar_t* pwc, const char* s, size_t n, mbstate_t* ps, ps5_locale_t loc) {
    (void)loc;
    return mbrtowc(pwc, s, n, ps);
}

int mbtowc_l(wchar_t* pwc, const char* s, size_t n, ps5_locale_t loc) {
    (void)loc;
    return mbtowc(pwc, s, n);
}

size_t wcrtomb_l(char* s, wchar_t wc, mbstate_t* ps, ps5_locale_t loc) {
    (void)loc;
    return wcrtomb(s, wc, ps);
}

size_t mbsrtowcs_l(wchar_t* dst, const char** src, size_t len, mbstate_t* ps, ps5_locale_t loc) {
    (void)loc;
    return mbsrtowcs(dst, src, len, ps);
}

size_t mbsnrtowcs(wchar_t* dst, const char** src, size_t nms, size_t len, mbstate_t* ps) {
    static mbstate_t internal;
    const char* s = *src;
    size_t count = 0;
    if (ps == NULL) {
        ps = &internal;
    }
    while (nms > 0 && (dst == NULL || count < len)) {
        wchar_t wc;
        size_t r = mbrtowc(&wc, s, nms, ps);
        if (r == (size_t)-1) {
            if (dst != NULL) {
                *src = s;
            }
            return (size_t)-1;
        }
        if (r == (size_t)-2) {
            s += nms;
            break;
        }
        if (dst != NULL) {
            dst[count] = wc;
        }
        if (r == 0) {
            if (dst != NULL) {
                *src = NULL;
            }
            return count;
        }
        s += r;
        nms -= r;
        count++;
    }
    if (dst != NULL) {
        *src = s;
    }
    return count;
}

size_t mbsnrtowcs_l(wchar_t* dst, const char** src, size_t nms, size_t len, mbstate_t* ps,
                    ps5_locale_t loc) {
    (void)loc;
    return mbsnrtowcs(dst, src, nms, len, ps);
}

size_t wcsnrtombs(char* dst, const wchar_t** src, size_t nwc, size_t len, mbstate_t* ps) {
    static mbstate_t internal;
    const wchar_t* s = *src;
    size_t count = 0;
    char buf[MB_LEN_MAX];
    if (ps == NULL) {
        ps = &internal;
    }
    while (nwc > 0) {
        size_t r = wcrtomb(buf, *s, ps);
        if (r == (size_t)-1) {
            if (dst != NULL) {
                *src = s;
            }
            return (size_t)-1;
        }
        if (dst != NULL) {
            if (count + r > len) {
                break;
            }
            memcpy(dst + count, buf, r);
        }
        if (*s == L'\0') {
            if (dst != NULL) {
                *src = NULL;
            }
            return count + r - 1;
        }
        count += r;
        s++;
        nwc--;
    }
    if (dst != NULL) {
        *src = s;
    }
    return count;
}

size_t wcsnrtombs_l(char* dst, const wchar_t** src, size_t nwc, size_t len, mbstate_t* ps,
                    ps5_locale_t loc) {
    (void)loc;
    return wcsnrtombs(dst, src, nwc, len, ps);
}

// ---- time ------------------------------------------------------------------
struct tm* gmtime_r(const time_t* t, struct tm* out) {
    struct tm* r = gmtime(t);
    if (r == NULL) {
        return NULL;
    }
    *out = *r;
    return out;
}

struct tm* localtime_r(const time_t* t, struct tm* out) {
    struct tm* r = localtime(t);
    if (r == NULL) {
        return NULL;
    }
    *out = *r;
    return out;
}

// ---- unsupported on the title's libc ---------------------------------------
typedef void* ps5_nl_catd;

ps5_nl_catd catopen(const char* name, int flag) {
    (void)name;
    (void)flag;
    errno = ENOENT;
    return (ps5_nl_catd)-1;
}

char* catgets(ps5_nl_catd cat, int set, int msg, const char* fallback) {
    (void)cat;
    (void)set;
    (void)msg;
    return (char*)fallback;
}

int catclose(ps5_nl_catd cat) {
    (void)cat;
    return 0;
}

int dladdr(const void* addr, void* info) {
    (void)addr;
    (void)info;
    return 0;
}

int utimensat(int fd, const char* path, const struct timespec times[2], int flag) {
    (void)fd;
    (void)path;
    (void)times;
    (void)flag;
    errno = ENOSYS;
    return -1;
}

// ---- C++ thread_local destructors (libc++abi) ------------------------------
// Runs registered destructors when the thread exits, in reverse order.
typedef struct ps5_tls_dtor {
    void (*dtor)(void*);
    void* obj;
    struct ps5_tls_dtor* next;
} ps5_tls_dtor;

static pthread_key_t ps5_tls_dtor_key;
static pthread_once_t ps5_tls_dtor_once = PTHREAD_ONCE_INIT;

static void ps5_tls_dtor_run(void* head) {
    ps5_tls_dtor* node = (ps5_tls_dtor*)head;
    while (node != NULL) {
        ps5_tls_dtor* next = node->next;
        node->dtor(node->obj);
        free(node);
        node = next;
    }
}

static void ps5_tls_dtor_init(void) {
    pthread_key_create(&ps5_tls_dtor_key, ps5_tls_dtor_run);
}

int __cxa_thread_atexit_impl(void (*dtor)(void*), void* obj, void* dso) {
    (void)dso;
    pthread_once(&ps5_tls_dtor_once, ps5_tls_dtor_init);
    ps5_tls_dtor* node = (ps5_tls_dtor*)malloc(sizeof(*node));
    if (node == NULL) {
        return -1;
    }
    node->dtor = dtor;
    node->obj = obj;
    node->next = (ps5_tls_dtor*)pthread_getspecific(ps5_tls_dtor_key);
    pthread_setspecific(ps5_tls_dtor_key, node);
    return 0;
}

// ---- getcwd -----------------------------------------------------------------
// The libSceLibcInternal stub lists getcwd, but on FW 9.00 the import resolves to an
// unmapped address. libultraship chdir()s into the data folder at start-up, so report it.
char* getcwd(char* buf, size_t size) {
    const char* cwd = access("/app0/UserData", W_OK) == 0 ? "/app0/UserData" : "/download0";
    size_t len = strlen(cwd) + 1;
    if (buf == NULL) {
        buf = (char*)malloc(size > len ? size : len);
        if (buf == NULL) {
            errno = ENOMEM;
            return NULL;
        }
    } else if (size < len) {
        errno = ERANGE;
        return NULL;
    }
    memcpy(buf, cwd, len);
    return buf;
}

// ---- POSIX functions only exported by libScePosixForWebKit -----------------
// That module is not loaded for game titles, so its imports would resolve to null.
int isatty(int fd) {
    (void)fd;
    errno = ENOTTY;
    return 0;
}

uint32_t arc4random(void) {
    static uint64_t state;
    if (state == 0) {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        state = ((uint64_t)ts.tv_sec << 32) ^ (uint64_t)ts.tv_nsec ^ (uint64_t)(uintptr_t)&ts;
        state |= 1;
    }
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return (uint32_t)(state >> 16);
}

int mkstemp(char* path) {
    static const char chars[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    size_t len = strlen(path);
    if (len < 6 || strcmp(path + len - 6, "XXXXXX") != 0) {
        errno = EINVAL;
        return -1;
    }
    for (int attempt = 0; attempt < 100; attempt++) {
        for (size_t i = len - 6; i < len; i++) {
            path[i] = chars[arc4random() % (sizeof(chars) - 1)];
        }
        int fd = open(path, O_RDWR | O_CREAT | O_EXCL, 0600);
        if (fd >= 0 || errno != EEXIST) {
            return fd;
        }
    }
    errno = EEXIST;
    return -1;
}

char* strcasestr(const char* haystack, const char* needle) {
    size_t n = strlen(needle);
    if (n == 0) {
        return (char*)haystack;
    }
    for (; *haystack != '\0'; haystack++) {
        if (strncasecmp(haystack, needle, n) == 0) {
            return (char*)haystack;
        }
    }
    return NULL;
}

// SoH's in-game ROM extractor never runs on PS5 (pre-built .o2r files are shipped).
int zapd_report(int argc, char** argv, void* extractCount, void* totalExtract) {
    (void)argc;
    (void)argv;
    (void)extractCount;
    (void)totalExtract;
    return 0;
}
