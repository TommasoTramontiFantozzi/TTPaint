unit TTVec;

{$mode objfpc}{$H+}

// Recognition of simple geometric figures in a raster picture: a flood fill of the
// uniform colour area under a point, then a rectangle / ellipse / straight line fit
// that is accepted only if it matches the area closely.

interface

uses
  SysUtils, Math;

type
  TVecKind = (vkNone, vkRect, vkEllipse, vkLine, vkPolygon, vkPolyline, vkLoop, vkArc);

  TVecPt = record
    x, y: Double;
  end;

  TVecResult = record
    Kind: TVecKind;
    Msg: string;           // vkNone: why nothing was recognised
    CX, CY: Double;        // centre, in pixels of the picture
    A, B: Double;          // half extents along Theta / across it (line: A = half length, B = half width)
    Theta: Double;         // direction of the A axis (radians, 0..pi)
    Color: Cardinal;       // $00BBGGRR of the area
    Ring: Boolean;         // only an outline of width Thick was found (A, B = middle of the stroke)
    Thick: Double;
    Area: Integer;
    Partial: Boolean;      // only the straight part (or the arc) of a bigger figure was recognised
    A1, A2: Double;        // vkArc: start / end angle seen from the centre (CX, CY; radius A), increasing
    Pts: array of TVecPt;  // vkPolygon / vkPolyline / vkLoop: vertices in picture pixels
  end;

// pix: packed ARGB (alpha in the high byte), w * h entries, row by row
function Vectorize(w, h: Integer; const pix: array of LongWord; sx, sy, tol: Integer): TVecResult;

implementation

function SameColor(a, b: LongWord; tol: Integer): Boolean;
var
  aa, ab: Integer;
begin
  aa := a shr 24;
  ab := b shr 24;
  if (aa < 128) or (ab < 128) then Exit((aa < 128) and (ab < 128));
  Result := Abs(Integer((a shr 16) and $FF) - Integer((b shr 16) and $FF)) +
            Abs(Integer((a shr 8) and $FF) - Integer((b shr 8) and $FF)) +
            Abs(Integer(a and $FF) - Integer(b and $FF)) <= tol;
end;

function Fail(const msg: string): TVecResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := vkNone;
  Result.Msg := msg;
end;

type
  TPtList = array of TVecPt;

// Douglas-Peucker on pts[a..b] (open); marks the points to keep
procedure DPRange(const pts: TPtList; a, b: Integer; eps: Double; var keep: array of Boolean);
var
  i, im: Integer;
  dmax, d, dx, dy, l2, t, px, py: Double;
begin
  if b <= a + 1 then Exit;
  dx := pts[b].x - pts[a].x;
  dy := pts[b].y - pts[a].y;
  l2 := dx * dx + dy * dy;
  dmax := -1;
  im := a;
  for i := a + 1 to b - 1 do
  begin
    if l2 < 1e-12 then d := Hypot(pts[i].x - pts[a].x, pts[i].y - pts[a].y)
    else
    begin
      t := ((pts[i].x - pts[a].x) * dx + (pts[i].y - pts[a].y) * dy) / l2;
      t := Max(0, Min(1, t));
      px := pts[a].x + t * dx;
      py := pts[a].y + t * dy;
      d := Hypot(pts[i].x - px, pts[i].y - py);
    end;
    if d > dmax then
    begin
      dmax := d;
      im := i;
    end;
  end;
  if dmax > eps then
  begin
    keep[im] := True;
    DPRange(pts, a, im, eps, keep);
    DPRange(pts, im, b, eps, keep);
  end;
end;

function SimplifyOpen(const pts: TPtList; eps: Double): TPtList;
var
  keep: array of Boolean;
  i, n: Integer;
begin
  SetLength(keep, Length(pts));
  FillChar(keep[0], Length(keep) * SizeOf(Boolean), 0);
  keep[0] := True;
  keep[High(pts)] := True;
  DPRange(pts, 0, High(pts), eps, keep);
  SetLength(Result, Length(pts));
  n := 0;
  for i := 0 to High(pts) do
    if keep[i] then
    begin
      Result[n] := pts[i];
      Inc(n);
    end;
  SetLength(Result, n);
end;

// closed polygon: split at the point farthest from point 0
function SimplifyClosed(const pts: TPtList; eps: Double): TPtList;
var
  i, far, n: Integer;
  d, dm: Double;
  keep: array of Boolean;
  ext: TPtList;
begin
  dm := -1;
  far := 0;
  for i := 1 to High(pts) do
  begin
    d := Hypot(pts[i].x - pts[0].x, pts[i].y - pts[0].y);
    if d > dm then
    begin
      dm := d;
      far := i;
    end;
  end;
  SetLength(ext, Length(pts) + 1);
  for i := 0 to High(pts) do ext[i] := pts[i];
  ext[High(ext)] := pts[0];
  SetLength(keep, Length(ext));
  FillChar(keep[0], Length(keep) * SizeOf(Boolean), 0);
  keep[0] := True;
  keep[High(ext)] := True;
  keep[far] := True;
  DPRange(ext, 0, far, eps, keep);
  DPRange(ext, far, High(ext), eps, keep);
  SetLength(Result, Length(ext));
  n := 0;
  for i := 0 to High(ext) - 1 do
    if keep[i] then
    begin
      Result[n] := ext[i];
      Inc(n);
    end;
  SetLength(Result, n);
end;

// drops vertices that lie on the line through their neighbours (closed polygon)
procedure DropCollinear(var pts: TPtList; eps: Double; closed: Boolean);
var
  i, k, n, lo, hi: Integer;
  changed: Boolean;
  a, b, c: TVecPt;
  dx, dy, l, d: Double;
begin
  repeat
    changed := False;
    n := Length(pts);
    if n < 4 then Exit;
    if closed then begin lo := 0; hi := n - 1; end else begin lo := 1; hi := n - 2; end;
    for i := lo to hi do
    begin
      a := pts[(i + n - 1) mod n];
      b := pts[i];
      c := pts[(i + 1) mod n];
      dx := c.x - a.x;
      dy := c.y - a.y;
      l := Hypot(dx, dy);
      if l < 1e-9 then d := 0 else d := Abs((b.x - a.x) * dy - (b.y - a.y) * dx) / l;
      if d <= eps then
      begin
        for k := i to n - 2 do pts[k] := pts[k + 1];
        SetLength(pts, n - 1);
        changed := True;
        Break;
      end;
    end;
  until not changed;
end;

// two vertices closer than dmax come from one rounded corner: replace them by the
// intersection of the sides around them
procedure MergeClose(var pts: TPtList; dmax: Double; closed: Boolean);
var
  i, k, n, ip, inx, lo, hi: Integer;
  changed: Boolean;
  p0, a, b, p3, m: TVecPt;
  d1x, d1y, d2x, d2y, den, t: Double;
begin
  repeat
    changed := False;
    n := Length(pts);
    if n < 4 then Exit;
    if closed then begin lo := 0; hi := n - 1; end else begin lo := 1; hi := n - 3; end;
    for i := lo to hi do
    begin
      ip := (i + n - 1) mod n;
      inx := (i + 2) mod n;
      p0 := pts[ip];
      a := pts[i];
      b := pts[(i + 1) mod n];
      p3 := pts[inx];
      if Hypot(b.x - a.x, b.y - a.y) > dmax then Continue;
      m.x := (a.x + b.x) / 2;
      m.y := (a.y + b.y) / 2;
      d1x := a.x - p0.x;
      d1y := a.y - p0.y;
      d2x := p3.x - b.x;
      d2y := p3.y - b.y;
      den := d1x * d2y - d1y * d2x;
      if Abs(den) > 1e-6 then
      begin
        t := ((b.x - p0.x) * d2y - (b.y - p0.y) * d2x) / den;
        if (Hypot(p0.x + t * d1x - m.x, p0.y + t * d1y - m.y) <= 3 * dmax) then
        begin
          m.x := p0.x + t * d1x;
          m.y := p0.y + t * d1y;
        end;
      end;
      pts[i] := m;
      for k := (i + 1) mod n to n - 2 do pts[k] := pts[k + 1];
      SetLength(pts, n - 1);
      changed := True;
      Break;
    end;
  until not changed;
end;

// Zhang-Suen thinning of a 0/1 mask (the border of the array must be 0)
procedure Thin(var m: array of Byte; bw, bh: Integer);
var
  del: array of Integer;
  nd, step, x, y, k, bcount, acount: Integer;
  p: array[0..8] of Integer;
  changed: Boolean;
begin
  SetLength(del, bw * bh);
  repeat
    changed := False;
    for step := 0 to 1 do
    begin
      nd := 0;
      for y := 1 to bh - 2 do
        for x := 1 to bw - 2 do
        begin
          if m[y * bw + x] = 0 then Continue;
          p[0] := m[(y - 1) * bw + x];
          p[1] := m[(y - 1) * bw + x + 1];
          p[2] := m[y * bw + x + 1];
          p[3] := m[(y + 1) * bw + x + 1];
          p[4] := m[(y + 1) * bw + x];
          p[5] := m[(y + 1) * bw + x - 1];
          p[6] := m[y * bw + x - 1];
          p[7] := m[(y - 1) * bw + x - 1];
          bcount := 0;
          for k := 0 to 7 do bcount := bcount + p[k];
          if (bcount < 2) or (bcount > 6) then Continue;
          acount := 0;
          for k := 0 to 7 do
            if (p[k] = 0) and (p[(k + 1) mod 8] = 1) then Inc(acount);
          if acount <> 1 then Continue;
          if step = 0 then
          begin
            if (p[0] * p[2] * p[4] <> 0) or (p[2] * p[4] * p[6] <> 0) then Continue;
          end
          else
          begin
            if (p[0] * p[2] * p[6] <> 0) or (p[0] * p[4] * p[6] <> 0) then Continue;
          end;
          del[nd] := y * bw + x;
          Inc(nd);
        end;
      for k := 0 to nd - 1 do m[del[k]] := 0;
      if nd > 0 then changed := True;
    end;
  until not changed;
end;

// IoU between the region and the stroke of the polyline (width t); closed adds the last side
function StrokeIoU(const reg: array of Byte; bw, bh, ox, oy: Integer; const pts: TPtList;
  closed: Boolean; t: Double): Double;
var
  m: array of Byte;
  i, ns, x, y, xa, xb, ya, yb: Integer;
  a, b: TVecPt;
  dx, dy, l2, tt, px, py, r: Double;
  inter, uni: Integer;
begin
  SetLength(m, bw * bh);
  FillChar(m[0], bw * bh, 0);
  r := t / 2;
  ns := Length(pts) - 1;
  if closed then ns := Length(pts);
  for i := 0 to ns - 1 do
  begin
    a := pts[i];
    b := pts[(i + 1) mod Length(pts)];
    xa := Max(0, Floor(Min(a.x, b.x) - r) - ox - 1);
    xb := Min(bw - 1, Ceil(Max(a.x, b.x) + r) - ox + 1);
    ya := Max(0, Floor(Min(a.y, b.y) - r) - oy - 1);
    yb := Min(bh - 1, Ceil(Max(a.y, b.y) + r) - oy + 1);
    dx := b.x - a.x;
    dy := b.y - a.y;
    l2 := dx * dx + dy * dy;
    for y := ya to yb do
      for x := xa to xb do
      begin
        if l2 < 1e-12 then tt := 0
        else tt := Max(0, Min(1, ((x + ox + 0.5 - a.x) * dx + (y + oy + 0.5 - a.y) * dy) / l2));
        px := a.x + tt * dx;
        py := a.y + tt * dy;
        if Hypot(x + ox + 0.5 - px, y + oy + 0.5 - py) <= r then m[y * bw + x] := 1;
      end;
  end;
  inter := 0;
  uni := 0;
  for i := 0 to bw * bh - 1 do
  begin
    if (m[i] <> 0) and (reg[i] <> 0) then Inc(inter);
    if (m[i] <> 0) or (reg[i] <> 0) then Inc(uni);
  end;
  if uni = 0 then Result := 0 else Result := inter / uni;
end;

function PolyIoU(const reg: array of Byte; bw, bh, ox, oy: Integer; const pts: TPtList): Double;
var
  x, y, i, j, inter, uni: Integer;
  cx, cy: Double;
  inside: Boolean;
begin
  inter := 0;
  uni := 0;
  for y := 0 to bh - 1 do
    for x := 0 to bw - 1 do
    begin
      cx := x + ox + 0.5;
      cy := y + oy + 0.5;
      inside := False;
      j := High(pts);
      for i := 0 to High(pts) do
      begin
        if ((pts[i].y > cy) <> (pts[j].y > cy)) and
           (cx < (pts[j].x - pts[i].x) * (cy - pts[i].y) / (pts[j].y - pts[i].y) + pts[i].x) then
          inside := not inside;
        j := i;
      end;
      if inside and (reg[y * bw + x] <> 0) then Inc(inter);
      if inside or (reg[y * bw + x] <> 0) then Inc(uni);
    end;
  if uni = 0 then Result := 0 else Result := inter / uni;
end;

// outline of the region along the pixel edges (region on the right-hand side)
function Crack(const reg: array of Byte; bw, bh: Integer): TPtList;
var
  sx, sy, cx, cy, d, nd, steps, n: Integer;
  found: Boolean;
  la, ra: Boolean;

  function InReg(x, y: Integer): Boolean;
  begin
    Result := (x >= 0) and (y >= 0) and (x < bw) and (y < bh) and (reg[y * bw + x] <> 0);
  end;

begin
  SetLength(Result, 0);
  found := False;
  sx := 0; sy := 0;
  for sy := 0 to bh - 1 do
  begin
    for sx := 0 to bw - 1 do
      if reg[sy * bw + sx] <> 0 then
      begin
        found := True;
        Break;
      end;
    if found then Break;
  end;
  if not found then Exit;
  cx := sx;
  cy := sy;
  d := 0;                       // 0 E, 1 S, 2 W, 3 N
  n := 0;
  steps := 0;
  repeat
    // move one pixel along d
    case d of
      0: Inc(cx);
      1: Inc(cy);
      2: Dec(cx);
      3: Dec(cy);
    end;
    Inc(steps);
    case d of
      0: begin la := InReg(cx, cy - 1); ra := InReg(cx, cy); end;
      1: begin la := InReg(cx, cy); ra := InReg(cx - 1, cy); end;
      2: begin la := InReg(cx - 1, cy); ra := InReg(cx - 1, cy - 1); end;
    else
      begin la := InReg(cx - 1, cy - 1); ra := InReg(cx, cy - 1); end;
    end;
    if la then nd := (d + 3) mod 4
    else if ra then nd := d
    else nd := (d + 1) mod 4;
    if nd <> d then
    begin
      SetLength(Result, n + 1);
      Result[n].x := cx;
      Result[n].y := cy;
      Inc(n);
    end;
    d := nd;
  until ((cx = sx) and (cy = sy) and (d = 0)) or (steps > 4 * bw * bh);
  if steps > 4 * bw * bh then SetLength(Result, 0);
end;

// Outline / stroke recognition for what is not a rectangle, ellipse or line.
// ox, oy: offset of the local arrays in picture pixels.
function TryPath(const reg: array of Byte; bw, bh, ox, oy, n: Integer; ring: Boolean;
  var res: TVecResult): Boolean;
var
  sk: array of Byte;
  i, j, k, x, y, lsk, e, nx, ny, far1, far2, a: Integer;
  t: Double;
  dist, par: array of Integer;
  q: array of Integer;
  qh, qt, cur, dd: Integer;
  pts, simp, tmp: TPtList;
  pathIdx: array of Integer;
  onPath, dil: array of Byte;
  closed: Boolean;
  iou, ex, ey, l: Double;
  rad: Integer;
  startPix: Integer;

  function Neighbors(p: Integer; out nb: array of Integer): Integer;
  var
    px, py, dx, dy: Integer;
  begin
    Result := 0;
    px := p mod bw;
    py := p div bw;
    for dy := -1 to 1 do
      for dx := -1 to 1 do
      begin
        if (dx = 0) and (dy = 0) then Continue;
        if sk[(py + dy) * bw + px + dx] <> 0 then
        begin
          nb[Result] := (py + dy) * bw + px + dx;
          Inc(Result);
        end;
      end;
  end;

  procedure Bfs(src: Integer);
  var
    nbs: array[0..7] of Integer;
    cn, m2, p2: Integer;
  begin
    for p2 := 0 to bw * bh - 1 do dist[p2] := -1;
    dist[src] := 0;
    par[src] := -1;
    qh := 0;
    qt := 0;
    q[qt] := src;
    Inc(qt);
    while qh < qt do
    begin
      cur := q[qh];
      Inc(qh);
      cn := Neighbors(cur, nbs);
      for m2 := 0 to cn - 1 do
        if dist[nbs[m2]] < 0 then
        begin
          dist[nbs[m2]] := dist[cur] + 1;
          par[nbs[m2]] := cur;
          q[qt] := nbs[m2];
          Inc(qt);
        end;
    end;
  end;

  function PtOf(p: Integer): TVecPt;
  begin
    Result.x := (p mod bw) + ox + 0.5;
    Result.y := (p div bw) + oy + 0.5;
  end;

var
  nbs2: array[0..7] of Integer;
  cn2, best: Integer;
  visited: array of Byte;
  cnt: Integer;
begin
  Result := False;
  SetLength(sk, bw * bh);
  Move(reg[0], sk[0], bw * bh);
  Thin(sk, bw, bh);
  lsk := 0;
  startPix := -1;
  for i := 0 to bw * bh - 1 do
    if sk[i] <> 0 then
    begin
      Inc(lsk);
      if startPix < 0 then startPix := i;
    end;
  if lsk < 2 then
  begin
    res.Msg := 'The area is not clearly a recognisable figure.';
    Exit;
  end;
  t := n / lsk;
  if (t <= 16) and (lsk >= 4 * t) then
  begin
    // thin stroke: follow the skeleton
    SetLength(dist, bw * bh);
    SetLength(par, bw * bh);
    SetLength(q, bw * bh);
    e := 0;
    for i := 0 to bw * bh - 1 do
      if (sk[i] <> 0) and (Neighbors(i, nbs2) = 1) then Inc(e);
    SetLength(onPath, bw * bh);
    FillChar(onPath[0], bw * bh, 0);
    closed := False;
    if e = 0 then
    begin
      // closed outline: walk around it
      closed := True;
      SetLength(visited, bw * bh);
      FillChar(visited[0], bw * bh, 0);
      cur := startPix;
      visited[cur] := 1;
      SetLength(pathIdx, 1);
      pathIdx[0] := cur;
      repeat
        cn2 := Neighbors(cur, nbs2);
        best := -1;
        for j := 0 to cn2 - 1 do
          if visited[nbs2[j]] = 0 then
          begin
            // prefer a side neighbour (4-connected) to a diagonal one
            if (best < 0) or ((Abs(nbs2[j] - cur) = 1) or (Abs(nbs2[j] - cur) = bw)) then
              if (best < 0) or (Abs(best - cur) <> 1) and (Abs(best - cur) <> bw) then best := nbs2[j];
          end;
        if best >= 0 then
        begin
          cur := best;
          visited[cur] := 1;
          SetLength(pathIdx, Length(pathIdx) + 1);
          pathIdx[High(pathIdx)] := cur;
        end;
      until best < 0;
    end
    else
    begin
      Bfs(startPix);
      far1 := startPix;
      for i := 0 to bw * bh - 1 do
        if dist[i] > dist[far1] then far1 := i;
      Bfs(far1);
      far2 := far1;
      for i := 0 to bw * bh - 1 do
        if dist[i] > dist[far2] then far2 := i;
      cnt := 0;
      cur := far2;
      while cur >= 0 do
      begin
        Inc(cnt);
        cur := par[cur];
      end;
      SetLength(pathIdx, cnt);
      cur := far2;
      for i := 0 to cnt - 1 do
      begin
        pathIdx[i] := cur;
        cur := par[cur];
      end;
    end;
    if Length(pathIdx) < 2 then
    begin
      res.Msg := 'The stroke is too short to be recognised.';
      Exit;
    end;
    // every skeleton pixel must lie close to the path, otherwise the stroke branches
    for i := 0 to High(pathIdx) do onPath[pathIdx[i]] := 1;
    rad := Max(3, Ceil(t) + 1);
    SetLength(dil, bw * bh);
    Move(onPath[0], dil[0], bw * bh);
    for k := 1 to rad do
    begin
      SetLength(tmp, 0);
      for y := 1 to bh - 2 do
        for x := 1 to bw - 2 do
          if (dil[y * bw + x] = 0) and
             ((dil[y * bw + x - 1] <> 0) or (dil[y * bw + x + 1] <> 0) or
              (dil[(y - 1) * bw + x] <> 0) or (dil[(y + 1) * bw + x] <> 0)) then
            onPath[y * bw + x] := 2;
      for i := 0 to bw * bh - 1 do
        if onPath[i] = 2 then
        begin
          dil[i] := 1;
          onPath[i] := 0;
        end;
    end;
    for i := 0 to bw * bh - 1 do
      if (sk[i] <> 0) and (dil[i] = 0) then
      begin
        res.Msg := 'The stroke branches or crosses itself: only single strokes are recognised.';
        Exit;
      end;
    SetLength(pts, Length(pathIdx));
    for i := 0 to High(pathIdx) do pts[i] := PtOf(pathIdx[i]);
    if closed then
    begin
      simp := SimplifyClosed(pts, 1.0);
      l := 0;
      for i := 0 to High(simp) do
        l := l + Hypot(simp[(i + 1) mod Length(simp)].x - simp[i].x, simp[(i + 1) mod Length(simp)].y - simp[i].y);
      t := n / Max(l, 1);
      MergeClose(simp, Max(3, 2 * t), True);
      DropCollinear(simp, 1.0, True);
      if Length(simp) < 3 then
      begin
        res.Msg := 'The outline is too small to be recognised.';
        Exit;
      end;
    end
    else
    begin
      simp := SimplifyOpen(pts, 1.0);
      l := 0;
      for i := 0 to High(simp) - 1 do l := l + Hypot(simp[i + 1].x - simp[i].x, simp[i + 1].y - simp[i].y);
      t := (-l + Sqrt(l * l + 4 * n)) / 2;
      MergeClose(simp, Max(3, 2 * t), False);
      DropCollinear(simp, 1.0, False);
      // end hooks of the skeleton: a first / last side shorter than the stroke is dropped
      while (Length(simp) > 2) and
            (Hypot(simp[1].x - simp[0].x, simp[1].y - simp[0].y) < 2 * t) do
      begin
        for k := 0 to High(simp) - 1 do simp[k] := simp[k + 1];
        SetLength(simp, Length(simp) - 1);
      end;
      while (Length(simp) > 2) and
            (Hypot(simp[High(simp)].x - simp[High(simp) - 1].x, simp[High(simp)].y - simp[High(simp) - 1].y) < 2 * t) do
        SetLength(simp, Length(simp) - 1);
      // thinning shortens the stroke ends by about half its width
      l := 0;
      for i := 0 to High(simp) - 1 do l := l + Hypot(simp[i + 1].x - simp[i].x, simp[i + 1].y - simp[i].y);
      t := (-l + Sqrt(l * l + 4 * n)) / 2;
      l := Max(0, t / 2 - 0.5);
      a := High(simp);
      ex := simp[0].x - simp[1].x;
      ey := simp[0].y - simp[1].y;
      if Hypot(ex, ey) > 1e-9 then
      begin
        simp[0].x := simp[0].x + ex / Hypot(ex, ey) * l;
        simp[0].y := simp[0].y + ey / Hypot(ex, ey) * l;
      end;
      ex := simp[a].x - simp[a - 1].x;
      ey := simp[a].y - simp[a - 1].y;
      if Hypot(ex, ey) > 1e-9 then
      begin
        simp[a].x := simp[a].x + ex / Hypot(ex, ey) * l;
        simp[a].y := simp[a].y + ey / Hypot(ex, ey) * l;
      end;
    end;
    if Length(simp) > 200 then
    begin
      res.Msg := 'The stroke is too complex (' + IntToStr(Length(simp)) + ' segments).';
      Exit;
    end;
    // width from the true length of the path (diagonal pixels are longer)
    if closed then
    begin
      l := 0;
      for i := 0 to High(simp) - 1 do l := l + Hypot(simp[i + 1].x - simp[i].x, simp[i + 1].y - simp[i].y);
      l := l + Hypot(simp[0].x - simp[High(simp)].x, simp[0].y - simp[High(simp)].y);
      t := n / Max(l, 1);
    end;
    iou := StrokeIoU(reg, bw, bh, ox, oy, simp, closed, t);
    if iou < 0.80 then
    begin
      res.Msg := 'The stroke is not clearly a polyline (fit ' + FormatFloat('0.00', iou) + ').';
      Exit;
    end;
    res.Pts := simp;
    res.Thick := t;
    if closed then res.Kind := vkLoop else res.Kind := vkPolyline;
    Result := True;
    Exit;
  end;
  if ring then
  begin
    res.Msg := 'The outline is too thick to be recognised.';
    Exit;
  end;
  // solid area: polygon along the pixel edges
  pts := Crack(reg, bw, bh);
  if Length(pts) < 4 then
  begin
    res.Msg := 'The area is not clearly a recognisable figure.';
    Exit;
  end;
  for i := 0 to High(pts) do
  begin
    pts[i].x := pts[i].x + ox;
    pts[i].y := pts[i].y + oy;
  end;
  simp := SimplifyClosed(pts, 1.2);
  MergeClose(simp, 3.0, True);
  DropCollinear(simp, 1.2, True);
  if (Length(simp) < 3) or (Length(simp) > 120) then
  begin
    res.Msg := 'The outline is too complex (' + IntToStr(Length(simp)) + ' vertices).';
    Exit;
  end;
  iou := PolyIoU(reg, bw, bh, ox, oy, simp);
  if iou < 0.96 then
  begin
    res.Msg := 'The area is not clearly a rectangle, an ellipse, a polygon or a straight line (fit ' +
      FormatFloat('0.00', iou) + ').';
    Exit;
  end;
  res.Pts := simp;
  res.Kind := vkPolygon;
  Result := True;
end;

// The area under the click is part of a bigger figure that is not simple (a line that goes on into a
// drawing, a side of a plan...): at least the straight stroke through the click is recognised.  The
// direction is the one along which the area goes on longest from the click; the stroke ends where the
// area gets much wider (a junction) or stops.
function TryLocalLine(w, h: Integer; const mask: array of Byte; sx, sy, n: Integer; seed: LongWord;
  var R: TVecResult): Boolean;
const
  MaxW = 60;
var
  a, bestA, bestRun, th, c, s, run: Double;
  w0, k, bad, cnt: Integer;
  px, py, ux, uy, nx, ny: Double;
  tEnd: array[0..1] of Double;
  sgn, side: Integer;
  t, wsum, wd, wmed: Double;
  m0x, m0y, sxx, syy, sxy, mx, my, dx, dy: Double;
  np: Integer;
  lo, hi: Double;
  widths: array of Double;
  nw, i: Integer;

  function Inside(x, y: Double): Boolean;
  var
    ix, iy: Integer;
  begin
    ix := Round(x);
    iy := Round(y);
    Result := (ix >= 0) and (iy >= 0) and (ix < w) and (iy < h) and (mask[iy * w + ix] <> 0);
  end;

  // how far the area goes from (x0, y0) along (dx, dy)
  function Reach(x0, y0, dx, dy: Double; limit: Double): Double;
  var
    q: Double;
  begin
    q := 0;
    while (q < limit) and Inside(x0 + dx * (q + 0.5), y0 + dy * (q + 0.5)) do q := q + 0.5;
    Result := q;
  end;

  // the width of the area across the direction (ux, uy) at (x0, y0); the middle of it goes to (mxx, myy)
  function Across(x0, y0, dx, dy: Double; out mxx, myy: Double): Double;
  var
    p1, p2: Double;
  begin
    mxx := x0;
    myy := y0;
    Result := 0;
    if not Inside(x0, y0) then Exit;
    p1 := Reach(x0, y0, -dy, dx, MaxW * 3);
    p2 := Reach(x0, y0, dy, -dx, MaxW * 3);
    Result := p1 + p2 + 1;
    mxx := x0 + (-dy) * (p1 - p2) / 2;
    myy := y0 + dx * (p1 - p2) / 2;
  end;

  function Probe(ang: Double): Double;
  begin
    Result := Reach(sx, sy, Cos(ang), Sin(ang), 4000) + Reach(sx, sy, -Cos(ang), -Sin(ang), 4000);
  end;

begin
  Result := False;
  if not Inside(sx, sy) then Exit;
  // direction: the longest way through the click
  bestA := 0;
  bestRun := -1;
  for k := 0 to 359 do
  begin
    a := k * Pi / 360;
    run := Probe(a);
    if run > bestRun then
    begin
      bestRun := run;
      bestA := a;
    end;
  end;
  for k := -10 to 10 do
  begin
    a := bestA + k * Pi / 3600;
    run := Probe(a);
    if run > bestRun then
    begin
      bestRun := run;
      th := a;
    end;
  end;
  if bestRun < 0 then Exit;
  th := bestA;
  for k := -10 to 10 do
    if Probe(bestA + k * Pi / 3600) >= bestRun - 1e-9 then
    begin
      th := bestA + k * Pi / 3600;
      Break;
    end;
  ux := Cos(th);
  uy := Sin(th);
  // the width of the stroke at the click
  wd := Across(sx, sy, ux, uy, px, py);
  if (wd < 1) or (wd > MaxW) then Exit;
  w0 := Round(wd);
  // follow the stroke from the middle of it; it ends at a junction (much wider) or where it stops
  SetLength(widths, 0);
  for sgn := 0 to 1 do
  begin
    t := 0;
    bad := 0;
    tEnd[sgn] := 0;
    px := sx;
    py := sy;
    // start on the middle line
    wd := Across(sx, sy, ux, uy, px, py);
    m0x := px;
    m0y := py;
    while t < 8000 do
    begin
      t := t + 1;
      if sgn = 0 then
      begin
        px := m0x + ux * t;
        py := m0y + uy * t;
      end
      else
      begin
        px := m0x - ux * t;
        py := m0y - uy * t;
      end;
      wd := Across(px, py, ux, uy, nx, ny);
      if (wd < 1) or (wd > 1.7 * w0 + 2) or (wd < 0.4 * w0) then
      begin
        Inc(bad);
        if bad > 2 then Break;
        Continue;
      end;
      bad := 0;
      tEnd[sgn] := t;
      SetLength(widths, Length(widths) + 1);
      widths[High(widths)] := wd;
    end;
  end;
  // the middle line again, from the pixels of the stroke between the two ends
  if tEnd[0] + tEnd[1] < Max(6, 2 * w0) then Exit;
  Across(sx, sy, ux, uy, m0x, m0y);
  mx := 0; my := 0; np := 0;
  sxx := 0; syy := 0; sxy := 0;
  lo := -tEnd[1];
  hi := tEnd[0];
  t := lo;
  while t <= hi do
  begin
    Across(m0x + ux * t, m0y + uy * t, ux, uy, nx, ny);
    mx := mx + nx;
    my := my + ny;
    Inc(np);
    t := t + 1;
  end;
  if np < 2 then Exit;
  mx := mx / np;
  my := my / np;
  t := lo;
  while t <= hi do
  begin
    Across(m0x + ux * t, m0y + uy * t, ux, uy, nx, ny);
    dx := nx - mx;
    dy := ny - my;
    sxx := sxx + dx * dx;
    syy := syy + dy * dy;
    sxy := sxy + dx * dy;
    t := t + 1;
  end;
  // the direction of the middle line (the fit of the points above)
  th := 0.5 * ArcTan2(2 * sxy, sxx - syy);
  if Abs(Cos(th) * ux + Sin(th) * uy) < 0.9 then th := Arctan2(uy, ux);
  // a stroke that is not straight is not one stroke
  c := Cos(th);
  s := Sin(th);
  // its ends: the extreme middle points along the direction
  lo := 1e30;
  hi := -1e30;
  t := -tEnd[1];
  while t <= tEnd[0] do
  begin
    Across(m0x + ux * t, m0y + uy * t, ux, uy, nx, ny);
    wd := (nx - mx) * c + (ny - my) * s;
    if wd < lo then lo := wd;
    if wd > hi then hi := wd;
    t := t + 1;
  end;
  // width: the middle of the widths found
  nw := Length(widths);
  if nw = 0 then Exit;
  wsum := 0;
  for i := 0 to nw - 1 do wsum := wsum + widths[i];
  wmed := wsum / nw;
  FillChar(R, SizeOf(R), 0);
  R.Kind := vkLine;
  R.Partial := True;
  R.Area := n;
  R.Color := ((seed shr 16) and $FF) or (((seed shr 8) and $FF) shl 8) or ((seed and $FF) shl 16);
  R.CX := mx + c * (lo + hi) / 2 + 0.5;
  R.CY := my + s * (lo + hi) / 2 + 0.5;
  R.A := (hi - lo + 1) / 2;
  R.B := Max(0.5, (wmed - 1) / 2 + 0.5);
  R.Theta := th;
  while R.Theta >= Pi do R.Theta := R.Theta - Pi;
  while R.Theta < 0 do R.Theta := R.Theta + Pi;
  Result := R.A >= Max(3, w0);
end;

// a stroke that bends: follows it from the click, fits a circle to it and takes the arc (or the
// whole circle) along which the area keeps the same colour
function TryLocalCurve(w, h: Integer; const mask: array of Byte; sx, sy, n: Integer; seed: LongWord;
  whole: Boolean; var R: TVecResult): Boolean;
const
  MaxW = 60;
  Step = 2.0;
var
  w0, a, q, th0, wd, wmed, wsum: Double;
  k, sgn, bad, cnt, i, it, nw: Integer;
  dx, dy, ppx, ppy, nx, ny, l: Double;
  lists: array[0..1] of TPtList;
  cn: array[0..1] of Integer;
  pts, ref: TPtList;
  ccx, ccy, rad, res, a0, da, aMinus, aPlus, sweep, ang, span, sag: Double;
  refN: Integer;
  full: Boolean;
  wlist: array of Double;

  function Inside(x, y: Double): Boolean;
  var
    ix, iy: Integer;
  begin
    ix := Round(x);
    iy := Round(y);
    Result := (ix >= 0) and (iy >= 0) and (ix < w) and (iy < h) and (mask[iy * w + ix] <> 0);
  end;

  function Reach(x0, y0, ddx, ddy: Double; limit: Double): Double;
  var
    t: Double;
  begin
    t := 0;
    while (t < limit) and Inside(x0 + ddx * (t + 0.5), y0 + ddy * (t + 0.5)) do t := t + 0.5;
    Result := t;
  end;

  // width of the area across the direction (ddx, ddy) at (x0, y0); the middle goes to (mxx, myy)
  function Across(x0, y0, ddx, ddy: Double; out mxx, myy: Double): Double;
  var
    p1, p2: Double;
  begin
    mxx := x0;
    myy := y0;
    Result := 0;
    if not Inside(x0, y0) then Exit;
    p1 := Reach(x0, y0, -ddy, ddx, MaxW * 3);
    p2 := Reach(x0, y0, ddy, -ddx, MaxW * 3);
    Result := p1 + p2 + 1;
    mxx := x0 + (-ddy) * (p1 - p2) / 2;
    myy := y0 + ddx * (p1 - p2) / 2;
  end;

  function GoodW(v: Double): Boolean;
  begin
    Result := (v >= 1) and (v <= 1.7 * w0 + 2) and (v >= 0.4 * w0);
  end;

  // least squares circle (Kasa) through the points
  function Fit(const p: TPtList; c: Integer; out fx, fy, fr, fres: Double): Boolean;
  var
    j: Integer;
    mx, my, u, v, suu, svv, suv, suuu, svvv, suvv, svuu, det, uc, vc, e: Double;
  begin
    Result := False;
    if c < 5 then Exit;
    mx := 0; my := 0;
    for j := 0 to c - 1 do
    begin
      mx := mx + p[j].x;
      my := my + p[j].y;
    end;
    mx := mx / c;
    my := my / c;
    suu := 0; svv := 0; suv := 0; suuu := 0; svvv := 0; suvv := 0; svuu := 0;
    for j := 0 to c - 1 do
    begin
      u := p[j].x - mx;
      v := p[j].y - my;
      suu := suu + u * u;
      svv := svv + v * v;
      suv := suv + u * v;
      suuu := suuu + u * u * u;
      svvv := svvv + v * v * v;
      suvv := suvv + u * v * v;
      svuu := svuu + v * u * u;
    end;
    det := suu * svv - suv * suv;
    if Abs(det) < 1e-9 * Max(1, suu * svv) then Exit;
    uc := ((suuu + suvv) / 2 * svv - suv * (svvv + svuu) / 2) / det;
    vc := (suu * (svvv + svuu) / 2 - suv * (suuu + suvv) / 2) / det;
    fx := mx + uc;
    fy := my + vc;
    fr := Sqrt(Max(0, uc * uc + vc * vc + (suu + svv) / c));
    fres := 0;
    for j := 0 to c - 1 do
    begin
      e := Abs(Hypot(p[j].x - fx, p[j].y - fy) - fr);
      if e > fres then fres := e;
    end;
    Result := (fr > 2) and (fr < 20000);
  end;

  function OnC(ag: Double): Boolean;
  var
    co, si: Double;
  begin
    co := Cos(ag);
    si := Sin(ag);
    Result := Inside(ccx + rad * co, ccy + rad * si) or Inside(ccx + (rad + 1) * co, ccy + (rad + 1) * si) or
              Inside(ccx + (rad - 1) * co, ccy + (rad - 1) * si);
  end;

  // how far the circle stays on the area from the angle a0, both ways
  procedure Extent;
  var
    gap: Integer;
    ag, last: Double;
  begin
    da := Max(1e-4, Min(0.05, 1 / rad));
    aPlus := 0;
    aMinus := 0;
    ag := a0;
    gap := 0;
    last := 0;
    while ag - a0 < 2 * Pi do
    begin
      ag := ag + da;
      if OnC(ag) then
      begin
        gap := 0;
        last := ag - a0;
      end
      else
      begin
        Inc(gap);
        if gap > 2 then Break;
      end;
    end;
    aPlus := last;
    ag := a0;
    gap := 0;
    last := 0;
    while a0 - ag < 2 * Pi - aPlus do
    begin
      ag := ag - da;
      if OnC(ag) then
      begin
        gap := 0;
        last := a0 - ag;
      end
      else
      begin
        Inc(gap);
        if gap > 2 then Break;
      end;
    end;
    aMinus := last;
  end;

begin
  Result := False;
  if not Inside(sx, sy) then Exit;
  // stroke width: the shortest chord through the click, across it
  w0 := 1e30;
  th0 := 0;
  for k := 0 to 179 do
  begin
    a := k * Pi / 180;
    q := Reach(sx, sy, Cos(a), Sin(a), MaxW * 3) + Reach(sx, sy, -Cos(a), -Sin(a), MaxW * 3) + 1;
    if q < w0 - 1e-9 then
    begin
      w0 := q;
      th0 := a + Pi / 2;
    end;
  end;
  if (w0 < 1) or (w0 > MaxW) then Exit;
  // follow the stroke both ways
  for sgn := 0 to 1 do
  begin
    SetLength(lists[sgn], 4000);
    cn[sgn] := 0;
    dx := Cos(th0);
    dy := Sin(th0);
    if sgn = 1 then
    begin
      dx := -dx;
      dy := -dy;
    end;
    wd := Across(sx, sy, dx, dy, nx, ny);
    if not GoodW(wd) then Continue;
    lists[sgn][0].x := nx;
    lists[sgn][0].y := ny;
    cn[sgn] := 1;
    ppx := nx;
    ppy := ny;
    bad := 0;
    while cn[sgn] < 4000 do
    begin
      if cn[sgn] >= 4 then
      begin
        i := Max(0, cn[sgn] - 7);
        nx := lists[sgn][cn[sgn] - 1].x - lists[sgn][i].x;
        ny := lists[sgn][cn[sgn] - 1].y - lists[sgn][i].y;
        l := Hypot(nx, ny);
        if l > 1e-6 then
        begin
          dx := nx / l;
          dy := ny / l;
        end;
      end;
      ppx := ppx + dx * Step;
      ppy := ppy + dy * Step;
      wd := Across(ppx, ppy, dx, dy, nx, ny);
      if not GoodW(wd) then
      begin
        Inc(bad);
        if bad > 2 then Break;
        Continue;
      end;
      bad := 0;
      lists[sgn][cn[sgn]].x := nx;
      lists[sgn][cn[sgn]].y := ny;
      Inc(cn[sgn]);
      ppx := nx;
      ppy := ny;
    end;
  end;
  if cn[0] = 0 then Exit;
  cnt := cn[0] + Max(0, cn[1] - 1);
  if cnt < 8 then Exit;
  SetLength(pts, cnt);
  k := 0;
  for i := cn[1] - 1 downto 1 do
  begin
    pts[k] := lists[1][i];
    Inc(k);
  end;
  a := k;                       // the index of the click's middle point
  for i := 0 to cn[0] - 1 do
  begin
    pts[k] := lists[0][i];
    Inc(k);
  end;
  if not Fit(pts, cnt, ccx, ccy, rad, res) then Exit;
  if res > Max(1.2, 0.3 * w0) then Exit;
  span := (cnt - 1) * Step / rad;
  sag := rad * (1 - Cos(Min(span, Pi) / 2));
  if sag < Max(2, 0.6 * w0) then Exit;      // too straight: the straight line does it
  a0 := ArcTan2(pts[Round(a)].y - ccy, pts[Round(a)].x - ccx);
  Extent;
  // refine the circle on the middle of the stroke along the arc found
  wmed := w0;
  for it := 1 to 2 do
  begin
    sweep := aPlus + aMinus;
    refN := Max(8, Round(sweep * rad / Step));
    SetLength(ref, refN + 1);
    nw := 0;
    wsum := 0;
    cnt := 0;
    for i := 0 to refN do
    begin
      ang := a0 - aMinus + sweep * i / refN;
      wd := Across(ccx + rad * Cos(ang), ccy + rad * Sin(ang), -Sin(ang), Cos(ang), nx, ny);
      if GoodW(wd) then
      begin
        ref[cnt].x := nx;
        ref[cnt].y := ny;
        Inc(cnt);
        wsum := wsum + wd;
        SetLength(wlist, nw + 1);
        wlist[nw] := wd;
        Inc(nw);
      end;
    end;
    if (cnt < 8) or (nw = 0) then Break;
    if not Fit(ref, cnt, nx, ny, l, wd) then Break;
    if wd > Max(1.2, 0.3 * w0) then Break;
    ccx := nx;
    ccy := ny;
    rad := l;
    for i := 1 to nw - 1 do
    begin
      l := wlist[i];
      k := i - 1;
      while (k >= 0) and (wlist[k] > l) do
      begin
        wlist[k + 1] := wlist[k];
        Dec(k);
      end;
      wlist[k + 1] := l;
    end;
    wmed := wlist[nw div 2];
    a0 := ArcTan2(pts[Round(a)].y - ccy, pts[Round(a)].x - ccx);
    Extent;
  end;
  sweep := aPlus + aMinus;
  if sweep * rad < Max(6, 2 * w0) then Exit;
  full := sweep >= 2 * Pi - 6 * da;
  if whole and (sweep * rad * wmed < 0.75 * n) then Exit;
  FillChar(R, SizeOf(R), 0);
  R.Area := n;
  R.Color := ((seed shr 16) and $FF) or (((seed shr 8) and $FF) shl 8) or ((seed and $FF) shl 16);
  R.Partial := not whole;
  R.Thick := wmed;
  R.CX := ccx + 0.5;
  R.CY := ccy + 0.5;
  R.A := rad;
  R.B := rad;
  if full then
  begin
    R.Kind := vkEllipse;
    R.Ring := True;
    R.Theta := 0;
  end
  else
  begin
    R.Kind := vkArc;
    R.A1 := a0 - aMinus;
    R.A2 := a0 + aPlus;
    while R.A1 < 0 do R.A1 := R.A1 + 2 * Pi;
    while R.A1 >= 2 * Pi do R.A1 := R.A1 - 2 * Pi;
    while R.A2 < 0 do R.A2 := R.A2 + 2 * Pi;
    while R.A2 >= 2 * Pi do R.A2 := R.A2 - 2 * Pi;
  end;
  Result := True;
end;

function Vectorize(w, h: Integer; const pix: array of LongWord; sx, sy, tol: Integer): TVecResult;
var
  reg: array of Byte;           // region, in the bounding box (+1 pixel margin) coordinates
  mask: array of Byte;          // whole picture: 1 = in the region
  stack: array of Integer;
  sp, i, j, k, x, y, n, bw, bh, x0, y0, x1, y1, bx, by: Integer;
  seed: LongWord;
  touches: Boolean;
  outside: array of Byte;
  filled: array of Byte;
  nf: Integer;
  ring: Boolean;
  sol: array of Byte;           // solid mask used by the fit
  area: Integer;
  mx, my, cxx, cyy, cxy, dx, dy: Double;
  thPCA, l1, l2, ea, eb: Double;
  bpx, bpy: array of Double;    // boundary pixel centres
  nb: Integer;
  ang, bestAng, bestArea, c, s, u, v, umin, umax, vmin, vmax, ar: Double;
  bumin, bumax, bvmin, bvmax: Double;
  rectIoU, ellIoU, inter, uni: Double;
  rcx, rcy, rl, rw: Double;     // oriented rectangle: centre, length (u), width (v)
  t, per: Double;
  circle: Boolean;

  function Idx(px, py: Integer): Integer;
  begin
    Result := py * w + px;
  end;

  function LIdx(px, py: Integer): Integer;
  begin
    Result := (py - y0 + 1) * bw + (px - x0 + 1);
  end;

  procedure Probe(a: Double);
  var
    q: Integer;
    cc, ss, uu, vv, mnu, mxu, mnv, mxv, aa: Double;
  begin
    cc := Cos(a);
    ss := Sin(a);
    mnu := 1e30; mxu := -1e30; mnv := 1e30; mxv := -1e30;
    for q := 0 to nb - 1 do
    begin
      uu := bpx[q] * cc + bpy[q] * ss;
      vv := -bpx[q] * ss + bpy[q] * cc;
      if uu < mnu then mnu := uu;
      if uu > mxu then mxu := uu;
      if vv < mnv then mnv := vv;
      if vv > mxv then mxv := vv;
    end;
    aa := (mxu - mnu + 1) * (mxv - mnv + 1);
    if aa < bestArea - 1e-9 then
    begin
      bestArea := aa;
      bestAng := a;
      bumin := mnu; bumax := mxu; bvmin := mnv; bvmax := mxv;
    end;
  end;

begin
  Result := Fail('');
  if (sx < 0) or (sy < 0) or (sx >= w) or (sy >= h) or (Length(pix) < w * h) then
    Exit(Fail('Click inside the picture.'));
  seed := pix[Idx(sx, sy)];
  SetLength(mask, w * h);
  FillChar(mask[0], w * h, 0);
  SetLength(stack, w * h);
  sp := 0;
  stack[sp] := Idx(sx, sy);
  Inc(sp);
  mask[Idx(sx, sy)] := 1;
  n := 0;
  x0 := sx; x1 := sx; y0 := sy; y1 := sy;
  touches := False;
  while sp > 0 do
  begin
    Dec(sp);
    k := stack[sp];
    y := k div w;
    x := k - y * w;
    Inc(n);
    if x < x0 then x0 := x;
    if x > x1 then x1 := x;
    if y < y0 then y0 := y;
    if y > y1 then y1 := y;
    if (x = 0) or (y = 0) or (x = w - 1) or (y = h - 1) then touches := True;
    if (x > 0) and (mask[k - 1] = 0) and SameColor(pix[k - 1], seed, tol) then
    begin
      mask[k - 1] := 1; stack[sp] := k - 1; Inc(sp);
    end;
    if (x < w - 1) and (mask[k + 1] = 0) and SameColor(pix[k + 1], seed, tol) then
    begin
      mask[k + 1] := 1; stack[sp] := k + 1; Inc(sp);
    end;
    if (y > 0) and (mask[k - w] = 0) and SameColor(pix[k - w], seed, tol) then
    begin
      mask[k - w] := 1; stack[sp] := k - w; Inc(sp);
    end;
    if (y < h - 1) and (mask[k + w] = 0) and SameColor(pix[k + w], seed, tol) then
    begin
      mask[k + w] := 1; stack[sp] := k + w; Inc(sp);
    end;
  end;
  if n < 12 then Exit(Fail('The area under the click is too small.'));
  if touches then
  begin
    // a figure that goes on to the edge: at least the straight stroke under the click
    if TryLocalCurve(w, h, mask, sx, sy, n, seed, False, Result) then Exit;
    if TryLocalLine(w, h, mask, sx, sy, n, seed, Result) then Exit;
    Exit(Fail('The area reaches the edge of the picture: click inside a closed figure.'));
  end;

  // local copy with a one pixel margin
  bw := x1 - x0 + 3;
  bh := y1 - y0 + 3;
  SetLength(reg, bw * bh);
  FillChar(reg[0], bw * bh, 0);
  for y := y0 to y1 do
    for x := x0 to x1 do
      if mask[Idx(x, y)] <> 0 then reg[LIdx(x, y)] := 1;
  // what is outside the region and connected to the margin; the rest is hole or region
  SetLength(outside, bw * bh);
  FillChar(outside[0], bw * bh, 0);
  SetLength(stack, bw * bh);
  sp := 0;
  stack[sp] := 0;
  Inc(sp);
  outside[0] := 1;
  while sp > 0 do
  begin
    Dec(sp);
    k := stack[sp];
    y := k div bw;
    x := k - y * bw;
    if (x > 0) and (outside[k - 1] = 0) and (reg[k - 1] = 0) then begin outside[k - 1] := 1; stack[sp] := k - 1; Inc(sp); end;
    if (x < bw - 1) and (outside[k + 1] = 0) and (reg[k + 1] = 0) then begin outside[k + 1] := 1; stack[sp] := k + 1; Inc(sp); end;
    if (y > 0) and (outside[k - bw] = 0) and (reg[k - bw] = 0) then begin outside[k - bw] := 1; stack[sp] := k - bw; Inc(sp); end;
    if (y < bh - 1) and (outside[k + bw] = 0) and (reg[k + bw] = 0) then begin outside[k + bw] := 1; stack[sp] := k + bw; Inc(sp); end;
  end;
  SetLength(filled, bw * bh);
  nf := 0;
  for k := 0 to bw * bh - 1 do
    if outside[k] = 0 then
    begin
      filled[k] := 1;
      Inc(nf);
    end
    else filled[k] := 0;
  ring := nf > n + n div 12 + 4;
  SetLength(sol, bw * bh);
  if ring then Move(filled[0], sol[0], bw * bh) else Move(reg[0], sol[0], bw * bh);
  area := 0;
  mx := 0; my := 0;
  for y := 0 to bh - 1 do
    for x := 0 to bw - 1 do
      if sol[y * bw + x] <> 0 then
      begin
        Inc(area);
        mx := mx + x;
        my := my + y;
      end;
  if area < 12 then Exit(Fail('The area under the click is too small.'));
  mx := mx / area;
  my := my / area;
  cxx := 0; cyy := 0; cxy := 0;
  for y := 0 to bh - 1 do
    for x := 0 to bw - 1 do
      if sol[y * bw + x] <> 0 then
      begin
        dx := x - mx;
        dy := y - my;
        cxx := cxx + dx * dx;
        cyy := cyy + dy * dy;
        cxy := cxy + dx * dy;
      end;
  cxx := cxx / area + 1 / 12;       // a pixel is not a point
  cyy := cyy / area + 1 / 12;
  cxy := cxy / area;
  thPCA := 0.5 * ArcTan2(2 * cxy, cxx - cyy);
  l1 := (cxx + cyy) / 2 + Sqrt(Sqr((cxx - cyy) / 2) + cxy * cxy);
  l2 := (cxx + cyy) / 2 - Sqrt(Sqr((cxx - cyy) / 2) + cxy * cxy);
  ea := 2 * Sqrt(Max(l1, 1e-9));
  eb := 2 * Sqrt(Max(l2, 1e-9));

  // boundary pixels of the solid mask
  SetLength(bpx, area);
  SetLength(bpy, area);
  nb := 0;
  for y := 1 to bh - 2 do
    for x := 1 to bw - 2 do
      if (sol[y * bw + x] <> 0) and
         ((sol[y * bw + x - 1] = 0) or (sol[y * bw + x + 1] = 0) or
          (sol[(y - 1) * bw + x] = 0) or (sol[(y + 1) * bw + x] = 0)) then
      begin
        bpx[nb] := x;
        bpy[nb] := y;
        Inc(nb);
      end;
  // smallest oriented bounding rectangle (1 degree steps)
  bestArea := 1e30;
  bestAng := 0;
  bumin := 0; bumax := 0; bvmin := 0; bvmax := 0;
  for k := 0 to 89 do Probe(k * Pi / 180);
  // fine search around the best angle (long thin shapes need it)
  ang := bestAng - Pi / 180;
  for k := 0 to 40 do Probe(ang + k * Pi / 180 / 20);
  c := Cos(bestAng);
  s := Sin(bestAng);
  rl := bumax - bumin + 1;
  rw := bvmax - bvmin + 1;
  u := (bumin + bumax) / 2;
  v := (bvmin + bvmax) / 2;
  rcx := u * c - v * s;
  rcy := u * s + v * c;
  // IoU of the rectangle
  inter := 0;
  for y := 0 to bh - 1 do
    for x := 0 to bw - 1 do
      if sol[y * bw + x] <> 0 then
      begin
        u := x * c + y * s - ((bumin + bumax) / 2);
        v := -x * s + y * c - ((bvmin + bvmax) / 2);
        if (Abs(u) <= rl / 2) and (Abs(v) <= rw / 2) then inter := inter + 1;
      end;
  uni := area + rl * rw - inter;
  rectIoU := inter / uni;
  // IoU of the ellipse with the same moments
  inter := 0;
  for y := 0 to bh - 1 do
    for x := 0 to bw - 1 do
      if sol[y * bw + x] <> 0 then
      begin
        dx := x - mx;
        dy := y - my;
        u := dx * Cos(thPCA) + dy * Sin(thPCA);
        v := -dx * Sin(thPCA) + dy * Cos(thPCA);
        if Sqr(u / ea) + Sqr(v / eb) <= 1 then inter := inter + 1;
      end;
  uni := area + Pi * ea * eb - inter;
  ellIoU := inter / uni;

  FillChar(Result, SizeOf(Result), 0);
  Result.Area := n;
  Result.Color := ((seed shr 16) and $FF) or (((seed shr 8) and $FF) shl 8) or ((seed and $FF) shl 16);
  Result.Ring := ring;
  // pixel centres -> picture coordinates: pixel (x, y) covers [x, x+1) so add 0.5, remove the margin
  if (ellIoU >= 0.93) and (ellIoU >= rectIoU) and not ((Max(rl, rw) / Min(rl, rw) >= 8)) then
  begin
    Result.Kind := vkEllipse;
    Result.CX := mx + x0 - 1 + 0.5;
    Result.CY := my + y0 - 1 + 0.5;
    Result.A := ea;
    Result.B := eb;
    Result.Theta := thPCA;
    circle := Abs(ea - eb) <= 0.06 * ea;
    if circle then
    begin
      Result.A := (ea + eb) / 2;
      Result.B := Result.A;
    end;
  end
  else if (rectIoU >= 0.95) or ((Min(rl, rw) > 0) and (Max(rl, rw) / Min(rl, rw) >= 8) and (rectIoU >= 0.78)) then
  begin
    if (Min(rl, rw) <= 0) then Exit(Fail('Not a recognisable shape.'));
    if Max(rl, rw) / Min(rl, rw) >= 8 then
    begin
      Result.Kind := vkLine;
      if rl >= rw then
      begin
        Result.Theta := bestAng;
        Result.A := rl / 2;
        Result.B := rw / 2;
      end
      else
      begin
        Result.Theta := bestAng + Pi / 2;
        Result.A := rw / 2;
        Result.B := rl / 2;
      end;
    end
    else
    begin
      Result.Kind := vkRect;
      Result.Theta := bestAng;
      Result.A := rl / 2;
      Result.B := rw / 2;
    end;
    Result.CX := rcx + x0 - 1 + 0.5;
    Result.CY := rcy + y0 - 1 + 0.5;
  end
  else
  begin
    // not a simple figure: a polygon or a polyline stroke, if it fits well
    if TryLocalCurve(w, h, mask, sx, sy, n, seed, True, Result) then Exit;
    if TryPath(reg, bw, bh, x0 - 1, y0 - 1, n, ring, Result) then Exit;
    if TryLocalCurve(w, h, mask, sx, sy, n, seed, False, Result) then Exit;
    if TryLocalLine(w, h, mask, sx, sy, n, seed, Result) then Exit;
    if Result.Msg = '' then Result.Msg := 'The area is not clearly a rectangle, an ellipse or a straight line.';
    Result.Kind := vkNone;
    Exit;
  end;
  while Result.Theta >= Pi do Result.Theta := Result.Theta - Pi;
  while Result.Theta < 0 do Result.Theta := Result.Theta + Pi;

  if ring then
  begin
    // a circle outline: measured on the stroke itself (other lines crossing it do not count)
    if (Result.Kind = vkEllipse) and (Abs(Result.A - Result.B) <= 1e-6) then
      if TryLocalCurve(w, h, mask, sx, sy, n, seed, False, Result) then Exit;
    if Result.Kind = vkLine then
    begin
      if TryLocalCurve(w, h, mask, sx, sy, n, seed, False, Result) then Exit;
      if TryLocalLine(w, h, mask, sx, sy, n, seed, Result) then Exit;
      Exit(Fail('Not a recognisable shape.'));
    end;
    // stroke width from the area of the outline; the figure is the middle of the stroke
    t := n / Max(1, 2 * (Result.A + Result.B) * 2);
    for i := 1 to 6 do
    begin
      if Result.Kind = vkRect then
        per := 4 * ((Result.A - t / 2) + (Result.B - t / 2))
      else
        per := Pi * (3 * ((Result.A - t / 2) + (Result.B - t / 2)) -
          Sqrt((3 * (Result.A - t / 2) + (Result.B - t / 2)) * ((Result.A - t / 2) + 3 * (Result.B - t / 2))));
      if per < 1 then Break;
      t := n / per;
    end;
    if (t <= 0) or (t >= Min(Result.A, Result.B)) then
      Exit(Fail('The outline is too thick to be recognised.'));
    Result.Thick := t;
    Result.A := Result.A - t / 2;
    Result.B := Result.B - t / 2;
  end;
end;

end.
