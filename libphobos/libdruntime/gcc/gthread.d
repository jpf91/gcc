// GNU D Compiler emulated TLS routines.
// Copyright (C) 2011-2019 Free Software Foundation, Inc.

// GCC is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3, or (at your option) any later
// version.

// GCC is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.

// Under Section 7 of GPL version 3, you are granted additional
// permissions described in the GCC Runtime Library Exception, version
// 3.1, as published by the Free Software Foundation.

// You should have received a copy of the GNU General Public License and
// a copy of the GCC Runtime Library Exception along with this program;
// see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
// <http://www.gnu.org/licenses/>.

alias GthreadDestroyFn = extern(C) void function(void*);
version (Windows)
{
    int __gthr_win32_key_create (__gthread_key_t *keyp, GthreadDestroyFn dtor);
    void* __gthr_win32_getspecific (__gthread_key_t key);
    int __gthr_win32_setspecific (__gthread_key_t key, const void* ptr);

    alias __gthread_key_create = __gthr_win32_key_create;
    alias __gthread_getspecific = __gthr_win32_getspecific;
    alias __gthread_setspecific = __gthr_win32_setspecific;
    alias __gthread_key_t = c_ulong;
}
else version (Posix)
{
    import core.sys.posix.pthread;
    alias __gthread_key_create = pthread_key_create;
    alias __gthread_getspecific = pthread_getspecific;
    alias __gthread_setspecific = pthread_setspecific;
    alias __gthread_key_t = pthread_key_t;
}
else
{
    static assert(false, "Not implemented");
}
