unit TTFill;

{$mode objfpc}{$H+}

// Paint bucket: finds the closed area that contains a point, bounded by a set of polylines.
// The polylines are cut at every crossing / touching point, the dangling ends are pruned and
// the face around the point is followed along the resulting planar graph.  Islands that do not
// touch the outer boundary become holes (joined to it by a zero-width bridge, so the result is a
// single polygon that fills correctly with any fill rule).

interface

uses
  SysUtils, Math;

type
  TFPt = record
    x, y: Double;
  end;
  TFPtArray = array of TFPt;
  TFIntArray = array of Integer;

  TFPoly = record
    Id: Integer;
    Pts: TFPtArray;
    Closed: Boolean;
  end;
  TFPolyArray = array of TFPoly;

  // one closed boundary of an area: Ids[i] is the shape of the side from Pts[i] to Pts[i+1]; the
  // area lies on the left of every side
  TFLoop = record
    Pts: TFPtArray;
    Ids: TFIntArray;
  end;
  TFLoopArray = array of TFLoop;

  TFRegion = record
    Ok: Boolean;
    Poly: TFPtArray;
    Ids: TFIntArray;
    Loops: TFLoopArray;       // the outer boundary first, then the holes
    Msg: string;
  end;
  TFRegionArray = array of TFRegion;

// polys: the boundaries (any open / closed polylines); seed: a point inside the wanted area;
// eps: points closer than this are the same point.  On success poly is the outline (outer
// boundary then holes, bridged), ids the shapes that form it.
function FindRegion(const polys: TFPolyArray; const seed: TFPt; eps: Double;
  out poly: TFPtArray; out ids: TFIntArray; out msg: string): Boolean;

// a loop moved towards the inside of the area by dist[i] along each side (the corners follow);
// the loop itself when the result would fold over
function InsetLoop(const pts: TFPtArray; const dist: array of Double): TFPtArray;

// the loops (outer boundary, then holes) as one polygon: every hole is joined to the outline by a
// zero-width bridge
function BridgeLoops(const loops: TFLoopArray): TFPtArray;

// the same for several seed points, building the boundary graph only once
procedure FindRegions(const polys: TFPolyArray; const seeds: TFPtArray; eps: Double;
  out regs: TFRegionArray);

function PolyArea(const p: TFPtArray): Double;
function InsidePoly(const p: TFPtArray; x, y: Double): Boolean;

const
  HatchCount = 8;
  HatchNames: array[0..HatchCount - 1] of string = (
    'None (solid colour)', 'Lines 45° (ISO general / metals)', 'Lines 135°', 'Horizontal lines',
    'Vertical lines', 'Cross-hatch 45°', 'Grid (horizontal + vertical)', 'Dots');

// hatching of the inside of a polygon (even-odd): segs gets pairs of points, one pair per line
// (a dot is a pair of equal points).  pat: see HatchNames; sp = distance between lines; ang is
// added to the angle of the pattern.  The lines are anchored to the origin of the drawing, so
// the same pattern lines up from one area to the next.
procedure HatchLines(const poly: TFPtArray; pat: Integer; sp, angDeg: Double; var segs: TFPtArray);

implementation

type
  TEdge = record
    a, b: Integer;          // nodes
    id: Integer;            // shape the edge comes from
    dead: Boolean;
  end;

procedure HatchLines(const poly: TFPtArray; pat: Integer; sp, angDeg: Double; var segs: TFPtArray);
var
  fam: array[0..1] of Double;
  nf, f, i, j, k, n: Integer;
  th, ux, uy, nx, ny, cmin, cmax, smin, smax, c, ca, cb, t, sv, step: Double;
  ss: array of Double;
  ns: Integer;
  px, py: Double;

  procedure Put(x1, y1, x2, y2: Double);
  begin
    if n + 2 > Length(segs) then SetLength(segs, Length(segs) * 2 + 64);
    segs[n].x := x1;
    segs[n].y := y1;
    segs[n + 1].x := x2;
    segs[n + 1].y := y2;
    Inc(n);
    Inc(n);
  end;

begin
  n := Length(segs);
  SetLength(segs, n);
  if (pat <= 0) or (Length(poly) < 3) then Exit;
  sp := Max(sp, 0.5);
  nf := 1;
  case pat of
    1: fam[0] := -45;
    2: fam[0] := 45;
    3: fam[0] := 0;
    4: fam[0] := 90;
    5: begin fam[0] := -45; fam[1] := 45; nf := 2; end;
    6: begin fam[0] := 0; fam[1] := 90; nf := 2; end;
    7: fam[0] := 0;
  else
    Exit;
  end;
  smin := 1e300; smax := -1e300;
  for i := 0 to High(poly) do
  begin
    smin := Min(smin, Min(poly[i].x, poly[i].y));
    smax := Max(smax, Max(poly[i].x, poly[i].y));
  end;
  // keep the number of lines reasonable
  step := sp;
  while (Hypot(smax - smin, smax - smin) * 2 / step > 3000) do step := step * 2;
  if pat = 7 then
  begin
    th := angDeg * Pi / 180;
    ux := Cos(th);
    uy := Sin(th);
    nx := -uy;
    ny := ux;
    // lattice (i * step, j * step) turned by th, kept inside the polygon
    cmin := 1e300; cmax := -1e300; smin := 1e300; smax := -1e300;
    for i := 0 to High(poly) do
    begin
      c := poly[i].x * nx + poly[i].y * ny;
      sv := poly[i].x * ux + poly[i].y * uy;
      cmin := Min(cmin, c); cmax := Max(cmax, c);
      smin := Min(smin, sv); smax := Max(smax, sv);
    end;
    while ((cmax - cmin) / step) * ((smax - smin) / step) > 40000 do step := step * 2;
    i := Ceil(cmin / step);
    while i * step <= cmax do
    begin
      j := Ceil(smin / step);
      while j * step <= smax do
      begin
        px := i * step * nx + j * step * ux;
        py := i * step * ny + j * step * uy;
        if InsidePoly(poly, px, py) then Put(px, py, px, py);
        Inc(j);
      end;
      Inc(i);
    end;
    Exit;
  end;
  SetLength(ss, 0);
  for f := 0 to nf - 1 do
  begin
    th := (fam[f] + angDeg) * Pi / 180;
    ux := Cos(th);
    uy := Sin(th);
    nx := -uy;
    ny := ux;
    cmin := 1e300; cmax := -1e300;
    for i := 0 to High(poly) do
    begin
      c := poly[i].x * nx + poly[i].y * ny;
      cmin := Min(cmin, c);
      cmax := Max(cmax, c);
    end;
    k := Ceil(cmin / step);
    while k * step <= cmax do
    begin
      c := k * step;
      ns := 0;
      SetLength(ss, 0);
      j := High(poly);
      for i := 0 to High(poly) do
      begin
        ca := poly[j].x * nx + poly[j].y * ny - c;
        cb := poly[i].x * nx + poly[i].y * ny - c;
        if (ca > 0) <> (cb > 0) then
        begin
          t := ca / (ca - cb);
          px := poly[j].x + t * (poly[i].x - poly[j].x);
          py := poly[j].y + t * (poly[i].y - poly[j].y);
          SetLength(ss, ns + 1);
          ss[ns] := px * ux + py * uy;
          Inc(ns);
        end;
        j := i;
      end;
      // sort and pair up (even-odd)
      for i := 1 to ns - 1 do
      begin
        sv := ss[i];
        j := i - 1;
        while (j >= 0) and (ss[j] > sv) do
        begin
          ss[j + 1] := ss[j];
          Dec(j);
        end;
        ss[j + 1] := sv;
      end;
      i := 0;
      while i + 1 < ns do
      begin
        Put(c * nx + ss[i] * ux, c * ny + ss[i] * uy, c * nx + ss[i + 1] * ux, c * ny + ss[i + 1] * uy);
        Inc(i, 2);
      end;
      Inc(k);
    end;
  end;
  SetLength(segs, n);
end;

function PolyArea(const p: TFPtArray): Double;
var
  i, j: Integer;
begin
  Result := 0;
  if Length(p) < 3 then Exit;
  j := High(p);
  for i := 0 to High(p) do
  begin
    Result := Result + (p[j].x + p[i].x) * (p[j].y - p[i].y);
    j := i;
  end;
  Result := Result / 2;
end;

function InsidePoly(const p: TFPtArray; x, y: Double): Boolean;
var
  i, j: Integer;
begin
  Result := False;
  if Length(p) < 3 then Exit;
  j := High(p);
  for i := 0 to High(p) do
  begin
    if ((p[i].y > y) <> (p[j].y > y)) and
       (x < (p[j].x - p[i].x) * (y - p[i].y) / (p[j].y - p[i].y) + p[i].x) then
      Result := not Result;
    j := i;
  end;
end;

function InsetLoop(const pts: TFPtArray; const dist: array of Double): TFPtArray;
var
  n, i, j: Integer;
  nxx, nyy, l: array of Double;
  ax, ay, bx, by, cx, cy, dx, dy, den, t, d1, d2, a0, a1: Double;
  ok, grows, shrinks: Boolean;
begin
  n := Length(pts);
  Result := Copy(pts);
  if n < 3 then Exit;
  SetLength(nxx, n);
  SetLength(nyy, n);
  SetLength(l, n);
  for i := 0 to n - 1 do
  begin
    j := (i + 1) mod n;
    dx := pts[j].x - pts[i].x;
    dy := pts[j].y - pts[i].y;
    l[i] := Hypot(dx, dy);
    if l[i] < 1e-12 then
    begin
      nxx[i] := 0;
      nyy[i] := 0;
    end
    else
    begin
      // left normal (the area is on the left)
      nxx[i] := -dy / l[i];
      nyy[i] := dx / l[i];
    end;
  end;
  a0 := PolyArea(pts);
  for i := 0 to n - 1 do
  begin
    j := (i + n - 1) mod n;          // the previous side ends at the corner i
    d1 := 0;
    d2 := 0;
    if j <= High(dist) then d1 := dist[j];
    if i <= High(dist) then d2 := dist[i];
    ax := pts[j].x + d1 * nxx[j];
    ay := pts[j].y + d1 * nyy[j];
    bx := pts[i].x - pts[j].x;
    by := pts[i].y - pts[j].y;
    cx := pts[i].x + d2 * nxx[i];
    cy := pts[i].y + d2 * nyy[i];
    dx := pts[(i + 1) mod n].x - pts[i].x;
    dy := pts[(i + 1) mod n].y - pts[i].y;
    den := bx * dy - by * dx;
    if (l[i] < 1e-12) or (l[j] < 1e-12) or (Abs(den) < 1e-9 * l[j] * l[i]) then
    begin
      // straight on: the corner moves along the normal
      Result[i].x := pts[i].x + d2 * nxx[i];
      Result[i].y := pts[i].y + d2 * nyy[i];
    end
    else
    begin
      t := ((cx - ax) * dy - (cy - ay) * dx) / den;
      Result[i].x := ax + t * bx;
      Result[i].y := ay + t * by;
      // a very sharp corner would send the point far away: keep it close
      if Hypot(Result[i].x - pts[i].x, Result[i].y - pts[i].y) > 6 * Max(Abs(d1), Max(Abs(d2), 0.5)) then
      begin
        Result[i].x := pts[i].x + (d1 * nxx[j] + d2 * nxx[i]) / 2;
        Result[i].y := pts[i].y + (d1 * nyy[j] + d2 * nyy[i]) / 2;
      end;
    end;
  end;
  // too thin to move in, or turned inside out: leave it as it is
  a1 := PolyArea(Result);
  grows := True;
  shrinks := True;
  for i := 0 to High(dist) do
  begin
    if dist[i] > 0 then grows := False;
    if dist[i] < 0 then shrinks := False;
  end;
  ok := (a0 * a1 > 0) and (Abs(a1) > 0.01 * Abs(a0));
  if shrinks then ok := ok and (Abs(a1) <= Abs(a0) * 1.0001)
  else if grows then ok := ok and (Abs(a1) >= Abs(a0) * 0.9999);
  if not ok then Result := Copy(pts);
end;

function BridgeLoops(const loops: TFLoopArray): TFPtArray;
var
  res, hp, work: TFPtArray;
  i, j, k, m, r2, bridgeO, bridgeH: Integer;
  dmin, dd: Double;
begin
  SetLength(res, 0);
  if Length(loops) = 0 then Exit(res);
  res := Copy(loops[0].Pts);
  for i := 1 to High(loops) do
  begin
    hp := loops[i].Pts;
    if Length(hp) < 3 then Continue;
    dmin := 1e300;
    bridgeO := 0;
    bridgeH := 0;
    for j := 0 to High(res) do
      for k := 0 to High(hp) do
      begin
        dd := Sqr(res[j].x - hp[k].x) + Sqr(res[j].y - hp[k].y);
        if dd < dmin then
        begin
          dmin := dd;
          bridgeO := j;
          bridgeH := k;
        end;
      end;
    m := Length(res);
    r2 := Length(hp);
    SetLength(work, m + r2 + 2);
    for j := 0 to bridgeO do work[j] := res[j];
    for k := 0 to r2 do work[bridgeO + 1 + k] := hp[(bridgeH + k) mod r2];
    work[bridgeO + r2 + 2] := res[bridgeO];
    for j := bridgeO + 1 to m - 1 do work[j + r2 + 2] := res[j];
    res := Copy(work);
  end;
  Result := res;
end;

procedure FindRegions(const polys: TFPolyArray; const seeds: TFPtArray; eps: Double;
  out regs: TFRegionArray);
var
  nIds: Integer;
  curSeed: TFPt;
  qpoly: TFPtArray;
  qloops: TFLoopArray;
  qids: TFIntArray;
  qmsg: string;
  qok: Boolean;
  qi: Integer;
  msg: string;
  // segments
  sx1, sy1, sx2, sy2: array of Double;
  sid: array of Integer;
  ns: Integer;
  // nodes
  nx, ny: array of Double;
  nn: Integer;
  // edges
  edges: array of TEdge;
  ne: Integer;
  adj: array of array of Integer;     // per node: neighbour nodes sorted by angle
  alive: array of Boolean;            // node still in the graph
  comp: array of Integer;
  removedEdge: array of Boolean;      // edges of the components taken out (islands met by the ray)
  holes: array of TFPtArray;
  nHoles: Integer;
  outer: TFPtArray;
  outerNodes: array of Integer;
  i, j, k, p: Integer;
  seen: array of Integer;
  usedIds: array of Integer;
  maxIds: Integer;

  function NodeAt(x, y: Double): Integer;
  var
    q: Integer;
  begin
    for q := 0 to nn - 1 do
      if (Abs(nx[q] - x) <= eps) and (Abs(ny[q] - y) <= eps) then Exit(q);
    if nn >= Length(nx) then
    begin
      SetLength(nx, nn * 2 + 16);
      SetLength(ny, nn * 2 + 16);
    end;
    nx[nn] := x;
    ny[nn] := y;
    Result := nn;
    Inc(nn);
  end;

  function EdgeIndex(a, b: Integer): Integer;
  var
    q: Integer;
  begin
    for q := 0 to ne - 1 do
      if ((edges[q].a = a) and (edges[q].b = b)) or ((edges[q].a = b) and (edges[q].b = a)) then Exit(q);
    Result := -1;
  end;

  procedure AddEdge(a, b, id: Integer);
  begin
    if a = b then Exit;
    if EdgeIndex(a, b) >= 0 then Exit;
    if ne >= Length(edges) then SetLength(edges, ne * 2 + 16);
    edges[ne].a := a;
    edges[ne].b := b;
    edges[ne].id := id;
    edges[ne].dead := False;
    Inc(ne);
  end;

  function Ang(a, b: Integer): Double;
  begin
    Result := ArcTan2(ny[b] - ny[a], nx[b] - nx[a]);
  end;

  procedure BuildAdj;
  var
    q, r, cnt: Integer;
    t: Integer;
    swapped: Boolean;
  begin
    SetLength(adj, nn);
    for q := 0 to nn - 1 do SetLength(adj[q], 0);
    for q := 0 to ne - 1 do
    begin
      if edges[q].dead or removedEdge[q] then Continue;
      cnt := Length(adj[edges[q].a]);
      SetLength(adj[edges[q].a], cnt + 1);
      adj[edges[q].a][cnt] := edges[q].b;
      cnt := Length(adj[edges[q].b]);
      SetLength(adj[edges[q].b], cnt + 1);
      adj[edges[q].b][cnt] := edges[q].a;
    end;
    for q := 0 to nn - 1 do
    begin
      repeat
        swapped := False;
        for r := 0 to Length(adj[q]) - 2 do
          if Ang(q, adj[q][r]) > Ang(q, adj[q][r + 1]) then
          begin
            t := adj[q][r];
            adj[q][r] := adj[q][r + 1];
            adj[q][r + 1] := t;
            swapped := True;
          end;
      until not swapped;
    end;
  end;

  procedure Prune;
  var
    q, r, deg: Integer;
    changed: Boolean;
  begin
    repeat
      changed := False;
      for q := 0 to ne - 1 do
        if not edges[q].dead and not removedEdge[q] then
        begin
          // degree of both ends
          deg := 0;
          for r := 0 to ne - 1 do
            if not edges[r].dead and not removedEdge[r] and
               ((edges[r].a = edges[q].a) or (edges[r].b = edges[q].a)) then Inc(deg);
          if deg = 1 then
          begin
            edges[q].dead := True;
            changed := True;
            Continue;
          end;
          deg := 0;
          for r := 0 to ne - 1 do
            if not edges[r].dead and not removedEdge[r] and
               ((edges[r].a = edges[q].b) or (edges[r].b = edges[q].b)) then Inc(deg);
          if deg = 1 then
          begin
            edges[q].dead := True;
            changed := True;
          end;
        end;
    until not changed;
  end;

  // the face on the left of the half edge u -> v, as a list of nodes; empty on failure
  function Trace(u, v: Integer; var nodes: array of Integer; out cnt: Integer): Boolean;
  var
    x0, y0, w, idx, q, steps, cu, cv: Integer;
  begin
    Result := False;
    cnt := 0;
    x0 := u;
    y0 := v;
    cu := u;
    cv := v;
    steps := 0;
    repeat
      if cnt >= Length(nodes) then Exit;
      nodes[cnt] := cu;
      Inc(cnt);
      // next: the neighbour just clockwise (previous in angle order) of the way back
      idx := -1;
      for q := 0 to High(adj[cv]) do
        if adj[cv][q] = cu then idx := q;
      if idx < 0 then Exit;
      w := adj[cv][(idx + Length(adj[cv]) - 1) mod Length(adj[cv])];
      cu := cv;
      cv := w;
      Inc(steps);
      if steps > 4 * ne + 8 then Exit;
    until (cu = x0) and (cv = y0);
    Result := cnt >= 3;
  end;

  procedure ComponentMark(startNode, mark: Integer);
  var
    stack: array of Integer;
    sp, q, cur: Integer;
  begin
    SetLength(stack, nn + 1);
    sp := 0;
    stack[sp] := startNode;
    Inc(sp);
    comp[startNode] := mark;
    while sp > 0 do
    begin
      Dec(sp);
      cur := stack[sp];
      for q := 0 to High(adj[cur]) do
        if comp[adj[cur][q]] <> mark then
        begin
          comp[adj[cur][q]] := mark;
          stack[sp] := adj[cur][q];
          Inc(sp);
        end;
    end;
  end;

  function LoopPts(const nodes: array of Integer; cnt: Integer): TFPtArray;
  var
    q: Integer;
  begin
    SetLength(Result, cnt);
    for q := 0 to cnt - 1 do
    begin
      Result[q].x := nx[nodes[q]];
      Result[q].y := ny[nodes[q]];
    end;
  end;

  procedure UseId(id: Integer);
  var
    q: Integer;
  begin
    for q := 0 to nIds - 1 do
      if usedIds[q] = id then Exit;
    if nIds < maxIds then
    begin
      usedIds[nIds] := id;
      Inc(nIds);
    end;
  end;

  procedure UseLoopIds(const nodes: array of Integer; cnt: Integer);
  var
    q, e: Integer;
  begin
    for q := 0 to cnt - 1 do
    begin
      e := EdgeIndex(nodes[q], nodes[(q + 1) mod cnt]);
      if e >= 0 then UseId(edges[e].id);
    end;
  end;

var
  poly0, pts, work: TFPtArray;
  a, b, c, d, t, tt, e1, e2: Double;
  ts: array of Double;
  na, ia, ib, hit, best, tries: Integer;
  bestY, cy, cx1, cx2, cross: Double;
  nodesBuf: array of Integer;
  cnt, startU, startV, t1, other: Integer;
  found: Boolean;
  holeNodes: array of array of Integer;
  holeCnt: array of Integer;
  topNode, topNb, q2, cc, nComp: Integer;
  hp: TFPtArray;
  bridgeO, bridgeH: Integer;
  dmin, dd: Double;
  res: TFPtArray;
  m, r2: Integer;
procedure MakeLoop(const nodes: array of Integer; cnt: Integer; var lp: TFLoop);
var
  q, e: Integer;
begin
  SetLength(lp.Pts, cnt);
  SetLength(lp.Ids, cnt);
  for q := 0 to cnt - 1 do
  begin
    lp.Pts[q].x := nx[nodes[q]];
    lp.Pts[q].y := ny[nodes[q]];
    e := EdgeIndex(nodes[q], nodes[(q + 1) mod cnt]);
    if e >= 0 then lp.Ids[q] := edges[e].id else lp.Ids[q] := 0;
  end;
end;

procedure FailAll(const m: string);
var
  q: Integer;
begin
  SetLength(regs, Length(seeds));
  for q := 0 to High(seeds) do
  begin
    regs[q].Ok := False;
    regs[q].Msg := m;
  end;
end;

procedure Query;
var
  i, j, k, tries, cc, q2: Integer;
begin
  qok := False;
  qmsg := '';
  nIds := 0;
  for i := 0 to ne - 1 do removedEdge[i] := False;
  SetLength(holes, 0);
  nHoles := 0;
  SetLength(holeNodes, 0);
  SetLength(holeCnt, 0);
  SetLength(nodesBuf, 4 * ne + 16);
  SetLength(comp, nn);
  found := False;
  // 3. follow the face that contains the seed
  for tries := 1 to 64 do
  begin
    BuildAdj;
    // nearest edge above the seed
    best := -1;
    bestY := -1e300;
    for i := 0 to ne - 1 do
    begin
      if edges[i].dead or removedEdge[i] then Continue;
      cx1 := nx[edges[i].a];
      cx2 := nx[edges[i].b];
      if (cx1 <= curSeed.x) = (cx2 <= curSeed.x) then Continue;
      t := (curSeed.x - cx1) / (cx2 - cx1);
      cy := ny[edges[i].a] + t * (ny[edges[i].b] - ny[edges[i].a]);
      if (cy < curSeed.y - 1e-9) and (cy > bestY) then
      begin
        bestY := cy;
        best := i;
      end;
    end;
    if best < 0 then
    begin
      qmsg := 'The point is not inside a closed area.';
      Exit;
    end;
    startU := edges[best].a;
    startV := edges[best].b;
    cross := (nx[startV] - nx[startU]) * (curSeed.y - ny[startU]) - (ny[startV] - ny[startU]) * (curSeed.x - nx[startU]);
    if cross < 0 then
    begin
      t1 := startU;
      startU := startV;
      startV := t1;
    end;
    if not Trace(startU, startV, nodesBuf, cnt) then
    begin
      qmsg := 'The boundary of the area cannot be followed.';
      Exit;
    end;
    pts := LoopPts(nodesBuf, cnt);
    if InsidePoly(pts, curSeed.x, curSeed.y) then
    begin
      outer := pts;
      SetLength(outerNodes, cnt);
      for i := 0 to cnt - 1 do outerNodes[i] := nodesBuf[i];
      found := True;
      Break;
    end;
    // an island met by the ray: it becomes a hole; take its component out and look further
    SetLength(holes, nHoles + 1);
    holes[nHoles] := pts;
    SetLength(holeNodes, nHoles + 1);
    SetLength(holeNodes[nHoles], cnt);
    for i := 0 to cnt - 1 do holeNodes[nHoles][i] := nodesBuf[i];
    SetLength(holeCnt, nHoles + 1);
    holeCnt[nHoles] := cnt;
    Inc(nHoles);
    for i := 0 to nn - 1 do comp[i] := 0;
    ComponentMark(startU, 1);
    for i := 0 to ne - 1 do
      if (comp[edges[i].a] = 1) or (comp[edges[i].b] = 1) then removedEdge[i] := True;
  end;
  if not found then
  begin
    qmsg := 'The point is not inside a closed area.';
    Exit;
  end;
  UseLoopIds(outerNodes, Length(outerNodes));
  for i := 0 to nHoles - 1 do UseLoopIds(holeNodes[i], holeCnt[i]);
  // 4. islands that do not touch the outer boundary and were not met by the ray
  for i := 0 to nn - 1 do comp[i] := 0;
  for i := 0 to Length(outerNodes) - 1 do
    if comp[outerNodes[i]] = 0 then ComponentMark(outerNodes[i], 1);
  nComp := 1;
  for i := 0 to nn - 1 do
    if (comp[i] = 0) and (Length(adj[i]) > 0) then
    begin
      Inc(nComp);
      ComponentMark(i, nComp);
    end;
  BuildAdj;
  for cc := 2 to nComp do
  begin
    // top-left node of the component
    topNode := -1;
    for i := 0 to nn - 1 do
      if comp[i] = cc then
        if (topNode < 0) or (ny[i] < ny[topNode]) or ((ny[i] = ny[topNode]) and (nx[i] < nx[topNode])) then
          topNode := i;
    if topNode < 0 then Continue;
    if not InsidePoly(outer, nx[topNode], ny[topNode]) then Continue;
    // already inside a hole found before?
    found := False;
    for i := 0 to nHoles - 1 do
      if InsidePoly(holes[i], nx[topNode], ny[topNode]) then found := True;
    if found then Continue;
    // outer boundary of the island: leave the top node along the neighbour with the largest angle
    topNb := -1;
    for q2 := 0 to High(adj[topNode]) do
      if (topNb < 0) or (Ang(topNode, adj[topNode][q2]) > Ang(topNode, topNb)) then topNb := adj[topNode][q2];
    if topNb < 0 then Continue;
    if not Trace(topNode, topNb, nodesBuf, cnt) then Continue;
    SetLength(holes, nHoles + 1);
    holes[nHoles] := LoopPts(nodesBuf, cnt);
    SetLength(holeNodes, nHoles + 1);
    SetLength(holeNodes[nHoles], cnt);
    for i := 0 to cnt - 1 do holeNodes[nHoles][i] := nodesBuf[i];
    SetLength(holeCnt, nHoles + 1);
    holeCnt[nHoles] := cnt;
    UseLoopIds(holeNodes[nHoles], cnt);
    Inc(nHoles);
  end;
  found := True;
  // 5. the loops (with the shape of each side) and the polygon made of them
  SetLength(qloops, 1 + nHoles);
  MakeLoop(outerNodes, Length(outerNodes), qloops[0]);
  for i := 0 to nHoles - 1 do MakeLoop(holeNodes[i], holeCnt[i], qloops[i + 1]);
  res := BridgeLoops(qloops);
  qpoly := Copy(res);
  SetLength(qids, nIds);
  for i := 0 to nIds - 1 do qids[i] := usedIds[i];
  qok := True;
end;

begin
  nIds := 0;
  msg := '';
  maxIds := 4096;
  SetLength(usedIds, maxIds);
  // 1. segments
  ns := 0;
  SetLength(sx1, 256);
  SetLength(sy1, 256);
  SetLength(sx2, 256);
  SetLength(sy2, 256);
  SetLength(sid, 256);
  for i := 0 to High(polys) do
  begin
    k := Length(polys[i].Pts);
    if k < 2 then Continue;
    for j := 0 to k - 1 do
    begin
      if (j = k - 1) and not polys[i].Closed then Break;
      a := polys[i].Pts[j].x;
      b := polys[i].Pts[j].y;
      c := polys[i].Pts[(j + 1) mod k].x;
      d := polys[i].Pts[(j + 1) mod k].y;
      if Hypot(c - a, d - b) < 1e-9 then Continue;
      if ns >= Length(sx1) then
      begin
        SetLength(sx1, ns * 2);
        SetLength(sy1, ns * 2);
        SetLength(sx2, ns * 2);
        SetLength(sy2, ns * 2);
        SetLength(sid, ns * 2);
      end;
      sx1[ns] := a;
      sy1[ns] := b;
      sx2[ns] := c;
      sy2[ns] := d;
      sid[ns] := polys[i].Id;
      Inc(ns);
    end;
  end;
  if ns = 0 then
  begin
    FailAll('There is nothing to fill: no lines to bound an area.');
    Exit;
  end;
  if ns > 6000 then
  begin
    FailAll('The drawing is too complex for the paint bucket.');
    Exit;
  end;
  // 2. cut every segment at the crossings and at the points where other segments touch it
  nn := 0;
  ne := 0;
  SetLength(nx, 64);
  SetLength(ny, 64);
  SetLength(edges, 64);
  for i := 0 to ns - 1 do
  begin
    SetLength(ts, 2);
    ts[0] := 0;
    ts[1] := 1;
    na := 2;
    for j := 0 to ns - 1 do
    begin
      if j = i then Continue;
      // bounding boxes
      if (Max(sx1[i], sx2[i]) + eps < Min(sx1[j], sx2[j])) or (Min(sx1[i], sx2[i]) - eps > Max(sx1[j], sx2[j])) or
         (Max(sy1[i], sy2[i]) + eps < Min(sy1[j], sy2[j])) or (Min(sy1[i], sy2[i]) - eps > Max(sy1[j], sy2[j])) then Continue;
      a := sx2[i] - sx1[i];
      b := sy2[i] - sy1[i];
      c := sx2[j] - sx1[j];
      d := sy2[j] - sy1[j];
      e1 := a * d - b * c;
      if Abs(e1) > 1e-12 then
      begin
        t := ((sx1[j] - sx1[i]) * d - (sy1[j] - sy1[i]) * c) / e1;
        tt := ((sx1[j] - sx1[i]) * b - (sy1[j] - sy1[i]) * a) / e1;
        // a little slack so that nearly touching ends are joined
        if (t > -1e-9) and (t < 1 + 1e-9) and (tt > -1e-9) and (tt < 1 + 1e-9) then
        begin
          if na >= Length(ts) then SetLength(ts, na * 2);
          ts[na] := Max(0, Min(1, t));
          Inc(na);
        end;
      end;
      // end points of j lying on i (T junctions, overlaps, small gaps)
      for p := 0 to 1 do
      begin
        if p = 0 then begin cx1 := sx1[j]; cy := sy1[j]; end else begin cx1 := sx2[j]; cy := sy2[j]; end;
        e2 := a * a + b * b;
        t := ((cx1 - sx1[i]) * a + (cy - sy1[i]) * b) / e2;
        if (t > 0) and (t < 1) then
          if Hypot(sx1[i] + t * a - cx1, sy1[i] + t * b - cy) <= eps then
          begin
            if na >= Length(ts) then SetLength(ts, na * 2);
            ts[na] := t;
            Inc(na);
          end;
      end;
    end;
    // sort
    for j := 1 to na - 1 do
    begin
      t := ts[j];
      k := j - 1;
      while (k >= 0) and (ts[k] > t) do
      begin
        ts[k + 1] := ts[k];
        Dec(k);
      end;
      ts[k + 1] := t;
    end;
    ia := NodeAt(sx1[i] + ts[0] * (sx2[i] - sx1[i]), sy1[i] + ts[0] * (sy2[i] - sy1[i]));
    for j := 1 to na - 1 do
    begin
      ib := NodeAt(sx1[i] + ts[j] * (sx2[i] - sx1[i]), sy1[i] + ts[j] * (sy2[i] - sy1[i]));
      AddEdge(ia, ib, sid[i]);
      ia := ib;
    end;
  end;
  SetLength(removedEdge, ne);
  for i := 0 to ne - 1 do removedEdge[i] := False;
  Prune;
  SetLength(regs, Length(seeds));
  for qi := 0 to High(seeds) do
  begin
    curSeed := seeds[qi];
    Query;
    regs[qi].Ok := qok;
    regs[qi].Msg := qmsg;
    if qok then
    begin
      regs[qi].Poly := Copy(qpoly);
      regs[qi].Ids := Copy(qids);
      regs[qi].Loops := qloops;
    end;
  end;
end;

function FindRegion(const polys: TFPolyArray; const seed: TFPt; eps: Double;
  out poly: TFPtArray; out ids: TFIntArray; out msg: string): Boolean;
var
  seeds: TFPtArray;
  regs: TFRegionArray;
begin
  SetLength(seeds, 1);
  seeds[0] := seed;
  FindRegions(polys, seeds, eps, regs);
  Result := (Length(regs) > 0) and regs[0].Ok;
  SetLength(poly, 0);
  SetLength(ids, 0);
  msg := '';
  if Length(regs) = 0 then Exit;
  msg := regs[0].Msg;
  if Result then
  begin
    poly := regs[0].Poly;
    ids := regs[0].Ids;
  end;
end;

end.
