{   FP32FH fp
*
*   Convert the floating point value FP to Embed dsPIC 32 bit fast floating
*   point and show the resulting 32 bits in hexadecimal.
}
program fp32fh;
%include 'base.ins.pas';
%include 'pic.ins.pas';

var
  fp32f: pic_fp32f_t;                  {floating point in FP32F format}
  r: double;                           {floating point in native format}
  tk:                                  {scratch token}
    %include '(cog)lib/string16.ins.pas';
  stat: sys_err_t;                     {completion status}

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token_fp2 (r, stat);   {get FP value}
  string_cmline_req_check (stat);
  string_cmline_end_abort;             {nothing more allowed on the command line}

  fp32f := pic_fp32f_f_real (r);       {convert to FP32F format}
  string_f_int16 (tk, fp32f.w1);
  write (tk.str:tk.len);
  string_f_int16 (tk, fp32f.w0);
  writeln (tk.str:tk.len);
  end.



