{   Program HFP <24 bit HEX integer>
*
*   Interpret command line argument as PIC 24 bit floating point and show
*   its value.
}
program hfp;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'pic.ins.pas';

var
  fp: real;                            {the floating point value}
  i: sys_int_max_t;                    {scratch integer}
  picfp: pic_fp24_t;                   {floating point value in PIC 24 bit format}
  tk: string_var32_t;                  {scratch token}
  stat: sys_err_t;                     {completion status code}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (tk, stat);      {get the command line argument string}
  string_cmline_req_check (stat);      {command line argument is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  string_t_int_max_base (              {convert argument string to integer}
    tk,                                {input string}
    16,                                {radix}
    [string_ti_unsig_k],               {the output number is unsigned}
    i,                                 {output integer}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  picfp.b0 := i & 255;                 {set PIC 24 bit FP number}
  picfp.b1 := rshft(i, 8) & 255;
  picfp.b2 := rshft(i, 16) & 255;
  fp := pic_fp24_t_real (picfp);       {convert to native floating point format}

  string_f_fp_free (tk, fp, 6);        {make floating point string}
  writeln (tk.str:tk.len);             {write floating point string to output}
  end.
