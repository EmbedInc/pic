{   Program HFP32 hexval
*
*   The command line argument is interpreted as a hexadecimal number.  This is
*   interpreted as a IEEE 32 bit floating point number, and its value written to
*   standard output.
}
program hfp32;
%include 'base.ins.pas';

var
  tk:                                  {scratch token}
    %include '(cog)lib/string32.ins.pas';
  stat: sys_err_t;                     {completion status}
  ii: sys_int_min32_t;                 {32 bit integer}
  fp: real;                            {32 bit IEEE floating point}

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (tk, stat);      {get hex number from command line}
  string_cmline_req_check (stat);      {hex number is required}
  sys_error_abort (stat, '', '', nil, 0);
  string_cmline_end_abort;             {no more command line arguments allowed}

  string_t_int32h (tk, ii, stat);      {convert HEX string to integer}
  sys_error_abort (stat, '', '', nil, 0);
  fp := real(ii);                      {interpret at 32 bit floating point}

  string_f_fp (                        {make string from floating point value}
    tk,                                {output string}
    fp,                                {input value}
    0, 0,                              {no fixed field width for number or exponent}
    7,                                 {min significant digits}
    7,                                 {max digits left of point}
    0,                                 {min digits right of point}
    7,                                 {max digits right of point}
    [string_ffp_exp_eng_k],            {use engineering notation}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  writeln (tk.str:tk.len);
  end.
