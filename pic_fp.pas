{   Module of routines that deal with PIC floating point numbers.
}
module pic_fp;
define pic_fp24_f_real;
define pic_fp24_t_real;
define pic_fp32f_f_real;
define pic_fp32f_t_real;
%include 'pic2.ins.pas';
{
********************************************************************************
*
*   Subroutine PIC_FP24_F_REAL (R)
*
*   Convert the input real number into a PIC 24 bit floating point number.
}
function pic_fp24_f_real (             {convert REAL number to PIC FP24}
  in      r: real)                     {input machine REAL value}
  :pic_fp24_t;                         {returned PIC 24 bit floating point number}
  val_param;

var
  m: real;                             {mantissa value}
  im: sys_int_conv24_t;                {integer mantissa value}
  exp: sys_int_machine_t;              {FP24 EXP field}
  f: pic_fp24_t;                       {PIC 24 bit floating point number}
  pos: boolean;                        {TRUE for positive value}

label
  zero, leave;

begin
  if r = 0.0 then goto zero;           {handle special case of zero}

  pos := r >= 0.0;                     {set flag for input value sign}
  m := abs(r);                         {make magnitude of the input value}

  exp := 64;                           {init EXP for exponent of 0}
  if m >= 1.0
    then begin                         {at this EXP value or higher}
      while m >= 2.0 do begin          {need to increase EXP value ?}
        exp := exp + 1;                {indicate next higher exponent}
        m := m / 2.0;                  {make mantissa value for this new exponent}
        end;                           {back to test this new exponent}
      end
    else begin                         {EXP needs to be lower}
      repeat
        exp := exp - 1;                {indicate next lower exponent}
        m := m * 2.0;                  {make mantissa value for this new exponent}
        until m >= 1.0;                {back until reached final exponent value}
      end
    ;
{
*   M is the mantissa value from 1.0 up to but not including 2.0.  EXP
*   is the exponent value in the offset 64 format.
*
*   Now round to the integer mantissa value and do any final adjust of the
*   exponent that might be needed due to rounding up.
}
  im := round((m - 1.0) * 65536.0);    {make initial integer mantissa value}
  if im > 65535 then begin             {rounded up to next exponent ?}
    im := rshft(im, 1);                {adjust for next higher exponent}
    exp := exp + 1;
    end;
{
*   IM is the integer mantissa value and is within the correct range.
*   EXP is the corresponding EXP field value with the offset of 64.
*
*   Now range check EXP and return the maximum or minimum magnitude
*   numbers if EXP is outside the representable range.  EXP must be in
*   the range of 1 to 127.  EXP = 0 is reserved for the special case of 0.0.
}
  if exp > 127 then begin              {too large, pass back max magnitude number}
    f.b0 := 255;                       {create maximum positive number}
    f.b1 := 255;
    if pos
      then f.b2 := 127                 {sign is positive}
      else f.b2 := 255;                {sign is negative}
    goto leave;                        {pass back final value and return}
    end;

  if exp < 1 then begin                {too small, pass back minimum magnitude}
zero:
    f.b0 := 0;                         {make FP24 zero}
    f.b1 := 0;
    f.b2 := 0;
    goto leave;                        {pass back final value and return}
    end;
{
*   IM, EXP, and POS are all set.  Now assemble the final FP24 number in F
*   and return it.
}
  f.b0 := im & 255;                    {mantissa low byte}
  f.b1 := rshft(im, 8) & 255;          {mantissa high byte}
  if pos                               {set sign bit}
    then f.b2 := 0
    else f.b2 := 128;
  f.b2 := f.b2 ! exp;                  {merge in exponent}

leave:                                 {common exit point}
  pic_fp24_f_real := f;                {pass back the final value}
  end;
{
********************************************************************************
*
*   Subroutine PIC_FP24_T_REAL (F)
*
*   Convert the input PIC 24 bit floating point number into a real number.
}
function pic_fp24_t_real (             {convert PIC FP24 number to REAL number}
  in      f: pic_fp24_t)               {input PIC 24 bit floating point number}
  :real;                               {returned machine REAL value}
  val_param;

var
  r: real;                             {real value being built}
  exp: sys_int_machine_t;              {EXP field value}
  e: real;                             {exponent resulting from EXP}

begin
  exp := f.b2 & 127;                   {extract exponent field value}

  if exp = 0 then begin                {check for special case of zero}
    pic_fp24_t_real := 0.0;
    return;
    end;

  r :=                                 {make 1.0 up to 2.0 mantissa value}
    (65536 + f.b1 * 256 + f.b0) / 65536.0;
  e := 2.0 ** (exp - 64);              {make multiplier resulting from exponent}
  r := r * e;                          {apply exponent multiplier}
  if (f.b2 & 128) <> 0 then begin      {value is negative ?}
    r := -r;
    end;
  pic_fp24_t_real := r;                {pass back final value}
  end;
{
********************************************************************************
*
*   Function PIC_FP32F_T_REAL (F)
*
*   Convert the fast PIC 32 bit floating point value F to REAL.
}
function pic_fp32f_t_real (            {convert fast PIC 32 bit FP to real}
  in      f: pic_fp32f_t)              {fast PIC 32 bit floating point}
  :double;                             {native machine floating point}
  val_param;

var
  r: double;                           {output value being built}
  ii: sys_int_machine_t;               {scratch integer}
  exp: double;                         {value resulting from exponent}

begin
  if (f.w0 = 0) and (f.w1 = 0) then begin {special case of all 0 ?}
    pic_fp32f_t_real := 0.0;           {pass back 0}
    return;
    end;

  r := (f.w0 + 65536) / 65536.0;       {make value from mantissa only}

  ii := f.w1 & 32767;                  {extract just the exponent field}
  ii := ii - 16384;                    {make actual power of 2 exponent}
  ii := max(-255, min(255, ii));
  exp := 2.0 ** ii;                    {make the exponent scale factor}
  r := r * exp;                        {apply the exponent scale factor}

  if (f.w1 & 32768) <> 0 then begin    {value is negative ?}
    r := -r;
    end;

  pic_fp32f_t_real := r;               {pass back final result}
  end;
{
********************************************************************************
*
*   Function PIC_FP32F_F_REAL (R)
*
*   Conver the machine floating point value R to fast PIC 32 bit floating point.
}
function pic_fp32f_f_real (            {convert machine FP to fast PIC 32 bit}
  in      r: double)                   {the machine floating point value to convert}
  :pic_fp32f_t;                        {fast PIC 32 bit floating point}
  val_param;

var
  m: double;                           {local corruptable copy of input value}
  f: pic_fp32f_t;                      {PIC floating point}
  e: sys_int_machine_t;                {exponent value}
  ii: sys_int_machine_t;               {scratch integer}

label
  have_mag, leave, zero;

begin
  if r = 0.0 then goto zero;           {handle special case of zero}

  m := abs(r);                         {get magnitude of the input value}
{
*   Find the exponent value.
}
  e := 0;                              {init exponent value}
  if m >= 1.0
    then begin                         {exponent 0 or higher}
      while m >= 2.0 do begin          {back here until 1.0 <= number < 2.0}
        e := e + 1;
        m := m / 2.0;
        end;
      end
    else begin                         {exponent will be negative}
      repeat
        e := e - 1;
        m := m * 2.0;
        until m >= 1.0;
      end
    ;
{
*   Set the mantissa.
}
  ii := round((m - 1.0) * 65536.0);    {make initial mantissa field value}
  if ii > 65535 then begin             {rounded up to next exponent ?}
    e := e + 1;                        {bump exponent up by 1}
    ii := rshft(ii, 1);                {adjust mantissa to the exponent change}
    end;

  f.w0 := ii;                          {set returned mantissa field}
{
*   Set the exponent field.
}
  e := e + 16384;                      {convert exponent to output format}
  if e < 0 then goto zero;             {exponent too small, return zero ?}
  if e > 32767 then begin              {exponent too large ?}
    f.w1 := 16#7FFF;                   {set to largest representable magnitude}
    f.W0 := 16#FFFF;
    goto have_mag;
    end;

  f.w1 := e;                           {set exponent field in output number}
{
*   Set the returned sign bit.
}
have_mag:
  if r < 0.0 then begin                {input number is negative ?}
    f.w1 := f.w1 ! 16#8000;            {set the output number sign bit}
    end;

leave:
  pic_fp32f_f_real := f;               {pass back result}
  return;

zero:                                  {return zero}
  f.w0 := 0;
  f.w1 := 0;
  goto leave;
  end;
