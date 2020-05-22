{   Private include file for all the modules of the PREPIC program.
}
%include 'base.ins.pas';
%include 'strflex.ins.pas';
%include 'escr.ins.pas';
%include 'pic.ins.pas';

type
  lang_k_t = (                         {input source language ID}
    lang_aspic_k,                      {MPASM}
    lang_dspic_k);                     {ASM30}

var (com)                              {state visible to all modules}
  nflags: sys_int_machine_t;           {total number of flags bits created}
  flag_byten: sys_int_machine_t;       {number of flag bytes (words on PIC 30) created}
  flag_bitn: sys_int_machine_t;        {0-N bit number of next flag within flag byte/word}
  lang: lang_k_t;                      {input file language ID}
  e_p: escr_p_t;                       {pointer to ESCR script system state}

procedure err_atline (                 {show error followed by source line number}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  options (val_param, noreturn, extern);

procedure err_atline_abort (           {bomb with msg and source line on error}
  in      stat: sys_err_t;             {error code, nothing done if no error}
  in      subsys: string;              {subsystem name of caller's message}
  in      msg: string;                 {name of caller's message within subsystem}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param; extern;

procedure err_dtype_unimp (            {unimplemented data type internal error}
  in      dtype: escr_dtype_k_t;       {unimplemented data type}
  in      routine: string);            {name of the routine where data type unimplemented}
  options (val_param, noreturn, extern);

procedure err_lang (                   {unexpected input language identifier}
  in      lang: lang_k_t;              {the language identifier}
  in      module: string;              {source module name where error encountered}
  in      checkpoint: sys_int_machine_t); {unique number for this occurrence}
  options (val_param, noreturn, extern);

procedure err_parm_bad (               {bomb with bad parameter to command error}
  in      parm: univ string_var_arg_t); {the offending parameter}
  options (val_param, noreturn, extern);

procedure err_parm_last_bad;           {last parameter parsed was bad}
  options (val_param, noreturn, extern);

procedure err_parm_missing (           {a required command parameter not found}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  options (val_param, noreturn, extern);

procedure err_sym_not_found (          {symbol not found}
  in      name: univ string_var_arg_t); {symbol name that was not found}
  options (val_param, noreturn, extern);

procedure err_val (                    {show value and data type of offending value}
  in      val: escr_val_t);            {the value}
  val_param; extern;

function prepic_func_detect (          {look for start of inline function}
  in      e_p: escr_p_t;               {pointer to script system state}
  in      lin: string_var_arg_t;       {input line to look for function in}
  in out  p: string_index_t;           {parse index, look for funct start here}
  out     stat: sys_err_t)             {completion status}
  :boolean;                            {function start was found, P advanced}
  val_param; extern;

procedure prepic_icmd_flag (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_icmd_inbit (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_icmd_inana (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_icmd_outbit (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_ifun_fp24i (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_ifun_fp24_int (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_ifun_fp32f (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;

procedure prepic_ifun_fp32f_int (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param; extern;
