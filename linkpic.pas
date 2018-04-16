{   Program LINKPIC gpath
*
*   This program is a wrapper that runs the Microchip MPLINK linker.  GPATH is
*   the generic pathname for files associated with this build.  For example,
*   GPATH could be "(cog)src/stuff/myproj".  In that case, the files for this
*   build will be assumed to be in "(cog)src/stuff", and their names will start
*   with "myproj".  For example, the HEX output file name will be <gpath>.HEX,
*   the map file <gpath>.MAP, etc.
*
*   The linker will be run in the directory containing GPATH.  The linker
*   control file <gpath>.lkr must exist.
*
*   The environment variable MPLABDir is assumed to be set to the directory
*   containing the Microchip executables.  If this variable is not present
*   or empty, then the Microchip executables are assumed to be in the
*   executables search path, in other words they can be run directly without
*   having to specify the full path name.
}
program linkpic;
%include '(cog)lib/base.ins.pas';

const
  envvar_com = 'MPLABDir';             {environment var of Microchip executables dir}
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  gpath: string_treename_t;            {input pathname}
  gnam: string_leafname_t;             {generic leafname of linker files}
  tnam: string_treename_t;             {scratch pathname}
  oldir: string_treename_t;            {old working directory}
  dir: string_treename_t;              {directory containing input file}
  picname: string_var32_t;             {PIC model name}
  cmd: string_var8192_t;               {full command line to execute}
  conn: file_conn_t;                   {scratch connection to a file}
  exstat: sys_sys_exstat_t;            {program exit status code}
  tf: boolean;                         {TRUE/FALSE flag from running program}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {subroutine completion status code}
  stat2: sys_err_t;                    {extra status code to avoid corrupting STAT}
{
********************************************************************************
*
*   Subroutine SET_COMMAND (S, PROG)
*
*   Set the target program executable name as the first token of S.  PROG is the
*   generic name of the executable, which is assumed to be in the directory
*   containing the MPLINK and related executable.  The environment variable set
*   by constant ENVVAR_COM is assumed to contain the name of the directory
*   holding the executable program if the variable exists and its value is not
*   empty.
}
procedure set_command (                {set executable command name}
  in out  s: univ string_var_arg_t;    {command will be first and only token}
  in      prog: string);               {generic MPLAB/MPASM executable name}
  val_param;

var
  vprog: string_leafname_t;            {var string version of executable name}
  tnam, tnam2: string_treename_t;      {scratch treenames}

begin
  vprog.max := size_char(vprog.str);   {init local var strings}
  tnam.max := size_char(tnam.str);
  tnam2.max := size_char(tnam2.str);

  string_vstring (vprog, prog, 80);    {var string prog name}
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
********************************************************************************
*
*   Start of main routine.
}
begin
  gpath.max := size_char(gpath.str);   {init local var strings}
  gnam.max := size_char(gnam.str);
  tnam.max := size_char(tnam.str);
  oldir.max := size_char(oldir.str);
  dir.max := size_char(dir.str);
  picname.max := size_char(picname.str);
  cmd.max := size_char(cmd.str);

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
  set_command (cmd, 'mplink');         {init command line to executable name}

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

  file_currdir_set (oldir, stat2);     {try to go back to the original directory}
  end.
