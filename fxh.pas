{   Program FXH <numeric value>
*
*   Show the PIC 16.16 fixed representation in hexadecimal of the command
*   line parameter value.
}
program fxh;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';

var
  fp: double;                          {the input value in floating point}
  i32: integer32;
  tk: string_var32_t;                  {scratch token}
  stat: sys_err_t;                     {completion status code}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token_fp2 (fp, stat);  {get floating point value from command line}
  string_cmline_req_check (stat);      {command line argument is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  i32 := round(fp * 65536.0);          {make fixed point number}

  string_f_int_max_base (              {make HEX string of integer part}
    tk,                                {output string}
    rshft(i32, 16),                    {input integer}
    16,                                {radix}
    4,                                 {field width}
    [string_fi_unsig_k],               {treat the input number as unsigned}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  write (tk.str:tk.len);

  string_f_int_max_base (              {make HEX string of fraction part}
    tk,                                {output string}
    i32 & 16#FFFF,                     {input integer}
    16,                                {radix}
    4,                                 {field width}
    [ string_fi_unsig_k,               {treat the input number as unsigned}
      string_fi_leadz_k],              {pad field with leading zeros}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  writeln ('.', tk.str:tk.len);
  end.
