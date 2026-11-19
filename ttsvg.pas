unit TTSvg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DOM, XMLRead, TTModel, TTFill, TTScript, TTMat;

type
  TIntArray = array of Integer;

{ Serialises the document (or only the shapes listed in `only` when `subset`
  is true, together with the constraints that involve only those shapes).
  Geometry is stored in standard SVG attributes AND, exactly, in ttp:* attributes;
  constraints and quotes live in <metadata><ttp:document>. }
function DocToSVG(doc: TDoc; subset: Boolean; const only: TIntArray; withQuotes: Boolean = False): string;

{ Loads an SVG. append=False replaces the document content. With append=True the
  shapes are added with fresh ids and moved by (dx,dy); their new ids are returned. }

procedure SVGToDoc(const text: string; doc: TDoc; append: Boolean;
  dx, dy: Double; out newIds: TIntArray);

{ The size of the drawing in an SVG text (width / height, or its viewBox); False when it cannot be read. }
function SvgSize(const text: string; out w, h: Double): Boolean;

function ShapeToSVG(s: TShape): string;
function ColorToSvg(c: Integer): string;
function FloatStr(v: Double): string;

implementation

const
  NS = 'https://ttpaint.local/ns';

var
  FS: TFormatSettings;

function FloatStr(v: Double): string;
begin
  Result := FormatFloat('0.####', v, FS);
  if (Result = '-0') or (Result = '') then Result := '0';
end;

function ColorToSvg(c: Integer): string;
begin
  if c = NoColor then Exit('none');
  Result := '#' + IntToHex(c and $FF, 2) + IntToHex((c shr 8) and $FF, 2) +
    IntToHex((c shr 16) and $FF, 2);
end;

function SvgToColor(const s0: string; def: Integer): Integer;
var
  s: string;
  r, g, b: Integer;
begin
  s := LowerCase(Trim(s0));
  if s = '' then Exit(def);
  if (s = 'none') or (s = 'transparent') then Exit(NoColor);
  if s[1] = '#' then
  begin
    if Length(s) = 4 then
      s := '#' + s[2] + s[2] + s[3] + s[3] + s[4] + s[4];
    if Length(s) = 7 then
    begin
      r := StrToIntDef('$' + Copy(s, 2, 2), 0);
      g := StrToIntDef('$' + Copy(s, 4, 2), 0);
      b := StrToIntDef('$' + Copy(s, 6, 2), 0);
      Exit(r or (g shl 8) or (b shl 16));
    end;
    Exit(def);
  end;
  if s = 'black' then Exit(0);
  if s = 'white' then Exit($FFFFFF);
  if s = 'red' then Exit($0000FF);
  if s = 'green' then Exit($008000);
  if s = 'blue' then Exit($FF0000);
  if s = 'yellow' then Exit($00FFFF);
  if s = 'gray' then Exit($808080);
  if s = 'grey' then Exit($808080);
  if s = 'orange' then Exit($00A5FF);
  Result := def;
end;

function AngStr(v: Double): string;
begin
  Result := FormatFloat('0.########', v, FS);
  if (Result = '-0') or (Result = '') then Result := '0';
end;

function Esc(const s: string): string;
begin
  Result := StringReplace(s, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function PtsStr(const p: TPtArray; sep: string = ' '): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(p) do
  begin
    if i > 0 then Result := Result + sep;
    Result := Result + FloatStr(p[i].x) + ',' + FloatStr(p[i].y);
  end;
end;

function DashArray(const st: TStyle): string;
var
  w: Double;
begin
  w := Max(1, st.Width);
  case st.Dash of
    dsDash: Result := FloatStr(w * 4) + ' ' + FloatStr(w * 2);
    dsDot: Result := FloatStr(w) + ' ' + FloatStr(w * 2);
    dsDashDot: Result := FloatStr(w * 4) + ' ' + FloatStr(w * 2) + ' ' + FloatStr(w) + ' ' + FloatStr(w * 2);
  else
    Result := '';
  end;
end;

function StyleAttrs(const st: TStyle; filled: Boolean): string;
const
  Caps: array[TLineCap] of string = ('butt', 'round', 'square');
  Joins: array[TLineJoin] of string = ('miter', 'round', 'bevel');
begin
  Result := ' stroke="' + ColorToSvg(st.Stroke) + '"';
  if st.Stroke <> NoColor then
  begin
    Result := Result + ' stroke-width="' + FloatStr(st.Width) + '"' +
      ' stroke-linecap="' + Caps[st.Cap] + '"' +
      ' stroke-linejoin="' + Joins[st.Join] + '"';
    if DashArray(st) <> '' then
      Result := Result + ' stroke-dasharray="' + DashArray(st) + '"';
  end;
  if StrokeMaterial(st) > 0 then Result := Result + ' ttp:smat="' + IntToStr(StrokeMaterial(st)) + '"';
  if (st.Stroke <> NoColor) and (st.StrokeTr > 0) then
    Result := Result + ' stroke-opacity="' + FormatFloat('0.###', (255 - st.StrokeTr) / 255, FS) + '"';
  if filled then
  begin
    Result := Result + ' fill="' + ColorToSvg(st.Fill) + '"';
    if FillMaterial(st) > 0 then Result := Result + ' ttp:fmat="' + IntToStr(FillMaterial(st)) + '"';
    if (st.Fill <> NoColor) and (st.FillTr > 0) then
      Result := Result + ' fill-opacity="' + FormatFloat('0.###', (255 - st.FillTr) / 255, FS) + '"';
  end
  else
    Result := Result + ' fill="none"';
end;

// one sub-path "M .. C .. Z" per closed curve (the outline first, then the holes)
function SplinePath(s: TShape): string;
var
  c1, c2, rp: TPtArray;
  rlo, rhi: TRingArr;
  i, k: Integer;
  closed: Boolean;
begin
  Result := '';
  SplineRings(s, rlo, rhi);
  for k := 0 to High(rlo) do
  begin
    SetLength(rp, rhi[k] - rlo[k] + 1);
    for i := 0 to High(rp) do rp[i] := s.P[rlo[k] + i];
    if Length(rp) < 2 then Continue;
    closed := s.SplineClosed and (Length(rp) >= 3);
    SplineBezier(rp, c1, c2, closed);
    if Result <> '' then Result := Result + ' ';
    Result := Result + 'M' + FloatStr(rp[0].x) + ' ' + FloatStr(rp[0].y);
    for i := 0 to High(c1) do
      Result := Result + ' C' + FloatStr(c1[i].x) + ' ' + FloatStr(c1[i].y) + ' ' +
        FloatStr(c2[i].x) + ' ' + FloatStr(c2[i].y) + ' ' +
        FloatStr(rp[(i + 1) mod Length(rp)].x) + ' ' + FloatStr(rp[(i + 1) mod Length(rp)].y);
    if closed then Result := Result + ' Z';
  end;
end;

function RingsStr(s: TShape): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(s.RingStarts) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + IntToStr(s.RingStarts[i]);
  end;
end;

// the middle stops of a gradient as pos:colour:transparency,...
function MidStr(s: TShape): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(s.GradMid) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + FormatFloat('0.####', s.GradMid[i].Pos, FS) + ':' + IntToStr(s.GradMid[i].Col) + ':' + IntToStr(s.GradMid[i].Tr);
  end;
end;

// the items of an array that were made independent
function FreedStr(sp: TArraySpec): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(sp.Freed) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + IntToStr(sp.Freed[i]);
  end;
end;

function BucketAttr(s: TShape): string;
var
  i: Integer;
  ids: string;
begin
  Result := '';
  if s.HatchPat > 0 then
    Result := ' ttp:hatch="' + IntToStr(s.HatchPat) + ';' + FormatFloat('0.###', s.HatchSp, FS) + ';' +
      FormatFloat('0.###', s.HatchAng, FS) + ';' + FormatFloat('0.###', s.HatchW, FS) + ';' +
      IntToStr(s.HatchColor) + '"';
  // SVG has no switch for smoothing: crispEdges is the nearest request
  if not s.Antialias then Result := Result + ' shape-rendering="crispEdges"';
  if s.GradOn then
    Result := Result + ' ttp:grad="' + IntToStr(s.GradColor) + ';' + IntToStr(s.GradTr) + ';' + IntToStr(s.GradRef) + ';' +
      IntToStr(s.Style.Fill) + ';' + IntToStr(s.Style.FillTr) + ';' + IntToStr(Ord(s.GradRadial)) + ';' + MidStr(s) + '"';
  if not s.Bucket then Exit;
  if s.BucketIgnoreLower then Result := Result + ' ttp:blow="1"';
  Result := Result + ' ttp:boff="' + FloatStr(s.BucketOffset) + '"';
  ids := '';
  for i := 0 to High(s.BucketIds) do
  begin
    if i > 0 then ids := ids + ',';
    ids := ids + IntToStr(s.BucketIds[i]);
  end;
  Result := Result + ' ttp:bucket="' + FormatFloat('0.######', s.BucketU, FS) + ';' + FormatFloat('0.######', s.BucketV, FS) + ';' +
    FormatFloat('0.###', s.BucketSX, FS) + ';' + FormatFloat('0.###', s.BucketSY, FS) + ';' + ids + '"';
end;


// a rectangle with rounded corners: rx / ry for any SVG viewer, the radius itself for us
function CornerAttrs(s: TShape): string;
begin
  Result := '';
  if CornerOf(s) > 0 then
    Result := ' rx="' + FloatStr(CornerOf(s)) + '" ry="' + FloatStr(CornerOf(s)) + '" ttp:corner="' + FloatStr(s.Corner) + '"';
end;

// the turn of a shape: our own attributes, and the transform that any viewer understands (SVG turns clockwise)
function RotAttrs(s: TShape): string;
begin
  Result := '';
  if (s.Rot <> 0) and RotKind(s.Kind) then Result := Result + ' ttp:rot="' + FormatFloat('0.########', s.Rot, FS) + '"';
  if s.GroupRot <> 0 then Result := Result + ' ttp:grot="' + FormatFloat('0.########', s.GroupRot, FS) + '"';
end;

function RotOnly(s: TShape): string;
var
  c: TPt;
begin
  Result := '';
  if (s.Rot = 0) or not RotKind(s.Kind) or (Length(s.P) = 0) then Exit;
  c := ShapePivot(s);
  Result := 'rotate(' + FormatFloat('0.####', -s.Rot * 180 / Pi, FS) + ' ' + FloatStr(c.x) + ' ' + FloatStr(c.y) + ')';
end;

function RotSep(s: TShape): string;
begin
  if RotOnly(s) <> '' then Result := ' ' else Result := '';
end;

function RotTransform(s: TShape): string;
begin
  Result := '';
  if RotOnly(s) <> '' then Result := ' transform="' + RotOnly(s) + '"';
end;

function TextFamily(s: TShape): string;
begin
  if s.FontName = '' then Result := 'sans-serif'
  else Result := Esc(s.FontName) + ', sans-serif';
end;

function FontAttr(s: TShape): string;
begin
  if s.FontName = '' then Result := ''
  else Result := ' ttp:ff="' + Esc(s.FontName) + '"';
end;

function ShapeToSVG(s: TShape): string;
var
  attrs, d: string;
  sx, sy, ex, ey, sw: Double;
  large: Integer;
  head: TPtArray;
  filled: Boolean;
  stq: TStyle;
begin
  attrs := ' id="s' + IntToStr(s.Id) + '" ttp:id="' + IntToStr(s.Id) +
    '" ttp:kind="' + ShapeNames[s.Kind] + '" ttp:pts="' + PtsStr(s.P) + '"' +
    ' ttp:dash="' + IntToStr(Ord(s.Style.Dash)) + '"';
  if s.IsRef then attrs := attrs + ' ttp:ref="1" display="none"';
  attrs := attrs + BucketAttr(s);
  attrs := attrs + ' ttp:layer="' + IntToStr(s.LayerId) + '"';
  if s.GroupId > 0 then attrs := attrs + ' ttp:group="' + IntToStr(s.GroupId) + '"';
  if s.GroupName <> '' then attrs := attrs + ' ttp:gname="' + Esc(s.GroupName) + '"';
  if s.Snip <> '' then attrs := attrs + ' ttp:snip="' + s.Snip + '"';
  attrs := attrs + RotAttrs(s);
  if s.SplineClosed then attrs := attrs + ' ttp:closed="1"';
  if Length(s.RingStarts) > 0 then attrs := attrs + ' ttp:rings="' + RingsStr(s) + '"';
  if s.Spray then
    attrs := attrs + ' ttp:spray="' + FormatFloat('0.###', s.SprayR, FS) + ';' + FormatFloat('0.###', s.SprayDot, FS) + ';' +
      FormatFloat('0.###', s.SprayDens, FS) + ';' + IntToStr(s.SpraySeed) + ';' + IntToStr(s.Style.Stroke) + '"';
  if s.Soft > 0 then attrs := attrs + ' ttp:soft="' + IntToStr(s.Soft) + '"';
  if s.ShOn then
    // read back by TTPaint (ttp:shadow); the style is for the programs that only look at the picture
    attrs := attrs + ' ttp:shadow="' + FormatFloat('0.###', s.ShDX, FS) + ';' + FormatFloat('0.###', s.ShDY, FS) + ';' +
      FormatFloat('0.###', s.ShBlur, FS) + ';' + IntToStr(s.ShColor) + ';' + IntToStr(s.ShTr) + '"' +
      ' style="filter:drop-shadow(' + FormatFloat('0.###', s.ShDX, FS) + 'px ' + FormatFloat('0.###', s.ShDY, FS) + 'px ' +
      FormatFloat('0.###', s.ShBlur, FS) + 'px rgba(' + IntToStr(s.ShColor and $FF) + ',' + IntToStr((s.ShColor shr 8) and $FF) + ',' +
      IntToStr((s.ShColor shr 16) and $FF) + ',' + FormatFloat('0.###', (255 - s.ShTr) / 255, FS) + '))"';
  if s.Locked then attrs := attrs + ' ttp:locked="1"';
  if s.Hidden then
  begin
    attrs := attrs + ' ttp:hidden="1"';
    if not s.IsRef then attrs := attrs + ' display="none"';       // a reference object has already got it
  end;
  if s.Reg then attrs := attrs + ' ttp:regular="1"';
  if (s.Kind = skImage) and s.KeyOn and (s.KeyOrig <> '') then
    attrs := attrs + ' ttp:keycolor="' + IntToStr(s.KeyColor) + '" ttp:keytol="' + IntToStr(s.KeyTol) + '" ttp:keyorig="' + s.KeyOrig + '"';
  if s.SelTarget > 0 then
  begin
    attrs := attrs + ' ttp:seltarget="' + IntToStr(s.SelTarget) + '" ttp:seltol="' + IntToStr(s.SelTol) + '"';
    if s.SelHole then attrs := attrs + ' ttp:selhole="1"';
    if s.SelSub then attrs := attrs + ' ttp:selsub="1"';
    if s.SelBase then attrs := attrs + ' ttp:selbase="1"';
    if s.SelWand then attrs := attrs + ' ttp:selwand="1" ttp:selu="' + FloatStr(s.SelU) + '" ttp:selv="' + FloatStr(s.SelV) + '"';
  end;
  if s.OffSrc > 0 then
    attrs := attrs + ' ttp:offset="' + IntToStr(s.OffSrc) + ':' + FormatFloat('0.######', s.OffDist, FS) + '"';
  if s.MirSrc > 0 then
    attrs := attrs + ' ttp:mirror="' + IntToStr(s.MirSrc) + ':' + IntToStr(s.MirAxis) + '"';
  if s.ArrId > 0 then
    attrs := attrs + ' ttp:array="' + IntToStr(s.ArrId) + ':' + IntToStr(s.ArrK) + '"';
  if s.FA > 0 then
  begin
    attrs := attrs + ' ttp:fillet="' + IntToStr(s.FA) + ':' + IntToStr(s.FB) + ':' +
      IntToStr(s.FSA) + ':' + IntToStr(s.FSB) + '"';
    if s.Kind = skLine then
      attrs := attrs + ' ttp:cham="' + FormatFloat('0.######', s.CD1, FS) + ':' +
        FormatFloat('0.######', s.CD2, FS) + '"';
  end;
  filled := s.Kind in [skPolygon, skRect, skEllipse, skArc, skText];
  case s.Kind of
    skLine:
      Result := '<line x1="' + FloatStr(s.P[0].x) + '" y1="' + FloatStr(s.P[0].y) +
        '" x2="' + FloatStr(s.P[1].x) + '" y2="' + FloatStr(s.P[1].y) + '"' +
        attrs + StyleAttrs(s.Style, False) + '/>';
    skArrow:
      begin
        head := ArrowHead(s.P[0], s.P[1], s.Style.Width);
        Result := '<g' + attrs + StyleAttrs(s.Style, False) + '>' +
          '<line x1="' + FloatStr(s.P[0].x) + '" y1="' + FloatStr(s.P[0].y) +
          '" x2="' + FloatStr(s.P[1].x) + '" y2="' + FloatStr(s.P[1].y) + '"/>' +
          '<polygon points="' + PtsStr(head) + '" fill="' + ColorToSvg(s.Style.Stroke) +
          '" stroke-linejoin="miter"/></g>';
      end;
    skPolyline:
      Result := '<polyline points="' + PtsStr(s.P) + '"' + attrs + StyleAttrs(s.Style, False) + '/>';
    skPolygon:
      Result := '<polygon points="' + PtsStr(s.P) + '"' + attrs + StyleAttrs(s.Style, True) + '/>';
    skRect:
      Result := '<rect x="' + FloatStr(Min(s.P[0].x, s.P[1].x)) + '" y="' + FloatStr(Min(s.P[0].y, s.P[1].y)) +
        '" width="' + FloatStr(Abs(s.P[1].x - s.P[0].x)) + '" height="' + FloatStr(Abs(s.P[1].y - s.P[0].y)) + '"' +
        CornerAttrs(s) +
        attrs + RotTransform(s) + StyleAttrs(s.Style, True) + '/>';
    skEllipse:
      Result := '<ellipse cx="' + FloatStr(s.P[0].x) + '" cy="' + FloatStr(s.P[0].y) +
        '" rx="' + FloatStr(s.RX) + '" ry="' + FloatStr(s.RY) + '"' +
        ' ttp:rx="' + FloatStr(s.RX) + '" ttp:ry="' + FloatStr(s.RY) + '" ttp:circ="' + IntToStr(Ord(s.Circ)) + '"' +
        attrs + RotTransform(s) + StyleAttrs(s.Style, True) + '/>';
    skArc:
      begin
        sx := s.P[0].x + s.RX * Cos(s.A1);
        sy := s.P[0].y + s.RY * Sin(s.A1);
        ex := s.P[0].x + s.RX * Cos(s.A2);
        ey := s.P[0].y + s.RY * Sin(s.A2);
        if ArcSweep(s) > Pi then large := 1 else large := 0;
        d := 'M' + FloatStr(sx) + ' ' + FloatStr(sy) + ' A' + FloatStr(s.RX) + ' ' + FloatStr(s.RY) +
          ' 0 ' + IntToStr(large) + ' 1 ' + FloatStr(ex) + ' ' + FloatStr(ey);
        if s.Style.Fill <> NoColor then d := d + ' Z';
        Result := '<path d="' + d + '"' +
          ' ttp:rx="' + FloatStr(s.RX) + '" ttp:ry="' + FloatStr(s.RY) + '" ttp:a1="' + AngStr(s.A1) +
          '" ttp:a2="' + AngStr(s.A2) + '" ttp:circ="' + IntToStr(Ord(s.Circ)) + '"' +
          attrs + RotTransform(s) + StyleAttrs(s.Style, True) + '/>';
      end;
    skSpline:
      begin
        stq := s.Style;
        if s.Spray then stq.Stroke := NoColor;       // only the dots are seen
        Result := '<path d="' + SplinePath(s) + '"' + attrs + StyleAttrs(stq, s.SplineClosed);
        if Length(s.RingStarts) > 0 then Result := Result + ' fill-rule="evenodd"';
        Result := Result + '/>';
      end;
    skText:
      begin
        sw := s.FontSize;
        Result := '<text x="' + FloatStr(s.P[0].x) + '" y="' + FloatStr(s.P[0].y + sw) +
          '" font-size="' + FloatStr(sw) + '" font-family="' + TextFamily(s) + '" ttp:fs="' + FloatStr(sw) + '"' + FontAttr(s) +
          attrs + RotTransform(s) + ' fill="' + ColorToSvg(s.Style.Fill) + '" stroke="none">' + Esc(s.Text) + '</text>';
      end;
    skPath:
      Result := '<path d="' + Esc(s.PathData) + '" transform="' + RotOnly(s) + RotSep(s) + 'translate(' + FloatStr(s.P[0].x) + ' ' +
        FloatStr(s.P[0].y) + ')"' + attrs + StyleAttrs(s.Style, True) + ' fill-rule="evenodd"/>';
    skImage:
      Result := '<image x="' + FloatStr(Min(s.P[0].x, s.P[1].x)) + '" y="' + FloatStr(Min(s.P[0].y, s.P[1].y)) +
        '" width="' + FloatStr(Abs(s.P[1].x - s.P[0].x)) + '" height="' + FloatStr(Abs(s.P[1].y - s.P[0].y)) +
        '" href="data:image/png;base64,' + s.ImageData + '"' + attrs + RotTransform(s) + '/>';
  end;
end;

function ExtAttr(s: TShape): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(s.Extends) do
  begin
    if i > 0 then Result := Result + ';';
    Result := Result + IntToStr(s.Extends[i].EndIdx) + ':' + IntToStr(s.Extends[i].Boundary);
  end;
end;

function TrimAttr(s: TShape): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(s.Trims) do
  begin
    if i > 0 then Result := Result + ';';
    Result := Result + IntToStr(s.Trims[i].Poly) + ':' +
      FormatFloat('0.######', s.Trims[i].U0, FS) + ':' + IntToStr(s.Trims[i].CA) + ':' +
      IntToStr(s.Trims[i].CB);
    if s.Trims[i].CA = -2 then
      Result := Result + ':' + FormatFloat('0.######', s.Trims[i].UA, FS) + ':' +
        FormatFloat('0.######', s.Trims[i].UB, FS);
  end;
end;

function OutlinePath(const o: TOutline; close: Boolean): string;
var
  i, j: Integer;
begin
  Result := '';
  for i := 0 to High(o) do
  begin
    if Length(o[i].Pts) < 2 then Continue;
    for j := 0 to High(o[i].Pts) do
    begin
      if j = 0 then Result := Result + 'M' else Result := Result + ' L';
      Result := Result + FloatStr(o[i].Pts[j].x) + ' ' + FloatStr(o[i].Pts[j].y);
    end;
    if close and o[i].Closed then Result := Result + ' Z';
    Result := Result + ' ';
  end;
  Result := Trim(Result);
end;

// A trimmed shape: the exact geometry stays in the ttp:* attributes of the group,
// the children draw only what is visible (so any SVG viewer shows the trim).
// a gradient for other programs: a linearGradient from the start to the end of the reference line
// (a curve is followed only by its chord: SVG has no gradient along a path), used as the fill
function GradientSvg(doc: TDoc; s: TShape; const el: string): string;
var
  g: TGradLine;
  c1, id, e, v: string;
  p, q, k: Integer;
begin
  Result := el;
  if (not s.GradOn) or (s.Style.Fill = NoColor) or (s.Kind in [skText, skImage]) then Exit;
  g := doc.GradientLine(s);
  if (not g.Radial) and (Length(g.Pts) < 2) then Exit;
  id := 'grad' + IntToStr(s.Id);
  c1 := ColorToSvg(s.Style.Fill);
  e := el;
  // the plain fill (and its opacity) become the gradient's stops
  e := StringReplace(e, ' fill="' + c1 + '"', ' fill="url(#' + id + ')"', [rfReplaceAll]);
  repeat
    p := Pos(' fill-opacity="', e);
    if p = 0 then Break;
    q := p + Length(' fill-opacity="');
    while (q <= Length(e)) and (e[q] <> '"') do Inc(q);
    Delete(e, p, q - p + 1);
  until False;
  if g.Radial then
    v := '<radialGradient id="' + id + '" gradientUnits="userSpaceOnUse" cx="' + FloatStr(g.CX) + '" cy="' +
      FloatStr(g.CY) + '" r="' + FloatStr(g.R) + '">'
  else
    v := '<linearGradient id="' + id + '" gradientUnits="userSpaceOnUse" x1="' + FloatStr(g.Pts[0].x) + '" y1="' +
      FloatStr(g.Pts[0].y) + '" x2="' + FloatStr(g.Pts[High(g.Pts)].x) + '" y2="' + FloatStr(g.Pts[High(g.Pts)].y) + '">';
  v := v + '<stop offset="0" stop-color="' + c1 + '" stop-opacity="' + FormatFloat('0.###', (255 - s.Style.FillTr) / 255, FS) + '"/>';
  for k := 0 to High(s.GradMid) do
    v := v + '<stop offset="' + FormatFloat('0.####', s.GradMid[k].Pos, FS) + '" stop-color="' + ColorToSvg(s.GradMid[k].Col) +
      '" stop-opacity="' + FormatFloat('0.###', (255 - s.GradMid[k].Tr) / 255, FS) + '"/>';
  v := v + '<stop offset="1" stop-color="' + ColorToSvg(s.GradColor) + '" stop-opacity="' +
    FormatFloat('0.###', (255 - s.GradTr) / 255, FS) + '"/>';
  if g.Radial then v := v + '</radialGradient>' else v := v + '</linearGradient>';
  Result := v + e;
end;

function TrimmedToSVG(s: TShape; const vis: TOutline): string;
var
  attrs: string;
begin
  attrs := ' id="s' + IntToStr(s.Id) + '" ttp:id="' + IntToStr(s.Id) +
    '" ttp:kind="' + ShapeNames[s.Kind] + '" ttp:pts="' + PtsStr(s.P) + '"' +
    ' ttp:dash="' + IntToStr(Ord(s.Style.Dash)) + '"';
  if Length(s.Trims) > 0 then attrs := attrs + ' ttp:trim="' + TrimAttr(s) + '"';
  if Length(s.Extends) > 0 then attrs := attrs + ' ttp:ext="' + ExtAttr(s) + '"';
  if s.Kind in [skEllipse, skArc] then
    attrs := attrs + ' ttp:rx="' + FloatStr(s.RX) + '" ttp:ry="' + FloatStr(s.RY) +
      '" ttp:a1="' + AngStr(s.A1) + '" ttp:a2="' + AngStr(s.A2) +
      '" ttp:circ="' + IntToStr(Ord(s.Circ)) + '"';
  if s.IsRef then attrs := attrs + ' ttp:ref="1" display="none"';
  attrs := attrs + BucketAttr(s);
  attrs := attrs + ' ttp:layer="' + IntToStr(s.LayerId) + '"';
  if s.GroupId > 0 then attrs := attrs + ' ttp:group="' + IntToStr(s.GroupId) + '"';
  if s.GroupName <> '' then attrs := attrs + ' ttp:gname="' + Esc(s.GroupName) + '"';
  if s.Snip <> '' then attrs := attrs + ' ttp:snip="' + s.Snip + '"';
  attrs := attrs + RotAttrs(s);
  if s.SplineClosed then attrs := attrs + ' ttp:closed="1"';
  if Length(s.RingStarts) > 0 then attrs := attrs + ' ttp:rings="' + RingsStr(s) + '"';
  if s.OffSrc > 0 then
    attrs := attrs + ' ttp:offset="' + IntToStr(s.OffSrc) + ':' + FormatFloat('0.######', s.OffDist, FS) + '"';
  if s.MirSrc > 0 then
    attrs := attrs + ' ttp:mirror="' + IntToStr(s.MirSrc) + ':' + IntToStr(s.MirAxis) + '"';
  if s.ArrId > 0 then
    attrs := attrs + ' ttp:array="' + IntToStr(s.ArrId) + ':' + IntToStr(s.ArrK) + '"';
  if s.FA > 0 then
  begin
    attrs := attrs + ' ttp:fillet="' + IntToStr(s.FA) + ':' + IntToStr(s.FB) + ':' +
      IntToStr(s.FSA) + ':' + IntToStr(s.FSB) + '"';
    if s.Kind = skLine then
      attrs := attrs + ' ttp:cham="' + FormatFloat('0.######', s.CD1, FS) + ':' +
        FormatFloat('0.######', s.CD2, FS) + '"';
  end;
  Result := '<g' + attrs + StyleAttrs(s.Style, False) + '>';
  if (s.Style.Fill <> NoColor) and (s.Kind in [skPolygon, skRect, skEllipse, skArc]) then
    Result := Result + '<path d="' + OutlinePath(ShapeOutline(s), True) + '" fill="' +
      ColorToSvg(s.Style.Fill) + '" stroke="none"/>';
  if s.Style.Stroke <> NoColor then
    Result := Result + '<path d="' + OutlinePath(vis, False) + '" fill="none"/>';
  Result := Result + '</g>';
end;

function IdIn(const a: TIntArray; id: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(a) do
    if a[i] = id then Exit(True);
  Result := False;
end;

function ConsToXml(doc: TDoc; c: TConstraint): string;
var
  i: Integer;
  refs: string;
begin
  refs := '';
  for i := 0 to High(c.Refs) do
  begin
    if i > 0 then refs := refs + ' ';
    refs := refs + IntToStr(c.Refs[i].Shape) + ':' + IntToStr(c.Refs[i].Idx);
  end;
  Result := '    <ttp:constraint ttp:id="' + IntToStr(c.Id) + '" kind="' +
    ConstraintNames[c.Kind] + '" refs="' + refs + '"';
  if c.IsQuote or (c.Kind = ckTangent) then
    Result := Result + ' value="' + FloatStr(c.Value) + '" aux="' + FloatStr(c.Aux) +
      '" axis="' + IntToStr(c.Axis) + '" diam="' + IntToStr(Ord(c.Diam)) +
      '" offset="' + FloatStr(c.Offset) + '"' +
      '';
  if c.NoPrint then Result := Result + ' noprint="1"';
  if c.UnitText <> '' then Result := Result + ' unit="' + Esc(c.UnitText) + '"';
  Result := Result + '/>' + LineEnding;
end;

// the hatch lines of a fill, as one path (skipped when the file is read: they are made again)
function HatchSvg(s: TShape): string;
var
  sg: TFPtArray;
  i: Integer;
  dots: Boolean;
begin
  Result := '';
  sg := BucketHatch(s);
  if Length(sg) < 2 then Exit;
  dots := s.HatchPat = 7;
  Result := '<path ttp:skip="1" d="';
  i := 0;
  while i + 1 < Length(sg) do
  begin
    if i > 0 then Result := Result + ' ';
    Result := Result + 'M' + FloatStr(sg[i].x) + ' ' + FloatStr(sg[i].y) + ' L' + FloatStr(sg[i + 1].x) + ' ' + FloatStr(sg[i + 1].y);
    Inc(i, 2);
  end;
  Result := Result + '" fill="none" stroke="' + ColorToSvg(s.HatchColor) + '" stroke-width="' +
    FloatStr(s.HatchW) + '"';
  if dots then Result := Result + ' stroke-linecap="round"' else Result := Result + ' stroke-linecap="butt"';
  Result := Result + '/>';
end;

// the dots of an airbrush stroke as one path of zero-length round dashes
function SpraySvg(s: TShape): string;
var
  d: TSprayDotArray;
  i: Integer;
  id, c, op: string;
begin
  Result := '';
  d := SprayDots(s);
  if Length(d) = 0 then Exit;
  id := 'spray' + IntToStr(s.Id);
  c := ColorToSvg(s.Style.Stroke);
  // soft drops: one radial gradient from the colour to nothing, and a circle for each drop with its own size and opacity
  Result := '<g ttp:skip="1"';
  if s.Style.StrokeTr > 0 then
    Result := Result + ' opacity="' + FormatFloat('0.###', (255 - s.Style.StrokeTr) / 255, FS) + '"';
  Result := Result + ' fill="url(#' + id + ')"><defs><radialGradient id="' + id + '">' +
    '<stop offset="0" stop-color="' + c + '" stop-opacity="1"/>' +
    '<stop offset="0.5" stop-color="' + c + '" stop-opacity="0.56"/>' +
    '<stop offset="0.75" stop-color="' + c + '" stop-opacity="0.19"/>' +
    '<stop offset="1" stop-color="' + c + '" stop-opacity="0"/></radialGradient></defs>';
  for i := 0 to High(d) do
  begin
    op := FormatFloat('0.##', d[i].A, FS);
    Result := Result + '<circle cx="' + FormatFloat('0.#', d[i].X, FS) + '" cy="' + FormatFloat('0.#', d[i].Y, FS) +
      '" r="' + FormatFloat('0.##', d[i].R, FS) + '" fill-opacity="' + op + '"/>';
  end;
  Result := Result + '</g>';
end;

function LayerBgAttr(l: TLayer): string;
begin
  if l.Bg = NoColor then Result := ''
  else Result := ' bg="' + IntToStr(l.Bg) + '"';
end;

function FilterAttrs(l: TLayer): string;
var
  i: Integer;
  v: string;
begin
  Result := '';
  if not l.IsFilter then Exit;
  v := '';
  for i := 0 to High(l.FVals) do
  begin
    if i > 0 then v := v + ';';
    v := v + FormatFloat('0.#####', l.FVals[i], FS);
  end;
  Result := ' filter="1" fname="' + Esc(l.FName) + '" fvals="' + v + '"';
  if (l.FFeather > 0) or (l.FFeatherIn > 0) then
    Result := Result + ' ffeather="' + FormatFloat('0.#####', l.FFeather, FS) + '" ffeatherin="' + FormatFloat('0.#####', l.FFeatherIn, FS) + '"';
  // the line ends are written as character references: an attribute value keeps them that way
  if l.FScript <> '' then
    Result := Result + ' fscript="' + StringReplace(StringReplace(Esc(l.FScript), #13, '', [rfReplaceAll]), #10, '&#10;', [rfReplaceAll]) + '"';
end;

// the quotes as drawings (for the programs that only look at the picture); when the file is read again they are skipped: the quotes
// themselves are in the metadata
function QuotesToSvg(doc: TDoc): string;
var
  i, j, k: Integer;
  c: TConstraint;
  q: TQuoteGeom;
  col, pts: string;
  w: Double;
begin
  Result := '';
  col := ColorToSvg($A06E00);
  for i := 0 to doc.Cons.Count - 1 do
  begin
    c := doc.Cons[i];
    if (not c.IsQuote) or c.NoPrint then Continue;
    if not doc.QuoteGeometry(c, 1, q) then Continue;
    Result := Result + '  <g ttp:skip="1" fill="none" stroke="' + col + '" stroke-width="1">' + LineEnding;
    for j := 0 to High(q.Segs) do
    begin
      Result := Result + '    <line x1="' + FloatStr(q.Segs[j].A.x) + '" y1="' + FloatStr(q.Segs[j].A.y) + '" x2="' +
        FloatStr(q.Segs[j].B.x) + '" y2="' + FloatStr(q.Segs[j].B.y) + '"';
      if q.Segs[j].Dotted then Result := Result + ' stroke-dasharray="2 2"';
      Result := Result + '/>' + LineEnding;
    end;
    if Length(q.Arc) > 1 then
    begin
      pts := '';
      for j := 0 to High(q.Arc) do pts := pts + FloatStr(q.Arc[j].x) + ',' + FloatStr(q.Arc[j].y) + ' ';
      Result := Result + '    <polyline points="' + Trim(pts) + '"/>' + LineEnding;
    end;
    for j := 0 to High(q.Heads) do
    begin
      pts := '';
      for k := 0 to High(q.Heads[j]) do pts := pts + FloatStr(q.Heads[j][k].x) + ',' + FloatStr(q.Heads[j][k].y) + ' ';
      Result := Result + '    <polygon points="' + Trim(pts) + '" fill="' + col + '"/>' + LineEnding;
    end;
    // the label, on a white ground
    w := Length(q.Text) * 7 + 6;
    Result := Result + '    <rect x="' + FloatStr(q.TextPos.x - w / 2) + '" y="' + FloatStr(q.TextPos.y - 8) + '" width="' + FloatStr(w) +
      '" height="16" fill="#ffffff" stroke="none"/>' + LineEnding;
    Result := Result + '    <text x="' + FloatStr(q.TextPos.x) + '" y="' + FloatStr(q.TextPos.y + 4) +
      '" font-family="sans-serif" font-size="12" text-anchor="middle" fill="' + col + '" stroke="none">' + Esc(q.Text) + '</text>' + LineEnding;
    Result := Result + '  </g>' + LineEnding;
  end;
end;

function DocToSVG(doc: TDoc; subset: Boolean; const only: TIntArray; withQuotes: Boolean): string;
var
  i, j, li: Integer;
  c: TConstraint;
  ok: Boolean;
  s: TShape;
  vis: TOutline;
begin
  doc.UpdateFillets;
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding +
    '<svg xmlns="http://www.w3.org/2000/svg" xmlns:ttp="' + NS + '" width="' +
    IntToStr(doc.Width) + '" height="' + IntToStr(doc.Height) + '" viewBox="0 0 ' +
    IntToStr(doc.Width) + ' ' + IntToStr(doc.Height) + '">' + LineEnding;
  Result := Result + '  <metadata>' + LineEnding +
    '  <ttp:document ttp:version="1" ttp:nextid="' + IntToStr(doc.NextId) + '" ttp:active="' + IntToStr(doc.ActiveLayer) + '">' + LineEnding;
  if not subset then
    for i := 0 to doc.Layers.Count - 1 do
      Result := Result + '    <ttp:layer id="' + IntToStr(doc.Layers[i].Id) + '" name="' + Esc(doc.Layers[i].Name) +
        '" visible="' + IntToStr(Ord(doc.Layers[i].Visible)) + '" locked="' + IntToStr(Ord(doc.Layers[i].Locked)) + '" hiderefs="' + IntToStr(Ord(doc.Layers[i].HideRefs)) + '" hidecons="' + IntToStr(Ord(doc.Layers[i].HideCons)) + '" lightaz="' + FloatStr(doc.Layers[i].LightAz) + '" lightel="' + FloatStr(doc.Layers[i].LightEl) + '" lightdiv="' + FloatStr(doc.Layers[i].LightDiv) + '" lightpower="' + FloatStr(doc.Layers[i].LightPower) + '" lighttint="' + IntToStr(doc.Layers[i].LightTint) +
        '" opacity="' + IntToStr(doc.Layers[i].Opacity) + '" scale="' + FloatStr(doc.Layers[i].Scale) + '"' +
        LayerBgAttr(doc.Layers[i]) + FilterAttrs(doc.Layers[i]) + '/>' + LineEnding;
  // the materials that have been changed
  if not subset then
    for i := 0 to MaterialCount - 1 do
      if not SameMatParams(doc.Mats[i], DefaultMatParams) then
        Result := Result + '    <ttp:material id="' + IntToStr(i) + '" rough="' + FloatStr(doc.Mats[i].Rough) + '" scale="' +
          FloatStr(doc.Mats[i].Scale) + '" angle="' + FloatStr(doc.Mats[i].Angle) + '" texture="' + FloatStr(doc.Mats[i].Texture) +
          '" gloss="' + FloatStr(doc.Mats[i].Gloss) + '" bright="' + FloatStr(doc.Mats[i].Bright) + '" tint="' +
          IntToStr(doc.Mats[i].Tint) + '" opacity="' + FloatStr(doc.Mats[i].Opacity) + '" thick="' + FloatStr(doc.Mats[i].Thick) + '" curve="' +
          FloatStr(doc.Mats[i].Curve) + '" cx="' + FloatStr(doc.Mats[i].CX) + '" cy="' + FloatStr(doc.Mats[i].CY) + '"/>' + LineEnding;
  for i := 0 to doc.Cons.Count - 1 do
  begin
    c := doc.Cons[i];
    ok := True;
    if subset then
      for j := 0 to High(c.Refs) do
        if not IdIn(only, c.Refs[j].Shape) then ok := False;
    if ok then Result := Result + ConsToXml(doc, c);
  end;
  for i := 0 to doc.Arrays.Count - 1 do
    with doc.Arrays[i] do
      if (not subset) or IdIn(only, Src) then
        Result := Result + '    <ttp:array id="' + IntToStr(Id) + '" src="' + IntToStr(Src) +
          '" polar="' + IntToStr(Ord(Polar)) + '" cols="' + IntToStr(Cols) + '" rows="' + IntToStr(Rows) +
          '" dx="' + FormatFloat('0.######', DX, FS) + '" dy="' + FormatFloat('0.######', DY, FS) +
          '" count="' + IntToStr(Count) + '" cx="' + FormatFloat('0.######', CX, FS) +
          '" cy="' + FormatFloat('0.######', CY, FS) + '" total="' + FormatFloat('0.######', Total, FS) +
          '" freed="' + FreedStr(doc.Arrays[i]) + '"/>' + LineEnding;
  Result := Result + '  </ttp:document>' + LineEnding + '  </metadata>' + LineEnding;
  // the shapes layer by layer (bottom first); a layer is a group
  for li := 0 to doc.Layers.Count - 1 do
  begin
    Result := Result + '  <g id="layer' + IntToStr(doc.Layers[li].Id) + '"';
    if not doc.Layers[li].Visible then Result := Result + ' display="none"';
    if doc.Layers[li].Opacity < 255 then
      Result := Result + ' opacity="' + FormatFloat('0.###', doc.Layers[li].Opacity / 255, FS) + '"';
    Result := Result + '>' + LineEnding;
    // the background of the layer: a rectangle for other programs (ours reads it from the metadata)
    if (not subset) and (doc.Layers[li].Bg <> NoColor) then
      Result := Result + '  <rect ttp:skip="1" x="0" y="0" width="' + IntToStr(doc.Width) + '" height="' + IntToStr(doc.Height) +
        '" fill="' + ColorToSvg(doc.Layers[li].Bg) + '"/>' + LineEnding;
    for i := 0 to doc.Shapes.Count - 1 do
    begin
      s := doc.Shapes[i];
      if doc.LayerOf(s) <> doc.Layers[li] then Continue;
      if subset and not IdIn(only, s.Id) then Continue;
      if doc.VisibleOutline(s, vis) then
        Result := Result + '  ' + GradientSvg(doc, s, TrimmedToSVG(s, vis)) + LineEnding
      else
        Result := Result + '  ' + GradientSvg(doc, s, ShapeToSVG(s)) + LineEnding;
      if (s.HatchPat > 0) and (Length(BucketHatch(s)) > 0) then Result := Result + '  ' + HatchSvg(s) + LineEnding;
      if s.Spray then Result := Result + '  ' + SpraySvg(s) + LineEnding;
    end;
    Result := Result + '  </g>' + LineEnding;
  end;
  if withQuotes then Result := Result + QuotesToSvg(doc);
  Result := Result + '</svg>' + LineEnding;
end;

{ ---------- reading ---------- }

type
  TIdMap = record
    OldId, NewId: Integer;
  end;

function A(el: TDOMElement; const name: string): string;
begin
  Result := el.GetAttribute(name);
end;

function StyleProp(el: TDOMElement; const name: string): string;
var
  st, item: string;
  p, q: Integer;
begin
  Result := A(el, name);
  if Result <> '' then Exit;
  st := A(el, 'style');
  p := Pos(name + ':', st);
  if p > 0 then
  begin
    item := Copy(st, p + Length(name) + 1, MaxInt);
    q := Pos(';', item);
    if q > 0 then item := Copy(item, 1, q - 1);
    Result := Trim(item);
  end;
end;

function ReadStyle(el: TDOMElement; const base: TStyle): TStyle;
var
  v: string;
  dsh: Integer;
begin
  Result := base;
  v := StyleProp(el, 'stroke');
  if v <> '' then Result.Stroke := SvgToColor(v, base.Stroke);
  v := StyleProp(el, 'fill');
  if v <> '' then Result.Fill := SvgToColor(v, base.Fill);
  Result.StrokeMatId := StrToIntDef(A(el, 'ttp:smat'), 0);
  Result.FillMatId := StrToIntDef(A(el, 'ttp:fmat'), 0);
  v := StyleProp(el, 'stroke-opacity');
  if v <> '' then Result.StrokeTr := 255 - Round(255 * Max(0, Min(1, StrToFloatDef(v, 1, FS))));
  v := StyleProp(el, 'fill-opacity');
  if v <> '' then Result.FillTr := 255 - Round(255 * Max(0, Min(1, StrToFloatDef(v, 1, FS))));
  v := StyleProp(el, 'opacity');
  if v <> '' then
  begin
    Result.StrokeTr := 255 - Round((255 - Result.StrokeTr) * Max(0, Min(1, StrToFloatDef(v, 1, FS))));
    Result.FillTr := 255 - Round((255 - Result.FillTr) * Max(0, Min(1, StrToFloatDef(v, 1, FS))));
  end;
  v := StyleProp(el, 'stroke-width');
  if v <> '' then Result.Width := StrToFloatDef(v, base.Width, FS);
  v := StyleProp(el, 'stroke-linecap');
  if v = 'butt' then Result.Cap := lcFlat
  else if v = 'round' then Result.Cap := lcRound
  else if v = 'square' then Result.Cap := lcSquare;
  v := StyleProp(el, 'stroke-linejoin');
  if v = 'miter' then Result.Join := ljMiter
  else if v = 'round' then Result.Join := ljRound
  else if v = 'bevel' then Result.Join := ljBevel;
  v := A(el, 'ttp:dash');
  if v <> '' then
  begin
    dsh := StrToIntDef(v, 0);
    if (dsh >= 0) and (dsh <= Ord(High(TDashStyle))) then Result.Dash := TDashStyle(dsh);
  end
  else if StyleProp(el, 'stroke-dasharray') <> '' then Result.Dash := dsDash;
end;

function ParsePts(const s: string): TPtArray;
var
  nums: array of Double;
  i, st: Integer;
begin
  SetLength(nums, 0);
  i := 1;
  while i <= Length(s) do
  begin
    while (i <= Length(s)) and (s[i] in [' ', ',', #9, #10, #13]) do Inc(i);
    st := i;
    while (i <= Length(s)) and not (s[i] in [' ', ',', #9, #10, #13]) do Inc(i);
    if i > st then
    begin
      SetLength(nums, Length(nums) + 1);
      nums[High(nums)] := StrToFloatDef(Copy(s, st, i - st), 0, FS);
    end;
  end;
  SetLength(Result, Length(nums) div 2);
  for i := 0 to High(Result) do
    Result[i] := MakePt(nums[2 * i], nums[2 * i + 1]);
end;

function KindFromName(const n: string; out k: TShapeKind): Boolean;
var
  kk: TShapeKind;
begin
  Result := False;
  for kk := Low(TShapeKind) to High(TShapeKind) do
    if ShapeNames[kk] = n then
    begin
      k := kk;
      Exit(True);
    end;
end;

function FNum(el: TDOMElement; const name: string; def: Double = 0): Double;
begin
  Result := StrToFloatDef(A(el, name), def, FS);
end;

procedure ReadExtends(el: TDOMElement; s: TShape);
var
  parts, f: TStringList;
  i: Integer;
begin
  if A(el, 'ttp:ext') = '' then Exit;
  parts := TStringList.Create;
  f := TStringList.Create;
  try
    parts.Delimiter := ';';
    parts.StrictDelimiter := True;
    parts.DelimitedText := A(el, 'ttp:ext');
    f.Delimiter := ':';
    f.StrictDelimiter := True;
    for i := 0 to parts.Count - 1 do
    begin
      f.DelimitedText := parts[i];
      if f.Count < 2 then Continue;
      SetLength(s.Extends, Length(s.Extends) + 1);
      s.Extends[High(s.Extends)].EndIdx := StrToIntDef(f[0], 0);
      s.Extends[High(s.Extends)].Boundary := StrToIntDef(f[1], -1);
    end;
  finally
    f.Free;
    parts.Free;
  end;
end;

procedure ReadMids(const v: string; s: TShape);
var
  f, q: TStringList;
  i: Integer;
begin
  f := TStringList.Create;
  q := TStringList.Create;
  try
    f.Delimiter := ',';
    f.StrictDelimiter := True;
    f.DelimitedText := v;
    for i := 0 to f.Count - 1 do
    begin
      q.Delimiter := ':';
      q.StrictDelimiter := True;
      q.DelimitedText := f[i];
      if q.Count >= 3 then
      begin
        SetLength(s.GradMid, Length(s.GradMid) + 1);
        s.GradMid[High(s.GradMid)].Pos := StrToFloatDef(q[0], 0.5, FS);
        s.GradMid[High(s.GradMid)].Col := StrToIntDef(q[1], 0);
        s.GradMid[High(s.GradMid)].Tr := StrToIntDef(q[2], 0);
      end;
    end;
  finally
    f.Free;
    q.Free;
  end;
end;

procedure ReadRings(el: TDOMElement; s: TShape);
var
  f: TStringList;
  i: Integer;
begin
  f := TStringList.Create;
  try
    f.Delimiter := ',';
    f.StrictDelimiter := True;
    f.DelimitedText := A(el, 'ttp:rings');
    for i := 0 to f.Count - 1 do
      if StrToIntDef(f[i], 0) > 0 then
      begin
        SetLength(s.RingStarts, Length(s.RingStarts) + 1);
        s.RingStarts[High(s.RingStarts)] := StrToInt(f[i]);
      end;
  finally
    f.Free;
  end;
end;

// the font of a text of another program: the first family of font-family, if it is not a generic one
function FontFromElement(el: TDOMElement): string;
var
  f: string;
  p: Integer;
begin
  Result := '';
  f := StyleProp(el, 'font-family');
  p := Pos(',', f);
  if p > 0 then f := Copy(f, 1, p - 1);
  f := Trim(StringReplace(StringReplace(f, '"', '', [rfReplaceAll]), Chr(39), '', [rfReplaceAll]));
  if (f <> '') and (LowerCase(f) <> 'sans-serif') and (LowerCase(f) <> 'serif') and (LowerCase(f) <> 'monospace') then Result := f;
end;

procedure ReadSpray(el: TDOMElement; s: TShape);
var
  f: TStringList;
begin
  if A(el, 'ttp:spray') = '' then Exit;
  f := TStringList.Create;
  try
    f.Delimiter := ';';
    f.StrictDelimiter := True;
    f.DelimitedText := A(el, 'ttp:spray');
    if f.Count < 5 then Exit;
    s.Spray := True;
    s.SprayR := StrToFloatDef(f[0], 20, FS);
    s.SprayDot := StrToFloatDef(f[1], 1.5, FS);
    s.SprayDens := StrToFloatDef(f[2], 6, FS);
    s.SpraySeed := StrToIntDef(f[3], 1);
    s.Style.Stroke := StrToIntDef(f[4], 0);
  finally
    f.Free;
  end;
end;

procedure ReadBucket(el: TDOMElement; s: TShape);
var
  f, ids: TStringList;
  i, k: Integer;
  v: string;
begin
  if A(el, 'ttp:hatch') <> '' then
  begin
    f := TStringList.Create;
    try
      f.Delimiter := ';';
      f.StrictDelimiter := True;
      f.DelimitedText := A(el, 'ttp:hatch');
      if f.Count >= 5 then
      begin
        s.HatchPat := StrToIntDef(f[0], 0);
        s.HatchSp := StrToFloatDef(f[1], 8, FS);
        s.HatchAng := StrToFloatDef(f[2], 0, FS);
        s.HatchW := StrToFloatDef(f[3], 1, FS);
        s.HatchColor := StrToIntDef(f[4], 0);
      end;
    finally
      f.Free;
    end;
  end;
  v := StyleProp(el, 'shape-rendering');
  if SameText(v, 'crispEdges') or SameText(v, 'optimizeSpeed') then s.Antialias := False;
  if A(el, 'ttp:grad') <> '' then
  begin
    f := TStringList.Create;
    try
      f.Delimiter := ';';
      f.StrictDelimiter := True;
      f.DelimitedText := A(el, 'ttp:grad');
      if f.Count >= 3 then
      begin
        s.GradOn := True;
        s.GradColor := StrToIntDef(f[0], 0);
        s.GradTr := StrToIntDef(f[1], 0);
        s.GradRef := StrToIntDef(f[2], 0);
        // the first colour: the file's own fill is the url of the gradient
        if f.Count >= 5 then
        begin
          s.Style.Fill := StrToIntDef(f[3], s.Style.Fill);
          s.Style.FillTr := StrToIntDef(f[4], 0);
        end;
        s.GradRadial := (f.Count >= 6) and (f[5] = '1');
        if (f.Count >= 7) and (f[6] <> '') then ReadMids(f[6], s);
      end;
    finally
      f.Free;
    end;
  end;
  if A(el, 'ttp:bucket') = '' then Exit;
  s.BucketIgnoreLower := A(el, 'ttp:blow') = '1';
  s.BucketOffset := StrToFloatDef(A(el, 'ttp:boff'), 0, FS);
  f := TStringList.Create;
  ids := TStringList.Create;
  try
    f.Delimiter := ';';
    f.StrictDelimiter := True;
    f.DelimitedText := A(el, 'ttp:bucket');
    if f.Count < 5 then Exit;
    s.Bucket := True;
    s.BucketU := StrToFloatDef(f[0], 0.5, FS);
    s.BucketV := StrToFloatDef(f[1], 0.5, FS);
    s.BucketSX := StrToFloatDef(f[2], 0, FS);
    s.BucketSY := StrToFloatDef(f[3], 0, FS);
    ids.Delimiter := ',';
    ids.StrictDelimiter := True;
    ids.DelimitedText := f[4];
    for i := 0 to ids.Count - 1 do
      if StrToIntDef(ids[i], 0) > 0 then
      begin
        SetLength(s.BucketIds, Length(s.BucketIds) + 1);
        s.BucketIds[High(s.BucketIds)] := StrToInt(ids[i]);
      end;
  finally
    ids.Free;
    f.Free;
  end;
end;

procedure ReadTrims(el: TDOMElement; s: TShape);
var
  parts, f: TStringList;
  i: Integer;
begin
  ReadExtends(el, s);
  if Pos(':', A(el, 'ttp:array')) > 0 then
  begin
    s.ArrId := StrToIntDef(Copy(A(el, 'ttp:array'), 1, Pos(':', A(el, 'ttp:array')) - 1), 0);
    s.ArrK := StrToIntDef(Copy(A(el, 'ttp:array'), Pos(':', A(el, 'ttp:array')) + 1, MaxInt), 0);
  end;
  if Pos(':', A(el, 'ttp:mirror')) > 0 then
  begin
    s.MirSrc := StrToIntDef(Copy(A(el, 'ttp:mirror'), 1, Pos(':', A(el, 'ttp:mirror')) - 1), 0);
    s.MirAxis := StrToIntDef(Copy(A(el, 'ttp:mirror'), Pos(':', A(el, 'ttp:mirror')) + 1, MaxInt), 0);
  end;
  if Pos(':', A(el, 'ttp:offset')) > 0 then
  begin
    s.OffSrc := StrToIntDef(Copy(A(el, 'ttp:offset'), 1, Pos(':', A(el, 'ttp:offset')) - 1), 0);
    s.OffDist := StrToFloatDef(Copy(A(el, 'ttp:offset'), Pos(':', A(el, 'ttp:offset')) + 1, MaxInt), 0, FS);
  end;
  if Pos(':', A(el, 'ttp:cham')) > 0 then
  begin
    s.CD1 := StrToFloatDef(Copy(A(el, 'ttp:cham'), 1, Pos(':', A(el, 'ttp:cham')) - 1), 20, FS);
    s.CD2 := StrToFloatDef(Copy(A(el, 'ttp:cham'), Pos(':', A(el, 'ttp:cham')) + 1, MaxInt), 20, FS);
  end;
  if A(el, 'ttp:fillet') <> '' then
  begin
    f := TStringList.Create;
    try
      f.Delimiter := ':';
      f.StrictDelimiter := True;
      f.DelimitedText := A(el, 'ttp:fillet');
      if f.Count >= 4 then
      begin
        s.FA := StrToIntDef(f[0], 0);
        s.FB := StrToIntDef(f[1], 0);
        s.FSA := StrToIntDef(f[2], 1);
        s.FSB := StrToIntDef(f[3], 1);
      end;
    finally
      f.Free;
    end;
  end;
  if A(el, 'ttp:trim') = '' then Exit;
  parts := TStringList.Create;
  f := TStringList.Create;
  try
    parts.Delimiter := ';';
    parts.StrictDelimiter := True;
    parts.DelimitedText := A(el, 'ttp:trim');
    for i := 0 to parts.Count - 1 do
    begin
      f.Delimiter := ':';
      f.StrictDelimiter := True;
      f.DelimitedText := parts[i];
      if f.Count < 4 then Continue;
      SetLength(s.Trims, Length(s.Trims) + 1);
      with s.Trims[High(s.Trims)] do
      begin
        Poly := StrToIntDef(f[0], 0);
        U0 := StrToFloatDef(f[1], 0, FS);
        CA := StrToIntDef(f[2], -1);
        CB := StrToIntDef(f[3], -1);
        UA := 0;
        UB := 0;
        if (CA = -2) and (f.Count >= 6) then
        begin
          UA := StrToFloatDef(f[4], 0, FS);
          UB := StrToFloatDef(f[5], 0, FS);
        end;
      end;
    end;
  finally
    f.Free;
    parts.Free;
  end;
end;

function ReadTtpShape(el: TDOMElement; const base: TStyle): TShape;
var
  k: TShapeKind;
  shf: TStringList;
begin
  Result := nil;
  if not KindFromName(A(el, 'ttp:kind'), k) then Exit;
  Result := TShape.Create;
  Result.Kind := k;
  Result.Id := StrToIntDef(A(el, 'ttp:id'), 0);
  Result.P := ParsePts(A(el, 'ttp:pts'));
  Result.Style := ReadStyle(el, base);
  Result.IsRef := A(el, 'ttp:ref') = '1';
  Result.SplineClosed := (k = skSpline) and (A(el, 'ttp:closed') = '1');
  if (k = skSpline) and (A(el, 'ttp:rings') <> '') then ReadRings(el, Result);
  ReadBucket(el, Result);
  ReadSpray(el, Result);
  Result.Soft := Max(0, Min(100, StrToIntDef(A(el, 'ttp:soft'), 0)));
  if A(el, 'ttp:shadow') <> '' then
  begin
    shf := TStringList.Create;
    try
      shf.Delimiter := ';';
      shf.StrictDelimiter := True;
      shf.DelimitedText := A(el, 'ttp:shadow');
      if shf.Count >= 5 then
      begin
        Result.ShOn := True;
        Result.ShDX := StrToFloatDef(shf[0], 0, FS);
        Result.ShDY := StrToFloatDef(shf[1], 0, FS);
        Result.ShBlur := StrToFloatDef(shf[2], 0, FS);
        Result.ShColor := StrToIntDef(shf[3], 0);
        Result.ShTr := StrToIntDef(shf[4], 128);
      end;
    finally
      shf.Free;
    end;
  end;
  Result.Locked := A(el, 'ttp:locked') = '1';
  Result.Hidden := A(el, 'ttp:hidden') = '1';
  Result.Reg := (A(el, 'ttp:regular') = '1') and (Result.Kind = skPolygon);
  Result.SelTarget := StrToIntDef(A(el, 'ttp:seltarget'), 0);
  Result.SelTol := Max(0, Min(100, StrToIntDef(A(el, 'ttp:seltol'), 20)));
  Result.SelHole := A(el, 'ttp:selhole') = '1';
  Result.SelSub := A(el, 'ttp:selsub') = '1';
  Result.SelBase := A(el, 'ttp:selbase') = '1';
  Result.SelWand := A(el, 'ttp:selwand') = '1';
  if (k = skImage) and (A(el, 'ttp:keyorig') <> '') then
  begin
    Result.KeyOrig := A(el, 'ttp:keyorig');
    Result.KeyOn := True;
    Result.KeyColor := StrToIntDef(A(el, 'ttp:keycolor'), 16777215);
    Result.KeyTol := Max(0, Min(100, StrToIntDef(A(el, 'ttp:keytol'), 0)));
  end;
  Result.SelU := StrToFloatDef(A(el, 'ttp:selu'), 0.5, FS);
  Result.SelV := StrToFloatDef(A(el, 'ttp:selv'), 0.5, FS);
  Result.LayerId := StrToIntDef(A(el, 'ttp:layer'), 0);
  Result.GroupId := StrToIntDef(A(el, 'ttp:group'), 0);
  Result.GroupName := A(el, 'ttp:gname');
  Result.Snip := A(el, 'ttp:snip');
  Result.Rot := FNum(el, 'ttp:rot', 0);
  Result.GroupRot := FNum(el, 'ttp:grot', 0);
  ReadTrims(el, Result);
  if Length(Result.P) < PointCountOf(k) then
  begin
    Result.Free;
    Exit(nil);
  end;
  case k of
    skRect: Result.Corner := Max(0, FNum(el, 'ttp:corner', 0));
    skEllipse, skArc:
      begin
        Result.RX := FNum(el, 'ttp:rx', 20);
        Result.RY := FNum(el, 'ttp:ry', 20);
        Result.A1 := FNum(el, 'ttp:a1', 0);
        Result.A2 := FNum(el, 'ttp:a2', Pi);
        Result.Circ := A(el, 'ttp:circ') = '1';
      end;
    skText:
      begin
        Result.Text := el.TextContent;
        Result.FontSize := FNum(el, 'ttp:fs', 18);
        Result.FontName := A(el, 'ttp:ff');
        Result.Style.Fill := SvgToColor(A(el, 'fill'), 0);
        Result.Style.Stroke := NoColor;
      end;
    skPath:
      begin
        Result.PathData := A(el, 'd');
        Result.ParsePath;
      end;
    skImage:
      begin
        Result.ImageData := A(el, 'href');
        if Result.ImageData = '' then Result.ImageData := A(el, 'xlink:href');
        if Pos('base64,', Result.ImageData) > 0 then
          Result.ImageData := Copy(Result.ImageData, Pos('base64,', Result.ImageData) + 7, MaxInt);
      end;
  end;
end;

function ReadForeignShape(el: TDOMElement; const base: TStyle): TShape;
var
  n: string;
  st: TStyle;
  cx, cy, x, y, w, h: Double;
  i: Integer;
begin
  Result := nil;
  n := el.TagName;
  st := ReadStyle(el, base);
  if n = 'line' then
  begin
    Result := TShape.Create;
    Result.Kind := skLine;
    SetLength(Result.P, 2);
    Result.P[0] := MakePt(FNum(el, 'x1'), FNum(el, 'y1'));
    Result.P[1] := MakePt(FNum(el, 'x2'), FNum(el, 'y2'));
  end
  else if (n = 'polyline') or (n = 'polygon') then
  begin
    Result := TShape.Create;
    if n = 'polygon' then Result.Kind := skPolygon else Result.Kind := skPolyline;
    Result.P := ParsePts(A(el, 'points'));
    if Length(Result.P) < 1 then FreeAndNil(Result);
  end
  else if n = 'rect' then
  begin
    x := FNum(el, 'x'); y := FNum(el, 'y'); w := FNum(el, 'width'); h := FNum(el, 'height');
    Result := TShape.Create;
    Result.Kind := skRect;
    SetLength(Result.P, 2);
    Result.P[0] := MakePt(x, y);
    Result.P[1] := MakePt(x + w, y + h);
    Result.Corner := Max(0, Max(FNum(el, 'rx'), FNum(el, 'ry')));
    if A(el, 'ttp:corner') <> '' then Result.Corner := Max(0, FNum(el, 'ttp:corner'));
  end
  else if (n = 'circle') or (n = 'ellipse') then
  begin
    cx := FNum(el, 'cx'); cy := FNum(el, 'cy');
    Result := TShape.Create;
    Result.Kind := skEllipse;
    SetLength(Result.P, 1);
    Result.P[0] := MakePt(cx, cy);
    if n = 'circle' then
    begin
      Result.RX := FNum(el, 'r');
      Result.RY := Result.RX;
      Result.Circ := True;
    end
    else
    begin
      Result.RX := FNum(el, 'rx');
      Result.RY := FNum(el, 'ry');
    end;
  end
  else if n = 'path' then
  begin
    Result := TShape.Create;
    Result.Kind := skPath;
    SetLength(Result.P, 1);
    Result.P[0] := MakePt(0, 0);
    Result.PathData := A(el, 'd');
    Result.ParsePath;
  end
  else if n = 'text' then
  begin
    Result := TShape.Create;
    Result.Kind := skText;
    SetLength(Result.P, 1);
    Result.FontSize := FNum(el, 'font-size', 18);
    Result.FontName := FontFromElement(el);
    Result.P[0] := MakePt(FNum(el, 'x'), FNum(el, 'y') - Result.FontSize);
    Result.Text := el.TextContent;
    st.Stroke := NoColor;
    if StyleProp(el, 'fill') = '' then st.Fill := 0;
  end;
  if Result <> nil then
  begin
    Result.Style := st;
    if SameText(StyleProp(el, 'shape-rendering'), 'crispEdges') or SameText(StyleProp(el, 'shape-rendering'), 'optimizeSpeed') then
      Result.Antialias := False;
  end;
end;

{ ---------- gradients of other programs ---------- }

function GradientById(xml: TXMLDocument; const id: string): TDOMElement;
var
  tags: array[0..1] of string = ('linearGradient', 'radialGradient');
  k, i: Integer;
  nl: TDOMNodeList;
begin
  Result := nil;
  for k := 0 to 1 do
  begin
    nl := xml.GetElementsByTagName(tags[k]);
    try
      for i := 0 to nl.Count - 1 do
        if TDOMElement(nl[i]).GetAttribute('id') = id then Exit(TDOMElement(nl[i]));
    finally
      nl.Free;
    end;
  end;
end;

// an attribute of a gradient, or the one it inherits through href
function GradAttr(xml: TXMLDocument; g: TDOMElement; const name: string): string;
var
  hop: Integer;
  h: string;
begin
  Result := '';
  hop := 0;
  while (g <> nil) and (hop < 8) do
  begin
    if g.HasAttribute(name) then Exit(g.GetAttribute(name));
    h := g.GetAttribute('xlink:href');
    if h = '' then h := g.GetAttribute('href');
    if (h = '') or (h[1] <> '#') then Break;
    g := GradientById(xml, Copy(h, 2, MaxInt));
    Inc(hop);
  end;
end;

// a number of a gradient: "0.5", or "50%" (as a fraction of 1)
function GradNum(const v: string; def: Double): Double;
begin
  if v = '' then Exit(def);
  if v[Length(v)] = '%' then Result := StrToFloatDef(Copy(v, 1, Length(v) - 1), def * 100, FS) / 100
  else Result := StrToFloatDef(v, def, FS);
end;

// the stops of a gradient (or of the one it refers to), in order
procedure GradStops(xml: TXMLDocument; g: TDOMElement; out stops: TGradStops);
var
  hop, cnt, i: Integer;
  h, v: string;
  n: TDOMNode;
  last, p: Double;
  c: Integer;
begin
  SetLength(stops, 0);
  hop := 0;
  while (g <> nil) and (hop < 8) do
  begin
    cnt := 0;
    last := 0;
    n := g.FirstChild;
    while n <> nil do
    begin
      if (n.NodeType = ELEMENT_NODE) and (TDOMElement(n).TagName = 'stop') then
      begin
        SetLength(stops, Length(stops) + 1);
        i := High(stops);
        v := StyleProp(TDOMElement(n), 'stop-color');
        if v = '' then c := 0 else c := SvgToColor(v, 0);
        if c = NoColor then c := 0;
        stops[i].Col := c;
        v := StyleProp(TDOMElement(n), 'stop-opacity');
        if v = '' then stops[i].Tr := 0
        else stops[i].Tr := 255 - Round(255 * Max(0, Min(1, StrToFloatDef(v, 1, FS))));
        // the offset never goes back
        p := GradNum(TDOMElement(n).GetAttribute('offset'), last);
        p := Max(last, Min(1, Max(0, p)));
        stops[i].Pos := p;
        last := p;
        Inc(cnt);
      end;
      n := n.NextSibling;
    end;
    if cnt > 0 then Exit;
    h := g.GetAttribute('xlink:href');
    if h = '' then h := g.GetAttribute('href');
    if (h = '') or (h[1] <> '#') then Break;
    g := GradientById(xml, Copy(h, 2, MaxInt));
    Inc(hop);
  end;
end;

// gradientTransform as a matrix (a b c d e f)
function GradMatrix(const t: string): TDblArr;
var
  ps, q, k: Integer;
  nm, args: string;
  nums: TDblArr;
  m, r: TDblArr;
  f: TStringList;

  function Mul(const a, b: TDblArr): TDblArr;     // a, then b is applied first
  begin
    SetLength(Result, 6);
    Result[0] := a[0] * b[0] + a[2] * b[1];
    Result[1] := a[1] * b[0] + a[3] * b[1];
    Result[2] := a[0] * b[2] + a[2] * b[3];
    Result[3] := a[1] * b[2] + a[3] * b[3];
    Result[4] := a[0] * b[4] + a[2] * b[5] + a[4];
    Result[5] := a[1] * b[4] + a[3] * b[5] + a[5];
  end;

begin
  SetLength(m, 6);
  m[0] := 1; m[1] := 0; m[2] := 0; m[3] := 1; m[4] := 0; m[5] := 0;
  Result := m;
  ps := 1;
  f := TStringList.Create;
  try
    while ps <= Length(t) do
    begin
      q := Pos('(', Copy(t, ps, MaxInt));
      if q = 0 then Break;
      nm := Trim(Copy(t, ps, q - 1));
      ps := ps + q;
      q := Pos(')', Copy(t, ps, MaxInt));
      if q = 0 then Break;
      args := Copy(t, ps, q - 1);
      ps := ps + q;
      f.Clear;
      f.Delimiter := ' ';
      f.StrictDelimiter := True;
      f.DelimitedText := StringReplace(StringReplace(args, ',', ' ', [rfReplaceAll]), '  ', ' ', [rfReplaceAll]);
      SetLength(nums, 0);
      for k := 0 to f.Count - 1 do
        if Trim(f[k]) <> '' then
        begin
          SetLength(nums, Length(nums) + 1);
          nums[High(nums)] := StrToFloatDef(Trim(f[k]), 0, FS);
        end;
      SetLength(r, 6);
      r[0] := 1; r[1] := 0; r[2] := 0; r[3] := 1; r[4] := 0; r[5] := 0;
      if (nm = 'matrix') and (Length(nums) >= 6) then
        for k := 0 to 5 do r[k] := nums[k]
      else if (nm = 'translate') and (Length(nums) >= 1) then
      begin
        r[4] := nums[0];
        if Length(nums) >= 2 then r[5] := nums[1];
      end
      else if (nm = 'scale') and (Length(nums) >= 1) then
      begin
        r[0] := nums[0];
        if Length(nums) >= 2 then r[3] := nums[1] else r[3] := nums[0];
      end
      else if (nm = 'rotate') and (Length(nums) >= 1) then
      begin
        r[0] := Cos(nums[0] * Pi / 180);
        r[1] := Sin(nums[0] * Pi / 180);
        r[2] := -r[1];
        r[3] := r[0];
        if Length(nums) >= 3 then
        begin
          r[4] := nums[1] - r[0] * nums[1] + r[1] * nums[2];
          r[5] := nums[2] - r[1] * nums[1] - r[0] * nums[2];
        end;
      end
      else if (nm = 'skewX') and (Length(nums) >= 1) then r[2] := Tan(nums[0] * Pi / 180)
      else if (nm = 'skewY') and (Length(nums) >= 1) then r[1] := Tan(nums[0] * Pi / 180);
      Result := Mul(Result, r);
    end;
  finally
    f.Free;
  end;
end;

// the shape s is filled with url(#id): it becomes a gradient shape; the line (or circle) the gradient
// runs along is returned as a reference object, to be added to the drawing before s
function ForeignGradient(xml: TXMLDocument; el: TDOMElement; s: TShape; out ref: TShape; byStroke: Boolean = False;
  bboxOf: TShape = nil): Boolean;
var
  v, id, units: string;
  g: TDOMElement;
  stops: TGradStops;
  fo: Double;
  m: TDblArr;
  o: TOutline;
  i, k, n: Integer;
  bx, by, bw, bh, x1, y1, x2, y2, cx, cy, r, sc: Double;
  bbox, radial: Boolean;

  procedure Map(var x, y: Double);
  var
    tx, ty: Double;
  begin
    tx := m[0] * x + m[2] * y + m[4];
    ty := m[1] * x + m[3] * y + m[5];
    if bbox then
    begin
      tx := bx + tx * bw;
      ty := by + ty * bh;
    end;
    x := tx;
    y := ty;
  end;

begin
  Result := False;
  ref := nil;
  if byStroke then v := StyleProp(el, 'stroke') else v := StyleProp(el, 'fill');
  if Copy(v, 1, 5) <> 'url(#' then Exit;
  id := Copy(v, 6, MaxInt);
  k := Pos(')', id);
  if k > 0 then id := Copy(id, 1, k - 1);
  id := Trim(id);
  g := GradientById(xml, id);
  if g = nil then Exit;
  radial := g.TagName = 'radialGradient';
  units := GradAttr(xml, g, 'gradientUnits');
  bbox := units <> 'userSpaceOnUse';
  m := GradMatrix(GradAttr(xml, g, 'gradientTransform'));
  bx := 0; by := 0; bw := 1; bh := 1;
  if bbox then
  begin
    // the box of the gradient is the one of the figure itself (for a stroke, not of the ring that stands for it)
    if bboxOf <> nil then o := ShapeOutline(bboxOf) else o := ShapeOutline(s);
    x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
    for i := 0 to High(o) do
      for k := 0 to High(o[i].Pts) do
      begin
        x1 := Min(x1, o[i].Pts[k].x);
        y1 := Min(y1, o[i].Pts[k].y);
        x2 := Max(x2, o[i].Pts[k].x);
        y2 := Max(y2, o[i].Pts[k].y);
      end;
    if x1 > x2 then Exit;
    bx := x1; by := y1; bw := Max(1e-6, x2 - x1); bh := Max(1e-6, y2 - y1);
  end;
  GradStops(xml, g, stops);
  if Length(stops) = 0 then Exit;
  ref := TShape.Create;
  ref.IsRef := True;
  ref.Style := DefaultStyle;
  if radial then
  begin
    cx := GradNum(GradAttr(xml, g, 'cx'), 0.5);
    cy := GradNum(GradAttr(xml, g, 'cy'), 0.5);
    r := GradNum(GradAttr(xml, g, 'r'), 0.5);
    sc := Sqrt(Abs(m[0] * m[3] - m[1] * m[2]));
    Map(cx, cy);
    if bbox then sc := sc * Sqrt(bw * bh);
    ref.Kind := skEllipse;
    SetLength(ref.P, 1);
    ref.P[0] := MakePt(cx, cy);
    ref.RX := Max(1e-3, r * sc);
    ref.RY := ref.RX;
    ref.Circ := True;
  end
  else
  begin
    x1 := GradNum(GradAttr(xml, g, 'x1'), 0);
    y1 := GradNum(GradAttr(xml, g, 'y1'), 0);
    x2 := GradNum(GradAttr(xml, g, 'x2'), 1);
    y2 := GradNum(GradAttr(xml, g, 'y2'), 0);
    Map(x1, y1);
    Map(x2, y2);
    if Hypot(x2 - x1, y2 - y1) < 1e-6 then x2 := x1 + 1;
    ref.Kind := skLine;
    SetLength(ref.P, 2);
    ref.P[0] := MakePt(x1, y1);
    ref.P[1] := MakePt(x2, y2);
  end;
  // the shape's own fill-opacity multiplies the stops' opacity
  fo := (255 - s.Style.FillTr) / 255;
  n := High(stops);
  s.Style.Fill := stops[0].Col;
  s.Style.FillTr := 255 - Round((255 - stops[0].Tr) * fo);
  s.GradOn := True;
  s.GradRadial := radial;
  s.GradColor := stops[n].Col;
  s.GradTr := 255 - Round((255 - stops[n].Tr) * fo);
  // the stops in between; a first stop after 0 (or a last one before 1) keeps its colour out to the end
  SetLength(s.GradMid, 0);
  if (n > 0) and (stops[0].Pos > 0.0001) then
  begin
    SetLength(s.GradMid, 1);
    s.GradMid[0] := stops[0];
    s.GradMid[0].Tr := s.Style.FillTr;
  end;
  for i := 1 to n - 1 do
  begin
    SetLength(s.GradMid, Length(s.GradMid) + 1);
    s.GradMid[High(s.GradMid)] := stops[i];
    s.GradMid[High(s.GradMid)].Tr := 255 - Round((255 - stops[i].Tr) * fo);
  end;
  if (n > 0) and (stops[n].Pos < 0.9999) then
  begin
    SetLength(s.GradMid, Length(s.GradMid) + 1);
    s.GradMid[High(s.GradMid)] := stops[n];
    s.GradMid[High(s.GradMid)].Tr := s.GradTr;
  end;
  Result := True;
end;


type
  TShadowSpec = record
    DX, DY, Blur: Double;
    Col, Tr: Integer;
  end;

function FindById(xml: TXMLDocument; const tag, id: string): TDOMElement;
var
  i: Integer;
  nl: TDOMNodeList;
begin
  Result := nil;
  nl := xml.GetElementsByTagName(tag);
  try
    for i := 0 to nl.Count - 1 do
      if TDOMElement(nl[i]).GetAttribute('id') = id then Exit(TDOMElement(nl[i]));
  finally
    nl.Free;
  end;
end;

// "url(#id)" -> id
function UrlId(const v: string): string;
var
  k: Integer;
begin
  Result := '';
  if Copy(Trim(v), 1, 5) <> 'url(#' then Exit;
  Result := Copy(Trim(v), 6, MaxInt);
  k := Pos(')', Result);
  if k > 0 then Result := Copy(Result, 1, k - 1);
  Result := Trim(Result);
end;

// the drop shadow a filter="url(#id)" asks for (feDropShadow); False when there is no filter or it is of another kind
function FilterShadowOf(xml: TXMLDocument; el: TDOMElement; out sp: TShadowSpec): Boolean;
var
  f, d: TDOMElement;
  n: TDOMNode;
  v: string;
  op: Double;
begin
  Result := False;
  f := FindById(xml, 'filter', UrlId(StyleProp(el, 'filter')));
  if f = nil then Exit;
  n := f.FirstChild;
  while n <> nil do
  begin
    if (n.NodeType = ELEMENT_NODE) and (TDOMElement(n).TagName = 'feDropShadow') then
    begin
      d := TDOMElement(n);
      sp.DX := StrToFloatDef(A(d, 'dx'), 2, FS);
      sp.DY := StrToFloatDef(A(d, 'dy'), 2, FS);
      v := Trim(A(d, 'stdDeviation'));
      if Pos(' ', v) > 0 then v := Copy(v, 1, Pos(' ', v) - 1);
      sp.Blur := Max(0, StrToFloatDef(v, 2, FS));
      v := A(d, 'flood-color');
      if v = '' then sp.Col := 0 else sp.Col := SvgToColor(v, 0);
      op := 1;
      if A(d, 'flood-opacity') <> '' then op := Max(0, Min(1, StrToFloatDef(A(d, 'flood-opacity'), 1, FS)));
      sp.Tr := 255 - Round(255 * op);
      Exit(True);
    end;
    n := n.NextSibling;
  end;
end;

function ShapeBox(s: TShape; out x1, y1, x2, y2: Double): Boolean;
var
  o: TOutline;
  i, j: Integer;
begin
  o := ShapeOutline(s);
  x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      x1 := Min(x1, o[i].Pts[j].x);
      y1 := Min(y1, o[i].Pts[j].y);
      x2 := Max(x2, o[i].Pts[j].x);
      y2 := Max(y2, o[i].Pts[j].y);
    end;
  Result := x1 <= x2;
end;

// the shapes from index n0 on share the shadow sp as one object would: the ones that lie inside another one of them add nothing
// to the outline of the whole, so only the outer ones get the shadow
procedure ApplyShadow(doc: TDoc; n0: Integer; const sp: TShadowSpec);
var
  i, j: Integer;
  a, b: TShape;
  ax1, ay1, ax2, ay2, bx1, by1, bx2, by2: Double;
  inner: Boolean;
begin
  for i := n0 to doc.Shapes.Count - 1 do
  begin
    a := doc.Shapes[i];
    if a.IsRef or a.ShOn or not ShapeBox(a, ax1, ay1, ax2, ay2) then Continue;
    inner := False;
    for j := n0 to doc.Shapes.Count - 1 do
    begin
      b := doc.Shapes[j];
      if (j = i) or b.IsRef or not ShapeBox(b, bx1, by1, bx2, by2) then Continue;
      if (bx1 <= ax1 + 0.01) and (by1 <= ay1 + 0.01) and (bx2 >= ax2 - 0.01) and (by2 >= ay2 - 0.01) and
         ((bx2 - bx1) * (by2 - by1) > (ax2 - ax1) * (ay2 - ay1) + 0.01) or
         ((Abs((bx2 - bx1) * (by2 - by1) - (ax2 - ax1) * (ay2 - ay1)) <= 0.01) and (j < i) and
          (bx1 <= ax1 + 0.01) and (by1 <= ay1 + 0.01) and (bx2 >= ax2 - 0.01) and (by2 >= ay2 - 0.01)) then
      begin
        inner := True;
        Break;
      end;
    end;
    if inner then Continue;
    a.ShOn := True;
    a.ShDX := sp.DX;
    a.ShDY := sp.DY;
    a.ShBlur := sp.Blur;
    a.ShColor := sp.Col;
    a.ShTr := sp.Tr;
  end;
end;

// the closed figures from index n0 on are cut by the clip figure (a clipPath): what is outside goes, and a figure that is
// completely outside goes altogether. Open lines and the other kinds are left as they are.
procedure ApplyClip(doc: TDoc; n0: Integer; clip: TShape);
var
  i, k, j: Integer;
  s: TShape;
  o, oc: TOutline;
  inside: Boolean;
  pd, err: string;
begin
  if (clip = nil) or not BoolEligible(clip) then Exit;
  oc := ShapeOutline(clip);
  for i := doc.Shapes.Count - 1 downto n0 do
  begin
    s := doc.Shapes[i];
    if s.IsRef or not BoolEligible(s) then Continue;
    o := ShapeOutline(s);
    inside := True;
    for k := 0 to High(o) do
      for j := 0 to High(o[k].Pts) do
        if not InsideOutline(oc, o[k].Pts[j].x, o[k].Pts[j].y) then inside := False;
    if inside then Continue;
    if not BoolOverlap(s, clip) then
    begin
      doc.DeleteShape(s);
      Continue;
    end;
    if BoolCompute(s, clip, 0, pd, err) then
    begin
      s.Kind := skPath;
      SetLength(s.P, 1);
      s.P[0] := MakePt(0, 0);
      s.PathData := pd;
      s.Rot := 0;
      s.Corner := 0;
      s.SplineClosed := False;
      SetLength(s.RingStarts, 0);
      s.ParsePath;
    end;
  end;
end;

// the first figure of the clipPath that el points to with clip-path="url(#id)"; nil: none
function ClipOf(xml: TXMLDocument; el: TDOMElement): TShape;
var
  c: TDOMElement;
  n: TDOMNode;
  st: TStyle;
begin
  Result := nil;
  c := FindById(xml, 'clipPath', UrlId(StyleProp(el, 'clip-path')));
  if c = nil then Exit;
  st := DefaultStyle;
  st.Fill := 0;
  n := c.FirstChild;
  while (n <> nil) and (Result = nil) do
  begin
    if n.NodeType = ELEMENT_NODE then Result := ReadForeignShape(TDOMElement(n), st);
    n := n.NextSibling;
  end;
end;

function EllPathStr(cx, cy, rx, ry: Double): string;
begin
  Result := 'M ' + FloatStr(cx - rx) + ' ' + FloatStr(cy) + ' A ' + FloatStr(rx) + ' ' + FloatStr(ry) + ' 0 1 0 ' +
    FloatStr(cx + rx) + ' ' + FloatStr(cy) + ' A ' + FloatStr(rx) + ' ' + FloatStr(ry) + ' 0 1 0 ' + FloatStr(cx - rx) + ' ' +
    FloatStr(cy) + ' Z ';
end;

function RRectPathStr(x, y, w, h, r: Double): string;
begin
  r := Max(0, Min(r, Min(w, h) / 2));
  if r < 1e-6 then
    Exit('M ' + FloatStr(x) + ' ' + FloatStr(y) + ' L ' + FloatStr(x + w) + ' ' + FloatStr(y) + ' L ' + FloatStr(x + w) + ' ' +
      FloatStr(y + h) + ' L ' + FloatStr(x) + ' ' + FloatStr(y + h) + ' Z ');
  Result := 'M ' + FloatStr(x + r) + ' ' + FloatStr(y) + ' L ' + FloatStr(x + w - r) + ' ' + FloatStr(y) +
    ' A ' + FloatStr(r) + ' ' + FloatStr(r) + ' 0 0 1 ' + FloatStr(x + w) + ' ' + FloatStr(y + r) +
    ' L ' + FloatStr(x + w) + ' ' + FloatStr(y + h - r) +
    ' A ' + FloatStr(r) + ' ' + FloatStr(r) + ' 0 0 1 ' + FloatStr(x + w - r) + ' ' + FloatStr(y + h) +
    ' L ' + FloatStr(x + r) + ' ' + FloatStr(y + h) +
    ' A ' + FloatStr(r) + ' ' + FloatStr(r) + ' 0 0 1 ' + FloatStr(x) + ' ' + FloatStr(y + h - r) +
    ' L ' + FloatStr(x) + ' ' + FloatStr(y + r) +
    ' A ' + FloatStr(r) + ' ' + FloatStr(r) + ' 0 0 1 ' + FloatStr(x + r) + ' ' + FloatStr(y) + ' Z ';
end;

// A stroke painted with a gradient: TTPaint gradients are fills, so the stroke becomes the ring of its width (circle, ellipse and
// rectangle), filled with that gradient. s is the figure read from el; the ring (nil: not possible) comes with the line or circle
// its gradient runs along.
function StrokeRing(xml: TXMLDocument; el: TDOMElement; s: TShape; out gref: TShape): TShape;
var
  w, x, y, bw, bh: Double;
  pd: string;
begin
  Result := nil;
  gref := nil;
  w := Max(0.1, s.Style.Width);
  if s.Kind = skEllipse then
  begin
    pd := EllPathStr(s.P[0].x, s.P[0].y, s.RX + w / 2, s.RY + w / 2);
    if (s.RX - w / 2 > 0.01) and (s.RY - w / 2 > 0.01) then pd := pd + EllPathStr(s.P[0].x, s.P[0].y, s.RX - w / 2, s.RY - w / 2);
  end
  else if s.Kind = skRect then
  begin
    x := Min(s.P[0].x, s.P[1].x);
    y := Min(s.P[0].y, s.P[1].y);
    bw := Abs(s.P[1].x - s.P[0].x);
    bh := Abs(s.P[1].y - s.P[0].y);
    pd := RRectPathStr(x - w / 2, y - w / 2, bw + w, bh + w, s.Corner + w / 2);
    if (bw > w) and (bh > w) then pd := pd + RRectPathStr(x + w / 2, y + w / 2, bw - w, bh - w, Max(0, s.Corner - w / 2));
  end
  else Exit;
  Result := TShape.Create;
  Result.Kind := skPath;
  SetLength(Result.P, 1);
  Result.P[0] := MakePt(0, 0);
  Result.PathData := pd;
  Result.ParsePath;
  Result.Style := DefaultStyle;
  Result.Style.Stroke := NoColor;
  Result.Style.Fill := 0;
  Result.Style.FillTr := s.Style.StrokeTr;
  if not ForeignGradient(xml, el, Result, gref, True, s) then FreeAndNil(Result);
end;


procedure SVGToDoc(const text: string; doc: TDoc; append: Boolean;
  dx, dy: Double; out newIds: TIntArray);
var
  mk: Integer;
  xml: TXMLDocument;
  ss: TStringStream;
  root: TDOMElement;
  map: array of TIdMap;
  pendingCons: array of TDOMElement;
  pendingArr: array of TDOMElement;
  firstNew: Integer;
  layersRead: Boolean;
  gdepth: Integer;

  function MapId(oldId: Integer): Integer;
  var
    i: Integer;
  begin
    for i := 0 to High(map) do
      if map[i].OldId = oldId then Exit(map[i].NewId);
    Result := oldId;
  end;

  procedure AddRead(s: TShape);
  var
    oldId: Integer;
  begin
    oldId := s.Id;
    if append then
    begin
      s.Id := 0;
      s.Translate(dx, dy);
    end;
    doc.AddShape(s);
    SetLength(map, Length(map) + 1);
    map[High(map)].OldId := oldId;
    map[High(map)].NewId := s.Id;
    SetLength(newIds, Length(newIds) + 1);
    newIds[High(newIds)] := s.Id;
  end;

  // the shapes from index n0 on (with the reference lines of their gradients) become one group, when there are at least two
  procedure MakeGroup(n0: Integer);
  var
    i, cnt, gid: Integer;
  begin
    cnt := 0;
    for i := n0 to doc.Shapes.Count - 1 do
      if not doc.Shapes[i].IsRef then Inc(cnt);
    if cnt < 2 then Exit;
    gid := doc.NewGroupId;
    for i := n0 to doc.Shapes.Count - 1 do
      doc.Shapes[i].GroupId := gid;
  end;

  // the clip-path and the filter (drop shadow) of an element or group act on the shapes made from it, from index n0 on
  procedure PostProcess(el: TDOMElement; n0: Integer);
  var
    clip: TShape;
    sp: TShadowSpec;
  begin
    clip := ClipOf(xml, el);
    if clip <> nil then
    begin
      ApplyClip(doc, n0, clip);
      clip.Free;
    end;
    if FilterShadowOf(xml, el, sp) then ApplyShadow(doc, n0, sp);
  end;

  procedure Walk(parent: TDOMNode; const base: TStyle);
  var
    n: TDOMNode;
    el: TDOMElement;
    s, gref, ring, rgref: TShape;
    st: TStyle;
    n0: Integer;
    isLayer: Boolean;
  begin
    n := parent.FirstChild;
    while n <> nil do
    begin
      if n.NodeType = ELEMENT_NODE then
      begin
        el := TDOMElement(n);
        if el.TagName = 'metadata' then
        begin
          // handled separately
        end
        else if A(el, 'ttp:skip') = '1' then
        begin
          // hatch lines of a fill: made again from the fill itself
        end
        else if A(el, 'ttp:kind') <> '' then
        begin
          s := ReadTtpShape(el, base);
          if s <> nil then AddRead(s);
        end
        else if el.TagName = 'g' then
        begin
          // a layer of ours is only a container: its opacity is kept in the metadata
          if Copy(A(el, 'id'), 1, 5) = 'layer' then st := base else st := ReadStyle(el, base);
          n0 := doc.Shapes.Count;
          isLayer := Copy(A(el, 'id'), 1, 5) = 'layer';
          if not isLayer then Inc(gdepth);
          Walk(el, st);
          PostProcess(el, n0);
          if not isLayer then
          begin
            Dec(gdepth);
            // a group of the file (the outermost one; the groups of TTPaint have a single level) is a group here too
            if gdepth = 0 then MakeGroup(n0);
          end;
        end
        else
        begin
          s := ReadForeignShape(el, base);
          if s <> nil then
          begin
            n0 := doc.Shapes.Count;
            ring := nil;
            // a stroke painted with a gradient: the ring of the stroke is filled with it
            if (Copy(Trim(StyleProp(el, 'stroke')), 1, 5) = 'url(#') and (s.Kind in [skEllipse, skRect]) then
            begin
              ring := StrokeRing(xml, el, s, rgref);
              s.Style.Stroke := NoColor;
              if s.Style.Fill = NoColor then FreeAndNil(s);
            end;
            if s <> nil then
            begin
              // filled with a gradient of another program: the line or circle it runs along comes first
              if ForeignGradient(xml, el, s, gref) then
              begin
                AddRead(gref);
                s.GradRef := -gref.Id;           // already a new id: not to be mapped below
              end;
              AddRead(s);
            end;
            if ring <> nil then
            begin
              AddRead(rgref);
              ring.GradRef := -rgref.Id;
              AddRead(ring);
            end;
            PostProcess(el, n0);
          end;
        end;
      end;
      n := n.NextSibling;
    end;
  end;

  procedure ReadConstraints(parent: TDOMNode);
  var
    n, m: TDOMNode;
    el: TDOMElement;
    kk: TConstraintKind;
    c: TConstraint;
    found: Boolean;
    parts: TStringList;
    i, p: Integer;
    refs: string;
    lay: TLayer;
    fpl: TStringList;
    ik: Integer;
  begin
    n := parent.FirstChild;
    while n <> nil do
    begin
      if n.NodeType = ELEMENT_NODE then
      begin
        el := TDOMElement(n);
        if el.TagName = 'ttp:document' then
        begin
          if not append then
          begin
            doc.NextId := Max(doc.NextId, StrToIntDef(A(el, 'ttp:nextid'), 1));
            doc.ActiveLayer := StrToIntDef(A(el, 'ttp:active'), 0);
          end;
          m := el.FirstChild;
          while m <> nil do
          begin
            if (m.NodeType = ELEMENT_NODE) and (TDOMElement(m).TagName = 'ttp:constraint') then
            begin
              SetLength(pendingCons, Length(pendingCons) + 1);
              pendingCons[High(pendingCons)] := TDOMElement(m);
            end;
            if (m.NodeType = ELEMENT_NODE) and (TDOMElement(m).TagName = 'ttp:material') and not append then
            begin
              mk := StrToIntDef(A(TDOMElement(m), 'id'), -1);
              if (mk >= 0) and (mk < MaterialCount) then
              begin
                doc.Mats[mk].Rough := StrToFloatDef(A(TDOMElement(m), 'rough'), 0, FS);
                doc.Mats[mk].Scale := StrToFloatDef(A(TDOMElement(m), 'scale'), 1, FS);
                doc.Mats[mk].Angle := StrToFloatDef(A(TDOMElement(m), 'angle'), 0, FS);
                doc.Mats[mk].Texture := StrToFloatDef(A(TDOMElement(m), 'texture'), 1, FS);
                doc.Mats[mk].Gloss := StrToFloatDef(A(TDOMElement(m), 'gloss'), 1, FS);
                doc.Mats[mk].Bright := StrToFloatDef(A(TDOMElement(m), 'bright'), 1, FS);
                doc.Mats[mk].Tint := StrToIntDef(A(TDOMElement(m), 'tint'), $FFFFFF);
                doc.Mats[mk].Opacity := StrToFloatDef(A(TDOMElement(m), 'opacity'), 1, FS);
                doc.Mats[mk].Thick := StrToFloatDef(A(TDOMElement(m), 'thick'), 0, FS);
                doc.Mats[mk].Curve := StrToFloatDef(A(TDOMElement(m), 'curve'), 0, FS);
                doc.Mats[mk].CX := StrToFloatDef(A(TDOMElement(m), 'cx'), 0.5, FS);
                doc.Mats[mk].CY := StrToFloatDef(A(TDOMElement(m), 'cy'), 0.5, FS);
              end;
            end;
            if (m.NodeType = ELEMENT_NODE) and (TDOMElement(m).TagName = 'ttp:layer') and not append then
            begin
              if not layersRead then
              begin
                doc.Layers.Clear;
                layersRead := True;
              end;
              lay := TLayer.Create;
              lay.Id := StrToIntDef(A(TDOMElement(m), 'id'), 0);
              lay.Name := A(TDOMElement(m), 'name');
              lay.Visible := A(TDOMElement(m), 'visible') <> '0';
              lay.Locked := A(TDOMElement(m), 'locked') = '1';
              lay.HideRefs := A(TDOMElement(m), 'hiderefs') = '1';
              lay.HideCons := A(TDOMElement(m), 'hidecons') = '1';
              lay.LightAz := StrToFloatDef(A(TDOMElement(m), 'lightaz'), 217, FS);
              lay.LightEl := StrToFloatDef(A(TDOMElement(m), 'lightel'), 60, FS);
              lay.LightDiv := StrToFloatDef(A(TDOMElement(m), 'lightdiv'), 0, FS);
              lay.LightPower := StrToFloatDef(A(TDOMElement(m), 'lightpower'), 1, FS);
              lay.LightTint := StrToIntDef(A(TDOMElement(m), 'lighttint'), $FFFFFF);
              lay.Opacity := Max(0, Min(255, StrToIntDef(A(TDOMElement(m), 'opacity'), 255)));
              lay.Scale := StrToFloatDef(A(TDOMElement(m), 'scale'), 1, FS);
              lay.Bg := StrToIntDef(A(TDOMElement(m), 'bg'), NoColor);
              if lay.Scale <= 0 then lay.Scale := 1;
              lay.IsFilter := A(TDOMElement(m), 'filter') = '1';
              if lay.IsFilter then
              begin
                lay.FName := A(TDOMElement(m), 'fname');
                lay.FScript := A(TDOMElement(m), 'fscript');
                lay.FFeather := Max(0, StrToFloatDef(A(TDOMElement(m), 'ffeather'), 0, FS));
                // older files fade at the borders of the holes as at the outer ones
                lay.FFeatherIn := Max(0, StrToFloatDef(A(TDOMElement(m), 'ffeatherin'), lay.FFeather, FS));
                fpl := TStringList.Create;
                try
                  fpl.Delimiter := ';';
                  fpl.StrictDelimiter := True;
                  if A(TDOMElement(m), 'ftype') = '1' then
                  begin
                    // the first version of the filter layers: contrast, luminance, saturation
                    lay.FName := FltBuiltinName(FltScriptCLS);
                    lay.FScript := FltBuiltinScript(FltScriptCLS);
                    fpl.DelimitedText := A(TDOMElement(m), 'fp');
                  end
                  else fpl.DelimitedText := A(TDOMElement(m), 'fvals');
                  SetLength(lay.FVals, fpl.Count);
                  for ik := 0 to fpl.Count - 1 do lay.FVals[ik] := StrToFloatDef(fpl[ik], 0, FS);
                finally
                  fpl.Free;
                end;
              end;
              doc.Layers.Add(lay);
              doc.NextLayerId := Max(doc.NextLayerId, lay.Id + 1);
            end;
            if (m.NodeType = ELEMENT_NODE) and (TDOMElement(m).TagName = 'ttp:array') then
            begin
              SetLength(pendingArr, Length(pendingArr) + 1);
              pendingArr[High(pendingArr)] := TDOMElement(m);
            end;
            m := m.NextSibling;
          end;
        end
        else ReadConstraints(el);
      end;
      n := n.NextSibling;
    end;
  end;

var
  i, p, j: Integer;
  fl: TStringList;
  el: TDOMElement;
  c: TConstraint;
  kk, ck: TConstraintKind;
  found: Boolean;
  parts: TStringList;
  refs: TRefArray;
  txt: string;
  base: TStyle;
  w, h: Double;
  vb: TPtArray;
  allMapped: Boolean;
  trShape: TShape;
  sp: TArraySpec;
  arrOld, arrNew: array of Integer;
  k, groupBase: Integer;
begin
  layersRead := False;
  SetLength(newIds, 0);
  SetLength(map, 0);
  SetLength(pendingCons, 0);
  SetLength(pendingArr, 0);
  ss := TStringStream.Create(text);
  xml := nil;
  try
    ReadXMLFile(xml, ss);
    root := xml.DocumentElement;
    if (root = nil) or (LowerCase(root.TagName) <> 'svg') then
      raise Exception.Create('Not an SVG document');
    if not append then
    begin
      doc.Clear;
      w := StrToFloatDef(StringReplace(A(root, 'width'), 'px', '', []), 0, FS);
      h := StrToFloatDef(StringReplace(A(root, 'height'), 'px', '', []), 0, FS);
      vb := ParsePts(StringReplace(A(root, 'viewBox'), ' ', ',', [rfReplaceAll]));
      if (w <= 0) or (h <= 0) then
        if Length(vb) >= 2 then
        begin
          w := vb[1].x;
          h := vb[1].y;
        end;
      if (w > 0) and (h > 0) then
      begin
        doc.Width := Round(w);
        doc.Height := Round(h);
      end;
    end;
    base.Stroke := NoColor;
    base.Fill := 0;
    base.Width := 1;
    base.Cap := lcFlat;
    base.Join := ljMiter;
    base.Dash := dsSolid;
    base.StrokeTr := 0;
    base.FillTr := 0;
    groupBase := 0;
    if append then
      for i := 0 to doc.Shapes.Count - 1 do
        if doc.Shapes[i].GroupId > groupBase then groupBase := doc.Shapes[i].GroupId;
    gdepth := 0;
    Walk(root, base);
    // the groups of what was added get numbers of their own
    if append then
      for i := 0 to High(newIds) do
        if (doc.FindShape(newIds[i]) <> nil) and (doc.FindShape(newIds[i]).GroupId > 0) then
          doc.FindShape(newIds[i]).GroupId := groupBase + doc.FindShape(newIds[i]).GroupId;
    for i := 0 to High(newIds) do
      if doc.FindShape(newIds[i]) <> nil then
      begin
        trShape := doc.FindShape(newIds[i]);
        // the reference line of a gradient was numbered again with the rest
        if trShape.GradRef < 0 then trShape.GradRef := -trShape.GradRef
        else if trShape.GradRef > 0 then trShape.GradRef := MapId(trShape.GradRef);
        for p := 0 to High(trShape.Trims) do
        begin
          if trShape.Trims[p].CA >= 0 then trShape.Trims[p].CA := MapId(trShape.Trims[p].CA);
          if trShape.Trims[p].CB >= 0 then trShape.Trims[p].CB := MapId(trShape.Trims[p].CB);
        end;
        for p := 0 to High(trShape.Extends) do
          trShape.Extends[p].Boundary := MapId(trShape.Extends[p].Boundary);
        for p := 0 to High(trShape.BucketIds) do trShape.BucketIds[p] := MapId(trShape.BucketIds[p]);
        if trShape.OffSrc > 0 then trShape.OffSrc := MapId(trShape.OffSrc);
        if trShape.MirSrc > 0 then
        begin
          trShape.MirSrc := MapId(trShape.MirSrc);
          trShape.MirAxis := MapId(trShape.MirAxis);
        end;
        if trShape.FA > 0 then
        begin
          trShape.FA := MapId(trShape.FA);
          trShape.FB := MapId(trShape.FB);
        end;
      end;
    if append then
      for i := 0 to High(newIds) do
        if doc.FindShape(newIds[i]) <> nil then doc.FindShape(newIds[i]).LayerId := doc.ActiveLayer;
    ReadConstraints(root);
    if not append then doc.EnsureLayers;
    doc.EnforceFilterRefs;
    for i := 0 to High(pendingCons) do
    begin
      el := pendingCons[i];
      found := False;
      ck := ckFixed;
      for kk := Low(TConstraintKind) to High(TConstraintKind) do
        if ConstraintNames[kk] = A(el, 'kind') then
        begin
          ck := kk;
          found := True;
        end;
      if not found then Continue;
      parts := TStringList.Create;
      try
        parts.Delimiter := ' ';
        parts.StrictDelimiter := True;
        parts.DelimitedText := A(el, 'refs');
        SetLength(refs, 0);
        allMapped := True;
        for p := 0 to parts.Count - 1 do
        begin
          txt := parts[p];
          if Pos(':', txt) = 0 then Continue;
          SetLength(refs, Length(refs) + 1);
          refs[High(refs)] := MakeRef(MapId(StrToIntDef(Copy(txt, 1, Pos(':', txt) - 1), 0)),
            StrToIntDef(Copy(txt, Pos(':', txt) + 1, MaxInt), -1));
          if doc.FindShape(refs[High(refs)].Shape) = nil then allMapped := False;
        end;
      finally
        parts.Free;
      end;
      if not allMapped or (Length(refs) = 0) then Continue;
      c := TConstraint.Create;
      c.Kind := ck;
      c.Refs := refs;
      c.Id := StrToIntDef(A(el, 'ttp:id'), 0);
      c.Value := StrToFloatDef(A(el, 'value'), 0, FS);
      c.Aux := StrToFloatDef(A(el, 'aux'), 1, FS);
      c.Axis := StrToIntDef(A(el, 'axis'), 0);
      c.Diam := A(el, 'diam') = '1';
      c.NoPrint := A(el, 'noprint') = '1';
      c.UnitText := A(el, 'unit');
      c.Offset := StrToFloatDef(A(el, 'offset'), 30, FS);
      if append or (c.Id <= 0) then
      begin
        c.Id := doc.NextId;
        Inc(doc.NextId);
      end
      else if c.Id >= doc.NextId then doc.NextId := c.Id + 1;
      doc.Cons.Add(c);
    end;
    // arrays: new ids when pasting, and the copies follow
    SetLength(arrOld, 0);
    SetLength(arrNew, 0);
    for i := 0 to High(pendingArr) do
    begin
      el := pendingArr[i];
      sp := TArraySpec.Create;
      sp.Id := StrToIntDef(A(el, 'id'), 0);
      sp.Src := MapId(StrToIntDef(A(el, 'src'), 0));
      sp.Polar := A(el, 'polar') = '1';
      sp.Cols := StrToIntDef(A(el, 'cols'), 1);
      sp.Rows := StrToIntDef(A(el, 'rows'), 1);
      sp.DX := StrToFloatDef(A(el, 'dx'), 0, FS);
      sp.DY := StrToFloatDef(A(el, 'dy'), 0, FS);
      sp.Count := StrToIntDef(A(el, 'count'), 2);
      sp.CX := StrToFloatDef(A(el, 'cx'), 0, FS);
      sp.CY := StrToFloatDef(A(el, 'cy'), 0, FS);
      sp.Total := StrToFloatDef(A(el, 'total'), 360, FS);
      if A(el, 'freed') <> '' then
      begin
        fl := TStringList.Create;
        try
          fl.Delimiter := ',';
          fl.StrictDelimiter := True;
          fl.DelimitedText := A(el, 'freed');
          for j := 0 to fl.Count - 1 do
            if StrToIntDef(fl[j], 0) > 0 then
            begin
              SetLength(sp.Freed, Length(sp.Freed) + 1);
              sp.Freed[High(sp.Freed)] := StrToInt(fl[j]);
            end;
        finally
          fl.Free;
        end;
      end;
      if (doc.FindShape(sp.Src) = nil) or (sp.N < 2) or (sp.N > 400) then
      begin
        sp.Free;
        Continue;
      end;
      SetLength(arrOld, Length(arrOld) + 1);
      SetLength(arrNew, Length(arrNew) + 1);
      arrOld[High(arrOld)] := sp.Id;
      if append or (sp.Id <= 0) then
      begin
        sp.Id := doc.NextId;
        Inc(doc.NextId);
      end
      else if sp.Id >= doc.NextId then doc.NextId := sp.Id + 1;
      arrNew[High(arrNew)] := sp.Id;
      doc.Arrays.Add(sp);
    end;
    for i := 0 to High(newIds) do
    begin
      trShape := doc.FindShape(newIds[i]);
      if (trShape = nil) or (trShape.ArrId <= 0) then Continue;
      p := -1;
      for k := 0 to High(arrOld) do
        if arrOld[k] = trShape.ArrId then p := k;
      if p >= 0 then trShape.ArrId := arrNew[p]
      else
      begin
        trShape.ArrId := 0;
        trShape.ArrK := 0;
      end;
    end;
  finally
    xml.Free;
    ss.Free;
  end;
end;


function SvgSize(const text: string; out w, h: Double): Boolean;
var
  ss: TStringStream;
  xml: TXMLDocument;
  root: TDOMElement;
  vb: TPtArray;
begin
  Result := False;
  w := 0;
  h := 0;
  xml := nil;
  ss := TStringStream.Create(text);
  try
    try
      ReadXMLFile(xml, ss);
      root := xml.DocumentElement;
      if (root = nil) or (LowerCase(root.TagName) <> 'svg') then Exit;
      w := StrToFloatDef(StringReplace(A(root, 'width'), 'px', '', []), 0, FS);
      h := StrToFloatDef(StringReplace(A(root, 'height'), 'px', '', []), 0, FS);
      vb := ParsePts(StringReplace(A(root, 'viewBox'), ' ', ',', [rfReplaceAll]));
      if ((w <= 0) or (h <= 0)) and (Length(vb) >= 2) then
      begin
        w := vb[1].x;
        h := vb[1].y;
      end;
      Result := (w > 0) and (h > 0);
    except
      Result := False;
    end;
  finally
    xml.Free;
    ss.Free;
  end;
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

end.
