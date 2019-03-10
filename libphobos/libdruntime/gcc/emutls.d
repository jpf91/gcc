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

// This code is based on the libgcc emutls.c emulated TLS support.

import core.atomic, core.sync.mutex, core.memory;
import core.stdc.stdlib;
import gcc.builtins, gcc.gthread;

version (GNU_EMUTLS):


alias word = __builtin_machine_uint;
alias pointer = __builtin_pointer_uint;

struct __emutls_object
{
    word size;
    word align_;
    union
    {
        pointer offset;
        void* ptr;
    }
    ubyte* templ;
}

__gshared Mutex emutlsMutex;
__gshared pointer emutlsSize;
__gshared __gthread_key_t emutlsKey;

extern (C) void keyDestroy(void* key)
{
    GC.removeRoot(key);
}

shared static this()
{
    if (__gthread_key_create (&emutlsKey, null) != 0)
        abort();
    emutlsMutex = new Mutex();
}

alias PointerArray = void*[];

extern(C) void* __emutls_d_get_address (shared __emutls_object* obj)
{
    // Obtain the offset index into the TLS array (same for all-threads)
    // for requested var. If it is unset, obtain a new offset index.
    pointer offset = atomicLoad!(MemoryOrder.acq, pointer)(obj.offset);
    if (__builtin_expect (offset == 0, 0))
    {
        synchronized(emutlsMutex)
        {
            offset = obj.offset;
            if (offset == 0)
            {
                offset = ++emutlsSize;
                atomicStore!(MemoryOrder.rel, pointer)(obj.offset, offset);
            }
        }
    }

    auto arr = cast(PointerArray*)__gthread_getspecific(emutlsKey);
    if (__builtin_expect (arr == null, 0))
    {
        arr = cast(PointerArray*)GC.calloc(PointerArray.sizeof);
        GC.addRoot(arr);
        __gthread_setspecific (emutlsKey, arr);
    }

    // Check if we have to grow the per-thread array
    if (__builtin_expect (offset > arr.length, 0))
    {
        auto newSize = arr.length * 2;
        if (offset > newSize)
            newSize = offset + 32;
        arr.length = newSize;
    }

    // Offset 0 is used as a not-initialized marker above. In the
    // TLS array, we start at 0.
    auto index = offset - 1;

    // Get the per-thread pointer from the TLS array
    void* ret = (*arr)[index];
    if (__builtin_expect (ret == null, 0))
    {
        // Initial access, have to allocate the storage
        ret = emutlsAlloc(obj);
        (*arr)[index] = ret;
    }

    return ret;
}

void*
emutlsAlloc (const shared __emutls_object* obj)
{
    // The GC ensures proper alignment for any D type
    auto ptr = cast(ubyte*)GC.malloc(obj.size);

    if (obj.templ)
        ptr[0 .. obj.size] = obj.templ[0 .. obj.size];
    else
        ptr[0 .. obj.size] = 0;

    return ptr;
}
