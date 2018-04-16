{   Program LIBPIC <filename>
*
*   This program runs the Microchip library manager MPLIB.  MPLIB requires
*   all arguments on the command line, including the list of object files
*   to put into a library.
*
*   This program runs MPLIB in the directory where the input file is
*   stored.  Each line in the input file is added as one additional
*   argument to MPLIB.  The input file is deleted if MPLIB completes
*   without errors.
*
*   The environment variable MPLABDir is assumed to be set to the directory
*   containing the Microchip executables.  If this variable is not present
*   or empty, then the Microchip executables are assumed to be in the
*   executables search path, in other words they can be run directly without
*   having to specify the full path name.
}
program libpic;
%include '/cognivision_links/dsee_libs/sys/sys.ins.pas';
%include '/cognivision_links/dsee_libs/util/util.ins.pas';
%include '/cognivision_links/dsee_libs/string/string.ins.pas';
%include '/cognivision_links/dsee_libs/file/file.ins.pas';

const
  envvar_com = 'MPLABDir';             {environment var of Microchip executables dir}
  prog_name = 'mplib';                 {program executable name}
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  fnam: string_treename_t;             {input file pathname}
  tnam: string_treename_t;             {scratch pathname}
  conn: file_conn_t;                   {connection to input file}
  oldir: string_treename_t;            {old working directory}
  dir: string_treename_t;              {directory containing input file}
  cmd: string_var8192_t;               {full command line to execute}
  buf: string_var8192_t;               {scratch string buffer}
  exstat: sys_sys_exstat_t;            {program exit status code}
  tf: boolean;                         {TRUE/FALSE flag from running program}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {subroutine completion status code}
  stat2: sys_err_t;                    {extra status code to avoid corrupting STAT}

label
  loop_line, done_lines, abort;
{
*************************************************************************
*
*   Subroutine SET_COMMAND (S)
*
*   Set the target program executable name as the first token of S.
*   The generic name of the executable is set by the constant PROG_NAME.
*   The environment variable set by constant ENVVAR_COM is assumed to
*   contain the name of the directory holding the executable program if
*   the variable exists is its value is not empty.
}
procedure set_command (                {set executable command name}
  in out  s: univ string_var_arg_t);   {command will be first and only token}
  val_param;

var
  vprog: string_leafname_t;            {var string version of executable name}
  tnam, tnam2: string_treename_t;      {scratch treenames}

begin
  vprog.max := size_char(vprog.str);   {init local var strings}
  tnam.max := size_char(tnam.str);
  tnam2.max := size_char(tnam2.str);

  string_vstring (vprog, prog_name, size_char(prog_name)); {var string prog name}
  s.len := 0;                          {init command line string to empty}

  sys_envvar_get (                     {get executables dir environment var value}
    string_v(envvar_com),              {environment variable name}
    tnam,                              {returned value}
    stat);
  if sys_error(stat) then tnam.len := 0; {no specific pathname on no envvar}
  if tnam.len > 0                      {check executable directory name}
    then begin                         {we have executable directory name}
      string_treename (tnam, tnam2);   {make full expansion of envvar value}
      string_pathname_join (tnam2, vprog, tnam); {make full pathname}
      string_append_token (s, tnam);   {add as token to S}
      end
    else begin                         {there is no executable directory name}
      string_append_token (s, vprog);  {add unqualified name as token to S}
      end
    ;
  end;
{
*************************************************************************
*
*   Start of main routine.
}
begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  tnam.max := size_char(tnam.str);
  oldir.max := size_char(oldir.str);
  dir.max := size_char(dir.str);
  cmd.max := size_char(cmd.str);
  buf.max := size_char(buf.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  string_cmline_end_abort;             {no additional command line ars allowed}

  file_open_read_text (fnam, '', conn, stat); {open input file for text read}
  sys_msg_parm_vstr (msg_parm[1], fnam);
  sys_error_abort (stat, 'file', 'open_input_read_text', msg_parm, 1);

  set_command (cmd);                   {init command line to executable token}
{
*   Back here for each new line from the input file.
}
loop_line:
  file_read_text (conn, buf, stat);    {read the next line from the input file}
  if file_eof(stat) then goto done_lines; {hit end of file ?}
  if sys_error(stat) then goto abort;  {hard error ?}
  string_append_token (cmd, buf);      {add this line as command line argument}
  goto loop_line;                      {back to do next line}
done_lines:                            {done reading the input file}
  file_close (conn);                   {close the input file}
{
*   Run the program.
}
  string_pathname_split (conn.tnam, dir, tnam); {get directory containing input file}
  file_currdir_get (oldir, stat);      {get current working directory name}
  sys_error_abort (stat, 'file', 'curr_dir_get', nil, 0);
  file_currdir_set (dir, stat);        {go to the directory containing input file}
  sys_msg_parm_vstr (msg_parm[1], dir);
  sys_error_abort (stat, 'file', 'curr_dir_set', msg_parm, 1);

  %debug; writeln ('Running: ', cmd.str:cmd.len);
  sys_run_wait_stdsame (               {execute the program, wait for done}
    cmd,                               {command line to execute}
    tf,                                {TRUE/FALSE flag from program exit status}
    exstat,                            {program exit status}
    stat);
  file_currdir_set (oldir, stat2);     {try to go back to the original directory}
  sys_error_abort (stat, '', '', nil, 0);

  if exstat = sys_sys_exstat_ok_k then begin {all went well ?}
    file_delete_name (conn.tnam, stat);
    sys_error_abort (stat, '', '', nil, 0);
    sys_exit;
    end;
  if exstat = sys_sys_exstat_true_k then sys_exit_true;
  if exstat = sys_sys_exstat_false_k then sys_exit_false;
  sys_exit_error;
{
*   Error exits.  STAT must already be set.
}
abort:                                 {input file is open}
  file_close (conn);                   {close input file}
  sys_error_abort (stat, '', '', nil, 0);
  sys_bomb;                            {should not get here if STAT was set}
  end.
