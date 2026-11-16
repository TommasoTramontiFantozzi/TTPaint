{ SVG snippets with parameters.

  A snippet may begin with parameter lines, then the SVG:

    @param Scale = 10 [2, 50, 0.5] "Pixels per tick"
    @param Ticks = 20 [1, 200, 1] "Number of ticks"
    @param Back = #f6e7a6 "Background colour"
    <svg ...> ... </svg>

  Inside the SVG, {expression} is replaced by its value, {for i = a to b} ... {end} repeats what is
  inside (i takes a, a+1 ... b; "step s" is optional) and {if condition} ... {else} ... {end} keeps one
  of the two parts. In expressions: numbers, parameters, loop variables, + - * / mod, ( ), comparisons
  (= <> < > <= >=), and / or / not, pi, and the functions sin cos tan (degrees), sqrt, abs, min, max,
  round, floor, ceil. A colour parameter (value written #rrggbb) is replaced by #rrggbb where {Name} is
  used, and is changed with a colour button.

  A text parameter holds a table (CSV, one row per line, separated by , ; or a tab) that the user pastes:

    @paramtext Data "CSV data"

  The table is read with rows(Data), cols(Data), hdr(Data) (1 when the first row is a header),
  num(Data, row, col) and isnum(Data, row, col) (rows and columns count from 0), sum(Data, col),
  csum(Data, col, row) (the sum of the rows before row), maxlen(Data, col) (characters of the longest cell), tlen(Data, row, col) (characters of a cell), vmin(Data, col) and vmax(Data, col) (col -1:
  all the columns from the second on) and nicestep(range, n) (a round step that cuts range in about n).
  {cell(Data, row, col)} is the text of a cell, {hsl(h, s, l)} a colour (h in degrees, s and l in
  percent) and {let name = expression} keeps a value for the rest of the snippet. }
unit ttsnip;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazUTF8;

type
  TSnipParam = record
    Name, Caption: string;
    Def, Min, Max, Step: Double;
    IsColor: Boolean;                    // the value is a colour: 0xRRGGBB
    IsText: Boolean;                     // the value is a text (a table); it is kept apart, see TSnipTexts
  end;
  TSnipParams = array of TSnipParam;
  TSnipValues = array of Double;
  TSnipTexts = array of string;          // the texts of the parameters, one for every parameter (empty if it is not a text)

// the parameter lines and the rest of the text
function SnipSplit(const src: string; out params: TSnipParams; out body, err: string): Boolean;
function SnipDefaults(const params: TSnipParams): TSnipValues;
// the SVG text for these values of the parameters (missing values: the defaults)
function SnipExpand(const src: string; const values: TSnipValues; out svg, err: string): Boolean;
function SnipExpandT(const src: string; const values: TSnipValues; const texts: TSnipTexts; out svg, err: string): Boolean;
// a snippet as stored in an object: source, values, the stretch of its SVG and the size of its box when it was made
function SnipEncode(const src: string; const values: TSnipValues; fx, fy, cw, ch: Double): string;
function SnipDecode(const enc: string; out src: string; out values: TSnipValues; out fx, fy, cw, ch: Double): Boolean;
// the same with the texts of the parameters
function SnipEncodeT(const src: string; const values: TSnipValues; const texts: TSnipTexts; fx, fy, cw, ch: Double): string;
function SnipDecodeT(const enc: string; out src: string; out values: TSnipValues; out texts: TSnipTexts; out fx, fy, cw, ch: Double): Boolean;

implementation

uses
  Math, StrUtils, base64;

type
  ESnip = class(Exception);

var
  FS: TFormatSettings;

{ ---------- variables ---------- }

type
  TCsvRow = array of string;
  TCsvTable = record
    Rows: array of TCsvRow;
    Delim: Char;
  end;

  TScope = class
    Names: array of string;
    Vals: array of Double;
    Colors: array of string;             // names of the colour parameters
    Tables: array of TCsvTable;          // the text parameters; the value of the name is the number of the table
    procedure SetVar(const n: string; v: Double);
    procedure AddText(const n, text: string);
    function IsColor(const n: string): Boolean;
    function Find(const n: string; out v: Double): Boolean;
  end;

procedure TScope.SetVar(const n: string; v: Double);
var
  i: Integer;
begin
  for i := 0 to High(Names) do
    if SameText(Names[i], n) then
    begin
      Vals[i] := v;
      Exit;
    end;
  SetLength(Names, Length(Names) + 1);
  SetLength(Vals, Length(Vals) + 1);
  Names[High(Names)] := n;
  Vals[High(Vals)] := v;
end;

{ ---------- tables (CSV) ---------- }

// the fields of one line; a field may be in double quotes (then it can hold the delimiter, and "" is a quote)
function SplitCsvLine(const line: string; delim: Char): TCsvRow;
var
  i, n: Integer;
  cur: string;
  q: Boolean;
begin
  Result := nil;
  cur := '';
  q := False;
  i := 1;
  n := Length(line);
  while i <= n do
  begin
    if q then
    begin
      if line[i] = '"' then
      begin
        if (i < n) and (line[i + 1] = '"') then
        begin
          cur := cur + '"';
          Inc(i);
        end
        else q := False;
      end
      else cur := cur + line[i];
    end
    else if line[i] = '"' then q := True
    else if line[i] = delim then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Trim(cur);
      cur := '';
    end
    else cur := cur + line[i];
    Inc(i);
  end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Trim(cur);
end;

function ParseCsv(const text: string): TCsvTable;
var
  lines: TStringList;
  i, nc, nsc, nt: Integer;
  first: string;
begin
  Result.Rows := nil;
  Result.Delim := ',';
  lines := TStringList.Create;
  try
    lines.Text := StringReplace(text, #13, '', [rfReplaceAll]);
    first := '';
    for i := 0 to lines.Count - 1 do
      if Trim(lines[i]) <> '' then
      begin
        first := lines[i];
        Break;
      end;
    // the delimiter that the first line uses most
    nc := 0;
    nsc := 0;
    nt := 0;
    for i := 1 to Length(first) do
      case first[i] of
        ',': Inc(nc);
        ';': Inc(nsc);
        #9: Inc(nt);
      end;
    if (nt >= nsc) and (nt >= nc) and (nt > 0) then Result.Delim := #9
    else if (nsc >= nc) and (nsc > 0) then Result.Delim := ';';
    for i := 0 to lines.Count - 1 do
      if Trim(lines[i]) <> '' then
      begin
        SetLength(Result.Rows, Length(Result.Rows) + 1);
        Result.Rows[High(Result.Rows)] := SplitCsvLine(lines[i], Result.Delim);
      end;
  finally
    lines.Free;
  end;
end;

// the number in a cell (a decimal comma is accepted when the delimiter is not the comma; a final % is ignored)
function CellNum(const t: TCsvTable; r, c: Integer; out v: Double): Boolean;
var
  x: string;
begin
  v := 0;
  Result := False;
  if (r < 0) or (r > High(t.Rows)) or (c < 0) or (c > High(t.Rows[r])) then Exit;
  x := t.Rows[r][c];
  if (x <> '') and (x[Length(x)] = '%') then Delete(x, Length(x), 1);
  x := Trim(x);
  if x = '' then Exit;
  if TryStrToFloat(x, v, FS) then Exit(True);
  if t.Delim <> ',' then
  begin
    x := StringReplace(x, ',', '.', []);
    if TryStrToFloat(x, v, FS) then Exit(True);
  end;
  v := 0;
end;

procedure TScope.AddText(const n, text: string);
begin
  SetLength(Tables, Length(Tables) + 1);
  Tables[High(Tables)] := ParseCsv(text);
  SetVar(n, High(Tables));
end;

function TScope.IsColor(const n: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(Colors) do
    if SameText(Colors[i], n) then Exit(True);
end;

function TScope.Find(const n: string; out v: Double): Boolean;
var
  i: Integer;
begin
  Result := False;
  v := 0;
  for i := 0 to High(Names) do
    if SameText(Names[i], n) then
    begin
      v := Vals[i];
      Exit(True);
    end;
end;

{ ---------- expressions ---------- }

type
  TExpr = class
    S: string;
    P: Integer;
    Scope: TScope;
    function Parse(const text: string; sc: TScope): Double;
    function ParseIn: Double;            // an expression inside a longer text: stops at what is not part of it
    procedure Skip;
    function PeekWord: string;
    function Orr: Double;
    function Andd: Double;
    function Cmp: Double;
    function Add: Double;
    function Mul: Double;
    function Unary: Double;
    function Primary: Double;
    function TableFunc(const w: string; const args: array of Double; out res: Double): Boolean;
  end;

function IsIdStart(c: Char): Boolean;
begin
  Result := c in ['A'..'Z', 'a'..'z', '_'];
end;

function IsIdChar(c: Char): Boolean;
begin
  Result := c in ['A'..'Z', 'a'..'z', '_', '0'..'9'];
end;

procedure TExpr.Skip;
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do Inc(P);
end;

// the word at the current position, without moving
function TExpr.PeekWord: string;
var
  q: Integer;
begin
  Skip;
  q := P;
  Result := '';
  if (q <= Length(S)) and IsIdStart(S[q]) then
  begin
    while (q <= Length(S)) and IsIdChar(S[q]) do Inc(q);
    Result := LowerCase(Copy(S, P, q - P));
  end;
end;

function TExpr.Parse(const text: string; sc: TScope): Double;
begin
  S := text;
  P := 1;
  Scope := sc;
  Result := ParseIn;
  Skip;
  if P <= Length(S) then raise ESnip.Create('unexpected "' + Copy(S, P, 12) + '" in "' + text + '"');
end;

function TExpr.ParseIn: Double;
begin
  Result := Orr;
end;

function TExpr.Orr: Double;
var
  b: Double;
begin
  Result := Andd;
  while PeekWord = 'or' do
  begin
    Inc(P, 2);
    b := Andd;
    if (Result <> 0) or (b <> 0) then Result := 1 else Result := 0;
  end;
end;

function TExpr.Andd: Double;
var
  b: Double;
begin
  Result := Cmp;
  while PeekWord = 'and' do
  begin
    Inc(P, 3);
    b := Cmp;
    if (Result <> 0) and (b <> 0) then Result := 1 else Result := 0;
  end;
end;

function TExpr.Cmp: Double;
var
  b: Double;
  op: string;
begin
  Result := Add;
  Skip;
  op := '';
  if P <= Length(S) then
  begin
    if Copy(S, P, 2) = '<=' then op := '<='
    else if Copy(S, P, 2) = '>=' then op := '>='
    else if Copy(S, P, 2) = '<>' then op := '<>'
    else if Copy(S, P, 2) = '==' then op := '=='
    else if S[P] in ['<', '>', '='] then op := S[P];
  end;
  if op = '' then Exit;
  Inc(P, Length(op));
  if op = '==' then op := '=';
  b := Add;
  if op = '=' then Result := Ord(Abs(Result - b) < 1e-9)
  else if op = '<>' then Result := Ord(Abs(Result - b) >= 1e-9)
  else if op = '<' then Result := Ord(Result < b - 1e-9)
  else if op = '>' then Result := Ord(Result > b + 1e-9)
  else if op = '<=' then Result := Ord(Result <= b + 1e-9)
  else Result := Ord(Result >= b - 1e-9);
end;

function TExpr.Add: Double;
begin
  Result := Mul;
  while True do
  begin
    Skip;
    if (P <= Length(S)) and (S[P] = '+') then
    begin
      Inc(P);
      Result := Result + Mul;
    end
    else if (P <= Length(S)) and (S[P] = '-') then
    begin
      Inc(P);
      Result := Result - Mul;
    end
    else Break;
  end;
end;

function TExpr.Mul: Double;
var
  b: Double;
begin
  Result := Self.Unary();
  while True do
  begin
    Skip;
    if (P <= Length(S)) and (S[P] = '*') then
    begin
      Inc(P);
      Result := Result * Unary;
    end
    else if (P <= Length(S)) and (S[P] = '/') then
    begin
      Inc(P);
      b := Unary;
      if b = 0 then raise ESnip.Create('division by zero in "' + S + '"');
      Result := Result / b;
    end
    else if PeekWord = 'mod' then
    begin
      Inc(P, 3);
      b := Unary;
      if b = 0 then raise ESnip.Create('mod by zero in "' + S + '"');
      Result := Result - b * Floor(Result / b);
    end
    else Break;
  end;
end;

function TExpr.Unary: Double;
begin
  Skip;
  if (P <= Length(S)) and (S[P] = '-') then
  begin
    Inc(P);
    Result := -Self.Unary();
  end
  else if (P <= Length(S)) and (S[P] = '+') then
  begin
    Inc(P);
    Result := Self.Unary();
  end
  else if PeekWord = 'not' then
  begin
    Inc(P, 3);
    Result := Ord(Self.Unary() = 0);
  end
  else Result := Primary;
end;

// the best round step (1, 2 or 5 times a power of ten) that cuts a range into about n parts
function NiceStep(range: Double; n: Double): Double;
var
  st, e, f: Double;
begin
  if (range <= 0) or (n < 1) then Exit(1);
  st := range / n;
  e := Power(10, Floor(Log10(st)));
  f := st / e;
  if f <= 1 then f := 1
  else if f <= 2 then f := 2
  else if f <= 5 then f := 5
  else f := 10;
  Result := f * e;
end;

function TExpr.TableFunc(const w: string; const args: array of Double; out res: Double): Boolean;
var
  ti, r, c, c0, c1: Integer;
  tb: TCsvTable;
  v, acc: Double;
  any: Boolean;
begin
  res := 0;
  Result := True;
  if w = 'nicestep' then
  begin
    if Length(args) <> 2 then raise ESnip.Create('nicestep needs (range, parts)');
    res := NiceStep(args[0], args[1]);
    Exit;
  end;
  if not ((w = 'rows') or (w = 'cols') or (w = 'hdr') or (w = 'num') or (w = 'isnum') or (w = 'sum') or
    (w = 'vmin') or (w = 'vmax') or (w = 'csum') or (w = 'maxlen') or (w = 'tlen')) then Exit(False);
  if Length(args) < 1 then raise ESnip.Create('"' + w + '" needs a text parameter');
  ti := Round(args[0]);
  if (ti < 0) or (ti > High(Scope.Tables)) then raise ESnip.Create('the first argument of "' + w + '" must be a text parameter');
  tb := Scope.Tables[ti];
  if w = 'rows' then res := Length(tb.Rows)
  else if w = 'cols' then
  begin
    for r := 0 to High(tb.Rows) do
      if Length(tb.Rows[r]) > res then res := Length(tb.Rows[r]);
  end
  else if w = 'hdr' then
  begin
    if Length(tb.Rows) > 0 then
    begin
      if Length(tb.Rows[0]) <= 1 then
        res := Ord((Length(tb.Rows[0]) = 1) and (tb.Rows[0][0] <> '') and not CellNum(tb, 0, 0, v))
      else
        for c := 1 to High(tb.Rows[0]) do
          if (tb.Rows[0][c] <> '') and not CellNum(tb, 0, c, v) then res := 1;
    end;
  end
  else if w = 'maxlen' then
  begin
    // the number of characters of the longest text of a column (for the width of a column of a table)
    if Length(args) <> 2 then raise ESnip.Create('"maxlen" needs (table, column)');
    c := Round(args[1]);
    for r := 0 to High(tb.Rows) do
      if (c >= 0) and (c <= High(tb.Rows[r])) and (UTF8Length(tb.Rows[r][c]) > res) then res := UTF8Length(tb.Rows[r][c]);
  end
  else if w = 'tlen' then
  begin
    // the number of characters of one cell
    if Length(args) <> 3 then raise ESnip.Create('"tlen" needs (table, row, column)');
    r := Round(args[1]);
    c := Round(args[2]);
    if (r >= 0) and (r <= High(tb.Rows)) and (c >= 0) and (c <= High(tb.Rows[r])) then res := UTF8Length(tb.Rows[r][c]);
  end
  else if (w = 'num') or (w = 'isnum') then
  begin
    if Length(args) <> 3 then raise ESnip.Create('"' + w + '" needs (table, row, column)');
    if w = 'num' then
    begin
      if not CellNum(tb, Round(args[1]), Round(args[2]), v) then v := 0;
      res := v;
    end
    else res := Ord(CellNum(tb, Round(args[1]), Round(args[2]), v));
  end
  else
  begin
    if Length(args) < 2 then raise ESnip.Create('"' + w + '" needs (table, column)');
    c := Round(args[1]);
    if c < 0 then
    begin
      c0 := 1;
      c1 := 0;
      for r := 0 to High(tb.Rows) do
        if Length(tb.Rows[r]) - 1 > c1 then c1 := Length(tb.Rows[r]) - 1;
    end
    else
    begin
      c0 := c;
      c1 := c;
    end;
    r := High(tb.Rows);
    if (w = 'csum') then
    begin
      if Length(args) <> 3 then raise ESnip.Create('csum needs (table, column, row)');
      r := Min(r, Round(args[2]) - 1);
    end;
    acc := 0;
    any := False;
    for ti := 0 to r do
      for c := c0 to c1 do
        if CellNum(tb, ti, c, v) then
        begin
          if (w = 'sum') or (w = 'csum') then acc := acc + v
          else if not any then acc := v
          else if w = 'vmin' then acc := Min(acc, v)
          else acc := Max(acc, v);
          any := True;
        end;
    res := acc;
  end;
end;

function TExpr.Primary: Double;
var
  q: Integer;
  w: string;
  args: array of Double;
  v: Double;
begin
  Skip;
  if P > Length(S) then raise ESnip.Create('the expression "' + S + '" is incomplete');
  if S[P] = '(' then
  begin
    Inc(P);
    Result := Orr;
    Skip;
    if (P > Length(S)) or (S[P] <> ')') then raise ESnip.Create('missing ")" in "' + S + '"');
    Inc(P);
    Exit;
  end;
  if S[P] in ['0'..'9', '.'] then
  begin
    q := P;
    while (q <= Length(S)) and (S[q] in ['0'..'9', '.']) do Inc(q);
    if not TryStrToFloat(Copy(S, P, q - P), Result, FS) then
      raise ESnip.Create('bad number "' + Copy(S, P, q - P) + '"');
    P := q;
    Exit;
  end;
  if IsIdStart(S[P]) then
  begin
    q := P;
    while (q <= Length(S)) and IsIdChar(S[q]) do Inc(q);
    w := LowerCase(Copy(S, P, q - P));
    P := q;
    Skip;
    if (P <= Length(S)) and (S[P] = '(') then
    begin
      Inc(P);
      SetLength(args, 0);
      Skip;
      if (P <= Length(S)) and (S[P] = ')') then Inc(P)
      else
        while True do
        begin
          SetLength(args, Length(args) + 1);
          args[High(args)] := Orr;
          Skip;
          if (P <= Length(S)) and (S[P] = ',') then Inc(P)
          else if (P <= Length(S)) and (S[P] = ')') then
          begin
            Inc(P);
            Break;
          end
          else raise ESnip.Create('missing ")" in "' + S + '"');
        end;
      if TableFunc(w, args, Result) then Exit;
      if (w = 'min') and (Length(args) = 2) then Result := Min(args[0], args[1])
      else if (w = 'max') and (Length(args) = 2) then Result := Max(args[0], args[1])
      else if Length(args) = 1 then
      begin
        if w = 'sin' then Result := Sin(DegToRad(args[0]))
        else if w = 'cos' then Result := Cos(DegToRad(args[0]))
        else if w = 'tan' then Result := Tan(DegToRad(args[0]))
        else if w = 'sqrt' then
        begin
          if args[0] < 0 then raise ESnip.Create('sqrt of a negative number');
          Result := Sqrt(args[0]);
        end
        else if w = 'abs' then Result := Abs(args[0])
        else if w = 'round' then Result := Round(args[0])
        else if w = 'floor' then Result := Floor(args[0])
        else if w = 'ceil' then Result := Ceil(args[0])
        else raise ESnip.Create('unknown function "' + w + '"');
      end
      else raise ESnip.Create('wrong number of arguments for "' + w + '"');
      Exit;
    end;
    if w = 'pi' then Exit(Pi);
    if Scope.Find(w, v) then Exit(v);
    raise ESnip.Create('unknown name "' + w + '"');
  end;
  raise ESnip.Create('unexpected "' + Copy(S, P, 12) + '" in "' + S + '"');
end;

function Eval(const text: string; sc: TScope): Double;
var
  e: TExpr;
begin
  e := TExpr.Create;
  try
    Result := e.Parse(text, sc);
  finally
    e.Free;
  end;
end;

function NumText(v: Double): string;
begin
  if Abs(v - Round(v)) < 1e-9 then Result := IntToStr(Round(v))
  else Result := FormatFloat('0.####', v, FS);
  if Result = '-0' then Result := '0';
end;

{ ---------- parameter lines ---------- }

function ReadNum(const s: string; var p: Integer; out v: Double): Boolean;
var
  q: Integer;
begin
  while (p <= Length(s)) and (s[p] = ' ') do Inc(p);
  q := p;
  while (q <= Length(s)) and (s[q] in ['0'..'9', '.', '-', '+', 'e', 'E']) do Inc(q);
  Result := TryStrToFloat(Copy(s, p, q - p), v, FS);
  if Result then p := q;
end;

function ParseParamLine(const line: string; out prm: TSnipParam; out err: string): Boolean;
var
  rest, inner: string;
  p, q, k: Integer;
  parts: TStringList;
  haveRange: Boolean;
begin
  Result := False;
  err := '';
  rest := Trim(Copy(Trim(line), 7, MaxInt));
  p := Pos('=', rest);
  if p < 2 then
  begin
    err := 'a parameter line needs "Name = value": ' + line;
    Exit;
  end;
  prm.Name := Trim(Copy(rest, 1, p - 1));
  if (prm.Name = '') or not IsIdStart(prm.Name[1]) then
  begin
    err := 'bad parameter name in: ' + line;
    Exit;
  end;
  for k := 1 to Length(prm.Name) do
    if not IsIdChar(prm.Name[k]) then
    begin
      err := 'bad parameter name "' + prm.Name + '"';
      Exit;
    end;
  Inc(p);
  while (p <= Length(rest)) and (rest[p] = ' ') do Inc(p);
  prm.IsColor := (p <= Length(rest)) and (rest[p] = '#');
  if prm.IsColor then
  begin
    q := p + 1;
    while (q <= Length(rest)) and (rest[q] in ['0'..'9', 'a'..'f', 'A'..'F']) do Inc(q);
    inner := Copy(rest, p + 1, q - p - 1);
    if Length(inner) = 3 then inner := inner[1] + inner[1] + inner[2] + inner[2] + inner[3] + inner[3];
    if Length(inner) <> 6 then
    begin
      err := 'the colour of "' + prm.Name + '" must be #rrggbb';
      Exit;
    end;
    prm.Def := StrToInt('$' + inner);
    prm.Min := 0;
    prm.Max := $FFFFFF;
    prm.Step := 1;
    prm.Caption := prm.Name;
    q := Pos('"', rest);
    if q > 0 then
    begin
      k := PosEx('"', rest, q + 1);
      if k > q then prm.Caption := Copy(rest, q + 1, k - q - 1);
    end;
    Exit(True);
  end;
  if not ReadNum(rest, p, prm.Def) then
  begin
    err := 'the value of "' + prm.Name + '" is not a number';
    Exit;
  end;
  prm.Caption := prm.Name;
  haveRange := False;
  prm.Min := 0;
  prm.Max := Max(1, Abs(prm.Def) * 10);
  if prm.Def < 0 then prm.Min := prm.Def * 10;
  if Abs(prm.Def - Round(prm.Def)) < 1e-9 then prm.Step := 1 else prm.Step := 0.1;
  q := Pos('[', rest);
  if q > 0 then
  begin
    k := Pos(']', rest);
    if k < q then
    begin
      err := 'missing "]" in: ' + line;
      Exit;
    end;
    inner := Copy(rest, q + 1, k - q - 1);
    parts := TStringList.Create;
    try
      parts.Delimiter := ',';
      parts.StrictDelimiter := True;
      parts.DelimitedText := inner;
      if (parts.Count < 2) or (parts.Count > 3) or
         not TryStrToFloat(Trim(parts[0]), prm.Min, FS) or not TryStrToFloat(Trim(parts[1]), prm.Max, FS) then
      begin
        err := 'the range of "' + prm.Name + '" must be [min, max] or [min, max, step]';
        Exit;
      end;
      if parts.Count = 3 then
        if not TryStrToFloat(Trim(parts[2]), prm.Step, FS) then
        begin
          err := 'the step of "' + prm.Name + '" is not a number';
          Exit;
        end;
      haveRange := True;
    finally
      parts.Free;
    end;
  end;
  q := Pos('"', rest);
  if q > 0 then
  begin
    k := PosEx('"', rest, q + 1);
    if k > q then prm.Caption := Copy(rest, q + 1, k - q - 1);
  end;
  if haveRange and (prm.Max <= prm.Min) then
  begin
    err := 'the range of "' + prm.Name + '" is empty';
    Exit;
  end;
  if prm.Step <= 0 then
  begin
    err := 'the step of "' + prm.Name + '" must be greater than zero';
    Exit;
  end;
  if prm.Def < prm.Min then prm.Min := prm.Def;
  if prm.Def > prm.Max then prm.Max := prm.Def;
  Result := True;
end;

// @paramtext Name "Caption"
function ParseTextParamLine(const line: string; out prm: TSnipParam; out err: string): Boolean;
var
  rest: string;
  p, q, k: Integer;
begin
  Result := False;
  err := '';
  prm.IsColor := False;
  prm.IsText := True;
  prm.Def := 0;
  prm.Min := 0;
  prm.Max := 1;
  prm.Step := 1;
  rest := Trim(Copy(Trim(line), 11, MaxInt));
  p := 1;
  while (p <= Length(rest)) and IsIdChar(rest[p]) do Inc(p);
  prm.Name := Copy(rest, 1, p - 1);
  if (prm.Name = '') or not IsIdStart(prm.Name[1]) then
  begin
    err := 'a text parameter needs a name: @paramtext Name "Caption"';
    Exit;
  end;
  prm.Caption := prm.Name;
  q := Pos('"', rest);
  if q > 0 then
  begin
    k := PosEx('"', rest, q + 1);
    if k > q then prm.Caption := Copy(rest, q + 1, k - q - 1);
  end;
  Result := True;
end;

function SnipSplit(const src: string; out params: TSnipParams; out body, err: string): Boolean;
var
  p, e: Integer;
  line, t: string;
  prm: TSnipParam;
begin
  Result := False;
  prm.IsColor := False;
  prm.IsText := False;
  params := nil;
  body := src;
  err := '';
  p := 1;
  while p <= Length(src) do
  begin
    e := p;
    while (e <= Length(src)) and not (src[e] in [#10, #13]) do Inc(e);
    line := Copy(src, p, e - p);
    t := Trim(line);
    if t = '' then
    begin
      p := e + 1;
      Continue;
    end;
    if (Length(t) >= 10) and SameText(Copy(t, 1, 10), '@paramtext') then
    begin
      if not ParseTextParamLine(t, prm, err) then Exit;
      SetLength(params, Length(params) + 1);
      params[High(params)] := prm;
      p := e + 1;
    end
    else if (Length(t) >= 6) and SameText(Copy(t, 1, 6), '@param') then
    begin
      prm.IsText := False;
      if not ParseParamLine(t, prm, err) then Exit;
      SetLength(params, Length(params) + 1);
      params[High(params)] := prm;
      p := e + 1;
    end
    else Break;
  end;
  body := Copy(src, p, MaxInt);
  Result := True;
end;

function SnipDefaults(const params: TSnipParams): TSnipValues;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(params));
  for i := 0 to High(params) do Result[i] := params[i].Def;
end;

{ ---------- templates ---------- }

const
  MaxLoop = 5000;
  MaxOut = 3000000;

type
  TExpander = class
    Scope: TScope;
    Steps: Integer;
    Output: string;
    procedure Run(const t: string);
  end;

// the directive that starts at t[i] = '{': its text and the position after its '}'
function DirectiveAt(const t: string; i: Integer; out after: Integer): string;
var
  k: Integer;
begin
  k := PosEx('}', t, i + 1);
  if k = 0 then raise ESnip.Create('missing "}" after "' + Copy(t, i, 20) + '"');
  after := k + 1;
  Result := Trim(Copy(t, i + 1, k - i - 1));
end;

function FirstWord(const d: string): string;
var
  k: Integer;
begin
  k := 1;
  while (k <= Length(d)) and IsIdChar(d[k]) do Inc(k);
  Result := LowerCase(Copy(d, 1, k - 1));
end;

// the end of the block that starts at position start: where {else} (0: none) and {end} begin and what follows {end}
procedure FindBlock(const t: string; start: Integer; out elseAt, elseAfter, endAt, endAfter: Integer);
var
  i, depth, aft: Integer;
  d, w: string;
begin
  elseAt := 0;
  elseAfter := 0;
  depth := 0;
  i := start;
  while True do
  begin
    i := PosEx('{', t, i);
    if i = 0 then raise ESnip.Create('{end} is missing');
    d := DirectiveAt(t, i, aft);
    w := FirstWord(d);
    if (w = 'for') or (w = 'if') then Inc(depth)
    else if (w = 'else') and (depth = 0) and (d = 'else') then
    begin
      elseAt := i;
      elseAfter := aft;
    end
    else if (w = 'end') and (d = 'end') then
    begin
      if depth = 0 then
      begin
        endAt := i;
        endAfter := aft;
        Exit;
      end;
      Dec(depth);
    end;
    i := aft;
  end;
end;

function HslText(h, sat, lig: Double): string;
var
  c, x, m, r, g, b: Double;
  hh: Double;
  function Hex2(v: Double): string;
  begin
    Result := IntToHex(Max(0, Min(255, Round((v + m) * 255))), 2);
  end;
begin
  hh := h - 360 * Floor(h / 360);
  sat := Max(0, Min(100, sat)) / 100;
  lig := Max(0, Min(100, lig)) / 100;
  c := (1 - Abs(2 * lig - 1)) * sat;
  x := c * (1 - Abs(Frac(hh / 120) * 2 - 1));
  if hh < 60 then begin r := c; g := x; b := 0; end
  else if hh < 120 then begin r := x; g := c; b := 0; end
  else if hh < 180 then begin r := 0; g := c; b := x; end
  else if hh < 240 then begin r := 0; g := x; b := c; end
  else if hh < 300 then begin r := x; g := 0; b := c; end
  else begin r := c; g := 0; b := x; end;
  m := lig - c / 2;
  Result := '#' + Hex2(r) + Hex2(g) + Hex2(b);
end;

function XmlText(const s: string): string;
begin
  Result := StringReplace(s, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

// the arguments of name(a, b, c) cut at the commas that are not inside brackets
function CallArgs(const d: string): TStringList;
var
  i, depth, st, o: Integer;
begin
  Result := TStringList.Create;
  o := Pos('(', d);
  if (o = 0) or (d[Length(d)] <> ')') then
  begin
    Result.Free;
    raise ESnip.Create('bad call: ' + d);
  end;
  depth := 0;
  st := o + 1;
  for i := o + 1 to Length(d) - 1 do
  begin
    if d[i] = '(' then Inc(depth)
    else if d[i] = ')' then Dec(depth)
    else if (d[i] = ',') and (depth = 0) then
    begin
      Result.Add(Copy(d, st, i - st));
      st := i + 1;
    end;
  end;
  Result.Add(Copy(d, st, Length(d) - st));
end;

procedure TExpander.Run(const t: string);
var
  i, aft, ea, eaf, en, enf, k: Integer;
  d, w, vname, body: string;
  ex: TExpr;
  a, b, st, v: Double;
  n: Integer;
  args: TStringList;
begin
  i := 1;
  while i <= Length(t) do
  begin
    k := PosEx('{', t, i);
    if k = 0 then
    begin
      Output := Output + Copy(t, i, MaxInt);
      Break;
    end;
    Output := Output + Copy(t, i, k - i);
    d := DirectiveAt(t, k, aft);
    w := FirstWord(d);
    if Length(Output) > MaxOut then raise ESnip.Create('the result is too big');
    if (w = 'for') and (Copy(d, 1, 3) = 'for') and ((Length(d) = 3) or (d[4] in [' ', #9])) then
    begin
      FindBlock(t, aft, ea, eaf, en, enf);
      body := Copy(t, aft, en - aft);
      ex := TExpr.Create;
      try
        ex.S := Copy(d, 4, MaxInt);
        ex.P := 1;
        ex.Scope := Scope;
        ex.Skip;
        vname := ex.PeekWord;
        if vname = '' then raise ESnip.Create('{for} needs a variable: {for i = 0 to 10}');
        Inc(ex.P, Length(vname));
        ex.Skip;
        if (ex.P > Length(ex.S)) or (ex.S[ex.P] <> '=') then raise ESnip.Create('{for} needs "=": ' + d);
        Inc(ex.P);
        a := ex.ParseIn;
        if ex.PeekWord <> 'to' then raise ESnip.Create('{for} needs "to": ' + d);
        Inc(ex.P, 2);
        b := ex.ParseIn;
        st := 1;
        if ex.PeekWord = 'step' then
        begin
          Inc(ex.P, 4);
          st := ex.ParseIn;
        end;
        ex.Skip;
        if ex.P <= Length(ex.S) then raise ESnip.Create('unexpected "' + Copy(ex.S, ex.P, 12) + '" in ' + d);
      finally
        ex.Free;
      end;
      if st = 0 then raise ESnip.Create('the step of {for} cannot be zero');
      n := 0;
      v := a;
      while ((st > 0) and (v <= b + 1e-9)) or ((st < 0) and (v >= b - 1e-9)) do
      begin
        Inc(n);
        Inc(Steps);
        if (n > MaxLoop) or (Steps > MaxLoop * 4) then raise ESnip.Create('too many repetitions in {for}');
        Scope.SetVar(vname, v);
        Run(body);
        v := v + st;
      end;
      i := enf;
    end
    else if (w = 'if') and (Copy(d, 1, 2) = 'if') and ((Length(d) = 2) or (d[3] in [' ', #9, '('])) then
    begin
      FindBlock(t, aft, ea, eaf, en, enf);
      if Eval(Copy(d, 3, MaxInt), Scope) <> 0 then
      begin
        if ea > 0 then Run(Copy(t, aft, ea - aft)) else Run(Copy(t, aft, en - aft));
      end
      else if ea > 0 then Run(Copy(t, eaf, en - eaf));
      i := enf;
    end
    else if (d = 'end') or (d = 'else') then
      raise ESnip.Create('{' + d + '} without {for} or {if}')
    else if (w = 'let') and (Copy(d, 1, 3) = 'let') and ((Length(d) > 3) and (d[4] in [' ', #9])) then
    begin
      // {let name = expression}: a value kept for the rest of the snippet
      vname := Trim(Copy(d, 4, MaxInt));
      k := Pos('=', vname);
      if k < 2 then raise ESnip.Create('{let} needs "name = value": ' + d);
      body := Trim(Copy(vname, 1, k - 1));
      if (body = '') or not IsIdStart(body[1]) then raise ESnip.Create('bad name in ' + d);
      Scope.SetVar(body, Eval(Copy(vname, k + 1, MaxInt), Scope));
      i := aft;
    end
    else if (w = 'cell') and (Copy(d, 1, 5) = 'cell(') then
    begin
      // {cell(table, row, column)}: the text of a cell of a table
      args := CallArgs(d);
      try
        if args.Count <> 3 then raise ESnip.Create('cell needs (table, row, column): ' + d);
        n := Round(Eval(args[0], Scope));
        ea := Round(Eval(args[1], Scope));
        eaf := Round(Eval(args[2], Scope));
        if (n >= 0) and (n <= High(Scope.Tables)) and (ea >= 0) and (ea <= High(Scope.Tables[n].Rows)) and
           (eaf >= 0) and (eaf <= High(Scope.Tables[n].Rows[ea])) then
          Output := Output + XmlText(Scope.Tables[n].Rows[ea][eaf]);
      finally
        args.Free;
      end;
      i := aft;
    end
    else if (w = 'hsl') and (Copy(d, 1, 4) = 'hsl(') then
    begin
      args := CallArgs(d);
      try
        if args.Count <> 3 then raise ESnip.Create('hsl needs (hue, saturation, lightness): ' + d);
        Output := Output + HslText(Eval(args[0], Scope), Eval(args[1], Scope), Eval(args[2], Scope));
      finally
        args.Free;
      end;
      i := aft;
    end
    else
    begin
      if Scope.IsColor(d) and Scope.Find(d, a) then
        Output := Output + '#' + IntToHex(Round(a) and $FFFFFF, 6)
      else Output := Output + NumText(Eval(d, Scope));
      i := aft;
    end;
  end;
end;

function SnipExpand(const src: string; const values: TSnipValues; out svg, err: string): Boolean;
begin
  Result := SnipExpandT(src, values, nil, svg, err);
end;

function SnipExpandT(const src: string; const values: TSnipValues; const texts: TSnipTexts; out svg, err: string): Boolean;
var
  params: TSnipParams;
  body: string;
  sc: TScope;
  ex: TExpander;
  i: Integer;
begin
  svg := '';
  Result := False;
  if not SnipSplit(src, params, body, err) then Exit;
  sc := TScope.Create;
  ex := TExpander.Create;
  try
    for i := 0 to High(params) do
    begin
      if params[i].IsText then
      begin
        if i <= High(texts) then sc.AddText(params[i].Name, texts[i])
        else sc.AddText(params[i].Name, '');
        Continue;
      end;
      if i <= High(values) then sc.SetVar(params[i].Name, values[i])
      else sc.SetVar(params[i].Name, params[i].Def);
      if params[i].IsColor then
      begin
        SetLength(sc.Colors, Length(sc.Colors) + 1);
        sc.Colors[High(sc.Colors)] := params[i].Name;
      end;
    end;
    ex.Scope := sc;
    try
      ex.Run(body);
      svg := ex.Output;
      Result := True;
    except
      on E: ESnip do err := E.Message;
    end;
  finally
    ex.Free;
    sc.Free;
  end;
end;

{ ---------- stored form ---------- }

function SnipEncode(const src: string; const values: TSnipValues; fx, fy, cw, ch: Double): string;
begin
  Result := SnipEncodeT(src, values, nil, fx, fy, cw, ch);
end;

function SnipDecode(const enc: string; out src: string; out values: TSnipValues; out fx, fy, cw, ch: Double): Boolean;
var
  tx: TSnipTexts;
begin
  Result := SnipDecodeT(enc, src, values, tx, fx, fy, cw, ch);
end;

function SnipEncodeT(const src: string; const values: TSnipValues; const texts: TSnipTexts; fx, fy, cw, ch: Double): string;
var
  i: Integer;
  vs, ts: string;
  anyText: Boolean;
begin
  vs := '';
  for i := 0 to High(values) do
  begin
    if i > 0 then vs := vs + ',';
    vs := vs + FloatToStr(values[i], FS);
  end;
  Result := EncodeStringBase64(src) + ';' + vs + ';' + FloatToStr(fx, FS) + ',' + FloatToStr(fy, FS) + ',' +
    FloatToStr(cw, FS) + ',' + FloatToStr(ch, FS);
  // the texts (base64, separated by commas) come last, and only if there are any: the older form stays valid
  ts := '';
  anyText := False;
  for i := 0 to High(texts) do
  begin
    if i > 0 then ts := ts + ',';
    ts := ts + EncodeStringBase64(texts[i]);
    if texts[i] <> '' then anyText := True;
  end;
  if anyText then Result := Result + ';' + ts;
end;

function SnipDecodeT(const enc: string; out src: string; out values: TSnipValues; out texts: TSnipTexts; out fx, fy, cw, ch: Double): Boolean;
var
  parts, vl, sz: TStringList;
  i: Integer;
  v: Double;
begin
  Result := False;
  src := '';
  values := nil;
  texts := nil;
  fx := 1;
  fy := 1;
  cw := 0;
  ch := 0;
  parts := TStringList.Create;
  vl := TStringList.Create;
  sz := TStringList.Create;
  try
    parts.Delimiter := ';';
    parts.StrictDelimiter := True;
    parts.DelimitedText := enc;
    if (parts.Count <> 3) and (parts.Count <> 4) then Exit;
    try
      src := DecodeStringBase64(parts[0]);
    except
      Exit;
    end;
    vl.Delimiter := ',';
    vl.StrictDelimiter := True;
    vl.DelimitedText := parts[1];
    for i := 0 to vl.Count - 1 do
      if vl[i] <> '' then
      begin
        if not TryStrToFloat(vl[i], v, FS) then Exit;
        SetLength(values, Length(values) + 1);
        values[High(values)] := v;
      end;
    sz.Delimiter := ',';
    sz.StrictDelimiter := True;
    sz.DelimitedText := parts[2];
    if sz.Count <> 4 then Exit;
    if not TryStrToFloat(sz[0], fx, FS) or not TryStrToFloat(sz[1], fy, FS) or
       not TryStrToFloat(sz[2], cw, FS) or not TryStrToFloat(sz[3], ch, FS) then Exit;
    if parts.Count = 4 then
    begin
      vl.Clear;
      vl.DelimitedText := parts[3];
      SetLength(texts, vl.Count);
      for i := 0 to vl.Count - 1 do
        try
          texts[i] := DecodeStringBase64(vl[i]);
        except
          texts[i] := '';
        end;
    end;
    Result := True;
  finally
    sz.Free;
    vl.Free;
    parts.Free;
  end;
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

end.
