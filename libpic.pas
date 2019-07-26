{   Program LIBPIC <filename>
*
*   Wrapper program for Microchip MPLIB.  The command line arguments to MPLIB
*   are taken from the input file instead of the command line.
}
program libpic;
%include 'base.ins.pas';

const
  prog_name = '(cog)extern/mplab/mplib.exe'; {MPLIB executable pathname}
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  fnam:                                {input file pathname}
    %include '(cog)lib/string_treename.ins.pas';
  tnam:                                {scratch pathname}
    %include '(cog)lib/string_treename.ins.pas';
  oldir:                               {old working directory}
    %include '(cog)lib/string_treename.ins.pas';
  dir:                                 {directory containing input file}
    %include '(cog)lib/string_treename.ins.pas';
  cmd:                                 {full command line to execute}
    %include '(cog)lib/string8192.ins.pas';
  buf:                                 {scratch string buffer}
    %include '(cog)lib/string8192.ins.pas';
  conn: file_conn_t;                   {connection to input file}
  exstat: sys_sys_exstat_t;            {program exit status code}
  tf: boolean;                         {TRUE/FALSE flag from running program}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {subroutine completion status code}
  stat2: sys_err_t;                    {extra status code to avoid corrupting STAT}

label
  loop_line, done_lines, abort;
{
********************************************************************************
*
*   Subroutine SET_COMMAND (S)
*
*   Set S to the the target program executable name.
}
procedure set_command (                {set executable command name}
  in out  s: univ string_var_arg_t);   {command will be first and only token}
  val_param;

var
  tnam, tnam2: string_treename_t;      {scratch treenames}

begin
  tnam.max := size_char(tnam.str);     {init local var strings}
  tnam2.max := size_char(tnam2.str);

  string_vstring (tnam, prog_name, size_char(prog_name)); {var string prog name}
  string_treename (tnam, tnam2);       {expand to full absolute pathname}

  s.len := 0;                          {init the return string to empty}
  string_append_token (s, tnam2);      {write pathname as single token to S}
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  string_cmline_end_abort;             {no additional command line args allowed}

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
