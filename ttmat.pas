{ Materials: what a surface looks like under a light that comes in parallel beams. Pure functions, no drawing:
  the renderer asks for the colour of a point (position on the page and direction of the surface there). }
unit TTMat;

{$mode objfpc}{$H+}

interface

const
  MaterialCount = 9;
  MaterialNames: array[0..MaterialCount - 1] of string = ('Gold', 'Chrome', 'Copper', 'Magnesium alloy', 'Metallic black',
    'Teak wood', 'Glass', 'Marble', 'Granite');

var
  // the direction the light comes from (towards the light), x to the right, y down, z towards the viewer
  LightX: Double = -0.30;
  LightY: Double = 0.40;
  LightZ: Double = 0.865;
  LightPower: Double = 1;                   // the strength of the light (1 as made)
  LightSpread: Double = 0;                  // the spread of the beam, in radians (half angle)
  TintR: Double = 1;
  TintG: Double = 1;
  TintB: Double = 1;

type
  // what can be set in a material (the defaults give the look it has when it is chosen)
  TMatParams = record
    Rough: Double;      // 0..1: how much the reflections are scattered (0: polished, 1: satin)
    Scale: Double;      // 0.2..5: the step of the texture (the grain, the veins, the flakes): 1 as made
    Angle: Double;      // 0..360 degrees: where the texture runs (the grain of the wood, the brushing of the metal)
    Texture: Double;    // 0..1: how much the texture shows
    Gloss: Double;      // 0..2: strength of the highlights and of the reflections
    Bright: Double;     // 0.5..1.5: brightness
    Tint: Integer;      // a colour that the material is multiplied by (white: none), a TColor
    Opacity: Double;    // 0.1..1
    Thick: Double;      // 0..1 (glass): the thickness of the glass: it absorbs more light (greener, more opaque, stronger edges)
    CX, CY: Double;     // 0..1 (glass): where the centre of the curve is on the surface (0.5, 0.5: the middle)
    Curve: Double;      // -1..1 (glass): the curve of the surface: > 0 convex (a magnifying lens), < 0 concave (it shrinks what is behind)
  end;

var
  // the parameters of the material that is being drawn (set by the renderer before it asks for colours)
  CurMat: TMatParams;

function DefaultMatParams: TMatParams;
function SameMatParams(const a, b: TMatParams): Boolean;

// the average colour of a material, as a TColor (BGR) value
function MaterialAvg(m: Integer): Integer;

// the colour of the material at the page point (x, y), where the surface looks towards (nx, ny, nz); flat: a plane (its
// small variations come from the position); the result is 0..255 each, a is the opacity
procedure MaterialShade(m: Integer; x0, y0, nx, ny, nz: Double; flat: Boolean; su, sv: Double; out r, g, b, a: Integer);

// the light from its angles: compass direction in the page (0 = from the top, 90 = from the right), height above the page, spread of
// the beam (all degrees) and the dominant colour of the light (a TColor)
procedure SetLightAngles(azDeg, elDeg, divDeg: Double; tint: Integer; power: Double = 1);

procedure SetLightDirection(ax, ay, az: Double);

implementation

uses
  Math;

const
  Avg: array[0..MaterialCount - 1] of Integer = ($3CC8F0, $E6E0DC, $5A8CD8, $B4AEA8, $202020, $2D4C80, $F0E6C8, $F0EEEE, $807C78);

function DefaultMatParams: TMatParams;
begin
  Result.Rough := 0;
  Result.Scale := 1;
  Result.Angle := 0;
  Result.Texture := 1;
  Result.Gloss := 1;
  Result.Bright := 1;
  Result.Tint := $FFFFFF;
  Result.Opacity := 1;
  Result.Thick := 0;
  Result.Curve := 0;
  Result.CX := 0.5;
  Result.CY := 0.5;
end;

function SameMatParams(const a, b: TMatParams): Boolean;
begin
  Result := (Abs(a.Rough - b.Rough) < 1e-6) and (Abs(a.Scale - b.Scale) < 1e-6) and (Abs(a.Angle - b.Angle) < 1e-6) and
            (Abs(a.Texture - b.Texture) < 1e-6) and (Abs(a.Gloss - b.Gloss) < 1e-6) and (Abs(a.Bright - b.Bright) < 1e-6) and
            (a.Tint = b.Tint) and (Abs(a.Opacity - b.Opacity) < 1e-6) and (Abs(a.Thick - b.Thick) < 1e-6) and
            (Abs(a.Curve - b.Curve) < 1e-6) and (Abs(a.CX - b.CX) < 1e-6) and (Abs(a.CY - b.CY) < 1e-6);
end;

function MaterialAvg(m: Integer): Integer;
begin
  if (m < 0) or (m >= MaterialCount) then Result := 0 else Result := Avg[m];
end;

procedure SetLightAngles(azDeg, elDeg, divDeg: Double; tint: Integer; power: Double);
var
  a, e, mx: Double;
begin
  a := azDeg * Pi / 180;
  e := Max(1, Min(90, elDeg)) * Pi / 180;
  LightX := Sin(a) * Cos(e);
  LightY := -Cos(a) * Cos(e);
  LightZ := Sin(e);
  LightSpread := Max(0, Min(60, divDeg)) * Pi / 180;
  LightPower := Max(0, Min(4, power));
  TintR := (tint and $FF) / 255;
  TintG := ((tint shr 8) and $FF) / 255;
  TintB := ((tint shr 16) and $FF) / 255;
  // the colour gives the hue, not the loss of light
  mx := Max(TintR, Max(TintG, TintB));
  if mx < 0.02 then
  begin
    TintR := 1; TintG := 1; TintB := 1;
  end
  else
  begin
    TintR := TintR / mx;
    TintG := TintG / mx;
    TintB := TintB / mx;
  end;
end;

procedure SetLightDirection(ax, ay, az: Double);
var
  l: Double;
begin
  l := Sqrt(ax * ax + ay * ay + az * az);
  if l < 1e-9 then Exit;
  LightX := ax / l;
  LightY := ay / l;
  LightZ := az / l;
end;

function Clamp01(v: Double): Double;
begin
  if v < 0 then Result := 0 else if v > 1 then Result := 1 else Result := v;
end;

function Smooth(a, b, v: Double): Double;
var
  t: Double;
begin
  t := Clamp01((v - a) / (b - a));
  Result := t * t * (3 - 2 * t);
end;

function Mix(a, b, t: Double): Double;
begin
  Result := a + (b - a) * t;
end;

// a repeatable number 0..1 for a point of the integer grid
{$PUSH}{$Q-}{$R-}
function Hash2(ix, iy: Integer): Double;
var
  h: LongWord;
begin
  h := LongWord(ix) * 374761393 + LongWord(iy) * 668265263;
  h := (h xor (h shr 13)) * 1274126177;
  h := h xor (h shr 16);
  Result := (h and $FFFFFF) / 16777215.0;
end;
{$POP}

function Noise(x, y: Double): Double;
var
  ix, iy: Integer;
  fx, fy, a, b, c, d: Double;
begin
  ix := Floor(x);
  iy := Floor(y);
  fx := x - ix;
  fy := y - iy;
  fx := fx * fx * (3 - 2 * fx);
  fy := fy * fy * (3 - 2 * fy);
  a := Hash2(ix, iy);
  b := Hash2(ix + 1, iy);
  c := Hash2(ix, iy + 1);
  d := Hash2(ix + 1, iy + 1);
  Result := Mix(Mix(a, b, fx), Mix(c, d, fx), fy);
end;

function Fbm(x, y: Double): Double;
begin
  Result := 0.5 * Noise(x, y) + 0.25 * Noise(x * 2.03, y * 2.03 + 11.7) + 0.125 * Noise(x * 4.1, y * 4.1 + 23.1);
  Result := Result / 0.875;
end;

// the exponent of a lobe once the beam spreads: a narrow lobe (large n) is widened by the spread of the light
function Spread(n: Double): Double;
begin
  Result := 1 / (1 / Max(n, 0.01) + 2 * LightSpread * LightSpread + 0.7 * CurMat.Rough * CurMat.Rough * 2);
end;

// the colours a metal takes from its brightest to its darkest reflection (position 0..1, then r, g, b)
const
  RampStops = 6;
  Ramps: array[0..4, 0..RampStops - 1, 0..3] of Integer = (
    // gold: from the deep amber of its shadow to the pale champagne of its highlight
    ((0, 104, 66, 18), (20, 150, 104, 36), (44, 182, 134, 59), (62, 211, 169, 87), (82, 235, 208, 140), (100, 248, 230, 176)),
    // chrome
    ((0, 18, 20, 26), (22, 66, 72, 84), (46, 140, 148, 162), (68, 205, 213, 226), (86, 238, 243, 250), (100, 255, 255, 255)),
    // copper
    ((0, 66, 28, 14), (20, 126, 64, 36), (44, 172, 98, 58), (62, 206, 130, 88), (82, 232, 164, 120), (100, 250, 202, 164)),
    // magnesium alloy (satin)
    ((0, 62, 64, 68), (25, 108, 112, 118), (50, 156, 160, 166), (72, 194, 198, 204), (88, 222, 225, 229), (100, 240, 242, 245)),
    // metallic black
    ((0, 4, 4, 6), (25, 14, 14, 19), (50, 38, 41, 50), (70, 78, 84, 98), (88, 150, 158, 176), (100, 226, 232, 245)));

procedure RampColour(k: Integer; e: Double; out r, g, b: Double);
var
  i: Integer;
  t, p0, p1: Double;
begin
  e := Clamp01(e) * 100;
  i := 0;
  while (i < RampStops - 2) and (e > Ramps[k, i + 1, 0]) do Inc(i);
  p0 := Ramps[k, i, 0];
  p1 := Ramps[k, i + 1, 0];
  t := Clamp01((e - p0) / (p1 - p0));
  r := Mix(Ramps[k, i, 1], Ramps[k, i + 1, 1], t) / 255;
  g := Mix(Ramps[k, i, 2], Ramps[k, i + 1, 2], t) / 255;
  b := Mix(Ramps[k, i, 3], Ramps[k, i + 1, 3], t) / 255;
end;

procedure MaterialShade(m: Integer; x0, y0, nx, ny, nz: Double; flat: Boolean; su, sv: Double; out r, g, b, a: Integer);
var
  x, y, ang, tx: Double;
  ar, ag, ab, alpha, shin, specK, amb, dif, spec, glossK: Double;
  cr, cg, cb, e, lobeL, lobeD, rx, ry, rz, hx, hy, hz, hl, dx, dy, dz, dl, v, w, t, sp: Double;
  base, ampL, ampD, pL, pD: Double;
  metalK: Integer;
  pr, pg, pb, tr, tg, tb, thk: Double;
begin
  alpha := 1;
  // the texture: turned and scaled (the step of the grain, of the flakes); the position of the sheen stays where it is
  ang := CurMat.Angle * Pi / 180;
  tx := Max(0.05, CurMat.Scale);
  x := (x0 * Cos(ang) + y0 * Sin(ang)) / tx;
  y := (-x0 * Sin(ang) + y0 * Cos(ang)) / tx;
  // a plane has no direction of its own: the reflection changes across it, as on a polished plate
  if flat then
  begin
    nx := 0.34 * (su - 0.5) + 0.03 * (Noise(x * 0.01, y * 0.01) - 0.5);
    ny := 0.90 * (sv - 0.5) + 0.03 * (Noise(x * 0.01 + 9, y * 0.01) - 0.5);
    // a curved glass: the surface looks away from the centre (convex) or towards it (concave)
    if m = 6 then
    begin
      nx := nx + CurMat.Curve * (su - CurMat.CX) / (2 * Max(CurMat.CX, 1 - CurMat.CX));
      ny := ny + CurMat.Curve * (sv - CurMat.CY) / (2 * Max(CurMat.CY, 1 - CurMat.CY));
    end;
    nz := Sqrt(Max(0.01, 1 - nx * nx - ny * ny));
  end;
  // the thickness of the glass here: a convex lens is thicker at the centre, a concave one at the edge
  thk := Clamp01(CurMat.Thick);
  if flat and (m = 6) then
  begin
    v := Sqr((su - CurMat.CX) / Max(CurMat.CX, 1 - CurMat.CX)) + Sqr((sv - CurMat.CY) / Max(CurMat.CY, 1 - CurMat.CY));
    thk := Clamp01(thk * (1 + 0.8 * CurMat.Curve * (1 - 2 * Min(1, v))));
  end;
  // what the surface mirrors: R is the direction of the reflection of the viewer (who looks along z)
  rx := 2 * nz * nx;
  ry := 2 * nz * ny;
  rz := 2 * nz * nz - 1;
  // a broad lobe where the light itself is mirrored, and a dark band on the opposite side (the dark surroundings of the studio)
  dx := -0.5 * LightX;
  dy := -LightY;
  dz := 0.45;
  dl := Sqrt(dx * dx + dy * dy + dz * dz);
  dx := dx / dl; dy := dy / dl; dz := dz / dl;
  hx := LightX; hy := LightY; hz := LightZ + 1;
  hl := Sqrt(hx * hx + hy * hy + hz * hz);
  hx := hx / hl; hy := hy / hl; hz := hz / hl;
  sp := Max(0, nx * hx + ny * hy + nz * hz);
  metalK := -1;
  case m of
    0: begin metalK := 0; base := 0.68; ampL := 0.30; ampD := 0.24; pL := 3.0; pD := 4.0; end;
    1: begin metalK := 1; base := 0.55; ampL := 0.62; ampD := 0.55; pL := 7.0; pD := 3.0; end;
    2: begin metalK := 2; base := 0.66; ampL := 0.32; ampD := 0.26; pL := 3.0; pD := 4.0; end;
    3: begin metalK := 3; base := 0.52; ampL := 0.40; ampD := 0.26; pL := 1.7; pD := 2.0; end;
    4: begin metalK := 4; base := 0.26; ampL := 0.80; ampD := 0.24; pL := 6.0; pD := 3.0; end;
  end;
  if metalK >= 0 then
  begin
    lobeL := Power(Max(0, rx * LightX + ry * LightY + rz * LightZ), Spread(pL));
    lobeD := Power(Max(0, rx * dx + ry * dy + rz * dz), Spread(pD));
    e := base + CurMat.Gloss * (ampL * LightPower * lobeL - ampD * lobeD);
    if m = 3 then e := e + 0.10 * CurMat.Texture * (Noise(x * 0.03, y * 1.3) * 0.6 + Noise(x * 0.11, y * 2.7) * 0.4 - 0.5);   // brushed
    RampColour(metalK, e, cr, cg, cb);
    if m = 4 then
      if Hash2(Floor(x * 0.9), Floor(y * 0.9)) > 1 - 0.025 * CurMat.Texture then
      begin
        cr := Mix(cr, 0.75, 0.7); cg := Mix(cg, 0.77, 0.7); cb := Mix(cb, 0.85, 0.7);     // flakes
      end;
  end
  else
  begin
    amb := 0.30;
    glossK := 0;
    shin := 20;
    specK := 0.2;
    ar := 0.7; ag := 0.7; ab := 0.7;
    pr := -1; pg := 0; pb := 0;
    case m of
      5:
        begin
          // teak: the grain runs along x
          v := 0.5 + 0.5 * Sin(y * 0.42 + 7 * Fbm(x * 0.012, y * 0.05) + 3 * Noise(x * 0.004, y * 0.02));
          w := 0.8 + 0.4 * Noise(x * 0.5, y * 0.12);
          ar := Mix(0.42, 0.62, v) * w; ag := Mix(0.26, 0.43, v) * w; ab := Mix(0.12, 0.22, v) * w;
          pr := 0.52; pg := 0.35; pb := 0.17;
          shin := 18; specK := 0.15; glossK := 0.10;
        end;
      6:
        begin
          // glass: it shows what is behind it; its edges are thicker (greener, more opaque), and the light is a white spot
          // the thicker it is the more it absorbs: deeper green, more opaque, stronger edges
          ar := 0.62 * (1 - 0.45 * thk); ag := 0.84 * (1 - 0.20 * thk); ab := 0.80 * (1 - 0.28 * thk);
          shin := 220; specK := 1.0;
          alpha := 0.10 + 0.70 * Power(Clamp01(1 - nz), 2.0) + thk * (0.20 + 0.28 * Power(Clamp01(1 - nz), 2.0));
          glossK := 0.45;
        end;
      7:
        begin
          v := Abs(Sin(x * 0.018 + 5.5 * Fbm(x * 0.008, y * 0.008) + y * 0.006));
          t := 1 - Smooth(0.0, 0.16, v);
          w := Fbm(x * 0.05, y * 0.05);
          ar := Mix(0.94, 0.50, t) * (0.96 + 0.06 * w); ag := Mix(0.94, 0.52, t) * (0.96 + 0.06 * w); ab := Mix(0.96, 0.56, t) * (0.96 + 0.06 * w);
          pr := 0.94; pg := 0.94; pb := 0.96;
          shin := 140; specK := 0.7; glossK := 0.28;
        end;
      8:
        begin
          v := Noise(x * 0.9, y * 0.9);
          w := Noise(x * 0.25 + 40, y * 0.25);
          ar := 0.50; ag := 0.49; ab := 0.50;
          if v > 0.70 then begin ar := 0.14; ag := 0.14; ab := 0.15; end
          else if v < 0.24 then begin ar := 0.88; ag := 0.82; ab := 0.78; end
          else if w > 0.62 then begin ar := 0.66; ag := 0.52; ab := 0.50; end;
          pr := 0.5; pg := 0.49; pb := 0.5;
          shin := 55; specK := 0.4; glossK := 0.15;
        end;
    end;
    // how much of the texture shows
    if pr >= 0 then
    begin
      ar := Mix(pr, ar, CurMat.Texture);
      ag := Mix(pg, ag, CurMat.Texture);
      ab := Mix(pb, ab, CurMat.Texture);
    end;
    dif := Max(0, nx * LightX + ny * LightY + nz * LightZ);
    spec := Power(sp, Spread(shin)) * specK * CurMat.Gloss * LightPower;
    glossK := glossK * CurMat.Gloss * LightPower;
    lobeL := Power(Max(0, rx * LightX + ry * LightY + rz * LightZ), Spread(3.0));
    cr := ar * (amb + (1 - amb) * dif) + spec + glossK * lobeL;
    cg := ag * (amb + (1 - amb) * dif) + spec + glossK * lobeL;
    cb := ab * (amb + (1 - amb) * dif) + spec + glossK * lobeL;
    if m = 6 then alpha := Max(alpha, Clamp01(spec + 0.5 * glossK * lobeL));
  end;
  // the colour of the material itself, its brightness, the colour of the light
  tr := (CurMat.Tint and $FF) / 255;
  tg := ((CurMat.Tint shr 8) and $FF) / 255;
  tb := ((CurMat.Tint shr 16) and $FF) / 255;
  // the power of the light as a whole (1: as made)
  tx := 0.4 + 0.6 * LightPower;
  r := Round(255 * Clamp01(cr * TintR * tr * CurMat.Bright * tx));
  g := Round(255 * Clamp01(cg * TintG * tg * CurMat.Bright * tx));
  b := Round(255 * Clamp01(cb * TintB * tb * CurMat.Bright * tx));
  a := Round(255 * Clamp01(alpha * CurMat.Opacity));
end;

initialization
  CurMat := DefaultMatParams;
end.
