/*ckwg +5
 * Copyright 2011-2013 by Kitware, Inc. All Rights Reserved. Please refer to
 * KITWARE_LICENSE.TXT for licensing information, or contact General Counsel,
 * Kitware, Inc., 28 Corporate Drive, Clifton Park, NY 12065.
 */

#include "utils.h"

#ifdef HAVE_PTHREAD_NAMING
#define NAME_THREAD_USING_PTHREAD
#ifdef HAVE_PTHREAD_SET_NAME_NP
#ifdef NDEBUG
// The mechanism only make sense in debugging mode.
#undef NAME_THREAD_USING_PTHREAD
#endif
#endif
#endif

#ifdef HAVE_SETPROCTITLE
#define NAME_THREAD_USING_SETPROCTITLE
#endif

#ifdef __linux__
#define NAME_THREAD_USING_PRCTL
#endif

#if defined(_WIN32) || defined(_WIN64)
#ifndef NDEBUG
// The mechanism only make sense in debugging mode.
#define NAME_THREAD_USING_WIN32
#endif
#endif

#ifdef NAME_THREAD_USING_PTHREAD
#include <errno.h>
#include <pthread.h>
#ifdef HAVE_PTHREAD_SET_NAME_NP
#include <pthread_np.h>
#endif
#endif

#ifdef NAME_THREAD_USING_PRCTL
#include <sys/prctl.h>
#endif

#if defined(_WIN32) || defined(_WIN64)
#include <boost/scoped_array.hpp>

#include <windows.h>
#else
#include <cstdlib>
#endif

/**
 * \file utils.cxx
 *
 * \brief Implementation of pipeline utilities.
 */

namespace sprokit
{

#ifdef NAME_THREAD_USING_PRCTL
static bool name_thread_prctl(thread_name_t const& name);
#endif

#ifdef NAME_THREAD_USING_SETPROCTITLE
static bool name_thread_setproctitle(thread_name_t const& name);
#endif

#ifdef NAME_THREAD_USING_PTHREAD
static bool name_thread_pthread(thread_name_t const& name);
#endif

#ifdef NAME_THREAD_USING_WIN32
static bool name_thread_win32(thread_name_t const& name);
#endif

bool
name_thread(thread_name_t const& name)
{
  bool ret = false;

#ifdef NAME_THREAD_USING_PRCTL
  if (!ret)
  {
    ret = name_thread_prctl(name);
  }
#endif

#ifdef NAME_THREAD_USING_SETPROCTITLE
  if (!ret)
  {
    ret = name_thread_setproctitle(name);
  }
#endif

#ifdef NAME_THREAD_USING_PTHREAD
  if (!ret)
  {
    ret = name_thread_pthread(name);
  }
#endif

#ifdef NAME_THREAD_USING_WIN32
  if (!ret)
  {
    ret = name_thread_win32(name);
  }
#endif

  return ret;
}

envvar_value_t
get_envvar(envvar_name_t const& name)
{
  envvar_value_t value;

#if defined(_WIN32) || defined(_WIN64)
  char const* const name_cstr = name.c_str();

  DWORD sz = GetEnvironmentVariable(name_cstr, NULL, 0);

  if (sz)
  {
    typedef boost::scoped_array<char> raw_envvar_value_t;
    raw_envvar_value_t const envvalue(new char[sz]);

    sz = GetEnvironmentVariable(name_cstr, envvalue.get(), sz);

    value = envvalue.get();
  }

  if (!sz)
  {
    /// \todo Log error that the environment reading failed.
  }
#else
  char const* const envvalue = getenv(name.c_str());

  if (envvalue)
  {
    value = envvalue;
  }
#endif

  return value;
}

#ifdef NAME_THREAD_USING_PRCTL
bool
name_thread_prctl(thread_name_t const& name)
{
  int const ret = prctl(PR_SET_NAME, reinterpret_cast<unsigned long>(name.c_str()), 0, 0, 0);

  return (ret == 0);
}
#endif

#ifdef NAME_THREAD_USING_SETPROCTITLE
bool
name_thread_setproctitle(thread_name_t const& name)
{
  setproctitle("%s", name.c_str());
}
#endif

#ifdef NAME_THREAD_USING_PTHREAD
bool
name_thread_pthread(thread_name_t const& name)
{
  int ret = -ENOTSUP;

#ifdef HAVE_PTHREAD_SETNAME_NP
#ifdef PTHREAD_SETNAME_NP_TAKES_ID
  pthread_t const tid = pthread_self();

  ret = pthread_setname_np(tid, name.c_str());
#else
  ret = pthread_setname_np(name.c_str());
#endif
#elif defined(HAVE_PTHREAD_SET_NAME_NP)
  pthread_t const tid = pthread_self();

  ret = pthread_set_name_np(tid, name.c_str());
#endif

  return (ret == 0);
}
#endif

#ifdef NAME_THREAD_USING_WIN32
static void set_thread_name(DWORD thread_id, LPCSTR name);

bool
name_thread_win32(thread_name_t const& name)
{
  static DWORD const current_thread = -1;

  set_thread_name(current_thread, name.c_str());

  return true;
}

// Code obtained from http://msdn.microsoft.com/en-us/library/xcb2z8hs.aspx
#pragma pack(push,8)
typedef struct tagTHREADNAME_INFO
{
   DWORD dwType;     // Must be 0x1000.
   LPCSTR szName;    // Pointer to name (in user addr space).
   DWORD dwThreadID; // Thread ID (-1 = caller thread).
   DWORD dwFlags;    // Reserved for future use, must be zero.
} THREADNAME_INFO;
#pragma pack(pop)

void
set_thread_name(DWORD thread_id, LPCSTR name)
{
   THREADNAME_INFO info;
   info.dwType = 0x1000;
   info.szName = name;
   info.dwThreadID = thread_id;
   info.dwFlags = 0;

   __try
   {
      static DWORD const MS_VC_EXCEPTION = 0x406D1388;

      RaiseException(MS_VC_EXCEPTION,
        0,
        sizeof(info) / sizeof(ULONG_PTR),
        reinterpret_cast<ULONG_PTR*>(&info));
   }
   __except(EXCEPTION_EXECUTE_HANDLER)
   {
   }
}
#endif

}
