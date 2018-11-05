@echo off
rem
rem   BUILD_PROGS [-dbg]
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

call src_prog %srcdir% asmpic %1
call src_prog %srcdir% aspic_fix %1
call src_prog %srcdir% filtbits %1
call src_prog %srcdir% fp32fh %1
call src_prog %srcdir% fph %1
call src_prog %srcdir% fxh %1
call src_prog %srcdir% hf32 %1
call src_prog %srcdir% hfp %1
call src_prog %srcdir% hfp32 %1
call src_prog %srcdir% hfx %1
call src_prog %srcdir% libpic %1
call src_prog %srcdir% linkpic %1

call callbat "%sourcedir%\build_prog_prepic" %1
