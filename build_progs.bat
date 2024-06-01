@echo off
rem
rem   BUILD_PROGS [-dbg]
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

call src_progl asmpic
call src_progl aspic_fix
call src_progl filtbits
call src_progl fp32fh
call src_progl fph
call src_progl fxh
call src_progl hf32
call src_progl hfp
call src_progl hfp32
call src_progl hfx
call src_progl hfx29
call src_progl libpic
call src_progl linkpic

call callbat "%sourcedir%\build_prog_prepic" %1
