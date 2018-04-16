{   Routines related to inline-functions.
}
module prepic_func;
define prepic_func_detect;
%include 'prepic.ins.pas';
{
********************************************************************************
*
*   Function PREPIC_FUNC_DETECT (E_P, LIN, P, STAT)
*
*   This routine is called by the script system to check for the start of a new
*   inline function.  E_P points to the script system state.  LIN is the input
*   line.  P is index at which to check for start of function.
*
*   When a function is found, TRUE is returned and P is advanced to immediately
*   after the start of function syntax.  This means P becomes the parse index
*   for extracting the function name.
*
*   When no function is found, FALSE is returned and P is not altered.
*
*   STAT is initialized to indicate to error before this routine is called.
}
function prepic_func_detect (          {look for start of inline function}
  in      e_p: escr_p_t;               {pointer to script system state}
  in      lin: string_var_arg_t;       {input line to look for function in}
  in out  p: string_index_t;           {parse index, look for funct start here}
  out     stat: sys_err_t)             {completion status}
  :boolean;                            {function start was found, P advanced}
  val_param;

var
  ind: sys_int_machine_t;              {our private parse index}

label
  isfunc;

begin
  prepic_func_detect := false;         {init to no function start here}

  if lin.str[p] <> '[' then return;    {not function start syntax}
{
*   The special function start syntax was found.  However, this could be the
*   ASM30 syntax for dereferncing one of the W registers.  These start with
*   the register names W0 to W15, possibly preceeded by "+" or "-" characters.
}
  if lang <> lang_dspic_k then goto isfunc; {not ASM30 source syntax ?}

  ind := p + 1;                        {init our internal parse index}
  while ind <= lin.len do begin        {skip over "+" or "-" characters}
    if not ((lin.str[ind] = '+') or (lin.str[ind] = '-')) then exit; {not + or - ?}
    ind := ind + 1;                    {skip over this character}
    end;                               {back to check next character}

  if ind > lin.len then goto isfunc;   {no room for W ?}
  if (lin.str[ind] <> 'w') and (lin.str[ind] <> 'W') then goto isfunc; {no W here ?}
  ind := ind + 1;                      {skip over W}

  if ind > lin.len then goto isfunc;   {no room for digit ?}
  if                                   {not 0-9 digit ?}
      (ord(lin.str[ind]) < ord('0')) or
      (ord(lin.str[ind]) > ord('9'))
    then goto isfunc;

  return;                              {is ASM30 W indirect sequence}

isfunc:                                {function start found}
  p := p + 1;                          {advance over the function start sequence}
  prepic_func_detect := true;          {indicate function found here}
  end;
