{   PIC assembler pre-processor.  See the PREPIC documentation file for details
*   of its operation.
*
*   The PREPIC program is implemented as a application of the ESCR Embed
*   scripting system.  ESCR handles the scripting mechanics and implements the
*   generic commands, functions, and the like.  PREPIC adds some commands and
*   functions that are specific to PIC pre-processing.
*
*   The ESCR system allows some optional configuration by the application.  The
*   specific configuration set by PREPIC includes:
*
*     Preprocessor mode, not script mode.
*
*     Data file comments start with ";".
*
*     Additional intrinsic commands:
*
*       INBIT
*       INANA
*       OUTBIT
*       FLAG
*
*     Additional intrinsic functions:
*
*       FP24I
*       FP24_INT
*       FP32F
*       FP32F_INT
}
program prepic;
define com;
%include 'prepic.ins.pas';

const
  max_msg_args = 2;                    {max arguments we can pass to a message}

var
  fnam_in:                             {input file name}
    %include '(cog)lib/string_treename.ins.pas';
  fnam_out:                            {output file name}
    %include '(cog)lib/string_treename.ins.pas';
  iname_set: boolean;                  {TRUE if the input file name already set}
  oname_set: boolean;                  {TRUE if the output file name already set}

  sym_p: escr_sym_p_t;                 {scratch pointer to symbol in symbol table}
  im: sys_int_max_t;                   {scratch max size integer}
  fp: sys_fp_max_t;                    {scratch max size floating point}
  conn: file_conn_t;                   {connection to the input file}
  osuff: string;                       {output file name suffix}

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  tk:                                  {scratch token}
    %include '(cog)lib/string8192.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts;
{
******************************
*
*   Subroutine ADDCMD (NAME, ROUTINE_P)
*
*   Add the intrinsic command NAME to the commands symbol table.  NAME is a
*   Pascal string, not a var string.  ROUTINE_P is the pointer to the command
*   routine.
}
type
  {
  *   A separate template for a command routine is defined here.  This is the
  *   same as the official ESCR_ICMD_P_T except that the first argument is the
  *   library use state directly defined for IN and OUT use, as apposed to a
  *   pointer to the library use state.  The former is how command routines are
  *   actually defined, but the ESCR_ICMD_P_T template can't be defined that way
  *   due to circular dependencies that would be required of such a definition.
  *   Both definitions should result in the same code.
  }
  cmd_routine_p_t = ^procedure (
    in out e: escr_t;
    out   stat: sys_err_t);
    val_param;

procedure addcmd (                     {add intrinsic command to commands table}
  in      name: string;                {command name}
  in      routine_p: cmd_routine_p_t); {pointer to command routine}
  val_param;

var
  stat: sys_err_t;

begin
  escr_icmd_add (                      {add intrinsic command to commands table}
    e_p^,                              {state for this use of the ESCR library}
    string_v(name),                    {command name}
    escr_icmd_p_t(routine_p),          {pointer to command routine}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
******************************
*
*   Local subroutine ADDFUNC (NAME, ROUTINE_P)
*
*   Add the intrinsic function NAME to the functions symbol table.  NAME is a
*   Pascal string, not a var string.  ROUTINE_P is the pointer to the function
*   routine.
*
*   The program is aborted on any error.
}
type
  {
  *   A separate template for a function routine is defined here.  This is the
  *   same as the official ESCR_IFUNC_P_T except that the first argument is the
  *   library use state directly defined for IN and OUT use, as apposed to a
  *   pointer to the library use state.  The former is how function routines are
  *   actually defined, but the ESCR_IFUNC_P_T template can't be defined that
  *   way due to circular dependencies that would be required of such a
  *   definition.  Both definitions should result in the same code.
  }
  func_routine_p_t = ^procedure (
    in out e: escr_t;                  {library use state}
    out   stat: sys_err_t);
    val_param;

procedure addfunc (                    {add intrinsic function to functions table}
  in      name: string;                {function name}
  in      function_p: func_routine_p_t); {pointer to function routine}
  val_param;

var
  stat: sys_err_t;

begin
  escr_ifunc_add (                     {add intrinsic function to functions table}
    e_p^,                              {state for this use of the ESCR library}
    string_v(name),                    {function name}
    escr_ifunc_p_t(function_p),        {pointer to function routine}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
******************************
*
*   Start of main routine.
}
begin
{
*   Initialize global state.
}
  nflags := 0;                         {init to no /FLAG flags created}
  flag_byten := 0;                     {init to no GFLx flag bytes required}
  flag_bitn := 0;                      {number of next flag bit within flag byte}
  escr_open (                          {create new use of the ESCR scripting system}
    util_top_mem_context,              {parent memory context, will make subordinate}
    e_p,                               {returned pointer to script system state}
    stat);
  sys_error_abort (stat, 'escr', 'open', nil, 0);
{
*   Initialize our state before reading the command line options.
}
  string_cmline_init;                  {init for reading the command line}
  iname_set := false;                  {no input file name specified}
  oname_set := false;                  {no output file name specified}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if not iname_set then begin        {input file name not set yet ?}
      string_copy (opt, fnam_in);      {set input file name}
      iname_set := true;               {input file name is now set}
      goto next_opt;
      end;
    if not oname_set then begin        {output file name not set yet ?}
      string_copy (opt, fnam_out);     {set output file name}
      oname_set := true;               {output file name is now set}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-IN -OUT -SET -I -F -S -NOT',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -IN filename
}
1: begin
  if iname_set then begin              {input file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (fnam_in, stat);
  iname_set := true;
  end;
{
*   -OUT filename
}
2: begin
  if oname_set then begin              {output file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (fnam_out, stat);
  oname_set := true;
  end;
{
*   -SET name
}
3: begin
  string_cmline_token (parm, stat);    {get the variable name}
  if sys_error(stat) then goto err_parm;
  if not escr_sym_name_bare (parm)     {check for illegal symbol name}
    then goto parm_bad;

  escr_sym_new_var (                   {create the new variable}
    e_p^,                              {ESCR script system state}
    parm,                              {name of variable to create}
    escr_dtype_bool_k,                 {data type of the variable}
    true,                              {make global, not local}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  sys_msg_parm_vstr (msg_parm[1], tk);
  sys_error_abort (stat, 'escr', 'var_new', msg_parm, 1);

  sym_p^.var_val.bool := true;         {set variable value}
  end;
{
*   -I name int
}
4: begin
  string_cmline_token (parm, stat);    {get the variable name}
  if sys_error(stat) then goto err_parm;
  if not escr_sym_name_bare (parm)     {check for illegal symbol name}
    then goto parm_bad;
  string_copy (parm, tk);              {save name of new variable}

  string_cmline_token (parm, stat);    {get value string}
  if sys_error(stat) then goto err_parm;
  string_t_int_max (parm, im, stat);   {convert to integer}
  if sys_error(stat) then goto err_parm;

  escr_sym_new_var (                   {create the new variable}
    e_p^,                              {ESCR script system state}
    tk,                                {name of variable to create}
    escr_dtype_int_k,                  {data type of the variable}
    true,                              {make global, not local}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  sys_msg_parm_vstr (msg_parm[1], tk);
  sys_error_abort (stat, 'escr', 'var_new', msg_parm, 1);

  sym_p^.var_val.int := im;            {set variable value}
  end;
{
*   -F name val
}
5: begin
  string_cmline_token (parm, stat);    {get the variable name}
  if sys_error(stat) then goto err_parm;
  if not escr_sym_name_bare (parm)     {check for illegal symbol name}
    then goto parm_bad;
  string_copy (parm, tk);              {save name of new variable}

  string_cmline_token (parm, stat);    {get value string}
  if sys_error(stat) then goto err_parm;
  string_t_fpmax (parm, fp, [], stat); {convert to floating point}
  if sys_error(stat) then goto err_parm;

  escr_sym_new_var (                   {create the new variable}
    e_p^,                              {ESCR script system state}
    tk,                                {name of variable to create}
    escr_dtype_fp_k,                   {data type of the variable}
    true,                              {make global, not local}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  sys_msg_parm_vstr (msg_parm[1], tk);
  sys_error_abort (stat, 'escr', 'var_new', msg_parm, 1);

  sym_p^.var_val.fp := fp;             {set variable value}
  end;
{
*   -S name string
}
6: begin
  string_cmline_token (parm, stat);    {get the variable name}
  if sys_error(stat) then goto err_parm;
  if not escr_sym_name_bare (parm)     {check for illegal symbol name}
    then goto parm_bad;
  string_copy (parm, tk);              {save name of new variable}

  string_cmline_token (parm, stat);    {get value string}
  if sys_error(stat) then goto err_parm;

  escr_sym_new_var (                   {create the new variable}
    e_p^,                              {ESCR script system state}
    tk,                                {name of variable to create}
    escr_dtype_str_k,                  {data type of the variable}
    true,                              {make global, not local}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  sys_msg_parm_vstr (msg_parm[1], tk);
  sys_error_abort (stat, 'escr', 'var_new', msg_parm, 1);

  strflex_copy_f_vstr (parm, sym_p^.var_val.stf); {set variable value}
  end;
{
*   -NOT name
}
7: begin
  string_cmline_token (parm, stat);    {get the variable name}
  if sys_error(stat) then goto err_parm;
  if not escr_sym_name_bare (parm)     {check for illegal symbol name}
    then goto parm_bad;

  escr_sym_new_var (                   {create the new variable}
    e_p^,                              {ESCR script system state}
    parm,                              {name of variable to create}
    escr_dtype_bool_k,                 {data type of the variable}
    true,                              {make global, not local}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  sys_msg_parm_vstr (msg_parm[1], tk);
  sys_error_abort (stat, 'escr', 'var_new', msg_parm, 1);

  sym_p^.var_val.bool := false;        {set variable value}
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
{
*   Process the input file name.
}
  if not iname_set then begin          {no input file name supplied ?}
    sys_message_bomb ('file', 'no_input_filename', nil, 0);
    end;

  file_open_read_text (fnam_in,        {test open the input file name}
    '.ins.aspic .aspic .ins.dspic .dspic',
    conn, stat);
  sys_error_abort (stat, '', '', nil, 0);

  case conn.ext_num of                 {which suffix did input file have ?}
1:  begin                              {.INS.ASPIC}
      lang := lang_aspic_k;            {set input file language ID}
      osuff := '.inc';                 {set output file suffix}
      end;
2:  begin                              {.ASPIC}
      lang := lang_aspic_k;            {set input file language ID}
      osuff := '.asm';                 {set output file suffix}
      end;
3:  begin                              {.INS.DSPIC}
      lang := lang_dspic_k;            {set input file language ID}
      osuff := '.inc';                 {set output file suffix}
      end;
4:  begin                              {.DSPIC}
      lang := lang_dspic_k;            {set input file language ID}
      osuff := '.as';                  {set output file suffix}
      end;
otherwise                              {anything else, like .ASPIC}
    sys_message_bomb ('pic', 'err_prepic_insuff', nil, 0);
    end;
{
*   Process the output file name.
}
  if not oname_set then begin          {output file name not explicitly set ?}
    string_copy (conn.gnam, fnam_out); {default to same generic name as input file}
    end;
  string_fnam_extend (fnam_out, osuff, parm); {make output file name with suffix}
  string_copy (parm, fnam_out);
{
*   Configure the ESCR scripting system for our use.
}
  escr_set_preproc (e_p^, true);       {set preprocessor mode, not script mode}

  escr_set_incsuff (e_p^, ''(0));      {no special suffixed required for include files}

  string_vstring (e_p^.cmdst, '/', 1); {special sequence to start a script command}

  escr_commdat_add (                   {add source file comment identifier}
    e_p^,                              {scripting system state}
    string_v(';'(0)),                  {comment start identifier}
    string_v(''(0)),                   {comment ends at end of line}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  escr_set_func_detect (               {install custom routine to detect functions}
    e_p^,                              {scripting system state}
    addr(prepic_func_detect));         {routine that will be called to detect functions}
  {
  *   Install our unique intrinsic commands.
  }
  addcmd ('flag', addr(prepic_icmd_flag));
  addcmd ('inbit', addr(prepic_icmd_inbit));
  addcmd ('inana', addr(prepic_icmd_inana));
  addcmd ('outbit', addr(prepic_icmd_outbit));
  {
  *   Install our unique intrinsic functions.
  }
  addfunc ('fp24i', addr(prepic_ifun_fp24i));
  addfunc ('fp24_int', addr(prepic_ifun_fp24_int));
  addfunc ('fp32f', addr(prepic_ifun_fp32f));
  addfunc ('fp32f_int', addr(prepic_ifun_fp32f_int));
{
*   Do the pre-processing.
}
  escr_out_open_file (e_p^, fnam_out, stat); {open pre-processed output file}
  sys_error_abort (stat, '', '', nil, 0);

  escr_run_conn (                      {run the input file}
    e_p^,                              {scripting system state}
    conn,                              {connection to file to run}
    stat);
  escr_err_atline_abort (e_p^, stat, '', '', nil, 0);

  escr_close (e_p);                    {end use of script system}
  end.
