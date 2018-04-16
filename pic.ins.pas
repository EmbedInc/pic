{   Public include file for the PIC library.  This library contains routines
*   that deal with Microchip PIC microcontrollers.
}
const
  pic_subsys_k = -44;                  {subsystem ID for the PIC library}

type
  pic_fp24_t = record                  {24 bit floating point format used on PIC}
    b0: int8u_t;                       {least significant mantissa byte}
    b1: int8u_t;                       {most significant mantissa byte}
    b2: int8u_t;                       {sign and exponent byte}
    end;

  pic_fp32f_t = record                 {fast 32 bit floating point used on dsPIC}
    w0: int16u_t;                      {low word, mantissa fraction bits}
    w1: int16u_t;                      {high word, sign bit and exponent}
    end;

  pic_mapsym_t = record                {into about one symbol in MAP file}
    name: string_var80_t;              {symbol name}
    val: int32u_t;                     {symbol value}
    found: boolean;                    {symbol was found in MAP file}
    end;

  pic_mapsym_ar_t =                    {list of MAP file symbols}
    array[1 .. 1] of pic_mapsym_t;
{
*
*   Entry points.
}
function pic_fp24_f_real (             {convert REAL number to PIC FP24}
  in      r: real)                     {input machine REAL value}
  :pic_fp24_t;                         {returned PIC 24 bit floating point number}
  val_param; extern;

function pic_fp24_t_real (             {convert PIC FP24 number to REAL number}
  in      f: pic_fp24_t)               {input PIC 24 bit floating point number}
  :real;                               {returned machine REAL value}
  val_param; extern;

function pic_fp32f_f_real (            {convert machine FP to fast PIC 32 bit}
  in      r: double)                   {the machine floating point value to convert}
  :pic_fp32f_t;                        {fast PIC 32 bit floating point}
  val_param; extern;

function pic_fp32f_t_real (            {convert fast PIC 32 bit FP to real}
  in      f: pic_fp32f_t)              {fast PIC 32 bit floating point}
  :double;                             {native machine floating point}
  val_param; extern;

procedure pic_map_syms_get (           {get values of list of symbols from MPLINK MAP file}
  in out  syms: univ pic_mapsym_ar_t;  {list of symbols to resolve}
  in      nsyms: sys_int_machine_t;    {number of symbols in the list}
  in      fnam: univ string_var_arg_t; {name of MAP file to read}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure pic_map_syms30_get (         {get values of list of symbols from dsPIC MAP file}
  in out  syms: univ pic_mapsym_ar_t;  {list of symbols to resolve}
  in      nsyms: sys_int_machine_t;    {number of symbols in the list}
  in      fnam: univ string_var_arg_t; {name of MAP file to read}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;
