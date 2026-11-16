{ Outlines of the letters of a text, read from a font file (for "Convert text to path / polygons"). }
unit ttglyph;

{$mode objfpc}{$H+}
{$R-}      // the outline arrays of the font library are declared with a fixed size of 100

interface

uses
  Classes, SysUtils, ttmodel;

type
  TGlyphPoint = record
    X, Y: Double;           // pixels, y down, origin on the baseline at the pen position
    OnCurve: Boolean;
  end;
  TGlyphContour = array of TGlyphPoint;

  TGlyph = record
    X, Y: Double;           // pen position (on the baseline) from the top-left corner of the text
    Contours: array of TGlyphContour;
  end;
  TGlyphArray = array of TGlyph;
  TPolyArray = array of TPtArray;

// the letters of txt (one line per #10) laid out like the screen does, font size fs in pixels
function TextGlyphs(const txt, fontName: string; fs: Double; out glyphs: TGlyphArray; out err: string): Boolean;
// SVG path data of one glyph, relative to its pen position
function GlyphPathData(const g: TGlyph): string;
// the glyph as closed polygons, one for every separate part (the holes are joined to the outside with a zero-width cut)
function GlyphPolygons(const g: TGlyph; fs: Double): TPolyArray;

implementation

uses
  Math, Process, LazUTF8, EasyLazFreeType, LazFreeTypeFontCollection, tttypes, lazfreetype;

const
  EmPx = 1024;              // the outlines are read at this size and scaled down

var
  FontObj: TFreeTypeFont = nil;
  FontObjName: string = '';
  FontErr: string = '';

function Num(v: Double): string;
begin
  Result := FormatFloat('0.###', v, DefaultFormatSettings);
  if Result = '-0' then Result := '0';
  Result := StringReplace(Result, ',', '.', []);
end;

function FindFontFile(const name: string): string;
var
  outp: string;
  fam: string;
begin
  Result := '';
  if name = '' then fam := 'sans-serif' else fam := name;
  if RunCommand('fc-match', ['-f', '%{file}', fam], outp) then
    Result := Trim(outp);
  if (Result = '') or not FileExists(Result) then
    Result := '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
end;

function EnsureFont(const name: string): Boolean;
var
  fn: string;
  item: TCustomFontCollectionItem;
begin
  if (FontObj <> nil) and (FontObjName = name) then Exit(True);
  FreeAndNil(FontObj);
  Result := False;
  fn := FindFontFile(name);
  if not FileExists(fn) then
  begin
    FontErr := 'no font file found (' + fn + ')';
    Exit;
  end;
  try
    item := FontCollection.AddFile(fn);
    if item = nil then
    begin
      FontErr := 'cannot read the font ' + fn;
      Exit;
    end;
    FontObj := item.CreateFont;
    FontObj.Hinted := False;
    FontObj.SizeInPixels := EmPx;
    FontObjName := name;
    Result := True;
  except
    on E: Exception do FontErr := E.Message;
  end;
end;

function TextGlyphs(const txt, fontName: string; fs: Double; out glyphs: TGlyphArray; out err: string): Boolean;
var
  line: string;
  lines: TStringList;
  li, p, len, k, c, e0, gi, cp, n: Integer;
  pen, sc, asc, lh: Double;
  gl: TFreeTypeGlyph;
  ol: TT_Outline;
  g: TGlyph;
  cn: TGlyphContour;
begin
  Result := False;
  err := '';
  glyphs := nil;
  if not EnsureFont(fontName) then
  begin
    err := FontErr;
    Exit;
  end;
  sc := fs / EmPx;
  asc := FontObj.Ascent * sc;
  lh := FontObj.LineFullHeight * sc;
  lines := TStringList.Create;
  try
    lines.Text := StringReplace(txt, #13, '', [rfReplaceAll]);
    for li := 0 to lines.Count - 1 do
    begin
      line := lines[li];
      pen := 0;
      p := 1;
      len := Length(line);
      while p <= len do
      begin
        cp := UTF8CodepointToUnicode(PChar(@line[p]), n);
        if n < 1 then n := 1;
        Inc(p, n);
        gi := FontObj.CharIndex[cp];
        gl := FontObj.Glyph[gi];
        if gl = nil then Continue;
        g.X := pen;
        g.Y := asc + li * lh;
        g.Contours := nil;
        if TT_Get_Glyph_Outline(gl.Data, ol) = TT_Err_Ok then
        begin
          e0 := 0;
          for k := 0 to ol.n_contours - 1 do
          begin
            cn := nil;
            SetLength(cn, ol.conEnds^[k] - e0 + 1);
            for c := e0 to ol.conEnds^[k] do
            begin
              cn[c - e0].X := ol.points^[c].x / 64 * sc;
              cn[c - e0].Y := -ol.points^[c].y / 64 * sc;
              cn[c - e0].OnCurve := (ol.flags^[c] and 1) <> 0;
            end;
            e0 := ol.conEnds^[k] + 1;
            if Length(cn) >= 2 then
            begin
              SetLength(g.Contours, Length(g.Contours) + 1);
              g.Contours[High(g.Contours)] := Copy(cn);
            end;
          end;
        end;
        if Length(g.Contours) > 0 then
        begin
          SetLength(glyphs, Length(glyphs) + 1);
          glyphs[High(glyphs)] := g;
        end;
        pen := pen + gl.Advance * sc;
      end;
    end;
  finally
    lines.Free;
  end;
  Result := True;
end;

type
  TSeg = record
    Quad: Boolean;
    C, E: TPt;              // control point (quadratic only) and end point
  end;
  TSegArray = array of TSeg;

// a contour as a start point and a closed run of segments (lines and quadratic curves)
procedure Decompose(const c: TGlyphContour; out start: TPt; out segs: TSegArray);
var
  cnt, st, i, n: Integer;
  a, b: TGlyphPoint;
  sg: TSeg;

  function At(k: Integer): TGlyphPoint;
  begin
    Result := c[(k + cnt) mod cnt];
  end;

  procedure Add;
  begin
    SetLength(segs, Length(segs) + 1);
    segs[High(segs)] := sg;
  end;

begin
  segs := nil;
  cnt := Length(c);
  st := -1;
  for i := 0 to cnt - 1 do
    if c[i].OnCurve then
    begin
      st := i;
      Break;
    end;
  if st >= 0 then
  begin
    start := MakePt(c[st].X, c[st].Y);
    i := st + 1;
    n := cnt - 1;
  end
  else
  begin
    // only off-curve points: start in the middle of the last and the first
    start := MakePt((c[0].X + c[cnt - 1].X) / 2, (c[0].Y + c[cnt - 1].Y) / 2);
    i := 0;
    n := cnt;
  end;
  while n > 0 do
  begin
    a := At(i);
    if a.OnCurve then
    begin
      sg.Quad := False;
      sg.C := start;
      sg.E := MakePt(a.X, a.Y);
      Add;
      Inc(i);
      Dec(n);
    end
    else
    begin
      sg.Quad := True;
      sg.C := MakePt(a.X, a.Y);
      if n = 1 then
      begin
        sg.E := start;
        Inc(i);
        Dec(n);
      end
      else
      begin
        b := At(i + 1);
        if b.OnCurve then
        begin
          sg.E := MakePt(b.X, b.Y);
          Inc(i, 2);
          Dec(n, 2);
        end
        else
        begin
          sg.E := MakePt((a.X + b.X) / 2, (a.Y + b.Y) / 2);
          Inc(i);
          Dec(n);
        end;
      end;
      Add;
    end;
  end;
end;

function GlyphPathData(const g: TGlyph): string;
var
  k, i: Integer;
  st: TPt;
  segs: TSegArray;
begin
  Result := '';
  for k := 0 to High(g.Contours) do
  begin
    Decompose(g.Contours[k], st, segs);
    Result := Result + 'M' + Num(st.x) + ' ' + Num(st.y);
    for i := 0 to High(segs) do
      if segs[i].Quad then
        Result := Result + 'Q' + Num(segs[i].C.x) + ' ' + Num(segs[i].C.y) + ' ' + Num(segs[i].E.x) + ' ' + Num(segs[i].E.y)
      else
        Result := Result + 'L' + Num(segs[i].E.x) + ' ' + Num(segs[i].E.y);
    Result := Result + 'Z';
  end;
end;

// the contour as points: the curves are cut into short straight pieces
function Flatten(const c: TGlyphContour; steps: Integer): TPtArray;
var
  i, j: Integer;
  st, cur: TPt;
  t: Double;
  segs: TSegArray;
begin
  Decompose(c, st, segs);
  Result := nil;
  SetLength(Result, 1);
  Result[0] := st;
  cur := st;
  for i := 0 to High(segs) do
  begin
    if segs[i].Quad then
      for j := 1 to steps do
      begin
        t := j / steps;
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := MakePt(
          (1 - t) * (1 - t) * cur.x + 2 * (1 - t) * t * segs[i].C.x + t * t * segs[i].E.x,
          (1 - t) * (1 - t) * cur.y + 2 * (1 - t) * t * segs[i].C.y + t * t * segs[i].E.y);
      end
    else
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := segs[i].E;
    end;
    cur := segs[i].E;
  end;
  // the last point repeats the first one
  if (Length(Result) > 1) and (Hypot(Result[High(Result)].x - Result[0].x, Result[High(Result)].y - Result[0].y) < 1e-6) then
    SetLength(Result, Length(Result) - 1);
end;

function SignedArea(const p: TPtArray): Double;
var
  i, j: Integer;
begin
  Result := 0;
  for i := 0 to High(p) do
  begin
    j := (i + 1) mod Length(p);
    Result := Result + p[i].x * p[j].y - p[j].x * p[i].y;
  end;
  Result := Result / 2;
end;

function Inside(const p: TPtArray; x, y: Double): Boolean;
var
  i, j: Integer;
begin
  Result := False;
  j := High(p);
  for i := 0 to High(p) do
  begin
    if ((p[i].y > y) <> (p[j].y > y)) and
       (x < (p[j].x - p[i].x) * (y - p[i].y) / (p[j].y - p[i].y) + p[i].x) then
      Result := not Result;
    j := i;
  end;
end;

// outline with a hole joined to it through the closest pair of points (a cut of zero width)
function JoinHole(const outer, hole: TPtArray): TPtArray;
var
  a, b, bi, bj, i: Integer;
  d, bd: Double;
begin
  bd := 1e300;
  bi := 0;
  bj := 0;
  for a := 0 to High(outer) do
    for b := 0 to High(hole) do
    begin
      d := Sqr(outer[a].x - hole[b].x) + Sqr(outer[a].y - hole[b].y);
      if d < bd then
      begin
        bd := d;
        bi := a;
        bj := b;
      end;
    end;
  Result := nil;
  SetLength(Result, Length(outer) + Length(hole) + 2);
  for i := 0 to bi do Result[i] := outer[i];
  for i := 0 to Length(hole) do Result[bi + 1 + i] := hole[(bj + i) mod Length(hole)];
  for i := bi to High(outer) do Result[Length(hole) + 2 + i] := outer[i];
end;

function GlyphPolygons(const g: TGlyph; fs: Double): TPolyArray;
var
  rings, polys: array of TPtArray;
  area: array of Double;
  isHole: array of Boolean;
  steps, k, j, best: Integer;
  bigSign, d: Double;
begin
  Result := nil;
  steps := Max(3, Min(12, Round(fs / 6)));
  SetLength(rings, Length(g.Contours));
  SetLength(polys, Length(g.Contours));
  SetLength(area, Length(g.Contours));
  SetLength(isHole, Length(g.Contours));
  bigSign := 0;
  d := 0;
  for k := 0 to High(rings) do
  begin
    rings[k] := Flatten(g.Contours[k], steps);
    polys[k] := rings[k];
    area[k] := SignedArea(rings[k]);
    if Abs(area[k]) > d then
    begin
      d := Abs(area[k]);
      bigSign := area[k];
    end;
  end;
  // a ring turning the other way than the biggest one is a hole (of the smallest ring around it)
  for k := 0 to High(rings) do
    isHole[k] := (area[k] * bigSign < 0) and (Length(rings[k]) > 2);
  for k := 0 to High(rings) do
    if isHole[k] then
    begin
      best := -1;
      for j := 0 to High(rings) do
        if (not isHole[j]) and (Length(rings[j]) > 2) and (Abs(area[j]) > Abs(area[k])) and
           Inside(rings[j], rings[k][0].x, rings[k][0].y) then
          if (best < 0) or (Abs(area[j]) < Abs(area[best])) then best := j;
      if best >= 0 then polys[best] := JoinHole(polys[best], rings[k])
      else isHole[k] := False;                 // nothing around it: it stays a polygon of its own
    end;
  for k := 0 to High(rings) do
    if (not isHole[k]) and (Length(polys[k]) > 2) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := polys[k];
    end;
end;

finalization
  FontObj.Free;

end.
