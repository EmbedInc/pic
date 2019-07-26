{   Program LINKPIC gpath
*
*   Wrapper around the Microchip MPLINK program.  See the documentation file for
*   details.
}
program linkpic;
%include '(cog)lib/base.ins.pas';

const
  prog_name = '(cog)extern/mplab/mplink.exe'; {linker executable pathname}
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  gpath:                               {input pathname}
    %include '(cog)lib/string_treename.ins.pas';
  gnam:                                {generic leafname of linker files}
    %include '(cog)lib/string_leafname.ins.pas';
  tnam:                                {scratch pathname}
    %include '(cog)lib/string_treename.ins.pas';
  oldir:                               {old working directory}
    %include '(cog)lib/string_treename.ins.pas';
  dir:                                 {directory containing input file}
    %include '(cog)lib/string_treename.ins.pas';
  picname:                             {PIC model name}
    %include '(cog)lib/string32.ins.pas';
  cmd:                                 {full command line to execute}
    %include '(cog)lib/string8192.ins.pas';
  conn: file_conn_t;                   {scratch connection to a file}
  exstat: sys_sys_exstat_t;            {program exit status code}
  tf: boolean;                         {TRUE/FALSE flag from running program}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {subroutine completion status code}
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
  string_cmline_token (gpath, stat);   {get input pathname}
  string_cmline_req_check (stat);      {this argument is required}
  string_cmline_end_abort;             {no additional command line args allowed}
{
*   Set up pathnames and go to the target directory.
}
  string_treename (gpath, tnam);       {make full treename of generic pathname}
  string_pathname_split (tnam, dir, gnam); {make directory and generic leafname}

  file_currdir_get (oldir, stat);      {get current working directory name}
  sys_error_abort (stat, 'file', 'curr_dir_get', nil, 0);

  file_currdir_set (dir, stat);        {go to the directory containing input file}
  sys_msg_parm_vstr (msg_parm[1], dir);
  sys_error_abort (stat, 'file', 'curr_dir_set', msg_parm, 1);
{
*   Read the .picname file if it exists.  If it does, the PIC name contained in
*   it will be passed using the /p command line argument later.
}
  picname.len := 0;                    {init to PIC name not known}

  while true do begin
    string_copy (gnam, tnam);          {make the .picname file name}
    string_appends (tnam, '.picname'(0));
    file_open_read_text (tnam, '', conn, stat); {try to open the .picname file}
    if sys_error(stat) then exit;      {couldn't open the file ?}
    file_read_text (conn, picname, stat); {read first line of .picname file}
    if sys_error(stat) then begin      {error reading the file ?}
      picname.len := 0;
      end;
    file_close (conn);                 {close the .picname file}
    string_unpad (picname);            {delete trailing blanks from the PIC name}
    string_upcase (picname);           {make upper case}
    exit;
    end;
{
*   Set CMD to the command line to execute.
}
  set_command (cmd);                   {init command line to executable name}

  string_copy (gnam, tnam);            {pass linker control file name}
  string_appends (tnam, '.lkr');
  string_append_token (cmd, tnam);

  if picname.len > 0 then begin        {pass PIC model name ?}
    string_append_token (cmd, string_v('/p'));
    string_append (cmd, picname);
    end;

  string_append_token (cmd, string_v('/o')); {set output file name}
  string_copy (gnam, tnam);
  string_appends (tnam, '.out');
  string_append_token (cmd, tnam);

  string_append_token (cmd, string_v('/m')); {set map file name}
  string_copy (gnam, tnam);
  string_appends (tnam, '.map');
  string_append_token (cmd, tnam);

  string_append_token (cmd, string_v('/a')); {set hex output file format}
  string_append_token (cmd, string_v('INHX32'));

  string_append_token (cmd, string_v('/w')); {don't make COD since we always do later anyway}
{
*   Run the target program.  The linker returns a non-OK exit status on failure.
}
  %debug; writeln ('Running: ', cmd.str:cmd.len);
  sys_run_wait_stdsame (               {execute the program, wait for done}
    cmd,                               {command line to execute}
    tf,                                {TRUE/FALSE flag from program exit status}
    exstat,                            {program exit status}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  if exstat <> sys_sys_exstat_ok_k then begin {something failed ?}
    sys_exit_error;                    {return indicating error}
    end;

  file_currdir_set (oldir, stat);      {try to go back to the original directory}
  sys_error_abort (stat, '', '', nil, 0);
  end.
