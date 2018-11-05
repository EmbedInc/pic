@echo off
rem
rem   Build everything from this source directory.
rem
setlocal
call godir "(cog)source/pic"

call build_lib
call build_progs
