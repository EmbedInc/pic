@echo off
rem
rem   Build the PREPIC program from this source library.
rem
setlocal
call build_pasinit
set prog=prepic

call src_get %srcdir% %prog%.ins.pas
call src_getfrom escr escr.ins.pas
call src_getfrom escr escr2.ins.pas

call src_pas %srcdir% %prog% %1
call src_pas %srcdir% %prog%_err %1
call src_pas %srcdir% %prog%_func %1
call src_pas %srcdir% %prog%_icmd_flag %1
call src_pas %srcdir% %prog%_icmd_inbit %1
call src_pas %srcdir% %prog%_icmd_outbit %1
call src_pas %srcdir% %prog%_ifun %1

set dbg_promote=none
call src_lib %srcdir% %prog%_prog

if "%1"=="-dbg" goto build_prog_dbg
set dbg_promote=true
call build_prog %prog% %prog% %prog%_prog.lib
goto done_build_prog
:build_prog_dbg
set dbg_promote=local
call build_prog %prog% %prog% /debug %prog%_prog.lib
:done_build_prog
if not exist %prog%.exe goto :eof

if "%dbg_promote%"=="true" goto cp_global
copyt %prog%.exe ~/com_dbg/%prog%.exe
goto :eof
:cp_global
copyt %prog%.exe (cog)com/%prog%.exe
del %prog%.exe
