{   Program ASMPIC <source file> <opt1> ... <optN>
}
program asmpic;
%include '(cog)lib/base.ins.pas';

const
  envvar_com = 'MPLABDir';             {environment var of Microchip executables dir}
  prog_name = 'mpasmx.exe';            {assembler executable name}
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  errnum: sys_int_machine_t;           {error number from ERR file}
  delim_pick: sys_int_machine_t;       {number of delimiter picked from list}
  pick: sys_int_machine_t;             {number of token picked from list}
  srcdir: string_treename_t;           {full pathname of source code directory}
  tnam: string_treename_t;             {scratch pathname}
  errname: string_leafname_t;          {error file name}
  oldir: string_treename_t;            {old working directory}
  cmd: string_var8192_t;               {full assembler command line to execute}
  preparm: string_var8192_t;           {parameters to pass to PREPIC from our command line}
  buf: string_var8192_t;               {scratch string buffer}
  tk: string_var32_t;                  {scratch token}
  p: string_index_t;                   {parse index}
  echo: boolean;                       {TRUE if echo ERR file line to output}
  conn: file_conn_t;                   {connection to an input file}
  exstat: sys_sys_exstat_t;            {assembler exit status code}
  tf: boolean;                         {TRUE/FALSE flag from running program}
  err: boolean;                        {TRUE if .ERR file not empty}
  cmdpre: boolean;                     {subsequent command line parameters are for PREPIC}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {subroutine completion status code}
  stat2: sys_err_t;                    {extra status code to avoid corrupting STAT}

label
  loop_opt, done_opts, loop_err, done_err,
  abort2, abort1;
{
********************************************************************************
*
*   Subroutine SET_COMMAND (S)
*
*   Set S to the the target program executable name.  The generic name of the
*   executable is set by the constant PROG_NAME.  The environment variable set
*   by constant ENVVAR_COM is assumed to contain the name of the directory
*   holding the executable program if the variable exists or its value is not
*   empty.
}
procedure set_command (                {set executable command name}
  in out  s: univ string_var_arg_t);   {command will be first and only token}
  val_param;

var
  vprog: string_leafname_t;            {var string version of executable name}
  tnam, tnam2: string_treename_t;      {scratch treenames}
  stat: sys_err_t;                     {subroutine completion status}

begin
  vprog.max := size_char(vprog.str);   {init local var strings}
  tnam.max := size_char(tnam.str);
  tnam2.max := size_char(tnam2.str);

  string_vstring (vprog, prog_name, size_char(prog_name)); {var string prog name}
  s.len := 0;                          {init return string to empty}

  sys_envvar_get (                     {get executables dir environment var value}
    string_v(envvar_com),              {environment variable name}
    tnam,                              {returned value}
    stat);
  if sys_error(stat) then tnam.len := 0; {no specific pathname on no envvar}
  if tnam.len > 0                      {check executable directory name}
    then begin                         {we have executable directory name}
      string_treename (tnam, tnam2);   {make full expansion of envvar value}
      string_pathname_join (tnam2, vprog, tnam); {make full pathname}
      string_treename (tnam, tnam2);   {resolve any symbolic links}
      string_append_token (s, tnam2);  {add as token to S}
      end
    else begin                         {there is no executable directory name}
      string_append_token (s, vprog);  {add unqualified name as token to S}
      end
    ;
  end;
{
*************************************************************************
*
*   Subroutine PREPROCESS (FNAM)
*
*   Pre-process the input source indicated by FNAM.  The result will be
*   a raw MPASM assembler source file with the same generic name in the
*   current directory.  The result file name always ends in '.asm'.
*
*   This routine runs the PREPIC program to perform the preprocess
*   operation.
}
procedure preprocess (                 {preprocess ASPIC file to ASM file}
  in    fnam: univ string_var_arg_t);  {ASPIC file name}
  val_param; internal;

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  cmd: string_var8192_t;               {full command line to execute}
  tf: boolean;                         {TRUE/FALSE status returned by program}
  exstat: sys_sys_exstat_t;            {exit status code returned by program}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;

begin
  cmd.max := size_char(cmd.str);       {init local var string}

  string_vstring (cmd, 'prepic '(0), -1); {build command line to execute}
  string_append (cmd, fnam);
  if preparm.len > 0 then begin        {additional parameters from our command line ?}
    string_append1 (cmd, ' ');
    string_append (cmd, preparm);
    end;

  sys_run_wait_stdsame (               {run preprocessor}
    cmd,                               {command line to execute}
    tf,                                {TRUE/FALSE status returned}
    exstat,                            {exit status code returned by program}
    stat);
  sys_msg_parm_vstr (msg_parm[1], cmd);
  sys_error_abort (stat, 'pic', 'err_cmd_prepic', msg_parm, 1);
  if exstat > 0 then sys_exit_error;
  end;
{
*************************************************************************
*
*   Start of main routine.
}
begin
  srcdir.max := size_char(srcdir.str); {init local var strings}
  tnam.max := size_char(tnam.str);
  errname.max := size_char(errname.str);
  oldir.max := size_char(oldir.str);
  cmd.max := size_char(cmd.str);
  buf.max := size_char(buf.str);
  tk.max := size_char(tk.str);
  preparm.max := size_char(preparm.str);

  string_cmline_init;                  {init for reading the command line}

  string_cmline_token (tnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  file_open_read_text (tnam, '.aspic .asm .ASM', conn, stat); {open input src file}
  sys_error_abort (stat, '', '', nil, 0);

  string_pathname_split (conn.tnam, srcdir, tnam); {make dir and file leafnames}
  string_fnam_extend (conn.gnam, '.err', errname); {make error file name}
{
*   The following variables have been set:
*
*     SRCDIR  -  Full pathname of directory containing source code file.
*
*     ERRNAME  -  Leafname of assembler .ERR output file.
*
*   Go to the source code directory.  The old working directory name will
*   be saved in OLDIR.
}
  file_currdir_get (oldir, stat);      {get current working directory name}
  sys_error_abort (stat, 'file', 'curr_dir_get', nil, 0);

  file_currdir_set (srcdir, stat);     {go to the source code directory}
  sys_msg_parm_vstr (msg_parm[1], srcdir);
  sys_error_abort (stat, 'file', 'curr_dir_set', msg_parm, 1);
  file_close (conn);
{
*   Build the full assembler command line to execute in CMD, and save any
*   command line parameters to PREPIC in PREPARM.
}
  set_command (cmd);                   {init command line to executable token}
  string_append_token (cmd, conn.gnam); {pass source code file name}
  string_append_token (cmd, string_v('/q')); {always quiet mode, no user interaction}
  string_append_token (cmd, string_v('/e')); {always produce an error file}

  preparm.len := 0;                    {init to no extra command line parameters for PREPIC}
  cmdpre := false;                     {init to command line parameters not for PREPIC}

loop_opt:                              {back here each new command line option}
  string_cmline_token (tnam, stat);    {get next command line option}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  if sys_error(stat) then goto abort1; {hard error ?}
  if cmdpre
    then begin                         {this parameter is for PREPIC}
      string_append_token (preparm, tnam);
      end
    else begin                         {this parameter is for assembler}
      string_copy (tnam, tk);          {make upper case copy of this parameter}
      string_upcase (tk);
      if string_equal (tk, string_v('-P'(0))) then begin {-P command line options ?}
        cmdpre := true;                {subsequent parameters are for PREPIC}
        goto loop_opt;                 {back for next command line option}
        end;
      string_append_token (cmd, tnam); {add this option to assembler command line}
      end
    ;
  goto loop_opt;                       {back for next command line option}
done_opts:                             {all done reading the command line}
{
*   Pre-process the input source file, if necessary.  If the input source
*   file name ends in ".aspic", then it is pre-processed to create the
*   .asm file which is then passed to the assembler.  If the input source
*   file name ends in ".asm", then it is passed to the assembler directly
*   without modification.
}
  if conn.ext_num = 1 then begin       {input file has .ASPIC suffix ?}
    preprocess (conn.tnam);            {preprocess to make .ASM file}
    end;
{
*   Run the assembler.
}
  file_delete_name (errname, stat);    {delete existing error file, if possible}

  %debug; writeln ('Running: ', cmd.str:cmd.len);
  sys_run_wait_stdsame (               {execute the assembler command, wait for done}
    cmd,                               {command line to execute}
    tf,                                {TRUE/FALSE flag from program exit status}
    exstat,                            {program exit status}
    stat);
  if sys_error(stat) then begin        {hard error on trying to run command ?}
    sys_msg_parm_vstr (msg_parm[1], cmd);
    sys_error_print (stat, 'pic', 'err_cmd_mpasm', msg_parm, 1);
    sys_error_none (stat);             {avoid additional error messages}
    goto abort1;                       {clean up and bomb the program}
    end;
{
*   Echo the .ERR file to standard output.  ERR will be set TRUE if the .ERR
*   file was not empty.
}
  err := false;                        {init to no error messages found}

  file_open_read_text (                {try to open error output file}
    errname, '',                       {file name and suffix}
    conn,                              {returned connection info}
    stat);
  if sys_error(stat) then goto done_err; {ignore error file if unable to open it}

loop_err:                              {back here each new line from the error file}
  file_read_text (conn, buf, stat);    {read the next line from the error file}
  if file_eof(stat) then begin         {hit end of file ?}
    file_close (conn);                 {close the file}
    file_delete_name (errname, stat);  {delete error file}
    if sys_error(stat) then goto abort1;
    goto done_err;                     {done dealing with the error file}
    end;
  if sys_error(stat) then goto abort2; {hard error reading error file ?}
  string_unpad (buf);                  {delete trailing spaces}
  echo := true;                        {init to echo line to output}
  p := 1;                              {init BUF parse index}
{
*   Each line of the error file looks like this:
*
*     <msgtype>[n] <message>
*
*   We will parse <msgtype> and N into CMD and ERRNUM, respectively.  This
*   allows special handling of some error or warning messages.  This
*   program always returns with error status if any ERROR messages are found.
}
  string_token_anyd (                  {parse message type name}
    buf, p,                            {input string and parse index}
    ' [', 2,                           {list of delimiters}
    1,                                 {first N delimiters that may repeat}
    [],                                {option flags}
    cmd,                               {returned token}
    delim_pick,                        {number of the delimiter actually used}
    stat);
  if sys_error(stat) then cmd.len := 0;
  string_upcase (cmd);

  errnum := -1;                        {init message number}
  string_token_anyd (                  {parse message number}
    buf, p,                            {input string and parse index}
    ' ]', 2,                           {list of delimiters}
    1,                                 {first N delimiters that may repeat}
    [],                                {option flags}
    tk,                                {returned token}
    delim_pick,                        {number of the delimiter actually used}
    stat);
  if not sys_error(stat) then begin    {got a real token ?}
    string_t_int (tk, errnum, stat);   {try to convert to an integer}
    if sys_error(stat) then errnum := -1; {default for no message number available}
    end;
{
*   CMD and ERRNUM are all set.
}
  echo := true;                        {init to this line will be echoed}
  string_tkpick80 (cmd,                {determine message type}
    'ERROR WARNING MESSAGE',
    pick);
  case pick of                         {what kind of message is this ?}

1:  begin                              {ERROR message}
      err := true;                     {indicate to return with error status}
      end;

2:  begin                              {WARNING message}
      case errnum of                   {which warning message is it ?}
207,                                   {found "label" after column 1}
212:                                   {missing ENDIF}
        err := true;                   {these warnings are considered errors}
        end;
      end;                             {end of WARNING message type case}

3:  begin                              {MESSAGE message}
      echo := false;                   {init echo inhibited for specific messages}
      case errnum of                   {which warning message is it ?}
302: ;                                 {register not in bank 0, check bank setting}
305: ;                                 {no F or W destination explicitly specified}
316: ;                                 {W register modified (from PAGESEL)}
otherwise                              {no special handling, echo to output}
        echo := true;                  {all other messages will be echoed}
        end;
      end;                             {end of WARNING message type case}

    end;                               {end of message type cases}
  if echo then begin                   {supposed to echo message to output ?}
    writeln (buf.str:buf.len);
    end;
  goto loop_err;                       {back to do next error file line}
done_err:                              {all done handling the error file}
{
*   Return to the original working directory and exit the program with
*   appropriate status.
}
  file_currdir_set (oldir, stat);      {go back to the original working directory}
  sys_msg_parm_vstr (msg_parm[1], oldir);
  sys_error_abort (stat, 'file', 'curr_dir_set', msg_parm, 1);

  if err then sys_exit_error;          {error message already shown ?}
  if exstat <> sys_sys_exstat_ok_k then begin {assembler not return OK status ?}
    sys_bomb;                          {exit with error and explicit message}
    end;

  sys_exit;                            {exit program indicating all went well}
{
*   Error exits.  STAT must already be set.
}
abort2:                                {an input file is open}
  file_close (conn);
abort1:                                {not in original working directory}
  file_currdir_set (oldir, stat2);     {try to go back to the original directory}
  sys_error_abort (stat, '', '', nil, 0); {bomb program with original error}
  sys_bomb;                            {should not get here if STAT was set}
  end.
