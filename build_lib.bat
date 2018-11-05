@echo off
rem
rem   BUILD_LIB [-dbg]
rem
rem   Build the PIC library.
rem
setlocal
call build_pasinit

call src_insall %srcdir% %libname%

call src_pas %srcdir% %libname%_fp %1
call src_pas %srcdir% %libname%_map %1
call src_pas %srcdir% %libname%_map30 %1

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%
