unit TTModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fgl, TTFill, TTMat;

const
  NoColor = -1;
  ArcStartIdx = -2;     // TRef.Idx of the start point (angle A1) / end point (angle A2) of an arc
  ArcEndIdx = -3;
  EllEastIdx = -4;      // the four extreme points of a circle / ellipse (virtual points)
  EllNorthIdx = -5;
  EllWestIdx = -6;
  EllSouthIdx = -7;
  SegBase = 1000;      // TRef.Idx >= SegBase: segment (Idx-SegBase) of a polyline/polygon
  HandleRX = 100;      // pseudo point indexes, only used for dragging
  HandleRY = 101;
  HandleA1 = 102;
  HandleA2 = 103;
  HandleCorner = 104;  // radius of the corners of a rectangle
  HandlePathBase = 100000;   // HandlePathBase + k: the point k of a path (see TShape.PathHandles)
  DragWeight = 0.0005;
  NeighborWeight = 0.05;     // the other end of a line whose end is dragged: it moves only when the others cannot

const
  DefaultBucketOffset = 1.0;     // a new fill goes this far under its lines, so no white gap is left

type
  TShapeKind = (skLine, skArrow, skPolyline, skPolygon, skRect, skEllipse,
                skArc, skSpline, skText, skPath, skImage);
  TLineCap = (lcFlat, lcRound, lcSquare);
  TLineJoin = (ljMiter, ljRound, ljBevel);
  TDashStyle = (dsSolid, dsDash, dsDot, dsDashDot);

  TPt = record
    x, y: Double;
  end;
  PPt = ^TPt;
  TPtArray = array of TPt;

  TPolyline = record
    Pts: TPtArray;
    Closed: Boolean;
  end;
  TOutline = array of TPolyline;
  TDblArr = array of Double;
  TBoolDyn = array of Boolean;
  TPtLoops = array of TPtArray;
  TIntDyn = array of Integer;
  // the path a gradient runs along: its points and the length reached at each
  TGradLine = record
    Pts: array of TPt;
    Cum: array of Double;
    Total: Double;
    Radial: Boolean;               // a radial gradient: t is the distance from (CX, CY) over R
    CX, CY, R: Double;
  end;
  TRingArr = array of Integer;
  // a stop of a gradient between its first colour (Style.Fill) and its last (GradColor)
  TGradStop = record
    Pos: Double;                   // 0..1 along the gradient
    Col: Integer;
    Tr: Integer;                   // transparency 0..255
  end;
  TGradStops = array of TGradStop;

  TStyle = record
    Stroke: Integer;     // $00BBGGRR or NoColor
    Fill: Integer;
    Width: Double;
    Cap: TLineCap;
    Join: TLineJoin;
    Dash: TDashStyle;
    StrokeTr, FillTr: Integer;   // transparency 0 (opaque) .. 255 (invisible); 0 when not set
    // a material (1..MaterialCount) instead of a flat colour: Stroke / Fill then hold its average colour, which is what the
    // places that know nothing of materials use; if the colour is changed the material is not valid any more
    StrokeMatId, FillMatId: Integer;
  end;

  // Non-destructive trim: the part of the outline (polyline Poly) around U0
  // (segment index + fraction, divided by the segment count) that lies between
  // the intersections with shape CA (before) and CB (after) is hidden.
  // CA / CB = -1: the open end of the shape.
  // CA = CB = -2: "break" with fixed limits UA..UB (same parameter as U0)
  TTrim = record
    Poly: Integer;
    U0: Double;
    CA, CB: Integer;
    UA, UB: Double;
  end;

  // Non-destructive extension: end EndIdx (0 = first point, 1 = last point) of a
  // line / polyline is prolonged along its last segment up to the shape Boundary.
  TExtend = record
    EndIdx: Integer;
    Boundary: Integer;
  end;

  // a path as it can be edited: only absolute M, L, C (three points: two controls and the end) and Z
  TPathNode = record
    Cmd: Char;
    N: Integer;
    Pt: array[0..2] of TPt;
  end;
  TPathNodes = array of TPathNode;

  TSprayDot = record              // a drop of an airbrush: its centre, its radius and its opacity (0..1)
    X, Y, R, A: Double;
  end;
  TSprayDotArray = array of TSprayDot;
  TShape = class
  public
    Id: Integer;
    Trims: array of TTrim;
    Extends: array of TExtend;
    // fillet arc (skArc): lines FA / FB it rounds and the side of each line that is kept
    // (+1 / -1 along P0->P1, seen from the corner); the geometry is derived (UpdateFillets)
    FA, FB, FSA, FSB: Integer;
    // chamfer (a line with FA > 0): distances from the corner along the two lines
    CD1, CD2: Double;
    // offset copy: source shape and signed distance (normal convention: see OffsetPoints);
    // the geometry is derived from the source (UpdateOffsets)
    OffSrc: Integer;
    OffDist: Double;
    // mirror copy: source shape and axis line; geometry derived (UpdateMirrors)
    MirSrc, MirAxis: Integer;
    // array copy: owning array and index (1..N-1; the source is item 0)
    ArrId, ArrK: Integer;
    // lines: end shortened (or prolonged) to the tangent point of a fillet; derived, not stored
    CutOn: array[0..1] of Boolean;
    CutPt: array[0..1] of TPt;
    Kind: TShapeKind;
    P: TPtArray;
    RX, RY: Double;          // ellipse / arc
    Corner: Double;          // rectangle: radius of the rounded corners (0: square corners)
    GroupId: Integer;        // > 0: the shapes with the same number are one object (moved and resized together)
    GroupName: string;       // the name of the group (the SVG snippet it comes from); shown in the tree of the objects
    GroupRot: Double;        // the group has been turned by this angle: its box (and its resize handles) turn with it
    Rot: Double;             // rectangle, ellipse, arc, text, path, image: turned by this angle about ShapePivot (radians, counter-clockwise on screen)
    Snip: string;            // one shape of a group made from a snippet with parameters keeps here how it was made (see ttsnip)
    A1, A2: Double;          // arc, parametric angles (radians)
    Circ: Boolean;           // ellipse/arc forced to RY = RX
    Text: string;
    FontSize: Double;
    FontName: string;        // the family of the font of a text; empty: the default one of the system
    PathData: string;        // skPath: raw SVG "d" (P[0] is the translation)
    // paint bucket (skPath): the area around a seed point, bounded by the shapes in BucketIds
    SplineClosed: Boolean;           // skSpline: closed curve (the last point joins the first)
    RingStarts: array of Integer;    // skSpline: index of the first point of the 2nd, 3rd... closed curve (holes)
    BucketLoops: TFLoopArray;        // fill: the loops of the area (outer boundary, holes), not saved
    Bucket: Boolean;
    Antialias: Boolean;              // smooth edges (on screen, in PNG and in a raster PDF)
    GradOn: Boolean;                 // the fill goes from Style.Fill to GradColor along the reference line / path
    GradColor: Integer;              // the second colour
    GradTr: Integer;                 // its transparency 0..255 (the first one's is Style.FillTr)
    GradMid: TGradStops;             // the stops between the first and the last colour, by position
    GradRadial: Boolean;             // radial instead of linear: the reference gives the centre and the radius
    GradRef: Integer;                // id of the reference line or path (0: left to right)
    BucketOffset: Double;            // fill: how far it goes under the lines that bound it (negative: stays away from them)
    BucketIgnoreLower: Boolean;      // the area is not bounded by shapes of the layers under its own
    BucketU, BucketV: Double;        // seed as fractions of the bounding box of the boundary shapes
    BucketSX, BucketSY: Double;      // seed in absolute coordinates (last good one)
    BucketIds: array of Integer;
    BucketBroken: Boolean;           // the area cannot be found any more (not saved)
    // airbrush (skSpline): the dots are made along the curve, from these values
    LayerId: Integer;                // layer the shape belongs to
    Spray: Boolean;
    SprayR, SprayDot, SprayDens: Double;
    SpraySeed: Integer;
    Locked: Boolean;                 // the object cannot be selected nor changed
    Hidden: Boolean;                 // the object is not shown (nor can it be picked)
    Reg: Boolean;                    // a regular polygon: its corners are on a circle, evenly spaced (the first one sets the circle)
    // selection (an object that marks an area of a picture): the picture it is on (0: not a selection), whether the picture is
    // transparent inside it, the tolerance of the magic wand that made it (percent) and where the wand was clicked (fractions
    // of the picture; SelWand: it comes from a click, so the tolerance can redo it)
    SelTarget: Integer;
    SelHole: Boolean;
    SelSub: Boolean;
    SelBase: Boolean;                // the selection that covers the whole picture, under all the others (made by Invert selection)
    SelTol: Integer;
    SelU, SelV: Double;
    SelWand: Boolean;
    ShOn: Boolean;                   // a drop shadow: the shape's own shape, moved by (ShDX, ShDY), blurred (ShBlur = standard deviation)
    ShDX, ShDY, ShBlur: Double;
    ShColor: Integer;
    ShTr: Integer;                   // its transparency 0..255
    Soft: Integer;                   // soft edges of the stroke (0..100): the opacity fades from the axis to the edges
    // hatching of a fill (see HatchNames in TTFill)
    HatchPat: Integer;
    HatchSp, HatchAng, HatchW: Double;
    HatchColor: Integer;
    BucketSeeds: TFPtArray;          // sample points inside the area (not saved): they vote for the area
    BucketSeedUV: TFPtArray;         // the same, as fractions of the bounding box of the boundaries
    ImageData: string;       // skImage: PNG, base64
    KeyOn: Boolean;          // skImage: one colour (and the similar ones) is made transparent; ImageData is the result
    KeyColor: Integer;       // that colour
    KeyTol: Integer;         // how similar (percent)
    KeyOrig: string;         // the picture before the colour was removed (PNG, base64): empty when KeyOn is False
    Style: TStyle;
    IsRef: Boolean;
    W: array of Double;      // solver weights per point
    WR: Double;              // solver weight of the radii
    Flat: array of TPtArray; // skPath: flattened sub-paths
    FlatClosed: array of Boolean;   // skPath: the sub-path ended with Z
    Cache: TObject;          // owned by the GUI (decoded image)
    PN: TPathNodes;          // skPath: the editable form of PathData (made when needed, see EnsureNodes)
    PNSrc: string;           // the PathData PN comes from
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Src: TShape);
    procedure Translate(dx, dy: Double);
    procedure ParsePath;
    procedure EnsureNodes;
    // the points of the path (local coordinates, without the translation P[0]): ctl = a control point of a curve, anc = the
    // index of the point it belongs to
    procedure PathHandles(out xs, ys: TDblArr; out ctl: TBoolDyn; out anc: TIntDyn);
    procedure MovePathPoint(k: Integer; x, y: Double);
    procedure MovePathPoints(const ks: array of Integer; dx, dy: Double);
    function RemovePathPoints(const ks: array of Integer; out err: string): Boolean;
  end;

  TConstraintKind = (ckFixed, ckHorizontal, ckVertical, ckParallel,
    ckPerpendicular, ckEqual, ckCoaxial, ckCoradial, ckMidPoint,
    ckIntersection, ckTangent, ckSymmetry, ckDistance, ckRadius, ckAngle, ckOnCurve);

  TQuoteSeg = record
    A, B: TPt;
    Dotted: Boolean;
  end;

  // drawing primitives of a quote (document coordinates)
  TQuoteGeom = record
    Segs: array of TQuoteSeg;
    Arc: TPtArray;               // polyline of an angular quote
    Heads: array of TPtArray;    // filled arrow heads (triangles)
    Text: string;
    TextPos: TPt;                // centre of the label
  end;

  TRef = record
    Shape: Integer;
    Idx: Integer;            // >=0 point, -1 whole shape, >=SegBase segment
    Seg: Integer;            // GUI hint only (segment under the cursor)
  end;
  TRefArray = array of TRef;

  TConstraint = class
  public
    Id: Integer;
    Kind: TConstraintKind;
    Refs: TRefArray;
    Value: Double;           // quotes: driving value
    Aux: Double;             // quotes: side/sign; tangent: 1 = internal
    Axis: Integer;           // distance quote: 0 aligned, 1 horizontal, 2 vertical
    Diam: Boolean;           // radius quote shown as diameter
    Offset: Double;          // quote label position
    NoPrint: Boolean;        // quote: not drawn in print / PDF / PNG export
    UnitText: string;        // quote: text after the number (mm, ft...)
    function IsQuote: Boolean;
  end;

  TPR = record
    S: TShape;
    I: Integer;
  end;

  // Point map of a derived copy: 1 = reflection on a line, 2 = translation, 3 = rotation
  TXf = record
    Mode: Integer;
    A, U: TPt;               // reflection: point of the axis, unit direction
    DX, DY: Double;          // translation
    C: TPt;                  // rotation: center
    Cs, Sn: Double;          // rotation: cosine / sine
  end;

  // Associative array (linked copies of a source shape).  Copies are real shapes
  // (ArrId / ArrK) whose geometry, style and number are derived from the source.
  TArraySpec = class
  public
    Id, Src: Integer;
    Polar: Boolean;
    Cols, Rows: Integer;     // rectangular
    DX, DY: Double;          // rectangular: step between columns / rows
    Count: Integer;          // polar: number of items (source included)
    CX, CY: Double;          // polar: center
    Total: Double;           // polar: angle covered, degrees
    Freed: array of Integer; // items (ArrK) made independent: they are not made again
    function N: Integer;
    function IsFreed(k: Integer): Boolean;
  end;

  TShapeArray = array of TShape;
  TLayer = class
  public
    Id: Integer;
    Name: string;
    Visible: Boolean;
    Locked: Boolean;
    HideRefs: Boolean;       // the reference figures of the layer are not shown (nor can they be picked)
    HideCons: Boolean;       // the tags of the constraints of the objects of the layer are not shown
    // the light on the materials of the layer: where it comes from (compass: 0 = from the top, 90 = from the right), how high above
    // the page (degrees), how much the beam spreads (degrees) and its dominant colour
    LightAz, LightEl, LightDiv, LightPower: Double;     // LightPower: 1 = as made
    LightTint: Integer;
    Opacity: Integer;        // 0..255 (255: opaque)
    Scale: Double;           // real units per document unit: the lengths of the quotes are multiplied by it
    Bg: Integer;             // colour of the background of the layer (the whole page, under its objects); NoColor: none
    // a filter layer shows the layers under it through a raster filter (a script, see TTScript); only reference objects
    // can be drawn in it
    IsFilter: Boolean;
    FName: string;           // the name of the filter
    FScript: string;         // its program; empty: no filter chosen yet
    FVals: array of Double;  // the values of its parameters
    FFeather: Double;        // the effect fades towards the outer borders of its domain over this many pixels (0: it does not)
    FFeatherIn: Double;      // the same towards the borders of the holes inside its domain
    constructor Create;
  end;

  TShapeList = specialize TFPGObjectList<TShape>;
  TLayerList = specialize TFPGObjectList<TLayer>;
  TArrayList = specialize TFPGObjectList<TArraySpec>;
  TConstraintList = specialize TFPGObjectList<TConstraint>;

  { TDoc }

  TGeomSnap = record             // the geometry of all the shapes at a moment (to go back to it)
    P: array of TPtArray;
    RX, RY, A1, A2: array of Double;
  end;

  TDoc = class
  public
    // the materials of the palette: what has been set in each of them (see TTMat); every object that uses one follows it
    Mats: array[0..MaterialCount - 1] of TMatParams;
    procedure ResetMats;
  private
    FMove: Double;
    FHasDerived: Boolean;
    FMvPt: array of array of Boolean;   // what the solver may move in a stage (see SolveMinimal)
    FMvR: array of Boolean;
    FSeedPt: array of array of Boolean;
    FSeedR: array of Boolean;
    FGeomKeep: TGeomSnap;
    FSeedActive: Boolean;      // the points the user holds count more than the ones that have to follow them
    FBucketHash: QWord;
    FBucketBusy: Boolean;
    procedure Note(d: Double);
    procedure MvClear;
    procedure MvMark(const r: TRef; seed: Boolean);
    function MvHas(const r: TRef): Boolean;
    procedure MvClose(stage: Integer);
    procedure MvWeights;
    procedure RunPasses(iter: Integer);
    function Residual: Double;
    function SolveMinimal(const drag: array of TRef; iter: Integer): Boolean;
    procedure Shift2(const a, b: TPR; dx, dy: Double);
    procedure RotateSeg(const a, b: TPR; ang: Double);
    procedure OnLine(const ps: array of TPR; const cs: array of Double;
      const la, lb: TPR; off: Double);
    procedure ShiftR(s1, s2: TShape; useY: Boolean);
    procedure PairDist(const a, b: TPR; c: TConstraint);
    procedure SolveOne(c: TConstraint);
    procedure SolveSymmetry(c: TConstraint);
    procedure SolveTangent(c: TConstraint);
    procedure SolveMid(c: TConstraint);
    procedure SolveDistance(c: TConstraint);
    procedure SolveAngle(c: TConstraint);
    procedure SolveOnCurve(c: TConstraint);
    function CoincideVirtual(const ra, rb: TRef): Boolean;
    function VirtualOnLine(const rp, rl: TRef): Boolean;
    procedure PrepareWeights(const drag: array of TRef);
    procedure EnsureRect(s: TShape);
    procedure ProjectRect(s: TShape);
    procedure ProjectRegular(s: TShape);
    procedure ProjectRegulars;
    procedure Normalize;
  public
    Width, Height: Integer;
    NextId: Integer;
    Shapes: TShapeList;
    Layers: TLayerList;           // from the bottom to the top
    NextLayerId: Integer;
    ActiveLayer: Integer;         // id of the layer new shapes go to
    Cons: TConstraintList;
    Arrays: TArrayList;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function FindLayer(id: Integer): TLayer;
    function LayerOf(s: TShape): TLayer;
    function AddLayer(const aName: string): TLayer;
    procedure EnsureLayers;
    function ShapeVisible(s: TShape): Boolean;
    function ShapeLocked(s: TShape): Boolean;
    function DrawOrder: TShapeArray;
    function EffectiveTr(s: TShape; fill: Boolean): Integer;
    function HasAlpha: Boolean;
    function HasFilter: Boolean;
    procedure EnforceFilterRefs;
    function QuoteScale(c: TConstraint): Double;
    function GradientLine(s: TShape): TGradLine;
    function FindShape(id: Integer): TShape;
    function AddShape(s: TShape): TShape;
    procedure DeleteShape(s: TShape);
    procedure DeleteConstraint(c: TConstraint);
    procedure Solve(const drag: array of TRef; iter: Integer = 80);
    procedure GeomKeep;                      // remember the present geometry
    procedure GeomBack;                      // go back to the remembered geometry
    function ConstraintsResidual: Double;    // how far the constraints are from being satisfied (0: all satisfied)
    procedure SolveNew(c: TConstraint);
    function ConstraintError(c: TConstraint): Double;
    function CheckConsistency(out msg: string): Boolean;
    function PointOf(const r: TRef; out p: TPR): Boolean;
    function SegOf(const r: TRef; out a, b: TPR): Boolean;
    function ArcEndOf(const r: TRef; out s: TShape; out pt: TPt): Boolean;
    function MovablePoint(const r: TRef; out mover: TPR; out pos: TPt): Boolean;
    function EllOf(const r: TRef): TShape;
    function CheckConstraint(kind: TConstraintKind; const refs: TRefArray): string;
    function AddConstraint(kind: TConstraintKind; const refs: TRefArray;
      out err: string): TConstraint;
    procedure InitQuote(c: TConstraint);
    function ConstraintsOf(shapeId: Integer): TConstraintList;
    function IsPinned(shapeId, idx: Integer): Boolean;
    function ConstraintAnchor(c: TConstraint): TPt;
    function AddTrim(s: TShape; x, y: Double; out err: string): Boolean;
    function ClosePolyline(s: TShape; out err: string): Boolean;
    function RemoveSplinePoint(s: TShape; idx: Integer; out dropped: Integer; out err: string): Boolean;
    function InsertSplinePoint(s: TShape; x, y: Double; out newIdx: Integer; out err: string): Boolean;
    function SuggestRoundRectPoints(s: TShape; asPath: Boolean): Integer;
    function SuggestFillPoints(b: TShape; asPath: Boolean; out hasHoles: Boolean; out total: Integer): Integer;
    function ConvertBucket(b: TShape; count: Integer; asPath: Boolean; out err: string): Boolean;
    function PathPointTotal(s: TShape): Integer;
    function PathOutlines(s: TShape): Integer;
    function ConvertPath(s: TShape; pointCount: Integer; out dropped: Integer; out err: string): Boolean;
    function ConvertShape(s: TShape; pointCount: Integer; out dropped: Integer; out err: string;
      asPath: Boolean = False): Boolean;
    function ConvertShapeCore(s: TShape; pointCount: Integer; out dropped: Integer; out err: string;
      asPath: Boolean): Boolean;
    function JoinShapes(a, b: TShape; out dropped: Integer; out gap: Double; out err: string): Boolean;
    function CloseSpline(s: TShape; drop, keep: Integer; out err: string): Boolean;
    function RemoveVertex(s: TShape; idx: Integer; out dropped: Integer; out err: string): Boolean;
    function InsertVertex(s: TShape; x, y: Double; out newIdx, dropped: Integer; out err: string): Boolean;
    function QuoteEnds(c: TConstraint; out a, b: TPt): Boolean;
    function QuoteGeometry(c: TConstraint; z: Double; out g: TQuoteGeom): Boolean;
    function QuoteAngle(c: TConstraint; out V: TPt; out a1, sweep: Double): Boolean;
    function NearestU(s: TShape; x, y: Double; out poly: Integer; out u: Double): Boolean;
    function AddBreak(s: TShape; poly: Integer; u1, u2: Double; out err: string): Boolean;
    function VisibleOutline(s: TShape; out o: TOutline): Boolean;
    function EffectiveOutline(s: TShape; out o: TOutline): Boolean;
    function AddExtend(s: TShape; x, y: Double; out err: string): Boolean;
    procedure UpdateFillets;
    procedure UpdateBuckets;
    function AddBucket(x, y: Double; color: Integer; out err: string): TShape;
    function BrokenBuckets: TShapeArray;
    procedure UpdateOffsets;
    procedure UpdateMirrors;
    procedure UpdateArrays;
    function ArrayOf(s: TShape): TArraySpec;
    function ParentOf(s: TShape): TShape;
    function DetachCopy(s: TShape): Boolean;
    function ArrayById(id: Integer): TArraySpec;
    function AddArray(src: TShape; polar: Boolean; cols, rows: Integer; dx, dy: Double;
      count: Integer; cx, cy, total: Double; out err: string): TArraySpec;
    procedure ExplodeArray(id: Integer);
    function CopyXf(s: TShape; out src: TShape; out m: TXf): Boolean;
    function NewGroupId: Integer;
    procedure StretchShapes(const ids: array of Integer; bx, by, sx, sy: Double; keepWidth: Boolean = False);
    // uniform scale of the given shapes about (bx, by); returns the number of shapes changed
    function ScaleShapes(const ids: array of Integer; bx, by, k: Double): Integer;
    // rotation about (bx, by), ang in radians, positive = counter-clockwise on screen
    function RotateShapes(const ids: array of Integer; bx, by, ang: Double;
      out skipped, dropped, converted: Integer): Integer;
    // shear about (bx, by): x grows by kx * (y - by), y by ky * (x - bx); rectangles / ellipses become polygons / paths (shapes with a turn, texts, arcs and pictures are skipped)
    function SkewShapes(const ids: array of Integer; bx, by, kx, ky: Double): Integer;
    function AddMirror(src, axis: TShape; out err: string): TShape;
    function MirrorFrame(s: TShape; out a, u: TPt): Boolean;
    function AddOffset(src: TShape; x, y, dist: Double; out err: string): TShape;
    function AddFillet(a, b: TShape; ax, ay, bx, by, r: Double; out err: string): TShape;
    function AddChamfer(a, b: TShape; ax, ay, bx, by, d1, d2: Double; out err: string): TShape;
    function FilletRadiusAt(f: TShape; px, py: Double; out r: Double): Boolean;
    function OffsetFactor(src: TShape): Double;
    function AddOffsetSigned(src: TShape; dist: Double; out err: string): TShape;
    function CutCorner(s: TShape; v: Integer; chamfer: Boolean; r1, r2: Double; out err: string): Boolean;
  private
    function TrimGap(s: TShape; const t: TTrim; const pl: TPolyline;
      out lo, hi: Double): Boolean;
  end;

const
  ConstraintNames: array[TConstraintKind] of string = ('fixed', 'horizontal',
    'vertical', 'parallel', 'perpendicular', 'equal', 'coaxial', 'coradial',
    'midpoint', 'intersection', 'tangent', 'symmetry', 'distance', 'radius', 'angle', 'oncurve');
  ShapeNames: array[TShapeKind] of string = ('line', 'arrow', 'polyline',
    'polygon', 'rect', 'ellipse', 'arc', 'spline', 'text', 'path', 'image');

function MakePt(ax, ay: Double): TPt; inline;
function RegularPoints(const c, v0: TPt; n: Integer): TPtArray;
function RegularCenter(const pts: TPtArray): TPt;
function MakeRef(shape, idx: Integer; seg: Integer = -1): TRef;
function SameRef(const a, b: TRef): Boolean;
function DefaultStyle: TStyle;
// the material of the stroke / of the fill of a style (1..MaterialCount), 0 when it is a plain colour
function StrokeMaterial(const st: TStyle): Integer;
function FillMaterial(const st: TStyle): Integer;
function ShapeOutline(s: TShape): TOutline;
function InsideOutline(const o: TOutline; x, y: Double): Boolean;
// the kinds that keep their own shape when turned: the stored geometry is drawn turned by Rot about ShapePivot
function RotKind(k: TShapeKind): Boolean;
function ShapePivot(s: TShape): TPt;
// a point turned about c (ang in radians, positive = counter-clockwise on screen)
function TurnPt(const p, c: TPt; ang: Double): TPt;
function NormAngle(a: Double): Double;
// a rectangle / ellipse that is turned becomes a polygon / path with the same look (Rot = 0): False when the kind cannot
function BakeRotation(s: TShape): Boolean;
function DistToOutline(const o: TOutline; x, y: Double; filled: Boolean): Double;
// boolean operations between two closed figures (rectangle, ellipse, polygon, closed curve or path): the result is a path.
// op: 0 intersection, 1 union, 2 difference (a minus b)
function BoolEligible(s: TShape): Boolean;
procedure ResizeLoops(var lps: TPtLoops; want: Integer);
function BoolOverlap(a, b: TShape): Boolean;
function BoolCompute(a, b: TShape; op: Integer; out pathData: string; out err: string): Boolean;
function DistToSegment(px, py, ax, ay, bx, by: Double): Double;
function TrimmableKind(k: TShapeKind): Boolean;
function ArrowHead(const a, b: TPt; width: Double): TPtArray;
procedure SplineBezier(const pts: TPtArray; var c1, c2: TPtArray; closed: Boolean = False);
function PointCountOf(k: TShapeKind): Integer;
function IsClosedKind(k: TShapeKind): Boolean;
function CornerOf(s: TShape): Double;
function RoundRectPoints(s: TShape; count: Integer; evenly: Boolean = False): TPtArray;
function ArcSweep(s: TShape): Double;
function ScalePathData(const d: string; k: Double): string;
function ScalePathDataXY(const d: string; kx, ky: Double): string;
// turns the path about its own origin (the angle as in RotateShapes); horizontal, vertical and arc segments become lines
function RotatePathData(const d: string; ang: Double): string;
// every point (x, y) of the path goes to (m11 x + m12 y, m21 x + m22 y); horizontal, vertical and arc segments become lines
function AffinePathData(const d: string; m11, m12, m21, m22: Double): string;
function BucketHatch(s: TShape): TFPtArray;
function Hatchable(s: TShape): Boolean;
procedure SplineRings(s: TShape; out lo, hi: TRingArr);
function GradientT(const g: TGradLine; x, y: Double): Double;
procedure GradientMix(s: TShape; t: Double; out col, opacity: Integer);
function SprayDots(s: TShape): TSprayDotArray;

implementation

var
  MFS: TFormatSettings;   // '.' decimal separator whatever the locale

function MakePt(ax, ay: Double): TPt;
begin
  Result.x := ax;
  Result.y := ay;
end;

function MakeRef(shape, idx: Integer; seg: Integer): TRef;
begin
  Result.Shape := shape;
  Result.Idx := idx;
  Result.Seg := seg;
end;

function SameRef(const a, b: TRef): Boolean;
begin
  Result := (a.Shape = b.Shape) and (a.Idx = b.Idx);
end;

function DefaultStyle: TStyle;
begin
  Result.Stroke := 0;
  Result.Fill := NoColor;
  Result.Width := 2;
  Result.Cap := lcRound;
  Result.Join := ljRound;
  Result.Dash := dsSolid;
  Result.StrokeTr := 0;
  Result.FillTr := 0;
  Result.StrokeMatId := 0;
  Result.FillMatId := 0;
end;

function StrokeMaterial(const st: TStyle): Integer;
begin
  Result := 0;
  if (st.StrokeMatId >= 1) and (st.StrokeMatId <= MaterialCount) and (st.Stroke = MaterialAvg(st.StrokeMatId - 1)) then
    Result := st.StrokeMatId;
end;

function FillMaterial(const st: TStyle): Integer;
begin
  Result := 0;
  if (st.FillMatId >= 1) and (st.FillMatId <= MaterialCount) and (st.Fill = MaterialAvg(st.FillMatId - 1)) then
    Result := st.FillMatId;
end;

function PointCountOf(k: TShapeKind): Integer;
begin
  case k of
    skLine, skArrow, skRect, skImage: Result := 2;
    skEllipse, skArc, skText, skPath: Result := 1;
  else
    Result := 0;
  end;
end;

function IsClosedKind(k: TShapeKind): Boolean;
begin
  Result := k in [skPolygon, skRect, skEllipse];
end;

function CornerOf(s: TShape): Double;
begin
  Result := 0;
  if (s.Kind <> skRect) or (s.Corner <= 0) or (Length(s.P) < 2) then Exit;
  Result := Min(s.Corner, Min(Abs(s.P[1].x - s.P[0].x), Abs(s.P[1].y - s.P[0].y)) / 2);
  if Result < 1e-9 then Result := 0;
end;

// the outline of a rectangle with rounded corners as count points: a quarter of a circle (at least its
// two ends) at each corner, clockwise from the top right one
function RoundRectPoints(s: TShape; count: Integer; evenly: Boolean): TPtArray;
var
  r, x1, y1, x2, y2, cx, cy, a, wS, hS, aL, per, t, u: Double;
  n, k, i, c, m: Integer;
  p: TPt;
begin
  SetLength(Result, 0);
  r := CornerOf(s);
  if r <= 0 then Exit;
  x1 := Min(s.P[0].x, s.P[1].x);
  x2 := Max(s.P[0].x, s.P[1].x);
  y1 := Min(s.P[0].y, s.P[1].y);
  y2 := Max(s.P[0].y, s.P[1].y);
  n := Max(8, count);
  if evenly then
  begin
    // equal steps along the outline: the smooth curve through them behaves well (it overshoots when
    // short and long spans follow each other)
    wS := x2 - x1 - 2 * r;
    hS := y2 - y1 - 2 * r;
    aL := Pi * r / 2;
    per := 2 * wS + 2 * hS + 4 * aL;
    SetLength(Result, n);
    for i := 0 to n - 1 do
    begin
      t := per * i / n;
      // pieces from the start of the top side: top, corner, right, corner, bottom, corner, left, corner
      if t < wS then Result[i] := MakePt(x1 + r + t, y1)
      else
      begin
        t := t - wS;
        if t < aL then begin u := -Pi / 2 + t / r; Result[i] := MakePt(x2 - r + r * Cos(u), y1 + r + r * Sin(u)); end
        else
        begin
          t := t - aL;
          if t < hS then Result[i] := MakePt(x2, y1 + r + t)
          else
          begin
            t := t - hS;
            if t < aL then begin u := t / r; Result[i] := MakePt(x2 - r + r * Cos(u), y2 - r + r * Sin(u)); end
            else
            begin
              t := t - aL;
              if t < wS then Result[i] := MakePt(x2 - r - t, y2)
              else
              begin
                t := t - wS;
                if t < aL then begin u := Pi / 2 + t / r; Result[i] := MakePt(x1 + r + r * Cos(u), y2 - r + r * Sin(u)); end
                else
                begin
                  t := t - aL;
                  if t < hS then Result[i] := MakePt(x1, y2 - r - t)
                  else
                  begin
                    t := t - hS;
                    u := Pi + t / r;
                    Result[i] := MakePt(x1 + r + r * Cos(u), y1 + r + r * Sin(u));
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
    Exit;
  end;
  for k := 0 to 3 do
  begin
    c := n div 4;
    if k < n mod 4 then Inc(c);
    case k of
      0: begin cx := x2 - r; cy := y1 + r; end;
      1: begin cx := x2 - r; cy := y2 - r; end;
      2: begin cx := x1 + r; cy := y2 - r; end;
    else
      begin cx := x1 + r; cy := y1 + r; end;
    end;
    for i := 0 to c - 1 do
    begin
      a := (k - 1) * Pi / 2 + i * (Pi / 2) / (c - 1);
      p := MakePt(cx + r * Cos(a), cy + r * Sin(a));
      m := Length(Result);
      // the ends of two corners meet when the side is all rounded: one point only
      if (m > 0) and (Hypot(p.x - Result[m - 1].x, p.y - Result[m - 1].y) < 1e-9) then Continue;
      SetLength(Result, m + 1);
      Result[m] := p;
    end;
  end;
  m := Length(Result);
  if (m > 1) and (Hypot(Result[0].x - Result[m - 1].x, Result[0].y - Result[m - 1].y) < 1e-9) then
    SetLength(Result, m - 1);
end;

function ArcSweep(s: TShape): Double;
begin
  Result := s.A2 - s.A1;
  while Result <= 0 do Result := Result + 2 * Pi;
  while Result > 2 * Pi do Result := Result - 2 * Pi;
end;

{ ---------- geometry ---------- }

function DistToSegment(px, py, ax, ay, bx, by: Double): Double;
var
  dx, dy, t, l2: Double;
begin
  dx := bx - ax;
  dy := by - ay;
  l2 := dx * dx + dy * dy;
  if l2 < 1e-12 then
    Exit(Hypot(px - ax, py - ay));
  t := ((px - ax) * dx + (py - ay) * dy) / l2;
  if t < 0 then t := 0;
  if t > 1 then t := 1;
  Result := Hypot(px - (ax + t * dx), py - (ay + t * dy));
end;

function ArrowHead(const a, b: TPt; width: Double): TPtArray;
var
  L, ux, uy, hl, hw: Double;
begin
  SetLength(Result, 3);
  L := Hypot(b.x - a.x, b.y - a.y);
  if L < 1e-9 then
  begin
    Result[0] := b; Result[1] := b; Result[2] := b;
    Exit;
  end;
  ux := (b.x - a.x) / L;
  uy := (b.y - a.y) / L;
  hl := Max(10, width * 4);
  hw := hl * 0.4;
  Result[0] := b;
  Result[1] := MakePt(b.x - ux * hl - uy * hw, b.y - uy * hl + ux * hw);
  Result[2] := MakePt(b.x - ux * hl + uy * hw, b.y - uy * hl - ux * hw);
end;

procedure SplineBezier(const pts: TPtArray; var c1, c2: TPtArray; closed: Boolean);
var
  i, n, m: Integer;
  p0, p1, p2, p3: TPt;
begin
  n := Length(pts);
  if closed and (n >= 3) then m := n else m := Max(0, n - 1);
  SetLength(c1, m);
  SetLength(c2, m);
  for i := 0 to m - 1 do
  begin
    p1 := pts[i];
    p2 := pts[(i + 1) mod n];
    if closed and (n >= 3) then
    begin
      p0 := pts[(i + n - 1) mod n];
      p3 := pts[(i + 2) mod n];
    end
    else
    begin
      if i > 0 then p0 := pts[i - 1] else p0 := p1;
      if i + 2 < n then p3 := pts[i + 2] else p3 := p2;
    end;
    c1[i] := MakePt(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6);
    c2[i] := MakePt(p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6);
  end;
end;

procedure AddPt(var a: TPtArray; x, y: Double);
begin
  SetLength(a, Length(a) + 1);
  a[High(a)].x := x;
  a[High(a)].y := y;
end;

function SingleLine(const pts: TPtArray; closed: Boolean): TOutline;
begin
  SetLength(Result, 1);
  Result[0].Pts := pts;
  Result[0].Closed := closed;
end;

// the point ranges of the closed curves that make a spline: the outline, then its holes
procedure SplineRings(s: TShape; out lo, hi: TRingArr);
var
  k, n: Integer;
begin
  n := Length(s.RingStarts) + 1;
  if (not s.SplineClosed) or (Length(s.RingStarts) = 0) then
  begin
    SetLength(lo, 1);
    SetLength(hi, 1);
    lo[0] := 0;
    hi[0] := High(s.P);
    Exit;
  end;
  SetLength(lo, n);
  SetLength(hi, n);
  for k := 0 to n - 1 do
  begin
    if k = 0 then lo[k] := 0 else lo[k] := s.RingStarts[k - 1];
    if k = n - 1 then hi[k] := High(s.P) else hi[k] := s.RingStarts[k] - 1;
  end;
end;

function ShapeOutlineLocal(s: TShape): TOutline;
var
  pts, c1, c2, rp: TPtArray;
  rlo, rhi: TRingArr;
  rclosed: Boolean;
  i, k, n, j: Integer;
  t, d, a, x, y, px, py: Double;
begin
  SetLength(Result, 0);
  pts := nil;
  case s.Kind of
    skLine, skArrow:
      if Length(s.P) >= 2 then Result := SingleLine(s.P, False);
    skPolyline:
      if Length(s.P) = 1 then
      begin
        // a single point (a reference point) has no extent: it is shown as a small cross
        SetLength(Result, 2);
        SetLength(Result[0].Pts, 2);
        SetLength(Result[1].Pts, 2);
        Result[0].Closed := False;
        Result[1].Closed := False;
        Result[0].Pts[0] := MakePt(s.P[0].x - 5, s.P[0].y);
        Result[0].Pts[1] := MakePt(s.P[0].x + 5, s.P[0].y);
        Result[1].Pts[0] := MakePt(s.P[0].x, s.P[0].y - 5);
        Result[1].Pts[1] := MakePt(s.P[0].x, s.P[0].y + 5);
      end
      else Result := SingleLine(s.P, False);
    skPolygon: Result := SingleLine(s.P, True);
    skRect:
      if Length(s.P) >= 2 then
      begin
        d := CornerOf(s);
        if d <= 1e-9 then
        begin
          AddPt(pts, s.P[0].x, s.P[0].y);
          AddPt(pts, s.P[1].x, s.P[0].y);
          AddPt(pts, s.P[1].x, s.P[1].y);
          AddPt(pts, s.P[0].x, s.P[1].y);
        end
        else
        begin
          // rounded corners: a quarter of a circle at each one, clockwise from the top right
          t := Min(s.P[0].x, s.P[1].x);
          x := Max(s.P[0].x, s.P[1].x);
          a := Min(s.P[0].y, s.P[1].y);
          y := Max(s.P[0].y, s.P[1].y);
          n := Max(4, Min(24, Ceil(d * 0.5)));
          for k := 0 to 3 do
            for i := 0 to n do
            begin
              case k of
                0: begin px := x - d; py := a + d; end;
                1: begin px := x - d; py := y - d; end;
                2: begin px := t + d; py := y - d; end;
              else
                begin px := t + d; py := a + d; end;
              end;
              AddPt(pts, px + d * Cos((k - 1) * Pi / 2 + i * Pi / 2 / n), py + d * Sin((k - 1) * Pi / 2 + i * Pi / 2 / n));
            end;
        end;
        Result := SingleLine(pts, True);
      end;
    skEllipse, skArc:
      if Length(s.P) >= 1 then
      begin
        n := Max(24, Min(180, Round((s.RX + s.RY) * 0.8)));
        if s.Kind = skArc then d := ArcSweep(s) else d := 2 * Pi;
        if s.Kind = skArc then k := n else k := n - 1;
        for i := 0 to k do
        begin
          if s.Kind = skArc then a := s.A1 + d * i / n
          else a := d * i / n;
          AddPt(pts, s.P[0].x + s.RX * Cos(a), s.P[0].y + s.RY * Sin(a));
        end;
        Result := SingleLine(pts, s.Kind = skEllipse);
      end;
    skSpline:
      if Length(s.P) >= 2 then
      begin
        SplineRings(s, rlo, rhi);
        SetLength(Result, 0);
        for k := 0 to High(rlo) do
        begin
          // the points of this closed curve (or of the whole open one)
          SetLength(rp, rhi[k] - rlo[k] + 1);
          for i := 0 to High(rp) do rp[i] := s.P[rlo[k] + i];
          if Length(rp) < 2 then Continue;
          rclosed := s.SplineClosed and (Length(rp) >= 3);
          SplineBezier(rp, c1, c2, rclosed);
          SetLength(pts, 0);
          AddPt(pts, rp[0].x, rp[0].y);
          for i := 0 to High(c1) do
            for j := 1 to 12 do
            begin
              t := j / 12;
              x := Power(1 - t, 3) * rp[i].x + 3 * Sqr(1 - t) * t * c1[i].x +
                3 * (1 - t) * t * t * c2[i].x + t * t * t * rp[(i + 1) mod Length(rp)].x;
              y := Power(1 - t, 3) * rp[i].y + 3 * Sqr(1 - t) * t * c1[i].y +
                3 * (1 - t) * t * t * c2[i].y + t * t * t * rp[(i + 1) mod Length(rp)].y;
              AddPt(pts, x, y);
            end;
          // a closed curve ends where it started: that last point is the first one again
          if rclosed then SetLength(pts, Length(pts) - 1);
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)].Pts := Copy(pts);
          Result[High(Result)].Closed := rclosed;
        end;
      end;
    skText:
      if Length(s.P) >= 1 then
      begin
        x := s.P[0].x;
        y := s.P[0].y;
        d := Max(1, Length(s.Text)) * s.FontSize * 0.6;
        AddPt(pts, x, y);
        AddPt(pts, x + d, y);
        AddPt(pts, x + d, y + s.FontSize * 1.2);
        AddPt(pts, x, y + s.FontSize * 1.2);
        Result := SingleLine(pts, True);
      end;
    skImage:
      if Length(s.P) >= 2 then
      begin
        AddPt(pts, s.P[0].x, s.P[0].y);
        AddPt(pts, s.P[1].x, s.P[0].y);
        AddPt(pts, s.P[1].x, s.P[1].y);
        AddPt(pts, s.P[0].x, s.P[1].y);
        Result := SingleLine(pts, True);
      end;
    skPath:
      if Length(s.P) >= 1 then
      begin
        SetLength(Result, Length(s.Flat));
        for i := 0 to High(s.Flat) do
        begin
          SetLength(Result[i].Pts, Length(s.Flat[i]));
          for j := 0 to High(s.Flat[i]) do
            Result[i].Pts[j] := MakePt(s.Flat[i][j].x + s.P[0].x,
              s.Flat[i][j].y + s.P[0].y);
          Result[i].Closed := s.Bucket or ((i <= High(s.FlatClosed)) and s.FlatClosed[i]);   // a fill's outline, or a sub-path ended by Z
          // a closed sub-path repeats its first point at the end: once is enough
          if Result[i].Closed and (Length(Result[i].Pts) > 3) and
             (Hypot(Result[i].Pts[0].x - Result[i].Pts[High(Result[i].Pts)].x,
                    Result[i].Pts[0].y - Result[i].Pts[High(Result[i].Pts)].y) < 1e-9) then
            SetLength(Result[i].Pts, Length(Result[i].Pts) - 1);
        end;
      end;
  end;
end;

function RotKind(k: TShapeKind): Boolean;
begin
  Result := k in [skRect, skEllipse, skArc, skText, skPath, skImage];
end;

// the point the turn is about: the centre of a rectangle / picture, the anchor point (P[0]) of the others
function ShapePivot(s: TShape): TPt;
begin
  if Length(s.P) = 0 then Exit(MakePt(0, 0));
  if (s.Kind in [skRect, skImage]) and (Length(s.P) >= 2) then
    Result := MakePt((s.P[0].x + s.P[1].x) / 2, (s.P[0].y + s.P[1].y) / 2)
  else Result := s.P[0];
end;

function TurnPt(const p, c: TPt; ang: Double): TPt;
var
  cs, sn: Double;
begin
  cs := Cos(ang);
  sn := Sin(ang);
  Result.x := c.x + (p.x - c.x) * cs + (p.y - c.y) * sn;
  Result.y := c.y - (p.x - c.x) * sn + (p.y - c.y) * cs;
end;

// the corners of a regular polygon with centre c and first corner v0
function RegularPoints(const c, v0: TPt; n: Integer): TPtArray;
var
  i: Integer;
  r, a: Double;
begin
  SetLength(Result, n);
  r := Hypot(v0.x - c.x, v0.y - c.y);
  a := ArcTan2(v0.y - c.y, v0.x - c.x);
  for i := 0 to n - 1 do
    Result[i] := MakePt(c.x + r * Cos(a + 2 * Pi * i / n), c.y + r * Sin(a + 2 * Pi * i / n));
end;

function RegularCenter(const pts: TPtArray): TPt;
var
  i: Integer;
begin
  Result := MakePt(0, 0);
  for i := 0 to High(pts) do
  begin
    Result.x := Result.x + pts[i].x / Length(pts);
    Result.y := Result.y + pts[i].y / Length(pts);
  end;
end;

function NormAngle(a: Double): Double;
begin
  Result := a - 2 * Pi * Floor((a + Pi) / (2 * Pi));
  if Abs(Result) < 1e-12 then Result := 0;
end;

function ShapeOutline(s: TShape): TOutline;
var
  i, j: Integer;
  c: TPt;
begin
  Result := ShapeOutlineLocal(s);
  if (s.Rot = 0) or not RotKind(s.Kind) or (Length(s.P) = 0) then Exit;
  c := ShapePivot(s);
  for i := 0 to High(Result) do
    for j := 0 to High(Result[i].Pts) do
      Result[i].Pts[j] := TurnPt(Result[i].Pts[j], c, s.Rot);
end;

function BakeRotation(s: TShape): Boolean;
var
  o: TOutline;
  c: TPt;
  k, rx, ry: Double;
begin
  Result := False;
  if (s.Rot = 0) or (s.Bucket) then Exit(s.Rot = 0);
  case s.Kind of
    skRect:
      begin
        o := ShapeOutline(s);
        if (Length(o) = 0) or (Length(o[0].Pts) < 3) then Exit;
        s.P := Copy(o[0].Pts);
        SetLength(s.W, 0);
        s.Kind := skPolygon;
        s.Corner := 0;
        s.Rot := 0;
        Result := True;
      end;
    skEllipse:
      begin
        c := s.P[0];
        rx := s.RX;
        ry := s.RY;
        k := 0.5523;
        s.PathData := RotatePathData(Format('M %.6f 0 C %.6f %.6f %.6f %.6f 0 %.6f C %.6f %.6f %.6f %.6f %.6f 0 ' +
          'C %.6f %.6f %.6f %.6f 0 %.6f C %.6f %.6f %.6f %.6f %.6f 0 Z',
          [rx, rx, k * ry, k * rx, ry, ry,
           -k * rx, ry, -rx, k * ry, -rx,
           -rx, -k * ry, -k * rx, -ry, -ry,
           k * rx, -ry, rx, -k * ry, rx], MFS), s.Rot);
        SetLength(s.P, 1);
        s.P[0] := c;
        s.Kind := skPath;
        s.RX := 0;
        s.RY := 0;
        s.Rot := 0;
        s.ParsePath;
        Result := True;
      end;
  end;
end;

function PointInPoly(const pts: TPtArray; x, y: Double): Boolean;
var
  i, j: Integer;
begin
  Result := False;
  j := High(pts);
  for i := 0 to High(pts) do
  begin
    if ((pts[i].y > y) <> (pts[j].y > y)) and
       (x < (pts[j].x - pts[i].x) * (y - pts[i].y) / (pts[j].y - pts[i].y) + pts[i].x) then
      Result := not Result;
    j := i;
  end;
end;

function DistToOutline(const o: TOutline; x, y: Double; filled: Boolean): Double;
var
  i, j, n, inside: Integer;
  d: Double;
begin
  Result := 1e18;
  inside := 0;
  for i := 0 to High(o) do
  begin
    n := Length(o[i].Pts);
    for j := 0 to n - 2 do
    begin
      d := DistToSegment(x, y, o[i].Pts[j].x, o[i].Pts[j].y,
        o[i].Pts[j + 1].x, o[i].Pts[j + 1].y);
      if d < Result then Result := d;
    end;
    if o[i].Closed and (n > 1) then
    begin
      d := DistToSegment(x, y, o[i].Pts[n - 1].x, o[i].Pts[n - 1].y,
        o[i].Pts[0].x, o[i].Pts[0].y);
      if d < Result then Result := d;
    end;
    if (n = 1) then Result := Min(Result, Hypot(x - o[i].Pts[0].x, y - o[i].Pts[0].y));
    if filled and o[i].Closed and PointInPoly(o[i].Pts, x, y) then Inc(inside);
  end;
  // inside an odd number of closed curves: in the area (a hole is not)
  if filled and Odd(inside) then Result := 0;
end;

{ ---------- TShape ---------- }

constructor TShape.Create;
begin
  inherited Create;
  Style := DefaultStyle;
  FontSize := 18;
  Antialias := True;
  GradColor := $FFFFFF;
  RX := 20;
  RY := 20;
  A1 := 0;
  A2 := Pi;
  WR := 1;
  HatchSp := 8;
  HatchW := 1;
  SprayR := 20;
  SprayDot := 1.5;
  SprayDens := 6;
end;

destructor TShape.Destroy;
begin
  Cache.Free;
  inherited Destroy;
end;

procedure TShape.Assign(Src: TShape);
begin
  Kind := Src.Kind;
  P := Copy(Src.P);
  RX := Src.RX;
  RY := Src.RY;
  A1 := Src.A1;
  A2 := Src.A2;
  Circ := Src.Circ;
  Text := Src.Text;
  FontSize := Src.FontSize;
  FontName := Src.FontName;
  PathData := Src.PathData;
  SplineClosed := Src.SplineClosed;
  RingStarts := Copy(Src.RingStarts);
  BucketLoops := Copy(Src.BucketLoops);
  Bucket := Src.Bucket;
  BucketIgnoreLower := Src.BucketIgnoreLower;
  BucketOffset := Src.BucketOffset;
  Corner := Src.Corner;
  Rot := Src.Rot;
  GroupRot := Src.GroupRot;
  GroupName := Src.GroupName;
  GradOn := Src.GradOn;
  Antialias := Src.Antialias;
  GradColor := Src.GradColor;
  GradTr := Src.GradTr;
  ShOn := Src.ShOn;
  ShDX := Src.ShDX;
  ShDY := Src.ShDY;
  ShBlur := Src.ShBlur;
  ShColor := Src.ShColor;
  ShTr := Src.ShTr;
  GradRef := Src.GradRef;
  GradRadial := Src.GradRadial;
  GradMid := Copy(Src.GradMid);
  BucketU := Src.BucketU;
  BucketV := Src.BucketV;
  BucketSX := Src.BucketSX;
  BucketSY := Src.BucketSY;
  BucketIds := Copy(Src.BucketIds);
  BucketBroken := Src.BucketBroken;
  LayerId := Src.LayerId;
  Spray := Src.Spray;
  SprayR := Src.SprayR;
  SprayDot := Src.SprayDot;
  SprayDens := Src.SprayDens;
  SpraySeed := Src.SpraySeed;
  Soft := Src.Soft;
  SelTarget := Src.SelTarget;
  SelHole := Src.SelHole;
  SelSub := Src.SelSub;
  SelBase := Src.SelBase;
  SelTol := Src.SelTol;
  SelU := Src.SelU;
  SelV := Src.SelV;
  SelWand := Src.SelWand;
  Locked := Src.Locked;
  Hidden := Src.Hidden;
  Reg := Src.Reg;
  HatchPat := Src.HatchPat;
  HatchSp := Src.HatchSp;
  HatchAng := Src.HatchAng;
  HatchW := Src.HatchW;
  HatchColor := Src.HatchColor;
  BucketSeeds := Copy(Src.BucketSeeds);
  BucketSeedUV := Copy(Src.BucketSeedUV);
  ImageData := Src.ImageData;
  KeyOn := Src.KeyOn;
  KeyColor := Src.KeyColor;
  KeyTol := Src.KeyTol;
  KeyOrig := Src.KeyOrig;
  Style := Src.Style;
  IsRef := Src.IsRef;
  Trims := Copy(Src.Trims);
  Extends := Copy(Src.Extends);
  FA := Src.FA;
  FB := Src.FB;
  FSA := Src.FSA;
  FSB := Src.FSB;
  CD1 := Src.CD1;
  CD2 := Src.CD2;
  OffSrc := Src.OffSrc;
  OffDist := Src.OffDist;
  MirSrc := Src.MirSrc;
  MirAxis := Src.MirAxis;
  ArrId := Src.ArrId;
  ArrK := Src.ArrK;
  if Kind = skPath then ParsePath;
end;

procedure TShape.Translate(dx, dy: Double);
var
  i: Integer;
begin
  for i := 0 to High(P) do
  begin
    P[i].x := P[i].x + dx;
    P[i].y := P[i].y + dy;
  end;
end;

type
  TArcSeg = record
    C1, C2, E: TPt;
  end;
  TArcSegs = array of TArcSeg;

// an SVG elliptical arc (from p0 to p1, radii rx ry, the ellipse turned by phi degrees) as cubic curves (at most a quarter turn each)
function ArcSegments(const p0: TPt; rx, ry, phiDeg: Double; large, sweep: Boolean; const p1: TPt): TArcSegs;
var
  phi, cp, sp, x1p, y1p, lam, num, den, coef, cxp, cyp, cx, cy, th1, dth, ux, uy, vx, vy, delta, t, a0, a1: Double;
  i, n: Integer;

  function Map(px, py: Double): TPt;
  begin
    Result.x := cx + rx * cp * px - ry * sp * py;
    Result.y := cy + rx * sp * px + ry * cp * py;
  end;

begin
  Result := nil;
  rx := Abs(rx);
  ry := Abs(ry);
  if ((p0.x = p1.x) and (p0.y = p1.y)) or (rx < 1e-9) or (ry < 1e-9) then Exit;
  phi := phiDeg * Pi / 180;
  cp := Cos(phi);
  sp := Sin(phi);
  x1p := cp * (p0.x - p1.x) / 2 + sp * (p0.y - p1.y) / 2;
  y1p := -sp * (p0.x - p1.x) / 2 + cp * (p0.y - p1.y) / 2;
  lam := Sqr(x1p) / Sqr(rx) + Sqr(y1p) / Sqr(ry);
  if lam > 1 then
  begin
    rx := rx * Sqrt(lam);
    ry := ry * Sqrt(lam);
  end;
  num := Sqr(rx) * Sqr(ry) - Sqr(rx) * Sqr(y1p) - Sqr(ry) * Sqr(x1p);
  den := Sqr(rx) * Sqr(y1p) + Sqr(ry) * Sqr(x1p);
  if den < 1e-18 then Exit;
  coef := Sqrt(Max(0, num / den));
  if large = sweep then coef := -coef;
  cxp := coef * rx * y1p / ry;
  cyp := -coef * ry * x1p / rx;
  cx := cp * cxp - sp * cyp + (p0.x + p1.x) / 2;
  cy := sp * cxp + cp * cyp + (p0.y + p1.y) / 2;
  ux := (x1p - cxp) / rx;
  uy := (y1p - cyp) / ry;
  vx := (-x1p - cxp) / rx;
  vy := (-y1p - cyp) / ry;
  th1 := ArcTan2(uy, ux);
  dth := ArcTan2(ux * vy - uy * vx, ux * vx + uy * vy);
  if (not sweep) and (dth > 0) then dth := dth - 2 * Pi
  else if sweep and (dth < 0) then dth := dth + 2 * Pi;
  n := Max(1, Ceil(Abs(dth) / (Pi / 2) - 1e-9));
  delta := dth / n;
  t := 4 / 3 * Tan(delta / 4);
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    a0 := th1 + i * delta;
    a1 := a0 + delta;
    Result[i].C1 := Map(Cos(a0) - t * Sin(a0), Sin(a0) + t * Cos(a0));
    Result[i].C2 := Map(Cos(a1) + t * Sin(a1), Sin(a1) - t * Cos(a1));
    Result[i].E := Map(Cos(a1), Sin(a1));
  end;
  // the last point is exactly the end of the arc
  Result[n - 1].E := p1;
end;

procedure TShape.ParsePath;
var
  i, n: Integer;
  cmd: Char;
  s: string;
  nums: array of Double;
  cur, start, lastC: TPt;
  sub: TPtArray;
  lastCmd: Char;
  lastQ: TPt;
  zEnd: Boolean;
  arcs: TArcSegs;
  ap: TPt;
  ai: Integer;

  procedure Flush;
  begin
    if Length(sub) > 0 then
    begin
      SetLength(Flat, Length(Flat) + 1);
      Flat[High(Flat)] := sub;
      SetLength(FlatClosed, Length(Flat));
      FlatClosed[High(Flat)] := zEnd;
    end;
    zEnd := False;
    sub := nil;
  end;

  procedure Bez(const p0, p1, p2, p3: TPt);
  var
    j: Integer;
    t: Double;
  begin
    for j := 1 to 16 do
    begin
      t := j / 16;
      AddPt(sub, Power(1 - t, 3) * p0.x + 3 * Sqr(1 - t) * t * p1.x + 3 * (1 - t) * t * t * p2.x + t * t * t * p3.x,
        Power(1 - t, 3) * p0.y + 3 * Sqr(1 - t) * t * p1.y + 3 * (1 - t) * t * t * p2.y + t * t * t * p3.y);
    end;
  end;

  procedure ReadNums(const from: Integer; out last: Integer);
  var
    j, st: Integer;
  begin
    SetLength(nums, 0);
    j := from;
    while j <= n do
    begin
      while (j <= n) and (s[j] in [' ', ',', #9, #10, #13]) do Inc(j);
      if (j > n) or (s[j] in ['A'..'Z', 'a'..'z']) and not (s[j] in ['e', 'E']) then Break;
      st := j;
      if (j <= n) and (s[j] in ['+', '-']) then Inc(j);
      while (j <= n) and (s[j] in ['0'..'9', '.']) do Inc(j);
      if (j <= n) and (s[j] in ['e', 'E']) then
      begin
        Inc(j);
        if (j <= n) and (s[j] in ['+', '-']) then Inc(j);
        while (j <= n) and (s[j] in ['0'..'9']) do Inc(j);
      end;
      if j = st then Break;
      SetLength(nums, Length(nums) + 1);
      nums[High(nums)] := StrToFloatDef(Copy(s, st, j - st), 0, MFS);
    end;
    last := j;
  end;

var
  k, nxt: Integer;
  rel: Boolean;
  c1, c2, e: TPt;
begin
  SetLength(Flat, 0);
  SetLength(FlatClosed, 0);
  zEnd := False;
  sub := nil;
  s := PathData;
  n := Length(s);
  i := 1;
  cur := MakePt(0, 0);
  start := cur;
  lastC := cur;
  lastCmd := ' ';
  while i <= n do
  begin
    if s[i] in ['A'..'Z', 'a'..'z'] then
    begin
      cmd := s[i];
      Inc(i);
    end
    else if s[i] in [' ', ',', #9, #10, #13] then
    begin
      Inc(i);
      Continue;
    end
    else Break;
    ReadNums(i, nxt);
    i := nxt;
    rel := cmd in ['a'..'z'];
    cmd := UpCase(cmd);
    k := 0;
    case cmd of
      'Z':
        begin
          if Length(sub) > 0 then AddPt(sub, start.x, start.y);
          cur := start;
          zEnd := True;
          Flush;
        end;
      'T':
        while k + 1 < Length(nums) do
        begin
          e := MakePt(nums[k], nums[k + 1]);
          if rel then begin e.x := e.x + cur.x; e.y := e.y + cur.y; end;
          if lastCmd in ['Q', 'T'] then c1 := MakePt(2 * cur.x - lastQ.x, 2 * cur.y - lastQ.y) else c1 := cur;
          if Length(sub) = 0 then AddPt(sub, cur.x, cur.y);
          Bez(cur, MakePt(cur.x + 2 / 3 * (c1.x - cur.x), cur.y + 2 / 3 * (c1.y - cur.y)),
            MakePt(e.x + 2 / 3 * (c1.x - e.x), e.y + 2 / 3 * (c1.y - e.y)), e);
          lastQ := c1;
          lastCmd := 'T';
          cur := e;
          Inc(k, 2);
        end;
      'M', 'L':
        while k + 1 < Length(nums) do
        begin
          e := MakePt(nums[k], nums[k + 1]);
          if rel then begin e.x := e.x + cur.x; e.y := e.y + cur.y; end;
          if (cmd = 'M') and (k = 0) then
          begin
            Flush;
            start := e;
            AddPt(sub, e.x, e.y);
          end
          else
          begin
            if Length(sub) = 0 then AddPt(sub, cur.x, cur.y);
            AddPt(sub, e.x, e.y);
          end;
          cur := e;
          Inc(k, 2);
        end;
      'H':
        while k < Length(nums) do
        begin
          if rel then cur.x := cur.x + nums[k] else cur.x := nums[k];
          if Length(sub) = 0 then AddPt(sub, cur.x, cur.y) else AddPt(sub, cur.x, cur.y);
          Inc(k);
        end;
      'V':
        while k < Length(nums) do
        begin
          if rel then cur.y := cur.y + nums[k] else cur.y := nums[k];
          AddPt(sub, cur.x, cur.y);
          Inc(k);
        end;
      'C', 'S':
        while True do
        begin
          if cmd = 'C' then
          begin
            if k + 5 >= Length(nums) then Break;
            c1 := MakePt(nums[k], nums[k + 1]);
            c2 := MakePt(nums[k + 2], nums[k + 3]);
            e := MakePt(nums[k + 4], nums[k + 5]);
            Inc(k, 6);
            if rel then
            begin
              c1.x := c1.x + cur.x; c1.y := c1.y + cur.y;
              c2.x := c2.x + cur.x; c2.y := c2.y + cur.y;
              e.x := e.x + cur.x; e.y := e.y + cur.y;
            end;
          end
          else
          begin
            if k + 3 >= Length(nums) then Break;
            if lastCmd in ['C', 'S'] then c1 := MakePt(2 * cur.x - lastC.x, 2 * cur.y - lastC.y) else c1 := cur;
            c2 := MakePt(nums[k], nums[k + 1]);
            e := MakePt(nums[k + 2], nums[k + 3]);
            Inc(k, 4);
            if rel then
            begin
              c2.x := c2.x + cur.x; c2.y := c2.y + cur.y;
              e.x := e.x + cur.x; e.y := e.y + cur.y;
            end;
          end;
          if Length(sub) = 0 then AddPt(sub, cur.x, cur.y);
          Bez(cur, c1, c2, e);
          lastC := c2;
          lastCmd := cmd;
          cur := e;
        end;
      'Q':
        while k + 3 < Length(nums) do
        begin
          c1 := MakePt(nums[k], nums[k + 1]);
          e := MakePt(nums[k + 2], nums[k + 3]);
          Inc(k, 4);
          if rel then
          begin
            c1.x := c1.x + cur.x; c1.y := c1.y + cur.y;
            e.x := e.x + cur.x; e.y := e.y + cur.y;
          end;
          if Length(sub) = 0 then AddPt(sub, cur.x, cur.y);
          Bez(cur, MakePt(cur.x + 2 / 3 * (c1.x - cur.x), cur.y + 2 / 3 * (c1.y - cur.y)),
            MakePt(e.x + 2 / 3 * (c1.x - e.x), e.y + 2 / 3 * (c1.y - e.y)), e);
          lastQ := c1;
          lastCmd := 'Q';
          cur := e;
        end;
      'A':
        while k + 6 < Length(nums) do
        begin
          e := MakePt(nums[k + 5], nums[k + 6]);
          if rel then begin e.x := e.x + cur.x; e.y := e.y + cur.y; end;
          if Length(sub) = 0 then AddPt(sub, cur.x, cur.y);
          arcs := ArcSegments(cur, nums[k], nums[k + 1], nums[k + 2], nums[k + 3] <> 0, nums[k + 4] <> 0, e);
          if Length(arcs) = 0 then AddPt(sub, e.x, e.y)
          else
          begin
            ap := cur;
            for ai := 0 to High(arcs) do
            begin
              Bez(ap, arcs[ai].C1, arcs[ai].C2, arcs[ai].E);
              ap := arcs[ai].E;
            end;
          end;
          cur := e;
          Inc(k, 7);
        end;
    end;
    lastCmd := cmd;
  end;
  Flush;
end;

{ ---------- editable paths ---------- }

// the commands of a path as absolute M, L, C and Z (what ParsePath draws: arcs are their chord)
function ParsePathNodes(const d: string): TPathNodes;
var
  i, n, k, nxt, cnt: Integer;
  cmd: Char;
  rel, needM: Boolean;
  nums: array of Double;
  cur, start, lastC, lastQ, c1, c2, e, ap: TPt;
  lastCmd: Char;
  arcs: TArcSegs;
  ai: Integer;

  procedure Put(c: Char; const a, b, cc: TPt; np: Integer);
  begin
    SetLength(Result, cnt + 1);
    Result[cnt].Cmd := c;
    Result[cnt].N := np;
    Result[cnt].Pt[0] := a;
    Result[cnt].Pt[1] := b;
    Result[cnt].Pt[2] := cc;
    Inc(cnt);
  end;

  procedure Need;
  begin
    if needM then
    begin
      Put('M', cur, cur, cur, 1);
      start := cur;
      needM := False;
    end;
  end;

  procedure ReadNums(from: Integer; out last: Integer);
  var
    j, st: Integer;
  begin
    SetLength(nums, 0);
    j := from;
    while j <= n do
    begin
      while (j <= n) and (d[j] in [' ', ',', #9, #10, #13]) do Inc(j);
      if (j > n) or (d[j] in ['A'..'Z', 'a'..'z']) and not (d[j] in ['e', 'E']) then Break;
      st := j;
      if (j <= n) and (d[j] in ['+', '-']) then Inc(j);
      while (j <= n) and (d[j] in ['0'..'9', '.']) do Inc(j);
      if (j <= n) and (d[j] in ['e', 'E']) then
      begin
        Inc(j);
        if (j <= n) and (d[j] in ['+', '-']) then Inc(j);
        while (j <= n) and (d[j] in ['0'..'9']) do Inc(j);
      end;
      if j = st then Break;
      SetLength(nums, Length(nums) + 1);
      nums[High(nums)] := StrToFloatDef(Copy(d, st, j - st), 0, MFS);
    end;
    last := j;
  end;

  function Rel2(x, y: Double): TPt;
  begin
    if rel then Result := MakePt(x + cur.x, y + cur.y) else Result := MakePt(x, y);
  end;

begin
  SetLength(Result, 0);
  cnt := 0;
  n := Length(d);
  i := 1;
  cur := MakePt(0, 0);
  start := cur;
  lastC := cur;
  lastCmd := ' ';
  needM := True;
  while i <= n do
  begin
    if d[i] in ['A'..'Z', 'a'..'z'] then
    begin
      cmd := d[i];
      Inc(i);
    end
    else if d[i] in [' ', ',', #9, #10, #13] then
    begin
      Inc(i);
      Continue;
    end
    else Break;
    ReadNums(i, nxt);
    i := nxt;
    rel := cmd in ['a'..'z'];
    cmd := UpCase(cmd);
    k := 0;
    case cmd of
      'Z':
        if cnt > 0 then
        begin
          Put('Z', cur, cur, cur, 0);
          cur := start;
          needM := True;
        end;
      'T':
        while k + 1 < Length(nums) do
        begin
          e := Rel2(nums[k], nums[k + 1]);
          if lastCmd in ['Q', 'T'] then c1 := MakePt(2 * cur.x - lastQ.x, 2 * cur.y - lastQ.y) else c1 := cur;
          Need;
          Put('C', MakePt(cur.x + 2 / 3 * (c1.x - cur.x), cur.y + 2 / 3 * (c1.y - cur.y)),
            MakePt(e.x + 2 / 3 * (c1.x - e.x), e.y + 2 / 3 * (c1.y - e.y)), e, 3);
          lastQ := c1;
          lastCmd := 'T';
          cur := e;
          Inc(k, 2);
        end;
      'M', 'L':
        while k + 1 < Length(nums) do
        begin
          e := Rel2(nums[k], nums[k + 1]);
          if (cmd = 'M') and (k = 0) then
          begin
            Put('M', e, e, e, 1);
            start := e;
            needM := False;
          end
          else
          begin
            Need;
            Put('L', e, e, e, 1);
          end;
          cur := e;
          Inc(k, 2);
        end;
      'H':
        while k < Length(nums) do
        begin
          Need;
          if rel then e := MakePt(cur.x + nums[k], cur.y) else e := MakePt(nums[k], cur.y);
          Put('L', e, e, e, 1);
          cur := e;
          Inc(k);
        end;
      'V':
        while k < Length(nums) do
        begin
          Need;
          if rel then e := MakePt(cur.x, cur.y + nums[k]) else e := MakePt(cur.x, nums[k]);
          Put('L', e, e, e, 1);
          cur := e;
          Inc(k);
        end;
      'C', 'S':
        while True do
        begin
          if cmd = 'C' then
          begin
            if k + 5 >= Length(nums) then Break;
            c1 := Rel2(nums[k], nums[k + 1]);
            c2 := Rel2(nums[k + 2], nums[k + 3]);
            e := Rel2(nums[k + 4], nums[k + 5]);
            Inc(k, 6);
          end
          else
          begin
            if k + 3 >= Length(nums) then Break;
            if lastCmd in ['C', 'S'] then c1 := MakePt(2 * cur.x - lastC.x, 2 * cur.y - lastC.y) else c1 := cur;
            c2 := Rel2(nums[k], nums[k + 1]);
            e := Rel2(nums[k + 2], nums[k + 3]);
            Inc(k, 4);
          end;
          Need;
          Put('C', c1, c2, e, 3);
          lastC := c2;
          lastCmd := cmd;
          cur := e;
        end;
      'Q':
        while k + 3 < Length(nums) do
        begin
          c1 := Rel2(nums[k], nums[k + 1]);
          e := Rel2(nums[k + 2], nums[k + 3]);
          Inc(k, 4);
          Need;
          Put('C', MakePt(cur.x + 2 / 3 * (c1.x - cur.x), cur.y + 2 / 3 * (c1.y - cur.y)),
            MakePt(e.x + 2 / 3 * (c1.x - e.x), e.y + 2 / 3 * (c1.y - e.y)), e, 3);
          lastQ := c1;
          lastCmd := 'Q';
          cur := e;
        end;
      'A':
        while k + 6 < Length(nums) do
        begin
          e := Rel2(nums[k + 5], nums[k + 6]);
          Need;
          arcs := ArcSegments(cur, nums[k], nums[k + 1], nums[k + 2], nums[k + 3] <> 0, nums[k + 4] <> 0, e);
          if Length(arcs) = 0 then Put('L', e, e, e, 1)
          else
          begin
            ap := cur;
            for ai := 0 to High(arcs) do
            begin
              Put('C', arcs[ai].C1, arcs[ai].C2, arcs[ai].E, 3);
              ap := arcs[ai].E;
            end;
          end;
          cur := e;
          Inc(k, 7);
        end;
    end;
    lastCmd := cmd;
  end;
end;

function PathNodesToData(const nodes: TPathNodes): string;
var
  i, j: Integer;

  function F(v: Double): string;
  begin
    Result := FormatFloat('0.###', v, MFS);
  end;

begin
  Result := '';
  for i := 0 to High(nodes) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + nodes[i].Cmd;
    for j := 0 to nodes[i].N - 1 do
    begin
      if j > 0 then Result := Result + ' ';
      Result := Result + F(nodes[i].Pt[j].x) + ' ' + F(nodes[i].Pt[j].y);
      if (j = 0) and (nodes[i].N = 1) then Continue;
    end;
  end;
end;

procedure TShape.EnsureNodes;
begin
  if (PNSrc = PathData) and ((Length(PN) > 0) or (PathData = '')) then Exit;
  PN := ParsePathNodes(PathData);
  PNSrc := PathData;
end;

procedure TShape.PathHandles(out xs, ys: TDblArr; out ctl: TBoolDyn; out anc: TIntDyn);
var
  i, j, k, lastAnchor: Integer;
begin
  EnsureNodes;
  SetLength(xs, 0);
  SetLength(ys, 0);
  SetLength(ctl, 0);
  SetLength(anc, 0);
  k := 0;
  lastAnchor := -1;
  for i := 0 to High(PN) do
    for j := 0 to PN[i].N - 1 do
    begin
      SetLength(xs, k + 1);
      SetLength(ys, k + 1);
      SetLength(ctl, k + 1);
      SetLength(anc, k + 1);
      xs[k] := PN[i].Pt[j].x;
      ys[k] := PN[i].Pt[j].y;
      ctl[k] := (PN[i].Cmd = 'C') and (j < 2);
      if ctl[k] then
      begin
        // the first control belongs to the point the curve starts from, the second to the one it ends at
        if j = 0 then anc[k] := lastAnchor else anc[k] := k + 1;
      end
      else
      begin
        anc[k] := k;
        lastAnchor := k;
      end;
      Inc(k);
    end;
end;

// moves point k (a control point alone; any other point with the controls next to it, and the points of the same place
// that close a sub-path)
procedure TShape.MovePathPoint(k: Integer; x, y: Double);
var
  i, j, c, ni, pi, sa, sb, a: Integer;
  ox, oy, dx, dy: Double;
begin
  EnsureNodes;
  c := 0;
  ni := -1;
  pi := 0;
  for i := 0 to High(PN) do
  begin
    if k < c + PN[i].N then
    begin
      ni := i;
      pi := k - c;
      Break;
    end;
    Inc(c, PN[i].N);
  end;
  if ni < 0 then Exit;
  ox := PN[ni].Pt[pi].x;
  oy := PN[ni].Pt[pi].y;
  dx := x - ox;
  dy := y - oy;
  if (PN[ni].Cmd = 'C') and (pi < 2) then
  begin
    PN[ni].Pt[pi].x := x;
    PN[ni].Pt[pi].y := y;
  end
  else
  begin
    // the sub-path that holds the point
    sa := ni;
    while (sa > 0) and (PN[sa].Cmd <> 'M') do Dec(sa);
    sb := ni;
    while (sb + 1 <= High(PN)) and (PN[sb + 1].Cmd <> 'M') do Inc(sb);
    for j := sa to sb do
    begin
      if PN[j].N = 0 then Continue;
      a := PN[j].N - 1;
      if (j = ni) or ((Abs(PN[j].Pt[a].x - ox) < 1e-9) and (Abs(PN[j].Pt[a].y - oy) < 1e-9)) then
      begin
        PN[j].Pt[a].x := PN[j].Pt[a].x + dx;
        PN[j].Pt[a].y := PN[j].Pt[a].y + dy;
        if PN[j].Cmd = 'C' then
        begin
          PN[j].Pt[1].x := PN[j].Pt[1].x + dx;
          PN[j].Pt[1].y := PN[j].Pt[1].y + dy;
        end;
        if (j + 1 <= sb) and (PN[j + 1].Cmd = 'C') then
        begin
          PN[j + 1].Pt[0].x := PN[j + 1].Pt[0].x + dx;
          PN[j + 1].Pt[0].y := PN[j + 1].Pt[0].y + dy;
        end;
      end;
    end;
  end;
  PathData := PathNodesToData(PN);
  PNSrc := PathData;
  ParsePath;
end;

// several points of the path move by the same amount (each point once, with its controls)
procedure TShape.MovePathPoints(const ks: array of Integer; dx, dy: Double);
var
  off: array of Integer;
  mark: array of Boolean;
  i, j, c, ni, pi, sa, sb, a, q: Integer;
  ox, oy: Double;

  procedure MarkAnchor(n: Integer);
  var
    t, b2, m: Integer;
  begin
    b2 := PN[n].N - 1;
    mark[off[n] + b2] := True;
    if PN[n].Cmd = 'C' then mark[off[n] + 1] := True;
    if (n + 1 < Length(PN)) and (PN[n + 1].Cmd = 'C') then mark[off[n + 1]] := True;
    t := 0;
    m := t;
  end;

begin
  EnsureNodes;
  SetLength(off, Length(PN));
  c := 0;
  for i := 0 to High(PN) do
  begin
    off[i] := c;
    Inc(c, PN[i].N);
  end;
  SetLength(mark, c);
  for q := 0 to High(ks) do
  begin
    ni := -1;
    pi := 0;
    for i := 0 to High(PN) do
      if (ks[q] >= off[i]) and (ks[q] < off[i] + PN[i].N) then
      begin
        ni := i;
        pi := ks[q] - off[i];
        Break;
      end;
    if ni < 0 then Continue;
    if (PN[ni].Cmd = 'C') and (pi < 2) then
    begin
      mark[ks[q]] := True;
      Continue;
    end;
    MarkAnchor(ni);
    // the points of the same place in its sub-path (the one that closes it)
    ox := PN[ni].Pt[PN[ni].N - 1].x;
    oy := PN[ni].Pt[PN[ni].N - 1].y;
    sa := ni;
    while (sa > 0) and (PN[sa].Cmd <> 'M') do Dec(sa);
    sb := ni;
    while (sb + 1 <= High(PN)) and (PN[sb + 1].Cmd <> 'M') do Inc(sb);
    for j := sa to sb do
    begin
      if (PN[j].N = 0) or (j = ni) then Continue;
      a := PN[j].N - 1;
      if (Abs(PN[j].Pt[a].x - ox) < 1e-9) and (Abs(PN[j].Pt[a].y - oy) < 1e-9) then MarkAnchor(j);
    end;
  end;
  for i := 0 to High(PN) do
    for j := 0 to PN[i].N - 1 do
      if mark[off[i] + j] then
      begin
        PN[i].Pt[j].x := PN[i].Pt[j].x + dx;
        PN[i].Pt[j].y := PN[i].Pt[j].y + dy;
      end;
  PathData := PathNodesToData(PN);
  PNSrc := PathData;
  ParsePath;
end;

// removes the given points: a vertex goes (the sides on its two sides join), a control point makes its curve a straight line
function TShape.RemovePathPoints(const ks: array of Integer; out err: string): Boolean;
var
  off: array of Integer;
  rm: array of Boolean;
  i, j, c, ni, pi, q, sa, sb, na, a: Integer;
  closed: Boolean;
  nx, ny, ox, oy: Double;
  any: Boolean;
begin
  Result := False;
  err := '';
  EnsureNodes;
  SetLength(off, Length(PN));
  c := 0;
  for i := 0 to High(PN) do
  begin
    off[i] := c;
    Inc(c, PN[i].N);
  end;
  SetLength(rm, Length(PN));
  any := False;
  for q := 0 to High(ks) do
  begin
    ni := -1;
    pi := 0;
    for i := 0 to High(PN) do
      if (ks[q] >= off[i]) and (ks[q] < off[i] + PN[i].N) then
      begin
        ni := i;
        pi := ks[q] - off[i];
        Break;
      end;
    if ni < 0 then Continue;
    if (PN[ni].Cmd = 'C') and (pi < 2) then
    begin
      // a control point: the curve becomes a straight line
      PN[ni].Cmd := 'L';
      PN[ni].N := 1;
      PN[ni].Pt[0] := PN[ni].Pt[2];
      PN[ni].Pt[1] := PN[ni].Pt[2];
      any := True;
    end
    else rm[ni] := True;
  end;
  // from the last vertex to the first, so the numbers of the others stay right
  for ni := High(PN) downto 0 do
  begin
    if not rm[ni] then Continue;
    sa := ni;
    while (sa > 0) and (PN[sa].Cmd <> 'M') do Dec(sa);
    sb := ni;
    while (sb + 1 <= High(PN)) and (PN[sb + 1].Cmd <> 'M') do Inc(sb);
    closed := PN[sb].Cmd = 'Z';
    na := 0;
    for j := sa to sb do
      if PN[j].N > 0 then Inc(na);
    // the point that closes the sub-path on its start is not one more vertex
    for j := sb downto sa + 1 do
      if PN[j].N > 0 then
      begin
        if (Abs(PN[j].Pt[PN[j].N - 1].x - PN[sa].Pt[0].x) < 1e-9) and (Abs(PN[j].Pt[PN[j].N - 1].y - PN[sa].Pt[0].y) < 1e-9) and closed then Dec(na);
        Break;
      end;
    if (closed and (na <= 3)) or (not closed and (na <= 2)) then
    begin
      err := 'A path keeps at least ' + IntToStr(Ord(closed) + 2) + ' points.';
      Continue;
    end;
    if PN[ni].Cmd = 'M' then
    begin
      if (ni + 1 > High(PN)) or (PN[ni + 1].N = 0) then Continue;
      ox := PN[ni].Pt[0].x;
      oy := PN[ni].Pt[0].y;
      nx := PN[ni + 1].Pt[PN[ni + 1].N - 1].x;
      ny := PN[ni + 1].Pt[PN[ni + 1].N - 1].y;
      for j := sa + 2 to sb do
        if PN[j].N > 0 then
        begin
          a := PN[j].N - 1;
          if (Abs(PN[j].Pt[a].x - ox) < 1e-9) and (Abs(PN[j].Pt[a].y - oy) < 1e-9) then
          begin
            PN[j].Pt[a].x := nx;
            PN[j].Pt[a].y := ny;
          end;
        end;
      PN[ni].Pt[0].x := nx;
      PN[ni].Pt[0].y := ny;
      Delete(PN, ni + 1, 1);
    end
    else Delete(PN, ni, 1);
    any := True;
  end;
  if not any then Exit;
  PathData := PathNodesToData(PN);
  PNSrc := PathData;
  ParsePath;
  Result := True;
end;

// the closed outlines get this many points in all (each keeps at least three): the points that change the shape least are
// dropped (the smallest triangle with its two neighbours), or the longest sides are halved
procedure ResizeLoops(var lps: TPtLoops; want: Integer);
var
  i, k, n, total, bi, bk, prv, nxt: Integer;
  a, best, ln, bl: Double;
begin
  total := 0;
  for i := 0 to High(lps) do Inc(total, Length(lps[i]));
  while total > want do
  begin
    best := 1e300;
    bi := -1;
    bk := -1;
    for i := 0 to High(lps) do
    begin
      n := Length(lps[i]);
      if n <= 3 then Continue;
      for k := 0 to n - 1 do
      begin
        prv := (k + n - 1) mod n;
        nxt := (k + 1) mod n;
        a := Abs((lps[i][k].x - lps[i][prv].x) * (lps[i][nxt].y - lps[i][prv].y) -
          (lps[i][nxt].x - lps[i][prv].x) * (lps[i][k].y - lps[i][prv].y)) / 2;
        if a < best then
        begin
          best := a;
          bi := i;
          bk := k;
        end;
      end;
    end;
    if bi < 0 then Break;
    n := Length(lps[bi]);
    for k := bk to n - 2 do lps[bi][k] := lps[bi][k + 1];
    SetLength(lps[bi], n - 1);
    Dec(total);
  end;
  while total < want do
  begin
    bl := -1;
    bi := 0;
    bk := 0;
    for i := 0 to High(lps) do
    begin
      n := Length(lps[i]);
      for k := 0 to n - 1 do
      begin
        nxt := (k + 1) mod n;
        ln := Hypot(lps[i][nxt].x - lps[i][k].x, lps[i][nxt].y - lps[i][k].y);
        if ln > bl then
        begin
          bl := ln;
          bi := i;
          bk := k;
        end;
      end;
    end;
    if bl <= 0 then Break;
    n := Length(lps[bi]);
    SetLength(lps[bi], n + 1);
    for k := n downto bk + 2 do lps[bi][k] := lps[bi][k - 1];
    lps[bi][bk + 1].x := (lps[bi][bk].x + lps[bi][(bk + 2) mod (n + 1)].x) / 2;
    lps[bi][bk + 1].y := (lps[bi][bk].y + lps[bi][(bk + 2) mod (n + 1)].y) / 2;
    Inc(total);
  end;
end;

function TDoc.PathPointTotal(s: TShape): Integer;
var
  o: TOutline;
  i: Integer;
begin
  Result := 0;
  o := ShapeOutline(s);
  for i := 0 to High(o) do Inc(Result, Length(o[i].Pts));
end;

function TDoc.PathOutlines(s: TShape): Integer;
begin
  Result := Length(ShapeOutline(s));
end;

// a path made of commands becomes a polygon (closed) or a poly-line (open) with pointCount points: only a path of a single
// outline can
function TDoc.ConvertPath(s: TShape; pointCount: Integer; out dropped: Integer; out err: string): Boolean;
var
  o: TOutline;
  lps: TPtLoops;
  i, ci, ri, f: Integer;
  c: TConstraint;
  drop: Boolean;
begin
  Result := False;
  dropped := 0;
  err := '';
  if (s.Kind <> skPath) or s.Bucket then
  begin
    err := 'Only a path can be converted here.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  for f := 0 to Shapes.Count - 1 do
    if (Shapes[f].FA > 0) and ((Shapes[f].FA = s.Id) or (Shapes[f].FB = s.Id)) then
    begin
      err := 'This object is joined by a fillet / chamfer: remove it first.';
      Exit;
    end;
  o := ShapeOutline(s);
  if Length(o) <> 1 then
  begin
    err := 'A path made of several outlines (holes or separate pieces) cannot become a polygon.';
    Exit;
  end;
  if Length(o[0].Pts) < 2 then
  begin
    err := 'The path has too few points.';
    Exit;
  end;
  SetLength(lps, 1);
  lps[0] := Copy(o[0].Pts);
  if o[0].Closed then ResizeLoops(lps, Max(3, pointCount));
  s.P := lps[0];
  if o[0].Closed then s.Kind := skPolygon else s.Kind := skPolyline;
  s.Rot := 0;
  s.PathData := '';
  SetLength(s.Flat, 0);
  SetLength(s.FlatClosed, 0);
  SetLength(s.PN, 0);
  s.PNSrc := '';
  SetLength(s.W, 0);
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    for ri := 0 to High(c.Refs) do
      if (c.Refs[ri].Shape = s.Id) and not ((c.Kind = ckFixed) and (c.Refs[ri].Idx = -1)) then drop := True;
    if drop then
    begin
      Cons.Delete(ci);
      Inc(dropped);
    end;
  end;
  Result := True;
end;

{ ---------- TConstraint ---------- }

function TConstraint.IsQuote: Boolean;
begin
  Result := Kind in [ckDistance, ckRadius, ckAngle];
end;

{ ---------- TDoc ---------- }

constructor TLayer.Create;
begin
  inherited Create;
  Visible := True;
  Opacity := 255;
  Scale := 1;
  Bg := NoColor;
  LightAz := 217;
  LightEl := 60;
  LightDiv := 0;
  LightPower := 1;
  LightTint := $FFFFFF;
end;

procedure TDoc.ResetMats;
var
  i: Integer;
begin
  for i := 0 to MaterialCount - 1 do Mats[i] := DefaultMatParams;
end;

constructor TDoc.Create;
begin
  inherited Create;
  ResetMats;
  Layers := TLayerList.Create(True);
  NextLayerId := 1;
  Shapes := TShapeList.Create(True);
  Cons := TConstraintList.Create(True);
  Arrays := TArrayList.Create(True);
  Width := 800;
  Height := 600;
  NextId := 1;
  AddLayer('Layer 1');
end;

destructor TDoc.Destroy;
begin
  Layers.Free;
  Arrays.Free;
  Cons.Free;
  Shapes.Free;
  inherited Destroy;
end;

procedure TDoc.Clear;
begin
  ResetMats;
  Arrays.Clear;
  Cons.Clear;
  Shapes.Clear;
  Layers.Clear;
  NextLayerId := 1;
  NextId := 1;
  AddLayer('Layer 1');
end;

{ ---------- layers ---------- }

function TDoc.FindLayer(id: Integer): TLayer;
var
  i: Integer;
begin
  for i := 0 to Layers.Count - 1 do
    if Layers[i].Id = id then Exit(Layers[i]);
  Result := nil;
end;

// the layer of a shape (the first one when the shape belongs to none)
function TDoc.LayerOf(s: TShape): TLayer;
begin
  Result := FindLayer(s.LayerId);
  if (Result = nil) and (Layers.Count > 0) then Result := Layers[0];
end;

function TDoc.AddLayer(const aName: string): TLayer;
begin
  Result := TLayer.Create;
  Result.Id := NextLayerId;
  Inc(NextLayerId);
  Result.Name := aName;
  Layers.Add(Result);
  if ActiveLayer = 0 then ActiveLayer := Result.Id;
end;

// at least one layer; shapes of unknown layers go to the first one
procedure TDoc.EnsureLayers;
var
  i: Integer;
begin
  if Layers.Count = 0 then AddLayer('Layer 1');
  if FindLayer(ActiveLayer) = nil then ActiveLayer := Layers[Layers.Count - 1].Id;
  for i := 0 to Shapes.Count - 1 do
    if FindLayer(Shapes[i].LayerId) = nil then Shapes[i].LayerId := Layers[0].Id;
end;

function TDoc.ShapeVisible(s: TShape): Boolean;
var
  l: TLayer;
begin
  l := LayerOf(s);
  Result := ((l = nil) or (l.Visible and not (l.HideRefs and s.IsRef))) and not s.Hidden;
end;

function TDoc.ShapeLocked(s: TShape): Boolean;
var
  l: TLayer;
begin
  l := LayerOf(s);
  Result := s.Locked or ((l <> nil) and l.Locked);
end;

// the shapes as they are painted: layer by layer from the bottom, hidden layers left out
function TDoc.DrawOrder: TShapeArray;
var
  i, j, k, n, first: Integer;
  bk: TShape;
begin
  SetLength(Result, Shapes.Count);
  n := 0;
  for i := 0 to Layers.Count - 1 do
  begin
    if not Layers[i].Visible then Continue;
    for j := 0 to Shapes.Count - 1 do
      if (LayerOf(Shapes[j]) = Layers[i]) and not Shapes[j].Hidden then
      begin
        Result[n] := Shapes[j];
        Inc(n);
      end;
  end;
  SetLength(Result, n);
  // a fill is always under the lines that bound it, whatever layer it is on
  for i := 0 to n - 1 do
  begin
    if not Result[i].Bucket then Continue;
    first := -1;
    for j := 0 to n - 1 do
      if (j <> i) and not Result[j].Bucket then
      begin
        for k := 0 to High(Result[i].BucketIds) do
          if Result[i].BucketIds[k] = Result[j].Id then
          begin
            if (first < 0) or (j < first) then first := j;
            Break;
          end;
      end;
    if (first >= 0) and (first < i) then
    begin
      bk := Result[i];
      for j := i downto first + 1 do Result[j] := Result[j - 1];
      Result[first] := bk;
    end;
  end;
end;

// transparency of the stroke / fill of a shape together with that of its layer
function TDoc.EffectiveTr(s: TShape; fill: Boolean): Integer;
var
  tr, lo: Integer;
  l: TLayer;
begin
  if fill then tr := s.Style.FillTr else tr := s.Style.StrokeTr;
  l := LayerOf(s);
  if l <> nil then lo := l.Opacity else lo := 255;
  // opacities multiply
  Result := 255 - Round((255 - tr) * lo / 255);
  if Result < 0 then Result := 0;
  if Result > 255 then Result := 255;
end;

// a visible filter layer that does something
function TDoc.HasFilter: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Layers.Count - 1 do
    if Layers[i].IsFilter and Layers[i].Visible and (Layers[i].FScript <> '') and (Layers[i].Opacity > 0) then Exit(True);
end;

// only reference objects can be drawn in a filter layer
procedure TDoc.EnforceFilterRefs;
var
  i: Integer;
  l: TLayer;
begin
  for i := 0 to Shapes.Count - 1 do
  begin
    l := LayerOf(Shapes[i]);
    if (l <> nil) and l.IsFilter then Shapes[i].IsRef := True;
  end;
end;

function TDoc.HasAlpha: Boolean;
var
  i: Integer;
begin
  Result := HasFilter;
  if Result then Exit;
  for i := 0 to Layers.Count - 1 do
    if Layers[i].Opacity < 255 then Exit(True);
  for i := 0 to Shapes.Count - 1 do
    if (Shapes[i].Style.StrokeTr > 0) or (Shapes[i].Style.FillTr > 0) or Shapes[i].GradOn then Exit(True);
end;

// the line a gradient runs along: the reference shape's outline (the longest one), or, without one,
// a horizontal line across the shape
function TDoc.GradientLine(s: TShape): TGradLine;
var
  o: TOutline;
  r: TShape;
  i, k, best, n, step: Integer;
  len, bl, x1, y1, x2, y2: Double;
  pts: TPtArray;
begin
  SetLength(Result.Pts, 0);
  SetLength(Result.Cum, 0);
  Result.Total := 0;
  Result.Radial := False;
  Result.CX := 0;
  Result.CY := 0;
  Result.R := 1;
  r := nil;
  if s.GradRef > 0 then r := FindShape(s.GradRef);
  if (r <> nil) and (r <> s) then o := ShapeOutline(r) else o := nil;
  if s.GradRadial then
  begin
    // centre and radius: a circle / arc gives its own, a line goes from the centre to the edge, anything else
    // is taken by its extent
    Result.Radial := True;
    if (r <> nil) and (r <> s) and (r.Kind in [skEllipse, skArc]) and (Length(r.P) >= 1) then
    begin
      Result.CX := r.P[0].x;
      Result.CY := r.P[0].y;
      Result.R := Max(1e-6, Max(r.RX, r.RY));
      if r.Kind = skEllipse then Result.R := Max(1e-6, (r.RX + r.RY) / 2);
      Exit;
    end;
    if (r <> nil) and (r <> s) and (r.Kind in [skLine, skArrow]) and (Length(r.P) >= 2) then
    begin
      Result.CX := r.P[0].x;
      Result.CY := r.P[0].y;
      Result.R := Max(1e-6, Hypot(r.P[1].x - r.P[0].x, r.P[1].y - r.P[0].y));
      Exit;
    end;
    if not ((r <> nil) and (r <> s) and (Length(o) > 0)) then o := ShapeOutline(s);
    x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
    for i := 0 to High(o) do
      for k := 0 to High(o[i].Pts) do
      begin
        x1 := Min(x1, o[i].Pts[k].x);
        y1 := Min(y1, o[i].Pts[k].y);
        x2 := Max(x2, o[i].Pts[k].x);
        y2 := Max(y2, o[i].Pts[k].y);
      end;
    if x1 > x2 then
    begin
      Result.R := 1;
      Exit;
    end;
    Result.CX := (x1 + x2) / 2;
    Result.CY := (y1 + y2) / 2;
    len := 0;
    for i := 0 to High(o) do
      for k := 0 to High(o[i].Pts) do
        len := Max(len, Hypot(o[i].Pts[k].x - Result.CX, o[i].Pts[k].y - Result.CY));
    Result.R := Max(1e-6, len);
    Exit;
  end;
  best := -1;
  bl := -1;
  for i := 0 to High(o) do
  begin
    len := 0;
    for k := 1 to High(o[i].Pts) do len := len + Hypot(o[i].Pts[k].x - o[i].Pts[k - 1].x, o[i].Pts[k].y - o[i].Pts[k - 1].y);
    if len > bl then
    begin
      bl := len;
      best := i;
    end;
  end;
  if (best >= 0) and (bl > 1e-9) then
  begin
    pts := Copy(o[best].Pts);
    if o[best].Closed then
    begin
      SetLength(pts, Length(pts) + 1);
      pts[High(pts)] := pts[0];
    end;
    // at most about 80 points: the curve is followed closely enough, and each pixel stays cheap
    n := Length(pts);
    step := Max(1, n div 80);
    SetLength(Result.Pts, 0);
    k := 0;
    while k < n do
    begin
      SetLength(Result.Pts, Length(Result.Pts) + 1);
      Result.Pts[High(Result.Pts)] := pts[k];
      if k < n - 1 then k := Min(k + step, n - 1) else Break;
    end;
  end
  else
  begin
    x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
    o := ShapeOutline(s);
    for i := 0 to High(o) do
      for k := 0 to High(o[i].Pts) do
      begin
        x1 := Min(x1, o[i].Pts[k].x);
        y1 := Min(y1, o[i].Pts[k].y);
        x2 := Max(x2, o[i].Pts[k].x);
        y2 := Max(y2, o[i].Pts[k].y);
      end;
    if x1 > x2 then Exit;
    SetLength(Result.Pts, 2);
    Result.Pts[0] := MakePt(x1, (y1 + y2) / 2);
    Result.Pts[1] := MakePt(Max(x2, x1 + 1), (y1 + y2) / 2);
  end;
  SetLength(Result.Cum, Length(Result.Pts));
  Result.Cum[0] := 0;
  for k := 1 to High(Result.Pts) do
    Result.Cum[k] := Result.Cum[k - 1] + Hypot(Result.Pts[k].x - Result.Pts[k - 1].x, Result.Pts[k].y - Result.Pts[k - 1].y);
  Result.Total := Result.Cum[High(Result.Cum)];
end;

// how far along the gradient line the point (x, y) is: 0 at its start, 1 at its end
function GradientT(const g: TGradLine; x, y: Double): Double;
var
  k: Integer;
  dx, dy, l2, u, px, py, d, bd, bt: Double;
begin
  Result := 0;
  if g.Radial then
  begin
    if g.R > 1e-9 then Result := Hypot(x - g.CX, y - g.CY) / g.R;
    Exit;
  end;
  if (Length(g.Pts) < 2) or (g.Total < 1e-9) then Exit;
  bd := 1e300;
  bt := 0;
  for k := 1 to High(g.Pts) do
  begin
    dx := g.Pts[k].x - g.Pts[k - 1].x;
    dy := g.Pts[k].y - g.Pts[k - 1].y;
    l2 := dx * dx + dy * dy;
    if l2 < 1e-18 then Continue;
    u := ((x - g.Pts[k - 1].x) * dx + (y - g.Pts[k - 1].y) * dy) / l2;
    if u < 0 then u := 0;
    if u > 1 then u := 1;
    px := g.Pts[k - 1].x + u * dx;
    py := g.Pts[k - 1].y + u * dy;
    d := Sqr(x - px) + Sqr(y - py);
    if d < bd then
    begin
      bd := d;
      bt := g.Cum[k - 1] + u * Sqrt(l2);
    end;
  end;
  Result := bt / g.Total;
end;

// the colour (BGR) and the opacity (0..255) of the gradient at t, before the opacity of the layer
procedure GradientMix(s: TShape; t: Double; out col, opacity: Integer);
var
  k, n: Integer;
  pa, pb, u: Double;
  ca, cb, ta, tb, r, g, b: Integer;

  // stop number i: 0 the first colour, 1..n the middle ones, n + 1 the last
  procedure Stop(i: Integer; out p: Double; out c, tr: Integer);
  begin
    if i <= 0 then
    begin
      p := 0;
      c := s.Style.Fill;
      tr := s.Style.FillTr;
      if c = NoColor then c := s.GradColor;
    end
    else if i > Length(s.GradMid) then
    begin
      p := 1;
      c := s.GradColor;
      tr := s.GradTr;
    end
    else
    begin
      p := s.GradMid[i - 1].Pos;
      c := s.GradMid[i - 1].Col;
      tr := s.GradMid[i - 1].Tr;
    end;
  end;

begin
  if t < 0 then t := 0;
  if t > 1 then t := 1;
  n := Length(s.GradMid);
  // the pair of stops t lies between
  k := 0;
  while (k <= n) do
  begin
    Stop(k + 1, pb, cb, tb);
    if t <= pb then Break;
    Inc(k);
  end;
  if k > n then k := n;
  Stop(k, pa, ca, ta);
  Stop(k + 1, pb, cb, tb);
  if pb - pa < 1e-9 then u := 1 else u := (t - pa) / (pb - pa);
  if u < 0 then u := 0;
  if u > 1 then u := 1;
  r := Round((ca and $FF) * (1 - u) + (cb and $FF) * u);
  g := Round(((ca shr 8) and $FF) * (1 - u) + ((cb shr 8) and $FF) * u);
  b := Round(((ca shr 16) and $FF) * (1 - u) + ((cb shr 16) and $FF) * u);
  col := r or (g shl 8) or (b shl 16);
  opacity := Round((255 - ta) * (1 - u) + (255 - tb) * u);
end;

function TDoc.FindShape(id: Integer): TShape;
var
  i: Integer;
begin
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].Id = id then Exit(Shapes[i]);
  Result := nil;
end;

function TDoc.AddShape(s: TShape): TShape;
begin
  if s.Id <= 0 then
  begin
    s.Id := NextId;
    Inc(NextId);
  end
  else if s.Id >= NextId then NextId := s.Id + 1;
  if s.LayerId = 0 then s.LayerId := ActiveLayer;
  if (LayerOf(s) <> nil) and LayerOf(s).IsFilter then s.IsRef := True;
  EnsureRect(s);
  Shapes.Add(s);
  Result := s;
end;

procedure TDoc.DeleteShape(s: TShape);
var
  i, j: Integer;
begin
  if s.ArrId > 0 then ExplodeArray(s.ArrId);   // an item cannot be removed from an array
  for i := Cons.Count - 1 downto 0 do
    for j := 0 to High(Cons[i].Refs) do
      if Cons[i].Refs[j].Shape = s.Id then
      begin
        Cons.Delete(i);
        Break;
      end;
  Shapes.Remove(s);
end;

procedure TDoc.DeleteConstraint(c: TConstraint);
begin
  Cons.Remove(c);
end;

function TDoc.IsPinned(shapeId, idx: Integer): Boolean;
var
  i, j: Integer;
  r: TRef;
  a, b: TPR;
begin
  Result := False;
  for i := 0 to Cons.Count - 1 do
  begin
    if Cons[i].Kind <> ckFixed then Continue;
    for j := 0 to High(Cons[i].Refs) do
    begin
      r := Cons[i].Refs[j];
      if r.Shape <> shapeId then Continue;
      if (r.Idx = -1) or (r.Idx = idx) then Exit(True);
      if (r.Idx >= SegBase) and SegOf(r, a, b) and ((a.I = idx) or (b.I = idx)) then Exit(True);
    end;
  end;
end;

function TDoc.ConstraintsOf(shapeId: Integer): TConstraintList;
var
  i, j: Integer;
begin
  Result := TConstraintList.Create(False);
  for i := 0 to Cons.Count - 1 do
    for j := 0 to High(Cons[i].Refs) do
      if Cons[i].Refs[j].Shape = shapeId then
      begin
        Result.Add(Cons[i]);
        Break;
      end;
end;

{ ---------- reference resolution ---------- }

// virtual points as constraint targets: start / end of an arc and the four extreme points of a
// circle / ellipse; moving the centre moves them
function TDoc.ArcEndOf(const r: TRef; out s: TShape; out pt: TPt): Boolean;
var
  a: Double;
begin
  Result := False;
  s := FindShape(r.Shape);
  if (s = nil) or (Length(s.P) < 1) or (r.Idx > ArcStartIdx) or (r.Idx < EllSouthIdx) then Exit;
  case r.Idx of
    ArcStartIdx, ArcEndIdx:
      begin
        if s.Kind <> skArc then Exit;
        if r.Idx = ArcStartIdx then a := s.A1 else a := s.A2;
        pt := MakePt(s.P[0].x + s.RX * Cos(a), s.P[0].y + s.RY * Sin(a));
      end;
    EllSouthIdx..EllEastIdx:
      begin
        if not (s.Kind in [skEllipse, skArc]) then Exit;
        case r.Idx of
          EllEastIdx: pt := MakePt(s.P[0].x + s.RX, s.P[0].y);
          EllNorthIdx: pt := MakePt(s.P[0].x, s.P[0].y - s.RY);
          EllWestIdx: pt := MakePt(s.P[0].x - s.RX, s.P[0].y);
        else
          pt := MakePt(s.P[0].x, s.P[0].y + s.RY);
        end;
      end;
  else
    Exit;
  end;
  Result := True;
end;

// a point that constraints can pull: mover is the stored point that has to move and pos the
// place of the point itself (they differ for the end of an arc: the centre moves)
function TDoc.MovablePoint(const r: TRef; out mover: TPR; out pos: TPt): Boolean;
var
  s: TShape;
begin
  Result := False;
  if PointOf(r, mover) then
  begin
    pos := mover.S.P[mover.I];
    Exit(True);
  end;
  if ArcEndOf(r, s, pos) then
  begin
    mover.S := s;
    mover.I := 0;
    Result := True;
  end;
end;

function TDoc.PointOf(const r: TRef; out p: TPR): Boolean;
var
  s: TShape;
begin
  Result := False;
  s := FindShape(r.Shape);
  if s = nil then Exit;
  if (r.Idx >= 0) and (r.Idx < SegBase) then
  begin
    if r.Idx >= Length(s.P) then Exit;
    p.S := s;
    p.I := r.Idx;
    Result := True;
  end
  else if (r.Idx = -1) and (s.Kind in [skEllipse, skArc, skText, skPath, skImage]) then
  begin
    p.S := s;
    p.I := 0;
    Result := True;
  end;
end;

// the index of the corner of a rectangle that has the x of point xo (0 or 1) and the y of point yo (0 or 1)
function RectCorner(xo, yo: Integer): Integer;
begin
  if (xo = 0) and (yo = 0) then Result := 0
  else if (xo = 1) and (yo = 0) then Result := 2
  else if (xo = 1) and (yo = 1) then Result := 1
  else Result := 3;
end;

function TDoc.SegOf(const r: TRef; out a, b: TPR): Boolean;
var
  s: TShape;
  k, n, xl, xr, yt, yb: Integer;
begin
  Result := False;
  s := FindShape(r.Shape);
  if s = nil then Exit;
  a.S := s;
  b.S := s;
  if (s.Kind in [skLine, skArrow]) and (r.Idx = -1) and (Length(s.P) >= 2) then
  begin
    a.I := 0;
    b.I := 1;
    Result := True;
  end
  else if (s.Kind in [skPolyline, skPolygon]) and (r.Idx >= SegBase) then
  begin
    k := r.Idx - SegBase;
    n := Length(s.P);
    if (k < 0) or (k >= n) then Exit;
    a.I := k;
    if s.Kind = skPolygon then b.I := (k + 1) mod n
    else if k + 1 < n then b.I := k + 1
    else Exit;
    Result := True;
  end
  else if (s.Kind = skRect) and (r.Idx >= SegBase) and (Length(s.P) = 4) then
  begin
    // the sides of a rectangle: top, right, bottom, left (the corners are 0 = (x0, y0), 2 = (x1, y0), 1 = (x1, y1), 3 = (x0, y1))
    k := r.Idx - SegBase;
    if (k < 0) or (k > 3) then Exit;
    // which of the points holds the left / right and the top / bottom
    if s.P[0].x <= s.P[1].x then begin xl := 0; xr := 1; end else begin xl := 1; xr := 0; end;
    if s.P[0].y <= s.P[1].y then begin yt := 0; yb := 1; end else begin yt := 1; yb := 0; end;
    case k of
      0: begin a.I := RectCorner(xl, yt); b.I := RectCorner(xr, yt); end;
      1: begin a.I := RectCorner(xr, yt); b.I := RectCorner(xr, yb); end;
      2: begin a.I := RectCorner(xl, yb); b.I := RectCorner(xr, yb); end;
    else
      begin a.I := RectCorner(xl, yt); b.I := RectCorner(xl, yb); end;
    end;
    Result := True;
  end;
end;

function TDoc.EllOf(const r: TRef): TShape;
begin
  Result := FindShape(r.Shape);
  if (Result <> nil) and not ((Result.Kind in [skEllipse, skArc]) and (r.Idx = -1)) then
    Result := nil;
end;

function TDoc.CheckConstraint(kind: TConstraintKind; const refs: TRefArray): string;
var
  i, np, ns, ne, n: Integer;
  a, b: TPR;
  s1, s2: TShape;
  pt0: TPt;
begin
  Result := '';
  n := Length(refs);
  np := 0; ns := 0; ne := 0;
  for i := 0 to n - 1 do
  begin
    if PointOf(refs[i], a) or ArcEndOf(refs[i], s1, pt0) then Inc(np);
    if SegOf(refs[i], a, b) then Inc(ns);
    if EllOf(refs[i]) <> nil then Inc(ne);
  end;
  case kind of
    ckFixed:
      if n < 1 then Result := 'Select at least one object or point.';
    ckHorizontal, ckVertical:
      if not (((n = 1) and (ns = 1)) or ((n = 2) and (np = 2))) then
        Result := 'Select one line or two points.';
    ckParallel, ckPerpendicular:
      if not ((n = 2) and (ns = 2)) then Result := 'Select two lines (or segments).';
    ckEqual:
      if not ((n >= 2) and (ns = n)) then Result := 'Select two or more lines (or segments).';
    ckCoaxial:
      if not ((n >= 2) and (np = n)) then
        Result := 'Select two or more points / circle centers.';
    ckCoradial:
      if not ((n >= 2) and (ne = n)) then Result := 'Select two or more circles/ellipses.';
    ckMidPoint:
      if not ((n = 2) and (np >= 1) and (ns = 1)) then Result := 'Select a point and a line.';
    ckIntersection:
      if not (((n = 2) and (ns = 1) and (np >= 1)) or ((n = 3) and (ns = 2) and (np >= 1))) then
        Result := 'Select a point and one or two lines.';
    ckOnCurve:
      if not ((n = 2) and (EllOf(refs[1]) <> nil) and (refs[0].Idx <> -1) and
              (PointOf(refs[0], a) or ArcEndOf(refs[0], s1, pt0)) and (refs[0].Shape <> refs[1].Shape)) then
        Result := 'Select a point and a circle / ellipse / arc.';
    ckTangent:
      if not ((n = 2) and (((ns = 1) and (ne = 1)) or (ne = 2))) then
        Result := 'Select a line and a circle, or two circles.';
    ckSymmetry:
      begin
        if n <> 3 then
          Result := 'Select two points (or two similar objects) and then the axis line.'
        else if not SegOf(refs[2], a, b) then
          Result := 'The last selected object must be the axis line.'
        else
        begin
          s1 := FindShape(refs[0].Shape);
          s2 := FindShape(refs[1].Shape);
          if (s1 = nil) or (s2 = nil) then Result := 'Invalid selection.'
          else if (refs[0].Idx >= 0) and (refs[1].Idx >= 0) then
          begin
            if not (PointOf(refs[0], a) and PointOf(refs[1], b)) then
              Result := 'Invalid points.';
          end
          else if (refs[0].Idx <> -1) or (refs[1].Idx <> -1) or (s1.Kind <> s2.Kind) or
                  (Length(s1.P) <> Length(s2.P)) or (s1 = s2) then
            Result := 'The two objects must be different and of the same type.';
        end;
      end;
    ckDistance:
      if not (((n = 1) and (ns = 1)) or ((n = 2) and (np = 2)) or
              ((n = 2) and (np >= 1) and (ns = 1))) then
        Result := 'Select a line, two points, or a point and a line.';
    ckRadius:
      if not ((n = 1) and (ne = 1)) then Result := 'Select one circle or ellipse.';
    ckAngle:
      if not ((n = 2) and (ns = 2)) then Result := 'Select two lines (or segments).';
  end;
end;

procedure TDoc.InitQuote(c: TConstraint);
var
  a, b, p, a2, b2: TPR;
  vp: TPt;
  ang1, sw, k1: Double;
  dx, dy, nx, ny, l: Double;
  s: TShape;
begin
  c.Aux := 1;
  c.Offset := 30;
  if c.Kind = ckRadius then
  begin
    s := EllOf(c.Refs[0]);
    if s <> nil then c.Value := s.RX;
    c.Offset := -Pi / 4;
    Exit;
  end;
  if c.Kind = ckAngle then
  begin
    c.Aux := 3;
    c.Offset := 40;
    if SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2) and QuoteAngle(c, vp, ang1, sw) then
    begin
      // rays point from the vertex towards the middle of each line
      if (a.S.P[a.I].x + b.S.P[b.I].x - 2 * vp.x) * (b.S.P[b.I].x - a.S.P[a.I].x) +
         (a.S.P[a.I].y + b.S.P[b.I].y - 2 * vp.y) * (b.S.P[b.I].y - a.S.P[a.I].y) >= 0 then k1 := 1 else k1 := 0;
      if (a2.S.P[a2.I].x + b2.S.P[b2.I].x - 2 * vp.x) * (b2.S.P[b2.I].x - a2.S.P[a2.I].x) +
         (a2.S.P[a2.I].y + b2.S.P[b2.I].y - 2 * vp.y) * (b2.S.P[b2.I].y - a2.S.P[a2.I].y) >= 0 then k1 := k1 + 2;
      c.Aux := k1;
      QuoteAngle(c, vp, ang1, sw);
      c.Value := Abs(sw) * 180 / Pi;
    end;
    Exit;
  end;
  if (Length(c.Refs) = 1) and SegOf(c.Refs[0], a, b) then
  begin
    dx := b.S.P[b.I].x - a.S.P[a.I].x;
    dy := b.S.P[b.I].y - a.S.P[a.I].y;
  end
  else if (Length(c.Refs) = 2) and PointOf(c.Refs[0], a) and PointOf(c.Refs[1], b) then
  begin
    dx := b.S.P[b.I].x - a.S.P[a.I].x;
    dy := b.S.P[b.I].y - a.S.P[a.I].y;
  end
  else
  begin
    // point / line
    if PointOf(c.Refs[0], p) and SegOf(c.Refs[1], a, b) then
    else if PointOf(c.Refs[1], p) and SegOf(c.Refs[0], a, b) then;
    dx := b.S.P[b.I].x - a.S.P[a.I].x;
    dy := b.S.P[b.I].y - a.S.P[a.I].y;
    l := Hypot(dx, dy);
    if l < 1e-9 then l := 1;
    nx := -dy / l;
    ny := dx / l;
    l := (p.S.P[p.I].x - a.S.P[a.I].x) * nx + (p.S.P[p.I].y - a.S.P[a.I].y) * ny;
    if l < 0 then c.Aux := -1;
    c.Value := Abs(l);
    Exit;
  end;
  case c.Axis of
    1: begin c.Value := Abs(dx); if dx < 0 then c.Aux := -1; end;
    2: begin c.Value := Abs(dy); if dy < 0 then c.Aux := -1; end;
  else
    c.Value := Hypot(dx, dy);
  end;
end;

function TDoc.QuoteEnds(c: TConstraint; out a, b: TPt): Boolean;
var
  pa, pb, pp: TPR;
  L, ux, uy, t: Double;
begin
  Result := False;
  if Length(c.Refs) = 1 then
  begin
    if not SegOf(c.Refs[0], pa, pb) then Exit;
    a := pa.S.P[pa.I];
    b := pb.S.P[pb.I];
    Exit(True);
  end;
  if Length(c.Refs) <> 2 then Exit;
  if PointOf(c.Refs[0], pa) and PointOf(c.Refs[1], pb) then
  begin
    a := pa.S.P[pa.I];
    b := pb.S.P[pb.I];
    Exit(True);
  end;
  if PointOf(c.Refs[0], pp) and SegOf(c.Refs[1], pa, pb) then
  else if PointOf(c.Refs[1], pp) and SegOf(c.Refs[0], pa, pb) then
  else Exit;
  L := Hypot(pb.S.P[pb.I].x - pa.S.P[pa.I].x, pb.S.P[pb.I].y - pa.S.P[pa.I].y);
  if L < 1e-9 then Exit;
  ux := (pb.S.P[pb.I].x - pa.S.P[pa.I].x) / L;
  uy := (pb.S.P[pb.I].y - pa.S.P[pa.I].y) / L;
  t := (pp.S.P[pp.I].x - pa.S.P[pa.I].x) * ux + (pp.S.P[pp.I].y - pa.S.P[pa.I].y) * uy;
  a := pp.S.P[pp.I];
  b := MakePt(pa.S.P[pa.I].x + ux * t, pa.S.P[pa.I].y + uy * t);
  Result := True;
end;

function QuoteNum(v: Double): string;
begin
  Result := FormatFloat('0.##', v);
end;

// the scale factor of the layer of the shape a quote measures (angles are not scaled)
function TDoc.QuoteScale(c: TConstraint): Double;
var
  s: TShape;
  l: TLayer;
begin
  Result := 1;
  if (c.Kind = ckAngle) or (Length(c.Refs) = 0) then Exit;
  s := FindShape(c.Refs[0].Shape);
  if s = nil then Exit;
  l := LayerOf(s);
  if (l <> nil) and (l.Scale > 0) then Result := l.Scale;
end;

function UnitSuffix(c: TConstraint): string;
begin
  if (c.UnitText <> '') and (c.Kind <> ckAngle) then Result := ' ' + c.UnitText else Result := '';
end;

// z = screen pixels per document unit: sizes that are fixed on screen (angle label
// distance, arrow arc length) are divided by it
function TDoc.QuoteGeometry(c: TConstraint; z: Double; out g: TQuoteGeom): Boolean;
var
  a, b, p, e1, e2, d1, d2, lp: TPt;
  s: TShape;
  L, nx, ny, o, ang, t, X, Y: Double;
  k, q: Integer;

  procedure Seg(const pa, pb: TPt; dotted: Boolean);
  begin
    SetLength(g.Segs, Length(g.Segs) + 1);
    g.Segs[High(g.Segs)].A := pa;
    g.Segs[High(g.Segs)].B := pb;
    g.Segs[High(g.Segs)].Dotted := dotted;
  end;

  procedure Head(const tip, from: TPt);
  var
    hh, r: TPtArray;
    i: Integer;
  begin
    hh := ArrowHead(from, tip, 1);
    SetLength(r, 3);
    for i := 0 to 2 do
      r[i] := MakePt(tip.x + (hh[i].x - tip.x) * 0.7, tip.y + (hh[i].y - tip.y) * 0.7);
    SetLength(g.Heads, Length(g.Heads) + 1);
    g.Heads[High(g.Heads)] := r;
  end;

begin
  Result := False;
  SetLength(g.Segs, 0);
  SetLength(g.Arc, 0);
  SetLength(g.Heads, 0);
  g.Text := '';
  if z < 1e-6 then z := 1;
  if c.Kind = ckRadius then
  begin
    s := EllOf(c.Refs[0]);
    if s = nil then Exit;
    ang := c.Offset;
    e1 := MakePt(s.P[0].x + s.RX * Cos(ang), s.P[0].y + s.RY * Sin(ang));
    if c.Diam then d1 := MakePt(2 * s.P[0].x - e1.x, 2 * s.P[0].y - e1.y) else d1 := s.P[0];
    Seg(d1, e1, False);
    Head(e1, d1);
    if c.Diam then Head(d1, e1);
    if c.Diam then g.Text := 'Ø ' + QuoteNum(c.Value * 2 * QuoteScale(c)) + UnitSuffix(c)
    else g.Text := 'R ' + QuoteNum(c.Value * QuoteScale(c)) + UnitSuffix(c);
    lp := MakePt((d1.x + e1.x) / 2, (d1.y + e1.y) / 2);
    if not c.Diam then lp := MakePt(e1.x + Cos(ang) * 14, e1.y + Sin(ang) * 14);
  end
  else if c.Kind = ckAngle then
  begin
    if not QuoteAngle(c, p, ang, t) then Exit;
    L := Max(8, c.Offset);
    k := Max(8, Ceil(Abs(t) / 0.08));
    SetLength(g.Arc, k + 1);
    for q := 0 to k do
      g.Arc[q] := MakePt(p.x + L * Cos(ang + t * q / k), p.y + L * Sin(ang + t * q / k));
    e1 := g.Arc[0];
    e2 := g.Arc[k];
    Seg(p, e1, True);
    Seg(p, e2, True);
    o := Min(Abs(t) / 2, 10 / z / L);
    if t < 0 then o := -o;
    Head(e1, MakePt(p.x + L * Cos(ang + o), p.y + L * Sin(ang + o)));
    Head(e2, MakePt(p.x + L * Cos(ang + t - o), p.y + L * Sin(ang + t - o)));
    g.Text := QuoteNum(c.Value) + '°';
    lp := MakePt(p.x + (L + 14 / z) * Cos(ang + t / 2), p.y + (L + 14 / z) * Sin(ang + t / 2));
  end
  else
  begin
    if not QuoteEnds(c, a, b) then Exit;
    o := c.Offset;
    case c.Axis of
      1:
        begin
          Y := Min(a.y, b.y) - o;
          d1 := MakePt(a.x, Y);
          d2 := MakePt(b.x, Y);
        end;
      2:
        begin
          X := Min(a.x, b.x) - o;
          d1 := MakePt(X, a.y);
          d2 := MakePt(X, b.y);
        end;
    else
      L := Hypot(b.x - a.x, b.y - a.y);
      if L < 1e-9 then
      begin
        nx := 0;
        ny := -1;
      end
      else
      begin
        nx := -(b.y - a.y) / L;
        ny := (b.x - a.x) / L;
      end;
      d1 := MakePt(a.x + nx * o, a.y + ny * o);
      d2 := MakePt(b.x + nx * o, b.y + ny * o);
    end;
    Seg(a, d1, True);
    Seg(b, d2, True);
    Seg(d1, d2, False);
    Head(d1, d2);
    Head(d2, d1);
    g.Text := QuoteNum(c.Value * QuoteScale(c)) + UnitSuffix(c);
    lp := MakePt((d1.x + d2.x) / 2, (d1.y + d2.y) / 2);
  end;
  g.TextPos := lp;
  Result := True;
end;

function TDoc.AddConstraint(kind: TConstraintKind; const refs: TRefArray;
  out err: string): TConstraint;
begin
  Result := nil;
  err := CheckConstraint(kind, refs);
  if err <> '' then Exit;
  Result := TConstraint.Create;
  Result.Id := NextId;
  Inc(NextId);
  Result.Kind := kind;
  Result.Refs := Copy(refs);
  if Result.IsQuote then InitQuote(Result);
  Cons.Add(Result);
end;

var
  MirDepth: Integer = 0;

function ReflectPt(const p, a, u: TPt): TPt;
var
  vx, vy, d: Double;
begin
  vx := p.x - a.x;
  vy := p.y - a.y;
  d := vx * u.x + vy * u.y;
  Result := MakePt(a.x + 2 * d * u.x - vx, a.y + 2 * d * u.y - vy);
end;

function XfPt(const m: TXf; const p: TPt): TPt;
begin
  case m.Mode of
    1: Result := ReflectPt(p, m.A, m.U);
    2: Result := MakePt(p.x + m.DX, p.y + m.DY);
    3: Result := MakePt(m.C.x + (p.x - m.C.x) * m.Cs - (p.y - m.C.y) * m.Sn,
         m.C.y + (p.x - m.C.x) * m.Sn + (p.y - m.C.y) * m.Cs);
  else Result := p;
  end;
end;

procedure XfOutline(const m: TXf; const src: TOutline; out o: TOutline);
var
  i, j: Integer;
begin
  SetLength(o, Length(src));
  for i := 0 to High(src) do
  begin
    o[i].Closed := src[i].Closed;
    SetLength(o[i].Pts, Length(src[i].Pts));
    for j := 0 to High(src[i].Pts) do
      o[i].Pts[j] := XfPt(m, src[i].Pts[j]);
  end;
end;

function TArraySpec.N: Integer;
begin
  if Polar then Result := Count else Result := Cols * Rows;
end;

{ ---------- trim ---------- }

function TrimmableKind(k: TShapeKind): Boolean;
begin
  Result := k in [skLine, skPolyline, skPolygon, skRect, skEllipse, skArc, skSpline];
end;

function SegCountOf(const pl: TPolyline): Integer;
begin
  if pl.Closed then Result := Length(pl.Pts) else Result := Length(pl.Pts) - 1;
  if Result < 0 then Result := 0;
end;

// u parameters (0..1) where polyline tp crosses any polyline of co
procedure TrimHits(const tp: TPolyline; const co: TOutline; var hits: array of Double;
  out n: Integer);
var
  sc, j, i, k, m, cn: Integer;
  a, b, c, d: TPt;
  rx, ry, sx, sy, den, qx, qy, t, u: Double;
  cnt: Integer;
begin
  n := 0;
  sc := SegCountOf(tp);
  if sc < 1 then Exit;
  for j := 0 to sc - 1 do
  begin
    a := tp.Pts[j];
    b := tp.Pts[(j + 1) mod Length(tp.Pts)];
    rx := b.x - a.x;
    ry := b.y - a.y;
    for i := 0 to High(co) do
    begin
      cn := SegCountOf(co[i]);
      m := Length(co[i].Pts);
      for k := 0 to cn - 1 do
      begin
        c := co[i].Pts[k];
        d := co[i].Pts[(k + 1) mod m];
        sx := d.x - c.x;
        sy := d.y - c.y;
        den := rx * sy - ry * sx;
        if Abs(den) < 1e-12 then Continue;
        qx := c.x - a.x;
        qy := c.y - a.y;
        t := (qx * sy - qy * sx) / den;
        u := (qx * ry - qy * rx) / den;
        if (t < 0) or (t > 1) or (u < 0) or (u > 1) then Continue;
        if n <= High(hits) then
        begin
          hits[n] := (j + t) / sc;
          Inc(n);
        end;
      end;
    end;
  end;
  cnt := n;
  n := cnt;
end;

function TDoc.NearestU(s: TShape; x, y: Double; out poly: Integer; out u: Double): Boolean;
var
  o: TOutline;
  i, j, sc, m: Integer;
  best, d, t, abx, aby, l2: Double;
  a, b: TPt;
begin
  Result := False;
  poly := -1;
  u := 0;
  if not TrimmableKind(s.Kind) then Exit;
  EffectiveOutline(s, o);
  best := 1e18;
  for i := 0 to High(o) do
  begin
    sc := SegCountOf(o[i]);
    m := Length(o[i].Pts);
    for j := 0 to sc - 1 do
    begin
      a := o[i].Pts[j];
      b := o[i].Pts[(j + 1) mod m];
      d := DistToSegment(x, y, a.x, a.y, b.x, b.y);
      if d >= best then Continue;
      best := d;
      poly := i;
      abx := b.x - a.x;
      aby := b.y - a.y;
      l2 := abx * abx + aby * aby;
      if l2 < 1e-12 then t := 0
      else t := ((x - a.x) * abx + (y - a.y) * aby) / l2;
      if t < 0 then t := 0;
      if t > 1 then t := 1;
      u := (j + t) / sc;
    end;
  end;
  Result := poly >= 0;
end;

// hides the part of the outline between two points (parameters u1, u2); the
// original object is kept whole underneath
// Adds a joint on the side of a line / poly-line / polygon nearest to (x, y).  A straight
// line becomes a poly-line of two sides.  Constraint references are renumbered.
// Joins two open lines / poly-lines into one poly-line (a keeps its identity and style).
// The nearest pair of ends is used; a gap wider than half a unit is bridged by a new side.
// A rectangle becomes a polygon with four real corners (so sides can be constrained); a circle,
// ellipse or arc becomes a spline through points on it, which can be deformed.  The constraints
// that only make sense for the old shape (radius, centre, extreme points...) are dropped.
// a new control point on a spline (path), exactly where the curve passes nearest to (x, y)
// removes one control point of a spline (path); constraints on that point are dropped
// a poly-line becomes a polygon: its two ends are joined by a new side (or merged, when they
// already coincide)
function TDoc.ClosePolyline(s: TShape; out err: string): Boolean;
var
  n, ci, ri, k: Integer;
  c: TConstraint;
  same: Boolean;
begin
  Result := False;
  err := '';
  if (s.Kind <> skPolyline) or (Length(s.P) < 3) then
  begin
    err := 'Only a poly-line with at least three points can be closed.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  n := Length(s.P);
  if (Hypot(s.P[n - 1].x - s.P[0].x, s.P[n - 1].y - s.P[0].y) <= 0.5) and (n >= 4) then
  begin
    // the ends already meet: they become one corner
    for ci := Cons.Count - 1 downto 0 do
    begin
      c := Cons[ci];
      for ri := 0 to High(c.Refs) do
        if (c.Refs[ri].Shape = s.Id) and (c.Refs[ri].Idx = n - 1) then c.Refs[ri].Idx := 0;
      if (c.Kind = ckCoaxial) and (Length(c.Refs) >= 2) then
      begin
        same := True;
        for k := 1 to High(c.Refs) do
          if not SameRef(c.Refs[k], c.Refs[0]) then same := False;
        if same then Cons.Delete(ci);
      end;
    end;
    SetLength(s.P, n - 1);
  end;
  s.Kind := skPolygon;
  SetLength(s.W, 0);
  Result := True;
end;

// removes one control point of a spline (path); constraints on that point are dropped
function TDoc.RemoveSplinePoint(s: TShape; idx: Integer; out dropped: Integer; out err: string): Boolean;
var
  n, i, ci, ri, k, minPts, r, cnt: Integer;
  rlo, rhi: TRingArr;
  c: TConstraint;
  drop: Boolean;
begin
  Result := False;
  dropped := 0;
  err := '';
  if s.Kind <> skSpline then
  begin
    err := 'Only a point of a path (curve) can be removed this way.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  n := Length(s.P);
  if (idx < 0) or (idx >= n) then Exit;
  // the closed curve (or the open one) the point belongs to
  SplineRings(s, rlo, rhi);
  r := 0;
  for k := 0 to High(rlo) do
    if (idx >= rlo[k]) and (idx <= rhi[k]) then r := k;
  cnt := rhi[r] - rlo[r] + 1;
  if s.SplineClosed then minPts := 3 else minPts := 2;
  if cnt <= minPts then
  begin
    if s.SplineClosed then err := 'A closed curve needs at least 3 points.'
    else err := 'A path needs at least 2 points.';
    Exit;
  end;
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    for ri := 0 to High(c.Refs) do
    begin
      if (c.Refs[ri].Shape <> s.Id) or (c.Refs[ri].Idx < 0) or (c.Refs[ri].Idx >= SegBase) then Continue;
      if c.Refs[ri].Idx = idx then drop := True
      else if c.Refs[ri].Idx > idx then Dec(c.Refs[ri].Idx);
    end;
    if drop then
    begin
      Cons.Delete(ci);
      Inc(dropped);
    end;
  end;
  for i := idx to n - 2 do s.P[i] := s.P[i + 1];
  SetLength(s.P, n - 1);
  for k := 0 to High(s.RingStarts) do
    if s.RingStarts[k] > idx then Dec(s.RingStarts[k]);
  SetLength(s.W, 0);
  Result := True;
end;

// a new control point on a spline (path), exactly where the curve passes nearest to (x, y)
function TDoc.InsertSplinePoint(s: TShape; x, y: Double; out newIdx: Integer; out err: string): Boolean;
var
  c1, c2, rp: TPtArray;
  rlo, rhi: TRingArr;
  m, r, i, j, k, bi, bring, ci, ri, pos, q: Integer;
  t, bt, d, best, px, py: Double;
  qp: TPt;
  rclosed: Boolean;
begin
  Result := False;
  newIdx := -1;
  err := '';
  if (s.Kind <> skSpline) or (Length(s.P) < 2) then
  begin
    err := 'Only a path (curve) can get a new point.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  SplineRings(s, rlo, rhi);
  best := 1e300;
  bi := 0;
  bring := 0;
  bt := 0;
  for r := 0 to High(rlo) do
  begin
    m := rhi[r] - rlo[r] + 1;
    SetLength(rp, m);
    for i := 0 to m - 1 do rp[i] := s.P[rlo[r] + i];
    rclosed := s.SplineClosed and (m >= 3);
    SplineBezier(rp, c1, c2, rclosed);
    for i := 0 to High(c1) do
    begin
      j := (i + 1) mod m;
      for k := 0 to 60 do
      begin
        t := k / 60;
        px := Power(1 - t, 3) * rp[i].x + 3 * Sqr(1 - t) * t * c1[i].x + 3 * (1 - t) * t * t * c2[i].x + t * t * t * rp[j].x;
        py := Power(1 - t, 3) * rp[i].y + 3 * Sqr(1 - t) * t * c1[i].y + 3 * (1 - t) * t * t * c2[i].y + t * t * t * rp[j].y;
        d := Hypot(px - x, py - y);
        if d < best then
        begin
          best := d;
          bi := i;
          bring := r;
          bt := t;
          qp := MakePt(px, py);
        end;
      end;
    end;
  end;
  if (bt < 0.02) or (bt > 0.98) then
  begin
    err := 'Too close to an existing point: click farther from it.';
    Exit;
  end;
  // where the new point goes (after point bi of its ring) and the numbers that shift by one
  pos := rlo[bring] + bi + 1;
  for ci := 0 to Cons.Count - 1 do
    for ri := 0 to High(Cons[ci].Refs) do
      if (Cons[ci].Refs[ri].Shape = s.Id) and (Cons[ci].Refs[ri].Idx >= pos) and
         (Cons[ci].Refs[ri].Idx < SegBase) then
        Inc(Cons[ci].Refs[ri].Idx);
  q := Length(s.P);
  SetLength(s.P, q + 1);
  for i := q downto pos + 1 do s.P[i] := s.P[i - 1];
  s.P[pos] := qp;
  for k := 0 to High(s.RingStarts) do
    if s.RingStarts[k] >= pos then Inc(s.RingStarts[k]);
  SetLength(s.W, 0);
  newIdx := pos;
  Result := True;
end;

{ ---------- converting a fill ---------- }

// how much each point of a closed outline matters (Douglas-Peucker): the distance it has from the
// line between its neighbours when it is chosen.  The two base points matter most.
procedure RankOutline(const np: TFPtArray; out imp: TDblArr);
var
  n, i, far: Integer;
  sim: TFPtArray;
  d, dm: Double;

  procedure Dp(a, c: Integer);
  var
    q, im: Integer;
    dmax, dd: Double;
  begin
    if c <= a + 1 then Exit;
    dmax := -1;
    im := a + 1;
    for q := a + 1 to c - 1 do
    begin
      dd := DistToSegment(sim[q].x, sim[q].y, sim[a].x, sim[a].y, sim[c].x, sim[c].y);
      if dd > dmax then
      begin
        dmax := dd;
        im := q;
      end;
    end;
    imp[im] := dmax;
    Dp(a, im);
    Dp(im, c);
  end;

begin
  n := Length(np);
  SetLength(imp, n);
  for i := 0 to n - 1 do imp[i] := 0;
  if n < 3 then Exit;
  dm := -1;
  far := 1;
  for i := 1 to n - 1 do
  begin
    d := Hypot(np[i].x - np[0].x, np[i].y - np[0].y);
    if d > dm then
    begin
      dm := d;
      far := i;
    end;
  end;
  SetLength(sim, n + 1);
  for i := 0 to n - 1 do sim[i] := np[i];
  sim[n] := np[0];
  imp[0] := 1e30;
  imp[far] := 1e30;
  Dp(0, far);
  Dp(far, n);
end;

// the count most important points, in their original order
function PickOutline(const np: TFPtArray; const imp: TDblArr; count: Integer): TFPtArray;
var
  n, i, j, k: Integer;
  idx: array of Integer;
  t: Integer;
  keep: array of Boolean;
begin
  n := Length(np);
  SetLength(Result, 0);
  if count >= n then
  begin
    Result := Copy(np);
    Exit;
  end;
  SetLength(idx, n);
  for i := 0 to n - 1 do idx[i] := i;
  // by importance, biggest first (insertion sort: the outlines are short)
  for i := 1 to n - 1 do
  begin
    t := idx[i];
    j := i - 1;
    while (j >= 0) and (imp[idx[j]] < imp[t]) do
    begin
      idx[j + 1] := idx[j];
      Dec(j);
    end;
    idx[j + 1] := t;
  end;
  SetLength(keep, n);
  for i := 0 to n - 1 do keep[i] := False;
  for k := 0 to count - 1 do keep[idx[k]] := True;
  for i := 0 to n - 1 do
    if keep[i] then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := np[i];
    end;
end;

// largest distance between a closed smooth curve through pts and the outline np
function CurveDeviation(const pts, np: TFPtArray): Double;
var
  c1, c2, tp: TPtArray;
  i, j, k, n, m, jj: Integer;
  t, x, y, d, best, dmin: Double;
begin
  Result := 0;
  n := Length(pts);
  if n < 3 then Exit(1e30);
  SetLength(tp, n);
  for i := 0 to n - 1 do tp[i] := MakePt(pts[i].x, pts[i].y);
  SplineBezier(tp, c1, c2, True);
  m := Length(np);
  best := 0;
  for i := 0 to n - 1 do
  begin
    j := (i + 1) mod n;
    for k := 1 to 8 do
    begin
      t := k / 8;
      x := Power(1 - t, 3) * tp[i].x + 3 * Sqr(1 - t) * t * c1[i].x + 3 * (1 - t) * t * t * c2[i].x + t * t * t * tp[j].x;
      y := Power(1 - t, 3) * tp[i].y + 3 * Sqr(1 - t) * t * c1[i].y + 3 * (1 - t) * t * t * c2[i].y + t * t * t * tp[j].y;
      dmin := 1e30;
      for jj := 0 to m - 1 do
      begin
        d := DistToSegment(x, y, np[jj].x, np[jj].y, np[(jj + 1) mod m].x, np[(jj + 1) mod m].y);
        if d < dmin then dmin := d;
      end;
      if dmin > best then best := dmin;
    end;
  end;
  Result := best;
end;

function FillOutline(b: TShape): TFPtArray;
var
  i: Integer;
begin
  SetLength(Result, 0);
  if (not b.Bucket) or (Length(b.Flat) = 0) or (Length(b.P) < 1) then Exit;
  SetLength(Result, Length(b.Flat[0]));
  for i := 0 to High(Result) do
  begin
    Result[i].x := b.Flat[0][i].x + b.P[0].x;
    Result[i].y := b.Flat[0][i].y + b.P[0].y;
  end;
  // the outline closes on its first point: that last copy is not a point of its own
  if (Length(Result) > 3) and (Hypot(Result[0].x - Result[High(Result)].x, Result[0].y - Result[High(Result)].y) < 1e-6) then
    SetLength(Result, Length(Result) - 1);
end;

// count points along a closed outline for a smooth curve: the corners stay, the rest is spread
// evenly by length (more points than the outline has are made on its sides)
function ResampleOutline(const np: TFPtArray; count: Integer): TFPtArray;
var
  n, i, j, k, m, a, bI: Integer;
  cum: array of Double;
  total, sPos, best, g, sa, sb, t, d1x, d1y, d2x, d2y, l1, l2, ang: Double;
  pos: array of Double;
  corner: array of Boolean;
  nc: Integer;

  function PointAtS(sv: Double): TFPtArray;
  var
    q: Integer;
    u: Double;
  begin
    SetLength(Result, 1);
    while sv >= total do sv := sv - total;
    q := 0;
    while (q < n - 1) and (cum[q + 1] <= sv) do Inc(q);
    if cum[q + 1 - 0] - cum[q] < 1e-12 then u := 0 else u := (sv - cum[q]) / (cum[q + 1] - cum[q]);
    Result[0].x := np[q].x + u * (np[(q + 1) mod n].x - np[q].x);
    Result[0].y := np[q].y + u * (np[(q + 1) mod n].y - np[q].y);
  end;

begin
  n := Length(np);
  SetLength(Result, 0);
  if n < 3 then Exit;
  SetLength(cum, n + 1);
  cum[0] := 0;
  for i := 0 to n - 1 do
    cum[i + 1] := cum[i] + Hypot(np[(i + 1) mod n].x - np[i].x, np[(i + 1) mod n].y - np[i].y);
  total := cum[n];
  if total < 1e-9 then Exit;
  // corners: where the outline turns by more than 25 degrees
  SetLength(corner, n);
  nc := 0;
  for i := 0 to n - 1 do
  begin
    j := (i + n - 1) mod n;
    k := (i + 1) mod n;
    d1x := np[i].x - np[j].x;
    d1y := np[i].y - np[j].y;
    d2x := np[k].x - np[i].x;
    d2y := np[k].y - np[i].y;
    l1 := Hypot(d1x, d1y);
    l2 := Hypot(d2x, d2y);
    corner[i] := False;
    if (l1 > 1e-9) and (l2 > 1e-9) then
    begin
      ang := ArcTan2(d1x * d2y - d1y * d2x, d1x * d2x + d1y * d2y);
      if Abs(ang) > 25 * Pi / 180 then
      begin
        corner[i] := True;
        Inc(nc);
      end;
    end;
  end;
  SetLength(pos, 0);
  for i := 0 to n - 1 do
    if corner[i] then
    begin
      SetLength(pos, Length(pos) + 1);
      pos[High(pos)] := cum[i];
    end;
  if Length(pos) < 2 then
  begin
    SetLength(pos, 2);
    pos[0] := 0;
    pos[1] := total / 2;
  end;
  // more points: the middle of the longest gap, again and again
  while Length(pos) < count do
  begin
    best := -1;
    a := 0;
    for i := 0 to High(pos) do
    begin
      if i < High(pos) then g := pos[i + 1] - pos[i] else g := total - pos[i] + pos[0];
      if g > best then
      begin
        best := g;
        a := i;
      end;
    end;
    sa := pos[a];
    t := sa + best / 2;
    if t >= total then t := t - total;
    SetLength(pos, Length(pos) + 1);
    // insert in order
    m := High(pos);
    while (m > 0) and (pos[m - 1] > t) do
    begin
      pos[m] := pos[m - 1];
      Dec(m);
    end;
    pos[m] := t;
  end;
  SetLength(Result, Length(pos));
  for i := 0 to High(pos) do Result[i] := PointAtS(pos[i])[0];
end;

// an outline with holes passes twice through the corners of the bridges
function OutlineHasHoles(const np: TFPtArray): Boolean;
var
  i, j, n: Integer;
begin
  Result := False;
  n := Length(np);
  for i := 0 to n - 1 do
    for j := i + 2 to n - 1 do
      if (not ((i = 0) and (j = n - 1))) and (Hypot(np[i].x - np[j].x, np[i].y - np[j].y) < 1e-6) then Exit(True);
end;

// the number of points that is a good compromise: as few as possible for a polygon within half a
// unit of the area, for a curve within a unit (the sum over its closed curves)
// the smallest number of points that keeps the polygon within half a unit of the rounded rectangle
// (the closed smooth curve: within one unit)
function TDoc.SuggestRoundRectPoints(s: TShape; asPath: Boolean): Integer;
var
  n, i, j: Integer;
  tmp: TShape;
  o, oo: TOutline;
  tol, e, d: Double;
begin
  Result := 8;
  oo := ShapeOutline(s);
  if (Length(oo) = 0) or (CornerOf(s) <= 0) then Exit;
  if asPath then tol := 1.0 else tol := 0.5;
  n := 8;
  while n <= 400 do
  begin
    tmp := TShape.Create;
    try
      if asPath then tmp.Kind := skSpline else tmp.Kind := skPolygon;
      tmp.SplineClosed := True;
      tmp.P := RoundRectPoints(s, n, asPath);
      o := ShapeOutline(tmp);
      e := 0;
      if Length(o) > 0 then
      begin
        for i := 0 to High(o[0].Pts) do
          e := Max(e, DistToOutline(oo, o[0].Pts[i].x, o[0].Pts[i].y, False));
        for j := 0 to High(oo[0].Pts) do
        begin
          d := DistToOutline(o, oo[0].Pts[j].x, oo[0].Pts[j].y, False);
          e := Max(e, d);
        end;
      end;
    finally
      tmp.Free;
    end;
    Result := n;
    if e <= tol then Exit;
    Inc(n, 4);
  end;
end;

function TDoc.SuggestFillPoints(b: TShape; asPath: Boolean; out hasHoles: Boolean; out total: Integer): Integer;
var
  np, pk: TFPtArray;
  imp: TDblArr;
  n, lo, hi, mid, i, k, sum: Integer;
begin
  np := FillOutline(b);
  n := Length(np);
  total := n;
  hasHoles := OutlineHasHoles(np) or (Length(b.BucketLoops) > 1);
  Result := Max(3, n);
  if (n < 3) and (Length(b.BucketLoops) = 0) then Exit;
  if asPath then
  begin
    if Length(b.BucketLoops) = 0 then Exit;
    sum := 0;
    total := 0;
    for k := 0 to High(b.BucketLoops) do
    begin
      np := b.BucketLoops[k].Pts;
      total := total + Length(np);
      lo := 3;
      hi := Min(Max(3, Length(np)), 200);
      if Length(np) < 3 then
      begin
        sum := sum + 3;
        Continue;
      end;
      hi := 200;
      // the smallest count whose smooth curve stays within a unit of this outline
      while lo < hi do
      begin
        mid := (lo + hi) div 2;
        pk := ResampleOutline(np, mid);
        if CurveDeviation(pk, np) <= 1 then hi := mid else lo := mid + 1;
      end;
      sum := sum + Max(3, lo);
    end;
    Result := Max(3, sum);
    Exit;
  end;
  if (n < 3) or hasHoles then Exit;
  RankOutline(np, imp);
  // the points that matter more than half a unit
  Result := 2;
  for i := 0 to n - 1 do
    if (imp[i] > 0.5) and (imp[i] < 1e29) then Inc(Result);
  Result := Max(3, Min(Result, n));
end;

// a fill becomes a shape of its own (a polygon, or a smooth closed path through count points):
// it no longer follows the lines that made it.  A path keeps the holes as closed curves of their own.
function TDoc.ConvertBucket(b: TShape; count: Integer; asPath: Boolean; out err: string): Boolean;
var
  np, pk, ring: TFPtArray;
  imp: TDblArr;
  j, k, nr: Integer;
  perim: array of Double;
  sumL: Double;
  starts: TRingArr;
  pts: TPtArray;
begin
  Result := False;
  err := '';
  if asPath then
  begin
    if Length(b.BucketLoops) = 0 then
    begin
      err := 'The area of this fill is not known: touch one of its lines and try again.';
      Exit;
    end;
    // the points are shared among the closed curves by their length
    nr := Length(b.BucketLoops);
    SetLength(perim, nr);
    sumL := 0;
    for k := 0 to nr - 1 do
    begin
      np := b.BucketLoops[k].Pts;
      perim[k] := 0;
      for j := 0 to High(np) do
        perim[k] := perim[k] + Hypot(np[(j + 1) mod Length(np)].x - np[j].x, np[(j + 1) mod Length(np)].y - np[j].y);
      sumL := sumL + perim[k];
    end;
    SetLength(pts, 0);
    SetLength(starts, 0);
    for k := 0 to nr - 1 do
    begin
      if sumL > 1e-9 then j := Max(3, Round(Max(3, count) * perim[k] / sumL)) else j := 3;
      ring := ResampleOutline(b.BucketLoops[k].Pts, j);
      if Length(ring) < 3 then Continue;
      if Length(pts) > 0 then
      begin
        SetLength(starts, Length(starts) + 1);
        starts[High(starts)] := Length(pts);
      end;
      for j := 0 to High(ring) do
      begin
        SetLength(pts, Length(pts) + 1);
        pts[High(pts)] := MakePt(ring[j].x, ring[j].y);
      end;
    end;
    if Length(pts) < 3 then
    begin
      err := 'This is not a fill.';
      Exit;
    end;
    b.P := pts;
    b.RingStarts := Copy(starts);
    b.Kind := skSpline;
    b.SplineClosed := True;
  end
  else
  begin
    np := FillOutline(b);
    if Length(np) < 3 then
    begin
      err := 'This is not a fill.';
      Exit;
    end;
    if OutlineHasHoles(np) or (Length(b.BucketLoops) > 1) then pk := np     // keeps every point: the holes stay as they are
    else
    begin
      RankOutline(np, imp);
      pk := PickOutline(np, imp, Max(3, count));
    end;
    SetLength(b.P, Length(pk));
    for j := 0 to High(pk) do b.P[j] := MakePt(pk[j].x, pk[j].y);
    b.Kind := skPolygon;
  end;
  b.Bucket := False;
  b.BucketIgnoreLower := False;
  SetLength(b.BucketIds, 0);
  SetLength(b.BucketSeeds, 0);
  SetLength(b.BucketSeedUV, 0);
  SetLength(b.BucketLoops, 0);
  SetLength(b.Flat, 0);
  b.PathData := '';
  b.BucketBroken := False;
  SetLength(b.W, 0);
  FBucketHash := 0;
  Result := True;
end;

// a turned shape is converted as it is seen: the points that come out are turned, and the shape stands upright
function TDoc.ConvertShape(s: TShape; pointCount: Integer; out dropped: Integer; out err: string;
  asPath: Boolean): Boolean;
var
  rot0: Double;
  pv0: TPt;
  i: Integer;
begin
  rot0 := s.Rot;
  pv0 := ShapePivot(s);
  Result := ConvertShapeCore(s, pointCount, dropped, err, asPath);
  if Result and (rot0 <> 0) then
  begin
    for i := 0 to High(s.P) do s.P[i] := TurnPt(s.P[i], pv0, rot0);
    s.Rot := 0;
  end;
end;

function TDoc.ConvertShapeCore(s: TShape; pointCount: Integer; out dropped: Integer; out err: string;
  asPath: Boolean): Boolean;
var
  i, ci, ri, n: Integer;
  c: TConstraint;
  drop: Boolean;
  cx, cy, rx, ry, a1, sw, a: Double;
  x1, y1, x2, y2: Double;
  f: TShape;
  pts: TPtArray;
  closed: Boolean;
begin
  Result := False;
  dropped := 0;
  err := '';
  if not (s.Kind in [skRect, skEllipse, skArc]) then
  begin
    err := 'Only a rectangle, circle, ellipse or arc can be converted.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  for i := 0 to Shapes.Count - 1 do
  begin
    f := Shapes[i];
    if (f.FA > 0) and ((f.FA = s.Id) or (f.FB = s.Id)) then
    begin
      err := 'This object is joined by a fillet / chamfer: remove it first.';
      Exit;
    end;
  end;
  if (s.Kind = skRect) and (CornerOf(s) > 0) then
  begin
    // rounded corners: the outline becomes a polygon or a closed smooth curve of pointCount points
    pts := RoundRectPoints(s, pointCount, asPath);
    if Length(pts) < 3 then Exit;
    s.P := pts;
    if asPath then
    begin
      s.Kind := skSpline;
      s.SplineClosed := True;
    end
    else s.Kind := skPolygon;
    s.Corner := 0;
    s.Circ := False;
    for ci := Cons.Count - 1 downto 0 do
    begin
      c := Cons[ci];
      drop := False;
      for ri := 0 to High(c.Refs) do
        if (c.Refs[ri].Shape = s.Id) and not ((c.Kind = ckFixed) and (c.Refs[ri].Idx = -1)) then drop := True;
      if drop then
      begin
        Cons.Delete(ci);
        Inc(dropped);
      end;
    end;
    SetLength(s.W, 0);
    Result := True;
    Exit;
  end;
  if s.Kind = skRect then
  begin
    if Length(s.P) < 2 then Exit;
    x1 := s.P[0].x;
    y1 := s.P[0].y;
    x2 := s.P[1].x;
    y2 := s.P[1].y;
    SetLength(s.P, 4);
    s.P[0] := MakePt(x1, y1);
    s.P[1] := MakePt(x2, y1);
    s.P[2] := MakePt(x2, y2);
    s.P[3] := MakePt(x1, y2);
    s.Kind := skPolygon;
    // the old corners 0 and 1 (opposite ones) are now corners 0 and 2
    for ci := 0 to Cons.Count - 1 do
      for ri := 0 to High(Cons[ci].Refs) do
        if (Cons[ci].Refs[ri].Shape = s.Id) and (Cons[ci].Refs[ri].Idx = 1) then
          Cons[ci].Refs[ri].Idx := 2;
  end
  else
  begin
    if Length(s.P) < 1 then Exit;
    cx := s.P[0].x;
    cy := s.P[0].y;
    rx := s.RX;
    ry := s.RY;
    closed := s.Kind = skEllipse;
    // number of points: asked by the caller (at least 3), 12 by default
    n := Max(3, pointCount);
    if pointCount <= 0 then n := 12;
    if closed then
    begin
      a1 := 0;
      sw := 2 * Pi;
    end
    else
    begin
      a1 := s.A1;
      sw := ArcSweep(s);
    end;
    SetLength(pts, n);
    for i := 0 to n - 1 do
    begin
      if closed then a := a1 + sw * i / n else a := a1 + sw * i / (n - 1);
      pts[i] := MakePt(cx + rx * Cos(a), cy + ry * Sin(a));
    end;
    s.P := pts;
    s.Kind := skSpline;
    s.SplineClosed := closed;
    s.Circ := False;
    // constraints that referred to the centre, the radius, the extreme points, ...
    for ci := Cons.Count - 1 downto 0 do
    begin
      c := Cons[ci];
      drop := False;
      for ri := 0 to High(c.Refs) do
        if (c.Refs[ri].Shape = s.Id) and not ((c.Kind = ckFixed) and (c.Refs[ri].Idx = -1)) then drop := True;
      if drop then
      begin
        Cons.Delete(ci);
        Inc(dropped);
      end;
    end;
  end;
  SetLength(s.W, 0);
  Result := True;
end;

function TDoc.JoinShapes(a, b: TShape; out dropped: Integer; out gap: Double;
  out err: string): Boolean;
var
  na, nb, ea, eb, i, j, ci, ri, m, k, newN: Integer;
  d, best: Double;
  merged: Boolean;
  mapA, mapB: array of Integer;
  newP: TPtArray;
  c: TConstraint;
  drop: Boolean;
  nr: TRefArray;
  sh: TShape;

  function Blocked(s: TShape): string;
  var
    q: Integer;
  begin
    Result := '';
    if not (s.Kind in [skLine, skPolyline, skSpline]) then
      Result := 'Only lines, poly-lines and splines can be joined.'
    else if (s.Kind = skSpline) and (s.SplineClosed or (Length(s.RingStarts) > 0)) then
      Result := 'A closed curve has no ends to join.'
    else if (s.Kind = skSpline) <> (a.Kind = skSpline) then
      Result := 'A spline can only be joined to another spline.'
    else if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) or (ArrayOf(s) <> nil) then
      Result := 'A derived copy or the source of an array cannot be joined: detach / explode it first.'
    else if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
      Result := 'Restore the trimmed / extended object first.'
    else
      for q := 0 to Shapes.Count - 1 do
        if (Shapes[q].FA > 0) and ((Shapes[q].FA = s.Id) or (Shapes[q].FB = s.Id)) then
          Result := 'A line joined by a fillet / chamfer cannot be joined: remove it first.';
  end;

  function MapRef(const r: TRef): TRef;
  begin
    Result := r;
    if r.Shape = a.Id then sh := a else sh := b;
    if (r.Idx >= 0) and (r.Idx < SegBase) then
    begin
      if sh = a then Result.Idx := mapA[r.Idx] else Result.Idx := mapB[r.Idx];
    end
    else if r.Idx >= SegBase then
    begin
      k := r.Idx - SegBase;
      if sh = a then Result.Idx := SegBase + Min(mapA[k], mapA[k + 1])
      else Result.Idx := SegBase + Min(mapB[k], mapB[k + 1]);
    end;
    Result.Shape := a.Id;
  end;

begin
  Result := False;
  dropped := 0;
  gap := 0;
  err := '';
  if a = b then
  begin
    err := 'Pick two different objects.';
    Exit;
  end;
  err := Blocked(a);
  if err = '' then err := Blocked(b);
  if err <> '' then Exit;
  na := Length(a.P);
  nb := Length(b.P);
  if (na < 2) or (nb < 2) then Exit;
  // nearest pair of ends
  best := 1e18;
  ea := 1;
  eb := 0;
  for i := 0 to 1 do
    for j := 0 to 1 do
    begin
      d := Hypot(a.P[IfThen(i = 0, 0, na - 1)].x - b.P[IfThen(j = 0, 0, nb - 1)].x,
                 a.P[IfThen(i = 0, 0, na - 1)].y - b.P[IfThen(j = 0, 0, nb - 1)].y);
      if d < best then
      begin
        best := d;
        ea := i;
        eb := j;
      end;
    end;
  gap := best;
  merged := best <= 0.5;
  // new order: a (reversed when joined at its start) followed by b (reversed when joined at its end)
  SetLength(mapA, na);
  SetLength(mapB, nb);
  for i := 0 to na - 1 do
    if ea = 0 then mapA[i] := na - 1 - i else mapA[i] := i;
  for j := 0 to nb - 1 do
  begin
    k := IfThen(eb = 0, j, nb - 1 - j);       // position in b read from the joined end
    if merged then mapB[j] := na - 1 + k else mapB[j] := na + k;
  end;
  newN := mapB[0];
  for j := 0 to nb - 1 do newN := Max(newN, mapB[j]);
  Inc(newN);
  SetLength(newP, newN);
  for i := 0 to na - 1 do newP[mapA[i]] := a.P[i];
  for j := 0 to nb - 1 do
    if not (merged and (mapB[j] = na - 1)) then newP[mapB[j]] := b.P[j];
  // constraints
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    SetLength(nr, 0);
    for ri := 0 to High(c.Refs) do
    begin
      if (c.Refs[ri].Shape <> a.Id) and (c.Refs[ri].Shape <> b.Id) then
      begin
        SetLength(nr, Length(nr) + 1);
        nr[High(nr)] := c.Refs[ri];
        Continue;
      end;
      if c.Refs[ri].Shape = a.Id then sh := a else sh := b;
      if c.Refs[ri].Idx = -1 then
      begin
        if c.Kind = ckFixed then
        begin
          // the whole object was fixed: fix each of its points
          for m := 0 to Length(sh.P) - 1 do
          begin
            SetLength(nr, Length(nr) + 1);
            nr[High(nr)] := MapRef(MakeRef(sh.Id, m));
          end;
        end
        else drop := True;
      end
      else
      begin
        SetLength(nr, Length(nr) + 1);
        nr[High(nr)] := MapRef(c.Refs[ri]);
      end;
    end;
    if drop then
    begin
      Cons.Delete(ci);
      Inc(dropped);
    end
    else
    begin
      c.Refs := nr;
      // the two ends that met were tied together: that is now the shared point itself
      if (c.Kind = ckCoaxial) and (Length(nr) >= 2) then
      begin
        drop := True;
        for ri := 1 to High(nr) do
          if not SameRef(nr[ri], nr[0]) then drop := False;
        if drop then Cons.Delete(ci);
      end;
    end;
  end;
  a.P := newP;
  if a.Kind <> skSpline then a.Kind := skPolyline;       // two splines make one spline: the curve goes on through the joint
  SetLength(a.W, 0);
  Shapes.Remove(b);
  Result := True;
end;

// the two ends of an open spline meet: point drop is removed (keep is the one that stays) and the curve is closed, so it goes
// on smoothly through the joint. Constraints on the removed point pass to the kept one.
function TDoc.CloseSpline(s: TShape; drop, keep: Integer; out err: string): Boolean;
var
  i, ci, ri: Integer;
  c: TConstraint;
begin
  Result := False;
  err := '';
  if (s.Kind <> skSpline) or s.SplineClosed or (Length(s.RingStarts) > 0) or (Length(s.P) < 3) or (drop = keep) then
  begin
    err := 'Only an open spline with at least 3 points can be closed.';
    Exit;
  end;
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    for ri := 0 to High(c.Refs) do
      if (c.Refs[ri].Shape = s.Id) and (c.Refs[ri].Idx >= 0) then
      begin
        if c.Refs[ri].Idx = drop then c.Refs[ri].Idx := keep;
        if c.Refs[ri].Idx > drop then Dec(c.Refs[ri].Idx);
      end;
    // a point tied to itself: nothing left to say
    if (c.Kind = ckCoaxial) and (Length(c.Refs) = 2) and SameRef(c.Refs[0], c.Refs[1]) then Cons.Delete(ci);
  end;
  for i := drop to High(s.P) - 1 do s.P[i] := s.P[i + 1];
  SetLength(s.P, Length(s.P) - 1);
  SetLength(s.W, 0);
  s.SplineClosed := True;
  Result := True;
end;

// Removes the joint idx of a poly-line / polygon (the inverse of InsertVertex).  A poly-line
// left with two points becomes a straight line again.  Constraints on the joint or on the two
// sides that meet there are dropped; the others are renumbered.
function TDoc.RemoveVertex(s: TShape; idx: Integer; out dropped: Integer; out err: string): Boolean;
var
  n, i, ci, ri, m, j, prev: Integer;
  c: TConstraint;
  drop: Boolean;
  f: TShape;
begin
  Result := False;
  dropped := 0;
  err := '';
  if not (s.Kind in [skPolyline, skPolygon]) then
  begin
    err := 'Only a joint of a poly-line or a polygon can be removed.';
    Exit;
  end;
  if s.Reg then
  begin
    err := 'A regular shape keeps its sides: convert it to a polygon first.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  for i := 0 to Shapes.Count - 1 do
  begin
    f := Shapes[i];
    if (f.FA > 0) and ((f.FA = s.Id) or (f.FB = s.Id)) then
    begin
      err := 'This object is joined by a fillet / chamfer: remove it first.';
      Exit;
    end;
  end;
  n := Length(s.P);
  if (idx < 0) or (idx >= n) then Exit;
  if (s.Kind = skPolyline) and ((idx = 0) or (idx = n - 1)) then
  begin
    err := 'That is an end of the poly-line, not a joint.';
    Exit;
  end;
  if (s.Kind = skPolygon) and (n <= 3) then
  begin
    err := 'A polygon needs at least three corners.';
    Exit;
  end;
  if s.Kind = skPolygon then prev := (idx + n - 1) mod n else prev := idx - 1;
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    for ri := 0 to High(c.Refs) do
    begin
      if c.Refs[ri].Shape <> s.Id then Continue;
      m := c.Refs[ri].Idx;
      if (m >= 0) and (m < SegBase) then
      begin
        if m = idx then drop := True
        else if m > idx then c.Refs[ri].Idx := m - 1;
      end
      else if m >= SegBase then
      begin
        j := m - SegBase;
        if (j = idx) or (j = prev) then drop := True
        else
        begin
          // new number of the point the side starts from
          if j > idx then c.Refs[ri].Idx := SegBase + j - 1;
        end;
      end;
    end;
    if drop then
    begin
      Cons.Delete(ci);
      Inc(dropped);
    end;
  end;
  for i := idx to n - 2 do s.P[i] := s.P[i + 1];
  SetLength(s.P, n - 1);
  if (s.Kind = skPolyline) and (Length(s.P) = 2) then s.Kind := skLine;
  SetLength(s.W, 0);
  Result := True;
end;

function TDoc.InsertVertex(s: TShape; x, y: Double; out newIdx, dropped: Integer;
  out err: string): Boolean;
var
  n, i, k, nseg, m, ci, ri: Integer;
  best, d, t, abx, aby, l2, px, py: Double;
  a, b: TPt;
  bt: Double;
  wasLine: Boolean;
  c: TConstraint;
  drop: Boolean;
  f: TShape;
begin
  Result := False;
  err := '';
  newIdx := -1;
  dropped := 0;
  if not (s.Kind in [skLine, skPolyline, skPolygon]) then
  begin
    err := 'Only lines, poly-lines and polygons can get a joint.';
    Exit;
  end;
  if s.Reg then
  begin
    err := 'A regular shape keeps its sides: convert it to a polygon first.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) then
  begin
    err := 'This is a derived copy: detach it from its original first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  for i := 0 to Shapes.Count - 1 do
  begin
    f := Shapes[i];
    if (f.FA > 0) and ((f.FA = s.Id) or (f.FB = s.Id)) then
    begin
      err := 'This line is joined by a fillet / chamfer: remove it first.';
      Exit;
    end;
  end;
  n := Length(s.P);
  if n < 2 then Exit;
  if s.Kind = skPolygon then nseg := n else nseg := n - 1;
  best := 1e18;
  k := 0;
  bt := 0;
  for i := 0 to nseg - 1 do
  begin
    a := s.P[i];
    b := s.P[(i + 1) mod n];
    d := DistToSegment(x, y, a.x, a.y, b.x, b.y);
    if d < best then
    begin
      best := d;
      k := i;
      abx := b.x - a.x;
      aby := b.y - a.y;
      l2 := abx * abx + aby * aby;
      if l2 < 1e-12 then t := 0 else t := ((x - a.x) * abx + (y - a.y) * aby) / l2;
      bt := Max(0, Min(1, t));
    end;
  end;
  a := s.P[k];
  b := s.P[(k + 1) mod n];
  px := a.x + (b.x - a.x) * bt;
  py := a.y + (b.y - a.y) * bt;
  if (Hypot(px - a.x, py - a.y) < 2) or (Hypot(px - b.x, py - b.y) < 2) then
  begin
    err := 'Too close to an end of the side: click farther from the corner.';
    Exit;
  end;
  wasLine := s.Kind = skLine;
  // renumber / drop the constraint references to this shape
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    for ri := 0 to High(c.Refs) do
    begin
      if c.Refs[ri].Shape <> s.Id then Continue;
      m := c.Refs[ri].Idx;
      if wasLine then
      begin
        if (m = -1) and (c.Kind <> ckFixed) then drop := True
        else if m = 1 then c.Refs[ri].Idx := 2;
      end
      else if (m >= 0) and (m < SegBase) then
      begin
        if m >= k + 1 then c.Refs[ri].Idx := m + 1;
      end
      else if m >= SegBase then
      begin
        if m - SegBase > k then c.Refs[ri].Idx := m + 1;
      end;
    end;
    if drop then
    begin
      Cons.Delete(ci);
      Inc(dropped);
    end;
  end;
  SetLength(s.P, n + 1);
  for i := n downto k + 2 do s.P[i] := s.P[i - 1];
  s.P[k + 1] := MakePt(px, py);
  if wasLine then s.Kind := skPolyline;
  SetLength(s.W, 0);
  newIdx := k + 1;
  Result := True;
end;

function TDoc.AddBreak(s: TShape; poly: Integer; u1, u2: Double; out err: string): Boolean;
var
  o: TOutline;
  tr: TTrim;
  d: Double;
begin
  Result := False;
  err := '';
  if not TrimmableKind(s.Kind) then
  begin
    err := 'This kind of object cannot be broken.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) then
  begin
    err := 'This is a linked copy: break the original (or detach / explode the copy first).';
    Exit;
  end;
  EffectiveOutline(s, o);
  if (poly < 0) or (poly > High(o)) then Exit;
  if Abs(u2 - u1) < 1e-6 then
  begin
    err := 'The two points coincide: click a different second point.';
    Exit;
  end;
  tr.Poly := poly;
  tr.CA := -2;
  tr.CB := -2;
  if o[poly].Closed then
  begin
    d := u2 - u1;
    while d < 0 do d := d + 1;
    if d <= 0.5 then
    begin
      tr.UA := u1;
      tr.UB := u1 + d;
    end
    else
    begin
      tr.UA := u2;
      tr.UB := u2 + (1 - d);
    end;
  end
  else
  begin
    tr.UA := Min(u1, u2);
    tr.UB := Max(u1, u2);
  end;
  tr.U0 := (tr.UA + tr.UB) / 2;
  SetLength(s.Trims, Length(s.Trims) + 1);
  s.Trims[High(s.Trims)] := tr;
  Result := True;
end;

function TDoc.AddTrim(s: TShape; x, y: Double; out err: string): Boolean;
var
  o, co: TOutline;
  pi, i, j, k, sc, nh, total, m: Integer;
  best, d, t, u0, bx, by, abx, aby, l2: Double;
  hits: array[0..4095] of Double;
  db, df, bestB, bestF: Double;
  tr: TTrim;
  cs: TShape;
  pl: TPolyline;
  a, b: TPt;
begin
  Result := False;
  err := '';
  if not TrimmableKind(s.Kind) then
  begin
    err := 'This kind of object cannot be trimmed.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) then
  begin
    err := 'This is a linked copy: trim the original (or detach / explode the copy first).';
    Exit;
  end;
  EffectiveOutline(s, o);
  best := 1e18;
  pi := -1;
  u0 := 0;
  for i := 0 to High(o) do
  begin
    sc := SegCountOf(o[i]);
    m := Length(o[i].Pts);
    for j := 0 to sc - 1 do
    begin
      a := o[i].Pts[j];
      b := o[i].Pts[(j + 1) mod m];
      d := DistToSegment(x, y, a.x, a.y, b.x, b.y);
      if d < best then
      begin
        best := d;
        pi := i;
        abx := b.x - a.x;
        aby := b.y - a.y;
        l2 := abx * abx + aby * aby;
        if l2 < 1e-12 then t := 0
        else t := ((x - a.x) * abx + (y - a.y) * aby) / l2;
        if t < 0 then t := 0;
        if t > 1 then t := 1;
        u0 := (j + t) / sc;
      end;
    end;
  end;
  if pi < 0 then Exit;
  pl := o[pi];
  tr.Poly := pi;
  tr.U0 := u0;
  tr.CA := -1;
  tr.CB := -1;
  tr.UA := 0;
  tr.UB := 0;
  bestB := 1e18;
  bestF := 1e18;
  total := 0;
  for k := 0 to Shapes.Count - 1 do
  begin
    cs := Shapes[k];
    if cs = s then Continue;
    EffectiveOutline(cs, co);
    TrimHits(pl, co, hits, nh);
    for j := 0 to nh - 1 do
    begin
      Inc(total);
      if pl.Closed then
      begin
        db := u0 - hits[j];
        while db <= 1e-9 do db := db + 1;
        df := hits[j] - u0;
        while df <= 1e-9 do df := df + 1;
      end
      else
      begin
        db := u0 - hits[j];
        df := hits[j] - u0;
      end;
      if (db > 1e-9) and (db < bestB) then
      begin
        bestB := db;
        tr.CA := cs.Id;
      end;
      if (df > 1e-9) and (df < bestF) then
      begin
        bestF := df;
        tr.CB := cs.Id;
      end;
    end;
  end;
  if total = 0 then
  begin
    err := 'This segment is not crossed by any other object.';
    Exit;
  end;
  if pl.Closed and (total < 2) then
  begin
    err := 'A closed shape needs at least two crossings to be trimmed.';
    Exit;
  end;
  SetLength(s.Trims, Length(s.Trims) + 1);
  s.Trims[High(s.Trims)] := tr;
  Result := True;
end;

// hidden interval [lo, hi] (hi may exceed 1 or lo be negative on closed shapes)
function TDoc.TrimGap(s: TShape; const t: TTrim; const pl: TPolyline;
  out lo, hi: Double): Boolean;
var
  co: TOutline;
  hits: array[0..4095] of Double;
  nh, j: Integer;
  cs: TShape;
  bestB, bestF, db, df: Double;
  foundB, foundF: Boolean;
begin
  Result := False;
  lo := 0;
  hi := 1;
  bestB := 1e18;
  bestF := 1e18;
  foundB := False;
  foundF := False;
  if t.CA = -2 then
  begin
    lo := t.UA;
    hi := t.UB;
    Result := hi > lo;
    Exit;
  end;
  if t.CA >= 0 then
  begin
    cs := FindShape(t.CA);
    if cs = nil then Exit;
    EffectiveOutline(cs, co);
    TrimHits(pl, co, hits, nh);
    for j := 0 to nh - 1 do
    begin
      db := t.U0 - hits[j];
      if pl.Closed then
        while db <= 1e-9 do db := db + 1;
      if (db > 1e-9) and (db < bestB) then
      begin
        bestB := db;
        foundB := True;
      end;
    end;
    if not foundB then Exit;
    lo := t.U0 - bestB;
  end
  else if pl.Closed then Exit;
  if t.CB >= 0 then
  begin
    cs := FindShape(t.CB);
    if cs = nil then Exit;
    EffectiveOutline(cs, co);
    TrimHits(pl, co, hits, nh);
    for j := 0 to nh - 1 do
    begin
      df := hits[j] - t.U0;
      if pl.Closed then
        while df <= 1e-9 do df := df + 1;
      if (df > 1e-9) and (df < bestF) then
      begin
        bestF := df;
        foundF := True;
      end;
    end;
    if not foundF then Exit;
    hi := t.U0 + bestF;
  end
  else if pl.Closed then Exit;
  if pl.Closed and (hi - lo >= 1) then
  begin
    lo := 0;
    hi := 1;
  end;
  Result := True;
end;

function TDoc.VisibleOutline(s: TShape; out o: TOutline): Boolean;
type
  TIv = record
    a, b: Double;
  end;
var
  full: TOutline;
  src: TShape;
  xf: TXf;
  ivs: array of TIv;
  i, j, k, sc, n, m, cnt: Integer;
  lo, hi: Double;
  pieces: array of TPtArray;
  pu1, pu2: array of Double;
  cur, v1, v2: Double;
  tmp: TIv;
  any: Boolean;

  procedure AddIv(a, b: Double);
  begin
    SetLength(ivs, Length(ivs) + 1);
    ivs[High(ivs)].a := a;
    ivs[High(ivs)].b := b;
  end;

  function At(const pl: TPolyline; u: Double): TPt;
  var
    f, tt: Double;
    jj, nn: Integer;
    p1, p2: TPt;
  begin
    nn := Length(pl.Pts);
    f := u * sc;
    jj := Trunc(f);
    if jj > sc - 1 then jj := sc - 1;
    if jj < 0 then jj := 0;
    tt := f - jj;
    p1 := pl.Pts[jj];
    p2 := pl.Pts[(jj + 1) mod nn];
    Result := MakePt(p1.x + (p2.x - p1.x) * tt, p1.y + (p2.y - p1.y) * tt);
  end;

  procedure AddPiece(const pl: TPolyline; u1, u2: Double);
  var
    pts: TPtArray;
    kk: Integer;
  begin
    SetLength(pts, 0);
    SetLength(pts, 1);
    pts[0] := At(pl, u1);
    for kk := 1 to sc do
      if (kk / sc > u1 + 1e-9) and (kk / sc < u2 - 1e-9) then
      begin
        SetLength(pts, Length(pts) + 1);
        pts[High(pts)] := pl.Pts[kk mod Length(pl.Pts)];
      end;
    SetLength(pts, Length(pts) + 1);
    pts[High(pts)] := At(pl, u2);
    SetLength(pieces, Length(pieces) + 1);
    pieces[High(pieces)] := pts;
    SetLength(pu1, Length(pu1) + 1);
    pu1[High(pu1)] := u1;
    SetLength(pu2, Length(pu2) + 1);
    pu2[High(pu2)] := u2;
  end;

begin
  Result := False;
  SetLength(o, 0);
  if (s.MirSrc > 0) or (s.ArrId > 0) then
  begin
    // derived copy: the visible parts of the source, transformed
    if CopyXf(s, src, xf) and (MirDepth < 8) then
    begin
      Inc(MirDepth);
      try
        if VisibleOutline(src, full) then
        begin
          XfOutline(xf, full, o);
          Result := True;
        end;
      finally
        Dec(MirDepth);
      end;
    end;
    Exit;
  end;
  if not TrimmableKind(s.Kind) then Exit;
  any := EffectiveOutline(s, full);
  if (Length(s.Trims) = 0) and not any then Exit;
  for i := 0 to High(full) do
  begin
    SetLength(ivs, 0);
    for k := 0 to High(s.Trims) do
    begin
      if s.Trims[k].Poly <> i then Continue;
      if not TrimGap(s, s.Trims[k], full[i], lo, hi) then Continue;
      if lo < 0 then
      begin
        AddIv(lo + 1, 1);
        AddIv(0, hi);
      end
      else if hi > 1 then
      begin
        AddIv(lo, 1);
        AddIv(0, hi - 1);
      end
      else AddIv(lo, hi);
    end;
    sc := SegCountOf(full[i]);
    if (Length(ivs) = 0) or (sc < 1) then
    begin
      SetLength(o, Length(o) + 1);
      o[High(o)] := full[i];
      Continue;
    end;
    any := True;
    // sort intervals by start
    for j := 1 to High(ivs) do
    begin
      tmp := ivs[j];
      k := j - 1;
      while (k >= 0) and (ivs[k].a > tmp.a) do
      begin
        ivs[k + 1] := ivs[k];
        Dec(k);
      end;
      ivs[k + 1] := tmp;
    end;
    SetLength(pieces, 0);
    SetLength(pu1, 0);
    SetLength(pu2, 0);
    cur := 0;
    for j := 0 to High(ivs) do
    begin
      if ivs[j].a - cur > 1e-7 then AddPiece(full[i], cur, ivs[j].a);
      if ivs[j].b > cur then cur := ivs[j].b;
    end;
    if 1 - cur > 1e-7 then AddPiece(full[i], cur, 1);
    // closed shape: join the piece ending at 1 with the one starting at 0
    cnt := Length(pieces);
    if full[i].Closed and (cnt > 1) and (pu1[0] < 1e-7) and (pu2[cnt - 1] > 1 - 1e-7) then
    begin
      n := Length(pieces[cnt - 1]);
      m := Length(pieces[0]);
      SetLength(pieces[cnt - 1], n + m - 1);
      for j := 1 to m - 1 do
        pieces[cnt - 1][n + j - 1] := pieces[0][j];
      for j := 0 to cnt - 2 do
        pieces[j] := pieces[j + 1];
      SetLength(pieces, cnt - 1);
    end;
    for j := 0 to High(pieces) do
    begin
      SetLength(o, Length(o) + 1);
      o[High(o)].Pts := pieces[j];
      o[High(o)].Closed := False;
    end;
  end;
  Result := any;
  if not any then SetLength(o, 0);
end;

{ ---------- extend ---------- }

function ExtendableKind(k: TShapeKind): Boolean;
begin
  Result := k in [skLine, skPolyline];
end;

// nearest crossing of the ray e + t*r (t > 0) with the polylines of co
function RayHit(const e, r: TPt; const co: TOutline; out t: Double): Boolean;
var
  i, k, cn, m: Integer;
  c, d: TPt;
  sx, sy, den, qx, qy, tt, u: Double;
begin
  Result := False;
  t := 1e18;
  for i := 0 to High(co) do
  begin
    cn := SegCountOf(co[i]);
    m := Length(co[i].Pts);
    for k := 0 to cn - 1 do
    begin
      c := co[i].Pts[k];
      d := co[i].Pts[(k + 1) mod m];
      sx := d.x - c.x;
      sy := d.y - c.y;
      den := r.x * sy - r.y * sx;
      if Abs(den) < 1e-12 then Continue;
      qx := c.x - e.x;
      qy := c.y - e.y;
      tt := (qx * sy - qy * sx) / den;
      u := (qx * r.y - qy * r.x) / den;
      if (tt <= 1e-6) or (u < 0) or (u > 1) then Continue;
      if tt < t then
      begin
        t := tt;
        Result := True;
      end;
    end;
  end;
end;

function TDoc.EffectiveOutline(s: TShape; out o: TOutline): Boolean;
var
  k, n: Integer;
  b: TShape;
  bo: TOutline;
  e, adj, r: TPt;
  t: Double;
  xf: TXf;
begin
  Result := False;
  o := ShapeOutline(s);
  if (s.MirSrc > 0) or (s.ArrId > 0) then
  begin
    // a derived copy looks exactly like its source (extensions, fillet cuts), transformed
    if CopyXf(s, b, xf) and (MirDepth < 8) then
    begin
      Inc(MirDepth);
      try
        if EffectiveOutline(b, bo) then
        begin
          XfOutline(xf, bo, o);
          Result := True;
        end;
      finally
        Dec(MirDepth);
      end;
    end;
    Exit;
  end;
  if not ExtendableKind(s.Kind) or (Length(o) <> 1) then Exit;
  if (Length(s.Extends) = 0) and not (s.CutOn[0] or s.CutOn[1]) then Exit;
  o[0].Pts := Copy(o[0].Pts);   // never edit the shape's own point array
  n := Length(o[0].Pts);
  if n < 2 then Exit;
  for k := 0 to High(s.Extends) do
  begin
    b := FindShape(s.Extends[k].Boundary);
    if (b = nil) or (b = s) then Continue;
    if s.Extends[k].EndIdx = 0 then
    begin
      e := o[0].Pts[0];
      adj := o[0].Pts[1];
    end
    else
    begin
      e := o[0].Pts[n - 1];
      adj := o[0].Pts[n - 2];
    end;
    r := MakePt(e.x - adj.x, e.y - adj.y);
    if (Abs(r.x) + Abs(r.y)) < 1e-9 then Continue;
    bo := ShapeOutline(b);
    if not RayHit(e, r, bo, t) then Continue;
    e := MakePt(e.x + r.x * t, e.y + r.y * t);
    if s.Extends[k].EndIdx = 0 then o[0].Pts[0] := e else o[0].Pts[n - 1] := e;
    Result := True;
  end;
  // fillets win over extensions at the same end (lines have exactly two points)
  if s.Kind = skLine then
  begin
    if s.CutOn[0] then
    begin
      o[0].Pts[0] := s.CutPt[0];
      Result := True;
    end;
    if s.CutOn[1] then
    begin
      o[0].Pts[n - 1] := s.CutPt[1];
      Result := True;
    end;
  end;
end;

function TDoc.AddExtend(s: TShape; x, y: Double; out err: string): Boolean;
var
  o, bo: TOutline;
  n, k, i, endIdx, bestId: Integer;
  e, adj, r: TPt;
  t, bestT: Double;
  ex: TExtend;
begin
  Result := False;
  err := '';
  if not ExtendableKind(s.Kind) then
  begin
    err := 'Only lines and poly-lines can be extended.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) then
  begin
    err := 'This is a linked copy: extend the original (or detach / explode the copy first).';
    Exit;
  end;
  o := ShapeOutline(s);
  n := Length(o[0].Pts);
  if n < 2 then Exit;
  // the end nearest to the click (of the original geometry)
  if Hypot(x - o[0].Pts[0].x, y - o[0].Pts[0].y) <= Hypot(x - o[0].Pts[n - 1].x, y - o[0].Pts[n - 1].y) then
    endIdx := 0
  else endIdx := 1;
  if endIdx = 0 then
  begin
    e := o[0].Pts[0];
    adj := o[0].Pts[1];
  end
  else
  begin
    e := o[0].Pts[n - 1];
    adj := o[0].Pts[n - 2];
  end;
  r := MakePt(e.x - adj.x, e.y - adj.y);
  if (Abs(r.x) + Abs(r.y)) < 1e-9 then
  begin
    err := 'Degenerate segment.';
    Exit;
  end;
  bestT := 1e18;
  bestId := -1;
  for k := 0 to Shapes.Count - 1 do
  begin
    if Shapes[k] = s then Continue;
    bo := ShapeOutline(Shapes[k]);
    if RayHit(e, r, bo, t) and (t < bestT) then
    begin
      bestT := t;
      bestId := Shapes[k].Id;
    end;
  end;
  if bestId < 0 then
  begin
    err := 'Nothing to extend to: no object lies beyond that end.';
    Exit;
  end;
  ex.EndIdx := endIdx;
  ex.Boundary := bestId;
  for i := 0 to High(s.Extends) do
    if s.Extends[i].EndIdx = endIdx then
    begin
      s.Extends[i] := ex;
      Exit(True);
    end;
  SetLength(s.Extends, Length(s.Extends) + 1);
  s.Extends[High(s.Extends)] := ex;
  Result := True;
end;

{ ---------- fillet ---------- }

function UnitDir(const a, b: TPt; out d: TPt): Boolean;
var
  l: Double;
begin
  l := Hypot(b.x - a.x, b.y - a.y);
  Result := l > 1e-9;
  if Result then d := MakePt((b.x - a.x) / l, (b.y - a.y) / l)
  else d := MakePt(1, 0);
end;

{ ---------- paint bucket ---------- }

{$PUSH}
{$Q-}
{$R-}
function GeomHashOf(doc: TDoc): QWord;
var
  h: QWord;
  i, j: Integer;
  s: TShape;

  procedure Mix(v: Int64);
  begin
    h := (h xor QWord(v)) * 1099511628211;
  end;

  procedure MixD(d: Double);
  begin
    Mix(Round(d * 1000));
  end;

begin
  h := 14695981039346656037;
  // layers: order and visibility decide which shapes bound a fill
  for i := 0 to doc.Layers.Count - 1 do
  begin
    Mix(doc.Layers[i].Id);
    Mix(Ord(doc.Layers[i].Visible));
  end;
  for i := 0 to doc.Shapes.Count - 1 do
  begin
    s := doc.Shapes[i];
    if s.Bucket then
    begin
      Mix(s.Id);
      Mix(s.LayerId);
      Mix(Ord(s.BucketIgnoreLower));
      Mix(Round(s.BucketOffset * 100));
      Continue;
    end;
    Mix(s.Id);
    Mix(s.LayerId);
    Mix(Ord(s.Kind));
    Mix(Ord(s.IsRef));
    for j := 0 to High(s.P) do
    begin
      MixD(s.P[j].x);
      MixD(s.P[j].y);
    end;
    if s.Kind = skRect then MixD(s.Corner);
    if s.Kind in [skEllipse, skArc] then
    begin
      MixD(s.RX);
      MixD(s.RY);
      MixD(s.A1);
      MixD(s.A2);
    end;
    Mix(Length(s.Trims));
    for j := 0 to High(s.Trims) do
    begin
      MixD(s.Trims[j].U0);
      Mix(s.Trims[j].CA);
      Mix(s.Trims[j].CB);
      MixD(s.Trims[j].UA);
      MixD(s.Trims[j].UB);
    end;
    Mix(Length(s.Extends));
    if s.Kind = skPath then
    begin
      Mix(Length(s.PathData));
      for j := 1 to Length(s.PathData) do Mix(Ord(s.PathData[j]));
    end;
  end;
  Result := h;
end;
{$POP}

// the outlines that bound areas: everything that is drawn, except fills, reference objects,
// text and pictures
function BoundaryPolys(doc: TDoc; const only: array of Integer; useOnly: Boolean; minLayer: Integer = 0): TFPolyArray;
var
  i, j, k, n, m: Integer;
  s: TShape;
  o: TOutline;
begin
  SetLength(Result, 0);
  n := 0;
  for i := 0 to doc.Shapes.Count - 1 do
  begin
    s := doc.Shapes[i];
    if (minLayer > 0) and (doc.Layers.IndexOf(doc.LayerOf(s)) < minLayer) then Continue;
    if s.Bucket or s.IsRef or not doc.ShapeVisible(s) or not (s.Kind in [skLine, skArrow, skPolyline, skPolygon, skRect, skEllipse, skArc, skSpline, skPath]) then Continue;
    if useOnly then
    begin
      m := 0;
      for k := 0 to High(only) do
        if only[k] = s.Id then m := 1;
      if m = 0 then Continue;
    end;
    if not doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    for j := 0 to High(o) do
    begin
      if Length(o[j].Pts) < 2 then Continue;
      SetLength(Result, n + 1);
      Result[n].Id := s.Id;
      Result[n].Closed := o[j].Closed;
      SetLength(Result[n].Pts, Length(o[j].Pts));
      for k := 0 to High(o[j].Pts) do
      begin
        Result[n].Pts[k].x := o[j].Pts[k].x;
        Result[n].Pts[k].y := o[j].Pts[k].y;
      end;
      Inc(n);
    end;
  end;
end;

function PolyToPath(const poly: TFPtArray): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(poly) do
  begin
    if i = 0 then Result := 'M' else Result := Result + ' L';
    Result := Result + FormatFloat('0.###', poly[i].x, MFS) + ' ' + FormatFloat('0.###', poly[i].y, MFS);
  end;
  Result := Result + ' Z';
end;

procedure SetBucketPath(b: TShape; const poly: TFPtArray);
begin
  SetLength(b.P, 1);
  b.P[0] := MakePt(0, 0);
  b.PathData := PolyToPath(poly);
  b.ParsePath;
end;

// bounding box of the shapes with these ids
function BoundsOfIds(doc: TDoc; const ids: array of Integer; out x1, y1, x2, y2: Double): Boolean;
var
  i, j, k, m: Integer;
  s: TShape;
  o: TOutline;
begin
  Result := False;
  x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
  for i := 0 to doc.Shapes.Count - 1 do
  begin
    s := doc.Shapes[i];
    m := 0;
    for k := 0 to High(ids) do
      if ids[k] = s.Id then m := 1;
    if m = 0 then Continue;
    if not doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    for j := 0 to High(o) do
      for k := 0 to High(o[j].Pts) do
      begin
        x1 := Min(x1, o[j].Pts[k].x);
        y1 := Min(y1, o[j].Pts[k].y);
        x2 := Max(x2, o[j].Pts[k].x);
        y2 := Max(y2, o[j].Pts[k].y);
        Result := True;
      end;
  end;
end;

// the loops of an area, moved in by half the stroke width of the shape each side comes from, so
// that the fill stays inside the lines instead of running under them
function InsetLoops(doc: TDoc; const loops: TFLoopArray; offset: Double): TFLoopArray;
var
  nl: TFLoopArray;
  i, k: Integer;
  dist: array of Double;
  sh: TShape;
begin
  SetLength(nl, Length(loops));
  for i := 0 to High(loops) do
  begin
    SetLength(dist, Length(loops[i].Pts));
    for k := 0 to High(dist) do
    begin
      dist[k] := Min(0, -offset);         // no line: it reaches the border, or stays away from it
      sh := nil;
      if k <= High(loops[i].Ids) then sh := doc.FindShape(loops[i].Ids[k]);
      if (sh <> nil) and (sh.Style.Stroke <> NoColor) and not sh.Spray then dist[k] := sh.Style.Width / 2 - offset;
    end;
    nl[i].Pts := InsetLoop(loops[i].Pts, dist);
    nl[i].Ids := loops[i].Ids;
  end;
  Result := nl;
end;

function InsetRegion(doc: TDoc; const loops: TFLoopArray; offset: Double): TFPtArray;
begin
  Result := BridgeLoops(InsetLoops(doc, loops, offset));
end;

procedure SampleSeeds(const poly: TFPtArray; out seeds: TFPtArray); forward;
procedure StoreBucketSeeds(doc: TDoc; b: TShape; const seeds: TFPtArray); forward;

// shapes that can be hatched: polygons, paths and closed curves
function Hatchable(s: TShape): Boolean;
begin
  Result := (s.Kind in [skPolygon, skPath]) or ((s.Kind = skSpline) and s.SplineClosed);
end;

// the hatch lines of a fill (pairs of points), clipped to its area
function BucketHatch(s: TShape): TFPtArray;
var
  np: TFPtArray;
  lps: TFLoopArray;
  j, k: Integer;
  o: TOutline;
begin
  SetLength(Result, 0);
  if s.HatchPat <= 0 then Exit;
  if s.Kind = skPolygon then
  begin
    if Length(s.P) < 3 then Exit;
    SetLength(np, Length(s.P));
    for j := 0 to High(np) do
    begin
      np[j].x := s.P[j].x;
      np[j].y := s.P[j].y;
    end;
  end
  else if (s.Kind = skSpline) and s.SplineClosed then
  begin
    o := ShapeOutline(s);
    if (Length(o) = 0) or (Length(o[0].Pts) < 3) then Exit;
    // the outline and its holes as one polygon (the hatching uses the even-odd rule)
    SetLength(lps, Length(o));
    for k := 0 to High(o) do
    begin
      SetLength(lps[k].Pts, Length(o[k].Pts));
      for j := 0 to High(o[k].Pts) do
      begin
        lps[k].Pts[j].x := o[k].Pts[j].x;
        lps[k].Pts[j].y := o[k].Pts[j].y;
      end;
    end;
    np := BridgeLoops(lps);
  end
  else if s.Kind = skPath then
  begin
    if (Length(s.Flat) = 0) or (Length(s.Flat[0]) < 3) or (Length(s.P) < 1) then Exit;
    SetLength(np, Length(s.Flat[0]));
    for j := 0 to High(np) do
    begin
      np[j].x := s.Flat[0][j].x + s.P[0].x;
      np[j].y := s.Flat[0][j].y + s.P[0].y;
    end;
  end
  else Exit;
  HatchLines(np, s.HatchPat, s.HatchSp, s.HatchAng, Result);
end;

{$PUSH}
{$Q-}
{$R-}
// the dots of an airbrush stroke: scattered round the curve (denser near it), always the same ones
// for the same curve and values
function SprayDots(s: TShape): TSprayDotArray;
var
  o: TOutline;
  pts: TPtArray;
  seg: array of Double;
  i, n, k, total, mist: Integer;
  len, r, u, v, a, rr, t, px, py, dx, dy, d, sig, dr: Double;
  state: QWord;

  function Rnd: Double;
  begin
    state := state * 6364136223846793005 + 1442695040888963407;
    Result := ((state shr 11) and $FFFFFFFFFFFFF) / 4503599627370496.0;
  end;

begin
  SetLength(Result, 0);
  if (not s.Spray) or (Length(s.P) < 1) then Exit;
  o := ShapeOutline(s);
  if (Length(o) = 0) or (Length(o[0].Pts) < 2) then Exit;
  pts := o[0].Pts;
  n := Length(pts);
  SetLength(seg, n);
  len := 0;
  seg[0] := 0;
  for i := 1 to n - 1 do
  begin
    len := len + Hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    seg[i] := len;
  end;
  r := Max(s.SprayR, 0.5);
  dr := Max(s.SprayDot, 0.3) / 2;                 // the middle radius of a drop
  total := Round(s.SprayDens * (len * 2 * r + Pi * r * r) / 100);
  if total > 12000 then total := 12000;
  if total < 1 then total := 1;
  // besides the drops, a faint mist of big soft ones
  mist := total div 8;
  state := QWord(s.SpraySeed) * 2654435761 + 12345;
  sig := r / 2.2;
  SetLength(Result, total + mist);
  for k := 0 to total + mist - 1 do
  begin
    // a place along the curve
    t := Rnd * len;
    i := 1;
    while (i < n - 1) and (seg[i] < t) do Inc(i);
    d := seg[i] - seg[i - 1];
    if d < 1e-9 then u := 0 else u := (t - seg[i - 1]) / d;
    px := pts[i - 1].x + u * (pts[i].x - pts[i - 1].x);
    py := pts[i - 1].y + u * (pts[i].y - pts[i - 1].y);
    // round it: gaussian, kept inside the radius
    u := Max(Rnd, 1e-9);
    v := Rnd;
    rr := sig * Sqrt(-2 * Ln(u));
    if rr > r then rr := r * Rnd;
    a := 2 * Pi * v;
    dx := rr * Cos(a);
    dy := rr * Sin(a);
    Result[k].X := px + dx;
    Result[k].Y := py + dy;
    if k < total then
    begin
      // drops differ: many small, a few big, each with its own opacity; the ones near the middle are denser
      u := Rnd;
      Result[k].R := dr * (0.25 + 1.5 * u * u);
      if Rnd < 0.04 then Result[k].R := Result[k].R * 1.8;
      Result[k].A := 0.12 + 0.88 * Power(Rnd, 1.3);
      if rr < r * 0.4 then Result[k].A := Min(1, Result[k].A * 1.25);
    end
    else
    begin
      Result[k].R := Max(dr * 3, r * (0.2 + 0.25 * Rnd));
      Result[k].A := 0.03 + 0.06 * Rnd;
    end;
  end;
end;
{$POP}

function TDoc.AddBucket(x, y: Double; color: Integer; out err: string): TShape;
var
  polys: TFPolyArray;
  poly: TFPtArray;
  ids: TFIntArray;
  seed: TFPt;
  b: TShape;
  x1, y1, x2, y2: Double;
  i, at: Integer;
  none: array of Integer;
  sd: TFPtArray;
  sds: TFPtArray;
  regs1: TFRegionArray;
begin
  Result := nil;
  err := '';
  SetLength(none, 0);
  polys := BoundaryPolys(Self, none, False);
  seed.x := x;
  seed.y := y;
  SetLength(sds, 1);
  sds[0] := seed;
  FindRegions(polys, sds, 0.3, regs1);
  if (Length(regs1) = 0) or not regs1[0].Ok then
  begin
    if Length(regs1) > 0 then err := regs1[0].Msg;
    Exit;
  end;
  ids := regs1[0].Ids;
  poly := InsetRegion(Self, regs1[0].Loops, DefaultBucketOffset);
  b := TShape.Create;
  b.BucketLoops := InsetLoops(Self, regs1[0].Loops, DefaultBucketOffset);
  b.BucketOffset := DefaultBucketOffset;
  b.Kind := skPath;
  b.Style := DefaultStyle;
  b.Style.Fill := color;
  b.Style.Stroke := NoColor;
  b.Bucket := True;
  b.BucketSX := x;
  b.BucketSY := y;
  SetLength(b.BucketIds, Length(ids));
  for i := 0 to High(ids) do b.BucketIds[i] := ids[i];
  if BoundsOfIds(Self, ids, x1, y1, x2, y2) then
  begin
    b.BucketU := (x - x1) / Max(x2 - x1, 1e-6);
    b.BucketV := (y - y1) / Max(y2 - y1, 1e-6);
  end
  else
  begin
    b.BucketU := 0.5;
    b.BucketV := 0.5;
  end;
  SetBucketPath(b, poly);
  SampleSeeds(poly, sd);
  if Length(sd) = 0 then
  begin
    SetLength(sd, 1);
    sd[0] := seed;
  end;
  AddShape(b);
  // behind the drawing, but over any picture used as a model
  at := 0;
  while (at < Shapes.Count) and (Shapes[at].Kind = skImage) do Inc(at);
  Shapes.Move(Shapes.IndexOf(b), Min(at, Shapes.Count - 1));
  StoreBucketSeeds(Self, b, sd);
  FBucketHash := GeomHashOf(Self);
  Result := b;
end;

// sample points well inside an outline (even-odd rule): they identify the area when the
// boundaries move, even if a boundary (an island) passes over one of the points
procedure SampleSeeds(const poly: TFPtArray; out seeds: TFPtArray);
const
  GridN = 9;
var
  i, j, k, n: Integer;
  x1, y1, x2, y2, x, y, d, m, margin: Double;
begin
  SetLength(seeds, 0);
  if Length(poly) < 3 then Exit;
  x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
  for i := 0 to High(poly) do
  begin
    x1 := Min(x1, poly[i].x);
    y1 := Min(y1, poly[i].y);
    x2 := Max(x2, poly[i].x);
    y2 := Max(y2, poly[i].y);
  end;
  margin := Max(1.5, 0.03 * Min(x2 - x1, y2 - y1));
  n := 0;
  for i := 0 to GridN - 1 do
    for j := 0 to GridN - 1 do
    begin
      x := x1 + (i + 0.5) * (x2 - x1) / GridN;
      y := y1 + (j + 0.5) * (y2 - y1) / GridN;
      if not InsidePoly(poly, x, y) then Continue;
      d := 1e300;
      for k := 0 to High(poly) do
      begin
        m := DistToSegment(x, y, poly[k].x, poly[k].y, poly[(k + 1) mod Length(poly)].x, poly[(k + 1) mod Length(poly)].y);
        if m < d then d := m;
      end;
      if d < margin then Continue;
      SetLength(seeds, n + 1);
      seeds[n].x := x;
      seeds[n].y := y;
      Inc(n);
    end;
end;

procedure StoreBucketSeeds(doc: TDoc; b: TShape; const seeds: TFPtArray);
var
  i: Integer;
  x1, y1, x2, y2: Double;
  ok: Boolean;
begin
  b.BucketSeeds := Copy(seeds);
  SetLength(b.BucketSeedUV, Length(seeds));
  ok := BoundsOfIds(doc, b.BucketIds, x1, y1, x2, y2);
  for i := 0 to High(seeds) do
    if ok then
    begin
      b.BucketSeedUV[i].x := (seeds[i].x - x1) / Max(x2 - x1, 1e-6);
      b.BucketSeedUV[i].y := (seeds[i].y - y1) / Max(y2 - y1, 1e-6);
    end
    else
    begin
      b.BucketSeedUV[i].x := 0.5;
      b.BucketSeedUV[i].y := 0.5;
    end;
  if Length(seeds) > 0 then
  begin
    b.BucketSX := seeds[0].x;
    b.BucketSY := seeds[0].y;
    b.BucketU := b.BucketSeedUV[0].x;
    b.BucketV := b.BucketSeedUV[0].y;
  end;
end;

// the fills follow their boundaries; one whose area cannot be found any more keeps its last
// outline and is flagged (BucketBroken).  Several sample points vote for the area, so an island
// that moves over one of them does not turn the fill inside out.
procedure TDoc.UpdateBuckets;
var
  i, j, k, g, votes, bestVotes, best: Integer;
  b: TShape;
  h: QWord;
  polys: TFPolyArray;
  regs: TFRegionArray;
  seeds, cands, np: TFPtArray;
  x1, y1, x2, y2: Double;
  any, ok, same: Boolean;
  live: array of Integer;
  none: array of Integer;
  area, bestArea: array of Double;
  bx1, by1, bx2, by2: array of Double;
  nGroups: Integer;
  grp: array of Integer;
  cnt: array of Integer;
  a, ax1, ay1, ax2, ay2: Double;
begin
  if FBucketBusy then Exit;
  any := False;
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].Bucket then any := True;
  if not any then
  begin
    FBucketHash := 0;
    Exit;
  end;
  h := GeomHashOf(Self);
  if h = FBucketHash then Exit;
  FBucketBusy := True;
  try
    FBucketHash := h;
    SetLength(none, 0);
    polys := BoundaryPolys(Self, none, False);
    for i := 0 to Shapes.Count - 1 do
    begin
      b := Shapes[i];
      if not b.Bucket then Continue;
      // the sample points: those of the last good outline (or made from the saved one)
      if Length(b.BucketSeeds) = 0 then
      begin
        if (Length(b.Flat) > 0) and (Length(b.Flat[0]) >= 3) then
        begin
          SetLength(np, Length(b.Flat[0]));
          for j := 0 to High(np) do
          begin
            np[j].x := b.Flat[0][j].x + b.P[0].x;
            np[j].y := b.Flat[0][j].y + b.P[0].y;
          end;
          SampleSeeds(np, seeds);
        end;
        if Length(seeds) = 0 then
        begin
          SetLength(seeds, 1);
          seeds[0].x := b.BucketSX;
          seeds[0].y := b.BucketSY;
        end;
        StoreBucketSeeds(Self, b, seeds);
      end;
      SetLength(live, 0);
      for j := 0 to High(b.BucketIds) do
        if FindShape(b.BucketIds[j]) <> nil then
        begin
          SetLength(live, Length(live) + 1);
          live[High(live)] := b.BucketIds[j];
        end;
      // where the points are now: same place relative to the boundaries
      SetLength(cands, Length(b.BucketSeeds));
      ok := (Length(live) > 0) and BoundsOfIds(Self, live, x1, y1, x2, y2);
      for j := 0 to High(cands) do
        if ok then
        begin
          cands[j].x := x1 + b.BucketSeedUV[j].x * (x2 - x1);
          cands[j].y := y1 + b.BucketSeedUV[j].y * (y2 - y1);
        end
        else cands[j] := b.BucketSeeds[j];
      // a fill may ignore the shapes of the layers under its own
      if b.BucketIgnoreLower then
        FindRegions(BoundaryPolys(Self, none, False, Layers.IndexOf(LayerOf(b))), cands, 0.3, regs)
      else FindRegions(polys, cands, 0.3, regs);
      // group the areas found (same outline = same area) and keep the one most points agree on
      nGroups := 0;
      SetLength(grp, Length(regs));
      SetLength(area, Length(regs));
      SetLength(bx1, Length(regs));
      SetLength(by1, Length(regs));
      SetLength(bx2, Length(regs));
      SetLength(by2, Length(regs));
      SetLength(cnt, Length(regs));
      for j := 0 to High(regs) do
      begin
        grp[j] := -1;
        if not regs[j].Ok then Continue;
        a := Abs(PolyArea(regs[j].Poly));
        ax1 := 1e300; ay1 := 1e300; ax2 := -1e300; ay2 := -1e300;
        for k := 0 to High(regs[j].Poly) do
        begin
          ax1 := Min(ax1, regs[j].Poly[k].x);
          ay1 := Min(ay1, regs[j].Poly[k].y);
          ax2 := Max(ax2, regs[j].Poly[k].x);
          ay2 := Max(ay2, regs[j].Poly[k].y);
        end;
        same := False;
        for g := 0 to nGroups - 1 do
          if (Abs(area[g] - a) < 0.5 + 1e-4 * a) and (Abs(bx1[g] - ax1) < 0.5) and (Abs(by1[g] - ay1) < 0.5) and
             (Abs(bx2[g] - ax2) < 0.5) and (Abs(by2[g] - ay2) < 0.5) then
          begin
            grp[j] := g;
            Inc(cnt[g]);
            same := True;
            Break;
          end;
        if not same then
        begin
          area[nGroups] := a;
          bx1[nGroups] := ax1;
          by1[nGroups] := ay1;
          bx2[nGroups] := ax2;
          by2[nGroups] := ay2;
          cnt[nGroups] := 1;
          grp[j] := nGroups;
          Inc(nGroups);
        end;
      end;
      best := -1;
      bestVotes := 0;
      for g := 0 to nGroups - 1 do
        if (cnt[g] > bestVotes) or ((cnt[g] = bestVotes) and (best >= 0) and (area[g] > area[best])) then
        begin
          bestVotes := cnt[g];
          best := g;
        end;
      if best < 0 then
      begin
        b.BucketBroken := True;
        Continue;
      end;
      for j := 0 to High(regs) do
        if grp[j] = best then
        begin
          votes := j;
          Break;
        end;
      b.BucketBroken := False;
      SetLength(b.BucketIds, Length(regs[votes].Ids));
      for j := 0 to High(regs[votes].Ids) do b.BucketIds[j] := regs[votes].Ids[j];
      np := InsetRegion(Self, regs[votes].Loops, b.BucketOffset);
      b.BucketLoops := InsetLoops(Self, regs[votes].Loops, b.BucketOffset);
      SetBucketPath(b, np);
      SampleSeeds(np, seeds);
      if Length(seeds) = 0 then
      begin
        SetLength(seeds, 1);
        seeds[0] := cands[votes];
      end;
      StoreBucketSeeds(Self, b, seeds);
    end;
  finally
    FBucketBusy := False;
  end;
end;

function TDoc.BrokenBuckets: TShapeArray;
var
  i, n: Integer;
begin
  UpdateBuckets;
  SetLength(Result, 0);
  n := 0;
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].Bucket and Shapes[i].BucketBroken then
    begin
      SetLength(Result, n + 1);
      Result[n] := Shapes[i];
      Inc(n);
    end;
end;

// the corner of the two lines of a fillet / chamfer, the kept directions, the angle between them, and how far the tangent points can go
// (not beyond the ends of the lines)
function FilletGeom(d: TDoc; f: TShape; out x, ka, kb: TPt; out th, tmaxA, tmaxB: Double): Boolean;
var
  la, lb: TShape;
  da, db: TPt;
  den, t, cs: Double;
begin
  Result := False;
  la := d.FindShape(f.FA);
  lb := d.FindShape(f.FB);
  if (la = nil) or (lb = nil) or (la = lb) or (la.Kind <> skLine) or (lb.Kind <> skLine) then Exit;
  if not (UnitDir(la.P[0], la.P[1], da) and UnitDir(lb.P[0], lb.P[1], db)) then Exit;
  den := da.x * db.y - da.y * db.x;
  if Abs(den) < 1e-9 then Exit;
  t := ((lb.P[0].x - la.P[0].x) * db.y - (lb.P[0].y - la.P[0].y) * db.x) / den;
  x := MakePt(la.P[0].x + da.x * t, la.P[0].y + da.y * t);
  ka := MakePt(da.x * f.FSA, da.y * f.FSA);
  kb := MakePt(db.x * f.FSB, db.y * f.FSB);
  cs := Max(-1, Min(1, ka.x * kb.x + ka.y * kb.y));
  th := ArcCos(cs);
  if (th < 1e-3) or (th > Pi - 1e-3) then Exit;
  tmaxA := Max((la.P[0].x - x.x) * ka.x + (la.P[0].y - x.y) * ka.y, (la.P[1].x - x.x) * ka.x + (la.P[1].y - x.y) * ka.y);
  tmaxB := Max((lb.P[0].x - x.x) * kb.x + (lb.P[0].y - x.y) * kb.y, (lb.P[1].x - x.x) * kb.x + (lb.P[1].y - x.y) * kb.y);
  Result := (tmaxA > 0.02) and (tmaxB > 0.02);
end;

// the radius of the arc of a fillet that a point of the screen asks for: along the bisector of the corner, never negative, never
// so big that the arc goes past the ends of its lines
function TDoc.FilletRadiusAt(f: TShape; px, py: Double; out r: Double): Boolean;
var
  x, ka, kb: TPt;
  th, ta, tb, bl, d, rmax: Double;
  bis: TPt;
begin
  Result := False;
  r := f.RX;
  if (f.FA <= 0) or not FilletGeom(Self, f, x, ka, kb, th, ta, tb) then Exit;
  bis := MakePt(ka.x + kb.x, ka.y + kb.y);
  bl := Hypot(bis.x, bis.y);
  if bl < 1e-9 then Exit;
  d := ((px - x.x) * bis.x + (py - x.y) * bis.y) / bl;
  r := d * Sin(th / 2);
  rmax := Min(ta, tb) * Tan(th / 2);
  r := Max(0.5, Min(r, Max(0.5, rmax)));
  Result := True;
end;

procedure TDoc.UpdateFillets;
var
  i: Integer;
  f, la, lb: TShape;

  // corner of the two carrier lines, kept rays, tangent points
  procedure CutEnd(l: TShape; const x, k, tp: TPt);
  var
    t0, t1: Double;
    e: Integer;
  begin
    t0 := (l.P[0].x - x.x) * k.x + (l.P[0].y - x.y) * k.y;
    t1 := (l.P[1].x - x.x) * k.x + (l.P[1].y - x.y) * k.y;
    if t0 <= t1 then e := 0 else e := 1;
    l.CutOn[e] := True;
    l.CutPt[e] := tp;
  end;

var
  da, db, x, ka, kb, ta, tb, c, bis: TPt;
  den, t, cs, th, td, r, aa, ab, sw, bl, tmA, tmB: Double;
begin
  UpdateOffsets;    // derived shapes first: they can be fillet partners
  UpdateMirrors;
  UpdateOffsets;
  UpdateArrays;
  for i := 0 to Shapes.Count - 1 do
  begin
    Shapes[i].CutOn[0] := False;
    Shapes[i].CutOn[1] := False;
  end;
  for i := 0 to Shapes.Count - 1 do
  begin
    f := Shapes[i];
    if (f.FA <= 0) or not (f.Kind in [skArc, skLine]) then Continue;
    la := FindShape(f.FA);
    lb := FindShape(f.FB);
    if (la = nil) or (lb = nil) or (la = lb) or (la.Kind <> skLine) or (lb.Kind <> skLine) then
    begin
      f.FA := 0;   // the lines are gone: the arc becomes an ordinary arc
      f.FB := 0;
      Continue;
    end;
    if not (UnitDir(la.P[0], la.P[1], da) and UnitDir(lb.P[0], lb.P[1], db)) then Continue;
    den := da.x * db.y - da.y * db.x;
    if Abs(den) < 1e-9 then Continue;           // parallel lines: keep the last geometry
    t := ((lb.P[0].x - la.P[0].x) * db.y - (lb.P[0].y - la.P[0].y) * db.x) / den;
    x := MakePt(la.P[0].x + da.x * t, la.P[0].y + da.y * t);
    ka := MakePt(da.x * f.FSA, da.y * f.FSA);
    kb := MakePt(db.x * f.FSB, db.y * f.FSB);
    cs := ka.x * kb.x + ka.y * kb.y;
    if cs > 1 then cs := 1;
    if cs < -1 then cs := -1;
    th := ArcCos(cs);
    if (th < 1e-3) or (th > Pi - 1e-3) then Continue;
    if not FilletGeom(Self, f, x, ka, kb, th, tmA, tmB) then Continue;
    if f.Kind = skLine then
    begin
      // chamfer: straight cut between the two points at the given distances from the corner (not beyond the ends of the lines)
      f.CD1 := Max(0.01, Min(f.CD1, tmA));
      f.CD2 := Max(0.01, Min(f.CD2, tmB));
      ta := MakePt(x.x + ka.x * Max(f.CD1, 0.01), x.y + ka.y * Max(f.CD1, 0.01));
      tb := MakePt(x.x + kb.x * Max(f.CD2, 0.01), x.y + kb.y * Max(f.CD2, 0.01));
      if Length(f.P) < 2 then SetLength(f.P, 2);
      f.P[0] := ta;
      f.P[1] := tb;
      CutEnd(la, x, ka, ta);
      CutEnd(lb, x, kb, tb);
      Continue;
    end;
    r := Max(f.RX, 0.01);
    // the arc cannot go past the ends of the lines, nor have a radius under a minimum
    r := Min(r, Max(0.01, Min(tmA, tmB) * Tan(th / 2)));
    td := r / Tan(th / 2);
    ta := MakePt(x.x + ka.x * td, x.y + ka.y * td);
    tb := MakePt(x.x + kb.x * td, x.y + kb.y * td);
    bis := MakePt(ka.x + kb.x, ka.y + kb.y);
    bl := Hypot(bis.x, bis.y);
    if bl < 1e-9 then Continue;
    c := MakePt(x.x + bis.x / bl * r / Sin(th / 2), x.y + bis.y / bl * r / Sin(th / 2));
    aa := ArcTan2(ta.y - c.y, ta.x - c.x);
    ab := ArcTan2(tb.y - c.y, tb.x - c.x);
    sw := ab - aa;
    while sw < 0 do sw := sw + 2 * Pi;
    while sw >= 2 * Pi do sw := sw - 2 * Pi;
    if sw <= Pi then
    begin
      f.A1 := aa;
      f.A2 := ab;
    end
    else
    begin
      f.A1 := ab;
      f.A2 := aa;
    end;
    if Length(f.P) < 1 then SetLength(f.P, 1);
    f.P[0] := c;
    f.RX := r;
    f.RY := r;
    f.Circ := True;
    CutEnd(la, x, ka, ta);
    CutEnd(lb, x, kb, tb);
  end;
  UpdateMirrors;    // mirror / array copies of fillet arcs
  UpdateArrays;
  UpdateMirrors;
  UpdateBuckets;
end;

// common checks of fillet / chamfer: corner of the two carrier lines, directions, kept sides
function FilletSetup(a, b: TShape; ax, ay, bx, by: Double; const what: string;
  out x, da, db: TPt; out sa, sb: Integer; out err: string): Boolean;
var
  den, t: Double;
begin
  Result := False;
  err := '';
  sa := 1;
  sb := 1;
  if (a = nil) or (b = nil) or (a = b) or (a.Kind <> skLine) or (b.Kind <> skLine) then
  begin
    err := 'A ' + what + ' needs two different lines.';
    Exit;
  end;
  if (a.MirSrc > 0) or (b.MirSrc > 0) or (a.ArrId > 0) or (b.ArrId > 0) then
  begin
    err := 'A linked copy cannot be used here: use the original (or detach / explode the copy first).';
    Exit;
  end;
  if (a.FA > 0) or (b.FA > 0) then
  begin
    err := 'A line made by a fillet or chamfer cannot be joined again.';
    Exit;
  end;
  if not (UnitDir(a.P[0], a.P[1], da) and UnitDir(b.P[0], b.P[1], db)) then
  begin
    err := 'Degenerate line.';
    Exit;
  end;
  den := da.x * db.y - da.y * db.x;
  if Abs(den) < 1e-9 then
  begin
    err := 'The lines are parallel.';
    Exit;
  end;
  t := ((b.P[0].x - a.P[0].x) * db.y - (b.P[0].y - a.P[0].y) * db.x) / den;
  x := MakePt(a.P[0].x + da.x * t, a.P[0].y + da.y * t);
  if (ax - x.x) * da.x + (ay - x.y) * da.y < 0 then sa := -1;
  if (bx - x.x) * db.x + (by - x.y) * db.y < 0 then sb := -1;
  Result := True;
end;

function TDoc.AddFillet(a, b: TShape; ax, ay, bx, by, r: Double; out err: string): TShape;
var
  da, db, x: TPt;
  sa, sb: Integer;
  f: TShape;
begin
  Result := nil;
  if not FilletSetup(a, b, ax, ay, bx, by, 'fillet', x, da, db, sa, sb, err) then Exit;
  f := TShape.Create;
  f.Kind := skArc;
  f.Style := a.Style;
  f.Style.Fill := NoColor;
  SetLength(f.P, 1);
  f.P[0] := x;
  f.RX := r;
  f.RY := r;
  f.Circ := True;
  f.FA := a.Id;
  f.FB := b.Id;
  f.FSA := sa;
  f.FSB := sb;
  f.LayerId := a.LayerId;
  AddShape(f);
  UpdateFillets;
  Result := f;
end;

// the corner v of a polygon / poly-line is rounded (an arc of short sides) or cut (one side): its point is replaced by the
// points where the two sides are left; what was tied to the sides stays, what was tied to the corner point is let go
function TDoc.CutCorner(s: TShape; v: Integer; chamfer: Boolean; r1, r2: Double; out err: string): Boolean;
var
  n, i, j, k, cnt, ci, ri, m, np: Integer;
  pv, pa, pb, t1, t2, cc, u1, u2, bis: TPt;
  l1, l2, th, t, a1, a2, sw, d1, d2, bl: Double;
  pts, np2: TPtArray;
  c: TConstraint;
  drop: Boolean;
  f: TShape;
begin
  Result := False;
  err := '';
  if not (s.Kind in [skPolyline, skPolygon]) then
  begin
    err := 'Only the corner of a polygon or a poly-line can be rounded or cut.';
    Exit;
  end;
  if s.Reg then
  begin
    err := 'A regular shape keeps its corners: convert it to a polygon first.';
    Exit;
  end;
  if (s.MirSrc > 0) or (s.ArrId > 0) or (s.OffSrc > 0) or (s.FA > 0) or (ArrayOf(s) <> nil) then
  begin
    err := 'This is a derived copy or the source of an array: detach / explode it first.';
    Exit;
  end;
  if (Length(s.Trims) > 0) or (Length(s.Extends) > 0) then
  begin
    err := 'Restore the trimmed / extended object first.';
    Exit;
  end;
  for i := 0 to Shapes.Count - 1 do
  begin
    f := Shapes[i];
    if (f.FA > 0) and ((f.FA = s.Id) or (f.FB = s.Id)) then
    begin
      err := 'This object is joined by a fillet / chamfer: remove it first.';
      Exit;
    end;
  end;
  n := Length(s.P);
  if (v < 0) or (v >= n) or ((s.Kind = skPolyline) and ((v = 0) or (v = n - 1))) then Exit;
  pv := s.P[v];
  pa := s.P[(v + n - 1) mod n];
  pb := s.P[(v + 1) mod n];
  l1 := Hypot(pa.x - pv.x, pa.y - pv.y);
  l2 := Hypot(pb.x - pv.x, pb.y - pv.y);
  if (l1 < 1e-6) or (l2 < 1e-6) then
  begin
    err := 'A side is too short.';
    Exit;
  end;
  u1 := MakePt((pa.x - pv.x) / l1, (pa.y - pv.y) / l1);
  u2 := MakePt((pb.x - pv.x) / l2, (pb.y - pv.y) / l2);
  th := ArcCos(Max(-1, Min(1, u1.x * u2.x + u1.y * u2.y)));
  if (th < 0.02) or (th > Pi - 0.02) then
  begin
    err := 'The two sides are on one line: there is no corner.';
    Exit;
  end;
  if chamfer then
  begin
    d1 := r1;
    d2 := r2;
  end
  else
  begin
    t := r1 / Tan(th / 2);
    d1 := t;
    d2 := t;
  end;
  if (d1 > l1 - 1e-6) or (d2 > l2 - 1e-6) then
  begin
    err := 'The corner is too big for the length of the sides.';
    Exit;
  end;
  t1 := MakePt(pv.x + u1.x * d1, pv.y + u1.y * d1);
  t2 := MakePt(pv.x + u2.x * d2, pv.y + u2.y * d2);
  if chamfer then
  begin
    SetLength(pts, 2);
    pts[0] := t1;
    pts[1] := t2;
  end
  else
  begin
    bis := MakePt(u1.x + u2.x, u1.y + u2.y);
    bl := Hypot(bis.x, bis.y);
    cc := MakePt(pv.x + bis.x / bl * r1 / Sin(th / 2), pv.y + bis.y / bl * r1 / Sin(th / 2));
    a1 := ArcTan2(t1.y - cc.y, t1.x - cc.x);
    a2 := ArcTan2(t2.y - cc.y, t2.x - cc.x);
    sw := a2 - a1;
    while sw > Pi do sw := sw - 2 * Pi;
    while sw < -Pi do sw := sw + 2 * Pi;
    np := Max(4, Ceil(Abs(sw) / (Pi / 18)));
    SetLength(pts, np + 1);
    for i := 0 to np do
      pts[i] := MakePt(cc.x + r1 * Cos(a1 + sw * i / np), cc.y + r1 * Sin(a1 + sw * i / np));
    pts[0] := t1;
    pts[np] := t2;
  end;
  cnt := Length(pts);
  // the points of the shape, the corner replaced by the new ones
  SetLength(np2, n - 1 + cnt);
  k := 0;
  for i := 0 to n - 1 do
    if i = v then
      for j := 0 to cnt - 1 do
      begin
        np2[k] := pts[j];
        Inc(k);
      end
    else
    begin
      np2[k] := s.P[i];
      Inc(k);
    end;
  // the constraints: the corner point goes, the later points and sides move on
  for ci := Cons.Count - 1 downto 0 do
  begin
    c := Cons[ci];
    drop := False;
    for ri := 0 to High(c.Refs) do
    begin
      if c.Refs[ri].Shape <> s.Id then Continue;
      m := c.Refs[ri].Idx;
      if (m >= 0) and (m < SegBase) then
      begin
        if m = v then drop := True
        else if m > v then c.Refs[ri].Idx := m + cnt - 1;
      end
      else if m >= SegBase then
      begin
        j := m - SegBase;
        if j >= v then c.Refs[ri].Idx := SegBase + j + cnt - 1;
      end
      else if (m = -1) and (c.Kind = ckFixed) then drop := False;
    end;
    if drop then Cons.Delete(ci);
  end;
  s.P := np2;
  SetLength(s.W, 0);
  Result := True;
end;

function TDoc.AddChamfer(a, b: TShape; ax, ay, bx, by, d1, d2: Double; out err: string): TShape;
var
  da, db, x: TPt;
  sa, sb: Integer;
  f: TShape;
begin
  Result := nil;
  if not FilletSetup(a, b, ax, ay, bx, by, 'chamfer', x, da, db, sa, sb, err) then Exit;
  if (d1 <= 0) or (d2 <= 0) then
  begin
    err := 'The distances must be positive.';
    Exit;
  end;
  f := TShape.Create;
  f.Kind := skLine;
  f.Style := a.Style;
  f.Style.Fill := NoColor;
  SetLength(f.P, 2);
  f.P[0] := x;
  f.P[1] := x;
  f.FA := a.Id;
  f.FB := b.Id;
  f.FSA := sa;
  f.FSB := sb;
  f.CD1 := d1;
  f.CD2 := d2;
  f.LayerId := a.LayerId;
  AddShape(f);
  UpdateFillets;
  Result := f;
end;

{ ---------- offset ---------- }

function OffsetableKind(k: TShapeKind): Boolean;
begin
  Result := k in [skLine, skPolyline, skPolygon, skRect, skEllipse, skArc];
end;

// vertices of an open / closed polyline moved by dist along the left normal (-dy, dx)
// of the adjoining segments, with mitered corners
procedure OffsetPoints(const p: TPtArray; closed: Boolean; dist: Double; out q: TPtArray);
var
  n, i, ip: Integer;
  dprev, dnext, nprev, nnext, m: TPt;
  hasPrev, hasNext: Boolean;
  den, ml: Double;
begin
  n := Length(p);
  SetLength(q, n);
  for i := 0 to n - 1 do
  begin
    hasPrev := False;
    hasNext := False;
    if closed or (i > 0) then
    begin
      ip := (i - 1 + n) mod n;
      hasPrev := UnitDir(p[ip], p[i], dprev);
    end;
    if closed or (i < n - 1) then
      hasNext := UnitDir(p[i], p[(i + 1) mod n], dnext);
    m := MakePt(0, 0);
    if hasPrev then nprev := MakePt(-dprev.y, dprev.x);
    if hasNext then nnext := MakePt(-dnext.y, dnext.x);
    if hasPrev and hasNext then
    begin
      den := 1 + nprev.x * nnext.x + nprev.y * nnext.y;
      if den < 0.05 then m := nprev
      else m := MakePt((nprev.x + nnext.x) / den, (nprev.y + nnext.y) / den);
      ml := Hypot(m.x, m.y);
      if ml > 4 then m := MakePt(m.x / ml * 4, m.y / ml * 4);
    end
    else if hasPrev then m := nprev
    else if hasNext then m := nnext;
    q[i] := MakePt(p[i].x + m.x * dist, p[i].y + m.y * dist);
  end;
end;

procedure TDoc.UpdateOffsets;
var
  pass, i: Integer;
  f, src: TShape;
  q: TPtArray;
  x1, y1, x2, y2, hw, hh, cx, cy: Double;
begin
  for pass := 1 to 2 do        // offsets of offsets
    for i := 0 to Shapes.Count - 1 do
    begin
      f := Shapes[i];
      if f.OffSrc <= 0 then Continue;
      src := FindShape(f.OffSrc);
      if (src = nil) or (src = f) or (src.Kind <> f.Kind) or not OffsetableKind(f.Kind) then
      begin
        f.OffSrc := 0;    // the source is gone: the copy becomes an ordinary object
        Continue;
      end;
      case f.Kind of
        skLine, skPolyline, skPolygon:
          begin
            OffsetPoints(src.P, f.Kind = skPolygon, f.OffDist, q);
            f.P := q;
          end;
        skRect:
          begin
            x1 := Min(src.P[0].x, src.P[1].x);
            x2 := Max(src.P[0].x, src.P[1].x);
            y1 := Min(src.P[0].y, src.P[1].y);
            y2 := Max(src.P[0].y, src.P[1].y);
            cx := (x1 + x2) / 2;
            cy := (y1 + y2) / 2;
            hw := Max((x2 - x1) / 2 + f.OffDist, 0.005);
            hh := Max((y2 - y1) / 2 + f.OffDist, 0.005);
            SetLength(f.P, 2);
            f.P[0] := MakePt(cx - hw, cy - hh);
            f.P[1] := MakePt(cx + hw, cy + hh);
            f.Corner := Max(0, src.Corner + f.OffDist);
            f.Rot := src.Rot;
          end;
        skEllipse, skArc:
          begin
            SetLength(f.P, 1);
            f.P[0] := src.P[0];
            f.RX := Max(src.RX + f.OffDist, 0.01);
            f.RY := Max(src.RY + f.OffDist, 0.01);
            f.A1 := src.A1;
            f.A2 := src.A2;
            f.Circ := src.Circ;
            f.Rot := src.Rot;
          end;
      end;
    end;
end;

// the sign that turns the distance the user gives (closed shapes: positive inwards; arcs: positive towards the centre; lines: positive
// on the left of the direction of the line) into the OffDist of the model
function TDoc.OffsetFactor(src: TShape): Double;
var
  i, n: Integer;
  area: Double;
begin
  Result := 1;
  if src = nil then Exit;
  case src.Kind of
    skRect, skEllipse, skArc: Result := -1;       // OffDist > 0 makes them bigger
    skPolygon:
      begin
        n := Length(src.P);
        area := 0;
        for i := 0 to n - 1 do
          area := area + src.P[i].x * src.P[(i + 1) mod n].y - src.P[(i + 1) mod n].x * src.P[i].y;
        if area < 0 then Result := -1;            // the left normal points outwards
      end;
  end;
end;

// a parallel copy at the distance the user gave (the sign decides the side)
function TDoc.AddOffsetSigned(src: TShape; dist: Double; out err: string): TShape;
var
  f: TShape;
begin
  Result := nil;
  err := '';
  if (src = nil) or not OffsetableKind(src.Kind) then
  begin
    err := 'This kind of object cannot be offset.';
    Exit;
  end;
  if Abs(dist) < 1e-9 then
  begin
    err := 'The distance cannot be zero.';
    Exit;
  end;
  f := TShape.Create;
  f.Kind := src.Kind;
  f.Style := src.Style;
  f.Style.Fill := NoColor;
  f.P := Copy(src.P);
  f.RX := src.RX;
  f.RY := src.RY;
  f.A1 := src.A1;
  f.A2 := src.A2;
  f.Circ := src.Circ;
  f.OffSrc := src.Id;
  f.OffDist := OffsetFactor(src) * dist;
  f.LayerId := src.LayerId;
  AddShape(f);
  UpdateOffsets;
  Result := f;
end;

function TDoc.AddOffset(src: TShape; x, y, dist: Double; out err: string): TShape;
var
  f: TShape;
  sgn, best, d, mx1, mx2, my1, my2: Double;
  i, n, bi: Integer;
  a, b, dd: TPt;
  outside: Boolean;
begin
  Result := nil;
  err := '';
  if (src = nil) or not OffsetableKind(src.Kind) then
  begin
    err := 'This kind of object cannot be offset.';
    Exit;
  end;
  if dist <= 0 then
  begin
    err := 'The distance must be positive.';
    Exit;
  end;
  sgn := 1;
  case src.Kind of
    skLine, skPolyline, skPolygon:
      begin
        n := Length(src.P);
        best := 1e18;
        bi := 0;
        for i := 0 to n - 1 do
        begin
          if (src.Kind <> skPolygon) and (i = n - 1) then Break;
          a := src.P[i];
          b := src.P[(i + 1) mod n];
          d := DistToSegment(x, y, a.x, a.y, b.x, b.y);
          if d < best then
          begin
            best := d;
            bi := i;
          end;
        end;
        a := src.P[bi];
        b := src.P[(bi + 1) mod n];
        if not UnitDir(a, b, dd) then
        begin
          err := 'Degenerate object.';
          Exit;
        end;
        if (x - a.x) * (-dd.y) + (y - a.y) * dd.x < 0 then sgn := -1;
      end;
    skRect:
      begin
        mx1 := Min(src.P[0].x, src.P[1].x);
        mx2 := Max(src.P[0].x, src.P[1].x);
        my1 := Min(src.P[0].y, src.P[1].y);
        my2 := Max(src.P[0].y, src.P[1].y);
        outside := (x < mx1) or (x > mx2) or (y < my1) or (y > my2);
        if not outside then sgn := -1;
      end;
    skEllipse, skArc:
      begin
        outside := Sqr((x - src.P[0].x) / Max(src.RX, 0.01)) +
          Sqr((y - src.P[0].y) / Max(src.RY, 0.01)) > 1;
        if not outside then sgn := -1;
      end;
  end;
  f := TShape.Create;
  f.Kind := src.Kind;
  f.Style := src.Style;
  f.Style.Fill := NoColor;
  f.P := Copy(src.P);
  f.RX := src.RX;
  f.RY := src.RY;
  f.A1 := src.A1;
  f.A2 := src.A2;
  f.Circ := src.Circ;
  f.OffSrc := src.Id;
  f.OffDist := sgn * dist;
  f.LayerId := src.LayerId;
  AddShape(f);
  UpdateOffsets;
  Result := f;
end;

{ ---------- mirror ---------- }

function MirrorableKind(k: TShapeKind): Boolean;
begin
  Result := k in [skLine, skArrow, skPolyline, skPolygon, skRect, skEllipse, skArc, skSpline];
end;

// axis of a mirror copy: a point of the axis line and its unit direction
function TDoc.MirrorFrame(s: TShape; out a, u: TPt): Boolean;
var
  ax: TShape;
begin
  Result := False;
  a := MakePt(0, 0);
  u := MakePt(1, 0);
  if s.MirAxis <= 0 then Exit;
  ax := FindShape(s.MirAxis);
  if (ax = nil) or (ax.Kind <> skLine) or (Length(ax.P) < 2) then Exit;
  a := ax.P[0];
  Result := UnitDir(ax.P[0], ax.P[1], u);
end;

procedure TDoc.UpdateMirrors;
var
  pass, i, j: Integer;
  f, src: TShape;
  a, u: TPt;
  phi: Double;
begin
  for pass := 1 to 2 do
    for i := 0 to Shapes.Count - 1 do
    begin
      f := Shapes[i];
      if f.MirSrc <= 0 then Continue;
      src := FindShape(f.MirSrc);
      if (src = nil) or (src = f) or (src.Kind <> f.Kind) or not MirrorableKind(f.Kind) or
         not MirrorFrame(f, a, u) then
      begin
        f.MirSrc := 0;      // source or axis gone: the copy becomes an ordinary object
        f.MirAxis := 0;
        Continue;
      end;
      SetLength(f.P, Length(src.P));
      f.Corner := src.Corner;
      f.Rot := -src.Rot;        // a reflection turns the other way
      for j := 0 to High(src.P) do
        f.P[j] := ReflectPt(src.P[j], a, u);
      if f.Kind in [skEllipse, skArc] then
      begin
        phi := ArcTan2(u.y, u.x);
        f.RX := src.RX;
        f.RY := src.RY;
        f.Circ := src.Circ;
        f.A1 := 2 * phi - src.A2;
        f.A2 := 2 * phi - src.A1;
      end;
    end;
end;

function TDoc.AddMirror(src, axis: TShape; out err: string): TShape;
var
  f: TShape;
  u: TPt;
  q: Double;
begin
  Result := nil;
  err := '';
  if (src = nil) or not MirrorableKind(src.Kind) then
  begin
    err := 'This kind of object cannot be mirrored.';
    Exit;
  end;
  if (axis = nil) or (axis.Kind <> skLine) or (axis = src) then
  begin
    err := 'The mirror axis must be a different, straight line.';
    Exit;
  end;
  if not UnitDir(axis.P[0], axis.P[1], u) then
  begin
    err := 'Degenerate axis.';
    Exit;
  end;
  // rectangles / true ellipses cannot be rotated: axis must be horizontal or vertical
  if (src.Kind = skRect) or ((src.Kind in [skEllipse, skArc]) and (Abs(src.RX - src.RY) > 1e-6)) then
  begin
    q := Min(Abs(u.x), Abs(u.y));
    if q > 1e-3 then
    begin
      err := 'Rectangles and non-circular ellipses can only be mirrored on a horizontal or vertical axis.';
      Exit;
    end;
  end;
  f := TShape.Create;
  f.Kind := src.Kind;
  f.Style := src.Style;
  f.P := Copy(src.P);
  f.RX := src.RX;
  f.RY := src.RY;
  f.A1 := src.A1;
  f.A2 := src.A2;
  f.Circ := src.Circ;
  f.MirSrc := src.Id;
  f.MirAxis := axis.Id;
  f.LayerId := src.LayerId;
  AddShape(f);
  UpdateMirrors;
  Result := f;
end;

{ ---------- array ---------- }

const
  MaxArrayItems = 400;

function RotatableKind(s: TShape): Boolean;
begin
  Result := (s.Kind in [skLine, skArrow, skPolyline, skPolygon, skSpline]) or
    ((s.Kind in [skEllipse, skArc]) and (Abs(s.RX - s.RY) < 1e-6));
end;

function ShapeCenter(s: TShape): TPt;
var
  o: TOutline;
  i, j: Integer;
  x1, y1, x2, y2: Double;
begin
  o := ShapeOutline(s);
  x1 := 1e18; y1 := 1e18; x2 := -1e18; y2 := -1e18;
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      x1 := Min(x1, o[i].Pts[j].x);
      y1 := Min(y1, o[i].Pts[j].y);
      x2 := Max(x2, o[i].Pts[j].x);
      y2 := Max(y2, o[i].Pts[j].y);
    end;
  if x1 > x2 then Result := MakePt(0, 0)
  else Result := MakePt((x1 + x2) / 2, (y1 + y2) / 2);
end;

function TDoc.ArrayById(id: Integer): TArraySpec;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Arrays.Count - 1 do
    if Arrays[i].Id = id then Exit(Arrays[i]);
end;

function TArraySpec.IsFreed(k: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(Freed) do
    if Freed[i] = k then Exit(True);
  Result := False;
end;

// the shape that s is derived from (array source, mirrored / offset original), or nil
function TDoc.ParentOf(s: TShape): TShape;
var
  spec: TArraySpec;
begin
  Result := nil;
  if s.ArrId > 0 then
  begin
    spec := ArrayById(s.ArrId);
    if spec <> nil then Result := FindShape(spec.Src);
  end
  else if s.MirSrc > 0 then Result := FindShape(s.MirSrc)
  else if s.OffSrc > 0 then Result := FindShape(s.OffSrc);
  if Result = s then Result := nil;
end;

// a copy (of an array, a mirror or an offset) becomes an object of its own, where it is now
function TDoc.DetachCopy(s: TShape): Boolean;
var
  spec: TArraySpec;
begin
  Result := False;
  if s.ArrId > 0 then
  begin
    spec := ArrayById(s.ArrId);
    if spec <> nil then
    begin
      SetLength(spec.Freed, Length(spec.Freed) + 1);
      spec.Freed[High(spec.Freed)] := s.ArrK;
    end;
    s.ArrId := 0;
    s.ArrK := 0;
    Result := True;
  end;
  if s.MirSrc > 0 then
  begin
    s.MirSrc := 0;
    s.MirAxis := 0;
    Result := True;
  end;
  if s.OffSrc > 0 then
  begin
    s.OffSrc := 0;
    Result := True;
  end;
end;

// the array a shape belongs to, as a copy or as the source
function TDoc.ArrayOf(s: TShape): TArraySpec;
var
  i: Integer;
begin
  Result := nil;
  if s.ArrId > 0 then Exit(ArrayById(s.ArrId));
  for i := 0 to Arrays.Count - 1 do
    if Arrays[i].Src = s.Id then Exit(Arrays[i]);
end;

// transform that maps the source of an array / mirror copy onto the copy s
function TDoc.CopyXf(s: TShape; out src: TShape; out m: TXf): Boolean;
var
  spec: TArraySpec;
  a, u: TPt;
  step, th, c0x, c0y: Double;
  i, j: Integer;
  cen: TPt;
begin
  Result := False;
  src := nil;
  FillChar(m, SizeOf(m), 0);
  if s.MirSrc > 0 then
  begin
    src := FindShape(s.MirSrc);
    if (src = nil) or (src = s) or not MirrorFrame(s, a, u) then Exit;
    m.Mode := 1;
    m.A := a;
    m.U := u;
    Exit(True);
  end;
  if s.ArrId > 0 then
  begin
    spec := ArrayById(s.ArrId);
    if spec = nil then Exit;
    src := FindShape(spec.Src);
    if (src = nil) or (src = s) then Exit;
    if not spec.Polar then
    begin
      i := s.ArrK mod Max(spec.Cols, 1);
      j := s.ArrK div Max(spec.Cols, 1);
      m.Mode := 2;
      m.DX := i * spec.DX;
      m.DY := j * spec.DY;
      Exit(True);
    end;
    if (spec.Total >= 359.999) or (spec.Count < 2) then step := 2 * Pi / Max(spec.Count, 1)
    else step := spec.Total * Pi / 180 / (spec.Count - 1);
    th := step * s.ArrK;
    m.C := MakePt(spec.CX, spec.CY);
    m.Cs := Cos(th);
    m.Sn := Sin(th);
    if RotatableKind(src) then m.Mode := 3
    else
    begin
      // not rotatable: the item keeps its orientation and travels around the center
      cen := ShapeCenter(src);
      c0x := m.C.x + (cen.x - m.C.x) * m.Cs - (cen.y - m.C.y) * m.Sn;
      c0y := m.C.y + (cen.x - m.C.x) * m.Sn + (cen.y - m.C.y) * m.Cs;
      m.Mode := 2;
      m.DX := c0x - cen.x;
      m.DY := c0y - cen.y;
    end;
    Exit(True);
  end;
end;

procedure TDoc.ExplodeArray(id: Integer);
var
  i: Integer;
begin
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].ArrId = id then
    begin
      Shapes[i].ArrId := 0;
      Shapes[i].ArrK := 0;
    end;
  for i := Arrays.Count - 1 downto 0 do
    if Arrays[i].Id = id then Arrays.Delete(i);
end;

procedure TDoc.UpdateArrays;
var
  i, j, k, n, r: Integer;
  spec: TArraySpec;
  src, f: TShape;
  slot: array of TShape;
  dead: array of TShape;
  xf: TXf;
  th: Double;
  pv, np: TPt;
begin
  // arrays whose source is gone are released: the copies become ordinary objects
  for i := Arrays.Count - 1 downto 0 do
    if FindShape(Arrays[i].Src) = nil then ExplodeArray(Arrays[i].Id);
  for i := 0 to Shapes.Count - 1 do
    if (Shapes[i].ArrId > 0) and (ArrayById(Shapes[i].ArrId) = nil) then
    begin
      Shapes[i].ArrId := 0;
      Shapes[i].ArrK := 0;
    end;
  for i := 0 to Arrays.Count - 1 do
  begin
    spec := Arrays[i];
    src := FindShape(spec.Src);
    n := Max(1, Min(spec.N, MaxArrayItems));
    SetLength(slot, n);
    SetLength(dead, 0);
    for k := 0 to n - 1 do slot[k] := nil;
    for j := 0 to Shapes.Count - 1 do
      if Shapes[j].ArrId = spec.Id then
      begin
        k := Shapes[j].ArrK;
        if (k >= 1) and (k < n) and (slot[k] = nil) then slot[k] := Shapes[j]
        else
        begin
          SetLength(dead, Length(dead) + 1);
          dead[High(dead)] := Shapes[j];
        end;
      end;
    for j := 0 to High(dead) do
    begin
      for k := Cons.Count - 1 downto 0 do
        for r := 0 to High(Cons[k].Refs) do
          if Cons[k].Refs[r].Shape = dead[j].Id then
          begin
            Cons.Delete(k);
            Break;
          end;
      Shapes.Remove(dead[j]);
    end;
    for k := 1 to n - 1 do
    begin
      if (slot[k] = nil) and spec.IsFreed(k) then Continue;
      if slot[k] = nil then
      begin
        f := TShape.Create;
        f.Assign(src);
        SetLength(f.Trims, 0);
        SetLength(f.Extends, 0);
        f.FA := 0; f.FB := 0;
        f.OffSrc := 0;
        f.MirSrc := 0; f.MirAxis := 0;
        f.ArrId := spec.Id;
        f.ArrK := k;
        AddShape(f);
        slot[k] := f;
      end;
      f := slot[k];
      // look: shared with the source
      f.Style := src.Style;
      f.IsRef := src.IsRef;
      f.Text := src.Text;
      f.FontSize := src.FontSize;
      f.ImageData := src.ImageData;
      f.KeyOn := src.KeyOn;
      f.KeyColor := src.KeyColor;
      f.KeyTol := src.KeyTol;
      f.KeyOrig := src.KeyOrig;
      f.Reg := src.Reg;
      if f.PathData <> src.PathData then
      begin
        f.PathData := src.PathData;
        if f.Kind = skPath then f.ParsePath;
      end;
      // geometry
      if not CopyXf(f, src, xf) then Continue;
      SetLength(f.P, Length(src.P));
      f.RX := src.RX;
      f.RY := src.RY;
      f.Circ := src.Circ;
      f.A1 := src.A1;
      f.A2 := src.A2;
      f.Corner := src.Corner;
      f.Rot := src.Rot;
      if (xf.Mode = 3) and RotKind(src.Kind) and (Length(src.P) > 0) then
      begin
        // the copy keeps its shape: it is the same object turned, with its pivot taken round the centre
        th := ArcTan2(xf.Sn, xf.Cs);
        pv := ShapePivot(src);
        np := XfPt(xf, pv);
        for j := 0 to High(src.P) do
          f.P[j] := MakePt(src.P[j].x + np.x - pv.x, src.P[j].y + np.y - pv.y);
        f.Rot := NormAngle(src.Rot - th);
      end
      else
        for j := 0 to High(src.P) do
          f.P[j] := XfPt(xf, src.P[j]);
    end;
  end;
end;

function TDoc.AddArray(src: TShape; polar: Boolean; cols, rows: Integer; dx, dy: Double;
  count: Integer; cx, cy, total: Double; out err: string): TArraySpec;
var
  spec: TArraySpec;
begin
  Result := nil;
  err := '';
  if src = nil then Exit;
  if (src.MirSrc > 0) or (src.OffSrc > 0) or (src.ArrId > 0) or (src.FA > 0) then
  begin
    // derived shapes are fine as sources too, only a copy of an array is not
    if src.ArrId > 0 then
    begin
      err := 'This object already belongs to an array.';
      Exit;
    end;
  end;
  if ArrayOf(src) <> nil then
  begin
    err := 'This object is already the source of an array.';
    Exit;
  end;
  if polar then
  begin
    if (count < 2) or (total <= 0) or (total > 360) then
    begin
      err := 'A polar array needs at least 2 items and an angle between 0 and 360.';
      Exit;
    end;
    cols := 1;
    rows := 1;
  end
  else
  begin
    if (cols < 1) or (rows < 1) or (cols * rows < 2) then
    begin
      err := 'A rectangular array needs at least 2 items.';
      Exit;
    end;
    count := cols * rows;
  end;
  if count > MaxArrayItems then
  begin
    err := 'Too many items (maximum ' + IntToStr(MaxArrayItems) + ').';
    Exit;
  end;
  spec := TArraySpec.Create;
  spec.Id := NextId;
  Inc(NextId);
  spec.Src := src.Id;
  spec.Polar := polar;
  spec.Cols := cols;
  spec.Rows := rows;
  spec.DX := dx;
  spec.DY := dy;
  spec.Count := count;
  spec.CX := cx;
  spec.CY := cy;
  spec.Total := total;
  Arrays.Add(spec);
  UpdateArrays;
  Result := spec;
end;

{ ---------- scale ---------- }

function RotatePathData(const d: string; ang: Double): string;
begin
  Result := AffinePathData(d, Cos(ang), Sin(ang), -Sin(ang), Cos(ang));
end;

function AffinePathData(const d: string; m11, m12, m21, m22: Double): string;
var
  i, n, k, per, q: Integer;
  cmd, uc: Char;
  rel: Boolean;
  nums: array of Double;
  cx, cy, sx, sy, ex, ey: Double;

  function F(v: Double): string;
  begin
    Result := FormatFloat('0.######', v, MFS);
  end;

  procedure Pair(x, y: Double);
  begin
    Result := Result + F(x * m11 + y * m12) + ' ' + F(x * m21 + y * m22) + ' ';
  end;

  procedure ReadNums;
  var
    j, st: Integer;
  begin
    SetLength(nums, 0);
    while i <= n do
    begin
      while (i <= n) and (d[i] in [' ', ',', #9, #10, #13]) do Inc(i);
      if (i > n) or ((d[i] in ['A'..'Z', 'a'..'z']) and not (d[i] in ['e', 'E'])) then Break;
      st := i;
      j := i;
      if d[j] in ['+', '-'] then Inc(j);
      while (j <= n) and (d[j] in ['0'..'9', '.']) do Inc(j);
      if (j <= n) and (d[j] in ['e', 'E']) then
      begin
        Inc(j);
        if (j <= n) and (d[j] in ['+', '-']) then Inc(j);
        while (j <= n) and (d[j] in ['0'..'9']) do Inc(j);
      end;
      if j = st then Break;
      SetLength(nums, Length(nums) + 1);
      nums[High(nums)] := StrToFloatDef(Copy(d, st, j - st), 0, MFS);
      i := j;
    end;
  end;

begin
  Result := '';
  n := Length(d);
  i := 1;
  cx := 0; cy := 0; sx := 0; sy := 0;
  while i <= n do
  begin
    if not (d[i] in ['A'..'Z', 'a'..'z']) then
    begin
      Inc(i);
      Continue;
    end;
    cmd := d[i];
    Inc(i);
    ReadNums;
    rel := cmd in ['a'..'z'];
    uc := UpCase(cmd);
    if uc = 'Z' then
    begin
      Result := Result + 'Z ';
      cx := sx;
      cy := sy;
      Continue;
    end;
    case uc of
      'M', 'L', 'T': per := 2;
      'C': per := 6;
      'S', 'Q': per := 4;
      'H', 'V': per := 1;
      'A': per := 7;
    else per := 0;
    end;
    if per = 0 then Continue;
    k := 0;
    while k + per <= Length(nums) do
    begin
      if uc = 'H' then
      begin
        if rel then cx := cx + nums[k] else cx := nums[k];
        Result := Result + 'L ';
        Pair(cx, cy);
      end
      else if uc = 'V' then
      begin
        if rel then cy := cy + nums[k] else cy := nums[k];
        Result := Result + 'L ';
        Pair(cx, cy);
      end
      else if uc = 'A' then
      begin
        ex := nums[k + 5];
        ey := nums[k + 6];
        if rel then begin ex := ex + cx; ey := ey + cy; end;
        cx := ex;
        cy := ey;
        Result := Result + 'L ';
        Pair(cx, cy);
      end
      else
      begin
        // every pair is a point (a vector when relative): all of them turn the same way
        if (uc = 'M') and (k > 0) then
        begin
          if rel then Result := Result + 'l ' else Result := Result + 'L ';
        end
        else Result := Result + cmd + ' ';
        for q := 0 to per div 2 - 1 do Pair(nums[k + q * 2], nums[k + q * 2 + 1]);
        ex := nums[k + per - 2];
        ey := nums[k + per - 1];
        if rel then begin ex := ex + cx; ey := ey + cy; end;
        cx := ex;
        cy := ey;
        if (uc = 'M') and (k = 0) then
        begin
          sx := cx;
          sy := cy;
        end;
      end;
      Inc(k, per);
    end;
  end;
end;

// multiplies every coordinate of an SVG path by k (arc flags / rotation are left alone)
function ScalePathData(const d: string; k: Double): string;
begin
  Result := ScalePathDataXY(d, k, k);
end;

// the same with a different factor for x and y
function ScalePathDataXY(const d: string; kx, ky: Double): string;
var
  i, j, n, argIdx: Integer;
  cmd: Char;
  c: Char;
  v: Double;
  doIt, useX: Boolean;
begin
  Result := '';
  n := Length(d);
  i := 1;
  cmd := ' ';
  argIdx := 0;
  while i <= n do
  begin
    c := d[i];
    if (c in ['A'..'Z', 'a'..'z']) and not (c in ['e', 'E']) then
    begin
      cmd := c;
      argIdx := 0;
      Result := Result + c;
      Inc(i);
    end
    else if c in ['0'..'9', '+', '-', '.'] then
    begin
      j := i;
      if d[j] in ['+', '-'] then Inc(j);
      while (j <= n) and (d[j] in ['0'..'9', '.']) do Inc(j);
      if (j <= n) and (d[j] in ['e', 'E']) then
      begin
        Inc(j);
        if (j <= n) and (d[j] in ['+', '-']) then Inc(j);
        while (j <= n) and (d[j] in ['0'..'9']) do Inc(j);
      end;
      if j = i then
      begin
        Result := Result + c;
        Inc(i);
        Continue;
      end;
      v := StrToFloatDef(Copy(d, i, j - i), 0, MFS);
      case UpCase(cmd) of
        'A': doIt := (argIdx mod 7) in [0, 1, 5, 6];
        'Z': doIt := False;
      else doIt := True;
      end;
      // which axis this number belongs to
      case UpCase(cmd) of
        'H': useX := True;
        'V': useX := False;
        'A': useX := (argIdx mod 7) in [0, 5];
      else useX := argIdx mod 2 = 0;
      end;
      if doIt then
        if useX then v := v * kx else v := v * ky;
      Result := Result + FormatFloat('0.######', v, MFS);
      Inc(argIdx);
      i := j;
    end
    else
    begin
      Result := Result + c;
      Inc(i);
    end;
  end;
end;

function TDoc.NewGroupId: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].GroupId > Result then Result := Shapes[i].GroupId;
  Inc(Result);
end;

// different factors in x and y about (bx, by): the shapes of an inserted drawing take the size of their box
procedure TDoc.StretchShapes(const ids: array of Integer; bx, by, sx, sy: Double; keepWidth: Boolean);
var
  i, j, q: Integer;
  s: TShape;
  inSet: Boolean;
  k, ssx, ssy: Double;
begin
  if (Abs(sx) < 1e-9) or (Abs(sy) < 1e-9) then Exit;
  k := (Abs(sx) + Abs(sy)) / 2;
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    inSet := False;
    for q := 0 to High(ids) do
      if ids[q] = s.Id then inSet := True;
    if not inSet then Continue;
    // a regular polygon stays regular: it is scaled evenly (about the same point), so that the opposite corner of the box stays
    ssx := sx;
    ssy := sy;
    if s.Reg then
    begin
      ssx := k * Sign(sx);
      ssy := k * Sign(sy);
    end;
    for j := 0 to High(s.P) do
    begin
      s.P[j].x := bx + (s.P[j].x - bx) * ssx;
      s.P[j].y := by + (s.P[j].y - by) * ssy;
    end;
    s.RX := s.RX * Abs(sx);
    s.RY := s.RY * Abs(sy);
    if Abs(Abs(sx) - Abs(sy)) > 1e-9 then s.Circ := False;
    s.Corner := s.Corner * Min(Abs(sx), Abs(sy));
    s.FontSize := s.FontSize * Abs(sy);
    if not keepWidth then s.Style.Width := s.Style.Width * k;
    if s.Kind = skPath then
    begin
      s.PathData := ScalePathDataXY(s.PathData, sx, sy);
      s.ParsePath;
    end;
  end;
  UpdateFillets;
end;

// shear about (bx, by)
function TDoc.SkewShapes(const ids: array of Integer; bx, by, kx, ky: Double): Integer;
var
  i, j, q: Integer;
  s: TShape;
  inSet: Boolean;
  o: TOutline;
  p0: TPt;
  k: Double;

  procedure Map(var p: TPt);
  var
    dx, dy: Double;
  begin
    dx := p.x - bx;
    dy := p.y - by;
    p.x := bx + dx + kx * dy;
    p.y := by + dy + ky * dx;
  end;

begin
  Result := 0;
  k := 0.5523;
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    inSet := False;
    for q := 0 to High(ids) do
      if ids[q] = s.Id then inSet := True;
    if not inSet then Continue;
    if (s.OffSrc > 0) or (s.MirSrc > 0) or (s.ArrId > 0) or (s.FA > 0) or s.Bucket or (Length(s.P) = 0) then Continue;
    if s.Kind in [skText, skImage, skArc] then Continue;
    if Abs(NormAngle(s.Rot)) > 1e-6 then Continue;
    s.Rot := 0;
    case s.Kind of
      skRect:
        begin
          o := ShapeOutline(s);
          if (Length(o) = 0) or (Length(o[0].Pts) < 3) then Continue;
          s.P := Copy(o[0].Pts);
          SetLength(s.W, 0);
          s.Kind := skPolygon;
          s.Corner := 0;
          for j := 0 to High(s.P) do Map(s.P[j]);
        end;
      skEllipse:
        begin
          p0 := s.P[0];
          s.PathData := AffinePathData(Format('M %.6f 0 C %.6f %.6f %.6f %.6f 0 %.6f C %.6f %.6f %.6f %.6f %.6f 0 ' +
            'C %.6f %.6f %.6f %.6f 0 %.6f C %.6f %.6f %.6f %.6f %.6f 0 Z',
            [s.RX, s.RX, k * s.RY, k * s.RX, s.RY, s.RY,
             -k * s.RX, s.RY, -s.RX, k * s.RY, -s.RX,
             -s.RX, -k * s.RY, -k * s.RX, -s.RY, -s.RY,
             k * s.RX, -s.RY, s.RX, -k * s.RY, s.RX], MFS), 1, kx, ky, 1);
          SetLength(s.P, 1);
          s.P[0] := p0;
          Map(s.P[0]);
          s.Kind := skPath;
          s.RX := 0;
          s.RY := 0;
          s.ParsePath;
        end;
      skPath:
        begin
          s.PathData := AffinePathData(s.PathData, 1, kx, ky, 1);
          for j := 0 to High(s.P) do Map(s.P[j]);
          s.ParsePath;
        end;
    else
      for j := 0 to High(s.P) do Map(s.P[j]);
    end;
    Inc(Result);
  end;
  UpdateFillets;
end;

function TDoc.ScaleShapes(const ids: array of Integer; bx, by, k: Double): Integer;
var
  i, j: Integer;
  s, l1, l2: TShape;
  c: TConstraint;
  spec: TArraySpec;
  allIn: Boolean;

  function InSet(id: Integer): Boolean;
  var
    q: Integer;
  begin
    Result := False;
    for q := 0 to High(ids) do
      if ids[q] = id then Exit(True);
  end;

begin
  Result := 0;
  if Abs(k) < 1e-9 then Exit;
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    if not InSet(s.Id) then Continue;
    // derived shapes are recomputed from their sources
    if (s.OffSrc > 0) or (s.MirSrc > 0) or (s.ArrId > 0) or (s.FA > 0) then Continue;
    for j := 0 to High(s.P) do
    begin
      s.P[j].x := bx + (s.P[j].x - bx) * k;
      s.P[j].y := by + (s.P[j].y - by) * k;
    end;
    s.RX := s.RX * k;
    s.RY := s.RY * k;
    s.FontSize := s.FontSize * k;
    if s.Kind = skPath then
    begin
      s.PathData := ScalePathData(s.PathData, k);
      s.ParsePath;
    end;
    Inc(Result);
  end;
  // things that hang on a scaled shape scale with it
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    if (s.OffSrc > 0) and InSet(s.OffSrc) then s.OffDist := s.OffDist * k;
    if s.FA > 0 then
    begin
      l1 := FindShape(s.FA);
      l2 := FindShape(s.FB);
      if (l1 <> nil) and (l2 <> nil) and InSet(l1.Id) and InSet(l2.Id) then
      begin
        s.RX := s.RX * k;
        s.RY := s.RY * k;
        s.CD1 := s.CD1 * k;
        s.CD2 := s.CD2 * k;
      end;
    end;
  end;
  for i := 0 to Arrays.Count - 1 do
  begin
    spec := Arrays[i];
    if not InSet(spec.Src) then Continue;
    spec.DX := spec.DX * k;
    spec.DY := spec.DY * k;
    spec.CX := bx + (spec.CX - bx) * k;
    spec.CY := by + (spec.CY - by) * k;
  end;
  for i := 0 to Cons.Count - 1 do
  begin
    c := Cons[i];
    if not c.IsQuote then Continue;
    allIn := Length(c.Refs) > 0;
    for j := 0 to High(c.Refs) do
      if not InSet(c.Refs[j].Shape) then allIn := False;
    if not allIn then Continue;
    if c.Kind <> ckAngle then c.Value := c.Value * k;
    if c.Kind in [ckDistance, ckAngle] then c.Offset := c.Offset * k;
  end;
  UpdateFillets;
  Solve([]);
  UpdateFillets;
end;

{ ---------- rotate ---------- }

function TDoc.RotateShapes(const ids: array of Integer; bx, by, ang: Double;
  out skipped, dropped, converted: Integer): Integer;
var
  i, j, kq, q: Integer;
  s, m: TShape;
  c: TConstraint;
  cs, sn, dx, dy, t: Double;
  isMult, odd, allIn, allRot, whole, known: Boolean;
  pv, np: TPt;
  gids: array of Integer;

  function InSet(id: Integer): Boolean;
  var
    z: Integer;
  begin
    Result := False;
    for z := 0 to High(ids) do
      if ids[z] = id then Exit(True);
  end;

  procedure RotPt(var p: TPt);
  begin
    dx := p.x - bx;
    dy := p.y - by;
    t := bx + dx * cs + dy * sn;
    p.y := by - dx * sn + dy * cs;
    p.x := t;
  end;

begin
  Result := 0;
  skipped := 0;
  dropped := 0;
  converted := 0;
  cs := Cos(ang);
  sn := Sin(ang);
  kq := Round(ang / (Pi / 2));
  isMult := Abs(ang - kq * Pi / 2) < 1e-6;
  odd := isMult and (((kq mod 2) + 2) mod 2 = 1);
  SetLength(gids, 0);
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    if not InSet(s.Id) then Continue;
    if (s.OffSrc > 0) or (s.MirSrc > 0) or (s.ArrId > 0) or (s.FA > 0) then Continue;
    if s.GroupId > 0 then
    begin
      known := False;
      for j := 0 to High(gids) do
        if gids[j] = s.GroupId then known := True;
      if not known then
      begin
        SetLength(gids, Length(gids) + 1);
        gids[High(gids)] := s.GroupId;
      end;
    end;
    if RotKind(s.Kind) then
    begin
      if s.Bucket or (Length(s.P) = 0) then Continue;        // a fill follows the shapes that bound it
      if s.Rot = 0 then
      begin
        // the solver works on the geometry as stored: constraints do not go with a turned object
        for q := Cons.Count - 1 downto 0 do
          for j := 0 to High(Cons[q].Refs) do
            if Cons[q].Refs[j].Shape = s.Id then
            begin
              Cons.Delete(q);
              Inc(dropped);
              Break;
            end;
      end;
      // the shape turns about its own pivot; the pivot goes where the turn about (bx, by) takes it
      pv := ShapePivot(s);
      np := pv;
      RotPt(np);
      s.Translate(np.x - pv.x, np.y - pv.y);
      s.Rot := NormAngle(s.Rot + ang);
      Inc(Result);
      Continue;
    end;
    for j := 0 to High(s.P) do RotPt(s.P[j]);
    Inc(Result);
  end;
  // a group turned as a whole turns its box; a group turned in part loses its orientation
  for j := 0 to High(gids) do
  begin
    whole := True;
    for i := 0 to Shapes.Count - 1 do
      if (Shapes[i].GroupId = gids[j]) and not InSet(Shapes[i].Id) then whole := False;
    for i := 0 to Shapes.Count - 1 do
      if Shapes[i].GroupId = gids[j] then
        if whole then Shapes[i].GroupRot := NormAngle(Shapes[i].GroupRot + ang)
        else
        begin
          Shapes[i].GroupRot := 0;
          Shapes[i].Snip := '';
        end;
  end;
  // constraints that depend on the direction
  for q := Cons.Count - 1 downto 0 do
  begin
    c := Cons[q];
    allIn := Length(c.Refs) > 0;
    allRot := Length(c.Refs) > 0;
    for j := 0 to High(c.Refs) do
    begin
      if not InSet(c.Refs[j].Shape) then allIn := False;
      m := FindShape(c.Refs[j].Shape);
      if (m = nil) or not RotKind(m.Kind) then allRot := False;
    end;
    if not allIn or allRot then Continue;
    case c.Kind of
      ckHorizontal, ckVertical:
        if isMult then
        begin
          if odd then
            if c.Kind = ckHorizontal then c.Kind := ckVertical else c.Kind := ckHorizontal;
        end
        else
        begin
          Cons.Delete(q);
          Inc(dropped);
        end;
      ckDistance:
        if c.Axis in [1, 2] then
        begin
          if isMult then
          begin
            if odd then c.Axis := 3 - c.Axis;
          end
          else c.Axis := 0;
          c.Aux := 1;
          InitQuote(c);
        end;
    end;
  end;
  UpdateFillets;
  Solve([]);
  UpdateFillets;
end;

function TDoc.ConstraintAnchor(c: TConstraint): TPt;
var
  i, cnt: Integer;
  a, b: TPR;
  sx, sy: Double;
begin
  sx := 0; sy := 0; cnt := 0;
  for i := 0 to High(c.Refs) do
  begin
    if SegOf(c.Refs[i], a, b) then
    begin
      sx := sx + (a.S.P[a.I].x + b.S.P[b.I].x) / 2;
      sy := sy + (a.S.P[a.I].y + b.S.P[b.I].y) / 2;
      Inc(cnt);
    end
    else if PointOf(c.Refs[i], a) then
    begin
      sx := sx + a.S.P[a.I].x;
      sy := sy + a.S.P[a.I].y;
      Inc(cnt);
    end
    else if FindShape(c.Refs[i].Shape) <> nil then
    begin
      a.S := FindShape(c.Refs[i].Shape);
      if Length(a.S.P) > 0 then
      begin
        sx := sx + a.S.P[0].x;
        sy := sy + a.S.P[0].y;
        Inc(cnt);
      end;
    end;
  end;
  if cnt = 0 then Exit(MakePt(0, 0));
  Result := MakePt(sx / cnt, sy / cnt);
end;

{ ---------- solver ---------- }

procedure TDoc.Note(d: Double);
begin
  if d > FMove then FMove := d;
end;

procedure TDoc.Shift2(const a, b: TPR; dx, dy: Double);
var
  wa, wb, s: Double;
begin
  if (a.S = b.S) and (a.I = b.I) then Exit;
  wa := a.S.W[a.I];
  wb := b.S.W[b.I];
  s := wa + wb;
  if s < 1e-9 then Exit;
  a.S.P[a.I].x := a.S.P[a.I].x - dx * wa / s;
  a.S.P[a.I].y := a.S.P[a.I].y - dy * wa / s;
  b.S.P[b.I].x := b.S.P[b.I].x + dx * wb / s;
  b.S.P[b.I].y := b.S.P[b.I].y + dy * wb / s;
  Note(Abs(dx) + Abs(dy));
end;

procedure TDoc.RotateSeg(const a, b: TPR; ang: Double);
var
  dx, dy, c, s: Double;
begin
  dx := b.S.P[b.I].x - a.S.P[a.I].x;
  dy := b.S.P[b.I].y - a.S.P[a.I].y;
  c := Cos(ang);
  s := Sin(ang);
  Shift2(a, b, dx * c - dy * s - dx, dx * s + dy * c - dy);
end;

procedure TDoc.OnLine(const ps: array of TPR; const cs: array of Double;
  const la, lb: TPR; off: Double);
var
  i: Integer;
  pa, pb: PPt;
  mx, my, ux, uy, nx, ny, L, t, g, den, lam, wa, wb: Double;
begin
  pa := @la.S.P[la.I];
  pb := @lb.S.P[lb.I];
  L := Hypot(pb^.x - pa^.x, pb^.y - pa^.y);
  if L < 1e-9 then Exit;
  ux := (pb^.x - pa^.x) / L;
  uy := (pb^.y - pa^.y) / L;
  nx := -uy;
  ny := ux;
  mx := 0; my := 0;
  for i := 0 to High(ps) do
  begin
    mx := mx + cs[i] * ps[i].S.P[ps[i].I].x;
    my := my + cs[i] * ps[i].S.P[ps[i].I].y;
  end;
  g := (mx - pa^.x) * nx + (my - pa^.y) * ny - off;
  t := ((mx - pa^.x) * ux + (my - pa^.y) * uy) / L;
  wa := la.S.W[la.I];
  wb := lb.S.W[lb.I];
  den := wa * Sqr(1 - t) + wb * t * t;
  for i := 0 to High(ps) do
    den := den + cs[i] * cs[i] * ps[i].S.W[ps[i].I];
  if den < 1e-9 then Exit;
  lam := g / den;
  for i := 0 to High(ps) do
  begin
    ps[i].S.P[ps[i].I].x := ps[i].S.P[ps[i].I].x - lam * cs[i] * ps[i].S.W[ps[i].I] * nx;
    ps[i].S.P[ps[i].I].y := ps[i].S.P[ps[i].I].y - lam * cs[i] * ps[i].S.W[ps[i].I] * ny;
  end;
  pa^.x := pa^.x + lam * (1 - t) * wa * nx;
  pa^.y := pa^.y + lam * (1 - t) * wa * ny;
  pb^.x := pb^.x + lam * t * wb * nx;
  pb^.y := pb^.y + lam * t * wb * ny;
  Note(Abs(g));
end;

procedure TDoc.ShiftR(s1, s2: TShape; useY: Boolean);
var
  d, w1, w2, s: Double;
begin
  w1 := s1.WR;
  w2 := s2.WR;
  s := w1 + w2;
  if s < 1e-9 then Exit;
  if useY then d := s2.RY - s1.RY else d := s2.RX - s1.RX;
  if useY then
  begin
    s1.RY := s1.RY + d * w1 / s;
    s2.RY := s2.RY - d * w2 / s;
  end
  else
  begin
    s1.RX := s1.RX + d * w1 / s;
    s2.RX := s2.RX - d * w2 / s;
  end;
  Note(Abs(d));
end;

procedure TDoc.PairDist(const a, b: TPR; c: TConstraint);
var
  dx, dy, L, ux, uy: Double;
begin
  dx := b.S.P[b.I].x - a.S.P[a.I].x;
  dy := b.S.P[b.I].y - a.S.P[a.I].y;
  case c.Axis of
    1: Shift2(a, b, c.Aux * c.Value - dx, 0);
    2: Shift2(a, b, 0, c.Aux * c.Value - dy);
  else
    L := Hypot(dx, dy);
    if L < 1e-9 then
    begin
      ux := 1;
      uy := 0;
    end
    else
    begin
      ux := dx / L;
      uy := dy / L;
    end;
    Shift2(a, b, ux * (c.Value - L), uy * (c.Value - L));
  end;
end;

// Angular quote between two lines: the rays are +-direction of each line
// (bit 0 / bit 1 of Aux = +); V = intersection of the two lines, a1 = direction
// of the first ray, sweep = signed angle from the first to the second ray.
function TDoc.QuoteAngle(c: TConstraint; out V: TPt; out a1, sweep: Double): Boolean;
var
  a, b, a2, b2: TPR;
  d1x, d1y, d2x, d2y, den, t, s1, s2, l1, l2: Double;
  code: Integer;
begin
  Result := False;
  V := MakePt(0, 0);
  a1 := 0;
  sweep := 0;
  if Length(c.Refs) < 2 then Exit;
  if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
  d1x := b.S.P[b.I].x - a.S.P[a.I].x;
  d1y := b.S.P[b.I].y - a.S.P[a.I].y;
  d2x := b2.S.P[b2.I].x - a2.S.P[a2.I].x;
  d2y := b2.S.P[b2.I].y - a2.S.P[a2.I].y;
  l1 := Hypot(d1x, d1y);
  l2 := Hypot(d2x, d2y);
  if (l1 < 1e-9) or (l2 < 1e-9) then Exit;
  den := d1x * d2y - d1y * d2x;
  if Abs(den) < 1e-9 * l1 * l2 then
    V := MakePt(a.S.P[a.I].x, a.S.P[a.I].y)
  else
  begin
    t := ((a2.S.P[a2.I].x - a.S.P[a.I].x) * d2y - (a2.S.P[a2.I].y - a.S.P[a.I].y) * d2x) / den;
    V := MakePt(a.S.P[a.I].x + t * d1x, a.S.P[a.I].y + t * d1y);
  end;
  code := Round(c.Aux);
  if code and 1 <> 0 then s1 := 1 else s1 := -1;
  if code and 2 <> 0 then s2 := 1 else s2 := -1;
  a1 := ArcTan2(s1 * d1y, s1 * d1x);
  sweep := ArcTan2(s2 * d2y, s2 * d2x) - a1;
  while sweep > Pi do sweep := sweep - 2 * Pi;
  while sweep <= -Pi do sweep := sweep + 2 * Pi;
  Result := True;
end;

// a point stays on a circle / ellipse / arc outline: the point, the centre and the radius share
// the correction according to their weights
{ ---------- virtual points: ends of arcs, extreme points of circles / ellipses ---------- }

type
  // one thing the solver may change to move a point: a coordinate, a radius, an angle or a
  // shift of a stored point along a vector
  TSParam = record
    P: PDouble;
    Px, Py: PDouble;
    vx, vy: Double;
    W: Double;
    ex, ey: Double;          // how the point moves per unit of the parameter
  end;
  TSParams = array[0..11] of TSParam;

procedure SAdd(var prm: TSParams; var n: Integer; p: PDouble; w, ex, ey: Double);
begin
  prm[n].P := p;
  prm[n].Px := nil;
  prm[n].Py := nil;
  prm[n].W := w;
  prm[n].ex := ex;
  prm[n].ey := ey;
  Inc(n);
end;

// the parameters that move the point r (real, or virtual) and its position
function SParamsOf(doc: TDoc; const r: TRef; var prm: TSParams; out n: Integer;
  out pos: TPt; out sh: TShape): Boolean;
var
  pr: TPR;
  q: TPt;
  a, cs, sn, rr: Double;
begin
  Result := False;
  n := 0;
  sh := nil;
  if doc.PointOf(r, pr) then
  begin
    pos := pr.S.P[pr.I];
    sh := pr.S;
    SAdd(prm, n, @pr.S.P[pr.I].x, pr.S.W[pr.I], 1, 0);
    SAdd(prm, n, @pr.S.P[pr.I].y, pr.S.W[pr.I], 0, 1);
    Exit(True);
  end;
  if not doc.ArcEndOf(r, sh, q) then Exit;
  pos := q;
  SAdd(prm, n, @sh.P[0].x, sh.W[0], 1, 0);
  SAdd(prm, n, @sh.P[0].y, sh.W[0], 0, 1);
  if sh.Kind = skEllipse then
  begin
    case r.Idx of
      EllEastIdx: if sh.Circ then SAdd(prm, n, @sh.RX, sh.WR, 1, 0) else SAdd(prm, n, @sh.RX, sh.WR, 1, 0);
      EllWestIdx: SAdd(prm, n, @sh.RX, sh.WR, -1, 0);
      EllNorthIdx: if sh.Circ then SAdd(prm, n, @sh.RX, sh.WR, 0, -1) else SAdd(prm, n, @sh.RY, sh.WR, 0, -1);
    else
      if sh.Circ then SAdd(prm, n, @sh.RX, sh.WR, 0, 1) else SAdd(prm, n, @sh.RY, sh.WR, 0, 1);
    end;
  end
  else
  begin
    // arc end: the angle moves it along the arc, the radius away from the centre
    if r.Idx = ArcStartIdx then a := sh.A1 else a := sh.A2;
    cs := Cos(a);
    sn := Sin(a);
    rr := Max(Hypot(sh.RX, sh.RY) / Sqrt(2), 1e-3);
    if sh.Circ then
      SAdd(prm, n, @sh.RX, sh.WR, cs, sn)
    else
    begin
      SAdd(prm, n, @sh.RX, sh.WR, cs, 0);
      SAdd(prm, n, @sh.RY, sh.WR, 0, sn);
    end;
    // angle: its weight is in length units
    if r.Idx = ArcStartIdx then
      SAdd(prm, n, @sh.A1, 1 / (rr * rr), -sh.RX * sn, sh.RY * cs)
    else
      SAdd(prm, n, @sh.A2, 1 / (rr * rr), -sh.RX * sn, sh.RY * cs);
  end;
  Result := True;
end;

procedure SFix(sh: TShape);
begin
  if sh = nil then Exit;
  if sh.Kind in [skEllipse, skArc] then
  begin
    if sh.RX < 0.5 then sh.RX := 0.5;
    if sh.Circ then sh.RY := sh.RX else if sh.RY < 0.5 then sh.RY := 0.5;
  end;
end;

// Two points become coincident when at least one of them is a virtual point (end of an arc, extreme
// point of a circle / ellipse): the correction is shared between the points, the centres, the
// radii and the angles, by weights.  A quoted line whose ends sit on an ellipse or an arc then
// sets its size.  False when both are ordinary points (the ordinary solver handles them).
function TDoc.CoincideVirtual(const ra, rb: TRef): Boolean;
var
  pa, pb: TSParams;
  na, nb, i: Integer;
  posA, posB: TPt;
  sa, sb: TShape;
  rx, ry, m11, m12, m22, det, mx, my: Double;
  ca, cb: TPR;
begin
  Result := False;
  if PointOf(ra, ca) and PointOf(rb, cb) then Exit;
  if not (SParamsOf(Self, ra, pa, na, posA, sa) and SParamsOf(Self, rb, pb, nb, posB, sb)) then Exit;
  Result := True;
  if sa = sb then Exit;
  rx := posA.x - posB.x;
  ry := posA.y - posB.y;
  for i := 0 to nb - 1 do
  begin
    pb[i].ex := -pb[i].ex;
    pb[i].ey := -pb[i].ey;
  end;
  m11 := 0; m12 := 0; m22 := 0;
  for i := 0 to na - 1 do
  begin
    m11 := m11 + pa[i].W * pa[i].ex * pa[i].ex;
    m12 := m12 + pa[i].W * pa[i].ex * pa[i].ey;
    m22 := m22 + pa[i].W * pa[i].ey * pa[i].ey;
  end;
  for i := 0 to nb - 1 do
  begin
    m11 := m11 + pb[i].W * pb[i].ex * pb[i].ex;
    m12 := m12 + pb[i].W * pb[i].ex * pb[i].ey;
    m22 := m22 + pb[i].W * pb[i].ey * pb[i].ey;
  end;
  // a little regularisation keeps the 2x2 system solvable when one direction is blocked
  m11 := m11 + 1e-9;
  m22 := m22 + 1e-9;
  det := m11 * m22 - m12 * m12;
  if Abs(det) < 1e-18 then Exit;
  // M mu = -R
  mx := (-rx * m22 + ry * m12) / det;
  my := (-ry * m11 + rx * m12) / det;
  for i := 0 to na - 1 do
    pa[i].P^ := pa[i].P^ + pa[i].W * (pa[i].ex * mx + pa[i].ey * my);
  for i := 0 to nb - 1 do
    pb[i].P^ := pb[i].P^ + pb[i].W * (pb[i].ex * mx + pb[i].ey * my);
  SFix(sa);
  SFix(sb);
  Note(Hypot(rx, ry));
end;

// a virtual point must lie on the line rl: the point's parameters and the two ends of the line
// share the correction along the normal
function TDoc.VirtualOnLine(const rp, rl: TRef): Boolean;
var
  pp: TSParams;
  np, i: Integer;
  pos: TPt;
  sp: TShape;
  la, lb: TPR;
  ax, ay, bx, by, l, nx, ny, g, t, den, wa, wb, mu, c: Double;
  cf: array[0..11] of Double;
begin
  Result := False;
  if not SegOf(rl, la, lb) then Exit;
  if not SParamsOf(Self, rp, pp, np, pos, sp) then Exit;
  Result := True;
  if sp = la.S then Exit;
  ax := la.S.P[la.I].x;
  ay := la.S.P[la.I].y;
  bx := lb.S.P[lb.I].x;
  by := lb.S.P[lb.I].y;
  l := Hypot(bx - ax, by - ay);
  if l < 1e-9 then Exit;
  nx := -(by - ay) / l;
  ny := (bx - ax) / l;
  g := (pos.x - ax) * nx + (pos.y - ay) * ny;
  t := ((pos.x - ax) * (bx - ax) + (pos.y - ay) * (by - ay)) / (l * l);
  wa := la.S.W[la.I];
  wb := lb.S.W[lb.I];
  den := wa * Sqr(1 - t) + wb * t * t;
  for i := 0 to np - 1 do
  begin
    cf[i] := pp[i].ex * nx + pp[i].ey * ny;
    den := den + pp[i].W * cf[i] * cf[i];
  end;
  if den < 1e-9 then Exit;
  mu := g / den;
  for i := 0 to np - 1 do
    pp[i].P^ := pp[i].P^ - pp[i].W * cf[i] * mu;
  c := mu * (1 - t) * wa;
  la.S.P[la.I].x := la.S.P[la.I].x + c * nx;
  la.S.P[la.I].y := la.S.P[la.I].y + c * ny;
  c := mu * t * wb;
  lb.S.P[lb.I].x := lb.S.P[lb.I].x + c * nx;
  lb.S.P[lb.I].y := lb.S.P[lb.I].y + c * ny;
  SFix(sp);
  Note(Abs(g));
end;

procedure TDoc.SolveOnCurve(c: TConstraint);
var
  pm: TPR;
  pos: TPt;
  e: TShape;
  ux, uy, len, ct, st, r, g, wp, wc, wr, den, dr, f, ang, sw: Double;
begin
  if Length(c.Refs) <> 2 then Exit;
  e := EllOf(c.Refs[1]);
  if (e = nil) or not MovablePoint(c.Refs[0], pm, pos) then Exit;
  if pm.S = e then Exit;
  ux := pos.x - e.P[0].x;
  uy := pos.y - e.P[0].y;
  len := Hypot(ux, uy);
  if len < 1e-9 then Exit;
  ct := ux / len;
  st := uy / len;
  if e.Circ then r := e.RX
  else r := 1 / Sqrt(Sqr(ct / Max(e.RX, 1e-6)) + Sqr(st / Max(e.RY, 1e-6)));
  g := len - r;
  wp := pm.S.W[pm.I];
  wc := e.W[0];
  wr := e.WR;
  den := wp + wc + wr;
  if den < 1e-9 then Exit;
  // the arc of a fillet is fixed by its lines: the point stays on the arc itself, not on the rest of its circle (past the ends
  // of the arc it waits at the nearer end)
  if (e.Kind = skArc) and (e.FA > 0) and (wc + wr < 1e-9) then
  begin
    ang := ArcTan2(uy / Max(e.RY, 1e-6), ux / Max(e.RX, 1e-6)) - e.A1;
    while ang < 0 do ang := ang + 2 * Pi;
    while ang >= 2 * Pi do ang := ang - 2 * Pi;
    sw := ArcSweep(e);
    if ang > sw then
    begin
      if Min(ang, 2 * Pi - ang) <= Abs(ang - sw) then ang := 0 else ang := sw;
      ct := Cos(e.A1 + ang);
      st := Sin(e.A1 + ang);
      len := r;      // the target is on the circle at that end
      g := Hypot(pos.x - (e.P[0].x + ct * r), pos.y - (e.P[0].y + st * r));
      Note(g);
      pm.S.P[pm.I].x := e.P[0].x + ct * r;
      pm.S.P[pm.I].y := e.P[0].y + st * r;
      Exit;
    end;
  end;
  pm.S.P[pm.I].x := pm.S.P[pm.I].x - ct * g * wp / den;
  pm.S.P[pm.I].y := pm.S.P[pm.I].y - st * g * wp / den;
  e.P[0].x := e.P[0].x + ct * g * wc / den;
  e.P[0].y := e.P[0].y + st * g * wc / den;
  dr := g * wr / den;
  if r > 1e-9 then
  begin
    f := (r + dr) / r;
    if f < 0.01 then f := 0.01;
    e.RX := e.RX * f;
    if e.Circ then e.RY := e.RX else e.RY := e.RY * f;
  end;
  Note(Abs(g));
end;

procedure TDoc.SolveAngle(c: TConstraint);
var
  a, b, a2, b2: TPR;
  v: TPt;
  a1, sw, tgt, e, ws1, ws2, k1: Double;
begin
  if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
  if not QuoteAngle(c, v, a1, sw) then Exit;
  tgt := c.Value * Pi / 180;
  if sw < 0 then tgt := -tgt;
  e := sw - tgt;
  while e > Pi do e := e - 2 * Pi;
  while e <= -Pi do e := e + 2 * Pi;
  ws1 := a.S.W[a.I] + b.S.W[b.I];
  ws2 := a2.S.W[a2.I] + b2.S.W[b2.I];
  if ws1 + ws2 < 1e-9 then Exit;
  k1 := ws1 / (ws1 + ws2);
  RotateSeg(a, b, e * k1);
  RotateSeg(a2, b2, -e * (1 - k1));
  Note(Abs(e) * 50);
end;

procedure TDoc.SolveDistance(c: TConstraint);
var
  a, b, p: TPR;
begin
  if (Length(c.Refs) = 1) then
  begin
    if SegOf(c.Refs[0], a, b) then PairDist(a, b, c);
  end
  else if PointOf(c.Refs[0], a) and PointOf(c.Refs[1], b) then
    PairDist(a, b, c)
  else if PointOf(c.Refs[0], p) and SegOf(c.Refs[1], a, b) then
    OnLine([p], [1.0], a, b, c.Aux * c.Value)
  else if PointOf(c.Refs[1], p) and SegOf(c.Refs[0], a, b) then
    OnLine([p], [1.0], a, b, c.Aux * c.Value);
end;

procedure TDoc.SolveMid(c: TConstraint);
var
  p, a, b: TPR;
  ex, ey, den, wp, wa, wb: Double;
begin
  if Length(c.Refs) <> 2 then Exit;
  if not (PointOf(c.Refs[0], p) and SegOf(c.Refs[1], a, b)) then
    if not (PointOf(c.Refs[1], p) and SegOf(c.Refs[0], a, b)) then Exit;
  wp := p.S.W[p.I];
  wa := a.S.W[a.I];
  wb := b.S.W[b.I];
  den := wp + (wa + wb) / 4;
  if den < 1e-9 then Exit;
  ex := p.S.P[p.I].x - (a.S.P[a.I].x + b.S.P[b.I].x) / 2;
  ey := p.S.P[p.I].y - (a.S.P[a.I].y + b.S.P[b.I].y) / 2;
  p.S.P[p.I].x := p.S.P[p.I].x - ex * wp / den;
  p.S.P[p.I].y := p.S.P[p.I].y - ey * wp / den;
  a.S.P[a.I].x := a.S.P[a.I].x + ex / 2 * wa / den;
  a.S.P[a.I].y := a.S.P[a.I].y + ey / 2 * wa / den;
  b.S.P[b.I].x := b.S.P[b.I].x + ex / 2 * wb / den;
  b.S.P[b.I].y := b.S.P[b.I].y + ey / 2 * wb / den;
  Note(Abs(ex) + Abs(ey));
end;

procedure TDoc.SolveTangent(c: TConstraint);
var
  a, b: TPR;
  e1, e2: TShape;
  r: TShape;
  pa, pb, pc: PPt;
  L, ux, uy, nx, ny, d, t, g, sg, den, lam, wa, wb, wc, dist, s: Double;
  wc2: Double;
  i, k: Integer;
  ells: array of TShape;
begin
  SetLength(ells, 0);
  r := nil;
  k := -1;
  for i := 0 to High(c.Refs) do
    if EllOf(c.Refs[i]) <> nil then
    begin
      SetLength(ells, Length(ells) + 1);
      ells[High(ells)] := EllOf(c.Refs[i]);
    end
    else k := i;
  if (Length(ells) = 1) and (k >= 0) and SegOf(c.Refs[k], a, b) then
  begin
    r := ells[0];
    pa := @a.S.P[a.I];
    pb := @b.S.P[b.I];
    pc := @r.P[0];
    L := Hypot(pb^.x - pa^.x, pb^.y - pa^.y);
    if L < 1e-9 then Exit;
    ux := (pb^.x - pa^.x) / L;
    uy := (pb^.y - pa^.y) / L;
    nx := -uy;
    ny := ux;
    d := (pc^.x - pa^.x) * nx + (pc^.y - pa^.y) * ny;
    t := ((pc^.x - pa^.x) * ux + (pc^.y - pa^.y) * uy) / L;
    if d < 0 then sg := -1 else sg := 1;
    g := Abs(d) - r.RX;
    wa := a.S.W[a.I];
    wb := b.S.W[b.I];
    wc := r.W[0];
    den := wc + wa * Sqr(1 - t) + wb * t * t + r.WR;
    if den < 1e-9 then Exit;
    lam := g / den;
    pc^.x := pc^.x - lam * sg * nx * wc;
    pc^.y := pc^.y - lam * sg * ny * wc;
    pa^.x := pa^.x + lam * sg * nx * (1 - t) * wa;
    pa^.y := pa^.y + lam * sg * ny * (1 - t) * wa;
    pb^.x := pb^.x + lam * sg * nx * t * wb;
    pb^.y := pb^.y + lam * sg * ny * t * wb;
    r.RX := r.RX + lam * r.WR;
    Note(Abs(g));
  end
  else if Length(ells) = 2 then
  begin
    e1 := ells[0];
    e2 := ells[1];
    dist := Hypot(e2.P[0].x - e1.P[0].x, e2.P[0].y - e1.P[0].y);
    if dist < 1e-9 then Exit;
    ux := (e2.P[0].x - e1.P[0].x) / dist;
    uy := (e2.P[0].y - e1.P[0].y) / dist;
    if c.Aux > 0.5 then
    begin
      if e1.RX >= e2.RX then s := 1 else s := -1;
      g := dist - Abs(e1.RX - e2.RX);
    end
    else
    begin
      s := 0;
      g := dist - (e1.RX + e2.RX);
    end;
    wc := e1.W[0];
    wc2 := e2.W[0];
    den := wc + wc2 + e1.WR + e2.WR;
    if den < 1e-9 then Exit;
    lam := g / den;
    e1.P[0].x := e1.P[0].x + lam * ux * wc;
    e1.P[0].y := e1.P[0].y + lam * uy * wc;
    e2.P[0].x := e2.P[0].x - lam * ux * wc2;
    e2.P[0].y := e2.P[0].y - lam * uy * wc2;
    if c.Aux > 0.5 then
    begin
      e1.RX := e1.RX + lam * s * e1.WR;
      e2.RX := e2.RX - lam * s * e2.WR;
    end
    else
    begin
      e1.RX := e1.RX + lam * e1.WR;
      e2.RX := e2.RX + lam * e2.WR;
    end;
    Note(Abs(g));
  end;
end;

procedure TDoc.SolveSymmetry(c: TConstraint);
var
  ax, bx: TPR;
  s1, s2: TShape;
  la, lb: TPR;
  i: Integer;

  procedure Pair(const pa, pb: TPR);
  var
    pl, pm: PPt;
    ux, uy, nx, ny, L, g1, g2, t, wA, wB, den, lam, mx, my: Double;
    wla, wlb: Double;
  begin
    if (pa.S = pb.S) and (pa.I = pb.I) then Exit;
    pl := @la.S.P[la.I];
    pm := @lb.S.P[lb.I];
    L := Hypot(pm^.x - pl^.x, pm^.y - pl^.y);
    if L < 1e-9 then Exit;
    ux := (pm^.x - pl^.x) / L;
    uy := (pm^.y - pl^.y) / L;
    nx := -uy;
    ny := ux;
    wA := pa.S.W[pa.I];
    wB := pb.S.W[pb.I];
    // (B - A) must be perpendicular to the axis
    if wA + wB > 1e-9 then
    begin
      g1 := (pb.S.P[pb.I].x - pa.S.P[pa.I].x) * ux + (pb.S.P[pb.I].y - pa.S.P[pa.I].y) * uy;
      pb.S.P[pb.I].x := pb.S.P[pb.I].x - g1 * ux * wB / (wA + wB);
      pb.S.P[pb.I].y := pb.S.P[pb.I].y - g1 * uy * wB / (wA + wB);
      pa.S.P[pa.I].x := pa.S.P[pa.I].x + g1 * ux * wA / (wA + wB);
      pa.S.P[pa.I].y := pa.S.P[pa.I].y + g1 * uy * wA / (wA + wB);
      Note(Abs(g1));
    end;
    // midpoint on the axis
    mx := (pa.S.P[pa.I].x + pb.S.P[pb.I].x) / 2;
    my := (pa.S.P[pa.I].y + pb.S.P[pb.I].y) / 2;
    g2 := (mx - pl^.x) * nx + (my - pl^.y) * ny;
    t := ((mx - pl^.x) * ux + (my - pl^.y) * uy) / L;
    wla := la.S.W[la.I];
    wlb := lb.S.W[lb.I];
    den := (wA + wB) / 4 + wla * Sqr(1 - t) + wlb * t * t;
    if den < 1e-9 then Exit;
    lam := g2 / den;
    pa.S.P[pa.I].x := pa.S.P[pa.I].x - lam * nx / 2 * wA;
    pa.S.P[pa.I].y := pa.S.P[pa.I].y - lam * ny / 2 * wA;
    pb.S.P[pb.I].x := pb.S.P[pb.I].x - lam * nx / 2 * wB;
    pb.S.P[pb.I].y := pb.S.P[pb.I].y - lam * ny / 2 * wB;
    pl^.x := pl^.x + lam * (1 - t) * wla * nx;
    pl^.y := pl^.y + lam * (1 - t) * wla * ny;
    pm^.x := pm^.x + lam * t * wlb * nx;
    pm^.y := pm^.y + lam * t * wlb * ny;
    Note(Abs(g2));
  end;

begin
  if Length(c.Refs) <> 3 then Exit;
  if not SegOf(c.Refs[2], la, lb) then Exit;
  s1 := FindShape(c.Refs[0].Shape);
  s2 := FindShape(c.Refs[1].Shape);
  if (s1 = nil) or (s2 = nil) then Exit;
  if (c.Refs[0].Idx >= 0) and (c.Refs[1].Idx >= 0) then
  begin
    if PointOf(c.Refs[0], ax) and PointOf(c.Refs[1], bx) then Pair(ax, bx);
  end
  else if (c.Refs[0].Idx = -1) and (c.Refs[1].Idx = -1) and (s1.Kind = s2.Kind) then
  begin
    for i := 0 to Min(Length(s1.P), Length(s2.P)) - 1 do
    begin
      ax.S := s1; ax.I := i;
      bx.S := s2; bx.I := i;
      Pair(ax, bx);
    end;
    if s1.Kind in [skEllipse, skArc] then
    begin
      ShiftR(s1, s2, False);
      ShiftR(s1, s2, True);
    end;
  end;
end;

procedure TDoc.SolveOne(c: TConstraint);
var
  a, b, p, a2, b2: TPR;
  i, k: Integer;
  s1, s2: TShape;
  l1, l2, ws1, ws2, tgt, e, k1, off, ux, uy, d1x, d1y, d2x, d2y, l: Double;
  pa0, pb0: TPt;
begin
  case c.Kind of
    ckFixed: ;
    ckHorizontal, ckVertical:
      begin
        if Length(c.Refs) = 1 then
        begin
          if not SegOf(c.Refs[0], a, b) then Exit;
        end
        else if not (PointOf(c.Refs[0], a) and PointOf(c.Refs[1], b)) then Exit;
        if c.Kind = ckHorizontal then
          Shift2(a, b, 0, -(b.S.P[b.I].y - a.S.P[a.I].y))
        else
          Shift2(a, b, -(b.S.P[b.I].x - a.S.P[a.I].x), 0);
      end;
    ckParallel, ckPerpendicular:
      begin
        if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
        d1x := b.S.P[b.I].x - a.S.P[a.I].x;
        d1y := b.S.P[b.I].y - a.S.P[a.I].y;
        d2x := b2.S.P[b2.I].x - a2.S.P[a2.I].x;
        d2y := b2.S.P[b2.I].y - a2.S.P[a2.I].y;
        if (Hypot(d1x, d1y) < 1e-9) or (Hypot(d2x, d2y) < 1e-9) then Exit;
        if c.Kind = ckPerpendicular then off := Pi / 2 else off := 0;
        e := ArcTan2(d2y, d2x) - ArcTan2(d1y, d1x) - off;
        e := e - Pi * Round(e / Pi);
        ws1 := a.S.W[a.I] + b.S.W[b.I];
        ws2 := a2.S.W[a2.I] + b2.S.W[b2.I];
        if ws1 + ws2 < 1e-9 then Exit;
        k1 := ws1 / (ws1 + ws2);
        RotateSeg(a, b, e * k1);
        RotateSeg(a2, b2, -e * (1 - k1));
        Note(Abs(e) * 50);
      end;
    ckEqual:
      begin
        if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
        d1x := b.S.P[b.I].x - a.S.P[a.I].x;
        d1y := b.S.P[b.I].y - a.S.P[a.I].y;
        d2x := b2.S.P[b2.I].x - a2.S.P[a2.I].x;
        d2y := b2.S.P[b2.I].y - a2.S.P[a2.I].y;
        l1 := Hypot(d1x, d1y);
        l2 := Hypot(d2x, d2y);
        ws1 := a.S.W[a.I] + b.S.W[b.I];
        ws2 := a2.S.W[a2.I] + b2.S.W[b2.I];
        if ws1 + ws2 < 1e-9 then Exit;
        tgt := (l1 * ws2 + l2 * ws1) / (ws1 + ws2);
        if l1 > 1e-9 then Shift2(a, b, d1x / l1 * (tgt - l1), d1y / l1 * (tgt - l1))
        else Shift2(a, b, tgt, 0);
        if l2 > 1e-9 then Shift2(a2, b2, d2x / l2 * (tgt - l2), d2y / l2 * (tgt - l2))
        else Shift2(a2, b2, tgt, 0);
      end;
    ckCoaxial:
      for i := 1 to High(c.Refs) do
      begin
        if CoincideVirtual(c.Refs[i - 1], c.Refs[i]) then Continue;
        if MovablePoint(c.Refs[i - 1], a, pa0) and MovablePoint(c.Refs[i], b, pb0) then
          Shift2(a, b, -(pb0.x - pa0.x), -(pb0.y - pa0.y));
      end;
    ckCoradial:
      for i := 1 to High(c.Refs) do
      begin
        s1 := EllOf(c.Refs[0]);
        s2 := EllOf(c.Refs[i]);
        if (s1 = nil) or (s2 = nil) or (s1 = s2) then Continue;
        ShiftR(s1, s2, False);
        if not (s1.Circ or s2.Circ) then ShiftR(s1, s2, True);
      end;
    ckMidPoint: SolveMid(c);
    ckIntersection:
      begin
        k := -1;
        for i := 0 to High(c.Refs) do
          if not SegOf(c.Refs[i], a, b) and MovablePoint(c.Refs[i], p, pa0) then k := i;
        if k < 0 then Exit;
        MovablePoint(c.Refs[k], p, pa0);
        for i := 0 to High(c.Refs) do
          if (i <> k) and SegOf(c.Refs[i], a, b) then
          begin
            if not PointOf(c.Refs[k], a2) then
            begin
              VirtualOnLine(c.Refs[k], c.Refs[i]);
              Continue;
            end;
            // offset of the point from the stored point that moves (non zero for an arc end)
            l := Hypot(b.S.P[b.I].x - a.S.P[a.I].x, b.S.P[b.I].y - a.S.P[a.I].y);
            if l < 1e-9 then Continue;
            OnLine([p], [1.0], a, b, -((pa0.x - p.S.P[p.I].x) * (-(b.S.P[b.I].y - a.S.P[a.I].y) / l) +
              (pa0.y - p.S.P[p.I].y) * ((b.S.P[b.I].x - a.S.P[a.I].x) / l)));
          end;
      end;
    ckTangent: SolveTangent(c);
    ckSymmetry: SolveSymmetry(c);
    ckDistance: SolveDistance(c);
    ckAngle: SolveAngle(c);
    ckOnCurve: SolveOnCurve(c);
    ckRadius:
      begin
        s1 := EllOf(c.Refs[0]);
        if (s1 <> nil) and (s1.WR > 0.5) then
        begin
          Note(Abs(s1.RX - c.Value));
          s1.RX := c.Value;
        end
        else if s1 <> nil then
        begin
          // radius shared with a dragged handle: pull gently
          Note(Abs(s1.RX - c.Value));
          s1.RX := s1.RX + (c.Value - s1.RX) * 0.5;
        end;
      end;
  end;
end;

procedure TDoc.PrepareWeights(const drag: array of TRef);
var
  i, j: Integer;
  s: TShape;
  c: TConstraint;
  r: TRef;
  a, b: TPR;

  procedure Pin(const rr: TRef; w: Double; hard: Boolean);
  var
    q, k: Integer;
    sh: TShape;
    pa, pb: TPR;
  begin
    sh := FindShape(rr.Shape);
    if sh = nil then Exit;
    if rr.Idx = -1 then
    begin
      for k := 0 to High(sh.P) do
        if hard then sh.W[k] := 0 else sh.W[k] := Min(sh.W[k], w);
      if hard then sh.WR := 0 else sh.WR := Min(sh.WR, w);
    end
    else if rr.Idx >= SegBase then
    begin
      if SegOf(rr, pa, pb) then
      begin
        if hard then begin pa.S.W[pa.I] := 0; pb.S.W[pb.I] := 0; end
        else begin
          pa.S.W[pa.I] := Min(pa.S.W[pa.I], w);
          pb.S.W[pb.I] := Min(pb.S.W[pb.I], w);
        end;
      end;
    end
    else if rr.Idx >= HandleRX then
    begin
      if hard then sh.WR := 0 else sh.WR := Min(sh.WR, w);
    end
    else if rr.Idx < Length(sh.P) then
    begin
      q := rr.Idx;
      if hard then sh.W[q] := 0 else sh.W[q] := Min(sh.W[q], w);
    end;
  end;

begin
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    SetLength(s.W, Length(s.P));
    for j := 0 to High(s.W) do s.W[j] := 1;
    s.WR := 1;
  end;
  for i := 0 to High(drag) do Pin(drag[i], DragWeight, False);
  // the other end of a dragged line stays where it is, unless the constraints cannot be met without moving it
  for i := 0 to High(drag) do
  begin
    s := FindShape(drag[i].Shape);
    if (s <> nil) and (s.Kind in [skLine, skArrow]) and (drag[i].Idx in [0, 1]) and (Length(s.W) >= 2) then
      s.W[1 - drag[i].Idx] := Min(s.W[1 - drag[i].Idx], NeighborWeight);
  end;
  // the copies (array items, mirrors, offsets) are made from their parents: the solver cannot move
  // them, it moves what is tied to them; they follow their parents after every pass (see Solve)
  FHasDerived := False;
  for i := 0 to Shapes.Count - 1 do
    if (Shapes[i].ArrId > 0) or (Shapes[i].MirSrc > 0) or (Shapes[i].OffSrc > 0) then
    begin
      FHasDerived := True;
      for j := 0 to High(Shapes[i].W) do Shapes[i].W[j] := 0;
      Shapes[i].WR := 0;
    end;
  // the arc / cut of a fillet / chamfer is made by its two lines (UpdateFillets): the solver cannot move it, it moves what is tied to it
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].FA > 0 then
    begin
      for j := 0 to High(Shapes[i].W) do Shapes[i].W[j] := 0;
      Shapes[i].WR := 0;
    end;
  for i := 0 to Cons.Count - 1 do
  begin
    c := Cons[i];
    if c.Kind <> ckFixed then Continue;
    for j := 0 to High(c.Refs) do Pin(c.Refs[j], 0, True);
  end;
end;

procedure TDoc.Normalize;
var
  i: Integer;
  s: TShape;
begin
  for i := 0 to Shapes.Count - 1 do
  begin
    s := Shapes[i];
    if (s.Kind = skRect) and (Length(s.P) = 2) then EnsureRect(s);
    if s.Kind in [skEllipse, skArc] then
    begin
      if s.RX < 0.5 then s.RX := 0.5;
      if s.RY < 0.5 then s.RY := 0.5;
      if s.Circ then s.RY := s.RX;
    end;
  end;
end;

// How far a constraint is from being satisfied (document units; angle quotes are turned into the
// length of the arc they leave open).  Symmetry is not measured.
function TDoc.ConstraintError(c: TConstraint): Double;
var
  a, b, a2, b2, pm: TPR;
  pa, pb, pos: TPt;
  e1, e2: TShape;
  i, k: Integer;
  l1, l2, dx, dy, d1x, d1y, d2x, d2y, t, ux, uy, len, r, cs, sn, dd, v, ang, tgt: Double;
  v0: TPt;
begin
  Result := 0;
  case c.Kind of
    ckHorizontal, ckVertical:
      begin
        if Length(c.Refs) = 1 then
        begin
          if not SegOf(c.Refs[0], a, b) then Exit;
          pa := a.S.P[a.I];
          pb := b.S.P[b.I];
        end
        else if PointOf(c.Refs[0], a) and PointOf(c.Refs[1], b) then
        begin
          pa := a.S.P[a.I];
          pb := b.S.P[b.I];
        end
        else Exit;
        if c.Kind = ckHorizontal then Result := Abs(pb.y - pa.y) else Result := Abs(pb.x - pa.x);
      end;
    ckParallel, ckPerpendicular, ckEqual:
      begin
        if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
        d1x := b.S.P[b.I].x - a.S.P[a.I].x;
        d1y := b.S.P[b.I].y - a.S.P[a.I].y;
        d2x := b2.S.P[b2.I].x - a2.S.P[a2.I].x;
        d2y := b2.S.P[b2.I].y - a2.S.P[a2.I].y;
        l1 := Hypot(d1x, d1y);
        l2 := Hypot(d2x, d2y);
        if c.Kind = ckEqual then Result := Abs(l1 - l2)
        else if (l1 > 1e-9) and (l2 > 1e-9) then
        begin
          if c.Kind = ckParallel then Result := Abs(d1x * d2y - d1y * d2x) / Max(l1, l2)
          else Result := Abs(d1x * d2x + d1y * d2y) / Max(l1, l2);
        end;
      end;
    ckCoaxial:
      for i := 1 to High(c.Refs) do
        if MovablePoint(c.Refs[i - 1], pm, pa) and MovablePoint(c.Refs[i], pm, pb) then
          Result := Max(Result, Hypot(pb.x - pa.x, pb.y - pa.y));
    ckCoradial:
      for i := 1 to High(c.Refs) do
      begin
        e1 := EllOf(c.Refs[0]);
        e2 := EllOf(c.Refs[i]);
        if (e1 = nil) or (e2 = nil) then Continue;
        Result := Max(Result, Abs(e1.RX - e2.RX));
        if not (e1.Circ or e2.Circ) then Result := Max(Result, Abs(e1.RY - e2.RY));
      end;
    ckMidPoint:
      begin
        k := -1;
        for i := 0 to 1 do
          if not SegOf(c.Refs[i], a, b) and MovablePoint(c.Refs[i], pm, pos) then k := i;
        if k < 0 then Exit;
        MovablePoint(c.Refs[k], pm, pos);
        if SegOf(c.Refs[1 - k], a, b) then
          Result := Hypot(pos.x - (a.S.P[a.I].x + b.S.P[b.I].x) / 2, pos.y - (a.S.P[a.I].y + b.S.P[b.I].y) / 2);
      end;
    ckIntersection:
      begin
        k := -1;
        for i := 0 to High(c.Refs) do
          if not SegOf(c.Refs[i], a, b) and MovablePoint(c.Refs[i], pm, pos) then k := i;
        if k < 0 then Exit;
        MovablePoint(c.Refs[k], pm, pos);
        for i := 0 to High(c.Refs) do
          if (i <> k) and SegOf(c.Refs[i], a, b) then
          begin
            len := Hypot(b.S.P[b.I].x - a.S.P[a.I].x, b.S.P[b.I].y - a.S.P[a.I].y);
            if len < 1e-9 then Continue;
            Result := Max(Result, Abs((pos.x - a.S.P[a.I].x) * (-(b.S.P[b.I].y - a.S.P[a.I].y)) +
              (pos.y - a.S.P[a.I].y) * (b.S.P[b.I].x - a.S.P[a.I].x)) / len);
          end;
      end;
    ckOnCurve:
      begin
        e1 := EllOf(c.Refs[1]);
        if (e1 = nil) or not MovablePoint(c.Refs[0], pm, pos) then Exit;
        dx := pos.x - e1.P[0].x;
        dy := pos.y - e1.P[0].y;
        len := Hypot(dx, dy);
        if len < 1e-9 then Exit;
        if e1.Circ then r := e1.RX
        else r := 1 / Sqrt(Sqr(dx / len / Max(e1.RX, 1e-6)) + Sqr(dy / len / Max(e1.RY, 1e-6)));
        Result := Abs(len - r);
      end;
    ckTangent:
      begin
        e1 := nil;
        e2 := nil;
        for i := 0 to 1 do
          if EllOf(c.Refs[i]) <> nil then
            if e1 = nil then e1 := EllOf(c.Refs[i]) else e2 := EllOf(c.Refs[i]);
        if (e1 <> nil) and (e2 = nil) then
        begin
          for i := 0 to 1 do
            if SegOf(c.Refs[i], a, b) then
            begin
              len := Hypot(b.S.P[b.I].x - a.S.P[a.I].x, b.S.P[b.I].y - a.S.P[a.I].y);
              if len < 1e-9 then Exit;
              dd := Abs((e1.P[0].x - a.S.P[a.I].x) * (-(b.S.P[b.I].y - a.S.P[a.I].y)) +
                (e1.P[0].y - a.S.P[a.I].y) * (b.S.P[b.I].x - a.S.P[a.I].x)) / len;
              Result := Abs(dd - e1.RX);
            end;
        end
        else if (e1 <> nil) and (e2 <> nil) then
        begin
          dd := Hypot(e1.P[0].x - e2.P[0].x, e1.P[0].y - e2.P[0].y);
          if Round(c.Aux) = 1 then Result := Abs(dd - Abs(e1.RX - e2.RX))
          else Result := Abs(dd - (e1.RX + e2.RX));
        end;
      end;
    ckDistance:
      begin
        if Length(c.Refs) = 1 then
        begin
          if not SegOf(c.Refs[0], a, b) then Exit;
          pa := a.S.P[a.I];
          pb := b.S.P[b.I];
        end
        else if PointOf(c.Refs[0], a) and PointOf(c.Refs[1], b) then
        begin
          pa := a.S.P[a.I];
          pb := b.S.P[b.I];
        end
        else
        begin
          // point and line
          if PointOf(c.Refs[0], pm) and SegOf(c.Refs[1], a, b) then
          else if PointOf(c.Refs[1], pm) and SegOf(c.Refs[0], a, b) then
          else Exit;
          len := Hypot(b.S.P[b.I].x - a.S.P[a.I].x, b.S.P[b.I].y - a.S.P[a.I].y);
          if len < 1e-9 then Exit;
          dd := ((pm.S.P[pm.I].x - a.S.P[a.I].x) * (-(b.S.P[b.I].y - a.S.P[a.I].y)) +
                (pm.S.P[pm.I].y - a.S.P[a.I].y) * (b.S.P[b.I].x - a.S.P[a.I].x)) / len;
          Result := Abs(dd - c.Aux * c.Value);
          Exit;
        end;
        case c.Axis of
          1: Result := Abs((pb.x - pa.x) - c.Aux * c.Value);
          2: Result := Abs((pb.y - pa.y) - c.Aux * c.Value);
        else
          Result := Abs(Hypot(pb.x - pa.x, pb.y - pa.y) - c.Value);
        end;
      end;
    ckRadius:
      begin
        e1 := EllOf(c.Refs[0]);
        if e1 <> nil then Result := Abs(e1.RX - c.Value);
      end;
    ckAngle:
      begin
        if not (SegOf(c.Refs[0], a, b) and SegOf(c.Refs[1], a2, b2)) then Exit;
        if not QuoteAngle(c, v0, ang, tgt) then Exit;
        l1 := Hypot(b.S.P[b.I].x - a.S.P[a.I].x, b.S.P[b.I].y - a.S.P[a.I].y);
        l2 := Hypot(b2.S.P[b2.I].x - a2.S.P[a2.I].x, b2.S.P[b2.I].y - a2.S.P[a2.I].y);
        v := Abs(tgt);
        Result := Abs(v - c.Value * Pi / 180) * (l1 + l2) / 2;
      end;
  end;
end;

// Solves hard and measures every constraint: False when some cannot all be satisfied together
// (msg then names the worst ones).  The geometry is left in the best compromise found.
function TDoc.CheckConsistency(out msg: string): Boolean;
var
  i, n, j, k, rel: Integer;
  errs: array of Double;
  idx: array of Integer;
  tmp: Integer;
  e: Double;
  w: TConstraint;
  share, dup: Boolean;
begin
  Result := True;
  msg := '';
  if Cons.Count = 0 then Exit;
  Solve([], 600);
  SetLength(errs, Cons.Count);
  SetLength(idx, Cons.Count);
  n := 0;
  for i := 0 to Cons.Count - 1 do
  begin
    e := ConstraintError(Cons[i]);
    if e > 0.05 then
    begin
      errs[n] := e;
      idx[n] := i;
      Inc(n);
    end;
  end;
  if n = 0 then Exit;
  Result := False;
  // worst first
  for i := 0 to n - 2 do
    for j := i + 1 to n - 1 do
      if errs[j] > errs[i] then
      begin
        e := errs[i]; errs[i] := errs[j]; errs[j] := e;
        tmp := idx[i]; idx[i] := idx[j]; idx[j] := tmp;
      end;
  msg := 'These constraints cannot all be satisfied together:';
  for i := 0 to Min(n, 5) - 1 do
    msg := msg + LineEnding + '  ' + ConstraintNames[Cons[idx[i]].Kind] + ' #' + IntToStr(Cons[idx[i]].Id) +
      ' (off by ' + FormatFloat('0.##', errs[i], MFS) + ')';
  if n > 5 then msg := msg + LineEnding + '  ... and ' + IntToStr(n - 5) + ' more';
  // the other constraints on the same objects as the worst one are the likely partners of the conflict
  rel := 0;
  w := Cons[idx[0]];
  for i := 0 to Cons.Count - 1 do
  begin
    if (Cons[i] = w) or (rel >= 4) then Continue;
    share := False;
    for j := 0 to High(Cons[i].Refs) do
      for k := 0 to High(w.Refs) do
        if Cons[i].Refs[j].Shape = w.Refs[k].Shape then share := True;
    if not share then Continue;
    dup := False;
    for j := 0 to Min(n, 5) - 1 do
      if idx[j] = i then dup := True;
    if dup then Continue;
    if rel = 0 then msg := msg + LineEnding + 'Also on the same objects:';
    msg := msg + LineEnding + '  ' + ConstraintNames[Cons[i].Kind] + ' #' + IntToStr(Cons[i].Id);
    if Cons[i].IsQuote then msg := msg + ' = ' + FormatFloat('0.##', Cons[i].Value, MFS);
    Inc(rel);
  end;
end;

// a rectangle keeps four points: the two opposite corners it is made of and the other two, that follow them (so that every
// corner can take constraints)
procedure TDoc.EnsureRect(s: TShape);
begin
  if (s.Kind <> skRect) or (Length(s.P) <> 2) then Exit;
  SetLength(s.P, 4);
  s.P[2] := MakePt(s.P[1].x, s.P[0].y);
  s.P[3] := MakePt(s.P[0].x, s.P[1].y);
end;

// the corners are pulled back to a rectangle: the ones that cannot move count more
procedure TDoc.ProjectRect(s: TShape);
const
  GX: array[0..3] of Integer = (0, 1, 1, 0);     // the corners that share the x of corner 0 or 1
  GY: array[0..3] of Integer = (0, 1, 0, 1);     // ... and the y
var
  om: array[0..3] of Double;
  xi, yi: array[0..1] of Double;
  sx, sy, wx, wy: array[0..1] of Double;
  i, g: Integer;
  e: Double;
begin
  if (Length(s.P) <> 4) or (Length(s.W) <> 4) then Exit;
  for i := 0 to 3 do om[i] := 1 / (s.W[i] + 0.001);
  for g := 0 to 1 do
  begin
    sx[g] := 0; wx[g] := 0; sy[g] := 0; wy[g] := 0;
  end;
  for i := 0 to 3 do
  begin
    sx[GX[i]] := sx[GX[i]] + om[i] * s.P[i].x;
    wx[GX[i]] := wx[GX[i]] + om[i];
    sy[GY[i]] := sy[GY[i]] + om[i] * s.P[i].y;
    wy[GY[i]] := wy[GY[i]] + om[i];
  end;
  for g := 0 to 1 do
  begin
    xi[g] := sx[g] / wx[g];
    yi[g] := sy[g] / wy[g];
  end;
  for i := 0 to 3 do
  begin
    e := (xi[GX[i]] - s.P[i].x) * s.W[i];
    s.P[i].x := s.P[i].x + e;
    if Abs(e) > FMove then FMove := Abs(e);
    e := (yi[GY[i]] - s.P[i].y) * s.W[i];
    s.P[i].y := s.P[i].y + e;
    if Abs(e) > FMove then FMove := Abs(e);
  end;
end;

// a regular polygon stays regular: its corners are pulled to the regular polygon that fits them best (the corners that
// cannot move count more); the points that are fixed or dragged are followed by the others
procedure TDoc.ProjectRegular(s: TShape);
var
  n, i: Integer;
  om, ur, ui, zr, zi, sw, sur, sui, szr, szi, syr, syi, ar, ai, br, bi, den, wr, wi, cr, ci, tr, ti, k, ang: Double;
  er, ei, wgt: Double;
begin
  n := Length(s.P);
  if (n < 3) or (Length(s.W) <> n) then Exit;
  sw := 0; sur := 0; sui := 0; szr := 0; szi := 0; syr := 0; syi := 0;
  for i := 0 to n - 1 do
  begin
    om := 1 / (s.W[i] + 0.001);
    ang := 2 * Pi * i / n;
    ur := Cos(ang);
    ui := Sin(ang);
    zr := s.P[i].x;
    zi := s.P[i].y;
    sw := sw + om;
    sur := sur + om * ur;
    sui := sui + om * ui;
    szr := szr + om * zr;
    szi := szi + om * zi;
    // z * conj(u)
    syr := syr + om * (zr * ur + zi * ui);
    syi := syi + om * (zi * ur - zr * ui);
  end;
  // w = (Y - Z conj(U) / W) / (W - |U|^2 / W)
  ar := szr * sur + szi * sui;            // Z * conj(U)
  ai := szi * sur - szr * sui;
  den := sw - (sur * sur + sui * sui) / sw;
  if den < 1e-12 then Exit;
  wr := (syr - ar / sw) / den;
  wi := (syi - ai / sw) / den;
  // c = (Z - w U) / W
  br := wr * sur - wi * sui;
  bi := wr * sui + wi * sur;
  cr := (szr - br) / sw;
  ci := (szi - bi) / sw;
  for i := 0 to n - 1 do
  begin
    ang := 2 * Pi * i / n;
    ur := Cos(ang);
    ui := Sin(ang);
    tr := cr + wr * ur - wi * ui;
    ti := ci + wr * ui + wi * ur;
    wgt := s.W[i];
    er := tr - s.P[i].x;
    ei := ti - s.P[i].y;
    s.P[i].x := s.P[i].x + er * wgt;
    s.P[i].y := s.P[i].y + ei * wgt;
    if (Abs(er) + Abs(ei)) * wgt > FMove then FMove := (Abs(er) + Abs(ei)) * wgt;
  end;
end;

procedure TDoc.ProjectRegulars;
var
  i: Integer;
begin
  for i := 0 to Shapes.Count - 1 do
    begin
      if Shapes[i].Reg then ProjectRegular(Shapes[i])
      else if (Shapes[i].Kind = skRect) and (Length(Shapes[i].P) = 4) then ProjectRect(Shapes[i]);
    end;
end;

// ---- the least movement ----
// A drag (or a new constraint) must move as little as the constraints allow: first only what is dragged (and what is the same
// point as it), then also what shares a constraint with it, and only then everything (the old way, with weights).

procedure TDoc.MvClear;
var
  i: Integer;
begin
  SetLength(FMvPt, Shapes.Count);
  SetLength(FMvR, Shapes.Count);
  SetLength(FSeedPt, Shapes.Count);
  SetLength(FSeedR, Shapes.Count);
  for i := 0 to Shapes.Count - 1 do
  begin
    SetLength(FMvPt[i], 0);
    SetLength(FMvPt[i], Length(Shapes[i].P));
    SetLength(FSeedPt[i], 0);
    SetLength(FSeedPt[i], Length(Shapes[i].P));
    FMvR[i] := False;
    FSeedR[i] := False;
  end;
end;

procedure TDoc.MvMark(const r: TRef; seed: Boolean);
var
  s: TShape;
  si, j: Integer;
  a, b: TPR;

  procedure Pt(i, k: Integer);
  begin
    if (i >= 0) and (k >= 0) and (k < Length(FMvPt[i])) then
    begin
      FMvPt[i][k] := True;
      if seed then FSeedPt[i][k] := True;
    end;
  end;

begin
  s := FindShape(r.Shape);
  if s = nil then Exit;
  si := Shapes.IndexOf(s);
  if si < 0 then Exit;
  if r.Idx = -1 then
  begin
    for j := 0 to High(s.P) do Pt(si, j);
    FMvR[si] := True;
    if seed then FSeedR[si] := True;
  end
  else if r.Idx >= SegBase then
  begin
    if SegOf(r, a, b) then
    begin
      Pt(Shapes.IndexOf(a.S), a.I);
      Pt(Shapes.IndexOf(b.S), b.I);
    end;
  end
  else if r.Idx >= HandleRX then
  begin
    FMvR[si] := True;
    if seed then FSeedR[si] := True;
  end
  else if r.Idx >= 0 then Pt(si, r.Idx)
  else
  begin
    // an end of an arc, a point of an ellipse: its centre and its radius
    Pt(si, 0);
    FMvR[si] := True;
  end;
end;

function TDoc.MvHas(const r: TRef): Boolean;
var
  s: TShape;
  si, j: Integer;
  a, b: TPR;
begin
  Result := False;
  s := FindShape(r.Shape);
  if s = nil then Exit;
  si := Shapes.IndexOf(s);
  if si < 0 then Exit;
  if r.Idx = -1 then
  begin
    for j := 0 to High(FMvPt[si]) do
      if FMvPt[si][j] then Exit(True);
    Result := FMvR[si];
  end
  else if r.Idx >= SegBase then
  begin
    if SegOf(r, a, b) then
      Result := FMvPt[Shapes.IndexOf(a.S)][a.I] or FMvPt[Shapes.IndexOf(b.S)][b.I];
  end
  else if r.Idx >= HandleRX then Result := FMvR[si]
  else if r.Idx >= 0 then Result := (r.Idx < Length(FMvPt[si])) and FMvPt[si][r.Idx]
  else Result := (Length(FMvPt[si]) > 0) and FMvPt[si][0];
end;

// what has to move together with what is marked
procedure TDoc.MvClose(stage: Integer);
var
  again: Boolean;
  i, j, k, si: Integer;
  c: TConstraint;
  touch: Boolean;
  s: TShape;
begin
  repeat
    again := False;
    // the points that are one and the same point
    for i := 0 to Cons.Count - 1 do
    begin
      c := Cons[i];
      touch := False;
      if c.Kind = ckCoaxial then
      begin
        for j := 0 to High(c.Refs) do
          if MvHas(c.Refs[j]) then touch := True;
        if touch then
          for j := 0 to High(c.Refs) do
            if not MvHas(c.Refs[j]) then
            begin
              MvMark(c.Refs[j], False);
              again := True;
            end;
      end
      else if stage >= 2 then
      begin
        for j := 0 to High(c.Refs) do
          if MvHas(c.Refs[j]) then touch := True;
        if touch then
          for j := 0 to High(c.Refs) do
            if not MvHas(c.Refs[j]) then
            begin
              MvMark(c.Refs[j], False);
              again := True;
            end;
      end;
    end;
    // a regular polygon / a rectangle moves as a whole
    for si := 0 to Shapes.Count - 1 do
    begin
      s := Shapes[si];
      if not (s.Reg or ((s.Kind = skRect) and (Length(s.P) = 4))) then Continue;
      touch := False;
      for k := 0 to High(FMvPt[si]) do
        if FMvPt[si][k] then touch := True;
      if touch then
        for k := 0 to High(FMvPt[si]) do
          if not FMvPt[si][k] then
          begin
            FMvPt[si][k] := True;
            again := True;
          end;
    end;
  until not again;
end;

// only what is marked can move (what is fixed or made by a copy cannot anyway)
procedure TDoc.MvWeights;
var
  i, j: Integer;
begin
  for i := 0 to Shapes.Count - 1 do
  begin
    for j := 0 to High(Shapes[i].W) do
      if (j >= Length(FMvPt[i])) or not FMvPt[i][j] then Shapes[i].W[j] := 0
      else if FSeedPt[i][j] and (Length(FSeedPt[i]) > j) and FSeedActive then Shapes[i].W[j] := Min(Shapes[i].W[j], DragWeight);
    if not FMvR[i] then Shapes[i].WR := 0;
  end;
end;

procedure TDoc.RunPasses(iter: Integer);
var
  k, i, j: Integer;
begin
  // with copies the pull of what is tied to them reaches the parents a little at a time: more passes
  if FHasDerived then iter := Max(iter, 400);
  for k := 1 to iter do
  begin
    FMove := 0;
    for i := 0 to Cons.Count - 1 do SolveOne(Cons[i]);
    ProjectRegulars;
    Normalize;
    if FHasDerived then
    begin
      // the copies follow their parents, so that what is tied to them sees where they really are
      UpdateOffsets;
      UpdateMirrors;
      UpdateOffsets;
      UpdateArrays;
      for i := 0 to Shapes.Count - 1 do
        if Length(Shapes[i].W) <> Length(Shapes[i].P) then
        begin
          SetLength(Shapes[i].W, Length(Shapes[i].P));
          for j := 0 to High(Shapes[i].W) do Shapes[i].W[j] := 0;
          Shapes[i].WR := 0;
        end;
    end;
    if FMove < 1e-4 then Break;
  end;
end;

function TDoc.Residual: Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Cons.Count - 1 do Result := Max(Result, ConstraintError(Cons[i]));
end;

procedure SaveGeom(d: TDoc; out g: TGeomSnap);
var
  i: Integer;
begin
  SetLength(g.P, d.Shapes.Count);
  SetLength(g.RX, d.Shapes.Count);
  SetLength(g.RY, d.Shapes.Count);
  SetLength(g.A1, d.Shapes.Count);
  SetLength(g.A2, d.Shapes.Count);
  for i := 0 to d.Shapes.Count - 1 do
  begin
    g.P[i] := Copy(d.Shapes[i].P);
    g.RX[i] := d.Shapes[i].RX;
    g.RY[i] := d.Shapes[i].RY;
    g.A1[i] := d.Shapes[i].A1;
    g.A2[i] := d.Shapes[i].A2;
  end;
end;

procedure LoadGeom(d: TDoc; const g: TGeomSnap);
var
  i: Integer;
begin
  for i := 0 to Min(d.Shapes.Count, Length(g.P)) - 1 do
  begin
    d.Shapes[i].P := Copy(g.P[i]);
    d.Shapes[i].RX := g.RX[i];
    d.Shapes[i].RY := g.RY[i];
    d.Shapes[i].A1 := g.A1[i];
    d.Shapes[i].A2 := g.A2[i];
  end;
end;

function TDoc.SolveMinimal(const drag: array of TRef; iter: Integer): Boolean;
var
  snap, snap1: TGeomSnap;
  stage, i, j, dir, fi, fj: Integer;
  canSlide: Boolean;
  x0, y0, dd: Double;
begin
  Result := False;
  SaveGeom(Self, snap);
  FSeedActive := True;
  for stage := 1 to 2 do
  begin
    MvClear;
    for i := 0 to High(drag) do MvMark(drag[i], True);
    MvClose(stage);
    PrepareWeights([]);
    MvWeights;
    RunPasses(iter);
    if Residual < 0.05 then
    begin
      // not stuck? (a point that cannot go anywhere would only be pulled back: then the others have to move)
      fi := -1;
      fj := -1;
      for i := 0 to High(FSeedPt) do
        for j := 0 to High(FSeedPt[i]) do
          if FSeedPt[i][j] and (fi < 0) then
          begin
            fi := i;
            fj := j;
          end;
      canSlide := True;
      if fi >= 0 then
      begin
        SaveGeom(Self, snap1);
        canSlide := False;
        x0 := Shapes[fi].P[fj].x;
        y0 := Shapes[fi].P[fj].y;
        for dir := 0 to 1 do
        begin
          if canSlide then Break;
          for i := 0 to High(FSeedPt) do
            for j := 0 to High(FSeedPt[i]) do
              if FSeedPt[i][j] then
              begin
                if dir = 0 then Shapes[i].P[j].x := Shapes[i].P[j].x + 1
                else Shapes[i].P[j].y := Shapes[i].P[j].y + 1;
              end;
          RunPasses(Max(10, iter div 2));
          dd := Hypot(Shapes[fi].P[fj].x - x0, Shapes[fi].P[fj].y - y0);
          if dd > 0.3 then canSlide := True;
          LoadGeom(Self, snap1);
        end;
      end;
      if canSlide then Exit(True);
    end;
    LoadGeom(Self, snap);
  end;
end;

procedure TDoc.GeomKeep;
begin
  SaveGeom(Self, FGeomKeep);
end;

procedure TDoc.GeomBack;
begin
  LoadGeom(Self, FGeomKeep);
end;

function TDoc.ConstraintsResidual: Double;
begin
  Result := Residual;
end;

procedure TDoc.Solve(const drag: array of TRef; iter: Integer);
var
  i: Integer;
  anyReg: Boolean;
begin
  anyReg := False;
  for i := 0 to Shapes.Count - 1 do
    if Shapes[i].Reg or ((Shapes[i].Kind = skRect) and (Length(Shapes[i].P) = 4)) then anyReg := True;
  if (Cons.Count = 0) and not anyReg then
  begin
    Normalize;
    Exit;
  end;
  if (Length(drag) > 0) and (Cons.Count > 0) and SolveMinimal(drag, iter) then Exit;
  PrepareWeights(drag);
  RunPasses(iter);
end;

// a constraint has just been added: what it depends on moves (the first thing chosen is the reference), and the rest only if that is
// not enough
procedure TDoc.SolveNew(c: TConstraint);
var
  snap: TGeomSnap;
  stage, i, k: Integer;
  a, b: TPR;
begin
  if c = nil then begin Solve([]); Exit; end;
  SaveGeom(Self, snap);
  for stage := 1 to 2 do
  begin
    MvClear;
    case c.Kind of
      ckHorizontal, ckVertical, ckDistance:
        if Length(c.Refs) = 1 then
        begin
          if SegOf(c.Refs[0], a, b) then MvMark(MakeRef(b.S.Id, b.I), True);
        end
        else if PointOf(c.Refs[1], a) and PointOf(c.Refs[0], b) then MvMark(c.Refs[1], True)
        else MvMark(c.Refs[0], True);
      ckMidPoint, ckIntersection, ckOnCurve:
        for i := 0 to High(c.Refs) do
          if (c.Refs[i].Idx <> -1) or (EllOf(c.Refs[i]) = nil) then
            if not SegOf(c.Refs[i], a, b) and ((c.Refs[i].Idx >= 0) or (c.Refs[i].Idx <= ArcStartIdx)) then
            begin
              MvMark(c.Refs[i], True);
              Break;
            end;
      ckRadius, ckFixed: ;
      ckSymmetry:
        if Length(c.Refs) > 1 then MvMark(c.Refs[1], True);
    else
      for i := 1 to High(c.Refs) do MvMark(c.Refs[i], True);
    end;
    FSeedActive := False;
    MvClose(stage);
    PrepareWeights([]);
    MvWeights;
    RunPasses(80);
    if Residual < 0.05 then Exit;
    LoadGeom(Self, snap);
  end;
  Solve([]);
end;

{ boolean operations }

function ClosedOutline(s: TShape; out o: TOutline): Boolean;
var
  i: Integer;
begin
  SetLength(o, 0);
  Result := False;
  if s.Bucket or not (s.Kind in [skRect, skEllipse, skPolygon, skPath, skSpline]) then Exit;
  o := ShapeOutline(s);
  if Length(o) = 0 then Exit;
  for i := 0 to High(o) do
    if (not o[i].Closed) or (Length(o[i].Pts) < 3) then Exit;
  Result := True;
end;

function BoolEligible(s: TShape): Boolean;
var
  o: TOutline;
begin
  Result := ClosedOutline(s, o);
end;

function InsideOutline(const o: TOutline; x, y: Double): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(o) do
    if PointInPoly(o[i].Pts, x, y) then Result := not Result;
end;

// the point where the segment ab crosses cd: t is the position along ab
function SegCross(ax, ay, bx, by, cx, cy, dx, dy: Double; out t: Double): Boolean;
var
  den, u: Double;
begin
  Result := False;
  t := 0;
  den := (bx - ax) * (dy - cy) - (by - ay) * (dx - cx);
  if Abs(den) < 1e-12 then Exit;
  t := ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / den;
  u := ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / den;
  Result := (t >= 0) and (t <= 1) and (u >= 0) and (u <= 1);
end;

function BoolOverlap(a, b: TShape): Boolean;
var
  oa, ob: TOutline;
  i, j, k, m, n1, n2: Integer;
  t: Double;
begin
  Result := False;
  if (a = b) or not ClosedOutline(a, oa) or not ClosedOutline(b, ob) then Exit;
  for i := 0 to High(oa) do
    for j := 0 to High(ob) do
    begin
      n1 := Length(oa[i].Pts);
      n2 := Length(ob[j].Pts);
      for k := 0 to n1 - 1 do
        for m := 0 to n2 - 1 do
          if SegCross(oa[i].Pts[k].x, oa[i].Pts[k].y, oa[i].Pts[(k + 1) mod n1].x, oa[i].Pts[(k + 1) mod n1].y,
            ob[j].Pts[m].x, ob[j].Pts[m].y, ob[j].Pts[(m + 1) mod n2].x, ob[j].Pts[(m + 1) mod n2].y, t) then Exit(True);
    end;
  // no crossing: one inside the other
  if InsideOutline(ob, oa[0].Pts[0].x, oa[0].Pts[0].y) then Exit(True);
  if InsideOutline(oa, ob[0].Pts[0].x, ob[0].Pts[0].y) then Exit(True);
end;

function BoolCompute(a, b: TShape; op: Integer; out pathData: string; out err: string): Boolean;
const
  Away = 0.05;       // how far from a side the sample points of the faces are
var
  oa, ob: TOutline;
  polys: TFPolyArray;
  seeds: TFPtArray;
  regs: TFRegionArray;
  ex1, ey1, ex2, ey2: array of Double;
  alive, used: array of Boolean;
  ne: Integer;
  loops: array of TFPtArray;

  function Wanted(x, y: Double): Boolean;
  var
    ia, ib: Boolean;
  begin
    ia := InsideOutline(oa, x, y);
    ib := InsideOutline(ob, x, y);
    case op of
      0: Result := ia and ib;
      1: Result := ia or ib;
    else Result := ia and not ib;
    end;
  end;

  procedure AddSeed(x, y: Double);
  begin
    if not Wanted(x, y) then Exit;
    SetLength(seeds, Length(seeds) + 1);
    seeds[High(seeds)].x := x;
    seeds[High(seeds)].y := y;
  end;

  // one sample point on each side of every stretch of the outline between two crossings
  procedure SeedsOf(const own, other: TOutline);
  var
    i, k, m, n, q, c, idx, bi: Integer;
    pos: array of Double;
    t, p1, p2, lo, hi, best, mid, ln, nx, ny, dx, dy, x, y: Double;
    nb: Integer;
    sw: Double;
  begin
    for i := 0 to High(own) do
    begin
      n := Length(own[i].Pts);
      SetLength(pos, 0);
      for k := 0 to n - 1 do
        for m := 0 to High(other) do
          for q := 0 to Length(other[m].Pts) - 1 do
          begin
            nb := Length(other[m].Pts);
            if SegCross(own[i].Pts[k].x, own[i].Pts[k].y, own[i].Pts[(k + 1) mod n].x, own[i].Pts[(k + 1) mod n].y,
              other[m].Pts[q].x, other[m].Pts[q].y, other[m].Pts[(q + 1) mod nb].x, other[m].Pts[(q + 1) mod nb].y, t) then
            begin
              SetLength(pos, Length(pos) + 1);
              pos[High(pos)] := k + t;
            end;
          end;
      // sorted, without repeats
      for k := 1 to High(pos) do
      begin
        t := pos[k];
        m := k - 1;
        while (m >= 0) and (pos[m] > t) do
        begin
          pos[m + 1] := pos[m];
          Dec(m);
        end;
        pos[m + 1] := t;
      end;
      c := 0;
      for k := 0 to High(pos) do
        if (c = 0) or (pos[k] - pos[c - 1] > 1e-7) then
        begin
          pos[c] := pos[k];
          Inc(c);
        end;
      if (c > 1) and (pos[0] + n - pos[c - 1] < 1e-7) then Dec(c);
      SetLength(pos, c);
      if c = 0 then
      begin
        SetLength(pos, 1);
        pos[0] := 0;
        c := 1;
      end;
      for k := 0 to c - 1 do
      begin
        p1 := pos[k];
        if k < c - 1 then p2 := pos[k + 1] else p2 := pos[0] + n;
        if c = 1 then p2 := p1 + n;
        // the longest piece of this stretch
        best := -1;
        mid := p1;
        bi := 0;
        for idx := Floor(p1) to Ceil(p2) - 1 do
        begin
          lo := Max(p1, idx);
          hi := Min(p2, idx + 1);
          if hi <= lo then Continue;
          dx := own[i].Pts[(idx + 1) mod n].x - own[i].Pts[idx mod n].x;
          dy := own[i].Pts[(idx + 1) mod n].y - own[i].Pts[idx mod n].y;
          ln := (hi - lo) * Sqrt(dx * dx + dy * dy);
          if ln > best then
          begin
            best := ln;
            mid := (lo + hi) / 2;
            bi := idx;
          end;
        end;
        if best < 0.2 then Continue;
        dx := own[i].Pts[(bi + 1) mod n].x - own[i].Pts[bi mod n].x;
        dy := own[i].Pts[(bi + 1) mod n].y - own[i].Pts[bi mod n].y;
        ln := Sqrt(dx * dx + dy * dy);
        if ln < 1e-12 then Continue;
        nx := -dy / ln;
        ny := dx / ln;
        sw := mid - bi;
        x := own[i].Pts[bi mod n].x + sw * dx;
        y := own[i].Pts[bi mod n].y + sw * dy;
        AddSeed(x + Away * nx, y + Away * ny);
        AddSeed(x - Away * nx, y - Away * ny);
      end;
    end;
  end;

  function SameP(x1, y1, x2, y2: Double): Boolean;
  begin
    Result := (Abs(x1 - x2) < 1e-6) and (Abs(y1 - y2) < 1e-6);
  end;

  procedure AddEdge(x1, y1, x2, y2: Double);
  var
    i: Integer;
  begin
    if SameP(x1, y1, x2, y2) then Exit;
    for i := 0 to ne - 1 do
      if SameP(ex1[i], ey1[i], x1, y1) and SameP(ex2[i], ey2[i], x2, y2) then Exit;
    SetLength(ex1, ne + 1);
    SetLength(ey1, ne + 1);
    SetLength(ex2, ne + 1);
    SetLength(ey2, ne + 1);
    ex1[ne] := x1;
    ey1[ne] := y1;
    ex2[ne] := x2;
    ey2[ne] := y2;
    Inc(ne);
  end;

var
  i, j, k, n, nl, start, cur, nxt: Integer;
  lp: TFPtArray;
  r: TFRegion;
  got: Boolean;
  area, cr: Double;
  cl: TFPtArray;
begin
  Result := False;
  pathData := '';
  err := '';
  if not ClosedOutline(a, oa) or not ClosedOutline(b, ob) then
  begin
    err := 'The operators need two closed figures.';
    Exit;
  end;
  SetLength(polys, Length(oa) + Length(ob));
  n := 0;
  for i := 0 to High(oa) do
  begin
    polys[n].Id := a.Id;
    polys[n].Closed := True;
    SetLength(polys[n].Pts, Length(oa[i].Pts));
    for k := 0 to High(oa[i].Pts) do
    begin
      polys[n].Pts[k].x := oa[i].Pts[k].x;
      polys[n].Pts[k].y := oa[i].Pts[k].y;
    end;
    Inc(n);
  end;
  for i := 0 to High(ob) do
  begin
    polys[n].Id := b.Id;
    polys[n].Closed := True;
    SetLength(polys[n].Pts, Length(ob[i].Pts));
    for k := 0 to High(ob[i].Pts) do
    begin
      polys[n].Pts[k].x := ob[i].Pts[k].x;
      polys[n].Pts[k].y := ob[i].Pts[k].y;
    end;
    Inc(n);
  end;
  SetLength(seeds, 0);
  SeedsOf(oa, ob);
  SeedsOf(ob, oa);
  if Length(seeds) = 0 then
  begin
    err := 'Nothing is left: the figures do not overlap in a way that gives a result.';
    Exit;
  end;
  FindRegions(polys, seeds, 0.3, regs);
  // the sides of all the wanted faces; a side shared by two of them is inside the result and goes away
  ne := 0;
  got := False;
  for i := 0 to High(regs) do
  begin
    r := regs[i];
    if not r.Ok then Continue;
    got := True;
    for j := 0 to High(r.Loops) do
    begin
      n := Length(r.Loops[j].Pts);
      for k := 0 to n - 1 do
        AddEdge(r.Loops[j].Pts[k].x, r.Loops[j].Pts[k].y, r.Loops[j].Pts[(k + 1) mod n].x, r.Loops[j].Pts[(k + 1) mod n].y);
    end;
  end;
  if not got then
  begin
    err := 'The areas could not be found.';
    Exit;
  end;
  SetLength(alive, ne);
  SetLength(used, ne);
  for i := 0 to ne - 1 do
  begin
    alive[i] := True;
    used[i] := False;
  end;
  for i := 0 to ne - 1 do
    if alive[i] then
      for j := i + 1 to ne - 1 do
        if alive[j] and SameP(ex1[i], ey1[i], ex2[j], ey2[j]) and SameP(ex2[i], ey2[i], ex1[j], ey1[j]) then
        begin
          alive[i] := False;
          alive[j] := False;
          Break;
        end;
  // the sides that are left are chained into loops
  nl := 0;
  SetLength(loops, 0);
  for start := 0 to ne - 1 do
  begin
    if (not alive[start]) or used[start] then Continue;
    SetLength(lp, 0);
    cur := start;
    repeat
      used[cur] := True;
      SetLength(lp, Length(lp) + 1);
      lp[High(lp)].x := ex1[cur];
      lp[High(lp)].y := ey1[cur];
      nxt := -1;
      for j := 0 to ne - 1 do
        if alive[j] and (not used[j]) and SameP(ex1[j], ey1[j], ex2[cur], ey2[cur]) then
        begin
          nxt := j;
          Break;
        end;
      cur := nxt;
    until cur < 0;
    // straight runs lose their middle points
    cl := nil;
    SetLength(cl, 0);
    n := Length(lp);
    for k := 0 to n - 1 do
    begin
      i := (k + n - 1) mod n;
      j := (k + 1) mod n;
      cr := (lp[k].x - lp[i].x) * (lp[j].y - lp[k].y) - (lp[k].y - lp[i].y) * (lp[j].x - lp[k].x);
      if Abs(cr) > 1e-7 * (1 + Abs(lp[k].x - lp[i].x) + Abs(lp[j].x - lp[k].x) + Abs(lp[k].y - lp[i].y) + Abs(lp[j].y - lp[k].y)) then
      begin
        SetLength(cl, Length(cl) + 1);
        cl[High(cl)] := lp[k];
      end;
    end;
    if Length(cl) < 3 then Continue;
    area := PolyArea(cl);
    if Abs(area) < 1e-6 then Continue;
    SetLength(loops, nl + 1);
    loops[nl] := cl;
    Inc(nl);
  end;
  if nl = 0 then
  begin
    err := 'Nothing is left.';
    Exit;
  end;
  for i := 0 to nl - 1 do
  begin
    if pathData <> '' then pathData := pathData + ' ';
    pathData := pathData + PolyToPath(loops[i]);
  end;
  Result := True;
end;


initialization
  MFS := DefaultFormatSettings;
  MFS.DecimalSeparator := '.';
  MFS.ThousandSeparator := #0;

end.
