{   Program FPH <FP value>
*
*   Show PIC 24 bit floating point hexadecimal representation of the floating
*   point value.
}
program fph;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'pic.ins.pas';

var
  fp: real;                            {the floating point value}
  picfp: pic_fp24_t;                   {floating point value in PIC 24 bit format}
  tk: string_var32_t;                  {scratch token}
  stat: sys_err_t;                     {completion status code}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token_fpm (fp, stat);  {get floating point value from command line}
  string_cmline_req_check (stat);      {command line argument is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  picfp := pic_fp24_f_real (fp);       {convert to PIC 24 bit FP format}

  string_f_int_max_base (              {make HEX string from PIC number}
    tk,                                {output string}
    lshft(picfp.b2, 16) ! lshft(picfp.b1, 8) ! picfp.b0, {input integer}
    16,                                {radix}
    6,                                 {field width}
    [ string_fi_leadz_k,               {write leading zeros to fill field}
      string_fi_unsig_k],              {treat the input number as unsigned}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  writeln (tk.str:tk.len);             {write converted value to standard output}
  end.
