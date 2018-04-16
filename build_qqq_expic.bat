@echo off
rem
rem   BUILD_QQ2_EXPIC
rem
rem   Build the QQ2 firmware from the QQ1 library.
rem
setlocal
set srcdir=qq1
set buildname=qq2

call treename_var (cog)source/pic/fwtype.all tnam
if exist "%tnam%" (
  call src_get pic fwtype.all
  )
call src_get_ins_aspic pic fwtype
call src_get_ins_aspic pic std_def
call src_get_ins_aspic pic std
call src_get_ins_aspic pic port
call src_get_ins_aspic pic regs
call src_get_ins_aspic pic stack
call src_get_ins_aspic pic uart

call src_ins_aspic %srcdir% %buildname%lib -set make_version
call src_get_ins_aspic %srcdir% %buildname%

call src_aspic %srcdir% %buildname%_cmd
call src_aspic %srcdir% %buildname%_init
call src_aspic %srcdir% %buildname%_intr
call src_aspic %srcdir% %buildname%_main
call src_aspic %srcdir% %buildname%_port
call src_aspic %srcdir% %buildname%_regs
call src_aspic %srcdir% %buildname%_stack
call src_aspic %srcdir% %buildname%_uart

call src_libpic %srcdir% %buildname%

call src_aspic %srcdir% %buildname%_strt
call src_expic %srcdir% %buildname%

rem   Do SRC_GET on files just so that promotion is performed when enabled.
rem
call src_get %srcdir% doc.txt
call src_get %srcdir% build.bat
