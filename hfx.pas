{   Program HFX <16.16 fixed point HEX value>
*
*   Interpret the command line argument as a 16.16 fixed point hexadecimal
*   number and show its value in normal decimal representation.
}
program hfx;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';

var
  fp: double;                          {the value in floating point}
  fx: string_var32_t;                  {fixed point input value}
  tk: string_var32_t;                  {scratch token}
  i: sys_int_machine_t;                {scratch integer}
  p: string_index_t;                   {TK parse index}
  unsig: boolean;                      {value is explicitly unsigned}
  stat: sys_err_t;                     {completion status code}

begin
  fx.max := size_char(fx.str);         {init local var strings}
  tk.max := size_char(tk.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fx, stat);      {read the fixed point HEX string}
  string_cmline_req_check (stat);      {command line argument is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  string_unpad (fx);                   {delete any trailing blanks}
  if fx.len <= 0 then return;          {nothing entered, nothing to do ?}
  string_upcase (fx);
  p := 1;                              {init parse index}
  unsig := false;                      {init to value is not explicitly unsigned}

  if fx.str[1] = 'U' then begin        {input number explicitly unsigned ?}
    unsig := true;
    p := p + 1;
    end;

  tk.len := 0;                         {init integer string to empty}
  while p <= fx.len do begin           {scan forwards thru the input string}
    if fx.str[p] = '.' then begin      {found the point ?}
      p := p + 1;                      {set index to first fraction digit}
      exit;
      end;
    string_append1 (tk, fx.str[p]);    {one more integer digit}
    p := p + 1;                        {advance to next input string character}
    end;

  string_t_int_max_base (              {convert integer HEX string to binary}
    tk,                                {input hex string}
    16,                                {radix}
    [ string_ti_unsig_k,               {treat input string as unsigned}
      string_ti_null_z_k],             {null string has zero value}
    i,                                 {output integer}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  if (i >= 16#8000) and (not unsig) then begin {negative value ?}
    i := i - 16#10000;                 {make the negative integer value}
    end;
  fp := i;                             {init output value with the integer part}

  string_substr (fx, p, fx.len, tk);   {get fraction digits into TK}
  string_t_int_max_base (              {convert integer HEX string to binary}
    tk,                                {input hex string}
    16,                                {radix}
    [ string_ti_unsig_k,               {interpret input string as unsigned}
      string_ti_null_z_k],             {null string has zero value}
    i,                                 {output integer}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  fp := fp + i / (lshft(1, tk.len * 4)); {add in fraction part}

  writeln (fp:13:5);
  end.
