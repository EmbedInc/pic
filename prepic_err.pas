{   Error handling.
}
module prepic_err;
define err_atline;
define err_atline_abort;
define err_val;
define err_lang;
define err_parm_bad;
define err_parm_last_bad;
define err_parm_missing;
define err_dtype_unimp;
define err_sym_not_found;
%include 'prepic.ins.pas';
{
****************************************************************************
*
*   Subroutine ERR_ATLINE (SUBSYS, MSG, PARMS, N_PARMS)
*
*   Write the message from the call parameters, then write a message indicating
*   the current source file name and line number, then exit the program with
*   error status.
}
procedure err_atline (                 {show error followed by source line number}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  options (val_param, noreturn);

begin
  escr_err_atline (e_p^, subsys, msg, parms, n_parms);
  end;
{
****************************************************************************
*
*   Subroutine ERR_ATLINE_ABORT (STAT, SUBSYS, MSG, PARMS, N_PARMS)
*
*   If STAT is indicating an error, then write the error and identify the
*   current source line, then bomb the program.  Nothing is done if
*   STAT is not indicating an error.
}
procedure err_atline_abort (           {bomb with msg and source line on error}
  in      stat: sys_err_t;             {error code, nothing done if no error}
  in      subsys: string;              {subsystem name of caller's message}
  in      msg: string;                 {name of caller's message within subsystem}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

begin
  escr_err_atline_abort (e_p^, stat, subsys, msg, parms, n_parms);
  end;
{
****************************************************************************
*
*   Subroutine ERR_VAL (VAL)
*
*   Show the data type and value of VAL.
}
procedure err_val (                    {show value and data type of offending value}
  in      val: escr_val_t);            {the value}
  val_param;

begin
  escr_err_val (e_p^, val);
  end;
{
****************************************************************************
*
*   Subroutine ERR_LANG (LANG, MODULE, CHECKPOINT)
*
*   Unexpected input language identifier encountered.
}
procedure err_lang (                   {unexpected input language identifier}
  in      lang: lang_k_t;              {the language identifier}
  in      module: string;              {source module name where error encountered}
  in      checkpoint: sys_int_machine_t); {unique number for this occurrence}
  options (val_param, noreturn);

const
  max_msg_parms = 3;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

begin
  sys_msg_parm_int (msg_parm[1], ord(lang));
  sys_msg_parm_str (msg_parm[2], module);
  sys_msg_parm_int (msg_parm[3], checkpoint);
  err_atline ('pic', 'err_lang', msg_parm, 3);
  end;
{
****************************************************************************
*
*   Subroutine ERR_PARM_BAD (PARM)
*
*   Bomb program with error message about the bad parameter PARM to the
*   current command.  The source file and line number will be shown.
}
procedure err_parm_bad (               {bomb with bad parameter to command error}
  in      parm: univ string_var_arg_t); {the offending parameter}
  options (val_param, noreturn);

begin
  escr_err_parm_bad (e_p^, parm);
  end;
{
****************************************************************************
*
*   Subroutine ERR_PARM_LAST_BAD
*
*   Like ERR_PARM_BAD except that it automatically works on the last
*   parameter parsed from the input line.
}
procedure err_parm_last_bad;           {last parameter parsed was bad}
  options (val_param, noreturn);

begin
  err_parm_bad (e_p^.parse_p^.lparm);
  end;
{
****************************************************************************
*
*   Subroutine ERR_PARM_MISSING (SUBSYS, MSG, PARMS, N_PARMS)
}
procedure err_parm_missing (           {a required command parameter not found}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  options (val_param, noreturn);

var
  stat: sys_err_t;

begin
  escr_stat_cmd_noarg (e_p^, stat);    {set STAT to missing parameter error}
  escr_err_atline_abort (e_p^, stat, '', '', nil, 0);
  end;
{
****************************************************************************
*
*   Subroutine ERR_DTYPE_UNIMP (DTYPE, ROUTINE)
*
*   Indicate an internal error has occurred where data type DTYPE is not supported
*   in routine ROUTINE.  The program will be aborted with error.
}
procedure err_dtype_unimp (            {unimplemented data type internal error}
  in      dtype: escr_dtype_k_t;       {unimplemented data type}
  in      routine: string);            {name of the routine where data type unimplemented}
  options (val_param, noreturn);

begin
  escr_err_dtype_unimp (e_p^, dtype, routine);
  end;
{
********************************************************************************
*
*   Subroutine ERR_SYM_NOT_FOUND (NAME)
*
*   No symbol of the indicated name was found.
}
procedure err_sym_not_found (          {symbol not found}
  in      name: univ string_var_arg_t); {symbol name that was not found}
  options (val_param, noreturn);

var
  stat: sys_err_t;

begin
  sys_stat_set (escr_subsys_k, escr_err_nfsym_k, stat);
  sys_stat_parm_vstr (name, stat);
  escr_err_atline_abort (e_p^, stat, '', '', nil, 0);
  end;
