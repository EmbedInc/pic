{   Program HF32 hexval
*
*   This command line argument is a 32 bit hexedecimal value.  This will be
*   interpreted as dsPIC fast 32 bit floating point and its result written to
*   standard output.
}
program hf32;
%include 'base.ins.pas';
%include 'pic.ins.pas';

var
  h: sys_int_min32_t;                  {HEX value as integer}
  fp: pic_fp32f_t;                     {dsPIC fast 32 bit floating point}
  d: double;                           {FP in native format}
  tk:                                  {scratch token}
    %include '(cog)lib/string32.ins.pas';
  stat: sys_err_t;                     {completion status}

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (tk, stat);      {get the command line argument}
  string_cmline_req_check (stat);      {this argument is required}
  string_cmline_end_abort;             {no more command line arguments allowed}

  string_t_int32h (tk, h, stat);       {make integer from the command line arg}
  sys_error_abort (stat, '', '', nil, 0);
  fp.w0 := h & 16#FFFF;                {set low word of FP}
  fp.w1 := rshft (h, 16) & 16#FFFF;    {set high word}
  d := pic_fp32f_t_real (fp);          {convert to native floating point}

  string_f_fp_free (tk, d, 6);         {make FP string}
  writeln (tk.str:tk.len);             {write it to standard output}
  end.

