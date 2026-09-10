#ifndef __dbg_h__
#define __dbg_h__

#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "AppLog.h"
#include "Log.h"

#define SUCCESS 0

#define clean_errno() (errno == 0 ? "None" : strerror(errno))

// not using _DEBUG here to avoid flood
// #define DEBUG 1
#ifdef DEBUG

#define debug(L, M, ...) (L)->add(LogTypes_Info, "DEBUG %s:%d: " M, \
                                  __FILE__, __LINE__, ##__VA_ARGS__)

#else

#define debug(L, M, ...)

#endif

#ifdef _DEBUG

#define log_err(L, M, ...) (L)->add(LogTypes_Error,                              \
                                    "(%s:%d: errno: %s) " M, __FILE__, __LINE__, \
                                    clean_errno(), ##__VA_ARGS__)

#define log_warn(L, M, ...) (L)->add(LogTypes_Warning,        \
                                     "(%s:%d: errno: %s) " M, \
                                     __FILE__, __LINE__, clean_errno(), ##__VA_ARGS__)

#define log_info(L, M, ...) (L)->add(LogTypes_Info, \
                                     "(%s:%d) " M,  \
                                     __FILE__, __LINE__, ##__VA_ARGS__)

#else

#define log_err(L, M, ...) (L)->add(LogTypes_Error, M, ##__VA_ARGS__)

#define log_warn(L, M, ...) (L)->add(LogTypes_Warning, M, ##__VA_ARGS__)

#define log_info(L, M, ...) (L)->add(LogTypes_Info, "(%s:%d) " M, ##__VA_ARGS__)

#endif

// #define debug(L, M, ...) fprintf(stderr, "DEBUG %s:%d: " M "\n", \
//                               __FILE__, __LINE__, ##__VA_ARGS__)

// #define log_err(L, M, ...) fprintf(stderr,                                                   \
//                                 "[ERROR] (%s:%d: errno: %s) " M "\n", __FILE__, __LINE__, \
//                                 clean_errno(), ##__VA_ARGS__)

// #define log_warn(L, M, ...) fprintf(stderr,                              \
//                                  "[WARN] (%s:%d: errno: %s) " M "\n", \
//                                  __FILE__, __LINE__, clean_errno(), ##__VA_ARGS__)

// #define log_info(L, M, ...) fprintf(stderr, "[INFO] (%s:%d) " M "\n", \
//                                  __FILE__, __LINE__, ##__VA_ARGS__)

#define check(L, A, M, ...)         \
  if (!(A))                         \
  {                                 \
    if (L)                          \
      log_err(L, M, ##__VA_ARGS__); \
    errno = 0;                      \
    goto error;                     \
  }

#define sentinel(L, M, ...)         \
  {                                 \
    if (L)                          \
      log_err(L, M, ##__VA_ARGS__); \
    errno = 0;                      \
    goto error;                     \
  }

#define check_mem(L, A) check((L), (A), "Out of memory.")

// #define check_debug(A, M, ...)  \
//   if (!(A))                     \
//   {                             \
//     debug(L, M, ##__VA_ARGS__); \
//     errno = 0;                  \
//     goto error;                 \
//   }

#endif
