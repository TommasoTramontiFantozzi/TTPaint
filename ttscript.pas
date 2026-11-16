{ The language of the raster filters: a small BASIC in which every variable is a float.  The script is the body that runs
  for every pixel (X, Y); it reads the colour of the pixels of the input (R, G, B, H, S, L) and writes the colour of the
  output (Ro, Go, Bo, or Ho, So, Lo).  It is compiled to a bytecode for a register machine and run by a few threads.

  Several passes (separated by a line "PASS") can follow each other: the output of one is the input of the next.
  Parameters are declared as for the SVG snippets: @param Name = default [min, max, step] "Caption" }
unit ttscript;

{$mode objfpc}{$H+}
{$POINTERMATH ON}
{$OPTIMIZATION LEVEL2}{$OPTIMIZATION REGVAR}
{$R-}{$Q-}

interface

uses
  Classes, SysUtils, Math, TTSnip;

type
  TFltValues = array of Double;

  // the pixels as three planes of bytes (the filters work on opaque pixels)
  TFltImage = record
    W, H: Integer;
    R, G, B: array of Byte;
    A: array of Byte;             // the opacity; empty: all 255 (and it is made when the script runs)
  end;

  TFltIns = record
    Op, A, B, C, D: LongInt;
  end;
  PFltIns = ^TFltIns;
  TFltCode = array of TFltIns;

  // one pass of the script
  TFltPass = record
    Code: TFltCode;
    NRegs: Integer;
    Consts: array of Double;      // registers FirstConst ...
    FirstConst: Integer;
    UsesHsl: Boolean;             // H, S, L are read or written
    HslOut: Boolean;              // Ho, So, Lo are written
    UsesAvg: Boolean;             // AVGR, AVGG or AVGB are used: the sums of the pixels are prepared
  end;

  TFltScript = class
  public
    Params: TSnipParams;
    Premul: Boolean;              // the line "@premul": R, G, B come multiplied by A (and go out like that)
    Passes: array of TFltPass;
    // true when the source is a good script; otherwise Err says which line is wrong
    function Compile(const src: string; out err: string): Boolean;
    // the script on the pixels of img inside roi (the passes before the last one work on the whole image); the result
    // replaces the pixels of img inside roi.  scale: pixels per unit of the drawing.
    function Run(var img: TFltImage; const vals: TFltValues; scale: Double; roi: TRect; out err: string): Boolean;
    // the same when img is a part of a bigger picture (fullW x fullH) whose top left corner of the part is (offX, offY):
    // the script sees the position (X, Y) and the size in the whole picture
    function RunAt(var img: TFltImage; const vals: TFltValues; scale: Double; roi: TRect; offX, offY, fullW, fullH: Integer;
      out err: string): Boolean;
    function Defaults: TFltValues;
    function UsesPass: Integer;
  end;

procedure RgbToHsl(r, g, b: Double; out h, s, l: Double);
procedure HslToRgb(h, s, l: Double; out r, g, b: Double);

// the filters that come with the program
function FltBuiltinCount: Integer;
function FltBuiltinName(i: Integer): string;
function FltBuiltinScript(i: Integer): string;

const
  FltScriptCLS = 0;

var
  FltThreads: Integer = 0;       // 0: as many as there are processors

implementation

uses
  SyncObjs;

var
  FS: TFormatSettings;

{ ---------- colours ---------- }

procedure RgbToHsl(r, g, b: Double; out h, s, l: Double);
var
  mx, mn, d: Double;
begin
  r := r / 255; g := g / 255; b := b / 255;
  mx := Max(r, Max(g, b));
  mn := Min(r, Min(g, b));
  l := (mx + mn) / 2;
  d := mx - mn;
  if d < 1e-9 then
  begin
    h := 0;
    s := 0;
  end
  else
  begin
    if l > 0.5 then s := d / (2 - mx - mn) else s := d / (mx + mn);
    if mx = r then h := (g - b) / d + (Ord(g < b) * 6)
    else if mx = g then h := (b - r) / d + 2
    else h := (r - g) / d + 4;
    h := h * 60;
  end;
  s := s * 100;
  l := l * 100;
end;

function Hue2Rgb(p, q, t: Double): Double;
begin
  if t < 0 then t := t + 1;
  if t > 1 then t := t - 1;
  if t < 1 / 6 then Result := p + (q - p) * 6 * t
  else if t < 1 / 2 then Result := q
  else if t < 2 / 3 then Result := p + (q - p) * (2 / 3 - t) * 6
  else Result := p;
end;

procedure HslToRgb(h, s, l: Double; out r, g, b: Double);
var
  p, q: Double;
begin
  h := h - Floor(h / 360) * 360;
  h := h / 360;
  s := Max(0, Min(1, s / 100));
  l := Max(0, Min(1, l / 100));
  if s < 1e-9 then
  begin
    r := l * 255; g := r; b := r;
    Exit;
  end;
  if l < 0.5 then q := l * (1 + s) else q := l + s - l * s;
  p := 2 * l - q;
  r := Hue2Rgb(p, q, h + 1 / 3) * 255;
  g := Hue2Rgb(p, q, h) * 255;
  b := Hue2Rgb(p, q, h - 1 / 3) * 255;
end;

{ ---------- the machine ---------- }

const
  // fixed registers
  rX = 0; rY = 1; rMaxX = 2; rMaxY = 3; rScale = 4;
  rR = 5; rG = 6; rB = 7; rH = 8; rS = 9; rL = 10;
  rRo = 11; rGo = 12; rBo = 13; rHo = 14; rSo = 15; rLo = 16;
  rA = 17; rAo = 18;
  rPi = 19;
  rFirstUser = 20;

  // instructions: A is the destination, B and C the sources
  opMov = 0; opAdd = 1; opSub = 2; opMul = 3; opDiv = 4; opMod = 5; opPow = 6; opNeg = 7; opNot = 8;
  opEq = 9; opNe = 10; opLt = 11; opGt = 12; opLe = 13; opGe = 14; opAnd = 15; opOr = 16;
  opJmp = 17;      // A: target (a jump back counts against the time of the pixel)
  opJz = 18;       // A: target, B: the condition
  opForChk = 19;   // A: target when the loop is over, B: variable, C: limit, D: step
  opAbs = 20; opSqrt = 21; opSin = 22; opCos = 23; opTan = 24; opAtan = 25; opExp = 26; opLog = 27;
  opFloor = 28; opCeil = 29; opRound = 30; opSgn = 31; opFrac = 32;
  opMin = 33; opMax = 34; opAtan2 = 35;
  opClamp = 36;    // A = clamp(B, C, D)
  opMix = 37;      // A = B + (C - B) * D
  opSmooth = 38;   // A = smoothstep(B, C, D)
  opNoise = 39;    // A = noise(B, C)
  opRd = 40;       // A = channel D (0 R, 1 G, 2 B, 3 H, 4 S, 5 L) at (B, C), the nearest pixel
  opRdI = 41;      // the same, interpolated
  opAsin = 42; opAcos = 43;
  opTanh = 46;     // A = hyperbolic tangent of B
  opAvg = 45;      // A = mean of channel C (0..2) in the rectangle whose corners are the registers B .. B + 3
  opForNext = 44;  // A: first instruction of the body, B: variable, C: limit, D: step

  MaxBudget = 4000000;       // jumps back for one pixel

type
  TCtx = record
    Reg: PDouble;
    W, H: Integer;
    OffX, OffY: Integer;      // the position of the top left pixel in the whole picture
    R, G, B, A: PByte;        // the input
    IR, IG, IB, IA: PLongWord;    // sums of the rectangle from the corner to each pixel, (W + 1) x (H + 1)
    Budget: Integer;
    TooSlow: Boolean;
  end;

function Clamp255(v: Double): Byte; inline;
begin
  if not (v > 0) then Result := 0
  else if v >= 255 then Result := 255
  else Result := Trunc(v + 0.5);
end;

function Hash2(x, y: Double): Double;
var
  n: LongInt;
begin
  n := Trunc(x * 73.0) xor (Trunc(y * 151.0) * 1013);
  n := (n shl 13) xor n;
  n := n * (n * n * 15731 + 789221) + 1376312589;
  Result := ((n and $7FFFFFFF) / 1073741823.5) - 1;
  Result := (Result + 1) / 2;
end;

// (fx, fy) in the pixels of the image itself
function ReadPixL(const cx: TCtx; ch: Integer; fx, fy: Double): Double;
var
  ix, iy, k: Integer;
  r, g, b, h, s, l: Double;
begin
  if not (fx > 0) then ix := 0
  else if fx >= cx.W - 1 then ix := cx.W - 1
  else ix := Trunc(fx + 0.5);
  if not (fy > 0) then iy := 0
  else if fy >= cx.H - 1 then iy := cx.H - 1
  else iy := Trunc(fy + 0.5);
  k := iy * cx.W + ix;
  case ch of
    0: Result := cx.R[k];
    1: Result := cx.G[k];
    2: Result := cx.B[k];
    6: Result := cx.A[k];
  else
    begin
      RgbToHsl(cx.R[k], cx.G[k], cx.B[k], h, s, l);
      case ch of
        3: Result := h;
        4: Result := s;
      else Result := l;
      end;
    end;
  end;
end;

// (fx, fy) in the whole picture
function ReadPix(const cx: TCtx; ch: Integer; fx, fy: Double): Double;
begin
  Result := ReadPixL(cx, ch, fx - cx.OffX, fy - cx.OffY);
end;

function ReadPixI(const cx: TCtx; ch: Integer; fx, fy: Double): Double;
var
  x0, y0: Integer;
  tx, ty, a, b: Double;
begin
  fx := Max(0, Min(cx.W - 1, fx - cx.OffX));
  fy := Max(0, Min(cx.H - 1, fy - cx.OffY));
  x0 := Trunc(fx);
  y0 := Trunc(fy);
  tx := fx - x0;
  ty := fy - y0;
  a := ReadPixL(cx, ch, x0, y0) * (1 - tx) + ReadPixL(cx, ch, x0 + 1, y0) * tx;
  b := ReadPixL(cx, ch, x0, y0 + 1) * (1 - tx) + ReadPixL(cx, ch, x0 + 1, y0 + 1) * tx;
  Result := a * (1 - ty) + b * ty;
end;

// the mean of a channel in the rectangle (the corners are included, the part outside the image is left out)
function AreaMean(const cx: TCtx; ch: Integer; ax, ay, bx, by: Double): Double;
var
  x0, y0, x1, y1, st: Integer;
  t: Int64;
  p: PLongWord;
begin
  ax := ax - cx.OffX;
  bx := bx - cx.OffX;
  ay := ay - cx.OffY;
  by := by - cx.OffY;
  if not (ax > 0) then x0 := 0 else if ax >= cx.W - 1 then x0 := cx.W - 1 else x0 := Trunc(ax + 0.5);
  if not (ay > 0) then y0 := 0 else if ay >= cx.H - 1 then y0 := cx.H - 1 else y0 := Trunc(ay + 0.5);
  if not (bx > 0) then x1 := 0 else if bx >= cx.W - 1 then x1 := cx.W - 1 else x1 := Trunc(bx + 0.5);
  if not (by > 0) then y1 := 0 else if by >= cx.H - 1 then y1 := cx.H - 1 else y1 := Trunc(by + 0.5);
  if x1 < x0 then begin st := x0; x0 := x1; x1 := st; end;
  if y1 < y0 then begin st := y0; y0 := y1; y1 := st; end;
  case ch of
    0: p := cx.IR;
    1: p := cx.IG;
    3: p := cx.IA;
  else p := cx.IB;
  end;
  st := cx.W + 1;
  t := Int64(p[(y1 + 1) * st + x1 + 1]) - p[y0 * st + x1 + 1] - p[(y1 + 1) * st + x0] + p[y0 * st + x0];
  Result := t / ((x1 - x0 + 1) * (y1 - y0 + 1));
end;

// Math.Floor is slow
function FFloor(x: Double): Double; inline;
begin
  if (x > 1e15) or (x < -1e15) then Exit(x);
  Result := Trunc(x);
  if Result > x then Result := Result - 1;
end;

// e^x by range reduction and a polynomial: much faster than the x87 instruction, good to about 1e-8
function FastExp(x: Double): Double; inline;
var
  t, f, u: Double;
  n: Integer;
  bits: Int64;
begin
  if x < -700 then Exit(0);
  t := x * 1.4426950408889634;
  n := Trunc(t + 1000.5) - 1000;
  f := t - n;
  u := f * 0.6931471805599453;
  Result := 1 + u * (1 + u / 2 * (1 + u / 3 * (1 + u / 4 * (1 + u / 5 * (1 + u / 6 * (1 + u / 7))))));
  bits := Int64(n + 1023) shl 52;
  Result := Result * PDouble(@bits)^;
end;

// the code for one pixel
procedure Exec(var cx: TCtx; code: PFltIns; n: Integer);
var
  pc, bud: Integer;
  r: PDouble;
  ip: PFltIns;
  t, u: Double;
begin
  r := cx.Reg;
  pc := 0;
  bud := cx.Budget;
  while pc < n do
  begin
    ip := code + pc;
    case ip^.Op of
      opMov: r[ip^.A] := r[ip^.B];
      opAdd: r[ip^.A] := r[ip^.B] + r[ip^.C];
      opSub: r[ip^.A] := r[ip^.B] - r[ip^.C];
      opMul: r[ip^.A] := r[ip^.B] * r[ip^.C];
      opDiv: if r[ip^.C] = 0 then r[ip^.A] := 0 else r[ip^.A] := r[ip^.B] / r[ip^.C];
      opMod:
        if r[ip^.C] = 0 then r[ip^.A] := 0
        else r[ip^.A] := r[ip^.B] - FFloor(r[ip^.B] / r[ip^.C]) * r[ip^.C];
      opPow:
        begin
          t := r[ip^.B];
          u := r[ip^.C];
          if (t = 0) then r[ip^.A] := Ord(u = 0)
          else if (t < 0) and (Frac(u) <> 0) then r[ip^.A] := 0
          else if Abs(u * Ln(Abs(t))) > 700 then r[ip^.A] := 0
          else if t < 0 then
          begin
            if Odd(Trunc(u)) then r[ip^.A] := -FastExp(u * Ln(-t)) else r[ip^.A] := FastExp(u * Ln(-t));
          end
          else r[ip^.A] := FastExp(u * Ln(t));
        end;
      opNeg: r[ip^.A] := -r[ip^.B];
      opNot: r[ip^.A] := Ord(r[ip^.B] = 0);
      opEq: r[ip^.A] := Ord(r[ip^.B] = r[ip^.C]);
      opNe: r[ip^.A] := Ord(r[ip^.B] <> r[ip^.C]);
      opLt: r[ip^.A] := Ord(r[ip^.B] < r[ip^.C]);
      opGt: r[ip^.A] := Ord(r[ip^.B] > r[ip^.C]);
      opLe: r[ip^.A] := Ord(r[ip^.B] <= r[ip^.C]);
      opGe: r[ip^.A] := Ord(r[ip^.B] >= r[ip^.C]);
      opAnd: r[ip^.A] := Ord((r[ip^.B] <> 0) and (r[ip^.C] <> 0));
      opOr: r[ip^.A] := Ord((r[ip^.B] <> 0) or (r[ip^.C] <> 0));
      opJmp:
        begin
          if ip^.A <= pc then
          begin
            Dec(bud);
            if bud <= 0 then
            begin
              cx.TooSlow := True;
              Exit;
            end;
          end;
          pc := ip^.A;
          Continue;
        end;
      opJz:
        if r[ip^.B] = 0 then
        begin
          pc := ip^.A;
          Continue;
        end;
      opForChk:
        if ((r[ip^.D] >= 0) and (r[ip^.B] > r[ip^.C])) or ((r[ip^.D] < 0) and (r[ip^.B] < r[ip^.C])) then
        begin
          pc := ip^.A;
          Continue;
        end;
      opForNext:
        begin
          r[ip^.B] := r[ip^.B] + r[ip^.D];
          if ((r[ip^.D] >= 0) and (r[ip^.B] <= r[ip^.C])) or ((r[ip^.D] < 0) and (r[ip^.B] >= r[ip^.C])) then
          begin
            Dec(bud);
            if bud <= 0 then
            begin
              cx.TooSlow := True;
              Exit;
            end;
            pc := ip^.A;
            Continue;
          end;
        end;
      opAbs: r[ip^.A] := Abs(r[ip^.B]);
      opSqrt: if r[ip^.B] > 0 then r[ip^.A] := Sqrt(r[ip^.B]) else r[ip^.A] := 0;
      opSin: r[ip^.A] := Sin(r[ip^.B]);
      opCos: r[ip^.A] := Cos(r[ip^.B]);
      opTan: r[ip^.A] := Tan(r[ip^.B]);
      opAtan: r[ip^.A] := ArcTan(r[ip^.B]);
      opTanh: r[ip^.A] := Tanh(r[ip^.B]);
      opAsin: if Abs(r[ip^.B]) <= 1 then r[ip^.A] := ArcSin(r[ip^.B]) else r[ip^.A] := 0;
      opAcos: if Abs(r[ip^.B]) <= 1 then r[ip^.A] := ArcCos(r[ip^.B]) else r[ip^.A] := 0;
      opExp: if r[ip^.B] > 700 then r[ip^.A] := 0 else r[ip^.A] := FastExp(r[ip^.B]);
      opLog: if r[ip^.B] > 0 then r[ip^.A] := Ln(r[ip^.B]) else r[ip^.A] := 0;
      opFloor: r[ip^.A] := FFloor(r[ip^.B]);
      opCeil: r[ip^.A] := Ceil(r[ip^.B]);
      opRound: r[ip^.A] := FFloor(r[ip^.B] + 0.5);
      opSgn: if r[ip^.B] > 0 then r[ip^.A] := 1 else if r[ip^.B] < 0 then r[ip^.A] := -1 else r[ip^.A] := 0;
      opFrac: r[ip^.A] := r[ip^.B] - FFloor(r[ip^.B]);
      opMin: if r[ip^.B] < r[ip^.C] then r[ip^.A] := r[ip^.B] else r[ip^.A] := r[ip^.C];
      opMax: if r[ip^.B] > r[ip^.C] then r[ip^.A] := r[ip^.B] else r[ip^.A] := r[ip^.C];
      opAtan2: r[ip^.A] := ArcTan2(r[ip^.B], r[ip^.C]);
      opClamp:
        begin
          t := r[ip^.B];
          if t < r[ip^.C] then t := r[ip^.C];
          if t > r[ip^.D] then t := r[ip^.D];
          r[ip^.A] := t;
        end;
      opMix: r[ip^.A] := r[ip^.B] + (r[ip^.C] - r[ip^.B]) * r[ip^.D];
      opSmooth:
        begin
          if r[ip^.C] = r[ip^.B] then t := Ord(r[ip^.D] >= r[ip^.C])
          else
          begin
            t := (r[ip^.D] - r[ip^.B]) / (r[ip^.C] - r[ip^.B]);
            if t < 0 then t := 0;
            if t > 1 then t := 1;
            t := t * t * (3 - 2 * t);
          end;
          r[ip^.A] := t;
        end;
      opNoise: r[ip^.A] := Hash2(r[ip^.B], r[ip^.C]);
      opAvg: r[ip^.A] := AreaMean(cx, ip^.C, r[ip^.B], r[ip^.B + 1], r[ip^.B + 2], r[ip^.B + 3]);
      opRd: r[ip^.A] := ReadPix(cx, ip^.D, r[ip^.B], r[ip^.C]);
      opRdI: r[ip^.A] := ReadPixI(cx, ip^.D, r[ip^.B], r[ip^.C]);
    end;
    Inc(pc);
  end;
end;

{ ---------- compiler ---------- }

type
  EFlt = class(Exception);

  TTokKind = (tkEOF, tkEOL, tkNum, tkId, tkOp);
  TTok = record
    Kind: TTokKind;
    Text: string;          // identifiers in capitals, operators as they are
    Num: Double;
    Line: Integer;
  end;

  TNameKind = (nkVar, nkReadOnly, nkParam);
  TName = record
    Name: string;
    Reg: Integer;
    Kind: TNameKind;
  end;

  TCompiler = class
    Toks: array of TTok;
    P: Integer;
    Names: array of TName;
    Code: TFltCode;
    NCode: Integer;
    NVars: Integer;
    Consts: array of Double;
    NTemps, MaxTemps: Integer;
    UsesHsl, HslOut, UsesAvg: Boolean;
    ParamNames: array of string;
    procedure Fail(const msg: string);
    function Cur: TTok;
    function IsOp(const s: string): Boolean;
    function IsWord(const s: string): Boolean;
    procedure Next;
    procedure ExpectOp(const s: string);
    function Emit(op, a, b, c, d: Integer): Integer;
    function FindName(const nm: string): Integer;
    function NewVar(const nm: string): Integer;
    function NewHidden: Integer;
    function ConstReg(v: Double): Integer;
    function Temp: Integer;
    function Expr: Integer;
    function OrExpr: Integer;
    function AndExpr: Integer;
    function NotExpr: Integer;
    function CmpExpr: Integer;
    function AddExpr: Integer;
    function MulExpr: Integer;
    function Unary: Integer;
    function PowExpr: Integer;
    function Primary: Integer;
    function Call(const nm: string): Integer;
    function ChannelCode(const nm: string): Integer;
    procedure Block(const enders: array of string);
    procedure Statement;
    procedure Assign(dst, src: Integer);
    procedure Finish(out pass: TFltPass);
    procedure Lex(const src: string);
    procedure RunCompile(const src: string; out pass: TFltPass);
  end;

procedure TCompiler.Fail(const msg: string);
begin
  raise EFlt.Create('line ' + IntToStr(Cur.Line) + ': ' + msg);
end;

function TCompiler.Cur: TTok;
begin
  Result := Toks[P];
end;

function TCompiler.IsOp(const s: string): Boolean;
begin
  Result := (Toks[P].Kind = tkOp) and (Toks[P].Text = s);
end;

function TCompiler.IsWord(const s: string): Boolean;
begin
  Result := (Toks[P].Kind = tkId) and (Toks[P].Text = s);
end;

procedure TCompiler.Next;
begin
  if P < High(Toks) then Inc(P);
end;

procedure TCompiler.ExpectOp(const s: string);
begin
  if not IsOp(s) then Fail('"' + s + '" expected');
  Next;
end;

function TCompiler.Emit(op, a, b, c, d: Integer): Integer;
begin
  if NCode >= Length(Code) then SetLength(Code, Max(64, Length(Code) * 2));
  Code[NCode].Op := op;
  Code[NCode].A := a;
  Code[NCode].B := b;
  Code[NCode].C := c;
  Code[NCode].D := d;
  Result := NCode;
  Inc(NCode);
end;

function TCompiler.FindName(const nm: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Names) do
    if Names[i].Name = nm then Exit(i);
  Result := -1;
end;

function TCompiler.NewVar(const nm: string): Integer;
begin
  SetLength(Names, Length(Names) + 1);
  Names[High(Names)].Name := nm;
  Names[High(Names)].Reg := rFirstUser + NVars;
  Names[High(Names)].Kind := nkVar;
  Inc(NVars);
  Result := High(Names);
end;

function TCompiler.NewHidden: Integer;
begin
  Result := rFirstUser + NVars;
  Inc(NVars);
end;

// constants and temporaries get provisional numbers (the variables are not all known yet); Finish puts them in place
const
  ConstBase = 100000;
  TempBase = 200000;

function TCompiler.ConstReg(v: Double): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Consts) do
    if Consts[i] = v then Exit(ConstBase + i);
  SetLength(Consts, Length(Consts) + 1);
  Consts[High(Consts)] := v;
  Result := ConstBase + High(Consts);
end;

function TCompiler.Temp: Integer;
begin
  Result := TempBase + NTemps;
  Inc(NTemps);
  if NTemps > MaxTemps then MaxTemps := NTemps;
end;

function TCompiler.ChannelCode(const nm: string): Integer;
begin
  if nm = 'R' then Result := 0
  else if nm = 'G' then Result := 1
  else if nm = 'B' then Result := 2
  else if nm = 'H' then Result := 3
  else if nm = 'S' then Result := 4
  else if nm = 'L' then Result := 5
  else if nm = 'A' then Result := 6
  else Result := -1;
end;

function TCompiler.Primary: Integer;
var
  t: TTok;
  k, ch, xr, yr, d: Integer;
begin
  t := Cur;
  if t.Kind = tkNum then
  begin
    Next;
    Exit(ConstReg(t.Num));
  end;
  if IsOp('(') then
  begin
    Next;
    Result := Expr;
    ExpectOp(')');
    Exit;
  end;
  if t.Kind <> tkId then Fail('a value is expected');
  Next;
  if t.Text = 'PI' then Exit(rPi);
  ch := ChannelCode(t.Text);
  if (ch >= 0) and IsOp('[') then
  begin
    Next;
    xr := Expr;
    ExpectOp(',');
    yr := Expr;
    ExpectOp(']');
    if (ch >= 3) and (ch <= 5) then UsesHsl := True;
    d := Temp;
    Emit(opRd, d, xr, yr, ch);
    Exit(d);
  end;
  if (Length(t.Text) = 2) and (t.Text[2] = 'O') and (ChannelCode(t.Text[1]) >= 0) and IsOp('[') then
  begin
    // Ro[X, Y] reads the output of this pixel: the position must be X, Y
    Next;
    if not IsWord('X') then Fail('only the pixel itself can be read here: ' + t.Text + '[X, Y]');
    Next;
    ExpectOp(',');
    if not IsWord('Y') then Fail('only the pixel itself can be read here: ' + t.Text + '[X, Y]');
    Next;
    ExpectOp(']');
  end;
  if IsOp('(') then Exit(Call(t.Text));
  k := FindName(t.Text);
  if k < 0 then
  begin
    Fail('"' + t.Text + '" has no value yet');
  end;
  if Names[k].Reg in [rH, rS, rL, rHo, rSo, rLo] then UsesHsl := True;
  Result := Names[k].Reg;
end;

function TCompiler.Call(const nm: string): Integer;
type
  TFn = record
    Name: string;
    Op: Integer;
    N: Integer;
  end;
const
  Fns: array[0..30] of TFn = (
    (Name: 'ABS'; Op: opAbs; N: 1), (Name: 'SQR'; Op: opSqrt; N: 1), (Name: 'SQRT'; Op: opSqrt; N: 1),
    (Name: 'SIN'; Op: opSin; N: 1), (Name: 'COS'; Op: opCos; N: 1), (Name: 'TAN'; Op: opTan; N: 1),
    (Name: 'TANH'; Op: opTanh; N: 1), (Name: 'ATN'; Op: opAtan; N: 1), (Name: 'ATAN'; Op: opAtan; N: 1), (Name: 'ASIN'; Op: opAsin; N: 1),
    (Name: 'ACOS'; Op: opAcos; N: 1), (Name: 'EXP'; Op: opExp; N: 1), (Name: 'LOG'; Op: opLog; N: 1),
    (Name: 'INT'; Op: opFloor; N: 1), (Name: 'FLOOR'; Op: opFloor; N: 1), (Name: 'CEIL'; Op: opCeil; N: 1),
    (Name: 'ROUND'; Op: opRound; N: 1), (Name: 'SGN'; Op: opSgn; N: 1), (Name: 'FRAC'; Op: opFrac; N: 1),
    (Name: 'MIN'; Op: opMin; N: 2), (Name: 'MAX'; Op: opMax; N: 2), (Name: 'ATAN2'; Op: opAtan2; N: 2),
    (Name: 'POW'; Op: opPow; N: 2), (Name: 'MOD'; Op: opMod; N: 2), (Name: 'NOISE'; Op: opNoise; N: 2),
    (Name: 'CLAMP'; Op: opClamp; N: 3), (Name: 'MIX'; Op: opMix; N: 3), (Name: 'SMOOTHSTEP'; Op: opSmooth; N: 3),
    (Name: 'SR'; Op: opRdI; N: 102), (Name: 'SG'; Op: opRdI; N: 102), (Name: 'SB'; Op: opRdI; N: 102));
var
  i, k, n: Integer;
  a: array[0..2] of Integer;
  d, ch, a0: Integer;
begin
  k := -1;
  for i := 0 to High(Fns) do
    if Fns[i].Name = nm then
    begin
      k := i;
      Break;
    end;
  if (nm = 'AVGR') or (nm = 'AVGG') or (nm = 'AVGB') or (nm = 'AVGA') then
  begin
    // the four corners go to four registers one after the other
    ExpectOp('(');
    a0 := TempBase + NTemps;
    for i := 0 to 3 do Temp;
    for i := 0 to 3 do
    begin
      d := Expr;
      Emit(opMov, a0 + i, d, 0, 0);
      if i < 3 then ExpectOp(',');
    end;
    ExpectOp(')');
    d := Temp;
    UsesAvg := True;
    Emit(opAvg, d, a0, Ord(nm[4]) - Ord('R'), 0);
    if nm[4] = 'G' then Code[NCode - 1].C := 1 else if nm[4] = 'B' then Code[NCode - 1].C := 2
    else if nm[4] = 'A' then Code[NCode - 1].C := 3 else Code[NCode - 1].C := 0;
    Exit(d);
  end;
  if k < 0 then Fail('unknown function "' + nm + '"');
  ExpectOp('(');
  n := 0;
  if not IsOp(')') then
    repeat
      if n > 2 then Fail('too many arguments for ' + nm);
      a[n] := Expr;
      Inc(n);
      if IsOp(',') then Next else Break;
    until False;
  ExpectOp(')');
  d := Temp;
  if Fns[k].N > 100 then
  begin
    // SR, SG, SB (x, y): the interpolated colour component
    if n <> 2 then Fail(nm + ' needs two arguments (x, y)');
    if nm = 'SR' then ch := 0 else if nm = 'SG' then ch := 1 else ch := 2;
    Emit(opRdI, d, a[0], a[1], ch);
    Exit(d);
  end;
  if n <> Fns[k].N then Fail(nm + ' needs ' + IntToStr(Fns[k].N) + ' argument(s)');
  case n of
    1: Emit(Fns[k].Op, d, a[0], 0, 0);
    2: Emit(Fns[k].Op, d, a[0], a[1], 0);
  else Emit(Fns[k].Op, d, a[0], a[1], a[2]);
  end;
  Result := d;
end;

function TCompiler.PowExpr: Integer;
var
  b, e, d: Integer;
begin
  b := Primary;
  if IsOp('^') then
  begin
    Next;
    e := Unary;               // 2 ^ -1
    d := Temp;
    Emit(opPow, d, b, e, 0);
    Exit(d);
  end;
  Result := b;
end;

function TCompiler.Unary: Integer;
var
  a, d: Integer;
begin
  if IsOp('-') then
  begin
    Next;
    a := Self.Unary;
    d := Temp;
    Emit(opNeg, d, a, 0, 0);
    Exit(d);
  end;
  if IsOp('+') then
  begin
    Next;
    Exit(Self.Unary);
  end;
  Result := PowExpr;
end;

function TCompiler.MulExpr: Integer;
var
  a, b, d: Integer;
  op: Integer;
begin
  a := Self.Unary;
  while IsOp('*') or IsOp('/') or IsWord('MOD') do
  begin
    if IsOp('*') then op := opMul else if IsOp('/') then op := opDiv else op := opMod;
    Next;
    b := Self.Unary;
    d := Temp;
    Emit(op, d, a, b, 0);
    a := d;
  end;
  Result := a;
end;

function TCompiler.AddExpr: Integer;
var
  a, b, d, op: Integer;
begin
  a := MulExpr;
  while IsOp('+') or IsOp('-') do
  begin
    if IsOp('+') then op := opAdd else op := opSub;
    Next;
    b := MulExpr;
    d := Temp;
    Emit(op, d, a, b, 0);
    a := d;
  end;
  Result := a;
end;

function TCompiler.CmpExpr: Integer;
var
  a, b, d, op: Integer;
begin
  a := AddExpr;
  while IsOp('=') or IsOp('<>') or IsOp('<') or IsOp('>') or IsOp('<=') or IsOp('>=') do
  begin
    if IsOp('=') then op := opEq
    else if IsOp('<>') then op := opNe
    else if IsOp('<') then op := opLt
    else if IsOp('>') then op := opGt
    else if IsOp('<=') then op := opLe
    else op := opGe;
    Next;
    b := AddExpr;
    d := Temp;
    Emit(op, d, a, b, 0);
    a := d;
  end;
  Result := a;
end;

function TCompiler.NotExpr: Integer;
var
  a, d: Integer;
begin
  if IsWord('NOT') then
  begin
    Next;
    a := Self.NotExpr;
    d := Temp;
    Emit(opNot, d, a, 0, 0);
    Exit(d);
  end;
  Result := CmpExpr;
end;

function TCompiler.AndExpr: Integer;
var
  a, b, d: Integer;
begin
  a := NotExpr;
  while IsWord('AND') do
  begin
    Next;
    b := NotExpr;
    d := Temp;
    Emit(opAnd, d, a, b, 0);
    a := d;
  end;
  Result := a;
end;

function TCompiler.OrExpr: Integer;
var
  a, b, d: Integer;
begin
  a := AndExpr;
  while IsWord('OR') do
  begin
    Next;
    b := AndExpr;
    d := Temp;
    Emit(opOr, d, a, b, 0);
    a := d;
  end;
  Result := a;
end;

function TCompiler.Expr: Integer;
begin
  Result := OrExpr;
end;

// the result of the last instruction goes straight to the variable when it was only in a temporary register
procedure TCompiler.Assign(dst, src: Integer);
begin
  if (src >= TempBase) and (NCode > 0) and (Code[NCode - 1].A = src) and
     not (Code[NCode - 1].Op in [opJmp, opJz, opForChk, opForNext]) then
    Code[NCode - 1].A := dst
  else
    Emit(opMov, dst, src, 0, 0);
end;

procedure TCompiler.Statement;
var
  t: TTok;
  k, v, e, jz, top, chk, lim, stp, i: Integer;
  jumps: array of Integer;
  nm: string;
begin
  t := Cur;
  if t.Kind = tkEOL then
  begin
    Next;
    Exit;
  end;
  if t.Kind <> tkId then Fail('a statement is expected');
  NTemps := 0;
  if t.Text = 'LET' then
  begin
    Next;
    t := Cur;
    if t.Kind <> tkId then Fail('a variable is expected after LET');
  end;
  if t.Text = 'IF' then
  begin
    Next;
    SetLength(jumps, 0);
    NTemps := 0;
    e := Expr;
    if not IsWord('THEN') then Fail('THEN expected');
    Next;
    jz := Emit(opJz, 0, e, 0, 0);
    Block(['ELSEIF', 'ELSE', 'ENDIF']);
    while IsWord('ELSEIF') do
    begin
      SetLength(jumps, Length(jumps) + 1);
      jumps[High(jumps)] := Emit(opJmp, 0, 0, 0, 0);
      Code[jz].A := NCode;
      Next;
      NTemps := 0;
      e := Expr;
      if not IsWord('THEN') then Fail('THEN expected');
      Next;
      jz := Emit(opJz, 0, e, 0, 0);
      Block(['ELSEIF', 'ELSE', 'ENDIF']);
    end;
    if IsWord('ELSE') then
    begin
      SetLength(jumps, Length(jumps) + 1);
      jumps[High(jumps)] := Emit(opJmp, 0, 0, 0, 0);
      Code[jz].A := NCode;
      jz := -1;
      Next;
      Block(['ENDIF']);
    end;
    if not IsWord('ENDIF') then Fail('ENDIF expected');
    Next;
    if jz >= 0 then Code[jz].A := NCode;
    for i := 0 to High(jumps) do Code[jumps[i]].A := NCode;
    Exit;
  end;
  if t.Text = 'FOR' then
  begin
    Next;
    if Cur.Kind <> tkId then Fail('a variable is expected after FOR');
    nm := Cur.Text;
    k := FindName(nm);
    if k < 0 then k := NewVar(nm)
    else if Names[k].Kind <> nkVar then Fail('"' + nm + '" cannot be changed');
    v := Names[k].Reg;
    Next;
    ExpectOp('=');
    NTemps := 0;
    e := Expr;
    Emit(opMov, v, e, 0, 0);
    if not IsWord('TO') then Fail('TO expected');
    Next;
    lim := NewHidden;
    NTemps := 0;
    e := Expr;
    Emit(opMov, lim, e, 0, 0);
    stp := NewHidden;
    if IsWord('STEP') then
    begin
      Next;
      NTemps := 0;
      e := Expr;
      Emit(opMov, stp, e, 0, 0);
    end
    else Emit(opMov, stp, ConstReg(1), 0, 0);
    chk := Emit(opForChk, 0, v, lim, stp);
    top := NCode;
    Block(['NEXT']);
    Next;                                  // NEXT
    if Cur.Kind = tkId then Next;          // NEXT v
    Emit(opForNext, top, v, lim, stp);
    Code[chk].A := NCode;
    Exit;
  end;
  if t.Text = 'WHILE' then
  begin
    Next;
    top := NCode;
    NTemps := 0;
    e := Expr;
    jz := Emit(opJz, 0, e, 0, 0);
    Block(['WEND']);
    Next;
    Emit(opJmp, top, 0, 0, 0);
    Code[jz].A := NCode;
    Exit;
  end;
  // an assignment: name = expr, or name[X, Y] = expr
  nm := t.Text;
  Next;
  if IsOp('[') then
  begin
    Next;
    if not IsWord('X') then Fail('the output can only be written at X, Y');
    Next;
    ExpectOp(',');
    if not IsWord('Y') then Fail('the output can only be written at X, Y');
    Next;
    ExpectOp(']');
    if not ((Length(nm) = 2) and (nm[2] = 'O') and (ChannelCode(nm[1]) >= 0)) then
      Fail('only Ro, Go, Bo, Ho, So, Lo can be written with [X, Y]');
  end;
  if not IsOp('=') then Fail('"=" expected after ' + nm);
  Next;
  k := FindName(nm);
  if k < 0 then
  begin
    // the expression is compiled first: a new variable has no value in it
    e := Expr;
    k := NewVar(nm);
    Assign(Names[k].Reg, e);
  end
  else
  begin
    if Names[k].Kind <> nkVar then
    begin
      if Names[k].Kind = nkParam then Fail('"' + nm + '" is a parameter: its value cannot be changed')
      else if (Length(nm) = 1) and (ChannelCode(nm) >= 0) then Fail('"' + nm + '" is the input and cannot be changed: the result goes to ' + nm + 'o')
      else Fail('"' + nm + '" is a name of the language and cannot be used for a variable');
    end;
    e := Expr;
    Assign(Names[k].Reg, e);
    if Names[k].Reg in [rHo, rSo, rLo] then
    begin
      HslOut := True;
      UsesHsl := True;
    end;
  end;
  if Cur.Kind in [tkNum, tkOp] then Fail('unexpected "' + Cur.Text + '"');
end;

// statements up to one of the words
procedure TCompiler.Block(const enders: array of string);
var
  i: Integer;
begin
  while True do
  begin
    if Cur.Kind = tkEOF then Fail(enders[High(enders)] + ' expected');
    if Cur.Kind = tkId then
      for i := 0 to High(enders) do
        if Cur.Text = enders[i] then Exit;
    Statement;
  end;
end;

procedure TCompiler.Lex(const src: string);
var
  i, line, n: Integer;
  c: Char;
  s: string;
  t: TTok;

  procedure Add(k: TTokKind; const txt: string; num: Double);
  begin
    t.Kind := k;
    t.Text := txt;
    t.Num := num;
    t.Line := line;
    SetLength(Toks, Length(Toks) + 1);
    Toks[High(Toks)] := t;
  end;

begin
  SetLength(Toks, 0);
  line := 1;
  i := 1;
  n := Length(src);
  while i <= n do
  begin
    c := src[i];
    if c = #10 then
    begin
      Add(tkEOL, 'end of line', 0);
      Inc(line);
      Inc(i);
    end
    else if c in [' ', #9, #13] then Inc(i)
    else if c = ':' then
    begin
      Add(tkEOL, ':', 0);
      Inc(i);
    end
    else if c = '''' then
      while (i <= n) and (src[i] <> #10) do Inc(i)
    else if c in ['0'..'9', '.'] then
    begin
      s := '';
      while (i <= n) and (src[i] in ['0'..'9', '.']) do
      begin
        s := s + src[i];
        Inc(i);
      end;
      if (i <= n) and (src[i] in ['e', 'E']) and (i < n) and (src[i + 1] in ['0'..'9', '-', '+']) then
      begin
        s := s + src[i] + src[i + 1];
        Inc(i, 2);
        while (i <= n) and (src[i] in ['0'..'9']) do
        begin
          s := s + src[i];
          Inc(i);
        end;
      end;
      Add(tkNum, s, StrToFloatDef(s, NaN, FS));
      if IsNan(Toks[High(Toks)].Num) then
      begin
        P := High(Toks);
        Fail('bad number "' + s + '"');
      end;
    end
    else if c in ['A'..'Z', 'a'..'z', '_'] then
    begin
      s := '';
      while (i <= n) and (src[i] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do
      begin
        s := s + UpCase(src[i]);
        Inc(i);
      end;
      if s = 'REM' then
      begin
        while (i <= n) and (src[i] <> #10) do Inc(i);
        Continue;
      end;
      Add(tkId, s, 0);
    end
    else if c in ['+', '-', '*', '/', '^', '(', ')', ',', '[', ']', '='] then
    begin
      Add(tkOp, c, 0);
      Inc(i);
    end
    else if c = '<' then
    begin
      if (i < n) and (src[i + 1] = '>') then
      begin
        Add(tkOp, '<>', 0);
        Inc(i, 2);
      end
      else if (i < n) and (src[i + 1] = '=') then
      begin
        Add(tkOp, '<=', 0);
        Inc(i, 2);
      end
      else
      begin
        Add(tkOp, '<', 0);
        Inc(i);
      end;
    end
    else if c = '>' then
    begin
      if (i < n) and (src[i + 1] = '=') then
      begin
        Add(tkOp, '>=', 0);
        Inc(i, 2);
      end
      else
      begin
        Add(tkOp, '>', 0);
        Inc(i);
      end;
    end
    else
    begin
      P := 0;
      SetLength(Toks, Length(Toks) + 1);
      Toks[High(Toks)].Line := line;
      P := High(Toks);
      Fail('unexpected character "' + c + '"');
    end;
  end;
  Add(tkEOF, 'the end', 0);
end;

procedure TCompiler.Finish(out pass: TFltPass);
var
  i, nUser, ofs, tmpBase: Integer;

  function Fix(r: Integer): Integer;
  begin
    if r >= TempBase then Result := tmpBase + (r - TempBase)
    else if r >= ConstBase then Result := ofs + (r - ConstBase)
    else Result := r;
  end;

begin
  nUser := rFirstUser + NVars;
  ofs := nUser;
  tmpBase := ofs + Length(Consts);
  // which fields are registers depends on the instruction
  for i := 0 to NCode - 1 do
    with Code[i] do
      case Op of
        opJmp: ;
        opJz: B := Fix(B);
        opForChk, opForNext:
          begin
            B := Fix(B);
            C := Fix(C);
            D := Fix(D);
          end;
        opAvg:
          begin
            A := Fix(A);
            B := Fix(B);
          end;
        opRd, opRdI:
          begin
            A := Fix(A);
            B := Fix(B);
            C := Fix(C);
          end;
        opClamp, opMix, opSmooth:
          begin
            A := Fix(A);
            B := Fix(B);
            C := Fix(C);
            D := Fix(D);
          end;
      else
        A := Fix(A);
        B := Fix(B);
        C := Fix(C);
      end;
  SetLength(Code, NCode);
  pass.Code := Code;
  pass.NRegs := tmpBase + MaxTemps + 1;
  pass.Consts := Copy(Consts);
  pass.FirstConst := ofs;
  pass.UsesHsl := UsesHsl;
  pass.HslOut := HslOut;
  pass.UsesAvg := UsesAvg;
end;

procedure TCompiler.RunCompile(const src: string; out pass: TFltPass);
const
  Fixed: array[0..18] of string = ('X', 'Y', 'MAXX', 'MAXY', 'SCALE', 'R', 'G', 'B', 'H', 'S', 'L',
    'RO', 'GO', 'BO', 'HO', 'SO', 'LO', 'A', 'AO');
var
  i: Integer;
begin
  Lex(src);
  P := 0;
  SetLength(Names, 0);
  for i := 0 to 18 do
  begin
    SetLength(Names, Length(Names) + 1);
    Names[High(Names)].Name := Fixed[i];
    Names[High(Names)].Reg := i;
    if (i >= 11) and (i <> rA) then Names[High(Names)].Kind := nkVar else Names[High(Names)].Kind := nkReadOnly;
  end;
  for i := 0 to High(ParamNames) do
  begin
    if FindName(UpperCase(ParamNames[i])) >= 0 then Fail('the parameter "' + ParamNames[i] + '" has a reserved name');
    SetLength(Names, Length(Names) + 1);
    Names[High(Names)].Name := UpperCase(ParamNames[i]);
    Names[High(Names)].Reg := rFirstUser + NVars;
    Names[High(Names)].Kind := nkParam;
    Inc(NVars);
  end;
  SetLength(Code, 64);
  NCode := 0;
  while Cur.Kind <> tkEOF do Statement;
  Finish(pass);
end;

{ ---------- the script ---------- }

// splits the source at the lines that are only PASS
function SplitPasses(const src: string): TStringList;
var
  lines: TStringList;
  i: Integer;
  cur: string;
  t: string;
begin
  Result := TStringList.Create;
  lines := TStringList.Create;
  try
    lines.Text := src;
    cur := '';
    for i := 0 to lines.Count - 1 do
    begin
      t := UpperCase(Trim(lines[i]));
      if t = 'PASS' then
      begin
        Result.Add(cur);
        cur := '';
        // the line numbers of the next passes go on from here: blank lines keep them right
        cur := StringOfChar(#10, i + 1);
      end
      else cur := cur + lines[i] + #10;
    end;
    Result.Add(cur);
  finally
    lines.Free;
  end;
end;

function TFltScript.Defaults: TFltValues;
var
  i: Integer;
begin
  SetLength(Result, Length(Params));
  for i := 0 to High(Params) do Result[i] := Params[i].Def;
end;

function TFltScript.UsesPass: Integer;
begin
  Result := Length(Passes);
end;

function TFltScript.Compile(const src: string; out err: string): Boolean;
var
  lines: TStringList;
  pl, body, e2, t: string;
  i, k: Integer;
  parts: TStringList;
  c: TCompiler;
begin
  Result := False;
  err := '';
  SetLength(Passes, 0);
  Params := nil;
  Premul := False;
  // the parameter lines (anywhere in the script) are read first and become blank lines
  lines := TStringList.Create;
  try
    lines.Text := src;
    pl := '';
    for i := 0 to lines.Count - 1 do
    begin
      t := Trim(lines[i]);
      if SameText(t, '@premul') then
      begin
        Premul := True;
        lines[i] := '';
      end
      else if (Length(t) >= 6) and SameText(Copy(t, 1, 6), '@param') then
      begin
        pl := pl + t + #10;
        lines[i] := '';
      end;
    end;
    if not SnipSplit(pl, Params, body, e2) then
    begin
      err := e2;
      Exit;
    end;
    parts := SplitPasses(lines.Text);
  finally
    lines.Free;
  end;
  try
    for i := 0 to parts.Count - 1 do
    begin
      c := TCompiler.Create;
      try
        SetLength(c.ParamNames, Length(Params));
        for k := 0 to High(Params) do c.ParamNames[k] := Params[k].Name;
        SetLength(Passes, Length(Passes) + 1);
        try
          c.RunCompile(parts[i], Passes[High(Passes)]);
        except
          on E: EFlt do
          begin
            err := E.Message;
            if parts.Count > 1 then err := 'pass ' + IntToStr(i + 1) + ', ' + err;
            SetLength(Passes, 0);
            Exit;
          end;
        end;
      finally
        c.Free;
      end;
    end;
  finally
    parts.Free;
  end;
  Result := True;
end;

{ ---------- running ---------- }

type
  PFltPass = ^TFltPass;

  TShared = record
    Pass: PFltPass;
    NParams: Integer;
    Vals: TFltValues;
    Scale: Double;
    W, H: Integer;
    OffX, OffY, FullW, FullH: Integer;
    InR, InG, InB, InA: PByte;
    OutR, OutG, OutB, OutA: PByte;
    IR, IG, IB, IA: PLongWord;
    X0, X1, Y0, Y1: Integer;
    NextRow: LongInt;
    Failed: Boolean;
    Slow: Boolean;
    Deadline: QWord;
    Done: LongInt;            // workers that have finished
  end;
  PShared = ^TShared;

  TFltWorker = class(TThread)
  public
    S: PShared;
    constructor Create(sh: PShared);
    procedure Work;
    procedure Execute; override;
  end;

constructor TFltWorker.Create(sh: PShared);
begin
  S := sh;
  inherited Create(True);
end;

procedure TFltWorker.Execute;
begin
  try
    Work;
  finally
    InterLockedIncrement(S^.Done);
  end;
end;

procedure TFltWorker.Work;
var
  cx: TCtx;
  regs: array of Double;
  p: PFltPass;
  i, x, y, k, nUser, zeroFrom: Integer;
  code: PFltIns;
  nCode: Integer;
  h0, s0, l0, colR, colG, colB: Double;
  useHsl, hslOut: Boolean;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  p := S^.Pass;
  SetLength(regs, p^.NRegs);
  for i := 0 to High(regs) do regs[i] := 0;
  cx.Reg := @regs[0];
  cx.W := S^.W;
  cx.H := S^.H;
  cx.OffX := S^.OffX;
  cx.OffY := S^.OffY;
  cx.R := S^.InR;
  cx.G := S^.InG;
  cx.B := S^.InB;
  cx.A := S^.InA;
  cx.IR := S^.IR;
  cx.IG := S^.IG;
  cx.IB := S^.IB;
  cx.IA := S^.IA;
  cx.TooSlow := False;
  regs[rMaxX] := S^.FullW - 1;
  regs[rMaxY] := S^.FullH - 1;
  regs[rScale] := S^.Scale;
  regs[rPi] := Pi;
  for i := 0 to S^.NParams - 1 do regs[rFirstUser + i] := S^.Vals[i];
  for i := 0 to High(p^.Consts) do regs[p^.FirstConst + i] := p^.Consts[i];
  zeroFrom := rFirstUser + S^.NParams;
  nUser := p^.FirstConst;
  code := PFltIns(Pointer(p^.Code));
  nCode := Length(p^.Code);
  useHsl := p^.UsesHsl;
  hslOut := p^.HslOut;
  h0 := 0; s0 := 0; l0 := 0;
  while not S^.Failed do
  begin
    y := S^.Y0 + InterlockedIncrement(S^.NextRow) - 1;
    if y >= S^.Y1 then Break;
    if GetTickCount64 > S^.Deadline then
    begin
      S^.Slow := True;
      S^.Failed := True;
      Break;
    end;
    for x := S^.X0 to S^.X1 - 1 do
    begin
      k := y * S^.W + x;
      for i := zeroFrom to nUser - 1 do regs[i] := 0;
      regs[rX] := x + S^.OffX;
      regs[rY] := y + S^.OffY;
      regs[rR] := S^.InR[k];
      regs[rG] := S^.InG[k];
      regs[rB] := S^.InB[k];
      regs[rA] := S^.InA[k];
      regs[rAo] := regs[rA];
      regs[rRo] := regs[rR];
      regs[rGo] := regs[rG];
      regs[rBo] := regs[rB];
      if useHsl then
      begin
        RgbToHsl(regs[rR], regs[rG], regs[rB], h0, s0, l0);
        regs[rH] := h0; regs[rS] := s0; regs[rL] := l0;
        regs[rHo] := h0; regs[rSo] := s0; regs[rLo] := l0;
      end;
      cx.Budget := MaxBudget;
      Exec(cx, code, nCode);
      if cx.TooSlow then
      begin
        S^.Slow := True;
        S^.Failed := True;
        Break;
      end;
      S^.OutA[k] := Clamp255(regs[rAo]);
      if hslOut and ((Abs(regs[rHo] - h0) > 1e-7) or (Abs(regs[rSo] - s0) > 1e-7) or (Abs(regs[rLo] - l0) > 1e-7)) then
      begin
        HslToRgb(regs[rHo], regs[rSo], regs[rLo], colR, colG, colB);
        S^.OutR[k] := Clamp255(colR);
        S^.OutG[k] := Clamp255(colG);
        S^.OutB[k] := Clamp255(colB);
      end
      else
      begin
        S^.OutR[k] := Clamp255(regs[rRo]);
        S^.OutG[k] := Clamp255(regs[rGo]);
        S^.OutB[k] := Clamp255(regs[rBo]);
      end;
    end;
  end;
end;

function TFltScript.Run(var img: TFltImage; const vals: TFltValues; scale: Double; roi: TRect; out err: string): Boolean;
begin
  Result := RunAt(img, vals, scale, roi, 0, 0, img.W, img.H, err);
end;

function TFltScript.RunAt(var img: TFltImage; const vals: TFltValues; scale: Double; roi: TRect; offX, offY, fullW, fullH: Integer;
  out err: string): Boolean;
var
  pi_, i, nth, n: Integer;
  sh: TShared;
  outR, outG, outB, outA: array of Byte;
  sumR, sumG, sumB, sumA: array of LongWord;
  x, y, st, k: Integer;
  ar, ag, ab, aa: LongWord;
  ws: array of TFltWorker;
  v: TFltValues;
begin
  Result := False;
  err := '';
  if Length(Passes) = 0 then
  begin
    err := 'the script has not been compiled';
    Exit;
  end;
  if Length(img.A) <> img.W * img.H then
  begin
    SetLength(img.A, img.W * img.H);
    FillChar(img.A[0], img.W * img.H, 255);
  end;
  roi.Left := Max(0, roi.Left);
  roi.Top := Max(0, roi.Top);
  roi.Right := Min(img.W, roi.Right);
  roi.Bottom := Min(img.H, roi.Bottom);
  if (roi.Right <= roi.Left) or (roi.Bottom <= roi.Top) then Exit(True);
  SetLength(v, Length(Params));
  for i := 0 to High(v) do
    if i <= High(vals) then v[i] := vals[i] else v[i] := Params[i].Def;
  if Premul then
    for k := 0 to img.W * img.H - 1 do
    begin
      img.R[k] := (img.R[k] * img.A[k] + 127) div 255;
      img.G[k] := (img.G[k] * img.A[k] + 127) div 255;
      img.B[k] := (img.B[k] * img.A[k] + 127) div 255;
    end;
  nth := Max(1, Min(8, TThread.ProcessorCount));
  if FltThreads > 0 then nth := FltThreads;
  for pi_ := 0 to High(Passes) do
  begin
    outR := Copy(img.R);
    outG := Copy(img.G);
    outB := Copy(img.B);
    outA := Copy(img.A);
    sh.Pass := @Passes[pi_];
    sh.NParams := Length(Params);
    sh.Vals := v;
    sh.Scale := scale;
    sh.W := img.W;
    sh.H := img.H;
    sh.OffX := offX;
    sh.OffY := offY;
    sh.FullW := fullW;
    sh.FullH := fullH;
    sh.InR := @img.R[0];
    sh.InG := @img.G[0];
    sh.InB := @img.B[0];
    sh.InA := @img.A[0];
    sh.OutR := @outR[0];
    sh.OutG := @outG[0];
    sh.OutB := @outB[0];
    sh.OutA := @outA[0];
    if pi_ < High(Passes) then
    begin
      sh.X0 := 0; sh.X1 := img.W; sh.Y0 := 0; sh.Y1 := img.H;
    end
    else
    begin
      sh.X0 := roi.Left; sh.X1 := roi.Right; sh.Y0 := roi.Top; sh.Y1 := roi.Bottom;
    end;
    sh.IR := nil; sh.IG := nil; sh.IB := nil; sh.IA := nil;
    if Passes[pi_].UsesAvg then
    begin
      // sum[y][x] = the sum of the pixels above and to the left of (x, y), the pixel itself not included
      st := img.W + 1;
      SetLength(sumR, st * (img.H + 1));
      SetLength(sumG, st * (img.H + 1));
      SetLength(sumB, st * (img.H + 1));
      SetLength(sumA, st * (img.H + 1));
      for x := 0 to img.W do begin sumR[x] := 0; sumG[x] := 0; sumB[x] := 0; sumA[x] := 0; end;
      for y := 0 to img.H - 1 do
      begin
        ar := 0; ag := 0; ab := 0; aa := 0;
        sumR[(y + 1) * st] := 0; sumG[(y + 1) * st] := 0; sumB[(y + 1) * st] := 0; sumA[(y + 1) * st] := 0;
        for x := 0 to img.W - 1 do
        begin
          k := y * img.W + x;
          Inc(ar, img.R[k]); Inc(ag, img.G[k]); Inc(ab, img.B[k]); Inc(aa, img.A[k]);
          sumR[(y + 1) * st + x + 1] := sumR[y * st + x + 1] + ar;
          sumG[(y + 1) * st + x + 1] := sumG[y * st + x + 1] + ag;
          sumB[(y + 1) * st + x + 1] := sumB[y * st + x + 1] + ab;
          sumA[(y + 1) * st + x + 1] := sumA[y * st + x + 1] + aa;
        end;
      end;
      sh.IR := @sumR[0]; sh.IG := @sumG[0]; sh.IB := @sumB[0]; sh.IA := @sumA[0];
    end;
    sh.NextRow := 0;
    sh.Failed := False;
    sh.Slow := False;
    sh.Deadline := GetTickCount64 + 60000;
    sh.Done := 0;
    n := Min(nth, sh.Y1 - sh.Y0);
    SetLength(ws, n);
    for i := 0 to n - 1 do
    begin
      ws[i] := TFltWorker.Create(@sh);
      ws[i].Start;
    end;
    // (TThread.WaitFor of the main thread sleeps in steps of 100 ms: the end of the workers is waited for here)
    while sh.Done < n do Sleep(1);
    for i := 0 to n - 1 do
    begin
      ws[i].WaitFor;
      ws[i].Free;
    end;
    if sh.Slow then
    begin
      err := 'the filter takes too long (a loop that does not end, or too much work for every pixel)';
      Exit;
    end;
    img.R := outR;
    img.G := outG;
    img.B := outB;
    img.A := outA;
  end;
  if Premul then
    for k := 0 to img.W * img.H - 1 do
      if img.A[k] > 0 then
      begin
        img.R[k] := Min(255, (img.R[k] * 255 + img.A[k] div 2) div img.A[k]);
        img.G[k] := Min(255, (img.G[k] * 255 + img.A[k] div 2) div img.A[k]);
        img.B[k] := Min(255, (img.B[k] * 255 + img.A[k] div 2) div img.A[k]);
      end;
  Result := True;
end;

{ ---------- the filters that come with the program ---------- }

const
  BuiltinNames: array[0..7] of string = (
    'Contrast / Luminance / Saturation', 'Gaussian blur', 'Hue / Saturation / Lightness', 'Invert', 'Gray scale',
    'Replace color', 'Color range offset', 'Soft clipping');

function FltBuiltinCount: Integer;
begin
  Result := Length(BuiltinNames);
end;

function FltBuiltinName(i: Integer): string;
begin
  Result := BuiltinNames[i];
end;

function FltBuiltinScript(i: Integer): string;
begin
  case i of
    0: Result :=
      '@param Contrast = 0 [-100,100,1] "Contrast"'#10 +
      '@param Luminance = 0 [-100,100,1] "Luminance"'#10 +
      '@param Saturation = 0 [-100,100,1] "Saturation"'#10 +
      ''' contrast -100 flattens everything to grey, 0 changes nothing, near 100 it is almost black and white'#10 +
      'k = 1 + Saturation / 100'#10 +
      'cf = TAN((CLAMP(Contrast, -100, 99.5) + 100) / 200 * PI / 2)'#10 +
      'lum = 0.299 * R + 0.587 * G + 0.114 * B'#10 +
      'Ro = (lum + (R - lum) * k - 128) * cf + 128 + Luminance * 2.55'#10 +
      'Go = (lum + (G - lum) * k - 128) * cf + 128 + Luminance * 2.55'#10 +
      'Bo = (lum + (B - lum) * k - 128) * cf + 128 + Luminance * 2.55'#10;
    1: Result :=
      '@param Radius = 4 [0,60,0.5] "Radius"'#10 +
      '@premul'#10 +
      ''' @premul: R, G, B come multiplied by the opacity A, so the transparent parts do not darken the edges'#10 +
      ''' three box blurs one after the other make a gaussian blur.  A box blur is the mean of a square, computed'#10 +
      ''' from sums that are prepared once (AVGR, AVGG, AVGB), so the time does not depend on the radius.'#10 +
      ''' The radius is in units of the drawing: the result does not change with the zoom.'#10 +
      'sig = Radius * SCALE / 2'#10 +
      'rad = ROUND(SQR(sig * sig + 0.25) - 0.5)'#10 +
      'Ro = AVGR(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Go = AVGG(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Bo = AVGB(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Ao = AVGA(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'PASS'#10 +
      'sig = Radius * SCALE / 2'#10 +
      'rad = ROUND(SQR(sig * sig + 0.25) - 0.5)'#10 +
      'Ro = AVGR(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Go = AVGG(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Bo = AVGB(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Ao = AVGA(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'PASS'#10 +
      'sig = Radius * SCALE / 2'#10 +
      'rad = ROUND(SQR(sig * sig + 0.25) - 0.5)'#10 +
      'Ro = AVGR(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Go = AVGG(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Bo = AVGB(X - rad, Y - rad, X + rad, Y + rad)'#10 +
      'Ao = AVGA(X - rad, Y - rad, X + rad, Y + rad)'#10;
    2: Result :=
      '@param Hue = 0 [-180,180,1] "Hue shift (degrees)"'#10 +
      '@param Saturation = 0 [-100,100,1] "Saturation"'#10 +
      '@param Lightness = 0 [-100,100,1] "Lightness"'#10 +
      ''' H is in degrees, S and L from 0 to 100'#10 +
      'Ho = H + Hue'#10 +
      'So = S * (1 + Saturation / 100)'#10 +
      'IF Lightness >= 0 THEN'#10 +
      '  Lo = L + (100 - L) * Lightness / 100'#10 +
      'ELSE'#10 +
      '  Lo = L * (1 + Lightness / 100)'#10 +
      'ENDIF'#10;
    3: Result :=
      'Ro = 255 - R'#10 +
      'Go = 255 - G'#10 +
      'Bo = 255 - B'#10;
    4: Result :=
      ''' the grey of each pixel: the weighted mean of the three colours'#10 +
      'lum = 0.299 * R + 0.587 * G + 0.114 * B'#10 +
      'Ro = lum : Go = lum : Bo = lum'#10;
    5: Result :=
      '@param MinRed = 240 [0,255,1] "Red from"'#10 +
      '@param MaxRed = 255 [0,255,1] "Red to"'#10 +
      '@param MinGreen = 240 [0,255,1] "Green from"'#10 +
      '@param MaxGreen = 255 [0,255,1] "Green to"'#10 +
      '@param MinBlue = 240 [0,255,1] "Blue from"'#10 +
      '@param MaxBlue = 255 [0,255,1] "Blue to"'#10 +
      '@param OutRed = 255 [0,255,1] "New red"'#10 +
      '@param OutGreen = 0 [0,255,1] "New green"'#10 +
      '@param OutBlue = 0 [0,255,1] "New blue"'#10 +
      ''' the pixels whose three colours are inside the ranges take the new colour (the opacity stays)'#10 +
      'IF R >= MinRed AND R <= MaxRed AND G >= MinGreen AND G <= MaxGreen AND B >= MinBlue AND B <= MaxBlue THEN'#10 +
      '  Ro = OutRed'#10 +
      '  Go = OutGreen'#10 +
      '  Bo = OutBlue'#10 +
      'ENDIF'#10;
    6: Result :=
      '@param MinRed = 0 [0,255,1] "Red from"'#10 +
      '@param MaxRed = 255 [0,255,1] "Red to"'#10 +
      '@param MinGreen = 0 [0,255,1] "Green from"'#10 +
      '@param MaxGreen = 255 [0,255,1] "Green to"'#10 +
      '@param MinBlue = 0 [0,255,1] "Blue from"'#10 +
      '@param MaxBlue = 255 [0,255,1] "Blue to"'#10 +
      '@param OffsetRed = 0 [-255,255,1] "Red offset"'#10 +
      '@param OffsetGreen = 0 [-255,255,1] "Green offset"'#10 +
      '@param OffsetBlue = 0 [-255,255,1] "Blue offset"'#10 +
      ''' the pixels whose three colours are inside the ranges get the offsets added; the results are kept between 0 and 255 by the'#10 +
      ''' script itself, so no MIN / MAX is needed'#10 +
      'IF R >= MinRed AND R <= MaxRed AND G >= MinGreen AND G <= MaxGreen AND B >= MinBlue AND B <= MaxBlue THEN'#10 +
      '  Ro = R + OffsetRed'#10 +
      '  Go = G + OffsetGreen'#10 +
      '  Bo = B + OffsetBlue'#10 +
      'ENDIF'#10;
  else
    Result :=
      '@param MinRed = 0 [0,255,1] "Red from"'#10 +
      '@param MaxRed = 255 [0,255,1] "Red to"'#10 +
      '@param MinGreen = 0 [0,255,1] "Green from"'#10 +
      '@param MaxGreen = 255 [0,255,1] "Green to"'#10 +
      '@param MinBlue = 0 [0,255,1] "Blue from"'#10 +
      '@param MaxBlue = 255 [0,255,1] "Blue to"'#10 +
      '@param OffsetRed = 0 [-255,255,1] "Red offset"'#10 +
      '@param OffsetGreen = 0 [-255,255,1] "Green offset"'#10 +
      '@param OffsetBlue = 0 [-255,255,1] "Blue offset"'#10 +
      '@param Softness = 2 [0.1,6,0.1] "Softness (higher: the offset is full over a wider part of the range)"'#10 +
      ''' like "Color range offset", but the offset fades out towards the ends of the ranges instead of stopping at once.'#10 +
      ''' For each colour d goes from 0 (at an end of the range) to 1 (in the middle), and tanh(Softness * d) / tanh(Softness) is'#10 +
      ''' the share of the offset that is applied; the three shares are multiplied, so the offset is full only in the centre of the'#10 +
      ''' range of the three colours and is zero on its border.'#10 +
      'IF R >= MinRed AND R <= MaxRed AND G >= MinGreen AND G <= MaxGreen AND B >= MinBlue AND B <= MaxBlue THEN'#10 +
      '  k = TANH(Softness)'#10 +
      '  wr = TANH(Softness * MIN(R - MinRed, MaxRed - R) * 2 / MAX(MaxRed - MinRed, 1)) / k'#10 +
      '  wg = TANH(Softness * MIN(G - MinGreen, MaxGreen - G) * 2 / MAX(MaxGreen - MinGreen, 1)) / k'#10 +
      '  wb = TANH(Softness * MIN(B - MinBlue, MaxBlue - B) * 2 / MAX(MaxBlue - MinBlue, 1)) / k'#10 +
      '  w = wr * wg * wb'#10 +
      '  Ro = R + OffsetRed * w'#10 +
      '  Go = G + OffsetGreen * w'#10 +
      '  Bo = B + OffsetBlue * w'#10 +
      'ENDIF'#10;
  end;
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

end.
