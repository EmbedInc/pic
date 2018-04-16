{   Module that contains the Prepic-specific intrinsic functions.  These are the
*   intrinsic functions available in PREPIC but not in the general ESCR
*   scripting system.
*
*   All the intrinsic function routines have this interface:
*
*      prepic_ifun_<name> (E, STAT)
*
*   The function invocation is in E.FUNARG.  This is the string starting with
*   the function name and including the function arguments.  It does not contain
*   whatever syntax was used to indicate the start and end of the function
*   invocation.  The parse index in FUNARG is set to next character after the
*   delimiter after the function name.  In other words, it is ready to parse the
*   first parameter.  There is no guarantee there are any parameters.  If there
*   are no parameters, then the parse index will be past the end of the string.
*
*   The function routine must write the expansion of the function to E.FUNRET.
*   This string has been initialized to empty.
*
*   STAT has been initialized to indicate no error.  If a error is encountered,
*   STAT must be set accordingly.
}
module prepic_ifun;
define prepic_ifun_fp24i;
define prepic_ifun_fp24_int;
define prepic_ifun_fp32f;
define prepic_ifun_fp32f_int;
%include 'prepic.ins.pas';
{
********************************************************************************
*
*   FP24I val
*
*   Convert the numeric value VAL to Embed Inc PIC 24 bit floating point and
*   return the result as a 6 character hex integer in native MPASM format.  For
*   example:
*
*     [FP24I 3.14159] --> h'419220'
*
*   This function does not return a string data byte, but the raw characters of
*   a hexadecimal value in native assembler format.
}
procedure prepic_ifun_fp24i (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  val: sys_fp_max_t;                   {VAL parameter}
  fp24: pic_fp24_t;                    {PIC 24 bit floating point}
  tk: string_var32_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  if not escr_ifn_get_fp (e, val, stat) then begin {get VAL parameter}
    escr_ifn_stat_required (e, stat);
    return;
    end;

  fp24 := pic_fp24_f_real (val);       {make PIC floating point}

  escr_ifn_ret_charsp (e, 'h'''(0));   {return starting chars}
  string_f_int8h (tk, fp24.b2);        {high byte}
  escr_ifn_ret_chars (e, tk);
  string_f_int8h (tk, fp24.b1);        {middle byte}
  escr_ifn_ret_chars (e, tk);
  string_f_int8h (tk, fp24.b0);        {low byte}
  escr_ifn_ret_chars (e, tk);
  escr_ifn_ret_charsp (e, ''''(0));    {ending characters}
  end;
{
********************************************************************************
*
*   FP24_INT val
*
*   Return the integer value of the 24 bits resulting from VAL expressed in
*   Embed Inc PIC 24 bit floating point.  For example:
*
*     [FP24I 3.14159] --> 4297248
}
procedure prepic_ifun_fp24_int (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  val: sys_fp_max_t;                   {VAL argument}
  fp24: pic_fp24_t;                    {PIC 24 bit floating point}
  resi: sys_int_max_t;                 {returned integer value}

begin
  if not escr_ifn_get_fp (e, val, stat) then begin {get VAL parameter}
    escr_ifn_stat_required (e, stat);
    return;
    end;

  fp24 := pic_fp24_f_real (val);       {make PIC floating point}

  resi :=                              {assemble the integer value}
    lshft(fp24.b2, 16) ! lshft(fp24.b1, 8) ! fp24.b0;
  escr_ifn_ret_int (e, resi);          {return it}
  end;
{
********************************************************************************
*
*   FP32F val
*
*   Convert the numeric value VAL to Embed Inc dsPIC 32 bit fast floating point
*   and return the result as a 8 character hex integer in native ASM30 format.
*   For example:
*
*     [FP32F -7.5] --> 0xC002E000
*
*   This function does not return a string data byte, but the raw characters of
*   a hexadecimal value in native assembler format.
}
procedure prepic_ifun_fp32f (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  val: sys_fp_max_t;                   {VAL parameter}
  fp32f: pic_fp32f_t;                  {dsPIC 32 bit floating point}
  tk: string_var32_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  if not escr_ifn_get_fp (e, val, stat) then begin {get VAL parameter}
    escr_ifn_stat_required (e, stat);
    return;
    end;

  fp32f := pic_fp32f_f_real (val);     {make PIC floating point}

  escr_ifn_ret_charsp (e, '0x'(0));    {return starting chars}
  string_f_int16h (tk, fp32f.w1);      {high word}
  escr_ifn_ret_chars (e, tk);
  string_f_int16h (tk, fp32f.w0);      {low word}
  escr_ifn_ret_chars (e, tk);
  end;
{
********************************************************************************
*
*   FP32F_INT val
*
*   Returns the integer value of the 32 bits resulting from VAL expressed in
*   Embed Inc dsPIC 32 bit fast floating point.  For example:
*
*     [FP32F -7.5] --> -1073553408
}
procedure prepic_ifun_fp32f_int (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  val: sys_fp_max_t;                   {VAL parameter}
  fp32f: pic_fp32f_t;                  {dsPIC 32 bit floating point}
  resi: sys_int_max_t;                 {returned integer value}

begin
  if not escr_ifn_get_fp (e, val, stat) then begin {get VAL parameter}
    escr_ifn_stat_required (e, stat);
    return;
    end;

  fp32f := pic_fp32f_f_real (val);     {make PIC floating point}

  resi :=                              {assemble the integer value}
    lshft(fp32f.w1, 16) ! fp32f.w0;
  escr_ifn_ret_int (e, resi);          {return it}
  end;
