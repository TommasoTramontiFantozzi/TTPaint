unit TTPdf;

{$mode objfpc}{$H+}

// Vector PDF export of a TTPaint document: one page, paths / text / images,
// written directly (no external tool).

interface

uses
  Classes, SysUtils, Math, Graphics, IntfGraphics, FPImage, zstream, LazUTF8, TTModel, TTFill;

type
  TPdfImageGetter = function(s: TShape): TGraphic of object;

const
  PaperCount = 12;
  PaperNames: array[0..PaperCount - 1] of string = ('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6',
    'B4', 'B5', 'Letter', 'Legal', 'Tabloid');
  // portrait size in millimetres
  PaperMM: array[0..PaperCount - 1, 0..1] of Double = ((841, 1189), (594, 841), (420, 594),
    (297, 420), (210, 297), (148, 210), (105, 148), (250, 353), (176, 250), (215.9, 279.4),
    (215.9, 355.6), (279.4, 431.8));

// page size in PDF points (1/72 inch) for paper index p
procedure PaperPoints(p: Integer; landscape: Boolean; out w, h: Double);

// draws doc on a page of pw x ph points; the drawing is scaled by z points per document unit
// and its top-left corner is put at (mx, my) points from the top-left of the page
procedure ExportPdf(doc: TDoc; const fileName: string; pw, ph, mx, my, z: Double;
  getImage: TPdfImageGetter);

implementation

var
  FS: TFormatSettings;

function Num(v: Double): string;
begin
  Result := FormatFloat('0.####', v, FS);
  if (Result = '-0') or (Result = '') then Result := '0';
end;

procedure PaperPoints(p: Integer; landscape: Boolean; out w, h: Double);
var
  t: Double;
begin
  if (p < 0) or (p >= PaperCount) then p := 4;
  w := PaperMM[p, 0] / 25.4 * 72;
  h := PaperMM[p, 1] / 25.4 * 72;
  if landscape then
  begin
    t := w;
    w := h;
    h := t;
  end;
end;

function ColorOps(c: Integer; stroke: Boolean): string;
begin
  Result := Num((c and $FF) / 255) + ' ' + Num(((c shr 8) and $FF) / 255) + ' ' +
    Num(((c shr 16) and $FF) / 255);
  if stroke then Result := Result + ' RG' else Result := Result + ' rg';
end;

function PdfString(const utf8: string): string;
var
  p, n: PChar;
  len, cp: Integer;
  ch: Byte;
begin
  Result := '(';
  p := PChar(utf8);
  n := p + Length(utf8);
  while p < n do
  begin
    cp := UTF8CodepointToUnicode(p, len);
    if len < 1 then len := 1;
    Inc(p, len);
    if cp < 256 then ch := cp else ch := Ord('?');
    case ch of
      Ord('('), Ord(')'), Ord('\'): Result := Result + '\' + Chr(ch);
      32..39, 42..91, 93..126: Result := Result + Chr(ch);
    else
      Result := Result + '\' + Chr(Ord('0') + (ch shr 6)) + Chr(Ord('0') + ((ch shr 3) and 7)) +
        Chr(Ord('0') + (ch and 7));
    end;
  end;
  Result := Result + ')';
end;

function PathOf(const pl: TPolyline; closeIt: Boolean): string;
var
  j: Integer;
begin
  Result := '';
  if Length(pl.Pts) < 2 then Exit;
  for j := 0 to High(pl.Pts) do
  begin
    Result := Result + Num(pl.Pts[j].x) + ' ' + Num(pl.Pts[j].y);
    if j = 0 then Result := Result + ' m ' else Result := Result + ' l ';
  end;
  if closeIt and pl.Closed then Result := Result + 'h ';
end;

// an image object body: flate-compressed 8-bit samples (extra: more dictionary entries)
function PdfRawImage(const samples: string; w, h: Integer; const cs, extra: string): string;
var
  comp: TMemoryStream;
  z: TCompressionStream;
  data: string;
  n: Integer;
begin
  comp := TMemoryStream.Create;
  try
    z := TCompressionStream.Create(clDefault, comp);
    try
      if samples <> '' then z.WriteBuffer(samples[1], Length(samples));
    finally
      z.Free;
    end;
    n := comp.Size;
    SetLength(data, n);
    comp.Position := 0;
    if n > 0 then comp.ReadBuffer(data[1], n);
  finally
    comp.Free;
  end;
  Result := '<< /Type /XObject /Subtype /Image /Width ' + IntToStr(w) + ' /Height ' + IntToStr(h) +
    ' /ColorSpace /' + cs + ' /BitsPerComponent 8' + extra + ' /Filter /FlateDecode /Length ' + IntToStr(n) +
    ' >>' + LineEnding + 'stream' + LineEnding + data + LineEnding + 'endstream' + LineEnding;
end;

procedure ExportPdf(doc: TDoc; const fileName: string; pw, ph, mx, my, z: Double;
  getImage: TPdfImageGetter);
type
  TImgRec = record
    Obj: Integer;
    Name: string;
  end;
var
  content: string;
  offs: array of Int64;
  ms: TMemoryStream;
  imgs: array of TImgRec;
  imgData: array of string;       // raw object bodies (dictionary + stream) per image
  i, j, k, n, nextLay: Integer;
  s: TShape;
  o, vis: TOutline;
  st: TStyle;
  head: TPtArray;
  ops, caps, joins, dashes: string;
  g: TGraphic;
  bmp: TBitmap;
  img: TLazIntfImage;
  raw: string;
  comp: TMemoryStream;
  cs: TCompressionStream;
  c16: TFPColor;
  pv, po: TPt;
  iw, ih: Double;
  x, y, r, gg, b, a: Integer;
  qg: TQuoteGeom;
  tw: Double;
  hs: TFPtArray;
  hq: Integer;
  sd: TSprayDotArray;
  spk: Integer;
  ordered: TShapeArray;
  gsOps: string;
  trS, trF: Integer;
  useGs: Boolean;
  gsList: array of record SA, FA: Integer; end;
  gx1, gy1, gx2, gy2, gres, glf: Double;
  gw, gh, gcol, gop, gmask: Integer;
  gline: TGradLine;
  rawA: string;

  procedure Put(const t: string);
  begin
    if t <> '' then ms.WriteBuffer(t[1], Length(t));
  end;

  procedure BeginObj(id: Integer);
  begin
    if id >= Length(offs) then SetLength(offs, id + 1);
    offs[id] := ms.Position;
    Put(IntToStr(id) + ' 0 obj' + LineEnding);
  end;

  function DashOf(const d: TStyle): string;
  var
    ww: Double;
  begin
    ww := Max(1, d.Width);
    case d.Dash of
      dsDash: Result := '[' + Num(ww * 4) + ' ' + Num(ww * 2) + '] 0 d ';
      dsDot: Result := '[' + Num(ww) + ' ' + Num(ww * 2) + '] 0 d ';
      dsDashDot: Result := '[' + Num(ww * 4) + ' ' + Num(ww * 2) + ' ' + Num(ww) + ' ' + Num(ww * 2) + '] 0 d ';
    else
      Result := '[] 0 d ';
    end;
  end;

  // name of the graphics state with stroke opacity CA and fill opacity ca (made when first used)
  function GsName(tS, tF: Integer): string;
  var
    q: Integer;
  begin
    for q := 0 to High(gsList) do
      if (gsList[q].SA = 255 - tS) and (gsList[q].FA = 255 - tF) then Exit('GS' + IntToStr(q));
    SetLength(gsList, Length(gsList) + 1);
    gsList[High(gsList)].SA := 255 - tS;
    gsList[High(gsList)].FA := 255 - tF;
    Result := 'GS' + IntToStr(High(gsList));
  end;

begin
  doc.UpdateFillets;
  SetLength(gsList, 0);
  SetLength(imgs, 0);
  SetLength(imgData, 0);
  content := 'q ' + Num(z) + ' 0 0 ' + Num(-z) + ' ' + Num(mx) + ' ' + Num(ph - my) + ' cm' + LineEnding;
  ordered := doc.DrawOrder;
  nextLay := 0;
  for i := 0 to High(ordered) do
  begin
    s := ordered[i];
    // the background of a layer comes under its objects and over the layers below
    k := doc.Layers.IndexOf(doc.LayerOf(s));
    while nextLay <= k do
    begin
      if doc.Layers[nextLay].Visible and not doc.Layers[nextLay].IsFilter and (doc.Layers[nextLay].Bg <> NoColor) then
        content := content + ColorOps(doc.Layers[nextLay].Bg, False) + ' 0 0 ' + Num(doc.Width) + ' ' + Num(doc.Height) + ' re f' + LineEnding;
      Inc(nextLay);
    end;
    if s.IsRef then Continue;
    st := s.Style;
    // transparency (of the shape and of its layer): an ExtGState around the shape
    trS := doc.EffectiveTr(s, False);
    trF := doc.EffectiveTr(s, True);
    if s.GradOn and (st.Fill <> NoColor) and not (s.Kind in [skText, skImage]) then trF := 0;     // the gradient image carries its own opacity
    useGs := ((trS > 0) or (trF > 0)) and (s.Kind <> skImage);
    if useGs then content := content + 'q /' + GsName(trS, trF) + ' gs' + LineEnding;
    if s.Spray then st.Stroke := NoColor;        // only the dots are drawn
    case s.Kind of
      skText:
        begin
          if st.Fill <> NoColor then
          begin
            content := content + 'BT ' + ColorOps(st.Fill, False) + ' /F1 ' + Num(s.FontSize) + ' Tf ' + Num(Cos(s.Rot)) + ' ' + Num(-Sin(s.Rot)) + ' ' +
              Num(-Sin(s.Rot)) + ' ' + Num(-Cos(s.Rot)) + ' ' +
              Num(s.P[0].x + s.FontSize * 0.9 * Sin(s.Rot)) + ' ' + Num(s.P[0].y + s.FontSize * 0.9 * Cos(s.Rot)) +
              ' Tm ' + PdfString(s.Text) +
              ' Tj ET' + LineEnding;
          end;
        end;
      skImage:
        begin
          g := nil;
          if Assigned(getImage) then g := getImage(s);
          if g = nil then Continue;
          // raw RGB, flate-compressed; transparent pixels blend over white
          bmp := TBitmap.Create;
          try
            bmp.Assign(g);
            img := bmp.CreateIntfImage;
            try
              SetLength(raw, img.Width * img.Height * 3);
              k := 1;
              for y := 0 to img.Height - 1 do
                for x := 0 to img.Width - 1 do
                begin
                  c16 := img.Colors[x, y];
                  a := c16.alpha shr 8;
                  r := (c16.red shr 8) * a div 255 + 255 - a;
                  gg := (c16.green shr 8) * a div 255 + 255 - a;
                  b := (c16.blue shr 8) * a div 255 + 255 - a;
                  raw[k] := Chr(r);
                  raw[k + 1] := Chr(gg);
                  raw[k + 2] := Chr(b);
                  Inc(k, 3);
                end;
              comp := TMemoryStream.Create;
              try
                cs := TCompressionStream.Create(clDefault, comp);
                try
                  if raw <> '' then cs.WriteBuffer(raw[1], Length(raw));
                finally
                  cs.Free;
                end;
                SetLength(imgs, Length(imgs) + 1);
                imgs[High(imgs)].Name := 'Im' + IntToStr(Length(imgs));
                SetLength(imgData, Length(imgData) + 1);
                n := comp.Size;
                SetLength(raw, n);
                comp.Position := 0;
                if n > 0 then comp.ReadBuffer(raw[1], n);
                imgData[High(imgData)] := '<< /Type /XObject /Subtype /Image /Width ' + IntToStr(img.Width) +
                  ' /Height ' + IntToStr(img.Height) + ' /ColorSpace /DeviceRGB /BitsPerComponent 8' +
                  ' /Filter /FlateDecode /Length ' + IntToStr(n) + ' >>' + LineEnding + 'stream' + LineEnding +
                  raw + LineEnding + 'endstream' + LineEnding;
              finally
                comp.Free;
              end;
            finally
              img.Free;
            end;
          finally
            bmp.Free;
          end;
          pv := ShapePivot(s);
          po := TurnPt(MakePt(Min(s.P[0].x, s.P[1].x), Max(s.P[0].y, s.P[1].y)), pv, s.Rot);
          iw := Abs(s.P[1].x - s.P[0].x);
          ih := Abs(s.P[1].y - s.P[0].y);
          content := content + 'q ' + Num(iw * Cos(s.Rot)) + ' ' + Num(-iw * Sin(s.Rot)) + ' ' +
            Num(-ih * Sin(s.Rot)) + ' ' + Num(-ih * Cos(s.Rot)) + ' ' +
            Num(po.x) + ' ' + Num(po.y) + ' cm /' +
            imgs[High(imgs)].Name + ' Do Q' + LineEnding;
        end;
    else
      o := ShapeOutline(s);
      // fill
      if (st.Fill <> NoColor) and s.GradOn then
      begin
        // a gradient: an image (colour and opacity per pixel) seen through the outline of the shape
        ops := '';
        for j := 0 to High(o) do
          if Length(o[j].Pts) >= 3 then ops := ops + PathOf(o[j], False) + 'h ';
        gx1 := 1e300; gy1 := 1e300; gx2 := -1e300; gy2 := -1e300;
        for j := 0 to High(o) do
          for k := 0 to High(o[j].Pts) do
          begin
            gx1 := Min(gx1, o[j].Pts[k].x);
            gy1 := Min(gy1, o[j].Pts[k].y);
            gx2 := Max(gx2, o[j].Pts[k].x);
            gy2 := Max(gy2, o[j].Pts[k].y);
          end;
        if (ops <> '') and (gx2 > gx1) and (gy2 > gy1) then
        begin
          gres := Min(3, 700 / Max(gx2 - gx1, gy2 - gy1));
          gw := Max(2, Ceil((gx2 - gx1) * gres));
          gh := Max(2, Ceil((gy2 - gy1) * gres));
          gline := doc.GradientLine(s);
          if doc.LayerOf(s) <> nil then glf := doc.LayerOf(s).Opacity / 255 else glf := 1;
          SetLength(raw, gw * gh * 3);
          SetLength(rawA, gw * gh);
          k := 1;
          for y := 0 to gh - 1 do
            for x := 0 to gw - 1 do
            begin
              GradientMix(s, GradientT(gline, gx1 + (x + 0.5) * (gx2 - gx1) / gw, gy1 + (y + 0.5) * (gy2 - gy1) / gh), gcol, gop);
              raw[(y * gw + x) * 3 + 1] := Chr(gcol and $FF);
              raw[(y * gw + x) * 3 + 2] := Chr((gcol shr 8) and $FF);
              raw[(y * gw + x) * 3 + 3] := Chr((gcol shr 16) and $FF);
              rawA[y * gw + x + 1] := Chr(Round(gop * glf));
            end;
          // the opacity as a soft mask (its own image object, numbered before the picture)
          SetLength(imgs, Length(imgs) + 1);
          imgs[High(imgs)].Name := 'Im' + IntToStr(Length(imgs));
          SetLength(imgData, Length(imgData) + 1);
          imgData[High(imgData)] := PdfRawImage(rawA, gw, gh, 'DeviceGray', '');
          gmask := Length(imgs) - 1;
          SetLength(imgs, Length(imgs) + 1);
          imgs[High(imgs)].Name := 'Im' + IntToStr(Length(imgs));
          SetLength(imgData, Length(imgData) + 1);
          imgData[High(imgData)] := PdfRawImage(raw, gw, gh, 'DeviceRGB', ' /SMask ' + IntToStr(6 + gmask) + ' 0 R');
          content := content + 'q ' + ops + 'W* n ' + Num(gx2 - gx1) + ' 0 0 ' + Num(-(gy2 - gy1)) + ' ' +
            Num(gx1) + ' ' + Num(gy2) + ' cm /' + imgs[High(imgs)].Name + ' Do Q' + LineEnding;
        end;
      end
      else if st.Fill <> NoColor then
      begin
        ops := '';
        for j := 0 to High(o) do
          if Length(o[j].Pts) >= 3 then ops := ops + PathOf(o[j], False) + 'h ';
        // several closed curves (holes): the even-odd rule
        if ops <> '' then
          if Length(o) > 1 then content := content + ColorOps(st.Fill, False) + ' ' + ops + 'f*' + LineEnding
          else content := content + ColorOps(st.Fill, False) + ' ' + ops + 'f' + LineEnding;
      end;
      // stroke (the visible parts: trims, extensions, fillet cuts)
      if st.Stroke <> NoColor then
      begin
        if not doc.VisibleOutline(s, vis) then vis := o;
        case st.Cap of
          lcFlat: caps := '0 J ';
          lcRound: caps := '1 J ';
        else
          caps := '2 J ';
        end;
        case st.Join of
          ljMiter: joins := '0 j ';
          ljRound: joins := '1 j ';
        else
          joins := '2 j ';
        end;
        ops := '';
        for j := 0 to High(vis) do
          ops := ops + PathOf(vis[j], True);
        if ops <> '' then
          content := content + 'q ' + ColorOps(st.Stroke, True) + ' ' + Num(Max(st.Width, 0.1)) + ' w ' +
            caps + joins + DashOf(st) + ops + 'S Q' + LineEnding;
        if (s.Kind = skArrow) and (Length(s.P) >= 2) then
        begin
          head := ArrowHead(s.P[0], s.P[1], st.Width);
          content := content + ColorOps(st.Stroke, False) + ' ' + Num(head[0].x) + ' ' + Num(head[0].y) + ' m ' +
            Num(head[1].x) + ' ' + Num(head[1].y) + ' l ' + Num(head[2].x) + ' ' + Num(head[2].y) + ' l h f' + LineEnding;
        end;
      end;
    end;
    // airbrush: its drops, as round zero-length dashes of their own size; four classes of opacity (a drop is not soft here)
    if s.Spray then
    begin
      sd := SprayDots(s);
      if Length(sd) > 0 then
      begin
        for hq := 0 to 3 do
        begin
          content := content + 'q /' + GsName(255 - Round((hq + 0.5) / 4 * (255 - trS)), 0) + ' gs ' + ColorOps(s.Style.Stroke, True) +
            ' 1 J [] 0 d' + LineEnding;
          for spk := 0 to High(sd) do
            if Min(3, Trunc(sd[spk].A * 4)) = hq then
              content := content + Num(Max(sd[spk].R * 1.6, 0.1)) + ' w ' + Num(sd[spk].X) + ' ' + Num(sd[spk].Y) + ' m ' +
                Num(sd[spk].X) + ' ' + Num(sd[spk].Y) + ' l S' + LineEnding;
          content := content + 'Q' + LineEnding;
        end;
      end;
    end;
    // hatching of a fill made by the paint bucket (lines clipped to the area; a dot is a point)
    if s.HatchPat > 0 then
    begin
      hs := BucketHatch(s);
      if Length(hs) >= 2 then
      begin
        content := content + 'q ' + ColorOps(s.HatchColor, True) + ' ' + Num(Max(s.HatchW, 0.1)) + ' w ';
        if s.HatchPat = 7 then content := content + '1 J ' else content := content + '0 J ';
        content := content + '[] 0 d' + LineEnding;
        hq := 0;
        while hq + 1 < Length(hs) do
        begin
          content := content + Num(hs[hq].x) + ' ' + Num(hs[hq].y) + ' m ' +
            Num(hs[hq + 1].x) + ' ' + Num(hs[hq + 1].y) + ' l S' + LineEnding;
          Inc(hq, 2);
        end;
        content := content + 'Q' + LineEnding;
      end;
    end;
    if useGs then content := content + 'Q' + LineEnding;
  end;
  // layers above the last object that have a background
  while nextLay < doc.Layers.Count do
  begin
    if doc.Layers[nextLay].Visible and not doc.Layers[nextLay].IsFilter and (doc.Layers[nextLay].Bg <> NoColor) then
      content := content + ColorOps(doc.Layers[nextLay].Bg, False) + ' 0 0 ' + Num(doc.Width) + ' ' + Num(doc.Height) + ' re f' + LineEnding;
    Inc(nextLay);
  end;
  // quotes (dimensions) that are not switched off
  for i := 0 to doc.Cons.Count - 1 do
  begin
    if not doc.Cons[i].IsQuote or doc.Cons[i].NoPrint then Continue;
    if not doc.QuoteGeometry(doc.Cons[i], 1, qg) then Continue;
    content := content + 'q 0 0.43 0.63 RG 0 0.43 0.63 rg 1 w [] 0 d' + LineEnding;
    for j := 0 to High(qg.Segs) do
    begin
      if qg.Segs[j].Dotted then ops := '[1 2] 0 d ' else ops := '[] 0 d ';
      content := content + ops + Num(qg.Segs[j].A.x) + ' ' + Num(qg.Segs[j].A.y) + ' m ' +
        Num(qg.Segs[j].B.x) + ' ' + Num(qg.Segs[j].B.y) + ' l S' + LineEnding;
    end;
    if Length(qg.Arc) > 1 then
    begin
      ops := '[] 0 d ' + Num(qg.Arc[0].x) + ' ' + Num(qg.Arc[0].y) + ' m ';
      for j := 1 to High(qg.Arc) do ops := ops + Num(qg.Arc[j].x) + ' ' + Num(qg.Arc[j].y) + ' l ';
      content := content + ops + 'S' + LineEnding;
    end;
    for j := 0 to High(qg.Heads) do
      content := content + Num(qg.Heads[j][0].x) + ' ' + Num(qg.Heads[j][0].y) + ' m ' +
        Num(qg.Heads[j][1].x) + ' ' + Num(qg.Heads[j][1].y) + ' l ' + Num(qg.Heads[j][2].x) + ' ' +
        Num(qg.Heads[j][2].y) + ' l h f' + LineEnding;
    // label: white box under the text (Helvetica, about 0.5 em per character)
    tw := 0.55 * 12 * UTF8Length(qg.Text);
    content := content + '1 g ' + Num(qg.TextPos.x - tw / 2 - 2) + ' ' + Num(qg.TextPos.y - 8) + ' ' +
      Num(tw + 4) + ' 16 re f 0 0.43 0.63 rg' + LineEnding +
      'BT /F1 12 Tf 1 0 0 -1 ' + Num(qg.TextPos.x - tw / 2) + ' ' + Num(qg.TextPos.y + 4) + ' Tm ' +
      PdfString(qg.Text) + ' Tj ET Q' + LineEnding;
  end;
  content := content + 'Q' + LineEnding;

  ms := TMemoryStream.Create;
  try
    SetLength(offs, 6 + Length(imgs) + Length(gsList));
    Put('%PDF-1.4' + LineEnding);
    BeginObj(1);
    Put('<< /Type /Catalog /Pages 2 0 R >>' + LineEnding + 'endobj' + LineEnding);
    BeginObj(2);
    Put('<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LineEnding + 'endobj' + LineEnding);
    BeginObj(3);
    ops := '';
    for i := 0 to High(imgs) do
      ops := ops + '/' + imgs[i].Name + ' ' + IntToStr(6 + i) + ' 0 R ';
    gsOps := '';
    for i := 0 to High(gsList) do
      gsOps := gsOps + '/GS' + IntToStr(i) + ' ' + IntToStr(6 + Length(imgs) + i) + ' 0 R ';
    Put('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + Num(pw) + ' ' + Num(ph) + ']' +
      ' /Resources << /Font << /F1 5 0 R >> /XObject << ' + ops + '>> /ExtGState << ' + gsOps + '>> >> /Contents 4 0 R >>' +
      LineEnding + 'endobj' + LineEnding);
    BeginObj(4);
    Put('<< /Length ' + IntToStr(Length(content)) + ' >>' + LineEnding + 'stream' + LineEnding + content +
      'endstream' + LineEnding + 'endobj' + LineEnding);
    BeginObj(5);
    Put('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>' + LineEnding +
      'endobj' + LineEnding);
    for i := 0 to High(imgs) do
    begin
      BeginObj(6 + i);
      Put(imgData[i] + 'endobj' + LineEnding);
    end;
    for i := 0 to High(gsList) do
    begin
      BeginObj(6 + Length(imgs) + i);
      Put('<< /Type /ExtGState /CA ' + Num(gsList[i].SA / 255) + ' /ca ' + Num(gsList[i].FA / 255) + ' >>' + LineEnding + 'endobj' + LineEnding);
    end;
    n := ms.Position;
    Put('xref' + LineEnding + '0 ' + IntToStr(Length(offs)) + LineEnding);
    Put('0000000000 65535 f ' + LineEnding);
    for i := 1 to High(offs) do
      Put(Format('%.10d 00000 n ', [offs[i]]) + LineEnding);
    Put('trailer << /Size ' + IntToStr(Length(offs)) + ' /Root 1 0 R >>' + LineEnding +
      'startxref' + LineEnding + IntToStr(n) + LineEnding + '%%EOF' + LineEnding);
    ms.SaveToFile(fileName);
  finally
    ms.Free;
  end;
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

end.
