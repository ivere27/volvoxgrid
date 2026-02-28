/* wine_stubs.c — Stub implementations for Win8+ APIs missing in Wine 6.x
 *
 * These are compiled into separate stub DLLs placed alongside the OCX
 * so Wine can resolve imports from Rust's std library.
 */

/*
 * === bcryptprimitives.dll stub ===
 *
 * ProcessPrng — used by Rust's getrandom crate.
 * On Wine, delegate to RtlGenRandom (SystemFunction036) from advapi32.
 */

/* Build: i686-w64-mingw32-gcc -shared -o bcryptprimitives.dll wine_stubs_bcrypt.c
          -Wl,--out-implib,libbcryptprimitives.a */

/* This file is for documentation. See build_wine_stubs.sh for build commands. */
