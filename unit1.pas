unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2,mainHelp,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,About,
  Math, Clipbrd, CheckLst, LCLIntf, LCLType, ComCtrls, Buttons, Menus, Types, Spin,
  IniFiles, base64, Printers, PrintersDlgs, IntfGraphics, FPImage, FPReadPNG, TTModel, TTSvg, TTPdf, TTVec, TTFill, TTGlyph, TTSnip, TTScript, TTMat, TTGL, GraphType, BGRABitmap, BGRABitmapTypes, libwebp;

type
  TTool = (tlSelect, tlLine, tlArrow, tlPolyline, tlPolygon, tlRect, tlEllipse,
           tlArc, tlSpline, tlText, tlSvgCode, tlRefLine, tlTrim, tlExtend, tlFillet, tlOffset, tlMirror, tlArray, tlScale, tlRotate, tlChamfer, tlBreak, tlVectorize, tlVertex, tlJoin, tlArc3, tlArcCSE, tlBucket, tlPathPoint, tlPen, tlMarker, tlAirbrush, tlRoundRect, tlSnippet, tlWand, tlSelShape, tlSelRect, tlSelEllipse, tlSelFree, tlRefPoint, tlRegPoly, tlClone, tlPicker, tlEraser);
  TSnippet = record
    Name, Svg: string;
    Icon: string;               // PNG file contents; empty: the icon is drawn from the SVG
    BuiltIn: Boolean;
  end;
  TSnippetArray = array of TSnippet;
  TFltDef = record              // a filter of the library
    Name, Script: string;
    BuiltIn: Boolean;
  end;
  TFltDefArray = array of TFltDef;
  TFltCacheItem = record        // what a filter layer made, kept while its input and its values stay the same
    Layer: TLayer;
    Key: QWord;
    Bmp: TBGRABitmap;
    BB: TRect;
  end;
  TFrameMem = record             // where a picture was (box and turn) the last time its selections were looked at
    ImgId: Integer;
    X1, Y1, X2, Y2, Rot: Double;
  end;
  TSelSigMem = record            // what a selection of a picture was like then
    Id: Integer;
    Sig: QWord;
  end;
  TRunCacheItem = record        // a group of objects already drawn with opacity, kept while nothing that shows in it changes
    Key: QWord;
    Bmp: TBGRABitmap;
  end;
  TObjTag = class                // what a node of the tree of objects stands for
  public
    Kind: Integer;               // 0 layer, 1 group, 2 object
    Layer: TLayer;
    Shape: TShape;
    GroupId: Integer;
  end;
  TFastImg = record              // a picture of the drawing, for the fast drawing while something is moved
    Shape: TShape;
    Src: TBGRABitmap;
    Scaled: TBGRABitmap;
    W, H: Integer;
    Key: QWord;                  // the transparent parts it was made with (see HoleKey)
    DataP: Pointer;              // the data of the picture it was made from (a new picture is a new string)
    DataLen: Integer;
  end;
  THoleImg = record              // a picture with the parts that selections make transparent
    Shape: TShape;
    Key: QWord;
    G: TGraphic;
  end;
  // what is remembered about a picture that is being deformed: the original, and how it has been changed since
  TRotImg = record
    Id: Integer;
    OrigData, OrigKey, Cur: string;     // the picture before the first manipulation, and the one that is in the shape now
    OrigKeyOn: Boolean;
    Ow, Oh: Integer;                    // its pixels
    OrigImg: TBGRABitmap;               // the original, decoded once
    PendImg: TBGRABitmap;             // the last result of a skew, shown but not yet written in the shape (it is, at the end of the drag)
    Pending: Boolean;
    Draft: Boolean;                     // what is shown has fewer pixels than the final picture
    Ux, Uy: Double;                     // the size of the picture without the skew
    M: array[0..3] of Double;           // the skew (and what follows from it): m00, m01, m10, m11
    SData, SKey: string;                // the state when the drag began
    SKeyOn: Boolean;
    SP0, SP1: TPt;
    SUx, SUy: Double;
    SM: array[0..3] of Double;
  end;
  TDragMode = (dmNone, dmCreate, dmPoint, dmShape, dmHandle, dmQuote, dmPage, dmBand, dmGroup, dmRotate, dmDeform, dmPix);
  TPointArr = array of TPoint;
  TByteDyn = array of Byte;
  TCovItem = record             // the coverage of a part of a shape, kept from the pass over white for the pass over black
    Shape: TShape;
    Part, K: Integer;
    Z, W: Double;
    BB: TRect;
    Cov: TByteDyn;
  end;
  THandleInfo = record
    Idx: Integer;
    P: TPt;
    Ctl: Boolean;        // control point of a curve of a path
    Anc: Integer;        // then: the Idx of the point it belongs to
  end;
  THandleArray = array of THandleInfo;
  TQuoteHit = record
    C: TConstraint;
    R: TRect;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    ColorDialog1: TColorDialog;
    constSimmetry: TSpeedButton;
    Label6: TLabel;
    MainMenu1: TMainMenu;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    MenuItem18: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    QuotePanel: TPanel;
    constTangent: TSpeedButton;
    constVertical: TSpeedButton;
    constHoritzontal: TSpeedButton;
    Label3: TLabel;
    ColorPanel: TPanel;
    Label4: TLabel;
    Label5: TLabel;
    MenuItem1: TMenuItem;
    PopupMenu1: TPopupMenu;
    constParallel: TSpeedButton;
    ReferencePanel: TPanel;
    referenceLine: TSpeedButton;
    colorButton8: TSpeedButton;
    constCoradial: TSpeedButton;
    colorButton4: TSpeedButton;
    constCoaxial: TSpeedButton;
    colorButton3: TSpeedButton;
    quoteRadial: TSpeedButton;
    quoteLinear: TSpeedButton;
    quoteAngular: TSpeedButton;
    toolText: TSpeedButton;
    constFixed: TSpeedButton;
    colorButton1: TSpeedButton;
    constPerpendicular: TSpeedButton;
    colorButton2: TSpeedButton;
    constEqual: TSpeedButton;
    colorButton7: TSpeedButton;
    toolSpline: TSpeedButton;
    constMidPoint: TSpeedButton;
    colorButton5: TSpeedButton;
    label1: TLabel;
    Label2: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    ToolsPanel: TPanel;
    ActionsPanel: TPanel;
    ArtisticPanel: TPanel;
    LabelArtistic: TLabel;
    toolPen, toolMarker, toolAirbrush: TSpeedButton;
    LabelActions: TLabel;
    PropertiesPanel: TPanel;
    ConstraintsPanel: TPanel;
    ScrollBox1: TScrollBox;
    ScrollBox2: TScrollBox;
    toolLine: TSpeedButton;
    toolPolygon: TSpeedButton;
    toolArrow: TSpeedButton;
    toolEllipse: TSpeedButton;
    toolRect: TSpeedButton;
    toolSelect: TSpeedButton;
    toolTrim, toolExtend, toolFillet, toolOffset, toolMirror, toolArray, toolScale, toolRotate, toolChamfer, toolBreak, toolVectorize, toolVertex, toolJoin: TSpeedButton;
    toolArcMenu: TSpeedButton;
    toolRectMenu: TSpeedButton;
    toolBucket: TSpeedButton;
    toolPathPoint: TSpeedButton;
    ArcMenu: TPopupMenu;
    RectMenu: TPopupMenu;
    ShapeMenu: TPopupMenu;
    toolSVGcode: TSpeedButton;
    toolEllipticalArc: TSpeedButton;
    toolPolyLine: TSpeedButton;
    StatusBar1: TStatusBar;
    constIntersection: TSpeedButton;
    colorButton6: TSpeedButton;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuItem16Click(Sender: TObject);
    procedure MenuHelpSnippets(Sender: TObject);
    procedure MenuHelpFilters(Sender: TObject);
    procedure MenuItem19Click(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseLeave(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
  private
    Doc: TDoc;
    Buf: TBitmap;
    BufZoom: Double;                // the zoom and the corner (in the page) of what the last drawing in Buf was
    BufOx, BufOy: Integer;
    Zoom: Double;
    Tool: TTool;
    FilletFirst: TShape;
    BreakShape: Integer;
    MenuShape: Integer;             // shape the context menu was opened on
    MenuPoint: Integer;             // point of a path the context menu was opened on (-1: none)
    SidePanel, ObjPanel: TPanel;       // the column at the left of the properties: layers, and the tree of the objects
    SideSplit: TSplitter;
    ObjTree: TTreeView;
    ObjSig: string;                   // what the tree was built from
    ObjSeenGroups: TStringList;       // the groups the tree has shown (a named group is collapsed the first time)
    ObjTags: TList;
    ObjSync, ObjClickCheck: Boolean;
    lblObjHide, lblObjLock: TLabel;
    imgObjHide, imgObjLock: TImage;
    ObjForce: Boolean;
    ObjLastSel: Int64;                // signature of the selection the tree shows
    LayersPanel: TPanel;
    clbLayers: TCheckListBox;
    btnLAdd, btnLDel, btnLUp, btnLDown, btnLRen, btnLLock, btnLMerge, btnLMove, btnLRaster, btnLHide: TButton;
    chkHideRefs, chkHideCons: TCheckBox;
    UpdatingLayers: Boolean;
    AlphaOK: Boolean;               // the canvas being painted can be read back: transparency is drawn
    AlphaMask: TBitmap;
    AAMask: TBitmap;                // the mask for smooth edges: AAS times bigger than the canvas
    RasterPdfBmp: TBitmap;          // the page, drawn, when a PDF is exported as a picture
    AAS: Integer;                   // samples per pixel side for smooth edges (1: the edges are not smoothed)
    AlphaW, AlphaH: Integer;
    AlphaX0, AlphaY0: Integer;      // the top left corner of what is drawn, in the canvas of the whole page (the visible part, on screen)
    FreeActive: Boolean;            // a freehand stroke (pen / marker / airbrush) is being drawn
    ArtStyle: array[tlPen..tlAirbrush] of TStyle;   // the style each artistic tool draws with
    SavedDef: TStyle;               // the usual defaults, while an artistic tool is active
    ArtSwapped: Boolean;
    DefSprayR, DefSprayDot, DefSprayDens: Double;
    seSprayR, seSprayDot, seSprayDens: TFloatSpinEdit;
    cbFont: TComboBox;
    btnReseed: TButton;
    PathPoints: Integer;            // points asked for the last conversion to a path
    DragGrp: Integer;               // handle of the group box being dragged: 0 top left, then clockwise
    GrpAng: Double;                 // the angle of the group being resized (its frame)
    GrpAx, GrpAy: Double;           // the corner / side that stays where it is
    GrpIds: TIntArray;
    Snippets: TSnippetArray;        // the SVG library: built-in ones first, then the user's
    SnipPanel: TPanel;
    btnGroup, btnUngroup, btnMerge, btnFlip, btnMirror, btnInvSel: TSpeedButton;
    FrameMem: array of TFrameMem;
    SelSigMem: array of TSelSigMem;
    OperatorPanel: TPanel;
    btnOp: array[0..2] of TSpeedButton;
    Centered: TList;         // the dialogs already put at the centre of the window
    SnipTimer: TTimer;               // the parameters of a snippet are applied a moment after the last change
    SnipUiKey: string;               // which snippet the parameter controls were made for
    SnipPrm: TSnipParams;
    SnipSpins: array of TFloatSpinEdit;
    SnipMemos: array of TMemo;       // the tables (text parameters) of the snippet shown in the properties
    SnipTracks: array of TTrackBar;
    SnipColors: array of TColorButton;
    SnipSync: Boolean;
    miGroup, miUngroup, miFilters, miMerge: TMenuItem;
    btnLFilter: TButton;
    FltLib: TFltDefArray;           // the library of filters: built-in ones first, then the user's
    FltPanel: TPanel;               // replaces the colours while a filter layer is the active one
    FltBox: TScrollBox;
    FltButtons: array of TSpeedButton;
    FltCache: array of TFltCacheItem;
    RunCache: array of TRunCacheItem;
    CovList: array of TCovItem;
    CovOn: Boolean;
    FastImgs: array of TFastImg;
    SelHaloPre: Boolean;             // the halos of what is selected are drawn first, under all the objects: the objects do not draw them
    FastHaloOnly: Boolean;           // FastShape draws only the halo of the selected shape
    FastMode: Boolean;               // something is being dragged, turned or resized: the picture is made with less quality, faster
    SoftW: Double;                   // width of the stroke while a band of a soft stroke is measured (0: its own)
    DefSoft: Integer;                // soft edges of the next markers
    seSoft: TSpinEdit;
    CovStamp, CovCur: QWord;
    CovBytes: Int64;
    FltScripts: TStringList;        // compiled scripts, by their text
    miFltParams, miFltClear, miFltApply: TMenuItem;
    NudgeHeld: Boolean;
    NudgeUndoCount: Integer;
    NudgeTick: QWord;
    FltPrevLayer: TLayer;
    FltPrevScript: string;
    FltPrevSel: Boolean;
    FltPrevTargets: TShapeArray;
    FltPrevData, FltPrevKey: array of string;
    FltPrevKeyOn: array of Boolean;
    SnipBox: TScrollBox;
    SnipButtons: array of TSpeedButton;
    SnipIdx: Integer;               // the snippet being inserted
    SnipStage: Integer;             // 0: waiting for the position, 1: for the opposite corner
    SnipP0: TPt;
    SnipW: Double;
    SnipCur: TPt;
    RectMode: TTool;                // tlRect or tlRoundRect: what the rectangle button does
    DefSides: Integer;              // sides of the next regular shape
    RegCenter: TPt;                 // centre of the regular shape being drawn
    seSides: TSpinEdit;
    CropActive: Boolean;            // the borders of a picture are being moved to crop it
    CropId: Integer;
    CropX1, CropY1, CropX2, CropY2: Double;     // the frame that is kept
    CropLX1, CropLY1, CropLX2, CropLY2: Double; // the whole picture: the frame cannot go outside of it
    CropDrag: Integer;              // the edges that are dragged: 1 left, 2 right, 4 top, 8 bottom
    QuickLblThick, QuickLblStyle, QuickLblTol: TLabel;
    QuickResX, QuickResY: TSpinEdit;
    ResTimer: TTimer;
    ResPanel: TPanel;
    ResBusy: Boolean;
    toolLight: TSpeedButton;
    PalMat: Boolean;                // the nine buttons of the panel are materials
    PalUndoMat: Integer;
    ColorsMenuBtn: TSpeedButton;
    ColorsMenu: TPopupMenu;
    QuickStrokeMat, QuickFillMat: Integer;
    PalLastBtn: TObject;
    PalLastTick: QWord;
    PalUndoStroke: Integer;
    PalUndoValid, PalUndoDoc: Boolean;
    CloneW, CloneF: Double;         // brush width (document units) and feather (%) of the clone tool
    CloneSrc, CloneOff, CloneCur: TPt;
    CloneHasSrc, CloneHasOff, CloneOn: Boolean;
    CloneImg: TShape;
    CloneLi, CloneSnap: TLazIntfImage;
    CloneKey: Boolean;
    CloneKC, CloneKT: Integer;
    CloneLast: TPt;
    CloneTick: QWord;
    EraseOn: Boolean;
    EraseImg: TShape;
    EraseLi, EraseSnap: TLazIntfImage;
    EraseCov: array of Single;
    EraseMask: TBytes;
    EraseKey: Boolean;
    EraseKC, EraseKT: Integer;
    EraseLast: TPt;
    EraseTick: QWord;
    EraseProt, EraseNone: Boolean;
    EraseP, EraseS: array[0..2] of Integer;
    EraseA: Double;
    EraseTol: Integer;
    seCloneW, seCloneF: TFloatSpinEdit;
    PersActive: Boolean;            // the four corners of a picture are being moved to correct its perspective
    PersId, PersDrag: Integer;
    PersX, PersY: array[0..3] of Double;        // the quadrilateral that becomes the rectangle (top left, top right, bottom right, bottom left)
    PersLX1, PersLY1, PersLX2, PersLY2: Double;
    PersSrcW, PersSrcH: Integer;                 // the picture reduced for the live preview
    PersScale, PersFx, PersFy: Double;           // reduction, and pixels of the full picture per document unit
    PersR, PersG, PersB, PersA: array of Byte;
    SidesTimer: TTimer;
    DefCorner: Double;              // corner radius of the next rounded rectangles
    seCorner: TFloatSpinEdit;
    CornerTimer: TTimer;
    ArcMode: TTool;                 // tlArc, tlArc3 or tlArcCSE: what the arc button does
    Arc2N: Integer;                 // points already clicked for the 3-point / centre arcs
    Arc2Pts: array[0..2] of TPt;
    Arc2Ok: Boolean;
    Arc2Snap: array[0..2] of TRef;   // snap target of each click of the 3-point / centre arcs
    Arc2AIsStart: Boolean;           // 3-point arc: the first end is the start (angle A1)
    SnapAt: TPt;                     // where the last snap put the point
    OldSnap: TPt;
    InBucketCheck: Boolean;
    toolSnapLine: TSpeedButton;
    toolWand, toolSelShape, toolSelRect, toolSelEllipse, toolSelFree, toolRefPoint, toolRegPoly, toolClone, toolPicker, toolEraser: TSpeedButton;
    RasterPanel: TPanel;
    SelStart: TPt;
    SelMode: Integer;               // how the selection that is being made combines with the ones there are: 0 replaces, 1 adds (Shift), 2 subtracts (Shift+Ctrl)
    PixIds: TIntArray;              // the selections whose pixels are going to be dragged
    NewIcons: Boolean;               // the icons are the pictures of the folder "icons" (and the buttons are square); False: the drawn ones
    WinRemember: Boolean;            // the position and size of the window are kept between runs
    FloatId, FloatBase: Integer;
    FloatBox: array[0..3] of Double;   // where the lifted raster was (x1, y1, x2, y2) and its rotation is in FloatRot
    FloatRot: Double;    // the raster of pixels lifted from a selection, and the raster it came from (Enter prints it there)
    PixCopy: Boolean;               // dragging them with Ctrl: the pixels are copied
    ToolImg: Integer;               // the picture the selection tools work on (the one selected when the tool was chosen)
    DefWandTol: Integer;            // tolerance of the magic wand (percent)
    seSelTol: TSpinEdit;
    chkSelHole: TCheckBox;
    SelTimer: TTimer;
    HoleImgs: array of THoleImg;
    ToolHints: array[TTool] of string;
    JoinFirst: Integer;
    JoinRef: TRef;               // the first point chosen by Join (Shape = 0: none yet)
    AngPrev: TConstraint;   // angular quote being placed (preview, not yet in the document)
    BreakPoly: Integer;
    BreakU: Double;
    FilletPt: TPt;
    FilletRadius: Double;
    OffsetFirst: TShape;
    OffsetDist: Double;
    seOff: TFloatSpinEdit;
    MirrorSrc: array of Integer;
    btnDetach: TButton;
    ZoomBar: TTrackBar;
    BottomPanel, ZoomPanel: TPanel;
    QuickPanel: TPanel;           // frequent functions, above the status bar
    QuickSample: TPaintBox;       // thickness: a sample of the stroke, it follows the Thickness of the Properties
    QuickDrop: TPanel;            // the practical choices, as samples, over the sample
    QuickDropRows: array[0..4] of TPaintBox;
    QuickW: Double;
    QuickPasteBox: TPaintBox;             // switch: pasted rasters opaque, or with the secondary colour transparent
    QuickPasteTransp: Boolean;
    QuickTol: TSpinEdit;                  // tolerance (percent) of the magic wand and of the transparent colour of the pasted pictures
    QuickBusy: Boolean;
    QuickStrokeTr, QuickFillTr: Integer;
    QuickStroke, QuickFill: Integer;      // the colours of the Properties (or of the next figures)
    QuickColors: TPaintBox;               // stroke colour in front, fill colour behind it
    QuickSwapBox: TPaintBox;              // swaps the two colours
    QuickDash: Integer;                   // line style of the Properties
    QuickDashSample: TPaintBox;
    QuickDashDrop: TPanel;
    QuickDashRows: array[0..3] of TPaintBox;
    ZoomSync: Boolean;
    ZoomTimer, ZoomSettle: TTimer;   // the turns of the wheel are added up and applied together; then the picture is made again with smooth edges
    ZoomPending: Double;             // the factor of the turns of the wheel not yet applied
    ZoomPt: TPoint;                  // where the mouse was (screen)
    ZoomAnim: TTimer;                // the zoom moves smoothly towards ZoomGoal (a step every few milliseconds)
    ZoomGoal: Double;                // the zoom that the wheel has asked for
    ZoomAnimOn: Boolean;
    ZoomLastTick: QWord;
    ZoomGL: TZoomGL;                 // the zoom on the graphics card (nil: not tried yet)
    ZoomGLState: Integer;            // 0 not tried, 1 works, 2 not available (the old zoom is used)
    GLShown: Double;                 // the zoom that the card shows
    GLPx, GLPy: Double;              // the point of the page that stays under the mouse ...
    GLVx, GLVy: Integer;             // ... and where, in the visible area
    ZoomHold: Boolean;               // the zoom is changing and the scroll position is not final: nothing is drawn yet
    ZoomFast: Boolean;               // the zoom has just changed: the drawing is made without smoothing (faster)
    ZoomAnchor: record X, Y: Double; VX, VY: Integer; end;   // the point kept under the mouse while zooming
    PrintDlg: TPrintDialog;
    ChamD1, ChamD2: Double;
    RotAngle: Double;
    RotCopy: Boolean;
    ScaleK: Double;
    ScaleCopy: Boolean;
    ArrPolar: Boolean;
    ArrCount: Integer;
    ArrTotal: Double;
    lblA: array[1..4] of TLabel;
    seA: array[1..4] of TFloatSpinEdit;
    Drag: TDragMode;
    RotMode: Boolean;               // the handles that resize, turn and skew the selection (a vector selection starts with them; double click on a handle goes to the ones of its points and back)
    PointEdit: Boolean;             // the user has asked for the handles of the points of the selection (PointEditSig says which selection)
    PointEditSig: QWord;
    RotPickOn: Boolean;             // a click inside the box fell on another object: if the pointer does not move, that object is selected
    RotPickRef: TRef;
    SelEditId: Integer;             // the selection of pixels whose outline is being edited by hand (its points are shown)
    RotIds: TIntArray;
    RotImgs: array of TRotImg;      // the pictures of the selection as they were before they were manipulated (skews start from them)
    RotCX, RotCY, RotHW, RotHH: Double;   // the centre and the half sizes of the box when the mode began
    RotTotal, RotAng0, RotBase: Double;   // the angle turned so far, and at the start of this drag
    RotDrag: Integer;                     // the handle being dragged to stretch (corners) or skew (sides)
    RotAx, RotAy, RotHx, RotHy: Double;   // in the frame of the box: the fixed side / corner and the handle when the drag began
    RotSx, RotSy, RotKx, RotKy: Double;   // the stretch and the skew applied so far in this drag
    Sel: TRefArray;
    SelQuote: TConstraint;
    HoverRef: TRef;
    HoverShape: TShape;
    HoverQuote: TConstraint;
    HighlightCons: TConstraint;
    Creating: TShape;
    ArcStage: Integer;
    CreateSnaps: array of TRef;       // per point of Creating: snapped target (Shape=0: none)
    DragRef: TRef;
    DragPageEdge: Integer;
    LastX, LastY, DownX, DownY: Double;
    FreeX, FreeY: Double;      // where the dragged point would be without Shift (straightening)
    FreeOn: Boolean;
    SnapTarget: TRef;
    HasSnap: Boolean;
    Moved: Boolean;
    EdgeOX, EdgeOY: Double;   // how far the magnetism to the borders of the image has moved a dragged raster
    BandOn: Boolean;
    BandPoints: Boolean;            // the band picks control points (Shift, with a polygon / polyline / path selected)
    QuoteHits: array of TQuoteHit;
    DefStyle: TStyle;
    DefCirc: Boolean;
    Palette: array[0..8] of TColor;
    QuickColorMenu: TPopupMenu;
    QuickMenuColor: Integer;
    UndoStack, RedoStack: TStringList;
    Before: string;
    FileName: string;
    Modified: Boolean;
    UpdatingProps: Boolean;
    ToolButtons: array[TTool] of TSpeedButton;
    ConsButtons: array[TConstraintKind] of TSpeedButton;
    // property panel controls
    lblTarget: TLabel;
    btnStroke, btnFill: TSpeedButton;
    chkNoStroke, chkNoFill, chkCirc, chkRef, chkDiam, chkQuotePrint, chkKeepRatio: TCheckBox;
    seImgW, seImgH: TFloatSpinEdit;
    seStrokeOp, seFillOp: TFloatSpinEdit;
    chkBucketLower: TCheckBox;
    cbHatch: TComboBox;
    seHatchSp, seHatchAng, seHatchW: TFloatSpinEdit;
    seBucketOff, seGradOp: TFloatSpinEdit;
    chkGrad: TCheckBox;
    cbGradType, cbRendering: TComboBox;
    btnGradColor: TSpeedButton;
    btnGradPick, btnGradStops: TButton;
    GradPickId: Integer;            // the shape whose gradient reference is being picked (0: not picking)
    btnHatchColor: TSpeedButton;
    seWidth, seFont, seQuote: TFloatSpinEdit;
    cbCap, cbJoin, cbDash, cbAxis: TComboBox;
    edText, edQuoteUnit: TEdit;
    lbCons: TListBox;
    btnDelCons, btnUntrim: TButton;
    Rows: array[0..57] of TPanel;
    // the properties of the active layer (shown by the arrow tool when nothing is selected)
    seLPOp, seLPScale: TFloatSpinEdit;
    btnLPBg: TSpeedButton;
    chkLPNoBg: TCheckBox;
    chkKey: TCheckBox;               // a picture: one colour is transparent
    btnKey: TSpeedButton;            // that colour
    seRot: TFloatSpinEdit;          // rotation of the selected group / turnable shape, in degrees
    RotTimer: TTimer;
    PasteCount: Integer;
    PixClip, PixMarker: string;      // pixels of a raster copied with a selection (PNG, base64) and the text that stands for them in the clipboard
    PixCX, PixCY, PixHW, PixHH, PixRot: Double;
    PixSerial: Integer;
    SaveDlg: TSaveDialog;
    OpenDlg: TOpenDialog;
    procedure BuildToolButtons;
    procedure BuildProps;
    procedure BuildMenus;
    function AddRow(idx, h: Integer; const cap: string): TPanel;
    procedure UpdateHover(X, Y: Integer);
    procedure ArcClick(px, py: Double);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SetSwatch(btn: TSpeedButton; col: Integer; tr: Integer = 0);
    procedure SetMatSwatch(btn: TSpeedButton; m: Integer);
    procedure SetPaletteMode(mat: Boolean);
    procedure LightClick(Sender: TObject);
    function MaterialDialog(idx: Integer; allowColour: Boolean = False): Integer;
    function ChooseMaterial: Integer;
    procedure EditColourOrMaterial(isFill: Boolean);
    function LayerHasMaterials(l: TLayer): Boolean;
    procedure PaletteModeClick(Sender: TObject);
    procedure ColorsMenuClick(Sender: TObject);
    function PalColorOf(idx: Integer): Integer;
    function PalMatOf(idx: Integer): Integer;
    function MakeToolIcon(t: TTool): TBitmap;
    procedure ToolClick(Sender: TObject);
    function ConsRefsFor(k: TConstraintKind; out refs: TRefArray): Boolean;
    function ConsUsable(k: TConstraintKind): Boolean;
    function FilletPair(out a, b: TShape; out ax, ay, bx, by: Double): Boolean;
    function FilletCorner(out sh: TShape; out v: Integer): Boolean;
    procedure FilletSelected(chamfer: Boolean);
    procedure ConstraintClick(Sender: TObject);
    procedure PaletteClick(Sender: TObject);
    procedure PaletteDouble(Sender: TObject);
    procedure PaletteSecondaryMenu(Sender: TObject);
    procedure PaletteSetFill(idx: Integer);
    procedure PaletteColorMenu(Sender: TObject);
    procedure SetTool(t: TTool);
    procedure SetStatus(const s: string);
    procedure UpdateBox;
    procedure Redraw;
    procedure NewDocument;
    // undo
    procedure Checkpoint;
    procedure Commit;
    procedure LoadState(const txt: string);
    procedure DoUndo(Sender: TObject);
    procedure DoRedo(Sender: TObject);
    // selection
    function SelFind(const r: TRef): Integer;
    procedure SelSet(const r: TRef);
    procedure SelToggle(const r: TRef);
    procedure SelClear;
    procedure SelectAll(Sender: TObject);
    procedure InvertSelection(Sender: TObject);
    function SelShapes: TShapeArray;
    function IsSelShape(s: TShape): Boolean;
    function IsActive(s: TShape): Boolean;
    procedure PurgeSelection;
    // hit testing
    function HandlesOf(s: TShape): THandleArray;
    function HitHandle(x, y: Double; out ref: TRef): Boolean;
    function HitShape(x, y: Double; out ref: TRef): Boolean;
    function HitShapeSel(x, y: Double; out ref: TRef): Boolean;
    function HitShapeCore(x, y: Double; out ref: TRef; onlySel: Boolean): Boolean;
    function HitQuote(X, Y: Integer): TConstraint;
    function SnapTo(x, y: Double; exclude: TShape; out ref: TRef; out pt: TPt): Boolean;
    function SnapDerived(x, y: Double; exclude: TShape; tol: Double; out ref: TRef; out pt: TPt): Boolean;
    procedure EnumSnapPoints(exclude: TShape; out refs: TRefArray; out pts: TPtArray);
    procedure DrawSnapMarkers(cnv: TCanvas);
    function Interactive(s: TShape): Boolean;
    procedure DrawSelectedSide(cnv: TCanvas);
    function SideEnds(s: TShape; seg: Integer; out a, b: TPt): Boolean;
    function PageEdgeAt(X, Y: Integer): Integer;
    // rendering
    function ScreenPt(const p: TPt): TPoint;
    procedure ApplyPen(cnv: TCanvas; const st: TStyle; z: Double);
    procedure RenderShape(cnv: TCanvas; s: TShape; z: Double; editView: Boolean);
    procedure RenderShapeCore(cnv: TCanvas; s: TShape; st0: TStyle; z: Double; editView: Boolean; part: Integer);
    function ShapeScreenBox(s: TShape; z: Double): TRect;
    procedure BlendMask(cnv: TCanvas; const bb: TRect; col: TColor; alpha: Integer; const cov: TByteDyn);
    procedure BlendPart(cnv: TCanvas; s: TShape; z: Double; part, tr, k: Integer);
    procedure SetAlphaSize(w, h: Integer; smooth: Boolean);
    function RasterGetter(s: TShape): TGraphic;
    procedure ExportPdfRaster(const fn: string; paperW, paperH, fx, fy, z: Double; dpi: Integer);
    procedure BlendMaskOf(cnv: TCanvas; const bb: TRect; col: TColor; alpha: Integer);
    function PartCoverage(s: TShape; z: Double; part, k: Integer; const bb: TRect): TByteDyn;
    procedure BlendGradient(cnv: TCanvas; s: TShape; z: Double; k: Integer);
    procedure BlendMaterial(cnv: TCanvas; s: TShape; z: Double; part, tr, k: Integer);
    procedure RenderDocBmp(bmp: TBitmap; z: Double; editView: Boolean);
    function DocStamp: QWord;
    function RenderRunCached(const ord: TShapeArray; i0, i1: Integer; w, h: Integer; z: Double; editView, quotes: Boolean; stamp: QWord; ox: Integer = 0; oy: Integer = 0): TBGRABitmap;
    procedure RenderDoc(cnv: TCanvas; z: Double; editView: Boolean);
    procedure ApplyFilterLayer(acc: TBGRABitmap; l: TLayer; z: Double; ox: Integer = 0; oy: Integer = 0);
    function RenderRun(const ord: TShapeArray; i0, i1: Integer; w, h: Integer; z: Double; editView, quotes: Boolean; ox: Integer = 0; oy: Integer = 0): TBGRABitmap;
    function RenderDocRgba(w, h: Integer; z: Double; editView: Boolean; ox: Integer = 0; oy: Integer = 0): TBGRABitmap;
    procedure RenderDocDirect(cnv: TCanvas; z: Double; editView: Boolean);
    procedure DrawHandles(cnv: TCanvas);
    procedure DrawQuote(cnv: TCanvas; c: TConstraint; z: Double; forOutput: Boolean);
    procedure DrawBadges(cnv: TCanvas);
    function QuoteEnds(c: TConstraint; out a, b: TPt): Boolean;
    procedure QuoteDragTo(c: TConstraint; px, py: Double);
    function ImageOf(s: TShape): TGraphic;
    function RawImage(s: TShape): TGraphic;
    function HoleKey(s: TShape): QWord;
    function RgbaOf(raw: TGraphic): TLazIntfImage;
    function PngBase64(li: TLazIntfImage): string;
    procedure FlushImageCaches(s: TShape);
    procedure FlipPicture(s: TShape; vertical: Boolean);
    procedure FlipClick(Sender: TObject);
    procedure RasterizeShapes(const ts: TShapeArray);
    procedure SyncSelFollow;
    function SelSigOf(s: TShape): QWord;
    procedure SelFollowImage(img: TShape; const ids: array of Integer; ox1, oy1, ox2, oy2, orot: Double);
    procedure InvertSelClick(Sender: TObject);
    function InvertSelImage: TShape;
    function FlipApplicable: Boolean;
    procedure ReflectShape(s: TShape; vertical: Boolean; cx, cy: Double);
    procedure FlushAllImageCaches;
    function NewPixelsShape(const data: string; cx, cy, hw, hh, rot: Double; after: TShape): TShape;
    function AllSelections(const ts: TShapeArray): Boolean;
    procedure PixelsOp(op: Integer; const sels: TShapeArray);
    procedure PastePixels;
    function PixelsOnClipboard: Boolean;
    function BucketOnSelection(px, py: Double): Boolean;
    function SelMask(img: TShape; const sels: TShapeArray; w, h: Integer): TBytes;
    function BuildHoleImage(s: TShape; raw: TGraphic): TGraphic;
    function WandRegion(img: TShape; u, v: Double; tolPct: Integer; out loops: TPtLoops): Boolean;
    function MaskLoops(const mask: TBytes; w, h: Integer; img: TShape; out loops: TPtLoops): Boolean;
    procedure SetPathFromLoops(nr: TShape; const lps: TPtLoops);
    procedure WandAt(px, py: Double; Shift: TShiftState);
    procedure SelShapeAt(px, py: Double; Shift: TShiftState);
    procedure RegenWand(sh: TShape);
    procedure SelHoleChanged(Sender: TObject);
    function SelModeOf(Shift: TShiftState): Integer;
    function SelListOf(img: TShape): TShapeArray;
    function SelInsideAt(px, py: Double): TShape;
    procedure SelRegister(s, img: TShape);
    procedure SelCollapse(s, img: TShape);
    procedure SelEditBorders(s: TShape);
    procedure SelMergeInto(s, img: TShape);
    function PixLift(const sels: TShapeArray; copyIt: Boolean): TShape;
    procedure SelToVector(const sels: TShapeArray);
    procedure AppException(Sender: TObject; E: Exception);
    procedure FormCreate2(Sender: TObject);
    procedure StartPixDrag(s: TShape; Shift: TShiftState);
    procedure PixCommit;
    procedure SkewImage(var r: TRotImg; s: TShape; bx, by, kx, ky: Double);
    procedure RotSaveImages(reset: Boolean);
    procedure RotRestoreImages;
    function RotImgFind(id: Integer): Integer;
    procedure RotFlushPending;
    procedure PutFastImg(s: TShape; src: TBGRABitmap);
    function AllRasterShapes(const ts: TShapeArray): Boolean;
    procedure DblLift(sel0: TShape);
    procedure NudgeSelection(Key: Word; big: Boolean);
    procedure PixPrint(fl, base: TShape);
    procedure MergeOverRaster(fl: TShape);
    procedure SelTolChanged(Sender: TObject);
    procedure SelApply(Sender: TObject);
    procedure DrawTurnedImage(cnv: TCanvas; s: TShape; g: TGraphic; z: Double);
    // creation
    function NewShape(k: TShapeKind): TShape;
    procedure CreateDown(px, py: Double; Shift: TShiftState);
    procedure CreateMove(px, py: Double; Shift: TShiftState);
    procedure CreateUp(px, py: Double; Shift: TShiftState);
    procedure SelToolDown(px, py: Double; Shift: TShiftState);
    procedure SelToolMove(px, py: Double; Shift: TShiftState);
    procedure SelToolUp;
    procedure FinishCreating(keep: Boolean);
    procedure CancelCreating;
    procedure AddSnapConstraints(s: TShape);
    procedure AddCoincident(const a, b: TRef);
    // select-tool interaction
    procedure SelectDown(px, py: Double; Shift: TShiftState; X, Y: Integer);
    procedure SelectMove(px, py: Double; Shift: TShiftState);
    procedure DragSolve;
    // properties
    procedure RefreshProps;
    function TargetShapes: TShapeArray;
    procedure StyleChanged(Sender: TObject);
    procedure StrokeClick(Sender: TObject);
    procedure FillClick(Sender: TObject);
    procedure ConsListClick(Sender: TObject);
    procedure DelConsClick(Sender: TObject);
    procedure UntrimClick(Sender: TObject);
    procedure TrimAt(px, py: Double; Shift: TShiftState);
    procedure BreakAt(px, py: Double; Shift: TShiftState);
    procedure AngleAim(px, py: Double);
    procedure VectorizeAt(px, py: Double);
    procedure VertexAt(px, py: Double);
    procedure JoinAt(px, py: Double);
    function NewIconFile(t: TTool): string;
    function LoadIcon(const fn: string; size: Integer): TBGRABitmap;
    procedure ApplyGlyphIcon(b: TSpeedButton; ic0: TBGRABitmap; tint: Boolean = True);
    procedure ApplySnipGlyph(b: TSpeedButton; const sn: TSnippet);
    procedure RelayoutToolButtons;
    procedure RelayoutExtras;
    procedure ApplyGlyph(b: TSpeedButton; t: TTool);
    procedure ExpandGroups;
    function GroupPartBlocked(s: TShape; const what: string): Boolean;
    function SelGroupIds(out ids: TIntArray): Boolean;
    function GroupBox(const ids: TIntArray; out x1, y1, x2, y2: Double): Boolean;
    function HitGroupHandle(px, py: Double): Integer;
    function GroupFrame(const ids: TIntArray; ang: Double; out cx, cy, hw, hh: Double): Boolean;
    function FramePt(i: Integer; cx, cy, hw, hh, ang: Double): TPt;
    function GroupAngle(const ids: TIntArray): Double;
    procedure RotEnter(quiet: Boolean = False);
    procedure AutoRotMode;
    function SelIdSig: QWord;
    function RotEligible(s: TShape): Boolean;
    procedure DrawHoverBox(cnv: TCanvas; s: TShape);
    function RotHandlePt(i: Integer): TPt;
    function RotHandleSide: Integer;
    function RotSpotVisible(const p: TPt): Boolean;
    function RotHit(px, py: Double): Integer;
    procedure DrawRotBox(cnv: TCanvas);
    procedure DrawGroupBox(cnv: TCanvas);
    procedure Ungroup(gid: Integer);
    procedure GroupClick(Sender: TObject);
    function SnipOwner(gid: Integer): TShape;
    function SnipGroupOfSelection: Integer;
    procedure UpdateSnipRow(gid: Integer);
    procedure SnipSpinChange(Sender: TObject);
    procedure SnipMemoChange(Sender: TObject);
    procedure SnipTrackChange(Sender: TObject);
    procedure SnipColorChange(Sender: TObject);
    procedure SnipApply(Sender: TObject);
    procedure UngroupClick(Sender: TObject);
    function MakeGroupIcon(apart: Boolean): TBitmap;
    function MakeMergeIcon: TBitmap;
    function EffectiveRgba(s: TShape): TLazIntfImage;
    procedure MergeRastersClick(Sender: TObject);
    procedure SetClipboardPictureText(const png, txt: string);
    procedure ApplyGlyphBmp(b: TSpeedButton; bmp: TBitmap);
    procedure InitSnippets;
    procedure SaveSnippets(ini: TIniFile);
    procedure RebuildSnipButtons;
    procedure ArrangeSnipButtons;
    procedure SnipBoxResize(Sender: TObject);
    procedure QuickSetWidth(v: Double);
    procedure QuickSamplePaint(Sender: TObject);
    procedure QuickSampleClick(Sender: TObject);
    procedure QuickRowPaint(Sender: TObject);
    procedure QuickRowClick(Sender: TObject);
    procedure QuickDropLeave(Sender: TObject);
    procedure QuickColorsPaint(Sender: TObject);
    procedure QuickColorsDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure QuickSwapPaint(Sender: TObject);
    procedure QuickSwapClick(Sender: TObject);
    procedure QuickPastePaint(Sender: TObject);
    procedure QuickPasteClick(Sender: TObject);
    procedure QuickTolChange(Sender: TObject);
    procedure SetImageKey(s: TShape; on: Boolean; col, tol: Integer);
    function KeyDefaultColor: Integer;
    function SelImages: TShapeArray;
    function QuickPasteShown: Boolean;
    function QuickPasteHint: string;
    procedure KeyChanged(Sender: TObject);
    procedure KeyColorClick(Sender: TObject);
    procedure QuickDashPaint(Sender: TObject);
    procedure QuickDashClick(Sender: TObject);
    procedure QuickDashRowPaint(Sender: TObject);
    procedure QuickDashRowClick(Sender: TObject);
    function SnippetGlyph(const sn: TSnippet; size: Integer): TBitmap;
    procedure MenuSvgLibrary(Sender: TObject);
    procedure SnipButtonClick(Sender: TObject);
    procedure SnippetClick(px, py: Double);
    procedure DrawSnippetPreview(cnv: TCanvas);
    procedure SetRectMode(t: TTool);
    procedure RectMenuClick(Sender: TObject);
    procedure RectMenuButtonClick(Sender: TObject);
    procedure RotPropChanged(Sender: TObject);
    procedure RotPropApply(Sender: TObject);
    function SelRotInfo(out ids: TIntArray; out ang: Double): Boolean;
    procedure CornerChanged(Sender: TObject);
    procedure CornerApply(Sender: TObject);
    procedure SetArcMode(t: TTool);
    procedure ArcMenuClick(Sender: TObject);
    procedure ArcMenuButtonClick(Sender: TObject);
    procedure Arc2Update(px, py: Double);
    procedure Arc2Click(px, py: Double);
    procedure AddSnapConstraint(const pointRef, target: TRef);
    function RejectIfInconsistent: Boolean;
    procedure AddArcEndSnaps(s: TShape);
    procedure BuildSnapButton;
    procedure BuildOperators;
    procedure ActiveFormChanged(Sender: TObject);
    procedure CenterCommonDlg(Sender: TObject);
    procedure OperatorClick(Sender: TObject);
    procedure BucketAt(px, py: Double);
    procedure BuildLayersPanel;
    procedure BuildObjectsPanel;
    procedure RefreshTree;
    procedure SyncTreeSel;
    procedure ObjTreeSelect(Sender: TObject);
    function ObjDropPlace(X, Y: Integer; out target: TShape; out above: Boolean; out lay: TLayer): Boolean;
    procedure ObjTreeDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ObjTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ObjTreeEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure ObjTreeDraw(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
      var PaintImages, DefaultDraw: Boolean);
    procedure ObjTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ObjToggleLock(Data: PtrInt);
    procedure ObjToggleHide(Data: PtrInt);
    procedure ObjPanelResize(Sender: TObject);
    function MakeObjTitleIcon(const fn, tip: string): TImage;
    function ObjNodeHidden(Node: TTreeNode): Boolean;
    function ObjNodeLocked(Node: TTreeNode): Boolean;
    procedure RefreshLayers;
    function ActiveLayerObj: TLayer;
    procedure LayerListClick(Sender: TObject);
    procedure LayerCheck(Sender: TObject);
    procedure LayerAddClick(Sender: TObject);
    procedure LayerAddFilterClick(Sender: TObject);
    procedure InitFilters;
    procedure SaveFilters(ini: TIniFile);
    procedure RebuildFltButtons;
    procedure RebuildFltApplyMenu;
    procedure FltApplyClick(Sender: TObject);
    function FilterTargets(out useSel: Boolean): TShapeArray;
    function ApplyFilterToRaster(img: TShape; const script: string; const vals: TFltValues; useSel: Boolean; feather, featherIn: Double): Boolean;
    procedure ArrangeFltButtons;
    procedure FltBoxResize(Sender: TObject);
    procedure FltButtonClick(Sender: TObject);
    function FilterGlyph(const script: string; size: Integer): TBitmap;
    function ScriptFor(const src: string; out err: string): TFltScript;
    procedure MenuFilterLibrary(Sender: TObject);
    procedure MenuFilterParams(Sender: TObject);
    procedure MenuFilterClear(Sender: TObject);
    function EditFilterValues(l: TLayer; pv: TNotifyEvent = nil): Boolean;
    procedure FltPreviewRaster(Sender: TObject);
    procedure LayerDelClick(Sender: TObject);
    procedure LayerMoveClick(Sender: TObject);
    procedure LayerRenameClick(Sender: TObject);
    procedure CropImage(img: TShape; rx1, ry1, rx2, ry2: Double);
    function CropHit(px, py: Double): Integer;
    procedure CropStart(img: TShape);
    procedure CropFinish(apply: Boolean);
    procedure CropMoveTo(px, py: Double);
    procedure DrawCropBox(cnv: TCanvas);
    procedure ApplyToolRows(hasSel, isQ: Boolean);
    procedure UpdateQuickEnabled;
    procedure DimQuick(pb: TPaintBox);
    procedure PickColorAt(px, py: Double; secondary: Boolean);
    procedure CloneDown(px, py: Double; Shift: TShiftState);
    procedure CloneMove(px, py: Double);
    procedure CloneUp;
    procedure EraseDown(px, py: Double);
    procedure EraseMove(px, py: Double);
    procedure EraseUp;
    procedure EraseView;
    procedure EraseDab(cx, cy: Double);
    procedure CloneDab(cx, cy: Double);
    procedure CloneView;
    procedure CloneChanged(Sender: TObject);
    procedure DrawCloneGuides(cnv: TCanvas);
    procedure DrawEraseGuide(cnv: TCanvas);
    procedure DrawFloatOutline(cnv: TCanvas);
    function PersHit(px, py: Double): Integer;
    function PersInside(px, py: Double): Boolean;
    procedure PersStart(img: TShape);
    procedure PersFinish(apply: Boolean);
    procedure PersApply(img: TShape);
    procedure DrawPersBox(cnv: TCanvas);
    procedure DrawPersPreview(cnv: TCanvas);
    procedure QuickCopyToPalette(Sender: TObject);
    procedure ResChanged(Sender: TObject);
    procedure ResApply(Sender: TObject);
    procedure SnapToggleClick(Sender: TObject);
    procedure SidesChanged(Sender: TObject);
    procedure SidesApply(Sender: TObject);
    procedure LayerLockClick(Sender: TObject);
    procedure LayerHideClick(Sender: TObject);
    procedure LayerMergeClick(Sender: TObject);
    procedure LayerPropChange(Sender: TObject);
    procedure LayerBgClick(Sender: TObject);
    procedure LayerBgNoneChange(Sender: TObject);
    procedure SyncLayerProps;
    function LayerPropsMode: Boolean;
    procedure HideRefsChange(Sender: TObject);
    procedure HideConsChange(Sender: TObject);
    procedure LayerSelToClick(Sender: TObject);
    procedure LayerRasterizeClick(Sender: TObject);
    function BgLayerIdx(s: TShape): Integer;
    procedure DrawLayerBgs(cnv: TCanvas; z: Double; var nextL: Integer; upTo: Integer; under: TColor = clWhite);
    function CanCreateHere: Boolean;
    procedure FreeDown(px, py: Double);
    procedure FreeMove(px, py: Double);
    procedure FreeUp;
    procedure DrawSpray(cnv: TCanvas; s: TShape; z: Double);
    procedure SetRowCaption(idx: Integer; const cap: string);
    procedure SprayChanged(Sender: TObject);
    procedure SoftChanged(Sender: TObject);
    procedure BlendSoftStroke(cnv: TCanvas; s: TShape; z: Double; tr, k: Integer);
    procedure BlendSoftFill(cnv: TCanvas; s: TShape; z: Double; tr, k: Integer);
    function PartCoverageSW(s: TShape; z: Double; part: Integer; const bb: TRect): TByteDyn;
    function Interacting: Boolean;
    function FastRenderOK(pw, ph: Integer): Boolean;
    function HaloPreOK: Boolean;
    procedure DrawSelHalos(cnv: TCanvas; const ord: TShapeArray; i0, i1: Integer; z: Double);
    procedure RenderFast(cnv: TCanvas; pw, ph: Integer);
    procedure FastLayerBgs(fb: TBGRABitmap; var nextL: Integer; upTo, pw, ph: Integer);
    procedure FastShape(fb: TBGRABitmap; s: TShape; z: Double);
    procedure ReseedClick(Sender: TObject);
    procedure PathPointAt(px, py: Double);
    function EditablePointAt(px, py: Double; out shapeId, idx: Integer): Boolean;
    procedure RemovePointClick(Sender: TObject);
    procedure RemoveSelectedPoints(const refs: TRefArray);
    procedure ShowShapeMenu(const ref: TRef);
    procedure TiedWarning(s: TShape);
    procedure ConvertShapeClick(Sender: TObject);
    procedure ConvertTextToShapes(s: TShape; asPath: Boolean);
    procedure CheckBrokenFills;
    procedure DoJoin(a, b: TShape);
    procedure JoinPoints(const a, b: TRef; const target: TPt);
    function Joinable(s: TShape): Boolean;
    procedure UpdateActionStates;
    procedure ImageSizeChanged(Sender: TObject);
    procedure HatchChanged(Sender: TObject);
    procedure BucketOptChanged(Sender: TObject);
    procedure GradChanged(Sender: TObject);
    procedure GradColorClick(Sender: TObject);
    procedure RenderingChanged(Sender: TObject);
    procedure GradStopsClick(Sender: TObject);
    procedure GradPickClick(Sender: TObject);
    procedure GradPick(px, py: Double);
    procedure HatchColorClick(Sender: TObject);
    procedure DrawHatch(cnv: TCanvas; s: TShape; z: Double);
    procedure AngleCancel;
    procedure AnglePlace;
    procedure ExtendAt(px, py: Double; Shift: TShiftState);
    procedure FilletAt(px, py: Double; Shift: TShiftState);
    procedure OffsetAt(px, py: Double);
    procedure OffsetSelected;
    function OffsetTargets: TShapeArray;
    procedure MirrorAt(px, py: Double; Shift: TShiftState);
    procedure DetachClick(Sender: TObject);
    procedure RelayoutProps;
    procedure RotateStart;
    procedure RotateAt(px, py: Double);
    procedure ScaleStart;
    procedure ScaleAt(px, py: Double; snapIt: Boolean = True);
    procedure ArrayStart;
    procedure ArrayAt(px, py: Double);
    procedure ArrayChanged(Sender: TObject);
    procedure OffsetChanged(Sender: TObject);
    procedure QuoteChanged(Sender: TObject);
    procedure EditQuoteValue(c: TConstraint);
    // files / clipboard / menus
    procedure MenuNew(Sender: TObject);
    procedure MenuOpen(Sender: TObject);
    procedure MenuSave(Sender: TObject);
    procedure MenuSaveAs(Sender: TObject);
    procedure MenuConfig(Sender: TObject);
    procedure MenuExit(Sender: TObject);
    procedure MenuPrint(Sender: TObject);
    procedure MenuZoomFit(Sender: TObject);
    procedure ZoomBarChange(Sender: TObject);
    procedure ZoomBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ZoomAt(newZoom: Double; const scrPt: TPoint);
    procedure ZoomAnimTick(Sender: TObject);
    function GLReady: Boolean;
    function GLOrigin(z: Double; out ox, oy: Double): Boolean;
    procedure GLDraw(z: Double);
    procedure GLBegin;
    procedure GLMakePage;
    procedure GLEnd;
    procedure GLStop;
    procedure ZoomAnchorApply(Data: PtrInt);
    procedure ZoomTick(Sender: TObject);
    procedure ZoomSettleTick(Sender: TObject);
    procedure MenuCopy(Sender: TObject);
    procedure MenuCut(Sender: TObject);
    procedure MenuPasteObject(Sender: TObject);
    procedure MenuPasteSmart(Sender: TObject);
    procedure MenuPasteRaster(Sender: TObject);
    procedure PasteKeyAsync(Data: PtrInt);
    function ClipboardPicture: TGraphic;
    function ClipboardText: string;
    function ClipboardData(const mime: string; ms: TStream): Boolean;
    procedure MenuSettings(Sender: TObject);
    procedure ApplyWindowConfig(ini: TIniFile);
    procedure MenuSvgCode(Sender: TObject);
    procedure MenuDelete(Sender: TObject);
    procedure MenuFront(Sender: TObject);
    procedure MenuBack(Sender: TObject);
    procedure MenuZoomIn(Sender: TObject);
    procedure MenuZoomOut(Sender: TObject);
    procedure MenuZoom100(Sender: TObject);
    procedure PaintBoxDblClick(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure PaletteMenuClick(Sender: TObject);
    procedure SaveToFile(const fn: string);
    procedure ExportPng(const fn: string);
    procedure ExportPngAlpha(const fn: string);
    procedure LoadFromFile(const fn: string);
    procedure LoadRasterFile(const fn: string);
    procedure MenuInsertImage(Sender: TObject);
    procedure InsertRasterFile(const fn: string);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    function ConfirmDiscard: Boolean;
    procedure UpdateCaption;
    procedure DeleteSelection;
    procedure AddRasterImage(bmp: TGraphic);
    var DropPos: TPt;           // where the next picture goes (document coordinates), when it comes from a drop
    var DropPlace: Boolean;
    procedure SetZoom(z: Double);
    function ConfigPath: string;
    procedure LoadConfig;
    procedure SaveConfig;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

function ParseNum(const t: string; def: Double): Double; forward;
function PickColor(const cap: string; var col: TColor; var pct: Double; showAlpha: Boolean = True): Boolean; forward;
function SelKey(s: TShape): Integer; forward;
var
  PickMatButton: Boolean = False;     // the colour window has a button to go to the materials
  PickWantMaterial: Boolean = False;  // ... and it was pressed
  PickNoneOption: Boolean = False;    // the colour window has a None box (stroke and fill colours)
  PickNoneInit: Boolean = False;      // ... checked when the window opens
  PickNoneLeft: Integer = 130;
  PickNoneOn: Boolean = False;        // ... and checked when it was closed with OK
function ZoomToPos(z: Double): Integer; forward;
function PosToZoom(p: Integer): Double; forward;

const
  PageMargin = 14;
  HandleSize = 4;
  ColorSel = $FF9A3C;     // BGR: azure
  ColorQuote = $A06E00;
  ConsSymbol: array[TConstraintKind] of string = ('Fix', 'H', 'V', '∥', '⊥', '=',
    '◎', 'R=', 'Mid', '✕', 'Tan', 'Sym', '', '', '', 'On');
  ConsHint: array[TConstraintKind] of string = ('Fixed: locks the selected points/objects',
    'Horizontal', 'Vertical', 'Parallel', 'Perpendicular', 'Equal length',
    'Coaxial / coincident (same center or point)', 'Coradial (same radius)',
    'Mid point', 'Intersection (point on lines)', 'Tangent', 'Symmetry (two items, then the axis)',
    'Linear quote', 'Radial quote', 'Angular quote (select two lines)', 'Point on a circle / ellipse / arc');

{ ================= small helpers ================= }

function ToCol(c: Integer): TColor;
begin
  Result := TColor(c);
end;

function ShowTextDialog(const cap: string; var s: string; readOnly: Boolean; const example: string = ''): Boolean;
var
  f: TForm;
  m, ex: TMemo;
  ok, cancel: TButton;
  p: TPanel;
begin
  f := TForm.CreateNew(Application);
  try
    f.Caption := cap;
    f.Width := 720;
    f.Height := 520;
    f.Position := poMainFormCenter;
    p := TPanel.Create(f);
    p.Parent := f;
    p.Align := alBottom;
    p.Height := 44;
    p.BevelOuter := bvNone;
    if example <> '' then
    begin
      ex := TMemo.Create(f);
      ex.Parent := f;
      ex.Align := alTop;
      ex.Height := 30 + 17 * (Length(example) - Length(StringReplace(example, #10, '', [rfReplaceAll])) + 1);
      ex.ReadOnly := True;
      ex.TabStop := False;
      ex.WordWrap := True;
      ex.Font.Name := 'Monospace';
      ex.ScrollBars := ssAutoVertical;
      ex.Text := example;
    end;
    m := TMemo.Create(f);
    m.Parent := f;
    m.Align := alClient;
    m.ScrollBars := ssBoth;
    m.WordWrap := False;
    m.Font.Name := 'Monospace';
    m.Text := s;
    m.ReadOnly := readOnly;
    cancel := TButton.Create(f);
    cancel.Parent := p;
    cancel.Caption := 'Cancel';
    cancel.ModalResult := mrCancel;
    cancel.Cancel := True;
    cancel.Align := alRight;
    cancel.Width := 90;
    cancel.BorderSpacing.Around := 8;
    ok := TButton.Create(f);
    ok.Parent := p;
    ok.Caption := 'OK';
    ok.ModalResult := mrOk;
    ok.Align := alRight;
    ok.Width := 90;
    ok.BorderSpacing.Around := 8;
    f.ActiveControl := m;
    Result := f.ShowModal = mrOk;
    if Result then s := m.Text;
  finally
    f.Free;
  end;
end;

function Dist(const a, b: TPt): Double;
begin
  Result := Hypot(a.x - b.x, a.y - b.y);
end;

function FmtNum(v: Double): string;
begin
  Result := FormatFloat('0.##', v);
end;

{ ================= form setup ================= }

// an error that nobody handled: where it happened goes to crash.log (next to the configuration), then the usual message
procedure TForm1.AppException(Sender: TObject; E: Exception);
var
  f: TextFile;
  fn: string;
  i: Integer;
begin
  try
    fn := GetAppConfigDir(False) + 'crash.log';
    ForceDirectories(ExtractFilePath(fn));
    AssignFile(f, fn);
    if FileExists(fn) then Append(f) else Rewrite(f);
    try
      WriteLn(f, DateTimeToStr(Now), '  ', E.ClassName, ': ', E.Message);
      WriteLn(f, BackTraceStrFunc(ExceptAddr));
      for i := 0 to ExceptFrameCount - 1 do WriteLn(f, BackTraceStrFunc(ExceptFrames[i]));
      WriteLn(f);
    finally
      CloseFile(f);
    end;
  except
  end;
  Application.ShowException(E);
end;

var
  StartT0: QWord = 0;
  StartLast: QWord = 0;
  StartPainted: Boolean = False;

// start-up timing: with TTP_STARTUP set in the environment, the time of each step goes to /tmp/ttp_start.log (ms since the first
// mark, and since the previous one)
procedure StartMark(const what: string);
var
  f: TextFile;
  t: QWord;
begin
  if GetEnvironmentVariable('TTP_STARTUP') = '' then Exit;
  t := GetTickCount64;
  if StartT0 = 0 then
  begin
    StartT0 := t;
    StartLast := t;
  end;
  AssignFile(f, '/tmp/ttp_start.log');
  if (what = 'FormCreate begins') or not FileExists('/tmp/ttp_start.log') then Rewrite(f) else Append(f);
  WriteLn(f, Format('%6d ms  (+%5d)  %s', [t - StartT0, t - StartLast, what]));
  CloseFile(f);
  StartLast := t;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  StartMark('FormCreate begins');
  Application.OnException := @AppException;
  OnKeyUp := @FormKeyUp;
  AllowDropFiles := True;
  OnDropFiles := @FormDropFiles;
  FormCreate2(Sender);
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN] then NudgeHeld := False;
end;

procedure TForm1.FormCreate2(Sender: TObject);
var
  i, k: Integer;
begin
  Centered := TList.Create;
  Screen.OnActiveFormChange := @ActiveFormChanged;
  Doc := TDoc.Create;
  Doc.Width := 800;
  Doc.Height := 600;
  Zoom := 1;
  Buf := TBitmap.Create;
  UndoStack := TStringList.Create;
  RedoStack := TStringList.Create;
  DefStyle := DefaultStyle;
  ArtStyle[tlPen] := DefaultStyle;
  ArtStyle[tlPen].Width := 2;
  ArtStyle[tlPen].Cap := lcRound;
  ArtStyle[tlPen].Join := ljRound;
  ArtStyle[tlMarker] := DefaultStyle;
  ArtStyle[tlMarker].Width := 14;
  ArtStyle[tlMarker].Stroke := $00FFFF;        // a highlighter: yellow, half transparent
  ArtStyle[tlMarker].StrokeTr := 128;
  ArtStyle[tlMarker].Cap := lcSquare;
  ArtStyle[tlMarker].Join := ljRound;
  ArtStyle[tlAirbrush] := DefaultStyle;
  DefSprayR := 20;
  DefSoft := 0;
  DefWandTol := 5;
  DefSprayDot := 3;
  DefSprayDens := 6;
  DefCirc := False;          // an ellipse; with Shift pressed while drawing: a circle
  Palette[0] := clBlack;
  Palette[1] := TColor($0000E0);
  Palette[2] := TColor($008000);
  Palette[3] := TColor($E00000);
  Palette[4] := TColor($00D7FF);
  Palette[5] := TColor($0080FF);
  Palette[6] := TColor($A000A0);
  Palette[7] := TColor($808080);
  Palette[8] := clWhite;
  StartMark('before LoadConfig');
  NewIcons := DirectoryExists(IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'icons');
  LoadConfig;
  StartMark('LoadConfig');
  InitSnippets;
  StartMark('InitSnippets');
  InitFilters;
  StartMark('InitFilters');
  HoverRef := MakeRef(0, -1);
  SnapTarget := MakeRef(0, -1);
  DragRef := MakeRef(0, -1);
  Tool := tlSelect;
  FilletRadius := 20;
  OffsetDist := 10;
  ArrCount := 3;
  ScaleK := 2;
  RotAngle := 90;
  ChamD1 := 20;
  ChamD2 := 20;
  ArrTotal := 360;
  Drag := dmNone;
  colorDialog1.Color := clYellow;

  ScrollBox1.HorzScrollBar.Visible := True;
  ScrollBox1.VertScrollBar.Visible := True;
  PaintBox1.OnDblClick := @PaintBoxDblClick;
  PaintBox1.ControlStyle := PaintBox1.ControlStyle + [csDoubleClicks];
  OnMouseWheel := @FormMouseWheel;
  OnCloseQuery := @FormCloseQuery;
  StatusBar1.Panels[0].Width := 60;
  StatusBar1.Panels[0].Alignment := taRightJustify;
  StatusBar1.AutoSize := False;
  StatusBar1.Height := 26;
  with StatusBar1.Panels.Add do Width := 130;
  with StatusBar1.Panels.Add do Width := 600;

  // bottom strip: status text on the left, zoom slider on the right
  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := Self;
  BottomPanel.BevelOuter := bvNone;
  BottomPanel.Height := 26 + 32;
  BottomPanel.Align := alBottom;
  StatusBar1.Parent := BottomPanel;
  // panel of the frequent functions, just above the status bar
  QuickPanel := TPanel.Create(Self);
  QuickPanel.Parent := BottomPanel;
  QuickPanel.BevelOuter := bvNone;
  QuickPanel.Height := 32;
  QuickPanel.Align := alTop;
  QuickLblThick := TLabel.Create(Self);
  QuickLblThick.Parent := QuickPanel;
  QuickLblThick.Caption := 'Thickness';
  QuickLblThick.SetBounds(8, 8, 62, 16);
  QuickSample := TPaintBox.Create(Self);
  QuickSample.Parent := QuickPanel;
  QuickSample.SetBounds(76, 3, 120, 26);
  QuickSample.Hint := 'Thickness of the selected figures (or of the next ones): the same as the Thickness of the Properties';
  QuickSample.ShowHint := True;
  QuickSample.OnPaint := @QuickSamplePaint;
  QuickSample.OnClick := @QuickSampleClick;
  QuickDrop := TPanel.Create(Self);
  QuickDrop.Parent := Self;
  QuickDrop.BevelOuter := bvNone;
  QuickDrop.Visible := False;
  QuickDrop.OnMouseLeave := @QuickDropLeave;
  for k := 0 to 4 do
  begin
    QuickDropRows[k] := TPaintBox.Create(Self);
    QuickDropRows[k].Parent := QuickDrop;
    QuickDropRows[k].Tag := k;
    QuickDropRows[k].SetBounds(0, k * 28, 120, 28);
    QuickDropRows[k].OnPaint := @QuickRowPaint;
    QuickDropRows[k].OnClick := @QuickRowClick;
  end;
  QuickDrop.SetBounds(0, 0, 120, 5 * 28);
  QuickW := 4;
  QuickStroke := 0;
  QuickFill := NoColor;
  QuickLblStyle := TLabel.Create(Self);
  QuickLblStyle.Parent := QuickPanel;
  QuickLblStyle.Caption := 'Style';
  QuickLblStyle.SetBounds(212, 8, 36, 16);
  QuickDashSample := TPaintBox.Create(Self);
  QuickDashSample.Parent := QuickPanel;
  QuickDashSample.SetBounds(250, 3, 110, 26);
  QuickDashSample.Hint := 'Line style of the selected figures (or of the next ones)';
  QuickDashSample.ShowHint := True;
  QuickDashSample.OnPaint := @QuickDashPaint;
  QuickDashSample.OnClick := @QuickDashClick;
  QuickDashDrop := TPanel.Create(Self);
  QuickDashDrop.Parent := Self;
  QuickDashDrop.BevelOuter := bvNone;
  QuickDashDrop.Visible := False;
  QuickDashDrop.OnMouseLeave := @QuickDropLeave;
  for k := 0 to 3 do
  begin
    QuickDashRows[k] := TPaintBox.Create(Self);
    QuickDashRows[k].Parent := QuickDashDrop;
    QuickDashRows[k].Tag := k;
    QuickDashRows[k].SetBounds(0, k * 28, 110, 28);
    QuickDashRows[k].OnPaint := @QuickDashRowPaint;
    QuickDashRows[k].OnClick := @QuickDashRowClick;
  end;
  QuickDashDrop.SetBounds(0, 0, 110, 4 * 28);
  QuickColors := TPaintBox.Create(Self);
  QuickColors.Parent := QuickPanel;
  QuickColors.SetBounds(380, 1, 50, 30);
  QuickColors.Hint := 'Stroke colour (in front) and fill colour (behind, the inside of the figures; None by default): click one to change it';
  QuickColors.ShowHint := True;
  QuickColors.OnPaint := @QuickColorsPaint;
  QuickColors.OnMouseDown := @QuickColorsDown;
  QuickSwapBox := TPaintBox.Create(Self);
  QuickSwapBox.Parent := QuickPanel;
  QuickSwapBox.SetBounds(436, 4, 26, 24);
  QuickSwapBox.Hint := 'Swap the stroke colour and the fill colour';
  QuickSwapBox.ShowHint := True;
  QuickSwapBox.OnPaint := @QuickSwapPaint;
  QuickSwapBox.OnClick := @QuickSwapClick;
  QuickPasteBox := TPaintBox.Create(Self);
  QuickPasteBox.Parent := QuickPanel;
  QuickPasteBox.SetBounds(484, 3, 40, 26);
  QuickPasteBox.OnPaint := @QuickPastePaint;
  QuickPasteBox.OnClick := @QuickPasteClick;
  QuickPasteBox.ShowHint := True;
  QuickPasteBox.Hint := 'Pasted pictures: opaque (click to make the secondary colour transparent)';
  QuickLblTol := TLabel.Create(Self);
  QuickLblTol.Parent := QuickPanel;
  QuickLblTol.Caption := 'Tolerance %';
  QuickLblTol.SetBounds(536, 8, 76, 16);
  QuickTol := TSpinEdit.Create(Self);
  QuickTol.Parent := QuickPanel;
  QuickTol.SetBounds(614, 3, 64, 26);
  QuickTol.MinValue := 0;
  QuickTol.MaxValue := 100;
  QuickTol.Increment := 5;
  QuickTol.Value := DefWandTol;
  QuickTol.Hint := 'How different from a colour another colour can be to count as the same: for the magic wand and for the transparent colour of the pasted pictures (0: exactly that colour)';
  QuickTol.ShowHint := True;
  QuickTol.OnChange := @QuickTolChange;
  // the size of the image: at the left of the status bar
  ResPanel := TPanel.Create(Self);
  ResPanel.Parent := BottomPanel;
  ResPanel.BevelOuter := bvNone;
  ResPanel.Width := 180;
  ResPanel.Align := alLeft;
  QuickResX := TSpinEdit.Create(Self);
  QuickResX.Parent := ResPanel;
  QuickResX.SetBounds(4, 1, 74, 24);
  QuickResX.MinValue := 20;
  QuickResX.MaxValue := 20000;
  QuickResX.Increment := 10;
  QuickResX.Value := Doc.Width;
  QuickResX.Hint := 'Width of the image (pixels): also changed by dragging the right border of the page';
  QuickResX.ShowHint := True;
  QuickResX.OnChange := @ResChanged;
  with TLabel.Create(Self) do
  begin
    Parent := ResPanel;
    Caption := 'x';
    SetBounds(82, 5, 10, 16);
  end;
  QuickResY := TSpinEdit.Create(Self);
  QuickResY.Parent := ResPanel;
  QuickResY.SetBounds(96, 1, 74, 24);
  QuickResY.MinValue := 20;
  QuickResY.MaxValue := 20000;
  QuickResY.Increment := 10;
  QuickResY.Value := Doc.Height;
  QuickResY.Hint := 'Height of the image (pixels): also changed by dragging the bottom border of the page';
  QuickResY.ShowHint := True;
  QuickResY.OnChange := @ResChanged;
  ResTimer := TTimer.Create(Self);
  ResTimer.Enabled := False;
  ResTimer.Interval := 600;
  ResTimer.OnTimer := @ResApply;
  StatusBar1.Align := alClient;
  ZoomPanel := TPanel.Create(Self);
  ZoomPanel.Parent := BottomPanel;
  ZoomPanel.BevelOuter := bvNone;
  ZoomPanel.Width := 200;
  ZoomPanel.Align := alRight;
  ZoomBar := TTrackBar.Create(Self);
  ZoomBar.Parent := ZoomPanel;
  ZoomBar.Align := alClient;
  ZoomBar.Min := 0;
  ZoomBar.Max := 100;
  ZoomBar.TickStyle := tsNone;
  ZoomBar.Position := ZoomToPos(1);
  ZoomBar.Hint := 'Zoom (also Ctrl+mouse wheel; double-click = 100%)';
  ZoomBar.ShowHint := True;
  ZoomBar.OnChange := @ZoomBarChange;
  ZoomBar.OnMouseDown := @ZoomBarMouseDown;
  ScrollBox1.OnMouseWheel := @FormMouseWheel;
  PrintDlg := TPrintDialog.Create(Self);

  SaveDlg := TSaveDialog.Create(Self);
  OpenDlg := TOpenDialog.Create(Self);
  SaveDlg.OnShow := @CenterCommonDlg;
  OpenDlg.OnShow := @CenterCommonDlg;
  PrintDlg.OnShow := @CenterCommonDlg;
  ColorDialog1.OnShow := @CenterCommonDlg;

  StartMark('before BuildToolButtons');
  BuildToolButtons;
  StartMark('BuildToolButtons');
  BuildSnapButton;
  StartMark('BuildSnapButton');
  BuildOperators;
  if NewIcons then RelayoutExtras;
  StartMark('BuildOperators');
  BuildProps;
  StartMark('BuildProps');
  BuildLayersPanel;
  StartMark('BuildLayersPanel');
  BuildMenus;
  StartMark('BuildMenus');
  for i := 0 to 8 do
    SetSwatch(TSpeedButton(FindComponent('colorButton' + IntToStr(i + 1))), Palette[i]);

  StartMark('swatches');
  UpdateBox;
  SetTool(tlSelect);
  StartMark('UpdateBox+SetTool');
  NewDocument;
  StartMark('NewDocument');
  // a file given on the command line is opened
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then
  begin
    if Pos(LowerCase(ExtractFileExt(ParamStr(1))), '.png.bmp.jpg.jpeg.webp') > 0 then LoadRasterFile(ParamStr(1))
    else LoadFromFile(ParamStr(1));
  end;
  StartMark('file opened; FormCreate ends');
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveConfig;
  Buf.Free;
  UndoStack.Free;
  RedoStack.Free;
  Creating.Free;
  Doc.Free;
end;

procedure TForm1.SetStatus(const s: string);
begin
  StatusBar1.Panels[2].Text := s;
end;

procedure TForm1.UpdateCaption;
var
  n: string;
begin
  if FileName = '' then n := 'untitled.svg' else n := ExtractFileName(FileName);
  if Modified then n := n + ' *';
  Caption := 'TTPaint - ' + n;
end;

procedure TForm1.UpdateBox;
begin
  PaintBox1.SetBounds(0, 0, Round(Doc.Width * Zoom) + PageMargin, Round(Doc.Height * Zoom) + PageMargin);
  StatusBar1.Panels[0].Text := IntToStr(Round(Zoom * 100)) + '%';
  // the spin edits of the bottom panel show the size too (unless one of them is being typed in)
  if (QuickResX <> nil) and not ResTimer.Enabled then
  begin
    ResBusy := True;
    QuickResX.Value := Doc.Width;
    QuickResY.Value := Doc.Height;
    ResBusy := False;
  end;
end;

procedure TForm1.ResChanged(Sender: TObject);
begin
  if ResBusy then Exit;
  ResTimer.Enabled := False;
  ResTimer.Enabled := True;
end;

// the size typed in the bottom panel is the size of the page
procedure TForm1.ResApply(Sender: TObject);
var
  w, h: Integer;
begin
  ResTimer.Enabled := False;
  w := QuickResX.Value;
  h := QuickResY.Value;
  if (w = Doc.Width) and (h = Doc.Height) then Exit;
  Checkpoint;
  Doc.Width := w;
  Doc.Height := h;
  Commit;
  UpdateBox;
  Redraw;
end;

procedure TForm1.Redraw;
begin
  SyncSelFollow;       // the selections of a picture go where the picture has gone
  PaintBox1.Invalidate;
end;

const
  ZoomMin = 0.1;
  ZoomMax = 8;

function ZoomToPos(z: Double): Integer;
begin
  Result := Round(100 * Ln(z / ZoomMin) / Ln(ZoomMax / ZoomMin));
end;

function PosToZoom(p: Integer): Double;
begin
  Result := ZoomMin * Exp(p / 100 * Ln(ZoomMax / ZoomMin));
end;

procedure TForm1.SetZoom(z: Double);
begin
  Zoom := Max(ZoomMin, Min(ZoomMax, z));
  if (ZoomBar <> nil) and not ZoomSync then
  begin
    ZoomSync := True;
    ZoomBar.Position := ZoomToPos(Zoom);
    ZoomSync := False;
  end;
  UpdateBox;
  Redraw;
end;

procedure TForm1.ZoomAnchorApply(Data: PtrInt);
begin
  ScrollBox1.HorzScrollBar.Position := Max(0, Round(ZoomAnchor.X * Zoom) - ZoomAnchor.VX);
  ScrollBox1.VertScrollBar.Position := Max(0, Round(ZoomAnchor.Y * Zoom) - ZoomAnchor.VY);
end;

procedure TForm1.ZoomTick(Sender: TObject);
var
  f: Double;
begin
  ZoomTimer.Enabled := False;
  f := ZoomPending;
  ZoomPending := 1;
  if f <> 1 then ZoomAt(Zoom * f, ZoomPt);
end;

// one step of the animated zoom: the zoom goes a part of the way to the goal (the same share of the distance each time,
// measured in time, so it is smooth whatever the speed of the computer) and the picture that is on the screen is enlarged or reduced
// the card is tried the first time that the wheel zooms; if it does not work the old zoom is used from then on
function TForm1.GLReady: Boolean;
var
  p: TPoint;
begin
  if ZoomGLState = 0 then
  begin
    ZoomGLState := 2;
    try
      ZoomGL := TZoomGL.Create(ScrollBox1.Parent);
      p := ScrollBox1.ClientToParent(Point(0, 0), ScrollBox1.Parent);
      if ZoomGL.Init(p.x, p.y, ScrollBox1.ClientWidth, ScrollBox1.ClientHeight) then ZoomGLState := 1
      else
      begin
        FreeAndNil(ZoomGL);
      end;
    except
      FreeAndNil(ZoomGL);
      ZoomGLState := 2;
    end;
  end;
  Result := ZoomGLState = 1;
end;

// where the visible area starts in the page picture at the zoom z, so that the anchor stays under the mouse (and the same limits
// as the scroll bars: the real position will be this one)
function TForm1.GLOrigin(z: Double; out ox, oy: Double): Boolean;
var
  mx, my: Double;
begin
  mx := Max(0, Doc.Width * z + PageMargin - ScrollBox1.ClientWidth);
  my := Max(0, Doc.Height * z + PageMargin - ScrollBox1.ClientHeight);
  ox := Max(0, Min(mx, GLPx * z - GLVx));
  oy := Max(0, Min(my, GLPy * z - GLVy));
  Result := True;
end;

procedure TForm1.GLDraw(z: Double);
var
  ox, oy: Double;
begin
  GLOrigin(z, ox, oy);
  ZoomGL.Frame(BufOx * z / BufZoom - ox, BufOy * z / BufZoom - oy,
    (BufOx + Buf.Width) * z / BufZoom - ox, (BufOy + Buf.Height) * z / BufZoom - oy, clBtnFace,
    -ox, -oy, Doc.Width * z - ox, Doc.Height * z - oy);
  GLShown := z;
end;

// a zoom out shows parts of the page that the picture of the screen does not have: the whole page is drawn once, small, as a texture
// that the card puts under the picture (made out of the screen: it does not touch the scroll bars or the zoom)
procedure TForm1.GLMakePage;
var
  bm: TBitmap;
  zz: Double;
  w, h: Integer;
begin
  if (ZoomGL = nil) or ZoomGL.HasPageTexture then Exit;
  zz := Min(Zoom, 2048 / Max(1, Max(Doc.Width, Doc.Height)));
  w := Max(1, Round(Doc.Width * zz));
  h := Max(1, Round(Doc.Height * zz));
  bm := TBitmap.Create;
  try
    bm.SetSize(w, h);
    bm.Canvas.Brush.Color := clWhite;
    bm.Canvas.FillRect(0, 0, w, h);
    RenderDocBmp(bm, zz, True);
    ZoomGL.UploadPage(bm);
  finally
    bm.Free;
  end;
end;

// the animation on the card starts: what is on the screen goes to the card and the card is put over the visible area
procedure TForm1.GLBegin;
var
  p: TPoint;
begin
  p := ScrollBox1.ClientToParent(Point(0, 0), ScrollBox1.Parent);
  ZoomGL.Place(p.x, p.y, ScrollBox1.ClientWidth, ScrollBox1.ClientHeight);
  ZoomGL.Upload(Buf);
  ZoomGL.ForgetPage;
  GLShown := Zoom;
  GLPx := 0;
  GLPy := 0;
  GLVx := -1;
  ZoomGL.Show;
end;

// the animation is over: the real zoom is put at the place that the card showed, and the card goes away
procedure TForm1.GLEnd;
var
  frozen: PGdkWindow;
begin
  ZoomAnimOn := False;
  ZoomAnim.Enabled := False;
  frozen := nil;
  if HandleAllocated then
  begin
    frozen := PGtkWidget(Pointer(Handle))^.window;
    if frozen <> nil then gdk_window_freeze_updates(frozen);
  end;
  ZoomHold := True;
  try
    SetZoom(ZoomGoal);
    ZoomAnchor.X := GLPx;
    ZoomAnchor.Y := GLPy;
    ZoomAnchor.VX := GLVx;
    ZoomAnchor.VY := GLVy;
    ZoomAnchorApply(0);
  finally
    ZoomHold := False;
    ZoomFast := True;
    ZoomSettle.Enabled := False;
    ZoomSettle.Enabled := True;
    PaintBox1.Invalidate;
    if frozen <> nil then gdk_window_thaw_updates(frozen);
  end;
  PaintBox1.Repaint;                 // the stretched picture, under the card (the card goes away when the sharp one is drawn)
end;

procedure TForm1.GLStop;
begin
  if (ZoomGL <> nil) and ZoomGL.Visible then ZoomGL.Hide;
  ZoomAnimOn := False;
  ZoomAnim.Enabled := False;
end;

// one step of the zoom on the card: the zoom goes a part of the way to the goal (the same share of the distance each time, measured
// in time, so it is smooth whatever the speed of the computer)
procedure TForm1.ZoomAnimTick(Sender: TObject);
var
  now_: QWord;
  dt, k, lz, lg: Double;
begin
  if not ZoomAnimOn or (ZoomGL = nil) or not ZoomGL.Visible then
  begin
    ZoomAnim.Enabled := False;
    Exit;
  end;
  now_ := GetTickCount64;
  dt := Min(60, Max(1, now_ - ZoomLastTick));
  ZoomLastTick := now_;
  k := 1 - Exp(-dt / 55);
  lz := Ln(GLShown);
  lg := Ln(ZoomGoal);
  if Abs(lg - lz) < 0.004 then
  begin
    GLDraw(ZoomGoal);
    GLEnd;
  end
  else GLDraw(Exp(lz + (lg - lz) * k));
end;

procedure TForm1.ZoomSettleTick(Sender: TObject);
begin
  ZoomSettle.Enabled := False;
  ZoomFast := False;
  Redraw;
  // the sharp picture is drawn: the card has nothing more to show
  if (ZoomGL <> nil) and ZoomGL.Visible and not ZoomAnimOn then
  begin
    PaintBox1.Repaint;
    ZoomGL.Hide;
  end;
end;

// zoom keeping the document point under scrPt where it is (when it lies over the page area)
procedure TForm1.ZoomAt(newZoom: Double; const scrPt: TPoint);
var
  frozen: PGdkWindow;
  pt, vp: TPoint;
  px, py: Double;
  over: Boolean;
begin
  ZoomFast := True;
  ZoomSettle.Enabled := False;
  ZoomSettle.Enabled := True;
  pt := PaintBox1.ScreenToClient(scrPt);
  vp := ScrollBox1.ScreenToClient(scrPt);
  over := (vp.x >= 0) and (vp.y >= 0) and (vp.x < ScrollBox1.ClientWidth) and (vp.y < ScrollBox1.ClientHeight);
  px := pt.x / Zoom;
  py := pt.y / Zoom;
  // the size of the page and the scroll position change one after the other, and each change would draw the picture: nothing is
  // drawn until the position is the final one (the picture would jump)
  ZoomHold := True;
  // nothing reaches the screen until the size of the page and the scroll position are both final (gdk keeps the exposures back)
  frozen := nil;
  if HandleAllocated then
  begin
    frozen := PGtkWidget(Pointer(Handle))^.window;
    if frozen <> nil then gdk_window_freeze_updates(frozen);
  end;
  try
    SetZoom(newZoom);
    if over then
    begin
      ZoomAnchor.X := px;
      ZoomAnchor.Y := py;
      ZoomAnchor.VX := vp.x;
      ZoomAnchor.VY := vp.y;
      ZoomAnchorApply(0);
    end;
  finally
    ZoomHold := False;
    PaintBox1.Invalidate;
    if frozen <> nil then gdk_window_thaw_updates(frozen);
  end;
  Redraw;
end;

procedure TForm1.ZoomBarChange(Sender: TObject);
var
  c: TPoint;
begin
  if ZoomSync then Exit;
  GLStop;          // the slider wins over the animation of the wheel
  ZoomSync := True;
  try
    // zoom about the center of the visible area
    c := ScrollBox1.ClientToScreen(Point(ScrollBox1.ClientWidth div 2, ScrollBox1.ClientHeight div 2));
    ZoomAt(PosToZoom(ZoomBar.Position), c);
  finally
    ZoomSync := False;
  end;
end;

procedure TForm1.ZoomBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if ssDouble in Shift then SetZoom(1);      // double-click: back to 100%
end;

procedure TForm1.NewDocument;
begin
  FlushAllImageCaches;
  Doc.Clear;
  Doc.Width := 800;
  Doc.Height := 600;
  RefreshLayers;
  SelClear;
  UndoStack.Clear;
  RedoStack.Clear;
  FileName := '';
  Modified := False;
  UpdateBox;
  UpdateCaption;
  RefreshProps;
  Redraw;
end;

{ ================= toolbar ================= }

// a small sample of a material: a round bar seen from the side, lit by the light (what a line of that material looks like)
function MaterialChip(m, w, h: Integer): TBitmap;
var
  x, y, r, g, b, a: Integer;
  sy, nz, bgR, bgG, bgB, f: Double;
  bg: TColor;
begin
  SetLightAngles(217, 60, 0, $FFFFFF);
  if Form1 <> nil then CurMat := Form1.Doc.Mats[m] else CurMat := DefaultMatParams;
  Result := TBitmap.Create;
  Result.SetSize(w, h);
  bg := ColorToRGB(clBtnFace);
  bgR := bg and $FF;
  bgG := (bg shr 8) and $FF;
  bgB := (bg shr 16) and $FF;
  Result.Canvas.Brush.Color := bg;
  Result.Canvas.FillRect(0, 0, w, h);
  for y := 1 to h - 2 do
  begin
    sy := ((y + 0.5) - h / 2) / (h / 2 - 0.5);
    if sy > 0.97 then sy := 0.97;
    if sy < -0.97 then sy := -0.97;
    nz := Sqrt(1 - sy * sy);
    for x := 1 to w - 2 do
    begin
      MaterialShade(m, x * 2.5, y * 2.5, 0, sy, nz, False, 0.5, 0.5, r, g, b, a);
      f := a / 255;
      Result.Canvas.Pixels[x, y] := TColor(Round(r * f + bgR * (1 - f)) or (Round(g * f + bgG * (1 - f)) shl 8) or
        (Round(b * f + bgB * (1 - f)) shl 16));
    end;
  end;
  Result.Canvas.Pen.Color := clGray;
  Result.Canvas.Brush.Style := bsClear;
  Result.Canvas.Rectangle(0, 0, w, h);
end;

procedure TForm1.SetMatSwatch(btn: TSpeedButton; m: Integer);
var
  b: TBitmap;
begin
  b := MaterialChip(m, 26, 16);
  try
    btn.Glyph.Assign(b);
  finally
    b.Free;
  end;
end;

// a colour that is not opaque, over a chequered ground: how much of the ground shows through tells how transparent it is
// (tr: transparency, 0 opaque .. 255 invisible)
procedure PaintTransColor(cnv: TCanvas; const R: TRect; col, tr: Integer);
var
  x, y, cx, cy, a: Integer;
  r0, g0, b0, gnd: Integer;
  rgb: TColor;
  cell: TRect;
begin
  rgb := ColorToRGB(TColor(col));
  r0 := rgb and $FF;
  g0 := (rgb shr 8) and $FF;
  b0 := (rgb shr 16) and $FF;
  a := 255 - Max(0, Min(255, tr));
  cnv.Pen.Style := psClear;
  cnv.Brush.Style := bsSolid;
  y := R.Top;
  cy := 0;
  while y < R.Bottom do
  begin
    x := R.Left;
    cx := 0;
    while x < R.Right do
    begin
      if (cx + cy) mod 2 = 0 then gnd := 255 else gnd := 190;
      cnv.Brush.Color := RGBToColor((r0 * a + gnd * (255 - a)) div 255, (g0 * a + gnd * (255 - a)) div 255,
        (b0 * a + gnd * (255 - a)) div 255);
      cell := Rect(x, y, Min(x + 4, R.Right), Min(y + 4, R.Bottom));
      cnv.FillRect(cell);
      Inc(x, 4);
      Inc(cx);
    end;
    Inc(y, 4);
    Inc(cy);
  end;
  cnv.Pen.Style := psSolid;
  cnv.Pen.Color := clGray;
  cnv.Brush.Style := bsClear;
  cnv.Rectangle(R);
end;

procedure TForm1.SetSwatch(btn: TSpeedButton; col: Integer; tr: Integer);
var
  b: TBitmap;
begin
  b := TBitmap.Create;
  try
    b.SetSize(26, 16);
    b.Canvas.Brush.Color := clWhite;
    b.Canvas.FillRect(0, 0, 26, 16);
    if (col <> NoColor) and (tr > 0) then PaintTransColor(b.Canvas, Rect(0, 0, 26, 16), col, tr)
    else if col <> NoColor then
    begin
      b.Canvas.Brush.Color := TColor(col);
      b.Canvas.Pen.Color := clGray;
      b.Canvas.Rectangle(0, 0, 26, 16);
    end
    else
    begin
      b.Canvas.Pen.Color := clGray;
      b.Canvas.Brush.Style := bsClear;
      b.Canvas.Rectangle(0, 0, 26, 16);
      b.Canvas.Pen.Color := clRed;
      b.Canvas.Line(2, 14, 24, 2);
    end;
    btn.Glyph.Assign(b);
  finally
    b.Free;
  end;
end;

function TForm1.MakeToolIcon(t: TTool): TBitmap;
const
  S = 26;
var
  c: TCanvas;
  pts: array of TPoint;
begin
  Result := TBitmap.Create;
  Result.SetSize(S, 22);
  Result.Transparent := True;
  Result.TransparentColor := clFuchsia;
  c := Result.Canvas;
  c.Brush.Color := clFuchsia;
  c.FillRect(0, 0, S, 22);
  c.Pen.Color := clBlack;
  c.Pen.Width := 2;
  c.Brush.Style := bsClear;
  case t of
    tlSelect:
      begin
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Pen.Width := 1;
        c.Polygon([Point(7, 2), Point(7, 18), Point(11, 14), Point(14, 20), Point(16, 19), Point(13, 13), Point(18, 13)]);
      end;
    tlLine:
      begin
        c.Line(4, 18, 21, 4);
      end;
    tlArrow:
      begin
        c.Line(4, 18, 20, 5);
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Pen.Width := 1;
        c.Polygon([Point(22, 3), Point(14, 5), Point(20, 11)]);
      end;
    tlPolyline:
      c.Polyline([Point(3, 17), Point(9, 5), Point(15, 15), Point(22, 4)]);
    tlPolygon:
      c.Polygon([Point(13, 3), Point(22, 9), Point(19, 19), Point(7, 19), Point(4, 9)]);
    tlRect:
      c.Rectangle(4, 5, 22, 18);
    tlRoundRect:
      c.RoundRect(4, 5, 22, 18, 9, 9);
    tlEllipse:
      c.Ellipse(3, 4, 23, 19);
    tlArc:
      c.Arc(3, 3, 23, 25, 22, 14, 4, 14);
    tlPen:
      begin
        c.Pen.Width := 2;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Polygon([Point(3, 20), Point(5, 13), Point(17, 2), Point(22, 7), Point(11, 18)]);
        c.Pen.Width := 1;
        c.Line(5, 13, 10, 18);
        c.Line(3, 20, 6, 17);
      end;
    tlMarker:
      begin
        c.Pen.Width := 1;
        c.Brush.Style := bsSolid;
        c.Brush.Color := TColor($40D0FF);
        c.Polygon([Point(4, 19), Point(4, 13), Point(15, 2), Point(23, 10), Point(12, 20)]);
        c.Brush.Color := clWhite;
        c.Polygon([Point(15, 2), Point(23, 10), Point(25, 8), Point(17, 0)]);
        c.Brush.Color := clBlack;
        c.Rectangle(2, 19, 9, 22);
      end;
    tlAirbrush:
      begin
        c.Pen.Width := 1;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Polygon([Point(2, 19), Point(5, 11), Point(11, 14)]);
        c.Rectangle(10, 3, 14, 12);
        c.Rectangle(15, 6, 17, 8);
        c.Rectangle(19, 4, 21, 6);
        c.Rectangle(18, 10, 20, 12);
        c.Rectangle(22, 8, 24, 10);
        c.Rectangle(15, 13, 17, 15);
        c.Rectangle(21, 14, 23, 16);
        c.Rectangle(18, 17, 20, 19);
      end;
    tlWand:
      begin
        // a wand with sparks
        c.Pen.Width := 3;
        c.Line(3, 20, 15, 8);
        c.Pen.Width := 1;
        c.Pen.Color := TColor($0090FF);
        c.Line(18, 2, 18, 8);
        c.Line(15, 5, 21, 5);
        c.Line(22, 9, 22, 13);
        c.Line(20, 11, 24, 11);
        c.Line(12, 2, 12, 5);
        c.Line(10, 3, 14, 3);
      end;
    tlPicker:
      begin
        // an eyedropper: a slanted tube with a bulb on top and a tip
        c.Pen.Width := 2;
        c.Pen.Color := clBlack;
        c.Line(6, 19, 17, 8);
        c.Brush.Style := bsSolid;
        c.Brush.Color := TColor($0080FF);
        c.Ellipse(15, 2, 23, 10);
        c.Pen.Width := 1;
        c.Line(5, 20, 3, 22);
      end;
    tlEraser:
      begin
        // a rubber: a slanted block, its lower half the colour of the part that rubs
        c.Pen.Width := 2;
        c.Brush.Style := bsSolid;
        c.Brush.Color := TColor($B0B0FF);
        c.Polygon([Point(4, 15), Point(14, 4), Point(22, 9), Point(12, 20)]);
        c.Brush.Color := TColor($F0F0F0);
        c.Polygon([Point(4, 15), Point(9, 10), Point(17, 15), Point(12, 20)]);
        c.Pen.Width := 1;
        c.Line(3, 22, 22, 22);
      end;
    tlClone:
      begin
        // a stamp: a handle over a flat base
        c.Pen.Width := 2;
        c.Brush.Style := bsSolid;
        c.Brush.Color := TColor($0080FF);
        c.Ellipse(8, 2, 18, 11);
        c.Rectangle(11, 10, 15, 15);
        c.Rectangle(4, 15, 22, 21);
      end;
    tlRegPoly:
      begin
        c.Pen.Width := 2;
        c.Polygon([Point(7, 3), Point(19, 3), Point(24, 12), Point(19, 21), Point(7, 21), Point(2, 12)]);
        c.Pen.Width := 1;
        c.Rectangle(12, 11, 14, 13);
      end;
    tlRefPoint:
      begin
        c.Pen.Color := TColor(ColorSel);
        c.Pen.Width := 2;
        c.Line(4, 12, 21, 12);
        c.Line(12, 4, 12, 20);
      end;
    tlSelRect:
      begin
        c.Pen.Width := 1;
        c.Pen.Style := psDot;
        c.Brush.Style := bsClear;
        c.Rectangle(3, 3, 23, 19);
      end;
    tlSelEllipse:
      begin
        c.Pen.Width := 1;
        c.Pen.Style := psDot;
        c.Brush.Style := bsClear;
        c.Ellipse(2, 3, 24, 19);
      end;
    tlSelFree:
      begin
        // a dotted loop drawn by hand
        c.Pen.Width := 1;
        c.Pen.Style := psDot;
        c.Brush.Style := bsClear;
        c.PolyBezier([Point(4, 14), Point(2, 2), Point(14, 2), Point(14, 8),
          Point(14, 14), Point(26, 2), Point(22, 17), Point(18, 21), Point(8, 21), Point(4, 14)]);
      end;
    tlSelShape:
      begin
        // a dashed frame with a figure inside
        c.Pen.Width := 1;
        c.Pen.Style := psDot;
        c.Rectangle(2, 3, 24, 20);
        c.Pen.Style := psSolid;
        c.Pen.Width := 2;
        c.Ellipse(8, 7, 19, 16);
      end;
    tlPathPoint:
      begin
        c.Pen.Width := 2;
        c.PolyBezier([Point(2, 17), Point(8, 2), Point(16, 22), Point(24, 6)]);
        c.Pen.Width := 1;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Rectangle(9, 8, 16, 15);
      end;
    tlBucket:
      begin
        c.Pen.Width := 2;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Polygon([Point(2, 11), Point(11, 2), Point(19, 10), Point(10, 19)]);
        c.Pen.Width := 1;
        c.Brush.Color := TColor($C08040);
        c.Ellipse(19, 13, 25, 21);
        c.Pen.Width := 2;
        c.Line(5, 8, 12, 15);
      end;
    tlArc3:
      begin
        c.Arc(3, 8, 23, 30, 23, 19, 3, 19);
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Pen.Width := 1;
        c.Rectangle(1, 17, 5, 21);
        c.Rectangle(21, 17, 25, 21);
        c.Rectangle(11, 6, 15, 10);
      end;
    tlArcCSE:
      begin
        c.Arc(3, 3, 23, 25, 22, 14, 4, 14);
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Pen.Width := 1;
        c.Rectangle(11, 12, 15, 16);
        c.Pen.Style := psDot;
        c.Line(13, 14, 23, 14);
      end;
    tlSpline:
      c.PolyBezier([Point(3, 17), Point(8, 0), Point(14, 26), Point(23, 5)]);
    tlText:
      begin
        c.Font.Height := -18;
        c.Font.Style := [fsBold];
        c.TextOut(6, 1, 'A');
      end;
    tlSvgCode:
      begin
        c.Pen.Width := 1;
        c.Font.Height := -11;
        c.Font.Style := [fsBold];
        c.TextOut(1, 4, '</>');
      end;
    tlTrim:
      begin
        c.Pen.Width := 2;
        c.Line(3, 6, 9, 6);
        c.Line(17, 6, 23, 6);
        c.Pen.Width := 1;
        c.Line(13, 2, 13, 20);
        c.Pen.Style := psDot;
        c.Line(9, 6, 17, 6);
      end;
    tlExtend:
      begin
        c.Pen.Width := 2;
        c.Line(3, 14, 12, 14);
        c.Pen.Width := 1;
        c.Pen.Style := psDot;
        c.Line(12, 14, 20, 14);
        c.Pen.Style := psSolid;
        c.Line(22, 3, 22, 20);
        c.Line(18, 11, 21, 14);
        c.Line(18, 17, 21, 14);
      end;
    tlJoin:
      begin
        c.Pen.Width := 2;
        c.Line(2, 18, 10, 8);
        c.Line(15, 8, 23, 18);
        c.Pen.Width := 1;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Rectangle(9, 6, 16, 13);
      end;
    tlVertex:
      begin
        c.Pen.Width := 2;
        c.Line(2, 18, 12, 6);
        c.Line(12, 6, 23, 18);
        c.Brush.Style := bsSolid;
        c.Brush.Color := clWhite;
        c.Pen.Width := 1;
        c.Rectangle(9, 3, 16, 10);
      end;
    tlVectorize:
      begin
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Pen.Width := 1;
        c.Rectangle(2, 2, 6, 6);
        c.Rectangle(6, 6, 10, 10);
        c.Rectangle(2, 10, 6, 14);
        c.Brush.Style := bsClear;
        c.Pen.Width := 2;
        c.Ellipse(9, 7, 24, 20);
      end;
    tlBreak:
      begin
        c.Pen.Width := 2;
        c.Line(2, 12, 8, 12);
        c.Line(16, 12, 22, 12);
        c.Pen.Width := 1;
        c.Line(9, 5, 11, 19);
        c.Line(14, 5, 12, 19);
      end;
    tlChamfer:
      begin
        c.Pen.Width := 2;
        c.Line(3, 4, 3, 11);
        c.Line(3, 11, 10, 18);
        c.Line(10, 18, 22, 18);
      end;
    tlRotate:
      begin
        c.Pen.Width := 2;
        c.Arc(3, 3, 21, 21, 21, 8, 8, 3);
        c.Pen.Width := 1;
        c.Brush.Style := bsSolid;
        c.Brush.Color := clBlack;
        c.Polygon([Point(18, 2), Point(23, 9), Point(14, 9)]);
      end;
    tlScale:
      begin
        c.Pen.Width := 1;
        c.Rectangle(3, 11, 11, 19);
        c.Pen.Width := 2;
        c.Rectangle(8, 4, 21, 17);
        c.Pen.Width := 1;
        c.Line(5, 17, 20, 6);
      end;
    tlArray:
      begin
        c.Pen.Width := 1;
        c.Rectangle(3, 3, 9, 9);
        c.Rectangle(13, 3, 19, 9);
        c.Rectangle(3, 13, 9, 19);
        c.Rectangle(13, 13, 19, 19);
        c.Pen.Style := psDot;
        c.Line(9, 6, 13, 6);
      end;
    tlMirror:
      begin
        c.Pen.Width := 1;
        c.Pen.Style := psDash;
        c.Line(13, 1, 13, 21);
        c.Pen.Style := psSolid;
        c.Pen.Width := 2;
        c.Polyline([Point(3, 18), Point(3, 6), Point(10, 18)]);
        c.Polyline([Point(23, 18), Point(23, 6), Point(16, 18)]);
      end;
    tlOffset:
      begin
        c.Pen.Width := 2;
        c.Line(3, 18, 18, 3);
        c.Pen.Width := 1;
        c.Line(8, 20, 23, 5);
        c.Line(11, 21, 24, 8);
      end;
    tlFillet:
      begin
        c.Pen.Width := 2;
        c.Line(3, 4, 3, 10);
        c.Arc(3, 10, 15, 22, 3, 10, 9, 16);
        c.Line(9, 16, 22, 16);
      end;
    tlRefLine:
      begin
        c.Pen.Color := TColor(ColorSel);
        c.Pen.Width := 2;
        c.Pen.Style := psDash;
        c.Line(3, 18, 22, 4);
      end;
  end;
end;

// the picture (file of the folder "icons") that stands for a tool; empty: that tool keeps its drawn icon
function ConsIconFile(k: TConstraintKind): string;
begin
  case k of
    ckFixed: Result := '40_vincolo_fisso';
    ckHorizontal: Result := '41_vincolo_orizzontale';
    ckVertical: Result := '42_vincolo_verticale';
    ckParallel: Result := '43_vincolo_parallelo';
    ckPerpendicular: Result := '44_vincolo_perpendicolare';
    ckEqual: Result := '45_vincolo_uguale';
    ckCoaxial: Result := '46_vincolo_coincidente';
    ckCoradial: Result := '47_vincolo_stesso_raggio';
    ckMidPoint: Result := '48_vincolo_punto_medio';
    ckIntersection: Result := '49_vincolo_intersezione';
    ckTangent: Result := '50_vincolo_tangente';
    ckSymmetry: Result := '51_vincolo_simmetria';
    ckDistance: Result := '52_quota_lineare';
    ckRadius: Result := '53_quota_radiale';
    ckAngle: Result := '54_quota_angolare';
  else
    Result := '';
  end;
end;

function TForm1.NewIconFile(t: TTool): string;
begin
  case t of
    tlLine: Result := '00_segmento_di_retta';
    tlRect: Result := '01_rettangolo';
    tlRoundRect: Result := '02_rettangolo_angoli_arrotondati';
    tlEllipse: Result := '03_ellisse';
    tlRegPoly: Result := '04_poligono_regolare';
    tlPolygon: Result := '05_poligono_irregolare';
    tlPolyline: Result := '06_polyline';
    tlSpline: Result := '07_path';
    tlArc: Result := '08_arco';
    tlVectorize: Result := '09_vettorializzatore_raster';
    tlText: Result := '10_testo';
    tlPen: Result := '11_penna';
    tlMarker: Result := '12_pennarello';
    tlBucket: Result := '13_secchiello_vernice';
    tlPicker: Result := '15_contagocce_colore';
    tlEraser: Result := '16_gomma_cancellare';
    tlAirbrush: Result := '17_aerografo';
    tlSelRect: Result := '18_selezione_rettangolare';
    tlSelEllipse: Result := '19_selezione_ellittica';
    tlSelFree: Result := '20_selezione_a_mano';
    tlWand: Result := '21_selezione_magic_wand';
    tlClone: Result := '22_clone_stamp';
    tlSelShape: Result := '23_da_forma_a_selezione';
    tlTrim: Result := '24_trim';
    tlBreak: Result := '25_break';
    tlExtend: Result := '26_extend';
    tlOffset: Result := '27_offset';
    tlMirror: Result := '28_mirror';
    tlFillet: Result := '29_fillet';
    tlChamfer: Result := '30_chamfer';
    tlArray: Result := '31_array';
    tlRotate: Result := '32_rotation';
    tlScale: Result := '33_scale';
    tlVertex: Result := '34_add_joint_polyline';
    tlJoin: Result := '35_join_lines';
    tlPathPoint: Result := '36_add_point_path';
    tlSelect: Result := '55_selezione_cursore';
    tlArrow: Result := '56_freccia';
    tlSvgCode: Result := '57_codice_svg';
    tlRefLine: Result := '58_linea_di_riferimento';
    tlRefPoint: Result := '59_punto_di_riferimento';
    tlArc3: Result := '64_arco_3_punti';
    tlArcCSE: Result := '65_arco_centro_inizio_fine';
  else
    Result := '';
  end;
end;

// a picture of the folder "icons" (next to the program) reduced to size x size; nil if it is not there
function TForm1.LoadIcon(const fn: string; size: Integer): TBGRABitmap;
var
  p: string;
  src: TBGRABitmap;
  r: TBGRACustomBitmap;
begin
  Result := nil;
  p := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'icons' + PathDelim + fn + '.png';
  if not FileExists(p) then Exit;
  size := Max(8, size);
  src := TBGRABitmap.Create;
  try
    try
      src.LoadFromFile(p);
    except
      Exit;
    end;
    r := src.Resample(size, size, rmFineResample);
    Result := r as TBGRABitmap;
  finally
    src.Free;
  end;
end;

// the colour behind a control: the first parent with a real colour
function BackColorOf(c: TControl): TColor;
begin
  Result := clBtnFace;
  while c <> nil do
  begin
    if (c is TWinControl) and (c.Color <> clDefault) then
    begin
      Result := c.Color;
      Break;
    end;
    c := c.Parent;
  end;
  Result := ColorToRGB(Result);
end;

procedure IconRgbToHsl(r, g, b: Integer; out h, s, l: Double);
var
  mx, mn, dl: Integer;
begin
  mx := Max(r, Max(g, b));
  mn := Min(r, Min(g, b));
  l := (mx + mn) / 510;
  dl := mx - mn;
  if dl = 0 then
  begin
    s := 0;
    h := 0;
  end
  else
  begin
    if l > 0.5 then s := dl / (510 - mx - mn) else s := dl / (mx + mn);
    if mx = r then h := (g - b) / dl
    else if mx = g then h := 2 + (b - r) / dl
    else h := 4 + (r - g) / dl;
    if h < 0 then h := h + 6;
  end;
end;

procedure IconHslToRgb(h, s, l: Double; out r, g, b: Integer);
var
  c, x, m: Double;
  r1, g1, b1: Double;
begin
  c := (1 - Abs(2 * l - 1)) * s;
  x := c * (1 - Abs(h - 2 * Int(h / 2) - 1));
  m := l - c / 2;
  case Trunc(h) mod 6 of
    0: begin r1 := c; g1 := x; b1 := 0; end;
    1: begin r1 := x; g1 := c; b1 := 0; end;
    2: begin r1 := 0; g1 := c; b1 := x; end;
    3: begin r1 := 0; g1 := x; b1 := c; end;
    4: begin r1 := x; g1 := 0; b1 := c; end;
  else
    begin r1 := c; g1 := 0; b1 := x; end;
  end;
  r := Round((r1 + m) * 255);
  g := Round((g1 + m) * 255);
  b := Round((b1 + m) * 255);
end;

// Lightness of the drawing for a light panel: the dark-theme drawing is bright on dark, so its lightness is turned
// upside down (hue and saturation stay): white becomes dark, a light cyan a deeper blue.
procedure FlipLightness(var r, g, b: Integer);
var
  h, s, l: Double;
begin
  IconRgbToHsl(r, g, b, h, s, l);
  IconHslToRgb(h, s, 0.12 + 0.50 * (1 - l), r, g, b);
end;

// the dark tile of an icon takes the colour of the panel behind it (same hue, a little lighter on a dark theme,
// a little darker on a light one). On a light panel the details of the tile (grid, frame) turn dark and the
// drawing gets its lightness flipped. Every channel is clamped to 0..255.
procedure TintIconTile(ic: TBGRABitmap; panel: TColor);
const
  LREF = 60;     // mean luminance of the original tile
var
  pr, pg, pb, lp, off, i, l, mx, w, d, dr, dg, db: Integer;
  light: Boolean;
  p: PBGRAPixel;

  function Cl(v: Integer): Integer;
  begin
    if v < 0 then Result := 0 else if v > 255 then Result := 255 else Result := v;
  end;

begin
  pr := Red(panel);
  pg := Green(panel);
  pb := Blue(panel);
  lp := (pr * 30 + pg * 59 + pb * 11) div 100;
  light := lp >= 128;
  if light then off := -16 else off := 16;
  if light then
  begin
    // on a light theme the tile is cream, not white: the blue goes down more than the red and the green
    pr := pr - 4;
    pg := pg - 10;
    pb := pb - 30;
  end;
  for i := 0 to ic.NbPixels - 1 do
  begin
    p := ic.Data + i;
    if p^.alpha = 0 then Continue;
    l := (p^.red * 30 + p^.green * 59 + p^.blue * 11) div 100;
    mx := Max(p^.red, Max(p^.green, p^.blue));
    // 256 = pure tile, 0 = pure drawing
    w := Round(Cl(Round((185 - mx) * 255 / 45)) * 256 / 255);
    if light then d := off - (l - LREF) * 12 div 10
    else d := off + (l - LREF) * 6 div 10;
    dr := p^.red;
    dg := p^.green;
    db := p^.blue;
    if light and (w < 256) then FlipLightness(dr, dg, db);
    p^.red := Cl((Cl(pr + d) * w + Cl(dr) * (256 - w)) div 256);
    p^.green := Cl((Cl(pg + d) * w + Cl(dg) * (256 - w)) div 256);
    p^.blue := Cl((Cl(pb + d) * w + Cl(db) * (256 - w)) div 256);
  end;
  ic.InvalidateBitmap;
end;

// the glyph of a button: the picture, and next to it the same one grayed (shown when the button is disabled)
procedure TForm1.ApplyGlyphIcon(b: TSpeedButton; ic0: TBGRABitmap; tint: Boolean);
var
  cmb, gr, ic: TBGRABitmap;
  p: PBGRAPixel;
  i, v, S, lp: Integer;
  pc: TColor;
begin
  S := ic0.Width;
  pc := BackColorOf(b);
  lp := (Red(pc) * 30 + Green(pc) * 59 + Blue(pc) * 11) div 100;
  ic := ic0.Duplicate as TBGRABitmap;
  if tint then TintIconTile(ic, pc);
  cmb := TBGRABitmap.Create(2 * S, S, BGRAPixelTransparent);
  gr := ic.Duplicate as TBGRABitmap;
  try
    for i := 0 to gr.NbPixels - 1 do
    begin
      p := gr.Data + i;
      v := (p^.red * 30 + p^.green * 59 + p^.blue * 11) div 100;
      v := (v * 40 + lp * 60) div 100;
      p^.red := v;
      p^.green := v;
      p^.blue := v;
      p^.alpha := p^.alpha * 55 div 100;
    end;
    cmb.PutImage(0, 0, ic, dmSet);
    cmb.PutImage(S, 0, gr, dmSet);
    b.Glyph.Assign(cmb.Bitmap);
    b.NumGlyphs := 2;
  finally
    gr.Free;
    cmb.Free;
    ic.Free;
  end;
end;

// the panels built after the tool buttons (References with the snap button, Operators) get the new size and pictures
procedure TForm1.RelayoutExtras;
const
  RH = 37;
  BW = 40;
  BH = 36;
var
  k: Integer;
  sc: Double;
  b: TSpeedButton;
  ic: TBGRABitmap;
  fn: string;

  function U(v: Integer): Integer;
  begin
    Result := Round(v * sc);
  end;

begin
  sc := toolSelect.Width / 40;
  if sc < 0.3 then sc := 1;
  // References panel: line, snap, point; Operators panel: intersection, union, difference
  b := referenceLine;
  for k := 0 to 2 do
  begin
    case k of
      0: b := referenceLine;
      1: b := toolSnapLine;
    else
      b := toolRefPoint;
    end;
    b.SetBounds(U(20), U(26 + k * RH), U(BW), U(BH));
  end;
  for k := 0 to 2 do
    if btnOp[k] <> nil then
    begin
      btnOp[k].SetBounds(U(16), U(26 + k * RH), U(BW), U(BH));
      case k of
        0: fn := '61_operatore_intersezione';
        1: fn := '62_operatore_unione';
      else
        fn := '63_operatore_differenza';
      end;
      ic := LoadIcon(fn, Min(btnOp[k].Width, btnOp[k].Height) - 6);
      if ic <> nil then
      try
        ApplyGlyphIcon(btnOp[k], ic);
      finally
        ic.Free;
      end;
    end;
  ic := LoadIcon('60_snap_alle_linee', Min(toolSnapLine.Width, toolSnapLine.Height) - 6);
  if ic <> nil then
  try
    ApplyGlyphIcon(toolSnapLine, ic);
  finally
    ic.Free;
  end;
end;

// square icons: the buttons of the tool panels are taller and a little wider apart, and the pictures are put on them again
procedure TForm1.RelayoutToolButtons;
const
  PX = 45;          // distance between two columns (before: 40)
  RH = 37;          // distance between two rows (before: 32)
  BW = 40;          // width and height of a button (before: 38 x 31)
  BH = 36;
  RW = 34;          // the buttons with a drop-down (rectangle, arc) are narrower: the little arrow takes the rest
var
  pans: array[0..5] of TPanel;
  pn: TPanel;
  k, i, col, row, oldMax, newMax: Integer;
  sc: Double;
  b: TSpeedButton;
  t: TTool;
  ic: TBGRABitmap;
  fn: string;
  ck: TConstraintKind;

  function U(v: Integer): Integer;
  begin
    Result := Round(v * sc);
  end;

begin
  // everything is measured in the units of the design (the form may be scaled)
  sc := toolSelect.Width / 38;
  if sc < 0.3 then sc := 1;
  pans[0] := ToolsPanel;
  pans[1] := ArtisticPanel;
  pans[2] := RasterPanel;
  pans[3] := ActionsPanel;
  pans[4] := ConstraintsPanel;
  pans[5] := QuotePanel;
  for k := 0 to 5 do
  begin
    pn := pans[k];
    oldMax := 0;
    newMax := 0;
    for i := 0 to pn.ControlCount - 1 do
      if (pn.Controls[i] is TSpeedButton) and (pn.Controls[i] <> toolRectMenu) and (pn.Controls[i] <> toolArcMenu) then
        oldMax := Max(oldMax, pn.Controls[i].Left + pn.Controls[i].Width);
    for i := 0 to pn.ControlCount - 1 do
      if (pn.Controls[i] is TSpeedButton) and (pn.Controls[i] <> toolRectMenu) and (pn.Controls[i] <> toolArcMenu) then
      begin
        b := TSpeedButton(pn.Controls[i]);
        col := Round((b.Left / sc - 8) / 40);
        row := Round((b.Top / sc - 26) / 32);
        if (b = toolRect) or (b = toolEllipticalArc) then b.SetBounds(U(8 + col * PX), U(26 + row * RH), U(RW), U(BH))
        else b.SetBounds(U(8 + col * PX), U(26 + row * RH), U(BW), U(BH));
        newMax := Max(newMax, b.Left + b.Width);
      end;
    if (oldMax > 0) then pn.Width := pn.Width - oldMax + newMax + U(2 * 0);
  end;
  // the little arrows next to the rectangle and the arc
  toolRectMenu.SetBounds(toolRect.Left + toolRect.Width + U(1), toolRect.Top, U(10), U(BH));
  toolArcMenu.SetBounds(toolEllipticalArc.Left + toolEllipticalArc.Width + U(1), toolEllipticalArc.Top, U(10), U(BH));
  ToolsPanel.Width := ToolsPanel.Width + U(10);
  Panel1.Height := Panel1.Height + U(15);
  // the pictures again, on buttons of the new size
  for t := Low(TTool) to High(TTool) do
    if (ToolButtons[t] <> nil) and (NewIconFile(t) <> '') and not (t in [tlRect, tlRoundRect, tlArc, tlArc3, tlArcCSE]) then
      ApplyGlyph(ToolButtons[t], t);
  SetRectMode(RectMode);
  SetArcMode(ArcMode);
  for k := 0 to 5 do
  begin
    case k of
      0: begin b := btnGroup; fn := '37_group'; end;
      1: begin b := btnUngroup; fn := '38_ungroup'; end;
      2: begin b := btnMerge; fn := '39_merge_rasters'; end;
      3: begin b := btnFlip; fn := '67_capovolgi'; end;
      4: begin b := btnInvSel; fn := '69_inverti_selezione'; end;
    else
      begin b := btnMirror; fn := '68_specchio'; end;
    end;
    ic := LoadIcon(fn, Min(b.Width, b.Height) - 6);
    if ic <> nil then
    try
      b.Caption := '';
      ApplyGlyphIcon(b, ic);
    finally
      ic.Free;
    end;
  end;
  for ck := Low(TConstraintKind) to High(TConstraintKind) do
    if (ConsButtons[ck] <> nil) and (ConsIconFile(ck) <> '') then
    begin
      ic := LoadIcon(ConsIconFile(ck), Min(ConsButtons[ck].Width, ConsButtons[ck].Height) - 6);
      if ic <> nil then
      try
        ConsButtons[ck].Caption := '';
        ApplyGlyphIcon(ConsButtons[ck], ic);
      finally
        ic.Free;
      end;
    end;
  ic := LoadIcon('14_fonte_illuminazione', Min(toolLight.Width, toolLight.Height) - 6);
  if ic <> nil then
  try
    ApplyGlyphIcon(toolLight, ic);
  finally
    ic.Free;
  end;
end;

procedure TForm1.ApplyGlyph(b: TSpeedButton; t: TTool);
var
  bmp: TBitmap;
  ic: TBGRABitmap;
  fn: string;
begin
  if NewIcons then
  begin
    fn := NewIconFile(t);
    if fn <> '' then
    begin
      ic := LoadIcon(fn, Min(b.Width, b.Height) - 6);
      if ic <> nil then
      begin
        try
          ApplyGlyphIcon(b, ic);
        finally
          ic.Free;
        end;
        Exit;
      end;
    end;
  end;
  bmp := MakeToolIcon(t);
  try
    ApplyGlyphBmp(b, bmp);
  finally
    bmp.Free;
  end;
end;

procedure TForm1.ApplyGlyphBmp(b: TSpeedButton; bmp: TBitmap);
var
  dbmp: TBitmap;
  gx, gy, w, h: Integer;
  li, dli: TLazIntfImage;
  c, grey, fuchsia: TFPColor;
begin
  // two glyphs side by side: normal and grayed (used when the button is disabled)
  // (the pixels are read and written in memory: each Canvas.Pixels is a round trip to the X server)
  w := bmp.Width;
  h := bmp.Height;
  dbmp := TBitmap.Create;
  li := bmp.CreateIntfImage;
  dli := TLazIntfImage.Create(0, 0);
  try
    dli.DataDescription := li.DataDescription;
    dli.SetSize(w * 2, h);
    grey := TColorToFPColor(TColor($B4B4B4));
    fuchsia := TColorToFPColor(clFuchsia);
    for gy := 0 to h - 1 do
      for gx := 0 to w - 1 do
      begin
        c := li.Colors[gx, gy];
        dli.Colors[gx, gy] := c;
        if (c.red = fuchsia.red) and (c.green = fuchsia.green) and (c.blue = fuchsia.blue) then
          dli.Colors[w + gx, gy] := fuchsia
        else dli.Colors[w + gx, gy] := grey;
      end;
    dbmp.LoadFromIntfImage(dli);
    dbmp.Transparent := True;
    dbmp.TransparentColor := clFuchsia;
    b.Glyph.Assign(dbmp);
    b.NumGlyphs := 2;
  finally
    dli.Free;
    li.Free;
    dbmp.Free;
  end;
end;

// Group: two boxes joined by a dashed frame; Ungroup: the same boxes apart
function TForm1.MakeGroupIcon(apart: Boolean): TBitmap;
var
  c: TCanvas;
begin
  Result := TBitmap.Create;
  Result.SetSize(26, 22);
  Result.Transparent := True;
  Result.TransparentColor := clFuchsia;
  c := Result.Canvas;
  c.Brush.Color := clFuchsia;
  c.FillRect(0, 0, 26, 22);
  c.Pen.Color := clBlack;
  c.Brush.Style := bsClear;
  c.Pen.Width := 2;
  if apart then
  begin
    c.Rectangle(2, 2, 11, 11);
    c.Rectangle(15, 12, 24, 21);
  end
  else
  begin
    c.Rectangle(5, 5, 13, 13);
    c.Rectangle(12, 10, 20, 18);
    c.Pen.Width := 1;
    c.Pen.Style := psDash;
    c.Rectangle(2, 2, 23, 21);
    c.Pen.Style := psSolid;
  end;
end;

procedure TForm1.GroupClick(Sender: TObject);
var
  ts: TShapeArray;
  i, gid: Integer;
begin
  ts := SelShapes;
  if Length(ts) < 2 then
  begin
    SetStatus('Group: select at least two objects first.');
    Exit;
  end;
  Checkpoint;
  gid := Doc.NewGroupId;
  for i := 0 to High(ts) do
  begin
    ts[i].GroupId := gid;
    ts[i].Snip := '';             // a group made by hand has no parameters
    ts[i].GroupName := '';
    ts[i].GroupRot := 0;
  end;
  Commit;
  SetStatus('Grouped ' + IntToStr(Length(ts)) + ' objects. Right-click, Ungroup or Edit > Ungroup splits them again.');
  RefreshProps;
  Redraw;
end;

procedure TForm1.UngroupClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  any: Boolean;
begin
  ts := SelShapes;
  any := False;
  for i := 0 to High(ts) do
    if ts[i].GroupId > 0 then any := True;
  if not any then
  begin
    SetStatus('Ungroup: the selection contains no group.');
    Exit;
  end;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    ts[i].GroupId := 0;
    ts[i].GroupRot := 0;
    ts[i].Snip := '';
    ts[i].GroupName := '';
  end;
  Commit;
  SetStatus('Ungrouped: the elements are separate objects now.');
  RefreshProps;
  Redraw;
end;

// the rectangle button makes the kind of rectangle chosen in its drop-down
procedure TForm1.SetRectMode(t: TTool);
var
  i: Integer;
begin
  RectMode := t;
  toolRect.Tag := Ord(t);
  ApplyGlyph(toolRect, t);
  toolRect.Hint := ToolHints[t];
  if RectMenu <> nil then
    for i := 0 to RectMenu.Items.Count - 1 do
      RectMenu.Items[i].Checked := RectMenu.Items[i].Tag = Ord(t);
end;

procedure TForm1.RectMenuClick(Sender: TObject);
begin
  SetTool(TTool(TMenuItem(Sender).Tag));
end;

procedure TForm1.RectMenuButtonClick(Sender: TObject);
var
  pt: TPoint;
begin
  pt := toolRectMenu.ClientToScreen(Point(0, toolRectMenu.Height));
  RectMenu.PopUp(pt.x, pt.y);
end;

// the arc button makes the kind of arc chosen in its drop-down
procedure TForm1.SetArcMode(t: TTool);
var
  i: Integer;
begin
  ArcMode := t;
  toolEllipticalArc.Tag := Ord(t);
  ApplyGlyph(toolEllipticalArc, t);
  toolEllipticalArc.Hint := ToolHints[t];
  if ArcMenu <> nil then
    for i := 0 to ArcMenu.Items.Count - 1 do
      ArcMenu.Items[i].Checked := ArcMenu.Items[i].Tag = Ord(t);
end;

procedure TForm1.ArcMenuClick(Sender: TObject);
begin
  SetTool(TTool(TMenuItem(Sender).Tag));
end;

procedure TForm1.ArcMenuButtonClick(Sender: TObject);
var
  pt: TPoint;
begin
  pt := toolArcMenu.ClientToScreen(Point(0, toolArcMenu.Height));
  ArcMenu.PopUp(pt.x, pt.y);
end;

// circle through three points: centre, radius and the angles of the arc from a to b through c
function ArcThrough(const a, b, c: TPt; out o: TPt; out r, a1, a2: Double; out aStart: Boolean): Boolean;
var
  d, sa, sb, sc, sAC, sAB, aa, ab, ac: Double;
begin
  Result := False;
  d := 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
  if Abs(d) < 1e-6 then Exit;
  sa := a.x * a.x + a.y * a.y;
  sb := b.x * b.x + b.y * b.y;
  sc := c.x * c.x + c.y * c.y;
  o := MakePt((sa * (b.y - c.y) + sb * (c.y - a.y) + sc * (a.y - b.y)) / d,
              (sa * (c.x - b.x) + sb * (a.x - c.x) + sc * (b.x - a.x)) / d);
  r := Hypot(a.x - o.x, a.y - o.y);
  if r > 1e6 then Exit;
  aa := ArcTan2(a.y - o.y, a.x - o.x);
  ab := ArcTan2(b.y - o.y, b.x - o.x);
  ac := ArcTan2(c.y - o.y, c.x - o.x);
  sAC := ac - aa;
  while sAC < 0 do sAC := sAC + 2 * Pi;
  sAB := ab - aa;
  while sAB < 0 do sAB := sAB + 2 * Pi;
  aStart := sAC < sAB;
  if aStart then
  begin
    a1 := aa;
    a2 := ab;
  end
  else
  begin
    a1 := ab;
    a2 := aa;
  end;
  Result := True;
end;

// preview of the arc being made with the 3-point / centre modes
procedure TForm1.Arc2Update(px, py: Double);
var
  pt, o: TPt;
  ref: TRef;
  r, a1, a2: Double;
begin
  if (Creating = nil) or (Arc2N < 1) then Exit;
  HasSnap := SnapTo(px, py, nil, ref, pt);
  if HasSnap then
  begin
    px := pt.x;
    py := pt.y;
  end;
  Arc2Ok := False;
  Creating.Circ := True;
  Creating.RX := 0.001;
  Creating.RY := 0.001;
  Creating.A1 := 0;
  Creating.A2 := 0.001;
  if (Tool = tlArc3) and (Arc2N >= 2) then
  begin
    if ArcThrough(Arc2Pts[0], Arc2Pts[1], MakePt(px, py), o, r, a1, a2, Arc2AIsStart) then
    begin
      Creating.P[0] := o;
      Creating.RX := r;
      Creating.RY := r;
      Creating.A1 := a1;
      Creating.A2 := a2;
      Arc2Ok := True;
    end;
  end
  else if (Tool = tlArcCSE) and (Arc2N >= 2) then
  begin
    r := Hypot(Arc2Pts[1].x - Arc2Pts[0].x, Arc2Pts[1].y - Arc2Pts[0].y);
    if r > 1e-6 then
    begin
      Creating.P[0] := Arc2Pts[0];
      Creating.RX := r;
      Creating.RY := r;
      a1 := ArcTan2(Arc2Pts[1].y - Arc2Pts[0].y, Arc2Pts[1].x - Arc2Pts[0].x);
      a2 := ArcTan2(py - Arc2Pts[0].y, px - Arc2Pts[0].x);
      // counter-clockwise on the screen = decreasing angle (y points down)
      Creating.A1 := a2;
      Creating.A2 := a1;
      Arc2Ok := Hypot(px - Arc2Pts[0].x, py - Arc2Pts[0].y) > 1e-6;
    end;
  end;
  Redraw;
end;

procedure TForm1.Arc2Click(px, py: Double);
var
  pt: TPt;
  ref: TRef;
  snapped: Boolean;
begin
  snapped := SnapTo(px, py, nil, ref, pt);
  if snapped then
  begin
    px := pt.x;
    py := pt.y;
  end;
  if snapped then Arc2Snap[Arc2N] := ref else FillChar(Arc2Snap[Arc2N], SizeOf(TRef), 0);
  if Arc2N = 0 then
  begin
    Checkpoint;
    Creating := NewShape(skArc);
    Creating.Circ := True;
    SetLength(Creating.P, 1);
    Creating.P[0] := MakePt(px, py);
    Creating.RX := 0.001;
    Creating.RY := 0.001;
    Creating.A1 := 0;
    Creating.A2 := 0.001;
    Arc2Pts[0] := MakePt(px, py);
    Arc2N := 1;
    SetLength(CreateSnaps, 0);
    if Tool = tlArcCSE then
    begin
      SetLength(CreateSnaps, 1);
      if snapped then CreateSnaps[0] := ref else FillChar(CreateSnaps[0], SizeOf(TRef), 0);
      SetStatus('Arc by centre: now click the start point (it sets the radius).');
    end
    else SetStatus('Arc by 3 points: now click the other end.');
    Redraw;
  end
  else if Arc2N = 1 then
  begin
    Arc2Pts[1] := MakePt(px, py);
    Arc2N := 2;
    if Tool = tlArcCSE then SetStatus('Arc by centre: now click the end of the arc (counter-clockwise).')
    else SetStatus('Arc by 3 points: click a third point on the arc, it sets the radius (Esc cancels).');
    Arc2Update(px, py);
  end
  else
  begin
    Arc2Update(px, py);
    if Arc2Ok then FinishCreating(True)
    else SetStatus('The three points are on a line: move the last point away from it.');
  end;
end;

// the markers of the points that attract appear / disappear at once
procedure TForm1.SnapToggleClick(Sender: TObject);
begin
  Redraw;
end;

// toggle button: points clicked near a line stay attached to it (see SnapTo)
procedure TForm1.BuildSnapButton;
var
  bmp: TBitmap;
begin
  toolSnapLine := TSpeedButton.Create(Self);
  toolSnapLine.Parent := ReferencePanel;
  toolSnapLine.SetBounds(referenceLine.Left, referenceLine.Top + 32, referenceLine.Width, referenceLine.Height);
  toolSnapLine.GroupIndex := 50;
  toolSnapLine.AllowAllUp := True;
  toolSnapLine.OnClick := @SnapToggleClick;
  toolSnapLine.Hint := 'Snap to lines: a point clicked on a line (also a reference line) or on a side of a poly-line stays attached to it by a constraint';
  toolSnapLine.ShowHint := True;
  bmp := TBitmap.Create;
  try
    bmp.SetSize(26, 22);
    bmp.Transparent := True;
    bmp.TransparentColor := clFuchsia;
    bmp.Canvas.Brush.Color := clFuchsia;
    bmp.Canvas.FillRect(0, 0, 26, 22);
    bmp.Canvas.Pen.Color := clBlack;
    bmp.Canvas.Pen.Width := 2;
    bmp.Canvas.Line(2, 19, 24, 5);
    bmp.Canvas.Pen.Width := 1;
    bmp.Canvas.Brush.Color := TColor($0090FF);
    bmp.Canvas.Ellipse(8, 7, 18, 17);
    toolSnapLine.Glyph.Assign(bmp);
  finally
    bmp.Free;
  end;
end;

// every dialog (ours, and the ones of the LCL: messages, questions, input) opens at the centre of the main window
procedure TForm1.ActiveFormChanged(Sender: TObject);
var
  f: TCustomForm;
  i: Integer;
  x, y: Integer;
begin
  f := Screen.ActiveCustomForm;
  if (f = nil) or (f = Self) or (Centered = nil) then Exit;
  for i := Centered.Count - 1 downto 0 do
    if Screen.CustomFormIndex(TCustomForm(Centered[i])) < 0 then Centered.Delete(i);
  if Centered.IndexOf(f) >= 0 then Exit;
  if not (fsModal in f.FormState) then Exit;
  Centered.Add(f);
  x := Left + (Width - f.Width) div 2;
  y := Top + (Height - f.Height) div 2;
  f.SetBounds(Max(0, x), Max(0, y), f.Width, f.Height);
end;

// the dialogs of the system (open, save, colour, print): centred on the main window when they are made
procedure TForm1.CenterCommonDlg(Sender: TObject);
var
  w: PGtkWindow;
begin
  if not (Sender is TCommonDialog) then Exit;
  w := PGtkWindow(TCommonDialog(Sender).Handle);
  if (w = nil) or (Form1 = nil) then Exit;
  gtk_window_set_transient_for(w, PGtkWindow(Form1.Handle));
  gtk_window_set_position(w, GTK_WIN_POS_CENTER_ON_PARENT);
end;

// the Operators panel of the toolbar: boolean operations on two overlapping closed figures
procedure TForm1.BuildOperators;
const
  Names: array[0..2] of string = ('Intersection', 'Union', 'Difference');
  Hints: array[0..2] of string = (
    'Intersection: select two overlapping closed figures; only the part they share is kept',
    'Union: select two overlapping closed figures; they become one outline',
    'Difference: select two overlapping closed figures; the upper one is cut out of the lower one');
var
  i, x, y: Integer;
  bmp: TBitmap;
  ina, inb, keep: Boolean;
begin
  OperatorPanel := TPanel.Create(Self);
  OperatorPanel.Parent := Panel1;
  OperatorPanel.Align := alLeft;
  OperatorPanel.Left := 4000;
  OperatorPanel.Width := 72;
  OperatorPanel.BevelOuter := bvRaised;
  with TLabel.Create(Self) do
  begin
    Parent := OperatorPanel;
    Caption := 'Operators';
    SetBounds(6, 8, 100, 16);
  end;
  for i := 0 to 2 do
  begin
    btnOp[i] := TSpeedButton.Create(Self);
    btnOp[i].Parent := OperatorPanel;
    btnOp[i].SetBounds(17, 26 + i * 32, 38, 31);
    btnOp[i].Tag := i;
    btnOp[i].Hint := Hints[i];
    btnOp[i].ShowHint := True;
    btnOp[i].Enabled := False;
    btnOp[i].OnClick := @OperatorClick;
    bmp := TBitmap.Create;
    try
      bmp.SetSize(26, 22);
      bmp.Transparent := True;
      bmp.TransparentColor := clFuchsia;
      bmp.Canvas.Brush.Color := clFuchsia;
      bmp.Canvas.FillRect(0, 0, 26, 22);
      // two overlapping discs: the part the operator keeps is solid
      for y := 0 to 21 do
        for x := 0 to 25 do
        begin
          ina := Sqr(x - 9.5) + Sqr(y - 10.5) <= 8.2 * 8.2;
          inb := Sqr(x - 16.5) + Sqr(y - 10.5) <= 8.2 * 8.2;
          case i of
            0: keep := ina and inb;
            1: keep := ina or inb;
          else keep := ina and not inb;
          end;
          if keep then bmp.Canvas.Pixels[x, y] := TColor($B06A1E)
          else if ina or inb then bmp.Canvas.Pixels[x, y] := TColor($E0D8D0);
        end;
      btnOp[i].Glyph.Assign(bmp);
    finally
      bmp.Free;
    end;
  end;
end;

// what the buttons do to the two selected figures: the lower one is the first operand
procedure TForm1.OperatorClick(Sender: TObject);
var
  ts: TShapeArray;
  lo, up, nr: TShape;
  op, pos, ilo, iup, i, j, n, total, want: Integer;
  pd, err, txt: string;
  lps: TPtLoops;
  bx1, by1, bx2, by2, cx, cy: Double;
begin
  op := (Sender as TSpeedButton).Tag;
  ts := SelShapes;
  if (Length(ts) <> 2) or not BoolOverlap(ts[0], ts[1]) then
  begin
    SetStatus('Operators: select two closed figures that overlap.');
    Exit;
  end;
  lo := ts[0];
  up := ts[1];
  ilo := Doc.Layers.IndexOf(Doc.LayerOf(lo)) * 100000 + Doc.Shapes.IndexOf(lo);
  iup := Doc.Layers.IndexOf(Doc.LayerOf(up)) * 100000 + Doc.Shapes.IndexOf(up);
  if iup < ilo then
  begin
    lo := ts[1];
    up := ts[0];
  end;
  if not BoolCompute(lo, up, op, pd, err) then
  begin
    SetStatus('Operators: ' + err);
    Exit;
  end;
  nr := TShape.Create;
  nr.Assign(lo);
  nr.Kind := skPath;
  SetLength(nr.P, 1);
  nr.P[0] := MakePt(0, 0);
  nr.PathData := pd;
  nr.Rot := 0;
  nr.Corner := 0;
  nr.GroupId := 0;
  nr.GroupRot := 0;
  nr.SplineClosed := False;
  nr.Locked := False;
  SetLength(nr.RingStarts, 0);
  nr.ParsePath;
  // the outlines of the result, without the point that closes each of them
  SetLength(lps, Length(nr.Flat));
  total := 0;
  for i := 0 to High(nr.Flat) do
  begin
    lps[i] := Copy(nr.Flat[i]);
    n := Length(lps[i]);
    if (n > 3) and (Hypot(lps[i][0].x - lps[i][n - 1].x, lps[i][0].y - lps[i][n - 1].y) < 1e-9) then SetLength(lps[i], n - 1);
    Inc(total, Length(lps[i]));
  end;
  // how many points the result should have
  txt := IntToStr(total);
  if not InputQuery('Operators', 'Number of points of the resulting path (the result has ' + IntToStr(total) + '):', txt) then
  begin
    nr.Free;
    Exit;
  end;
  want := StrToIntDef(Trim(txt), total);
  want := Max(3 * Length(lps), Min(5000, want));
  ResizeLoops(lps, want);
  // the point that moves the path (its handle, and the pivot of a rotation) goes to the centre of the figure
  bx1 := 1e300; by1 := 1e300; bx2 := -1e300; by2 := -1e300;
  for i := 0 to High(lps) do
    for j := 0 to High(lps[i]) do
    begin
      bx1 := Min(bx1, lps[i][j].x);
      by1 := Min(by1, lps[i][j].y);
      bx2 := Max(bx2, lps[i][j].x);
      by2 := Max(by2, lps[i][j].y);
    end;
  cx := (bx1 + bx2) / 2;
  cy := (by1 + by2) / 2;
  pd := '';
  for i := 0 to High(lps) do
  begin
    for j := 0 to High(lps[i]) do
    begin
      if j = 0 then pd := pd + 'M' else pd := pd + ' L';
      pd := pd + StringReplace(FormatFloat('0.###', lps[i][j].x - cx), DefaultFormatSettings.DecimalSeparator, '.', []) + ' ' +
        StringReplace(FormatFloat('0.###', lps[i][j].y - cy), DefaultFormatSettings.DecimalSeparator, '.', []);
    end;
    pd := pd + ' Z ';
  end;
  nr.PathData := Trim(pd);
  nr.P[0] := MakePt(cx, cy);
  nr.ParsePath;
  Checkpoint;
  pos := Doc.Shapes.IndexOf(lo);
  if Doc.Shapes.IndexOf(up) < pos then Dec(pos);
  Doc.DeleteShape(lo);
  Doc.DeleteShape(up);
  Doc.AddShape(nr);
  Doc.Shapes.Move(Doc.Shapes.IndexOf(nr), Min(pos, Doc.Shapes.Count - 1));
  // a result made of one outline is a real polygon: its sides and points can be selected and constrained
  if Length(lps) = 1 then
  begin
    if Doc.ConvertPath(nr, Length(lps[0]), i, err) then SetStatus('The result is a polygon of ' + IntToStr(Length(nr.P)) + ' points.')
    else SetStatus('Operators: ' + err);
  end
  else SetStatus('The result has several outlines (holes or separate pieces): it stays a path, its sides cannot take constraints.');
  SetLength(Sel, 1);
  Sel[0] := MakeRef(nr.Id, -1);
  SelQuote := nil;
  Commit;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.BuildToolButtons;
const
  Hints: array[TTool] of string = ('Select / move', 'Line', 'Arrow', 'Poly-line (double-click or Enter to end)',
    'Polygon (double-click or Enter to end)', 'Rectangle', 'Ellipse / circle (drag from the center; Shift = circle)',
    'Elliptical arc (drag the ellipse, then click start and end)', 'Spline (double-click or Enter to end)', 'Text',
    'Insert SVG path code', 'Reference line (guide for quotes, not exported to raster)',
    'Trim: click the part of a line between two crossings to hide it (Shift+click: restore the object)',
    'Extend: click near the end of a line / poly-line to prolong it up to the next object (Shift+click: remove the extension)',
    'Fillet: click two lines on the sides you want to keep; they are joined by a rounded corner',
    'Offset: click an object, then click on the side where the parallel copy goes',
    'Mirror: pick the objects (or select them first, Shift+click for more), then click the axis line',
    'Array: select the objects first, then press this button (rectangular or polar copies that follow the original)',
    'Scale: select the objects first, then press this button and enter the factor: they are scaled around the centre of the selection',
    'Rotate: select the objects first, then press this button, enter the angle and click the center of rotation',
    'Chamfer: click two lines on the sides you want to keep; they are joined by a straight cut',
    'Break: click a first point on an object, then a second point: the part between them is hidden (Shift+click: restore the object)',
    'Vectorize: click a uniform area of a raster picture; if it is a rectangle, an ellipse or a straight line the vector figure is put over it',
    'Add joint: click a line (or a side of a poly-line / polygon) to add a vertex there; a straight line becomes a poly-line',
    'Join: with a line, poly-line, polygon or spline selected, click its point that must move and then the point it must reach: they become one point',
    'Arc by 3 points: click the two ends, then a third point on the arc (it sets the radius)',
    'Arc by centre: click the centre, the start point (sets the radius), then the end (counter-clockwise)',
    'Paint bucket: click inside an area closed by lines / curves to fill it; the fill follows its boundaries',
    'Add point to path: select a path, then click a point of it to add a new control point there',
    'Pen: draw freehand; the stroke is a smooth vector curve (points can be moved afterwards)',
    'Marker: draw freehand with a thick marker stroke (vector curve, thickness and colour can be changed)',
    'Airbrush: spray dots along a freehand curve (vector dots: radius, dot size and density can be changed)',
    'Rectangle with rounded corners (the radius is in its properties)',
    'SVG snippet: click one corner, then the opposite corner (sets position, width and height)',
    'Magic wand: select a raster first, then click on it: the area of a similar colour becomes a Selection object (its tolerance is in the properties)',
    'Selection from a figure: select a raster first, then click a closed figure that lies on it: the figure becomes a Selection object',
    'Rectangular selection: select a raster first, then drag on it (Shift: add to the selection, Shift+Ctrl: subtract)',
    'Elliptical selection: select a raster first, then drag the box of the ellipse on it (Shift: add, Shift+Ctrl: subtract)',
    'Freehand selection: select a raster first, then draw around the area you want, holding the mouse button',
    'Reference point: click to put a point (a guide for quotes and constraints, not exported to raster)',
    'Regular shape: drag from the centre to a corner (the number of sides is in the properties)',
    'Clone: select a raster, Ctrl+click the place to copy from, then paint where the copy goes (width and feather are in the properties)',
    'Eyedropper: click a point to take its colour (left click: primary colour, right click: secondary colour)',
    'Eraser: select a raster, then paint over it: the secondary colour is left behind (an opaque one covers, a transparent one only tints, none erases); the primary colour is protected, within the tolerance');
var
  lbmp: TBitmap;
  t: TTool;
  tmpIcon: TBitmap;
  k: TConstraintKind;
  i: Integer;
  b: TSpeedButton;
  mi: TMenuItem;

  procedure AddArcItem(tool: TTool; const cap: string);
  var
    mi: TMenuItem;
  begin
    mi := TMenuItem.Create(ArcMenu);
    mi.Caption := cap;
    mi.Tag := Ord(tool);
    mi.RadioItem := True;
    mi.OnClick := @ArcMenuClick;
    ArcMenu.Items.Add(mi);
  end;

begin
  ToolButtons[tlSelect] := toolSelect;
  ToolButtons[tlLine] := toolLine;
  ToolButtons[tlArrow] := toolArrow;
  ToolButtons[tlPolyline] := toolPolyLine;
  ToolButtons[tlPolygon] := toolPolygon;
  ToolButtons[tlRect] := toolRect;
  ToolButtons[tlEllipse] := toolEllipse;
  ToolButtons[tlArc] := toolEllipticalArc;
  ToolButtons[tlSpline] := toolSpline;
  ToolButtons[tlText] := toolText;
  ToolButtons[tlSvgCode] := toolSVGcode;
  ToolButtons[tlRefLine] := referenceLine;
  ToolButtons[tlTrim] := toolTrim;
  ToolButtons[tlExtend] := toolExtend;
  ToolButtons[tlFillet] := toolFillet;
  ToolButtons[tlOffset] := toolOffset;
  ToolButtons[tlMirror] := toolMirror;
  ToolButtons[tlArray] := toolArray;
  ToolButtons[tlScale] := toolScale;
  ToolButtons[tlRotate] := toolRotate;
  ToolButtons[tlChamfer] := toolChamfer;
  ToolButtons[tlBreak] := toolBreak;
  ToolButtons[tlVectorize] := toolVectorize;
  ToolButtons[tlVertex] := toolVertex;
  ToolButtons[tlJoin] := toolJoin;
  ToolButtons[tlBucket] := toolBucket;
  ToolButtons[tlPen] := toolPen;
  ToolButtons[tlMarker] := toolMarker;
  ToolButtons[tlAirbrush] := toolAirbrush;
  ToolButtons[tlPathPoint] := toolPathPoint;
  ToolButtons[tlRoundRect] := toolRect;
  // the panel of the raster tools, next to the artistic tools
  RasterPanel := TPanel.Create(Self);
  RasterPanel.Parent := ArtisticPanel.Parent;
  RasterPanel.Align := alLeft;
  RasterPanel.Left := ArtisticPanel.Left + 20;
  RasterPanel.Width := 136;
  with TLabel.Create(Self) do
  begin
    Parent := RasterPanel;
    Caption := 'Raster Tools';
    SetBounds(4, 8, 88, 16);
  end;
  toolSelRect := TSpeedButton.Create(Self);
  toolSelRect.Parent := RasterPanel;
  toolSelRect.SetBounds(8, 26, 38, 31);
  toolSelRect.Enabled := False;
  toolSelEllipse := TSpeedButton.Create(Self);
  toolSelEllipse.Parent := RasterPanel;
  toolSelEllipse.SetBounds(48, 26, 38, 31);
  toolSelEllipse.Enabled := False;
  toolSelFree := TSpeedButton.Create(Self);
  toolSelFree.Parent := RasterPanel;
  toolSelFree.SetBounds(88, 26, 38, 31);
  toolSelFree.Enabled := False;
  toolWand := TSpeedButton.Create(Self);
  toolWand.Parent := RasterPanel;
  toolWand.SetBounds(8, 58, 38, 31);
  toolWand.Enabled := False;
  toolSelShape := TSpeedButton.Create(Self);
  toolSelShape.Parent := RasterPanel;
  toolSelShape.SetBounds(48, 58, 38, 31);
  toolSelShape.Enabled := False;
  toolRefPoint := TSpeedButton.Create(Self);
  toolRefPoint.Parent := ReferencePanel;
  toolRefPoint.SetBounds(referenceLine.Left, referenceLine.Top + 64, referenceLine.Width, referenceLine.Height);
  ToolButtons[tlRefPoint] := toolRefPoint;
  toolPicker := TSpeedButton.Create(Self);
  toolPicker.Parent := toolPen.Parent;
  toolPicker.SetBounds(toolPen.Left, toolPen.Top + 64, toolPen.Width, toolPen.Height);
  ToolButtons[tlPicker] := toolPicker;
  // the light on the materials of the layer
  toolLight := TSpeedButton.Create(Self);
  toolLight.Parent := toolPen.Parent;
  toolLight.SetBounds(toolPen.Left + 40, toolPen.Top + 64, toolPen.Width, toolPen.Height);
  toolLight.Hint := 'Light of the layer: direction, spread of the beam and dominant colour of the light that falls on its materials';
  toolLight.ShowHint := True;
  toolLight.Enabled := False;
  toolLight.OnClick := @LightClick;
  lbmp := TBitmap.Create;
  try
    lbmp.SetSize(26, 22);
    lbmp.Transparent := True;
    lbmp.TransparentColor := clFuchsia;
    lbmp.Canvas.Brush.Color := clFuchsia;
    lbmp.Canvas.FillRect(0, 0, 26, 22);
    lbmp.Canvas.Pen.Color := TColor($0090FF);
    lbmp.Canvas.Pen.Width := 2;
    lbmp.Canvas.Line(13, 1, 13, 5);
    lbmp.Canvas.Line(13, 17, 13, 21);
    lbmp.Canvas.Line(2, 11, 6, 11);
    lbmp.Canvas.Line(20, 11, 24, 11);
    lbmp.Canvas.Line(5, 3, 8, 6);
    lbmp.Canvas.Line(18, 16, 21, 19);
    lbmp.Canvas.Line(21, 3, 18, 6);
    lbmp.Canvas.Line(8, 16, 5, 19);
    lbmp.Canvas.Pen.Width := 1;
    lbmp.Canvas.Pen.Color := clBlack;
    lbmp.Canvas.Brush.Color := TColor($30D0FF);
    lbmp.Canvas.Ellipse(8, 6, 19, 17);
    toolLight.Glyph.Assign(lbmp);
  finally
    lbmp.Free;
  end;
  toolRegPoly := TSpeedButton.Create(Self);
  toolRegPoly.Parent := toolPolygon.Parent;
  toolRegPoly.SetBounds(128, 90, toolPolygon.Width, toolPolygon.Height);
  ToolButtons[tlRegPoly] := toolRegPoly;
  toolClone := TSpeedButton.Create(Self);
  toolClone.Parent := RasterPanel;
  toolClone.SetBounds(88, 58, 38, 31);
  toolClone.Enabled := False;
  ToolButtons[tlClone] := toolClone;
  toolEraser := TSpeedButton.Create(Self);
  toolEraser.Parent := RasterPanel;
  toolEraser.SetBounds(8, 90, 38, 31);
  toolEraser.Enabled := False;
  ToolButtons[tlEraser] := toolEraser;
  ToolButtons[tlSelRect] := toolSelRect;
  ToolButtons[tlSelEllipse] := toolSelEllipse;
  ToolButtons[tlSelFree] := toolSelFree;
  ToolButtons[tlWand] := toolWand;
  ToolButtons[tlSelShape] := toolSelShape;
  ToolButtons[tlSnippet] := TSpeedButton.Create(Self);      // never shown: the snippet buttons are in their own panel
  ToolButtons[tlArc3] := toolEllipticalArc;
  ToolButtons[tlArcCSE] := toolEllipticalArc;
  ArcMode := tlArc;
  PathPoints := 12;
  MenuPoint := -1;
  for t := Low(TTool) to High(TTool) do ToolHints[t] := Hints[t];
  for t := Low(TTool) to High(TTool) do
  begin
    if t in [tlArc3, tlArcCSE, tlRoundRect, tlSnippet] then Continue;       // same button as the elliptical arc / the rectangle
    b := ToolButtons[t];
    b.GroupIndex := 1;
    b.AllowAllUp := True;
    b.Tag := Ord(t);
    b.Hint := Hints[t];
    b.ShowHint := True;
    b.OnClick := @ToolClick;
    ApplyGlyph(b, t);
  end;
  toolSelect.Down := True;
  ArcMenu := TPopupMenu.Create(Self);
  AddArcItem(tlArc, 'Elliptical arc: drag the ellipse, then click start and end');
  AddArcItem(tlArc3, 'Arc by 3 points: two ends, then a point that sets the radius');
  AddArcItem(tlArcCSE, 'Arc by centre: centre, start, end');
  toolArcMenu := TSpeedButton.Create(Self);
  toolArcMenu.Parent := toolEllipticalArc.Parent;
  toolArcMenu.SetBounds(toolEllipticalArc.Left + toolEllipticalArc.Width + 1, toolEllipticalArc.Top, 14, toolEllipticalArc.Height);
  toolArcMenu.Caption := #$E2#$96#$BE;
  toolArcMenu.Font.Size := 7;
  toolArcMenu.Hint := 'Kind of arc';
  toolArcMenu.ShowHint := True;
  toolArcMenu.OnClick := @ArcMenuButtonClick;
  btnGroup := TSpeedButton.Create(Self);
  btnGroup.Parent := toolJoin.Parent;
  btnGroup.SetBounds(128, 90, 38, 31);
  btnGroup.Hint := 'Group: join the selected objects into one that moves and resizes as a whole (Ctrl+G)';
  btnGroup.ShowHint := True;
  btnGroup.OnClick := @GroupClick;
  btnUngroup := TSpeedButton.Create(Self);
  btnUngroup.Parent := toolJoin.Parent;
  btnUngroup.SetBounds(168, 90, 38, 31);
  btnUngroup.Hint := 'Ungroup: split the selected groups into their elements (Ctrl+Shift+G)';
  btnUngroup.ShowHint := True;
  btnUngroup.OnClick := @UngroupClick;
  ActionsPanel.Width := ActionsPanel.Width + 40;
  btnMerge := TSpeedButton.Create(Self);
  btnMerge.Parent := toolJoin.Parent;
  btnMerge.SetBounds(208, 90, 38, 31);
  btnMerge.Hint := 'Merge rasters: select two rasters; they become one, as large as needed to hold both';
  btnMerge.ShowHint := True;
  btnMerge.Enabled := False;
  btnMerge.OnClick := @MergeRastersClick;
  btnFlip := TSpeedButton.Create(Self);
  btnFlip.Parent := toolJoin.Parent;
  btnFlip.SetBounds(208, 26, 38, 31);
  btnFlip.Caption := #$E2#$86#$95;
  btnFlip.Tag := 1;
  btnFlip.Hint := 'Flip: turn the selected raster pictures or groups upside down (about their centre)';
  btnFlip.ShowHint := True;
  btnFlip.Enabled := False;
  btnFlip.OnClick := @FlipClick;
  btnMirror := TSpeedButton.Create(Self);
  btnMirror.Parent := toolJoin.Parent;
  btnMirror.SetBounds(208, 58, 38, 31);
  btnMirror.Caption := #$E2#$86#$94;
  btnMirror.Tag := 0;
  btnMirror.Hint := 'Mirror: swap left and right in the selected raster pictures or groups (about their centre)';
  btnMirror.ShowHint := True;
  btnMirror.Enabled := False;
  btnMirror.OnClick := @FlipClick;
  btnInvSel := TSpeedButton.Create(Self);
  btnInvSel.Parent := RasterPanel;
  btnInvSel.SetBounds(48, 90, 38, 31);
  btnInvSel.Caption := #$E2#$97#$91;
  btnInvSel.Hint := 'Invert selection: what is selected on the raster becomes what is not, and the other way round (with nothing selected: select all)';
  btnInvSel.ShowHint := True;
  btnInvSel.Enabled := False;
  btnInvSel.OnClick := @InvertSelClick;
  tmpIcon := MakeMergeIcon;
  try ApplyGlyphBmp(btnMerge, tmpIcon); finally tmpIcon.Free; end;
  tmpIcon := MakeGroupIcon(False);
  try ApplyGlyphBmp(btnGroup, tmpIcon); finally tmpIcon.Free; end;
  tmpIcon := MakeGroupIcon(True);
  try ApplyGlyphBmp(btnUngroup, tmpIcon); finally tmpIcon.Free; end;
  SetArcMode(tlArc);
  RectMode := tlRect;
  DefCorner := 12;
  DefSides := 5;
  CloneW := 30;
  CloneF := 50;
  toolRect.Width := 24;
  RectMenu := TPopupMenu.Create(Self);
  for t in [tlRect, tlRoundRect] do
  begin
    mi := TMenuItem.Create(RectMenu);
    if t = tlRect then mi.Caption := 'Rectangle' else mi.Caption := 'Rectangle with rounded corners';
    mi.Tag := Ord(t);
    mi.RadioItem := True;
    mi.OnClick := @RectMenuClick;
    RectMenu.Items.Add(mi);
  end;
  toolRectMenu := TSpeedButton.Create(Self);
  toolRectMenu.Parent := toolRect.Parent;
  toolRectMenu.SetBounds(toolRect.Left + toolRect.Width + 1, toolRect.Top, 14, toolRect.Height);
  toolRectMenu.Caption := #$E2#$96#$BE;
  toolRectMenu.Font.Size := 7;
  toolRectMenu.Hint := 'Kind of rectangle';
  toolRectMenu.ShowHint := True;
  toolRectMenu.OnClick := @RectMenuButtonClick;
  SetRectMode(tlRect);

  ConsButtons[ckFixed] := constFixed;
  ConsButtons[ckHorizontal] := constHoritzontal;
  ConsButtons[ckVertical] := constVertical;
  ConsButtons[ckParallel] := constParallel;
  ConsButtons[ckPerpendicular] := constPerpendicular;
  ConsButtons[ckEqual] := constEqual;
  ConsButtons[ckCoaxial] := constCoaxial;
  ConsButtons[ckCoradial] := constCoradial;
  ConsButtons[ckMidPoint] := constMidPoint;
  ConsButtons[ckIntersection] := constIntersection;
  ConsButtons[ckTangent] := constTangent;
  constSimmetry.Visible := False;       // the symmetry constraint has no button any more (files that have one still work)
  ConsButtons[ckDistance] := quoteLinear;
  ConsButtons[ckRadius] := quoteRadial;
  ConsButtons[ckAngle] := quoteAngular;
  for k := Low(TConstraintKind) to High(TConstraintKind) do
  begin
    b := ConsButtons[k];
    if b = nil then Continue;      // constraints made only by the snap have no button
    b.Tag := Ord(k);
    b.Hint := ConsHint[k];
    b.ShowHint := True;
    b.OnClick := @ConstraintClick;
    case k of
      ckDistance: b.Caption := '↔';
      ckRadius: b.Caption := 'R';
      ckAngle: b.Caption := '∠';
      ckHorizontal: b.Caption := 'H';
    else
      b.Caption := ConsSymbol[k];
    end;
    b.Font.Size := 9;
  end;
  // the ninth colour of the panel
  with TSpeedButton.Create(Self) do
  begin
    Name := 'colorButton9';
    Parent := colorButton8.Parent;
    SetBounds(colorButton8.Left + 40, colorButton8.Top, colorButton8.Width, colorButton8.Height);
  end;
  // the label "Colors" is a split menu: colours or materials
  for i := 0 to colorButton8.Parent.ControlCount - 1 do
    if (colorButton8.Parent.Controls[i] is TLabel) and (TLabel(colorButton8.Parent.Controls[i]).Caption = 'Colors') then
    begin
      TLabel(colorButton8.Parent.Controls[i]).Visible := False;
      ColorsMenuBtn := TSpeedButton.Create(Self);
      ColorsMenuBtn.Parent := colorButton8.Parent;
      ColorsMenuBtn.SetBounds(4, 3, 128, 22);
      ColorsMenuBtn.Flat := True;
      ColorsMenuBtn.Caption := 'Colors ' + #$E2#$96#$BE;
      ColorsMenuBtn.OnClick := @ColorsMenuClick;
      ColorsMenuBtn.Hint := 'Colors or materials';
      ColorsMenuBtn.ShowHint := True;
      Break;
    end;
  ColorsMenu := TPopupMenu.Create(Self);
  mi := TMenuItem.Create(ColorsMenu);
  mi.Caption := 'Colors';
  mi.Tag := 0;
  mi.RadioItem := True;
  mi.Checked := True;
  mi.OnClick := @PaletteModeClick;
  ColorsMenu.Items.Add(mi);
  mi := TMenuItem.Create(ColorsMenu);
  mi.Caption := 'Materials';
  mi.Tag := 1;
  mi.RadioItem := True;
  mi.OnClick := @PaletteModeClick;
  ColorsMenu.Items.Add(mi);
  for i := 1 to 9 do
  begin
    b := TSpeedButton(FindComponent('colorButton' + IntToStr(i)));
    b.Tag := i - 1;
    b.OnClick := @PaletteClick;
    b.PopupMenu := PopupMenu1;
    b.Hint := 'Click: stroke (primary) colour  -  Double click or Ctrl+click: fill (secondary) colour  -  Right click: change the swatch, assign as secondary colour';
    b.ShowHint := True;
  end;
  MenuItem1.OnClick := @PaletteMenuClick;
  MenuItem1.Caption := 'Change color...';
  mi := TMenuItem.Create(PopupMenu1);
  mi.Caption := 'Assign as secondary color (dbl click)';
  mi.OnClick := @PaletteSecondaryMenu;
  PopupMenu1.Items.Add(mi);
  if NewIcons then RelayoutToolButtons;
end;

procedure TForm1.SetTool(t: TTool);
var
  tt: TTool;
  txt: string;
  pr2, vl2: array of string;
  ts: TShapeArray;
  i: Integer;
begin
  // the offset is made at once on what is selected
  if t = tlOffset then
  begin
    OffsetSelected;
    Exit;
  end;
  // fillet and chamfer work at once on the two lines that are selected
  if t in [tlFillet, tlChamfer] then
  begin
    FilletSelected(t = tlChamfer);
    Exit;
  end;
  if Creating <> nil then CancelCreating;
  RotMode := False;
  FreeAndNil(AngPrev);
  Arc2N := 0;
  SnipStage := 0;
  FilletFirst := nil;
  BreakShape := 0;
  JoinFirst := 0;
  JoinRef := MakeRef(0, -1);
  OffsetFirst := nil;
  FreeActive := False;
  // an artistic tool draws with its own style: the usual defaults come back when it is left
  if ArtSwapped then
  begin
    ArtStyle[Tool] := DefStyle;
    DefStyle := SavedDef;
    ArtSwapped := False;
  end;
  SetLength(MirrorSrc, 0);
  if (t = tlMirror) or (t = tlArray) or (t = tlScale) or (t = tlRotate) then
  begin
    // objects selected before pressing the button are the ones to mirror / repeat
    ts := SelShapes;
    for i := 0 to High(ts) do
      if (t = tlArray) or (t = tlScale) or (t = tlRotate) or (ts[i].Kind in [skLine, skArrow, skPolyline, skPolygon, skRect, skEllipse, skArc, skSpline]) then
      begin
        SetLength(MirrorSrc, Length(MirrorSrc) + 1);
        MirrorSrc[High(MirrorSrc)] := ts[i].Id;
      end;
  end;
  if t in [tlWand, tlSelShape, tlSelRect, tlSelEllipse, tlSelFree, tlClone, tlEraser] then
  begin
    ts := SelShapes;
    for i := 0 to High(ts) do
      if ts[i].GroupId > 0 then Continue
      else if ts[i].Kind = skImage then ToolImg := ts[i].Id
      else if ts[i].SelTarget > 0 then ToolImg := ts[i].SelTarget;
  end;
  Tool := t;
  if CropActive and (t <> tlSelect) then CropFinish(False);
  if PersActive and (t <> tlSelect) then PersFinish(False);
  if t in [tlPen, tlMarker, tlAirbrush] then
  begin
    SavedDef := DefStyle;
    DefStyle := ArtStyle[t];
    ArtSwapped := True;
  end;
  UpdateActionStates;
  // the buttons are in different panels, so the radio behaviour is done by hand
  for tt := Low(TTool) to High(TTool) do
    if ToolButtons[tt] <> nil then ToolButtons[tt].Down := False;
  ToolButtons[t].Down := True;
  for i := 0 to High(SnipButtons) do SnipButtons[i].Down := (t = tlSnippet) and (i = SnipIdx);
  if t = tlSnippet then SetStatus('SVG snippet: click where it goes (its top left corner).');
  if t = tlEraser then SetStatus('Eraser: paint on the selected raster; the secondary colour is left behind, the primary colour is protected (within the tolerance).');
  if t = tlClone then SetStatus('Clone: Ctrl+click the place to copy from, then paint where the copy goes.');
  if t = tlWand then SetStatus('Magic wand: click on the raster; the area of a similar colour becomes a selection.');
  if t in [tlSelRect, tlSelEllipse, tlSelFree] then SetStatus('Selection: drag on the selected raster (Shift: add to the selection, Shift+Ctrl: subtract from it).');
  if t = tlSelShape then SetStatus('Selection from a figure: click a closed figure that lies on the raster.');
  if t = tlBucket then SetStatus('Paint bucket: click inside an area closed by lines or curves.');
  if t = tlPathPoint then SetStatus('Add point: click a point of the path where the new control point goes.');
  if t = tlVertex then SetStatus('Add joint: click a point of the line / side where the joint goes.');
  if t in [tlRect, tlRoundRect] then SetRectMode(t);
  if t in [tlArc, tlArc3, tlArcCSE] then
  begin
    SetArcMode(t);
    if t = tlArc3 then SetStatus('Arc by 3 points: click the first end.')
    else if t = tlArcCSE then SetStatus('Arc by centre: click the centre.');
  end;
  if t = tlJoin then
  begin
    // the selected figure keeps showing its points: first the point that moves, then the point it must reach
    SetStatus('Join: click the point of the selected figure that must move, then the point it must reach.');
  end;
  if t = tlOffset then
  begin
    txt := FloatToStr(OffsetDist, DefaultFormatSettings);
    if InputQuery('Offset', 'Distance of the parallel copy:', txt) then
      OffsetDist := Max(0.01, StrToFloatDef(StringReplace(StringReplace(txt, ',',
        DefaultFormatSettings.DecimalSeparator, []), '.', DefaultFormatSettings.DecimalSeparator, []), OffsetDist));
  end;
  if t = tlChamfer then
  begin
    SetLength(pr2, 2);
    SetLength(vl2, 2);
    pr2[0] := 'Distance from the corner on the first line';
    pr2[1] := 'Distance from the corner on the second line';
    vl2[0] := FloatToStr(ChamD1, DefaultFormatSettings);
    vl2[1] := FloatToStr(ChamD2, DefaultFormatSettings);
    if InputQuery('Chamfer', pr2, vl2) then
    begin
      ChamD1 := Max(0.5, ParseNum(vl2[0], ChamD1));
      ChamD2 := Max(0.5, ParseNum(vl2[1], ChamD2));
    end;
  end;
  if t = tlFillet then
  begin
    txt := FloatToStr(FilletRadius, DefaultFormatSettings);
    if InputQuery('Fillet', 'Radius of the rounded corner:', txt) then
      FilletRadius := Max(0.5, StrToFloatDef(StringReplace(StringReplace(txt, ',', DefaultFormatSettings.DecimalSeparator, []), '.',
        DefaultFormatSettings.DecimalSeparator, []), FilletRadius));
  end;
  if t <> tlSelect then
  begin
    if not (t in [tlPathPoint, tlVertex, tlJoin]) then SelClear;      // the figure stays selected while its point is chosen
    PaintBox1.Cursor := crCross;
  end
  else PaintBox1.Cursor := crDefault;
  RefreshProps;
  Redraw;
end;

procedure TForm1.ToolClick(Sender: TObject);
var
  i: Integer;
begin
  SetTool(TTool(TSpeedButton(Sender).Tag));
  if (Tool = tlMirror) and (Length(MirrorSrc) > 0) then
  begin
    // keep the picked objects highlighted
    SelSet(MakeRef(MirrorSrc[0], -1));
    for i := 1 to High(MirrorSrc) do SelToggle(MakeRef(MirrorSrc[i], -1));
    Redraw;
    SetStatus('Mirror: ' + IntToStr(Length(MirrorSrc)) + ' object(s) picked - now click the axis line.');
  end
  else if Tool = tlMirror then
    SetStatus('Mirror: click the object(s) to mirror (Shift+click for more), then click the axis line.')
  else if Tool = tlArray then ArrayStart
  else if Tool = tlScale then ScaleStart
  else if Tool = tlRotate then RotateStart;
end;

// the colour becomes the fill (secondary) colour of the selected objects and of the next ones
function TForm1.PalColorOf(idx: Integer): Integer;
begin
  if PalMat then Result := MaterialAvg(idx) else Result := Palette[idx];
end;

function TForm1.PalMatOf(idx: Integer): Integer;
begin
  if PalMat then Result := idx + 1 else Result := 0;
end;

// the panel shows colours or materials
procedure TForm1.SetPaletteMode(mat: Boolean);
var
  i: Integer;
  b: TSpeedButton;
begin
  PalMat := mat;
  if mat then ColorsMenuBtn.Caption := 'Materials ' + #$E2#$96#$BE else ColorsMenuBtn.Caption := 'Colors ' + #$E2#$96#$BE;
  ColorsMenu.Items[0].Checked := not mat;
  ColorsMenu.Items[1].Checked := mat;
  if mat then MenuItem1.Caption := 'Change material...' else MenuItem1.Caption := 'Change color...';
  for i := 0 to 8 do
  begin
    b := TSpeedButton(FindComponent('colorButton' + IntToStr(i + 1)));
    if b = nil then Continue;
    if mat then
    begin
      SetMatSwatch(b, i);
      b.Hint := MaterialNames[i] + '  -  Click: stroke (primary) material (a line becomes a tube)  -  Double click or Ctrl+click: fill (secondary) material (a surface)';
    end
    else
    begin
      SetSwatch(b, Palette[i]);
      b.Hint := 'Click: stroke (primary) colour  -  Double click or Ctrl+click: fill (secondary) colour  -  Right click: change the swatch, assign as secondary colour';
    end;
  end;
end;

procedure TForm1.PaletteModeClick(Sender: TObject);
begin
  SetPaletteMode(TMenuItem(Sender).Tag = 1);
end;

procedure TForm1.ColorsMenuClick(Sender: TObject);
var
  pt: TPoint;
begin
  pt := ColorsMenuBtn.ClientToScreen(Point(0, ColorsMenuBtn.Height));
  ColorsMenu.PopUp(pt.x, pt.y);
end;

procedure TForm1.PaletteSetFill(idx: Integer);
var
  ts: TShapeArray;
  i: Integer;
  col: Integer;
begin
  col := PalColorOf(idx);
  ts := TargetShapes;
  Checkpoint;
  DefStyle.Fill := col;
  DefStyle.FillMatId := PalMatOf(idx);
  for i := 0 to High(ts) do
  begin
    ts[i].Style.Fill := col;
    ts[i].Style.FillMatId := PalMatOf(idx);
  end;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.PaletteSecondaryMenu(Sender: TObject);
begin
  if PopupMenu1.PopupComponent is TSpeedButton then PaletteSetFill(TSpeedButton(PopupMenu1.PopupComponent).Tag);
end;

// a double click: the first click has already made the colour the stroke colour; that is taken back
procedure TForm1.PaletteDouble(Sender: TObject);
begin
  if PalUndoValid then
  begin
    DefStyle.Stroke := PalUndoStroke;
    DefStyle.StrokeMatId := PalUndoMat;
    if PalUndoDoc then DoUndo(nil);
    PalUndoValid := False;
  end;
  PaletteSetFill(TSpeedButton(Sender).Tag);
end;

procedure TForm1.PaletteClick(Sender: TObject);
var
  col: Integer;
  ts: TShapeArray;
  i, nUndo: Integer;
begin
  // two clicks on the same colour in a row: the fill (secondary) colour
  if (PalLastBtn = Sender) and (GetTickCount64 - PalLastTick < 450) then
  begin
    PalLastBtn := nil;
    PaletteDouble(Sender);
    Exit;
  end;
  PalLastBtn := Sender;
  PalLastTick := GetTickCount64;
  col := PalColorOf(TSpeedButton(Sender).Tag);
  ts := TargetShapes;
  PalUndoStroke := DefStyle.Stroke;
  PalUndoMat := DefStyle.StrokeMatId;
  nUndo := UndoStack.Count;
  Checkpoint;
  if (GetKeyState(VK_CONTROL) < 0) or (Tool = tlBucket) then
  begin
    DefStyle.Fill := col;
    DefStyle.FillMatId := PalMatOf(TSpeedButton(Sender).Tag);
    for i := 0 to High(ts) do
    begin
      ts[i].Style.Fill := col;
      ts[i].Style.FillMatId := PalMatOf(TSpeedButton(Sender).Tag);
    end;
  end
  else
  begin
    DefStyle.Stroke := col;
    DefStyle.StrokeMatId := PalMatOf(TSpeedButton(Sender).Tag);
    for i := 0 to High(ts) do
      if ts[i].Kind = skText then
      begin
        ts[i].Style.Fill := col;
        ts[i].Style.FillMatId := PalMatOf(TSpeedButton(Sender).Tag);
      end
      else
      begin
        ts[i].Style.Stroke := col;
        ts[i].Style.StrokeMatId := PalMatOf(TSpeedButton(Sender).Tag);
      end;
  end;
  Commit;
  PalUndoValid := (GetKeyState(VK_CONTROL) >= 0) and (Tool <> tlBucket);
  PalUndoDoc := UndoStack.Count > nUndo;
  RefreshProps;
  Redraw;
end;

procedure TForm1.PaletteMenuClick(Sender: TObject);
var
  b: TSpeedButton;
  col: TColor;
  pct: Double;
begin
  if PopupMenu1.PopupComponent is TSpeedButton then
  begin
    b := TSpeedButton(PopupMenu1.PopupComponent);
    if PalMat then
    begin
      MaterialDialog(b.Tag);
      Exit;
    end;
    col := Palette[b.Tag];
    pct := 100;
    if PickColor('Palette colour', col, pct, False) then
    begin
      Palette[b.Tag] := col;
      SetSwatch(b, col);
    end;
  end;
end;

procedure TForm1.PaletteColorMenu(Sender: TObject);
begin
end;

{ ================= undo ================= }

procedure TForm1.Checkpoint;
begin
  Before := DocToSVG(Doc, False, nil);
end;

procedure TForm1.Commit;
var
  cur: string;
  i: Integer;
  orphan: Boolean;
begin
  RotFlushPending;
  SyncSelFollow;
  // the selections of a picture that no longer exists have nothing to select
  orphan := False;
  for i := Doc.Shapes.Count - 1 downto 0 do
    if (Doc.Shapes[i].SelTarget > 0) and (Doc.FindShape(Doc.Shapes[i].SelTarget) = nil) then
    begin
      Doc.DeleteShape(Doc.Shapes[i]);
      orphan := True;
    end;
  if orphan then PurgeSelection;
  Doc.EnforceFilterRefs;
  cur := DocToSVG(Doc, False, nil);
  if cur <> Before then
  begin
    UndoStack.Add(Before);
    if UndoStack.Count > 100 then UndoStack.Delete(0);
    RedoStack.Clear;
    Modified := True;
    UpdateCaption;
    CheckBrokenFills;
    RefreshTree;
  end;
end;

procedure TForm1.PurgeSelection;
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to High(Sel) do
    if (Doc.FindShape(Sel[i].Shape) <> nil) and Doc.ShapeVisible(Doc.FindShape(Sel[i].Shape)) and
      not Doc.ShapeLocked(Doc.FindShape(Sel[i].Shape)) then
    begin
      Sel[n] := Sel[i];
      Inc(n);
    end;
  SetLength(Sel, n);
  if (SelQuote <> nil) and (Doc.Cons.IndexOf(SelQuote) < 0) then SelQuote := nil;
  HoverShape := nil;
  HoverQuote := nil;
  HighlightCons := nil;
end;

// after a change that adds or edits constraints: refuses it (and warns) when they cannot all hold
function TForm1.RejectIfInconsistent: Boolean;
var
  msg: string;
begin
  Result := False;
  if Doc.CheckConsistency(msg) then Exit;
  LoadState(Before);
  SetStatus('Conflicting constraints: the change was not applied.');
  MessageDlg('Conflicting constraints', msg + LineEnding + LineEnding + 'The change was not applied.',
    mtWarning, [mbOK], 0);
  Result := True;
end;

procedure TForm1.LoadState(const txt: string);
var
  ids: TIntArray;
begin
  FloatId := 0;
  FloatBase := 0;
  FlushAllImageCaches;
  SetLength(FrameMem, 0);       // the pictures and their selections come back together: nothing to follow
  SetLength(SelSigMem, 0);
  SVGToDoc(txt, Doc, False, 0, 0, ids);
  FlushAllImageCaches;
  // the tree of objects points to the old objects, which are gone: it is made again before anything else looks at it
  ObjSig := '';
  RefreshTree;
  PurgeSelection;
  UpdateBox;
  RefreshProps;
  RefreshLayers;
  RefreshTree;
  Redraw;
end;

procedure TForm1.DoUndo(Sender: TObject);
var
  txt: string;
begin
  RotMode := False;
  if UndoStack.Count = 0 then Exit;
  RedoStack.Add(DocToSVG(Doc, False, nil));
  txt := UndoStack[UndoStack.Count - 1];
  UndoStack.Delete(UndoStack.Count - 1);
  LoadState(txt);
  Modified := True;
  UpdateCaption;
end;

procedure TForm1.DoRedo(Sender: TObject);
var
  txt: string;
begin
  RotMode := False;
  if RedoStack.Count = 0 then Exit;
  UndoStack.Add(DocToSVG(Doc, False, nil));
  txt := RedoStack[RedoStack.Count - 1];
  RedoStack.Delete(RedoStack.Count - 1);
  LoadState(txt);
  Modified := True;
  UpdateCaption;
end;

{ ================= selection ================= }

function TForm1.SelFind(const r: TRef): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Sel) do
    if SameRef(Sel[i], r) then Exit(i);
  Result := -1;
end;

procedure TForm1.SelClear;
begin
  RotMode := False;
  PointEdit := False;
  SetLength(Sel, 0);
  SelQuote := nil;
end;

procedure TForm1.SelSet(const r: TRef);
begin
  SetLength(Sel, 1);
  Sel[0] := r;
  SelQuote := nil;
end;

procedure TForm1.SelToggle(const r: TRef);
var
  i: Integer;
begin
  SelQuote := nil;
  i := SelFind(r);
  if i >= 0 then
  begin
    Delete(Sel, i, 1);
  end
  else
  begin
    SetLength(Sel, Length(Sel) + 1);
    Sel[High(Sel)] := r;
  end;
end;

procedure TForm1.SelectAll(Sender: TObject);
var
  i: Integer;
begin
  SelClear;
  SetLength(Sel, 0);
  for i := 0 to Doc.Shapes.Count - 1 do
    if Interactive(Doc.Shapes[i]) then
    begin
      SetLength(Sel, Length(Sel) + 1);
      Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, -1);
    end;
  RefreshProps;
  Redraw;
end;

function IsOldSel(const old: TRefArray; id: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(old) do
    if old[i].Shape = id then Exit(True);
  Result := False;
end;

// the objects that were not selected become the selection, and the selected ones are left out
procedure TForm1.InvertSelection(Sender: TObject);
var
  i: Integer;
  old: TRefArray;
begin
  old := Copy(Sel);
  SelClear;
  SetLength(Sel, 0);
  RotMode := False;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Interactive(Doc.Shapes[i]) and not IsOldSel(old, Doc.Shapes[i].Id) then
    begin
      SetLength(Sel, Length(Sel) + 1);
      Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, -1);
    end;
  RefreshProps;
  Redraw;
end;

function TForm1.SelShapes: TShapeArray;
var
  i, j: Integer;
  s: TShape;
  dup: Boolean;
begin
  SetLength(Result, 0);
  for i := 0 to High(Sel) do
  begin
    s := Doc.FindShape(Sel[i].Shape);
    if s = nil then Continue;
    dup := False;
    for j := 0 to High(Result) do
      if Result[j] = s then dup := True;
    if not dup then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := s;
    end;
  end;
end;

// a shape that can be picked: its layer is visible and not locked
function TForm1.Interactive(s: TShape): Boolean;
begin
  Result := Doc.ShapeVisible(s) and not Doc.ShapeLocked(s);
end;

function TForm1.IsSelShape(s: TShape): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(Sel) do
    if Sel[i].Shape = s.Id then Exit(True);
  Result := False;
end;

function TForm1.IsActive(s: TShape): Boolean;
begin
  Result := IsSelShape(s) or (s = HoverShape);
end;

{ ================= groups ================= }

function ShapeBox(s: TShape; out x1, y1, x2, y2: Double): Boolean; forward;

// what a group is made of cannot be handled directly (its joints, points, sides...): the group is moved, turned, resized or
// ungrouped as a whole. The tools that pick one figure refuse the figures of a group, with the reason in the status bar
function TForm1.GroupPartBlocked(s: TShape; const what: string): Boolean;
begin
  Result := (s <> nil) and (s.GroupId > 0);
  if Result then SetStatus(what + ': this figure is part of a group, which can only be handled as a whole (ungroup it first).');
end;

// everything that shares a group with a selected shape is selected too
procedure TForm1.ExpandGroups;
var
  i, j: Integer;
  s: TShape;
  gids: array of Integer;
  found: Boolean;
begin
  SetLength(gids, 0);
  for i := 0 to High(Sel) do
  begin
    s := Doc.FindShape(Sel[i].Shape);
    if (s = nil) or (s.GroupId <= 0) then Continue;
    found := False;
    for j := 0 to High(gids) do
      if gids[j] = s.GroupId then found := True;
    if not found then
    begin
      SetLength(gids, Length(gids) + 1);
      gids[High(gids)] := s.GroupId;
    end;
  end;
  for j := 0 to High(gids) do
    for i := 0 to Doc.Shapes.Count - 1 do
      if (Doc.Shapes[i].GroupId = gids[j]) and Interactive(Doc.Shapes[i]) and
         (SelFind(MakeRef(Doc.Shapes[i].Id, -1)) < 0) then
      begin
        SetLength(Sel, Length(Sel) + 1);
        Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, -1);
      end;
end;

// the selection is one whole group: the ids of its shapes
function TForm1.SelGroupIds(out ids: TIntArray): Boolean;
var
  ts: TShapeArray;
  i, g: Integer;
begin
  Result := False;
  SetLength(ids, 0);
  ts := SelShapes;
  if Length(ts) = 0 then Exit;
  g := ts[0].GroupId;
  if g <= 0 then Exit;
  for i := 0 to High(ts) do
    if ts[i].GroupId <> g then Exit;
  SetLength(ids, Length(ts));
  for i := 0 to High(ts) do ids[i] := ts[i].Id;
  Result := True;
end;

// the box of the shapes of a group (reference objects, which are not drawn, do not count)
function TForm1.GroupBox(const ids: TIntArray; out x1, y1, x2, y2: Double): Boolean;
var
  i: Integer;
  s: TShape;
  a, b, c, d: Double;
begin
  Result := False;
  x1 := 1e18; y1 := 1e18; x2 := -1e18; y2 := -1e18;
  for i := 0 to High(ids) do
  begin
    s := Doc.FindShape(ids[i]);
    if (s = nil) or s.IsRef then Continue;
    if ShapeBox(s, a, b, c, d) then
    begin
      x1 := Min(x1, a);
      y1 := Min(y1, b);
      x2 := Max(x2, c);
      y2 := Max(y2, d);
      Result := True;
    end;
  end;
end;

procedure GroupHandlePoint(i: Integer; x1, y1, x2, y2: Double; out hx, hy: Double);
begin
  case i of
    0, 6, 7: hx := x1;
    2, 3, 4: hx := x2;
  else
    hx := (x1 + x2) / 2;
  end;
  case i of
    0, 1, 2: hy := y1;
    4, 5, 6: hy := y2;
  else
    hy := (y1 + y2) / 2;
  end;
end;

// how far the group has been turned
function TForm1.GroupAngle(const ids: TIntArray): Double;
begin
  Result := 0;
  if (Length(ids) > 0) and (Doc.FindShape(ids[0]) <> nil) then Result := Doc.FindShape(ids[0]).GroupRot;
end;

// the box of some shapes in a frame turned by ang: its centre (document coordinates) and half sizes
function TForm1.GroupFrame(const ids: TIntArray; ang: Double; out cx, cy, hw, hh: Double): Boolean;
var
  i, j, k: Integer;
  sh: TShape;
  o: TOutline;
  q, o0: TPt;
  u1, v1, u2, v2: Double;
begin
  Result := False;
  o0 := MakePt(0, 0);
  u1 := 1e18; v1 := 1e18; u2 := -1e18; v2 := -1e18;
  for i := 0 to High(ids) do
  begin
    sh := Doc.FindShape(ids[i]);
    if (sh = nil) or sh.IsRef then Continue;
    o := ShapeOutline(sh);
    for j := 0 to High(o) do
      for k := 0 to High(o[j].Pts) do
      begin
        q := TurnPt(o[j].Pts[k], o0, -ang);
        u1 := Min(u1, q.x);
        v1 := Min(v1, q.y);
        u2 := Max(u2, q.x);
        v2 := Max(v2, q.y);
        Result := True;
      end;
  end;
  if not Result then Exit;
  hw := (u2 - u1) / 2;
  hh := (v2 - v1) / 2;
  q := TurnPt(MakePt((u1 + u2) / 2, (v1 + v2) / 2), o0, ang);
  cx := q.x;
  cy := q.y;
end;

// a handle of a box (0 top left, going clockwise) in a frame turned by ang
function TForm1.FramePt(i: Integer; cx, cy, hw, hh, ang: Double): TPt;
var
  hx, hy: Double;
begin
  GroupHandlePoint(i, -hw, -hh, hw, hh, hx, hy);
  Result := MakePt(cx + hx * Cos(ang) + hy * Sin(ang), cy - hx * Sin(ang) + hy * Cos(ang));
end;

function TForm1.HitGroupHandle(px, py: Double): Integer;
var
  ids: TIntArray;
  cx, cy, hw, hh, ang: Double;
  i: Integer;
  p: TPt;
begin
  Result := -1;
  if (Tool <> tlSelect) or AllSelections(SelShapes) or AllRasterShapes(SelShapes) or not SelGroupIds(ids) then Exit;
  ang := GroupAngle(ids);
  if not GroupFrame(ids, ang, cx, cy, hw, hh) then Exit;
  for i := 0 to 7 do
  begin
    p := FramePt(i, cx, cy, hw, hh, ang);
    if Hypot(p.x - px, p.y - py) <= (HandleSize + 3) / Zoom then Exit(i);
  end;
end;

procedure TForm1.DrawGroupBox(cnv: TCanvas);
var
  ids: TIntArray;
  cx, cy, hw, hh, ang: Double;
  i: Integer;
  p: TPoint;
  pts: array[0..3] of TPoint;
begin
  if (Tool <> tlSelect) or (Creating <> nil) then Exit;
  if AllSelections(SelShapes) or AllRasterShapes(SelShapes) or not SelGroupIds(ids) then Exit;
  ang := GroupAngle(ids);
  if not GroupFrame(ids, ang, cx, cy, hw, hh) then Exit;
  for i := 0 to 3 do pts[i] := ScreenPt(FramePt(i * 2, cx, cy, hw, hh, ang));
  cnv.Pen.Style := psDash;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := ToCol(ColorSel);
  cnv.Brush.Style := bsClear;
  cnv.Polygon(pts);
  cnv.Pen.Style := psSolid;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := clWhite;
  for i := 0 to 7 do
  begin
    p := ScreenPt(FramePt(i, cx, cy, hw, hh, ang));
    cnv.Rectangle(p.x - HandleSize, p.y - HandleSize, p.x + HandleSize + 1, p.y + HandleSize + 1);
  end;
  cnv.Brush.Style := bsClear;
end;


// double click on a handle: the selection can be turned about the centre of its box with the mouse
// which objects are selected (the points chosen in them do not count)
function TForm1.SelIdSig: QWord;
var
  i: Integer;
begin
  Result := 14695981039346656037;
  for i := 0 to High(Sel) do
    Result := Result + QWord(Sel[i].Shape) * 2654435761;
end;

// the objects that show the handles that resize and turn them first (the handles of their points come with a double click):
// vector figures that are not tied to others
function TForm1.RotEligible(s: TShape): Boolean;
begin
  Result := not (s.IsRef or s.Bucket or (s.SelTarget > 0) or (s.GroupId > 0) or not Interactive(s) or (s.FA > 0) or
                 (s.OffSrc > 0) or (s.MirSrc > 0) or (s.ArrId > 0));
end;

// what the handles of an object that the pointer is over (and is not selected) are: the box that resizes and turns it
procedure TForm1.DrawHoverBox(cnv: TCanvas; s: TShape);
var
  ids: TIntArray;
  ang0, cx, cy, hw, hh: Double;
  sCX, sCY, sHW, sHH, sT: Double;
begin
  SetLength(ids, 1);
  ids[0] := s.Id;
  ang0 := 0;
  if RotKind(s.Kind) then ang0 := s.Rot;
  if not GroupFrame(ids, ang0, cx, cy, hw, hh) then Exit;
  sCX := RotCX; sCY := RotCY; sHW := RotHW; sHH := RotHH; sT := RotTotal;
  RotCX := cx; RotCY := cy; RotHW := hw; RotHH := hh; RotTotal := ang0;
  try
    DrawRotBox(cnv);
  finally
    RotCX := sCX; RotCY := sCY; RotHW := sHW; RotHH := sHH; RotTotal := sT;
  end;
end;

// a selected vector object shows first the handles that resize and turn it; those of its points come with a double click
procedure TForm1.AutoRotMode;
var
  ts: TShapeArray;
  i: Integer;
  sig: QWord;
begin
  if (Tool <> tlSelect) or (Creating <> nil) or (Length(Sel) = 0) or (SelQuote <> nil) or CropActive or PersActive or
     (Drag in [dmCreate, dmPoint, dmHandle, dmQuote, dmPage, dmBand, dmGroup, dmRotate, dmDeform, dmPix]) then Exit;
  sig := SelIdSig;
  if PointEdit and (sig <> PointEditSig) then PointEdit := False;
  if PointEdit or RotMode then Exit;
  for i := 0 to High(Sel) do
    if Sel[i].Idx <> -1 then Exit;
  ts := SelShapes;
  if Length(ts) = 0 then Exit;
  for i := 0 to High(ts) do
  begin
    if (ts[i].GroupId = 0) and not RotEligible(ts[i]) then Exit;
    if (ts[i].GroupId > 0) and not Interactive(ts[i]) then Exit;
  end;
  RotEnter(True);
end;

procedure TForm1.RotEnter(quiet: Boolean);
var
  ts: TShapeArray;
  i: Integer;
  ang0: Double;
  grp: TIntArray;
begin
  ts := SelShapes;
  SetLength(RotIds, 0);
  for i := 0 to High(ts) do
    if not ts[i].IsRef then
    begin
      SetLength(RotIds, Length(RotIds) + 1);
      RotIds[High(RotIds)] := ts[i].Id;
    end;
  if Length(RotIds) = 0 then Exit;
  // a line alone has only its two points to edit: resizing, turning and skewing make little sense for it
  if (Length(ts) = 1) and (ts[0].Kind = skLine) and (ts[0].GroupId = 0) then
  begin
    RotIds := nil;
    Exit;
  end;
  // the box is turned as the group is; a single turned shape has its own turn; anything else starts upright
  ang0 := 0;
  if SelGroupIds(grp) then ang0 := GroupAngle(grp)
  else if (Length(RotIds) = 1) and (Doc.FindShape(RotIds[0]) <> nil) and RotKind(Doc.FindShape(RotIds[0]).Kind) then
    ang0 := Doc.FindShape(RotIds[0]).Rot;
  if not GroupFrame(RotIds, ang0, RotCX, RotCY, RotHW, RotHH) then Exit;
  RotTotal := ang0;
  RotMode := True;
  RotSaveImages(True);
  if not quiet then
    SetStatus('Resize / turn: square handles stretch, diamond handles skew (Shift on a corner = keep proportions), ' +
      'the round handle turns the selection about its centre (Shift = steps of 15 degrees). Double-click a handle to edit the points.');
  Redraw;
end;

// is the point (document coordinates) in the part of the page that is on the screen, with room for a handle?
function TForm1.RotSpotVisible(const p: TPt): Boolean;
var
  m, x, y, x0, y0, x1, y1: Double;
begin
  m := HandleSize + 5;
  x := p.x * Zoom;
  y := p.y * Zoom;
  x0 := Max(0, ScrollBox1.HorzScrollBar.Position) + m;
  y0 := Max(0, ScrollBox1.VertScrollBar.Position) + m;
  x1 := Min(PaintBox1.Width, ScrollBox1.HorzScrollBar.Position + ScrollBox1.ClientWidth) - m;
  y1 := Min(PaintBox1.Height, ScrollBox1.VertScrollBar.Position + ScrollBox1.ClientHeight) - m;
  Result := (x >= x0) and (x <= x1) and (y >= y0) and (y <= y1);
end;

// the side of the box the turning handle sits at: the top one, unless the handle would be off the screen (a box that
// touches the top of the page, or is scrolled up) - then the bottom, the right or the left one
function TForm1.RotHandleSide: Integer;
const
  Sides: array[0..3] of Integer = (1, 5, 3, 7);
var
  k: Integer;
  d: Double;
  c, v: TPt;
  nx, ny: Double;
begin
  d := 28 / Zoom;
  for k := 0 to 3 do
  begin
    c := FramePt(Sides[k], RotCX, RotCY, RotHW, RotHH, RotTotal);
    case Sides[k] of
      1: begin nx := -Sin(RotTotal); ny := -Cos(RotTotal); end;
      5: begin nx := Sin(RotTotal); ny := Cos(RotTotal); end;
      3: begin nx := Cos(RotTotal); ny := -Sin(RotTotal); end;
    else
      begin nx := -Cos(RotTotal); ny := Sin(RotTotal); end;
    end;
    v := MakePt(c.x + d * nx, c.y + d * ny);
    if RotSpotVisible(v) then Exit(Sides[k]);
  end;
  Result := 1;
end;

function TForm1.RotHandlePt(i: Integer): TPt;
var
  d, nx, ny, x0, y0, x1, y1, m: Double;
  side: Integer;
begin
  if i = 8 then
  begin
    // the handle that turns: outside the box, above the middle of the top side (or at another side when that
    // place is not on the screen)
    d := 28 / Zoom;
    side := RotHandleSide;
    case side of
      1: begin nx := -Sin(RotTotal); ny := -Cos(RotTotal); end;
      5: begin nx := Sin(RotTotal); ny := Cos(RotTotal); end;
      3: begin nx := Cos(RotTotal); ny := -Sin(RotTotal); end;
    else
      begin nx := -Cos(RotTotal); ny := Sin(RotTotal); end;
    end;
    Result := FramePt(side, RotCX, RotCY, RotHW, RotHH, RotTotal);
    Result := MakePt(Result.x + d * nx, Result.y + d * ny);
    if not RotSpotVisible(Result) then
    begin
      // no side has room (a box larger than the window): the handle is kept on the screen anyway
      m := (HandleSize + 5) / Zoom;
      x0 := Max(0, ScrollBox1.HorzScrollBar.Position) / Zoom + m;
      y0 := Max(0, ScrollBox1.VertScrollBar.Position) / Zoom + m;
      x1 := Min(PaintBox1.Width, ScrollBox1.HorzScrollBar.Position + ScrollBox1.ClientWidth) / Zoom - m;
      y1 := Min(PaintBox1.Height, ScrollBox1.VertScrollBar.Position + ScrollBox1.ClientHeight) / Zoom - m;
      if x1 >= x0 then Result.x := Max(x0, Min(x1, Result.x));
      if y1 >= y0 then Result.y := Max(y0, Min(y1, Result.y));
    end;
  end
  else Result := FramePt(i, RotCX, RotCY, RotHW, RotHH, RotTotal);
end;

function TForm1.RotHit(px, py: Double): Integer;
var
  i: Integer;
  p: TPt;
begin
  Result := -1;
  if not RotMode then Exit;
  for i := 8 downto 0 do
  begin
    p := RotHandlePt(i);
    if Hypot(p.x - px, p.y - py) <= (HandleSize + 3) / Zoom then Exit(i);
  end;
end;

procedure TForm1.DrawRotBox(cnv: TCanvas);
var
  i: Integer;
  p: TPoint;
  c: TPoint;
  pts: array[0..3] of TPoint;
begin
  c := ScreenPt(MakePt(RotCX, RotCY));
  for i := 0 to 3 do pts[i] := ScreenPt(RotHandlePt(i * 2));
  cnv.Pen.Style := psDash;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := TColor($0090FF);
  cnv.Brush.Style := bsClear;
  cnv.Polygon(pts);
  cnv.Pen.Style := psSolid;
  cnv.Line(c.x - 6, c.y, c.x + 7, c.y);
  cnv.Line(c.x, c.y - 6, c.x, c.y + 7);
  cnv.Line(ScreenPt(FramePt(RotHandleSide, RotCX, RotCY, RotHW, RotHH, RotTotal)).x, ScreenPt(FramePt(RotHandleSide, RotCX, RotCY, RotHW, RotHH, RotTotal)).y,
    ScreenPt(RotHandlePt(8)).x, ScreenPt(RotHandlePt(8)).y);
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := TColor($0090FF);
  for i := 0 to 7 do
  begin
    p := ScreenPt(RotHandlePt(i));
    if i mod 2 = 0 then
      // corners: stretch
      cnv.Rectangle(p.x - HandleSize, p.y - HandleSize, p.x + HandleSize + 1, p.y + HandleSize + 1)
    else
      // sides: skew
      cnv.Polygon([Point(p.x - HandleSize - 1, p.y), Point(p.x, p.y - HandleSize - 1),
                   Point(p.x + HandleSize + 1, p.y), Point(p.x, p.y + HandleSize + 1)]);
  end;
  // the round handle turns
  p := ScreenPt(RotHandlePt(8));
  cnv.Ellipse(p.x - HandleSize, p.y - HandleSize, p.x + HandleSize + 1, p.y + HandleSize + 1);
  cnv.Brush.Style := bsClear;
end;

procedure TForm1.Ungroup(gid: Integer);
var
  i: Integer;
begin
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.Shapes[i].GroupId = gid then
    begin
      Doc.Shapes[i].GroupId := 0;
      Doc.Shapes[i].GroupRot := 0;
      Doc.Shapes[i].Snip := '';
      Doc.Shapes[i].GroupName := '';
    end;
end;

{ ================= hit testing ================= }

function TForm1.HandlesOf(s: TShape): THandleArray;

  procedure Add(idx: Integer; x, y: Double);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Idx := idx;
    Result[High(Result)].P := MakePt(x, y);
    Result[High(Result)].Ctl := False;
    Result[High(Result)].Anc := -1;
  end;

var
  i: Integer;
  x1, x2, a1: Double;
  pxs, pys: TDblArr;
  pctl: TBoolDyn;
  panc: TIntDyn;
begin
  SetLength(Result, 0);
  if s.GroupId > 0 then Exit;     // a group has the handles of its box
  if s.Bucket then Exit;          // a fill follows its boundaries: nothing to drag
  if (s.SelTarget > 0) and not ((s.Id = SelEditId) and PointEdit) then Exit;   // a selection of pixels is neither moved nor deformed as a shape (unless its outline is being edited)
  if s.Kind = skImage then Exit;  // nor is a raster: a double click gives it the handles of the second mode
  case s.Kind of
    skEllipse, skArc:
      if (s.Kind = skArc) and (s.FA > 0) then
      begin
        // the arc of a fillet: one handle, in the middle of the arc, that changes its radius (the rest follows the lines)
        a1 := s.A1 + ArcSweep(s) / 2;
        Add(HandleRX, s.P[0].x + s.RX * Cos(a1), s.P[0].y + s.RY * Sin(a1));
      end
      else
      begin
        Add(0, s.P[0].x, s.P[0].y);
        Add(HandleRX, s.P[0].x + s.RX, s.P[0].y);
        if not s.Circ then Add(HandleRY, s.P[0].x, s.P[0].y + s.RY);
        if s.Kind = skArc then
        begin
          Add(HandleA1, s.P[0].x + s.RX * Cos(s.A1), s.P[0].y + s.RY * Sin(s.A1));
          Add(HandleA2, s.P[0].x + s.RX * Cos(s.A2), s.P[0].y + s.RY * Sin(s.A2));
        end;
      end;
    skRect:
      begin
        for i := 0 to High(s.P) do Add(i, s.P[i].x, s.P[i].y);
        if Length(s.P) >= 2 then
        begin
          // the radius of the corners: on the top side, that far from the left end
          x1 := Min(s.P[0].x, s.P[1].x);
          x2 := Max(s.P[0].x, s.P[1].x);
          Add(HandleCorner, Min(x2, x1 + Max(CornerOf(s), 10 / Zoom)), Min(s.P[0].y, s.P[1].y));
        end;
      end;
  skPath:
    begin
      // the points of the path (the handle of its position is the last)
      if (Length(s.P) > 0) and IsActive(s) then
      begin
        s.PathHandles(pxs, pys, pctl, panc);
        for i := 0 to High(pxs) do
        begin
          Add(HandlePathBase + i, s.P[0].x + pxs[i], s.P[0].y + pys[i]);
          Result[High(Result)].Ctl := pctl[i];
          if pctl[i] and (panc[i] >= 0) then Result[High(Result)].Anc := HandlePathBase + panc[i];
        end;
      end;
      for i := 0 to High(s.P) do Add(i, s.P[i].x, s.P[i].y);
    end;
  else
    for i := 0 to High(s.P) do Add(i, s.P[i].x, s.P[i].y);
  end;
  // a turned shape: its handles are where its points are seen
  if (s.Rot <> 0) and RotKind(s.Kind) and (Length(s.P) > 0) then
    for i := 0 to High(Result) do Result[i].P := TurnPt(Result[i].P, ShapePivot(s), s.Rot);
end;

function TForm1.HitHandle(x, y: Double; out ref: TRef): Boolean;
var
  i, j: Integer;
  h: THandleArray;
  tol: Double;
begin
  Result := False;
  if RotMode and (Tool = tlSelect) then Exit;       // the handles of the points are not there
  tol := (HandleSize + 3) / Zoom;
  for i := Doc.Shapes.Count - 1 downto 0 do
  begin
    if not Interactive(Doc.Shapes[i]) then Continue;
    // an object that has the resizing handles first shows (and has) the ones of its points only when it is selected
    if RotEligible(Doc.Shapes[i]) and not IsSelShape(Doc.Shapes[i]) then Continue;
    h := HandlesOf(Doc.Shapes[i]);
    for j := 0 to High(h) do
    begin
      if (h[j].Idx >= HandleRX) and not IsActive(Doc.Shapes[i]) then Continue;
      if Hypot(h[j].P.x - x, h[j].P.y - y) <= tol then
      begin
        ref := MakeRef(Doc.Shapes[i].Id, h[j].Idx);
        Exit(True);
      end;
    end;
  end;
end;

function TForm1.HitShape(x, y: Double; out ref: TRef): Boolean;
begin
  Result := HitShapeCore(x, y, ref, False);
end;

// like HitShape, but an object that is selected wins over the ones on top of it: what is taken is what the user has selected
function TForm1.HitShapeSel(x, y: Double; out ref: TRef): Boolean;
begin
  Result := HitShapeCore(x, y, ref, True);
  if not Result then Result := HitShapeCore(x, y, ref, False);
end;

function TForm1.HitShapeCore(x, y: Double; out ref: TRef; onlySel: Boolean): Boolean;
var
  ordered: TShapeArray;
  i, j, seg: Integer;
  s: TShape;
  o: TOutline;
  d, tol, best, dd: Double;
  filled: Boolean;
begin
  Result := False;
  ordered := Doc.DrawOrder;          // the topmost shape first
  for i := High(ordered) downto 0 do
  begin
    s := ordered[i];
    if Doc.ShapeLocked(s) or (s.SelTarget > 0) then Continue;
    if onlySel and not IsSelShape(s) then Continue;
    if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    filled := (s.Style.Fill <> NoColor) or (s.Kind in [skText, skImage]) or s.Bucket or
              ((s.HatchPat > 0) and Hatchable(s));
    tol := Max(4, s.Style.Width / 2 + 3) / Zoom;
    if s.Spray then tol := Max(tol, s.SprayR * 0.6);
    d := DistToOutline(o, x, y, filled);
    if d <= tol then
    begin
      ref := MakeRef(s.Id, -1);
      if s.Kind in [skPolyline, skPolygon] then
      begin
        seg := -1;
        best := 1e18;
        for j := 0 to High(s.P) do
        begin
          if (s.Kind = skPolyline) and (j = High(s.P)) then Break;
          dd := DistToSegment(x, y, s.P[j].x, s.P[j].y, s.P[(j + 1) mod Length(s.P)].x,
            s.P[(j + 1) mod Length(s.P)].y);
          if dd < best then
          begin
            best := dd;
            seg := j;
          end;
        end;
        ref.Seg := seg;
      end
      else if s.Kind = skRect then
      begin
        // side of the rectangle: 0 top, 1 right, 2 bottom, 3 left
        best := Abs(y - Min(s.P[0].y, s.P[1].y));
        ref.Seg := 0;
        dd := Abs(x - Max(s.P[0].x, s.P[1].x));
        if dd < best then begin best := dd; ref.Seg := 1; end;
        dd := Abs(y - Max(s.P[0].y, s.P[1].y));
        if dd < best then begin best := dd; ref.Seg := 2; end;
        dd := Abs(x - Min(s.P[0].x, s.P[1].x));
        if dd < best then ref.Seg := 3;
      end;
      Exit(True);
    end;
  end;
end;

function TForm1.HitQuote(X, Y: Integer): TConstraint;
var
  i: Integer;
begin
  Result := nil;
  for i := High(QuoteHits) downto 0 do
    if PtInRect(QuoteHits[i].R, Point(X, Y)) then Exit(QuoteHits[i].C);
end;

// every point that can be snapped to: the stored points of the shapes, the four extreme points of
// circles / ellipses (their centre is the stored point) and the ends of arcs
procedure TForm1.EnumSnapPoints(exclude: TShape; out refs: TRefArray; out pts: TPtArray);
var
  i, j, n: Integer;
  s, tmp: TShape;
  q: TPt;

  procedure Add(const r: TRef; const p: TPt);
  begin
    if n >= Length(refs) then
    begin
      SetLength(refs, n + 64);
      SetLength(pts, n + 64);
    end;
    refs[n] := r;
    pts[n] := p;
    Inc(n);
  end;

begin
  n := 0;
  SetLength(refs, 64);
  SetLength(pts, 64);
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    s := Doc.Shapes[i];
    if (s = exclude) or s.Bucket or (s.GroupId > 0) or not Doc.ShapeVisible(s) then Continue;      // the parts of a group are not snap targets
    if (s.Rot <> 0) and RotKind(s.Kind) then Continue;       // the points it is made of are not where it is seen
    for j := 0 to High(s.P) do Add(MakeRef(s.Id, j), s.P[j]);
    if s.Kind = skEllipse then
    begin
      for j := EllSouthIdx to EllEastIdx do
        if Doc.ArcEndOf(MakeRef(s.Id, j), tmp, q) then Add(MakeRef(s.Id, j), q);
    end
    else if s.Kind = skArc then
    begin
      if Doc.ArcEndOf(MakeRef(s.Id, ArcStartIdx), tmp, q) then Add(MakeRef(s.Id, ArcStartIdx), q);
      if Doc.ArcEndOf(MakeRef(s.Id, ArcEndIdx), tmp, q) then Add(MakeRef(s.Id, ArcEndIdx), q);
    end;
  end;
  SetLength(refs, n);
  SetLength(pts, n);
end;

// the straight sides (lines, sides of poly-lines, polygons and rectangles) that pass within tol of (x, y)
// The middle of a side, and the point where two of those sides cross, are snap points: the ref that comes back is the side
// (the Seg field says what the point is: -2 the middle of the side, <= -3 the crossing with another side, see AddSnapConstraint)
function TForm1.SnapDerived(x, y: Double; exclude: TShape; tol: Double; out ref: TRef; out pt: TPt): Boolean;
var
  i, j, k, n, nseg, m: Integer;
  s: TShape;
  r: TRef;
  a, b: TPR;
  sr: TRefArray;
  ax, ay, bx, by: TDblArr;
  best, d, dx1, dy1, dx2, dy2, den, t1, t2, ix, iy: Double;
  eps: Double;
begin
  Result := False;
  best := 1e18;
  n := 0;
  SetLength(sr, 0);
  SetLength(ax, 0);
  SetLength(ay, 0);
  SetLength(bx, 0);
  SetLength(by, 0);
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    s := Doc.Shapes[i];
    if (s = exclude) or s.Bucket or (s.GroupId > 0) or not Doc.ShapeVisible(s) then Continue;
    if (s.Rot <> 0) and RotKind(s.Kind) then Continue;
    if s.Kind = skLine then nseg := 1
    else if s.Kind = skPolygon then nseg := Length(s.P)
    else if s.Kind = skPolyline then nseg := Length(s.P) - 1
    else if (s.Kind = skRect) and (Length(s.P) = 4) then nseg := 4
    else Continue;
    for j := 0 to nseg - 1 do
    begin
      if s.Kind = skLine then r := MakeRef(s.Id, -1) else r := MakeRef(s.Id, SegBase + j);
      if not Doc.SegOf(r, a, b) then Continue;
      if Hypot(a.S.P[a.I].x - b.S.P[b.I].x, a.S.P[a.I].y - b.S.P[b.I].y) < 1e-6 then Continue;
      if DistToSegment(x, y, a.S.P[a.I].x, a.S.P[a.I].y, b.S.P[b.I].x, b.S.P[b.I].y) > tol then Continue;
      SetLength(sr, n + 1);
      SetLength(ax, n + 1);
      SetLength(ay, n + 1);
      SetLength(bx, n + 1);
      SetLength(by, n + 1);
      sr[n] := r;
      ax[n] := a.S.P[a.I].x;
      ay[n] := a.S.P[a.I].y;
      bx[n] := b.S.P[b.I].x;
      by[n] := b.S.P[b.I].y;
      Inc(n);
    end;
  end;
  // the middle of each side
  for i := 0 to n - 1 do
  begin
    ix := (ax[i] + bx[i]) / 2;
    iy := (ay[i] + by[i]) / 2;
    d := Hypot(ix - x, iy - y);
    if (d <= tol) and (d < best) then
    begin
      best := d;
      ref := MakeRef(sr[i].Shape, sr[i].Idx, -2);
      pt := MakePt(ix, iy);
      Result := True;
    end;
  end;
  // the crossing of two sides (of different objects)
  eps := 1e-9;
  for i := 0 to n - 1 do
    for k := i + 1 to n - 1 do
    begin
      if sr[i].Shape = sr[k].Shape then Continue;
      dx1 := bx[i] - ax[i];
      dy1 := by[i] - ay[i];
      dx2 := bx[k] - ax[k];
      dy2 := by[k] - ay[k];
      den := dx1 * dy2 - dy1 * dx2;
      if Abs(den) < 1e-9 then Continue;
      t1 := ((ax[k] - ax[i]) * dy2 - (ay[k] - ay[i]) * dx2) / den;
      t2 := ((ax[k] - ax[i]) * dy1 - (ay[k] - ay[i]) * dx1) / den;
      if (t1 < -eps) or (t1 > 1 + eps) or (t2 < -eps) or (t2 > 1 + eps) then Continue;
      ix := ax[i] + t1 * dx1;
      iy := ay[i] + t1 * dy1;
      d := Hypot(ix - x, iy - y);
      if (d <= tol) and (d < best) then
      begin
        best := d;
        if sr[k].Idx = -1 then m := 0 else m := sr[k].Idx - SegBase + 1;
        ref := MakeRef(sr[i].Shape, sr[i].Idx, -(3 + sr[k].Shape * 8192 + m));
        pt := MakePt(ix, iy);
        Result := True;
      end;
    end;
end;

function TForm1.SnapTo(x, y: Double; exclude: TShape; out ref: TRef; out pt: TPt): Boolean;
var
  i, j, nseg: Integer;
  s: TShape;
  tol, d, best, ax, ay, bx, by, l2, t, ux, uy, len, ct, st, r, ang, sw: Double;
  refs: TRefArray;
  pts: TPtArray;
begin
  Result := False;
  best := 1e18;
  tol := 9 / Zoom;
  EnumSnapPoints(exclude, refs, pts);
  for i := 0 to High(refs) do
  begin
    d := Hypot(pts[i].x - x, pts[i].y - y);
    if (d <= tol) and (d < best) then
    begin
      best := d;
      ref := refs[i];
      pt := pts[i];
      Result := True;
    end;
  end;
  if Result then
  begin
    SnapAt := pt;
    Exit;
  end;
  // the middle of a side and the crossing of two straight sides also attract
  if SnapDerived(x, y, exclude, tol, ref, pt) then
  begin
    SnapAt := pt;
    Result := True;
    Exit;
  end;
  // with "snap to lines" on, any point of a line (also a reference line), of a side of a
  // poly-line / polygon or of a circle / ellipse / arc attracts: a constraint keeps the point there
  if (toolSnapLine = nil) or not toolSnapLine.Down then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    s := Doc.Shapes[i];
    if (s = exclude) or s.Bucket or (s.GroupId > 0) or not Doc.ShapeVisible(s) then Continue;      // the parts of a group are not snap targets
    if (s.Rot <> 0) and RotKind(s.Kind) then Continue;
    if s.Kind in [skLine, skPolyline, skPolygon] then
    begin
      if s.Kind = skLine then nseg := 1
      else if s.Kind = skPolygon then nseg := Length(s.P)
      else nseg := Length(s.P) - 1;
      for j := 0 to nseg - 1 do
      begin
        ax := s.P[j].x;
        ay := s.P[j].y;
        bx := s.P[(j + 1) mod Length(s.P)].x;
        by := s.P[(j + 1) mod Length(s.P)].y;
        d := DistToSegment(x, y, ax, ay, bx, by);
        if (d <= tol) and (d < best) then
        begin
          l2 := (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
          if l2 < 1e-12 then Continue;
          t := Max(0, Min(1, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / l2));
          best := d;
          if s.Kind = skLine then ref := MakeRef(s.Id, -1) else ref := MakeRef(s.Id, SegBase + j);
          pt := MakePt(ax + t * (bx - ax), ay + t * (by - ay));
          Result := True;
        end;
      end;
    end
    else if (s.Kind in [skEllipse, skArc]) and (Length(s.P) > 0) then
    begin
      ux := x - s.P[0].x;
      uy := y - s.P[0].y;
      len := Hypot(ux, uy);
      if len < 1e-6 then Continue;
      ct := ux / len;
      st := uy / len;
      if s.Circ then r := s.RX
      else r := 1 / Sqrt(Sqr(ct / Max(s.RX, 1e-6)) + Sqr(st / Max(s.RY, 1e-6)));
      d := Abs(len - r);
      if (d > tol) or (d >= best) then Continue;
      if s.Kind = skArc then
      begin
        // only the drawn part of an arc attracts
        ang := ArcTan2(uy / Max(s.RY, 1e-6), ux / Max(s.RX, 1e-6)) - s.A1;
        while ang < 0 do ang := ang + 2 * Pi;
        while ang >= 2 * Pi do ang := ang - 2 * Pi;
        sw := ArcSweep(s);
        if ang > sw then Continue;
      end;
      best := d;
      ref := MakeRef(s.Id, -1);
      pt := MakePt(s.P[0].x + ct * r, s.P[0].y + st * r);
      Result := True;
    end;
  end;
  if Result then SnapAt := pt;
end;

function TForm1.PageEdgeAt(X, Y: Integer): Integer;
var
  w, h: Integer;
  nearR, nearB: Boolean;
begin
  // 1 = right edge, 2 = bottom edge, 3 = corner
  w := Round(Doc.Width * Zoom);
  h := Round(Doc.Height * Zoom);
  nearR := (Abs(X - w) <= 6) and (Y <= h + 6);
  nearB := (Abs(Y - h) <= 6) and (X <= w + 6);
  if nearR and nearB then Result := 3
  else if nearR then Result := 1
  else if nearB then Result := 2
  else Result := 0;
end;

{ ================= rendering ================= }

function TForm1.ScreenPt(const p: TPt): TPoint;
begin
  Result.x := Round(p.x * Zoom);
  Result.y := Round(p.y * Zoom);
end;

procedure TForm1.ApplyPen(cnv: TCanvas; const st: TStyle; z: Double);
begin
  with cnv.Pen do
  begin
    if st.Stroke = NoColor then
    begin
      Style := psClear;
      Exit;
    end;
    Color := ToCol(st.Stroke);
    Width := Max(1, Round(st.Width * z));
    Cosmetic := False;
    case st.Dash of
      dsDash: Style := psDash;
      dsDot: Style := psDot;
      dsDashDot: Style := psDashDot;
    else
      Style := psSolid;
    end;
    case st.Cap of
      lcFlat: EndCap := pecFlat;
      lcRound: EndCap := pecRound;
      lcSquare: EndCap := pecSquare;
    end;
    case st.Join of
      ljMiter: JoinStyle := pjsMiter;
      ljRound: JoinStyle := pjsRound;
      ljBevel: JoinStyle := pjsBevel;
    end;
  end;
end;

function TForm1.RawImage(s: TShape): TGraphic;
var
  png: TPortableNetworkGraphic;
  ss: TStringStream;
begin
  if s.Cache = nil then
  begin
    png := TPortableNetworkGraphic.Create;
    try
      ss := TStringStream.Create(DecodeStringBase64(s.ImageData));
      try
        png.LoadFromStream(ss);
      finally
        ss.Free;
      end;
    except
      FreeAndNil(png);
    end;
    s.Cache := png;
  end;
  Result := TGraphic(s.Cache);
end;

// a picture that is turned: each pixel of the turned box takes its colour from the picture (bilinear), over what is there
procedure TForm1.DrawTurnedImage(cnv: TCanvas; s: TShape; g: TGraphic; z: Double);
var
  o: TOutline;
  i, j, x, y, w, h, x0, y0, ix, iy: Integer;
  bx1, by1, bx2, by2, u, v, fx, fy, a, wgt: Double;
  c: TPt;
  srcB, dstB: TBitmap;
  si, di: TLazIntfImage;
  c00, c10, c01, c11, dc: TFPColor;
  cs, sn, hw, hh, px, py, dx, dy: Double;

  function Mix(p, q, r, t: Word; fx2, fy2: Double): Word;
  begin
    Result := Round((p * (1 - fx2) + q * fx2) * (1 - fy2) + (r * (1 - fx2) + t * fx2) * fy2);
  end;

begin
  o := ShapeOutline(s);
  bx1 := 1e18; by1 := 1e18; bx2 := -1e18; by2 := -1e18;
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      bx1 := Min(bx1, o[i].Pts[j].x * z);
      by1 := Min(by1, o[i].Pts[j].y * z);
      bx2 := Max(bx2, o[i].Pts[j].x * z);
      by2 := Max(by2, o[i].Pts[j].y * z);
    end;
  x0 := Floor(bx1);
  y0 := Floor(by1);
  w := Ceil(bx2) - x0 + 1;
  h := Ceil(by2) - y0 + 1;
  if (w <= 0) or (h <= 0) or (w > 5000) or (h > 5000) then Exit;
  c := ShapePivot(s);
  hw := Abs(s.P[1].x - s.P[0].x) / 2;
  hh := Abs(s.P[1].y - s.P[0].y) / 2;
  if (hw < 1e-9) or (hh < 1e-9) then Exit;
  cs := Cos(s.Rot);
  sn := Sin(s.Rot);
  srcB := TBitmap.Create;
  dstB := TBitmap.Create;
  try
    srcB.Assign(g);
    dstB.SetSize(w, h);
    dstB.Canvas.CopyRect(Rect(0, 0, w, h), cnv, Rect(x0, y0, x0 + w, y0 + h));
    si := srcB.CreateIntfImage;
    di := dstB.CreateIntfImage;
    try
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          // the point of the document, taken back by the turn, as a fraction of the picture
          px := (x0 + x + 0.5) / z - c.x;
          py := (y0 + y + 0.5) / z - c.y;
          dx := px * cs - py * sn;
          dy := px * sn + py * cs;
          u := (dx + hw) / (2 * hw) * si.Width - 0.5;
          v := (dy + hh) / (2 * hh) * si.Height - 0.5;
          if (u < -0.5) or (v < -0.5) or (u > si.Width - 0.5) or (v > si.Height - 0.5) then Continue;
          u := Max(0, Min(si.Width - 1, u));
          v := Max(0, Min(si.Height - 1, v));
          ix := Min(si.Width - 2, Trunc(u));
          iy := Min(si.Height - 2, Trunc(v));
          if ix < 0 then ix := 0;
          if iy < 0 then iy := 0;
          fx := u - ix;
          fy := v - iy;
          if si.Width < 2 then fx := 0;
          if si.Height < 2 then fy := 0;
          c00 := si.Colors[ix, iy];
          c10 := si.Colors[Min(ix + 1, si.Width - 1), iy];
          c01 := si.Colors[ix, Min(iy + 1, si.Height - 1)];
          c11 := si.Colors[Min(ix + 1, si.Width - 1), Min(iy + 1, si.Height - 1)];
          a := Mix(c00.alpha, c10.alpha, c01.alpha, c11.alpha, fx, fy) / 65535;
          if a <= 0 then Continue;
          wgt := a;
          dc := di.Colors[x, y];
          dc.red := Round(dc.red * (1 - wgt) + Mix(c00.red, c10.red, c01.red, c11.red, fx, fy) * wgt);
          dc.green := Round(dc.green * (1 - wgt) + Mix(c00.green, c10.green, c01.green, c11.green, fx, fy) * wgt);
          dc.blue := Round(dc.blue * (1 - wgt) + Mix(c00.blue, c10.blue, c01.blue, c11.blue, fx, fy) * wgt);
          di.Colors[x, y] := dc;
        end;
      dstB.LoadFromIntfImage(di);
    finally
      di.Free;
      si.Free;
    end;
    cnv.Draw(x0, y0, dstB);
  finally
    dstB.Free;
    srcB.Free;
  end;
end;

procedure TForm1.RenderShapeCore(cnv: TCanvas; s: TShape; st0: TStyle; z: Double; editView: Boolean; part: Integer);
var
  o: TOutline;
  i, j: Integer;
  pts: array of TPoint;
  st: TStyle;
  haloStyle: TStyle;
  isSel, isHover: Boolean;
  head: TPtArray;
  r: TRect;
  g: TGraphic;
  lps: TFLoopArray;
  bp: TFPtArray;
  nClosed: Integer;

  function Conv(const pl: TPolyline): TPointArr;
  var
    k: Integer;
  begin
    SetLength(Result, Length(pl.Pts));
    for k := 0 to High(pl.Pts) do
    begin
      Result[k].x := Round(pl.Pts[k].x * z);
      Result[k].y := Round(pl.Pts[k].y * z);
    end;
  end;

  procedure Stroke(const pl: TPolyline; const pp: TPointArr);
  begin
    if Length(pp) < 2 then Exit;
    cnv.Brush.Style := bsClear;
    if pl.Closed then cnv.Polygon(pp) else cnv.Polyline(pp);
  end;

begin
  // part: 0 everything, 1 only the halo, 2 only the fill (text: the text), 3 only the stroke
  st := st0;
  if s.Spray then st.Stroke := NoColor;        // the airbrush shows only its dots
  isSel := editView and IsSelShape(s);
  isHover := editView and (s = HoverShape) and not isSel;
  if editView and ((isSel and not SelHaloPre) or isHover) and (part in [0, 1]) then
  begin
    haloStyle := st;
    haloStyle.Stroke := IfThen(isSel, $FFD9A8, $FBE8D2);
    haloStyle.Width := Max(st.Width, 1) + 7 / z;
    haloStyle.Dash := dsSolid;
    haloStyle.Cap := lcRound;
    haloStyle.Join := ljRound;
    ApplyPen(cnv, haloStyle, z);
    cnv.Brush.Style := bsClear;
    o := ShapeOutline(s);
    for i := 0 to High(o) do
    begin
      pts := Conv(o[i]);
      if Length(pts) >= 2 then
        if o[i].Closed and (s.Kind in [skRect, skEllipse, skPolygon]) then cnv.Polygon(pts) else cnv.Polyline(pts);
    end;
  end;
  if part = 1 then Exit;
  if editView and s.IsRef then
  begin
    st.Stroke := ColorSel;
    st.Width := 1;
    st.Dash := dsDash;
    st.Fill := NoColor;
    if (s.Kind = skPolyline) and (Length(s.P) = 1) then
    begin
      st.Dash := dsSolid;      // a reference point: a small solid cross
      st.Width := 2;
    end;
  end;

  case s.Kind of
    skText:
      if part in [0, 2] then
      begin
        cnv.Font.Height := -Max(2, Round(s.FontSize * z));
        if s.FontName <> '' then cnv.Font.Name := s.FontName else cnv.Font.Name := 'default';
        if st.Fill <> NoColor then cnv.Font.Color := ToCol(st.Fill) else cnv.Font.Color := clBlack;
        cnv.Brush.Style := bsClear;
        cnv.Font.Orientation := Round(s.Rot * 1800 / Pi);
        cnv.TextOut(Round(s.P[0].x * z), Round(s.P[0].y * z), s.Text);
        cnv.Font.Orientation := 0;
        cnv.Font.Name := 'default';
      end;
    skImage:
      if part = 0 then
      begin
        g := ImageOf(s);
        r := Rect(Round(Min(s.P[0].x, s.P[1].x) * z), Round(Min(s.P[0].y, s.P[1].y) * z),
          Round(Max(s.P[0].x, s.P[1].x) * z), Round(Max(s.P[0].y, s.P[1].y) * z));
        if (g <> nil) and (s.Rot <> 0) and AlphaOK then DrawTurnedImage(cnv, s, g, z)
        else if g <> nil then cnv.StretchDraw(r, g)
        else
        begin
          cnv.Brush.Style := bsClear;
          cnv.Pen.Color := clRed;
          cnv.Rectangle(r);
        end;
        if editView and s.IsRef then
        begin
          // reference picture: marked by a dashed frame (never printed or exported)
          cnv.Brush.Style := bsClear;
          cnv.Pen.Color := TColor($C08040);
          cnv.Pen.Style := psDash;
          cnv.Pen.Width := 1;
          cnv.Rectangle(r);
          cnv.Pen.Style := psSolid;
        end;
      end;
  else
    o := ShapeOutline(s);
    // fill pass
    if (st.Fill <> NoColor) and (part in [0, 2]) then
    begin
      cnv.Brush.Style := bsSolid;
      cnv.Brush.Color := ToCol(st.Fill);
      cnv.Pen.Style := psClear;
      nClosed := 0;
      for i := 0 to High(o) do
        if o[i].Closed and (Length(o[i].Pts) >= 3) then Inc(nClosed);
      if nClosed > 1 then
      begin
        // an outline with holes: the closed curves are joined into one polygon by thin bridges
        SetLength(lps, Length(o));
        for i := 0 to High(o) do
        begin
          SetLength(lps[i].Pts, Length(o[i].Pts));
          for j := 0 to High(o[i].Pts) do
          begin
            lps[i].Pts[j].x := o[i].Pts[j].x;
            lps[i].Pts[j].y := o[i].Pts[j].y;
          end;
        end;
        bp := BridgeLoops(lps);
        SetLength(pts, Length(bp));
        for j := 0 to High(bp) do
        begin
          pts[j].x := Round(bp[j].x * z);
          pts[j].y := Round(bp[j].y * z);
        end;
        if Length(pts) >= 3 then cnv.Polygon(pts);
      end
      else
        for i := 0 to High(o) do
        begin
          pts := Conv(o[i]);
          if Length(pts) >= 3 then cnv.Polygon(pts);
        end;
    end;
    // stroke pass
    if part in [0, 3] then
    begin
    ApplyPen(cnv, st, z);
    if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    for i := 0 to High(o) do
    begin
      pts := Conv(o[i]);
      Stroke(o[i], pts);
    end;
    end;
    if (part in [0, 3]) and (s.Kind = skArrow) and (Length(s.P) >= 2) then
    begin
      head := ArrowHead(s.P[0], s.P[1], st.Width);
      SetLength(pts, 3);
      for j := 0 to 2 do
      begin
        pts[j].x := Round(head[j].x * z);
        pts[j].y := Round(head[j].y * z);
      end;
      cnv.Pen.Style := psSolid;
      cnv.Pen.Width := 1;
      cnv.Pen.Color := ToCol(st.Stroke);
      cnv.Brush.Style := bsSolid;
      cnv.Brush.Color := ToCol(st.Stroke);
      cnv.Polygon(pts);
      cnv.Brush.Style := bsClear;
    end;
  end;
end;

// screen rectangle that a shape can touch (with its stroke and arrow head)
function TForm1.ShapeScreenBox(s: TShape; z: Double): TRect;
var
  o: TOutline;
  i, j: Integer;
  x1, y1, x2, y2, m: Double;
begin
  x1 := 1e300; y1 := 1e300; x2 := -1e300; y2 := -1e300;
  if s.Kind = skText then
  begin
    x1 := s.P[0].x;
    y1 := s.P[0].y;
    x2 := x1 + Max(1, Length(s.Text)) * s.FontSize * 0.9;
    y2 := y1 + s.FontSize * 1.6;
  end
  else
  begin
    if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    for i := 0 to High(o) do
      for j := 0 to High(o[i].Pts) do
      begin
        x1 := Min(x1, o[i].Pts[j].x);
        y1 := Min(y1, o[i].Pts[j].y);
        x2 := Max(x2, o[i].Pts[j].x);
        y2 := Max(y2, o[i].Pts[j].y);
      end;
  end;
  if x1 > x2 then
  begin
    Result := Rect(0, 0, 0, 0);
    Exit;
  end;
  m := (Max(s.Style.Width, 1) * 3 + 14) / 1;
  Result := Rect(Floor(x1 * z - m * z), Floor(y1 * z - m * z), Ceil(x2 * z + m * z), Ceil(y2 * z + m * z));
  if Result.Left < AlphaX0 then Result.Left := AlphaX0;
  if Result.Top < AlphaY0 then Result.Top := AlphaY0;
  if Result.Right > AlphaX0 + AlphaW then Result.Right := AlphaX0 + AlphaW;
  if Result.Bottom > AlphaY0 + AlphaH then Result.Bottom := AlphaY0 + AlphaH;
end;

// The same coverage made in memory (BGRABitmap): no drawing on a mask of the display and no reading it back, which
// are slow with gtk2. Only for the shapes that are lines and areas (not texts and pictures).
function TForm1.PartCoverageSW(s: TShape; z: Double; part: Integer; const bb: TRect): TByteDyn;
var
  w, h, i, j, x, y, nClosed: Integer;
  bmp: TBGRABitmap;
  o: TOutline;
  pts: array of TPointF;
  lps: TFLoopArray;
  bp: TFPtArray;
  head: TPtArray;
  px: PBGRAPixel;
  pw: Single;
  st: TStyle;

  procedure Conv(const pl: TPolyline);
  var
    k: Integer;
  begin
    SetLength(pts, Length(pl.Pts));
    for k := 0 to High(pl.Pts) do
      pts[k] := PointF(pl.Pts[k].x * z - bb.Left, pl.Pts[k].y * z - bb.Top);
    // a closed curve whose last point is its first one: the repeated point would leave a gap at the join
    if pl.Closed and (Length(pts) > 2) and (Abs(pts[0].x - pts[High(pts)].x) < 1e-3) and
      (Abs(pts[0].y - pts[High(pts)].y) < 1e-3) then SetLength(pts, Length(pts) - 1);
  end;

begin
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  SetLength(Result, w * h);
  bmp := TBGRABitmap.Create(w, h, BGRAPixelTransparent);
  try
    o := ShapeOutline(s);
    if part = 2 then
    begin
      nClosed := 0;
      for i := 0 to High(o) do
        if o[i].Closed and (Length(o[i].Pts) >= 3) then Inc(nClosed);
      if nClosed > 1 then
      begin
        // an outline with holes: the closed curves are joined into one polygon by thin bridges
        SetLength(lps, Length(o));
        for i := 0 to High(o) do
        begin
          SetLength(lps[i].Pts, Length(o[i].Pts));
          for j := 0 to High(o[i].Pts) do
          begin
            lps[i].Pts[j].x := o[i].Pts[j].x;
            lps[i].Pts[j].y := o[i].Pts[j].y;
          end;
        end;
        bp := BridgeLoops(lps);
        SetLength(pts, Length(bp));
        for j := 0 to High(bp) do pts[j] := PointF(bp[j].x * z - bb.Left, bp[j].y * z - bb.Top);
        if Length(pts) >= 3 then bmp.FillPolyAntialias(pts, BGRAWhite);
      end
      else
        for i := 0 to High(o) do
        begin
          Conv(o[i]);
          if Length(pts) >= 3 then bmp.FillPolyAntialias(pts, BGRAWhite);
        end;
    end
    else
    begin
      st := s.Style;
      if SoftW > 0 then st.Width := SoftW;
      pw := Max(1, st.Width * z);
      case st.Cap of
        lcFlat: bmp.LineCap := pecFlat;
        lcRound: bmp.LineCap := pecRound;
        lcSquare: bmp.LineCap := pecSquare;
      end;
      case st.Join of
        ljMiter: bmp.JoinStyle := pjsMiter;
        ljRound: bmp.JoinStyle := pjsRound;
        ljBevel: bmp.JoinStyle := pjsBevel;
      end;
      case st.Dash of
        dsDash: bmp.PenStyle := psDash;
        dsDot: bmp.PenStyle := psDot;
        dsDashDot: bmp.PenStyle := psDashDot;
      else
        bmp.PenStyle := psSolid;
      end;
      if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
      for i := 0 to High(o) do
      begin
        Conv(o[i]);
        if Length(pts) >= 2 then
        begin
          if o[i].Closed and (Length(pts) >= 3) then
          begin
            // a closed curve as a line that comes back over its first two points (DrawPolygonAntialias is much slower)
            if bmp.PenStyle = psSolid then
            begin
              SetLength(pts, Length(pts) + 2);
              pts[High(pts) - 1] := pts[0];
              pts[High(pts)] := pts[1];
            end
            else
            begin
              // dashed: the first side must not be drawn twice
              SetLength(pts, Length(pts) + 1);
              pts[High(pts)] := pts[0];
            end;
          end;
          bmp.DrawPolyLineAntialias(pts, BGRAWhite, pw);
        end;
      end;
      if (s.Kind = skArrow) and (Length(s.P) >= 2) then
      begin
        head := ArrowHead(s.P[0], s.P[1], st.Width);
        SetLength(pts, 3);
        for j := 0 to 2 do pts[j] := PointF(head[j].x * z - bb.Left, head[j].y * z - bb.Top);
        bmp.PenStyle := psSolid;
        bmp.FillPolyAntialias(pts, BGRAWhite);
      end;
    end;
    for y := 0 to h - 1 do
    begin
      px := bmp.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        Result[y * w + x] := px^.alpha;
        Inc(px);
      end;
    end;
  finally
    bmp.Free;
  end;
end;

// The drawing made while something is moved, turned or resized: all in memory (BGRABitmap), in one go, without the reading of
// the display that the exact drawing needs for its transparencies. It does the lines, the areas, the transparency, the soft
// strokes, the texts and the pictures; what it cannot do (filters, gradients, hatching, airbrush, turned pictures)
// sends the drawing to the exact way.
function TForm1.FastRenderOK(pw, ph: Integer): Boolean;
var
  i: Integer;
  s: TShape;

  function Plain(sh: TShape): Boolean;
  begin
    Result := not (sh.Spray or (sh.HatchPat > 0) or (sh.GradOn and (sh.Style.Fill <> NoColor)) or ((sh.Kind = skImage) and (sh.Rot <> 0)));
  end;

begin
  Result := False;
  if Doc.HasFilter or (pw < 1) or (ph < 1) or (Int64(pw) * ph > 6000000) then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    s := Doc.Shapes[i];
    if Doc.ShapeVisible(s) and not Plain(s) then Exit;
  end;
  if (Creating <> nil) and not Plain(Creating) then Exit;
  Result := True;
end;

procedure TForm1.FastShape(fb: TBGRABitmap; s: TShape; z: Double);
var
  o: TOutline;
  st: TStyle;
  i, j, k, nb: Integer;
  pts: array of TPointF;
  isSel, isHover: Boolean;
  col: TBGRAPixel;
  fa, sa, w0: Double;
  head: TPtArray;
  nClosed: Integer;
  lps: TFLoopArray;
  bp: TFPtArray;
  g: TGraphic;
  hk: QWord;
  r: TRect;
  e: Integer;
  src: TBGRABitmap;
  tb: TBitmap;
  full: Double;
  al: array of Double;
  al1: Double;
  bx1, by1, bx2, by2, wm: Double;
  tgt, tb2: TBGRABitmap;
  FOx, FOy: Double;
  bx0, by0, bw, bh: Integer;

  procedure Conv(const pl: TPolyline);
  var
    q: Integer;
  begin
    SetLength(pts, Length(pl.Pts));
    for q := 0 to High(pl.Pts) do pts[q] := PointF(pl.Pts[q].x * z - FOx, pl.Pts[q].y * z - FOy);
  end;

  procedure SetPen(const sy: TStyle);
  begin
    case sy.Cap of
      lcFlat: tgt.LineCap := pecFlat;
      lcRound: tgt.LineCap := pecRound;
      lcSquare: tgt.LineCap := pecSquare;
    end;
    case sy.Join of
      ljMiter: tgt.JoinStyle := pjsMiter;
      ljRound: tgt.JoinStyle := pjsRound;
      ljBevel: tgt.JoinStyle := pjsBevel;
    end;
    case sy.Dash of
      dsDash: tgt.PenStyle := psDash;
      dsDot: tgt.PenStyle := psDot;
      dsDashDot: tgt.PenStyle := psDashDot;
    else
      tgt.PenStyle := psSolid;
    end;
  end;

  procedure Line(const pl: TPolyline; c: TBGRAPixel; wpx: Double);
  var
    n: Integer;
  begin
    Conv(pl);
    if Length(pts) < 2 then Exit;
    if pl.Closed and (Length(pts) >= 3) then
    begin
      // a closed curve as a line that comes back over its first two points (DrawPolygonAntialias is much slower)
      n := Length(pts);
      if tgt.PenStyle = psSolid then
      begin
        SetLength(pts, n + 2);
        pts[n] := pts[0];
        pts[n + 1] := pts[1];
      end
      else
      begin
        // dashed: going over the first side again would draw it twice with another phase, and it would look solid
        SetLength(pts, n + 1);
        pts[n] := pts[0];
      end;
    end;
    tgt.DrawPolyLineAntialias(pts, c, wpx);
  end;

  function Prof(d: Double): Double;
  var
    t: Double;
  begin
    if d <= full then Result := 1
    else if d >= 1 then Result := 0
    else
    begin
      t := (d - full) / (1 - full);
      Result := 1 - t * t * (3 - 2 * t);
    end;
  end;

begin
  tgt := fb;
  FOx := 0;
  FOy := 0;
  st := s.Style;
  if s.Spray then st.Stroke := NoColor;
  isSel := IsSelShape(s);
  isHover := (s = HoverShape) and not isSel;
  if FastHaloOnly and (not isSel or (s.Kind in [skText, skImage])) then Exit;
  if SelHaloPre then isSel := False;
  if s.IsRef then
  begin
    st.Stroke := ColorSel;
    st.Width := 1;
    st.Dash := dsDash;
    st.Fill := NoColor;
  end;
  if s.Kind = skImage then
  begin
    r := Rect(Round(Min(s.P[0].x, s.P[1].x) * z), Round(Min(s.P[0].y, s.P[1].y) * z),
      Round(Max(s.P[0].x, s.P[1].x) * z), Round(Max(s.P[0].y, s.P[1].y) * z));
    if (r.Right <= r.Left) or (r.Bottom <= r.Top) then Exit;
    e := -1;
    hk := HoleKey(s);
    for i := 0 to High(FastImgs) do
      if FastImgs[i].Shape = s then e := i;
    if (e >= 0) and ((FastImgs[e].Key <> hk) or (FastImgs[e].DataP <> Pointer(s.ImageData)) or (FastImgs[e].DataLen <> Length(s.ImageData))) then
    begin
      FastImgs[e].Src.Free;
      FastImgs[e].Scaled.Free;
      Delete(FastImgs, e, 1);
      e := -1;
    end;
    if e < 0 then
    begin
      g := ImageOf(s);
      if g = nil then Exit;
      tb := TBitmap.Create;
      try
        tb.Assign(g);
        src := TBGRABitmap.Create(tb);
      finally
        tb.Free;
      end;
      if Length(FastImgs) >= 6 then
      begin
        FastImgs[0].Src.Free;
        FastImgs[0].Scaled.Free;
        Delete(FastImgs, 0, 1);
      end;
      SetLength(FastImgs, Length(FastImgs) + 1);
      e := High(FastImgs);
      FastImgs[e].Shape := s;
      FastImgs[e].Key := hk;
      FastImgs[e].DataP := Pointer(s.ImageData);
      FastImgs[e].DataLen := Length(s.ImageData);
      FastImgs[e].Src := src;
      FastImgs[e].Scaled := nil;
      FastImgs[e].W := 0;
      FastImgs[e].H := 0;
    end;
    if (FastImgs[e].Scaled = nil) or (FastImgs[e].W <> r.Right - r.Left) or (FastImgs[e].H <> r.Bottom - r.Top) then
    begin
      FastImgs[e].Scaled.Free;
      FastImgs[e].W := r.Right - r.Left;
      FastImgs[e].H := r.Bottom - r.Top;
      FastImgs[e].Scaled := FastImgs[e].Src.Resample(FastImgs[e].W, FastImgs[e].H, rmSimpleStretch) as TBGRABitmap;
    end;
    fb.PutImage(r.Left, r.Top, FastImgs[e].Scaled, dmDrawWithTransparency);
    if s.IsRef then
    begin
      fb.PenStyle := psDash;
      fb.RectangleAntialias(r.Left + 0.5, r.Top + 0.5, r.Right - 0.5, r.Bottom - 0.5, ColorToBGRA(TColor($C08040)), 1);
    end;
    Exit;
  end;
  if s.Kind = skText then
  begin
    if st.Fill <> NoColor then col := ColorToBGRA(ToCol(st.Fill), 255 - st.FillTr) else col := BGRA(0, 0, 0, 255 - st.FillTr);
    fb.FontHeight := Max(2, Round(s.FontSize * z));      // BGRA: positive = height of the letters (as the negative one of the Canvas)
    if s.FontName <> '' then fb.FontName := s.FontName else fb.FontName := 'default';
    fb.FontOrientation := Round(s.Rot * 1800 / Pi);
    fb.TextOut(Round(s.P[0].x * z), Round(s.P[0].y * z), s.Text, col);
    fb.FontOrientation := 0;
    fb.FontName := 'default';
    Exit;
  end;
  o := ShapeOutline(s);
  // the shape is drawn alone in a small transparent picture (the box of the shape) and that is laid on the drawing: a
  // translucent stroke costs as much as the picture it is drawn in
  bx1 := 1e30; by1 := 1e30; bx2 := -1e30; by2 := -1e30;
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      bx1 := Min(bx1, o[i].Pts[j].x * z);
      by1 := Min(by1, o[i].Pts[j].y * z);
      bx2 := Max(bx2, o[i].Pts[j].x * z);
      by2 := Max(by2, o[i].Pts[j].y * z);
    end;
  if bx1 > bx2 then Exit;
  wm := (Max(st.Width, 1) + 7 / z) * z + 4;
  bx0 := Max(0, Floor(bx1 - wm));
  by0 := Max(0, Floor(by1 - wm));
  bw := Min(tgt.Width, Ceil(bx2 + wm)) - bx0;
  bh := Min(tgt.Height, Ceil(by2 + wm)) - by0;
  if (bw <= 0) or (bh <= 0) then Exit;
  tb2 := TBGRABitmap.Create(bw, bh, BGRAPixelTransparent);
  try
    tgt := tb2;
    FOx := bx0;
    FOy := by0;
  if isSel or isHover then
  begin
    // the halo of what is selected or under the pointer
    tgt.LineCap := pecRound;
    tgt.JoinStyle := pjsRound;
    tgt.PenStyle := psSolid;
    if isSel then col := ColorToBGRA(TColor($FFD9A8)) else col := ColorToBGRA(TColor($FBE8D2));
    for i := 0 to High(o) do
      if Length(o[i].Pts) >= 2 then
      begin
        Conv(o[i]);
        if o[i].Closed and (s.Kind in [skRect, skEllipse, skPolygon]) and (Length(pts) >= 3) then
        begin
          SetLength(pts, Length(pts) + 2);
          pts[High(pts) - 1] := pts[0];
          pts[High(pts)] := pts[1];
        end;
        tgt.DrawPolyLineAntialias(pts, col, (Max(st.Width, 1) + 7 / z) * z);
      end;
  end;
  if FastHaloOnly then Exit;
  // the area
  if st.Fill <> NoColor then
  begin
    col := ColorToBGRA(ToCol(st.Fill), 255 - st.FillTr);
    nClosed := 0;
    for i := 0 to High(o) do
      if o[i].Closed and (Length(o[i].Pts) >= 3) then Inc(nClosed);
    if nClosed > 1 then
    begin
      SetLength(lps, Length(o));
      for i := 0 to High(o) do
      begin
        SetLength(lps[i].Pts, Length(o[i].Pts));
        for j := 0 to High(o[i].Pts) do
        begin
          lps[i].Pts[j].x := o[i].Pts[j].x;
          lps[i].Pts[j].y := o[i].Pts[j].y;
        end;
      end;
      bp := BridgeLoops(lps);
      SetLength(pts, Length(bp));
      for j := 0 to High(bp) do pts[j] := PointF(bp[j].x * z - FOx, bp[j].y * z - FOy);
      if Length(pts) >= 3 then tgt.FillPolyAntialias(pts, col);
    end
    else
      for i := 0 to High(o) do
      begin
        Conv(o[i]);
        if Length(pts) >= 3 then tgt.FillPolyAntialias(pts, col);
      end;
  end;
  // the stroke
  if (st.Stroke <> NoColor) and (s.Kind <> skText) then
  begin
    if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    SetPen(st);
    sa := (255 - st.StrokeTr) / 255;
    w0 := Max(1, st.Width * z);
    if s.Soft > 0 then
    begin
      // soft: bands of growing width, drawn from the widest, each with the opacity that gives the profile
      full := 1 - Min(100, s.Soft) / 100;
      nb := 3;
      SetLength(al, nb + 2);
      al[nb + 1] := 0;
      for k := nb downto 1 do
      begin
        // what the pixels of the ring k must end with
        al1 := Prof((k - 0.5) / nb) * sa;
        al[k] := al1;
      end;
      for k := nb downto 1 do
      begin
        if k = nb then fa := al[k]
        else if al[k + 1] >= 0.999 then fa := 0
        else fa := 1 - (1 - al[k]) / (1 - al[k + 1]);
        if fa <= 0.002 then Continue;
        col := ColorToBGRA(ToCol(st.Stroke), Round(255 * Min(1, fa)));
        for i := 0 to High(o) do Line(o[i], col, Max(1, st.Width * z * k / nb));
      end;
    end
    else
    begin
      col := ColorToBGRA(ToCol(st.Stroke), Round(255 * sa));
      for i := 0 to High(o) do Line(o[i], col, w0);
    end;
    if (s.Kind = skArrow) and (Length(s.P) >= 2) then
    begin
      head := ArrowHead(s.P[0], s.P[1], st.Width);
      SetLength(pts, 3);
      for j := 0 to 2 do pts[j] := PointF(head[j].x * z - FOx, head[j].y * z - FOy);
      tgt.PenStyle := psSolid;
      tgt.FillPolyAntialias(pts, ColorToBGRA(ToCol(st.Stroke), Round(255 * sa)));
    end;
  end;
  finally
    fb.PutImage(bx0, by0, tb2, dmDrawWithTransparency);
    tb2.Free;
  end;
end;

// the layer whose background must be laid before this shape is drawn: a fill (bucket) is drawn under the lines that bound it,
// even when they are in a lower layer, so it must not bring the backgrounds of its own layer under those lines
function TForm1.BgLayerIdx(s: TShape): Integer;
begin
  if s.Bucket then Result := -1 else Result := Doc.Layers.IndexOf(Doc.LayerOf(s));
end;

// the backgrounds of the layers up to the layer number upTo that have not been laid yet (the fast drawing)
procedure TForm1.FastLayerBgs(fb: TBGRABitmap; var nextL: Integer; upTo, pw, ph: Integer);
var
  l: TLayer;
begin
  while nextL <= upTo do
  begin
    l := Doc.Layers[nextL];
    if l.Visible and not l.IsFilter and (l.Bg <> NoColor) then
    begin
      // the background has the opacity of its layer
      if l.Opacity >= 255 then fb.FillRect(0, 0, pw, ph, ColorToBGRA(TColor(l.Bg)), dmSet)
      else fb.FillRect(0, 0, pw, ph, ColorToBGRA(TColor(l.Bg), l.Opacity), dmDrawWithTransparency);
    end;
    Inc(nextL);
  end;
end;

// the halos can be drawn first only when nothing is laid over the page between them and the objects (no layer background, no filter)
function TForm1.HaloPreOK: Boolean;
var
  k: Integer;
begin
  Result := not Doc.HasFilter;
  for k := 0 to Doc.Layers.Count - 1 do
    if Doc.Layers[k].Visible and (Doc.Layers[k].Bg <> NoColor) then Result := False;
end;

// the halos of the selected objects, drawn before all the objects: the halo of one object does not cover the objects drawn before it
// (a group: the halos of all its parts are one outline under the whole group)
procedure TForm1.DrawSelHalos(cnv: TCanvas; const ord: TShapeArray; i0, i1: Integer; z: Double);
var
  i: Integer;
begin
  for i := i0 to i1 do
    if IsSelShape(ord[i]) and not (ord[i].IsRef and not Doc.ShapeVisible(ord[i])) then
      RenderShapeCore(cnv, ord[i], ord[i].Style, z, True, 1);
end;

procedure TForm1.RenderFast(cnv: TCanvas; pw, ph: Integer);
var
  fb: TBGRABitmap;
  i, nextL: Integer;
  ord: TShapeArray;
begin
  fb := TBGRABitmap.Create(pw, ph, BGRAWhite);
  try
    ord := Doc.DrawOrder;
    nextL := 0;
    // the halos of the selection first, under everything (over the page, under the objects)
    if (Length(Sel) > 0) and HaloPreOK then
    begin
      FastHaloOnly := True;
      try
        for i := 0 to High(ord) do
          if not (ord[i].IsRef and not Doc.ShapeVisible(ord[i])) then FastShape(fb, ord[i], Zoom);
      finally
        FastHaloOnly := False;
      end;
      SelHaloPre := True;
    end;
    try
    for i := 0 to High(ord) do
    begin
      if ord[i].IsRef and not Doc.ShapeVisible(ord[i]) then Continue;
      // the background of a layer is under the objects of the layer: it is laid when its turn comes
      FastLayerBgs(fb, nextL, BgLayerIdx(ord[i]), pw, ph);
      FastShape(fb, ord[i], Zoom);
    end;
    finally
      SelHaloPre := False;
    end;
    FastLayerBgs(fb, nextL, Doc.Layers.Count - 1, pw, ph);
    if Creating <> nil then FastShape(fb, Creating, Zoom);
    fb.Draw(cnv, 0, 0, True);
  finally
    fb.Free;
  end;
end;

// something is being dragged, turned, resized or created: the drawing may be less exact until it stops
function TForm1.Interacting: Boolean;
begin
  Result := (Drag in [dmCreate, dmPoint, dmShape, dmHandle, dmQuote, dmGroup, dmRotate, dmDeform, dmPix]) or (Creating <> nil) or ZoomFast;
end;

// the coverage (0..255) of one part of a shape over the pixels of bb: it is drawn white on black into a
// mask S times bigger and then reduced, so that the edges are smooth (S = 1: not smoothed)
function TForm1.PartCoverage(s: TShape; z: Double; part, k: Integer; const bb: TRect): TByteDyn;
var
  st2: TStyle;
  w, h, x, y, sx, sy, sum, bpp, ss: Integer;
  m: TBitmap;
  mi: TLazIntfImage;
  row: PByte;
  mc: TFPColor;
  bs: TRect;
  tmp: TBitmap;
begin
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  SetLength(Result, 0);
  if (w <= 0) or (h <= 0) then Exit;
  if CovOn then
    for ss := 0 to High(CovList) do
      if (CovList[ss].Shape = s) and (CovList[ss].Part = part) and (CovList[ss].K = k) and (CovList[ss].Z = z) and (CovList[ss].W = SoftW) and
        EqualRect(CovList[ss].BB, bb) then
      begin
        Result := CovList[ss].Cov;
        Exit;
      end;
  if not (s.Kind in [skText, skImage]) then
  begin
    Result := PartCoverageSW(s, z, part, bb);
    if CovOn then
    begin
      if CovBytes > 96000000 then
      begin
        SetLength(CovList, 0);
        CovBytes := 0;
      end;
      SetLength(CovList, Length(CovList) + 1);
      CovList[High(CovList)].Shape := s;
      CovList[High(CovList)].Part := part;
      CovList[High(CovList)].K := k;
      CovList[High(CovList)].Z := z;
      CovList[High(CovList)].W := SoftW;
      CovList[High(CovList)].BB := bb;
      CovList[High(CovList)].Cov := Result;
      CovBytes := CovBytes + Length(Result);
    end;
    Exit;
  end;
  SetLength(Result, w * h);
  ss := Max(1, k);
  if ss = 1 then tmp := nil else tmp := AAMask;
  if ss = 1 then
  begin
    if (AlphaMask = nil) or (AlphaMask.Width <> AlphaW) or (AlphaMask.Height <> AlphaH) then
    begin
      FreeAndNil(AlphaMask);
      AlphaMask := TBitmap.Create;
      AlphaMask.SetSize(AlphaW, AlphaH);
    end;
    tmp := AlphaMask;
  end
  else if (AAMask = nil) or (AAMask.Width <> AlphaW * ss) or (AAMask.Height <> AlphaH * ss) then
  begin
    FreeAndNil(AAMask);
    AAMask := TBitmap.Create;
    AAMask.SetSize(AlphaW * ss, AlphaH * ss);
    tmp := AAMask;
  end
  else tmp := AAMask;
  bs := Rect(bb.Left * ss, bb.Top * ss, bb.Right * ss, bb.Bottom * ss);
  SetViewPortOrgEx(tmp.Canvas.Handle, -AlphaX0 * ss, -AlphaY0 * ss, nil);
  tmp.Canvas.Brush.Style := bsSolid;
  tmp.Canvas.Brush.Color := clBlack;
  tmp.Canvas.FillRect(bs);
  st2 := s.Style;
  if part = 2 then
  begin
    st2.Fill := Integer(clWhite);
    st2.Stroke := NoColor;
  end
  else
  begin
    st2.Stroke := Integer(clWhite);
    st2.Fill := NoColor;
    if SoftW > 0 then st2.Width := SoftW;
  end;
  RenderShapeCore(tmp.Canvas, s, st2, z * ss, False, part);
  m := TBitmap.Create;
  try
    m.SetSize(w * ss, h * ss);
    m.Canvas.CopyRect(Rect(0, 0, w * ss, h * ss), tmp.Canvas, bs);
    mi := m.CreateIntfImage;
    try
      bpp := mi.DataDescription.BitsPerPixel div 8;
      if (bpp < 3) or (bpp > 4) then
      begin
        // an unexpected pixel format: read the pixels one by one
        for y := 0 to h - 1 do
          for x := 0 to w - 1 do
          begin
            sum := 0;
            for sy := 0 to ss - 1 do
              for sx := 0 to ss - 1 do
              begin
                mc := mi.Colors[x * ss + sx, y * ss + sy];
                if mc.red > 32767 then Inc(sum);
              end;
            Result[y * w + x] := sum * 255 div (ss * ss);
          end;
      end
      else
        for y := 0 to h - 1 do
        begin
          for x := 0 to w - 1 do Result[y * w + x] := 0;
          for sy := 0 to ss - 1 do
          begin
            row := mi.GetDataLineStart(y * ss + sy);
            for x := 0 to w * ss - 1 do
              if row[x * bpp] > 127 then Inc(Result[y * w + x div ss]);
          end;
          // the samples counted for each pixel become 0..255
          for x := 0 to w - 1 do Result[y * w + x] := Result[y * w + x] * 255 div (ss * ss);
        end;
    finally
      mi.Free;
    end;
  finally
    m.Free;
  end;
  if CovOn then
  begin
    if CovBytes > 96000000 then
    begin
      SetLength(CovList, 0);
      CovBytes := 0;
    end;
    SetLength(CovList, Length(CovList) + 1);
    CovList[High(CovList)].Shape := s;
    CovList[High(CovList)].Part := part;
    CovList[High(CovList)].K := k;
    CovList[High(CovList)].Z := z;
    CovList[High(CovList)].W := SoftW;
    CovList[High(CovList)].BB := bb;
    CovList[High(CovList)].Cov := Result;
    CovBytes := CovBytes + Length(Result);
  end;
end;

// the same, with the pixels where AlphaMask (drawn at the scale of the canvas) is white
procedure TForm1.BlendMaskOf(cnv: TCanvas; const bb: TRect; col: TColor; alpha: Integer);
var
  m: TBitmap;
  mi: TLazIntfImage;
  w, h, x, y: Integer;
  cov: TByteDyn;
begin
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) or (AlphaMask = nil) then Exit;
  SetLength(cov, w * h);
  m := TBitmap.Create;
  try
    m.SetSize(w, h);
    m.Canvas.CopyRect(Rect(0, 0, w, h), AlphaMask.Canvas, bb);
    mi := m.CreateIntfImage;
    try
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do cov[y * w + x] := mi.Colors[x, y].red shr 8;
    finally
      mi.Free;
    end;
  finally
    m.Free;
  end;
  BlendMask(cnv, bb, col, alpha, cov);
end;

// mixes colour col over the pixels of cnv inside bb, where the coverage is not zero, with opacity alpha (0..255)
procedure TForm1.BlendMask(cnv: TCanvas; const bb: TRect; col: TColor; alpha: Integer; const cov: TByteDyn);
var
  d: TBitmap;
  li: TLazIntfImage;
  w, h, x, y: Integer;
  cr, cg, cb: Integer;
  f: Double;
  dc: TFPColor;
begin
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) or (Length(cov) < w * h) then Exit;
  cr := (Integer(col) and $FF) * 257;
  cg := ((Integer(col) shr 8) and $FF) * 257;
  cb := ((Integer(col) shr 16) and $FF) * 257;
  d := TBitmap.Create;
  try
    d.SetSize(w, h);
    d.Canvas.CopyRect(Rect(0, 0, w, h), cnv, bb);
    li := d.CreateIntfImage;
    try
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          if cov[y * w + x] = 0 then Continue;
          f := (alpha / 255) * (cov[y * w + x] / 255);
          dc := li.Colors[x, y];
          dc.red := Round(dc.red * (1 - f) + cr * f);
          dc.green := Round(dc.green * (1 - f) + cg * f);
          dc.blue := Round(dc.blue * (1 - f) + cb * f);
          li.Colors[x, y] := dc;
        end;
      d.LoadFromIntfImage(li);
    finally
      li.Free;
    end;
    cnv.Draw(bb.Left, bb.Top, d);
  finally
    d.Free;
  end;
end;

// a coverage blurred (three box passes of radius r, about a gaussian of sigma 2r / 3) in place
procedure BlurCoverage(var cov: TByteDyn; w, h, r: Integer);
var
  tmp: array of Integer;
  x, y, k, pass, n, sum, lo, hi: Integer;
begin
  if (r < 1) or (w < 1) or (h < 1) then Exit;
  SetLength(tmp, Max(w, h) + 2 * r + 2);
  for pass := 1 to 3 do
  begin
    // rows
    for y := 0 to h - 1 do
    begin
      sum := 0;
      for k := -r to r do
        if (k >= 0) and (k < w) then Inc(sum, cov[y * w + k]);
      n := 2 * r + 1;
      for x := 0 to w - 1 do
      begin
        tmp[x] := sum div n;
        lo := x - r;
        hi := x + r + 1;
        if lo >= 0 then Dec(sum, cov[y * w + lo]);
        if hi < w then Inc(sum, cov[y * w + hi]);
      end;
      for x := 0 to w - 1 do cov[y * w + x] := tmp[x];
    end;
    // columns
    for x := 0 to w - 1 do
    begin
      sum := 0;
      for k := -r to r do
        if (k >= 0) and (k < h) then Inc(sum, cov[k * w + x]);
      n := 2 * r + 1;
      for y := 0 to h - 1 do
      begin
        tmp[y] := sum div n;
        lo := y - r;
        hi := y + r + 1;
        if lo >= 0 then Dec(sum, cov[lo * w + x]);
        if hi < h then Inc(sum, cov[hi * w + x]);
      end;
      for y := 0 to h - 1 do cov[y * w + x] := tmp[y];
    end;
  end;
end;

// a filled area (or a text) with soft edges: its coverage is blurred, so that it fades out around the outline; the blur is a
// part of the size of the shape (of the font for a text) as large as the percentage says
procedure TForm1.BlendSoftFill(cnv: TCanvas; s: TShape; z: Double; tr, k: Integer);
var
  bb: TRect;
  cov: TByteDyn;
  w, h, r: Integer;
  d, dim, m: Double;
  col: Integer;
begin
  bb := ShapeScreenBox(s, z);
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) then Exit;
  m := (Max(s.Style.Width, 1) * 3 + 14) * z;
  if s.Kind = skText then d := s.FontSize * z * 0.12 * s.Soft / 100
  else
  begin
    dim := Max(4, Min(w, h) - 2 * m);
    d := dim * 0.12 * s.Soft / 100;
  end;
  d := Min(d, m * 0.8);
  r := Round(d / 2);
  cov := PartCoverage(s, z, 2, k, bb);
  if Length(cov) < w * h then Exit;
  // the coverage may belong to a cache: the blur works on a copy
  cov := Copy(cov);
  BlurCoverage(cov, w, h, r);
  col := s.Style.Fill;
  if col = NoColor then col := 0;
  BlendMask(cnv, bb, ToCol(col), 255 - tr, cov);
end;

// a stroke with soft edges: the opacity is full on the axis (and out to the part of the half width that is not soft) and fades to
// nothing at the edges. The stroke is measured as bands of growing width; each band is weighted by how much the profile drops
// there, so that the sum of the bands is the profile (and the stroke does not get darker where it crosses itself)
procedure TForm1.BlendSoftStroke(cnv: TCanvas; s: TShape; z: Double; tr, k: Integer);
var
  bb: TRect;
  nb, i, j, n: Integer;
  rad, full, t, t2, dk: Double;
  acc: array of Single;
  cov: TByteDyn;
  w: array of Double;

  // the opacity (0..1) at the distance d from the axis, d in 0..1 of the half width
  function Prof(d: Double): Double;
  begin
    if d <= full then Result := 1
    else if d >= 1 then Result := 0
    else
    begin
      t := (d - full) / (1 - full);
      Result := 1 - t * t * (3 - 2 * t);
    end;
  end;

begin
  bb := ShapeScreenBox(s, z);
  if (bb.Right <= bb.Left) or (bb.Bottom <= bb.Top) then Exit;
  rad := s.Style.Width / 2;
  full := 1 - Min(100, s.Soft) / 100;
  nb := Max(6, Min(24, Ceil(rad * z)));
  if FastMode then nb := 3;       // while it is moved: few bands (the edge shows steps until it stops)
  n := (bb.Right - bb.Left) * (bb.Bottom - bb.Top);
  SetLength(acc, n);
  for i := 0 to n - 1 do acc[i] := 0;
  SetLength(w, nb + 1);
  for i := 1 to nb do w[i] := Prof((i - 0.5) / nb);
  for i := 1 to nb do
  begin
    // the band i covers everything within the distance i / nb of the axis
    if i < nb then dk := w[i] - w[i + 1] else dk := w[i];
    if dk <= 0.0005 then Continue;
    SoftW := Max(0.2, s.Style.Width * i / nb);
    try
      cov := PartCoverage(s, z, 3, k, bb);
    finally
      SoftW := 0;
    end;
    for j := 0 to n - 1 do acc[j] := acc[j] + cov[j] * dk;
  end;
  SetLength(cov, n);
  for j := 0 to n - 1 do cov[j] := Max(0, Min(255, Round(acc[j])));
  BlendMask(cnv, bb, ToCol(s.Style.Stroke), 255 - tr, cov);
end;

// one part of a shape drawn with transparency and / or smooth edges: coverage, then mixed in
procedure TForm1.BlendPart(cnv: TCanvas; s: TShape; z: Double; part, tr, k: Integer);
var
  bb: TRect;
  col: Integer;
begin
  bb := ShapeScreenBox(s, z);
  if (bb.Right <= bb.Left) or (bb.Bottom <= bb.Top) then Exit;
  if part = 2 then col := s.Style.Fill else col := s.Style.Stroke;
  BlendMask(cnv, bb, ToCol(col), 255 - tr, PartCoverage(s, z, part, k, bb));
end;

// the fill of a shape with a gradient: each pixel is mixed in with the colour and the opacity the gradient has there
procedure TForm1.BlendGradient(cnv: TCanvas; s: TShape; z: Double; k: Integer);
var
  d: TBitmap;
  li: TLazIntfImage;
  bb: TRect;
  g: TGradLine;
  w, h, x, y, col, op: Integer;
  f, lf, t: Double;
  dc: TFPColor;
  l: TLayer;
  cov: TByteDyn;
begin
  bb := ShapeScreenBox(s, z);
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) then Exit;
  cov := PartCoverage(s, z, 2, k, bb);
  g := Doc.GradientLine(s);
  l := Doc.LayerOf(s);
  if l <> nil then lf := l.Opacity / 255 else lf := 1;
  d := TBitmap.Create;
  try
    d.SetSize(w, h);
    d.Canvas.CopyRect(Rect(0, 0, w, h), cnv, bb);
    li := d.CreateIntfImage;
    try
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          if cov[y * w + x] = 0 then Continue;
          t := GradientT(g, (bb.Left + x + 0.5) / z, (bb.Top + y + 0.5) / z);
          GradientMix(s, t, col, op);
          f := (op / 255) * lf * (cov[y * w + x] / 255);
          dc := li.Colors[x, y];
          dc.red := Round(dc.red * (1 - f) + (col and $FF) * 257 * f);
          dc.green := Round(dc.green * (1 - f) + ((col shr 8) and $FF) * 257 * f);
          dc.blue := Round(dc.blue * (1 - f) + ((col shr 16) and $FF) * 257 * f);
          li.Colors[x, y] := dc;
        end;
      d.LoadFromIntfImage(li);
    finally
      li.Free;
    end;
    cnv.Draw(bb.Left, bb.Top, d);
  finally
    d.Free;
  end;
end;

// the stroke (a tube) or the fill (a surface) of a shape made of a material: each pixel takes the colour that the material has there under
// the light; the tube is shaded across, as a round bar, the surface by its texture and its sheen
procedure TForm1.BlendMaterial(cnv: TCanvas; s: TShape; z: Double; part, tr, k: Integer);
type
  TSeg = record
    ax, ay, bx, by, x1, y1, x2, y2: Double;
  end;
var
  d: TBitmap;
  li: TLazIntfImage;
  bb: TRect;
  w, h, x, y, i, j, m, rr, gg, bl, aa: Integer;
  cov: TByteDyn;
  o: TOutline;
  segs: array of TSeg;
  half, px, py, dx, dy, l2, t, qx, qy, dd, best, nearx, neary, f, lf, len, nx, ny, nz: Double;
  dc, dc2: TFPColor;
  lay: TLayer;
  flat, lens: Boolean;
  li2: TLazIntfImage;
  gx1, gy1, gx2, gy2, gcx, gcy, ghw, ghh, gk, fa, cv, su, sv: Double;
  xs, ys: Integer;
begin
  bb := ShapeScreenBox(s, z);
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) then Exit;
  if part = 2 then m := FillMaterial(s.Style) - 1 else m := StrokeMaterial(s.Style) - 1;
  if m < 0 then Exit;
  cov := PartCoverage(s, z, part, k, bb);
  flat := part = 2;
  // a glass: its curve is measured on the box of the shape itself, and the curve makes a lens (what is behind is magnified or shrunk)
  gx1 := 1e9; gy1 := 1e9; gx2 := -1e9; gy2 := -1e9;
  if m = 6 then
  begin
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
        if cov[y * w + x] > 0 then
        begin
          if x < gx1 then gx1 := x;
          if x > gx2 then gx2 := x;
          if y < gy1 then gy1 := y;
          if y > gy2 then gy2 := y;
        end;
  end;
  lens := flat and (m = 6) and (gx2 > gx1) and (gy2 > gy1);
  gcx := gx1 + Doc.Mats[6].CX * (gx2 - gx1 + 1);
  gcy := gy1 + Doc.Mats[6].CY * (gy2 - gy1 + 1);
  ghw := Max(1, (gx2 - gx1 + 1) / 2);
  ghh := Max(1, (gy2 - gy1 + 1) / 2);
  gk := 0;
  if lens then gk := 0.45 * Doc.Mats[m].Curve * (0.35 + 0.65 * Doc.Mats[m].Thick);
  li2 := nil;
  half := Max(0.8, s.Style.Width * z / 2);
  SetLength(segs, 0);
  if not flat then
  begin
    if not Doc.VisibleOutline(s, o) then o := ShapeOutline(s);
    for i := 0 to High(o) do
      for j := 0 to Length(o[i].Pts) - 2 + Ord(o[i].Closed) do
      begin
        SetLength(segs, Length(segs) + 1);
        with segs[High(segs)] do
        begin
          ax := o[i].Pts[j].x * z;
          ay := o[i].Pts[j].y * z;
          bx := o[i].Pts[(j + 1) mod Length(o[i].Pts)].x * z;
          by := o[i].Pts[(j + 1) mod Length(o[i].Pts)].y * z;
          x1 := Min(ax, bx) - half - 2;
          x2 := Max(ax, bx) + half + 2;
          y1 := Min(ay, by) - half - 2;
          y2 := Max(ay, by) + half + 2;
        end;
      end;
    if Length(segs) = 0 then Exit;
  end;
  lay := Doc.LayerOf(s);
  if lay <> nil then lf := lay.Opacity / 255 else lf := 1;
  CurMat := Doc.Mats[m];
  // the light of the layer
  if lay <> nil then SetLightAngles(lay.LightAz, lay.LightEl, lay.LightDiv, lay.LightTint, lay.LightPower)
  else SetLightAngles(217, 60, 0, $FFFFFF, 1);
  d := TBitmap.Create;
  try
    d.SetSize(w, h);
    d.Canvas.CopyRect(Rect(0, 0, w, h), cnv, bb);
    li := d.CreateIntfImage;
    if Abs(gk) > 1e-4 then li2 := d.CreateIntfImage;
    try
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          if cov[y * w + x] = 0 then Continue;
          px := bb.Left + x + 0.5;
          py := bb.Top + y + 0.5;
          if lens and (Doc.Mats[m].Curve <> 0) then
          begin
            su := (x + 0.5 - gx1) / (gx2 - gx1 + 1);
            sv := (y + 0.5 - gy1) / (gy2 - gy1 + 1);
          end
          else
          begin
            su := (px - bb.Left) / w;
            sv := (py - bb.Top) / h;
          end;
          if flat then
          begin
            nx := 0; ny := 0; nz := 1;
          end
          else
          begin
            // the nearest point of the axis of the tube: the surface looks away from it
            best := 1e18;
            nearx := px;
            neary := py;
            for i := 0 to High(segs) do
              with segs[i] do
              begin
                if (px < x1) or (px > x2) or (py < y1) or (py > y2) then Continue;
                dx := bx - ax;
                dy := by - ay;
                l2 := dx * dx + dy * dy;
                if l2 < 1e-12 then t := 0 else t := Max(0, Min(1, ((px - ax) * dx + (py - ay) * dy) / l2));
                qx := ax + t * dx;
                qy := ay + t * dy;
                dd := (px - qx) * (px - qx) + (py - qy) * (py - qy);
                if dd < best then
                begin
                  best := dd;
                  nearx := qx;
                  neary := qy;
                end;
              end;
            if best > 1e17 then Continue;
            nx := (px - nearx) / half;
            ny := (py - neary) / half;
            len := Sqrt(nx * nx + ny * ny);
            if len > 0.999 then
            begin
              nx := nx / len * 0.999;
              ny := ny / len * 0.999;
              len := 0.999;
            end;
            nz := Sqrt(1 - len * len);
          end;
          MaterialShade(m, px / z, py / z, nx, ny, nz, flat, su, sv, rr, gg, bl, aa);
          f := (aa / 255) * ((255 - tr) / 255) * lf * (cov[y * w + x] / 255);
          dc := li.Colors[x, y];
          if li2 <> nil then
          begin
            // the lens: what is seen through the glass comes from a point nearer the centre (convex) or farther from it (concave)
            xs := Max(0, Min(w - 1, Round(gcx + (x + 0.5 - gcx) * (1 - gk) - 0.5)));
            ys := Max(0, Min(h - 1, Round(gcy + (y + 0.5 - gcy) * (1 - gk) - 0.5)));
            dc2 := li2.Colors[xs, ys];
            fa := (aa / 255) * ((255 - tr) / 255) * lf;
            cv := cov[y * w + x] / 255;
            dc.red := Round(dc.red * (1 - cv) + (dc2.red * (1 - fa) + rr * 257 * fa) * cv);
            dc.green := Round(dc.green * (1 - cv) + (dc2.green * (1 - fa) + gg * 257 * fa) * cv);
            dc.blue := Round(dc.blue * (1 - cv) + (dc2.blue * (1 - fa) + bl * 257 * fa) * cv);
          end
          else
          begin
            dc.red := Round(dc.red * (1 - f) + rr * 257 * f);
            dc.green := Round(dc.green * (1 - f) + gg * 257 * f);
            dc.blue := Round(dc.blue * (1 - f) + bl * 257 * f);
          end;
          li.Colors[x, y] := dc;
        end;
      d.LoadFromIntfImage(li);
    finally
      li.Free;
      li2.Free;
    end;
    cnv.Draw(bb.Left, bb.Top, d);
  finally
    d.Free;
  end;
end;

procedure TForm1.RenderShape(cnv: TCanvas; s: TShape; z: Double; editView: Boolean);
var
  trS, trF, smp: Integer;
  grad, smooth, matS, matF: Boolean;
begin
  matF := AlphaOK and (FillMaterial(s.Style) > 0) and (s.Style.Fill <> NoColor) and not (s.Kind in [skText, skImage]) and
          not (editView and s.IsRef);
  matS := AlphaOK and (StrokeMaterial(s.Style) > 0) and (s.Style.Stroke <> NoColor) and not (s.Kind in [skText, skImage]) and
          not s.Spray and not (editView and s.IsRef);
  grad := AlphaOK and s.GradOn and (s.Style.Fill <> NoColor) and not (s.Kind in [skText, skImage]) and not (editView and s.IsRef);
  // smooth edges: only where the canvas can be read back, and not for texts and pictures
  smooth := AlphaOK and s.Antialias and (AAS > 1) and not (s.Kind in [skText, skImage]) and not (editView and s.IsRef);
  if smooth then smp := AAS else smp := 1;
  trS := Doc.EffectiveTr(s, False);
  trF := Doc.EffectiveTr(s, True);
  if (not AlphaOK) or (s.Kind = skImage) or (editView and s.IsRef) or
     ((trS = 0) and (trF = 0) and not grad and not smooth and (s.Soft = 0) and not matS and not matF) then
  begin
    RenderShapeCore(cnv, s, s.Style, z, editView, 0);
    Exit;
  end;
  // transparency, gradients, smooth edges: the halo, then the fill and the stroke, each drawn opaque or mixed in
  if editView then RenderShapeCore(cnv, s, s.Style, z, editView, 1);
  if (s.Style.Fill <> NoColor) or (s.Kind = skText) then
  begin
    if matF then BlendMaterial(cnv, s, z, 2, trF, smp)
    else if grad then BlendGradient(cnv, s, z, smp)
    else if s.Soft > 0 then BlendSoftFill(cnv, s, z, trF, smp)
    else if (trF > 0) or smooth then BlendPart(cnv, s, z, 2, trF, smp)
    else RenderShapeCore(cnv, s, s.Style, z, False, 2);
  end;
  if (s.Style.Stroke <> NoColor) and (s.Kind <> skText) and not s.Spray then
  begin
    if matS then BlendMaterial(cnv, s, z, 3, trS, smp)
    else if s.Soft > 0 then BlendSoftStroke(cnv, s, z, trS, smp)
    else if (trS > 0) or smooth then BlendPart(cnv, s, z, 3, trS, smp)
    else RenderShapeCore(cnv, s, s.Style, z, False, 3);
  end;
end;

// the size of the canvas that is going to be drawn, and whether the edges can be smoothed (the mask is
// several times bigger: not for very big canvases)
procedure TForm1.SetAlphaSize(w, h: Integer; smooth: Boolean);
begin
  AlphaW := w;
  AlphaH := h;
  AlphaX0 := 0;
  AlphaY0 := 0;
  // the edges are smoothed by the coverage made in memory: no size limit; AAS only tells whether to do it
  AAS := 1;
  if smooth then AAS := 2;
end;

// the document drawn into a bitmap (transparency needs a readable canvas)
procedure TForm1.RenderDocBmp(bmp: TBitmap; z: Double; editView: Boolean);
begin
  SetAlphaSize(bmp.Width, bmp.Height, True);
  AlphaOK := True;
  try
    RenderDoc(bmp.Canvas, z, editView);
  finally
    AlphaOK := False;
  end;
end;

// a 64-bit hash of some bytes (FNV, a word at a time); it is meant to overflow
{$PUSH}{$Q-}{$R-}
function HashBytes(p: Pointer; n: Integer; h: QWord): QWord;
var
  q: PQWord;
  b: PByte;
  k: Integer;
begin
  q := PQWord(p);
  for k := 1 to n div 8 do
  begin
    h := (h xor q^) * 1099511628211;
    h := h xor (h shr 29);
    Inc(q);
  end;
  b := PByte(q);
  for k := 1 to n mod 8 do
  begin
    h := (h xor b^) * 1099511628211;
    Inc(b);
  end;
  Result := h;
end;
{$POP}

// a filter layer: what is under it (everything drawn so far) goes through the filter, in the whole page or only inside
// the closed figures of the layer
type
  TSingleArray = array of Single;
  TBoolArray = array of Boolean;

// how much of the effect of a filter is kept at each pixel of a w x h area: 1 inside, less and less towards the borders of the
// domain, over `feather` pixels. The domain is the pixels that are `inside` (nil: all of them) and the rectangle (rl, rt, rr, rb)
// (the page, or the picture); what is out of the area is not in the domain when `inside` is given
function FeatherMap(w, h: Integer; const inside: TBoolArray; feather, featherIn: Double; rl, rt, rr, rb: Integer): TSingleArray;
var
  d, e: array of Single;
  hole, reach: array of Boolean;
  stack: array of Integer;
  sp, x, y, k, nk: Integer;
  dm, t, a, a2: Single;
  anyHole: Boolean;

  procedure Chamfer(var v: array of Single);
  var
    xx, yy, kk: Integer;

    procedure Relax(k1, k2: Integer; c: Single);
    begin
      if v[k2] + c < v[k1] then v[k1] := v[k2] + c;
    end;

  begin
    for yy := 0 to h - 1 do
      for xx := 0 to w - 1 do
      begin
        kk := yy * w + xx;
        if xx > 0 then Relax(kk, kk - 1, 1);
        if yy > 0 then
        begin
          Relax(kk, kk - w, 1);
          if xx > 0 then Relax(kk, kk - w - 1, 1.4142);
          if xx < w - 1 then Relax(kk, kk - w + 1, 1.4142);
        end;
      end;
    for yy := h - 1 downto 0 do
      for xx := w - 1 downto 0 do
      begin
        kk := yy * w + xx;
        if xx < w - 1 then Relax(kk, kk + 1, 1);
        if yy < h - 1 then
        begin
          Relax(kk, kk + w, 1);
          if xx > 0 then Relax(kk, kk + w - 1, 1.4142);
          if xx < w - 1 then Relax(kk, kk + w + 1, 1.4142);
        end;
      end;
  end;

  function Smooth(dist, f: Single): Single;
  begin
    if f <= 0 then
    begin
      if dist > 0 then Exit(1) else Exit(0);
    end;
    t := dist / f;
    if t >= 1 then Result := 1
    else if t <= 0 then Result := 0
    else Result := t * t * (3 - 2 * t);
  end;

begin
  SetLength(Result, w * h);
  d := nil;
  e := nil;
  anyHole := False;
  if Length(inside) > 0 then
  begin
    // what is outside the area and can be reached from the edge of the picture is the outside; the rest are holes
    SetLength(reach, w * h);
    SetLength(hole, w * h);
    SetLength(stack, w * h);
    for k := 0 to w * h - 1 do reach[k] := False;
    sp := 0;
    for x := 0 to w - 1 do
      for y := 0 to h - 1 do
        if ((x = 0) or (x = w - 1) or (y = 0) or (y = h - 1)) and not inside[y * w + x] and not reach[y * w + x] then
        begin
          reach[y * w + x] := True;
          stack[sp] := y * w + x;
          Inc(sp);
        end;
    while sp > 0 do
    begin
      Dec(sp);
      k := stack[sp];
      x := k mod w;
      y := k div w;
      if x > 0 then begin nk := k - 1; if not inside[nk] and not reach[nk] then begin reach[nk] := True; stack[sp] := nk; Inc(sp); end; end;
      if x < w - 1 then begin nk := k + 1; if not inside[nk] and not reach[nk] then begin reach[nk] := True; stack[sp] := nk; Inc(sp); end; end;
      if y > 0 then begin nk := k - w; if not inside[nk] and not reach[nk] then begin reach[nk] := True; stack[sp] := nk; Inc(sp); end; end;
      if y < h - 1 then begin nk := k + w; if not inside[nk] and not reach[nk] then begin reach[nk] := True; stack[sp] := nk; Inc(sp); end; end;
    end;
    for k := 0 to w * h - 1 do
    begin
      hole[k] := not inside[k] and not reach[k];
      if hole[k] then anyHole := True;
    end;
    SetLength(d, w * h);
    for k := 0 to w * h - 1 do
      if not inside[k] and reach[k] then d[k] := 0 else d[k] := 1e9;
    // the pixels at the border of the area touch what is outside
    for x := 0 to w - 1 do
    begin
      if d[x] > 1 then d[x] := 1;
      if d[(h - 1) * w + x] > 1 then d[(h - 1) * w + x] := 1;
    end;
    for y := 0 to h - 1 do
    begin
      if d[y * w] > 1 then d[y * w] := 1;
      if d[y * w + w - 1] > 1 then d[y * w + w - 1] := 1;
    end;
    Chamfer(d);
    if anyHole then
    begin
      SetLength(e, w * h);
      for k := 0 to w * h - 1 do
        if hole[k] then e[k] := 0 else e[k] := 1e9;
      Chamfer(e);
    end;
  end;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      k := y * w + x;
      dm := Min(Min(x + 0.5 - rl, rr - (x + 0.5)), Min(y + 0.5 - rt, rb - (y + 0.5)));
      if Length(d) > 0 then dm := Min(dm, d[k] - 0.5);
      a := Smooth(dm, feather);
      if (Length(e) > 0) and (featherIn > 0) then
      begin
        a2 := Smooth(e[k] - 0.5, featherIn);
        if a2 < a then a := a2;
      end;
      if (Length(inside) > 0) and not inside[k] then a := 0;
      Result[k] := a;
    end;
end;

procedure TForm1.ApplyFilterLayer(acc: TBGRABitmap; l: TLayer; z: Double; ox, oy: Integer);
var
  reg, bb: TRect;
  i, j, k, x, y, w, h, nShapes, nClosed, bpp: Integer;
  s: TShape;
  o: TOutline;
  lps: TFLoopArray;
  bp: TFPtArray;
  pts: array of TPoint;
  mk, d: TBitmap;
  mi, li: TLazIntfImage;
  mrow, row: PByte;
  mask: array of Boolean;
  f, fa: Double;
  r, g, b, r0, g0, b0: Byte;
  scr: TFltScript;
  err: string;
  img: TFltImage;
  px: PBGRAPixel;
  oa, na: Integer;
  ra: Double;
  key: QWord;
  rw, rh, kk, ci: Integer;
  vals: TFltValues;
  v: DWord;
  rs, gs, bs: Integer;
  dc: TFPColor;
  minx, miny, maxx, maxy: Integer;
  masked: Boolean;
  fw: TSingleArray;
  ins: TBoolArray;
  fe: Double;
begin
  if (not l.IsFilter) or (l.FScript = '') then Exit;
  reg := Rect(0, 0, acc.Width, acc.Height);
  if (reg.Right <= reg.Left) or (reg.Bottom <= reg.Top) then Exit;
  // with something drawn in the layer the filter works only inside its closed figures
  nShapes := 0;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.LayerOf(Doc.Shapes[i]) = l then Inc(nShapes);
  masked := nShapes > 0;
  bb := reg;
  if masked then
  begin
    minx := MaxInt; miny := MaxInt; maxx := -MaxInt; maxy := -MaxInt;
    for i := 0 to Doc.Shapes.Count - 1 do
    begin
      s := Doc.Shapes[i];
      if Doc.LayerOf(s) <> l then Continue;
      o := ShapeOutline(s);
      for j := 0 to High(o) do
        if o[j].Closed and (Length(o[j].Pts) >= 3) then
          for k := 0 to High(o[j].Pts) do
          begin
            minx := Min(minx, Floor(o[j].Pts[k].x * z) - ox);
            miny := Min(miny, Floor(o[j].Pts[k].y * z) - oy);
            maxx := Max(maxx, Ceil(o[j].Pts[k].x * z) - ox);
            maxy := Max(maxy, Ceil(o[j].Pts[k].y * z) - oy);
          end;
    end;
    if minx > maxx then Exit;              // nothing closed: nothing to filter
    bb := Rect(Max(reg.Left, minx), Max(reg.Top, miny), Min(reg.Right, maxx + 1), Min(reg.Bottom, maxy + 1));
    if (bb.Right <= bb.Left) or (bb.Bottom <= bb.Top) then Exit;
  end;
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  SetLength(mask, 0);
  if masked then
  begin
    mk := TBitmap.Create;
    try
      mk.SetSize(w, h);
      mk.Canvas.Brush.Style := bsSolid;
      mk.Canvas.Brush.Color := clBlack;
      mk.Canvas.FillRect(0, 0, w, h);
      mk.Canvas.Brush.Color := clWhite;
      mk.Canvas.Pen.Style := psClear;
      for i := 0 to Doc.Shapes.Count - 1 do
      begin
        s := Doc.Shapes[i];
        if Doc.LayerOf(s) <> l then Continue;
        o := ShapeOutline(s);
        nClosed := 0;
        for j := 0 to High(o) do
          if o[j].Closed and (Length(o[j].Pts) >= 3) then Inc(nClosed);
        if nClosed > 1 then
        begin
          // closed curves inside each other are holes: joined into one polygon by thin bridges
          SetLength(lps, 0);
          for j := 0 to High(o) do
            if o[j].Closed and (Length(o[j].Pts) >= 3) then
            begin
              SetLength(lps, Length(lps) + 1);
              SetLength(lps[High(lps)].Pts, Length(o[j].Pts));
              for k := 0 to High(o[j].Pts) do
              begin
                lps[High(lps)].Pts[k].x := o[j].Pts[k].x;
                lps[High(lps)].Pts[k].y := o[j].Pts[k].y;
              end;
            end;
          bp := BridgeLoops(lps);
          SetLength(pts, Length(bp));
          for k := 0 to High(bp) do
          begin
            pts[k].x := Round(bp[k].x * z) - ox - bb.Left;
            pts[k].y := Round(bp[k].y * z) - oy - bb.Top;
          end;
          if Length(pts) >= 3 then mk.Canvas.Polygon(pts);
        end
        else
          for j := 0 to High(o) do
            if o[j].Closed and (Length(o[j].Pts) >= 3) then
            begin
              SetLength(pts, Length(o[j].Pts));
              for k := 0 to High(o[j].Pts) do
              begin
                pts[k].x := Round(o[j].Pts[k].x * z) - ox - bb.Left;
                pts[k].y := Round(o[j].Pts[k].y * z) - oy - bb.Top;
              end;
              mk.Canvas.Polygon(pts);
            end;
      end;
      mi := mk.CreateIntfImage;
      try
        bpp := Max(1, mi.DataDescription.BitsPerPixel div 8);
        SetLength(mask, w * h);
        for y := 0 to h - 1 do
        begin
          mrow := mi.GetDataLineStart(y);
          for x := 0 to w - 1 do mask[y * w + x] := mrow[x * bpp] > 127;
        end;
      finally
        mi.Free;
      end;
    finally
      mk.Free;
    end;
  end;
  scr := ScriptFor(l.FScript, err);
  if scr = nil then
  begin
    SetStatus('Filter "' + l.FName + '": ' + err);
    Exit;
  end;
  f := l.Opacity / 255;
  rw := reg.Right - reg.Left;
  rh := reg.Bottom - reg.Top;
  vals := nil;
  SetLength(vals, Length(scr.Params));
  for i := 0 to High(vals) do
    if i <= High(l.FVals) then vals[i] := l.FVals[i] else vals[i] := scr.Params[i].Def;
  // everything drawn so far (not premultiplied: the colour and the opacity of each pixel), as four planes of bytes
  img.W := rw;
  img.H := rh;
  SetLength(img.R, rw * rh);
  SetLength(img.G, rw * rh);
  SetLength(img.B, rw * rh);
  SetLength(img.A, rw * rh);
  for y := 0 to rh - 1 do
  begin
    px := acc.ScanLine[y];
    for x := 0 to rw - 1 do
    begin
      img.R[y * rw + x] := px^.red;
      img.G[y * rw + x] := px^.green;
      img.B[y * rw + x] := px^.blue;
      img.A[y * rw + x] := px^.alpha;
      Inc(px);
    end;
  end;
  // the same input, script, values, strength and mask as the last time: the result is already there
  key := HashBytes(@img.R[0], rw * rh, 14695981039346656037);
  key := HashBytes(@img.G[0], rw * rh, key);
  key := HashBytes(@img.B[0], rw * rh, key);
  key := HashBytes(@img.A[0], rw * rh, key);
  if Length(mask) > 0 then key := HashBytes(@mask[0], Length(mask), key);
  key := HashBytes(PChar(l.FScript), Length(l.FScript), key);
  if Length(vals) > 0 then key := HashBytes(@vals[0], Length(vals) * SizeOf(Double), key);
  key := HashBytes(@z, SizeOf(z), key);
  key := HashBytes(@l.Opacity, SizeOf(l.Opacity), key);
  key := HashBytes(@bb, SizeOf(bb), key);
  key := HashBytes(@l.FFeather, SizeOf(l.FFeather), key);
  key := HashBytes(@l.FFeatherIn, SizeOf(l.FFeatherIn), key);
  key := HashBytes(@ox, SizeOf(ox), key);
  key := HashBytes(@oy, SizeOf(oy), key);
  ci := -1;
  for i := 0 to High(FltCache) do
    if FltCache[i].Layer = l then ci := i;
  if (ci >= 0) and (FltCache[ci].Key = key) then
  begin
    acc.PutImage(FltCache[ci].BB.Left, FltCache[ci].BB.Top, FltCache[ci].Bmp, dmSet);
    Exit;
  end;
  if not scr.RunAt(img, vals, z, bb, ox, oy, Round(Doc.Width * z), Round(Doc.Height * z), err) then
  begin
    SetStatus('Filter "' + l.FName + '": ' + err);
    Exit;
  end;
  // the effect fades towards the borders of the domain: the page, or the closed figures of the layer
  fw := nil;
  if (l.FFeather > 0) or (l.FFeatherIn > 0) then
  begin
    ins := nil;
    if masked then
    begin
      SetLength(ins, w * h);
      for k := 0 to w * h - 1 do ins[k] := mask[k];
    end;
    fw := FeatherMap(w, h, ins, l.FFeather * z, l.FFeatherIn * z, -ox - bb.Left, -oy - bb.Top,
      Round(Doc.Width * z) - ox - bb.Left, Round(Doc.Height * z) - oy - bb.Top);
  end;
  for y := 0 to h - 1 do
  begin
    px := acc.ScanLine[bb.Top + y] + bb.Left;
    for x := 0 to w - 1 do
    begin
      if (not masked) or mask[y * w + x] then
      begin
        kk := (bb.Top + y) * rw + bb.Left + x;
        fe := f;
        if Length(fw) > 0 then fe := f * fw[y * w + x];
        if fe >= 1 then
        begin
          px^.red := img.R[kk];
          px^.green := img.G[kk];
          px^.blue := img.B[kk];
          px^.alpha := img.A[kk];
        end
        else
        begin
          // between the old pixel and the new one, in premultiplied colours
          oa := px^.alpha;
          na := img.A[kk];
          ra := oa + (na - oa) * fe;
          if ra < 0.5 then
            px^ := BGRAPixelTransparent
          else
          begin
            px^.red := Min(255, Round((px^.red * oa + (img.R[kk] * na - px^.red * oa) * fe) / ra));
            px^.green := Min(255, Round((px^.green * oa + (img.G[kk] * na - px^.green * oa) * fe) / ra));
            px^.blue := Min(255, Round((px^.blue * oa + (img.B[kk] * na - px^.blue * oa) * fe) / ra));
            px^.alpha := Round(ra);
          end;
        end;
      end;
      Inc(px);
    end;
  end;
  acc.InvalidateBitmap;
  // kept for the next time (one result for each filter layer)
  if ci < 0 then
  begin
    if Length(FltCache) >= 6 then
    begin
      FltCache[0].Bmp.Free;
      Delete(FltCache, 0, 1);
    end;
    SetLength(FltCache, Length(FltCache) + 1);
    ci := High(FltCache);
  end
  else FltCache[ci].Bmp.Free;
  FltCache[ci].Layer := l;
  FltCache[ci].Key := key;
  FltCache[ci].BB := bb;
  FltCache[ci].Bmp := acc.GetPart(bb) ;
end;

// a run of objects (ord[i0] .. ord[i1], and the quotes if asked) drawn twice, on white and on black: from the two
// pictures come the colour and the opacity of every pixel of what they make
function TForm1.RenderRun(const ord: TShapeArray; i0, i1: Integer; w, h: Integer; z: Double; editView, quotes: Boolean; ox, oy: Integer): TBGRABitmap;
var
  bmp: array[0..1] of TBitmap;
  px: array[0..1] of TBGRABitmap;
  pass, i, x, y, d, a, nextL: Integer;
  underCol: TColor;
  oldW, oldH, oldAAS, oldX0, oldY0: Integer;
  oldOK, smooth: Boolean;
  pw, pb, pr: PBGRAPixel;
begin
  Result := TBGRABitmap.Create(w, h, BGRAPixelTransparent);
  oldW := AlphaW;
  oldH := AlphaH;
  oldX0 := AlphaX0;
  oldY0 := AlphaY0;
  oldAAS := AAS;
  oldOK := AlphaOK;
  smooth := AAS > 1;
  for pass := 0 to 1 do
  begin
    bmp[pass] := TBitmap.Create;
    px[pass] := nil;
  end;
  try
    for pass := 0 to 1 do
    begin
      bmp[pass].SetSize(w, h);
      SetViewPortOrgEx(bmp[pass].Canvas.Handle, -ox, -oy, nil);
      if pass = 0 then underCol := clWhite else underCol := clBlack;
      bmp[pass].Canvas.Brush.Color := underCol;
      bmp[pass].Canvas.Brush.Style := bsSolid;
      bmp[pass].Canvas.FillRect(ox, oy, ox + w, oy + h);
      SetAlphaSize(w, h, smooth);
      AlphaX0 := ox;
      AlphaY0 := oy;
      AlphaOK := True;
      CovOn := True;
      if i1 >= i0 then nextL := Doc.Layers.IndexOf(Doc.LayerOf(ord[i0])) else nextL := Doc.Layers.Count;
      for i := i0 to i1 do
      begin
        DrawLayerBgs(bmp[pass].Canvas, z, nextL, BgLayerIdx(ord[i]), underCol);
        if ord[i].IsRef and (not editView or not Doc.ShapeVisible(ord[i])) then Continue;
        RenderShape(bmp[pass].Canvas, ord[i], z, editView);
        if ord[i].HatchPat > 0 then DrawHatch(bmp[pass].Canvas, ord[i], z);
        if ord[i].Spray then DrawSpray(bmp[pass].Canvas, ord[i], z);
      end;
      if quotes then
        for i := 0 to Doc.Cons.Count - 1 do
          if Doc.Cons[i].IsQuote and not Doc.Cons[i].NoPrint then DrawQuote(bmp[pass].Canvas, Doc.Cons[i], z, True);
      SetViewPortOrgEx(bmp[pass].Canvas.Handle, 0, 0, nil);
      px[pass] := TBGRABitmap.Create(bmp[pass]);
    end;
    // over black the pixel is the colour times the opacity, over white it is that plus what the opacity lets through
    for y := 0 to h - 1 do
    begin
      pw := px[0].ScanLine[y];
      pb := px[1].ScanLine[y];
      pr := Result.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        d := ((pw^.red - pb^.red) + (pw^.green - pb^.green) + (pw^.blue - pb^.blue)) div 3;
        a := 255 - d;
        if a > 255 then a := 255;
        if a <= 0 then pr^ := BGRAPixelTransparent
        else if a >= 255 then
        begin
          pr^.red := pb^.red;
          pr^.green := pb^.green;
          pr^.blue := pb^.blue;
          pr^.alpha := 255;
        end
        else
        begin
          pr^.red := Min(255, (pb^.red * 255 + a div 2) div a);
          pr^.green := Min(255, (pb^.green * 255 + a div 2) div a);
          pr^.blue := Min(255, (pb^.blue * 255 + a div 2) div a);
          pr^.alpha := a;
        end;
        Inc(pw);
        Inc(pb);
        Inc(pr);
      end;
    end;
    Result.InvalidateBitmap;
  finally
    for pass := 0 to 1 do
    begin
      px[pass].Free;
      bmp[pass].Free;
    end;
    CovOn := False;
    AlphaW := oldW;
    AlphaH := oldH;
    AlphaX0 := oldX0;
    AlphaY0 := oldY0;
    AAS := oldAAS;
    AlphaOK := oldOK;
  end;
end;

// what the drawing looks like apart from the filter layers (their values do not count: the groups of objects under them
// stay the same while they are being tried)
function TForm1.DocStamp: QWord;
var
  k, i: Integer;
  l: TLayer;
  sv: array of record
    V: array of Double;
    S: string;
    O: Integer;
  end;
  txt: string;
begin
  SetLength(sv, Doc.Layers.Count);
  for k := 0 to Doc.Layers.Count - 1 do
  begin
    l := Doc.Layers[k];
    if not l.IsFilter then Continue;
    sv[k].V := l.FVals;
    sv[k].S := l.FScript;
    sv[k].O := l.Opacity;
    l.FVals := nil;
    l.FScript := '';
    l.Opacity := 0;
  end;
  try
    txt := DocToSVG(Doc, False, nil);
  finally
    for k := 0 to Doc.Layers.Count - 1 do
      if Doc.Layers[k].IsFilter then
      begin
        Doc.Layers[k].FVals := sv[k].V;
        Doc.Layers[k].FScript := sv[k].S;
        Doc.Layers[k].Opacity := sv[k].O;
      end;
  end;
  Result := HashBytes(PChar(txt), Length(txt), 14695981039346656037);
  CovCur := Result;
  for i := 0 to High(Sel) do Result := HashBytes(@Sel[i], SizeOf(TRef), Result);
  Result := HashBytes(@HoverShape, SizeOf(HoverShape), Result);
  Result := HashBytes(@HighlightCons, SizeOf(HighlightCons), Result);
end;

// the same, from the cache when the stamp, the range, the size and the zoom are the same as last time (the bitmap belongs
// to the cache: not to be freed)
function TForm1.RenderRunCached(const ord: TShapeArray; i0, i1: Integer; w, h: Integer; z: Double; editView, quotes: Boolean; stamp: QWord; ox, oy: Integer): TBGRABitmap;
var
  key: QWord;
  i: Integer;
begin
  key := HashBytes(@stamp, SizeOf(stamp), 1469598103934665603);
  key := HashBytes(@i0, SizeOf(i0), key);
  key := HashBytes(@i1, SizeOf(i1), key);
  key := HashBytes(@w, SizeOf(w), key);
  key := HashBytes(@h, SizeOf(h), key);
  key := HashBytes(@ox, SizeOf(ox), key);
  key := HashBytes(@oy, SizeOf(oy), key);
  key := HashBytes(@z, SizeOf(z), key);
  key := HashBytes(@editView, SizeOf(editView), key);
  key := HashBytes(@quotes, SizeOf(quotes), key);
  key := HashBytes(@AAS, SizeOf(AAS), key);
  for i := 0 to High(RunCache) do
    if RunCache[i].Key = key then
    begin
      Result := RunCache[i].Bmp;
      Exit;
    end;
  Result := RenderRun(ord, i0, i1, w, h, z, editView, quotes, ox, oy);
  if Length(RunCache) >= 6 then
  begin
    RunCache[0].Bmp.Free;
    Delete(RunCache, 0, 1);
  end;
  SetLength(RunCache, Length(RunCache) + 1);
  RunCache[High(RunCache)].Key := key;
  RunCache[High(RunCache)].Bmp := Result;
end;

// the document as colours with opacity (a page with nothing on it is transparent): the objects of the layers
// between two filter layers are drawn together, each filter works on what is under it
function TForm1.RenderDocRgba(w, h: Integer; z: Double; editView: Boolean; ox, oy: Integer): TBGRABitmap;
var
  i, k, li, nf, s0: Integer;
  ord: TShapeArray;
  fl: array of Integer;
  run: TBGRABitmap;
  stamp: QWord;

  procedure Flush(i1: Integer);
  begin
    if i1 < s0 then Exit;
    run := RenderRunCached(ord, s0, i1, w, h, z, editView, False, stamp, ox, oy);
    Result.PutImage(0, 0, run, dmDrawWithTransparency);
  end;

begin
  Doc.UpdateFillets;
  stamp := DocStamp;
  if CovCur <> CovStamp then
  begin
    SetLength(CovList, 0);
    CovBytes := 0;
    CovStamp := CovCur;
  end;
  Result := TBGRABitmap.Create(w, h, BGRAPixelTransparent);
  SetLength(fl, 0);
  for k := 0 to Doc.Layers.Count - 1 do
    if Doc.Layers[k].IsFilter and Doc.Layers[k].Visible and (Doc.Layers[k].FScript <> '') and (Doc.Layers[k].Opacity > 0) then
    begin
      SetLength(fl, Length(fl) + 1);
      fl[High(fl)] := k;
    end;
  nf := 0;
  s0 := 0;
  ord := Doc.DrawOrder;
  for i := 0 to High(ord) do
  begin
    li := Doc.Layers.IndexOf(Doc.LayerOf(ord[i]));
    while (nf <= High(fl)) and (fl[nf] <= li) do
    begin
      Flush(i - 1);
      s0 := i;
      ApplyFilterLayer(Result, Doc.Layers[fl[nf]], z, ox, oy);
      Inc(nf);
    end;
  end;
  Flush(High(ord));
  s0 := Length(ord);
  while nf <= High(fl) do
  begin
    ApplyFilterLayer(Result, Doc.Layers[fl[nf]], z, ox, oy);
    Inc(nf);
  end;
  if not editView then
  begin
    run := RenderRunCached(ord, 0, -1, w, h, z, editView, True, stamp, ox, oy);
    Result.PutImage(0, 0, run, dmDrawWithTransparency);
  end;
end;

// with filter layers the picture is made with opacity, then laid over what is already in the canvas (the page)
procedure TForm1.RenderDoc(cnv: TCanvas; z: Double; editView: Boolean);
var
  rw, rh, ox, oy: Integer;
  acc, small: TBGRABitmap;
begin
  if AlphaOK and Doc.HasFilter then
  begin
    ox := AlphaX0;
    oy := AlphaY0;
    rw := Min(AlphaW, Round(Doc.Width * z) - ox);
    rh := Min(AlphaH, Round(Doc.Height * z) - oy);
    if (rw > 0) and (rh > 0) then
    begin
      if FastMode and (rw >= 200) and (rh >= 200) then
      begin
        // while something is moved the filters work on half the size (a quarter of the pixels) and the result is enlarged
        small := RenderDocRgba((rw + 1) div 2, (rh + 1) div 2, z / 2, editView, ox div 2, oy div 2);
        try
          acc := small.Resample(rw, rh, rmSimpleStretch) as TBGRABitmap;
        finally
          small.Free;
        end;
      end
      else acc := RenderDocRgba(rw, rh, z, editView, ox, oy);
      try
        acc.Draw(cnv, ox, oy, False);
      finally
        acc.Free;
      end;
      Exit;
    end;
  end;
  RenderDocDirect(cnv, z, editView);
end;

// the backgrounds of the layers up to the layer number upTo (the ones not drawn yet): the whole page, over what is under
procedure TForm1.DrawLayerBgs(cnv: TCanvas; z: Double; var nextL: Integer; upTo: Integer; under: TColor);
var
  l: TLayer;
  pr, cr: TRect;
  w, h: Integer;
  cov: TByteDyn;
begin
  while nextL <= upTo do
  begin
    l := Doc.Layers[nextL];
    if l.Visible and not l.IsFilter and (l.Bg <> NoColor) then
    begin
      cnv.Brush.Style := bsSolid;
      cnv.Brush.Color := TColor(l.Bg);
      if l.Opacity < 255 then
      begin
        // the opacity of the layer: the colour is mixed with what is already there (the layers under it)
        pr := Rect(0, 0, Round(Doc.Width * z), Round(Doc.Height * z));
        cr := cnv.ClipRect;
        if (cr.Right > cr.Left) and (cr.Bottom > cr.Top) then IntersectRect(pr, pr, cr);
        w := Max(0, pr.Right - pr.Left);
        h := Max(0, pr.Bottom - pr.Top);
        if (w > 0) and (h > 0) then
        begin
          cov := nil;
          SetLength(cov, w * h);
          FillChar(cov[0], Length(cov), 255);
          BlendMask(cnv, pr, TColor(l.Bg), l.Opacity, cov);
        end;
        Inc(nextL);
        Continue;
      end;
      cnv.FillRect(0, 0, Round(Doc.Width * z), Round(Doc.Height * z));
    end;
    Inc(nextL);
  end;
end;

procedure TForm1.RenderDocDirect(cnv: TCanvas; z: Double; editView: Boolean);
var
  i, nextL: Integer;
  ord: TShapeArray;
begin
  Doc.UpdateFillets;
  // layer by layer from the bottom; hidden layers are not drawn
  ord := Doc.DrawOrder;
  nextL := 0;
  // the halos of the selection first, under all the objects
  if editView and (Length(Sel) > 0) and HaloPreOK then
  begin
    DrawSelHalos(cnv, ord, 0, High(ord), z);
    SelHaloPre := True;
  end;
  try
    for i := 0 to High(ord) do
    begin
      DrawLayerBgs(cnv, z, nextL, BgLayerIdx(ord[i]));
      if ord[i].IsRef and (not editView or not Doc.ShapeVisible(ord[i])) then Continue;
      RenderShape(cnv, ord[i], z, editView);
      if ord[i].HatchPat > 0 then DrawHatch(cnv, ord[i], z);
      if ord[i].Spray then DrawSpray(cnv, ord[i], z);
    end;
  finally
    SelHaloPre := False;
  end;
  DrawLayerBgs(cnv, z, nextL, Doc.Layers.Count - 1);
  if not editView then
    for i := 0 to Doc.Cons.Count - 1 do
      if Doc.Cons[i].IsQuote and not Doc.Cons[i].NoPrint then DrawQuote(cnv, Doc.Cons[i], z, True);
end;

// "snap to lines" on: the points that attract are shown
procedure TForm1.DrawSnapMarkers(cnv: TCanvas);
var
  refs: TRefArray;
  pts: TPtArray;
  i: Integer;
  p: TPoint;
begin
  if (toolSnapLine = nil) or not toolSnapLine.Down then Exit;
  EnumSnapPoints(nil, refs, pts);
  cnv.Pen.Color := TColor($0090FF);
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psSolid;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := clWhite;
  for i := 0 to High(pts) do
  begin
    p := ScreenPt(pts[i]);
    cnv.Rectangle(p.x - 2, p.y - 2, p.x + 3, p.y + 3);
  end;
  cnv.Brush.Style := bsClear;
end;

// ends of side seg of a rectangle (0 top, 1 right, 2 bottom, 3 left), polygon or poly-line
function TForm1.SideEnds(s: TShape; seg: Integer; out a, b: TPt): Boolean;
var
  x1, y1, x2, y2: Double;
  n: Integer;
begin
  Result := False;
  if seg < 0 then Exit;
  case s.Kind of
    skRect:
      begin
        if Length(s.P) < 2 then Exit;
        x1 := Min(s.P[0].x, s.P[1].x);
        x2 := Max(s.P[0].x, s.P[1].x);
        y1 := Min(s.P[0].y, s.P[1].y);
        y2 := Max(s.P[0].y, s.P[1].y);
        case seg of
          0: begin a := MakePt(x1, y1); b := MakePt(x2, y1); end;
          1: begin a := MakePt(x2, y1); b := MakePt(x2, y2); end;
          2: begin a := MakePt(x1, y2); b := MakePt(x2, y2); end;
          3: begin a := MakePt(x1, y1); b := MakePt(x1, y2); end;
        else
          Exit;
        end;
        if s.Rot <> 0 then
        begin
          a := TurnPt(a, ShapePivot(s), s.Rot);
          b := TurnPt(b, ShapePivot(s), s.Rot);
        end;
        Result := True;
      end;
    skPolygon, skPolyline:
      begin
        n := Length(s.P);
        if (seg >= n) or ((s.Kind = skPolyline) and (seg >= n - 1)) then Exit;
        a := s.P[seg];
        b := s.P[(seg + 1) mod n];
        Result := True;
      end;
  end;
end;

// the side that was clicked (the whole figure is selected): marked more strongly, as the
// operand of quotes and constraints
procedure TForm1.DrawSelectedSide(cnv: TCanvas);
var
  i: Integer;
  s: TShape;
  a, b: TPt;
  pa, pb: TPoint;
begin
  if Drag in [dmShape, dmHandle, dmPoint] then Exit;
  for i := 0 to High(Sel) do
  begin
    if (Sel[i].Idx <> -1) or (Sel[i].Seg < 0) then Continue;
    s := Doc.FindShape(Sel[i].Shape);
    if (s = nil) or not SideEnds(s, Sel[i].Seg, a, b) then Continue;
    pa := ScreenPt(a);
    pb := ScreenPt(b);
    cnv.Pen.Style := psSolid;
    cnv.Pen.Width := 5;
    cnv.Pen.Color := TColor($FFFFFF);
    cnv.Line(pa.x, pa.y, pb.x, pb.y);
    cnv.Pen.Width := 3;
    cnv.Pen.Color := TColor($1E78FF);
    cnv.Line(pa.x, pa.y, pb.x, pb.y);
    cnv.Pen.Width := 1;
  end;
end;

procedure TForm1.DrawHandles(cnv: TCanvas);
var
  i, j, k: Integer;
  s: TShape;
  h: THandleArray;
  p: TPoint;
  r: TRef;
  selected, hot: Boolean;
  hoverBox: TShape;
begin
  cnv.Pen.Style := psSolid;
  cnv.Pen.Width := 1;
  if Tool = tlClone then DrawCloneGuides(cnv);
  if Tool = tlEraser then DrawEraseGuide(cnv);
  DrawFloatOutline(cnv);
  if CropActive then
  begin
    DrawCropBox(cnv);
    Exit;
  end;
  if PersActive then
  begin
    DrawPersBox(cnv);
    Exit;
  end;
  if RotMode and (Tool = tlSelect) then
  begin
    DrawRotBox(cnv);
    Exit;
  end;
  hoverBox := nil;
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    s := Doc.Shapes[i];
    if not IsActive(s) then Continue;
    if RotEligible(s) and not IsSelShape(s) then
    begin
      // the pointer is over an object that is not selected: the handles it will have when it is (a line has no box)
      if (Tool = tlSelect) and (Drag = dmNone) and (s.Kind <> skLine) then hoverBox := s;
      Continue;
    end;
    h := HandlesOf(s);
    for j := 0 to High(h) do
    begin
      p := ScreenPt(h[j].P);
      r := MakeRef(s.Id, h[j].Idx);
      selected := SelFind(r) >= 0;
      hot := SameRef(r, HoverRef) or (HasSnap and (Drag <> dmNone) and False);
      for k := 0 to High(Sel) do
        if (Sel[k].Shape = s.Id) and (Sel[k].Idx >= SegBase) then selected := selected;
      cnv.Pen.Color := ToCol(ColorSel);
      if hot then cnv.Brush.Color := TColor($0090FF)
      else if selected then cnv.Brush.Color := ToCol(ColorSel)
      else cnv.Brush.Color := clWhite;
      cnv.Brush.Style := bsSolid;
      if h[j].Ctl then
      begin
        // a control point: a small circle joined to its point by a thin line
        for k := 0 to High(h) do
          if h[k].Idx = h[j].Anc then
          begin
            cnv.Pen.Style := psDot;
            cnv.Line(ScreenPt(h[k].P).x, ScreenPt(h[k].P).y, p.x, p.y);
            cnv.Pen.Style := psSolid;
            Break;
          end;
        cnv.Ellipse(p.x - HandleSize + 1, p.y - HandleSize + 1, p.x + HandleSize, p.y + HandleSize);
      end
      else if h[j].Idx >= HandlePathBase then
        cnv.Rectangle(p.x - HandleSize + 1, p.y - HandleSize + 1, p.x + HandleSize, p.y + HandleSize)
      else if h[j].Idx >= HandleRX then
        cnv.Ellipse(p.x - HandleSize, p.y - HandleSize, p.x + HandleSize + 1, p.y + HandleSize + 1)
      else
        cnv.Rectangle(p.x - HandleSize, p.y - HandleSize, p.x + HandleSize + 1, p.y + HandleSize + 1);
    end;
  end;
  if hoverBox <> nil then DrawHoverBox(cnv, hoverBox);
  DrawGroupBox(cnv);
  if HasSnap and ((Drag in [dmPoint, dmCreate]) or (Creating <> nil) or (Tool <> tlSelect)) then
  begin
    // snap indicator
    p := ScreenPt(SnapAt);
    cnv.Pen.Color := TColor($0090FF);
    cnv.Pen.Width := 2;
    cnv.Brush.Style := bsClear;
    cnv.Ellipse(p.x - 8, p.y - 8, p.x + 9, p.y + 9);
  end;
end;

function TForm1.QuoteEnds(c: TConstraint; out a, b: TPt): Boolean;
begin
  Result := Doc.QuoteEnds(c, a, b);
end;

procedure TForm1.QuoteDragTo(c: TConstraint; px, py: Double);
var
  a, b: TPt;
  s: TShape;
  L: Double;
begin
  if c.Kind = ckRadius then
  begin
    s := Doc.EllOf(c.Refs[0]);
    if s <> nil then c.Offset := ArcTan2(py - s.P[0].y, px - s.P[0].x);
    Exit;
  end;
  if c.Kind = ckAngle then
  begin
    if Doc.QuoteAngle(c, a, L, L) then c.Offset := Max(8, Dist(a, MakePt(px, py)));
    Exit;
  end;
  if not QuoteEnds(c, a, b) then Exit;
  case c.Axis of
    1: c.Offset := Min(a.y, b.y) - py;
    2: c.Offset := Min(a.x, b.x) - px;
  else
    L := Dist(a, b);
    if L > 1e-9 then
      c.Offset := (px - a.x) * (-(b.y - a.y) / L) + (py - a.y) * ((b.x - a.x) / L);
  end;
end;

procedure TForm1.DrawQuote(cnv: TCanvas; c: TConstraint; z: Double; forOutput: Boolean);
var
  g: TQuoteGeom;
  i, j: Integer;
  r: TRect;
  tw, th: Integer;
  isSel: Boolean;
  pts: array of TPoint;
  tp: TPoint;

  function Sc(const p: TPt): TPoint;
  begin
    Result.x := Round(p.x * z);
    Result.y := Round(p.y * z);
  end;

begin
  if not Doc.QuoteGeometry(c, z, g) then Exit;
  isSel := (c = SelQuote) and not forOutput;
  if isSel then cnv.Pen.Color := TColor($0000E0)
  else if c.NoPrint then cnv.Pen.Color := TColor($B4B4B4)     // reference only: grayed
  else cnv.Pen.Color := ToCol(ColorQuote);
  if forOutput then cnv.Pen.Width := Max(1, Round(z)) else cnv.Pen.Width := 1;
  cnv.Brush.Style := bsClear;
  for i := 0 to High(g.Segs) do
  begin
    if g.Segs[i].Dotted then cnv.Pen.Style := psDot else cnv.Pen.Style := psSolid;
    cnv.Line(Sc(g.Segs[i].A).x, Sc(g.Segs[i].A).y, Sc(g.Segs[i].B).x, Sc(g.Segs[i].B).y);
  end;
  cnv.Pen.Style := psSolid;
  if Length(g.Arc) > 1 then
  begin
    SetLength(pts, Length(g.Arc));
    for i := 0 to High(g.Arc) do pts[i] := Sc(g.Arc[i]);
    cnv.Polyline(pts);
  end;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := cnv.Pen.Color;
  for i := 0 to High(g.Heads) do
  begin
    SetLength(pts, 3);
    for j := 0 to 2 do pts[j] := Sc(g.Heads[i][j]);
    cnv.Polygon(pts);
  end;
  cnv.Brush.Style := bsClear;
  if forOutput then cnv.Font.Height := -Max(6, Round(12 * z)) else cnv.Font.Height := -12;
  cnv.Font.Color := cnv.Pen.Color;
  tw := cnv.TextWidth(g.Text);
  th := cnv.TextHeight(g.Text);
  tp := Sc(g.TextPos);
  r := Rect(tp.x - tw div 2 - 3, tp.y - th div 2 - 1, tp.x + tw div 2 + 3, tp.y + th div 2 + 1);
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := clWhite;
  if forOutput then cnv.FillRect(r) else cnv.Rectangle(r);
  cnv.Brush.Style := bsClear;
  cnv.TextOut(r.Left + 3, r.Top + 1, g.Text);
  if forOutput then Exit;
  SetLength(QuoteHits, Length(QuoteHits) + 1);
  QuoteHits[High(QuoteHits)].C := c;
  QuoteHits[High(QuoteHits)].R := r;
end;

procedure TForm1.DrawBadges(cnv: TCanvas);
var
  i, j, n: Integer;
  c: TConstraint;
  a: TPt;
  sp: TPoint;
  counts: TStringList;
  key: string;
  idx: Integer;
  sym: string;
  r: TRect;
  sh: TShape;
begin
  counts := TStringList.Create;
  try
    for i := 0 to Doc.Cons.Count - 1 do
    begin
      c := Doc.Cons[i];
      if c.IsQuote then Continue;
      sh := Doc.FindShape(c.Refs[0].Shape);
      if (sh <> nil) and (Doc.LayerOf(sh) <> nil) and Doc.LayerOf(sh).HideCons then Continue;
      a := Doc.ConstraintAnchor(c);
      key := IntToStr(c.Refs[0].Shape);
      idx := counts.IndexOf(key);
      if idx < 0 then idx := counts.AddObject(key, TObject(PtrInt(0)));
      n := PtrInt(counts.Objects[idx]);
      counts.Objects[idx] := TObject(PtrInt(n + 1));
      sp := ScreenPt(a);
      sym := ConsSymbol[c.Kind];
      cnv.Font.Height := -11;
      cnv.Font.Color := clBlack;
      r := Rect(sp.x + 6 + n * 22, sp.y - 20, sp.x + 6 + n * 22 + Max(18, cnv.TextWidth(sym) + 6), sp.y - 5);
      cnv.Brush.Style := bsSolid;
      if c = HighlightCons then cnv.Brush.Color := TColor($60C0FF) else cnv.Brush.Color := TColor($C8F4FF);
      cnv.Pen.Color := clGray;
      cnv.Pen.Width := 1;
      cnv.Pen.Style := psSolid;
      cnv.Rectangle(r);
      cnv.Brush.Style := bsClear;
      cnv.TextOut(r.Left + 3, r.Top, sym);
      if c = HighlightCons then
      begin
        for j := 0 to High(c.Refs) do ;
      end;
    end;
  finally
    counts.Free;
  end;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  i, pw, ph, ox, oy, vw, vh: Integer;
  c: TConstraint;
begin
  if not StartPainted then StartMark('first paint begins');
  if ZoomHold then
  begin
    // an exposure while the zoom is being applied: the last picture, enlarged or reduced, instead of the bare background
    if (BufZoom > 0) and (Buf.Width > 0) and (Buf.Height > 0) then
      PaintBox1.Canvas.StretchDraw(Rect(Round(BufOx * Zoom / BufZoom), Round(BufOy * Zoom / BufZoom),
        Round((BufOx + Buf.Width) * Zoom / BufZoom), Round((BufOy + Buf.Height) * Zoom / BufZoom)), Buf);
    Exit;
  end;
  // while the zoom is changing the last picture is shown, enlarged or reduced (at once, whatever the document is); the right one is
  // drawn when the zoom has stopped (ZoomSettleTick)
  if ZoomFast and (BufZoom > 0) and (Buf.Width > 0) and (Buf.Height > 0) and (Drag = dmNone) and (Creating = nil) then
  begin
    PaintBox1.Canvas.StretchDraw(Rect(Round(BufOx * Zoom / BufZoom), Round(BufOy * Zoom / BufZoom),
      Round((BufOx + Buf.Width) * Zoom / BufZoom), Round((BufOy + Buf.Height) * Zoom / BufZoom)), Buf);
      Exit;
  end;
  Doc.UpdateFillets;
  pw := Round(Doc.Width * Zoom);
  ph := Round(Doc.Height * Zoom);
  // only the part of the page that is on screen is drawn (the whole page at a big zoom would be a huge picture); the canvas
  // of the buffer has its origin moved, so everything is still drawn at its place in the page
  ox := 0;
  oy := 0;
  vw := PaintBox1.Width;
  vh := PaintBox1.Height;
  begin
    ox := Max(0, Min(PaintBox1.Width - 1, ScrollBox1.HorzScrollBar.Position - 16));
    oy := Max(0, Min(PaintBox1.Height - 1, ScrollBox1.VertScrollBar.Position - 16));
    vw := Min(PaintBox1.Width - ox, ScrollBox1.ClientWidth + 32);
    vh := Min(PaintBox1.Height - oy, ScrollBox1.ClientHeight + 32);
  end;
  Buf.SetSize(vw, vh);
  SetViewPortOrgEx(Buf.Canvas.Handle, -ox, -oy, nil);
  with Buf.Canvas do
  begin
    Brush.Style := bsSolid;
    Brush.Color := TColor($D8D4D0);
    FillRect(ox, oy, ox + vw, oy + vh);
    Brush.Color := clWhite;
    FillRect(0, 0, pw, ph);
    // page edge, as in the original draft
    Pen.Color := RGB(21, 83, 158);
    Pen.Width := 3;
    Line(0, ph + 1, pw + 2, ph + 1);
    Line(pw + 1, 0, pw + 1, ph + 2);
    ClipRect := Rect(0, 0, pw, ph);
    Clipping := True;
  end;
  // while something is being dragged the edges are not smoothed (faster); they are when it stops
  FastMode := Interacting;
  SetAlphaSize(vw, vh, not FastMode);
  AlphaX0 := ox;
  AlphaY0 := oy;
  AlphaOK := True;
  if FastMode and (vw = PaintBox1.Width) and (vh = PaintBox1.Height) and FastRenderOK(pw, ph) then RenderFast(Buf.Canvas, pw, ph)
  else
  begin
    RenderDoc(Buf.Canvas, Zoom, True);
    if Creating <> nil then
    begin
      RenderShape(Buf.Canvas, Creating, Zoom, True);
      if Creating.Spray then DrawSpray(Buf.Canvas, Creating, Zoom);
    end;
  end;
  AlphaOK := False;
  if (Tool = tlSnippet) and (SnipStage > 0) then DrawSnippetPreview(Buf.Canvas);
  if (Arc2N > 0) and (Tool in [tlArc3, tlArcCSE]) then
  begin
    // the points already clicked
    Buf.Canvas.Pen.Color := TColor($FF9A3C);
    Buf.Canvas.Pen.Width := 1;
    Buf.Canvas.Pen.Style := psSolid;
    Buf.Canvas.Brush.Style := bsClear;
    for i := 0 to Arc2N - 1 do
      Buf.Canvas.Rectangle(Round(Arc2Pts[i].x * Zoom) - 3, Round(Arc2Pts[i].y * Zoom) - 3,
        Round(Arc2Pts[i].x * Zoom) + 4, Round(Arc2Pts[i].y * Zoom) + 4);
    if (Tool = tlArcCSE) and (Arc2N >= 2) then
    begin
      Buf.Canvas.Pen.Style := psDot;
      Buf.Canvas.Line(Round(Arc2Pts[0].x * Zoom), Round(Arc2Pts[0].y * Zoom),
        Round(Arc2Pts[1].x * Zoom), Round(Arc2Pts[1].y * Zoom));
      Buf.Canvas.Pen.Style := psSolid;
    end;
  end;
  Buf.Canvas.Clipping := False;
  SetLength(QuoteHits, 0);
  for i := 0 to Doc.Cons.Count - 1 do
  begin
    c := Doc.Cons[i];
    if c.IsQuote then DrawQuote(Buf.Canvas, c, Zoom, False);
  end;
  if AngPrev <> nil then
  begin
    DrawQuote(Buf.Canvas, AngPrev, Zoom, False);
    SetLength(QuoteHits, Length(QuoteHits) - 1);
  end;
  DrawBadges(Buf.Canvas);
  DrawSnapMarkers(Buf.Canvas);
  DrawSelectedSide(Buf.Canvas);
  DrawHandles(Buf.Canvas);
  if BandOn then
  begin
    Buf.Canvas.Pen.Color := TColor(ColorSel);
    Buf.Canvas.Pen.Width := 1;
    Buf.Canvas.Pen.Style := psDash;
    Buf.Canvas.Brush.Style := bsClear;
    Buf.Canvas.Rectangle(Round(DownX * Zoom), Round(DownY * Zoom), Round(LastX * Zoom), Round(LastY * Zoom));
  end;
  SetViewPortOrgEx(Buf.Canvas.Handle, 0, 0, nil);
  PaintBox1.Canvas.Draw(ox, oy, Buf);
  BufZoom := Zoom;
  BufOx := ox;
  BufOy := oy;
  SyncTreeSel;
  if not StartPainted then
  begin
    StartPainted := True;
    StartMark('first paint done');
  end;
end;

{ ================= creation ================= }

function TForm1.NewShape(k: TShapeKind): TShape;
begin
  Result := TShape.Create;
  Result.Kind := k;
  Result.Style := DefStyle;
  case k of
    skLine, skArrow, skPolyline, skSpline:
      Result.Style.Fill := NoColor;
    skText:
      begin
        Result.Style.Fill := DefStyle.Stroke;
        Result.Style.Stroke := NoColor;
      end;
  end;
  if k in [skEllipse, skArc] then Result.Circ := DefCirc;
  if k <> skImage then Result.Soft := DefSoft;
end;

procedure TForm1.AddCoincident(const a, b: TRef);
var
  i: Integer;
  c: TConstraint;
  err: string;
begin
  for i := 0 to Doc.Cons.Count - 1 do
  begin
    c := Doc.Cons[i];
    if (c.Kind = ckCoaxial) and (Length(c.Refs) = 2) and
       ((SameRef(c.Refs[0], a) and SameRef(c.Refs[1], b)) or
        (SameRef(c.Refs[0], b) and SameRef(c.Refs[1], a))) then Exit;
  end;
  Doc.AddConstraint(ckCoaxial, [a, b], err);
end;

procedure TForm1.AddSnapConstraints(s: TShape);
var
  i: Integer;
begin
  for i := 0 to Min(High(CreateSnaps), High(s.P)) do
    if CreateSnaps[i].Shape <> 0 then
      AddSnapConstraint(MakeRef(s.Id, i), CreateSnaps[i]);
end;

// a point snapped to a point: coincident; snapped to a line: kept on that line
procedure TForm1.AddSnapConstraint(const pointRef, target: TRef);
var
  i, k2: Integer;
  sh: TShape;
  c: TConstraint;
  err: string;
begin
  if target.Seg = -2 then
  begin
    // the middle of a side
    Doc.AddConstraint(ckMidPoint, [pointRef, MakeRef(target.Shape, target.Idx)], err);
    Exit;
  end;
  if target.Seg <= -3 then
  begin
    // the crossing of two sides (the second one is in the Seg field)
    i := -target.Seg - 3;
    k2 := i mod 8192;
    Doc.AddConstraint(ckIntersection, [pointRef, MakeRef(target.Shape, target.Idx),
      MakeRef(i div 8192, IfThen(k2 = 0, -1, SegBase + k2 - 1))], err);
    Exit;
  end;
  if ((target.Idx >= 0) and (target.Idx < SegBase)) or (target.Idx <= ArcStartIdx) then
  begin
    AddCoincident(pointRef, target);
    Exit;
  end;
  sh := Doc.FindShape(target.Shape);
  if (sh <> nil) and (sh.Kind in [skEllipse, skArc]) then
  begin
    for i := 0 to Doc.Cons.Count - 1 do
    begin
      c := Doc.Cons[i];
      if (c.Kind = ckOnCurve) and SameRef(c.Refs[0], pointRef) and SameRef(c.Refs[1], target) then Exit;
    end;
    Doc.AddConstraint(ckOnCurve, [pointRef, target], err);
    Exit;
  end;
  for i := 0 to Doc.Cons.Count - 1 do
  begin
    c := Doc.Cons[i];
    if (c.Kind = ckIntersection) and (Length(c.Refs) = 2) and SameRef(c.Refs[0], pointRef) and
       SameRef(c.Refs[1], target) then Exit;
  end;
  Doc.AddConstraint(ckIntersection, [pointRef, target], err);
end;

// the ends of an arc made by the 3-point / centre modes keep the snap they were clicked on
procedure TForm1.AddArcEndSnaps(s: TShape);
begin
  if s.Kind <> skArc then Exit;
  if Tool = tlArc3 then
  begin
    if Arc2Snap[0].Shape <> 0 then
      AddSnapConstraint(MakeRef(s.Id, IfThen(Arc2AIsStart, ArcStartIdx, ArcEndIdx)), Arc2Snap[0]);
    if Arc2Snap[1].Shape <> 0 then
      AddSnapConstraint(MakeRef(s.Id, IfThen(Arc2AIsStart, ArcEndIdx, ArcStartIdx)), Arc2Snap[1]);
  end
  else if Tool = tlArcCSE then
  begin
    if Arc2Snap[1].Shape <> 0 then AddSnapConstraint(MakeRef(s.Id, ArcEndIdx), Arc2Snap[1]);
    if Arc2Snap[2].Shape <> 0 then AddSnapConstraint(MakeRef(s.Id, ArcStartIdx), Arc2Snap[2]);
  end;
end;

procedure TForm1.CancelCreating;
begin
  FreeActive := False;
  FreeAndNil(Creating);
  SetLength(CreateSnaps, 0);
  ArcStage := 0;
  Arc2N := 0;
  Drag := dmNone;
  Redraw;
end;

procedure TForm1.FinishCreating(keep: Boolean);
var
  nCons, minPts: Integer;
  s: TShape;
begin
  if Creating = nil then Exit;
  s := Creating;
  Creating := nil;
  if keep then
  begin
    case s.Kind of
      skPolyline, skSpline:
        begin
          SetLength(s.P, Length(s.P) - 1);   // drop the live point
          if (Length(s.P) > 1) and (Dist(s.P[High(s.P)], s.P[High(s.P) - 1]) < 1) then
            SetLength(s.P, Length(s.P) - 1);
          minPts := 2;
        end;
      skPolygon:
        begin
          if not s.Reg then
          begin
            SetLength(s.P, Length(s.P) - 1);
            if (Length(s.P) > 1) and (Dist(s.P[High(s.P)], s.P[High(s.P) - 1]) < 1) then
              SetLength(s.P, Length(s.P) - 1);
          end;
          minPts := 3;
        end;
    else
      minPts := 0;
    end;
    if (minPts > 0) and (Length(s.P) < minPts) then keep := False;
  end;
  if keep then
  begin
    Doc.AddShape(s);
    nCons := Doc.Cons.Count;
    AddSnapConstraints(s);
    AddArcEndSnaps(s);
    Doc.Solve([]);
    if (Doc.Cons.Count > nCons) and RejectIfInconsistent then
      s := nil                // the document was restored: the new shape is gone
    else
    begin
      Commit;
      SetStatus('');
      SelSet(MakeRef(s.Id, -1));      // the new object is selected: its properties can be edited at once
    end;
  end
  else s.Free;
  SetLength(CreateSnaps, 0);
  ArcStage := 0;
  Arc2N := 0;
  Drag := dmNone;
  RefreshProps;
  Redraw;
end;

procedure TForm1.AngleAim(px, py: Double);
var
  a, b, a2, b2: TPR;
  v: TPt;
  a1, sw, wx, wy, den, al, be: Double;
  d1x, d1y, d2x, d2y: Double;
  code: Integer;
begin
  if AngPrev = nil then Exit;
  AngPrev.Aux := 3;
  if not (Doc.SegOf(AngPrev.Refs[0], a, b) and Doc.SegOf(AngPrev.Refs[1], a2, b2) and
          Doc.QuoteAngle(AngPrev, v, a1, sw)) then Exit;
  d1x := b.S.P[b.I].x - a.S.P[a.I].x;
  d1y := b.S.P[b.I].y - a.S.P[a.I].y;
  d2x := b2.S.P[b2.I].x - a2.S.P[a2.I].x;
  d2y := b2.S.P[b2.I].y - a2.S.P[a2.I].y;
  wx := px - v.x;
  wy := py - v.y;
  den := d1x * d2y - d1y * d2x;
  code := 3;
  if Abs(den) > 1e-9 * Hypot(d1x, d1y) * Hypot(d2x, d2y) then
  begin
    // the cursor lies between ray 1 and ray 2 of the chosen quadrant
    al := (wx * d2y - wy * d2x) / den;
    be := (d1x * wy - d1y * wx) / den;
    code := 0;
    if al >= 0 then code := code + 1;
    if be >= 0 then code := code + 2;
  end;
  AngPrev.Aux := code;
  AngPrev.Offset := Max(8, Hypot(wx, wy));
  if Doc.QuoteAngle(AngPrev, v, a1, sw) then AngPrev.Value := Abs(sw) * 180 / Pi;
  Redraw;
end;

procedure TForm1.AngleCancel;
begin
  if AngPrev = nil then Exit;
  FreeAndNil(AngPrev);
  SetStatus('Angular quote cancelled.');
  Redraw;
end;

procedure TForm1.AnglePlace;
var
  c: TConstraint;
  err: string;
begin
  if AngPrev = nil then Exit;
  Checkpoint;
  c := Doc.AddConstraint(ckAngle, AngPrev.Refs, err);
  if c = nil then
  begin
    FreeAndNil(AngPrev);
    SetStatus(err);
    Exit;
  end;
  c.Aux := AngPrev.Aux;
  c.Offset := AngPrev.Offset;
  c.Value := AngPrev.Value;
  FreeAndNil(AngPrev);
  Doc.SolveNew(c);
  Commit;
  SelClear;
  SelQuote := c;
  SetStatus('Angular quote added.');
  RefreshProps;
  Redraw;
end;

procedure TForm1.DoJoin(a, b: TShape);
var
  dropped: Integer;
  gap: Double;
  err, msg: string;
begin
  Checkpoint;
  if Doc.JoinShapes(a, b, dropped, gap, err) then
  begin
    Doc.Solve([]);
    Commit;
    SetTool(tlSelect);
    SelSet(MakeRef(a.Id, -1));
    msg := 'Joined into one poly-line.';
    if gap > 0.5 then msg := msg + ' The ends were ' + FmtNum(gap) + ' apart: a new side bridges them.';
    if dropped > 0 then msg := msg + ' ' + IntToStr(dropped) + ' constraint(s) on a whole line were removed.';
    SetStatus(msg);
    RefreshProps;
    Redraw;
  end
  else
  begin
    Commit;
    SetTool(tlSelect);
    SetStatus('Join: ' + err);
    Redraw;
  end;
end;

// a figure the Join button works on
function TForm1.Joinable(s: TShape): Boolean;
begin
  Result := (s <> nil) and (s.Kind in [skLine, skArrow, skPolyline, skPolygon, skSpline]) and (s.GroupId = 0) and (s.SelTarget = 0);
end;

procedure TForm1.JoinAt(px, py: Double);
var
  refs: TRefArray;
  pts: TPtArray;
  i, j, best: Integer;
  d, bd, tol: Double;
  s: TShape;
begin
  tol := 9 / Zoom;
  best := -1;
  bd := 1e18;
  if JoinRef.Shape = 0 then
  begin
    // the point that moves: a point of a selected line / poly-line
    for i := 0 to Doc.Shapes.Count - 1 do
    begin
      s := Doc.Shapes[i];
      if not (Joinable(s) and IsSelShape(s)) or Doc.ShapeLocked(s) then Continue;
      for j := 0 to High(s.P) do
      begin
        d := Hypot(s.P[j].x - px, s.P[j].y - py);
        if (d <= tol) and (d < bd) then
        begin
          bd := d;
          JoinRef := MakeRef(s.Id, j);
        end;
      end;
    end;
    if JoinRef.Shape = 0 then
    begin
      SetStatus('Join: click a point of the selected figure (the one that must move).');
      Exit;
    end;
    SelSet(JoinRef);
    SetStatus('Join: now click the point it must reach (the moving point will coincide with it).');
    Redraw;
    Exit;
  end;
  // the point to reach: any point of the drawing but the one chosen
  EnumSnapPoints(nil, refs, pts);
  for i := 0 to High(refs) do
  begin
    if SameRef(refs[i], JoinRef) then Continue;
    d := Hypot(pts[i].x - px, pts[i].y - py);
    if (d <= tol) and (d < bd) then
    begin
      bd := d;
      best := i;
    end;
  end;
  if best < 0 then
  begin
    SetStatus('Join: click the point it must reach (or press Esc to start again).');
    Exit;
  end;
  JoinPoints(JoinRef, refs[best], pts[best]);
end;

// the point a moves onto the point b and the two become one (a coincidence constraint keeps them together)
procedure TForm1.JoinPoints(const a, b: TRef; const target: TPt);
var
  sa, sb: TShape;
  c: TConstraint;
  err: string;
  i, k, dropped: Integer;
  gap: Double;
  ok: Boolean;
begin
  sa := Doc.FindShape(a.Shape);
  sb := Doc.FindShape(b.Shape);
  JoinRef := MakeRef(0, -1);
  if (sa = nil) or (sb = nil) then Exit;
  if GroupPartBlocked(sb, 'Join') then Exit;
  if (sa = sb) and ((sa.Kind in [skLine, skArrow]) or (Length(sa.P) < 3)) then
  begin
    SetStatus('Join: the two points belong to the same line, which would shrink to nothing.');
    SelSet(MakeRef(sa.Id, -1));
    Redraw;
    Exit;
  end;
  err := Doc.CheckConstraint(ckCoaxial, [b, a]);
  if err <> '' then
  begin
    SetStatus('Join: ' + err);
    SelSet(MakeRef(sa.Id, -1));
    Redraw;
    Exit;
  end;
  // a figure (or a point) that is fixed cannot be moved
  for i := 0 to Doc.Cons.Count - 1 do
  begin
    c := Doc.Cons[i];
    if c.Kind <> ckFixed then Continue;
    for k := 0 to High(c.Refs) do
      if (c.Refs[k].Shape = a.Shape) and ((c.Refs[k].Idx = -1) or (c.Refs[k].Idx = a.Idx)) then
      begin
        SetStatus('Join: the point to move is fixed by a constraint: it cannot be moved.');
        MessageDlg('Join', 'The point to move belongs to a figure (or is a point) that is fixed by a constraint, so it cannot be moved onto the other point.' +
          LineEnding + LineEnding + 'Delete the "fixed" constraint, or choose the other point as the one that moves.', mtWarning, [mbOK], 0);
        SelSet(MakeRef(sa.Id, -1));
        Redraw;
        Exit;
      end;
  end;
  // the ends of splines: the curve goes on through the joint (no corner), as one spline
  if (sa.Kind = skSpline) and (sb.Kind = skSpline) and (not sa.SplineClosed) and (not sb.SplineClosed) and
     (Length(sa.RingStarts) = 0) and (Length(sb.RingStarts) = 0) and
     ((a.Idx = 0) or (a.Idx = High(sa.P))) and ((b.Idx = 0) or (b.Idx = High(sb.P))) and
     ((sa <> sb) or ((Length(sa.P) >= 3) and (a.Idx <> b.Idx))) then
  begin
    Checkpoint;
    sa.P[a.Idx] := target;
    if sa = sb then ok := Doc.CloseSpline(sa, a.Idx, b.Idx, err)
    else ok := Doc.JoinShapes(sa, sb, dropped, gap, err);
    if not ok then
    begin
      LoadState(Before);
      SetStatus('Join: ' + err);
      MessageDlg('Join', err, mtWarning, [mbOK], 0);
      SelSet(MakeRef(a.Shape, -1));
      Redraw;
      Exit;
    end;
    Doc.Solve([]);
    if RejectIfInconsistent then
    begin
      SelSet(MakeRef(a.Shape, -1));
      Redraw;
      Exit;
    end;
    Commit;
    SetTool(tlSelect);
    SelSet(MakeRef(a.Shape, -1));
    if sa = sb then SetStatus('Joined: the spline is now closed and goes on smoothly through the joint.')
    else SetStatus('Joined: the two splines are now one curve that goes on smoothly through the joint.');
    RefreshProps;
    Redraw;
    Exit;
  end;
  Checkpoint;
  // the point that was chosen first goes where the second one is; then the coincidence keeps them together
  sa.P[a.Idx] := target;
  AddCoincident(b, a);
  c := Doc.Cons[Doc.Cons.Count - 1];
  Doc.SolveNew(c);
  if RejectIfInconsistent then
  begin
    SelSet(MakeRef(sa.Id, -1));
    Redraw;
    Exit;
  end;
  Commit;
  SetTool(tlSelect);
  SelSet(MakeRef(sa.Id, -1));
  SetStatus('Joined: the two points are now one.');
  RefreshProps;
  Redraw;
end;

function AskPointCount(const ACaption: string; var N: Integer; AMax: Integer): Boolean; forward;

function IndexInShapes(const ts: TShapeArray; s: TShape): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(ts) do
    if ts[i] = s then Result := i;
end;

// right click on a shape: conversions that make it editable in more ways
procedure TForm1.ShowShapeMenu(const ref: TRef);
const
  PixCaptions: array[0..4] of string = ('Copy the pixels under the selection (Ctrl+C)', 'Cut the pixels under the selection (Ctrl+X)',
    'Move the pixels (lift them into a raster of their own)', 'Fill the selection with the secondary colour (Shift+Del)',
    'Convert to vectorial figure (a polygon)');
var
  s: TShape;
  mi: TMenuItem;
  pt: TPoint;
  i: Integer;

  // every vector figure (and every group) can be turned into a raster picture
  procedure AddRasterItem;
  var
    m: TMenuItem;
  begin
    if (s.Kind = skImage) or (s.SelTarget > 0) or s.IsRef then Exit;
    if ShapeMenu.Items.Count > 0 then
    begin
      m := TMenuItem.Create(ShapeMenu);
      m.Caption := '-';
      ShapeMenu.Items.Add(m);
    end;
    m := TMenuItem.Create(ShapeMenu);
    m.Caption := 'Rasterize (turn it into a raster picture)';
    m.OnClick := @ConvertShapeClick;
    m.Tag := 14;
    ShapeMenu.Items.Add(m);
  end;

begin
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if ShapeMenu = nil then ShapeMenu := TPopupMenu.Create(Self);
  ShapeMenu.Items.Clear;
  if s.GroupId > 0 then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Ungroup (split into its elements)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 4;
    ShapeMenu.Items.Add(mi);
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    AddRasterItem;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  // a copy of an array / mirror / offset is tied to its parent: the only thing to offer is to free it
  if Doc.ParentOf(s) <> nil then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Detach from its parent (make it an object of its own)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 3;
    ShapeMenu.Items.Add(mi);
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    AddRasterItem;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if s.Kind = skText then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert text to paths (one curve per letter)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 5;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert text to polygons (straight sides, one per letter)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 6;
    ShapeMenu.Items.Add(mi);
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    AddRasterItem;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if s.Kind = skImage then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Crop (move the borders of the picture)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 10;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Perspective correction (move the four corners)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 11;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Flip (turn the picture upside down)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 12;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Mirror (swap left and right)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 13;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    if s.Id = FloatId then mi.Caption := 'Paste the pixels into the raster (Enter)'
    else mi.Caption := 'Merge into the raster underneath (Enter)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 15;
    ShapeMenu.Items.Add(mi);
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if s.SelTarget > 0 then
  begin
    for i := 0 to 4 do
    begin
      if i = 2 then Continue;
      mi := TMenuItem.Create(ShapeMenu);
      mi.Caption := PixCaptions[i];
      mi.OnClick := @ConvertShapeClick;
      mi.Tag := 20 + i;
      ShapeMenu.Items.Add(mi);
    end;
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Modify selection borders (move the points of the outline)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 25;
    ShapeMenu.Items.Add(mi);
    // the outline of a selection is not a figure to convert: only the operations on its pixels
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if s.Reg then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert to polygon (its corners can then be moved freely)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 8;
    ShapeMenu.Items.Add(mi);
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert to path (a path with the same look, whose points can be edited)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 9;
    ShapeMenu.Items.Add(mi);
    MenuShape := s.Id;
    MenuPoint := -1;
    pt := Mouse.CursorPos;
    AddRasterItem;
    pt := Mouse.CursorPos;
    ShapeMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if not (s.Kind in [skRect, skEllipse, skArc, skPolyline, skPath]) and not s.Bucket then
  begin
    // lines, arrows, polygons and curves: only the conversion to a raster
    AddRasterItem;
    if ShapeMenu.Items.Count > 0 then
    begin
      MenuShape := s.Id;
      MenuPoint := -1;
      pt := Mouse.CursorPos;
      ShapeMenu.PopUp(pt.x, pt.y);
    end;
    Exit;
  end;
  mi := TMenuItem.Create(ShapeMenu);
  case s.Kind of
    skRect: mi.Caption := 'Convert to polygon (its sides can then be constrained)';
    skPath: if s.Bucket then mi.Caption := 'Convert to polygon (independent of the lines that made it)'
            else mi.Caption := 'Convert to polygon (its points can then take constraints; asks how many)';
    skPolyline: mi.Caption := 'Close into a polygon (join the two ends)';
    skArc: mi.Caption := 'Convert to path (a curve whose points can be moved)';
  else
    mi.Caption := 'Convert to path (a curve whose points can be moved)';
  end;
  mi.OnClick := @ConvertShapeClick;
  mi.Tag := 1;                    // a polygon
  ShapeMenu.Items.Add(mi);
  if (s.Kind = skRect) and (CornerOf(s) > 0) then
  begin
    mi.Caption := 'Convert to polygon (asks how many points)';
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert to path (a smooth curve through points that can be moved)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 2;                  // a path
    ShapeMenu.Items.Add(mi);
  end;
  if s.Bucket then
  begin
    mi := TMenuItem.Create(ShapeMenu);
    mi.Caption := 'Convert to path (a smooth curve through points that can be moved)';
    mi.OnClick := @ConvertShapeClick;
    mi.Tag := 2;                  // a path
    ShapeMenu.Items.Add(mi);
  end;
  AddRasterItem;
  MenuShape := s.Id;
  MenuPoint := -1;
  pt := Mouse.CursorPos;
  ShapeMenu.PopUp(pt.x, pt.y);
end;

// a text becomes its letters: one path (curves) or polygon (straight sides) for every letter, in the place of the text
procedure TForm1.ConvertTextToShapes(s: TShape; asPath: Boolean);
var
  glyphs: TGlyphArray;
  polys: TPolyArray;
  err: string;
  at, gi, pi, k, made, r1, r2, r3: Integer;
  ns: TShape;
  made_ids: TIntArray;
  ox, oy: Double;
begin
  if Trim(s.Text) = '' then
  begin
    SetStatus('The text is empty: nothing to convert.');
    Exit;
  end;
  if not TextGlyphs(s.Text, s.FontName, s.FontSize, glyphs, err) then
  begin
    SetStatus('Cannot convert the text: ' + err);
    Exit;
  end;
  if Length(glyphs) = 0 then
  begin
    SetStatus('The text has no visible letters.');
    Exit;
  end;
  Checkpoint;
  made_ids := nil;
  for gi := 0 to High(glyphs) do
  begin
    ox := s.P[0].x + glyphs[gi].X;
    oy := s.P[0].y + glyphs[gi].Y;
    if asPath then
    begin
      ns := NewShape(skPath);
      ns.Style := s.Style;
      ns.Style.Stroke := NoColor;
      SetLength(ns.P, 1);
      ns.P[0] := MakePt(ox, oy);
      ns.PathData := GlyphPathData(glyphs[gi]);
      ns.ParsePath;
      ns.LayerId := s.LayerId;
      Doc.AddShape(ns);
      SetLength(made_ids, Length(made_ids) + 1);
      made_ids[High(made_ids)] := ns.Id;
    end
    else
    begin
      polys := GlyphPolygons(glyphs[gi], s.FontSize);
      for pi := 0 to High(polys) do
      begin
        ns := NewShape(skPolygon);
        ns.Style := s.Style;
        ns.Style.Stroke := NoColor;
        SetLength(ns.P, Length(polys[pi]));
        for k := 0 to High(polys[pi]) do
          ns.P[k] := MakePt(ox + polys[pi][k].x, oy + polys[pi][k].y);
        ns.LayerId := s.LayerId;
        Doc.AddShape(ns);
        SetLength(made_ids, Length(made_ids) + 1);
        made_ids[High(made_ids)] := ns.Id;
      end;
    end;
  end;
  // a turned text gives turned letters
  if (s.Rot <> 0) and (Length(s.P) > 0) then Doc.RotateShapes(made_ids, s.P[0].x, s.P[0].y, s.Rot, r1, r2, r3);
  // the letters take the place of the text in the stacking order
  at := Doc.Shapes.IndexOf(s);
  Doc.DeleteShape(s);
  made := Length(made_ids);
  for k := 0 to made - 1 do
    Doc.Shapes.Move(Doc.Shapes.IndexOf(Doc.FindShape(made_ids[k])), Min(at + k, Doc.Shapes.Count - 1));
  Doc.Solve([]);
  SelClear;
  SetLength(Sel, made);
  for k := 0 to made - 1 do Sel[k] := MakeRef(made_ids[k], -1);
  Commit;
  if asPath then SetStatus('The text is now ' + IntToStr(made) + ' paths: the points of each letter can be edited.')
  else SetStatus('The text is now ' + IntToStr(made) + ' polygons: the points of each letter can be edited.');
  RefreshProps;
  Redraw;
end;

procedure TForm1.ConvertShapeClick(Sender: TObject);
var
  s: TShape;
  dropped: Integer;
  err, msg, capt: string;
  wasRect, asPath, hasHoles: Boolean;
  nPts, totalPts, j, k: Integer;
  txt: string;
  fs: TFormatSettings;
  ts: TShapeArray;
begin
  s := Doc.FindShape(MenuShape);
  if s = nil then Exit;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 15) then
  begin
    // the same as the Enter key on a raster
    if (Creating <> nil) or (Drag <> dmNone) then Exit;
    SelSet(MakeRef(s.Id, -1));
    if s.Id = FloatId then PixCommit
    else if (s.Kind = skImage) and (s.SelTarget = 0) then MergeOverRaster(s);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 25) then
  begin
    SelEditBorders(s);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag in [20..24]) then
  begin
    SetLength(ts, 1);
    ts[0] := s;
    if TMenuItem(Sender).Tag = 24 then SelToVector(ts)
    else PixelsOp(TMenuItem(Sender).Tag - 19, ts);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 14) then
  begin
    // the selection (a whole group, if it is one), or else the figure that was clicked
    ts := SelShapes;
    if IndexInShapes(ts, s) < 0 then
    begin
      SetLength(ts, 1);
      ts[0] := s;
    end;
    RasterizeShapes(ts);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 4) then
  begin
    Checkpoint;
    Ungroup(s.GroupId);
    Commit;
    SetStatus('Ungrouped: the elements are separate objects now.');
    RefreshProps;
    Redraw;
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag in [5, 6]) then
  begin
    ConvertTextToShapes(s, TMenuItem(Sender).Tag = 5);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag in [12, 13]) and (s.Kind = skImage) then
  begin
    FlipPicture(s, TMenuItem(Sender).Tag = 12);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 11) and (s.Kind = skImage) then
  begin
    if Abs(s.Rot) > 1e-9 then
    begin
      SetStatus('Perspective: a turned picture cannot be corrected (turn it back to 0 first).');
      Exit;
    end;
    PersStart(s);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 10) and (s.Kind = skImage) then
  begin
    if Abs(s.Rot) > 1e-9 then
    begin
      SetStatus('Crop: a turned picture cannot be cropped (turn it back to 0 first).');
      Exit;
    end;
    CropStart(s);
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag in [8, 9]) and s.Reg then
  begin
    Checkpoint;
    if TMenuItem(Sender).Tag = 8 then
    begin
      s.Reg := False;
      SetStatus('Now a plain polygon: its corners can be moved freely.');
    end
    else
    begin
      // the corners become the points of a path of straight sides; what was tied to them is let go
      for k := Doc.Cons.Count - 1 downto 0 do
        for j := 0 to High(Doc.Cons[k].Refs) do
          if Doc.Cons[k].Refs[j].Shape = s.Id then
          begin
            Doc.DeleteConstraint(Doc.Cons[k]);
            Break;
          end;
      fs := DefaultFormatSettings;
      fs.DecimalSeparator := '.';
      txt := 'M0 0';
      for j := 1 to High(s.P) do
        txt := txt + Format(' L%.4f %.4f', [s.P[j].x - s.P[0].x, s.P[j].y - s.P[0].y], fs);
      txt := txt + ' Z';
      SetLength(s.P, 1);
      s.Kind := skPath;
      s.Reg := False;
      s.PathData := txt;
      s.ParsePath;
      SetLength(s.W, 0);
      SetStatus('Now a path: select its points to edit them.');
    end;
    Doc.Solve([]);
    Commit;
    SelSet(MakeRef(s.Id, -1));
    RefreshProps;
    Redraw;
    Exit;
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 3) then
  begin
    Checkpoint;
    Doc.DetachCopy(s);
    Commit;
    SetStatus('The object is now independent of its parent: it can be edited and moved.');
    RefreshProps;
    Redraw;
    Exit;
  end;
  if (s.Kind = skPath) and not s.Bucket then
  begin
    nPts := Doc.PathPointTotal(s);
    if nPts < 1 then
    begin
      SetStatus('Convert: the path has no points.');
      Exit;
    end;
    if Doc.PathOutlines(s) = 1 then
      if not AskPointCount('Convert to polygon', nPts, Max(3, Min(2000, nPts * 3))) then Exit;
    Checkpoint;
    if Doc.ConvertPath(s, nPts, dropped, err) then
    begin
      Doc.Solve([]);
      Commit;
      SelSet(MakeRef(s.Id, -1));
      msg := 'The path is now a polygon of ' + IntToStr(Length(s.P)) + ' points: its points can take constraints.';
      if s.Kind = skPolyline then msg := 'The path is now a poly-line of ' + IntToStr(Length(s.P)) + ' points.';
      if dropped > 0 then msg := msg + ' ' + IntToStr(dropped) + ' constraint(s) that depended on the old shape were removed.';
      SetStatus(msg);
      RefreshProps;
      Redraw;
    end
    else
    begin
      Commit;
      SetStatus('Convert: ' + err);
    end;
    Exit;
  end;
  if s.Bucket then
  begin
    asPath := (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 2);
    // how many points: the best compromise for this fill is proposed
    nPts := Doc.SuggestFillPoints(s, asPath, hasHoles, totalPts);
    if asPath or not hasHoles then
    begin
      if asPath then capt := 'Convert to path' else capt := 'Convert to polygon';
      if not AskPointCount(capt, nPts, Max(3, Min(totalPts, 500))) then Exit;
    end;
    Checkpoint;
    if Doc.ConvertBucket(s, nPts, asPath, err) then
    begin
      Doc.UpdateFillets;
      Commit;
      SelSet(MakeRef(s.Id, -1));
      if asPath then msg := 'The fill is now a smooth closed path of ' + IntToStr(Length(s.P)) + ' points: it no longer follows the lines that made it.'
      else msg := 'The fill is now a polygon of ' + IntToStr(Length(s.P)) + ' points: it no longer follows the lines that made it.';
      if hasHoles and not asPath then msg := msg + ' (A fill with holes keeps all its points.)';
      SetStatus(msg);
      RefreshProps;
      Redraw;
    end
    else
    begin
      Commit;
      SetStatus('Convert: ' + err);
    end;
    Exit;
  end;
  if s.Kind = skPolyline then
  begin
    Checkpoint;
    if Doc.ClosePolyline(s, err) then
    begin
      Doc.Solve([]);
      Commit;
      SelSet(MakeRef(s.Id, -1));
      SetStatus('Closed into a polygon: the two ends are joined.');
      RefreshProps;
      Redraw;
    end
    else
    begin
      Commit;
      SetStatus('Close: ' + err);
    end;
    Exit;
  end;
  if (s.Kind = skRect) and (CornerOf(s) > 0) then
  begin
    asPath := (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 2);
    nPts := Doc.SuggestRoundRectPoints(s, asPath);
    if asPath then capt := 'Convert to path' else capt := 'Convert to polygon';
    if not AskPointCount(capt, nPts, 400) then Exit;
    Checkpoint;
    if Doc.ConvertShape(s, nPts, dropped, err, asPath) then
    begin
      Doc.Solve([]);
      Commit;
      SelSet(MakeRef(s.Id, -1));
      if asPath then msg := 'Converted to a smooth closed path of ' + IntToStr(Length(s.P)) + ' points: drag them to deform it.'
      else msg := 'Converted to a polygon of ' + IntToStr(Length(s.P)) + ' points: its corners and sides can now take constraints.';
      if dropped > 0 then msg := msg + ' ' + IntToStr(dropped) + ' constraint(s) that depended on the old shape were removed.';
      SetStatus(msg);
      RefreshProps;
      Redraw;
    end
    else
    begin
      Commit;
      SetStatus('Convert: ' + err);
    end;
    Exit;
  end;
  wasRect := s.Kind = skRect;
  if not wasRect then
  begin
    // how many points the curve gets
    PathPoints := 12;
    if not AskPointCount('Convert to path', PathPoints, 200) then Exit;
  end;
  Checkpoint;
  if Doc.ConvertShape(s, PathPoints, dropped, err) then
  begin
    Doc.Solve([]);
    Commit;
    SelSet(MakeRef(s.Id, -1));
    if wasRect then msg := 'Converted to a polygon: its corners and sides can now take constraints.'
    else msg := 'Converted to a path: drag its points to deform it.';
    if dropped > 0 then msg := msg + ' ' + IntToStr(dropped) + ' constraint(s) that depended on the old shape were removed.';
    SetStatus(msg);
    RefreshProps;
    Redraw;
  end
  else
  begin
    Commit;
    SetStatus('Convert: ' + err);
  end;
end;

// a control point of a path or a joint of a poly-line / polygon under the cursor (selected
// figures first); the ends of a poly-line are not joints
function TForm1.EditablePointAt(px, py: Double; out shapeId, idx: Integer): Boolean;
var
  i, j, pass, lo, hi: Integer;
  s: TShape;
  tol, d, best: Double;
  pxs, pys: TDblArr;
  pctl: TBoolDyn;
  panc: TIntDyn;
  pt: TPt;
begin
  Result := False;
  tol := 9 / Zoom;
  best := 1e18;
  for pass := 0 to 1 do
  begin
    for i := Doc.Shapes.Count - 1 downto 0 do
    begin
      s := Doc.Shapes[i];
      if (s.GroupId > 0) or (s.SelTarget > 0) then Continue;       // the joints and points of a group, or of the outline of a selection, are not reachable
      if (s.Kind = skPath) and not s.Bucket and IsSelShape(s) and (pass = 0) and Interactive(s) and (Length(s.P) > 0) then
      begin
        s.PathHandles(pxs, pys, pctl, panc);
        for j := 0 to High(pxs) do
        begin
          pt := MakePt(s.P[0].x + pxs[j], s.P[0].y + pys[j]);
          if (s.Rot <> 0) and RotKind(s.Kind) then pt := TurnPt(pt, ShapePivot(s), s.Rot);
          d := Hypot(pt.x - px, pt.y - py);
          if (d <= tol) and (d < best) then
          begin
            best := d;
            shapeId := s.Id;
            idx := HandlePathBase + j;
            Result := True;
          end;
        end;
        Continue;
      end;
      if not (s.Kind in [skSpline, skPolyline, skPolygon]) or ((pass = 0) and not IsSelShape(s)) or not Interactive(s) then Continue;
      lo := 0;
      hi := High(s.P);
      if s.Kind = skPolyline then
      begin
        lo := 1;
        hi := High(s.P) - 1;
      end;
      for j := lo to hi do
      begin
        d := Hypot(s.P[j].x - px, s.P[j].y - py);
        if (d <= tol) and (d < best) then
        begin
          best := d;
          shapeId := s.Id;
          idx := j;
          Result := True;
        end;
      end;
    end;
    if Result then Exit;
  end;
end;

// removes the given control points of paths (several of one path: from the last one)
procedure TForm1.RemoveSelectedPoints(const refs: TRefArray);
var
  i, j, k, dropped, total, nOk: Integer;
  s: TShape;
  err, lastErr: string;
  ord: TRefArray;
  t: TRef;
  pks: TIntDyn;
  pathOk: Integer;
begin
  ord := Copy(refs);
  Checkpoint;
  pathOk := 0;
  // the points of paths made of commands (not of control points): all of one path at once
  for i := 0 to High(ord) do
    if ord[i].Idx >= HandlePathBase then
    begin
      s := Doc.FindShape(ord[i].Shape);
      if (s = nil) or (s.Kind <> skPath) then Continue;
      SetLength(pks, 0);
      for j := i to High(ord) do
        if (ord[j].Shape = ord[i].Shape) and (ord[j].Idx >= HandlePathBase) then
        begin
          SetLength(pks, Length(pks) + 1);
          pks[High(pks)] := ord[j].Idx - HandlePathBase;
          ord[j].Idx := -2;
        end;
      if s.RemovePathPoints(pks, err) then Inc(pathOk) else lastErr := err;
    end;
  if pathOk > 0 then
  begin
    Doc.Solve([]);
    Commit;
    s := Doc.FindShape(refs[0].Shape);
    SelClear;
    if s <> nil then SelSet(MakeRef(s.Id, -1));
    SetStatus('Points removed.');
    RefreshProps;
    Redraw;
    Exit;
  end;
  if (Length(ord) > 0) and (ord[0].Idx >= HandlePathBase) then
  begin
    Commit;
    SetStatus('Remove point: ' + lastErr);
    Exit;
  end;
  // higher point numbers first, so the others keep their numbers
  for i := 0 to High(ord) - 1 do
    for j := i + 1 to High(ord) do
      if ord[j].Idx > ord[i].Idx then
      begin
        t := ord[i];
        ord[i] := ord[j];
        ord[j] := t;
      end;
  total := 0;
  nOk := 0;
  lastErr := '';
  for k := 0 to High(ord) do
  begin
    s := Doc.FindShape(ord[k].Shape);
    if s = nil then Continue;
    if ((s.Kind = skSpline) and Doc.RemoveSplinePoint(s, ord[k].Idx, dropped, err)) or
       ((s.Kind <> skSpline) and Doc.RemoveVertex(s, ord[k].Idx, dropped, err)) then
    begin
      Inc(nOk);
      Inc(total, dropped);
    end
    else lastErr := err;
  end;
  if nOk > 0 then
  begin
    Doc.Solve([]);
    Commit;
    // the path stays selected
    s := Doc.FindShape(ord[0].Shape);
    SelClear;
    if s <> nil then SelSet(MakeRef(s.Id, -1));
    if total > 0 then
      SetStatus(IntToStr(nOk) + ' point(s) removed (' + IntToStr(total) + ' constraint(s) on them removed).')
    else
      SetStatus(IntToStr(nOk) + ' point(s) removed.');
    RefreshProps;
    Redraw;
  end
  else
  begin
    Commit;
    SetStatus('Remove point: ' + lastErr);
  end;
end;

procedure TForm1.RemovePointClick(Sender: TObject);
var
  refs: TRefArray;
begin
  if MenuPoint < 0 then Exit;
  SetLength(refs, 1);
  refs[0] := MakeRef(MenuShape, MenuPoint);
  RemoveSelectedPoints(refs);
end;

procedure TForm1.PathPointAt(px, py: Double);
var
  ref: TRef;
  s: TShape;
  err: string;
  idx: Integer;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Add point: click on the path.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if GroupPartBlocked(s, 'Add point') then Exit;
  if (s = nil) or (s.Kind <> skSpline) then
  begin
    SetStatus('Add point: click on a path (a curve made of points).');
    Exit;
  end;
  Checkpoint;
  if Doc.InsertSplinePoint(s, px, py, idx, err) then
  begin
    Doc.Solve([]);
    Commit;
    SetTool(tlSelect);
    SelSet(MakeRef(s.Id, idx));
    SetStatus('Point added: drag it to deform the path.');
    RefreshProps;
    Redraw;
  end
  else
  begin
    Commit;
    SetStatus('Add point: ' + err);
  end;
end;

{ ---------- freehand tools: pen, marker, airbrush ---------- }

procedure TForm1.FreeDown(px, py: Double);
begin
  Checkpoint;
  Creating := NewShape(skSpline);
  SetLength(Creating.P, 1);
  Creating.P[0] := MakePt(px, py);
  if Tool = tlAirbrush then
  begin
    Creating.Soft := 0;
    Creating.Spray := True;
    Creating.SprayR := DefSprayR;
    Creating.SprayDot := DefSprayDot;
    Creating.SprayDens := DefSprayDens;
    Creating.SpraySeed := 1 + Random(900000);
  end;
  FreeActive := True;
  Redraw;
end;

procedure TForm1.FreeMove(px, py: Double);
var
  n: Integer;
begin
  if Creating = nil then Exit;
  n := Length(Creating.P);
  if Hypot(px - Creating.P[n - 1].x, py - Creating.P[n - 1].y) < 1.5 / Zoom then Exit;
  SetLength(Creating.P, n + 1);
  Creating.P[n] := MakePt(px, py);
  Redraw;
end;

// Douglas-Peucker on the points of a hand drawn stroke
procedure SimplifyStroke(const pts: TPtArray; a, b: Integer; eps: Double; var keep: array of Boolean);
var
  i, im: Integer;
  dmax, d: Double;
begin
  if b <= a + 1 then Exit;
  dmax := -1;
  im := a;
  for i := a + 1 to b - 1 do
  begin
    d := DistToSegment(pts[i].x, pts[i].y, pts[a].x, pts[a].y, pts[b].x, pts[b].y);
    if d > dmax then
    begin
      dmax := d;
      im := i;
    end;
  end;
  if dmax > eps then
  begin
    keep[im] := True;
    SimplifyStroke(pts, a, im, eps, keep);
    SimplifyStroke(pts, im, b, eps, keep);
  end;
end;

procedure TForm1.FreeUp;
var
  s: TShape;
  keep: array of Boolean;
  np: TPtArray;
  i, n: Integer;
  eps: Double;
begin
  FreeActive := False;
  if Creating = nil then Exit;
  s := Creating;
  Creating := nil;
  n := Length(s.P);
  case Tool of
    tlPen: eps := 0.8;
    tlMarker: eps := 1.5;
  else
    eps := 3;
  end;
  eps := eps / Zoom;
  SetLength(keep, n);
  for i := 0 to n - 1 do keep[i] := False;
  keep[0] := True;
  keep[n - 1] := True;
  SimplifyStroke(s.P, 0, n - 1, eps, keep);
  SetLength(np, 0);
  for i := 0 to n - 1 do
    if keep[i] then
    begin
      SetLength(np, Length(np) + 1);
      np[High(np)] := s.P[i];
    end;
  if Length(np) < 2 then
  begin
    // a click: a tiny stroke, so that the airbrush still leaves a spot
    SetLength(np, 2);
    np[0] := s.P[0];
    np[1] := MakePt(s.P[0].x + 0.5, s.P[0].y);
  end;
  s.P := np;
  Doc.AddShape(s);
  Commit;
  SetStatus('');
  RefreshProps;
  Redraw;
end;

// the dots of an airbrush stroke
procedure TForm1.DrawSpray(cnv: TCanvas; s: TShape; z: Double);
var
  d: TSprayDotArray;
  i, tr, w, h, x, y, x0, y0, x1, y1: Integer;
  bb: TRect;
  cov: array of Single;         // what is left uncovered at each pixel
  op, rx, ry, r, a, dx, dy, t2, wgt, mg: Double;
  bmp: TBGRABitmap;
  px: PBGRAPixel;
  col: TBGRAPixel;
begin
  d := SprayDots(s);
  if Length(d) = 0 then Exit;
  tr := Doc.EffectiveTr(s, False);
  op := (255 - tr) / 255;
  bb := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
  for i := 0 to High(d) do
  begin
    mg := Max(d[i].R * z, 0.7) + 2;
    bb.Left := Min(bb.Left, Floor(d[i].X * z - mg));
    bb.Top := Min(bb.Top, Floor(d[i].Y * z - mg));
    bb.Right := Max(bb.Right, Ceil(d[i].X * z + mg));
    bb.Bottom := Max(bb.Bottom, Ceil(d[i].Y * z + mg));
  end;
  bb.Left := Max(0, bb.Left);
  bb.Top := Max(0, bb.Top);
  bb.Right := Min(cnv.Width, bb.Right);
  bb.Bottom := Min(cnv.Height, bb.Bottom);
  w := bb.Right - bb.Left;
  h := bb.Bottom - bb.Top;
  if (w <= 0) or (h <= 0) then Exit;
  cov := nil;
  SetLength(cov, w * h);
  for i := 0 to High(cov) do cov[i] := 1;
  // every drop is a soft round spot: full in the middle, fading to nothing at its edge; the spots add up
  for i := 0 to High(d) do
  begin
    rx := d[i].X * z - bb.Left;
    ry := d[i].Y * z - bb.Top;
    r := d[i].R * z;
    a := d[i].A;
    if r < 0.7 then
    begin
      a := a * Sqr(r / 0.7);          // a very small drop gets fainter instead of disappearing
      r := 0.7;
    end;
    x0 := Max(0, Floor(rx - r));
    x1 := Min(w - 1, Ceil(rx + r));
    y0 := Max(0, Floor(ry - r));
    y1 := Min(h - 1, Ceil(ry + r));
    for y := y0 to y1 do
    begin
      dy := y + 0.5 - ry;
      for x := x0 to x1 do
      begin
        dx := x + 0.5 - rx;
        t2 := (dx * dx + dy * dy) / (r * r);
        if t2 < 1 then
        begin
          wgt := 1 - t2;
          wgt := wgt * wgt * a;
          cov[y * w + x] := cov[y * w + x] * (1 - wgt);
        end;
      end;
    end;
  end;
  bmp := TBGRABitmap.Create(w, h, BGRAPixelTransparent);
  try
    col := ColorToBGRA(ToCol(s.Style.Stroke));
    for y := 0 to h - 1 do
    begin
      px := bmp.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        wgt := (1 - cov[y * w + x]) * op;
        if wgt > 0.003 then
        begin
          px^ := col;
          px^.alpha := Min(255, Round(wgt * 255));
        end;
        Inc(px);
      end;
    end;
    bmp.InvalidateBitmap;
    bmp.Draw(cnv, bb.Left, bb.Top, False);
  finally
    bmp.Free;
  end;
end;

procedure TForm1.SoftChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  any: Boolean;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  any := False;
  Checkpoint;
  for i := 0 to High(ts) do
    if (ts[i].Kind <> skImage) and not ts[i].Spray and not ts[i].Bucket then
    begin
      ts[i].Soft := seSoft.Value;
      any := True;
    end;
  if not any then DefSoft := seSoft.Value;
  Commit;
  Redraw;
end;

procedure TForm1.SprayChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  any: Boolean;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  any := False;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    if not ts[i].Spray then Continue;
    any := True;
    if Sender = seSprayR then ts[i].SprayR := seSprayR.Value
    else if Sender = seSprayDot then ts[i].SprayDot := seSprayDot.Value
    else if Sender = seSprayDens then ts[i].SprayDens := seSprayDens.Value;
  end;
  if not any then
  begin
    // nothing selected: the values for the next strokes
    DefSprayR := seSprayR.Value;
    DefSprayDot := seSprayDot.Value;
    DefSprayDens := seSprayDens.Value;
  end;
  Commit;
  RefreshProps;
  Redraw;
end;

// the radius is applied a moment after the last keystroke (typing 40 passes through 4)
// the selection whose rotation the property shows: a group, or one shape that keeps its own turn
function TForm1.SelRotInfo(out ids: TIntArray; out ang: Double): Boolean;
var
  ts: TShapeArray;
begin
  Result := False;
  ang := 0;
  if SelGroupIds(ids) then
  begin
    ang := GroupAngle(ids);
    Exit(True);
  end;
  ts := SelShapes;
  if (Length(ts) = 1) and RotKind(ts[0].Kind) and not ts[0].Bucket and not ts[0].IsRef then
  begin
    SetLength(ids, 1);
    ids[0] := ts[0].Id;
    ang := ts[0].Rot;
    Result := True;
  end;
end;

procedure TForm1.RotPropChanged(Sender: TObject);
begin
  if UpdatingProps then Exit;
  RotTimer.Enabled := False;
  RotTimer.Enabled := True;
end;

// the rotation typed in the properties: the selection turns about the centre of its box
procedure TForm1.RotPropApply(Sender: TObject);
var
  ids: TIntArray;
  ang, cx, cy, hw, hh, delta: Double;
  r1, r2, r3, i: Integer;
begin
  RotTimer.Enabled := False;
  if UpdatingProps then Exit;
  if not SelRotInfo(ids, ang) then Exit;
  delta := NormAngle(seRot.Value * Pi / 180 - ang);
  if Abs(delta) < 1e-7 then Exit;
  if not GroupFrame(ids, ang, cx, cy, hw, hh) then Exit;
  Checkpoint;
  Doc.RotateShapes(ids, cx, cy, delta, r1, r2, r3);
  Commit;
  SelClear;
  SetLength(Sel, Length(ids));
  for i := 0 to High(ids) do Sel[i] := MakeRef(ids[i], -1);
  RefreshProps;
  Redraw;
end;

procedure TForm1.SidesChanged(Sender: TObject);
begin
  if UpdatingProps then Exit;
  SidesTimer.Enabled := False;
  SidesTimer.Enabled := True;
end;

procedure TForm1.SidesApply(Sender: TObject);
var
  ts: TShapeArray;
  i, j, k, n: Integer;
  any: Boolean;
  c: TPt;
begin
  SidesTimer.Enabled := False;
  if UpdatingProps then Exit;
  n := seSides.Value;
  ts := TargetShapes;
  any := False;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].Reg and (Length(ts[i].P) >= 3) then
    begin
      c := RegularCenter(ts[i].P);
      // the constraints on its points would point to corners that are gone
      for k := Doc.Cons.Count - 1 downto 0 do
        for j := 0 to High(Doc.Cons[k].Refs) do
          if Doc.Cons[k].Refs[j].Shape = ts[i].Id then
          begin
            Doc.DeleteConstraint(Doc.Cons[k]);
            Break;
          end;
      ts[i].P := RegularPoints(c, ts[i].P[0], n);
      any := True;
    end;
  if not any then DefSides := n;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.CornerChanged(Sender: TObject);
begin
  if UpdatingProps then Exit;
  CornerTimer.Enabled := False;
  CornerTimer.Enabled := True;
end;

procedure TForm1.CornerApply(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  any: Boolean;
begin
  CornerTimer.Enabled := False;
  if UpdatingProps then Exit;
  ts := TargetShapes;
  any := False;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].Kind = skRect then
    begin
      ts[i].Corner := seCorner.Value;
      any := True;
    end;
  if not any then DefCorner := seCorner.Value;
  Commit;
  Redraw;
end;

procedure TForm1.ReseedClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := TargetShapes;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].Spray then ts[i].SpraySeed := 1 + Random(900000);
  Commit;
  Redraw;
end;

{ ================= layers ================= }

function TForm1.ActiveLayerObj: TLayer;
begin
  Result := Doc.FindLayer(Doc.ActiveLayer);
  if (Result = nil) and (Doc.Layers.Count > 0) then Result := Doc.Layers[Doc.Layers.Count - 1];
end;

// new shapes go to the active layer: it must be visible and not locked
function TForm1.CanCreateHere: Boolean;
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  Result := (l <> nil) and l.Visible and not l.Locked;
  if not Result then
    SetStatus('The active layer is hidden or locked: choose another layer (or unlock it) to draw.');
end;

{ ================= the tree of the objects ================= }

// a small picture over one of the boxes of the objects tree (nil if the icon file is missing)
function TForm1.MakeObjTitleIcon(const fn, tip: string): TImage;
var
  ic: TBGRABitmap;
begin
  Result := nil;
  ic := LoadIcon(fn, 20);
  if ic = nil then Exit;
  try
    TintIconTile(ic, BackColorOf(ObjPanel));
    Result := TImage.Create(Self);
    Result.Parent := ObjPanel;
    Result.Transparent := True;
    Result.Stretch := False;
    Result.SetBounds(0, 2, 20, 20);
    Result.Picture.Bitmap.Assign(ic.Bitmap);
    Result.Hint := tip;
    Result.ShowHint := True;
  finally
    ic.Free;
  end;
end;

procedure TForm1.BuildObjectsPanel;
begin
  ObjTags := TList.Create;
  ObjSeenGroups := TStringList.Create;
  ObjPanel := TPanel.Create(Self);
  ObjPanel.Parent := SidePanel;
  ObjPanel.Align := alClient;
  ObjPanel.BevelOuter := bvNone;
  ObjPanel.Caption := '';
  with TLabel.Create(Self) do
  begin
    Parent := ObjPanel;
    Caption := 'Objects';
    Font.Style := [fsBold];
    SetBounds(8, 4, 100, 18);
  end;
  lblObjLock := TLabel.Create(Self);
  with lblObjLock do
  begin
    Parent := ObjPanel;
    Caption := 'Lock';
    SetBounds(268, 4, 30, 18);
    Hint := 'Right box of each row: locked objects cannot be selected nor changed';
    ShowHint := True;
  end;
  lblObjHide := TLabel.Create(Self);
  with lblObjHide do
  begin
    Parent := ObjPanel;
    Caption := 'Hide';
    SetBounds(240, 4, 28, 18);
    Hint := 'Left box of each row: hidden objects are not drawn nor picked';
    ShowHint := True;
  end;
  // the titles of the two boxes are pictures, as everywhere else, when the icons are there (otherwise the words stay)
  imgObjHide := MakeObjTitleIcon('66_nascondi', 'Left box of each row: hidden objects are not drawn nor picked');
  imgObjLock := MakeObjTitleIcon('40_vincolo_fisso', 'Right box of each row: locked objects cannot be selected nor changed');
  if (imgObjHide <> nil) and (imgObjLock <> nil) then
  begin
    lblObjHide.Visible := False;
    lblObjLock.Visible := False;
  end
  else
  begin
    FreeAndNil(imgObjHide);
    FreeAndNil(imgObjLock);
  end;
  ObjTree := TTreeView.Create(Self);
  ObjTree.Parent := ObjPanel;
  ObjTree.Align := alClient;
  ObjTree.BorderSpacing.Top := 24;
  ObjTree.BorderSpacing.Left := 6;
  ObjTree.BorderSpacing.Right := 6;
  ObjTree.BorderSpacing.Bottom := 6;
  ObjTree.ReadOnly := True;
  ObjTree.RowSelect := True;
  ObjTree.HideSelection := False;
  ObjTree.Options := ObjTree.Options + [tvoAllowMultiselect, tvoRowSelect, tvoReadOnly] - [tvoToolTips];
  ObjTree.OnSelectionChanged := @ObjTreeSelect;
  ObjTree.OnAdvancedCustomDrawItem := @ObjTreeDraw;
  ObjTree.OnMouseDown := @ObjTreeMouseDown;
  ObjTree.DragMode := dmAutomatic;
  ObjTree.OnDragOver := @ObjTreeDragOver;
  ObjTree.OnDragDrop := @ObjTreeDragDrop;
  ObjTree.OnEndDrag := @ObjTreeEndDrag;
  ObjPanel.OnResize := @ObjPanelResize;
  ObjTree.OnResize := @ObjPanelResize;
  ObjPanelResize(nil);
  RefreshTree;
end;

// the titles of the two boxes of the entries follow the right edge of the panel (they are centred over the boxes)
procedure TForm1.ObjPanelResize(Sender: TObject);
var
  rx, lx, hx: Integer;
begin
  if (lblObjHide = nil) or (lblObjLock = nil) or (ObjTree = nil) then Exit;
  rx := ObjTree.ClientToParent(Point(ObjTree.ClientWidth, 0), ObjPanel).X;       // the right edge of what the tree shows (without its scroll bar)
  if imgObjHide <> nil then
  begin
    // the pictures are centred over the boxes (24 pixels apart)
    lx := rx - 17 - imgObjLock.Width div 2;
    hx := rx - 41 - imgObjHide.Width div 2;
    if (lx = imgObjLock.Left) and (hx = imgObjHide.Left) then Exit;
    imgObjLock.SetBounds(lx, 2, imgObjLock.Width, imgObjLock.Height);
    imgObjHide.SetBounds(hx, 2, imgObjHide.Width, imgObjHide.Height);
    ObjPanel.Invalidate;
    Exit;
  end;
  // small, so that the two titles do not touch
  lblObjLock.Font.Size := Max(6, Font.Size - 1);
  lblObjHide.Font.Size := lblObjLock.Font.Size;
  lx := rx - 17 - lblObjLock.Canvas.TextWidth(lblObjLock.Caption) div 2;
  hx := rx - 41 - lblObjHide.Canvas.TextWidth(lblObjHide.Caption) div 2;
  if (lx = lblObjLock.Left) and (hx = lblObjHide.Left) then Exit;
  lblObjLock.SetBounds(lx, 5, lblObjLock.Width, lblObjLock.Height);
  lblObjHide.SetBounds(hx, 5, lblObjHide.Width, lblObjHide.Height);
  ObjPanel.Invalidate;      // the titles are drawn by the panel: it must paint them again
end;

// a layer is hidden when it is not visible, a group when all its objects are
function TForm1.ObjNodeHidden(Node: TTreeNode): Boolean;
var
  t: TObjTag;
  k: Integer;
begin
  Result := False;
  if (Node = nil) or (Node.Data = nil) then Exit;
  t := TObjTag(Node.Data);
  case t.Kind of
    0: Result := not t.Layer.Visible;
    2: Result := t.Shape.Hidden;
    1:
      begin
        Result := Node.Count > 0;
        for k := 0 to Node.Count - 1 do
          if (Node.Items[k].Data <> nil) and not TObjTag(Node.Items[k].Data).Shape.Hidden then Result := False;
      end;
  end;
end;

function TForm1.ObjNodeLocked(Node: TTreeNode): Boolean;
var
  t: TObjTag;
  k: Integer;
begin
  Result := False;
  if (Node = nil) or (Node.Data = nil) then Exit;
  t := TObjTag(Node.Data);
  case t.Kind of
    0: Result := t.Layer.Locked;
    2: Result := t.Shape.Locked;
    1:
      begin
        Result := Node.Count > 0;
        for k := 0 to Node.Count - 1 do
          if (Node.Items[k].Data <> nil) and not TObjTag(Node.Items[k].Data).Shape.Locked then Result := False;
      end;
  end;
end;

// the tree is made again only when what it shows has changed
procedure TForm1.RefreshTree;
var
  sig, nm: string;
  i, j: Integer;
  l: TLayer;
  sh: TShape;
  ln, gn, nd: TTreeNode;
  t: TObjTag;
  gids: TStringList;
  collapsed, present: TStringList;
  gKey: string;
begin
  if ObjTree = nil then Exit;
  sig := '';
  for i := 0 to Doc.Layers.Count - 1 do sig := sig + 'L' + IntToStr(PtrUInt(Doc.Layers[i])) + '/' + IntToStr(Doc.Layers[i].Id) + ':' + Doc.Layers[i].Name + ':' + IntToStr(Ord(Doc.Layers[i].Locked)) + ';';
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    sh := Doc.Shapes[i];
    // the objects themselves count too: when the document is made again (undo, redo, load) the nodes must point to the new ones
    sig := sig + 'S' + IntToStr(PtrUInt(sh)) + '/' + IntToStr(sh.Id) + '/' + IntToStr(sh.LayerId) + '/' + IntToStr(sh.GroupId) + '/' + IntToStr(Ord(sh.Kind)) + '/' + IntToStr(sh.SelTarget) + '/' +
      IntToStr(Ord(sh.Locked)) + '/' + sh.GroupName;
    if sh.Kind = skText then sig := sig + '/' + sh.Text;
    sig := sig + ';';
  end;
  if sig = ObjSig then
  begin
    SyncTreeSel;
    Exit;
  end;
  ObjSig := sig;
  collapsed := TStringList.Create;
  gids := TStringList.Create;
  present := TStringList.Create;
  ObjSync := True;
  ObjTree.BeginUpdate;
  try
    for i := 0 to ObjTree.Items.Count - 1 do
      if (ObjTree.Items[i].Data <> nil) and (not ObjTree.Items[i].Expanded) and (ObjTree.Items[i].Count > 0) then
      begin
        t := TObjTag(ObjTree.Items[i].Data);
        if t.Kind = 0 then collapsed.Add('L' + IntToStr(t.Layer.Id))
        else if t.Kind = 1 then collapsed.Add('G' + IntToStr(t.GroupId));
      end;
    ObjTree.Items.Clear;
    for i := 0 to ObjTags.Count - 1 do TObject(ObjTags[i]).Free;
    ObjTags.Clear;
    // the top layer first, and in each the front objects first (as in the list of the layers)
    for i := Doc.Layers.Count - 1 downto 0 do
    begin
      l := Doc.Layers[i];
      t := TObjTag.Create;
      t.Kind := 0;
      t.Layer := l;
      ObjTags.Add(t);
      nm := l.Name;
      if l.IsFilter then nm := nm + ' (filter)';
      ln := ObjTree.Items.AddChildObject(nil, nm, t);
      gids.Clear;
      for j := Doc.Shapes.Count - 1 downto 0 do
      begin
        sh := Doc.Shapes[j];
        if Doc.LayerOf(sh) <> l then Continue;
        t := TObjTag.Create;
        t.Kind := 2;
        t.Shape := sh;
        t.Layer := l;
        ObjTags.Add(t);
        if sh.Kind = skText then nm := 'text "' + Copy(sh.Text, 1, 24) + '" #' + IntToStr(sh.Id)
        else if sh.SelTarget > 0 then nm := 'Selection #' + IntToStr(sh.Id)
        else nm := ShapeNames[sh.Kind] + ' #' + IntToStr(sh.Id);
        if sh.GroupId > 0 then
        begin
          gKey := IntToStr(sh.GroupId);
          if gids.IndexOf(gKey) < 0 then
          begin
            t := TObjTag.Create;
            t.Kind := 1;
            t.Layer := l;
            t.GroupId := sh.GroupId;
            ObjTags.Add(t);
            if sh.GroupName <> '' then gn := ObjTree.Items.AddChildObject(ln, sh.GroupName, t)
            else gn := ObjTree.Items.AddChildObject(ln, 'Group ' + gKey, t);
            // the group of an SVG snippet starts closed
            if (sh.GroupName <> '') and (ObjSeenGroups.IndexOf(gKey + '|' + sh.GroupName) < 0) then collapsed.Add('G' + gKey);
            if ObjSeenGroups.IndexOf(gKey + '|' + sh.GroupName) < 0 then ObjSeenGroups.Add(gKey + '|' + sh.GroupName);
            present.Add(gKey + '|' + sh.GroupName);
            gids.AddObject(gKey, gn);
            t := TObjTag.Create;
            t.Kind := 2;
            t.Shape := sh;
            t.Layer := l;
            ObjTags.Add(t);
          end;
          gn := TTreeNode(gids.Objects[gids.IndexOf(gKey)]);
          ObjTree.Items.AddChildObject(gn, nm, t);
        end
        else ObjTree.Items.AddChildObject(ln, nm, t);
      end;
    end;
    for i := 0 to ObjTree.Items.Count - 1 do
    begin
      nd := ObjTree.Items[i];
      t := TObjTag(nd.Data);
      if t.Kind = 0 then nd.Expanded := collapsed.IndexOf('L' + IntToStr(t.Layer.Id)) < 0
      else if t.Kind = 1 then nd.Expanded := collapsed.IndexOf('G' + IntToStr(t.GroupId)) < 0;
    end;
    // a group that no longer exists is forgotten: a new one may take its number and name (a snippet deleted and made again)
    for i := ObjSeenGroups.Count - 1 downto 0 do
      if present.IndexOf(ObjSeenGroups[i]) < 0 then ObjSeenGroups.Delete(i);
  finally
    ObjTree.EndUpdate;
    ObjSync := False;
    collapsed.Free;
    gids.Free;
    present.Free;
  end;
  ObjForce := True;
  SyncTreeSel;
end;

// the objects selected in the drawing are selected in the tree (the number that stands for the selection wraps around)
{$PUSH}{$Q-}{$R-}
procedure TForm1.SyncTreeSel;
var
  i: Integer;
  nd, first: TTreeNode;
  differs: Boolean;
  sg: Int64;

  function InSel(id: Integer): Boolean;
  var
    k: Integer;
  begin
    Result := False;
    for k := 0 to High(Sel) do
      if Sel[k].Shape = id then Result := True;
  end;

  // an object is selected in the tree; inside a closed group the group is the one that shows it (the group stays closed)
  function Wanted(n: TTreeNode): Boolean;
  var
    t, pt: TObjTag;
    c: Integer;
  begin
    Result := False;
    t := TObjTag(n.Data);
    if t = nil then Exit;
    if t.Kind = 2 then
    begin
      if not InSel(t.Shape.Id) then Exit;
      if n.Parent <> nil then
      begin
        pt := TObjTag(n.Parent.Data);
        if (pt <> nil) and (pt.Kind = 1) and not n.Parent.Expanded then Exit;
      end;
      Result := True;
    end
    else if (t.Kind = 1) and not n.Expanded then
      for c := 0 to n.Count - 1 do
        if (n.Items[c].Data <> nil) and (TObjTag(n.Items[c].Data).Kind = 2) and InSel(TObjTag(n.Items[c].Data).Shape.Id) then Result := True;
  end;

begin
  if (ObjTree = nil) or ObjSync then Exit;
  // nothing to do when the selection is the one already shown
  sg := Length(Sel);
  for i := 0 to High(Sel) do sg := sg * 31 + Sel[i].Shape + 7;
  if (sg = ObjLastSel) and not ObjForce then Exit;
  ObjLastSel := sg;
  ObjForce := False;
  differs := False;
  for i := 0 to ObjTree.Items.Count - 1 do
    if ObjTree.Items[i].Selected <> Wanted(ObjTree.Items[i]) then differs := True;
  if not differs then Exit;
  ObjSync := True;
  try
    first := nil;
    ObjTree.BeginUpdate;
    try
      ObjTree.ClearSelection(False);
      for i := 0 to ObjTree.Items.Count - 1 do
      begin
        nd := ObjTree.Items[i];
        if Wanted(nd) then
        begin
          nd.Selected := True;
          if first = nil then first := nd;
        end;
      end;
    finally
      ObjTree.EndUpdate;
    end;
    if first <> nil then first.MakeVisible;
  finally
    ObjSync := False;
  end;
end;
{$POP}

// a click in the tree selects in the drawing
procedure TForm1.ObjTreeSelect(Sender: TObject);
var
  i, k: Integer;
  nd: TTreeNode;
  t: TObjTag;
  layerOnly: TLayer;
begin
  if ObjSync then Exit;
  if ObjClickCheck then Exit;
  SetLength(Sel, 0);
  layerOnly := nil;
  for i := 0 to ObjTree.SelectionCount - 1 do
  begin
    nd := ObjTree.Selections[i];
    t := TObjTag(nd.Data);
    if t = nil then Continue;
    case t.Kind of
      0: layerOnly := t.Layer;
      1:
        for k := 0 to nd.Count - 1 do
          if (nd.Items[k].Data <> nil) and Interactive(TObjTag(nd.Items[k].Data).Shape) then
          begin
            SetLength(Sel, Length(Sel) + 1);
            Sel[High(Sel)] := MakeRef(TObjTag(nd.Items[k].Data).Shape.Id, -1);
          end;
      2:
        if Interactive(t.Shape) then
        begin
          SetLength(Sel, Length(Sel) + 1);
          Sel[High(Sel)] := MakeRef(t.Shape.Id, -1);
        end;
    end;
  end;
  SelQuote := nil;
  RotMode := False;
  ExpandGroups;       // the figure of a group in the tree stands for the whole group
  if (layerOnly <> nil) and (Length(Sel) = 0) then
  begin
    Doc.ActiveLayer := layerOnly.Id;
    RefreshLayers;
    if Tool <> tlSelect then SetTool(tlSelect);
  end
  else if Length(Sel) > 0 then
  begin
    // the layer of what is selected becomes the active one
    Doc.ActiveLayer := Doc.LayerOf(Doc.FindShape(Sel[0].Shape)).Id;
    RefreshLayers;
  end;
  RefreshProps;
  Redraw;
end;

procedure TForm1.ObjTreeDraw(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
  var PaintImages, DefaultDraw: Boolean);
var
  r, b: TRect;
  locked, hid: Boolean;
  c: TCanvas;
begin
  c := Sender.Canvas;
  if (Stage = cdPrePaint) and (Node.Index = 0) then ObjPanelResize(nil);      // the titles over the boxes follow the real width
  locked := ObjNodeLocked(Node);
  hid := ObjNodeHidden(Node);
  if Stage = cdPrePaint then
  begin
    if locked or hid then c.Font.Color := clGray;
    Exit;
  end;
  if Stage <> cdPostPaint then Exit;
  r := Node.DisplayRect(False);
  b := Rect(Sender.ClientWidth - 24, r.Top + (r.Bottom - r.Top - 14) div 2, Sender.ClientWidth - 10,
    r.Top + (r.Bottom - r.Top - 14) div 2 + 14);
  c.Pen.Style := psSolid;
  c.Pen.Width := 1;
  c.Pen.Color := TColor($B0B0B0);
  if locked then c.Brush.Color := TColor($C07030) else c.Brush.Color := TColor($3A3A3A);
  c.Brush.Style := bsSolid;
  c.Rectangle(b);
  if locked then
  begin
    c.Pen.Color := clWhite;
    c.Pen.Width := 2;
    c.MoveTo(b.Left + 3, b.Top + 7);
    c.LineTo(b.Left + 6, b.Top + 10);
    c.LineTo(b.Left + 11, b.Top + 4);
  end;
  // the box of the hiding, at the left of the one of the lock
  OffsetRect(b, -24, 0);
  c.Pen.Style := psSolid;
  c.Pen.Width := 1;
  c.Pen.Color := TColor($B0B0B0);
  if hid then c.Brush.Color := TColor($3C8C3C) else c.Brush.Color := TColor($3A3A3A);
  c.Brush.Style := bsSolid;
  c.Rectangle(b);
  if hid then
  begin
    c.Pen.Color := clWhite;
    c.Pen.Width := 2;
    c.MoveTo(b.Left + 3, b.Top + 7);
    c.LineTo(b.Left + 6, b.Top + 10);
    c.LineTo(b.Left + 11, b.Top + 4);
  end;
  c.Pen.Width := 1;
end;

// the box at the right of an entry: it is not a selection but a (deferred) change of the lock
procedure TForm1.ObjTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  nd: TTreeNode;
begin
  ObjClickCheck := False;
  if (Button <> mbLeft) or (X < ObjTree.ClientWidth - 52) then Exit;
  nd := ObjTree.GetNodeAt(X, Y);
  if (nd = nil) or (nd.Data = nil) then Exit;
  ObjClickCheck := True;
  if X >= ObjTree.ClientWidth - 28 then Application.QueueAsyncCall(@ObjToggleLock, PtrInt(nd.Data))
  else if X >= ObjTree.ClientWidth - 52 then Application.QueueAsyncCall(@ObjToggleHide, PtrInt(nd.Data))
  else ObjClickCheck := False;
end;

// the objects dragged in the tree: the selected objects, and the members of the selected groups
procedure ObjDragList(Tree: TTreeView; list: TShapeList);
var
  i, k: Integer;
  nd: TTreeNode;
  t: TObjTag;
begin
  for i := 0 to Tree.SelectionCount - 1 do
  begin
    nd := Tree.Selections[i];
    t := TObjTag(nd.Data);
    if t = nil then Continue;
    if (t.Kind = 2) and (t.Shape.GroupId > 0) then
    begin
      // a figure of a group goes with the whole group
      for k := 0 to Form1.Doc.Shapes.Count - 1 do
        if (Form1.Doc.Shapes[k].GroupId = t.Shape.GroupId) and (list.IndexOf(Form1.Doc.Shapes[k]) < 0) then list.Add(Form1.Doc.Shapes[k]);
    end
    else if t.Kind = 2 then
    begin
      if list.IndexOf(t.Shape) < 0 then list.Add(t.Shape);
    end
    else if t.Kind = 1 then
      for k := 0 to nd.Count - 1 do
        if (nd.Items[k].Data <> nil) and (list.IndexOf(TObjTag(nd.Items[k].Data).Shape) < 0) then
          list.Add(TObjTag(nd.Items[k].Data).Shape);
  end;
end;

// where a drop would go: the shape it is put next to (nil: on top of the layer), above or below it, and the layer
function TForm1.ObjDropPlace(X, Y: Integer; out target: TShape; out above: Boolean; out lay: TLayer): Boolean;
var
  nd, ref: TTreeNode;
  t: TObjTag;
  r: TRect;
begin
  Result := False;
  target := nil;
  above := True;
  lay := nil;
  nd := ObjTree.GetNodeAt(X, Y);
  if (nd = nil) or (nd.Data = nil) then Exit;
  t := TObjTag(nd.Data);
  r := nd.DisplayRect(False);
  above := Y < (r.Top + r.Bottom) div 2;
  if t.Kind = 0 then
  begin
    lay := t.Layer;
    Result := True;
    Exit;
  end;
  ref := nd;
  if t.Kind = 1 then
  begin
    if nd.Count = 0 then Exit;
    if above then ref := nd.Items[0] else ref := nd.Items[nd.Count - 1];
  end;
  if (ref.Data = nil) or (TObjTag(ref.Data).Kind <> 2) then Exit;
  target := TObjTag(ref.Data).Shape;
  lay := TObjTag(ref.Data).Layer;
  Result := True;
end;

procedure TForm1.ObjTreeDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
  list: TShapeList;
  target: TShape;
  above: Boolean;
  lay: TLayer;
  nd: TTreeNode;
begin
  Accept := False;
  if Source <> ObjTree then Exit;
  if not ObjDropPlace(X, Y, target, above, lay) then
  begin
    ObjTree.SetInsertMark(nil, tvimNone);
    Exit;
  end;
  list := TShapeList.Create(False);
  try
    ObjDragList(ObjTree, list);
    Accept := (list.Count > 0) and (list.IndexOf(target) < 0);
  finally
    list.Free;
  end;
  nd := ObjTree.GetNodeAt(X, Y);
  if Accept and (nd <> nil) then
  begin
    if TObjTag(nd.Data).Kind = 0 then ObjTree.SetInsertMark(nd, tvimAsFirstChild)
    else if above then ObjTree.SetInsertMark(nd, tvimAsPrevSibling)
    else ObjTree.SetInsertMark(nd, tvimAsNextSibling);
  end
  else ObjTree.SetInsertMark(nil, tvimNone);
end;

procedure TForm1.ObjTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  list: TShapeList;
  target: TShape;
  above: Boolean;
  lay: TLayer;
  i, at: Integer;
  mv: TShapeArray;
  sh: TShape;
begin
  ObjTree.SetInsertMark(nil, tvimNone);
  if Source <> ObjTree then Exit;
  if not ObjDropPlace(X, Y, target, above, lay) then Exit;
  list := TShapeList.Create(False);
  try
    ObjDragList(ObjTree, list);
    if (list.Count = 0) or (list.IndexOf(target) >= 0) then Exit;
    if lay.IsFilter then
      for i := 0 to list.Count - 1 do
        if not list[i].IsRef then
        begin
          SetStatus('Only reference objects can go in a filter layer');
          Exit;
        end;
    // in their present order, from the back
    mv := nil;
    SetLength(mv, 0);
    for i := 0 to Doc.Shapes.Count - 1 do
      if list.IndexOf(Doc.Shapes[i]) >= 0 then
      begin
        SetLength(mv, Length(mv) + 1);
        mv[High(mv)] := Doc.Shapes[i];
      end;
    Checkpoint;
    for i := 0 to High(mv) do Doc.Shapes.Extract(mv[i]);
    if target = nil then at := Doc.Shapes.Count
    else
    begin
      at := Doc.Shapes.IndexOf(target);
      if above then Inc(at);        // the tree shows the front first
    end;
    for i := 0 to High(mv) do
    begin
      sh := mv[i];
      sh.LayerId := lay.Id;
      Doc.Shapes.Insert(at + i, sh);
    end;
    Commit;
    PurgeSelection;
    RefreshLayers;
    RefreshProps;
    Redraw;
  finally
    list.Free;
  end;
end;

procedure TForm1.ObjTreeEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  ObjTree.SetInsertMark(nil, tvimNone);
end;

procedure TForm1.ObjToggleLock(Data: PtrInt);
var
  t: TObjTag;
  i: Integer;
  sh: TShape;
  v: Boolean;
begin
  try
    t := TObjTag(Data);
    if (t = nil) or (ObjTags.IndexOf(t) < 0) then Exit;
    Checkpoint;
    if (t.Kind = 2) and (t.Shape.GroupId > 0) then
    begin
      // the figures of a group are not handled one by one: the box acts on the whole group
      v := not t.Shape.Locked;
      for i := 0 to Doc.Shapes.Count - 1 do
        if Doc.Shapes[i].GroupId = t.Shape.GroupId then Doc.Shapes[i].Locked := v;
    end
    else
    case t.Kind of
      0: t.Layer.Locked := not t.Layer.Locked;
      2: t.Shape.Locked := not t.Shape.Locked;
      1:
        begin
          v := True;
          for i := 0 to Doc.Shapes.Count - 1 do
            if (Doc.Shapes[i].GroupId = t.GroupId) and (Doc.LayerOf(Doc.Shapes[i]) = t.Layer) and not Doc.Shapes[i].Locked then v := False;
          for i := 0 to Doc.Shapes.Count - 1 do
          begin
            sh := Doc.Shapes[i];
            if (sh.GroupId = t.GroupId) and (Doc.LayerOf(sh) = t.Layer) then sh.Locked := not v;
          end;
        end;
    end;
    Commit;
    PurgeSelection;
    RefreshLayers;
    RefreshProps;
    Redraw;
  finally
    ObjClickCheck := False;
  end;
  RefreshTree;
  ObjTree.Invalidate;      // the boxes show the new state at once
  ObjTree.Update;
end;

// the box of the hiding of an entry: a layer is shown or hidden (as with its checkbox), objects and groups get hidden or shown
procedure TForm1.ObjToggleHide(Data: PtrInt);
var
  t: TObjTag;
  i: Integer;
  sh: TShape;
  v: Boolean;
begin
  try
    t := TObjTag(Data);
    if (t = nil) or (ObjTags.IndexOf(t) < 0) then Exit;
    Checkpoint;
    if (t.Kind = 2) and (t.Shape.GroupId > 0) then
    begin
      v := not t.Shape.Hidden;
      for i := 0 to Doc.Shapes.Count - 1 do
        if Doc.Shapes[i].GroupId = t.Shape.GroupId then Doc.Shapes[i].Hidden := v;
    end
    else
    case t.Kind of
      0: t.Layer.Visible := not t.Layer.Visible;
      2: t.Shape.Hidden := not t.Shape.Hidden;
      1:
        begin
          v := True;
          for i := 0 to Doc.Shapes.Count - 1 do
            if (Doc.Shapes[i].GroupId = t.GroupId) and (Doc.LayerOf(Doc.Shapes[i]) = t.Layer) and not Doc.Shapes[i].Hidden then v := False;
          for i := 0 to Doc.Shapes.Count - 1 do
          begin
            sh := Doc.Shapes[i];
            if (sh.GroupId = t.GroupId) and (Doc.LayerOf(sh) = t.Layer) then sh.Hidden := not v;
          end;
        end;
    end;
    Commit;
    PurgeSelection;
    RefreshLayers;
    RefreshProps;
    Redraw;
  finally
    ObjClickCheck := False;
  end;
  RefreshTree;
  ObjTree.Invalidate;      // the boxes show the new state at once
  ObjTree.Update;
end;

procedure TForm1.BuildLayersPanel;
const
  Wd = 68;
var
  lb: TLabel;

  function Btn(const cap: string; x, y, w: Integer; h: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := LayersPanel;
    Result.Caption := cap;
    Result.SetBounds(x, y, w, 24);
    Result.OnClick := h;
  end;

begin
  // a column at the left of the properties: the layers on top, the tree of the objects under them
  SidePanel := TPanel.Create(Self);
  SidePanel.Parent := Self;
  SidePanel.BevelOuter := bvNone;
  SidePanel.Caption := '';
  SidePanel.Width := 300;
  SidePanel.Left := PropertiesPanel.Left - 1;
  SidePanel.Align := alRight;
  SideSplit := TSplitter.Create(Self);
  SideSplit.Parent := Self;
  SideSplit.Align := alRight;
  SideSplit.Left := SidePanel.Left - 1;
  SideSplit.ResizeStyle := rsUpdate;
  LayersPanel := TPanel.Create(Self);
  LayersPanel.Parent := SidePanel;
  LayersPanel.Align := alTop;
  LayersPanel.Height := 294;
  LayersPanel.BevelOuter := bvNone;
  LayersPanel.Caption := '';
  lb := TLabel.Create(Self);
  lb.Parent := LayersPanel;
  lb.Caption := 'Layers';
  lb.Font.Style := [fsBold];
  lb.SetBounds(8, 4, 100, 18);
  clbLayers := TCheckListBox.Create(Self);
  clbLayers.Parent := LayersPanel;
  clbLayers.SetBounds(6, 24, 288, 86);
  clbLayers.Anchors := [akLeft, akTop, akRight];
  clbLayers.OnClick := @LayerListClick;
  clbLayers.OnItemClick := nil;
  clbLayers.OnClickCheck := @LayerCheck;
  btnLAdd := Btn('Add', 6, 116, Wd, @LayerAddClick);
  btnLDel := Btn('Delete', 78, 116, Wd, @LayerDelClick);
  btnLUp := Btn('Up', 150, 116, Wd, @LayerMoveClick);
  btnLDown := Btn('Down', 222, 116, Wd, @LayerMoveClick);
  btnLRen := Btn('Rename', 6, 144, Wd, @LayerRenameClick);
  btnLLock := Btn('Lock', 78, 144, Wd, @LayerLockClick);
  btnLMerge := Btn('Merge down', 150, 144, 68, @LayerMergeClick);
  btnLFilter := Btn('Filter...', 222, 144, Wd, @LayerAddFilterClick);
  btnLFilter.Hint := 'Add a filter layer: a raster filter that works on everything under it';
  btnLFilter.ShowHint := True;
  btnLHide := Btn('Hide', 6, 174, Wd, @LayerHideClick);
  btnLHide.Hint := 'Hide or show the layer (the same as its checkbox)';
  btnLHide.ShowHint := True;
  chkHideRefs := TCheckBox.Create(Self);
  chkHideRefs.Parent := LayersPanel;
  chkHideRefs.SetBounds(8, 206, 280, 22);
  chkHideRefs.Caption := 'Hide the reference figures';
  chkHideRefs.Hint := 'Hides the dashed reference figures of this layer (for instance the ones that limit a filter), to see the final result';
  chkHideRefs.ShowHint := True;
  chkHideRefs.OnChange := @HideRefsChange;
  chkHideCons := TCheckBox.Create(Self);
  chkHideCons.Parent := LayersPanel;
  chkHideCons.SetBounds(8, 230, 280, 22);
  chkHideCons.Caption := 'Hide constraints tags';
  chkHideCons.Hint := 'Hides the little tags of the constraints (H, V, =, ...) of the objects of this layer';
  chkHideCons.ShowHint := True;
  chkHideCons.OnChange := @HideConsChange;
  btnLMove := Btn('Move selection to this layer', 6, 260, 288, @LayerSelToClick);
  btnLRaster := Btn('Rasterize', 6, 288, 288, @LayerRasterizeClick);
  btnLRaster.Hint := 'Turns everything that is seen in this layer into a raster picture';
  btnLRaster.ShowHint := True;
  LayersPanel.Height := 320;
  BuildObjectsPanel;
  RefreshLayers;
end;

// the list shows the top layer first; the checkbox is the visibility
procedure TForm1.RefreshLayers;
var
  i, selIdx: Integer;
  l: TLayer;
begin
  if clbLayers = nil then Exit;
  UpdatingLayers := True;
  try
    clbLayers.Items.Clear;
    selIdx := -1;
    for i := Doc.Layers.Count - 1 downto 0 do
    begin
      l := Doc.Layers[i];
      if l.IsFilter and l.Locked then clbLayers.Items.AddObject(l.Name + '   (filter, locked)', l)
      else if l.IsFilter then clbLayers.Items.AddObject(l.Name + '   (filter)', l)
      else if l.Locked then clbLayers.Items.AddObject(l.Name + '   (locked)', l)
      else clbLayers.Items.AddObject(l.Name, l);
      clbLayers.Checked[clbLayers.Items.Count - 1] := l.Visible;
      if l.Id = Doc.ActiveLayer then selIdx := clbLayers.Items.Count - 1;
    end;
    if selIdx < 0 then selIdx := 0;
    if clbLayers.Items.Count > 0 then clbLayers.ItemIndex := selIdx;
    l := ActiveLayerObj;
    if l <> nil then
    begin
      chkHideRefs.Checked := l.HideRefs;
      chkHideCons.Checked := l.HideCons;
      if l.Locked then btnLLock.Caption := 'Unlock' else btnLLock.Caption := 'Lock';
      if l.Visible then btnLHide.Caption := 'Hide' else btnLHide.Caption := 'Show';
    end;
    // the Filters menu works only when a filter layer is the active one
    if miFilters <> nil then miFilters.Enabled := True;
    if miFltParams <> nil then
      miFltParams.Enabled := (l <> nil) and l.IsFilter and (l.FScript <> '');
    if miFltClear <> nil then miFltClear.Enabled := (l <> nil) and l.IsFilter and (l.FScript <> '');
    // the colours are of no use there: the filters take their place
    if FltPanel <> nil then
    begin
      FltPanel.Visible := (l <> nil) and l.IsFilter;
      ColorPanel.Visible := not FltPanel.Visible;
    end;
  finally
    UpdatingLayers := False;
  end;
  SyncLayerProps;
  RefreshTree;
end;

procedure TForm1.LayerListClick(Sender: TObject);
var
  nl: TLayer;
  i: Integer;
  chg: Boolean;
begin
  if UpdatingLayers or (clbLayers.ItemIndex < 0) then Exit;
  nl := TLayer(clbLayers.Items.Objects[clbLayers.ItemIndex]);
  if Doc.ActiveLayer <> nl.Id then
  begin
    // choosing a layer locks the others (and unlocks the chosen one)
    chg := nl.Locked;
    for i := 0 to Doc.Layers.Count - 1 do
      if (Doc.Layers[i] <> nl) and not Doc.Layers[i].Locked then chg := True;
    if chg then
    begin
      Checkpoint;
      for i := 0 to Doc.Layers.Count - 1 do
        Doc.Layers[i].Locked := Doc.Layers[i] <> nl;
      Commit;
    end;
  end;
  Doc.ActiveLayer := nl.Id;
  // choosing a layer shows its properties: nothing is selected, and the arrow is the tool
  SetLength(Sel, 0);
  SelQuote := nil;
  RotMode := False;
  PurgeSelection;
  RefreshLayers;
  if Tool <> tlSelect then SetTool(tlSelect);
  RefreshProps;
  Redraw;
end;

procedure TForm1.LayerHideClick(Sender: TObject);
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  if l = nil then Exit;
  Checkpoint;
  l.Visible := not l.Visible;
  Commit;
  PurgeSelection;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.LayerCheck(Sender: TObject);
var
  l: TLayer;
  i: Integer;
begin
  if UpdatingLayers or (clbLayers.ItemIndex < 0) then Exit;
  i := clbLayers.ItemIndex;
  l := TLayer(clbLayers.Items.Objects[i]);
  Checkpoint;
  l.Visible := clbLayers.Checked[i];
  Commit;
  // what is on a hidden layer cannot stay selected
  PurgeSelection;
  RefreshProps;
  Redraw;
end;

procedure TForm1.LayerAddClick(Sender: TObject);
var
  l: TLayer;
  at, k: Integer;
begin
  Checkpoint;
  at := Doc.Layers.IndexOf(ActiveLayerObj);
  l := Doc.AddLayer('Layer ' + IntToStr(Doc.NextLayerId));
  k := Doc.Layers.IndexOf(l);
  if (at >= 0) and (at + 1 < k) then Doc.Layers.Move(k, at + 1);
  Doc.ActiveLayer := l.Id;
  for k := 0 to Doc.Layers.Count - 1 do Doc.Layers[k].Locked := Doc.Layers[k] <> l;   // the others get locked
  Commit;
  PurgeSelection;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// a filter layer: a raster filter that sees everything under it; only reference objects can be drawn in it
procedure TForm1.LayerAddFilterClick(Sender: TObject);
var
  l: TLayer;
  at, k: Integer;
begin
  Checkpoint;
  at := Doc.Layers.IndexOf(ActiveLayerObj);
  l := Doc.AddLayer('Filter ' + IntToStr(Doc.NextLayerId));
  l.IsFilter := True;
  k := Doc.Layers.IndexOf(l);
  if (at >= 0) and (at + 1 < k) then Doc.Layers.Move(k, at + 1);
  Doc.ActiveLayer := l.Id;
  for k := 0 to Doc.Layers.Count - 1 do Doc.Layers[k].Locked := Doc.Layers[k] <> l;
  Commit;
  PurgeSelection;
  RefreshLayers;
  RefreshProps;
  Redraw;
  SetStatus('Filter layer added: choose a filter in the panel at the top. Draw closed reference figures in it to limit the filter to them.');
end;

procedure TForm1.LayerDelClick(Sender: TObject);
var
  l: TLayer;
  i, n, at: Integer;
  r: Integer;
begin
  l := ActiveLayerObj;
  if l = nil then Exit;
  if Doc.Layers.Count <= 1 then
  begin
    SetStatus('A drawing needs at least one layer.');
    Exit;
  end;
  n := 0;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.LayerOf(Doc.Shapes[i]) = l then Inc(n);
  if n > 0 then
  begin
    r := MessageDlg('Delete layer', 'The layer "' + l.Name + '" holds ' + IntToStr(n) + ' object(s): they will be deleted too.' +
      LineEnding + 'Delete it?', mtWarning, [mbYes, mbNo], 0);
    if r <> mrYes then Exit;
  end;
  Checkpoint;
  for i := Doc.Shapes.Count - 1 downto 0 do
    if Doc.LayerOf(Doc.Shapes[i]) = l then Doc.DeleteShape(Doc.Shapes[i]);
  at := Doc.Layers.IndexOf(l);
  Doc.Layers.Remove(l);
  Doc.ActiveLayer := Doc.Layers[Max(0, Min(at, Doc.Layers.Count - 1))].Id;
  ActiveLayerObj.Locked := False;     // a layer that becomes the active one is unlocked
  PurgeSelection;
  Commit;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.LayerMoveClick(Sender: TObject);
var
  at: Integer;
begin
  at := Doc.Layers.IndexOf(ActiveLayerObj);
  if at < 0 then Exit;
  Checkpoint;
  if Sender = btnLUp then
  begin
    if at + 1 < Doc.Layers.Count then Doc.Layers.Exchange(at, at + 1);
  end
  else if at > 0 then Doc.Layers.Exchange(at, at - 1);
  Commit;
  RefreshLayers;
  Redraw;
end;

procedure TForm1.LayerRenameClick(Sender: TObject);
var
  l: TLayer;
  nm: string;
begin
  l := ActiveLayerObj;
  if l = nil then Exit;
  nm := l.Name;
  if not InputQuery('Rename layer', 'Name of the layer:', nm) then Exit;
  nm := Trim(nm);
  if nm = '' then Exit;
  Checkpoint;
  l.Name := nm;
  Commit;
  RefreshLayers;
end;

procedure TForm1.LayerLockClick(Sender: TObject);
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  if l = nil then Exit;
  Checkpoint;
  l.Locked := not l.Locked;
  Commit;
  PurgeSelection;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// the layer is joined to the one below it
procedure TForm1.LayerMergeClick(Sender: TObject);
var
  l, below: TLayer;
  at, i: Integer;
begin
  l := ActiveLayerObj;
  at := Doc.Layers.IndexOf(l);
  if (l = nil) or (at <= 0) then
  begin
    SetStatus('There is no layer below to merge into.');
    Exit;
  end;
  below := Doc.Layers[at - 1];
  if l.IsFilter or below.IsFilter then
  begin
    SetStatus('A filter layer cannot be merged with another layer.');
    Exit;
  end;
  Checkpoint;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.LayerOf(Doc.Shapes[i]) = l then Doc.Shapes[i].LayerId := below.Id;
  Doc.Layers.Remove(l);
  Doc.ActiveLayer := below.Id;
  below.Locked := False;
  Commit;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.HideConsChange(Sender: TObject);
var
  l: TLayer;
begin
  if UpdatingLayers then Exit;
  l := ActiveLayerObj;
  if l = nil then Exit;
  Checkpoint;
  l.HideCons := chkHideCons.Checked;
  Commit;
  Redraw;
end;

procedure TForm1.HideRefsChange(Sender: TObject);
var
  l: TLayer;
begin
  if UpdatingLayers then Exit;
  l := ActiveLayerObj;
  if l = nil then Exit;
  Checkpoint;
  l.HideRefs := chkHideRefs.Checked;
  Commit;
  PurgeSelection;
  RefreshProps;
  Redraw;
end;

// the arrow tool with nothing selected: Properties shows the layer that is active
function TForm1.LayerPropsMode: Boolean;
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  Result := (Tool = tlSelect) and (l <> nil) and (not l.IsFilter) and (Length(TargetShapes) = 0) and (SelQuote = nil);
end;

// the controls of Properties take the values of the active layer (without answering to the change)
procedure TForm1.SyncLayerProps;
var
  l: TLayer;
  was: Boolean;
begin
  if seLPOp = nil then Exit;
  l := ActiveLayerObj;
  if l = nil then Exit;
  was := UpdatingLayers;
  UpdatingLayers := True;
  try
    if Round(seLPOp.Value) <> Round(l.Opacity * 100 / 255) then seLPOp.Value := l.Opacity * 100 / 255;
    if Abs(seLPScale.Value - l.Scale) > 1e-9 then seLPScale.Value := l.Scale;
    SetSwatch(btnLPBg, l.Bg);
    chkLPNoBg.Checked := l.Bg = NoColor;
  finally
    UpdatingLayers := was;
  end;
end;

// opacity or scale changed in Properties: the same as in the layers panel
procedure TForm1.LayerPropChange(Sender: TObject);
var
  l: TLayer;
  v: Integer;
  sc: Double;
begin
  if UpdatingLayers then Exit;
  l := ActiveLayerObj;
  if l = nil then Exit;
  v := Max(0, Min(255, Round(seLPOp.Value * 255 / 100)));
  sc := Max(0.000001, seLPScale.Value);
  if (v = l.Opacity) and (Abs(sc - l.Scale) < 1e-12) then Exit;
  Checkpoint;
  l.Opacity := v;
  l.Scale := sc;
  Commit;
  Redraw;
end;

procedure TForm1.LayerBgClick(Sender: TObject);
var
  l: TLayer;
  c: TColor;
  pct: Double;
begin
  l := ActiveLayerObj;
  if l = nil then Exit;
  if l.Bg <> NoColor then c := TColor(l.Bg) else c := clWhite;
  pct := 100;
  if not PickColor('Background colour of the layer', c, pct, False) then Exit;
  Checkpoint;
  l.Bg := c;
  Commit;
  SyncLayerProps;
  Redraw;
end;

procedure TForm1.LayerBgNoneChange(Sender: TObject);
var
  l: TLayer;
begin
  if UpdatingLayers then Exit;
  l := ActiveLayerObj;
  if l = nil then Exit;
  if chkLPNoBg.Checked = (l.Bg = NoColor) then Exit;
  Checkpoint;
  if chkLPNoBg.Checked then l.Bg := NoColor
  else l.Bg := clWhite;
  Commit;
  SyncLayerProps;
  Redraw;
end;

// everything that is seen in the active layer (objects and background) becomes one raster picture, as large as what is drawn
procedure TForm1.LayerRasterizeClick(Sender: TObject);
var
  l: TLayer;
  ord, mine: TShapeArray;
  ids: TIntArray;
  run, part: TBGRABitmap;
  px: PBGRAPixel;
  ms: TMemoryStream;
  raw: string;
  i, x, y, w, h, bx1, by1, bx2, by2, op: Integer;
  ns: TShape;
begin
  l := ActiveLayerObj;
  if (l = nil) or l.IsFilter then
  begin
    SetStatus('Rasterize: select a layer that holds objects.');
    Exit;
  end;
  Doc.UpdateFillets;
  ord := Doc.DrawOrder;
  SetLength(mine, 0);
  for i := 0 to High(ord) do
    if (Doc.LayerOf(ord[i]) = l) and not ord[i].IsRef then
    begin
      SetLength(mine, Length(mine) + 1);
      mine[High(mine)] := ord[i];
    end;
  if (Length(mine) = 0) and (l.Bg = NoColor) then
  begin
    SetStatus('Rasterize: this layer has nothing to rasterize.');
    Exit;
  end;
  w := Doc.Width;
  h := Doc.Height;
  // the opacity of the layer is applied when the raster is drawn, not twice
  op := l.Opacity;
  l.Opacity := 255;
  try
    if Length(mine) > 0 then run := RenderRun(mine, 0, High(mine), w, h, 1, False, False)
    else
    begin
      run := TBGRABitmap.Create(w, h, BGRAPixelTransparent);
      run.Fill(ColorToBGRA(l.Bg));
    end;
  finally
    l.Opacity := op;
  end;
  part := nil;
  try
    bx1 := w;
    by1 := h;
    bx2 := -1;
    by2 := -1;
    for y := 0 to h - 1 do
    begin
      px := run.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        if px^.alpha > 0 then
        begin
          if x < bx1 then bx1 := x;
          if x > bx2 then bx2 := x;
          if y < by1 then by1 := y;
          if y > by2 then by2 := y;
        end;
        Inc(px);
      end;
    end;
    if bx2 < bx1 then
    begin
      SetStatus('Rasterize: nothing of this layer is visible on the page.');
      Exit;
    end;
    part := run.GetPart(Rect(bx1, by1, bx2 + 1, by2 + 1)) as TBGRABitmap;
    ms := TMemoryStream.Create;
    try
      part.SaveToStreamAsPng(ms);
      SetString(raw, PAnsiChar(ms.Memory), ms.Size);
    finally
      ms.Free;
    end;
  finally
    part.Free;
    run.Free;
  end;
  Checkpoint;
  SetLength(ids, Length(mine));
  for i := 0 to High(mine) do ids[i] := mine[i].Id;
  if Length(mine) > 0 then ns := NewPixelsShape(EncodeStringBase64(raw), (bx1 + bx2 + 1) / 2, (by1 + by2 + 1) / 2, (bx2 - bx1 + 1) / 2, (by2 - by1 + 1) / 2, 0, mine[High(mine)])
  else ns := NewPixelsShape(EncodeStringBase64(raw), (bx1 + bx2 + 1) / 2, (by1 + by2 + 1) / 2, (bx2 - bx1 + 1) / 2, (by2 - by1 + 1) / 2, 0, nil);
  ns.LayerId := l.Id;
  for i := 0 to High(ids) do
    if Doc.FindShape(ids[i]) <> nil then Doc.DeleteShape(Doc.FindShape(ids[i]));
  // the selections of the pictures that are gone have nothing to select
  for i := Doc.Shapes.Count - 1 downto 0 do
    if (Doc.Shapes[i].SelTarget > 0) and (Doc.FindShape(Doc.Shapes[i].SelTarget) = nil) then Doc.DeleteShape(Doc.Shapes[i]);
  l.Bg := NoColor;
  Commit;
  PurgeSelection;
  SelSet(MakeRef(ns.Id, -1));
  SetStatus('Layer "' + l.Name + '" rasterized: ' + IntToStr(bx2 - bx1 + 1) + 'x' + IntToStr(by2 - by1 + 1) + ' pixels.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// the selected objects go to the active layer
procedure TForm1.LayerSelToClick(Sender: TObject);
var
  ts: TShapeArray;
  l: TLayer;
  i: Integer;
begin
  l := ActiveLayerObj;
  ts := SelShapes;
  if (l = nil) or (Length(ts) = 0) then
  begin
    SetStatus('Select some objects first.');
    Exit;
  end;
  Checkpoint;
  for i := 0 to High(ts) do ts[i].LayerId := l.Id;
  Commit;
  PurgeSelection;
  RefreshProps;
  Redraw;
end;

procedure TForm1.BucketAt(px, py: Double);
var
  b: TShape;
  lay: TLayer;
  err: string;
  fillCol: Integer;
begin
  if BucketOnSelection(px, py) then Exit;
  Doc.UpdateFillets;
  if DefStyle.Fill <> NoColor then fillCol := DefStyle.Fill
  else if DefStyle.Stroke <> NoColor then fillCol := DefStyle.Stroke
  else fillCol := TColor($F0C080);
  Checkpoint;
  b := Doc.AddBucket(px, py, fillCol, err);
  if b = nil then
  begin
    // not inside any closed area: the point is on the background, which takes the colour (the background of the active layer)
    if (Pos('not inside a closed area', err) > 0) or (Pos('nothing to fill', err) > 0) then
    begin
      lay := ActiveLayerObj;
      if (lay <> nil) and not lay.IsFilter then
      begin
        lay.Bg := fillCol;
        Commit;
        SetStatus('The background of the layer "' + lay.Name + '" now has this colour.');
        RefreshProps;
        Redraw;
        Exit;
      end;
    end;
    Commit;
    SetStatus('Paint bucket: ' + err);
    Exit;
  end;
  if DefStyle.Fill = fillCol then b.Style.FillMatId := DefStyle.FillMatId;       // a fill can be made of a material too
  Commit;
  SelSet(MakeRef(b.Id, -1));
  SetStatus('Area filled. The fill follows its boundaries when they change.');
  RefreshProps;
  Redraw;
end;

// a fill whose boundaries no longer enclose its area: delete it or undo the change
procedure TForm1.CheckBrokenFills;
var
  broken: TShapeArray;
  txt: string;
  r, i: Integer;
begin
  if InBucketCheck then Exit;
  broken := Doc.BrokenBuckets;
  if Length(broken) = 0 then Exit;
  InBucketCheck := True;
  try
    if Length(broken) = 1 then txt := 'The fill #' + IntToStr(broken[0].Id) + ' can no longer follow its boundaries: they do not enclose its area any more.'
    else txt := IntToStr(Length(broken)) + ' fills can no longer follow their boundaries: they do not enclose their areas any more.';
    txt := txt + LineEnding + LineEnding + 'Delete the fill, or undo the change?';
    r := QuestionDlg('Fill no longer possible', txt, mtWarning, [mrYes, 'Delete the fill', mrNo, 'Undo the change'], 0);
    if r = mrYes then
    begin
      for i := 0 to High(broken) do Doc.DeleteShape(broken[i]);
      PurgeSelection;
      RefreshProps;
      Redraw;
    end
    else DoUndo(nil);
  finally
    InBucketCheck := False;
  end;
end;

procedure TForm1.VertexAt(px, py: Double);
var
  ref: TRef;
  s: TShape;
  err: string;
  idx, dropped: Integer;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Add joint: click on a line, a poly-line or a polygon.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if GroupPartBlocked(s, 'Add joint') then Exit;
  Checkpoint;
  if Doc.InsertVertex(s, px, py, idx, dropped, err) then
  begin
    Doc.Solve([]);
    Commit;
    SetTool(tlSelect);
    SelSet(MakeRef(s.Id, idx));
    if dropped > 0 then
      SetStatus('Joint added: drag it to bend the line (' + IntToStr(dropped) + ' constraint(s) on the whole line removed).')
    else
      SetStatus('Joint added: drag it to bend the line.');
    RefreshProps;
    Redraw;
  end
  else
  begin
    Commit;
    SetStatus('Add joint: ' + err);
  end;
end;

{ ================= selections of a raster ================= }

// what the selections that are transparent inside change in a picture: 0 when there are none, else a number that changes
// with their shape and with the place of the picture
function TForm1.HoleKey(s: TShape): QWord;
var
  vals: TDblArr;
  i, j, k, n: Integer;
  sh: TShape;
  o: TOutline;
begin
  Result := 0;
  SetLength(vals, 0);
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    sh := Doc.Shapes[i];
    if (sh.SelTarget <> s.Id) or not (sh.SelHole or sh.SelSub) then Continue;
    n := Length(vals);
    SetLength(vals, n + 1);
    vals[n] := sh.Id;
    o := ShapeOutline(sh);
    for j := 0 to High(o) do
      for k := 0 to High(o[j].Pts) do
      begin
        n := Length(vals);
        SetLength(vals, n + 2);
        vals[n] := o[j].Pts[k].x;
        vals[n + 1] := o[j].Pts[k].y;
      end;
  end;
  if Length(vals) = 0 then Exit;
  n := Length(vals);
  SetLength(vals, n + 6);
  vals[n] := s.Id;
  vals[n + 1] := s.P[0].x;
  vals[n + 2] := s.P[0].y;
  vals[n + 3] := s.P[1].x;
  vals[n + 4] := s.P[1].y;
  vals[n + 5] := s.Rot;
  Result := HashBytes(@vals[0], Length(vals) * SizeOf(Double), 14695981039346656037) or 1;
end;

// the box of a picture and the point of the document taken back to the frame of the (unturned) picture
procedure ImageBox(img: TShape; out x1, y1, x2, y2: Double);
begin
  x1 := Min(img.P[0].x, img.P[1].x);
  y1 := Min(img.P[0].y, img.P[1].y);
  x2 := Max(img.P[0].x, img.P[1].x);
  y2 := Max(img.P[0].y, img.P[1].y);
end;

// the pixels of a picture (w x h) that lie inside any of the selections (1 = inside; even-odd scan lines through the middle of
// the rows of pixels)
function TForm1.SelMask(img: TShape; const sels: TShapeArray; w, h: Integer): TBytes;
type
  TEdge = record
    X1, Y1, X2, Y2: Double;
  end;
var
  x1, y1, x2, y2, fx, fy, yc: Double;
  c, a, b: TPt;
  i, j, k, n, y, xa, xb, m, t: Integer;
  o: TOutline;
  edges: array of TEdge;
  xs: array of Double;
  srt: TShapeArray;
  mk: Byte;
  q: Integer;
  tmp: TShape;
begin
  Result := nil;
  SetLength(Result, w * h);
  if (w <= 0) or (h <= 0) then Exit;
  FillChar(Result[0], w * h, 0);
  ImageBox(img, x1, y1, x2, y2);
  if (x2 - x1 < 1e-6) or (y2 - y1 < 1e-6) then Exit;
  c := ShapePivot(img);
  // in the order they were made: a selection that subtracts takes away what the ones before it covered
  srt := Copy(sels);
  for i := 1 to High(srt) do
  begin
    tmp := srt[i];
    q := i - 1;
    while (q >= 0) and (SelKey(srt[q]) > SelKey(tmp)) do
    begin
      srt[q + 1] := srt[q];
      Dec(q);
    end;
    srt[q + 1] := tmp;
  end;
  fx := w / (x2 - x1);
  fy := h / (y2 - y1);
  for i := 0 to High(srt) do
  begin
    SetLength(edges, 0);
    if srt[i].SelSub then mk := 0 else mk := 1;
    o := ShapeOutline(srt[i]);
    for j := 0 to High(o) do
    begin
      n := Length(o[j].Pts);
      if n < 3 then Continue;
      for k := 0 to n - 1 do
      begin
        a := TurnPt(o[j].Pts[k], c, -img.Rot);
        b := TurnPt(o[j].Pts[(k + 1) mod n], c, -img.Rot);
        SetLength(edges, Length(edges) + 1);
        edges[High(edges)].X1 := (a.x - x1) * fx;
        edges[High(edges)].Y1 := (a.y - y1) * fy;
        edges[High(edges)].X2 := (b.x - x1) * fx;
        edges[High(edges)].Y2 := (b.y - y1) * fy;
      end;
    end;
    for y := 0 to h - 1 do
    begin
      yc := y + 0.5;
      SetLength(xs, 0);
      for k := 0 to High(edges) do
        if (edges[k].Y1 <= yc) <> (edges[k].Y2 <= yc) then
        begin
          SetLength(xs, Length(xs) + 1);
          xs[High(xs)] := edges[k].X1 + (yc - edges[k].Y1) / (edges[k].Y2 - edges[k].Y1) * (edges[k].X2 - edges[k].X1);
        end;
      for m := 1 to High(xs) do
      begin
        yc := xs[m];
        t := m - 1;
        while (t >= 0) and (xs[t] > yc) do
        begin
          xs[t + 1] := xs[t];
          Dec(t);
        end;
        xs[t + 1] := yc;
      end;
      m := 0;
      while m + 1 <= High(xs) do
      begin
        xa := Max(0, Ceil(xs[m] - 0.5));
        xb := Min(w - 1, Floor(xs[m + 1] - 0.5));
        for k := xa to xb do Result[y * w + k] := mk;
        Inc(m, 2);
      end;
    end;
  end;
end;

// the picture with transparent parts where selections on it say so
function TForm1.BuildHoleImage(s: TShape; raw: TGraphic): TGraphic;
var
  bmp: TBitmap;
  li, src: TLazIntfImage;
  desc: TRawImageDescription;
  png: TPortableNetworkGraphic;
  x1, y1, x2, y2: Double;
  w, h, i, k, y: Integer;
  holes: TShapeArray;
  mask: TBytes;
  col: TFPColor;
begin
  Result := nil;
  if (raw = nil) or (Length(s.P) < 2) then Exit;
  ImageBox(s, x1, y1, x2, y2);
  if (x2 - x1 < 1e-6) or (y2 - y1 < 1e-6) then Exit;
  bmp := TBitmap.Create;
  try
    bmp.Assign(raw);
    src := bmp.CreateIntfImage;
    li := TLazIntfImage.Create(0, 0);
    try
      w := src.Width;
      h := src.Height;
      // the copy has a channel for the opacity, even if the picture has none
      desc.Init_BPP32_B8G8R8A8_BIO_TTB(w, h);
      li.DataDescription := desc;
      li.SetSize(w, h);
      for y := 0 to h - 1 do
        for k := 0 to w - 1 do li.Colors[k, y] := src.Colors[k, y];
      SetLength(holes, 0);
      for i := 0 to Doc.Shapes.Count - 1 do
        if (Doc.Shapes[i].SelTarget = s.Id) and (Doc.Shapes[i].SelHole or Doc.Shapes[i].SelSub) then
        begin
          SetLength(holes, Length(holes) + 1);
          holes[High(holes)] := Doc.Shapes[i];
        end;
      mask := SelMask(s, holes, w, h);
      for y := 0 to h - 1 do
        for k := 0 to w - 1 do
          if mask[y * w + k] <> 0 then
          begin
            col := li.Colors[k, y];
            col.alpha := 0;
            li.Colors[k, y] := col;
          end;
      png := TPortableNetworkGraphic.Create;
      png.LoadFromIntfImage(li);
      Result := png;
    finally
      li.Free;
      src.Free;
    end;
  finally
    bmp.Free;
  end;
end;

// the picture as it is seen: with the parts that selections make transparent
function TForm1.ImageOf(s: TShape): TGraphic;
var
  raw, g: TGraphic;
  key: QWord;
  i: Integer;
begin
  raw := RawImage(s);
  Result := raw;
  if (raw = nil) or (Length(s.P) < 2) then Exit;
  key := HoleKey(s);
  if key = 0 then Exit;
  for i := 0 to High(HoleImgs) do
    if HoleImgs[i].Shape = s then
    begin
      if HoleImgs[i].Key = key then Exit(HoleImgs[i].G);
      HoleImgs[i].G.Free;
      Delete(HoleImgs, i, 1);
      Break;
    end;
  g := BuildHoleImage(s, raw);
  if g = nil then Exit;
  if Length(HoleImgs) >= 4 then
  begin
    HoleImgs[0].G.Free;
    Delete(HoleImgs, 0, 1);
  end;
  SetLength(HoleImgs, Length(HoleImgs) + 1);
  HoleImgs[High(HoleImgs)].Shape := s;
  HoleImgs[High(HoleImgs)].Key := key;
  HoleImgs[High(HoleImgs)].G := g;
  Result := g;
end;

// the picture as an image with a channel for the opacity
function TForm1.RgbaOf(raw: TGraphic): TLazIntfImage;
var
  bmp: TBitmap;
  src: TLazIntfImage;
  desc: TRawImageDescription;
  x, y, i: Integer;
  rd: TFPReaderPNG;
  ss: TStringStream;
  mem: TFPMemoryImage;
begin
  // the pixels of a picture are read from its own PNG data: going through a bitmap of the widget set would turn the
  // partial transparency (a marker, a soft brush) into all or nothing
  Result := nil;
  for i := 0 to Doc.Shapes.Count - 1 do
    if (Doc.Shapes[i].Kind = skImage) and (Doc.Shapes[i].ImageData <> '') and (TObject(Doc.Shapes[i].Cache) = TObject(raw)) then
    begin
      mem := TFPMemoryImage.Create(0, 0);
      rd := TFPReaderPNG.Create;
      ss := TStringStream.Create(DecodeStringBase64(Doc.Shapes[i].ImageData));
      try
        try
          mem.LoadFromStream(ss, rd);
          Result := TLazIntfImage.Create(0, 0);
          desc.Init_BPP32_B8G8R8A8_BIO_TTB(mem.Width, mem.Height);
          Result.DataDescription := desc;
          Result.SetSize(mem.Width, mem.Height);
          for y := 0 to mem.Height - 1 do
            for x := 0 to mem.Width - 1 do Result.Colors[x, y] := mem.Colors[x, y];
          Exit;
        except
          FreeAndNil(Result);
        end;
      finally
        ss.Free;
        rd.Free;
        mem.Free;
      end;
      Break;
    end;
  bmp := nil;
  if raw is TCustomBitmap then src := TCustomBitmap(raw).CreateIntfImage
  else
  begin
    bmp := TBitmap.Create;
    bmp.Assign(raw);
    src := bmp.CreateIntfImage;
  end;
  try
    try
      Result := TLazIntfImage.Create(0, 0);
      desc.Init_BPP32_B8G8R8A8_BIO_TTB(src.Width, src.Height);
      Result.DataDescription := desc;
      Result.SetSize(src.Width, src.Height);
      for y := 0 to src.Height - 1 do
        for x := 0 to src.Width - 1 do Result.Colors[x, y] := src.Colors[x, y];
    finally
      src.Free;
    end;
  finally
    bmp.Free;
  end;
end;

function TForm1.PngBase64(li: TLazIntfImage): string;
var
  png: TPortableNetworkGraphic;
  ms: TMemoryStream;
  raw: string;
begin
  png := TPortableNetworkGraphic.Create;
  ms := TMemoryStream.Create;
  try
    png.LoadFromIntfImage(li);
    png.SaveToStream(ms);
    SetString(raw, PAnsiChar(ms.Memory), ms.Size);
  finally
    ms.Free;
    png.Free;
  end;
  Result := EncodeStringBase64(raw);
end;

// the picture of a shape changed: what was kept of it (decoded, with holes, for the fast drawing) is not valid any more
// the document was made again (undo, redo, load, new): the shapes are other objects, what was kept for the old ones is not valid
procedure TForm1.FlushAllImageCaches;
var
  i: Integer;
begin
  for i := High(HoleImgs) downto 0 do HoleImgs[i].G.Free;
  SetLength(HoleImgs, 0);
  for i := High(FastImgs) downto 0 do
  begin
    FastImgs[i].Src.Free;
    FastImgs[i].Scaled.Free;
  end;
  SetLength(FastImgs, 0);
end;

// the pixels of a PNG (base64) turned upside down or left to right
function FlipPngBase64(const data: string; vertical: Boolean): string;
var
  bmp: TBGRABitmap;
  ms: TMemoryStream;
  ss: TStringStream;
begin
  Result := data;
  if data = '' then Exit;
  bmp := TBGRABitmap.Create;
  ms := TMemoryStream.Create;
  ss := TStringStream.Create(DecodeStringBase64(data));
  try
    try
      bmp.LoadFromStream(ss);
      if vertical then bmp.VerticalFlip else bmp.HorizontalFlip;
      bmp.SaveToStreamAsPng(ms);
      SetString(Result, PAnsiChar(ms.Memory), ms.Size);
      Result := EncodeStringBase64(Result);
    except
      Result := data;
    end;
  finally
    ss.Free;
    ms.Free;
    bmp.Free;
  end;
end;

// Flip / Mirror of a picture: its pixels are turned, and a turned picture keeps its place (the angle changes sign,
// which is what a flip about an axis through the centre does to a rotated rectangle)
procedure TForm1.FlipPicture(s: TShape; vertical: Boolean);
begin
  if s.Kind <> skImage then Exit;
  Checkpoint;
  s.ImageData := FlipPngBase64(s.ImageData, vertical);
  if s.KeyOn and (s.KeyOrig <> '') then s.KeyOrig := FlipPngBase64(s.KeyOrig, vertical);
  s.Rot := -s.Rot;
  FlushImageCaches(s);
  FlushAllImageCaches;
  Commit;
  if vertical then SetStatus('Picture flipped (upside down).') else SetStatus('Picture mirrored (left and right swapped).');
  RefreshProps;
  Redraw;
end;

// the raster the selection buttons work on: the one that is selected (or whose selection is), and is not part of a group
function TForm1.InvertSelImage: TShape;
var
  ts: TShapeArray;
  i: Integer;
  img: TShape;
begin
  Result := nil;
  ts := SelShapes;
  for i := 0 to High(ts) do
  begin
    img := nil;
    if (ts[i].Kind = skImage) and (ts[i].SelTarget = 0) then img := ts[i]
    else if ts[i].SelTarget > 0 then img := Doc.FindShape(ts[i].SelTarget);
    if (img = nil) or (img.Kind <> skImage) or (img.GroupId > 0) or not Interactive(img) then Continue;
    if (Result <> nil) and (Result <> img) then Exit(nil);       // more than one raster: it is not clear which
    Result := img;
  end;
end;

// Invert selection: the area that is selected on the raster becomes the one that is not, and the other way round. The result is one
// selection (not two): the pixels that were selected are worked out, taken the other way, and their outline is the new selection
procedure TForm1.InvertSelClick(Sender: TObject);
var
  img, nr: TShape;
  list: TShapeArray;
  raw: TGraphic;
  li: TLazIntfImage;
  mask: TBytes;
  loops: TPtLoops;
  w, h, i: Integer;
  hole: Boolean;
begin
  img := InvertSelImage;
  if img = nil then
  begin
    SetStatus('Invert selection: select one raster picture (or its selection) first.');
    Exit;
  end;
  raw := RawImage(img);
  if raw = nil then Exit;
  li := RgbaOf(raw);
  list := SelListOf(img);
  try
    w := li.Width;
    h := li.Height;
    mask := SelMask(img, list, w, h);
  finally
    li.Free;
  end;
  for i := 0 to High(mask) do
    if mask[i] <> 0 then mask[i] := 0 else mask[i] := 1;
  hole := (Length(list) > 0) and list[0].SelHole;
  Checkpoint;
  for i := High(list) downto 0 do Doc.DeleteShape(list[i]);
  nr := nil;
  if MaskLoops(mask, w, h, img, loops) then
  begin
    nr := TShape.Create;
    nr.Style := DefaultStyle;
    nr.Style.Fill := NoColor;
    SetPathFromLoops(nr, loops);
    nr.IsRef := True;
    nr.SelTarget := img.Id;
    nr.SelTol := DefWandTol;
    nr.SelHole := hole;
    nr.LayerId := img.LayerId;
    Doc.AddShape(nr);
  end;
  Commit;
  SelClear;
  if nr <> nil then
  begin
    SelSet(MakeRef(nr.Id, -1));
    SetStatus('Selection inverted.');
  end
  else
  begin
    SelSet(MakeRef(img.Id, -1));
    SetStatus('Selection inverted: everything was selected, now nothing is.');
  end;
  FlushImageCaches(img);
  FlushAllImageCaches;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// the figures (or groups) become one raster picture, as large as what is seen of them on the page, in their place
procedure TForm1.RasterizeShapes(const ts: TShapeArray);
var
  ord, mine: TShapeArray;
  run, part: TBGRABitmap;
  px: PBGRAPixel;
  ms: TMemoryStream;
  raw: string;
  ls: array of TLayer;
  ops, bgs: array of Integer;
  ids: TIntArray;
  i, j, x, y, w, h, bx1, by1, bx2, by2: Integer;
  ns: TShape;
  l: TLayer;
begin
  Doc.UpdateFillets;
  ord := Doc.DrawOrder;
  SetLength(mine, 0);
  for i := 0 to High(ord) do
    if (IndexInShapes(ts, ord[i]) >= 0) and not ord[i].IsRef and (ord[i].Kind <> skImage) and (ord[i].SelTarget = 0) then
    begin
      SetLength(mine, Length(mine) + 1);
      mine[High(mine)] := ord[i];
    end;
  if Length(mine) = 0 then
  begin
    SetStatus('Rasterize: nothing that can be rasterized is selected (or it is hidden).');
    Exit;
  end;
  w := Doc.Width;
  h := Doc.Height;
  // the opacity and the background of the layer are not part of the figures: they stay where they are
  SetLength(ls, 0);
  for i := 0 to High(mine) do
  begin
    l := Doc.LayerOf(mine[i]);
    j := 0;
    while (j <= High(ls)) and (ls[j] <> l) do Inc(j);
    if (j > High(ls)) and (l <> nil) then
    begin
      SetLength(ls, Length(ls) + 1);
      ls[High(ls)] := l;
    end;
  end;
  SetLength(ops, Length(ls));
  SetLength(bgs, Length(ls));
  for i := 0 to High(ls) do
  begin
    ops[i] := ls[i].Opacity;
    bgs[i] := ls[i].Bg;
    ls[i].Opacity := 255;
    ls[i].Bg := NoColor;
  end;
  try
    run := RenderRun(mine, 0, High(mine), w, h, 1, False, False);
  finally
    for i := 0 to High(ls) do
    begin
      ls[i].Opacity := ops[i];
      ls[i].Bg := bgs[i];
    end;
  end;
  part := nil;
  try
    bx1 := w;
    by1 := h;
    bx2 := -1;
    by2 := -1;
    for y := 0 to h - 1 do
    begin
      px := run.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        if px^.alpha > 0 then
        begin
          if x < bx1 then bx1 := x;
          if x > bx2 then bx2 := x;
          if y < by1 then by1 := y;
          if y > by2 then by2 := y;
        end;
        Inc(px);
      end;
    end;
    if bx2 < bx1 then
    begin
      SetStatus('Rasterize: nothing of the selection is visible on the page.');
      Exit;
    end;
    part := run.GetPart(Rect(bx1, by1, bx2 + 1, by2 + 1)) as TBGRABitmap;
    ms := TMemoryStream.Create;
    try
      part.SaveToStreamAsPng(ms);
      SetString(raw, PAnsiChar(ms.Memory), ms.Size);
    finally
      ms.Free;
    end;
  finally
    part.Free;
    run.Free;
  end;
  Checkpoint;
  SetLength(ids, Length(mine));
  for i := 0 to High(mine) do ids[i] := mine[i].Id;
  ns := NewPixelsShape(EncodeStringBase64(raw), (bx1 + bx2 + 1) / 2, (by1 + by2 + 1) / 2, (bx2 - bx1 + 1) / 2, (by2 - by1 + 1) / 2, 0, mine[High(mine)]);
  for i := 0 to High(ids) do
    if Doc.FindShape(ids[i]) <> nil then Doc.DeleteShape(Doc.FindShape(ids[i]));
  for i := Doc.Shapes.Count - 1 downto 0 do
    if (Doc.Shapes[i].SelTarget > 0) and (Doc.FindShape(Doc.Shapes[i].SelTarget) = nil) then Doc.DeleteShape(Doc.Shapes[i]);
  Commit;
  PurgeSelection;
  SelSet(MakeRef(ns.Id, -1));
  SetStatus('Rasterized: ' + IntToStr(Length(mine)) + ' figure(s) are now one raster picture of ' + IntToStr(bx2 - bx1 + 1) + 'x' + IntToStr(by2 - by1 + 1) + ' pixels.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// Flip / Mirror work on raster pictures and on groups (never on the single figures of a group, which are not handled alone)
function TForm1.FlipApplicable: Boolean;
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := SelShapes;
  Result := (Length(ts) > 0) and (Creating = nil) and (SelQuote = nil);
  for i := 0 to High(ts) do
    if not (((ts[i].Kind = skImage) and (ts[i].SelTarget = 0)) or (ts[i].GroupId > 0)) or ts[i].Bucket then Result := False;
end;

// the shape as it is seen in a mirror: vertical = the axis is horizontal (flip), otherwise vertical (left and right swapped);
// the axis goes through (cx, cy). A turned figure turns the other way
procedure TForm1.ReflectShape(s: TShape; vertical: Boolean; cx, cy: Double);
var
  i: Integer;
  w, w2: TPt;
  x1, y1, x2, y2: Double;
  a: Double;

  function Refl(const p: TPt): TPt;
  begin
    if vertical then Result := MakePt(p.x, 2 * cy - p.y) else Result := MakePt(2 * cx - p.x, p.y);
  end;

begin
  if s.Kind = skText then
  begin
    // the letters are not mirrored: the text goes where its box would be in the mirror
    if ShapeBox(s, x1, y1, x2, y2) then
    begin
      w := MakePt((x1 + x2) / 2, (y1 + y2) / 2);
      w2 := Refl(w);
      s.P[0] := MakePt(s.P[0].x + w2.x - w.x, s.P[0].y + w2.y - w.y);
    end;
    s.Rot := -s.Rot;
  end
  else if (s.Kind in [skRect, skImage]) and (Length(s.P) >= 2) then
  begin
    // the box keeps its size, its centre goes to the other side
    w := ShapePivot(s);
    w2 := Refl(w);
    for i := 0 to 1 do s.P[i] := MakePt(s.P[i].x + w2.x - w.x, s.P[i].y + w2.y - w.y);
    s.Rot := -s.Rot;
    if s.Kind = skImage then
    begin
      s.ImageData := FlipPngBase64(s.ImageData, vertical);
      if s.KeyOn and (s.KeyOrig <> '') then s.KeyOrig := FlipPngBase64(s.KeyOrig, vertical);
      FlushImageCaches(s);
    end;
  end
  else
  begin
    for i := 0 to High(s.P) do s.P[i] := Refl(s.P[i]);
    if s.Kind in [skEllipse, skArc, skPath] then s.Rot := -s.Rot;
    if s.Kind = skArc then
    begin
      // the arc runs the other way round
      a := s.A1;
      if vertical then
      begin
        s.A1 := -s.A2;
        s.A2 := -a;
      end
      else
      begin
        s.A1 := Pi - s.A2;
        s.A2 := Pi - a;
      end;
    end;
    if s.Kind = skPath then
    begin
      if vertical then s.PathData := AffinePathData(s.PathData, 1, 0, 0, -1)
      else s.PathData := AffinePathData(s.PathData, -1, 0, 0, 1);
      s.ParsePath;
    end;
  end;
  if s.HatchPat > 0 then
  begin
    if vertical then s.HatchAng := -s.HatchAng else s.HatchAng := 180 - s.HatchAng;
    while s.HatchAng > 180 do s.HatchAng := s.HatchAng - 360;
    while s.HatchAng < -180 do s.HatchAng := s.HatchAng + 360;
  end;
  if s.GroupId > 0 then s.GroupRot := -s.GroupRot;
end;

// Flip (Tag 1) / Mirror (Tag 0) button: every selected raster about its own centre, every selected group about the centre of its box
procedure TForm1.FlipClick(Sender: TObject);
var
  vertical: Boolean;
  ts: TShapeArray;
  gids: array of Integer;
  ids: TIntArray;
  i, j, n: Integer;
  x1, y1, x2, y2: Double;
  found: Boolean;
begin
  vertical := TSpeedButton(Sender).Tag = 1;
  if not FlipApplicable then Exit;
  ts := SelShapes;
  // a fixed point cannot be moved by the mirror
  for i := 0 to High(ts) do
    if Doc.IsPinned(ts[i].Id, 0) then
    begin
      SetStatus('Part of the selection is fixed.');
      Exit;
    end;
  Checkpoint;
  SetLength(gids, 0);
  n := 0;
  for i := 0 to High(ts) do
    if ts[i].GroupId > 0 then
    begin
      found := False;
      for j := 0 to High(gids) do
        if gids[j] = ts[i].GroupId then found := True;
      if not found then
      begin
        SetLength(gids, Length(gids) + 1);
        gids[High(gids)] := ts[i].GroupId;
      end;
    end
    else
    begin
      // a picture: about its own centre
      ReflectShape(ts[i], vertical, ShapePivot(ts[i]).x, ShapePivot(ts[i]).y);
      FlushImageCaches(ts[i]);
      Inc(n);
    end;
  for j := 0 to High(gids) do
  begin
    SetLength(ids, 0);
    for i := 0 to Doc.Shapes.Count - 1 do
      if Doc.Shapes[i].GroupId = gids[j] then
      begin
        SetLength(ids, Length(ids) + 1);
        ids[High(ids)] := Doc.Shapes[i].Id;
      end;
    if GroupBox(ids, x1, y1, x2, y2) then
      for i := 0 to High(ids) do
        ReflectShape(Doc.FindShape(ids[i]), vertical, (x1 + x2) / 2, (y1 + y2) / 2);
    Inc(n);
  end;
  Doc.Solve([]);
  Doc.UpdateFillets;
  FlushAllImageCaches;
  Commit;
  if vertical then SetStatus('Flipped (upside down): ' + IntToStr(n) + ' item(s).')
  else SetStatus('Mirrored (left and right swapped): ' + IntToStr(n) + ' item(s).');
  RefreshProps;
  Redraw;
end;

procedure TForm1.FlushImageCaches(s: TShape);
var
  i: Integer;
begin
  FreeAndNil(s.Cache);
  for i := High(HoleImgs) downto 0 do
    if HoleImgs[i].Shape = s then
    begin
      HoleImgs[i].G.Free;
      Delete(HoleImgs, i, 1);
    end;
  for i := High(FastImgs) downto 0 do
    if FastImgs[i].Shape = s then
    begin
      FastImgs[i].Src.Free;
      FastImgs[i].Scaled.Free;
      Delete(FastImgs, i, 1);
    end;
end;

// a new picture (PNG in base64), centred on (cx, cy), just above another one
function TForm1.NewPixelsShape(const data: string; cx, cy, hw, hh, rot: Double; after: TShape): TShape;
begin
  Result := NewShape(skImage);
  SetLength(Result.P, 2);
  Result.P[0] := MakePt(cx - hw, cy - hh);
  Result.P[1] := MakePt(cx + hw, cy + hh);
  Result.Rot := rot;
  Result.ImageData := data;
  Result.Style.Stroke := NoColor;
  if after <> nil then Result.LayerId := after.LayerId;
  Doc.AddShape(Result);
  if after <> nil then Doc.Shapes.Move(Doc.Shapes.IndexOf(Result), Doc.Shapes.IndexOf(after) + 1);
end;

function TForm1.AllSelections(const ts: TShapeArray): Boolean;
var
  i: Integer;
begin
  Result := Length(ts) > 0;
  for i := 0 to High(ts) do
    if ts[i].SelTarget <= 0 then Result := False;
end;

// operations on the pixels of the raster that the selections cover: 1 copy, 2 cut, 3 move (lift them into a picture of
// their own, leaving a transparent hole), 4 fill with a colour
procedure TForm1.PixelsOp(op: Integer; const sels: TShapeArray);
var
  img: TShape;
  raw: TGraphic;
  li, nl: TLazIntfImage;
  mask: TBytes;
  list: TShapeArray;
  col: TFPColor;
  data: string;
  w, h, x, y, bx1, by1, bx2, by2, i, bw, bh: Integer;
  x1, y1, x2, y2, fx, fy: Double;
  cn, dc: TPt;
  ns: TShape;
  fillCol: TColor;
  a: Integer;
begin
  SetLength(list, 0);
  if Length(sels) = 0 then Exit;
  img := Doc.FindShape(sels[0].SelTarget);
  // the area that is selected is made of all the selections of the raster
  list := SelListOf(img);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('The raster of this selection does not exist any more.');
    Exit;
  end;
  raw := RawImage(img);
  if raw = nil then Exit;
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    mask := SelMask(img, list, w, h);
    bx1 := w;
    by1 := h;
    bx2 := -1;
    by2 := -1;
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
        if mask[y * w + x] <> 0 then
        begin
          if x < bx1 then bx1 := x;
          if x > bx2 then bx2 := x;
          if y < by1 then by1 := y;
          if y > by2 then by2 := y;
        end;
    if bx2 < bx1 then
    begin
      SetStatus('The selection does not contain any pixel of the raster.');
      Exit;
    end;
    bw := bx2 - bx1 + 1;
    bh := by2 - by1 + 1;
    ImageBox(img, x1, y1, x2, y2);
    fx := w / (x2 - x1);
    fy := h / (y2 - y1);
    cn := MakePt(x1 + (bx1 + bx2 + 1) / 2 / fx, y1 + (by1 + by2 + 1) / 2 / fy);
    dc := TurnPt(cn, ShapePivot(img), img.Rot);
    if op in [1, 2, 3] then
    begin
      // the pixels alone, in a picture as small as they are
      nl := TLazIntfImage.Create(0, 0);
      try
        nl.DataDescription := li.DataDescription;
        nl.SetSize(bw, bh);
        col := FPColor(0, 0, 0, 0);
        for y := 0 to bh - 1 do
          for x := 0 to bw - 1 do
            if mask[(by1 + y) * w + bx1 + x] <> 0 then nl.Colors[x, y] := li.Colors[bx1 + x, by1 + y]
            else nl.Colors[x, y] := col;
        data := PngBase64(nl);
      finally
        nl.Free;
      end;
    end;
    if op = 1 then
    begin
      PixClip := data;
      PixCX := dc.x;
      PixCY := dc.y;
      PixHW := bw / fx / 2;
      PixHH := bh / fy / 2;
      PixRot := img.Rot;
      Inc(PixSerial);
      PixMarker := 'TTPAINT-PIXELS-' + IntToStr(PixSerial);
      SetClipboardPictureText(DecodeStringBase64(data), PixMarker);
      PasteCount := 0;
      SetStatus('Copied ' + IntToStr(bw) + 'x' + IntToStr(bh) + ' pixels (Ctrl+V pastes them as a new raster).');
      Exit;
    end;
    Checkpoint;
    if op = 3 then
    begin
      ns := NewPixelsShape(data, dc.x, dc.y, bw / fx / 2, bh / fy / 2, img.Rot, img);
    end
    else ns := nil;
    if op = 2 then
    begin
      PixClip := data;
      PixCX := dc.x;
      PixCY := dc.y;
      PixHW := bw / fx / 2;
      PixHH := bh / fy / 2;
      PixRot := img.Rot;
      Inc(PixSerial);
      PixMarker := 'TTPAINT-PIXELS-' + IntToStr(PixSerial);
      SetClipboardPictureText(DecodeStringBase64(data), PixMarker);
      PasteCount := 0;
    end;
    if op in [2, 3] then
    begin
      // what the pixels leave behind: the fill colour (the square behind in the colours), or a transparent hole when there is none
      if DefStyle.Fill <> NoColor then
      begin
        col := TColorToFPColor(DefStyle.Fill);
        col.alpha := (255 - DefStyle.FillTr) * 257;
      end
      else col := FPColor(0, 0, 0, 0);
      for y := by1 to by2 do
        for x := bx1 to bx2 do
          if mask[y * w + x] <> 0 then li.Colors[x, y] := col;
    end
    else
    begin
      // only the secondary colour (the fill) is used; on none the pixels become transparent
      if DefStyle.Fill <> NoColor then begin fillCol := DefStyle.Fill; a := 255 - DefStyle.FillTr; end
      else begin fillCol := TColor(0); a := 0; end;
      col := TColorToFPColor(fillCol);
      col.alpha := a * 257;
      for y := by1 to by2 do
        for x := bx1 to bx2 do
          if mask[y * w + x] <> 0 then li.Colors[x, y] := col;
    end;
    img.ImageData := PngBase64(li);
    img.KeyOn := False;
    img.KeyOrig := '';
    FlushImageCaches(img);
    if op = 2 then
    begin
      // the pixels are gone: the selection goes with them
      SelClear;
      for i := High(list) downto 0 do Doc.DeleteShape(list[i]);
      RefreshTree;
      RefreshLayers;
    end;
    Commit;
    if ns <> nil then
    begin
      SelSet(MakeRef(ns.Id, -1));
      SetStatus('The pixels are a raster of their own now: drag it to move them.');
    end
    else if op = 2 then SetStatus('Pixels cut (Ctrl+V pastes them as a new raster).')
    else SetStatus('Selection filled.');
    RefreshProps;
    Redraw;
  finally
    li.Free;
  end;
end;

// the pixels under the selections become a raster of their own (a copy of them if copyIt); where they were, the
// fill colour (the square behind) stays (or a transparent hole, when there is none). The selections go away with them.
function TForm1.PixLift(const sels: TShapeArray; copyIt: Boolean): TShape;
var
  img: TShape;
  raw: TGraphic;
  li, nl: TLazIntfImage;
  mask: TBytes;
  col: TFPColor;
  data: string;
  w, h, x, y, bx1, by1, bx2, by2, bw, bh, i: Integer;
  x1, y1, x2, y2, fx, fy: Double;
  cn, dc: TPt;
  list: TShapeArray;
begin
  Result := nil;
  if Length(sels) = 0 then Exit;
  img := Doc.FindShape(sels[0].SelTarget);
  if (img = nil) or (img.Kind <> skImage) then Exit;
  list := SelListOf(img);
  raw := RawImage(img);
  if raw = nil then Exit;
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    mask := SelMask(img, list, w, h);
    bx1 := w;
    by1 := h;
    bx2 := -1;
    by2 := -1;
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
        if mask[y * w + x] <> 0 then
        begin
          if x < bx1 then bx1 := x;
          if x > bx2 then bx2 := x;
          if y < by1 then by1 := y;
          if y > by2 then by2 := y;
        end;
    if bx2 < bx1 then
    begin
      SetStatus('The selection does not contain any pixel of the raster.');
      Exit;
    end;
    bw := bx2 - bx1 + 1;
    bh := by2 - by1 + 1;
    ImageBox(img, x1, y1, x2, y2);
    fx := w / (x2 - x1);
    fy := h / (y2 - y1);
    cn := MakePt(x1 + (bx1 + bx2 + 1) / 2 / fx, y1 + (by1 + by2 + 1) / 2 / fy);
    dc := TurnPt(cn, ShapePivot(img), img.Rot);
    nl := TLazIntfImage.Create(0, 0);
    try
      nl.DataDescription := li.DataDescription;
      nl.SetSize(bw, bh);
      col := FPColor(0, 0, 0, 0);
      for y := 0 to bh - 1 do
        for x := 0 to bw - 1 do
          if mask[(by1 + y) * w + bx1 + x] <> 0 then nl.Colors[x, y] := li.Colors[bx1 + x, by1 + y]
          else nl.Colors[x, y] := col;
      data := PngBase64(nl);
    finally
      nl.Free;
    end;
    Result := NewPixelsShape(data, dc.x, dc.y, bw / fx / 2, bh / fy / 2, img.Rot, img);
    FloatId := Result.Id;
    FloatBase := img.Id;
    FloatBox[0] := Result.P[0].x; FloatBox[1] := Result.P[0].y; FloatBox[2] := Result.P[1].x; FloatBox[3] := Result.P[1].y;
    FloatRot := Result.Rot;
    if not copyIt then
    begin
      if DefStyle.Fill <> NoColor then
      begin
        col := TColorToFPColor(DefStyle.Fill);         // the colour behind in the little squares
        col.alpha := (255 - DefStyle.FillTr) * 257;
      end
      else col := FPColor(0, 0, 0, 0);
      for y := by1 to by2 do
        for x := bx1 to bx2 do
          if mask[y * w + x] <> 0 then li.Colors[x, y] := col;
      img.ImageData := PngBase64(li);
      img.KeyOn := False;
      img.KeyOrig := '';
      FlushImageCaches(img);
    end;
  finally
    li.Free;
  end;
  SelClear;
  for i := High(list) downto 0 do Doc.DeleteShape(list[i]);
  // the tree of objects still points to the selections that are gone: it is made again before anything draws
  RefreshTree;
  RefreshLayers;
end;

// the area that the selections cover becomes a vector shape (a path made of its outlines)
procedure TForm1.SelToVector(const sels: TShapeArray);
var
  img, nr: TShape;
  raw: TGraphic;
  li: TLazIntfImage;
  mask: TBytes;
  loops: TPtLoops;
  w, h: Integer;
begin
  if Length(sels) = 0 then Exit;
  img := Doc.FindShape(sels[0].SelTarget);
  if (img = nil) or (img.Kind <> skImage) then Exit;
  raw := RawImage(img);
  if raw = nil then Exit;
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    mask := SelMask(img, SelListOf(img), w, h);
  finally
    li.Free;
  end;
  if not MaskLoops(mask, w, h, img, loops) then
  begin
    SetStatus('The selection does not contain any pixel of the raster.');
    Exit;
  end;
  Checkpoint;
  nr := TShape.Create;
  nr.Style := DefaultStyle;
  if (Length(loops) = 1) and (Length(loops[0]) >= 3) then
  begin
    // one outline: a polygon, whose corners can be moved and take constraints
    nr.Kind := skPolygon;
    nr.P := Copy(loops[0]);
  end
  else SetPathFromLoops(nr, loops);       // several outlines or holes: a polygon cannot have them, a path made of straight sides can
  nr.LayerId := img.LayerId;
  Doc.AddShape(nr);
  Commit;
  SelSet(MakeRef(nr.Id, -1));
  if nr.Kind = skPolygon then SetStatus('The selection is now a vector polygon of ' + IntToStr(Length(nr.P)) + ' corners: its points can be edited.')
  else SetStatus('The selection is now a vector figure with several outlines or holes (a path of straight sides): its points can be edited.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.PastePixels;
var
  ns: TShape;
  d: Double;
begin
  if PixClip = '' then Exit;
  Inc(PasteCount);
  d := 12 * PasteCount;
  Checkpoint;
  ns := NewPixelsShape(PixClip, PixCX + d, PixCY + d, PixHW, PixHH, PixRot, nil);
  Commit;
  SetTool(tlSelect);
  SelSet(MakeRef(ns.Id, -1));
  SetStatus('Pasted as a new raster: drag it where you want.');
  RefreshProps;
  Redraw;
end;

function TForm1.PixelsOnClipboard: Boolean;
begin
  Result := (PixClip <> '') and (ClipboardText = PixMarker);
end;

// the paint bucket inside a selection of a raster paints its pixels
function TForm1.BucketOnSelection(px, py: Double): Boolean;
var
  i: Integer;
  sh: TShape;
  list: TShapeArray;
begin
  Result := False;
  SetLength(list, 0);
  for i := Doc.Shapes.Count - 1 downto 0 do
  begin
    sh := Doc.Shapes[i];
    if (sh.SelTarget <= 0) or not Doc.ShapeVisible(sh) then Continue;
    if InsideOutline(ShapeOutline(sh), px, py) then
    begin
      SetLength(list, 1);
      list[0] := sh;
      Break;
    end;
  end;
  if Length(list) = 0 then Exit;
  Result := True;
  PixelsOp(4, list);
end;

// the picture of a shape as it is seen (with the parts that selections make transparent), with a channel for the opacity
function TForm1.EffectiveRgba(s: TShape): TLazIntfImage;
var
  raw: TGraphic;
  holes: TShapeArray;
  mask: TBytes;
  i, x, y, w, h: Integer;
  col: TFPColor;
begin
  Result := nil;
  raw := RawImage(s);
  if raw = nil then Exit;
  Result := RgbaOf(raw);
  SetLength(holes, 0);
  for i := 0 to Doc.Shapes.Count - 1 do
    if (Doc.Shapes[i].SelTarget = s.Id) and (Doc.Shapes[i].SelHole or Doc.Shapes[i].SelSub) then
    begin
      SetLength(holes, Length(holes) + 1);
      holes[High(holes)] := Doc.Shapes[i];
    end;
  if Length(holes) = 0 then Exit;
  w := Result.Width;
  h := Result.Height;
  mask := SelMask(s, holes, w, h);
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
      if mask[y * w + x] <> 0 then
      begin
        col := Result.Colors[x, y];
        col.alpha := 0;
        Result.Colors[x, y] := col;
      end;
end;

// two rasters become one: a rectangle, transparent where neither of them is, that holds both as they are seen
procedure TForm1.MergeRastersClick(Sender: TObject);
var
  ts: TShapeArray;
  imgs: array[0..1] of TShape;
  srcs: array[0..1] of TLazIntfImage;
  outImg: TLazIntfImage;
  desc: TRawImageDescription;
  srcRows: array of PBGRAPixel;
  c, q, p: TPt;
  corners: array[0..3] of TPt;
  bx1, by1, bx2, by2, X1, Y1, X2, Y2, dens, f, ux, vy, fx, fy, w00, w10, w01, w11: Double;
  cx1, cy1, cx2, cy2: Double;
  k, i, j, ow, oh, ox, oy, ox1, oy1, ox2, oy2, sw, sh, ix, iy, ix1, iy1: Integer;
  dst, p00, p10, p01, p11: PBGRAPixel;
  sa, pa, pr, pg, pb, da, oa: Double;
  id0, id1: Integer;
  ns: TShape;
begin
  ts := SelShapes;
  if (Length(ts) <> 2) or (ts[0].Kind <> skImage) or (ts[1].Kind <> skImage) then
  begin
    SetStatus('Merge rasters: select two rasters.');
    Exit;
  end;
  if Doc.Shapes.IndexOf(ts[0]) < Doc.Shapes.IndexOf(ts[1]) then
  begin
    imgs[0] := ts[0];
    imgs[1] := ts[1];
  end
  else
  begin
    imgs[0] := ts[1];
    imgs[1] := ts[0];
  end;
  srcs[0] := nil;
  srcs[1] := nil;
  outImg := nil;
  try
    X1 := 1e30;
    Y1 := 1e30;
    X2 := -1e30;
    Y2 := -1e30;
    dens := 0;
    for k := 0 to 1 do
    begin
      srcs[k] := EffectiveRgba(imgs[k]);
      if srcs[k] = nil then
      begin
        SetStatus('Merge rasters: a picture cannot be read.');
        Exit;
      end;
      ImageBox(imgs[k], bx1, by1, bx2, by2);
      c := ShapePivot(imgs[k]);
      corners[0] := MakePt(bx1, by1);
      corners[1] := MakePt(bx2, by1);
      corners[2] := MakePt(bx2, by2);
      corners[3] := MakePt(bx1, by2);
      for i := 0 to 3 do
      begin
        p := TurnPt(corners[i], c, imgs[k].Rot);
        X1 := Min(X1, p.x);
        Y1 := Min(Y1, p.y);
        X2 := Max(X2, p.x);
        Y2 := Max(Y2, p.y);
      end;
      // the finer of the two pictures sets the pixels of the result
      dens := Max(dens, Max(srcs[k].Width / (bx2 - bx1), srcs[k].Height / (by2 - by1)));
    end;
    if (X2 - X1 < 1e-6) or (Y2 - Y1 < 1e-6) or (dens <= 0) then Exit;
    ow := Max(1, Ceil((X2 - X1) * dens - 1e-6));
    oh := Max(1, Ceil((Y2 - Y1) * dens - 1e-6));
    f := Min(Min(8192 / ow, 8192 / oh), Sqrt(40e6 / (1.0 * ow * oh)));
    if f < 1 then
    begin
      dens := dens * f;
      ow := Max(1, Ceil((X2 - X1) * dens - 1e-6));
      oh := Max(1, Ceil((Y2 - Y1) * dens - 1e-6));
    end;
    outImg := TLazIntfImage.Create(0, 0);
    desc.Init_BPP32_B8G8R8A8_BIO_TTB(ow, oh);
    outImg.DataDescription := desc;
    outImg.SetSize(ow, oh);
    for oy := 0 to oh - 1 do FillChar(outImg.GetDataLineStart(oy)^, ow * 4, 0);
    for k := 0 to 1 do
    begin
      ImageBox(imgs[k], bx1, by1, bx2, by2);
      c := ShapePivot(imgs[k]);
      sw := srcs[k].Width;
      sh := srcs[k].Height;
      SetLength(srcRows, sh);
      for j := 0 to sh - 1 do srcRows[j] := PBGRAPixel(srcs[k].GetDataLineStart(j));
      // the box of this picture in the result
      cx1 := 1e30;
      cy1 := 1e30;
      cx2 := -1e30;
      cy2 := -1e30;
      corners[0] := MakePt(bx1, by1);
      corners[1] := MakePt(bx2, by1);
      corners[2] := MakePt(bx2, by2);
      corners[3] := MakePt(bx1, by2);
      for i := 0 to 3 do
      begin
        p := TurnPt(corners[i], c, imgs[k].Rot);
        cx1 := Min(cx1, p.x);
        cy1 := Min(cy1, p.y);
        cx2 := Max(cx2, p.x);
        cy2 := Max(cy2, p.y);
      end;
      ox1 := Max(0, Floor((cx1 - X1) * dens));
      oy1 := Max(0, Floor((cy1 - Y1) * dens));
      ox2 := Min(ow - 1, Ceil((cx2 - X1) * dens));
      oy2 := Min(oh - 1, Ceil((cy2 - Y1) * dens));
      for oy := oy1 to oy2 do
      begin
        dst := PBGRAPixel(outImg.GetDataLineStart(oy)) + ox1;
        for ox := ox1 to ox2 do
        begin
          // the middle of the pixel, back in the frame of the (unturned) picture
          q := TurnPt(MakePt(X1 + (ox + 0.5) / dens, Y1 + (oy + 0.5) / dens), c, -imgs[k].Rot);
          if (q.x >= bx1) and (q.x <= bx2) and (q.y >= by1) and (q.y <= by2) then
          begin
            ux := (q.x - bx1) / (bx2 - bx1) * sw - 0.5;
            vy := (q.y - by1) / (by2 - by1) * sh - 0.5;
            ix := Floor(ux);
            iy := Floor(vy);
            fx := ux - ix;
            fy := vy - iy;
            ix1 := Min(Max(ix + 1, 0), sw - 1);
            iy1 := Min(Max(iy + 1, 0), sh - 1);
            ix := Min(Max(ix, 0), sw - 1);
            iy := Min(Max(iy, 0), sh - 1);
            p00 := srcRows[iy] + ix;
            p10 := srcRows[iy] + ix1;
            p01 := srcRows[iy1] + ix;
            p11 := srcRows[iy1] + ix1;
            w00 := (1 - fx) * (1 - fy);
            w10 := fx * (1 - fy);
            w01 := (1 - fx) * fy;
            w11 := fx * fy;
            // colours weighted by their opacity
            pa := w00 * p00^.alpha + w10 * p10^.alpha + w01 * p01^.alpha + w11 * p11^.alpha;
            if pa > 0.01 then
            begin
              pr := (w00 * p00^.alpha * p00^.red + w10 * p10^.alpha * p10^.red + w01 * p01^.alpha * p01^.red + w11 * p11^.alpha * p11^.red) / pa;
              pg := (w00 * p00^.alpha * p00^.green + w10 * p10^.alpha * p10^.green + w01 * p01^.alpha * p01^.green + w11 * p11^.alpha * p11^.green) / pa;
              pb := (w00 * p00^.alpha * p00^.blue + w10 * p10^.alpha * p10^.blue + w01 * p01^.alpha * p01^.blue + w11 * p11^.alpha * p11^.blue) / pa;
              sa := pa / 255;
              da := dst^.alpha / 255;
              oa := sa + da * (1 - sa);
              if oa > 0 then
              begin
                dst^.red := Min(255, Round((pr * sa + dst^.red * da * (1 - sa)) / oa));
                dst^.green := Min(255, Round((pg * sa + dst^.green * da * (1 - sa)) / oa));
                dst^.blue := Min(255, Round((pb * sa + dst^.blue * da * (1 - sa)) / oa));
                dst^.alpha := Min(255, Round(oa * 255));
              end;
            end;
          end;
          Inc(dst);
        end;
      end;
    end;
    id0 := imgs[0].Id;
    id1 := imgs[1].Id;
    Checkpoint;
    ns := NewPixelsShape(PngBase64(outImg), (X1 + X2) / 2, (Y1 + Y2) / 2, (X2 - X1) / 2, (Y2 - Y1) / 2, 0, imgs[1]);
    for i := Doc.Shapes.Count - 1 downto 0 do
      if (Doc.Shapes[i].SelTarget = id0) or (Doc.Shapes[i].SelTarget = id1) then Doc.DeleteShape(Doc.Shapes[i]);
    Doc.DeleteShape(Doc.FindShape(id0));
    Doc.DeleteShape(Doc.FindShape(id1));
    Commit;
    SelSet(MakeRef(ns.Id, -1));
    SetStatus('Rasters merged: ' + IntToStr(ow) + 'x' + IntToStr(oh) + ' pixels.');
    RefreshProps;
    RefreshLayers;
    Redraw;
  finally
    srcs[0].Free;
    srcs[1].Free;
    outImg.Free;
  end;
end;

function TForm1.MakeMergeIcon: TBitmap;
var
  c: TCanvas;
begin
  Result := TBitmap.Create;
  Result.SetSize(26, 22);
  Result.Transparent := True;
  Result.TransparentColor := clFuchsia;
  c := Result.Canvas;
  c.Brush.Color := clFuchsia;
  c.FillRect(0, 0, 26, 22);
  c.Pen.Color := clBlack;
  c.Pen.Width := 1;
  c.Brush.Color := TColor($E8C090);
  c.Rectangle(1, 1, 14, 12);
  c.Brush.Color := TColor($90C0E8);
  c.Rectangle(11, 9, 24, 20);
  c.Brush.Color := TColor($B8B8B8);
  c.Pen.Style := psClear;
  c.Rectangle(12, 10, 14, 12);
  c.Pen.Style := psSolid;
end;

// the boundaries of the area of the picture that has a colour like the one at (u, v) (fractions of the picture), as loops in
// the coordinates of the document; the colour may differ by tolPct percent
function TForm1.WandRegion(img: TShape; u, v: Double; tolPct: Integer; out loops: TPtLoops): Boolean;
type
  TPix = record
    R, G, B, A: Byte;
  end;
var
  g: TGraphic;
  bmp: TBitmap;
  li: TLazIntfImage;
  pix: array of TPix;
  mask: array of Byte;
  stack: array of Integer;
  w, h, x, y, sx, sy, sp, i, n, tol: Integer;
  seed: TPix;
  cl: TFPColor;
  x1, y1, x2, y2: Double;
  c: TPt;

  function Close(const p: TPix): Boolean;
  begin
    Result := (Abs(p.R - seed.R) <= tol) and (Abs(p.G - seed.G) <= tol) and (Abs(p.B - seed.B) <= tol) and
      (Abs(p.A - seed.A) <= tol);
  end;

  procedure Push(xx, yy: Integer);
  var
    q: Integer;
  begin
    if (xx < 0) or (yy < 0) or (xx >= w) or (yy >= h) then Exit;
    q := yy * w + xx;
    if (mask[q] <> 0) or not Close(pix[q]) then Exit;
    mask[q] := 1;
    stack[sp] := q;
    Inc(sp);
  end;

begin
  Result := False;
  SetLength(loops, 0);
  g := RawImage(img);
  if (g = nil) or (Length(img.P) < 2) then Exit;
  bmp := TBitmap.Create;
  try
    bmp.Assign(g);
    li := bmp.CreateIntfImage;
    try
      w := li.Width;
      h := li.Height;
      if (w < 1) or (h < 1) then Exit;
      SetLength(pix, w * h);
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          cl := li.Colors[x, y];
          pix[y * w + x].R := cl.red shr 8;
          pix[y * w + x].G := cl.green shr 8;
          pix[y * w + x].B := cl.blue shr 8;
          pix[y * w + x].A := cl.alpha shr 8;
        end;
    finally
      li.Free;
    end;
  finally
    bmp.Free;
  end;
  tol := Round(Max(0, Min(100, tolPct)) * 2.55);
  sx := Max(0, Min(w - 1, Trunc(u * w)));
  sy := Max(0, Min(h - 1, Trunc(v * h)));
  seed := pix[sy * w + sx];
  SetLength(mask, w * h);
  SetLength(stack, w * h);
  FillChar(mask[0], Length(mask), 0);
  sp := 0;
  Push(sx, sy);
  while sp > 0 do
  begin
    Dec(sp);
    i := stack[sp];
    x := i mod w;
    y := i div w;
    Push(x + 1, y);
    Push(x - 1, y);
    Push(x, y + 1);
    Push(x, y - 1);
  end;
  Result := MaskLoops(mask, w, h, img, loops);
end;

// the outlines of the pixels that are marked (1 byte each, w x h), in the coordinates of the document, on the picture img
function TForm1.MaskLoops(const mask: TBytes; w, h: Integer; img: TShape; out loops: TPtLoops): Boolean;
var
  dirs: array of Byte;
  x, y, i, n: Integer;
  x1, y1, x2, y2: Double;
  c: TPt;

  function Inside(xx, yy: Integer): Boolean;
  begin
    Result := (xx >= 0) and (yy >= 0) and (xx < w) and (yy < h) and (mask[yy * w + xx] <> 0);
  end;

  // the loops of the pixels that are marked, along the sides of the pixels (the area stays on the right)
  procedure Trace;
  var
    x, y, vw, v0, cur, dIn, d, nd, k, cnt, lastD: Integer;
    px, py, bx, by, dx, dy: Integer;
    lp: TPtArray;
    pts: TPtArray;
    start: Integer;
  const
    DX4: array[0..3] of Integer = (1, 0, -1, 0);
    DY4: array[0..3] of Integer = (0, 1, 0, -1);
  begin
    vw := w + 1;
    SetLength(dirs, vw * (h + 1));
    FillChar(dirs[0], Length(dirs), 0);
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
        if mask[y * w + x] <> 0 then
        begin
          if not Inside(x, y - 1) then dirs[y * vw + x] := dirs[y * vw + x] or 1;
          if not Inside(x + 1, y) then dirs[y * vw + x + 1] := dirs[y * vw + x + 1] or 2;
          if not Inside(x, y + 1) then dirs[(y + 1) * vw + x + 1] := dirs[(y + 1) * vw + x + 1] or 4;
          if not Inside(x - 1, y) then dirs[(y + 1) * vw + x] := dirs[(y + 1) * vw + x] or 8;
        end;
    for v0 := 0 to High(dirs) do
      while dirs[v0] <> 0 do
      begin
        start := v0;
        d := 0;
        while (dirs[v0] and (1 shl d)) = 0 do Inc(d);
        SetLength(lp, 0);
        cur := start;
        lastD := -1;
        repeat
          // a corner is where the direction changes
          px := cur mod vw;
          py := cur div vw;
          if d <> lastD then
          begin
            SetLength(lp, Length(lp) + 1);
            lp[High(lp)].x := px;
            lp[High(lp)].y := py;
          end;
          dirs[cur] := dirs[cur] and not (1 shl d);
          lastD := d;
          cur := (py + DY4[d]) * vw + (px + DX4[d]);
          dIn := d;
          if dirs[cur] = 0 then Break;
          // the next side: turn left if possible, then straight on, then right
          nd := -1;
          for k := 0 to 2 do
          begin
            d := (dIn + 3 + k) mod 4;
            if (dirs[cur] and (1 shl d)) <> 0 then
            begin
              nd := d;
              Break;
            end;
          end;
          if nd < 0 then
          begin
            d := (dIn + 2) mod 4;
            if (dirs[cur] and (1 shl d)) = 0 then Break;
            nd := d;
          end;
          d := nd;
        until False;
        cnt := Length(lp);
        if cnt >= 3 then
        begin
          SetLength(loops, Length(loops) + 1);
          loops[High(loops)] := lp;
        end;
        dirs[start] := dirs[start];
      end;
    // keep the loops, simplified later
    pts := nil;
    bx := 0;
    by := 0;
    dx := bx;
    dy := by;
  end;

  // a closed loop with fewer points (Douglas-Peucker, a staircase becomes straight lines)
  function Simplify(const lp: TPtArray; eps: Double): TPtArray;
  var
    nn, a, b, mid, k2, top, cnt2: Integer;
    keep: array of Boolean;
    st: array of Integer;
    best, dd, lx, ly, ll: Double;
  begin
    nn := Length(lp);
    SetLength(Result, 0);
    if nn < 4 then
    begin
      Result := Copy(lp);
      Exit;
    end;
    SetLength(keep, nn);
    for k2 := 0 to nn - 1 do keep[k2] := False;
    // the farthest point from the first splits the loop in two open runs
    mid := 0;
    best := -1;
    for k2 := 1 to nn - 1 do
    begin
      dd := Sqr(lp[k2].x - lp[0].x) + Sqr(lp[k2].y - lp[0].y);
      if dd > best then
      begin
        best := dd;
        mid := k2;
      end;
    end;
    keep[0] := True;
    keep[mid] := True;
    SetLength(st, 0);
    for k2 := 0 to 1 do
    begin
      if k2 = 0 then
      begin
        a := 0;
        b := mid;
      end
      else
      begin
        a := mid;
        b := nn;
      end;
      SetLength(st, Length(st) + 2);
      st[High(st) - 1] := a;
      st[High(st)] := b;
    end;
    while Length(st) > 0 do
    begin
      b := st[High(st)];
      a := st[High(st) - 1];
      SetLength(st, Length(st) - 2);
      if b - a < 2 then Continue;
      lx := lp[b mod nn].x - lp[a].x;
      ly := lp[b mod nn].y - lp[a].y;
      ll := Sqrt(lx * lx + ly * ly);
      best := -1;
      mid := a;
      for k2 := a + 1 to b - 1 do
      begin
        if ll < 1e-12 then dd := Hypot(lp[k2].x - lp[a].x, lp[k2].y - lp[a].y)
        else dd := Abs((lp[k2].x - lp[a].x) * ly - (lp[k2].y - lp[a].y) * lx) / ll;
        if dd > best then
        begin
          best := dd;
          mid := k2;
        end;
      end;
      if best > eps then
      begin
        keep[mid mod nn] := True;
        top := Length(st);
        SetLength(st, top + 4);
        st[top] := a;
        st[top + 1] := mid;
        st[top + 2] := mid;
        st[top + 3] := b;
      end;
    end;
    cnt2 := 0;
    for k2 := 0 to nn - 1 do
      if keep[k2] then Inc(cnt2);
    SetLength(Result, cnt2);
    cnt2 := 0;
    for k2 := 0 to nn - 1 do
      if keep[k2] then
      begin
        Result[cnt2] := lp[k2];
        Inc(cnt2);
      end;
  end;

  function Area2(const lp: TPtArray): Double;
  var
    k2: Integer;
  begin
    Result := 0;
    for k2 := 0 to High(lp) do
      Result := Result + lp[k2].x * lp[(k2 + 1) mod Length(lp)].y - lp[(k2 + 1) mod Length(lp)].x * lp[k2].y;
    Result := Abs(Result) / 2;
  end;

begin
  Result := False;
  SetLength(loops, 0);
  if (w < 1) or (h < 1) or (Length(mask) < w * h) then Exit;
  Trace;
  // in the coordinates of the document
  ImageBox(img, x1, y1, x2, y2);
  c := ShapePivot(img);
  n := 0;
  for i := 0 to High(loops) do
  begin
    loops[i] := Simplify(loops[i], 0.75);
    if (Length(loops[i]) < 3) or (Area2(loops[i]) < 3) then Continue;
    for x := 0 to High(loops[i]) do
    begin
      loops[i][x] := TurnPt(MakePt(x1 + loops[i][x].x / w * (x2 - x1), y1 + loops[i][x].y / h * (y2 - y1)), c, img.Rot);
    end;
    loops[n] := loops[i];
    Inc(n);
  end;
  SetLength(loops, n);
  Result := n > 0;
end;

// a path made of these closed outlines; its handle (and the pivot of a rotation) is the centre of its box
procedure TForm1.SetPathFromLoops(nr: TShape; const lps: TPtLoops);
var
  i, j: Integer;
  bx1, by1, bx2, by2, cx, cy: Double;
  pd: string;

  function F(v: Double): string;
  begin
    Result := StringReplace(FormatFloat('0.###', v), DefaultFormatSettings.DecimalSeparator, '.', []);
  end;

begin
  bx1 := 1e300; by1 := 1e300; bx2 := -1e300; by2 := -1e300;
  for i := 0 to High(lps) do
    for j := 0 to High(lps[i]) do
    begin
      bx1 := Min(bx1, lps[i][j].x);
      by1 := Min(by1, lps[i][j].y);
      bx2 := Max(bx2, lps[i][j].x);
      by2 := Max(by2, lps[i][j].y);
    end;
  cx := (bx1 + bx2) / 2;
  cy := (by1 + by2) / 2;
  pd := '';
  for i := 0 to High(lps) do
  begin
    for j := 0 to High(lps[i]) do
    begin
      if j = 0 then pd := pd + 'M' else pd := pd + ' L';
      pd := pd + F(lps[i][j].x - cx) + ' ' + F(lps[i][j].y - cy);
    end;
    pd := pd + ' Z ';
  end;
  nr.Kind := skPath;
  SetLength(nr.P, 1);
  nr.P[0] := MakePt(cx, cy);
  nr.Rot := 0;
  nr.PathData := Trim(pd);
  SetLength(nr.PN, 0);
  nr.PNSrc := '';
  nr.ParsePath;
end;

procedure TForm1.WandAt(px, py: Double; Shift: TShiftState);
var
  img, nr: TShape;
  q, c: TPt;
  x1, y1, x2, y2, u, v: Double;
  loops: TPtLoops;
begin
  img := Doc.FindShape(ToolImg);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('Magic wand: select a raster picture first.');
    Exit;
  end;
  ImageBox(img, x1, y1, x2, y2);
  c := ShapePivot(img);
  q := TurnPt(MakePt(px, py), c, -img.Rot);
  if (q.x < x1) or (q.x > x2) or (q.y < y1) or (q.y > y2) or (x2 - x1 < 1e-6) or (y2 - y1 < 1e-6) then
  begin
    SetStatus('Magic wand: click inside the selected raster.');
    Exit;
  end;
  u := (q.x - x1) / (x2 - x1);
  v := (q.y - y1) / (y2 - y1);
  if not WandRegion(img, u, v, DefWandTol, loops) then
  begin
    SetStatus('Magic wand: nothing found there.');
    Exit;
  end;
  Checkpoint;
  nr := TShape.Create;
  nr.Style := DefaultStyle;
  nr.Style.Fill := NoColor;
  SetPathFromLoops(nr, loops);
  nr.IsRef := True;
  nr.SelTarget := img.Id;
  nr.SelTol := DefWandTol;
  nr.SelU := u;
  nr.SelV := v;
  nr.SelWand := True;
  nr.LayerId := img.LayerId;
  Doc.AddShape(nr);
  SelMode := SelModeOf(Shift);
  SelRegister(nr, img);
  Commit;
  SelSet(MakeRef(nr.Id, -1));
  SetStatus('Selection made: the tolerance and "Transparent content" are in its properties.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// a closed figure that lies entirely on the picture becomes a selection of it
procedure TForm1.SelShapeAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s, img: TShape;
  o: TOutline;
  q, c: TPt;
  x1, y1, x2, y2: Double;
  i, j: Integer;
  inside: Boolean;
begin
  img := Doc.FindShape(ToolImg);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('Selection: select a raster picture first.');
    Exit;
  end;
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Selection: click a closed figure that lies on the raster.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if (s = nil) or (s = img) then Exit;
  if s.SelTarget > 0 then
  begin
    SetStatus('This is already a selection.');
    Exit;
  end;
  if not BoolEligible(s) then
  begin
    SetStatus('Selection: only a closed figure (rectangle, ellipse, polygon, closed curve or path) can become a selection.');
    Exit;
  end;
  ImageBox(img, x1, y1, x2, y2);
  c := ShapePivot(img);
  inside := True;
  o := ShapeOutline(s);
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      q := TurnPt(o[i].Pts[j], c, -img.Rot);
      if (q.x < x1) or (q.x > x2) or (q.y < y1) or (q.y > y2) then inside := False;
    end;
  if not inside then
  begin
    SetStatus('Selection: the figure must lie entirely on the raster.');
    Exit;
  end;
  Checkpoint;
  s.SelTarget := img.Id;
  s.SelHole := False;
  s.SelWand := False;
  s.SelTol := DefWandTol;
  s.IsRef := True;
  SelMode := SelModeOf(Shift);
  SelRegister(s, img);
  Commit;
  SelSet(MakeRef(s.Id, -1));
  SetStatus('The figure is now a selection of the raster: "Transparent content" is in its properties.');
  RefreshProps;
  Redraw;
end;

// the area of a selection made by the wand is found again with its tolerance
procedure TForm1.RegenWand(sh: TShape);
var
  img: TShape;
  loops: TPtLoops;
begin
  img := Doc.FindShape(sh.SelTarget);
  if (img = nil) or (img.Kind <> skImage) or not sh.SelWand then Exit;
  if WandRegion(img, sh.SelU, sh.SelV, sh.SelTol, loops) then SetPathFromLoops(sh, loops)
  else SetStatus('Magic wand: nothing found with this tolerance.');
end;

// with the variable TTP_DEBUG set, what the mouse does on selections goes to /tmp/ttp_dbg.log
procedure DbgLog(const m: string);
var
  f: TextFile;
begin
  if GetEnvironmentVariable('TTP_DEBUG') = '' then Exit;
  AssignFile(f, '/tmp/ttp_dbg.log');
  if FileExists('/tmp/ttp_dbg.log') then Append(f) else Rewrite(f);
  WriteLn(f, FormatDateTime('hh:nn:ss.zzz', Now), ' ', m);
  CloseFile(f);
end;

// dragging inside the area that is selected on a raster takes the pixels along (Ctrl: a copy of them)
procedure TForm1.StartPixDrag(s: TShape; Shift: TShiftState);
var
  ts: TShapeArray;
  i: Integer;
begin
  DbgLog('StartPix sel=' + IntToStr(s.Id) + ' ctrl=' + BoolToStr(ssCtrl in Shift, True) + ' tool=' + IntToStr(Ord(Tool)));
  Checkpoint;
  Moved := False;
  ts := SelListOf(Doc.FindShape(s.SelTarget));
  SetLength(PixIds, Length(ts));
  for i := 0 to High(ts) do PixIds[i] := ts[i].Id;
  PixCopy := ssCtrl in Shift;
  SelSet(MakeRef(s.Id, -1));
  Drag := dmPix;
  RefreshProps;
  Redraw;
end;

function TForm1.AllRasterShapes(const ts: TShapeArray): Boolean;
var
  i: Integer;
begin
  Result := Length(ts) > 0;
  for i := 0 to High(ts) do
    if (ts[i].Kind <> skImage) or (ts[i].SelTarget > 0) then Exit(False);
end;

function TForm1.RotImgFind(id: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to High(RotImgs) do
    if RotImgs[i].Id = id then Exit(i);
  Result := -1;
end;

// the pictures of the selection: with reset they are taken as the originals (the selection has just got its handles); without it a
// picture that was changed by something else since is taken as a new original. The state is kept for the drag that begins
procedure TForm1.RotSaveImages(reset: Boolean);
var
  i, k: Integer;
  sh: TShape;
  old: array of TRotImg;
  r: TRotImg;
  raw: TGraphic;
  tb: TBitmap;
begin
  RotFlushPending;
  old := RotImgs;
  SetLength(RotImgs, 0);
  for i := 0 to High(RotIds) do
  begin
    sh := Doc.FindShape(RotIds[i]);
    if (sh = nil) or (sh.Kind <> skImage) or (Length(sh.P) < 2) then Continue;
    k := -1;
    if not reset then
      for k := 0 to High(old) do
        if old[k].Id = sh.Id then Break;
    if reset or (k > High(old)) or (k < 0) or (old[k].Cur <> sh.ImageData) then
    begin
      raw := RawImage(sh);
      if raw = nil then Continue;
      FillChar(r, SizeOf(r), 0);
      r.Id := sh.Id;
      r.OrigData := sh.ImageData;
      r.OrigKey := sh.KeyOrig;
      r.OrigKeyOn := sh.KeyOn;
      r.Cur := sh.ImageData;
      r.Ow := raw.Width;
      r.Oh := raw.Height;
      tb := TBitmap.Create;
      try
        tb.Assign(raw);
        r.OrigImg := TBGRABitmap.Create(tb);
      finally
        tb.Free;
      end;
      r.Ux := Abs(sh.P[1].x - sh.P[0].x);
      r.Uy := Abs(sh.P[1].y - sh.P[0].y);
      r.M[0] := 1; r.M[1] := 0; r.M[2] := 0; r.M[3] := 1;
    end
    else r := old[k];
    r.SData := sh.ImageData;
    r.SKey := sh.KeyOrig;
    r.SKeyOn := sh.KeyOn;
    r.SP0 := sh.P[0];
    r.SP1 := sh.P[1];
    r.SUx := r.Ux;
    r.SUy := r.Uy;
    r.SM := r.M;
    SetLength(RotImgs, Length(RotImgs) + 1);
    RotImgs[High(RotImgs)] := r;
  end;
  // the originals of what is no longer in the selection are let go
  for k := 0 to High(old) do
  begin
    i := 0;
    while (i <= High(RotImgs)) and (RotImgs[i].OrigImg <> old[k].OrigImg) do Inc(i);
    if i > High(RotImgs) then
    begin
      old[k].OrigImg.Free;
      old[k].PendImg.Free;
    end;
  end;
end;

function RenderSkew(const r: TRotImg; const m: array of Double; scale: Double): TBGRABitmap; forward;

// a picture for the fast drawing of the shape s (the drawing looks for it before it makes one from the data of the shape)
procedure TForm1.PutFastImg(s: TShape; src: TBGRABitmap);
var
  i, e: Integer;
begin
  for i := High(FastImgs) downto 0 do
    if FastImgs[i].Shape = s then
    begin
      FastImgs[i].Src.Free;
      FastImgs[i].Scaled.Free;
      Delete(FastImgs, i, 1);
    end;
  if Length(FastImgs) >= 6 then
  begin
    FastImgs[0].Src.Free;
    FastImgs[0].Scaled.Free;
    Delete(FastImgs, 0, 1);
  end;
  SetLength(FastImgs, Length(FastImgs) + 1);
  e := High(FastImgs);
  FastImgs[e].Shape := s;
  FastImgs[e].Key := HoleKey(s);
  FastImgs[e].DataP := Pointer(s.ImageData);
  FastImgs[e].DataLen := Length(s.ImageData);
  FastImgs[e].Src := src;
  FastImgs[e].Scaled := nil;
  FastImgs[e].W := 0;
  FastImgs[e].H := 0;
end;

// what a skew has made is written in the pictures (the PNG is made once, when the drag ends, not at every move)
procedure TForm1.RotFlushPending;
var
  i: Integer;
  sh: TShape;
  ms: TMemoryStream;
  raw: string;
  full: TBGRABitmap;
begin
  for i := 0 to High(RotImgs) do
    if RotImgs[i].Pending then
    begin
      RotImgs[i].Pending := False;
      sh := Doc.FindShape(RotImgs[i].Id);
      if (sh <> nil) and (RotImgs[i].PendImg <> nil) then
      begin
        if RotImgs[i].Draft then
        begin
          // the picture with all its pixels, now that the drag is over
          full := RenderSkew(RotImgs[i], RotImgs[i].M, 1);
          if full <> nil then
          begin
            RotImgs[i].PendImg.Free;
            RotImgs[i].PendImg := full;
          end;
          RotImgs[i].Draft := False;
        end;
        ms := TMemoryStream.Create;
        try
          RotImgs[i].PendImg.SaveToStreamAsPng(ms);
          SetString(raw, PAnsiChar(ms.Memory), ms.Size);
        finally
          ms.Free;
        end;
        sh.ImageData := EncodeStringBase64(raw);
        DbgLog('final picture ' + IntToStr(RotImgs[i].PendImg.Width) + 'x' + IntToStr(RotImgs[i].PendImg.Height));
        sh.KeyOn := False;
        sh.KeyOrig := '';
        RotImgs[i].Cur := sh.ImageData;
        // the picture that is on the screen stays: it is the same one
        FlushImageCaches(sh);
        PutFastImg(sh, RotImgs[i].PendImg.Duplicate as TBGRABitmap);
      end;
      FreeAndNil(RotImgs[i].PendImg);
    end;
end;

// the pictures go back to what they were when the drag began
procedure TForm1.RotRestoreImages;
var
  i: Integer;
  sh: TShape;
begin
  for i := 0 to High(RotImgs) do
  begin
    sh := Doc.FindShape(RotImgs[i].Id);
    if sh = nil then Continue;
    sh.ImageData := RotImgs[i].SData;
    sh.KeyOrig := RotImgs[i].SKey;
    sh.KeyOn := RotImgs[i].SKeyOn;
    sh.P[0] := RotImgs[i].SP0;
    sh.P[1] := RotImgs[i].SP1;
    RotImgs[i].Cur := RotImgs[i].SData;
    RotImgs[i].Pending := False;
    RotImgs[i].Ux := RotImgs[i].SUx;
    RotImgs[i].Uy := RotImgs[i].SUy;
    RotImgs[i].M := RotImgs[i].SM;
    FlushImageCaches(sh);
  end;
end;

// the skew of a picture about (bx, by), added to the ones it has had: it is made from the original, so nothing is lost by
// skewing again (the picture must not be turned: the selection is in its upright frame when this is called)
// the original skewed by m (see TRotImg), as a picture whose pixels are those of the original times scale
function RenderSkew(const r: TRotImg; const m: array of Double; scale: Double): TBGRABitmap;
var
  nl: TBGRABitmap;
  bw, bh, det, qx, qy: Double;
  nw, nh, x, y, ix, iy, ix1, iy1, ow, oh, fx, fy, w00, w10, w01, w11, a00, a10, a01, a11, asum, sa: Integer;
  uF, vF, duF, dvF, umax, vmax, stride: Int64;
  base0: PBGRAPixel;
  p00, p10, p01, p11: PBGRAPixel;
  dst: PBGRAPixel;
begin
  Result := nil;
  det := m[0] * m[3] - m[1] * m[2];
  bw := Abs(m[0]) * r.Ux + Abs(m[1]) * r.Uy;
  bh := Abs(m[2]) * r.Ux + Abs(m[3]) * r.Uy;
  ow := r.OrigImg.Width;
  oh := r.OrigImg.Height;
  nw := Max(1, Ceil(bw * ow / r.Ux * scale));
  nh := Max(1, Ceil(bh * oh / r.Uy * scale));
  nl := TBGRABitmap.Create(nw, nh, BGRAPixelTransparent);
  try
    base0 := r.OrigImg.ScanLine[0];
    if oh > 1 then stride := (Int64(PtrUInt(r.OrigImg.ScanLine[1])) - Int64(PtrUInt(base0))) div SizeOf(TBGRAPixel)
    else stride := ow;
    umax := Int64(ow) * 65536 - 32768;
    vmax := Int64(oh) * 65536 - 32768;
    for y := 0 to nh - 1 do
    begin
      dst := nl.ScanLine[y];
      // along a row the position in the original changes by a constant step (16.16 fixed point)
      qx := -bw / 2 + 0.5 * bw / nw;
      qy := -bh / 2 + (y + 0.5) * bh / nh;
      uF := Round((((m[3] * qx - m[1] * qy) / det / r.Ux + 0.5) * ow - 0.5) * 65536);
      vF := Round((((-m[2] * qx + m[0] * qy) / det / r.Uy + 0.5) * oh - 0.5) * 65536);
      duF := Round((m[3] * (bw / nw) / det) / r.Ux * ow * 65536);
      dvF := Round((-m[2] * (bw / nw) / det) / r.Uy * oh * 65536);
      for x := 0 to nw - 1 do
      begin
        if (uF >= -32768) and (vF >= -32768) and (uF < umax) and (vF < vmax) then
        begin
          ix := ((uF + 65536) shr 16) - 1;
          iy := ((vF + 65536) shr 16) - 1;
          fx := ((uF + 65536) and $FFFF) shr 8;
          fy := ((vF + 65536) and $FFFF) shr 8;
          ix1 := ix + 1;
          if ix1 > ow - 1 then ix1 := ow - 1;
          iy1 := iy + 1;
          if iy1 > oh - 1 then iy1 := oh - 1;
          if ix < 0 then ix := 0;
          if iy < 0 then iy := 0;
          p00 := base0 + iy * stride + ix;
          p10 := base0 + iy * stride + ix1;
          p01 := base0 + iy1 * stride + ix;
          p11 := base0 + iy1 * stride + ix1;
          w00 := (256 - fx) * (256 - fy);
          w10 := fx * (256 - fy);
          w01 := (256 - fx) * fy;
          w11 := fx * fy;
          if (p00^.alpha and p10^.alpha and p01^.alpha and p11^.alpha) = 255 then
          begin
            // all opaque: the weights add up to 65536
            dst^.blue := (p00^.blue * w00 + p10^.blue * w10 + p01^.blue * w01 + p11^.blue * w11 + 32768) shr 16;
            dst^.green := (p00^.green * w00 + p10^.green * w10 + p01^.green * w01 + p11^.green * w11 + 32768) shr 16;
            dst^.red := (p00^.red * w00 + p10^.red * w10 + p01^.red * w01 + p11^.red * w11 + 32768) shr 16;
            dst^.alpha := 255;
          end
          else
          begin
            // weights by the opacity of each pixel (the colours are not premultiplied)
            a00 := w00 * p00^.alpha;
            a10 := w10 * p10^.alpha;
            a01 := w01 * p01^.alpha;
            a11 := w11 * p11^.alpha;
            asum := a00 + a10 + a01 + a11;
            if asum <> 0 then
            begin
              dst^.blue := (p00^.blue * a00 + p10^.blue * a10 + p01^.blue * a01 + p11^.blue * a11 + asum div 2) div asum;
              dst^.green := (p00^.green * a00 + p10^.green * a10 + p01^.green * a01 + p11^.green * a11 + asum div 2) div asum;
              dst^.red := (p00^.red * a00 + p10^.red * a10 + p01^.red * a01 + p11^.red * a11 + asum div 2) div asum;
              sa := (asum + 32768) div 65536;
              if sa > 255 then sa := 255;
              dst^.alpha := sa;
            end;
          end;
        end;
        Inc(dst);
        uF := uF + duF;
        vF := vF + dvF;
      end;
    end;
    nl.InvalidateBitmap;
    Result := nl;
    nl := nil;
  finally
    nl.Free;
  end;
end;

procedure TForm1.SkewImage(var r: TRotImg; s: TShape; bx, by, kx, ky: Double);
var
  nl: TBGRABitmap;
  m: array[0..3] of Double;
  cx, cy, ncx, ncy, bw, bh, det, scale: Double;
  nw, nh, ow, oh: Integer;
  tA: QWord;
  ident: Boolean;
begin
  if (s.Kind <> skImage) or (Length(s.P) < 2) or (r.OrigImg = nil) then Exit;
  // the total skew: the new one comes after the ones of before
  m[0] := r.SM[0] + kx * r.SM[2];
  m[1] := r.SM[1] + kx * r.SM[3];
  m[2] := ky * r.SM[0] + r.SM[2];
  m[3] := ky * r.SM[1] + r.SM[3];
  det := m[0] * m[3] - m[1] * m[2];
  if Abs(det) < 1e-3 then Exit;
  cx := (s.P[0].x + s.P[1].x) / 2;
  cy := (s.P[0].y + s.P[1].y) / 2;
  // the centre of the picture goes where the skew takes it (the parallelogram is symmetrical about it)
  ncx := bx + (cx - bx) + kx * (cy - by);
  ncy := by + (cy - by) + ky * (cx - bx);
  ident := (Abs(m[0] - 1) < 1e-6) and (Abs(m[1]) < 1e-6) and (Abs(m[2]) < 1e-6) and (Abs(m[3] - 1) < 1e-6);
  if ident then
  begin
    // no skew left: the picture is the original again, with nothing added to its size
    bw := r.Ux;
    bh := r.Uy;
    s.ImageData := r.OrigData;
    s.KeyOrig := r.OrigKey;
    s.KeyOn := r.OrigKeyOn;
    s.P[0] := MakePt(ncx - bw / 2, ncy - bh / 2);
    s.P[1] := MakePt(ncx + bw / 2, ncy + bh / 2);
    r.M[0] := 1; r.M[1] := 0; r.M[2] := 0; r.M[3] := 1;
    r.Cur := s.ImageData;
    r.Pending := False;
    FreeAndNil(r.PendImg);
    FlushImageCaches(s);
    Exit;
  end;
  bw := Abs(m[0]) * r.Ux + Abs(m[1]) * r.Uy;
  bh := Abs(m[2]) * r.Ux + Abs(m[3]) * r.Uy;
  ow := r.OrigImg.Width;
  oh := r.OrigImg.Height;
  nw := Max(1, Ceil(bw * ow / r.Ux));
  nh := Max(1, Ceil(bh * oh / r.Uy));
  if (nw > 12000) or (nh > 12000) or (Int64(nw) * nh > 80000000) then
  begin
    SetStatus('Skew: the raster would become too large.');
    Exit;
  end;
  // while the pointer moves the picture is made with no more pixels than the screen can show (and at most 1.5 million); the full
  // one is made when the drag ends
  scale := Min(1, Max(Zoom * 1.5, 0.2));
  if Int64(nw) * nh * scale * scale > 1500000 then scale := Sqrt(1500000 / (Int64(nw) * nh));
  tA := GetTickCount64;
  nl := RenderSkew(r, m, scale);
  if nl = nil then Exit;
  try
    FlushImageCaches(s);
    s.P[0] := MakePt(ncx - bw / 2, ncy - bh / 2);
    s.P[1] := MakePt(ncx + bw / 2, ncy + bh / 2);
    r.M := m;
    PutFastImg(s, nl.Duplicate as TBGRABitmap);
    r.PendImg.Free;
    r.PendImg := nl;
    nl := nil;
    r.Pending := True;
    r.Draft := scale < 0.999;
    DbgLog('skew ' + IntToStr(nw) + 'x' + IntToStr(nh) + ' scale=' + FloatToStr(Round(scale * 100) / 100) + ' ms=' + IntToStr(GetTickCount64 - tA));
  finally
    nl.Free;
  end;
end;

// Enter on a raster lying over other rasters: it is printed on the one it overlaps; with more than one the user chooses
procedure TForm1.MergeOverRaster(fl: TShape);
type
  TQuad = array[0..3] of TPt;
var
  cands: TShapeArray;
  o, base: TShape;
  qf, qo: TQuad;
  i, k, n, pick: Integer;
  dlg: TForm;
  lb: TListBox;
  bo, bc: TButton;

  procedure GetQuad(sh: TShape; out q: TQuad);
  var
    x1, y1, x2, y2: Double;
    c: TPt;
  begin
    ImageBox(sh, x1, y1, x2, y2);
    c := ShapePivot(sh);
    q[0] := TurnPt(MakePt(x1, y1), c, sh.Rot);
    q[1] := TurnPt(MakePt(x2, y1), c, sh.Rot);
    q[2] := TurnPt(MakePt(x2, y2), c, sh.Rot);
    q[3] := TurnPt(MakePt(x1, y2), c, sh.Rot);
  end;

  // separating axis test: True when the two rectangles share some area
  function Overlap(const a, b: TQuad): Boolean;
  var
    pass, j, m: Integer;
    ax, ay, l, amin, amax, bmin, bmax, d: Double;
    q: ^TQuad;
  begin
    Result := True;
    for pass := 0 to 1 do
    begin
      if pass = 0 then q := @a else q := @b;
      for j := 0 to 1 do
      begin
        ax := q^[j + 1].y - q^[j].y;
        ay := q^[j].x - q^[j + 1].x;
        l := Sqrt(ax * ax + ay * ay);
        if l < 1e-12 then Continue;
        ax := ax / l; ay := ay / l;
        amin := 1e300; amax := -1e300; bmin := 1e300; bmax := -1e300;
        for m := 0 to 3 do
        begin
          d := a[m].x * ax + a[m].y * ay;
          if d < amin then amin := d;
          if d > amax then amax := d;
          d := b[m].x * ax + b[m].y * ay;
          if d < bmin then bmin := d;
          if d > bmax then bmax := d;
        end;
        if (amax <= bmin + 1e-9) or (bmax <= amin + 1e-9) then Exit(False);
      end;
    end;
  end;

begin
  if (fl = nil) or (fl.Kind <> skImage) or (fl.SelTarget > 0) then Exit;
  GetQuad(fl, qf);
  n := 0;
  SetLength(cands, 0);
  for i := Doc.Shapes.Count - 1 downto 0 do
  begin
    o := Doc.Shapes[i];
    if (o = fl) or (o.Kind <> skImage) or (o.SelTarget > 0) or not Doc.ShapeVisible(o) then Continue;
    GetQuad(o, qo);
    if not Overlap(qf, qo) then Continue;
    SetLength(cands, n + 1);
    cands[n] := o;
    Inc(n);
  end;
  if n = 0 then
  begin
    SetStatus('Enter: this raster does not overlap any other raster.');
    Exit;
  end;
  base := cands[0];
  if n > 1 then
  begin
    dlg := TForm.CreateNew(Self);
    try
      dlg.Caption := 'Merge the raster into...';
      dlg.Position := poMainFormCenter;
      dlg.BorderStyle := bsDialog;
      dlg.ClientWidth := 380;
      dlg.ClientHeight := 260;
      lb := TListBox.Create(dlg);
      lb.Parent := dlg;
      lb.SetBounds(10, 10, 360, 200);
      for k := 0 to n - 1 do
        lb.Items.Add('Raster #' + IntToStr(cands[k].Id) + '  (' + IntToStr(k + 1) + ' from the top)');
      lb.ItemIndex := 0;
      bo := TButton.Create(dlg);
      bo.Parent := dlg;
      bo.Caption := 'Merge';
      bo.SetBounds(200, 220, 80, 28);
      bo.ModalResult := mrOk;
      bo.Default := True;
      bc := TButton.Create(dlg);
      bc.Parent := dlg;
      bc.Caption := 'Cancel';
      bc.SetBounds(290, 220, 80, 28);
      bc.ModalResult := mrCancel;
      bc.Cancel := True;
      // the chosen raster is flagged in the selection so that the user sees which one it is
      lb.OnSelectionChange := nil;
      if dlg.ShowModal <> mrOk then Exit;
      pick := lb.ItemIndex;
    finally
      dlg.Free;
    end;
    if (pick < 0) or (pick >= n) then Exit;
    base := cands[pick];
  end;
  PixPrint(fl, base);
end;

// Enter: the pixels that were lifted are printed on the raster they came from (or the one under them); where they go
// beyond its borders the raster grows to hold them
procedure TForm1.PixCommit;
var
  fl, base, o: TShape;
  cf, q: TPt;
  bx1, by1, bx2, by2: Double;
  i: Integer;
begin
  fl := Doc.FindShape(FloatId);
  if (fl = nil) or (fl.Kind <> skImage) then Exit;
  base := Doc.FindShape(FloatBase);
  if (base = nil) or (base.Kind <> skImage) or (base = fl) then
  begin
    // the raster it came from is gone: the first one that lies under its centre
    base := nil;
    cf := ShapePivot(fl);
    for i := Doc.Shapes.Count - 1 downto 0 do
    begin
      o := Doc.Shapes[i];
      if (o.Kind <> skImage) or (o = fl) or not Doc.ShapeVisible(o) then Continue;
      ImageBox(o, bx1, by1, bx2, by2);
      q := TurnPt(cf, ShapePivot(o), -o.Rot);
      if (q.x >= bx1) and (q.x <= bx2) and (q.y >= by1) and (q.y <= by2) then
      begin
        base := o;
        Break;
      end;
    end;
  end;
  if base = nil then
  begin
    SetStatus('Enter: there is no raster under the pixels to print them on.');
    Exit;
  end;
  PixPrint(fl, base);
end;

// prints the picture fl over the raster base (growing it when needed) and deletes fl
procedure TForm1.PixPrint(fl, base: TShape);
var
  bli, fli, nl: TLazIntfImage;
  desc: TRawImageDescription;
  braw, fraw: TGraphic;
  cc, c0, cf, d, b, q: TPt;
  corners: array[0..3] of TPt;
  bx1, by1, bx2, by2, fx1, fy1, fx2, fy2, ux1, uy1, ux2, uy2, fx, fy, dfx, dfy, u, v, sx, sy, wx, wy: Double;
  bw, bh, nw, nh, padL, padT, padR, padB, x, y, i, k, dx1, dy1, dx2, dy2, ix, iy, ix1, iy1: Integer;
  nx1, ny1, nx2, ny2: Double;
  same: Boolean;
  col, p00, p10, p01, res: TFPColor;
  sa, da, oa: Double;

  function Mix(a, b2: TFPColor; t: Double): TFPColor;
  var
    wa, wb, ta: Double;
  begin
    // two colours weighted by their opacity
    wa := (1 - t) * a.alpha;
    wb := t * b2.alpha;
    ta := wa + wb;
    if ta < 1e-9 then Exit(FPColor(0, 0, 0, 0));
    Result.red := Round((a.red * wa + b2.red * wb) / ta);
    Result.green := Round((a.green * wa + b2.green * wb) / ta);
    Result.blue := Round((a.blue * wa + b2.blue * wb) / ta);
    Result.alpha := Round(ta);
  end;

begin
  braw := RawImage(base);
  fraw := RawImage(fl);
  if (braw = nil) or (fraw = nil) then Exit;
  bli := RgbaOf(braw);
  fli := RgbaOf(fraw);
  nl := nil;
  try
    bw := bli.Width;
    bh := bli.Height;
    ImageBox(base, bx1, by1, bx2, by2);
    ImageBox(fl, fx1, fy1, fx2, fy2);
    if (bx2 - bx1 < 1e-6) or (by2 - by1 < 1e-6) or (fx2 - fx1 < 1e-6) or (fy2 - fy1 < 1e-6) then Exit;
    fx := bw / (bx2 - bx1);
    fy := bh / (by2 - by1);
    c0 := ShapePivot(base);
    cf := ShapePivot(fl);
    // the corners of the lifted picture, in the frame of the (unturned) raster
    corners[0] := MakePt(fx1, fy1);
    corners[1] := MakePt(fx2, fy1);
    corners[2] := MakePt(fx2, fy2);
    corners[3] := MakePt(fx1, fy2);
    ux1 := bx1; uy1 := by1; ux2 := bx2; uy2 := by2;
    for k := 0 to 3 do
    begin
      d := TurnPt(corners[k], cf, fl.Rot);
      q := TurnPt(d, c0, -base.Rot);
      ux1 := Min(ux1, q.x); uy1 := Min(uy1, q.y);
      ux2 := Max(ux2, q.x); uy2 := Max(uy2, q.y);
    end;
    // whole pixels more on each side, so that the pixels of the raster do not move
    padL := Max(0, Ceil((bx1 - ux1) * fx - 1e-6));
    padT := Max(0, Ceil((by1 - uy1) * fy - 1e-6));
    padR := Max(0, Ceil((ux2 - bx2) * fx - 1e-6));
    padB := Max(0, Ceil((uy2 - by2) * fy - 1e-6));
    nw := bw + padL + padR;
    nh := bh + padT + padB;
    if (nw > 12000) or (nh > 12000) or (Int64(nw) * nh > 80000000) then
    begin
      SetStatus('Enter: the raster would become too large (more than 12000 pixels on a side).');
      Exit;
    end;
    nx1 := bx1 - padL / fx;
    ny1 := by1 - padT / fy;
    nx2 := bx2 + padR / fx;
    ny2 := by2 + padB / fy;
    nl := TLazIntfImage.Create(0, 0);
    desc.Init_BPP32_B8G8R8A8_BIO_TTB(nw, nh);
    nl.DataDescription := desc;
    nl.SetSize(nw, nh);
    col := FPColor(0, 0, 0, 0);
    for y := 0 to nh - 1 do
      for x := 0 to nw - 1 do nl.Colors[x, y] := col;
    for y := 0 to bh - 1 do
      for x := 0 to bw - 1 do nl.Colors[x + padL, y + padT] := bli.Colors[x, y];
    // the lifted pixels over them
    dfx := fli.Width / (fx2 - fx1);
    dfy := fli.Height / (fy2 - fy1);
    same := (Abs(NormAngle(fl.Rot - base.Rot)) < 1e-9) and (Abs(dfx - fx) < 1e-6 * fx) and (Abs(dfy - fy) < 1e-6 * fy);
    dx1 := nw; dy1 := nh; dx2 := -1; dy2 := -1;
    for k := 0 to 3 do
    begin
      d := TurnPt(corners[k], cf, fl.Rot);
      q := TurnPt(d, c0, -base.Rot);
      dx1 := Min(dx1, Floor((q.x - nx1) * fx));
      dy1 := Min(dy1, Floor((q.y - ny1) * fy));
      dx2 := Max(dx2, Ceil((q.x - nx1) * fx));
      dy2 := Max(dy2, Ceil((q.y - ny1) * fy));
    end;
    dx1 := Max(0, dx1); dy1 := Max(0, dy1); dx2 := Min(nw - 1, dx2); dy2 := Min(nh - 1, dy2);
    for y := dy1 to dy2 do
      for x := dx1 to dx2 do
      begin
        b := MakePt(nx1 + (x + 0.5) / fx, ny1 + (y + 0.5) / fy);
        d := TurnPt(b, c0, base.Rot);
        q := TurnPt(d, cf, -fl.Rot);
        u := (q.x - fx1) * dfx;
        v := (q.y - fy1) * dfy;
        if (u < 0) or (v < 0) or (u >= fli.Width) or (v >= fli.Height) then Continue;
        if same then
        begin
          ix := Min(fli.Width - 1, Floor(u));
          iy := Min(fli.Height - 1, Floor(v));
          p00 := fli.Colors[ix, iy];
        end
        else
        begin
          sx := u - 0.5;
          sy := v - 0.5;
          ix := Floor(sx);
          iy := Floor(sy);
          wx := sx - ix;
          wy := sy - iy;
          ix1 := Min(Max(ix + 1, 0), fli.Width - 1);
          iy1 := Min(Max(iy + 1, 0), fli.Height - 1);
          ix := Min(Max(ix, 0), fli.Width - 1);
          iy := Min(Max(iy, 0), fli.Height - 1);
          p00 := Mix(fli.Colors[ix, iy], fli.Colors[ix1, iy], wx);
          p01 := Mix(fli.Colors[ix, iy1], fli.Colors[ix1, iy1], wx);
          p00 := Mix(p00, p01, wy);
        end;
        if p00.alpha = 0 then Continue;
        p10 := nl.Colors[x, y];
        sa := p00.alpha / 65535;
        da := p10.alpha / 65535;
        oa := sa + da * (1 - sa);
        if oa < 1e-9 then Continue;
        res.red := Round((p00.red * sa + p10.red * da * (1 - sa)) / oa);
        res.green := Round((p00.green * sa + p10.green * da * (1 - sa)) / oa);
        res.blue := Round((p00.blue * sa + p10.blue * da * (1 - sa)) / oa);
        res.alpha := Round(oa * 65535);
        nl.Colors[x, y] := res;
      end;
    Checkpoint;
    base.ImageData := PngBase64(nl);
    base.KeyOn := False;
    base.KeyOrig := '';
    // the new box, with its centre where the turned raster has it
    cc := TurnPt(MakePt((nx1 + nx2) / 2, (ny1 + ny2) / 2), c0, base.Rot);
    base.P[0] := MakePt(cc.x - (nx2 - nx1) / 2, cc.y - (ny2 - ny1) / 2);
    base.P[1] := MakePt(cc.x + (nx2 - nx1) / 2, cc.y + (ny2 - ny1) / 2);
    FlushImageCaches(base);
    Doc.DeleteShape(fl);
    RefreshTree;
    RotMode := False;       // the handles of the raster that has been printed are gone with it
    FloatId := 0;
    FloatBase := 0;
    Commit;
    SelSet(MakeRef(base.Id, -1));
    if (padL + padT + padR + padB) > 0 then SetStatus('The pixels are printed on the raster, which has grown to hold them.')
    else SetStatus('The pixels are printed on the raster.');
  finally
    bli.Free;
    fli.Free;
    nl.Free;
  end;
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// Shift adds a selection to the ones there are, Shift+Ctrl subtracts it from them; without Shift it replaces them
function TForm1.SelModeOf(Shift: TShiftState): Integer;
begin
  if not (ssShift in Shift) then Result := 0
  else if ssCtrl in Shift then Result := 2
  else Result := 1;
end;

// all the selections of a raster: together they are the area that is selected
// what the geometry of a selection is like (it changes when the selection is made again, not when it follows a picture)
function TForm1.SelSigOf(s: TShape): QWord;
var
  i: Integer;
  v: array of Double;
begin
  v := nil;
  SetLength(v, Length(s.P) * 2 + 1);
  for i := 0 to High(s.P) do
  begin
    v[2 * i] := s.P[i].x;
    v[2 * i + 1] := s.P[i].y;
  end;
  v[High(v)] := s.Rot;
  Result := HashBytes(@v[0], Length(v) * SizeOf(Double), 14695981039346656037);
  if s.PathData <> '' then Result := HashBytes(@s.PathData[1], Length(s.PathData), Result);
end;

// the selections of a picture that moved, was resized or turned go with it: what was the box and the turn of the picture is
// mapped onto what they are now (the picture turned back, stretched, moved and turned again)
procedure TForm1.SelFollowImage(img: TShape; const ids: array of Integer; ox1, oy1, ox2, oy2, orot: Double);
var
  nx1, ny1, nx2, ny2, sx, sy, dx, dy: Double;
  co, cn: TPt;
  i, sk, dr, cv: Integer;
  sh: TShape;
begin
  ImageBox(img, nx1, ny1, nx2, ny2);
  co := MakePt((ox1 + ox2) / 2, (oy1 + oy2) / 2);
  cn := MakePt((nx1 + nx2) / 2, (ny1 + ny2) / 2);
  if (Abs(orot - img.Rot) < 1e-9) and (Abs((ox2 - ox1) - (nx2 - nx1)) < 1e-9) and (Abs((oy2 - oy1) - (ny2 - ny1)) < 1e-9) then
  begin
    // only moved
    dx := cn.x - co.x;
    dy := cn.y - co.y;
    for i := 0 to High(ids) do
    begin
      sh := Doc.FindShape(ids[i]);
      if sh <> nil then sh.Translate(dx, dy);
    end;
    Exit;
  end;
  if Abs(orot) > 1e-12 then Doc.RotateShapes(ids, co.x, co.y, -orot, sk, dr, cv);
  if (ox2 - ox1 > 1e-9) and (oy2 - oy1 > 1e-9) then
  begin
    sx := (nx2 - nx1) / (ox2 - ox1);
    sy := (ny2 - ny1) / (oy2 - oy1);
    if (Abs(sx - 1) > 1e-9) or (Abs(sy - 1) > 1e-9) then Doc.StretchShapes(ids, ox1, oy1, sx, sy);
  end;
  dx := nx1 - ox1;
  dy := ny1 - oy1;
  for i := 0 to High(ids) do
  begin
    sh := Doc.FindShape(ids[i]);
    if sh <> nil then sh.Translate(dx, dy);
  end;
  if Abs(img.Rot) > 1e-12 then Doc.RotateShapes(ids, cn.x, cn.y, img.Rot, sk, dr, cv);
end;

// a picture whose box or turn is not what it was is followed by its selections, except for those that have been made again
// since (an operation that took care of them): those are left as they are
procedure TForm1.SyncSelFollow;
var
  i, j, k, fi: Integer;
  img, sh: TShape;
  sels: TShapeArray;
  follow: array of Integer;
  x1, y1, x2, y2: Double;
  seen: Boolean;
  sig: QWord;
begin
  if (Doc = nil) or (Doc.Shapes.Count = 0) then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    img := Doc.Shapes[i];
    if (img.Kind <> skImage) or (img.SelTarget > 0) then Continue;
    sels := SelListOf(img);
    if Length(sels) = 0 then Continue;
    ImageBox(img, x1, y1, x2, y2);
    fi := -1;
    for j := 0 to High(FrameMem) do
      if FrameMem[j].ImgId = img.Id then fi := j;
    if fi < 0 then
    begin
      fi := Length(FrameMem);
      SetLength(FrameMem, fi + 1);
      FrameMem[fi].ImgId := img.Id;
      FrameMem[fi].X1 := x1;
      FrameMem[fi].Y1 := y1;
      FrameMem[fi].X2 := x2;
      FrameMem[fi].Y2 := y2;
      FrameMem[fi].Rot := img.Rot;
    end
    else if (Abs(FrameMem[fi].X1 - x1) > 1e-9) or (Abs(FrameMem[fi].Y1 - y1) > 1e-9) or (Abs(FrameMem[fi].X2 - x2) > 1e-9) or
            (Abs(FrameMem[fi].Y2 - y2) > 1e-9) or (Abs(FrameMem[fi].Rot - img.Rot) > 1e-12) then
    begin
      SetLength(follow, 0);
      for j := 0 to High(sels) do
      begin
        sig := SelSigOf(sels[j]);
        seen := False;
        for k := 0 to High(SelSigMem) do
          if (SelSigMem[k].Id = sels[j].Id) and (SelSigMem[k].Sig = sig) then seen := True;
        if seen then
        begin
          SetLength(follow, Length(follow) + 1);
          follow[High(follow)] := sels[j].Id;
        end;
      end;
      if Length(follow) > 0 then SelFollowImage(img, follow, FrameMem[fi].X1, FrameMem[fi].Y1, FrameMem[fi].X2, FrameMem[fi].Y2, FrameMem[fi].Rot);
      FrameMem[fi].X1 := x1;
      FrameMem[fi].Y1 := y1;
      FrameMem[fi].X2 := x2;
      FrameMem[fi].Y2 := y2;
      FrameMem[fi].Rot := img.Rot;
    end;
    // what the selections are like now (after following)
    for j := 0 to High(sels) do
    begin
      sh := Doc.FindShape(sels[j].Id);
      if sh = nil then Continue;
      sig := SelSigOf(sh);
      k := -1;
      for fi := 0 to High(SelSigMem) do
        if SelSigMem[fi].Id = sh.Id then k := fi;
      if k < 0 then
      begin
        k := Length(SelSigMem);
        SetLength(SelSigMem, k + 1);
        SelSigMem[k].Id := sh.Id;
      end;
      SelSigMem[k].Sig := sig;
    end;
  end;
end;

// the order the selections of a picture are applied in: as they were made, except the one that covers the whole picture, which
// comes first
function SelKey(s: TShape): Integer;
begin
  if s.SelBase then Result := 0 else Result := s.Id;
end;

function TForm1.SelListOf(img: TShape): TShapeArray;
var
  i: Integer;
begin
  SetLength(Result, 0);
  if img = nil then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.Shapes[i].SelTarget = img.Id then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Doc.Shapes[i];
    end;
end;

// the selection that covers the point (not where a later subtraction took it away)
function TForm1.SelInsideAt(px, py: Double): TShape;
var
  i, j: Integer;
  sh: TShape;
  gone: Boolean;
begin
  Result := nil;
  for i := Doc.Shapes.Count - 1 downto 0 do
  begin
    sh := Doc.Shapes[i];
    if (sh.SelTarget <= 0) or sh.SelSub or not Doc.ShapeVisible(sh) then Continue;
    if not InsideOutline(ShapeOutline(sh), px, py) then Continue;
    gone := False;
    for j := 0 to Doc.Shapes.Count - 1 do
      if (Doc.Shapes[j].SelTarget = sh.SelTarget) and Doc.Shapes[j].SelSub and (SelKey(Doc.Shapes[j]) > SelKey(sh)) and
         InsideOutline(ShapeOutline(Doc.Shapes[j]), px, py) then gone := True;
    if not gone then Exit(sh);
  end;
end;

// the selection s that has just been made on the picture img joins the area that is selected, or replaces it
procedure TForm1.SelRegister(s, img: TShape);
var
  i: Integer;
begin
  if SelMode = 0 then
  begin
    for i := Doc.Shapes.Count - 1 downto 0 do
      if (Doc.Shapes[i].SelTarget = img.Id) and (Doc.Shapes[i] <> s) then Doc.DeleteShape(Doc.Shapes[i]);
  end;
  s.SelSub := SelMode = 2;
  if s.SelSub then s.Style.Stroke := TColor($0000D0);
  if s.SelSub then SelCollapse(s, img);
  if SelMode = 1 then SelMergeInto(s, img);
end;

// the outline of a selection of pixels shows its points, which can be dragged to change the area
procedure TForm1.SelEditBorders(s: TShape);
var
  o: TOutline;
  loops: TPtLoops;
  i, j: Integer;
begin
  if (s = nil) or (s.SelTarget <= 0) then Exit;
  Checkpoint;
  if s.Kind <> skPath then
  begin
    o := ShapeOutline(s);
    SetLength(loops, 0);
    for i := 0 to High(o) do
      if Length(o[i].Pts) > 2 then
      begin
        SetLength(loops, Length(loops) + 1);
        SetLength(loops[High(loops)], Length(o[i].Pts));
        for j := 0 to High(o[i].Pts) do loops[High(loops)][j] := o[i].Pts[j];
      end;
    if Length(loops) = 0 then Exit;
    SetPathFromLoops(s, loops);
  end;
  s.SelWand := False;
  Commit;
  SetTool(tlSelect);
  SelSet(MakeRef(s.Id, -1));
  SelEditId := s.Id;
  RotMode := False;
  PointEdit := True;
  PointEditSig := SelIdSig;
  SetStatus('Selection borders: drag the points to change the area. Click outside to finish.');
  RefreshProps;
  Redraw;
end;

// Shift+Ctrl: the area that is left after the subtraction becomes one outline (the selection s takes its shape, the others go)
procedure TForm1.SelCollapse(s, img: TShape);
var
  list: TShapeArray;
  raw: TGraphic;
  li: TLazIntfImage;
  mask: TBytes;
  loops: TPtLoops;
  w, h, i: Integer;
  hole, any: Boolean;
begin
  raw := RawImage(img);
  if raw = nil then Exit;
  list := SelListOf(img);
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    mask := SelMask(img, list, w, h);
  finally
    li.Free;
  end;
  any := False;
  for i := 0 to High(mask) do
    if mask[i] <> 0 then begin any := True; Break; end;
  if not any then Exit;       // everything is taken away: the outlines stay as they are
  if not MaskLoops(mask, w, h, img, loops) then Exit;
  hole := False;
  for i := 0 to High(list) do
    if (list[i] <> s) and not list[i].SelSub then begin hole := list[i].SelHole; Break; end;
  for i := High(list) downto 0 do
    if list[i] <> s then Doc.DeleteShape(list[i]);
  SetPathFromLoops(s, loops);
  s.SelSub := False;
  s.SelWand := False;
  s.SelHole := hole;
  s.Style := DefaultStyle;
  s.Style.Fill := NoColor;
  s.IsRef := True;
  FlushImageCaches(img);
  FlushAllImageCaches;
end;

// Shift: the new selection and the ones it overlaps become one outline (their union)
procedure TForm1.SelMergeInto(s, img: TShape);
var
  list: TShapeArray;
  i: Integer;
  again: Boolean;
  pd, err: string;
  o: TShape;
begin
  list := SelListOf(img);
  for i := 0 to High(list) do
    if list[i].SelSub then Exit;   // with subtractions the order matters: leave them as they are
  if not BoolEligible(s) then Exit;
  repeat
    again := False;
    list := SelListOf(img);
    for i := 0 to High(list) do
    begin
      o := list[i];
      if (o = s) or not BoolEligible(o) or not BoolOverlap(o, s) then Continue;
      if not BoolCompute(o, s, 1, pd, err) then Continue;
      s.Kind := skPath;
      SetLength(s.P, 1);
      s.P[0] := MakePt(0, 0);
      s.PathData := pd;
      s.Rot := 0;
      s.Corner := 0;
      s.SplineClosed := False;
      SetLength(s.RingStarts, 0);
      s.SelWand := False;
      s.ParsePath;
      Doc.DeleteShape(o);
      again := True;
      Break;
    end;
  until not again;
end;

procedure TForm1.SelHoleChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].SelTarget > 0 then ts[i].SelHole := chkSelHole.Checked;
  Commit;
  Redraw;
end;

procedure TForm1.SelTolChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  any: Boolean;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  any := False;
  for i := 0 to High(ts) do
    if ts[i].SelTarget > 0 then
    begin
      ts[i].SelTol := seSelTol.Value;
      any := True;
    end;
  if not any then
  begin
    DefWandTol := seSelTol.Value;
    QuickBusy := True;
    QuickTol.Value := DefWandTol;
    QuickBusy := False;
  end;
  SelTimer.Enabled := False;
  SelTimer.Enabled := any;
end;

procedure TForm1.SelApply(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  SelTimer.Enabled := False;
  ts := TargetShapes;
  Checkpoint;
  for i := 0 to High(ts) do
    if (ts[i].SelTarget > 0) and ts[i].SelWand then RegenWand(ts[i]);
  Commit;
  RefreshProps;
  Redraw;
end;


procedure TForm1.VectorizeAt(px, py: Double);
var
  i, x, y, iw, ih: Integer;
  img: TShape;
  g: TGraphic;
  bmp: TBitmap;
  li: TLazIntfImage;
  c16: TFPColor;
  pix: array of LongWord;
  x0, y0, x1, y1, fx, fy, ux, uy, vx, vy, thDeg, avg, tmp: Double;
  r: TVecResult;
  s: TShape;
  what: string;

  function ToDoc(const lx, ly: Double): TPt;
  begin
    // lx, ly: offsets from the figure centre in picture pixels
    Result := MakePt(x0 + (r.CX + lx) * fx, y0 + (r.CY + ly) * fy);
  end;

begin
  img := nil;
  for i := Doc.Shapes.Count - 1 downto 0 do
    if (Doc.Shapes[i].Kind = skImage) and Interactive(Doc.Shapes[i]) and
       (px >= Min(Doc.Shapes[i].P[0].x, Doc.Shapes[i].P[1].x)) and (px <= Max(Doc.Shapes[i].P[0].x, Doc.Shapes[i].P[1].x)) and
       (py >= Min(Doc.Shapes[i].P[0].y, Doc.Shapes[i].P[1].y)) and (py <= Max(Doc.Shapes[i].P[0].y, Doc.Shapes[i].P[1].y)) then
    begin
      img := Doc.Shapes[i];
      Break;
    end;
  if img = nil then
  begin
    SetStatus('Vectorize: click inside a raster picture.');
    Exit;
  end;
  g := RawImage(img);
  if g = nil then
  begin
    SetStatus('Vectorize: the picture cannot be read.');
    Exit;
  end;
  x0 := Min(img.P[0].x, img.P[1].x);
  y0 := Min(img.P[0].y, img.P[1].y);
  x1 := Max(img.P[0].x, img.P[1].x);
  y1 := Max(img.P[0].y, img.P[1].y);
  iw := g.Width;
  ih := g.Height;
  if (iw < 2) or (ih < 2) or (x1 - x0 < 1e-6) or (y1 - y0 < 1e-6) then Exit;
  fx := (x1 - x0) / iw;
  fy := (y1 - y0) / ih;
  bmp := TBitmap.Create;
  try
    bmp.Assign(g);
    li := bmp.CreateIntfImage;
    try
      SetLength(pix, iw * ih);
      for y := 0 to ih - 1 do
        for x := 0 to iw - 1 do
        begin
          c16 := li.Colors[x, y];
          pix[y * iw + x] := (LongWord(c16.alpha shr 8) shl 24) or (LongWord(c16.red shr 8) shl 16) or
            (LongWord(c16.green shr 8) shl 8) or LongWord(c16.blue shr 8);
        end;
    finally
      li.Free;
    end;
  finally
    bmp.Free;
  end;
  r := Vectorize(iw, ih, pix, Trunc((px - x0) / fx), Trunc((py - y0) / fy), 48);
  if r.Kind = vkNone then
  begin
    SetStatus('Vectorize: ' + r.Msg);
    Exit;
  end;
  avg := (fx + fy) / 2;
  ux := Cos(r.Theta);
  uy := Sin(r.Theta);
  vx := -uy;
  vy := ux;
  thDeg := r.Theta * 180 / Pi;
  s := nil;
  what := '';
  case r.Kind of
    vkRect:
      begin
        // horizontal / vertical sides: a true rectangle, otherwise a polygon
        if Abs(thDeg - Round(thDeg / 90) * 90) < 0.7 then
        begin
          s := NewShape(skRect);
          if (thDeg > 45) and (thDeg < 135) then
          begin
            tmp := r.A;
            r.A := r.B;
            r.B := tmp;
          end;
          SetLength(s.P, 2);
          s.P[0] := ToDoc(-r.A, -r.B);
          s.P[1] := ToDoc(r.A, r.B);
        end
        else
        begin
          s := NewShape(skPolygon);
          SetLength(s.P, 4);
          s.P[0] := ToDoc(-r.A * ux - r.B * vx, -r.A * uy - r.B * vy);
          s.P[1] := ToDoc(r.A * ux - r.B * vx, r.A * uy - r.B * vy);
          s.P[2] := ToDoc(r.A * ux + r.B * vx, r.A * uy + r.B * vy);
          s.P[3] := ToDoc(-r.A * ux + r.B * vx, -r.A * uy + r.B * vy);
        end;
        what := 'rectangle';
      end;
    vkEllipse:
      begin
        if (Abs(r.A - r.B) > 1e-6) and (Abs(thDeg - Round(thDeg / 90) * 90) >= 2) then
        begin
          SetStatus('Vectorize: the area is an ellipse that is not aligned with the axes (not supported).');
          Exit;
        end;
        s := NewShape(skEllipse);
        SetLength(s.P, 1);
        s.P[0] := ToDoc(0, 0);
        if (thDeg > 45) and (thDeg < 135) then
        begin
          s.RX := r.B * fx;
          s.RY := r.A * fy;
        end
        else
        begin
          s.RX := r.A * fx;
          s.RY := r.B * fy;
        end;
        s.Circ := (Abs(r.A - r.B) < 1e-6) and (Abs(fx - fy) < 1e-6);
        if s.Circ then
        begin
          s.RY := s.RX;
          what := 'circle';
        end
        else what := 'ellipse';
      end;
    vkLine:
      begin
        s := NewShape(skLine);
        SetLength(s.P, 2);
        s.P[0] := ToDoc(-r.A * ux, -r.A * uy);
        s.P[1] := ToDoc(r.A * ux, r.A * uy);
        s.Style.Cap := lcFlat;
        what := 'line';
      end;
    vkArc:
      begin
        s := NewShape(skArc);
        SetLength(s.P, 1);
        s.P[0] := ToDoc(0, 0);
        s.RX := r.A * fx;
        s.RY := r.A * fy;
        s.Circ := Abs(fx - fy) < 1e-6;
        if s.Circ then s.RY := s.RX;
        s.A1 := r.A1;
        s.A2 := r.A2;
        s.Style.Cap := lcFlat;
        what := 'arc';
      end;
    vkPolygon, vkPolyline, vkLoop:
      begin
        if r.Kind = vkPolyline then s := NewShape(skPolyline) else s := NewShape(skPolygon);
        SetLength(s.P, Length(r.Pts));
        for i := 0 to High(r.Pts) do s.P[i] := MakePt(x0 + r.Pts[i].x * fx, y0 + r.Pts[i].y * fy);
        case r.Kind of
          vkPolygon: what := 'polygon (' + IntToStr(Length(r.Pts)) + ' vertices)';
          vkLoop: what := 'closed outline (' + IntToStr(Length(r.Pts)) + ' vertices)';
        else
          what := 'polyline (' + IntToStr(Length(r.Pts)) + ' vertices)';
        end;
        if r.Kind <> vkPolygon then s.Style.Cap := lcFlat;
      end;
  end;
  if s = nil then Exit;
  if r.Kind in [vkPolyline, vkLoop] then
  begin
    s.Style.Stroke := Integer(r.Color);
    s.Style.Fill := NoColor;
    s.Style.Width := Max(0.5, r.Thick * avg);
    s.Style.Join := ljMiter;
  end
  else if r.Kind = vkArc then
  begin
    s.Style.Stroke := Integer(r.Color);
    s.Style.Fill := NoColor;
    s.Style.Width := Max(0.5, r.Thick * avg);
  end
  else if r.Kind = vkLine then
  begin
    s.Style.Stroke := Integer(r.Color);
    s.Style.Fill := NoColor;
    s.Style.Width := Max(0.5, 2 * r.B * avg);
  end
  else if r.Ring then
  begin
    s.Style.Stroke := Integer(r.Color);
    s.Style.Fill := NoColor;
    s.Style.Width := Max(0.5, r.Thick * avg);
    s.Style.Join := ljMiter;
  end
  else
  begin
    s.Style.Fill := Integer(r.Color);
    s.Style.Stroke := NoColor;
  end;
  Checkpoint;
  Doc.AddShape(s);
  Commit;
  SelSet(MakeRef(s.Id, -1));
  if r.Ring and (r.Kind in [vkRect, vkEllipse]) then what := what + ' (outline)';
  if r.Partial then
  begin
    if r.Kind = vkLine then what := 'straight part'
    else if r.Kind = vkArc then what := 'arc'
    else what := 'circle';
    SetStatus('Vectorize: the figure goes on in a shape that is not simple: only its ' + what + ' was put over the picture.');
  end
  else SetStatus('Vectorize: ' + what + ' recognised and put over the picture.');
  RefreshProps;
  Redraw;
end;

procedure TForm1.BreakAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s: TShape;
  err: string;
  poly: Integer;
  u: Double;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Break: click on an object.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if GroupPartBlocked(s, 'Break') then Exit;
  if ssShift in Shift then
  begin
    BreakShape := 0;
    if Length(s.Trims) = 0 then Exit;
    Checkpoint;
    SetLength(s.Trims, 0);
    Commit;
    SetStatus('Break removed: the object is whole again.');
    Redraw;
    Exit;
  end;
  if not Doc.NearestU(s, px, py, poly, u) then
  begin
    SetStatus('Break: this kind of object cannot be broken.');
    Exit;
  end;
  if (BreakShape = 0) or (BreakShape <> s.Id) then
  begin
    BreakShape := s.Id;
    BreakPoly := poly;
    BreakU := u;
    SetStatus('Break: now click the second point on the same object.');
    Exit;
  end;
  if poly <> BreakPoly then
  begin
    SetStatus('Break: the second point must be on the same outline.');
    Exit;
  end;
  Checkpoint;
  if Doc.AddBreak(s, poly, BreakU, u, err) then
  begin
    Commit;
    SetTool(tlSelect);
    SetStatus('Broken. The part between the two points is hidden; the original is kept (Shift+click restores).');
  end
  else
  begin
    Commit;
    SetStatus('Break: ' + err);
  end;
  Redraw;
end;

procedure TForm1.TrimAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s: TShape;
  err: string;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Trim: click on a line that is crossed by other objects.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if GroupPartBlocked(s, 'Trim') then Exit;
  if ssShift in Shift then
  begin
    if Length(s.Trims) = 0 then Exit;
    Checkpoint;
    SetLength(s.Trims, 0);
    Commit;
    SetStatus('Trim removed: the object is whole again.');
    Redraw;
    Exit;
  end;
  Checkpoint;
  if Doc.AddTrim(s, px, py, err) then
  begin
    Commit;
    SetStatus('Trimmed. Moving or resizing the crossing objects keeps the cut consistent (Shift+click restores).');
  end
  else
  begin
    Commit;
    SetStatus('Trim: ' + err);
  end;
  Redraw;
end;

procedure TForm1.ExtendAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s: TShape;
  err: string;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Extend: click on a line or poly-line, near the end you want to prolong.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if GroupPartBlocked(s, 'Extend') then Exit;
  if ssShift in Shift then
  begin
    if Length(s.Extends) = 0 then Exit;
    Checkpoint;
    SetLength(s.Extends, 0);
    Commit;
    SetStatus('Extension removed.');
    Redraw;
    Exit;
  end;
  Checkpoint;
  if Doc.AddExtend(s, px, py, err) then
  begin
    Commit;
    SetStatus('Extended. The end follows the object it reaches (Shift+click removes the extension).');
  end
  else
  begin
    Commit;
    SetStatus('Extend: ' + err);
  end;
  Redraw;
end;

// two straight lines selected that are joined at a point (an end of one is where an end of the other is): the points of each one
// on the side of its other end say which parts are kept
function TForm1.FilletPair(out a, b: TShape; out ax, ay, bx, by: Double): Boolean;
var
  ts: TShapeArray;
  i, j: Integer;
begin
  Result := False;
  a := nil;
  b := nil;
  ts := TargetShapes;
  if Length(ts) <> 2 then Exit;
  if (ts[0].Kind <> skLine) or (ts[1].Kind <> skLine) or (Length(ts[0].P) < 2) or (Length(ts[1].P) < 2) then Exit;
  if (ts[0].MirSrc > 0) or (ts[1].MirSrc > 0) then Exit;
  for i := 0 to 1 do
    for j := 0 to 1 do
      if Dist(ts[0].P[i], ts[1].P[j]) < 0.6 then
      begin
        a := ts[0];
        b := ts[1];
        ax := a.P[1 - i].x;
        ay := a.P[1 - i].y;
        bx := b.P[1 - j].x;
        by := b.P[1 - j].y;
        Exit(True);
      end;
end;

// two sides of a polygon / poly-line that follow each other are selected: the corner they share
function TForm1.FilletCorner(out sh: TShape; out v: Integer): Boolean;
var
  k1, k2, n: Integer;
begin
  Result := False;
  sh := nil;
  v := -1;
  if (Length(Sel) <> 2) or (Sel[0].Shape <> Sel[1].Shape) or (Sel[0].Idx <> -1) or (Sel[1].Idx <> -1) or
     (Sel[0].Seg < 0) or (Sel[1].Seg < 0) then Exit;
  sh := Doc.FindShape(Sel[0].Shape);
  if (sh = nil) or not (sh.Kind in [skPolyline, skPolygon]) or sh.Reg then Exit;
  n := Length(sh.P);
  k1 := Min(Sel[0].Seg, Sel[1].Seg);
  k2 := Max(Sel[0].Seg, Sel[1].Seg);
  if k2 >= n then Exit;
  if k2 = k1 + 1 then v := k2
  else if (sh.Kind = skPolygon) and (k1 = 0) and (k2 = n - 1) then v := 0
  else Exit;
  Result := (sh.Kind = skPolygon) or ((v > 0) and (v < n - 1));
end;

procedure TForm1.FilletSelected(chamfer: Boolean);
var
  a, b, f, sh: TShape;
  v: Integer;
  ax, ay, bx, by: Double;
  err, txt: string;
  pr2, vl2: array of string;
begin
  if not FilletPair(a, b, ax, ay, bx, by) and not FilletCorner(sh, v) then
  begin
    if chamfer then SetStatus('Chamfer: select two straight lines that are joined at a point (or two following sides of a polygon).')
    else SetStatus('Fillet: select two straight lines that are joined at a point (or two following sides of a polygon).');
    Exit;
  end;
  if chamfer then
  begin
    SetLength(pr2, 2);
    SetLength(vl2, 2);
    pr2[0] := 'Distance from the corner on the first line';
    pr2[1] := 'Distance from the corner on the second line';
    vl2[0] := FloatToStr(ChamD1, DefaultFormatSettings);
    vl2[1] := FloatToStr(ChamD2, DefaultFormatSettings);
    if not InputQuery('Chamfer', pr2, vl2) then Exit;
    ChamD1 := Max(0.5, ParseNum(vl2[0], ChamD1));
    ChamD2 := Max(0.5, ParseNum(vl2[1], ChamD2));
  end
  else
  begin
    txt := FloatToStr(FilletRadius, DefaultFormatSettings);
    if not InputQuery('Fillet', 'Radius of the rounded corner:', txt) then Exit;
    FilletRadius := Max(0.5, ParseNum(txt, FilletRadius));
  end;
  // the sides of a polygon / poly-line: its own corner is changed
  if (a = nil) and (sh <> nil) then
  begin
    Checkpoint;
    if Doc.CutCorner(sh, v, chamfer, IfThen(chamfer, ChamD1, FilletRadius), ChamD2, err) then
    begin
      Doc.Solve([]);
      Commit;
      SelSet(MakeRef(sh.Id, -1));
      if chamfer then SetStatus('The corner has been cut.') else SetStatus('The corner has been rounded.');
    end
    else
    begin
      Commit;
      if chamfer then SetStatus('Chamfer: ' + err) else SetStatus('Fillet: ' + err);
    end;
    RefreshProps;
    Redraw;
    Exit;
  end;
  Checkpoint;
  if chamfer then f := Doc.AddChamfer(a, b, ax, ay, bx, by, ChamD1, ChamD2, err)
  else f := Doc.AddFillet(a, b, ax, ay, bx, by, FilletRadius, err);
  Commit;
  if f <> nil then
  begin
    SelSet(MakeRef(f.Id, -1));
    if chamfer then SetStatus('Chamfer created. The lines are unchanged: the cut follows them (select it to change the distances).')
    else SetStatus('Fillet created. The lines are unchanged: the corner follows them (radius: select the arc).');
  end
  else if chamfer then SetStatus('Chamfer: ' + err)
  else SetStatus('Fillet: ' + err);
  RefreshProps;
  Redraw;
end;

procedure TForm1.FilletAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s, f: TShape;
  err: string;
  wasChamfer: Boolean;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Fillet: click on a line.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if GroupPartBlocked(s, 'Fillet / chamfer') then Exit;
  if (s = nil) or (s.Kind <> skLine) then
  begin
    SetStatus('Fillet: only straight lines can be joined.');
    Exit;
  end;
  if FilletFirst = nil then
  begin
    FilletFirst := s;
    FilletPt := MakePt(px, py);
    SelSet(ref);
    SetStatus('Fillet: now click the second line (on the side you want to keep).');
    Redraw;
    Exit;
  end;
  Checkpoint;
  if Tool = tlChamfer then
    f := Doc.AddChamfer(FilletFirst, s, FilletPt.x, FilletPt.y, px, py, ChamD1, ChamD2, err)
  else
    f := Doc.AddFillet(FilletFirst, s, FilletPt.x, FilletPt.y, px, py, FilletRadius, err);
  if f <> nil then
  begin
    Commit;
    wasChamfer := Tool = tlChamfer;
    SetTool(tlSelect);
    if wasChamfer then
      SetStatus('Chamfer created. The original lines are unchanged: the cut follows them (select it to change the distances).')
    else
      SetStatus('Fillet created. The original lines are unchanged: the corner follows them (radius: select the arc).');
  end
  else
  begin
    Commit;
    if Tool = tlChamfer then SetStatus('Chamfer: ' + err) else SetStatus('Fillet: ' + err);
  end;
  FilletFirst := nil;
  SelClear;
  Redraw;
end;


function ParseNum(const t: string; def: Double): Double;
var
  u: string;
begin
  u := StringReplace(Trim(t), ',', DefaultFormatSettings.DecimalSeparator, []);
  u := StringReplace(u, '.', DefaultFormatSettings.DecimalSeparator, []);
  Result := StrToFloatDef(u, def);
end;

// small parameter dialog: one number plus a Yes/No combo ("keep the original, make a copy?")
// asks into how many points a circle / ellipse / arc is divided (never fewer than 3)
function AskPointCount(const ACaption: string; var N: Integer; AMax: Integer): Boolean;
var
  f: TForm;
  l1: TLabel;
  se: TSpinEdit;
  b1, b2: TButton;
begin
  f := TForm.CreateNew(Application);
  try
    f.Caption := ACaption;
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 360;
    f.ClientHeight := 90;
    l1 := TLabel.Create(f);
    l1.Parent := f;
    l1.Caption := 'Number of points of the path:';
    l1.SetBounds(14, 20, 200, 20);
    se := TSpinEdit.Create(f);
    se.Parent := f;
    se.MinValue := 3;
    se.MaxValue := Max(3, AMax);
    se.Value := Max(3, Min(N, Max(3, AMax)));
    se.SetBounds(220, 16, 126, 26);
    b1 := TButton.Create(f);
    b1.Parent := f;
    b1.Caption := 'OK';
    b1.ModalResult := mrOk;
    b1.Default := True;
    b1.SetBounds(170, 54, 84, 26);
    b2 := TButton.Create(f);
    b2.Parent := f;
    b2.Caption := 'Cancel';
    b2.ModalResult := mrCancel;
    b2.Cancel := True;
    b2.SetBounds(262, 54, 84, 26);
    f.ActiveControl := se;
    Result := f.ShowModal = mrOk;
    if Result then N := Max(3, se.Value);
  finally
    f.Free;
  end;
end;

function AskNumberAndCopy(const ACaption, ANumLabel: string; var ANum: string;
  const ACopyLabel: string; var ACopy: Boolean): Boolean;
var
  f: TForm;
  l1, l2: TLabel;
  ed: TEdit;
  cb: TComboBox;
  b1, b2: TButton;
begin
  f := TForm.CreateNew(Application);
  try
    f.Caption := ACaption;
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 440;
    f.ClientHeight := 118;
    l1 := TLabel.Create(f);
    l1.Parent := f;
    l1.Caption := ANumLabel;
    l1.SetBounds(14, 20, 270, 20);
    ed := TEdit.Create(f);
    ed.Parent := f;
    ed.Text := ANum;
    ed.SetBounds(290, 16, 136, 26);
    l2 := TLabel.Create(f);
    l2.Parent := f;
    l2.Caption := ACopyLabel;
    l2.SetBounds(14, 56, 270, 20);
    cb := TComboBox.Create(f);
    cb.Parent := f;
    cb.Style := csDropDownList;
    cb.Items.Add('Yes');
    cb.Items.Add('No');
    if ACopy then cb.ItemIndex := 0 else cb.ItemIndex := 1;
    cb.SetBounds(290, 52, 136, 26);
    b1 := TButton.Create(f);
    b1.Parent := f;
    b1.Caption := 'OK';
    b1.ModalResult := mrOk;
    b1.Default := True;
    b1.SetBounds(250, 86, 84, 26);
    b2 := TButton.Create(f);
    b2.Parent := f;
    b2.Caption := 'Cancel';
    b2.ModalResult := mrCancel;
    b2.Cancel := True;
    b2.SetBounds(342, 86, 84, 26);
    f.ActiveControl := ed;
    Result := f.ShowModal = mrOk;
    if Result then
    begin
      ANum := ed.Text;
      ACopy := cb.ItemIndex = 0;
    end;
  finally
    f.Free;
  end;
end;

procedure TForm1.RotateStart;
var
  txt: string;
  i: Integer;
begin
  if Length(MirrorSrc) = 0 then
  begin
    SetStatus('Rotate: select the objects first, then press the Rotate button.');
    SetTool(tlSelect);
    Exit;
  end;
  txt := FloatToStr(RotAngle, DefaultFormatSettings);
  if not AskNumberAndCopy('Rotate', 'Angle (deg, + = counter-clockwise)', txt,
    'Keep the original (make a copy)?', RotCopy) then
  begin
    SetTool(tlSelect);
    Exit;
  end;
  RotAngle := ParseNum(txt, 0);
  if Abs(RotAngle) < 1e-9 then
  begin
    SetStatus('Rotate: the angle is zero, nothing to do.');
    SetLength(MirrorSrc, 0);
    SetTool(tlSelect);
    Exit;
  end;
  SelSet(MakeRef(MirrorSrc[0], -1));
  for i := 1 to High(MirrorSrc) do SelToggle(MakeRef(MirrorSrc[i], -1));
  Redraw;
  SetStatus('Rotate ' + FloatToStr(RotAngle, DefaultFormatSettings) + ' deg: click the center of rotation (it stays where it is).');
end;

procedure TForm1.RotateAt(px, py: Double);
var
  ref: TRef;
  pt: TPt;
  ids, newIds: TIntArray;
  i, n, skipped, dropped, converted: Integer;
  msg: string;
begin
  if (Abs(RotAngle) < 1e-9) or (Length(MirrorSrc) = 0) then Exit;
  if SnapTo(px, py, nil, ref, pt) then
  begin
    px := pt.x;
    py := pt.y;
  end;
  SetLength(ids, Length(MirrorSrc));
  for i := 0 to High(MirrorSrc) do ids[i] := MirrorSrc[i];
  Checkpoint;
  SetLength(newIds, 0);
  if RotCopy then
  begin
    SVGToDoc(DocToSVG(Doc, True, ids), Doc, True, 0, 0, newIds);
    ids := newIds;
  end;
  n := Doc.RotateShapes(ids, px, py, RotAngle * Pi / 180, skipped, dropped, converted);
  Commit;
  SelClear;
  if Length(ids) > 0 then SelSet(MakeRef(ids[0], -1));
  for i := 1 to High(ids) do SelToggle(MakeRef(ids[i], -1));
  if n > 0 then msg := 'Rotated ' + IntToStr(n) + ' object(s).'
  else msg := 'Rotate: nothing was rotated - copies made by Offset, Mirror and Array follow their original, rotate that instead.';
  if converted > 0 then msg := msg + ' ' + IntToStr(converted) + ' rectangle(s) / ellipse(s) became polygons / paths.';
  if dropped > 0 then msg := msg + ' ' + IntToStr(dropped) + ' horizontal/vertical constraint(s) were removed.';
  if skipped > 0 then msg := msg + ' ' + IntToStr(skipped) + ' object(s) cannot be rotated by this angle (images, SVG paths, ellipses).';
  SetStatus(msg);
  SetLength(MirrorSrc, 0);
  SetTool(tlSelect);
  Redraw;
end;

procedure TForm1.ScaleStart;
var
  txt: string;
  i: Integer;
  bx1, by1, bx2, by2: Double;
begin
  if Length(MirrorSrc) = 0 then
  begin
    SetStatus('Scale: select the objects first, then press the Scale button.');
    SetTool(tlSelect);
    Exit;
  end;
  txt := FloatToStr(ScaleK, DefaultFormatSettings);
  if not AskNumberAndCopy('Scale', 'Scale factor (2 = double, 0.5 = half)', txt,
    'Keep the original (make a copy)?', ScaleCopy) then
  begin
    SetTool(tlSelect);
    Exit;
  end;
  ScaleK := ParseNum(txt, 0);
  if ScaleK <= 0 then
  begin
    SetStatus('Scale: the factor must be greater than zero.');
    SetLength(MirrorSrc, 0);
    SetTool(tlSelect);
    Exit;
  end;
  SelSet(MakeRef(MirrorSrc[0], -1));
  for i := 1 to High(MirrorSrc) do SelToggle(MakeRef(MirrorSrc[i], -1));
  // the scaling is done at once, around the centre of the selection
  if GroupBox(MirrorSrc, bx1, by1, bx2, by2) then
  begin
    ScaleAt((bx1 + bx2) / 2, (by1 + by2) / 2, False);
    Exit;
  end;
  Redraw;
  SetStatus('Scale x' + FloatToStr(ScaleK, DefaultFormatSettings) + ': click the base point (it stays where it is).');
end;

procedure TForm1.ScaleAt(px, py: Double; snapIt: Boolean);
var
  ref: TRef;
  pt: TPt;
  ids, newIds: TIntArray;
  i, n: Integer;
begin
  if (ScaleK <= 0) or (Length(MirrorSrc) = 0) then Exit;
  if snapIt and SnapTo(px, py, nil, ref, pt) then
  begin
    px := pt.x;
    py := pt.y;
  end;
  SetLength(ids, Length(MirrorSrc));
  for i := 0 to High(MirrorSrc) do ids[i] := MirrorSrc[i];
  Checkpoint;
  SetLength(newIds, 0);
  if ScaleCopy then
  begin
    // duplicate the objects (with the constraints among them) and scale the duplicates
    SVGToDoc(DocToSVG(Doc, True, ids), Doc, True, 0, 0, newIds);
    ids := newIds;
  end;
  n := Doc.ScaleShapes(ids, px, py, ScaleK);
  Commit;
  SelClear;
  if Length(ids) > 0 then SelSet(MakeRef(ids[0], -1));
  for i := 1 to High(ids) do SelToggle(MakeRef(ids[i], -1));
  if n > 0 then SetStatus('Scaled ' + IntToStr(n) + ' object(s) around the centre of the selection.')
  else SetStatus('Scale: nothing to scale - copies made by Offset, Mirror and Array follow their original, scale that instead.');
  SetLength(MirrorSrc, 0);
  SetTool(tlSelect);
  Redraw;
end;

procedure TForm1.ArrayStart;
var
  prompts, vals: array of string;
  s: TShape;
  x1, y1, x2, y2, dx, dy: Double;
  i, nCols, nRows, made: Integer;
  err, firstErr: string;
  spec: TArraySpec;
begin
  if Length(MirrorSrc) = 0 then
  begin
    SetStatus('Array: select the objects first, then press the Array button.');
    SetTool(tlSelect);
    Exit;
  end;
  s := Doc.FindShape(MirrorSrc[0]);
  dx := 60;
  dy := 60;
  if (s <> nil) and ShapeBox(s, x1, y1, x2, y2) then
  begin
    dx := Round((x2 - x1) * 1.2 + 10);
    dy := Round((y2 - y1) * 1.2 + 10);
  end;
  SetLength(prompts, 6);
  SetLength(vals, 6);
  prompts[0] := 'Type: rect (grid) or polar (around a center)';
  prompts[1] := 'Columns (rect) / number of items (polar)';
  prompts[2] := 'Rows (rect)';
  prompts[3] := 'Step X between columns (rect)';
  prompts[4] := 'Step Y between rows (rect)';
  prompts[5] := 'Total angle in degrees (polar)';
  if ArrPolar then vals[0] := 'polar' else vals[0] := 'rect';
  vals[1] := IntToStr(ArrCount);
  vals[2] := '2';
  vals[3] := FloatToStr(dx, DefaultFormatSettings);
  vals[4] := FloatToStr(dy, DefaultFormatSettings);
  vals[5] := FloatToStr(ArrTotal, DefaultFormatSettings);
  if not InputQuery('Array', prompts, vals) then
  begin
    SetTool(tlSelect);
    Exit;
  end;
  ArrPolar := LowerCase(Trim(vals[0])) = 'polar';
  ArrCount := Max(1, Round(ParseNum(vals[1], ArrCount)));
  ArrTotal := ParseNum(vals[5], 360);
  if ArrPolar then
  begin
    SelSet(MakeRef(MirrorSrc[0], -1));
    for i := 1 to High(MirrorSrc) do SelToggle(MakeRef(MirrorSrc[i], -1));
    Redraw;
    SetStatus('Array: click the center of the polar array.');
    Exit;
  end;
  nCols := ArrCount;
  nRows := Max(1, Round(ParseNum(vals[2], 2)));
  Checkpoint;
  made := 0;
  firstErr := '';
  for i := 0 to High(MirrorSrc) do
  begin
    spec := Doc.AddArray(Doc.FindShape(MirrorSrc[i]), False, nCols, nRows,
      ParseNum(vals[3], dx), ParseNum(vals[4], dy), 0, 0, 0, 360, err);
    if spec <> nil then Inc(made) else if firstErr = '' then firstErr := err;
  end;
  Commit;
  if made > 0 then SetStatus('Array created: ' + IntToStr(made) + ' array(s). Select any item to change the numbers.')
  else SetStatus('Array: ' + firstErr);
  SetLength(MirrorSrc, 0);
  SetTool(tlSelect);
  Redraw;
end;

procedure TForm1.ArrayAt(px, py: Double);
var
  ref: TRef;
  pt: TPt;
  i, made: Integer;
  err, firstErr: string;
  spec: TArraySpec;
begin
  if not ArrPolar or (Length(MirrorSrc) = 0) then Exit;
  if SnapTo(px, py, nil, ref, pt) then
  begin
    px := pt.x;
    py := pt.y;
  end;
  Checkpoint;
  made := 0;
  firstErr := '';
  for i := 0 to High(MirrorSrc) do
  begin
    spec := Doc.AddArray(Doc.FindShape(MirrorSrc[i]), True, 1, 1, 0, 0, ArrCount, px, py, ArrTotal, err);
    if spec <> nil then Inc(made) else if firstErr = '' then firstErr := err;
  end;
  Commit;
  if made > 0 then SetStatus('Array created: ' + IntToStr(made) + ' array(s). Select any item to change the numbers.')
  else SetStatus('Array: ' + firstErr);
  SetLength(MirrorSrc, 0);
  SetTool(tlSelect);
  Redraw;
end;

procedure TForm1.ArrayChanged(Sender: TObject);
var
  ts: TShapeArray;
  spec: TArraySpec;
  keep: Integer;
begin
  if UpdatingProps then Exit;
  ts := SelShapes;
  if Length(ts) = 0 then Exit;
  spec := Doc.ArrayOf(ts[0]);
  if (spec = nil) and (ts[0].FA > 0) then
  begin
    // fillet radius / chamfer distances
    Checkpoint;
    if ts[0].Kind = skLine then
    begin
      ts[0].CD1 := Max(0.01, seA[1].Value);
      ts[0].CD2 := Max(0.01, seA[2].Value);
    end
    else
    begin
      ts[0].RX := Max(0.01, seA[1].Value);
      ts[0].RY := ts[0].RX;
    end;
    Commit;
    Doc.UpdateFillets;
    RefreshProps;
    Redraw;
    Exit;
  end;
  if spec = nil then Exit;
  keep := ts[0].Id;
  Checkpoint;
  if spec.Polar then
  begin
    spec.Count := Max(2, Min(400, Round(seA[1].Value)));
    spec.Total := Max(1, Min(360, seA[2].Value));
  end
  else
  begin
    spec.Cols := Max(1, Min(400, Round(seA[1].Value)));
    spec.Rows := Max(1, Min(400, Round(seA[2].Value)));
    if spec.Cols * spec.Rows > 400 then spec.Rows := Max(1, 400 div spec.Cols);
    if spec.Cols * spec.Rows < 2 then spec.Cols := 2;
    spec.DX := seA[3].Value;
    spec.DY := seA[4].Value;
  end;
  Commit;
  Doc.UpdateFillets;
  if Doc.FindShape(keep) <> nil then SelSet(MakeRef(keep, -1)) else SelClear;
  RefreshProps;
  Redraw;
end;

procedure TForm1.MirrorAt(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  s, f: TShape;
  i: Integer;
  err, firstErr: string;
  made: Integer;
  first: TShape;
begin
  if not HitShape(px, py, ref) then
  begin
    SetStatus('Mirror: click on an object.');
    Exit;
  end;
  s := Doc.FindShape(ref.Shape);
  if s = nil then Exit;
  if GroupPartBlocked(s, 'Mirror') then Exit;
  // no objects yet, or Shift: this click picks an object to mirror
  if (Length(MirrorSrc) = 0) or (ssShift in Shift) then
  begin
    if not (s.Kind in [skLine, skArrow, skPolyline, skPolygon, skRect, skEllipse, skArc, skSpline]) then
    begin
      SetStatus('Mirror: this kind of object cannot be mirrored.');
      Exit;
    end;
    for i := 0 to High(MirrorSrc) do
      if MirrorSrc[i] = s.Id then Exit;
    SetLength(MirrorSrc, Length(MirrorSrc) + 1);
    MirrorSrc[High(MirrorSrc)] := s.Id;
    if Length(MirrorSrc) = 1 then SelSet(ref) else SelToggle(ref);
    SetStatus('Mirror: ' + IntToStr(Length(MirrorSrc)) + ' object(s) picked - Shift+click for more, or click the axis line.');
    Redraw;
    Exit;
  end;
  // otherwise the click picks the axis
  if s.Kind <> skLine then
  begin
    SetStatus('Mirror: the axis must be a straight line (a reference line works well).');
    Exit;
  end;
  Checkpoint;
  made := 0;
  first := nil;
  firstErr := '';
  for i := 0 to High(MirrorSrc) do
  begin
    f := Doc.AddMirror(Doc.FindShape(MirrorSrc[i]), s, err);
    if f <> nil then
    begin
      Inc(made);
      if first = nil then first := f;
    end
    else if firstErr = '' then firstErr := err;
  end;
  Commit;
  SelClear;
  if first <> nil then SelSet(MakeRef(first.Id, -1));
  if made > 0 then
  begin
    err := '';
    if firstErr <> '' then err := ' (some were skipped: ' + firstErr + ')';
    SetStatus('Mirrored ' + IntToStr(made) + ' object(s). The copies follow the originals and the axis.' + err);
  end
  else SetStatus('Mirror: ' + firstErr);
  SetLength(MirrorSrc, 0);
  if made > 0 then SetTool(tlSelect);
  Redraw;
end;

procedure TForm1.DetachClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := SelShapes;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    if Doc.ArrayOf(ts[i]) <> nil then Doc.ExplodeArray(Doc.ArrayOf(ts[i]).Id);
    ts[i].OffSrc := 0;
    ts[i].MirSrc := 0;
    ts[i].MirAxis := 0;
  end;
  Commit;
  RefreshProps;
  Redraw;
end;

type
  TSignHelper = class
    Ed: TEdit;
    procedure Flip(Sender: TObject);
  end;

procedure TSignHelper.Flip(Sender: TObject);
var
  t: string;
begin
  t := Trim(Ed.Text);
  if (t <> '') and (t[1] = '-') then Delete(t, 1, 1) else t := '-' + t;
  Ed.Text := t;
  Ed.SetFocus;
  Ed.SelectAll;
end;

// the distance of an offset: a number and a button that changes its sign (positive: inwards in a closed shape)
function AskOffsetDistance(var d: Double): Boolean;
var
  f: TForm;
  l: TLabel;
  e: TEdit;
  bFlip, bOk, bCancel: TButton;
  h: TSignHelper;
begin
  Result := False;
  f := TForm.CreateNew(Application);
  h := TSignHelper.Create;
  try
    f.Caption := 'Offset';
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 420;
    f.ClientHeight := 120;
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Distance (positive: towards the inside of a closed shape; negative: the other side):';
    l.AutoSize := False;
    l.WordWrap := True;
    l.SetBounds(14, 10, 392, 36);
    e := TEdit.Create(f);
    e.Parent := f;
    e.Text := FloatToStr(d, DefaultFormatSettings);
    e.SetBounds(14, 52, 150, 26);
    h.Ed := e;
    bFlip := TButton.Create(f);
    bFlip.Parent := f;
    bFlip.Caption := '+ / -';
    bFlip.Hint := 'Change the sign of the distance: the copy goes to the other side';
    bFlip.ShowHint := True;
    bFlip.SetBounds(172, 51, 70, 28);
    bFlip.OnClick := @h.Flip;
    bOk := TButton.Create(f);
    bOk.Parent := f;
    bOk.Caption := 'OK';
    bOk.ModalResult := mrOk;
    bOk.Default := True;
    bOk.SetBounds(244, 86, 80, 28);
    bCancel := TButton.Create(f);
    bCancel.Parent := f;
    bCancel.Caption := 'Cancel';
    bCancel.ModalResult := mrCancel;
    bCancel.Cancel := True;
    bCancel.SetBounds(330, 86, 80, 28);
    f.ActiveControl := e;
    if f.ShowModal = mrOk then
    begin
      d := ParseNum(e.Text, d);
      Result := True;
    end;
  finally
    h.Free;
    f.Free;
  end;
end;

// the selected objects that can be offset
function TForm1.OffsetTargets: TShapeArray;
var
  ts: TShapeArray;
  i, n: Integer;
begin
  ts := TargetShapes;
  SetLength(Result, 0);
  n := 0;
  for i := 0 to High(ts) do
    if (ts[i].Kind in [skLine, skPolyline, skPolygon, skRect, skEllipse, skArc]) and (ts[i].FA <= 0) and not ts[i].Bucket then
    begin
      SetLength(Result, n + 1);
      Result[n] := ts[i];
      Inc(n);
    end;
end;

procedure TForm1.OffsetSelected;
var
  ts: TShapeArray;
  i: Integer;
  txt, err: string;
  f: TShape;
  made: TShapeArray;
begin
  ts := OffsetTargets;
  if Length(ts) = 0 then
  begin
    SetStatus('Offset: select lines, poly-lines, polygons, rectangles, ellipses or arcs first.');
    Exit;
  end;
  if not AskOffsetDistance(OffsetDist) then Exit;
  if Abs(OffsetDist) < 1e-9 then
  begin
    SetStatus('Offset: the distance cannot be zero.');
    Exit;
  end;
  SetLength(made, 0);
  Checkpoint;
  err := '';
  for i := 0 to High(ts) do
  begin
    f := Doc.AddOffsetSigned(ts[i], OffsetDist, err);
    if f <> nil then
    begin
      SetLength(made, Length(made) + 1);
      made[High(made)] := f;
    end;
  end;
  Commit;
  if Length(made) > 0 then
  begin
    SelSet(MakeRef(made[0].Id, -1));
    for i := 1 to High(made) do SelToggle(MakeRef(made[i].Id, -1));
    SetStatus('Offset created. It follows the original (select it to change the distance).');
  end
  else SetStatus('Offset: ' + err);
  RefreshProps;
  Redraw;
end;

procedure TForm1.OffsetAt(px, py: Double);
var
  ref: TRef;
  s, f: TShape;
  err: string;
begin
  if OffsetFirst = nil then
  begin
    if not HitShape(px, py, ref) then
    begin
      SetStatus('Offset: click on the object to copy.');
      Exit;
    end;
    s := Doc.FindShape(ref.Shape);
    if GroupPartBlocked(s, 'Offset') then Exit;
    if (s = nil) or not (s.Kind in [skLine, skPolyline, skPolygon, skRect, skEllipse, skArc]) then
    begin
      SetStatus('Offset: lines, poly-lines, polygons, rectangles, ellipses and arcs can be offset.');
      Exit;
    end;
    OffsetFirst := s;
    SelSet(ref);
    SetStatus('Offset: now click on the side where the copy goes.');
    Redraw;
    Exit;
  end;
  Checkpoint;
  f := Doc.AddOffset(OffsetFirst, px, py, OffsetDist, err);
  Commit;
  if f <> nil then
  begin
    SetStatus('Offset created. It follows the original (select it to change the distance).');
    SetTool(tlSelect);
    SelSet(MakeRef(f.Id, -1));
  end
  else SetStatus('Offset: ' + err);
  OffsetFirst := nil;
  Redraw;
end;

procedure TForm1.OffsetChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := SelShapes;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].OffSrc > 0 then
      ts[i].OffDist := seOff.Value * Doc.OffsetFactor(Doc.FindShape(ts[i].OffSrc));
  Commit;
  Doc.UpdateFillets;
  RefreshProps;
  Redraw;
end;

procedure TForm1.CreateDown(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  pt: TPt;
  snap: Boolean;
  txt: string;
  s: TShape;
  n: Integer;
  fl: Boolean;
begin
  if Tool = tlVectorize then
  begin
    VectorizeAt(px, py);
    Exit;
  end;
  if Tool = tlWand then
  begin
    WandAt(px, py, Shift);
    Exit;
  end;
  if Tool = tlSelShape then
  begin
    SelShapeAt(px, py, Shift);
    Exit;
  end;
  if Tool in [tlSelRect, tlSelEllipse, tlSelFree] then
  begin
    // inside the area that is already selected the pixels are dragged; outside a new selection is made
    if not (ssShift in Shift) then
    begin
      s := SelInsideAt(px, py);
      if s <> nil then
      begin
        StartPixDrag(s, Shift);
        Exit;
      end;
    end;
    SelToolDown(px, py, Shift);
    Exit;
  end;
  if Tool = tlBucket then
  begin
    BucketAt(px, py);
    Exit;
  end;
  if Tool = tlPathPoint then
  begin
    PathPointAt(px, py);
    Exit;
  end;
  if Tool = tlVertex then
  begin
    VertexAt(px, py);
    Exit;
  end;
  if Tool = tlJoin then
  begin
    JoinAt(px, py);
    Exit;
  end;
  if Tool = tlTrim then
  begin
    TrimAt(px, py, Shift);
    Exit;
  end;
  if Tool = tlBreak then
  begin
    BreakAt(px, py, Shift);
    Exit;
  end;
  if Tool = tlExtend then
  begin
    ExtendAt(px, py, Shift);
    Exit;
  end;
  if (Tool = tlFillet) or (Tool = tlChamfer) then
  begin
    FilletAt(px, py, Shift);
    Exit;
  end;
  if Tool = tlOffset then
  begin
    OffsetAt(px, py);
    Exit;
  end;
  if Tool = tlMirror then
  begin
    MirrorAt(px, py, Shift);
    Exit;
  end;
  if Tool = tlArray then
  begin
    ArrayAt(px, py);
    Exit;
  end;
  if Tool = tlScale then
  begin
    ScaleAt(px, py);
    Exit;
  end;
  if Tool = tlRotate then
  begin
    RotateAt(px, py);
    Exit;
  end;
  snap := SnapTo(px, py, nil, ref, pt);
  if snap then
  begin
    px := pt.x;
    py := pt.y;
  end;
  if Tool = tlRefPoint then
  begin
    Checkpoint;
    s := NewShape(skPolyline);
    s.IsRef := True;
    SetLength(s.P, 1);
    s.P[0] := MakePt(px, py);
    Doc.AddShape(s);
    Commit;
    SelSet(MakeRef(s.Id, -1));
    RefreshProps;
    Redraw;
    Exit;
  end;
  if Tool = tlText then
  begin
    txt := 'Text';
    if InputQuery('Text', 'Text:', txt) and (txt <> '') then
    begin
      Checkpoint;
      s := NewShape(skText);
      SetLength(s.P, 1);
      s.P[0] := MakePt(px, py);
      s.Text := txt;
      Doc.AddShape(s);
      Commit;
      Redraw;
    end;
    Exit;
  end;
  if Tool = tlSvgCode then
  begin
    txt := 'M0 0 L60 0 L60 40 C60 60 0 60 0 40 Z';
    if ShowTextDialog('SVG path data (the "d" attribute)', txt, False) and (Trim(txt) <> '') then
    begin
      Checkpoint;
      s := NewShape(skPath);
      s.Style.Fill := DefStyle.Fill;
      SetLength(s.P, 1);
      s.P[0] := MakePt(px, py);
      s.PathData := Trim(StringReplace(txt, LineEnding, ' ', [rfReplaceAll]));
      s.ParsePath;
      Doc.AddShape(s);
      Commit;
      Redraw;
    end;
    Exit;
  end;
  Checkpoint;
  case Tool of
    tlRegPoly:
      begin
        Creating := NewShape(skPolygon);
        Creating.Reg := True;
        SetLength(Creating.P, DefSides);
        for n := 0 to DefSides - 1 do Creating.P[n] := MakePt(px, py);
        RegCenter := MakePt(px, py);
        SetLength(CreateSnaps, DefSides);
        FillChar(CreateSnaps[0], SizeOf(TRef) * DefSides, 0);
        ArcStage := 0;
        Drag := dmCreate;
      end;
    tlLine, tlArrow, tlRefLine, tlRect, tlRoundRect, tlEllipse, tlArc:
      begin
        case Tool of
          tlLine, tlRefLine: Creating := NewShape(skLine);
          tlArrow: Creating := NewShape(skArrow);
          tlRect: Creating := NewShape(skRect);
          tlRoundRect:
            begin
              Creating := NewShape(skRect);
              Creating.Corner := DefCorner;
            end;
          tlEllipse: Creating := NewShape(skEllipse);
          tlArc: Creating := NewShape(skArc);
        end;
        if Tool = tlRefLine then
        begin
          Creating.IsRef := True;
        end;
        n := PointCountOf(Creating.Kind);
        SetLength(Creating.P, n);
        SetLength(CreateSnaps, n);
        Creating.P[0] := MakePt(px, py);
        if n > 1 then Creating.P[1] := MakePt(px, py);
        FillChar(CreateSnaps[0], SizeOf(TRef) * n, 0);
        if snap then CreateSnaps[0] := ref;
        if Creating.Kind in [skEllipse, skArc] then
        begin
          fl := ssShift in Shift;
          Creating.Circ := DefCirc xor fl;
          Creating.RX := 0.5;
          Creating.RY := 0.5;
        end;
        ArcStage := 0;
        Drag := dmCreate;
      end;
    tlPolyline, tlPolygon, tlSpline:
      begin
        if Creating = nil then
        begin
          case Tool of
            tlPolyline: Creating := NewShape(skPolyline);
            tlPolygon: Creating := NewShape(skPolygon);
            tlSpline: Creating := NewShape(skSpline);
          end;
          SetLength(Creating.P, 2);
          SetLength(CreateSnaps, 2);
          FillChar(CreateSnaps[0], SizeOf(TRef) * 2, 0);
          Creating.P[0] := MakePt(px, py);
          Creating.P[1] := MakePt(px, py);
          if snap then CreateSnaps[0] := ref;
          Drag := dmNone;
        end
        else
        begin
          n := Length(Creating.P);
          if snap then CreateSnaps[n - 1] := ref else FillChar(CreateSnaps[n - 1], SizeOf(TRef), 0);
          // closing a polygon on its first point
          if (Tool = tlPolygon) and (n >= 4) and (Hypot(px - Creating.P[0].x, py - Creating.P[0].y) < 9 / Zoom) then
          begin
            FinishCreating(True);
            Exit;
          end;
          Creating.P[n - 1] := MakePt(px, py);
          SetLength(Creating.P, n + 1);
          SetLength(CreateSnaps, n + 1);
          FillChar(CreateSnaps[n], SizeOf(TRef), 0);
          Creating.P[n] := MakePt(px, py);
        end;
        SetStatus('Click to add points; double-click, Enter or right-click to finish.');
      end;
  end;
  Redraw;
end;

// the selection tools drag a rectangle, an ellipse or a freehand outline on the raster that is selected: the figure becomes a Selection of it
procedure ClampToPicture(img: TShape; var x, y: Double; ix1, iy1, ix2, iy2: Double);
begin
  if Abs(img.Rot) > 1e-9 then Exit;       // a turned picture: no limit
  x := Max(ix1, Min(ix2, x));
  y := Max(iy1, Min(iy2, y));
end;

procedure TForm1.SelToolDown(px, py: Double; Shift: TShiftState);
var
  img: TShape;
  x1, y1, x2, y2: Double;
  n: Integer;
begin
  img := Doc.FindShape(ToolImg);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('Selection: select a raster picture first.');
    Exit;
  end;
  ImageBox(img, x1, y1, x2, y2);
  ClampToPicture(img, px, py, x1, y1, x2, y2);
  Checkpoint;
  SelMode := SelModeOf(Shift);
  case Tool of
    tlSelRect: Creating := NewShape(skRect);
    tlSelEllipse: Creating := NewShape(skEllipse);
  else
    Creating := NewShape(skPolygon);
  end;
  n := PointCountOf(Creating.Kind);
  if Creating.Kind = skPolygon then n := 2;
  SetLength(Creating.P, n);
  Creating.P[0] := MakePt(px, py);
  if n > 1 then Creating.P[1] := MakePt(px, py);
  if Creating.Kind = skEllipse then
  begin
    Creating.Circ := False;
    Creating.RX := 0.5;
    Creating.RY := 0.5;
  end;
  Creating.IsRef := True;
  Creating.Style.Fill := NoColor;
  SetLength(CreateSnaps, n);
  FillChar(CreateSnaps[0], SizeOf(TRef) * n, 0);
  SelStart := MakePt(px, py);
  ArcStage := 0;
  Drag := dmCreate;
  Redraw;
end;

procedure TForm1.SelToolMove(px, py: Double; Shift: TShiftState);
var
  img: TShape;
  x1, y1, x2, y2, dx, dy, d: Double;
  n: Integer;
begin
  if (Creating = nil) or (Drag <> dmCreate) then Exit;
  img := Doc.FindShape(ToolImg);
  if img = nil then Exit;
  ImageBox(img, x1, y1, x2, y2);
  ClampToPicture(img, px, py, x1, y1, x2, y2);
  dx := px - SelStart.x;
  dy := py - SelStart.y;
  case Creating.Kind of
    skRect: Creating.P[1] := MakePt(SelStart.x + dx, SelStart.y + dy);
    skEllipse:
      begin
        // the box that is dragged is the box of the ellipse
        Creating.P[0] := MakePt(SelStart.x + dx / 2, SelStart.y + dy / 2);
        Creating.RX := Max(0.5, Abs(dx) / 2);
        Creating.RY := Max(0.5, Abs(dy) / 2);
      end;
  else
    begin
      n := Length(Creating.P);
      if Hypot(px - Creating.P[n - 1].x, py - Creating.P[n - 1].y) >= 2 / Zoom then
      begin
        SetLength(Creating.P, n + 1);
        SetLength(CreateSnaps, n + 1);
        FillChar(CreateSnaps[n], SizeOf(TRef), 0);
        Creating.P[n] := MakePt(px, py);
      end;
    end;
  end;
  Redraw;
end;

// the colour of the point as it is seen (what is drawn there, raster or vector; the page where nothing is)
procedure TForm1.PickColorAt(px, py: Double; secondary: Boolean);
var
  bmp: TBGRABitmap;
  q: TBGRAPixel;
  r, g, b, a: Integer;
  col: TColor;
  nm: string;
begin
  bmp := RenderDocRgba(1, 1, 1, False, Floor(px), Floor(py));
  try
    q := bmp.GetPixel(0, 0);
  finally
    bmp.Free;
  end;
  // over the white of the page
  a := q.alpha;
  r := (q.red * a + 255 * (255 - a)) div 255;
  g := (q.green * a + 255 * (255 - a)) div 255;
  b := (q.blue * a + 255 * (255 - a)) div 255;
  col := TColor(r or (g shl 8) or (b shl 16));
  if secondary then
  begin
    DefStyle.Fill := col;
    DefStyle.FillTr := 0;
  end
  else
  begin
    DefStyle.Stroke := col;
    DefStyle.StrokeTr := 0;
  end;
  if secondary then nm := 'secondary' else nm := 'primary';
  SetStatus(Format('Eyedropper: #%.2x%.2x%.2x is now the %s colour.', [r, g, b, nm]));
  RefreshProps;
  Redraw;
end;

procedure TForm1.CloneChanged(Sender: TObject);
begin
  if UpdatingProps then Exit;
  CloneW := seCloneW.Value;
  CloneF := seCloneF.Value;
  Redraw;
end;

// the brush (a circle), and the point that is being copied
procedure TForm1.DrawCloneGuides(cnv: TCanvas);
var
  r, sx, sy: Integer;
begin
  r := Max(2, Round(CloneW / 2 * Zoom));
  cnv.Brush.Style := bsClear;
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psSolid;
  cnv.Pen.Color := TColor($0080FF);
  cnv.Ellipse(Round(CloneCur.x * Zoom) - r, Round(CloneCur.y * Zoom) - r, Round(CloneCur.x * Zoom) + r, Round(CloneCur.y * Zoom) + r);
  if CloneHasSrc then
  begin
    if CloneHasOff then
    begin
      sx := Round((CloneCur.x + CloneOff.x) * Zoom);
      sy := Round((CloneCur.y + CloneOff.y) * Zoom);
    end
    else
    begin
      sx := Round(CloneSrc.x * Zoom);
      sy := Round(CloneSrc.y * Zoom);
    end;
    cnv.Pen.Color := TColor($0000E0);
    cnv.Ellipse(sx - r, sy - r, sx + r, sy + r);
    cnv.Line(sx - r - 4, sy, sx + r + 4, sy);
    cnv.Line(sx, sy - r - 4, sx, sy + r + 4);
  end;
end;

// the picture shown is the working copy
procedure TForm1.CloneView;
var
  bmp: TBitmap;
begin
  if (CloneImg = nil) or (CloneLi = nil) then Exit;
  FlushImageCaches(CloneImg);
  bmp := TBitmap.Create;
  bmp.PixelFormat := pf32bit;
  bmp.LoadFromIntfImage(CloneLi);
  CloneImg.Cache := bmp;
  CloneTick := GetTickCount64;
  Redraw;
end;

// one round dab: the pixels of the source (from the picture as it was when the stroke began) are mixed over the picture,
// fully inside and fading to nothing at the edge (feather)
procedure TForm1.CloneDab(cx, cy: Double);
var
  x1, y1, x2, y2, fx, fy, rp, solid, d, wgt, px, py: Double;
  w, h, x, y, bx1, by1, bx2, by2, ox, oy, sx, sy: Integer;
  c: TPt;
  dc, sc: TFPColor;
  aDst, aSrc, aNew: Double;

  function Mixw(a, b: Word; wt: Double): Word;
  begin
    Result := Round(a + (b - a) * wt);
  end;

begin
  ImageBox(CloneImg, x1, y1, x2, y2);
  w := CloneLi.Width;
  h := CloneLi.Height;
  fx := w / (x2 - x1);
  fy := h / (y2 - y1);
  // the centre in picture pixels (a turned picture: back to its own axes)
  c := TurnPt(MakePt(cx, cy), ShapePivot(CloneImg), -CloneImg.Rot);
  px := (c.x - x1) * fx;
  py := (c.y - y1) * fy;
  rp := Max(1, CloneW / 2 * fx);
  solid := rp * (1 - CloneF / 100);
  ox := Round(CloneOff.x * fx);
  oy := Round(CloneOff.y * fy);
  bx1 := Max(0, Floor(px - rp));
  bx2 := Min(w - 1, Ceil(px + rp));
  by1 := Max(0, Floor(py - rp));
  by2 := Min(h - 1, Ceil(py + rp));
  for y := by1 to by2 do
    for x := bx1 to bx2 do
    begin
      d := Hypot(x + 0.5 - px, y + 0.5 - py);
      if d >= rp then Continue;
      if d <= solid then wgt := 1 else wgt := (rp - d) / Max(1e-9, rp - solid);
      sx := x + ox;
      sy := y + oy;
      if (sx < 0) or (sy < 0) or (sx >= w) or (sy >= h) then Continue;
      dc := CloneLi.Colors[x, y];
      sc := CloneSnap.Colors[sx, sy];
      // mixed with the opacity as a weight, so that a transparent source does not darken the colours
      aDst := dc.alpha * (1 - wgt);
      aSrc := sc.alpha * wgt;
      aNew := aDst + aSrc;
      if aNew < 1e-6 then
        dc := FPColor(0, 0, 0, 0)
      else
      begin
        dc.red := Round((dc.red * aDst + sc.red * aSrc) / aNew);
        dc.green := Round((dc.green * aDst + sc.green * aSrc) / aNew);
        dc.blue := Round((dc.blue * aDst + sc.blue * aSrc) / aNew);
        dc.alpha := Round(aNew);
      end;
      CloneLi.Colors[x, y] := dc;
    end;
end;

procedure TForm1.CloneDown(px, py: Double; Shift: TShiftState);
var
  img: TShape;
  raw: TGraphic;
begin
  CloneCur := MakePt(px, py);
  img := Doc.FindShape(ToolImg);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('Clone: select a raster picture first.');
    Exit;
  end;
  if (ssCtrl in Shift) or not CloneHasSrc then
  begin
    CloneSrc := MakePt(px, py);
    CloneHasSrc := True;
    CloneHasOff := False;
    SetStatus('Clone: copy point set; now paint where the copy goes (Ctrl+click to choose another point).');
    Redraw;
    Exit;
  end;
  if not CloneHasOff then
  begin
    CloneOff := MakePt(CloneSrc.x - px, CloneSrc.y - py);
    CloneHasOff := True;
  end;
  Checkpoint;
  CloneImg := img;
  CloneKey := img.KeyOn;
  CloneKC := img.KeyColor;
  CloneKT := img.KeyTol;
  if CloneKey then SetImageKey(img, False, CloneKC, CloneKT);    // the original picture is the one that is painted
  raw := RawImage(img);
  if raw = nil then
  begin
    Commit;
    Exit;
  end;
  CloneLi := RgbaOf(raw);
  CloneSnap := TLazIntfImage.Create(0, 0);
  CloneSnap.Assign(CloneLi);
  CloneOn := True;
  CloneLast := MakePt(px, py);
  CloneDab(px, py);
  CloneView;
end;

procedure TForm1.CloneMove(px, py: Double);
var
  n, i: Integer;
  d, step: Double;
begin
  CloneCur := MakePt(px, py);
  if CloneOn then
  begin
    // dabs along the segment from the last point, a quarter of the width apart
    step := Max(0.5, CloneW / 4);
    d := Hypot(px - CloneLast.x, py - CloneLast.y);
    n := Max(1, Ceil(d / step));
    for i := 1 to n do
      CloneDab(CloneLast.x + (px - CloneLast.x) * i / n, CloneLast.y + (py - CloneLast.y) * i / n);
    CloneLast := MakePt(px, py);
    if GetTickCount64 - CloneTick > 40 then CloneView else Redraw;
  end
  else Redraw;
end;

procedure TForm1.CloneUp;
begin
  if not CloneOn then Exit;
  CloneOn := False;
  CloneView;
  CloneImg.ImageData := PngBase64(CloneLi);
  CloneLi.Free;
  CloneLi := nil;
  CloneSnap.Free;
  CloneSnap := nil;
  FlushImageCaches(CloneImg);
  if CloneKey then SetImageKey(CloneImg, True, CloneKC, CloneKT);
  Commit;
  Redraw;
end;

// the brush of the eraser: a circle
// the pixels lifted from a selection are still a selection that waits for Enter: a light dashed outline shows where they are
procedure TForm1.DrawFloatOutline(cnv: TCanvas);
var
  fl: TShape;
  x1, y1, x2, y2: Double;
  c, q: TPt;
  pts: array[0..4] of TPoint;
  i: Integer;
begin
  if FloatId <= 0 then Exit;
  fl := Doc.FindShape(FloatId);
  if (fl = nil) or (fl.Kind <> skImage) or not Doc.ShapeVisible(fl) then Exit;
  ImageBox(fl, x1, y1, x2, y2);
  // once the pixels are moved, resized or turned they are easy to tell from the background: no outline
  if (Abs(fl.P[0].x - FloatBox[0]) > 1e-6) or (Abs(fl.P[0].y - FloatBox[1]) > 1e-6) or (Abs(fl.P[1].x - FloatBox[2]) > 1e-6) or
    (Abs(fl.P[1].y - FloatBox[3]) > 1e-6) or (Abs(fl.Rot - FloatRot) > 1e-9) then Exit;
  c := ShapePivot(fl);
  for i := 0 to 4 do
  begin
    case i mod 4 of
      0: q := MakePt(x1, y1);
      1: q := MakePt(x2, y1);
      2: q := MakePt(x2, y2);
      else q := MakePt(x1, y2);
    end;
    q := TurnPt(q, c, fl.Rot);
    pts[i] := Point(Round(q.x * Zoom), Round(q.y * Zoom));
  end;
  cnv.Brush.Style := bsClear;
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psDot;
  cnv.Pen.Color := TColor($E0A040);
  cnv.Polyline(pts);
  cnv.Pen.Style := psSolid;
end;

procedure TForm1.DrawEraseGuide(cnv: TCanvas);
var
  r: Integer;
begin
  r := Max(2, Round(CloneW / 2 * Zoom));
  cnv.Brush.Style := bsClear;
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psSolid;
  cnv.Pen.Color := TColor($0000E0);
  cnv.Ellipse(Round(CloneCur.x * Zoom) - r, Round(CloneCur.y * Zoom) - r, Round(CloneCur.x * Zoom) + r, Round(CloneCur.y * Zoom) + r);
end;

// the picture shown is the working copy
procedure TForm1.EraseView;
var
  bmp: TBitmap;
begin
  if (EraseImg = nil) or (EraseLi = nil) then Exit;
  FlushImageCaches(EraseImg);
  bmp := TBitmap.Create;
  bmp.PixelFormat := pf32bit;
  bmp.LoadFromIntfImage(EraseLi);
  EraseImg.Cache := bmp;
  EraseTick := GetTickCount64;
  Redraw;
end;

// one round dab. What is done to a pixel depends on how much of it the brush has covered during the stroke (the most of any dab),
// and is made from the picture as it was when the stroke began: going over the same place again does not add up
procedure TForm1.EraseDab(cx, cy: Double);
var
  x1, y1, x2, y2, fx, fy, rp, solid, d, wgt, px, py, a, aO, aN: Double;
  w, h, x, y, bx1, by1, bx2, by2, q: Integer;
  c: TPt;
  sc, dc: TFPColor;
begin
  ImageBox(EraseImg, x1, y1, x2, y2);
  w := EraseLi.Width;
  h := EraseLi.Height;
  fx := w / (x2 - x1);
  fy := h / (y2 - y1);
  c := TurnPt(MakePt(cx, cy), ShapePivot(EraseImg), -EraseImg.Rot);
  px := (c.x - x1) * fx;
  py := (c.y - y1) * fy;
  rp := Max(1, CloneW / 2 * fx);
  solid := rp * (1 - CloneF / 100);
  bx1 := Max(0, Floor(px - rp));
  bx2 := Min(w - 1, Ceil(px + rp));
  by1 := Max(0, Floor(py - rp));
  by2 := Min(h - 1, Ceil(py + rp));
  for y := by1 to by2 do
    for x := bx1 to bx2 do
    begin
      d := Hypot(x + 0.5 - px, y + 0.5 - py);
      if d >= rp then Continue;
      if d <= solid then wgt := 1 else wgt := (rp - d) / Max(1e-9, rp - solid);
      q := y * w + x;
      if wgt <= EraseCov[q] then Continue;
      EraseCov[q] := wgt;
      if (Length(EraseMask) > 0) and (EraseMask[q] = 0) then Continue;
      sc := EraseSnap.Colors[x, y];
      // the primary colour resists
      if EraseProt and (sc.alpha > 0) and (Abs((sc.red shr 8) - EraseP[0]) <= EraseTol) and
         (Abs((sc.green shr 8) - EraseP[1]) <= EraseTol) and (Abs((sc.blue shr 8) - EraseP[2]) <= EraseTol) then Continue;
      aO := sc.alpha / 65535;
      if EraseNone then
      begin
        // no secondary colour: the picture becomes transparent
        aN := aO * (1 - wgt);
        dc := sc;
        if aN < 1 / 65535 then dc := FPColor(0, 0, 0, 0) else dc.alpha := Round(aN * 65535);
      end
      else
      begin
        // the secondary colour over the old one, as opaque as it is
        a := EraseA * wgt;
        aN := a + aO * (1 - a);
        if aN < 1e-6 then dc := FPColor(0, 0, 0, 0)
        else
        begin
          dc.red := Round((EraseS[0] * 257 * a + sc.red * aO * (1 - a)) / aN);
          dc.green := Round((EraseS[1] * 257 * a + sc.green * aO * (1 - a)) / aN);
          dc.blue := Round((EraseS[2] * 257 * a + sc.blue * aO * (1 - a)) / aN);
          dc.alpha := Round(aN * 65535);
        end;
      end;
      EraseLi.Colors[x, y] := dc;
    end;
end;

procedure TForm1.EraseDown(px, py: Double);
var
  img: TShape;
  raw: TGraphic;
  sels: TShapeArray;
  col: Integer;
begin
  CloneCur := MakePt(px, py);
  img := Doc.FindShape(ToolImg);
  if (img = nil) or (img.Kind <> skImage) then
  begin
    SetStatus('Eraser: select a raster picture first.');
    Exit;
  end;
  Checkpoint;
  EraseImg := img;
  EraseKey := img.KeyOn;
  EraseKC := img.KeyColor;
  EraseKT := img.KeyTol;
  if EraseKey then SetImageKey(img, False, EraseKC, EraseKT);    // the original picture is the one that is painted
  raw := RawImage(img);
  if raw = nil then
  begin
    Commit;
    Exit;
  end;
  EraseLi := RgbaOf(raw);
  EraseSnap := TLazIntfImage.Create(0, 0);
  EraseSnap.Assign(EraseLi);
  SetLength(EraseCov, EraseLi.Width * EraseLi.Height);
  FillChar(EraseCov[0], Length(EraseCov) * SizeOf(Single), 0);
  // a selection of pixels on the picture limits the eraser to itself
  SetLength(EraseMask, 0);
  sels := SelListOf(img);
  if Length(sels) > 0 then EraseMask := SelMask(img, sels, EraseLi.Width, EraseLi.Height);
  // the primary colour is protected, the secondary is left behind
  col := DefStyle.Stroke;
  EraseProt := col <> NoColor;
  if EraseProt then
  begin
    EraseP[0] := col and $FF;
    EraseP[1] := (col shr 8) and $FF;
    EraseP[2] := (col shr 16) and $FF;
  end;
  col := DefStyle.Fill;
  EraseNone := col = NoColor;
  if not EraseNone then
  begin
    EraseS[0] := col and $FF;
    EraseS[1] := (col shr 8) and $FF;
    EraseS[2] := (col shr 16) and $FF;
    EraseA := (255 - DefStyle.FillTr) / 255;
  end;
  EraseTol := Round(Max(0, Min(100, DefWandTol)) * 2.55);
  EraseOn := True;
  EraseLast := MakePt(px, py);
  EraseDab(px, py);
  EraseView;
end;

procedure TForm1.EraseMove(px, py: Double);
var
  n, i: Integer;
  d, step: Double;
begin
  CloneCur := MakePt(px, py);
  if EraseOn then
  begin
    step := Max(0.5, CloneW / 4);
    d := Hypot(px - EraseLast.x, py - EraseLast.y);
    n := Max(1, Ceil(d / step));
    for i := 1 to n do
      EraseDab(EraseLast.x + (px - EraseLast.x) * i / n, EraseLast.y + (py - EraseLast.y) * i / n);
    EraseLast := MakePt(px, py);
    if GetTickCount64 - EraseTick > 40 then EraseView else Redraw;
  end
  else Redraw;
end;

procedure TForm1.EraseUp;
begin
  if not EraseOn then Exit;
  EraseOn := False;
  EraseView;
  EraseImg.ImageData := PngBase64(EraseLi);
  EraseLi.Free;
  EraseLi := nil;
  EraseSnap.Free;
  EraseSnap := nil;
  SetLength(EraseCov, 0);
  SetLength(EraseMask, 0);
  FlushImageCaches(EraseImg);
  if EraseKey then SetImageKey(EraseImg, True, EraseKC, EraseKT);
  Commit;
  Redraw;
end;

procedure TForm1.PersStart(img: TShape);
var
  x1, y1, x2, y2: Double;
  raw: TGraphic;
  li: TLazIntfImage;
  col: TFPColor;
  kx, ky: Integer;
begin
  ImageBox(img, x1, y1, x2, y2);
  PersActive := True;
  PersId := img.Id;
  PersDrag := -1;
  // a reduced copy of the picture: the preview while the corners move is made from it (approximate, but fast)
  SetLength(PersR, 0);
  SetLength(PersG, 0);
  SetLength(PersB, 0);
  SetLength(PersA, 0);
  PersSrcW := 0;
  raw := RawImage(img);
  if raw <> nil then
  begin
    li := RgbaOf(raw);
    try
      PersScale := Min(1, 420 / Max(li.Width, li.Height));
      PersSrcW := Max(1, Round(li.Width * PersScale));
      PersSrcH := Max(1, Round(li.Height * PersScale));
      PersFx := li.Width / (x2 - x1);
      PersFy := li.Height / (y2 - y1);
      SetLength(PersR, PersSrcW * PersSrcH);
      SetLength(PersG, PersSrcW * PersSrcH);
      SetLength(PersB, PersSrcW * PersSrcH);
      SetLength(PersA, PersSrcW * PersSrcH);
      for ky := 0 to PersSrcH - 1 do
        for kx := 0 to PersSrcW - 1 do
        begin
          col := li.Colors[Min(li.Width - 1, Round((kx + 0.5) / PersScale - 0.5)), Min(li.Height - 1, Round((ky + 0.5) / PersScale - 0.5))];
          PersR[ky * PersSrcW + kx] := col.red shr 8;
          PersG[ky * PersSrcW + kx] := col.green shr 8;
          PersB[ky * PersSrcW + kx] := col.blue shr 8;
          PersA[ky * PersSrcW + kx] := col.alpha shr 8;
        end;
    finally
      li.Free;
    end;
  end;
  PersLX1 := x1; PersLY1 := y1; PersLX2 := x2; PersLY2 := y2;
  PersX[0] := x1; PersY[0] := y1;
  PersX[1] := x2; PersY[1] := y1;
  PersX[2] := x2; PersY[2] := y2;
  PersX[3] := x1; PersY[3] := y2;
  SelClear;
  RefreshProps;
  SetStatus('Perspective: put the four corners on the corners of what must become a rectangle; click outside of it to confirm (Enter too), Esc to cancel.');
  Redraw;
end;

function TForm1.PersInside(px, py: Double): Boolean;
var
  o: TOutline;
  i: Integer;
begin
  SetLength(o, 1);
  SetLength(o[0].Pts, 4);
  for i := 0 to 3 do o[0].Pts[i] := MakePt(PersX[i], PersY[i]);
  o[0].Closed := True;
  Result := InsideOutline(o, px, py);
end;

function TForm1.PersHit(px, py: Double): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to 3 do
    if Hypot(px - PersX[i], py - PersY[i]) <= 9 / Zoom then Exit(i);
end;

procedure TForm1.PersFinish(apply: Boolean);
var
  img: TShape;
  chg: Boolean;
begin
  if not PersActive then Exit;
  PersActive := False;
  PersDrag := -1;
  PaintBox1.Cursor := crDefault;
  img := Doc.FindShape(PersId);
  chg := (Abs(PersX[0] - PersLX1) > 1e-6) or (Abs(PersY[0] - PersLY1) > 1e-6) or
           (Abs(PersX[1] - PersLX2) > 1e-6) or (Abs(PersY[1] - PersLY1) > 1e-6) or
           (Abs(PersX[2] - PersLX2) > 1e-6) or (Abs(PersY[2] - PersLY2) > 1e-6) or
           (Abs(PersX[3] - PersLX1) > 1e-6) or (Abs(PersY[3] - PersLY2) > 1e-6);
  if apply and (img <> nil) and chg then PersApply(img)
  else SetStatus('Perspective: nothing changed.');
  if img <> nil then SelSet(MakeRef(img.Id, -1));
  RefreshProps;
  Redraw;
end;

function LanczosW(x: Double): Double;
begin
  if Abs(x) < 1e-9 then Exit(1);
  if Abs(x) >= 3 then Exit(0);
  Result := 3 * Sin(Pi * x) * Sin(Pi * x / 3) / (Sqr(Pi) * Sqr(x));
end;

// the quadrilateral becomes a rectangle: every pixel of the result is read from the picture through the projective map,
// with a Lanczos (a = 3) interpolation, premultiplied by the opacity so that transparent edges do not bleed
procedure TForm1.PersApply(img: TShape);
var
  raw: TGraphic;
  li, nl: TLazIntfImage;
  w, h, ow, oh, x, y, i, j, ix, iy, sx0, sy0, k: Integer;
  x1, y1, x2, y2, fx, fy: Double;
  qx, qy: array[0..3] of Double;
  gx, gy, hx, hy, a, b, c, d, e, f, g, hh, u, v, den, sx, sy, dx, dy, wxy, wsum, ra, ga, ba, aa, aw: Double;
  sdx, sdy, ddx, ddy, ex1, ey1, ex2, ey2: Double;
  wx, wy: array[0..5] of Double;
  sr, sg, sb, sa: array of Byte;
  col: TFPColor;
  wasKey, convex: Boolean;
  kc, kt, sgn, cr: Integer;
  cx, cy, bw, bh: Double;
  cross: Double;
  ids: array of Integer;

  function Clamp255(v: Double): Word;
  begin
    if v < 0 then v := 0;
    if v > 255 then v := 255;
    Result := Round(v) * 257;
  end;

begin
  ImageBox(img, x1, y1, x2, y2);
  // the corners must make a convex quadrilateral
  convex := True;
  sgn := 0;
  for i := 0 to 3 do
  begin
    j := (i + 1) mod 4;
    k := (i + 2) mod 4;
    cross := (PersX[j] - PersX[i]) * (PersY[k] - PersY[j]) - (PersY[j] - PersY[i]) * (PersX[k] - PersX[j]);
    if Abs(cross) < 1e-9 then convex := False
    else if sgn = 0 then sgn := Sign(cross)
    else if Sign(cross) <> sgn then convex := False;
  end;
  if not convex then
  begin
    SetStatus('Perspective: the four corners must make a convex quadrilateral (no crossed sides).');
    Exit;
  end;
  wasKey := img.KeyOn;
  kc := img.KeyColor;
  kt := img.KeyTol;
  Checkpoint;
  if wasKey then SetImageKey(img, False, kc, kt);
  raw := RawImage(img);
  if raw = nil then
  begin
    Commit;
    Exit;
  end;
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    fx := w / (x2 - x1);
    fy := h / (y2 - y1);
    for i := 0 to 3 do
    begin
      qx[i] := (PersX[i] - x1) * fx;
      qy[i] := (PersY[i] - y1) * fy;
    end;
    // size of the result: the longer of the opposite sides, in pixels of the picture
    ow := Round(Max(Hypot(qx[1] - qx[0], qy[1] - qy[0]), Hypot(qx[2] - qx[3], qy[2] - qy[3])));
    oh := Round(Max(Hypot(qx[3] - qx[0], qy[3] - qy[0]), Hypot(qx[2] - qx[1], qy[2] - qy[1])));
    if (ow > 6000) or (oh > 6000) then
    begin
      f := 6000 / Max(ow, oh);
      ow := Max(1, Round(ow * f));
      oh := Max(1, Round(oh * f));
    end;
    ow := Max(2, ow);
    oh := Max(2, oh);
    SetLength(sr, w * h);
    SetLength(sg, w * h);
    SetLength(sb, w * h);
    SetLength(sa, w * h);
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
      begin
        col := li.Colors[x, y];
        sr[y * w + x] := col.red shr 8;
        sg[y * w + x] := col.green shr 8;
        sb[y * w + x] := col.blue shr 8;
        sa[y * w + x] := col.alpha shr 8;
      end;
    // unit square -> quadrilateral (projective): x = (a u + b v + c) / (g u + h v + 1), y likewise
    sdx := qx[0] - qx[1] + qx[2] - qx[3];
    sdy := qy[0] - qy[1] + qy[2] - qy[3];
    if (Abs(sdx) < 1e-9) and (Abs(sdy) < 1e-9) then
    begin
      g := 0;
      hh := 0;
      a := qx[1] - qx[0]; b := qx[3] - qx[0];
      d := qy[1] - qy[0]; e := qy[3] - qy[0];
    end
    else
    begin
      ex1 := qx[1] - qx[2]; ey1 := qy[1] - qy[2];
      ex2 := qx[3] - qx[2]; ey2 := qy[3] - qy[2];
      den := ex1 * ey2 - ex2 * ey1;
      g := (sdx * ey2 - ex2 * sdy) / den;
      hh := (ex1 * sdy - sdx * ey1) / den;
      a := qx[1] - qx[0] + g * qx[1];
      b := qx[3] - qx[0] + hh * qx[3];
      d := qy[1] - qy[0] + g * qy[1];
      e := qy[3] - qy[0] + hh * qy[3];
    end;
    c := qx[0];
    f := qy[0];
    nl := TLazIntfImage.Create(0, 0);
    try
      nl.DataDescription := li.DataDescription;
      nl.SetSize(ow, oh);
      for y := 0 to oh - 1 do
        for x := 0 to ow - 1 do
        begin
          u := (x + 0.5) / ow;
          v := (y + 0.5) / oh;
          den := g * u + hh * v + 1;
          sx := (a * u + b * v + c) / den - 0.5;
          sy := (d * u + e * v + f) / den - 0.5;
          sx0 := Floor(sx);
          sy0 := Floor(sy);
          dx := sx - sx0;
          dy := sy - sy0;
          for k := 0 to 5 do
          begin
            wx[k] := LanczosW(dx - (k - 2));
            wy[k] := LanczosW(dy - (k - 2));
          end;
          ra := 0; ga := 0; ba := 0; aa := 0; wsum := 0;
          for j := 0 to 5 do
          begin
            iy := Max(0, Min(h - 1, sy0 - 2 + j));
            for k := 0 to 5 do
            begin
              ix := Max(0, Min(w - 1, sx0 - 2 + k));
              wxy := wx[k] * wy[j];
              wsum := wsum + wxy;
              cr := iy * w + ix;
              aw := wxy * sa[cr];
              aa := aa + aw;
              ra := ra + aw * sr[cr];
              ga := ga + aw * sg[cr];
              ba := ba + aw * sb[cr];
            end;
          end;
          if (wsum < 1e-9) or (aa < 1e-6) then col := FPColor(0, 0, 0, 0)
          else
          begin
            col.red := Clamp255(ra / aa);
            col.green := Clamp255(ga / aa);
            col.blue := Clamp255(ba / aa);
            col.alpha := Clamp255(aa / wsum);
          end;
          // a point that falls outside of the picture is transparent
          if (sx < -0.5) or (sy < -0.5) or (sx > w - 0.5) or (sy > h - 0.5) then col := FPColor(0, 0, 0, 0);
          nl.Colors[x, y] := col;
        end;
      img.ImageData := PngBase64(nl);
    finally
      nl.Free;
    end;
  finally
    li.Free;
  end;
  // the picture keeps its scale; it is centred where the quadrilateral was
  cx := (PersX[0] + PersX[1] + PersX[2] + PersX[3]) / 4;
  cy := (PersY[0] + PersY[1] + PersY[2] + PersY[3]) / 4;
  bw := ow / fx;
  bh := oh / fy;
  img.P[0] := MakePt(cx - bw / 2, cy - bh / 2);
  img.P[1] := MakePt(cx + bw / 2, cy + bh / 2);
  img.Rot := 0;
  // the selections of the old picture do not fit the new one
  SetLength(ids, 0);
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.Shapes[i].SelTarget = img.Id then
    begin
      SetLength(ids, Length(ids) + 1);
      ids[High(ids)] := Doc.Shapes[i].Id;
    end;
  for i := 0 to High(ids) do
    if Doc.FindShape(ids[i]) <> nil then Doc.DeleteShape(Doc.FindShape(ids[i]));
  FlushImageCaches(img);
  if wasKey then SetImageKey(img, True, kc, kt);
  Commit;
  SetStatus('Perspective corrected: the picture is now ' + IntToStr(ow) + ' x ' + IntToStr(oh) + ' pixels.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

// the result of the correction, made from the reduced picture and drawn where the final picture will be
procedure TForm1.DrawPersPreview(cnv: TCanvas);
var
  i, j, k, ow, oh, pw, ph, x, y, sx0, sy0, ix, iy: Integer;
  qx, qy: array[0..3] of Double;
  sdx, sdy, a, b, c, d, e, f, g, hh, u, v, den, sx, sy, dx, dy, ex1, ey1, ex2, ey2, cross, cx, cy, bw, bh, ps: Double;
  sgn: Integer;
  bmp: TBGRABitmap;
  r, gg, bb, aa, w00, w10, w01, w11, wa: Double;

  function At(xx, yy: Integer; ch: Integer): Double;
  var
    q: Integer;
  begin
    q := Max(0, Min(PersSrcH - 1, yy)) * PersSrcW + Max(0, Min(PersSrcW - 1, xx));
    case ch of
      0: Result := PersR[q];
      1: Result := PersG[q];
      2: Result := PersB[q];
    else Result := PersA[q];
    end;
  end;

begin
  if PersSrcW < 1 then Exit;
  sgn := 0;
  for i := 0 to 3 do
  begin
    j := (i + 1) mod 4;
    k := (i + 2) mod 4;
    cross := (PersX[j] - PersX[i]) * (PersY[k] - PersY[j]) - (PersY[j] - PersY[i]) * (PersX[k] - PersX[j]);
    if Abs(cross) < 1e-9 then Exit;
    if sgn = 0 then sgn := Sign(cross) else if Sign(cross) <> sgn then Exit;
  end;
  // the corners in pixels of the full picture
  for i := 0 to 3 do
  begin
    qx[i] := (PersX[i] - PersLX1) * PersFx;
    qy[i] := (PersY[i] - PersLY1) * PersFy;
  end;
  ow := Round(Max(Hypot(qx[1] - qx[0], qy[1] - qy[0]), Hypot(qx[2] - qx[3], qy[2] - qy[3])));
  oh := Round(Max(Hypot(qx[3] - qx[0], qy[3] - qy[0]), Hypot(qx[2] - qx[1], qy[2] - qy[1])));
  if (ow < 2) or (oh < 2) then Exit;
  bw := ow / PersFx;
  bh := oh / PersFy;
  cx := (PersX[0] + PersX[1] + PersX[2] + PersX[3]) / 4;
  cy := (PersY[0] + PersY[1] + PersY[2] + PersY[3]) / 4;
  ps := Min(1, 200 / Max(ow, oh));
  pw := Max(2, Round(ow * ps));
  ph := Max(2, Round(oh * ps));
  // projective map of the unit square on the corners (in pixels of the reduced picture)
  for i := 0 to 3 do
  begin
    qx[i] := qx[i] * PersScale;
    qy[i] := qy[i] * PersScale;
  end;
  sdx := qx[0] - qx[1] + qx[2] - qx[3];
  sdy := qy[0] - qy[1] + qy[2] - qy[3];
  if (Abs(sdx) < 1e-9) and (Abs(sdy) < 1e-9) then
  begin
    g := 0; hh := 0;
    a := qx[1] - qx[0]; b := qx[3] - qx[0];
    d := qy[1] - qy[0]; e := qy[3] - qy[0];
  end
  else
  begin
    ex1 := qx[1] - qx[2]; ey1 := qy[1] - qy[2];
    ex2 := qx[3] - qx[2]; ey2 := qy[3] - qy[2];
    den := ex1 * ey2 - ex2 * ey1;
    if Abs(den) < 1e-12 then Exit;
    g := (sdx * ey2 - ex2 * sdy) / den;
    hh := (ex1 * sdy - sdx * ey1) / den;
    a := qx[1] - qx[0] + g * qx[1];
    b := qx[3] - qx[0] + hh * qx[3];
    d := qy[1] - qy[0] + g * qy[1];
    e := qy[3] - qy[0] + hh * qy[3];
  end;
  c := qx[0];
  f := qy[0];
  bmp := TBGRABitmap.Create(pw, ph, BGRA(0, 0, 0, 0));
  try
    for y := 0 to ph - 1 do
      for x := 0 to pw - 1 do
      begin
        u := (x + 0.5) / pw;
        v := (y + 0.5) / ph;
        den := g * u + hh * v + 1;
        sx := (a * u + b * v + c) / den - 0.5;
        sy := (d * u + e * v + f) / den - 0.5;
        if (sx < -0.5) or (sy < -0.5) or (sx > PersSrcW - 0.5) or (sy > PersSrcH - 0.5) then Continue;
        sx0 := Floor(sx);
        sy0 := Floor(sy);
        dx := sx - sx0;
        dy := sy - sy0;
        w00 := (1 - dx) * (1 - dy); w10 := dx * (1 - dy); w01 := (1 - dx) * dy; w11 := dx * dy;
        aa := At(sx0, sy0, 3) * w00 + At(sx0 + 1, sy0, 3) * w10 + At(sx0, sy0 + 1, 3) * w01 + At(sx0 + 1, sy0 + 1, 3) * w11;
        if aa < 0.5 then Continue;
        r := (At(sx0, sy0, 0) * At(sx0, sy0, 3) * w00 + At(sx0 + 1, sy0, 0) * At(sx0 + 1, sy0, 3) * w10 +
              At(sx0, sy0 + 1, 0) * At(sx0, sy0 + 1, 3) * w01 + At(sx0 + 1, sy0 + 1, 0) * At(sx0 + 1, sy0 + 1, 3) * w11) / aa;
        gg := (At(sx0, sy0, 1) * At(sx0, sy0, 3) * w00 + At(sx0 + 1, sy0, 1) * At(sx0 + 1, sy0, 3) * w10 +
               At(sx0, sy0 + 1, 1) * At(sx0, sy0 + 1, 3) * w01 + At(sx0 + 1, sy0 + 1, 1) * At(sx0 + 1, sy0 + 1, 3) * w11) / aa;
        bb := (At(sx0, sy0, 2) * At(sx0, sy0, 3) * w00 + At(sx0 + 1, sy0, 2) * At(sx0 + 1, sy0, 3) * w10 +
               At(sx0, sy0 + 1, 2) * At(sx0, sy0 + 1, 3) * w01 + At(sx0 + 1, sy0 + 1, 2) * At(sx0 + 1, sy0 + 1, 3) * w11) / aa;
        bmp.SetPixel(x, y, BGRA(Round(Min(255, r)), Round(Min(255, gg)), Round(Min(255, bb)), Round(Min(255, aa))));
      end;
    bmp.Draw(cnv, Rect(Round((cx - bw / 2) * Zoom), Round((cy - bh / 2) * Zoom), Round((cx + bw / 2) * Zoom),
      Round((cy + bh / 2) * Zoom)), False);
  finally
    bmp.Free;
  end;
  cnv.Pen.Style := psSolid;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := TColor($0080FF);
  cnv.Brush.Style := bsClear;
  cnv.Rectangle(Round((cx - bw / 2) * Zoom), Round((cy - bh / 2) * Zoom), Round((cx + bw / 2) * Zoom) + 1,
    Round((cy + bh / 2) * Zoom) + 1);
end;

procedure TForm1.DrawPersBox(cnv: TCanvas);
var
  i: Integer;
  pts: array[0..3] of TPoint;
begin
  cnv.Brush.Style := bsClear;
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psDot;
  cnv.Pen.Color := clGray;
  cnv.Rectangle(Round(PersLX1 * Zoom), Round(PersLY1 * Zoom), Round(PersLX2 * Zoom), Round(PersLY2 * Zoom));
  if PersDrag >= 0 then DrawPersPreview(cnv);        // the result, while a corner is moved
  for i := 0 to 3 do pts[i] := Point(Round(PersX[i] * Zoom), Round(PersY[i] * Zoom));
  cnv.Pen.Style := psDash;
  cnv.Pen.Width := 2;
  cnv.Pen.Color := TColor($0080FF);
  cnv.Polygon(pts);
  cnv.Pen.Style := psSolid;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := clBlack;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := TColor($0080FF);
  for i := 0 to 3 do
    cnv.Rectangle(pts[i].x - 5, pts[i].y - 5, pts[i].x + 6, pts[i].y + 6);
  cnv.Brush.Style := bsClear;
end;

procedure TForm1.CropStart(img: TShape);
var
  x1, y1, x2, y2: Double;
begin
  ImageBox(img, x1, y1, x2, y2);
  CropActive := True;
  CropId := img.Id;
  CropLX1 := x1; CropLY1 := y1; CropLX2 := x2; CropLY2 := y2;
  CropX1 := x1; CropY1 := y1; CropX2 := x2; CropY2 := y2;
  CropDrag := 0;
  SelClear;
  RefreshProps;
  SetStatus('Crop: drag the borders of the picture; click outside of them to confirm (Enter too), Esc to cancel.');
  Redraw;
end;

procedure TForm1.CropFinish(apply: Boolean);
var
  img: TShape;
begin
  if not CropActive then Exit;
  CropActive := False;
  CropDrag := 0;
  PaintBox1.Cursor := crDefault;
  img := Doc.FindShape(CropId);
  if apply and (img <> nil) and ((CropX1 > CropLX1 + 1e-6) or (CropY1 > CropLY1 + 1e-6) or
     (CropX2 < CropLX2 - 1e-6) or (CropY2 < CropLY2 - 1e-6)) then
    CropImage(img, CropX1, CropY1, CropX2, CropY2)
  else SetStatus('Crop: nothing changed.');
  if img <> nil then SelSet(MakeRef(img.Id, -1));
  RefreshProps;
  Redraw;
end;

// which edges of the frame are under the point (corners count as two)
function TForm1.CropHit(px, py: Double): Integer;
var
  t: Double;
  inX, inY: Boolean;
begin
  Result := 0;
  t := 8 / Zoom;
  inX := (px >= CropX1 - t) and (px <= CropX2 + t);
  inY := (py >= CropY1 - t) and (py <= CropY2 + t);
  if not (inX and inY) then Exit;
  if Abs(px - CropX1) <= t then Result := Result or 1
  else if Abs(px - CropX2) <= t then Result := Result or 2;
  if Abs(py - CropY1) <= t then Result := Result or 4
  else if Abs(py - CropY2) <= t then Result := Result or 8;
end;

procedure TForm1.CropMoveTo(px, py: Double);
var
  m: Double;
begin
  m := 2;
  if CropDrag and 1 <> 0 then CropX1 := Max(CropLX1, Min(px, CropX2 - m));
  if CropDrag and 2 <> 0 then CropX2 := Min(CropLX2, Max(px, CropX1 + m));
  if CropDrag and 4 <> 0 then CropY1 := Max(CropLY1, Min(py, CropY2 - m));
  if CropDrag and 8 <> 0 then CropY2 := Min(CropLY2, Max(py, CropY1 + m));
  StatusBar1.Panels[1].Text := Format('crop %d x %d', [Round(CropX2 - CropX1), Round(CropY2 - CropY1)]);
  Redraw;
end;

// the frame that is kept: dashed and orange, with a handle on every corner and side; the original limits are grey
procedure TForm1.DrawCropBox(cnv: TCanvas);
var
  i: Integer;
  hx, hy: array[0..7] of Integer;
  x1, y1, x2, y2, xm, ym: Integer;
begin
  cnv.Brush.Style := bsClear;
  cnv.Pen.Width := 1;
  cnv.Pen.Style := psDot;
  cnv.Pen.Color := clGray;
  cnv.Rectangle(Round(CropLX1 * Zoom), Round(CropLY1 * Zoom), Round(CropLX2 * Zoom), Round(CropLY2 * Zoom));
  x1 := Round(CropX1 * Zoom);
  y1 := Round(CropY1 * Zoom);
  x2 := Round(CropX2 * Zoom);
  y2 := Round(CropY2 * Zoom);
  cnv.Pen.Style := psDash;
  cnv.Pen.Width := 2;
  cnv.Pen.Color := TColor($0080FF);
  cnv.Rectangle(x1, y1, x2, y2);
  cnv.Pen.Style := psSolid;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := clBlack;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := TColor($0080FF);
  xm := (x1 + x2) div 2;
  ym := (y1 + y2) div 2;
  hx[0] := x1; hy[0] := y1; hx[1] := xm; hy[1] := y1; hx[2] := x2; hy[2] := y1;
  hx[3] := x2; hy[3] := ym; hx[4] := x2; hy[4] := y2; hx[5] := xm; hy[5] := y2;
  hx[6] := x1; hy[6] := y2; hx[7] := x1; hy[7] := ym;
  for i := 0 to 7 do
    cnv.Rectangle(hx[i] - 4, hy[i] - 4, hx[i] + 5, hy[i] + 5);
  cnv.Brush.Style := bsClear;
end;

procedure TForm1.CropImage(img: TShape; rx1, ry1, rx2, ry2: Double);
var
  raw: TGraphic;
  li, nl: TLazIntfImage;
  w, h, bx1, by1, bx2, by2, x, y: Integer;
  x1, y1, x2, y2, fx, fy: Double;
  wasKey: Boolean;
  kc, kt: Integer;
begin
  ImageBox(img, x1, y1, x2, y2);
  wasKey := img.KeyOn;
  kc := img.KeyColor;
  kt := img.KeyTol;
  Checkpoint;
  if wasKey then SetImageKey(img, False, kc, kt);        // the original picture is the one that is cropped
  raw := RawImage(img);
  if raw = nil then
  begin
    Commit;
    Exit;
  end;
  li := RgbaOf(raw);
  try
    w := li.Width;
    h := li.Height;
    fx := w / (x2 - x1);
    fy := h / (y2 - y1);
    bx1 := Max(0, Floor((rx1 - x1) * fx + 0.5));
    by1 := Max(0, Floor((ry1 - y1) * fy + 0.5));
    bx2 := Min(w, Floor((rx2 - x1) * fx + 0.5));
    by2 := Min(h, Floor((ry2 - y1) * fy + 0.5));
    if (bx2 - bx1 < 1) or (by2 - by1 < 1) then
    begin
      SetStatus('Crop: the rectangle is outside the picture.');
      if wasKey then SetImageKey(img, True, kc, kt);
      Commit;
      Exit;
    end;
    nl := TLazIntfImage.Create(0, 0);
    try
      nl.DataDescription := li.DataDescription;
      nl.SetSize(bx2 - bx1, by2 - by1);
      for y := 0 to by2 - by1 - 1 do
        for x := 0 to bx2 - bx1 - 1 do
          nl.Colors[x, y] := li.Colors[bx1 + x, by1 + y];
      img.ImageData := PngBase64(nl);
    finally
      nl.Free;
    end;
  finally
    li.Free;
  end;
  img.P[0] := MakePt(x1 + bx1 / fx, y1 + by1 / fy);
  img.P[1] := MakePt(x1 + bx2 / fx, y1 + by2 / fy);
  img.Rot := 0;
  FlushImageCaches(img);
  if wasKey then SetImageKey(img, True, kc, kt);
  Commit;
  SetStatus('Cropped to ' + IntToStr(bx2 - bx1) + ' x ' + IntToStr(by2 - by1) + ' pixels.');
  RefreshProps;
  Redraw;
end;

procedure TForm1.SelToolUp;
var
  s, img: TShape;
  ok: Boolean;
  i: Integer;
  x1, y1, x2, y2: Double;
begin
  s := Creating;
  Creating := nil;
  Drag := dmNone;
  SetLength(CreateSnaps, 0);
  img := Doc.FindShape(ToolImg);
  case s.Kind of
    skRect: ok := (Abs(s.P[1].x - s.P[0].x) > 3 / Zoom) and (Abs(s.P[1].y - s.P[0].y) > 3 / Zoom);
    skEllipse: ok := (s.RX > 1.5 / Zoom) and (s.RY > 1.5 / Zoom);
  else
    begin
      // the point that was put twice when the button went down
      if (Length(s.P) > 2) and (Hypot(s.P[1].x - s.P[0].x, s.P[1].y - s.P[0].y) < 1e-9) then Delete(s.P, 1, 1);
      ok := Length(s.P) >= 3;
      if ok then
      begin
        x1 := 1e30; y1 := 1e30; x2 := -1e30; y2 := -1e30;
        for i := 0 to High(s.P) do
        begin
          x1 := Min(x1, s.P[i].x); x2 := Max(x2, s.P[i].x);
          y1 := Min(y1, s.P[i].y); y2 := Max(y2, s.P[i].y);
        end;
        ok := (x2 - x1 > 3 / Zoom) and (y2 - y1 > 3 / Zoom);
      end;
    end;
  end;
  if (not ok) or (img = nil) then
  begin
    s.Free;
    // a click without dragging takes the selection away, as it does in Paint
    if (img <> nil) and (SelMode = 0) and (Length(SelListOf(img)) > 0) then
    begin
      SelClear;
      for i := Doc.Shapes.Count - 1 downto 0 do
        if Doc.Shapes[i].SelTarget = img.Id then Doc.DeleteShape(Doc.Shapes[i]);
      Commit;
      RefreshLayers;
      RefreshProps;
    end;
    Redraw;
    Exit;
  end;
  Doc.AddShape(s);
  s.SelTarget := img.Id;
  s.SelHole := False;
  s.SelWand := False;
  s.SelTol := DefWandTol;
  s.IsRef := True;
  s.LayerId := img.LayerId;
  SelRegister(s, img);
  Commit;
  SelSet(MakeRef(s.Id, -1));
  SetStatus('Selection made: drag inside it to move the pixels (Ctrl: copy); Shift adds, Shift+Ctrl subtracts.');
  RefreshLayers;
  RefreshProps;
  Redraw;
end;

procedure TForm1.CreateMove(px, py: Double; Shift: TShiftState);
var
  ref: TRef;
  pt: TPt;
  n: Integer;
  dxy: Double;

  function AngleOf(const s: TShape; x, y: Double): Double;
  begin
    Result := ArcTan2((y - s.P[0].y) / Max(s.RY, 0.5), (x - s.P[0].x) / Max(s.RX, 0.5));
  end;

begin
  if Creating = nil then Exit;
  if Tool in [tlSelRect, tlSelEllipse, tlSelFree] then
  begin
    SelToolMove(px, py, Shift);
    Exit;
  end;
  HasSnap := SnapTo(px, py, nil, ref, pt);
  if HasSnap then
  begin
    px := pt.x;
    py := pt.y;
    SnapTarget := ref;
  end;
  case Creating.Kind of
    skLine, skArrow, skRect:
      if Drag = dmCreate then
      begin
        Creating.P[1] := MakePt(px, py);
        if ssShift in Shift then
          if Creating.Kind = skRect then
          begin
            dxy := Max(Abs(px - Creating.P[0].x), Abs(py - Creating.P[0].y));
            Creating.P[1] := MakePt(Creating.P[0].x + Sign(px - Creating.P[0].x) * dxy,
              Creating.P[0].y + Sign(py - Creating.P[0].y) * dxy);
          end
          else if Abs(px - Creating.P[0].x) > Abs(py - Creating.P[0].y) then
            Creating.P[1].y := Creating.P[0].y
          else Creating.P[1].x := Creating.P[0].x;
        if Length(CreateSnaps) > 1 then
        begin
          if HasSnap then CreateSnaps[1] := ref else FillChar(CreateSnaps[1], SizeOf(TRef), 0);
        end;
      end;
    skEllipse, skArc:
      begin
        if (Drag = dmCreate) and (ArcStage = 0) then
        begin
          // Shift pressed (also while dragging): a circle
          Creating.Circ := DefCirc xor (ssShift in Shift);
          if Creating.Circ then
          begin
            Creating.RX := Max(0.5, Hypot(px - Creating.P[0].x, py - Creating.P[0].y));
            Creating.RY := Creating.RX;
          end
          else
          begin
            Creating.RX := Max(0.5, Abs(px - Creating.P[0].x));
            Creating.RY := Max(0.5, Abs(py - Creating.P[0].y));
          end;
        end
        else if ArcStage = 1 then
        begin
          Creating.A1 := AngleOf(Creating, px, py);
          Creating.A2 := Creating.A1 + 0.3;
        end
        else if ArcStage = 2 then
          Creating.A2 := AngleOf(Creating, px, py);
      end;
    skPolyline, skPolygon, skSpline:
      if Creating.Reg then
      begin
        if Drag = dmCreate then Creating.P := RegularPoints(RegCenter, MakePt(px, py), Length(Creating.P));
      end
      else
      begin
        n := Length(Creating.P);
        Creating.P[n - 1] := MakePt(px, py);
      end;
  end;
  Redraw;
end;

procedure TForm1.CreateUp(px, py: Double; Shift: TShiftState);
var
  ok: Boolean;
begin
  if Creating = nil then Exit;
  if Drag <> dmCreate then Exit;
  if Tool in [tlSelRect, tlSelEllipse, tlSelFree] then
  begin
    SelToolUp;
    Exit;
  end;
  case Creating.Kind of
    skLine, skArrow:
      ok := Dist(Creating.P[0], Creating.P[1]) > 3 / Zoom;
    skRect:
      ok := (Abs(Creating.P[1].x - Creating.P[0].x) > 3 / Zoom) and (Abs(Creating.P[1].y - Creating.P[0].y) > 3 / Zoom);
    skEllipse:
      ok := (Creating.RX > 3 / Zoom) and (Creating.RY > 3 / Zoom);
    skArc:
      begin
        ok := (Creating.RX > 3 / Zoom) and (Creating.RY > 3 / Zoom);
        if ok then
        begin
          ArcStage := 1;
          Drag := dmNone;
          SetStatus('Arc: click to set the start, then click to set the end.');
          Redraw;
          Exit;
        end;
      end;
    skPolygon:
      ok := Creating.Reg and (Dist(Creating.P[0], RegCenter) > 3 / Zoom);
  else
    ok := False;
  end;
  FinishCreating(ok);
end;

{ ================= select tool ================= }

procedure TForm1.SelectDown(px, py: Double; Shift: TShiftState; X, Y: Integer);
var
  ref: TRef;
  q: TConstraint;
  edge: Integer;
  i, n, sideAt: Integer;
  ts: TShapeArray;
  s: TShape;
  whole: Boolean;
  gx1, gy1, gx2, gy2, gcx, gcy, ghw, ghh: Double;
  p0: TPt;
  moveOk: Boolean;
begin
  Checkpoint;
  Moved := False;
  HasSnap := False;
  q := HitQuote(X, Y);
  if q <> nil then
  begin
    RotMode := False;
    SelClear;
    SelQuote := q;
    Drag := dmQuote;
    RefreshProps;
    Redraw;
    Exit;
  end;
  if RotMode then
  begin
    i := RotHit(px, py);
    if i = 8 then
    begin
      RotAng0 := ArcTan2(py - RotCY, px - RotCX);
      RotBase := RotTotal;
      Drag := dmRotate;
      Exit;
    end;
    if i >= 0 then
    begin
      // the box in the frame of the selection: the side / corner opposite to the handle stays where it is
      if GroupFrame(RotIds, RotTotal, gcx, gcy, ghw, ghh) then
      begin
        p0 := TurnPt(MakePt(gcx, gcy), MakePt(0, 0), -RotTotal);
        gx1 := p0.x - ghw;
        gx2 := p0.x + ghw;
        gy1 := p0.y - ghh;
        gy2 := p0.y + ghh;
        GroupHandlePoint(i, gx1, gy1, gx2, gy2, RotHx, RotHy);
        if i in [0, 6, 7] then RotAx := gx2 else RotAx := gx1;
        if i in [0, 1, 2] then RotAy := gy2 else RotAy := gy1;
        RotDrag := i;
        RotSx := 1;
        RotSy := 1;
        RotKx := 0;
        RotKy := 0;
        RotSaveImages(False);
        Drag := dmDeform;
      end;
      Exit;
    end;
    // inside the box: the selection is moved and the handles stay
    p0 := TurnPt(MakePt(px, py), MakePt(RotCX, RotCY), -RotTotal);
    moveOk := (Abs(p0.x - RotCX) <= RotHW) and (Abs(p0.y - RotCY) <= RotHH);
    RotPickOn := False;
    if moveOk and not AllRasterShapes(SelShapes) then
      // any point of the box drags the selection; a click that does not move on another (unselected) object picks that object
      if HitShapeSel(px, py, ref) and (Doc.FindShape(ref.Shape) <> nil) and not IsSelShape(Doc.FindShape(ref.Shape)) then
      begin
        RotPickOn := True;
        RotPickRef := MakeRef(ref.Shape, -1);
      end;
    if moveOk then
    begin
      ts := SelShapes;
      for i := 0 to High(ts) do
        if Doc.IsPinned(ts[i].Id, 0) then
        begin
          SetStatus('Part of the selection is fixed.');
          Exit;
        end;
      Drag := dmShape;
      Exit;
    end;
    RotMode := False;
    Redraw;
  end;
  // the corner and the edges of the page win over the handle of an object that lies on it: otherwise the page could not be resized
  edge := PageEdgeAt(X, Y);
  if edge <> 0 then
  begin
    DragPageEdge := edge;
    Drag := dmPage;
    Exit;
  end;
  i := HitGroupHandle(px, py);
  if i >= 0 then
  begin
    DbgLog('SelectDown: group handle ' + IntToStr(i));
    SelGroupIds(GrpIds);
    GrpAng := GroupAngle(GrpIds);
    // the box in the frame of the group (the frame is the document's when the group has not been turned)
    GroupFrame(GrpIds, GrpAng, gcx, gcy, ghw, ghh);
    p0 := TurnPt(MakePt(gcx, gcy), MakePt(0, 0), -GrpAng);
    gx1 := p0.x - ghw;
    gx2 := p0.x + ghw;
    gy1 := p0.y - ghh;
    gy2 := p0.y + ghh;
    DragGrp := i;
    // the corner / side opposite to the handle stays where it is
    if i in [0, 6, 7] then GrpAx := gx2 else GrpAx := gx1;
    if i in [0, 1, 2] then GrpAy := gy2 else GrpAy := gy1;
    Drag := dmGroup;
    Exit;
  end;
  if HitHandle(px, py, ref) then
  begin
    DbgLog('SelectDown: handle idx=' + IntToStr(ref.Idx) + ' shape=' + IntToStr(ref.Shape));
    DragRef := ref;
    if ref.Idx >= HandlePathBase then
    begin
      // a point of a path: Shift adds it to (or takes it out of) the selected points
      FreeOn := False;
      if ssShift in Shift then SelToggle(ref)
      else if SelFind(ref) < 0 then SelSet(ref);
      if SelFind(ref) >= 0 then Drag := dmHandle else Drag := dmNone;
    end
    else if ref.Idx >= HandleRX then
    begin
      if SelFind(MakeRef(ref.Shape, -1)) < 0 then SelSet(MakeRef(ref.Shape, -1));
      Drag := dmHandle;
    end
    else
    begin
      FreeOn := False;
      s := Doc.FindShape(ref.Shape);
      if (ssShift in Shift) and not ((s <> nil) and (s.Kind in [skLine, skArrow])) then SelToggle(ref)
      else if SelFind(ref) < 0 then SelSet(ref);
      // Shift+click on a selected point takes it out of the selection: nothing to drag
      if SelFind(ref) >= 0 then Drag := dmPoint else Drag := dmNone;
    end;
    RefreshProps;
    Redraw;
    Exit;
  end;
  // inside the area that is selected on a raster: dragging takes the pixels along (Ctrl: a copy of them)
  if not (ssShift in Shift) then
  begin
    s := SelInsideAt(px, py);
    if s <> nil then
    begin
      StartPixDrag(s, Shift);
      Exit;
    end;
  end;
  if ((ssShift in Shift) and HitShape(px, py, ref)) or (not (ssShift in Shift) and HitShapeSel(px, py, ref)) then
  begin
    s := Doc.FindShape(ref.Shape);
    if (ssShift in Shift) and (s <> nil) and (s.GroupId > 0) then
    begin
      // a group is taken in or out of the selection as a whole
      if SelFind(MakeRef(ref.Shape, -1)) >= 0 then
      begin
        for i := High(Sel) downto 0 do
          if (Doc.FindShape(Sel[i].Shape) <> nil) and (Doc.FindShape(Sel[i].Shape).GroupId = s.GroupId) then Delete(Sel, i, 1);
        SelQuote := nil;
      end
      else
      begin
        SetLength(Sel, Length(Sel) + 1);
        Sel[High(Sel)] := MakeRef(ref.Shape, -1);
        ExpandGroups;
      end;
    end
    else if ssShift in Shift then
    begin
      // sides of a polygon / polyline: several of them can be selected at once (for the constraints)
      sideAt := -2;
      whole := False;
      if ref.Seg >= 0 then
      begin
        for i := 0 to High(Sel) do
          if (Sel[i].Shape = ref.Shape) and (Sel[i].Idx = -1) then
          begin
            if Sel[i].Seg < 0 then whole := True
            else if Sel[i].Seg = ref.Seg then sideAt := i
            else if sideAt = -2 then sideAt := -3;
          end;
        s := Doc.FindShape(ref.Shape);
        if (s = nil) or not (s.Kind in [skPolyline, skPolygon]) then sideAt := -2
        else if whole then sideAt := -2;
      end;
      if sideAt >= 0 then
      begin
        Delete(Sel, sideAt, 1);
        SelQuote := nil;
      end
      else if sideAt = -3 then
      begin
        SetLength(Sel, Length(Sel) + 1);
        Sel[High(Sel)] := ref;
        SelQuote := nil;
      end
      else SelToggle(ref);
    end
    else if (SelFind(ref) < 0) then
    begin
      // already part of the selection through another ref of the same shape?
      ts := SelShapes;
      i := 0;
      while (i <= High(ts)) and (ts[i].Id <> ref.Shape) do Inc(i);
      if (i > High(ts)) or (Length(Sel) = 1) then SelSet(ref)
      else
      begin
        // keep multi selection when dragging one of its members; refresh the segment hint
        SelSet(ref);
      end;
    end;
    // remember the segment hint for constraints
    n := 0;
    for i := 0 to High(Sel) do
      if SameRef(Sel[i], ref) then Inc(n);
    if n = 1 then
      for i := 0 to High(Sel) do
        if SameRef(Sel[i], ref) then Sel[i].Seg := ref.Seg;
    ExpandGroups;
    DbgLog('SelectDown: shape drag of ' + IntToStr(ref.Shape));
    // a raster is only selected by a click: it is moved and resized after a double click (the handles of the second mode)
    if AllRasterShapes(SelShapes) then Drag := dmNone
    else Drag := dmShape;
    RefreshProps;
    Redraw;
    Exit;
  end;
  edge := PageEdgeAt(X, Y);
  if edge <> 0 then
  begin
    DragPageEdge := edge;
    Drag := dmPage;
    Exit;
  end;
  // Shift with a figure that has control points selected: the band picks points, not figures
  BandPoints := False;
  if ssShift in Shift then
  begin
    ts := SelShapes;
    for i := 0 to High(ts) do
      if (ts[i].GroupId = 0) and ((ts[i].Kind in [skSpline, skPolyline, skPolygon]) or ((ts[i].Kind = skPath) and not ts[i].Bucket)) then BandPoints := True;
  end;
  if not (ssShift in Shift) then SelClear;
  BandOn := True;
  Drag := dmBand;
  RefreshProps;
  Redraw;
end;

procedure TForm1.DragSolve;
var
  refs: TRefArray;
  i, n: Integer;
begin
  SetLength(refs, 0);
  case Drag of
    dmPoint:
      begin
        // the dragged point and the other selected points move together
        SetLength(refs, 1);
        refs[0] := DragRef;
        for i := 0 to High(Sel) do
          if (Sel[i].Idx >= 0) and (Sel[i].Idx < HandleRX) and not SameRef(MakeRef(Sel[i].Shape, Sel[i].Idx), DragRef) then
          begin
            SetLength(refs, Length(refs) + 1);
            refs[High(refs)] := MakeRef(Sel[i].Shape, Sel[i].Idx);
          end;
      end;
    dmHandle:
      if DragRef.Idx < HandlePathBase then
      begin
        SetLength(refs, 1);
        refs[0] := DragRef;
      end;
    dmShape:
      begin
        n := 0;
        SetLength(refs, Length(Sel));
        for i := 0 to High(Sel) do
        begin
          if Sel[i].Idx >= 0 then
            refs[n] := MakeRef(Sel[i].Shape, -1)
          else
            refs[n] := MakeRef(Sel[i].Shape, -1);
          Inc(n);
        end;
        SetLength(refs, n);
      end;
  end;
  Doc.Solve(refs);
end;

// the status bar says why a copy does not move
procedure TForm1.TiedWarning(s: TShape);
var
  what: string;
begin
  if s.ArrId > 0 then what := 'an item of an array'
  else if s.MirSrc > 0 then what := 'a mirror copy'
  else what := 'an offset copy';
  SetStatus('Not allowed: this is ' + what + ', tied to its parent. Right-click it and choose "Detach from its parent".');
end;

procedure TForm1.SelectMove(px, py: Double; Shift: TShiftState);
var
  dx, dy, rnew: Double;
  s: TShape;
  i, j: Integer;
  ts: TShapeArray;
  pinned, straight: Boolean;
  ref: TRef;
  pt: TPt;
  nx, ny, a: Double;
  gx1, gy1, gx2, gy2, gsx, gsy, cx, cy: Double;
  n: Integer;
  pv0, pv1: TPt;
  lx, ly: Double;
  pxs, pys: TDblArr;
  pctl: TBoolDyn;
  panc: TIntDyn;
  pks: TIntDyn;
  k: Integer;
  res0, adx, ady: Double;
  okMove: Boolean;
  rgA, rgB, rgR, rgI, rgD, rgQr, rgQi: Double;
  rgN, rgM: Integer;
  rgOne: Boolean;
begin
  if Drag = dmPix then
  begin
    // the pixels are lifted when the pointer starts to move (a click only selects)
    if Hypot(px - LastX, py - LastY) < 3 / Zoom then Exit;
    SetLength(ts, 0);
    for i := 0 to High(PixIds) do
      if Doc.FindShape(PixIds[i]) <> nil then
      begin
        SetLength(ts, Length(ts) + 1);
        ts[High(ts)] := Doc.FindShape(PixIds[i]);
      end;
    s := PixLift(ts, PixCopy);
    DbgLog('Lift n=' + IntToStr(Length(ts)) + ' ok=' + BoolToStr(s <> nil, True));
    if s = nil then
    begin
      Drag := dmNone;
      Exit;
    end;
    SelSet(MakeRef(s.Id, -1));
    Drag := dmShape;
    RefreshProps;
  end;
  lx := px;
  ly := py;
  dx := px - LastX;
  dy := py - LastY;
  // a copy cannot be edited or moved by itself: it follows its parent
  if (Drag in [dmPoint, dmHandle]) and (Doc.FindShape(DragRef.Shape) <> nil) and
     (Doc.ParentOf(Doc.FindShape(DragRef.Shape)) <> nil) then
  begin
    TiedWarning(Doc.FindShape(DragRef.Shape));
    Exit;
  end;
  if Drag = dmShape then
  begin
    ts := SelShapes;
    for i := 0 to High(ts) do
      if (Doc.ParentOf(ts[i]) <> nil) and (SelFind(MakeRef(Doc.ParentOf(ts[i]).Id, -1)) < 0) then
      begin
        TiedWarning(ts[i]);
        Exit;
      end;
  end;
  case Drag of
    dmPoint:
      begin
        s := Doc.FindShape(DragRef.Shape);
        if s = nil then Exit;
        if Doc.IsPinned(s.Id, DragRef.Idx) then
        begin
          SetStatus('This point is fixed.');
          Exit;
        end;
        // the other selected points must be free too
        for i := 0 to High(Sel) do
          if (Sel[i].Idx >= 0) and (Sel[i].Idx < HandleRX) and Doc.IsPinned(Sel[i].Shape, Sel[i].Idx) then
          begin
            SetStatus('Part of the selected points is fixed.');
            Exit;
          end;
        if (s.Rot <> 0) and (s.Kind in [skRect, skImage]) and (DragRef.Idx <= 3) and (DragRef.Idx < Length(s.P)) and (Length(s.P) >= 2) then
        begin
          // a turned rectangle: the corner moves in the frame of the rectangle, the opposite one stays where it is seen
          pv0 := TurnPt(s.P[DragRef.Idx xor 1], ShapePivot(s), s.Rot);
          s.P[DragRef.Idx].x := s.P[DragRef.Idx].x + dx * Cos(s.Rot) - dy * Sin(s.Rot);
          s.P[DragRef.Idx].y := s.P[DragRef.Idx].y + dx * Sin(s.Rot) + dy * Cos(s.Rot);
          pv1 := TurnPt(s.P[DragRef.Idx xor 1], ShapePivot(s), s.Rot);
          s.Translate(pv0.x - pv1.x, pv0.y - pv1.y);
          HasSnap := False;
          DragSolve;
          Moved := True;
          LastX := px;
          LastY := py;
          Exit;
        end;
        nx := s.P[DragRef.Idx].x + dx;
        ny := s.P[DragRef.Idx].y + dy;
        // Shift: the segment that ends in the point becomes horizontal or vertical
        straight := False;
        if (ssShift in Shift) and (s.Kind in [skLine, skArrow, skPolyline, skPolygon]) and (Length(s.P) >= 2) then
        begin
          if s.Kind in [skLine, skArrow] then j := 1 - DragRef.Idx
          else if DragRef.Idx > 0 then j := DragRef.Idx - 1
          else if s.Kind = skPolygon then j := High(s.P)
          else j := 1;
          if (j >= 0) and (j <= High(s.P)) and (j <> DragRef.Idx) then
          begin
            if not FreeOn then
            begin
              FreeX := s.P[DragRef.Idx].x;
              FreeY := s.P[DragRef.Idx].y;
              FreeOn := True;
            end;
            FreeX := FreeX + dx;
            FreeY := FreeY + dy;
            if Abs(FreeX - s.P[j].x) > Abs(FreeY - s.P[j].y) then
            begin
              nx := FreeX;
              ny := s.P[j].y;
            end
            else
            begin
              nx := s.P[j].x;
              ny := FreeY;
            end;
            straight := True;
          end;
        end
        else FreeOn := False;
        if straight then HasSnap := False
        else HasSnap := SnapTo(px, py, s, ref, pt);
        if HasSnap then
        begin
          nx := pt.x;
          ny := pt.y;
          SnapTarget := ref;
        end;
        // a regular polygon: the corner that is dragged resizes (and turns) the whole shape about the opposite corner (or the middle of
        // the opposite side), which stays where it is; if the constraints do not allow it, the solver moves it
        rgN := Length(s.P);
        rgOne := s.Reg and (rgN >= 3) and (DragRef.Idx < rgN);
        if rgOne then
          for i := 0 to High(Sel) do
            if (Sel[i].Idx >= 0) and (Sel[i].Idx < HandleRX) and
               not ((Sel[i].Shape = DragRef.Shape) and (Sel[i].Idx = DragRef.Idx)) then rgOne := False;
        if rgOne then
        begin
          if rgN mod 2 = 0 then
          begin
            rgM := (DragRef.Idx + rgN div 2) mod rgN;
            rgA := s.P[rgM].x;
            rgB := s.P[rgM].y;
          end
          else
          begin
            rgM := (DragRef.Idx + rgN div 2) mod rgN;
            rgA := (s.P[rgM].x + s.P[(rgM + 1) mod rgN].x) / 2;
            rgB := (s.P[rgM].y + s.P[(rgM + 1) mod rgN].y) / 2;
          end;
          // z' = A + (z - A) * (T - A) / (V - A)
          rgR := s.P[DragRef.Idx].x - rgA;
          rgI := s.P[DragRef.Idx].y - rgB;
          rgD := rgR * rgR + rgI * rgI;
          if rgD > 1e-9 then
          begin
            rgQr := ((nx - rgA) * rgR + (ny - rgB) * rgI) / rgD;
            rgQi := ((ny - rgB) * rgR - (nx - rgA) * rgI) / rgD;
            if Hypot(nx - rgA, ny - rgB) > 1 / Zoom then
            begin
              for i := 0 to rgN - 1 do
              begin
                dx := s.P[i].x - rgA;
                dy := s.P[i].y - rgB;
                s.P[i].x := rgA + dx * rgQr - dy * rgQi;
                s.P[i].y := rgB + dx * rgQi + dy * rgQr;
              end;
              DragSolve;
              Moved := True;
            end;
            LastX := px;
            LastY := py;
            Exit;
          end;
        end;
        // the same shift for every other selected point
        dx := nx - s.P[DragRef.Idx].x;
        dy := ny - s.P[DragRef.Idx].y;
        for i := 0 to High(Sel) do
          if (Sel[i].Idx >= 0) and (Sel[i].Idx < HandleRX) and
             not ((Sel[i].Shape = DragRef.Shape) and (Sel[i].Idx = DragRef.Idx)) then
          begin
            if Doc.FindShape(Sel[i].Shape) <> nil then
              with Doc.FindShape(Sel[i].Shape) do
                if Sel[i].Idx <= High(P) then
                begin
                  P[Sel[i].Idx].x := P[Sel[i].Idx].x + dx;
                  P[Sel[i].Idx].y := P[Sel[i].Idx].y + dy;
                end;
          end;
        s.P[DragRef.Idx].x := nx;
        s.P[DragRef.Idx].y := ny;
        if (s.Kind = skRect) or (ssShift in Shift) then ;
        DragSolve;
        Moved := True;
      end;
    dmShape:
      begin
        ts := SelShapes;
        pinned := False;
        for i := 0 to High(ts) do
          for j := 0 to High(ts[i].P) do
            if Doc.IsPinned(ts[i].Id, j) then pinned := True;
        if pinned then
        begin
          SetStatus('Part of the selection is fixed.');
          Exit;
        end;
        // a single raster is attracted by the borders of the image (the arrow keys do not use this)
        if not Moved then begin EdgeOX := 0; EdgeOY := 0; end;
        if (Length(ts) = 1) and (ts[0].Kind = skImage) and (ts[0].Rot = 0) and (Length(ts[0].P) >= 2) then
        begin
          ImageBox(ts[0], gx1, gy1, gx2, gy2);
          gsx := gx1 - EdgeOX + dx;
          gsy := gy1 - EdgeOY + dy;
          cx := gx2 - gx1;
          cy := gy2 - gy1;
          a := 8 / Zoom;
          nx := 0;
          ny := 0;
          if Abs(gsx) < a then nx := -gsx
          else if Abs(gsx + cx - Doc.Width) < a then nx := Doc.Width - cx - gsx;
          if Abs(gsy) < a then ny := -gsy
          else if Abs(gsy + cy - Doc.Height) < a then ny := Doc.Height - cy - gsy;
          dx := dx + (nx - EdgeOX);
          dy := dy + (ny - EdgeOY);
          EdgeOX := nx;
          EdgeOY := ny;
        end;
        res0 := 0;
        if Doc.Cons.Count > 0 then
        begin
          res0 := Doc.ConstraintsResidual;
          Doc.GeomKeep;
        end;
        for i := 0 to High(ts) do
          if not ts[i].Bucket then ts[i].Translate(dx, dy);
        DragSolve;
        adx := dx;
        ady := dy;
        if (Doc.Cons.Count > 0) and (Doc.ConstraintsResidual > Max(0.05, res0 + 0.05)) then
        begin
          // the constraints do not allow this move: only along one axis, or not at all
          okMove := False;
          for k := 0 to 1 do
          begin
            Doc.GeomBack;
            if k = 0 then begin adx := dx; ady := 0; end else begin adx := 0; ady := dy; end;
            if (adx = 0) and (ady = 0) then Continue;
            for i := 0 to High(ts) do
              if not ts[i].Bucket then ts[i].Translate(adx, ady);
            DragSolve;
            if Doc.ConstraintsResidual <= Max(0.05, res0 + 0.05) then
            begin
              okMove := True;
              Break;
            end;
          end;
          if not okMove then
          begin
            Doc.GeomBack;
            adx := 0;
            ady := 0;
            SetStatus('The constraints do not allow this movement.');
          end;
          // the pointer is followed only for what has been done
          lx := LastX + adx;
          ly := LastY + ady;
        end;
        if RotMode then
        begin
          // the box follows the shapes also when the constraints deform them while they are dragged
          if not GroupFrame(RotIds, RotTotal, gx1, gy1, gx2, gy2) then
          begin
            gx1 := RotCX + adx;
            gy1 := RotCY + ady;
            gx2 := RotHW;
            gy2 := RotHH;
          end;
          RotCX := gx1;
          RotCY := gy1;
          RotHW := gx2;
          RotHH := gy2;
        end;
        Moved := True;
      end;
    dmHandle:
      begin
        s := Doc.FindShape(DragRef.Shape);
        if s = nil then Exit;
        if (s.Rot <> 0) and RotKind(s.Kind) and (Length(s.P) > 0) then
        begin
          // the pointer in the frame of the turned shape
          pv0 := TurnPt(MakePt(px, py), ShapePivot(s), -s.Rot);
          px := pv0.x;
          py := pv0.y;
        end;
        if (DragRef.Idx >= HandlePathBase) and (s.Kind = skPath) and (Length(s.P) > 0) then
        begin
          s.PathHandles(pxs, pys, pctl, panc);
          k := DragRef.Idx - HandlePathBase;
          if (k >= 0) and (k <= High(pxs)) then
          begin
            SetLength(pks, 0);
            for i := 0 to High(Sel) do
              if (Sel[i].Shape = s.Id) and (Sel[i].Idx >= HandlePathBase) then
              begin
                SetLength(pks, Length(pks) + 1);
                pks[High(pks)] := Sel[i].Idx - HandlePathBase;
              end;
            if Length(pks) = 0 then
            begin
              SetLength(pks, 1);
              pks[0] := k;
            end;
            s.MovePathPoints(pks, px - s.P[0].x - pxs[k], py - s.P[0].y - pys[k]);
          end;
          DragSolve;
          Moved := True;
          Exit;
        end;
        case DragRef.Idx of
          HandleRX:
            begin
              if (s.Kind = skArc) and (s.FA > 0) then
              begin
                // a fillet: the radius follows the pointer along the bisector of the corner, within the lines
                if Doc.FilletRadiusAt(s, px, py, rnew) then
                begin
                  s.RX := rnew;
                  s.RY := rnew;
                end;
              end
              else
              begin
                s.RX := Max(0.5, Abs(px - s.P[0].x));
                if s.Circ then s.RY := s.RX;
              end;
              if s.FA > 0 then Doc.UpdateFillets;
            end;
          HandleRY: s.RY := Max(0.5, Abs(py - s.P[0].y));
          HandleCorner:
            if Length(s.P) >= 2 then
              s.Corner := Max(0, Min(px - Min(s.P[0].x, s.P[1].x),
                Min(Abs(s.P[1].x - s.P[0].x), Abs(s.P[1].y - s.P[0].y)) / 2));
          HandleA1:
            s.A1 := ArcTan2((py - s.P[0].y) / Max(s.RY, 0.5), (px - s.P[0].x) / Max(s.RX, 0.5));
          HandleA2:
            s.A2 := ArcTan2((py - s.P[0].y) / Max(s.RY, 0.5), (px - s.P[0].x) / Max(s.RX, 0.5));
        end;
        if DragRef.Idx <= HandleRY then DragSolve;
        Moved := True;
      end;
    dmRotate:
      begin
        a := RotBase - (ArcTan2(py - RotCY, px - RotCX) - RotAng0);
        if ssShift in Shift then a := Round(a / (Pi / 12)) * (Pi / 12);
        a := a - RotTotal;
        if Abs(a) > 1e-9 then
        begin
          Doc.RotateShapes(RotIds, RotCX, RotCY, a, i, j, n);
          RotTotal := RotTotal + a;
          Moved := True;
          SetStatus('Rotation: ' + IntToStr(Round(RotTotal * 180 / Pi)) + ' degrees.');
        end;
      end;
    dmDeform:
      begin
        // the selection is brought back to the upright frame of its box, deformed, and turned again
        if (RotDrag mod 2 = 1) and (Length(RotImgs) > 0) then RotRestoreImages;
        Doc.RotateShapes(RotIds, 0, 0, -RotTotal, i, j, n);
        pv0 := TurnPt(MakePt(px, py), MakePt(0, 0), -RotTotal);
        if RotDrag mod 2 = 0 then
        begin
          gsx := RotSx;
          gsy := RotSy;
          if Abs(RotHx - RotAx) > 1e-6 then gsx := Max(0.02, (pv0.x - RotAx) / (RotHx - RotAx));
          if Abs(RotHy - RotAy) > 1e-6 then gsy := Max(0.02, (pv0.y - RotAy) / (RotHy - RotAy));
          if ssShift in Shift then
            if Abs(gsx - 1) >= Abs(gsy - 1) then gsy := gsx else gsx := gsy;
          Doc.StretchShapes(RotIds, RotAx, RotAy, gsx / RotSx, gsy / RotSy, True);
          for i := 0 to High(RotImgs) do
          begin
            // what is stretched afterwards stays stretched when the skew changes
            RotImgs[i].M[1] := RotImgs[i].M[1] * (gsx / RotSx) / (gsy / RotSy);
            RotImgs[i].M[2] := RotImgs[i].M[2] * (gsy / RotSy) / (gsx / RotSx);
            RotImgs[i].Ux := RotImgs[i].Ux * (gsx / RotSx);
            RotImgs[i].Uy := RotImgs[i].Uy * (gsy / RotSy);
          end;
          RotSx := gsx;
          RotSy := gsy;
        end
        else if RotDrag in [1, 5] then
        begin
          if Abs(RotHy - RotAy) > 1e-6 then
          begin
            a := (pv0.x - RotHx) / (RotHy - RotAy);
            if Abs(a) < 0.004 then a := 0;
            Doc.SkewShapes(RotIds, RotAx, RotAy, a - RotKx, 0);
            for i := 0 to High(RotImgs) do
              if Doc.FindShape(RotImgs[i].Id) <> nil then SkewImage(RotImgs[i], Doc.FindShape(RotImgs[i].Id), RotAx, RotAy, a, 0);
            RotKx := a;
            SetStatus('Skew: ' + IntToStr(Round(ArcTan(a) * 180 / Pi)) + ' degrees.');
          end;
        end
        else
        begin
          if Abs(RotHx - RotAx) > 1e-6 then
          begin
            a := (pv0.y - RotHy) / (RotHx - RotAx);
            if Abs(a) < 0.004 then a := 0;
            Doc.SkewShapes(RotIds, RotAx, RotAy, 0, a - RotKy);
            for i := 0 to High(RotImgs) do
              if Doc.FindShape(RotImgs[i].Id) <> nil then SkewImage(RotImgs[i], Doc.FindShape(RotImgs[i].Id), RotAx, RotAy, 0, a);
            RotKy := a;
            SetStatus('Skew: ' + IntToStr(Round(ArcTan(a) * 180 / Pi)) + ' degrees.');
          end;
        end;
        Doc.RotateShapes(RotIds, 0, 0, RotTotal, i, j, n);
        GroupFrame(RotIds, RotTotal, RotCX, RotCY, RotHW, RotHH);
        Moved := True;
      end;
    dmGroup:
      begin
        if GrpAng <> 0 then
        begin
          // a turned group is resized in its own frame: it is turned back, stretched, and turned again
          Doc.RotateShapes(GrpIds, 0, 0, -GrpAng, i, j, n);
          pv0 := TurnPt(MakePt(px, py), MakePt(0, 0), -GrpAng);
          px := pv0.x;
          py := pv0.y;
        end;
        if GroupBox(GrpIds, gx1, gy1, gx2, gy2) then
        begin
          // the factor of each axis: where the pointer is, against where the moving side is
          gsx := 1;
          gsy := 1;
          if DragGrp in [0, 6, 7, 2, 3, 4] then
          begin
            if DragGrp in [0, 6, 7] then cx := gx1 else cx := gx2;
            if Abs(cx - GrpAx) > 1e-6 then gsx := Max(0.02, (px - GrpAx) / (cx - GrpAx));
          end;
          if DragGrp in [0, 1, 2, 4, 5, 6] then
          begin
            if DragGrp in [0, 1, 2] then cy := gy1 else cy := gy2;
            if Abs(cy - GrpAy) > 1e-6 then gsy := Max(0.02, (py - GrpAy) / (cy - GrpAy));
          end;
          // Shift (or a corner with Ctrl not needed): keep the proportions
          if (ssShift in Shift) and (DragGrp in [0, 2, 4, 6]) then
          begin
            if Abs(gsx - 1) >= Abs(gsy - 1) then gsy := gsx else gsx := gsy;
          end;
          Doc.StretchShapes(GrpIds, GrpAx, GrpAy, gsx, gsy, True);
          Moved := True;
        end;
        if GrpAng <> 0 then Doc.RotateShapes(GrpIds, 0, 0, GrpAng, i, j, n);
      end;
    dmQuote:
      if SelQuote <> nil then
      begin
        Moved := True;
        QuoteDragTo(SelQuote, px, py);
      end;
    dmPage:
      begin
        if DragPageEdge in [1, 3] then Doc.Width := Max(40, Round(px));
        if DragPageEdge in [2, 3] then Doc.Height := Max(40, Round(py));
        UpdateBox;
        Moved := True;
      end;
    dmBand:
      ;
  end;
  LastX := lx;
  LastY := ly;
end;
{ ================= mouse / keyboard ================= }

procedure TForm1.UpdateHover(X, Y: Integer);
var
  px, py: Double;
  ref: TRef;
  oldShape: TShape;
  oldRef: TRef;
  oldQ: TConstraint;
  edge, gh: Integer;
begin
  px := X / Zoom;
  py := Y / Zoom;
  if RotMode then
  begin
    HoverShape := nil;
    HoverRef := MakeRef(0, -1);
    if RotHit(px, py) >= 0 then
    begin
      PaintBox1.Cursor := crHandPoint;
      SetStatus('Double-click a handle to edit the points of the object (double-click a handle again to come back to resizing and turning).');
    end
    else if (Abs(TurnPt(MakePt(px, py), MakePt(RotCX, RotCY), -RotTotal).x - RotCX) <= RotHW) and
            (Abs(TurnPt(MakePt(px, py), MakePt(RotCX, RotCY), -RotTotal).y - RotCY) <= RotHH) then PaintBox1.Cursor := crSizeAll
    else PaintBox1.Cursor := crDefault;
    Exit;
  end;
  oldShape := HoverShape;
  oldRef := HoverRef;
  oldQ := HoverQuote;
  HoverQuote := HitQuote(X, Y);
  HoverRef := MakeRef(0, -1);
  HoverShape := nil;
  gh := HitGroupHandle(px, py);
  if HoverQuote <> nil then PaintBox1.Cursor := crHandPoint
  else if PageEdgeAt(X, Y) <> 0 then
    case PageEdgeAt(X, Y) of
      1: PaintBox1.Cursor := crSizeWE;
      2: PaintBox1.Cursor := crSizeNS;
    else
      PaintBox1.Cursor := crSizeNWSE;
    end
  else if gh >= 0 then
    case gh of
      0, 4: PaintBox1.Cursor := crSizeNWSE;
      2, 6: PaintBox1.Cursor := crSizeNESW;
      1, 5: PaintBox1.Cursor := crSizeNS;
    else
      PaintBox1.Cursor := crSizeWE;
    end
  else if HitHandle(px, py, ref) then
  begin
    HoverRef := ref;
    HoverShape := Doc.FindShape(ref.Shape);
    PaintBox1.Cursor := crHandPoint;
  end
  else if HitShapeSel(px, py, ref) then
  begin
    HoverShape := Doc.FindShape(ref.Shape);
    // a fill follows its boundaries: it cannot be dragged
    // a raster is moved only through the handles of the second mode
    if (HoverShape <> nil) and (HoverShape.Bucket or ((HoverShape.Kind = skImage) and (HoverShape.GroupId = 0))) then PaintBox1.Cursor := crDefault
    else PaintBox1.Cursor := crSizeAll;
  end
  else
  begin
    edge := PageEdgeAt(X, Y);
    case edge of
      1: PaintBox1.Cursor := crSizeWE;
      2: PaintBox1.Cursor := crSizeNS;
      3: PaintBox1.Cursor := crSizeNWSE;
    else
      PaintBox1.Cursor := crDefault;
    end;
  end;
  if (oldShape <> HoverShape) or not SameRef(oldRef, HoverRef) or (oldQ <> HoverQuote) then Redraw;
end;

procedure TForm1.ArcClick(px, py: Double);
begin
  if ArcStage = 1 then
  begin
    CreateMove(px, py, []);
    ArcStage := 2;
    SetStatus('Arc: click to set the end.');
  end
  else
  begin
    CreateMove(px, py, []);
    FinishCreating(True);
  end;
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  px, py: Double;
  hitRef: TRef;
  hitSid, hitIdx: Integer;
  hitMi: TMenuItem;
begin
  px := X / Zoom;
  py := Y / Zoom;
  LastX := px;
  LastY := py;
  DownX := px;
  DownY := py;
  ActiveControl := nil;
  if PersActive then
  begin
    if Button <> mbLeft then Exit;
    PersDrag := PersHit(px, py);
    if PersDrag < 0 then
      if not PersInside(px, py) then PersFinish(True);
    Exit;
  end;
  if CropActive then
  begin
    if Button <> mbLeft then Exit;
    CropDrag := CropHit(px, py);
    if CropDrag = 0 then
    begin
      // a click away from the borders confirms; inside the frame nothing happens
      if (px < CropX1) or (px > CropX2) or (py < CropY1) or (py > CropY2) then CropFinish(True);
    end;
    Exit;
  end;
  if Tool = tlPicker then
  begin
    if Button in [mbLeft, mbRight] then PickColorAt(px, py, Button = mbRight);
    Exit;
  end;
  if Tool = tlClone then
  begin
    if Button = mbLeft then CloneDown(px, py, Shift);
    Exit;
  end;
  if Tool = tlEraser then
  begin
    if Button = mbLeft then EraseDown(px, py);
    Exit;
  end;
  if GradPickId > 0 then
  begin
    if Button = mbLeft then GradPick(px, py)
    else
    begin
      GradPickId := 0;
      SetStatus('Gradient: reference not changed.');
      RefreshProps;
    end;
    Exit;
  end;
  if AngPrev <> nil then
  begin
    if Button = mbLeft then
    begin
      AngleAim(px, py);
      AnglePlace;
    end
    else if Button = mbRight then AngleCancel;
    Exit;
  end;
  if (Button = mbRight) and (Tool = tlSelect) and (Creating = nil) and
     EditablePointAt(px, py, hitSid, hitIdx) then
  begin
    // a point of a path / a joint: remove it
    SelSet(MakeRef(hitSid, hitIdx));
    RefreshProps;
    Redraw;
    if ShapeMenu = nil then ShapeMenu := TPopupMenu.Create(Self);
    ShapeMenu.Items.Clear;
    hitMi := TMenuItem.Create(ShapeMenu);
    if Doc.FindShape(hitSid).Kind in [skSpline, skPath] then hitMi.Caption := 'Remove this point'
    else hitMi.Caption := 'Remove this joint';
    hitMi.OnClick := @RemovePointClick;
    ShapeMenu.Items.Add(hitMi);
    if Doc.FindShape(hitSid).Kind = skPath then
    begin
      hitMi := TMenuItem.Create(ShapeMenu);
      hitMi.Caption := 'Convert the path to a polygon (its points can then take constraints)';
      hitMi.Tag := 1;
      hitMi.OnClick := @ConvertShapeClick;
      ShapeMenu.Items.Add(hitMi);
    end;
    MenuShape := hitSid;
    MenuPoint := hitIdx;
    ShapeMenu.PopUp(Mouse.CursorPos.x, Mouse.CursorPos.y);
    Exit;
  end;
  if (Button = mbRight) and (Tool in [tlSelect, tlSelRect, tlSelEllipse, tlSelFree, tlWand, tlSelShape]) and (Creating = nil) and (SelInsideAt(px, py) <> nil) then
  begin
    // the menu of the selection of a raster (copy, cut, move, fill, convert to a vector shape)
    hitRef := MakeRef(SelInsideAt(px, py).Id, -1);
    SelSet(hitRef);
    RefreshProps;
    Redraw;
    ShowShapeMenu(hitRef);
    Exit;
  end;
  if (Button = mbRight) and (Tool = tlSelect) and (Creating = nil) and HitShapeSel(px, py, hitRef) then
  begin
    // context menu of the shape under the cursor
    if SelFind(MakeRef(hitRef.Shape, -1)) < 0 then SelSet(MakeRef(hitRef.Shape, -1));
    ExpandGroups;
    RefreshProps;
    Redraw;
    ShowShapeMenu(hitRef);
    Exit;
  end;
  if Button = mbRight then
  begin
    if (Creating <> nil) and (Creating.Kind in [skPolyline, skPolygon, skSpline]) then
      FinishCreating(True)
    else
    begin
      if Creating <> nil then CancelCreating;
      if Tool <> tlSelect then SetTool(tlSelect);
    end;
    Exit;
  end;
  if Button <> mbLeft then Exit;
  if (Tool in [tlLine, tlArrow, tlPolyline, tlPolygon, tlRect, tlRoundRect, tlEllipse, tlArc, tlSpline, tlText, tlSvgCode, tlRefLine, tlRefPoint, tlRegPoly,
               tlArc3, tlArcCSE, tlPen, tlMarker, tlAirbrush, tlBucket, tlSnippet]) and not CanCreateHere then Exit;
  if Tool in [tlPen, tlMarker, tlAirbrush] then
  begin
    FreeDown(px, py);
    Exit;
  end;
  if Tool in [tlSelect, tlSelRect, tlSelEllipse, tlSelFree, tlWand, tlSelShape] then
    DbgLog('Down tool=' + IntToStr(Ord(Tool)) + ' x=' + FloatToStr(Round(px)) + ' y=' + FloatToStr(Round(py)) + ' inside=' + BoolToStr(SelInsideAt(px, py) <> nil, True) + ' shift=' + BoolToStr(ssShift in Shift, True) + ' ctrl=' + BoolToStr(ssCtrl in Shift, True) + ' rot=' + BoolToStr(RotMode, True) + ' nsel=' + IntToStr(Length(Sel)));
  if Tool = tlSelect then SelectDown(px, py, Shift, X, Y)
  else if Tool in [tlArc3, tlArcCSE] then Arc2Click(px, py)
  else if Tool = tlSnippet then SnippetClick(px, py)
  else if (Creating <> nil) and (ArcStage in [1, 2]) then ArcClick(px, py)
  else CreateDown(px, py, Shift);
end;

procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  px, py: Double;
  ref: TRef;
  pt: TPt;
  hoverSnap: Boolean;
begin
  px := X / Zoom;
  py := Y / Zoom;
  StatusBar1.Panels[1].Text := IntToStr(Round(px)) + ', ' + IntToStr(Round(py));
  if PersActive then
  begin
    if PersDrag >= 0 then
    begin
      PersX[PersDrag] := Max(PersLX1, Min(PersLX2, px));
      PersY[PersDrag] := Max(PersLY1, Min(PersLY2, py));
      Redraw;
    end
    else if PersHit(px, py) >= 0 then PaintBox1.Cursor := crSizeAll
    else PaintBox1.Cursor := crDefault;
    Exit;
  end;
  if CropActive then
  begin
    if CropDrag <> 0 then CropMoveTo(px, py)
    else
      case CropHit(px, py) of
        1, 2: PaintBox1.Cursor := crSizeWE;
        4, 8: PaintBox1.Cursor := crSizeNS;
        5, 10: PaintBox1.Cursor := crSizeNWSE;
        6, 9: PaintBox1.Cursor := crSizeNESW;
      else
        PaintBox1.Cursor := crDefault;
      end;
    Exit;
  end;
  if Tool = tlClone then
  begin
    CloneMove(px, py);
    Exit;
  end;
  if Tool = tlEraser then
  begin
    EraseMove(px, py);
    Exit;
  end;
  if (Tool = tlSnippet) and (SnipStage > 0) then
  begin
    SnipCur := MakePt(px, py);
    Redraw;
  end;
  if AngPrev <> nil then
  begin
    AngleAim(px, py);
    Exit;
  end;
  if FreeActive then
  begin
    FreeMove(px, py);
    Exit;
  end;
  if (Tool in [tlLine, tlArrow, tlPolyline, tlPolygon, tlRect, tlRoundRect, tlEllipse, tlArc, tlSpline, tlRefLine,
               tlArc3, tlArcCSE, tlText, tlSvgCode, tlRegPoly]) and (Creating = nil) then
  begin
    // show what the next click would snap to
    hoverSnap := SnapTo(px, py, nil, ref, pt);
    if hoverSnap then SnapTarget := ref;
    if (hoverSnap <> HasSnap) or (hoverSnap and ((Abs(SnapAt.x - OldSnap.x) > 1e-9) or (Abs(SnapAt.y - OldSnap.y) > 1e-9))) then
    begin
      HasSnap := hoverSnap;
      OldSnap := SnapAt;
      Redraw;
    end;
  end;
  if Tool in [tlArc3, tlArcCSE] then
  begin
    if Arc2N > 0 then Arc2Update(px, py);
    Exit;
  end;
  if (Tool in [tlSelRect, tlSelEllipse, tlSelFree]) and (Drag in [dmPix, dmShape]) then
  begin
    SelectMove(px, py, Shift);
    Redraw;
    Exit;
  end;
  if Tool = tlSelect then
  begin
    if Drag = dmNone then UpdateHover(X, Y)
    else
    begin
      SelectMove(px, py, Shift);
      Redraw;
    end;
  end
  else if Creating <> nil then CreateMove(px, py, Shift);
end;

procedure TForm1.PaintBox1MouseLeave(Sender: TObject);
begin
  if Drag = dmNone then
  begin
    HasSnap := False;
    HoverShape := nil;
    HoverRef := MakeRef(0, -1);
    HoverQuote := nil;
    Redraw;
  end;
end;

function ShapeBox(s: TShape; out x1, y1, x2, y2: Double): Boolean;
var
  o: TOutline;
  i, j: Integer;
begin
  o := ShapeOutline(s);
  x1 := 1e18; y1 := 1e18; x2 := -1e18; y2 := -1e18;
  Result := False;
  for i := 0 to High(o) do
    for j := 0 to High(o[i].Pts) do
    begin
      x1 := Min(x1, o[i].Pts[j].x);
      y1 := Min(y1, o[i].Pts[j].y);
      x2 := Max(x2, o[i].Pts[j].x);
      y2 := Max(y2, o[i].Pts[j].y);
      Result := True;
    end;
end;

procedure TForm1.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  px, py: Double;
  i, j: Integer;
  bx1, by1, bx2, by2, sx1, sy1, sx2, sy2: Double;
  prev: TDragMode;
  nCons: Integer;
  pxs, pys: TDblArr;
  pctl: TBoolDyn;
  panc: TIntDyn;
  bp: TPt;
  got: Boolean;
begin
  if Button <> mbLeft then Exit;
  px := X / Zoom;
  py := Y / Zoom;
  if PersActive then
  begin
    PersDrag := -1;
    Exit;
  end;
  if CropActive then
  begin
    CropDrag := 0;
    Exit;
  end;
  if CloneOn then
  begin
    CloneUp;
    Exit;
  end;
  if EraseOn then
  begin
    EraseUp;
    Exit;
  end;
  if FreeActive then
  begin
    FreeUp;
    Exit;
  end;
  if (Tool <> tlSelect) and not ((Tool in [tlSelRect, tlSelEllipse, tlSelFree]) and (Drag in [dmPix, dmShape])) then
  begin
    CreateUp(px, py, Shift);
    Exit;
  end;
  prev := Drag;
  Drag := dmNone;
  case prev of
    dmBand:
      begin
        BandOn := False;
        bx1 := Min(DownX, px); bx2 := Max(DownX, px);
        by1 := Min(DownY, py); by2 := Max(DownY, py);
        if BandPoints then
        begin
          // the control points inside the band, of the selected figures
          for i := 0 to Doc.Shapes.Count - 1 do
            if IsSelShape(Doc.Shapes[i]) and Interactive(Doc.Shapes[i]) and (Doc.Shapes[i].GroupId = 0) and
               (Doc.Shapes[i].Kind in [skSpline, skPolyline, skPolygon]) then
              for j := 0 to High(Doc.Shapes[i].P) do
                if (Doc.Shapes[i].P[j].x >= bx1) and (Doc.Shapes[i].P[j].x <= bx2) and
                   (Doc.Shapes[i].P[j].y >= by1) and (Doc.Shapes[i].P[j].y <= by2) and
                   (SelFind(MakeRef(Doc.Shapes[i].Id, j)) < 0) then
                begin
                  SetLength(Sel, Length(Sel) + 1);
                  Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, j);
                end;
          // the points of paths made of commands (curve controls too)
          for i := 0 to Doc.Shapes.Count - 1 do
            if IsSelShape(Doc.Shapes[i]) and Interactive(Doc.Shapes[i]) and (Doc.Shapes[i].GroupId = 0) and (Doc.Shapes[i].Kind = skPath) and
               not Doc.Shapes[i].Bucket and (Length(Doc.Shapes[i].P) > 0) then
            begin
              Doc.Shapes[i].PathHandles(pxs, pys, pctl, panc);
              got := False;
              for j := 0 to High(pxs) do
              begin
                bp := MakePt(Doc.Shapes[i].P[0].x + pxs[j], Doc.Shapes[i].P[0].y + pys[j]);
                if (Doc.Shapes[i].Rot <> 0) and RotKind(skPath) then bp := TurnPt(bp, ShapePivot(Doc.Shapes[i]), Doc.Shapes[i].Rot);
                if (bp.x >= bx1) and (bp.x <= bx2) and (bp.y >= by1) and (bp.y <= by2) and
                   (SelFind(MakeRef(Doc.Shapes[i].Id, HandlePathBase + j)) < 0) then
                begin
                  SetLength(Sel, Length(Sel) + 1);
                  Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, HandlePathBase + j);
                  got := True;
                end;
              end;
              // with points picked, the figure itself is no longer the selection (Delete removes the points)
              if got then
                for j := High(Sel) downto 0 do
                  if (Sel[j].Shape = Doc.Shapes[i].Id) and (Sel[j].Idx = -1) then Delete(Sel, j, 1);
            end;
          BandPoints := False;
        end
        else if (bx2 - bx1 > 3 / Zoom) or (by2 - by1 > 3 / Zoom) then
          for i := 0 to Doc.Shapes.Count - 1 do
            if Interactive(Doc.Shapes[i]) and ShapeBox(Doc.Shapes[i], sx1, sy1, sx2, sy2) and
               (sx1 >= bx1) and (sx2 <= bx2) and (sy1 >= by1) and (sy2 <= by2) then
              if SelFind(MakeRef(Doc.Shapes[i].Id, -1)) < 0 then
              begin
                SetLength(Sel, Length(Sel) + 1);
                Sel[High(Sel)] := MakeRef(Doc.Shapes[i].Id, -1);
              end;
      end;
    dmPoint:
      begin
        if Moved and HasSnap and (SnapTarget.Shape <> DragRef.Shape) then
        begin
          nCons := Doc.Cons.Count;
          AddSnapConstraint(DragRef, SnapTarget);
          Doc.Solve([]);
          if (Doc.Cons.Count > nCons) and RejectIfInconsistent then Moved := False;
        end;
      end;
  end;
  if (prev = dmShape) and RotPickOn and not Moved then
  begin
    RotMode := False;
    SelSet(RotPickRef);
  end;
  RotPickOn := False;
  ExpandGroups;
  HasSnap := False;
  if Moved then Commit;
  Moved := False;
  RefreshProps;
  Redraw;
end;

procedure TForm1.DblLift(sel0: TShape);
var
  img, lifted: TShape;
begin
  img := Doc.FindShape(sel0.SelTarget);
  if img = nil then Exit;
  SetTool(tlSelect);
  Checkpoint;
  lifted := PixLift(SelListOf(img), False);
  if lifted = nil then Exit;
  SelSet(MakeRef(lifted.Id, -1));
  Commit;
  RefreshProps;
  RotEnter;
  Redraw;
end;

procedure TForm1.PaintBoxDblClick(Sender: TObject);
var
  sel0: TShape;
  p: TPoint;
  ref: TRef;
  q: TConstraint;
  s: TShape;
  txt: string;
begin
  if Creating <> nil then
  begin
    if Creating.Kind in [skPolyline, skPolygon, skSpline] then FinishCreating(True);
    Exit;
  end;
  p := PaintBox1.ScreenToClient(Mouse.CursorPos);
  if (Drag in [dmNone, dmPix]) and (Tool in [tlSelect, tlSelRect, tlSelEllipse, tlSelFree, tlWand, tlSelShape]) then
  begin
    // a double click inside a selection of pixels: they are lifted into a raster that can be moved, resized, turned and deformed
    sel0 := SelInsideAt(p.x / Zoom, p.y / Zoom);
    if sel0 <> nil then
    begin
      Drag := dmNone;
      Moved := False;
      DblLift(sel0);
      Exit;
    end;
  end;
  if Tool <> tlSelect then Exit;
  q := HitQuote(p.x, p.y);
  if q <> nil then
  begin
    // the second press of the double click began to drag the quote: the window swallows the release, so the drag ends here
    Drag := dmNone;
    Moved := False;
    EditQuoteValue(q);
    Drag := dmNone;
    Exit;
  end;
  // a handle: the selection is turned with the mouse instead of being resized (and back)
  if RotMode then
  begin
    if RotHit(p.x / Zoom, p.y / Zoom) >= 0 then
    begin
      RotMode := False;
      PointEdit := True;
      PointEditSig := SelIdSig;
      Drag := dmNone;
      Moved := False;
      SetStatus('Points: drag the handles to edit the object. Double-click a handle to go back to resizing and turning.');
      UpdateHover(p.x, p.y);
      Redraw;
      Exit;
    end;
  end
  else if (HitGroupHandle(p.x / Zoom, p.y / Zoom) >= 0) or HitHandle(p.x / Zoom, p.y / Zoom, ref) then
  begin
    Drag := dmNone;
    Moved := False;
    PointEdit := False;
    RotEnter;
    if RotMode then UpdateHover(p.x, p.y);
    Exit;
  end;
  if HitShape(p.x / Zoom, p.y / Zoom, ref) then
  begin
    s := Doc.FindShape(ref.Shape);
    if (s <> nil) and (s.GroupId > 0) then Exit;       // the figures of a group are not edited one by one
    if (s <> nil) and (s.Kind = skImage) and (s.SelTarget = 0) and not RotMode then
    begin
      // a double click anywhere on a raster: the handles of the second mode (move, resize, turn, deform)
      Drag := dmNone;
      Moved := False;
      if SelFind(MakeRef(s.Id, -1)) < 0 then SelSet(MakeRef(s.Id, -1));
      RotEnter;
      if RotMode then UpdateHover(p.x, p.y);
      Exit;
    end;
    if (s <> nil) and (s.Kind = skText) then
    begin
      txt := s.Text;
      if InputQuery('Text', 'Text:', txt) then
      begin
        Checkpoint;
        s.Text := txt;
        Commit;
        RefreshProps;
        Redraw;
      end;
    end;
  end;
end;

procedure TForm1.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  vp: TPoint;
  over, useGL: Boolean;
  ox, oy: Double;
begin
  if ssCtrl in Shift then
  begin
    vp := ScrollBox1.ScreenToClient(Mouse.CursorPos);
    over := (vp.x >= 0) and (vp.y >= 0) and (vp.x < ScrollBox1.ClientWidth) and (vp.y < ScrollBox1.ClientHeight);
    useGL := over and (Drag = dmNone) and (Creating = nil) and (BufZoom > 0) and (Buf.Width > 0) and (Buf.Height > 0) and GLReady;
    if useGL then
    begin
      // the zoom is animated by the graphics card; the turns of the wheel move the goal, the card goes towards it smoothly
      if not ZoomAnimOn then
      begin
        ZoomGoal := Zoom;
        GLBegin;
        ox := ScrollBox1.HorzScrollBar.Position;
        oy := ScrollBox1.VertScrollBar.Position;
        ZoomAnimOn := True;
        ZoomLastTick := GetTickCount64 - 16;
      end
      else GLOrigin(GLShown, ox, oy);
      // the point under the mouse now is the one that stays there
      GLVx := vp.x;
      GLVy := vp.y;
      GLPx := (ox + vp.x) / GLShown;
      GLPy := (oy + vp.y) / GLShown;
      if WheelDelta > 0 then ZoomGoal := ZoomGoal * 1.15 else ZoomGoal := ZoomGoal / 1.15;
      ZoomGoal := Max(ZoomMin, Min(ZoomMax, ZoomGoal));
      if ZoomGoal < GLShown then GLMakePage;
      ZoomAnim.Enabled := True;
      Handled := True;
      Exit;
    end;
    // without the card: the turns in a row are applied together, after the last one
    if ZoomAnimOn then GLEnd;
    if WheelDelta > 0 then ZoomPending := ZoomPending * 1.15 else ZoomPending := ZoomPending / 1.15;
    ZoomPt := Mouse.CursorPos;
    ZoomFast := True;
    ZoomSettle.Enabled := False;
    ZoomSettle.Enabled := True;
    ZoomTimer.Enabled := False;
    ZoomTimer.Enabled := True;
    Handled := True;
  end;
end;

// the arrow keys move the selected objects by one unit of the page (ten with Shift)
procedure TForm1.NudgeSelection(Key: Word; big: Boolean);
var
  ts: TShapeArray;
  i, j: Integer;
  dx, dy, st: Double;
  lifted: TShape;
  nc: Integer;
begin
  ts := SelShapes;
  for i := 0 to High(ts) do
    for j := 0 to High(ts[i].P) do
      if Doc.IsPinned(ts[i].Id, j) then
      begin
        SetStatus('Part of the selection is fixed.');
        Exit;
      end;
  st := 1;
  if big then st := 10;
  dx := 0; dy := 0;
  case Key of
    VK_LEFT: dx := -st;
    VK_RIGHT: dx := st;
    VK_UP: dy := -st;
    VK_DOWN: dy := st;
  end;
  Checkpoint;
  if AllSelections(ts) and (ts[0].SelTarget > 0) and (Doc.FindShape(ts[0].SelTarget) <> nil) then
  begin
    // a selection of pixels: the first step lifts the pixels (as a drag does), the next ones move them
    lifted := PixLift(SelListOf(Doc.FindShape(ts[0].SelTarget)), False);
    if lifted = nil then Exit;
    SelSet(MakeRef(lifted.Id, -1));
    SetLength(ts, 1);
    ts[0] := lifted;
  end;
  for i := 0 to High(ts) do
    if not ts[i].Bucket then ts[i].Translate(dx, dy);
  Drag := dmShape;
  try
    DragSolve;
  finally
    Drag := dmNone;
  end;
  nc := UndoStack.Count;
  Commit;
  // a key kept pressed is one single step for Undo: the steps of the repeats are not kept
  if NudgeHeld and (GetTickCount64 - NudgeTick < 1000) and (nc = NudgeUndoCount) and (UndoStack.Count = nc + 1) then
    UndoStack.Delete(nc)
  else if UndoStack.Count = nc + 1 then
    NudgeUndoCount := UndoStack.Count;
  NudgeHeld := True;
  NudgeTick := GetTickCount64;
  FlushAllImageCaches;
  UpdateBox;
  RefreshProps;
  Redraw;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  typing: Boolean;
begin
  typing := (ActiveControl is TCustomEdit) or (ActiveControl is TCustomComboBox) or
            (ActiveControl is TCustomFloatSpinEdit);
  if PersActive and (Key in [VK_ESCAPE, VK_RETURN]) then
  begin
    PersFinish(Key = VK_RETURN);
    Key := 0;
    Exit;
  end;
  if CropActive and (Key in [VK_ESCAPE, VK_RETURN]) then
  begin
    CropFinish(Key = VK_RETURN);
    Key := 0;
    Exit;
  end;
  if Key = VK_ESCAPE then
  begin
    if GradPickId > 0 then
    begin
      GradPickId := 0;
      RefreshProps;
    end
    else if AngPrev <> nil then AngleCancel
    else if Creating <> nil then CancelCreating
    else if RotMode then
    begin
      RotMode := False;
      Redraw;
    end
    else
    begin
      SetTool(tlSelect);
      SelClear;
      RefreshProps;
      Redraw;
    end;
    Key := 0;
    Exit;
  end;
  if typing then Exit;
  if (Key = VK_RETURN) and (Creating <> nil) and (Creating.Kind in [skPolyline, skPolygon, skSpline]) then
  begin
    FinishCreating(True);
    Key := 0;
  end
  else if (Key = VK_RETURN) and (Creating = nil) and (Drag = dmNone) and (FloatId > 0) and
          (Length(SelShapes) = 1) and (SelShapes[0].Id = FloatId) then
  begin
    PixCommit;
    Key := 0;
  end
  else if (Key = VK_RETURN) and (Creating = nil) and (Drag = dmNone) and (Length(SelShapes) = 1) and
          (SelShapes[0].Kind = skImage) and (SelShapes[0].SelTarget = 0) then
  begin
    MergeOverRaster(SelShapes[0]);
    Key := 0;
  end
  else if (Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN]) and (Creating = nil) and (Drag = dmNone) and
          (Length(SelShapes) > 0) and not (ssCtrl in Shift) and not (ssAlt in Shift) and
          not (ActiveControl is TCustomTreeView) and not (ActiveControl is TCustomListBox) and
          not (ActiveControl is TCustomCheckGroup) then
  begin
    NudgeSelection(Key, ssShift in Shift);
    Key := 0;
  end
  else if (Key = VK_DELETE) and (ssShift in Shift) and AllSelections(SelShapes) then
  begin
    PixelsOp(4, SelShapes);   // Shift+Del: fill the selection with the current colour
    Key := 0;
  end
  else if Key = VK_DELETE then
  begin
    DeleteSelection;
    Key := 0;
  end
  else if ssCtrl in Shift then
  begin
    case Key of
      VK_Z:
        begin
          if ssShift in Shift then DoRedo(nil) else DoUndo(nil);
          Key := 0;
        end;
      VK_Y: begin DoRedo(nil); Key := 0; end;
      VK_A: begin SelectAll(nil); Key := 0; end;
      VK_I: begin InvertSelection(nil); Key := 0; end;
      VK_G: begin if ssShift in Shift then UngroupClick(nil) else GroupClick(nil); Key := 0; end;
      VK_C: begin MenuCopy(nil); Key := 0; end;
      VK_X: begin MenuCut(nil); Key := 0; end;
      VK_S: begin MenuSave(nil); Key := 0; end;
      VK_O: begin MenuOpen(nil); Key := 0; end;
      VK_N: begin MenuNew(nil); Key := 0; end;
      VK_P: begin MenuPrint(nil); Key := 0; end;
      VK_V:
        begin
          // not inside the key event of GTK: the clipboard runs the event loop while it waits, and an error here
          // would open its dialog from inside the signal
          Application.QueueAsyncCall(@PasteKeyAsync, Ord(ssShift in Shift));
          Key := 0;
        end;
      VK_0, VK_NUMPAD0: begin SetZoom(1); Key := 0; end;
    end;
  end;
end;

procedure TForm1.MenuItem16Click(Sender: TObject);
begin
  form2.show;
end;

// Help > SVG Snippets: the language of the snippets
procedure TForm1.MenuHelpSnippets(Sender: TObject);
begin
  Form2.ShowTopic('SVG Snippets Language');
end;

// Help > Filters: the language of the filters
procedure TForm1.MenuHelpFilters(Sender: TObject);
begin
  Form2.ShowTopic('Filters Language');
end;

procedure TForm1.MenuItem19Click(Sender: TObject);
begin
  form3.Left:=trunc(form1.Left+form1.Width/2-form3.Width/2);
  form3.top:=trunc(form1.top+form1.height/2-form3.height/2);
  form3.show;
end;

{ ================= constraints ================= }

// the references that a constraint button would use for the selection: a side that was clicked is a segment
function TForm1.ConsRefsFor(k: TConstraintKind; out refs: TRefArray): Boolean;
var
  i: Integer;
  s: TShape;
begin
  Result := True;
  SetLength(refs, Length(Sel));
  for i := 0 to High(Sel) do
  begin
    refs[i] := Sel[i];
    if Sel[i].Idx >= HandlePathBase then Result := False;
    s := Doc.FindShape(refs[i].Shape);
    if (s <> nil) and (s.GroupId > 0) then Result := False;       // what a group is made of takes no constraints
    if (s <> nil) and (refs[i].Idx = -1) and (refs[i].Seg >= 0) and (k <> ckFixed) and
       ((s.Kind in [skPolyline, skPolygon]) or ((s.Kind = skRect) and (k <> ckDistance))) then
      refs[i].Idx := SegBase + refs[i].Seg;
  end;
end;

// does the selection suit the constraint (how many things, of which kind)?
function TForm1.ConsUsable(k: TConstraintKind): Boolean;
var
  refs: TRefArray;
  s: TShape;
begin
  Result := False;
  if (Creating <> nil) or (Length(Sel) = 0) or (SelQuote <> nil) then Exit;
  if not ConsRefsFor(k, refs) then Exit;
  // the dimension of a side of a rectangle (the quote is made between its corners)
  if (k = ckDistance) and (Length(refs) = 1) and (refs[0].Idx = -1) and (refs[0].Seg >= 0) then
  begin
    s := Doc.FindShape(refs[0].Shape);
    if (s <> nil) and (s.Kind = skRect) then Exit(True);
  end;
  Result := Doc.CheckConstraint(k, refs) = '';
end;

procedure TForm1.ConstraintClick(Sender: TObject);
var
  k: TConstraintKind;
  refs: TRefArray;
  i, n: Integer;
  s, s2: TShape;
  c: TConstraint;
  err: string;
  tmp: TRef;
  d: Double;
begin
  k := TConstraintKind(TSpeedButton(Sender).Tag);
  if Creating <> nil then Exit;
  if Length(Sel) = 0 then
  begin
    SetStatus(ConsHint[k] + ' - select the objects/points first (Shift+click to add more).');
    Exit;
  end;
  for i := 0 to High(Sel) do
    if Sel[i].Idx >= HandlePathBase then
    begin
      SetStatus('The points of a path made of commands cannot take constraints: convert it to a polygon first.');
      Exit;
    end;
  if not ConsRefsFor(k, refs) then
  begin
    for i := 0 to High(Sel) do
      if (Doc.FindShape(Sel[i].Shape) <> nil) and (Doc.FindShape(Sel[i].Shape).GroupId > 0) then
      begin
        SetStatus('A group can only be handled as a whole: its figures take no constraints (ungroup it first).');
        Exit;
      end;
  end;
  if (k = ckDistance) and (Length(refs) = 1) and (refs[0].Idx = -1) then
  begin
    s := Doc.FindShape(refs[0].Shape);
    if (s <> nil) and (s.Kind = skRect) then
    begin
      // dimension of a rectangle side = horizontal/vertical quote between its corners
      i := refs[0].Seg;
      SetLength(refs, 2);
      refs[0] := MakeRef(s.Id, 0);
      refs[1] := MakeRef(s.Id, 1);
      Checkpoint;
      c := Doc.AddConstraint(k, refs, err);
      if c <> nil then
      begin
        if i in [1, 3] then c.Axis := 2 else c.Axis := 1;
        Doc.InitQuote(c);
        // default offset puts the label above / left; bottom and right sides go the other way
        if i = 2 then c.Offset := -(Abs(s.P[1].y - s.P[0].y) + 30);
        if i = 1 then c.Offset := -(Abs(s.P[1].x - s.P[0].x) + 30);
      end;
      Commit;
      RefreshProps;
      Redraw;
      Exit;
    end;
  end;
  if k = ckAngle then
  begin
    err := Doc.CheckConstraint(k, refs);
    if err <> '' then
    begin
      SetStatus(err);
      Exit;
    end;
    FreeAndNil(AngPrev);
    AngPrev := TConstraint.Create;
    AngPrev.Kind := ckAngle;
    AngPrev.Refs := Copy(refs);
    Doc.InitQuote(AngPrev);
    SetStatus('Angular quote: move the mouse to choose which of the 4 angles, click to place it (Esc cancels).');
    Redraw;
    Exit;
  end;
  if (k = ckSymmetry) and (Length(refs) = 3) then
  begin
    // a reference line is the natural axis
    for i := 0 to 1 do
    begin
      s := Doc.FindShape(refs[i].Shape);
      if (s <> nil) and s.IsRef and (s.Kind = skLine) then
      begin
        tmp := refs[i];
        refs[i] := refs[2];
        refs[2] := tmp;
        Break;
      end;
    end;
  end;
  Checkpoint;
  if (k = ckEqual) and (Length(refs) > 2) then
  begin
    // several sides: each one is made equal to the first
    c := nil;
    for i := 1 to High(refs) do
    begin
      c := Doc.AddConstraint(k, [refs[0], refs[i]], err);
      if c = nil then Break;
    end;
  end
  else c := Doc.AddConstraint(k, refs, err);
  if c = nil then
  begin
    SetStatus(err);
    Exit;
  end;
  if (k = ckTangent) and (Doc.EllOf(c.Refs[0]) <> nil) and (Doc.EllOf(c.Refs[1]) <> nil) then
  begin
    s := Doc.EllOf(c.Refs[0]);
    s2 := Doc.EllOf(c.Refs[1]);
    d := Dist(s.P[0], s2.P[0]);
    if d < Max(s.RX, s2.RX) then c.Aux := 1 else c.Aux := 0;
  end;
  Doc.SolveNew(c);
  if RejectIfInconsistent then Exit;
  Commit;
  n := Doc.Cons.Count;
  SetStatus(ConsHint[k] + ' added (' + IntToStr(n) + ' constraints in the drawing).');
  if c.IsQuote then
  begin
    SelClear;
    SelQuote := c;
  end;
  RefreshProps;
  Redraw;
end;

procedure TForm1.EditQuoteValue(c: TConstraint);
var
  v: string;
  d: Double;
begin
  if c.Kind = ckRadius then
  begin
    if c.Diam then d := c.Value * 2 else d := c.Value;
  end
  else d := c.Value;
  v := FmtNum(d);
  if not InputQuery('Quote', 'Value:', v) then Exit;
  d := StrToFloatDef(StringReplace(v, ',', '.', []), -1, DefaultFormatSettings);
  if d = -1 then
    d := StrToFloatDef(v, -1);
  if (d <= 0) or ((c.Kind = ckAngle) and (d >= 180)) then
  begin
    SetStatus('Invalid value.');
    Exit;
  end;
  Checkpoint;
  if (c.Kind = ckRadius) and c.Diam then c.Value := d / 2 else c.Value := d;
  Doc.SolveNew(c);
  if RejectIfInconsistent then Exit;
  Commit;
  RefreshProps;
  Redraw;
end;

{ ================= properties panel ================= }

procedure TForm1.SetRowCaption(idx: Integer; const cap: string);
var
  i: Integer;
begin
  if Rows[idx] = nil then Exit;
  for i := 0 to Rows[idx].ControlCount - 1 do
    if Rows[idx].Controls[i] is TLabel then
    begin
      TLabel(Rows[idx].Controls[i]).Caption := cap;
      Exit;
    end;
end;

function TForm1.AddRow(idx, h: Integer; const cap: string): TPanel;
var
  l: TLabel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := ScrollBox2;
  Result.BevelOuter := bvNone;
  Result.Caption := '';
  Result.Anchors := [akLeft, akTop, akRight];
  Result.SetBounds(0, 0, Max(ScrollBox2.ClientWidth, 300), h);   // stacked by RelayoutProps
  if cap <> '' then
  begin
    l := TLabel.Create(Self);
    l.Parent := Result;
    l.Caption := cap;
    l.Left := 8;
    l.Top := 8;
  end;
  Rows[idx] := Result;
end;

procedure TForm1.RelayoutProps;
const
  Order: array[0..57] of Integer = (0, 55, 56, 57, 45, 46, 48, 49, 53, 54, 1, 33, 2, 34, 44, 52, 37, 40, 38, 41, 39, 42, 35, 36, 24, 25, 26, 27, 28, 29, 30, 31, 32, 3, 47, 4, 5, 6, 7, 8, 9, 50, 23, 51, 10, 11, 43, 12, 13, 22, 16, 18, 19, 20, 21, 17, 14, 15);
var
  k, y: Integer;
begin
  y := 0;
  for k := 0 to High(Order) do
    if (Rows[Order[k]] <> nil) and Rows[Order[k]].Visible then
    begin
      Rows[Order[k]].Top := y;
      Inc(y, Rows[Order[k]].Height);
    end;
end;

procedure TForm1.BuildProps;
const
  CX = 104;
var
  p: TPanel;
  i: Integer;
begin
  ScrollBox2.HorzScrollBar.Visible := False;
  p := AddRow(0, 26, '');
  lblTarget := TLabel.Create(Self);
  lblTarget.Parent := p;
  lblTarget.Left := 8;
  lblTarget.Top := 6;
  lblTarget.Font.Style := [fsBold];

  p := AddRow(55, 32, 'Layer opacity %');
  seLPOp := TFloatSpinEdit.Create(Self);
  seLPOp.Parent := p;
  seLPOp.SetBounds(CX + 20, 3, 90, 24);
  seLPOp.MinValue := 0;
  seLPOp.MaxValue := 100;
  seLPOp.Increment := 5;
  seLPOp.DecimalPlaces := 0;
  seLPOp.Value := 100;
  seLPOp.OnChange := @LayerPropChange;
  seLPOp.OnEditingDone := @LayerPropChange;

  p := AddRow(56, 32, 'Scale factor');
  seLPScale := TFloatSpinEdit.Create(Self);
  seLPScale.Parent := p;
  seLPScale.SetBounds(CX + 20, 3, 110, 24);
  seLPScale.MinValue := 0.000001;
  seLPScale.MaxValue := 1000000;
  seLPScale.Increment := 0.1;
  seLPScale.DecimalPlaces := 4;
  seLPScale.Value := 1;
  seLPScale.Hint := 'Real units per drawing unit (pixel): the quotes of this layer show their length multiplied by it';
  seLPScale.ShowHint := True;
  seLPScale.OnChange := @LayerPropChange;
  seLPScale.OnEditingDone := @LayerPropChange;

  p := AddRow(57, 32, 'Background');
  btnLPBg := TSpeedButton.Create(Self);
  btnLPBg.Parent := p;
  btnLPBg.SetBounds(CX + 20, 3, 40, 24);
  btnLPBg.OnClick := @LayerBgClick;
  btnLPBg.Hint := 'Colour of the background of the layer (the whole page, under its objects)';
  btnLPBg.ShowHint := True;
  chkLPNoBg := TCheckBox.Create(Self);
  chkLPNoBg.Parent := p;
  chkLPNoBg.Caption := 'none';
  chkLPNoBg.SetBounds(CX + 70, 5, 80, 20);
  chkLPNoBg.OnChange := @LayerBgNoneChange;

  p := AddRow(1, 32, 'Stroke color');
  btnStroke := TSpeedButton.Create(Self);
  btnStroke.Parent := p;
  btnStroke.SetBounds(CX, 3, 40, 24);
  btnStroke.OnClick := @StrokeClick;
  chkNoStroke := TCheckBox.Create(Self);
  chkNoStroke.Parent := p;
  chkNoStroke.Caption := 'none';
  chkNoStroke.SetBounds(CX + 50, 5, 80, 20);
  chkNoStroke.OnChange := @StyleChanged;

  p := AddRow(2, 32, 'Fill color');
  btnFill := TSpeedButton.Create(Self);
  btnFill.Parent := p;
  btnFill.SetBounds(CX, 3, 40, 24);
  btnFill.OnClick := @FillClick;
  chkNoFill := TCheckBox.Create(Self);
  chkNoFill.Parent := p;
  chkNoFill.Caption := 'none';
  chkNoFill.SetBounds(CX + 50, 5, 80, 20);
  chkNoFill.OnChange := @StyleChanged;

  p := AddRow(3, 32, 'Thickness');
  seWidth := TFloatSpinEdit.Create(Self);
  seWidth.Parent := p;
  seWidth.SetBounds(CX, 3, 90, 24);
  seWidth.MinValue := 0.5;
  seWidth.MaxValue := 200;
  seWidth.Increment := 0.5;
  seWidth.DecimalPlaces := 1;
  seWidth.OnChange := @StyleChanged;

  p := AddRow(4, 32, 'Line end');
  cbCap := TComboBox.Create(Self);
  cbCap.Parent := p;
  cbCap.Style := csDropDownList;
  cbCap.Items.Add('Flat');
  cbCap.Items.Add('Round');
  cbCap.Items.Add('Square (pointed)');
  cbCap.SetBounds(CX, 3, 150, 24);
  cbCap.OnChange := @StyleChanged;

  p := AddRow(5, 32, 'Corners');
  cbJoin := TComboBox.Create(Self);
  cbJoin.Parent := p;
  cbJoin.Style := csDropDownList;
  cbJoin.Items.Add('Pointed (miter)');
  cbJoin.Items.Add('Round');
  cbJoin.Items.Add('Bevel');
  cbJoin.SetBounds(CX, 3, 150, 24);
  cbJoin.OnChange := @StyleChanged;

  p := AddRow(6, 32, 'Line style');
  cbDash := TComboBox.Create(Self);
  cbDash.Parent := p;
  cbDash.Style := csDropDownList;
  cbDash.Items.Add('Solid');
  cbDash.Items.Add('Dashed');
  cbDash.Items.Add('Dotted');
  cbDash.Items.Add('Dash-dot');
  cbDash.SetBounds(CX, 3, 150, 24);
  cbDash.OnChange := @StyleChanged;

  p := AddRow(7, 28, '');
  chkCirc := TCheckBox.Create(Self);
  chkCirc.Parent := p;
  chkCirc.Caption := 'Circle (equal radii)';
  chkCirc.SetBounds(8, 4, 250, 20);
  chkCirc.OnChange := @StyleChanged;

  p := AddRow(8, 32, 'Text');
  edText := TEdit.Create(Self);
  edText.Parent := p;
  edText.SetBounds(CX, 3, 170, 24);
  edText.OnEditingDone := @StyleChanged;

  p := AddRow(9, 32, 'Font size');
  seFont := TFloatSpinEdit.Create(Self);
  seFont.Parent := p;
  seFont.SetBounds(CX, 3, 90, 24);
  seFont.MinValue := 4;
  seFont.MaxValue := 400;
  seFont.DecimalPlaces := 0;
  seFont.OnChange := @StyleChanged;

  p := AddRow(50, 32, 'Font');
  cbFont := TComboBox.Create(Self);
  cbFont.Parent := p;
  cbFont.SetBounds(CX, 3, 170, 24);
  cbFont.Style := csDropDownList;
  cbFont.DropDownCount := 20;
  cbFont.Items.Add('Default');
  for i := 0 to Screen.Fonts.Count - 1 do
    if (Screen.Fonts[i] <> '') and (Screen.Fonts[i][1] <> '@') then cbFont.Items.Add(Screen.Fonts[i]);
  cbFont.ItemIndex := 0;
  cbFont.OnChange := @StyleChanged;

  p := AddRow(10, 28, '');
  chkRef := TCheckBox.Create(Self);
  chkRef.Parent := p;
  chkRef.Caption := 'Reference object (not in raster export)';
  chkRef.SetBounds(8, 4, 280, 20);
  chkRef.OnChange := @StyleChanged;

  p := AddRow(33, 32, 'Stroke opacity %');
  seStrokeOp := TFloatSpinEdit.Create(Self);
  seStrokeOp.Parent := p;
  seStrokeOp.SetBounds(CX + 20, 3, 80, 24);
  seStrokeOp.MinValue := 0;
  seStrokeOp.MaxValue := 100;
  seStrokeOp.Increment := 5;
  seStrokeOp.DecimalPlaces := 0;
  seStrokeOp.OnChange := @StyleChanged;

  p := AddRow(34, 32, 'Fill opacity %');
  seFillOp := TFloatSpinEdit.Create(Self);
  seFillOp.Parent := p;
  seFillOp.SetBounds(CX + 20, 3, 80, 24);
  seFillOp.MinValue := 0;
  seFillOp.MaxValue := 100;
  seFillOp.Increment := 5;
  seFillOp.DecimalPlaces := 0;
  seFillOp.OnChange := @StyleChanged;

  p := AddRow(35, 28, '');
  chkBucketLower := TCheckBox.Create(Self);
  chkBucketLower.Parent := p;
  chkBucketLower.Caption := 'Bounded by shapes on lower layers';
  chkBucketLower.SetBounds(8, 4, 280, 20);
  chkBucketLower.Checked := True;
  chkBucketLower.OnChange := @BucketOptChanged;

  p := AddRow(37, 28, '');
  chkGrad := TCheckBox.Create(Self);
  chkGrad.Parent := p;
  chkGrad.Caption := 'Gradient to a second colour';
  chkGrad.SetBounds(8, 4, 280, 20);
  chkGrad.OnChange := @GradChanged;

  p := AddRow(42, 32, 'Antialiasing');
  cbRendering := TComboBox.Create(Self);
  cbRendering.Parent := p;
  cbRendering.Style := csDropDownList;
  cbRendering.Items.Add('Yes');
  cbRendering.Items.Add('No');
  cbRendering.Hint := 'Smooth edges, on screen, in PNG and in a raster PDF (in an SVG, No asks for crispEdges)';
  cbRendering.ShowHint := True;
  cbRendering.SetBounds(CX, 3, 190, 24);
  cbRendering.OnChange := @RenderingChanged;

  p := AddRow(40, 32, 'Gradient type');
  cbGradType := TComboBox.Create(Self);
  cbGradType.Parent := p;
  cbGradType.Style := csDropDownList;
  cbGradType.Items.Add('Linear (along a line or path)');
  cbGradType.Items.Add('Radial (from a centre outwards)');
  cbGradType.SetBounds(CX, 3, 190, 24);
  cbGradType.OnChange := @GradChanged;

  p := AddRow(38, 32, 'Colour 2');
  btnGradColor := TSpeedButton.Create(Self);
  btnGradColor.Parent := p;
  btnGradColor.SetBounds(CX, 3, 40, 24);
  btnGradColor.OnClick := @GradColorClick;
  seGradOp := TFloatSpinEdit.Create(Self);
  seGradOp.Parent := p;
  seGradOp.SetBounds(CX + 50, 3, 70, 24);
  seGradOp.MinValue := 0;
  seGradOp.MaxValue := 100;
  seGradOp.Increment := 5;
  seGradOp.DecimalPlaces := 0;
  seGradOp.Hint := 'Opacity % of the second colour (the first one uses the Fill opacity)';
  seGradOp.ShowHint := True;
  seGradOp.OnChange := @GradChanged;
  with TLabel.Create(Self) do
  begin
    Parent := p;
    Caption := 'opacity %';
    SetBounds(CX + 126, 8, 70, 16);
  end;

  p := AddRow(41, 32, '');
  btnGradStops := TButton.Create(Self);
  btnGradStops.Parent := p;
  btnGradStops.SetBounds(8, 3, 280, 26);
  btnGradStops.OnClick := @GradStopsClick;

  p := AddRow(39, 32, '');
  btnGradPick := TButton.Create(Self);
  btnGradPick.Parent := p;
  btnGradPick.SetBounds(8, 3, 280, 26);
  btnGradPick.OnClick := @GradPickClick;

  p := AddRow(36, 32, 'Fill offset');
  seBucketOff := TFloatSpinEdit.Create(Self);
  seBucketOff.Parent := p;
  seBucketOff.SetBounds(CX + 20, 3, 80, 24);
  seBucketOff.MinValue := -50;
  seBucketOff.MaxValue := 50;
  seBucketOff.Increment := 0.5;
  seBucketOff.DecimalPlaces := 1;
  seBucketOff.Hint := 'How far the fill goes under its lines: positive overlaps them, negative keeps it away from them';
  seBucketOff.ShowHint := True;
  seBucketOff.OnChange := @BucketOptChanged;

  p := AddRow(24, 32, 'Hatching');
  cbHatch := TComboBox.Create(Self);
  cbHatch.Parent := p;
  cbHatch.Style := csDropDownList;
  for i := 0 to HatchCount - 1 do cbHatch.Items.Add(HatchNames[i]);
  cbHatch.SetBounds(CX, 3, 190, 24);
  cbHatch.OnChange := @HatchChanged;

  p := AddRow(25, 32, 'Line distance');
  seHatchSp := TFloatSpinEdit.Create(Self);
  seHatchSp.Parent := p;
  seHatchSp.SetBounds(CX, 3, 90, 24);
  seHatchSp.MinValue := 1;
  seHatchSp.MaxValue := 500;
  seHatchSp.Increment := 1;
  seHatchSp.DecimalPlaces := 1;
  seHatchSp.OnChange := @HatchChanged;

  p := AddRow(26, 32, 'Extra angle (deg)');
  seHatchAng := TFloatSpinEdit.Create(Self);
  seHatchAng.Parent := p;
  seHatchAng.SetBounds(CX + 20, 3, 90, 24);
  seHatchAng.MinValue := -180;
  seHatchAng.MaxValue := 180;
  seHatchAng.Increment := 5;
  seHatchAng.DecimalPlaces := 1;
  seHatchAng.OnChange := @HatchChanged;

  p := AddRow(27, 32, 'Line width');
  seHatchW := TFloatSpinEdit.Create(Self);
  seHatchW.Parent := p;
  seHatchW.SetBounds(CX, 3, 90, 24);
  seHatchW.MinValue := 0.1;
  seHatchW.MaxValue := 20;
  seHatchW.Increment := 0.1;
  seHatchW.DecimalPlaces := 1;
  seHatchW.OnChange := @HatchChanged;

  p := AddRow(28, 32, 'Line color');
  btnHatchColor := TSpeedButton.Create(Self);
  btnHatchColor.Parent := p;
  btnHatchColor.SetBounds(CX, 3, 40, 24);
  btnHatchColor.OnClick := @HatchColorClick;

  p := AddRow(29, 32, 'Spray radius');
  seSprayR := TFloatSpinEdit.Create(Self);
  seSprayR.Parent := p;
  seSprayR.SetBounds(CX, 3, 90, 24);
  seSprayR.MinValue := 1;
  seSprayR.MaxValue := 300;
  seSprayR.Increment := 1;
  seSprayR.DecimalPlaces := 1;
  seSprayR.OnChange := @SprayChanged;

  p := AddRow(30, 32, 'Dot size');
  seSprayDot := TFloatSpinEdit.Create(Self);
  seSprayDot.Parent := p;
  seSprayDot.SetBounds(CX, 3, 90, 24);
  seSprayDot.MinValue := 0.3;
  seSprayDot.MaxValue := 20;
  seSprayDot.Increment := 0.1;
  seSprayDot.DecimalPlaces := 1;
  seSprayDot.OnChange := @SprayChanged;

  p := AddRow(31, 32, 'Density');
  seSprayDens := TFloatSpinEdit.Create(Self);
  seSprayDens.Parent := p;
  seSprayDens.SetBounds(CX, 3, 90, 24);
  seSprayDens.MinValue := 0.5;
  seSprayDens.MaxValue := 100;
  seSprayDens.Increment := 0.5;
  seSprayDens.DecimalPlaces := 1;
  seSprayDens.OnChange := @SprayChanged;

  p := AddRow(32, 34, '');
  btnReseed := TButton.Create(Self);
  btnReseed.Parent := p;
  btnReseed.Caption := 'New random pattern';
  btnReseed.SetBounds(8, 4, 170, 26);
  btnReseed.OnClick := @ReseedClick;

  p := AddRow(23, 92, '');
  with TLabel.Create(Self) do
  begin
    Parent := p;
    Caption := 'Width';
    Left := 8;
    Top := 8;
  end;
  seImgW := TFloatSpinEdit.Create(Self);
  seImgW.Parent := p;
  seImgW.SetBounds(CX, 3, 110, 24);
  seImgW.MinValue := 1;
  seImgW.MaxValue := 100000;
  seImgW.DecimalPlaces := 1;
  seImgW.OnEditingDone := @ImageSizeChanged;
  with TLabel.Create(Self) do
  begin
    Parent := p;
    Caption := 'Height';
    Left := 8;
    Top := 38;
  end;
  seImgH := TFloatSpinEdit.Create(Self);
  seImgH.Parent := p;
  seImgH.SetBounds(CX, 33, 110, 24);
  seImgH.MinValue := 1;
  seImgH.MaxValue := 100000;
  seImgH.DecimalPlaces := 1;
  seImgH.OnEditingDone := @ImageSizeChanged;
  chkKeepRatio := TCheckBox.Create(Self);
  chkKeepRatio.Parent := p;
  chkKeepRatio.Caption := 'Keep proportions';
  chkKeepRatio.SetBounds(8, 64, 250, 20);
  chkKeepRatio.Checked := True;

  p := AddRow(51, 32, '');
  chkKey := TCheckBox.Create(Self);
  chkKey.Parent := p;
  chkKey.Caption := 'Transparent colour';
  chkKey.SetBounds(8, 5, 150, 20);
  chkKey.Hint := 'One colour of the picture (and the similar ones, see Tolerance) is transparent';
  chkKey.ShowHint := True;
  chkKey.OnChange := @KeyChanged;
  btnKey := TSpeedButton.Create(Self);
  btnKey.Parent := p;
  btnKey.SetBounds(CX + 60, 3, 40, 24);
  btnKey.OnClick := @KeyColorClick;

  p := AddRow(11, 32, 'Quote value');
  seQuote := TFloatSpinEdit.Create(Self);
  seQuote.Parent := p;
  seQuote.SetBounds(CX, 3, 110, 24);
  seQuote.MinValue := 0.01;
  seQuote.MaxValue := 1000000000;
  seQuote.DecimalPlaces := 2;
  seQuote.OnEditingDone := @QuoteChanged;

  p := AddRow(45, 40, '');
  ZoomPending := 1;
  ZoomTimer := TTimer.Create(Self);
  ZoomTimer.Enabled := False;
  ZoomTimer.Interval := 30;
  ZoomTimer.OnTimer := @ZoomTick;
  ZoomAnim := TTimer.Create(Self);
  ZoomAnim.Enabled := False;
  ZoomAnim.Interval := 15;
  ZoomAnim.OnTimer := @ZoomAnimTick;
  ZoomSettle := TTimer.Create(Self);
  ZoomSettle.Enabled := False;
  ZoomSettle.Interval := 250;
  ZoomSettle.OnTimer := @ZoomSettleTick;
  SnipTimer := TTimer.Create(Self);
  SnipTimer.Enabled := False;
  SnipTimer.Interval := 250;
  SnipTimer.OnTimer := @SnipApply;

  p := AddRow(47, 32, 'Soft edges %');
  seSoft := TSpinEdit.Create(Self);
  seSoft.Parent := p;
  seSoft.SetBounds(CX, 3, 90, 24);
  seSoft.MinValue := 0;
  seSoft.MaxValue := 100;
  seSoft.Increment := 10;
  seSoft.Hint := 'The stroke fades from its axis to transparency at the edges (0: hard edges, 100: it fades all the way from the axis)';
  seSoft.ShowHint := True;
  seSoft.OnChange := @SoftChanged;

  p := AddRow(53, 32, 'Brush width');
  seCloneW := TFloatSpinEdit.Create(Self);
  seCloneW.Parent := p;
  seCloneW.SetBounds(CX, 3, 90, 24);
  seCloneW.MinValue := 1;
  seCloneW.MaxValue := 2000;
  seCloneW.DecimalPlaces := 0;
  seCloneW.Increment := 5;
  seCloneW.Value := CloneW;
  seCloneW.Hint := 'Width of the brush of the clone tool and of the eraser (document units)';
  seCloneW.ShowHint := True;
  seCloneW.OnChange := @CloneChanged;
  p := AddRow(54, 32, 'Feather %');
  seCloneF := TFloatSpinEdit.Create(Self);
  seCloneF.Parent := p;
  seCloneF.SetBounds(CX, 3, 90, 24);
  seCloneF.MinValue := 0;
  seCloneF.MaxValue := 100;
  seCloneF.DecimalPlaces := 0;
  seCloneF.Increment := 10;
  seCloneF.Value := CloneF;
  seCloneF.Hint := 'The effect of the clone tool and of the eraser fades towards the edge of the brush (0: hard edge, 100: it fades from the centre)';
  seCloneF.ShowHint := True;
  seCloneF.OnChange := @CloneChanged;

  p := AddRow(52, 32, 'Sides');
  seSides := TSpinEdit.Create(Self);
  seSides.Parent := p;
  seSides.SetBounds(CX, 3, 90, 24);
  seSides.MinValue := 3;
  seSides.MaxValue := 200;
  seSides.Hint := 'Number of sides of the regular shape';
  seSides.ShowHint := True;
  seSides.OnChange := @SidesChanged;
  SidesTimer := TTimer.Create(Self);
  SidesTimer.Enabled := False;
  SidesTimer.Interval := 600;
  SidesTimer.OnTimer := @SidesApply;

  p := AddRow(48, 32, 'Tolerance %');
  seSelTol := TSpinEdit.Create(Self);
  seSelTol.Parent := p;
  seSelTol.SetBounds(CX, 3, 90, 24);
  seSelTol.MinValue := 0;
  seSelTol.MaxValue := 100;
  seSelTol.Increment := 5;
  seSelTol.Hint := 'How different from the colour clicked a colour can be to be part of the selection (0: only that colour)';
  seSelTol.ShowHint := True;
  seSelTol.OnChange := @SelTolChanged;
  SelTimer := TTimer.Create(Self);
  SelTimer.Enabled := False;
  SelTimer.Interval := 300;
  SelTimer.OnTimer := @SelApply;

  p := AddRow(49, 28, '');
  chkSelHole := TCheckBox.Create(Self);
  chkSelHole.Parent := p;
  chkSelHole.Caption := 'Transparent content';
  chkSelHole.SetBounds(8, 4, 280, 20);
  chkSelHole.Hint := 'The raster is transparent inside the selection: the layers under it show through';
  chkSelHole.ShowHint := True;
  chkSelHole.OnChange := @SelHoleChanged;

  p := AddRow(44, 32, 'Corner radius');
  seCorner := TFloatSpinEdit.Create(Self);
  seCorner.Parent := p;
  seCorner.SetBounds(CX, 3, 90, 24);
  seCorner.MinValue := 0;
  seCorner.MaxValue := 100000;
  seCorner.Increment := 1;
  seCorner.DecimalPlaces := 1;
  seCorner.Hint := 'Radius of the rounded corners (0: square corners; it cannot be more than half of the shorter side)';
  seCorner.ShowHint := True;
  seCorner.OnChange := @CornerChanged;
  seCorner.OnEditingDone := @CornerApply;
  CornerTimer := TTimer.Create(Self);
  CornerTimer.Enabled := False;
  CornerTimer.Interval := 700;
  CornerTimer.OnTimer := @CornerApply;

  p := AddRow(46, 32, 'Rotation');
  seRot := TFloatSpinEdit.Create(Self);
  seRot.Parent := p;
  seRot.SetBounds(CX, 3, 90, 24);
  seRot.MinValue := -360;
  seRot.MaxValue := 360;
  seRot.Increment := 1;
  seRot.DecimalPlaces := 1;
  seRot.Hint := 'How far the object is turned (counter-clockwise, in degrees). It turns about the centre of its box.';
  seRot.ShowHint := True;
  seRot.OnChange := @RotPropChanged;
  seRot.OnEditingDone := @RotPropApply;
  RotTimer := TTimer.Create(Self);
  RotTimer.Enabled := False;
  RotTimer.Interval := 600;
  RotTimer.OnTimer := @RotPropApply;

  p := AddRow(43, 32, 'Unit text');
  edQuoteUnit := TEdit.Create(Self);
  edQuoteUnit.Parent := p;
  edQuoteUnit.SetBounds(CX, 3, 110, 24);
  edQuoteUnit.Hint := 'Text shown after the number of the quote: mm, ft, m...';
  edQuoteUnit.ShowHint := True;
  edQuoteUnit.OnEditingDone := @QuoteChanged;

  p := AddRow(12, 32, 'Measure');
  cbAxis := TComboBox.Create(Self);
  cbAxis.Parent := p;
  cbAxis.Style := csDropDownList;
  cbAxis.Items.Add('Aligned');
  cbAxis.Items.Add('Horizontal');
  cbAxis.Items.Add('Vertical');
  cbAxis.SetBounds(CX, 3, 150, 24);
  cbAxis.OnChange := @QuoteChanged;

  p := AddRow(13, 28, '');
  chkDiam := TCheckBox.Create(Self);
  chkDiam.Parent := p;
  chkDiam.Caption := 'Show as diameter';
  chkDiam.SetBounds(8, 4, 250, 20);
  chkDiam.OnChange := @QuoteChanged;

  p := AddRow(22, 28, '');
  chkQuotePrint := TCheckBox.Create(Self);
  chkQuotePrint.Parent := p;
  chkQuotePrint.Caption := 'Only as reference';
  chkQuotePrint.SetBounds(8, 4, 280, 20);
  chkQuotePrint.OnChange := @QuoteChanged;

  p := AddRow(16, 32, 'Offset distance');
  seOff := TFloatSpinEdit.Create(Self);
  seOff.Parent := p;
  seOff.SetBounds(CX, 3, 110, 24);
  seOff.MinValue := -100000;
  seOff.MaxValue := 100000;
  seOff.DecimalPlaces := 2;
  seOff.OnEditingDone := @OffsetChanged;

  p := AddRow(17, 34, '');
  btnDetach := TButton.Create(Self);
  btnDetach.Parent := p;
  btnDetach.Caption := 'Detach from original';
  btnDetach.SetBounds(8, 4, 170, 26);
  btnDetach.OnClick := @DetachClick;

  for i := 1 to 4 do
  begin
    p := AddRow(17 + i, 32, '');
      lblA[i] := TLabel.Create(Self);
    lblA[i].Parent := p;
    lblA[i].Left := 8;
    lblA[i].Top := 8;
    seA[i] := TFloatSpinEdit.Create(Self);
    seA[i].Parent := p;
    seA[i].SetBounds(CX + 30, 3, 100, 24);
    seA[i].MinValue := -100000;
    seA[i].MaxValue := 100000;
    seA[i].DecimalPlaces := 2;
    seA[i].OnEditingDone := @ArrayChanged;
  end;

  p := AddRow(14, 140, '');
  lbCons := TListBox.Create(Self);
  lbCons.Parent := p;
  lbCons.SetBounds(8, 22, 270, 112);
  lbCons.OnClick := @ConsListClick;
  with TLabel.Create(Self) do
  begin
    Parent := p;
    Caption := 'Constraints on the selection';
    Left := 8;
    Top := 4;
  end;

  p := AddRow(15, 34, '');
  btnDelCons := TButton.Create(Self);
  btnDelCons.Parent := p;
  btnDelCons.Caption := 'Delete constraint';
  btnDelCons.SetBounds(8, 4, 150, 26);
  btnDelCons.OnClick := @DelConsClick;
  btnUntrim := TButton.Create(Self);
  btnUntrim.Parent := p;
  btnUntrim.Caption := 'Restore original';
  btnUntrim.SetBounds(166, 4, 120, 26);
  btnUntrim.OnClick := @UntrimClick;
end;

function TForm1.TargetShapes: TShapeArray;
begin
  if SelQuote <> nil then SetLength(Result, 0)
  else Result := SelShapes;
end;

// commands that do nothing without a selection are grayed
procedure TForm1.UpdateActionStates;
var
  fa, fb: TShape;
  fv: Integer;
  fx1, fy1, fx2, fy2: Double;
  k: TConstraintKind;
  hasSel, hasShapes, hasPath, hasJoint, inGroup: Boolean;
  ts0: TShapeArray;
  i: Integer;
begin
  hasSel := Length(Sel) > 0;
  ts0 := SelShapes;
  hasShapes := Length(ts0) > 0;
  // what a group is made of is not handled one piece at a time: the tools that work on single figures wait for them to be ungrouped
  inGroup := False;
  for i := 0 to High(ts0) do
    if ts0[i].GroupId > 0 then inGroup := True;
  for k := Low(TConstraintKind) to High(TConstraintKind) do
    if ConsButtons[k] <> nil then ConsButtons[k].Enabled := ConsUsable(k);
  toolArray.Enabled := hasShapes or (Tool = tlArray);
  // the selection tools work on a raster picture that is selected
  hasJoint := False;
  for i := 0 to High(ts0) do
    if ((ts0[i].Kind = skImage) or (ts0[i].SelTarget > 0)) and (ts0[i].GroupId = 0) then hasJoint := True;
  if toolWand <> nil then
  begin
    toolWand.Enabled := hasJoint or (Tool = tlWand);
    toolSelShape.Enabled := hasJoint or (Tool = tlSelShape);
    toolSelRect.Enabled := hasJoint or (Tool = tlSelRect);
    toolSelEllipse.Enabled := hasJoint or (Tool = tlSelEllipse);
    toolSelFree.Enabled := hasJoint or (Tool = tlSelFree);
    toolClone.Enabled := hasJoint or (Tool = tlClone);
    toolEraser.Enabled := hasJoint or (Tool = tlEraser);
  end;
  toolOffset.Enabled := (Length(OffsetTargets) > 0) and not inGroup;
  toolLight.Enabled := LayerHasMaterials(ActiveLayerObj);
  toolFillet.Enabled := FilletPair(fa, fb, fx1, fy1, fx2, fy2) or FilletCorner(fa, fv);
  toolFillet.Enabled := toolFillet.Enabled and not inGroup;
  toolChamfer.Enabled := toolFillet.Enabled;
  toolScale.Enabled := hasShapes or (Tool = tlScale);
  toolRotate.Enabled := hasShapes or (Tool = tlRotate);
  for i := 0 to High(ts0) do
    if (ts0[i].FA > 0) and (Tool <> tlRotate) then toolRotate.Enabled := False;
  // adding a point needs a path to be selected
  hasPath := False;
  for i := 0 to High(ts0) do
    if ts0[i].Kind = skSpline then hasPath := True;
  toolPathPoint.Enabled := (hasPath and not inGroup) or (Tool = tlPathPoint);
  // a joint can be added to a line, poly-line or polygon
  hasJoint := False;
  for i := 0 to High(ts0) do
    if ts0[i].Kind in [skLine, skPolyline, skPolygon] then hasJoint := True;
  toolVertex.Enabled := (hasJoint and not inGroup) or (Tool = tlVertex);
  hasJoint := False;
  for i := 0 to High(ts0) do
    if Joinable(ts0[i]) then hasJoint := True;
  toolJoin.Enabled := (hasJoint and not inGroup) or (Tool = tlJoin);
  MenuItem9.Enabled := hasShapes;
  MenuItem10.Enabled := hasShapes;
  if btnOp[0] <> nil then
  begin
    hasJoint := (Length(ts0) = 2) and not inGroup and BoolOverlap(ts0[0], ts0[1]);
    for i := 0 to 2 do btnOp[i].Enabled := hasJoint;
  end;
  hasJoint := False;
  for i := 0 to High(ts0) do
    if ts0[i].GroupId > 0 then hasJoint := True;
  if btnGroup <> nil then
  begin
    btnGroup.Enabled := Length(ts0) >= 2;
    miGroup.Enabled := btnGroup.Enabled;
    btnUngroup.Enabled := hasJoint;
    miUngroup.Enabled := hasJoint;
  end;
  if btnInvSel <> nil then btnInvSel.Enabled := InvertSelImage <> nil;
  if btnFlip <> nil then
  begin
    btnFlip.Enabled := FlipApplicable;
    btnMirror.Enabled := btnFlip.Enabled;
  end;
  if btnMerge <> nil then
  begin
    btnMerge.Enabled := (Length(ts0) = 2) and not inGroup and (ts0[0].Kind = skImage) and (ts0[1].Kind = skImage);
    miMerge.Enabled := btnMerge.Enabled;
  end;
end;

// with no object selected, the Properties show only what the tool in use has to do with: the rows of the others are hidden
procedure TForm1.ApplyToolRows(hasSel, isQ: Boolean);
type
  TRowSet = set of 0..63;
const
  Stroke: TRowSet = [1, 33, 3, 4, 5, 6];
  Fill: TRowSet = [2, 34];
var
  allowed: TRowSet;
  i: Integer;
begin
  for i := 55 to 57 do
    if Rows[i] <> nil then Rows[i].Visible := False;
  if (not hasSel) and (not isQ) and LayerPropsMode then
  begin
    // the layer that is active: its opacity, scale and background
    SyncLayerProps;
    for i := 1 to 54 do
      if Rows[i] <> nil then Rows[i].Visible := False;
    for i := 55 to 57 do Rows[i].Visible := True;
    Exit;
  end;
  if hasSel or isQ or (Tool = tlSelect) then Exit;
  allowed := [0];
  case Tool of
    tlLine, tlArrow, tlPolyline, tlSpline, tlPen, tlMarker: allowed := allowed + Stroke + [42, 47];
    tlPolygon, tlRect, tlSvgCode: allowed := allowed + Stroke + Fill + [42, 47];
    tlRoundRect: allowed := allowed + Stroke + Fill + [42, 47, 44];
    tlEllipse, tlArc, tlArc3, tlArcCSE: allowed := allowed + Stroke + Fill + [42, 47, 7];
    tlRegPoly: allowed := allowed + Stroke + Fill + [42, 47, 52];
    tlText: allowed := allowed + [1, 33, 47];
    tlAirbrush: allowed := allowed + [1, 33, 42, 29, 30, 31];
    tlBucket: allowed := allowed + Fill;
    tlVectorize: allowed := allowed + Stroke + Fill + [42];
    tlWand: allowed := allowed + [48];
    tlClone: allowed := allowed + [53, 54];
    tlEraser: allowed := allowed + [1, 33, 2, 34, 48, 53, 54];
    tlSnippet: allowed := allowed + [45];
  end;
  for i := 1 to High(Rows) do
    if (Rows[i] <> nil) and not (i in allowed) then Rows[i].Visible := False;
end;

procedure TForm1.RefreshProps;
var
  fltSel: Boolean;  ts: TShapeArray;
  st: TStyle;
  i, j: Integer;
  hasText, hasEll, isQ, hasSel, anyFillable: Boolean;
  rids: TIntArray;
  rang: Double;
  cl: TConstraintList;
  c: TConstraint;
  txt: string;
  circ: Boolean;
  q: TConstraint;
  pa, pb: TPR;
  arrSpec: TArraySpec;
  onlyImg, onlyBucket, onlySpray, onlyHatchable, onlyRect, onlyReg, onlySoft, gradOK, onlyText: Boolean;
  pa0, pb0: TPt;
  k: Integer;
begin
  if miFltApply <> nil then miFltApply.Enabled := Length(FilterTargets(fltSel)) > 0;  // the raster tools need the picture they work on: if it is gone (undo, delete) the tool goes back to the arrow
  if (Tool in [tlWand, tlSelShape, tlSelRect, tlSelEllipse, tlSelFree, tlClone, tlEraser]) and not CloneOn and not EraseOn then
    if (Doc.FindShape(ToolImg) = nil) or (Doc.FindShape(ToolImg).Kind <> skImage) or (Doc.FindShape(ToolImg).GroupId > 0) then
    begin
      SetTool(tlSelect);
      Exit;
    end;
  UpdateActionStates;
  if Rows[0] = nil then Exit;
  UpdatingProps := True;
  try
    ts := TargetShapes;
    q := SelQuote;
    isQ := q <> nil;
    hasSel := Length(ts) > 0;
    hasText := False;
    hasEll := False;
    anyFillable := False;
    for i := 0 to High(ts) do
    begin
      if ts[i].Kind = skText then hasText := True;
      if ts[i].Kind in [skEllipse, skArc] then hasEll := True;
    end;
    if isQ then
    begin
      lblTarget.Caption := 'Quote';
    end
    else if hasSel then
    begin
      st := ts[0].Style;
      if Length(ts) = 1 then
      begin
        lblTarget.Caption := 'Selected: ' + ShapeNames[ts[0].Kind] + ' #' + IntToStr(ts[0].Id);
        if ts[0].Bucket then lblTarget.Caption := 'Selected: fill #' + IntToStr(ts[0].Id);
        if ts[0].Spray then lblTarget.Caption := 'Selected: airbrush #' + IntToStr(ts[0].Id);
        if ts[0].SelTarget > 0 then lblTarget.Caption := 'Selected: selection #' + IntToStr(ts[0].Id);
        // the side that was clicked
        for i := 0 to High(Sel) do
          if (Sel[i].Shape = ts[0].Id) and (Sel[i].Idx = -1) and SideEnds(ts[0], Sel[i].Seg, pa0, pb0) then
            lblTarget.Caption := lblTarget.Caption + ' - side ' + IntToStr(Sel[i].Seg + 1);
      end
      else lblTarget.Caption := 'Selected: ' + IntToStr(Length(ts)) + ' objects';
    end
    else
    begin
      st := DefStyle;
      lblTarget.Caption := 'New objects (defaults)';
      if LayerPropsMode then lblTarget.Caption := 'Layer: ' + ActiveLayerObj.Name;
    end;
    for i := 1 to 10 do Rows[i].Visible := not isQ;
    Rows[33].Visible := not isQ;
    Rows[34].Visible := not isQ;
    Rows[23].Visible := False;
    Rows[51].Visible := False;
    for i := 24 to 32 do Rows[i].Visible := False;
    Rows[35].Visible := False;
    Rows[36].Visible := False;
    Rows[44].Visible := False;
    Rows[52].Visible := False;
    Rows[53].Visible := False;
    Rows[54].Visible := False;
    Rows[47].Visible := False;
    Rows[48].Visible := False;
    Rows[49].Visible := False;
    if hasSel and not isQ then UpdateSnipRow(SnipGroupOfSelection) else UpdateSnipRow(0);
    Rows[46].Visible := False;
    if hasSel and not isQ and SelRotInfo(rids, rang) then
    begin
      Rows[46].Visible := True;
      seRot.Value := Round(NormAngle(rang) * 1800 / Pi) / 10;
      // the arc of a fillet / the cut of a chamfer follows its lines: it cannot be turned by itself
      Rows[46].Enabled := True;
      for i := 0 to High(ts) do
        if ts[i].FA > 0 then Rows[46].Enabled := False;
    end;
    for i := 37 to 41 do Rows[i].Visible := False;
    Rows[42].Visible := hasSel and not isQ;
    if hasSel and not isQ then cbRendering.ItemIndex := IfThen(ts[0].Antialias, 0, 1);
    for i := 11 to 13 do Rows[i].Visible := isQ;
    Rows[43].Visible := False;
    Rows[22].Visible := isQ;
    Rows[14].Visible := hasSel or isQ;
    Rows[16].Visible := hasSel and (not isQ) and (ts[0].OffSrc > 0);
    arrSpec := nil;
    if hasSel and (not isQ) then arrSpec := Doc.ArrayOf(ts[0]);
    Rows[17].Visible := hasSel and (not isQ) and ((ts[0].OffSrc > 0) or (ts[0].MirSrc > 0) or (arrSpec <> nil));
    if arrSpec <> nil then btnDetach.Caption := 'Explode array' else btnDetach.Caption := 'Detach from original';
    for i := 18 to 21 do Rows[i].Visible := arrSpec <> nil;
    if (arrSpec = nil) and hasSel and (not isQ) and (ts[0].FA > 0) then
    begin
      Rows[18].Visible := True;
      if ts[0].Kind = skLine then
      begin
        Rows[19].Visible := True;
        lblA[1].Caption := 'Distance 1';
        lblA[2].Caption := 'Distance 2';
        seA[1].Value := ts[0].CD1;
        seA[2].Value := ts[0].CD2;
      end
      else
      begin
        lblA[1].Caption := 'Radius';
        seA[1].Value := ts[0].RX;
      end;
    end;
    if arrSpec <> nil then
    begin
      if arrSpec.Polar then
      begin
        lblA[1].Caption := 'Items';
        lblA[2].Caption := 'Angle (deg)';
        seA[1].Value := arrSpec.Count;
        seA[2].Value := arrSpec.Total;
        Rows[20].Visible := False;
        Rows[21].Visible := False;
      end
      else
      begin
        lblA[1].Caption := 'Columns';
        lblA[2].Caption := 'Rows';
        lblA[3].Caption := 'Step X';
        lblA[4].Caption := 'Step Y';
        seA[1].Value := arrSpec.Cols;
        seA[2].Value := arrSpec.Rows;
        seA[3].Value := arrSpec.DX;
        seA[4].Value := arrSpec.DY;
      end;
    end;
    if Rows[16].Visible then seOff.Value := ts[0].OffDist * Doc.OffsetFactor(Doc.FindShape(ts[0].OffSrc));
    Rows[15].Visible := hasSel or isQ;
    btnUntrim.Visible := False;
    for i := 0 to High(ts) do
      if (Length(ts[i].Trims) > 0) or (Length(ts[i].Extends) > 0) then btnUntrim.Visible := True;
    if isQ then
    begin
      seQuote.Value := IfThen((q.Kind = ckRadius) and q.Diam, q.Value * 2, q.Value) * Doc.QuoteScale(q);
      Rows[43].Visible := q.Kind <> ckAngle;
      edQuoteUnit.Text := q.UnitText;
      Rows[12].Visible := (q.Kind = ckDistance) and ((Length(q.Refs) = 1) or
        (Doc.PointOf(q.Refs[0], pa) and Doc.PointOf(q.Refs[1], pb)));
      cbAxis.ItemIndex := q.Axis;
      Rows[13].Visible := q.Kind = ckRadius;
      chkDiam.Checked := q.Diam;
      chkQuotePrint.Checked := q.NoPrint;
    end
    else
    begin
      if hasSel and (ts[0].Kind = skText) then
      begin
        SetSwatch(btnStroke, ts[0].Style.Fill, ts[0].Style.FillTr);
        chkNoStroke.Checked := ts[0].Style.Fill = NoColor;
      end
      else
      begin
        SetSwatch(btnStroke, st.Stroke, st.StrokeTr);
        if StrokeMaterial(st) > 0 then SetMatSwatch(btnStroke, StrokeMaterial(st) - 1);
        chkNoStroke.Checked := st.Stroke = NoColor;
      end;
      SetSwatch(btnFill, st.Fill, st.FillTr);
      if FillMaterial(st) > 0 then SetMatSwatch(btnFill, FillMaterial(st) - 1);
      chkNoFill.Checked := st.Fill = NoColor;
      seWidth.Value := st.Width;
      QuickBusy := True;
      QuickTol.Value := DefWandTol;
      for i := 0 to High(ts) do
        if (ts[i].Kind = skImage) and ts[i].KeyOn then
        begin
          QuickTol.Value := ts[i].KeyTol;
          Break;
        end;
      for i := 0 to High(ts) do
        if (ts[i].SelTarget > 0) and ts[i].SelWand then
        begin
          QuickTol.Value := ts[i].SelTol;
          Break;
        end;
      QuickBusy := False;
      QuickPasteBox.Hint := QuickPasteHint;
      QuickPasteBox.Invalidate;
      QuickW := st.Width;                     // the Thickness of the Properties has the priority
      QuickSample.Invalidate;
      if hasSel and (AllSelections(ts) or AllRasterShapes(ts)) then
      begin
        QuickStroke := DefStyle.Stroke;
        QuickFill := DefStyle.Fill;
        QuickStrokeTr := DefStyle.StrokeTr;
        QuickFillTr := DefStyle.FillTr;
        QuickStrokeMat := StrokeMaterial(DefStyle);
        QuickFillMat := FillMaterial(DefStyle);
      end
      else begin
        if hasSel and (ts[0].Kind = skText) then
        begin
          QuickStroke := ts[0].Style.Fill;
          QuickStrokeMat := FillMaterial(ts[0].Style);
          QuickStrokeTr := ts[0].Style.FillTr;
        end
        else
        begin
          QuickStroke := st.Stroke;
          QuickStrokeMat := StrokeMaterial(st);
          QuickStrokeTr := st.StrokeTr;
        end;
        QuickFillTr := st.FillTr;
        QuickFill := st.Fill;
        QuickFillMat := FillMaterial(st);
      end;
      QuickDash := Ord(st.Dash);
      QuickColors.Invalidate;
      QuickDashSample.Invalidate;
      QuickSample.Invalidate;
      if hasSel and (ts[0].Kind = skText) then seStrokeOp.Value := (255 - st.FillTr) * 100 / 255
      else seStrokeOp.Value := (255 - st.StrokeTr) * 100 / 255;
      seFillOp.Value := (255 - st.FillTr) * 100 / 255;
      cbCap.ItemIndex := Ord(st.Cap);
      cbJoin.ItemIndex := Ord(st.Join);
      cbDash.ItemIndex := Ord(st.Dash);
      circ := DefCirc;
      if hasEll then
        for i := 0 to High(ts) do
          if ts[i].Kind in [skEllipse, skArc] then
          begin
            circ := ts[i].Circ;
            Break;
          end;
      chkCirc.Checked := circ;
      Rows[7].Visible := hasEll or not hasSel;
      Rows[8].Visible := hasText;
      Rows[9].Visible := hasText;
      Rows[10].Visible := hasSel;
      if hasText then Rows[34].Visible := False;       // a text has one colour: its stroke opacity
      // a text has no outline, no corners and no antialiasing switch: only its colour, opacity, font and size count
      onlyText := hasText;
      for i := 0 to High(ts) do
        if ts[i].Kind <> skText then onlyText := False;
      if onlyText then
      begin
        for i := 2 to 6 do Rows[i].Visible := False;
        Rows[42].Visible := False;
        SetRowCaption(1, 'Text color');
        SetRowCaption(33, 'Text opacity %');
      end
      else
      begin
        SetRowCaption(1, 'Stroke color');
        SetRowCaption(33, 'Stroke opacity %');
      end;
      Rows[50].Visible := onlyText;
      if hasText then
        for i := 0 to High(ts) do
          if ts[i].Kind = skText then
          begin
            edText.Text := ts[i].Text;
            seFont.Value := ts[i].FontSize;
            k := 0;
            if ts[i].FontName <> '' then
            begin
              k := cbFont.Items.IndexOf(ts[i].FontName);
              if k < 0 then k := cbFont.Items.Add(ts[i].FontName);
            end;
            cbFont.ItemIndex := k;
            Break;
          end;
      if hasSel then chkRef.Checked := ts[0].IsRef;
      onlyImg := hasSel;
      for i := 0 to High(ts) do
        if ts[i].Kind <> skImage then onlyImg := False;
      if onlyImg then
      begin
        for i := 1 to 7 do Rows[i].Visible := False;
        Rows[33].Visible := False;
        Rows[34].Visible := False;
        seImgW.Value := Abs(ts[0].P[1].x - ts[0].P[0].x);
        seImgH.Value := Abs(ts[0].P[1].y - ts[0].P[0].y);
      end;
      Rows[23].Visible := onlyImg;
      Rows[51].Visible := onlyImg;
      if onlyImg then
      begin
        chkKey.Checked := ts[0].KeyOn;
        if ts[0].KeyOn then SetSwatch(btnKey, ts[0].KeyColor) else SetSwatch(btnKey, KeyDefaultColor);
      end;
      // airbrush strokes (or the airbrush tool with nothing selected): spray values
      onlySpray := hasSel;
      for i := 0 to High(ts) do
        if not ts[i].Spray then onlySpray := False;
      if onlySpray or ((not hasSel) and (Tool = tlAirbrush)) then
      begin
        for i := 2 to 7 do Rows[i].Visible := False;
        Rows[34].Visible := False;
        for i := 29 to 31 do Rows[i].Visible := True;
        Rows[32].Visible := hasSel;
        if onlySpray then
        begin
          seSprayR.Value := ts[0].SprayR;
          seSprayDot.Value := ts[0].SprayDot;
          seSprayDens.Value := ts[0].SprayDens;
        end
        else
        begin
          seSprayR.Value := DefSprayR;
          seSprayDot.Value := DefSprayDot;
          seSprayDens.Value := DefSprayDens;
        end;
      end;
      // free strokes (or the marker with nothing selected): soft edges
      onlySoft := hasSel;
      for i := 0 to High(ts) do
        if (ts[i].Kind = skImage) or ts[i].Spray or ts[i].Bucket then onlySoft := False;
      if onlySoft or ((not hasSel) and (Tool in [tlLine, tlArrow, tlPolyline, tlPolygon, tlRect, tlRoundRect, tlEllipse, tlArc,
        tlArc3, tlArcCSE, tlSpline, tlText, tlSvgCode, tlPen, tlMarker])) then
      begin
        Rows[47].Visible := True;
        if onlySoft then seSoft.Value := ts[0].Soft else seSoft.Value := DefSoft;
      end;
      // selections of a picture: tolerance of the wand and transparency
      onlyImg := hasSel;
      anyFillable := False;
      for i := 0 to High(ts) do
      begin
        if ts[i].SelTarget <= 0 then onlyImg := False;
        if ts[i].SelWand then anyFillable := True;
      end;
      if onlyImg then
      begin
        Rows[49].Visible := True;
        chkSelHole.Checked := ts[0].SelHole;
        if anyFillable then
        begin
          Rows[48].Visible := True;
          seSelTol.Value := ts[0].SelTol;
        end;
      end
      else if (not hasSel) and (Tool = tlWand) then
      begin
        Rows[48].Visible := True;
        seSelTol.Value := DefWandTol;
      end;
      if (not hasSel) and (Tool in [tlClone, tlEraser]) then
      begin
        Rows[53].Visible := True;
        Rows[54].Visible := True;
      end;
      if (not hasSel) and (Tool = tlEraser) then
      begin
        Rows[48].Visible := True;
        seSelTol.Value := DefWandTol;
      end;
      // regular shapes: the number of sides
      onlyReg := hasSel;
      for i := 0 to High(ts) do
        if not ts[i].Reg then onlyReg := False;
      if onlyReg or ((not hasSel) and (Tool = tlRegPoly)) then
      begin
        Rows[52].Visible := True;
        if onlyReg then seSides.Value := Length(ts[0].P) else seSides.Value := DefSides;
      end;
      // rectangles (or the rounded rectangle tool with nothing selected): radius of the corners
      onlyRect := hasSel;
      for i := 0 to High(ts) do
        if ts[i].Kind <> skRect then onlyRect := False;
      if onlyRect or ((not hasSel) and (Tool = tlRoundRect)) then
      begin
        Rows[44].Visible := True;
        if onlyRect then seCorner.Value := ts[0].Corner else seCorner.Value := DefCorner;
      end;
      // polygons and paths can be hatched too
      onlyHatchable := hasSel;
      for i := 0 to High(ts) do
        if (ts[i].Bucket) or not Hatchable(ts[i]) then onlyHatchable := False;
      if onlyHatchable then
      begin
        for i := 24 to 28 do Rows[i].Visible := True;
        cbHatch.ItemIndex := ts[0].HatchPat;
        seHatchSp.Value := ts[0].HatchSp;
        seHatchAng.Value := ts[0].HatchAng;
        seHatchW.Value := ts[0].HatchW;
        SetSwatch(btnHatchColor, ts[0].HatchColor);
        for i := 25 to 28 do Rows[i].Visible := ts[0].HatchPat > 0;
      end;
      // fills made by the paint bucket: colour and hatching
      onlyBucket := hasSel;
      for i := 0 to High(ts) do
        if not ts[i].Bucket then onlyBucket := False;
      if onlyBucket then
      begin
        for i := 3 to 7 do Rows[i].Visible := False;
        Rows[1].Visible := False;
        Rows[33].Visible := False;
        for i := 24 to 28 do Rows[i].Visible := True;
        Rows[35].Visible := True;
        Rows[36].Visible := True;
        chkBucketLower.Checked := not ts[0].BucketIgnoreLower;
        seBucketOff.Value := ts[0].BucketOffset;
        cbHatch.ItemIndex := ts[0].HatchPat;
        seHatchSp.Value := ts[0].HatchSp;
        seHatchAng.Value := ts[0].HatchAng;
        seHatchW.Value := ts[0].HatchW;
        SetSwatch(btnHatchColor, ts[0].HatchColor);
        for i := 25 to 28 do Rows[i].Visible := ts[0].HatchPat > 0;
      end;
    end;
    // gradient: any shape that has a fill
    gradOK := hasSel and Rows[34].Visible;
    for i := 0 to High(ts) do
      if (ts[i].Kind in [skText, skImage]) or ts[i].Spray then gradOK := False;
    if gradOK then
    begin
      Rows[37].Visible := True;
      chkGrad.Checked := ts[0].GradOn;
      Rows[38].Visible := ts[0].GradOn;
      Rows[39].Visible := ts[0].GradOn;
      Rows[40].Visible := ts[0].GradOn;
      Rows[41].Visible := ts[0].GradOn;
      if Length(ts[0].GradMid) = 0 then btnGradStops.Caption := 'Colour stops in between (none)...'
      else btnGradStops.Caption := 'Colour stops in between (' + IntToStr(Length(ts[0].GradMid)) + ')...';
      cbGradType.ItemIndex := Ord(ts[0].GradRadial);
      if ts[0].GradOn then
      begin
        SetSwatch(btnGradColor, ts[0].GradColor, ts[0].GradTr);
        seGradOp.Value := Round((255 - ts[0].GradTr) * 100 / 255);
        if GradPickId = ts[0].Id then btnGradPick.Caption := 'Click a line or path in the drawing (empty space: none)...'
        else if (ts[0].GradRef > 0) and (Doc.FindShape(ts[0].GradRef) <> nil) then
          btnGradPick.Caption := 'Pick reference geometry (now: ' + ShapeNames[Doc.FindShape(ts[0].GradRef).Kind] + ' #' + IntToStr(ts[0].GradRef) + ')'
        else if ts[0].GradRadial then btnGradPick.Caption := 'Pick reference geometry (now: centre of the shape)'
        else btnGradPick.Caption := 'Pick reference geometry (now: left to right)';
      end;
    end;
    // constraints list
    lbCons.Items.Clear;
    for i := 0 to High(ts) do
    begin
      cl := Doc.ConstraintsOf(ts[i].Id);
      try
        for j := 0 to cl.Count - 1 do
        begin
          c := cl[j];
          if lbCons.Items.IndexOfObject(c) >= 0 then Continue;
          txt := ConstraintNames[c.Kind];
          if c.IsQuote then txt := txt + ' = ' + FmtNum(c.Value);
          lbCons.Items.AddObject(txt + '  (#' + IntToStr(c.Id) + ')', c);
        end;
      finally
        cl.Free;
      end;
    end;
    if isQ then
    begin
      lbCons.Items.AddObject(ConstraintNames[q.Kind] + ' = ' + FmtNum(q.Value) + '  (#' + IntToStr(q.Id) + ')', q);
      lbCons.ItemIndex := 0;
    end;
  finally
    ApplyToolRows(Length(TargetShapes) > 0, SelQuote <> nil);
    UpdateQuickEnabled;
    RelayoutProps;
    UpdatingProps := False;
  end;
  AutoRotMode;
  SyncTreeSel;
end;

procedure TForm1.ImageSizeChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  w, h, w0, h0, x0, y0: Double;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  if Length(ts) = 0 then Exit;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    if ts[i].Kind <> skImage then Continue;
    w0 := Abs(ts[i].P[1].x - ts[i].P[0].x);
    h0 := Abs(ts[i].P[1].y - ts[i].P[0].y);
    if (w0 < 1e-6) or (h0 < 1e-6) then Continue;
    w := seImgW.Value;
    h := seImgH.Value;
    if chkKeepRatio.Checked then
    begin
      if Sender = seImgW then h := w * h0 / w0 else w := h * w0 / h0;
    end;
    // the top-left corner stays where it is
    x0 := Min(ts[i].P[0].x, ts[i].P[1].x);
    y0 := Min(ts[i].P[0].y, ts[i].P[1].y);
    ts[i].P[0] := MakePt(x0, y0);
    ts[i].P[1] := MakePt(x0 + w, y0 + h);
  end;
  Doc.Solve([]);
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.BucketOptChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].Bucket then
    begin
      ts[i].BucketIgnoreLower := not chkBucketLower.Checked;
      ts[i].BucketOffset := seBucketOff.Value;
    end;
  Doc.UpdateFillets;
  Commit;
  RefreshProps;
  Redraw;
end;

type
  // the dialog that edits the colour stops of a gradient between its first and last colour
  TGradStopsDlg = class
    Form: TForm;
    List: TListBox;
    sePos, seOp: TSpinEdit;
    Swatch: TPanel;
    Stops: TGradStops;
    First: Integer;
    Busy: Boolean;
    procedure Fill(sel: Integer);
    procedure ListClick(Sender: TObject);
    procedure ValueChange(Sender: TObject);
    procedure SwatchClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
  end;

procedure TGradStopsDlg.Fill(sel: Integer);
var
  i: Integer;
begin
  Busy := True;
  List.Items.Clear;
  for i := 0 to High(Stops) do
    List.Items.Add(Format('%d%%   #%.2x%.2x%.2x   opacity %d%%', [Round(Stops[i].Pos * 100), Stops[i].Col and $FF,
      (Stops[i].Col shr 8) and $FF, (Stops[i].Col shr 16) and $FF, Round((255 - Stops[i].Tr) * 100 / 255)]));
  if (sel >= 0) and (sel < List.Items.Count) then List.ItemIndex := sel;
  i := List.ItemIndex;
  sePos.Enabled := i >= 0;
  seOp.Enabled := i >= 0;
  Swatch.Enabled := i >= 0;
  if i >= 0 then
  begin
    sePos.Value := Round(Stops[i].Pos * 100);
    seOp.Value := Round((255 - Stops[i].Tr) * 100 / 255);
    Swatch.Color := TColor(Stops[i].Col);
  end;
  Busy := False;
end;

procedure TGradStopsDlg.ListClick(Sender: TObject);
begin
  Fill(List.ItemIndex);
end;

procedure TGradStopsDlg.ValueChange(Sender: TObject);
var
  i, k: Integer;
  st: TGradStop;
begin
  i := List.ItemIndex;
  if Busy or (i < 0) then Exit;
  Stops[i].Pos := sePos.Value / 100;
  Stops[i].Tr := 255 - Round(seOp.Value * 255 / 100);
  // keep them in order of position
  st := Stops[i];
  k := i;
  while (k > 0) and (Stops[k - 1].Pos > st.Pos) do
  begin
    Stops[k] := Stops[k - 1];
    Dec(k);
  end;
  while (k < High(Stops)) and (Stops[k + 1].Pos < st.Pos) do
  begin
    Stops[k] := Stops[k + 1];
    Inc(k);
  end;
  Stops[k] := st;
  Fill(k);
end;

procedure TGradStopsDlg.SwatchClick(Sender: TObject);
var
  cd: TColorDialog;
begin
  if List.ItemIndex < 0 then Exit;
  cd := TColorDialog.Create(Form);
  cd.OnShow := @Form1.CenterCommonDlg;
  try
    cd.Color := TColor(Stops[List.ItemIndex].Col);
    if cd.Execute then
    begin
      Stops[List.ItemIndex].Col := Integer(cd.Color) and $FFFFFF;
      Fill(List.ItemIndex);
    end;
  finally
    cd.Free;
  end;
end;

// a new stop in the middle of the widest gap (between 0, the stops and 1), with the colour before it
procedure TGradStopsDlg.AddClick(Sender: TObject);
var
  i, at: Integer;
  a, b, bestGap: Double;
  col: Integer;
begin
  at := 0;
  bestGap := -1;
  a := 0;
  col := First;
  for i := 0 to Length(Stops) do
  begin
    if i < Length(Stops) then b := Stops[i].Pos else b := 1;
    if b - a > bestGap then
    begin
      bestGap := b - a;
      at := i;
      if i = 0 then col := First else col := Stops[i - 1].Col;
    end;
    if i < Length(Stops) then a := Stops[i].Pos;
  end;
  a := 0;
  if at > 0 then a := Stops[at - 1].Pos;
  SetLength(Stops, Length(Stops) + 1);
  for i := High(Stops) downto at + 1 do Stops[i] := Stops[i - 1];
  Stops[at].Pos := a + bestGap / 2;
  Stops[at].Col := col;
  Stops[at].Tr := 0;
  Fill(at);
end;

procedure TGradStopsDlg.RemoveClick(Sender: TObject);
var
  i, k: Integer;
begin
  k := List.ItemIndex;
  if k < 0 then Exit;
  for i := k to High(Stops) - 1 do Stops[i] := Stops[i + 1];
  SetLength(Stops, Length(Stops) - 1);
  Fill(Min(k, High(Stops)));
end;

function EditGradStops(var mids: TGradStops; firstColor: Integer): Boolean;
var
  d: TGradStopsDlg;
  f: TForm;
  b: TButton;
  l: TLabel;
begin
  d := TGradStopsDlg.Create;
  f := TForm.CreateNew(Application);
  try
    d.Form := f;
    d.Stops := Copy(mids);
    d.First := firstColor;
    f.Caption := 'Gradient stops';
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 420;
    f.ClientHeight := 300;
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Stops between the first colour (0%) and the second colour (100%):';
    l.SetBounds(12, 10, 400, 18);
    d.List := TListBox.Create(f);
    d.List.Parent := f;
    d.List.SetBounds(12, 32, 396, 130);
    d.List.OnClick := @d.ListClick;
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Add a stop';
    b.SetBounds(12, 170, 120, 26);
    b.OnClick := @d.AddClick;
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Remove the stop';
    b.SetBounds(140, 170, 130, 26);
    b.OnClick := @d.RemoveClick;
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Position %';
    l.SetBounds(12, 212, 80, 18);
    d.sePos := TSpinEdit.Create(f);
    d.sePos.Parent := f;
    d.sePos.SetBounds(90, 208, 70, 26);
    d.sePos.MinValue := 0;
    d.sePos.MaxValue := 100;
    d.sePos.OnChange := @d.ValueChange;
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Opacity %';
    l.SetBounds(180, 212, 70, 18);
    d.seOp := TSpinEdit.Create(f);
    d.seOp.Parent := f;
    d.seOp.SetBounds(250, 208, 70, 26);
    d.seOp.MinValue := 0;
    d.seOp.MaxValue := 100;
    d.seOp.OnChange := @d.ValueChange;
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Colour';
    l.SetBounds(335, 212, 50, 18);
    d.Swatch := TPanel.Create(f);
    d.Swatch.Parent := f;
    d.Swatch.SetBounds(378, 208, 30, 26);
    d.Swatch.BevelOuter := bvLowered;
    d.Swatch.OnClick := @d.SwatchClick;
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'OK';
    b.ModalResult := mrOk;
    b.Default := True;
    b.SetBounds(228, 258, 84, 28);
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Cancel';
    b.ModalResult := mrCancel;
    b.Cancel := True;
    b.SetBounds(324, 258, 84, 28);
    d.Fill(0);
    Result := f.ShowModal = mrOk;
    if Result then mids := Copy(d.Stops);
  finally
    f.Free;
    d.Free;
  end;
end;

procedure TForm1.GradStopsClick(Sender: TObject);
var
  ts: TShapeArray;
  mids: TGradStops;
  i: Integer;
begin
  ts := TargetShapes;
  if (Length(ts) = 0) or not ts[0].GradOn then Exit;
  mids := Copy(ts[0].GradMid);
  if not EditGradStops(mids, ts[0].Style.Fill) then Exit;
  Checkpoint;
  for i := 0 to High(ts) do ts[i].GradMid := Copy(mids);
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.GradChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  if Length(ts) = 0 then Exit;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    if Sender = chkGrad then
    begin
      ts[i].GradOn := chkGrad.Checked;
      if chkGrad.Checked and (ts[i].Style.Fill = NoColor) then ts[i].Style.Fill := TColor($F0C080);
    end
    else if Sender = seGradOp then ts[i].GradTr := 255 - Round(seGradOp.Value * 255 / 100)
    else if Sender = cbGradType then ts[i].GradRadial := cbGradType.ItemIndex = 1;
  end;
  if (Sender = chkGrad) and not chkGrad.Checked then GradPickId := 0;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.RenderingChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  if Length(ts) = 0 then Exit;
  Checkpoint;
  for i := 0 to High(ts) do ts[i].Antialias := cbRendering.ItemIndex <> 1;
  Commit;
  RefreshProps;
end;

procedure TForm1.GradColorClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  col: TColor;
  pct: Double;
begin
  ts := TargetShapes;
  if Length(ts) = 0 then Exit;
  col := ToCol(ts[0].GradColor);
  pct := 100;
  if not PickColor('Second colour of the gradient', col, pct, False) then Exit;
  Checkpoint;
  for i := 0 to High(ts) do ts[i].GradColor := col;
  Commit;
  RefreshProps;
  Redraw;
end;

// "Pick reference geometry": the next click in the drawing chooses the line or path the gradient runs along
procedure TForm1.GradPickClick(Sender: TObject);
var
  ts: TShapeArray;
begin
  ts := TargetShapes;
  if (Length(ts) = 0) or not ts[0].GradOn then Exit;
  GradPickId := ts[0].Id;
  if ts[0].GradRadial then
    SetStatus('Gradient: click a circle (its centre and radius) or a line (from the centre to the edge). Click an empty place for none, right-click or Esc to cancel.')
  else
    SetStatus('Gradient: click the line or path it should run along (from colour 1 to colour 2). Click an empty place for none, right-click or Esc to cancel.');
  RefreshProps;
end;

procedure TForm1.GradPick(px, py: Double);
var
  ref: TRef;
  r, s: TShape;
begin
  s := Doc.FindShape(GradPickId);
  if s = nil then
  begin
    GradPickId := 0;
    Exit;
  end;
  if not HitShape(px, py, ref) then
  begin
    Checkpoint;
    s.GradRef := 0;
    Commit;
    SetStatus('Gradient: no reference, it runs left to right across the shape.');
  end
  else
  begin
    r := Doc.FindShape(ref.Shape);
    if (r = nil) or (r = s) or (r.Kind in [skText, skImage]) then
    begin
      SetStatus('Gradient: pick a line, an arrow, a polyline or a path (a curve), not this object.');
      Exit;
    end;
    Checkpoint;
    s.GradRef := r.Id;
    Commit;
    if s.GradRadial then SetStatus('Gradient: radial, defined by ' + ShapeNames[r.Kind] + ' #' + IntToStr(r.Id) + ' (colour 1 at the centre, colour 2 at the edge).')
    else SetStatus('Gradient: it now runs along ' + ShapeNames[r.Kind] + ' #' + IntToStr(r.Id) + ', from its start (colour 1) to its end (colour 2).');
  end;
  GradPickId := 0;
  RefreshProps;
  Redraw;
end;

procedure TForm1.HatchChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    if not (ts[i].Bucket or Hatchable(ts[i])) then Continue;
    if Sender = cbHatch then ts[i].HatchPat := Max(0, cbHatch.ItemIndex)
    else if Sender = seHatchSp then ts[i].HatchSp := seHatchSp.Value
    else if Sender = seHatchAng then ts[i].HatchAng := seHatchAng.Value
    else if Sender = seHatchW then ts[i].HatchW := seHatchW.Value;
  end;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.HatchColorClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
  col: TColor;
  pct: Double;
begin
  ts := TargetShapes;
  if Length(ts) = 0 then Exit;
  col := ToCol(ts[0].HatchColor);
  pct := 100;
  if not PickColor('Hatching colour', col, pct, False) then Exit;
  Checkpoint;
  for i := 0 to High(ts) do
    if ts[i].Bucket or Hatchable(ts[i]) then ts[i].HatchColor := col;
  Commit;
  RefreshProps;
  Redraw;
end;

// hatch lines of a fill (clipped to its area)
procedure TForm1.DrawHatch(cnv: TCanvas; s: TShape; z: Double);
var
  sg: TFPtArray;
  i, w, r: Integer;
  a, b: TPoint;
begin
  sg := BucketHatch(s);
  if Length(sg) < 2 then Exit;
  w := Max(1, Round(s.HatchW * z));
  cnv.Pen.Style := psSolid;
  cnv.Pen.Color := ToCol(s.HatchColor);
  cnv.Pen.Width := w;
  cnv.Brush.Style := bsSolid;
  cnv.Brush.Color := ToCol(s.HatchColor);
  r := Max(1, w);
  i := 0;
  while i + 1 < Length(sg) do
  begin
    a := Point(Round(sg[i].x * z), Round(sg[i].y * z));
    b := Point(Round(sg[i + 1].x * z), Round(sg[i + 1].y * z));
    if (a.x = b.x) and (a.y = b.y) then cnv.Ellipse(a.x - r, a.y - r, a.x + r + 1, a.y + r + 1)
    else cnv.Line(a.x, a.y, b.x, b.y);
    Inc(i, 2);
  end;
  cnv.Brush.Style := bsClear;
end;

const
  QuickChoices: array[0..4] of Double = (1, 2, 4, 8, 12);

// a sample of the stroke: a horizontal line of the given thickness (round ends) on a white ground
procedure DrawStrokeSample(cnv: TCanvas; const R: TRect; w: Double; hot: Boolean; col: Integer; dash: Integer = 0; padR: Integer = 12);
var
  t, y, x1, x2, ln, x, k, on, off: Integer;
begin
  if hot then cnv.Brush.Color := TColor($F0D8B0) else cnv.Brush.Color := TColor($B8B8B8);
  cnv.Pen.Color := TColor($808080);
  cnv.Pen.Style := psSolid;
  cnv.Pen.Width := 1;
  cnv.Rectangle(R);
  t := Max(1, Min(R.Bottom - R.Top - 6, Round(w)));
  y := (R.Top + R.Bottom) div 2;
  x1 := R.Left + 12;
  x2 := R.Right - padR;
  if col = NoColor then
  begin
    // no stroke: a dotted outline of the line
    cnv.Brush.Style := bsClear;
    cnv.Pen.Color := TColor($707070);
    cnv.Pen.Style := psDot;
    cnv.Rectangle(x1, y - t div 2, x2, y - t div 2 + t);
    cnv.Pen.Style := psSolid;
    cnv.Brush.Style := bsSolid;
    Exit;
  end;
  cnv.Brush.Color := TColor(col);
  cnv.Pen.Color := TColor(col);
  if dash > 0 then
  begin
    // dashed: the pieces are as long as a few times the thickness
    ln := Max(3, t);
    x := x1;
    k := 0;
    while x < x2 do
    begin
      case dash of
        1: begin on := 4 * ln; off := 2 * ln; end;
        2: begin on := ln; off := ln; end;
      else
        if k mod 2 = 0 then begin on := 4 * ln; off := 2 * ln; end
        else begin on := ln; off := 2 * ln; end;
      end;
      cnv.Rectangle(x, y - t div 2, Min(x2, x + on), y - t div 2 + t);
      x := x + on + off;
      Inc(k);
    end;
  end
  else if t <= 2 then cnv.Rectangle(x1, y - t div 2, x2, y - t div 2 + t)
  else cnv.RoundRect(x1, y - t div 2, x2, y - t div 2 + t, t, t);
end;

// a control that does not apply to the tool in use is grayed: every other point is painted with the background
procedure TForm1.DimQuick(pb: TPaintBox);
var
  x, y: Integer;
begin
  if pb.Enabled then Exit;
  pb.Canvas.Pen.Color := QuickPanel.Color;
  for y := 0 to pb.Height - 1 do
    for x := (y and 1) to pb.Width - 1 do
      if x and 1 = (y and 1) then pb.Canvas.Pixels[x, y] := ColorToRGB(clBtnFace);
end;

// what the bottom panel can do with the tool in use: the rest is grayed (it stays where it is)
procedure TForm1.UpdateQuickEnabled;
var
  useStroke, useCol: Boolean;
  wasT, wasD, wasC: Boolean;
begin
  if QuickSample = nil then Exit;
  if Tool = tlSelect then
  begin
    useStroke := True;
    useCol := True;
  end
  else
  begin
    useStroke := Tool in [tlLine, tlArrow, tlPolyline, tlPolygon, tlRect, tlRoundRect, tlEllipse, tlArc, tlArc3, tlArcCSE, tlSpline,
      tlSvgCode, tlRegPoly, tlPen, tlMarker, tlVectorize];
    useCol := useStroke or (Tool in [tlText, tlAirbrush, tlBucket, tlPicker, tlEraser]);
  end;
  wasT := QuickSample.Enabled;
  wasD := QuickDashSample.Enabled;
  wasC := QuickColors.Enabled;
  QuickSample.Enabled := useStroke;
  QuickLblThick.Enabled := useStroke;
  QuickDashSample.Enabled := useStroke;
  QuickLblStyle.Enabled := useStroke;
  QuickColors.Enabled := useCol;
  QuickSwapBox.Enabled := useCol;
  QuickTol.Enabled := (Tool in [tlSelect, tlWand, tlEraser]) or QuickPasteShown;
  QuickLblTol.Enabled := QuickTol.Enabled;
  if not useStroke then
  begin
    QuickDrop.Visible := False;
    QuickDashDrop.Visible := False;
  end;
  if (wasT <> useStroke) or (wasD <> useStroke) or (wasC <> useCol) then
  begin
    QuickSample.Invalidate;
    QuickDashSample.Invalidate;
    QuickColors.Invalidate;
    QuickSwapBox.Invalidate;
    QuickLblThick.Invalidate;
    QuickLblStyle.Invalidate;
  end;
  QuickLblTol.Invalidate;
end;

procedure TForm1.QuickSamplePaint(Sender: TObject);
var
  cnv: TCanvas;
  x, y: Integer;
begin
  cnv := QuickSample.Canvas;
  DrawStrokeSample(cnv, Rect(0, 0, QuickSample.Width, QuickSample.Height), QuickW, False, QuickStroke, QuickDash, 26);
  // the little arrow of a drop-down list
  x := QuickSample.Width - 11;
  y := QuickSample.Height div 2;
  cnv.Brush.Color := TColor($606060);
  cnv.Pen.Color := TColor($606060);
  cnv.Polygon([Point(x - 4, y - 2), Point(x + 4, y - 2), Point(x, y + 3)]);
  DimQuick(QuickSample);
end;

procedure TForm1.QuickSampleClick(Sender: TObject);
var
  pt: TPoint;
begin
  if not QuickSample.Enabled then Exit;
  pt := ScreenToClient(QuickSample.ClientToScreen(Point(0, 0)));
  // the list opens upwards, its last row over the sample: the mouse is inside it at once
  QuickDrop.Left := pt.x;
  QuickDrop.Top := pt.y + QuickSample.Height - QuickDrop.Height;
  QuickDrop.Visible := True;
  QuickDrop.BringToFront;
end;

procedure TForm1.QuickRowPaint(Sender: TObject);
var
  b: TPaintBox;
begin
  b := Sender as TPaintBox;
  DrawStrokeSample(b.Canvas, Rect(0, 0, b.Width, b.Height), QuickChoices[b.Tag], Abs(QuickChoices[b.Tag] - QuickW) < 0.05, QuickStroke, QuickDash);
end;

// the colours, partly overlapped: the stroke in front, the fill behind it
const
  QuickStrokeRect: TRect = (Left: 0; Top: 0; Right: 32; Bottom: 20);
  QuickFillRect: TRect = (Left: 16; Top: 10; Right: 48; Bottom: 30);

procedure QuickPaintColor(cnv: TCanvas; const R: TRect; col: Integer; mat: Integer = 0; tr: Integer = 0);
var
  chip: TBitmap;
begin
  cnv.Pen.Color := clGray;
  cnv.Pen.Style := psSolid;
  if (col <> NoColor) and (mat > 0) then
  begin
    chip := MaterialChip(mat - 1, R.Right - R.Left, R.Bottom - R.Top);
    try
      cnv.Draw(R.Left, R.Top, chip);
    finally
      chip.Free;
    end;
  end
  else if (col <> NoColor) and (tr > 0) then PaintTransColor(cnv, R, col, tr)
  else if col <> NoColor then
  begin
    cnv.Brush.Color := TColor(col);
    cnv.Rectangle(R);
  end
  else
  begin
    cnv.Brush.Color := clWhite;
    cnv.Rectangle(R);
    cnv.Pen.Color := clRed;
    cnv.Line(R.Left + 3, R.Bottom - 4, R.Right - 3, R.Top + 3);
  end;
end;

procedure TForm1.QuickColorsPaint(Sender: TObject);
begin
  QuickPaintColor(QuickColors.Canvas, QuickFillRect, QuickFill, QuickFillMat, QuickFillTr);
  QuickPaintColor(QuickColors.Canvas, QuickStrokeRect, QuickStroke, QuickStrokeMat, QuickStrokeTr);
  DimQuick(QuickColors);
end;

procedure TForm1.QuickCopyToPalette(Sender: TObject);
var
  i: Integer;
begin
  i := TMenuItem(Sender).Tag;
  Palette[i] := TColor(QuickMenuColor);
  SetSwatch(TSpeedButton(FindComponent('colorButton' + IntToStr(i + 1))), Palette[i]);
  SetStatus('Colour copied to button ' + IntToStr(i + 1) + ' of the Colors panel.');
end;

procedure TForm1.QuickColorsDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  mi: TMenuItem;
  bm: TBitmap;
  pt: TPoint;
begin
  if not QuickColors.Enabled then Exit;
  if Button = mbRight then
  begin
    // the colour under the mouse can be copied into one of the buttons of the Colors panel
    if PtInRect(QuickStrokeRect, Point(X, Y)) then QuickMenuColor := QuickStroke
    else if PtInRect(QuickFillRect, Point(X, Y)) then QuickMenuColor := QuickFill
    else Exit;
    if QuickMenuColor = NoColor then Exit;
    if PalMat then
    begin
      SetStatus('The buttons of the panel are materials now: switch the panel to Colors to copy a colour into one of them.');
      Exit;
    end;
    if QuickColorMenu = nil then QuickColorMenu := TPopupMenu.Create(Self);
    QuickColorMenu.Items.Clear;
    for i := 0 to 8 do
    begin
      mi := TMenuItem.Create(QuickColorMenu);
      mi.Caption := 'Copy to button ' + IntToStr(i + 1) + ' of the Colors panel';
      mi.Tag := i;
      mi.OnClick := @QuickCopyToPalette;
      bm := TBitmap.Create;
      bm.SetSize(16, 12);
      bm.Canvas.Brush.Color := Palette[i];
      bm.Canvas.Pen.Color := clGray;
      bm.Canvas.Rectangle(0, 0, 16, 12);
      mi.Bitmap.Assign(bm);
      bm.Free;
      QuickColorMenu.Items.Add(mi);
    end;
    pt := Mouse.CursorPos;
    QuickColorMenu.PopUp(pt.x, pt.y);
    Exit;
  end;
  if PtInRect(QuickStrokeRect, Point(X, Y)) then StrokeClick(nil)
  else if PtInRect(QuickFillRect, Point(X, Y)) then FillClick(nil);
end;

procedure TForm1.QuickSwapPaint(Sender: TObject);
var
  c: TCanvas;
  w, y: Integer;
begin
  c := QuickSwapBox.Canvas;
  w := QuickSwapBox.Width;
  y := QuickSwapBox.Height div 2;
  c.Brush.Color := TColor($B8B8B8);
  c.Pen.Color := clGray;
  c.Rectangle(0, 0, w, QuickSwapBox.Height);
  // a double arrow
  c.Pen.Color := clBlack;
  c.Brush.Color := clBlack;
  c.Line(6, y, w - 6, y);
  c.Polygon([Point(3, y), Point(8, y - 4), Point(8, y + 4)]);
  c.Polygon([Point(w - 4, y), Point(w - 9, y - 4), Point(w - 9, y + 4)]);
  DimQuick(QuickSwapBox);
end;

// the switch of the pasted pictures: a picture on a solid ground (opaque) or on a chequered one (the secondary colour is transparent)
procedure TForm1.QuickPastePaint(Sender: TObject);
var
  cnv: TCanvas;
  x, y, w, h: Integer;
begin
  cnv := QuickPasteBox.Canvas;
  w := QuickPasteBox.Width;
  h := QuickPasteBox.Height;
  cnv.Pen.Style := psClear;
  if QuickPasteShown then
  begin
    for y := 0 to (h - 1) div 6 do
      for x := 0 to (w - 1) div 6 do
      begin
        if (x + y) mod 2 = 0 then cnv.Brush.Color := clWhite else cnv.Brush.Color := TColor($B0B0B0);
        cnv.Rectangle(x * 6, y * 6, x * 6 + 7, y * 6 + 7);
      end;
  end
  else
  begin
    cnv.Brush.Color := TColor($E8E8E8);
    cnv.Rectangle(0, 0, w + 1, h + 1);
  end;
  // the picture: a hill and a sun
  cnv.Brush.Color := TColor($30A030);
  cnv.Polygon([Point(5, h - 5), Point(16, 10), Point(24, 18), Point(29, 13), Point(w - 5, h - 5)]);
  cnv.Brush.Color := TColor($20C0F0);
  cnv.Ellipse(w - 17, 5, w - 7, 15);
  cnv.Pen.Style := psSolid;
  if QuickPasteShown then cnv.Pen.Color := TColor($E09020) else cnv.Pen.Color := clGray;
  cnv.Brush.Style := bsClear;
  cnv.Rectangle(0, 0, w, h);
  if QuickPasteShown then cnv.Rectangle(1, 1, w - 1, h - 1);
  cnv.Brush.Style := bsSolid;
end;

procedure TForm1.QuickTolChange(Sender: TObject);
var
  im, ts: TShapeArray;
  k: Integer;
  any, wandAny: Boolean;
begin
  if QuickBusy then Exit;
  DefWandTol := QuickTol.Value;
  // the pictures selected that have a transparent colour take the new tolerance
  im := SelImages;
  any := False;
  for k := 0 to High(im) do
    if im[k].KeyOn then any := True;
  if any then
  begin
    Checkpoint;
    for k := 0 to High(im) do
      if im[k].KeyOn then SetImageKey(im[k], True, im[k].KeyColor, QuickTol.Value);
    Commit;
    Redraw;
  end;
  // the selections made by the wand take it too (their area is found again, after a short pause)
  ts := TargetShapes;
  wandAny := False;
  for k := 0 to High(ts) do
    if (ts[k].SelTarget > 0) and ts[k].SelWand then
    begin
      ts[k].SelTol := QuickTol.Value;
      wandAny := True;
    end;
  if wandAny then
  begin
    SelTimer.Enabled := False;
    SelTimer.Enabled := True;
  end;
  // the Properties show the same value when no selection of the wand is selected
  if not UpdatingProps and (Length(TargetShapes) = 0) then RefreshProps;
end;

// the switch: the selected pictures have a transparent colour or not; with no picture selected it is what the pasted ones will have
procedure TForm1.QuickPasteClick(Sender: TObject);
var
  im: TShapeArray;
  k: Integer;
  on: Boolean;
begin
  im := SelImages;
  if Length(im) > 0 then
  begin
    on := not im[0].KeyOn;
    Checkpoint;
    for k := 0 to High(im) do
      if im[k].KeyOn then SetImageKey(im[k], on, im[k].KeyColor, im[k].KeyTol)
      else SetImageKey(im[k], on, KeyDefaultColor, DefWandTol);
    Commit;
    RefreshProps;
    Redraw;
  end
  else QuickPasteTransp := not QuickPasteTransp;
  QuickPasteBox.Invalidate;
  SetStatus(QuickPasteHint);
end;

// the stroke colour becomes the fill colour and the other way round (texts keep their colour)
procedure TForm1.QuickSwapClick(Sender: TObject);
var
  ts: TShapeArray;
  i, t: Integer;
begin
  if not QuickSwapBox.Enabled then Exit;
  ts := TargetShapes;
  Checkpoint;
  if Length(ts) = 0 then
  begin
    t := DefStyle.Stroke;
    DefStyle.Stroke := DefStyle.Fill;
    DefStyle.Fill := t;
  end
  else
    for i := 0 to High(ts) do
      if ts[i].Kind <> skText then
      begin
        t := ts[i].Style.Stroke;
        ts[i].Style.Stroke := ts[i].Style.Fill;
        ts[i].Style.Fill := t;
      end;
  Commit;
  RefreshProps;
  Redraw;
end;

// the line style: a sample, and a list of the four styles over it
procedure TForm1.QuickDashPaint(Sender: TObject);
var
  cnv: TCanvas;
  x, y: Integer;
begin
  cnv := QuickDashSample.Canvas;
  DrawStrokeSample(cnv, Rect(0, 0, QuickDashSample.Width, QuickDashSample.Height), Max(2, Min(6, QuickW)), False, QuickStroke, QuickDash, 26);
  x := QuickDashSample.Width - 11;
  y := QuickDashSample.Height div 2;
  cnv.Brush.Color := TColor($606060);
  cnv.Pen.Color := TColor($606060);
  cnv.Polygon([Point(x - 4, y - 2), Point(x + 4, y - 2), Point(x, y + 3)]);
  DimQuick(QuickDashSample);
end;

procedure TForm1.QuickDashClick(Sender: TObject);
var
  pt: TPoint;
begin
  if not QuickDashSample.Enabled then Exit;
  pt := ScreenToClient(QuickDashSample.ClientToScreen(Point(0, 0)));
  QuickDashDrop.Left := pt.x;
  QuickDashDrop.Top := pt.y + QuickDashSample.Height - QuickDashDrop.Height;
  QuickDashDrop.Visible := True;
  QuickDashDrop.BringToFront;
end;

procedure TForm1.QuickDashRowPaint(Sender: TObject);
var
  b: TPaintBox;
begin
  b := Sender as TPaintBox;
  DrawStrokeSample(b.Canvas, Rect(0, 0, b.Width, b.Height), Max(2, Min(6, QuickW)), b.Tag = QuickDash, QuickStroke, b.Tag);
end;

procedure TForm1.QuickDashRowClick(Sender: TObject);
begin
  QuickDashDrop.Visible := False;
  if cbDash.ItemIndex <> (Sender as TPaintBox).Tag then
  begin
    cbDash.ItemIndex := (Sender as TPaintBox).Tag;
    StyleChanged(cbDash);
  end;
end;

procedure TForm1.QuickRowClick(Sender: TObject);
begin
  QuickDrop.Visible := False;
  QuickSetWidth(QuickChoices[(Sender as TPaintBox).Tag]);
end;

procedure TForm1.QuickDropLeave(Sender: TObject);
begin
  QuickDrop.Visible := False;
  QuickDashDrop.Visible := False;
end;

// the choice made in the panel of the frequent functions goes to the Thickness of the Properties
procedure TForm1.QuickSetWidth(v: Double);
begin
  if Abs(v - seWidth.Value) > 1e-9 then
  begin
    seWidth.Value := v;
    StyleChanged(seWidth);         // as if the value had been typed in the Properties
  end;
end;

procedure TForm1.StyleChanged(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;

  procedure Apply(var st: TStyle);
  begin
    if Sender = seWidth then st.Width := seWidth.Value
    else if Sender = cbCap then st.Cap := TLineCap(cbCap.ItemIndex)
    else if Sender = cbJoin then st.Join := TLineJoin(cbJoin.ItemIndex)
    else if Sender = cbDash then st.Dash := TDashStyle(cbDash.ItemIndex)
    else if Sender = chkNoStroke then
    begin
      if chkNoStroke.Checked then st.Stroke := NoColor
      else if st.Stroke = NoColor then st.Stroke := 0;
    end
    else if Sender = chkNoFill then
    begin
      if chkNoFill.Checked then st.Fill := NoColor
      else if st.Fill = NoColor then st.Fill := TColor($F0C080);
    end
    else if Sender = seStrokeOp then st.StrokeTr := 255 - Round(seStrokeOp.Value * 255 / 100)
    else if Sender = seFillOp then st.FillTr := 255 - Round(seFillOp.Value * 255 / 100);
  end;

begin
  if UpdatingProps then Exit;
  ts := TargetShapes;
  Checkpoint;
  if Length(ts) = 0 then
  begin
    Apply(DefStyle);
    if Sender = chkCirc then DefCirc := chkCirc.Checked;
  end
  else
    for i := 0 to High(ts) do
    begin
      if (ts[i].Kind = skText) and ((Sender = chkNoStroke)) then
      begin
        if chkNoStroke.Checked then ts[i].Style.Fill := NoColor
        else if ts[i].Style.Fill = NoColor then ts[i].Style.Fill := 0;
      end
      else if (ts[i].Kind = skText) and (Sender = seStrokeOp) then
        ts[i].Style.FillTr := 255 - Round(seStrokeOp.Value * 255 / 100)      // the colour of a text is its fill
      else Apply(ts[i].Style);
      if Sender = chkCirc then
      begin
        if ts[i].Kind in [skEllipse, skArc] then
        begin
          ts[i].Circ := chkCirc.Checked;
          if ts[i].Circ then ts[i].RY := ts[i].RX;
        end;
      end
      else if Sender = chkRef then ts[i].IsRef := chkRef.Checked
      else if (Sender = edText) and (ts[i].Kind = skText) then ts[i].Text := edText.Text
      else if (Sender = seFont) and (ts[i].Kind = skText) then ts[i].FontSize := seFont.Value
      else if (Sender = cbFont) and (ts[i].Kind = skText) then
      begin
        if cbFont.ItemIndex <= 0 then ts[i].FontName := '' else ts[i].FontName := cbFont.Items[cbFont.ItemIndex];
      end;
    end;
  Doc.Solve([]);
  Commit;
  RefreshProps;
  Redraw;
end;

// ---- the colour chooser of the program: saturation / value square, hue bar, RGB, hex, palette and opacity ----
type
  TColorPick = class
    Form: TForm;
    SV, HueBar, Pal, Preview: TPaintBox;
    spR, spG, spB, spA: TSpinEdit;
    edHex: TEdit;
    Track: TTrackBar;
    H, S, Vv: Double;               // hue 0..360, saturation and value 0..1
    Old: TColor;
    OldPct: Double;
    Busy: Boolean;
    Downed: Boolean;                // a press has been seen since the last release
    ShowA: Boolean;
    Chk: TCheckBox;                 // the None box: choosing a colour clears it
    Bmp: TBGRABitmap;
    BmpHue: Double;
    function Cur: TColor;
    procedure SetFromColor(c: TColor);
    procedure Sync(src: Integer);
    procedure SVPaint(Sender: TObject);
    procedure SVMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure SVDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HuePaint(Sender: TObject);
    procedure HueMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HueDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PalPaint(Sender: TObject);
    procedure PalDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaint(Sender: TObject);
    procedure RGBChange(Sender: TObject);
    procedure HexChange(Sender: TObject);
    procedure TrackChange(Sender: TObject);
    procedure AlphaChange(Sender: TObject);
    procedure PickUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;

const
  PickPalette: array[0..15] of TColor = ($000000, $808080, $C0C0C0, $FFFFFF, $0000FF, $000080, $00FFFF, $008080,
    $00FF00, $008000, $FFFF00, $808000, $FF0000, $800000, $FF00FF, $800080);

procedure HSVToRGBInt(h, s, v: Double; out r, g, b: Integer);
var
  i: Integer;
  f, p, q, t, rr, gg, bb: Double;
begin
  h := h - 360 * Floor(h / 360);
  i := Trunc(h / 60) mod 6;
  f := h / 60 - Trunc(h / 60);
  p := v * (1 - s);
  q := v * (1 - f * s);
  t := v * (1 - (1 - f) * s);
  case i of
    0: begin rr := v; gg := t; bb := p; end;
    1: begin rr := q; gg := v; bb := p; end;
    2: begin rr := p; gg := v; bb := t; end;
    3: begin rr := p; gg := q; bb := v; end;
    4: begin rr := t; gg := p; bb := v; end;
  else
    begin rr := v; gg := p; bb := q; end;
  end;
  r := Round(rr * 255);
  g := Round(gg * 255);
  b := Round(bb * 255);
end;

procedure RGBToHSVFloat(r, g, b: Integer; out h, s, v: Double);
var
  mx, mn, d, rf, gf, bf: Double;
begin
  rf := r / 255; gf := g / 255; bf := b / 255;
  mx := Max(rf, Max(gf, bf));
  mn := Min(rf, Min(gf, bf));
  d := mx - mn;
  v := mx;
  if mx = 0 then s := 0 else s := d / mx;
  if d = 0 then h := 0
  else if mx = rf then h := 60 * ((gf - bf) / d)
  else if mx = gf then h := 60 * ((bf - rf) / d + 2)
  else h := 60 * ((rf - gf) / d + 4);
  if h < 0 then h := h + 360;
end;

function TColorPick.Cur: TColor;
var
  r, g, b: Integer;
begin
  HSVToRGBInt(H, S, Vv, r, g, b);
  Result := RGBToColor(r, g, b);
end;

procedure TColorPick.SetFromColor(c: TColor);
var
  rgb: Integer;
  nh, ns, nv: Double;
begin
  rgb := ColorToRGB(c);
  RGBToHSVFloat(rgb and $FF, (rgb shr 8) and $FF, (rgb shr 16) and $FF, nh, ns, nv);
  if (ns > 0) and (nv > 0) then H := nh;       // a grey keeps the hue it had
  S := ns;
  Vv := nv;
end;

// src: which control the change comes from (it is not rewritten): 0 none, 1 square / bar / palette, 2 RGB, 3 hex, 4 opacity
procedure TColorPick.Sync(src: Integer);
var
  c: TColor;
begin
  if (Chk <> nil) and (src > 0) then Chk.Checked := False;
  c := Cur;
  Busy := True;
  if src <> 2 then
  begin
    spR.Value := Red(c);
    spG.Value := Green(c);
    spB.Value := Blue(c);
  end;
  if src <> 3 then edHex.Text := IntToHex(Red(c), 2) + IntToHex(Green(c), 2) + IntToHex(Blue(c), 2);
  Busy := False;
  SV.Invalidate;
  HueBar.Invalidate;
  Preview.Invalidate;
end;

procedure TColorPick.SVPaint(Sender: TObject);
var
  x, y, r, g, b, w, hh: Integer;
  cnv: TCanvas;
begin
  w := SV.Width;
  hh := SV.Height;
  if (Bmp = nil) or (BmpHue <> H) then
  begin
    if Bmp = nil then Bmp := TBGRABitmap.Create(w, hh);
    for y := 0 to hh - 1 do
      for x := 0 to w - 1 do
      begin
        HSVToRGBInt(H, x / (w - 1), 1 - y / (hh - 1), r, g, b);
        Bmp.SetPixel(x, y, BGRA(r, g, b, 255));
      end;
    Bmp.InvalidateBitmap;
    BmpHue := H;
  end;
  cnv := SV.Canvas;
  Bmp.Draw(cnv, 0, 0, True);
  // the marker
  x := Round(S * (w - 1));
  y := Round((1 - Vv) * (hh - 1));
  cnv.Brush.Style := bsClear;
  cnv.Pen.Color := clWhite;
  cnv.Ellipse(x - 6, y - 6, x + 7, y + 7);
  cnv.Pen.Color := clBlack;
  cnv.Ellipse(x - 5, y - 5, x + 6, y + 6);
  cnv.Brush.Style := bsSolid;
end;

procedure TColorPick.SVMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) then Exit;
  S := Max(0, Min(1, X / (SV.Width - 1)));
  Vv := Max(0, Min(1, 1 - Y / (SV.Height - 1)));
  Sync(1);
end;

procedure TColorPick.SVDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Downed := True;
  SVMouse(Sender, Shift + [ssLeft], X, Y);
end;

procedure TColorPick.HuePaint(Sender: TObject);
var
  y, r, g, b, w, hh: Integer;
  cnv: TCanvas;
begin
  cnv := HueBar.Canvas;
  w := HueBar.Width;
  hh := HueBar.Height;
  cnv.Pen.Style := psSolid;
  for y := 0 to hh - 1 do
  begin
    HSVToRGBInt(360 * y / hh, 1, 1, r, g, b);
    cnv.Pen.Color := RGBToColor(r, g, b);
    cnv.Line(0, y, w, y);
  end;
  y := Round(H / 360 * hh);
  cnv.Pen.Color := clWhite;
  cnv.Line(0, y - 1, w, y - 1);
  cnv.Line(0, y + 1, w, y + 1);
  cnv.Pen.Color := clBlack;
  cnv.Line(0, y, w, y);
end;

procedure TColorPick.HueMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) then Exit;
  H := Max(0, Min(359.99, 360 * Y / HueBar.Height));
  // a grey (or black) has no hue to show: clicking the bar gives it the full saturation (and brightness), so the change is seen
  if S < 0.02 then S := 1;
  if Vv < 0.02 then Vv := 1;
  Sync(1);
end;

procedure TColorPick.HueDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Downed := True;
  HueMouse(Sender, Shift + [ssLeft], X, Y);
end;

procedure TColorPick.PalPaint(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    Pal.Canvas.Brush.Color := PickPalette[i];
    Pal.Canvas.Pen.Color := clGray;
    Pal.Canvas.Rectangle(i * 28, 0, i * 28 + 26, Pal.Height);
  end;
end;

procedure TColorPick.PalDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  Downed := True;
  i := X div 28;
  if (i < 0) or (i > 15) then Exit;
  SetFromColor(PickPalette[i]);
  Sync(1);
end;

procedure TColorPick.PreviewPaint(Sender: TObject);
var
  cnv: TCanvas;
  x, y, a, bg, k: Integer;
  c: Integer;

  function Mix(f, b: Integer): Integer;
  begin
    Result := (f * a + b * (100 - a)) div 100;
  end;

begin
  cnv := Preview.Canvas;
  cnv.Pen.Style := psClear;
  for k := 0 to 1 do
  begin
    // left: the colour the dialog was opened with, right: the new one; both over a chequered ground
    if k = 0 then
    begin
      c := ColorToRGB(Old);
      a := Round(OldPct);
    end
    else
    begin
      c := ColorToRGB(Cur);
      a := spA.Value;
    end;
    for y := 0 to (Preview.Height - 1) div 10 do
      for x := 0 to (Preview.Width - 1) div 10 do
      begin
        if (x * 10 + 5 < Preview.Width div 2) <> (k = 0) then Continue;
        if (x + y) mod 2 = 0 then bg := 255 else bg := 190;
        cnv.Brush.Color := RGBToColor(Mix(c and $FF, bg), Mix((c shr 8) and $FF, bg), Mix((c shr 16) and $FF, bg));
        cnv.Rectangle(x * 10, y * 10, x * 10 + 11, y * 10 + 11);
      end;
  end;
  cnv.Pen.Style := psSolid;
  cnv.Pen.Color := clGray;
  cnv.Brush.Style := bsClear;
  cnv.Rectangle(0, 0, Preview.Width, Preview.Height);
  cnv.Brush.Style := bsSolid;
end;

// the first press on the window is lost on some systems (only the release arrives): the release then does what the press would have done
procedure TColorPick.PickUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if not Downed and (Button = mbLeft) then
  begin
    if Sender = SV then SVDown(Sender, Button, Shift, X, Y)
    else if Sender = HueBar then HueDown(Sender, Button, Shift, X, Y)
    else if Sender = Pal then PalDown(Sender, Button, Shift, X, Y);
  end;
  Downed := False;
end;

procedure TColorPick.RGBChange(Sender: TObject);
begin
  if Busy then Exit;
  SetFromColor(RGBToColor(spR.Value, spG.Value, spB.Value));
  Sync(2);
end;

procedure TColorPick.HexChange(Sender: TObject);
var
  t: string;
  v: LongInt;
begin
  if Busy then Exit;
  t := Trim(edHex.Text);
  if (Length(t) > 0) and (t[1] = '#') then Delete(t, 1, 1);
  if Length(t) <> 6 then Exit;
  v := StrToIntDef('$' + t, -1);
  if v < 0 then Exit;
  SetFromColor(RGBToColor((v shr 16) and $FF, (v shr 8) and $FF, v and $FF));
  Sync(3);
end;

procedure TColorPick.TrackChange(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  spA.Value := Track.Position;
  Busy := False;
  Preview.Invalidate;
end;

procedure TColorPick.AlphaChange(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  Track.Position := Round(spA.Value);
  Busy := False;
  Preview.Invalidate;
end;

// asks for a colour and (when showAlpha) its opacity in percent
function PickColor(const cap: string; var col: TColor; var pct: Double; showAlpha: Boolean): Boolean;
var
  mrp: Integer;
  h: TColorPick;
  f: TForm;
  l: TLabel;
  b: TButton;
  chkNone: TCheckBox;

  function Lab(const t: string; x, y: Integer): TLabel;
  begin
    Result := TLabel.Create(f);
    Result.Parent := f;
    Result.Caption := t;
    Result.SetBounds(x, y, 60, 18);
  end;

  function Spn(x, y: Integer): TSpinEdit;
  begin
    Result := TSpinEdit.Create(f);
    Result.Parent := f;
    Result.SetBounds(x, y, 64, 26);
    Result.MinValue := 0;
    Result.MaxValue := 255;
  end;

  function Pb(x, y, w, hh: Integer): TPaintBox;
  begin
    Result := TPaintBox.Create(f);
    Result.Parent := f;
    Result.SetBounds(x, y, w, hh);
  end;

begin
  h := TColorPick.Create;
  f := TForm.CreateNew(Application);
  try
    h.Form := f;
    h.ShowA := showAlpha;
    if col = TColor(NoColor) then h.Old := clBlack else h.Old := col;
    h.OldPct := pct;
    h.H := 0;
    h.BmpHue := -1;
    h.SetFromColor(h.Old);
    f.Caption := cap;
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 470;
    if showAlpha then f.ClientHeight := 330 else f.ClientHeight := 290;
    h.SV := Pb(12, 12, 230, 170);
    h.SV.OnPaint := @h.SVPaint;
    h.SV.OnMouseDown := @h.SVDown;
    h.SV.OnMouseMove := @h.SVMouse;
    h.HueBar := Pb(250, 12, 24, 170);
    h.HueBar.OnPaint := @h.HuePaint;
    h.HueBar.OnMouseDown := @h.HueDown;
    h.HueBar.OnMouseMove := @h.HueMouse;
    h.Preview := Pb(294, 12, 164, 54);
    h.Preview.OnPaint := @h.PreviewPaint;
    Lab('Red', 294, 82);
    h.spR := Spn(340, 78);
    Lab('Green', 294, 112);
    h.spG := Spn(340, 108);
    Lab('Blue', 294, 142);
    h.spB := Spn(340, 138);
    Lab('Hex #', 294, 172);
    h.edHex := TEdit.Create(f);
    h.edHex.Parent := f;
    h.edHex.SetBounds(340, 168, 90, 26);
    h.edHex.MaxLength := 7;
    h.Pal := Pb(12, 194, 16 * 28, 22);
    h.Pal.OnPaint := @h.PalPaint;
    h.Pal.OnMouseDown := @h.PalDown;
    h.spR.OnChange := @h.RGBChange;
    h.spG.OnChange := @h.RGBChange;
    h.spB.OnChange := @h.RGBChange;
    h.edHex.OnChange := @h.HexChange;
    h.Track := TTrackBar.Create(f);
    h.Track.Parent := f;
    h.Track.SetBounds(84, 224, 270, 30);
    h.Track.Min := 0;
    h.Track.Max := 100;
    h.Track.Position := Round(pct);
    h.Track.OnChange := @h.TrackChange;
    h.spA := TSpinEdit.Create(f);
    h.spA.Parent := f;
    h.spA.SetBounds(364, 226, 66, 26);
    h.spA.MinValue := 0;
    h.spA.MaxValue := 100;
    h.spA.Value := Round(pct);
    h.spA.OnChange := @h.AlphaChange;
    l := Lab('Opacity %', 12, 230);
    l.Width := 70;
    h.Track.Visible := showAlpha;
    h.spA.Visible := showAlpha;
    l.Visible := showAlpha;
    h.Sync(0);
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'OK';
    b.ModalResult := mrOk;
    b.Default := True;
    b.SetBounds(300, f.ClientHeight - 38, 75, 28);
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Cancel';
    b.ModalResult := mrCancel;
    b.Cancel := True;
    b.SetBounds(383, f.ClientHeight - 38, 75, 28);
    if PickMatButton then
    begin
      b := TButton.Create(f);
      b.Parent := f;
      b.Caption := 'Material...';
      b.Hint := 'Use a material instead of a colour';
      b.ShowHint := True;
      b.ModalResult := mrRetry;
      b.SetBounds(12, f.ClientHeight - 38, 100, 28);
    end;
    chkNone := nil;
    h.Chk := nil;
    if PickNoneOption then
    begin
      chkNone := TCheckBox.Create(f);
      chkNone.Parent := f;
      chkNone.Caption := 'None';
      chkNone.Hint := 'No colour: the outline (or the inside) is not drawn';
      chkNone.ShowHint := True;
      chkNone.Checked := PickNoneInit;
      chkNone.SetBounds(PickNoneLeft, f.ClientHeight - 34, 80, 22);
      h.Chk := chkNone;
    end;
    PickWantMaterial := False;
    h.SV.OnMouseUp := @h.PickUp;
    h.HueBar.OnMouseUp := @h.PickUp;
    h.Pal.OnMouseUp := @h.PickUp;
    mrp := f.ShowModal;
    Result := mrp = mrOk;
    PickWantMaterial := mrp = mrRetry;
    PickNoneOn := Result and (chkNone <> nil) and chkNone.Checked;
    if Result then
    begin
      col := h.Cur;
      if PickNoneOn then col := TColor(NoColor);
      if showAlpha then pct := h.spA.Value;
    end;
  finally
    h.Bmp.Free;
    f.Free;
    h.Free;
  end;
end;

function TForm1.LayerHasMaterials(l: TLayer): Boolean;
var
  i: Integer;
  sh: TShape;
begin
  Result := False;
  if l = nil then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
  begin
    sh := Doc.Shapes[i];
    if Doc.LayerOf(sh) <> l then Continue;
    if ((StrokeMaterial(sh.Style) > 0) and (sh.Style.Stroke <> NoColor) and not (sh.Kind in [skText, skImage])) or
       ((FillMaterial(sh.Style) > 0) and (sh.Style.Fill <> NoColor) and not (sh.Kind in [skText, skImage])) then
      Exit(True);
  end;
end;

type
  // the window that chooses a material
  TMatPick = class
    Form: TForm;
    Res: Integer;
    procedure Pick(Sender: TObject);
  end;

procedure TMatPick.Pick(Sender: TObject);
begin
  Res := TSpeedButton(Sender).Tag;
  Form.ModalResult := mrOk;
end;

type
  // the window of a material: its parameters, changed with a sample that shows them
  TMatDlg = class
    Idx: Integer;
    Pr: ^TMatParams;
    Prev: TPaintBox;
    Tr: array[0..10] of TTrackBar;     // 7 to 10 (thickness, curve, centre) only for the glass
    Vl: array[0..10] of TLabel;
    Tint: TPanel;
    Busy: Boolean;
    procedure PrevPaint(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure TintClick(Sender: TObject);
    procedure NoTintClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure Load;
    procedure Apply;
  end;

procedure TMatDlg.Load;
begin
  Busy := True;
  Tr[0].Position := Round(Pr^.Rough * 100);
  Tr[1].Position := Round(Pr^.Scale * 100);
  Tr[2].Position := Round(Pr^.Angle);
  Tr[3].Position := Round(Pr^.Texture * 100);
  Tr[4].Position := Round(Pr^.Gloss * 100);
  Tr[5].Position := Round(Pr^.Bright * 100);
  Tr[6].Position := Round(Pr^.Opacity * 100);
  if Tr[7] <> nil then Tr[7].Position := Round(Pr^.Thick * 100);
  if Tr[8] <> nil then Tr[8].Position := Round(Pr^.Curve * 100);
  if Tr[9] <> nil then Tr[9].Position := Round(Pr^.CX * 100);
  if Tr[10] <> nil then Tr[10].Position := Round(Pr^.CY * 100);
  Busy := False;
  Apply;
end;

procedure TMatDlg.Apply;
var
  i: Integer;
begin
  Pr^.Rough := Tr[0].Position / 100;
  Pr^.Scale := Tr[1].Position / 100;
  Pr^.Angle := Tr[2].Position;
  Pr^.Texture := Tr[3].Position / 100;
  Pr^.Gloss := Tr[4].Position / 100;
  Pr^.Bright := Tr[5].Position / 100;
  Pr^.Opacity := Tr[6].Position / 100;
  if Tr[7] <> nil then Pr^.Thick := Tr[7].Position / 100;
  if Tr[8] <> nil then Pr^.Curve := Tr[8].Position / 100;
  if Tr[9] <> nil then Pr^.CX := Tr[9].Position / 100;
  if Tr[10] <> nil then Pr^.CY := Tr[10].Position / 100;
  Vl[0].Caption := IntToStr(Tr[0].Position) + ' %';
  Vl[1].Caption := IntToStr(Tr[1].Position) + ' %';
  Vl[2].Caption := IntToStr(Tr[2].Position) + ' deg';
  for i := 3 to 6 do Vl[i].Caption := IntToStr(Tr[i].Position) + ' %';
  if Tr[7] <> nil then Vl[7].Caption := IntToStr(Tr[7].Position) + ' %';
  if Tr[8] <> nil then
    if Tr[8].Position > 0 then Vl[8].Caption := 'convex ' + IntToStr(Tr[8].Position)
    else if Tr[8].Position < 0 then Vl[8].Caption := 'concave ' + IntToStr(-Tr[8].Position)
    else Vl[8].Caption := 'flat';
  if Tr[9] <> nil then Vl[9].Caption := IntToStr(Tr[9].Position) + ' %';
  if Tr[10] <> nil then Vl[10].Caption := IntToStr(Tr[10].Position) + ' %';
  Tint.Color := TColor(Pr^.Tint);
  Prev.Invalidate;
  Form1.SetPaletteMode(Form1.PalMat);   // the swatches of the buttons
  Form1.Redraw;
end;

procedure TMatDlg.Changed(Sender: TObject);
begin
  if Busy then Exit;
  Apply;
end;

procedure TMatDlg.TintClick(Sender: TObject);
var
  col: TColor;
  pct: Double;
begin
  col := TColor(Pr^.Tint);
  pct := 100;
  if PickColor('Colour of the material', col, pct, False) then
  begin
    Pr^.Tint := col;
    Apply;
  end;
end;

procedure TMatDlg.NoTintClick(Sender: TObject);
begin
  Pr^.Tint := $FFFFFF;
  Apply;
end;

procedure TMatDlg.ResetClick(Sender: TObject);
begin
  Pr^ := DefaultMatParams;
  Load;
end;

// a round bar, a plate and a sphere of the material, lit as the layer is lit
procedure TMatDlg.PrevPaint(Sender: TObject);
var
  c: TCanvas;
  x, y, r, g, b, a, w, h, cx, cy, rad, xs, ys: Integer;
  nx, ny, nz, d, f, bgv: Double;
  lay: TLayer;
begin
  c := Prev.Canvas;
  w := Prev.Width;
  h := Prev.Height;
  lay := Form1.ActiveLayerObj;
  if lay <> nil then SetLightAngles(lay.LightAz, lay.LightEl, lay.LightDiv, lay.LightTint, lay.LightPower) else SetLightAngles(217, 60, 0, $FFFFFF, 1);
  CurMat := Pr^;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      // a chequered ground, so that what is transparent shows
      if ((x div 8) + (y div 8)) mod 2 = 0 then bgv := 205 else bgv := 235;
      c.Pixels[x, y] := TColor(Round(bgv) or (Round(bgv) shl 8) or (Round(bgv) shl 16));
    end;
  // the bar
  for y := 8 to 38 do
  begin
    ny := ((y + 0.5) - 23) / 15.5;
    if Abs(ny) > 0.97 then ny := 0.97 * Sign(ny);
    nz := Sqrt(1 - ny * ny);
    for x := 8 to w - 130 do
    begin
      MaterialShade(Idx, x * 1.0, y * 1.0, 0, ny, nz, False, 0.5, 0.5, r, g, b, a);
      f := a / 255;
      bgv := ((x div 8) + (y div 8)) mod 2;
      if bgv = 0 then bgv := 205 else bgv := 235;
      c.Pixels[x, y] := TColor(Round(r * f + bgv * (1 - f)) or (Round(g * f + bgv * (1 - f)) shl 8) or (Round(b * f + bgv * (1 - f)) shl 16));
    end;
  end;
  // the plate
  for y := 48 to h - 8 do
    for x := 8 to w - 130 do
    begin
      MaterialShade(Idx, x * 1.0, y * 1.0, 0, 0, 1, True, (x - 8) / (w - 138), (y - 48) / (h - 56), r, g, b, a);
      f := a / 255;
      // a glass with a curve: the ground is magnified or shrunk behind it
      xs := x;
      ys := y;
      if (Idx = 6) and (Pr^.Curve <> 0) then
      begin
        bgv := 0.45 * Pr^.Curve * (0.35 + 0.65 * Pr^.Thick);
        xs := Round(8 + Pr^.CX * (w - 138) + (x - 8 - Pr^.CX * (w - 138)) * (1 - bgv));
        ys := Round(48 + Pr^.CY * (h - 56) + (y - 48 - Pr^.CY * (h - 56)) * (1 - bgv));
      end;
      bgv := ((xs div 8) + (ys div 8)) mod 2;
      if bgv = 0 then bgv := 205 else bgv := 235;
      c.Pixels[x, y] := TColor(Round(r * f + bgv * (1 - f)) or (Round(g * f + bgv * (1 - f)) shl 8) or (Round(b * f + bgv * (1 - f)) shl 16));
    end;
  // the sphere
  rad := 54;
  cx := w - 70;
  cy := h div 2;
  for y := cy - rad to cy + rad do
    for x := cx - rad to cx + rad do
    begin
      nx := (x - cx + 0.5) / rad;
      ny := (y - cy + 0.5) / rad;
      d := nx * nx + ny * ny;
      if d >= 1 then Continue;
      nz := Sqrt(1 - d);
      MaterialShade(Idx, x * 1.0, y * 1.0, nx, ny, nz, False, 0.5, 0.5, r, g, b, a);
      f := a / 255;
      bgv := ((x div 8) + (y div 8)) mod 2;
      if bgv = 0 then bgv := 205 else bgv := 235;
      c.Pixels[x, y] := TColor(Round(r * f + bgv * (1 - f)) or (Round(g * f + bgv * (1 - f)) shl 8) or (Round(b * f + bgv * (1 - f)) shl 16));
    end;
end;

function TForm1.MaterialDialog(idx: Integer; allowColour: Boolean): Integer;
const
  Names: array[0..10] of string = ('Roughness', 'Texture step', 'Texture direction', 'Texture strength', 'Gloss', 'Brightness', 'Opacity',
    'Thickness', 'Curve', 'Curve centre X', 'Curve centre Y');
  Mins: array[0..10] of Integer = (0, 20, 0, 0, 0, 50, 10, 0, -100, 0, 0);
  Maxs: array[0..10] of Integer = (100, 500, 360, 100, 200, 150, 100, 100, 100, 100, 100);
var
  f: TForm;
  d: TMatDlg;
  lb: TLabel;
  i: Integer;
  bOk, bCancel, bReset, bTint, bNone, bColour: TButton;
  orig: TMatParams;
  mr, nS, yb: Integer;
begin
  Result := 0;
  if (idx < 0) or (idx >= MaterialCount) then Exit;
  // the glass has two more settings
  nS := 7;
  if idx = 6 then nS := 11;
  yb := 446 + (nS - 7) * 34;
  orig := Doc.Mats[idx];
  f := TForm.CreateNew(Application);
  d := TMatDlg.Create;
  try
    d.Idx := idx;
    d.Pr := @Doc.Mats[idx];
    f.Caption := 'Material: ' + MaterialNames[idx];
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 560;
    f.ClientHeight := 486 + (nS - 7) * 34;
    d.Prev := TPaintBox.Create(f);
    d.Prev.Parent := f;
    d.Prev.SetBounds(10, 10, 540, 130);
    d.Prev.OnPaint := @d.PrevPaint;
    for i := 0 to 10 do d.Tr[i] := nil;
    for i := 0 to nS - 1 do
    begin
      lb := TLabel.Create(f);
      lb.Parent := f;
      lb.Caption := Names[i];
      lb.SetBounds(14, 160 + i * 34, 130, 18);
      d.Tr[i] := TTrackBar.Create(f);
      d.Tr[i].Parent := f;
      d.Tr[i].SetBounds(150, 154 + i * 34, 330, 30);
      d.Tr[i].Min := Mins[i];
      d.Tr[i].Max := Maxs[i];
      d.Tr[i].TickStyle := tsNone;
      d.Tr[i].OnChange := @d.Changed;
      d.Vl[i] := TLabel.Create(f);
      d.Vl[i].Parent := f;
      d.Vl[i].SetBounds(490, 160 + i * 34, 60, 18);
    end;
    d.Tr[0].Hint := 'How much the reflections are scattered: 0 polished, 100 satin';
    d.Tr[1].Hint := 'The step of the grain, the veins, the flakes (100 % as made)';
    d.Tr[2].Hint := 'The direction of the grain of the wood, of the brushing of the metal';
    d.Tr[3].Hint := 'How much the texture shows (0: smooth)';
    d.Tr[4].Hint := 'The strength of the highlights and of the reflections';
    if nS = 11 then
    begin
      d.Tr[9].Hint := 'Where the centre of the curve is, left (0) to right (100): the lens is centred there';
      d.Tr[10].Hint := 'Where the centre of the curve is, top (0) to bottom (100)';
      d.Tr[7].Hint := 'How thick the glass is: a thicker glass absorbs more light (greener, more opaque, stronger edges)';
      d.Tr[8].Hint := 'The curve of the glass: convex (a lens that magnifies what is behind) or concave (it shrinks it); 0 is a flat sheet';
    end;
    for i := 0 to nS - 1 do d.Tr[i].ShowHint := True;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Colour';
    lb.SetBounds(14, 160 + nS * 34, 130, 18);
    d.Tint := TPanel.Create(f);
    d.Tint.Parent := f;
    d.Tint.SetBounds(150, 160 + nS * 34 - 4, 44, 24);
    d.Tint.ParentBackground := False;
    bTint := TButton.Create(f);
    bTint.Parent := f;
    bTint.Caption := '...';
    bTint.SetBounds(200, 160 + nS * 34 - 5, 30, 26);
    bTint.OnClick := @d.TintClick;
    bNone := TButton.Create(f);
    bNone.Parent := f;
    bNone.Caption := 'As made';
    bNone.SetBounds(236, 160 + nS * 34 - 5, 80, 26);
    bNone.OnClick := @d.NoTintClick;
    bReset := TButton.Create(f);
    bReset.Parent := f;
    bReset.Caption := 'Reset all';
    bReset.SetBounds(10, yb, 90, 28);
    bReset.OnClick := @d.ResetClick;
    if allowColour then
    begin
      bColour := TButton.Create(f);
      bColour.Parent := f;
      bColour.Caption := 'Colour...';
      bColour.Hint := 'Use a plain colour instead of this material';
      bColour.ShowHint := True;
      bColour.ModalResult := mrRetry;
      bColour.SetBounds(110, yb, 90, 28);
    end;
    bOk := TButton.Create(f);
    bOk.Parent := f;
    bOk.Caption := 'OK';
    bOk.ModalResult := mrOk;
    bOk.Default := True;
    bOk.SetBounds(380, yb, 80, 28);
    bCancel := TButton.Create(f);
    bCancel.Parent := f;
    bCancel.Caption := 'Cancel';
    bCancel.ModalResult := mrCancel;
    bCancel.Cancel := True;
    bCancel.SetBounds(468, yb, 80, 28);
    Checkpoint;
    d.Load;
    mr := f.ShowModal;
    if mr = mrOk then
    begin
      Commit;
      SetStatus('Material changed: every object made of it follows.');
      Result := 1;
    end
    else
    begin
      Doc.Mats[idx] := orig;
      if mr = mrRetry then Result := 2;
      SetPaletteMode(PalMat);
    end;
  finally
    d.Free;
    f.Free;
  end;
  Redraw;
end;

// which material: the nine of the palette, with their samples
function TForm1.ChooseMaterial: Integer;
var
  f: TForm;
  i: Integer;
  b: TSpeedButton;
  bm: TBitmap;
  h: TMatPick;
begin
  Result := -1;
  f := TForm.CreateNew(Application);
  h := TMatPick.Create;
  try
    f.Caption := 'Choose a material';
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 3 * 150 + 20;
    f.ClientHeight := 3 * 46 + 20;
    h.Form := f;
    h.Res := -1;
    for i := 0 to MaterialCount - 1 do
    begin
      b := TSpeedButton.Create(f);
      b.Parent := f;
      b.SetBounds(10 + (i mod 3) * 150, 10 + (i div 3) * 46, 146, 42);
      b.Caption := MaterialNames[i];
      b.Tag := i;
      b.Layout := blGlyphLeft;
      b.Spacing := 6;
      bm := MaterialChip(i, 40, 26);
      try
        b.Glyph.Assign(bm);
      finally
        bm.Free;
      end;
      b.OnClick := @h.Pick;
    end;
    f.ShowModal;
    Result := h.Res;
  finally
    h.Free;
    f.Free;
  end;
end;

// a click on Stroke colour / Fill colour: the colour window for a colour, the material window for a material; each has a button
// that goes to the other, to put a material in the place of a colour or the other way round
procedure TForm1.EditColourOrMaterial(isFill: Boolean);
var
  ts: TShapeArray;
  i, mat, tr, mi: Integer;
  col: TColor;
  pct: Double;
  useFill, asMat, ok: Boolean;
  st: TStyle;

  procedure SetTarget(c: TColor; m, trv: Integer; withTr: Boolean);
  var
    k: Integer;

    procedure One(var sty: TStyle; fl: Boolean);
    begin
      if fl then
      begin
        sty.Fill := c;
        sty.FillMatId := m;
        if withTr then sty.FillTr := trv;
      end
      else
      begin
        sty.Stroke := c;
        sty.StrokeMatId := m;
        if withTr then sty.StrokeTr := trv;
      end;
    end;

  begin
    Checkpoint;
    if Length(ts) = 0 then One(DefStyle, isFill)
    else
      for k := 0 to High(ts) do One(ts[k].Style, isFill or (ts[k].Kind = skText));
    Commit;
    RefreshProps;
    Redraw;
  end;

begin
  // the paint bucket has only a fill: whichever colour is changed, it is that one
  if Tool = tlBucket then isFill := True;
  ts := TargetShapes;
  if AllSelections(ts) or AllRasterShapes(ts) then SetLength(ts, 0);   // a selection (or a raster) has no colours of its own: the colour is the current one
  if Length(ts) > 0 then st := ts[0].Style else st := DefStyle;
  useFill := isFill or ((Length(ts) > 0) and (ts[0].Kind = skText));
  if useFill then
  begin
    col := ToCol(st.Fill);
    pct := (255 - st.FillTr) * 100 / 255;
    mat := FillMaterial(st);
  end
  else
  begin
    col := ToCol(st.Stroke);
    pct := (255 - st.StrokeTr) * 100 / 255;
    mat := StrokeMaterial(st);
  end;
  asMat := (mat > 0) and (col <> TColor(NoColor));
  repeat
    if asMat then
    begin
      i := MaterialDialog(mat - 1, True);
      if i = 2 then
      begin
        asMat := False;                    // to a colour: the one the material has on average
        col := TColor(MaterialAvg(mat - 1));
      end
      else Exit;
    end
    else
    begin
      PickMatButton := True;
      PickNoneOption := True;
      if useFill then PickNoneInit := st.Fill = NoColor else PickNoneInit := st.Stroke = NoColor;
      try
        if isFill then ok := PickColor('Fill colour', col, pct) else ok := PickColor('Stroke colour', col, pct);
      finally
        PickMatButton := False;
        PickNoneOption := False;
      end;
      if ok then
      begin
        tr := 255 - Round(pct * 255 / 100);
        if PickNoneOn then SetTarget(TColor(NoColor), 0, 0, False)
        else SetTarget(col, 0, tr, True);
        Exit;
      end
      else if PickWantMaterial then
      begin
        mi := ChooseMaterial;
        if mi < 0 then Exit;
        // the material replaces the colour at once; its window then lets it be adjusted
        mat := mi + 1;
        SetTarget(TColor(MaterialAvg(mi)), mat, 0, False);
        asMat := True;
      end
      else Exit;
    end;
  until False;
end;

type
  // the window of the light of a layer: the changes are seen at once in the drawing
  TLightDlg = class
    L: TLayer;
    Dial: TPaintBox;
    seAz, seEl: TSpinEdit;
    seDiv, sePow: TFloatSpinEdit;
    Tint: TPanel;
    Busy: Boolean;
    procedure DialPaint(Sender: TObject);
    procedure DialMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DialDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Changed(Sender: TObject);
    procedure TintClick(Sender: TObject);
    procedure WhiteClick(Sender: TObject);
    procedure Apply;
  end;

procedure TLightDlg.Apply;
begin
  L.LightAz := seAz.Value;
  L.LightEl := seEl.Value;
  L.LightDiv := seDiv.Value;
  L.LightPower := sePow.Value / 100;
  Tint.Color := TColor(L.LightTint);
  Dial.Invalidate;
  Form1.Redraw;
end;

procedure TLightDlg.Changed(Sender: TObject);
begin
  if Busy then Exit;
  Apply;
end;

procedure TLightDlg.DialPaint(Sender: TObject);
var
  c: TCanvas;
  cx, cy, r, i: Integer;
  a, rr: Double;
begin
  c := Dial.Canvas;
  cx := Dial.Width div 2;
  cy := Dial.Height div 2;
  r := Min(cx, cy) - 6;
  c.Brush.Color := TColor($303030);
  c.FillRect(0, 0, Dial.Width, Dial.Height);
  c.Pen.Color := TColor($909090);
  c.Brush.Color := TColor($484848);
  c.Ellipse(cx - r, cy - r, cx + r, cy + r);
  // the object in the middle, a sphere lit from where the light is
  c.Pen.Color := TColor($707070);
  c.Brush.Style := bsClear;
  c.Ellipse(cx - r div 2, cy - r div 2, cx + r div 2, cy + r div 2);
  for i := 0 to 7 do
  begin
    a := i * Pi / 4;
    c.Line(cx + Round(Sin(a) * (r - 4)), cy - Round(Cos(a) * (r - 4)), cx + Round(Sin(a) * r), cy - Round(Cos(a) * r));
  end;
  c.Font.Color := TColor($B0B0B0);
  c.Font.Height := -11;
  c.TextOut(cx - 3, 0, 'N');
  // the light: a sun on the circle, and the line to the middle
  a := seAz.Value * Pi / 180;
  rr := Max(0.06 * r, r * (1 - seEl.Value / 90));
  c.Pen.Color := TColor($30C0FF);
  c.Pen.Width := 2;
  c.Line(cx, cy, cx + Round(Sin(a) * rr), cy - Round(Cos(a) * rr));
  c.Pen.Width := 1;
  c.Brush.Style := bsSolid;
  c.Brush.Color := TColor($30D0FF);
  c.Pen.Color := clBlack;
  c.Ellipse(cx + Round(Sin(a) * rr) - 7, cy - Round(Cos(a) * rr) - 7, cx + Round(Sin(a) * rr) + 8, cy - Round(Cos(a) * rr) + 8);
end;

procedure TLightDlg.DialMouse(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  cx, cy, r: Integer;
  a, d: Double;
begin
  if not (ssLeft in Shift) then Exit;
  cx := Dial.Width div 2;
  cy := Dial.Height div 2;
  r := Min(cx, cy) - 6;
  a := ArcTan2(X - cx, -(Y - cy)) * 180 / Pi;
  if a < 0 then a := a + 360;
  // the nearer to the middle, the higher the light is above the page
  d := Min(1, Hypot(X - cx, Y - cy) / r);
  Busy := True;
  seAz.Value := Round(a);
  seEl.Value := Max(3, Min(90, Round(90 * (1 - d))));
  Busy := False;
  Apply;
end;

procedure TLightDlg.DialDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  DialMouse(Sender, Shift + [ssLeft], X, Y);
end;

procedure TLightDlg.TintClick(Sender: TObject);
var
  col: TColor;
  pct: Double;
begin
  col := TColor(L.LightTint);
  pct := 100;
  if PickColor('Dominant colour of the light', col, pct, False) then
  begin
    L.LightTint := col;
    Apply;
  end;
end;

procedure TLightDlg.WhiteClick(Sender: TObject);
begin
  L.LightTint := $FFFFFF;
  Apply;
end;

procedure TForm1.LightClick(Sender: TObject);
var
  l: TLayer;
  f: TForm;
  d: TLightDlg;
  lb: TLabel;
  bOk, bCancel, bTint, bWhite: TButton;
  oAz, oEl, oDiv, oPow: Double;
  oTint: Integer;
  ok: Boolean;
begin
  l := ActiveLayerObj;
  if (l = nil) or not LayerHasMaterials(l) then
  begin
    SetStatus('Light: the active layer has no materials.');
    Exit;
  end;
  oAz := l.LightAz;
  oEl := l.LightEl;
  oDiv := l.LightDiv;
  oPow := l.LightPower;
  oTint := l.LightTint;
  f := TForm.CreateNew(Application);
  d := TLightDlg.Create;
  try
    d.L := l;
    f.Caption := 'Light of the layer "' + l.Name + '"';
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 540;
    f.ClientHeight := 210;
    d.Dial := TPaintBox.Create(f);
    d.Dial.Parent := f;
    d.Dial.SetBounds(12, 12, 150, 150);
    d.Dial.OnPaint := @d.DialPaint;
    d.Dial.OnMouseDown := @d.DialDown;
    d.Dial.OnMouseMove := @d.DialMouse;
    d.Dial.Hint := 'Drag the sun: round the circle for the direction, towards the middle for a higher light';
    d.Dial.ShowHint := True;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Direction (0 = top, 90 = right)';
    lb.SetBounds(182, 14, 180, 16);
    d.seAz := TSpinEdit.Create(f);
    d.seAz.Parent := f;
    d.seAz.SetBounds(182, 32, 80, 26);
    d.seAz.MinValue := 0;
    d.seAz.MaxValue := 360;
    d.seAz.Value := Round(l.LightAz);
    d.seAz.OnChange := @d.Changed;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Height above the page (degrees)';
    lb.SetBounds(182, 66, 180, 16);
    d.seEl := TSpinEdit.Create(f);
    d.seEl.Parent := f;
    d.seEl.SetBounds(182, 84, 80, 26);
    d.seEl.MinValue := 1;
    d.seEl.MaxValue := 90;
    d.seEl.Value := Round(l.LightEl);
    d.seEl.OnChange := @d.Changed;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Spread of the beam (0 = parallel)';
    lb.SetBounds(182, 118, 180, 16);
    d.seDiv := TFloatSpinEdit.Create(f);
    d.seDiv.Parent := f;
    d.seDiv.SetBounds(182, 136, 90, 26);
    d.seDiv.MinValue := 0;
    d.seDiv.MaxValue := 45;
    d.seDiv.DecimalPlaces := 2;
    d.seDiv.Increment := 0.25;
    d.seDiv.Value := l.LightDiv;
    d.seDiv.OnChange := @d.Changed;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Power of the light (%)';
    lb.SetBounds(380, 66, 150, 16);
    d.sePow := TFloatSpinEdit.Create(f);
    d.sePow.Parent := f;
    d.sePow.SetBounds(380, 84, 90, 26);
    d.sePow.MinValue := 0;
    d.sePow.MaxValue := 400;
    d.sePow.DecimalPlaces := 0;
    d.sePow.Increment := 5;
    d.sePow.Value := Round(l.LightPower * 100);
    d.sePow.OnChange := @d.Changed;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Dominant colour';
    lb.SetBounds(380, 14, 140, 16);
    d.Tint := TPanel.Create(f);
    d.Tint.Parent := f;
    d.Tint.SetBounds(380, 34, 40, 24);
    d.Tint.ParentBackground := False;
    d.Tint.Color := TColor(l.LightTint);
    bTint := TButton.Create(f);
    bTint.Parent := f;
    bTint.Caption := '...';
    bTint.SetBounds(426, 33, 30, 26);
    bTint.OnClick := @d.TintClick;
    bWhite := TButton.Create(f);
    bWhite.Parent := f;
    bWhite.Caption := 'White';
    bWhite.SetBounds(462, 33, 64, 26);
    bWhite.OnClick := @d.WhiteClick;
    bOk := TButton.Create(f);
    bOk.Parent := f;
    bOk.Caption := 'OK';
    bOk.ModalResult := mrOk;
    bOk.Default := True;
    bOk.SetBounds(360, 172, 80, 28);
    bCancel := TButton.Create(f);
    bCancel.Parent := f;
    bCancel.Caption := 'Cancel';
    bCancel.ModalResult := mrCancel;
    bCancel.Cancel := True;
    bCancel.SetBounds(446, 172, 80, 28);
    Checkpoint;
    ok := f.ShowModal = mrOk;
    if ok then
    begin
      l.LightAz := d.seAz.Value;
      l.LightEl := d.seEl.Value;
      l.LightDiv := d.seDiv.Value;
      l.LightPower := d.sePow.Value / 100;
      Commit;
      SetStatus('Light changed.');
    end
    else
    begin
      l.LightAz := oAz;
      l.LightEl := oEl;
      l.LightDiv := oDiv;
      l.LightPower := oPow;
      l.LightTint := oTint;
    end;
  finally
    d.Free;
    f.Free;
  end;
  Redraw;
end;

procedure TForm1.StrokeClick(Sender: TObject);
begin
  EditColourOrMaterial(False);
end;

procedure TForm1.FillClick(Sender: TObject);
begin
  EditColourOrMaterial(True);
end;

procedure TForm1.QuoteChanged(Sender: TObject);
var
  v: Double;
begin
  if UpdatingProps or (SelQuote = nil) then Exit;
  Checkpoint;
  if Sender = seQuote then
  begin
    v := seQuote.Value / Doc.QuoteScale(SelQuote);
    if (SelQuote.Kind = ckRadius) and SelQuote.Diam then v := v / 2;
    if SelQuote.Kind = ckAngle then v := Min(v, 179.99);
    SelQuote.Value := v;
    Doc.SolveNew(SelQuote);
    if RejectIfInconsistent then Exit;
  end
  else if Sender = cbAxis then
  begin
    SelQuote.Axis := cbAxis.ItemIndex;
    SelQuote.Aux := 1;
    Doc.InitQuote(SelQuote);
  end
  else if Sender = edQuoteUnit then SelQuote.UnitText := Trim(edQuoteUnit.Text)
  else if Sender = chkDiam then SelQuote.Diam := chkDiam.Checked
  else if Sender = chkQuotePrint then SelQuote.NoPrint := chkQuotePrint.Checked;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.ConsListClick(Sender: TObject);
begin
  if lbCons.ItemIndex >= 0 then HighlightCons := TConstraint(lbCons.Items.Objects[lbCons.ItemIndex])
  else HighlightCons := nil;
  Redraw;
end;

procedure TForm1.UntrimClick(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := SelShapes;
  Checkpoint;
  for i := 0 to High(ts) do
  begin
    SetLength(ts[i].Trims, 0);
    SetLength(ts[i].Extends, 0);
  end;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.DelConsClick(Sender: TObject);
var
  c: TConstraint;
begin
  if lbCons.ItemIndex < 0 then
  begin
    SetStatus('Select a constraint in the list first.');
    Exit;
  end;
  c := TConstraint(lbCons.Items.Objects[lbCons.ItemIndex]);
  Checkpoint;
  if c = SelQuote then SelQuote := nil;
  HighlightCons := nil;
  Doc.DeleteConstraint(c);
  Commit;
  RefreshProps;
  Redraw;
end;

{ ================= edit commands ================= }

procedure TForm1.DeleteSelection;
var
  ts: TShapeArray;
  i: Integer;
  pts: TRefArray;
  sh: TShape;
begin
  // points of a path / joints selected (and not the whole figure): Delete removes those points
  SetLength(pts, 0);
  if SelQuote = nil then
    for i := 0 to High(Sel) do
    begin
      sh := Doc.FindShape(Sel[i].Shape);
      if (sh <> nil) and (((sh.Kind in [skSpline, skPolyline, skPolygon]) and (Sel[i].Idx >= 0) and (Sel[i].Idx < SegBase)) or
         ((sh.Kind = skPath) and (Sel[i].Idx >= HandlePathBase))) and
         (SelFind(MakeRef(Sel[i].Shape, -1)) < 0) then
      begin
        SetLength(pts, Length(pts) + 1);
        pts[High(pts)] := Sel[i];
      end;
    end;
  if Length(pts) > 0 then
  begin
    RemoveSelectedPoints(pts);
    Exit;
  end;
  Checkpoint;
  if SelQuote <> nil then
  begin
    Doc.DeleteConstraint(SelQuote);
    SelQuote := nil;
  end
  else
  begin
    ts := SelShapes;
    for i := 0 to High(ts) do Doc.DeleteShape(ts[i]);
    SelClear;
  end;
  HoverShape := nil;
  HighlightCons := nil;
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.MenuDelete(Sender: TObject);
begin
  DeleteSelection;
end;

procedure TForm1.MenuCopy(Sender: TObject);
var
  ts: TShapeArray;
  ids: TIntArray;
  i: Integer;
begin
  ts := SelShapes;
  if Length(ts) = 0 then
  begin
    SetStatus('Nothing selected to copy.');
    Exit;
  end;
  if AllSelections(ts) then
  begin
    PixelsOp(1, ts);
    Exit;
  end;
  SetLength(ids, Length(ts));
  for i := 0 to High(ts) do ids[i] := ts[i].Id;
  if (Length(ts) = 1) and (ts[0].Kind = skImage) then
    SetClipboardPictureText(DecodeStringBase64(ts[0].ImageData), DocToSVG(Doc, True, ids))
  else Clipboard.AsText := DocToSVG(Doc, True, ids);
  PasteCount := 0;
  SetStatus('Copied ' + IntToStr(Length(ts)) + ' object(s).');
end;

procedure TForm1.MenuCut(Sender: TObject);
begin
  if AllSelections(SelShapes) then
  begin
    PixelsOp(2, SelShapes);
    Exit;
  end;
  MenuCopy(nil);
  if Length(Sel) > 0 then DeleteSelection;
end;

procedure TForm1.MenuPasteObject(Sender: TObject);
var
  ids: TIntArray;
  i: Integer;
  txt: string;
begin
  if PixelsOnClipboard then
  begin
    PastePixels;
    Exit;
  end;
  txt := ClipboardText;
  if Pos('<svg', txt) = 0 then
  begin
    SetStatus('The clipboard does not contain SVG objects.');
    Exit;
  end;
  Checkpoint;
  Inc(PasteCount);
  try
    SVGToDoc(txt, Doc, True, 14 * PasteCount, 14 * PasteCount, ids);
  except
    on E: Exception do
    begin
      SetStatus('Paste failed: ' + E.Message);
      Exit;
    end;
  end;
  SetTool(tlSelect);
  SelClear;
  SetLength(Sel, Length(ids));
  for i := 0 to High(ids) do Sel[i] := MakeRef(ids[i], -1);
  Doc.Solve([]);
  Commit;
  RefreshProps;
  Redraw;
end;

// the PNG with the pixels of one colour made transparent (the colour is white when none is given)
function PngKeyTransparent(const raw: string; key: Integer; tolPct: Integer): string;
var
  bmp: TBGRABitmap;
  ms: TMemoryStream;
  c: Integer;
  kr, kg, kb, i, tol: Integer;
  p: PBGRAPixel;
begin
  Result := raw;
  if key = NoColor then c := ColorToRGB(clWhite) else c := ColorToRGB(TColor(key));
  kr := c and $FF;
  kg := (c shr 8) and $FF;
  kb := (c shr 16) and $FF;
  tol := Round(Max(0, Min(100, tolPct)) * 2.55);
  bmp := TBGRABitmap.Create;
  ms := TMemoryStream.Create;
  try
    try
      ms.WriteBuffer(raw[1], Length(raw));
      ms.Position := 0;
      bmp.LoadFromStream(ms);
      p := bmp.Data;
      for i := 0 to bmp.NbPixels - 1 do
      begin
        if (p^.alpha > 0) and (Abs(p^.red - kr) <= tol) and (Abs(p^.green - kg) <= tol) and (Abs(p^.blue - kb) <= tol) then p^ := BGRAPixelTransparent;
        Inc(p);
      end;
      bmp.InvalidateBitmap;
      ms.Clear;
      bmp.SaveToStreamAsPng(ms);
      SetString(Result, PAnsiChar(ms.Memory), ms.Size);
    except
      Result := raw;
    end;
  finally
    ms.Free;
    bmp.Free;
  end;
end;

// the colour (and the similar ones) of a picture made transparent, or not: the original is kept to change it at any time
procedure TForm1.SetImageKey(s: TShape; on: Boolean; col, tol: Integer);
begin
  if s.Kind <> skImage then Exit;
  if on then
  begin
    if (not s.KeyOn) or (s.KeyOrig = '') then s.KeyOrig := s.ImageData;
    s.KeyOn := True;
    s.KeyColor := col;
    s.KeyTol := tol;
    s.ImageData := EncodeStringBase64(PngKeyTransparent(DecodeStringBase64(s.KeyOrig), col, tol));
  end
  else if s.KeyOn then
  begin
    s.ImageData := s.KeyOrig;
    s.KeyOrig := '';
    s.KeyOn := False;
  end;
  FlushImageCaches(s);
end;

// the secondary colour (white when there is none): the colour that becomes transparent when the switch is turned on
function TForm1.KeyDefaultColor: Integer;
begin
  if QuickFill = NoColor then Result := ColorToRGB(clWhite) else Result := ColorToRGB(TColor(QuickFill));
end;

function TForm1.SelImages: TShapeArray;
var
  ts: TShapeArray;
  i, n: Integer;
begin
  ts := TargetShapes;
  SetLength(Result, 0);
  n := 0;
  for i := 0 to High(ts) do
    if ts[i].Kind = skImage then
    begin
      SetLength(Result, n + 1);
      Result[n] := ts[i];
      Inc(n);
    end;
end;

// what the switch shows: the state of the selected picture, or the one that pasted pictures will have
function TForm1.QuickPasteShown: Boolean;
var
  im: TShapeArray;
begin
  im := SelImages;
  if Length(im) > 0 then Result := im[0].KeyOn else Result := QuickPasteTransp;
end;

function TForm1.QuickPasteHint: string;
begin
  if Length(SelImages) > 0 then
  begin
    if QuickPasteShown then Result := 'The selected picture has a transparent colour (click to make it opaque again)'
    else Result := 'The selected picture is opaque (click to make the secondary colour transparent)';
  end
  else if QuickPasteTransp then Result := 'Pasted pictures: the secondary colour is transparent (click to make them opaque)'
  else Result := 'Pasted pictures: opaque (click to make the secondary colour transparent)';
end;

procedure TForm1.KeyChanged(Sender: TObject);
var
  im: TShapeArray;
  i: Integer;
begin
  if UpdatingProps then Exit;
  im := SelImages;
  Checkpoint;
  for i := 0 to High(im) do
    if im[i].KeyOn then SetImageKey(im[i], chkKey.Checked, im[i].KeyColor, im[i].KeyTol)
    else SetImageKey(im[i], chkKey.Checked, KeyDefaultColor, DefWandTol);
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.KeyColorClick(Sender: TObject);
var
  im: TShapeArray;
  i: Integer;
  col: TColor;
  pct: Double;
begin
  im := SelImages;
  if Length(im) = 0 then Exit;
  if im[0].KeyOn then col := TColor(im[0].KeyColor) else col := TColor(KeyDefaultColor);
  pct := 100;
  if not PickColor('Transparent colour', col, pct, False) then Exit;
  Checkpoint;
  for i := 0 to High(im) do
    if im[i].KeyOn then SetImageKey(im[i], True, ColorToRGB(col), im[i].KeyTol)
    else SetImageKey(im[i], True, ColorToRGB(col), DefWandTol);
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.AddRasterImage(bmp: TGraphic);
var
  png: TPortableNetworkGraphic;
  ms: TMemoryStream;
  raw: string;
  s: TShape;
begin
  png := TPortableNetworkGraphic.Create;
  ms := TMemoryStream.Create;
  try
    png.Assign(bmp);
    png.SaveToStream(ms);
    SetString(raw, PAnsiChar(ms.Memory), ms.Size);
  finally
    ms.Free;
    png.Free;
  end;
  Checkpoint;
  s := NewShape(skImage);
  SetLength(s.P, 2);
  s.P[0] := MakePt(20, 20);
  if DropPlace then
  begin
    // dropped from outside: the picture is centred on the pointer, inside the page
    s.P[0] := MakePt(Max(0, Round(DropPos.x - bmp.Width / 2)), Max(0, Round(DropPos.y - bmp.Height / 2)));
    DropPlace := False;
  end;
  s.P[1] := MakePt(s.P[0].x + bmp.Width, s.P[0].y + bmp.Height);
  s.ImageData := EncodeStringBase64(raw);
  s.Style.Stroke := NoColor;
  if QuickPasteTransp then SetImageKey(s, True, KeyDefaultColor, DefWandTol);
  Doc.AddShape(s);
  // behind everything else: the picture is mostly used as a model to trace over
  Doc.Shapes.Move(Doc.Shapes.IndexOf(s), 0);
  if (Doc.Width < s.P[1].x) or (Doc.Height < s.P[1].y) or (Doc.Width < 20 + bmp.Width) or (Doc.Height < 20 + bmp.Height) then
  begin
    Doc.Width := Max(Doc.Width, Round(s.P[1].x) + 20);
    Doc.Height := Max(Doc.Height, Round(s.P[1].y) + 20);
    UpdateBox;
  end;
  Commit;
  SetTool(tlSelect);
  SelSet(MakeRef(s.Id, -1));
  SetStatus('Raster pasted: drag it to move it (the Vectorize tool turns uniform areas into figures).');
  RefreshProps;
  Redraw;
end;

var
  ClipPng, ClipTxt: string;    // what the clipboard gives out while this program owns it

procedure ClipGetFunc(cb: PGtkClipboard; sd: PGtkSelectionData; info: guint; data: gpointer); cdecl;
begin
  if info = 0 then
    gtk_selection_data_set(sd, gdk_atom_intern('image/png', False), 8, Pguchar(PChar(ClipPng)), Length(ClipPng))
  else
    gtk_selection_data_set_text(sd, PChar(ClipTxt), Length(ClipTxt));
end;

procedure ClipClearFunc(cb: PGtkClipboard; data: gpointer); cdecl;
begin
end;

// a picture (PNG) and a text offered together on the clipboard, with gtk itself: the clipboard of the LCL copies twice the
// bytes it received, which kills the program with a big picture
procedure TForm1.SetClipboardPictureText(const png, txt: string);
var
  targets: array[0..5] of TGtkTargetEntry;
  n: Integer;

  procedure Add(const name: PChar; info: Integer);
  begin
    targets[n].target := name;
    targets[n].flags := 0;
    targets[n].info := info;
    Inc(n);
  end;

begin
  ClipPng := png;
  ClipTxt := txt;
  n := 0;
  if png <> '' then Add('image/png', 0);
  Add('UTF8_STRING', 1);
  Add('STRING', 1);
  Add('TEXT', 1);
  Add('text/plain', 1);
  Add('text/plain;charset=utf-8', 1);
  gtk_clipboard_set_with_data(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), @targets[0], n, @ClipGetFunc, @ClipClearFunc, nil);
end;

// The clipboard of the LCL (gtk2, 64 bits) copies twice the bytes it received: with a big picture it reads past the end of the
// buffer and the program dies. These two ask gtk for the data directly.
function TForm1.ClipboardData(const mime: string; ms: TStream): Boolean;
var
  cb: PGtkClipboard;
  atom: TGdkAtom;
  sd: PGtkSelectionData;
begin
  Result := False;
  cb := gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  atom := gdk_atom_intern(PChar(mime), False);
  if not gtk_clipboard_wait_is_target_available(cb, atom) then Exit;
  sd := gtk_clipboard_wait_for_contents(cb, atom);
  if sd = nil then Exit;
  try
    if (sd^.data <> nil) and (sd^.length > 0) then
    begin
      ms.WriteBuffer(sd^.data^, sd^.length);
      Result := True;
    end;
  finally
    gtk_selection_data_free(sd);
  end;
end;

function TForm1.ClipboardText: string;
var
  cb: PGtkClipboard;
  p: PChar;
begin
  Result := '';
  cb := gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  p := gtk_clipboard_wait_for_text(cb);
  if p = nil then Exit;
  try
    Result := string(p);
  finally
    g_free(p);
  end;
end;

// reads a picture from the clipboard (PNG, BMP or JPEG data); nil if there is none
function TForm1.ClipboardPicture: TGraphic;
const
  Mimes: array[0..3] of string = ('image/png', 'image/bmp', 'image/jpeg', 'image/x-bmp');
var
  i: Integer;
  ms: TMemoryStream;
  g: TGraphic;
begin
  Result := nil;
  for i := 0 to High(Mimes) do
  begin
    ms := TMemoryStream.Create;
    g := nil;
    try
      try
        if not ClipboardData(Mimes[i], ms) or (ms.Size < 16) then Continue;
        ms.Position := 0;
        if i = 0 then g := TPortableNetworkGraphic.Create
        else if i = 2 then g := TJPEGImage.Create
        else g := TBitmap.Create;
        g.LoadFromStream(ms);
        if (g.Width > 0) and (g.Height > 0) then
        begin
          Result := g;
          g := nil;
          Exit;
        end;
      except
        // unreadable data: try the next format
      end;
    finally
      g.Free;
      ms.Free;
    end;
  end;
end;

procedure TForm1.PasteKeyAsync(Data: PtrInt);
var
  txt: string;
begin
  txt := '';
  try
    txt := ClipboardText;
    if PixelsOnClipboard then PastePixels
    else if (Pos('<svg', txt) > 0) and (Data = 0) then MenuPasteObject(nil)
    else MenuPasteRaster(nil);
  except
    on E: Exception do SetStatus('Paste failed: ' + E.Message);
  end;
end;

// the Paste of the menu does what Ctrl+V does: pixels, SVG objects or a picture, whatever the clipboard holds
procedure TForm1.MenuPasteSmart(Sender: TObject);
begin
  PasteKeyAsync(0);
end;

procedure TForm1.MenuPasteRaster(Sender: TObject);
var
  g: TGraphic;
begin
  g := ClipboardPicture;
  if g = nil then
  begin
    SetStatus('No image found in the clipboard.');
    Exit;
  end;
  try
    AddRasterImage(g);
  finally
    g.Free;
  end;
end;

procedure TForm1.MenuFront(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := SelShapes;
  Checkpoint;
  for i := 0 to High(ts) do Doc.Shapes.Move(Doc.Shapes.IndexOf(ts[i]), Doc.Shapes.Count - 1);
  Commit;
  Redraw;
end;

procedure TForm1.MenuBack(Sender: TObject);
var
  ts: TShapeArray;
  i: Integer;
begin
  ts := SelShapes;
  Checkpoint;
  for i := High(ts) downto 0 do Doc.Shapes.Move(Doc.Shapes.IndexOf(ts[i]), 0);
  Commit;
  Redraw;
end;

procedure TForm1.MenuZoomIn(Sender: TObject);
begin
  SetZoom(Zoom * 1.25);
end;

procedure TForm1.MenuZoomOut(Sender: TObject);
begin
  SetZoom(Zoom / 1.25);
end;

procedure TForm1.MenuZoom100(Sender: TObject);
begin
  SetZoom(1);
end;

procedure TForm1.MenuSvgCode(Sender: TObject);
var
  txt, orig: string;
  tmp: TDoc;
  ids: TIntArray;
begin
  orig := DocToSVG(Doc, False, nil);
  txt := orig;
  if not ShowTextDialog('SVG code (edit it and press OK to apply)', txt, False) then Exit;
  if txt = orig then Exit;
  tmp := TDoc.Create;
  try
    try
      SVGToDoc(txt, tmp, False, 0, 0, ids);
    except
      on E: Exception do
      begin
        ShowMessage('Invalid SVG: ' + E.Message);
        Exit;
      end;
    end;
  finally
    tmp.Free;
  end;
  Checkpoint;
  FlushAllImageCaches;
  SVGToDoc(txt, Doc, False, 0, 0, ids);
  FlushAllImageCaches;
  PurgeSelection;
  Commit;
  UpdateBox;
  RefreshProps;
  RefreshLayers;
  Redraw;
end;

procedure TForm1.MenuSettings(Sender: TObject);
var
  f: TForm;
  lb: TLabel;
  ed: TEdit;
  chk: TCheckBox;
  bOk, bCancel: TButton;
  v: string;
  p: Integer;
  w, h: Integer;
begin
  f := TForm.CreateNew(Self);
  try
    f.Caption := 'Settings';
    f.Position := poOwnerFormCenter;
    f.BorderStyle := bsDialog;
    f.ClientWidth := 360;
    f.ClientHeight := 140;
    lb := TLabel.Create(f);
    lb.Parent := f;
    lb.Caption := 'Page size (width x height):';
    lb.SetBounds(12, 14, 336, 18);
    ed := TEdit.Create(f);
    ed.Parent := f;
    ed.Text := IntToStr(Doc.Width) + 'x' + IntToStr(Doc.Height);
    ed.SetBounds(12, 36, 336, 24);
    chk := TCheckBox.Create(f);
    chk.Parent := f;
    chk.Caption := 'Remember window position and size';
    chk.Hint := 'The window opens where and as large as it was when the program was closed';
    chk.ShowHint := True;
    chk.Checked := WinRemember;
    chk.SetBounds(12, 72, 336, 22);
    bOk := TButton.Create(f);
    bOk.Parent := f;
    bOk.Caption := 'OK';
    bOk.ModalResult := mrOk;
    bOk.Default := True;
    bOk.SetBounds(180, 104, 80, 28);
    bCancel := TButton.Create(f);
    bCancel.Parent := f;
    bCancel.Caption := 'Cancel';
    bCancel.ModalResult := mrCancel;
    bCancel.Cancel := True;
    bCancel.SetBounds(268, 104, 80, 28);
    ed.SelectAll;
    if f.ShowModal <> mrOk then Exit;
    if chk.Checked <> WinRemember then
    begin
      WinRemember := chk.Checked;
      SaveConfig;
    end;
    v := ed.Text;
  finally
    f.Free;
  end;
  p := Pos('x', LowerCase(v));
  if p = 0 then Exit;
  w := StrToIntDef(Trim(Copy(v, 1, p - 1)), 0);
  h := StrToIntDef(Trim(Copy(v, p + 1, MaxInt)), 0);
  if (w < 20) or (h < 20) then Exit;
  if (w = Doc.Width) and (h = Doc.Height) then Exit;
  Checkpoint;
  Doc.Width := w;
  Doc.Height := h;
  Commit;
  UpdateBox;
  Redraw;
end;

{ ================= files ================= }

function TForm1.ConfigPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetUserDir) + '.config/ttpaint/ttpaint.ini';
end;

// the window goes where it was left; numbers that make no sense (outside the screen, too small or too large, not numbers) are
// ignored: the window is then centred, with the size it has by default
procedure TForm1.ApplyWindowConfig(ini: TIniFile);
const
  NoVal = -2147483647;
var
  l, t, w, h, mx, vw, vh, ix, iy: Integer;
  wa, r: TRect;
  ok: Boolean;
begin
  try
    l := ini.ReadInteger('Window', 'Left', NoVal);
    t := ini.ReadInteger('Window', 'Top', NoVal);
    w := ini.ReadInteger('Window', 'Width', NoVal);
    h := ini.ReadInteger('Window', 'Height', NoVal);
    mx := ini.ReadInteger('Window', 'Maximized', 0);
    wa := Screen.DesktopRect;
    vw := wa.Right - wa.Left;
    vh := wa.Bottom - wa.Top;
    ok := (l <> NoVal) and (t <> NoVal) and (w <> NoVal) and (h <> NoVal) and (vw > 0) and (vh > 0) and
      (w >= 400) and (h >= 300) and (w <= vw) and (h <= vh);
    if ok then
    begin
      // at least a good part of the window (and its title bar) must be on a screen
      r := Rect(l, t, l + w, t + h);
      ix := Min(r.Right, wa.Right) - Max(r.Left, wa.Left);
      iy := Min(r.Bottom, wa.Bottom) - Max(r.Top, wa.Top);
      ok := (ix >= Min(200, w)) and (iy >= Min(100, h)) and (t >= wa.Top - 5) and (t < wa.Bottom - 50);
    end;
    if ok then
    begin
      Position := poDesigned;
      SetBounds(l, t, w, h);
      if mx = 1 then WindowState := wsMaximized;
    end
    else
    begin
      Position := poScreenCenter;
      Width := Min(Width, Max(400, vw));
      Height := Min(Height, Max(300, vh));
    end;
  except
    Position := poScreenCenter;
  end;
end;

procedure TForm1.LoadConfig;
var
  ini: TIniFile;
  i: Integer;
begin
  if not FileExists(ConfigPath) then Exit;
  ini := TIniFile.Create(ConfigPath);
  try
    for i := 0 to 8 do
      Palette[i] := TColor(ini.ReadInteger('Palette', 'Color' + IntToStr(i + 1), Palette[i]));
    DefStyle.Width := ini.ReadFloat('Defaults', 'Width', DefStyle.Width);
    DefStyle.Cap := TLineCap(EnsureRange(ini.ReadInteger('Defaults', 'Cap', Ord(DefStyle.Cap)), 0, 2));
    DefStyle.Join := TLineJoin(EnsureRange(ini.ReadInteger('Defaults', 'Join', Ord(DefStyle.Join)), 0, 2));
    DefStyle.Stroke := ini.ReadInteger('Defaults', 'Stroke', DefStyle.Stroke);
    DefStyle.Fill := ini.ReadInteger('Defaults', 'Fill', DefStyle.Fill);
    DefWandTol := EnsureRange(ini.ReadInteger('Defaults', 'Tolerance', DefWandTol), 0, 100);
    QuickPasteTransp := ini.ReadBool('Defaults', 'PasteTransparent', QuickPasteTransp);
    NewIcons := NewIcons and ini.ReadBool('Interface', 'NewIcons', True);
    WinRemember := ini.ReadBool('Window', 'Remember', False);
    if WinRemember then ApplyWindowConfig(ini);
  finally
    ini.Free;
  end;
end;

procedure TForm1.SaveConfig;
var
  ini: TIniFile;
  i: Integer;
begin
  try
    ForceDirectories(ExtractFilePath(ConfigPath));
    ini := TIniFile.Create(ConfigPath);
    try
      for i := 0 to 8 do ini.WriteInteger('Palette', 'Color' + IntToStr(i + 1), Palette[i]);
      ini.WriteFloat('Defaults', 'Width', DefStyle.Width);
      ini.WriteInteger('Defaults', 'Cap', Ord(DefStyle.Cap));
      ini.WriteInteger('Defaults', 'Join', Ord(DefStyle.Join));
      ini.WriteInteger('Defaults', 'Stroke', DefStyle.Stroke);
      ini.WriteInteger('Defaults', 'Fill', DefStyle.Fill);
      ini.WriteBool('Defaults', 'Circle', DefCirc);
      ini.WriteInteger('Defaults', 'Tolerance', DefWandTol);
      ini.WriteBool('Defaults', 'PasteTransparent', QuickPasteTransp);
      if DirectoryExists(IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'icons') then
        ini.WriteBool('Interface', 'NewIcons', NewIcons);
      ini.WriteBool('Window', 'Remember', WinRemember);
      if WinRemember then
      begin
        if WindowState = wsMaximized then
          ini.WriteInteger('Window', 'Maximized', 1)
        else if WindowState = wsNormal then
        begin
          ini.WriteInteger('Window', 'Left', Left);
          ini.WriteInteger('Window', 'Top', Top);
          ini.WriteInteger('Window', 'Width', Width);
          ini.WriteInteger('Window', 'Height', Height);
          ini.WriteInteger('Window', 'Maximized', 0);
        end;
      end;
      SaveSnippets(ini);
      SaveFilters(ini);
    finally
      ini.Free;
    end;
  except
    // configuration is optional
  end;
end;

procedure TForm1.MenuConfig(Sender: TObject);
begin
  SaveConfig;
  ShowMessage('Configuration file written:' + LineEnding + ConfigPath);
end;

function TForm1.ConfirmDiscard: Boolean;
begin
  Result := True;
  if Modified then
    Result := MessageDlg('TTPaint', 'The drawing has unsaved changes. Continue anyway?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmDiscard;
end;

procedure TForm1.SaveToFile(const fn: string);
var
  fs: TFileStream;
  txt: string;
begin
  txt := DocToSVG(Doc, False, nil, True);
  fs := TFileStream.Create(fn, fmCreate);
  try
    if txt <> '' then fs.WriteBuffer(txt[1], Length(txt));
  finally
    fs.Free;
  end;
  FileName := fn;
  Modified := False;
  UpdateCaption;
  SetStatus('Saved ' + fn);
end;

// the picture with a transparent page: only what is drawn is opaque
procedure TForm1.ExportPngAlpha(const fn: string);
var
  rgba: TBGRABitmap;
begin
  SetAlphaSize(Doc.Width, Doc.Height, True);
  AlphaOK := True;
  try
    rgba := RenderDocRgba(Doc.Width, Doc.Height, 1, False);
  finally
    AlphaOK := False;
  end;
  try
    rgba.SaveToFile(fn);
  finally
    rgba.Free;
  end;
  SetStatus('Exported ' + fn + ' with a transparent background (reference objects omitted)');
end;

procedure TForm1.ExportPng(const fn: string);
var
  bmp: TBitmap;
  png: TPortableNetworkGraphic;
begin
  bmp := TBitmap.Create;
  png := TPortableNetworkGraphic.Create;
  try
    bmp.SetSize(Doc.Width, Doc.Height);
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.FillRect(0, 0, Doc.Width, Doc.Height);
    RenderDocBmp(bmp, 1, False);       // reference objects are skipped
    png.Assign(bmp);
    png.SaveToFile(fn);
  finally
    png.Free;
    bmp.Free;
  end;
  SetStatus('Exported ' + fn + ' (reference objects omitted)');
end;

procedure TForm1.LoadFromFile(const fn: string);
var
  sl: TStringList;
  ids: TIntArray;
begin
  sl := TStringList.Create;
  try
    sl.LoadFromFile(fn);
    try
      FlushAllImageCaches;
      SVGToDoc(sl.Text, Doc, False, 0, 0, ids);
      RefreshLayers;
    except
      on E: Exception do
      begin
        ShowMessage('Cannot open ' + fn + LineEnding + E.Message);
        Exit;
      end;
    end;
  finally
    sl.Free;
  end;
  SelClear;
  PurgeSelection;
  UndoStack.Clear;
  RedoStack.Clear;
  FileName := fn;
  Modified := False;
  UpdateBox;
  UpdateCaption;
  RefreshProps;
  Redraw;
end;

// a picture (PNG, BMP, JPG, WEBP) as a new document: the page has the size of the picture, which is an image object on it
procedure TForm1.LoadRasterFile(const fn: string);
var
  bmp: TBGRABitmap;
  ms: TMemoryStream;
  raw: string;
  s: TShape;
begin
  // the library of WebP that is installed is the 7th version
  if not FileExists(LibWebPFilename) then LibWebPFilename := 'libwebp.so.7';
  bmp := TBGRABitmap.Create;
  ms := TMemoryStream.Create;
  try
    try
      bmp.LoadFromFile(fn);
      if (bmp.Width <= 0) or (bmp.Height <= 0) then raise Exception.Create('the picture is empty');
      bmp.SaveToStreamAsPng(ms);
      SetString(raw, PAnsiChar(ms.Memory), ms.Size);
    except
      on E: Exception do
      begin
        ShowMessage('Cannot open ' + fn + LineEnding + E.Message);
        Exit;
      end;
    end;
    NewDocument;
    Doc.Width := bmp.Width;
    Doc.Height := bmp.Height;
    s := NewShape(skImage);
    SetLength(s.P, 2);
    s.P[0] := MakePt(0, 0);
    s.P[1] := MakePt(bmp.Width, bmp.Height);
    s.ImageData := EncodeStringBase64(raw);
    s.Style.Stroke := NoColor;
    Doc.AddShape(s);
    RefreshLayers;
    // not an SVG file yet: it has no name and is to be saved
    Modified := True;
    UpdateBox;
    UpdateCaption;
    SelClear;
    SetStatus('Opened ' + ExtractFileName(fn) + ' (' + IntToStr(bmp.Width) + ' x ' + IntToStr(bmp.Height) + '): save it as SVG to keep the changes.');
    RefreshProps;
    Redraw;
  finally
    ms.Free;
    bmp.Free;
  end;
end;

procedure TForm1.MenuNew(Sender: TObject);
begin
  if ConfirmDiscard then NewDocument;
end;

procedure TForm1.MenuOpen(Sender: TObject);
begin
  if not ConfirmDiscard then Exit;
  OpenDlg.Filter := 'Images (*.svg, *.png, *.bmp, *.jpg, *.webp)|*.svg;*.png;*.bmp;*.jpg;*.jpeg;*.webp|SVG images (*.svg)|*.svg|' +
    'Pictures (*.png, *.bmp, *.jpg, *.webp)|*.png;*.bmp;*.jpg;*.jpeg;*.webp|All files|*';
  if OpenDlg.Execute and (OpenDlg.FileName <> '') then
    if Pos(LowerCase(ExtractFileExt(OpenDlg.FileName)), '.png.bmp.jpg.jpeg.webp') > 0 then LoadRasterFile(OpenDlg.FileName)
    else LoadFromFile(OpenDlg.FileName);
end;

// a picture from a file (PNG, BMP, JPG, WEBP) added to the open document, like a pasted raster
procedure TForm1.MenuInsertImage(Sender: TObject);
begin
  OpenDlg.Filter := 'Pictures (*.png, *.bmp, *.jpg, *.webp)|*.png;*.bmp;*.jpg;*.jpeg;*.webp|All files|*';
  if not OpenDlg.Execute or (OpenDlg.FileName = '') then Exit;
  InsertRasterFile(OpenDlg.FileName);
end;

procedure TForm1.InsertRasterFile(const fn: string);
var
  bmp: TBGRABitmap;
  ms: TMemoryStream;
  png: TPortableNetworkGraphic;
begin
  if not FileExists(LibWebPFilename) then LibWebPFilename := 'libwebp.so.7';
  bmp := TBGRABitmap.Create;
  ms := TMemoryStream.Create;
  png := TPortableNetworkGraphic.Create;
  try
    try
      bmp.LoadFromFile(fn);
      if (bmp.Width <= 0) or (bmp.Height <= 0) then raise Exception.Create('the picture is empty');
      bmp.SaveToStreamAsPng(ms);
      ms.Position := 0;
      png.LoadFromStream(ms);
    except
      on E: Exception do
      begin
        DropPlace := False;
        ShowMessage('Cannot open ' + fn + LineEnding + E.Message);
        Exit;
      end;
    end;
    AddRasterImage(png);
    SetStatus('Inserted ' + ExtractFileName(fn) + ' (' + IntToStr(bmp.Width) + ' x ' + IntToStr(bmp.Height) + '): drag it to move it.');
  finally
    png.Free;
    ms.Free;
    bmp.Free;
  end;
end;

// pictures (PNG, BMP, JPG, WEBP) dragged from a file manager onto the window are added to the drawing, like Insert image
procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of String);
var
  i, n: Integer;
  pt: TPoint;
  skipped: string;
begin
  if (Creating <> nil) or CropActive or PersActive then Exit;
  pt := PaintBox1.ScreenToClient(Mouse.CursorPos);
  n := 0;
  skipped := '';
  for i := 0 to High(FileNames) do
  begin
    if Pos(LowerCase(ExtractFileExt(FileNames[i])), '.png.bmp.jpg.jpeg.webp') = 0 then
    begin
      skipped := skipped + ' ' + ExtractFileName(FileNames[i]);
      Continue;
    end;
    // several pictures are staggered so that they do not hide each other
    DropPos := MakePt(pt.X / Zoom + n * 20, pt.Y / Zoom + n * 20);
    DropPlace := True;
    InsertRasterFile(FileNames[i]);
    DropPlace := False;
    Inc(n);
  end;
  if skipped <> '' then
    SetStatus('Only pictures (PNG, BMP, JPG, WEBP) can be dropped here; not used:' + skipped);
  if n > 0 then Application.BringToFront;
end;

procedure TForm1.MenuSave(Sender: TObject);
begin
  if FileName = '' then MenuSaveAs(nil) else SaveToFile(FileName);
end;

procedure TForm1.MenuSaveAs(Sender: TObject);
var
  fn: string;
begin
  SaveDlg.Filter := 'SVG image with TTPaint data (*.svg)|*.svg|PNG raster export (*.png)|*.png|PNG with transparent background (*.png)|*.png';
  SaveDlg.DefaultExt := 'svg';
  SaveDlg.Options := SaveDlg.Options + [ofOverwritePrompt];
  if FileName <> '' then SaveDlg.FileName := FileName;
  if not SaveDlg.Execute then Exit;
  fn := SaveDlg.FileName;
  if LowerCase(ExtractFileExt(fn)) = '.png' then
  begin
    if SaveDlg.FilterIndex = 3 then ExportPngAlpha(fn) else ExportPng(fn);
  end
  else
  begin
    if ExtractFileExt(fn) = '' then fn := fn + '.svg';
    SaveToFile(fn);
  end;
end;

procedure TForm1.MenuZoomFit(Sender: TObject);
begin
  SetZoom(Min((ScrollBox1.ClientWidth - PageMargin - 4) / Max(1, Doc.Width),
    (ScrollBox1.ClientHeight - PageMargin - 4) / Max(1, Doc.Height)));
end;

type
  // print preview: the page in miniature with the drawing on it; output to a printer or a PDF file
  TPrintPreview = class(TForm)
  private
    Main: TForm1;
    rgOri, rgScale, rgDest: TRadioGroup;
    cbPaper: TComboBox;
    lblPaper: TLabel;
    pb: TPaintBox;
    lblInfo: TLabel;
    btnPrinter, btnPrint, btnCancel, btnReset: TButton;
    // the place of the figure on the paper (paper units): automatic until it is moved or resized with the mouse
    Manual: Boolean;
    FigX, FigY, FigZ: Double;
    FigDrag: Integer;               // 0 nothing, 1 moving, 2..5 resizing by a corner (the opposite one stays)
    DragDX, DragDY, AnchX, AnchY: Double;
    procedure PageGeom(out f: Double; out x0, y0: Integer);
    function CornerAt(X, Y: Integer): Integer;
    procedure PbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ResetClick(Sender: TObject);
    procedure PbPaint(Sender: TObject);
    procedure OptionChanged(Sender: TObject);
    procedure ChoosePrinter(Sender: TObject);
    procedure UpdateInfo;
  public
    constructor CreateFor(AMain: TForm1);
    function Landscape: Boolean;
    function FitToPage: Boolean;
    function ToPdf: Boolean;
    // where the figure goes on the paper and at which scale (device units per document unit)
    procedure Placement(out fx, fy, fz: Double);
    // printable area, drawing scale (device units per document unit, and at real size),
    // whole paper and margin, all in printer pixels or PDF points
    procedure PageInfo(out pw, ph, z, z1, paperW, paperH, margin: Double);
  end;

constructor TPrintPreview.CreateFor(AMain: TForm1);
var
  hdr: TPanel;
  i: Integer;
begin
  inherited CreateNew(AMain);
  Main := AMain;
  Caption := 'Print preview';
  Position := poOwnerFormCenter;
  Width := 1100;
  Height := 740;
  hdr := TPanel.Create(Self);
  hdr.Parent := Self;
  hdr.Align := alTop;
  hdr.Height := 104;
  hdr.BevelOuter := bvNone;

  rgOri := TRadioGroup.Create(Self);
  rgOri.Parent := hdr;
  rgOri.SetBounds(8, 4, 140, 96);
  rgOri.Caption := 'Orientation';
  rgOri.Items.Add('Portrait');
  rgOri.Items.Add('Landscape');
  if Main.Doc.Width > Main.Doc.Height then rgOri.ItemIndex := 1 else rgOri.ItemIndex := 0;
  rgOri.OnClick := @OptionChanged;

  rgScale := TRadioGroup.Create(Self);
  rgScale.Parent := hdr;
  rgScale.SetBounds(154, 4, 280, 96);
  rgScale.Caption := 'Size';
  rgScale.Items.Add('Actual size (reduced only if too big)');
  rgScale.Items.Add('Fit to the page');
  rgScale.ItemIndex := 0;
  rgScale.OnClick := @OptionChanged;

  rgDest := TRadioGroup.Create(Self);
  rgDest.Parent := hdr;
  rgDest.SetBounds(440, 4, 130, 96);
  rgDest.Caption := 'Output';
  rgDest.Items.Add('Printer');
  rgDest.Items.Add('PDF file');
  rgDest.ItemIndex := 0;
  rgDest.OnClick := @OptionChanged;

  lblPaper := TLabel.Create(Self);
  lblPaper.Parent := hdr;
  lblPaper.Caption := 'Paper size (PDF)';
  lblPaper.SetBounds(580, 10, 120, 18);
  cbPaper := TComboBox.Create(Self);
  cbPaper.Parent := hdr;
  cbPaper.Style := csDropDownList;
  cbPaper.SetBounds(580, 28, 110, 26);
  for i := 0 to PaperCount - 1 do
    cbPaper.Items.Add(PaperNames[i] + ' (' + FormatFloat('0.#', PaperMM[i, 0]) + ' x ' +
      FormatFloat('0.#', PaperMM[i, 1]) + ' mm)');
  cbPaper.ItemIndex := 4;               // A4
  cbPaper.DropDownCount := PaperCount;
  cbPaper.OnChange := @OptionChanged;

  btnPrinter := TButton.Create(Self);
  btnPrinter.Parent := hdr;
  btnPrinter.Caption := 'Printer...';
  btnPrinter.SetBounds(700, 28, 90, 26);
  btnPrinter.OnClick := @ChoosePrinter;

  lblInfo := TLabel.Create(Self);
  lblInfo.Parent := hdr;
  lblInfo.SetBounds(580, 60, 245, 40);
  lblInfo.AutoSize := False;
  lblInfo.WordWrap := True;

  btnPrint := TButton.Create(Self);
  btnPrint.Parent := hdr;
  btnPrint.Caption := 'Print';
  btnPrint.ModalResult := mrOk;
  btnPrint.Default := True;
  btnPrint.SetBounds(970, 10, 110, 32);

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := hdr;
  btnCancel.Caption := 'Cancel';
  btnCancel.ModalResult := mrCancel;
  btnCancel.Cancel := True;
  btnCancel.SetBounds(970, 50, 110, 32);

  btnReset := TButton.Create(Self);
  btnReset.Parent := hdr;
  btnReset.Caption := 'Reset position';
  btnReset.Hint := 'The figure goes back to the automatic place and size';
  btnReset.ShowHint := True;
  btnReset.SetBounds(830, 28, 130, 26);
  btnReset.OnClick := @ResetClick;

  pb := TPaintBox.Create(Self);
  pb.Parent := Self;
  pb.Align := alClient;
  pb.OnPaint := @PbPaint;
  pb.OnMouseDown := @PbMouseDown;
  pb.OnMouseMove := @PbMouseMove;
  pb.OnMouseUp := @PbMouseUp;
  pb.Hint := 'Drag the figure to move it, drag a corner to resize it';
  pb.ShowHint := True;
  UpdateInfo;
end;

function TPrintPreview.Landscape: Boolean;
begin
  Result := rgOri.ItemIndex = 1;
end;

function TPrintPreview.FitToPage: Boolean;
begin
  Result := rgScale.ItemIndex = 1;
end;

function TPrintPreview.ToPdf: Boolean;
begin
  Result := rgDest.ItemIndex = 1;
end;

procedure TPrintPreview.PageInfo(out pw, ph, z, z1, paperW, paperH, margin: Double);
var
  a, b: Integer;
  w, h: Double;
begin
  if ToPdf then
  begin
    PaperPoints(cbPaper.ItemIndex, Landscape, w, h);
    paperW := w;
    paperH := h;
    margin := 10 / 25.4 * 72;                  // 10 mm
    pw := w - 2 * margin;
    ph := h - 2 * margin;
    z1 := 72 / 96;                             // points per document unit at real size
  end
  else
  begin
    Printer.Orientation := poPortrait;
    a := Printer.PageWidth;
    b := Printer.PageHeight;
    if Landscape then
    begin
      pw := Max(a, b);
      ph := Min(a, b);
    end
    else
    begin
      pw := Min(a, b);
      ph := Max(a, b);
    end;
    paperW := pw;
    paperH := ph;
    margin := 0;
    z1 := Printer.XDPI / 96;
  end;
  z := Min(pw / Max(1, Main.Doc.Width), ph / Max(1, Main.Doc.Height));
  if (not FitToPage) and (z > z1) then z := z1;
end;

procedure TPrintPreview.Placement(out fx, fy, fz: Double);
var
  pw, ph, z, z1, paperW, paperH, margin: Double;
begin
  if Manual then
  begin
    fx := FigX;
    fy := FigY;
    fz := FigZ;
    Exit;
  end;
  PageInfo(pw, ph, z, z1, paperW, paperH, margin);
  fx := margin;
  fy := margin;
  fz := z;
end;

procedure TPrintPreview.UpdateInfo;
var
  pw, ph, z, z1, paperW, paperH, margin, fx, fy: Double;
begin
  lblPaper.Enabled := ToPdf;
  cbPaper.Enabled := ToPdf;
  btnPrinter.Enabled := not ToPdf;
  if ToPdf then btnPrint.Caption := 'Save PDF...' else btnPrint.Caption := 'Print';
  PageInfo(pw, ph, z, z1, paperW, paperH, margin);
  Placement(fx, fy, z);
  btnReset.Enabled := Manual;
  if ToPdf then
    lblInfo.Caption := 'PDF, vector, 10 mm margins' + LineEnding +
      'Drawn at ' + IntToStr(Round(100 * z / z1)) + '% of the real size'
  else
    lblInfo.Caption := 'Printer: ' + Printer.PrinterName + LineEnding +
      'Printed at ' + IntToStr(Round(100 * z / z1)) + '% of the real size';
  pb.Invalidate;
end;

procedure TPrintPreview.OptionChanged(Sender: TObject);
begin
  Manual := False;          // another paper or size: the figure goes back to its automatic place
  UpdateInfo;
end;

procedure TPrintPreview.ChoosePrinter(Sender: TObject);
begin
  if Main.PrintDlg.Execute then
  begin
    Manual := False;
    UpdateInfo;
  end;
end;

procedure TPrintPreview.ResetClick(Sender: TObject);
begin
  Manual := False;
  UpdateInfo;
end;

// the paper in the window: scale (screen pixels per paper unit) and top left corner
procedure TPrintPreview.PageGeom(out f: Double; out x0, y0: Integer);
var
  pw, ph, z, z1, paperW, paperH, margin: Double;
begin
  PageInfo(pw, ph, z, z1, paperW, paperH, margin);
  f := Min((pb.Width - 40) / paperW, (pb.Height - 40) / paperH);
  if f <= 0 then f := 0.0001;
  x0 := (pb.Width - Round(paperW * f)) div 2;
  y0 := (pb.Height - Round(paperH * f)) div 2;
end;

// the corner of the figure under the pointer: 2 top left, 3 top right, 4 bottom left, 5 bottom right; 1 inside, 0 outside
function TPrintPreview.CornerAt(X, Y: Integer): Integer;
var
  f, fx, fy, fz: Double;
  x0, y0, i, cx, cy: Integer;
  l, t, r, b: Double;
begin
  Result := 0;
  PageGeom(f, x0, y0);
  Placement(fx, fy, fz);
  l := x0 + fx * f;
  t := y0 + fy * f;
  r := l + Main.Doc.Width * fz * f;
  b := t + Main.Doc.Height * fz * f;
  for i := 0 to 3 do
  begin
    if i mod 2 = 0 then cx := Round(l) else cx := Round(r);
    if i < 2 then cy := Round(t) else cy := Round(b);
    if (Abs(X - cx) <= 7) and (Abs(Y - cy) <= 7) then Exit(2 + i);
  end;
  if (X >= l) and (X <= r) and (Y >= t) and (Y <= b) then Result := 1;
end;

procedure TPrintPreview.PbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  f, fx, fy, fz: Double;
  x0, y0: Integer;
begin
  if Button <> mbLeft then Exit;
  FigDrag := CornerAt(X, Y);
  if FigDrag = 0 then Exit;
  PageGeom(f, x0, y0);
  Placement(fx, fy, fz);
  if not Manual then
  begin
    Manual := True;
    FigX := fx;
    FigY := fy;
    FigZ := fz;
  end;
  if FigDrag = 1 then
  begin
    DragDX := (X - x0) / f - FigX;
    DragDY := (Y - y0) / f - FigY;
  end
  else
  begin
    // the opposite corner stays where it is
    if FigDrag in [2, 4] then AnchX := FigX + Main.Doc.Width * FigZ else AnchX := FigX;
    if FigDrag in [2, 3] then AnchY := FigY + Main.Doc.Height * FigZ else AnchY := FigY;
  end;
end;

procedure TPrintPreview.PbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  f, s, mx, my: Double;
  x0, y0, c: Integer;
begin
  PageGeom(f, x0, y0);
  mx := (X - x0) / f;
  my := (Y - y0) / f;
  case FigDrag of
    1:
      begin
        FigX := mx - DragDX;
        FigY := my - DragDY;
      end;
    2..5:
      begin
        s := Max(Abs(mx - AnchX) / Max(1, Main.Doc.Width), Abs(my - AnchY) / Max(1, Main.Doc.Height));
        s := Max(s, 20 / Max(0.0001, f) / Max(1, Main.Doc.Width));       // not smaller than about 20 pixels on the screen
        FigZ := s;
        if FigDrag in [2, 4] then FigX := AnchX - Main.Doc.Width * FigZ else FigX := AnchX;
        if FigDrag in [2, 3] then FigY := AnchY - Main.Doc.Height * FigZ else FigY := AnchY;
      end;
  else
    begin
      c := CornerAt(X, Y);
      case c of
        2, 5: pb.Cursor := crSizeNWSE;
        3, 4: pb.Cursor := crSizeNESW;
        1: pb.Cursor := crSizeAll;
      else
        pb.Cursor := crDefault;
      end;
      Exit;
    end;
  end;
  UpdateInfo;
end;

procedure TPrintPreview.PbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FigDrag := 0;
end;

procedure TPrintPreview.PbPaint(Sender: TObject);
var
  pw, ph, z, z1, paperW, paperH, margin, f, fx, fy, fz: Double;
  x0, y0, w, h, bw, bh, lx, ly: Integer;
  bmp: TBitmap;
begin
  PageInfo(pw, ph, z, z1, paperW, paperH, margin);
  Placement(fx, fy, fz);
  with pb.Canvas do
  begin
    Brush.Color := TColor($808080);
    FillRect(0, 0, pb.Width, pb.Height);
  end;
  PageGeom(f, x0, y0);
  w := Round(paperW * f);
  h := Round(paperH * f);
  pb.Canvas.Brush.Color := TColor($505050);
  pb.Canvas.FillRect(x0 + 5, y0 + 5, x0 + w + 5, y0 + h + 5);     // shadow
  pb.Canvas.Brush.Color := clWhite;
  pb.Canvas.FillRect(x0, y0, x0 + w, y0 + h);                      // paper
  bw := Max(1, Round(Main.Doc.Width * fz * f));
  bh := Max(1, Round(Main.Doc.Height * fz * f));
  lx := x0 + Round(fx * f);
  ly := y0 + Round(fy * f);
  bmp := TBitmap.Create;
  try
    bmp.SetSize(bw, bh);
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.FillRect(0, 0, bw, bh);
    Main.RenderDocBmp(bmp, fz * f, False);      // what will be drawn, in miniature
    // what goes out of the paper is not printed: it is not shown either
    pb.Canvas.ClipRect := Rect(x0, y0, x0 + w + 1, y0 + h + 1);
    pb.Canvas.Clipping := True;
    pb.Canvas.Draw(lx, ly, bmp);
    pb.Canvas.Clipping := False;
  finally
    bmp.Free;
  end;
  // the frame of the figure, with its corners to drag
  pb.Canvas.Brush.Style := bsClear;
  pb.Canvas.Pen.Color := TColor($C08000);
  pb.Canvas.Pen.Style := psDot;
  pb.Canvas.Rectangle(lx, ly, lx + bw, ly + bh);
  pb.Canvas.Pen.Style := psSolid;
  pb.Canvas.Brush.Style := bsSolid;
  pb.Canvas.Brush.Color := clWhite;
  pb.Canvas.Rectangle(lx - 4, ly - 4, lx + 5, ly + 5);
  pb.Canvas.Rectangle(lx + bw - 4, ly - 4, lx + bw + 5, ly + 5);
  pb.Canvas.Rectangle(lx - 4, ly + bh - 4, lx + 5, ly + bh + 5);
  pb.Canvas.Rectangle(lx + bw - 4, ly + bh - 4, lx + bw + 5, ly + bh + 5);
  pb.Canvas.Brush.Style := bsClear;
  pb.Canvas.Pen.Color := clBlack;
  pb.Canvas.Pen.Width := 1;
  pb.Canvas.Rectangle(x0, y0, x0 + w, y0 + h);
end;

// asks how to export the PDF: vectorial, or as a picture of the page
function AskPdfMode(var raster: Boolean; var dpi: Integer): Boolean;
var
  f: TForm;
  rg: TRadioGroup;
  l: TLabel;
  se: TSpinEdit;
  b1, b2: TButton;
begin
  f := TForm.CreateNew(Application);
  try
    f.Caption := 'Export PDF';
    f.BorderStyle := bsDialog;
    f.Position := poMainFormCenter;
    f.ClientWidth := 460;
    f.ClientHeight := 190;
    rg := TRadioGroup.Create(f);
    rg.Parent := f;
    rg.Caption := 'How to export';
    rg.Items.Add('Export as Vectorial (lines and curves stay sharp at any size)');
    rg.Items.Add('Export as Raster (a picture of the page, as you see it)');
    rg.ItemIndex := Ord(raster);
    rg.SetBounds(12, 10, 436, 88);
    l := TLabel.Create(f);
    l.Parent := f;
    l.Caption := 'Raster resolution (dpi):';
    l.SetBounds(14, 112, 170, 20);
    se := TSpinEdit.Create(f);
    se.Parent := f;
    se.MinValue := 72;
    se.MaxValue := 600;
    se.Value := dpi;
    se.SetBounds(190, 108, 90, 26);
    b1 := TButton.Create(f);
    b1.Parent := f;
    b1.Caption := 'OK';
    b1.ModalResult := mrOk;
    b1.Default := True;
    b1.SetBounds(270, 148, 84, 28);
    b2 := TButton.Create(f);
    b2.Parent := f;
    b2.Caption := 'Cancel';
    b2.ModalResult := mrCancel;
    b2.Cancel := True;
    b2.SetBounds(364, 148, 84, 28);
    Result := f.ShowModal = mrOk;
    if Result then
    begin
      raster := rg.ItemIndex = 1;
      dpi := se.Value;
    end;
  finally
    f.Free;
  end;
end;

function TForm1.RasterGetter(s: TShape): TGraphic;
begin
  Result := RasterPdfBmp;
end;

// the page drawn as a picture (with smooth edges and every effect) and put in a PDF
procedure TForm1.ExportPdfRaster(const fn: string; paperW, paperH, fx, fy, z: Double; dpi: Integer);
var
  tmp: TDoc;
  pw, ph: Double;
  img: TShape;
  bw, bh: Integer;
  k: Double;
begin
  pw := Doc.Width * z;
  ph := Doc.Height * z;
  k := dpi / 72;
  bw := Max(1, Round(pw * k));
  bh := Max(1, Round(ph * k));
  if Int64(bw) * bh > 80000000 then
  begin
    k := k * Sqrt(80000000 / (Int64(bw) * bh));
    bw := Max(1, Round(pw * k));
    bh := Max(1, Round(ph * k));
  end;
  RasterPdfBmp := TBitmap.Create;
  tmp := TDoc.Create;
  try
    RasterPdfBmp.SetSize(bw, bh);
    RasterPdfBmp.Canvas.Brush.Color := clWhite;
    RasterPdfBmp.Canvas.FillRect(0, 0, bw, bh);
    RenderDocBmp(RasterPdfBmp, z * k, False);
    img := TShape.Create;
    img.Kind := skImage;
    img.Style.Stroke := NoColor;
    SetLength(img.P, 2);
    img.P[0] := MakePt(0, 0);
    img.P[1] := MakePt(Doc.Width, Doc.Height);
    tmp.AddShape(img);
    ExportPdf(tmp, fn, paperW, paperH, fx, fy, z, @RasterGetter);
  finally
    tmp.Free;
    FreeAndNil(RasterPdfBmp);
  end;
end;

procedure TForm1.MenuPrint(Sender: TObject);
var
  pv: TPrintPreview;
  pw, ph, z, z1, paperW, paperH, margin, fx, fy: Double;
  pdf, pdfRaster, byBmp: Boolean;
  pdfDpi: Integer;
  fn: string;
  pbmp: TBitmap;
begin
  pdfRaster := False;
  pdfDpi := 300;
  pv := TPrintPreview.CreateFor(Self);
  try
    if pv.ShowModal <> mrOk then Exit;
    pdf := pv.ToPdf;
    pv.PageInfo(pw, ph, z, z1, paperW, paperH, margin);
    pv.Placement(fx, fy, z);
    byBmp := pv.Manual;
    if (not pdf) and pv.Landscape then Printer.Orientation := poLandscape
    else if not pdf then Printer.Orientation := poPortrait;
  finally
    pv.Free;
  end;
  if pdf then
  begin
    SaveDlg.Filter := 'PDF document (*.pdf)|*.pdf';
    SaveDlg.DefaultExt := 'pdf';
    if FileName = '' then SaveDlg.FileName := 'drawing.pdf'
    else SaveDlg.FileName := ChangeFileExt(ExtractFileName(FileName), '.pdf');
    if not SaveDlg.Execute then Exit;
    fn := SaveDlg.FileName;
    if LowerCase(ExtractFileExt(fn)) <> '.pdf' then fn := fn + '.pdf';
    if not AskPdfMode(pdfRaster, pdfDpi) then Exit;
    if Doc.HasFilter and not pdfRaster then
    begin
      pdfRaster := True;       // a filter works on pixels: a vector PDF cannot show it
      ShowMessage('The drawing has a filter layer: the PDF is made as a picture (raster).');
    end;
    try
      if pdfRaster then ExportPdfRaster(fn, paperW, paperH, fx, fy, z, pdfDpi)
      else ExportPdf(Doc, fn, paperW, paperH, fx, fy, z, @ImageOf);   // reference objects are skipped
      SetStatus('PDF saved: ' + fn);
    except
      on E: Exception do ShowMessage('Cannot save the PDF: ' + E.Message);
    end;
    Exit;
  end;
  if Printer.Printers.Count = 0 then
  begin
    ShowMessage('No printer is installed.');
    Exit;
  end;
  Printer.Title := 'TTPaint - ' + ExtractFileName(FileName);
  Printer.BeginDoc;
  try
    if (Doc.HasAlpha or byBmp) and (Int64(Round(Doc.Width * z)) * Round(Doc.Height * z) < 80000000) then
    begin
      // the printer canvas cannot be read back (and cannot be moved): the figure is made as a picture first
      pbmp := TBitmap.Create;
      try
        pbmp.SetSize(Max(1, Round(Doc.Width * z)), Max(1, Round(Doc.Height * z)));
        pbmp.Canvas.Brush.Color := clWhite;
        pbmp.Canvas.FillRect(0, 0, pbmp.Width, pbmp.Height);
        RenderDocBmp(pbmp, z, False);
        Printer.Canvas.Draw(Round(fx), Round(fy), pbmp);
      finally
        pbmp.Free;
      end;
    end
    else RenderDoc(Printer.Canvas, z, False);        // reference objects are not printed
  finally
    Printer.EndDoc;
  end;
  SetStatus('Sent to the printer: ' + Printer.PrinterName);
end;

procedure TForm1.MenuExit(Sender: TObject);
begin
  Close;
end;

{ ================= SVG library ================= }

const
  SnipTemplate =
    '<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">' + #10 +
    '  <circle cx="100" cy="100" r="80" fill="#f4c542" stroke="#333333" stroke-width="4"/>' + #10 +
    '</svg>';

// the SVG of a snippet with the defaults of its parameters (the text itself when it cannot be made)
function SnippetSvgDefault(const src: string): string;
var
  err: string;
begin
  if not SnipExpand(src, nil, Result, err) then Result := src;
end;

// the snippets that come with the program (they cannot be removed or edited)
function BuiltinSnippets: TSnippetArray;

  procedure Add(const nm, svg: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Name := nm;
    Result[High(Result)].Svg := svg;
    Result[High(Result)].Icon := '';
    Result[High(Result)].BuiltIn := True;
  end;

begin
  SetLength(Result, 0);
  Add('Speech bubble',
    '<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <path d="M40 10 H360 Q390 10 390 40 V190 Q390 220 360 220 H190 L110 290 L130 220 H40 Q10 220 10 190 V40 Q10 10 40 10 Z"' + #10 +
    '  fill="#ffffff" stroke="#333333" stroke-width="6" stroke-linejoin="round"/>' + #10 +
    '</svg>');
  Add('Arrow',
    '@param Thick = 3 [1, 30, 0.5] "Line thickness"' + #10 +
    '@param Head = 18 [4, 80, 1] "Size of the head"' + #10 +
    '@param Col = #000000 "Colour"' + #10 +
    '<svg width="200" height="{Head*1.2}" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <line x1="0" y1="{Head*0.6}" x2="{200-Head*0.8}" y2="{Head*0.6}" stroke="{Col}" stroke-width="{Thick}"/>' + #10 +
    ' <polygon points="{200-Head},0 200,{Head*0.6} {200-Head},{Head*1.2}" fill="{Col}" stroke="none"/>' + #10 +
    '</svg>');
  Add('Arrow right',
    '<svg width="400" height="240" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <polygon points="10,80 240,80 240,10 390,120 240,230 240,160 10,160"' + #10 +
    '  fill="#90be6d" stroke="#2d5016" stroke-width="6" stroke-linejoin="round"/>' + #10 +
    '</svg>');
  Add('Pie graph',
    '@paramtext Data "CSV data: label;value (one row per slice, header row optional)\nExample (separator ; or , or tab):\nFruit;Sales\nApples;40\nPears;25\nKiwi;10"' + #10 +
    '@param Hole = 0 [0, 80, 5] "Hole in the middle (%)"' + #10 +
    '@param Pct = 1 [0, 1, 1] "Percentages on the slices (1 = yes)"' + #10 +
    '@param Legend = 1 [0, 1, 1] "Legend (1 = yes)"' + #10 +
    '<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">' + #10 +
    '{let h = hdr(Data)}' + #10 +
    '{let total = sum(Data, 1)}' + #10 +
    '{let cx = 140}' + #10 +
    '{let cy = 150}' + #10 +
    '{let rad = 120}' + #10 +
    '{let rin = rad * Hole / 100}' + #10 +
    '{if total > 0}' + #10 +
    '{for r = h to rows(Data) - 1}' + #10 +
    '{let v = max(0, num(Data, r, 1))}' + #10 +
    '{if v > 0}' + #10 +
    '{let k = r - h}' + #10 +
    '{let a0 = 360 * csum(Data, 1, r) / total}' + #10 +
    '{let a1 = a0 + 360 * v / total}' + #10 +
    '{let am = (a0 + a1) / 2}' + #10 +
    '{let big = (a1 - a0) > 180}' + #10 +
    '{if v >= total * 0.99999}' + #10 +
    '<path d="M {cx - rad} {cy} A {rad} {rad} 0 1 1 {cx + rad} {cy} A {rad} {rad} 0 1 1 {cx - rad} {cy} Z M {cx - rin} {cy} A {rin} {rin} 0 1 0 {cx + rin} {cy} A {rin} {rin} 0 1 0 {cx - rin} {cy} Z" fill="{hsl(k * 137.5 + 205, 62, 55)}" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.5"/>' + #10 +
    '{else}' + #10 +
    '{if rin > 0}' + #10 +
    '<path d="M {cx + rad * sin(a0)} {cy - rad * cos(a0)} A {rad} {rad} 0 {big} 1 {cx + rad * sin(a1)} {cy - rad * cos(a1)} L {cx + rin * sin(a1)} {cy - rin * cos(a1)} A {rin} {rin} 0 {big} 0 {cx + rin * sin(a0)} {cy - rin * cos(a0)} Z" fill="{hsl(k * 137.5 + 205, 62, 55)}" stroke="#ffffff" stroke-width="1.5"/>' + #10 +
    '{else}' + #10 +
    '<path d="M {cx} {cy} L {cx + rad * sin(a0)} {cy - rad * cos(a0)} A {rad} {rad} 0 {big} 1 {cx + rad * sin(a1)} {cy - rad * cos(a1)} Z" fill="{hsl(k * 137.5 + 205, 62, 55)}" stroke="#ffffff" stroke-width="1.5"/>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{if (Pct = 1) and (v / total >= 0.04)}' + #10 +
    '{if rin > 0}{let rl = (rad + rin) / 2}{else}{let rl = rad * 0.65}{end}' + #10 +
    '<text x="{cx + rl * sin(am) - 10}" y="{cy - rl * cos(am) + 4}" font-size="12" fill="#ffffff">{round(100 * v / total)}%</text>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{else}' + #10 +
    '<circle cx="140" cy="150" r="120" fill="#f2f2f2" stroke="#999999" stroke-width="2"/>' + #10 +
    '<text x="80" y="155" font-size="14" fill="#888888">Paste the CSV data</text>' + #10 +
    '{end}' + #10 +
    '{if Legend = 1}' + #10 +
    '{for r = h to rows(Data) - 1}' + #10 +
    '{let k = r - h}' + #10 +
    '<rect x="280" y="{20 + k * 20}" width="12" height="12" fill="{hsl(k * 137.5 + 205, 62, 55)}" stroke="none"/>' + #10 +
    '<text x="298" y="{31 + k * 20}" font-size="12" fill="#333333">{cell(Data, r, 0)}</text>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '</svg>');
  Add('Line graph',
    '@paramtext Data "CSV data: first column = labels, then one column for each line (header row optional)\nExample (separator ; or , or tab):\nMonth;Rome;Milan\nJan;10;14\nFeb;20;18\nMar;35;22"' + #10 +
    '@param Grid = 1 [0, 1, 1] "Grid lines (1 = yes)"' + #10 +
    '@param Dots = 1 [0, 1, 1] "Dots on the points (1 = yes)"' + #10 +
    '<svg width="500" height="300" xmlns="http://www.w3.org/2000/svg">' + #10 +
    '{let h = hdr(Data)}' + #10 +
    '{let n = rows(Data) - h}' + #10 +
    '{let m = cols(Data) - 1}' + #10 +
    '{let lo = min(0, vmin(Data, -1))}' + #10 +
    '{let hi = max(vmax(Data, -1), lo + 1)}' + #10 +
    '{let hi = hi + (hi - lo) * 0.08}' + #10 +
    '{let st = nicestep(hi - lo, 5)}' + #10 +
    '{let y0 = st * floor(lo / st + 0.000001)}' + #10 +
    '{let y1 = st * ceil(hi / st - 0.000001)}' + #10 +
    '{if y1 <= y0}{let y1 = y0 + st}{end}' + #10 +
    '{let px0 = 52}' + #10 +
    '{let px1 = 485}' + #10 +
    '{let py0 = 16}' + #10 +
    '{let py1 = 245}' + #10 +
    '<rect x="{px0}" y="{py0}" width="{px1 - px0}" height="{py1 - py0}" fill="#ffffff" stroke="#888888" stroke-width="1"/>' + #10 +
    '{for t = 0 to round((y1 - y0) / st)}' + #10 +
    '{let yv = y0 + t * st}' + #10 +
    '{let yy = py1 - (yv - y0) / (y1 - y0) * (py1 - py0)}' + #10 +
    '{if Grid = 1}<line x1="{px0}" y1="{yy}" x2="{px1}" y2="{yy}" stroke="#dddddd" stroke-width="1"/>{end}' + #10 +
    '<text x="4" y="{yy + 4}" font-size="11" fill="#444444">{yv}</text>' + #10 +
    '{end}' + #10 +
    '{if n > 0}' + #10 +
    '{let skip = ceil(n / 10)}' + #10 +
    '{for j = 0 to n - 1}' + #10 +
    '{if j mod skip = 0}<text x="{px0 + (j + 0.5) * (px1 - px0) / n - 8}" y="{py1 + 15}" font-size="11" fill="#444444">{cell(Data, j + h, 0)}</text>{end}' + #10 +
    '{end}' + #10 +
    '{for s = 1 to m}' + #10 +
    '<polyline fill="none" stroke="{hsl((s - 1) * 137.5 + 215, 65, 45)}" stroke-width="2" points="{for j = 0 to n - 1}{px0 + (j + 0.5) * (px1 - px0) / n} {py1 - (num(Data, j + h, s) - y0) / (y1 - y0) * (py1 - py0)} {end}"/>' + #10 +
    '{if Dots = 1}' + #10 +
    '{for j = 0 to n - 1}' + #10 +
    '<circle cx="{px0 + (j + 0.5) * (px1 - px0) / n}" cy="{py1 - (num(Data, j + h, s) - y0) / (y1 - y0) * (py1 - py0)}" r="3" fill="{hsl((s - 1) * 137.5 + 215, 65, 45)}" stroke="none"/>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{else}' + #10 +
    '<text x="190" y="140" font-size="14" fill="#888888">Paste the CSV data</text>' + #10 +
    '{end}' + #10 +
    '{if h = 1}' + #10 +
    '{for s = 1 to m}' + #10 +
    '<rect x="{px0 + (s - 1) * 100}" y="272" width="12" height="12" fill="{hsl((s - 1) * 137.5 + 215, 65, 45)}" stroke="none"/>' + #10 +
    '<text x="{px0 + (s - 1) * 100 + 17}" y="282" font-size="11" fill="#333333">{cell(Data, 0, s)}</text>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '</svg>');
  Add('Scatter XY',
    '@paramtext Data "CSV data: x;y (one row per point; more columns add series; header row optional)\nExample (separator ; or tab; with a decimal comma only if the separator is not a comma):\nx;Group A;Group B\n1;2,1;1,5\n2;3,9;2,8\n3;6,2;3,1\n4;8,1;5,5"' + #10 +
    '@param Grid = 1 [0, 1, 1] "Grid lines (1 = yes)"' + #10 +
    '@param Size = 3.5 [1, 12, 0.5] "Size of the points"' + #10 +
    '<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">' + #10 +
    '{let h = hdr(Data)}' + #10 +
    '{let n = rows(Data) - h}' + #10 +
    '{let m = cols(Data) - 1}' + #10 +
    '{let xmin = vmin(Data, 0)}' + #10 +
    '{let xmax = vmax(Data, 0)}' + #10 +
    '{let ymin = vmin(Data, -1)}' + #10 +
    '{let ymax = vmax(Data, -1)}' + #10 +
    '{if xmax <= xmin}{let xmax = xmin + 1}{end}' + #10 +
    '{if ymax <= ymin}{let ymax = ymin + 1}{end}' + #10 +
    '{let xmin = xmin - (xmax - xmin) * 0.04}' + #10 +
    '{let xmax = xmax + (xmax - xmin) * 0.04}' + #10 +
    '{let ymin = ymin - (ymax - ymin) * 0.06}' + #10 +
    '{let ymax = ymax + (ymax - ymin) * 0.06}' + #10 +
    '{let xs = nicestep(xmax - xmin, 6)}' + #10 +
    '{let ys = nicestep(ymax - ymin, 5)}' + #10 +
    '{let x0 = xs * floor(xmin / xs + 0.000001)}' + #10 +
    '{let x1 = xs * ceil(xmax / xs - 0.000001)}' + #10 +
    '{let y0 = ys * floor(ymin / ys + 0.000001)}' + #10 +
    '{let y1 = ys * ceil(ymax / ys - 0.000001)}' + #10 +
    '{if x1 <= x0}{let x1 = x0 + xs}{end}' + #10 +
    '{if y1 <= y0}{let y1 = y0 + ys}{end}' + #10 +
    '{let px0 = 52}' + #10 +
    '{let px1 = 385}' + #10 +
    '{let py0 = 16}' + #10 +
    '{let py1 = 250}' + #10 +
    '<rect x="{px0}" y="{py0}" width="{px1 - px0}" height="{py1 - py0}" fill="#ffffff" stroke="#888888" stroke-width="1"/>' + #10 +
    '{for t = 0 to round((x1 - x0) / xs)}' + #10 +
    '{let xx = px0 + t * xs / (x1 - x0) * (px1 - px0)}' + #10 +
    '{if Grid = 1}<line x1="{xx}" y1="{py0}" x2="{xx}" y2="{py1}" stroke="#dddddd" stroke-width="1"/>{end}' + #10 +
    '<text x="{xx - 8}" y="{py1 + 15}" font-size="11" fill="#444444">{x0 + t * xs}</text>' + #10 +
    '{end}' + #10 +
    '{for t = 0 to round((y1 - y0) / ys)}' + #10 +
    '{let yy = py1 - t * ys / (y1 - y0) * (py1 - py0)}' + #10 +
    '{if Grid = 1}<line x1="{px0}" y1="{yy}" x2="{px1}" y2="{yy}" stroke="#dddddd" stroke-width="1"/>{end}' + #10 +
    '<text x="4" y="{yy + 4}" font-size="11" fill="#444444">{y0 + t * ys}</text>' + #10 +
    '{end}' + #10 +
    '{if n > 0}' + #10 +
    '{for s = 1 to m}' + #10 +
    '{for j = 0 to n - 1}' + #10 +
    '{if isnum(Data, j + h, 0) and isnum(Data, j + h, s)}' + #10 +
    '<circle cx="{px0 + (num(Data, j + h, 0) - x0) / (x1 - x0) * (px1 - px0)}" cy="{py1 - (num(Data, j + h, s) - y0) / (y1 - y0) * (py1 - py0)}" r="{Size}" fill="{hsl((s - 1) * 137.5 + 215, 65, 45)}" stroke="none"/>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{else}' + #10 +
    '<text x="130" y="140" font-size="14" fill="#888888">Paste the CSV data</text>' + #10 +
    '{end}' + #10 +
    '{if (h = 1) and (m > 1)}' + #10 +
    '{for s = 1 to m}' + #10 +
    '<rect x="{px0 + (s - 1) * 100}" y="272" width="12" height="12" fill="{hsl((s - 1) * 137.5 + 215, 65, 45)}" stroke="none"/>' + #10 +
    '<text x="{px0 + (s - 1) * 100 + 17}" y="282" font-size="11" fill="#333333">{cell(Data, 0, s)}</text>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '</svg>');
  Add('Table',
    '@paramtext Data "CSV data: one row per table row (header row optional, shown in bold)\nExample (separator ; or , or tab):\nFruit;Sales;Price\nApples;40;1.2\nPears;25;1.8\nKiwi;10;2.5"' + #10 +
    '@param Row1 = #ffffff "Colour of the odd rows"' + #10 +
    '@param Row2 = #dce9f7 "Colour of the even rows"' + #10 +
    '@param Head = #4a7fb5 "Colour of the header row"' + #10 +
    '@param Text = #222222 "Text colour"' + #10 +
    '@param Grid = 1 [0, 1, 1] "Lines between the rows (1 = yes)"' + #10 +
    '@param RowH = 26 [14, 60, 1] "Height of a row"' + #10 +
    '@param FS = 14 [8, 30, 1] "Size of the text"' + #10 +
    '<!-- natural size -->' + #10 +
    '{let h = hdr(Data)}' + #10 +
    '{let n = rows(Data)}' + #10 +
    '{let m = max(1, cols(Data))}' + #10 +
    '{let cw = FS * 0.62}' + #10 +
    '{let pad = FS * 0.7}' + #10 +
    '{let tw = 0}' + #10 +
    '{for c = 0 to m - 1}{let tw = tw + 2 * pad + max(2, maxlen(Data, c)) * cw}{end}' + #10 +
    '<svg width="{tw}" height="{max(1, n) * RowH}" xmlns="http://www.w3.org/2000/svg">' + #10 +
    '{if n > 0}' + #10 +
    '{for r = 0 to n - 1}' + #10 +
    '{if (r = 0) and (h = 1)}' + #10 +
    '<rect x="0" y="{r * RowH}" width="{tw}" height="{RowH}" fill="{Head}" stroke="none"/>' + #10 +
    '{else}' + #10 +
    '{if (r - h) mod 2 = 0}' + #10 +
    '<rect x="0" y="{r * RowH}" width="{tw}" height="{RowH}" fill="{Row1}" stroke="none"/>' + #10 +
    '{else}' + #10 +
    '<rect x="0" y="{r * RowH}" width="{tw}" height="{RowH}" fill="{Row2}" stroke="none"/>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{if (Grid = 1) and (r > 0)}<line x1="0" y1="{r * RowH}" x2="{tw}" y2="{r * RowH}" stroke="#b8b8b8" stroke-width="0.6"/>{end}' + #10 +
    '{let x = 0}' + #10 +
    '{for c = 0 to m - 1}' + #10 +
    '{let w = 2 * pad + max(2, maxlen(Data, c)) * cw}' + #10 +
    '{if (r = 0) and (h = 1)}' + #10 +
    '<text x="{x + pad}" y="{r * RowH + RowH / 2 + FS * 0.35}" font-size="{FS}" font-weight="bold" fill="#ffffff">{cell(Data, r, c)}</text>' + #10 +
    '{else}' + #10 +
    '{if isnum(Data, r, c)}' + #10 +
    '<text x="{x + w - pad - tlen(Data, r, c) * cw}" y="{r * RowH + RowH / 2 + FS * 0.35}" font-size="{FS}" fill="{Text}">{cell(Data, r, c)}</text>' + #10 +
    '{else}' + #10 +
    '<text x="{x + pad}" y="{r * RowH + RowH / 2 + FS * 0.35}" font-size="{FS}" fill="{Text}">{cell(Data, r, c)}</text>' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '{let x = x + w}' + #10 +
    '{end}' + #10 +
    '{end}' + #10 +
    '<rect x="0" y="0" width="{tw}" height="{n * RowH}" fill="none" stroke="#888888" stroke-width="1"/>' + #10 +
    '{else}' + #10 +
    '<rect x="0" y="0" width="{tw}" height="{RowH}" fill="{Row2}" stroke="#888888" stroke-width="1"/>' + #10 +
    '<text x="{pad}" y="{RowH / 2 + FS * 0.35}" font-size="{FS}" fill="#888888">Paste the CSV data</text>' + #10 +
    '{end}' + #10 +
    '</svg>');
  Add('Ruler',
    '@param Scale = 10 [2, 40, 0.5] "Scale (pixels per tick)"' + #10 +
    '@param Ticks = 30 [5, 150, 1] "Number of ticks"' + #10 +
    '@param Back = #f6e7a6 "Background colour"' + #10 +
    '<svg width="{Ticks*Scale}" height="46" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <rect x="0" y="0" width="{Ticks*Scale}" height="46" fill="{Back}" stroke="#5c4a00" stroke-width="2"/>' + #10 +
    ' {for i = 0 to Ticks}' + #10 +
    ' <line x1="{i*Scale}" y1="0" x2="{i*Scale}" y2="{if i mod 10 = 0}20{else}{if i mod 5 = 0}14{else}8{end}{end}" stroke="#5c4a00" stroke-width="1.5"/>' + #10 +
    ' {if i mod 10 = 0}<text x="{i*Scale+3}" y="38" font-size="12" fill="#5c4a00">{i/10}</text>{end}' + #10 +
    ' {end}' + #10 +
    '</svg>');
  Add('Squared paper',
    '@param Cols = 20 [1, 100, 1] "Width (number of squares)"' + #10 +
    '@param Rows = 15 [1, 100, 1] "Height (number of squares)"' + #10 +
    '@param Size = 20 [5, 80, 1] "Square size (pixels)"' + #10 +
    '@param Thick = 0.8 [0.2, 3, 0.1] "Line thickness"' + #10 +
    '@param Paper = #ffffff "Paper colour"' + #10 +
    '@param Ink = #4a90c2 "Line colour"' + #10 +
    '<svg width="{Cols*Size}" height="{Rows*Size}" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <rect x="0" y="0" width="{Cols*Size}" height="{Rows*Size}" fill="{Paper}" stroke="{Ink}" stroke-width="{Thick*2}"/>' + #10 +
    ' <path fill="none" stroke="{Ink}" stroke-width="{Thick}" d="{for i = 1 to Cols-1}M{i*Size} 0L{i*Size} {Rows*Size} {end}{for j = 1 to Rows-1}M0 {j*Size}L{Cols*Size} {j*Size} {end}"/>' + #10 +
    '</svg>');
  Add('Isometric grid',
    '@param Cols = 20 [1, 60, 1] "Width (number of cells)"' + #10 +
    '@param Rows = 12 [1, 40, 1] "Height (number of cells)"' + #10 +
    '@param Size = 20 [8, 60, 1] "Cell size (pixels)"' + #10 +
    '@param Thick = 0.8 [0.2, 3, 0.1] "Line thickness"' + #10 +
    '@param Paper = #ffffff "Paper colour"' + #10 +
    '@param Ink = #4a90c2 "Line colour"' + #10 +
    '<svg width="{(Cols*Size*0.866025)}" height="{(Rows*Size)}" xmlns="http://www.w3.org/2000/svg">' + #10 +
    ' <rect x="0" y="0" width="{(Cols*Size*0.866025)}" height="{(Rows*Size)}" fill="{Paper}" stroke="{Ink}" stroke-width="{Thick*2}"/>' + #10 +
    ' <!-- one path for all the lines: vertical, and at 30 degrees up and down -->' + #10 +
    ' <path fill="none" stroke="{Ink}" stroke-width="{Thick}" d="{for i = 1 to Cols-1}M{i*Size*0.866025} 0L{i*Size*0.866025} {(Rows*Size)} {end}{for k = -ceil(Cols/2)-1 to Rows}{if min((Cols*Size*0.866025),((Rows*Size)-k*Size)/0.57735) > max(0,-k*Size/0.57735)}M{max(0,-k*Size/0.57735)} {(k*Size+0.57735*max(0,-k*Size/0.57735))}L{min((Cols*Size*0.866025),((Rows*Size)-k*Size)/0.57735)} {(k*Size+0.57735*min((Cols*Size*0.866025),((Rows*Size)-k*Size)/0.57735))} {end}{end}{for k = 0 to Rows+ceil(Cols/2)+1}{if min((Cols*Size*0.866025),k*Size/0.57735) > max(0,(k*Size-(Rows*Size))/0.57735)}M{max(0,(k*Size-(Rows*Size))/0.57735)} {(k*Size-0.57735*max(0,(k*Size-(Rows*Size))/0.57735))}L{min((Cols*Size*0.866025),k*Size/0.57735)} {(k*Size-0.57735*min((Cols*Size*0.866025),k*Size/0.57735))} {end}{end}"/>' + #10 +
    '</svg>');
end;

// the icon of a snippet: its PNG, or the SVG drawn small; size x size, on white
function TForm1.SnippetGlyph(const sn: TSnippet; size: Integer): TBitmap;
var
  png: TPortableNetworkGraphic;
  ss: TStringStream;
  tmp: TDoc;
  old: TDoc;
  ids: TIntArray;
  src: TBitmap;
  z: Double;
  w, h: Integer;
  ok: Boolean;
begin
  Result := TBitmap.Create;
  Result.SetSize(size, size);
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(0, 0, size, size);
  ok := False;
  if sn.Icon <> '' then
  begin
    png := TPortableNetworkGraphic.Create;
    ss := TStringStream.Create(sn.Icon);
    try
      try
        png.LoadFromStream(ss);
        z := Min((size - 2) / Max(1, png.Width), (size - 2) / Max(1, png.Height));
        w := Max(1, Round(png.Width * z));
        h := Max(1, Round(png.Height * z));
        Result.Canvas.StretchDraw(Rect((size - w) div 2, (size - h) div 2, (size - w) div 2 + w, (size - h) div 2 + h), png);
        ok := True;
      except
        ok := False;
      end;
    finally
      ss.Free;
      png.Free;
    end;
  end;
  if ok then Exit;
  // drawn from the SVG, with the document machinery of a scratch drawing
  tmp := TDoc.Create;
  old := Doc;
  src := TBitmap.Create;
  try
    try
      SVGToDoc(SnippetSvgDefault(sn.Svg), tmp, False, 0, 0, ids);
      z := (size - 4) / Max(tmp.Width, tmp.Height);
      w := Max(1, Round(tmp.Width * z));
      h := Max(1, Round(tmp.Height * z));
      src.SetSize(w, h);
      src.Canvas.Brush.Color := clWhite;
      src.Canvas.FillRect(0, 0, w, h);
      Doc := tmp;
      RenderDocBmp(src, z, False);
      Doc := old;
      Result.Canvas.Draw((size - w) div 2, (size - h) div 2, src);
    except
      Doc := old;
    end;
  finally
    Doc := old;
    src.Free;
    tmp.Free;
  end;
end;

procedure TForm1.InitSnippets;
var
  ini: TIniFile;
  n, i: Integer;
  sn: TSnippet;
begin
  Snippets := BuiltinSnippets;
  SnipIdx := -1;
  if FileExists(ConfigPath) then
  begin
    ini := TIniFile.Create(ConfigPath);
    try
      n := ini.ReadInteger('Snippets', 'Count', 0);
      for i := 1 to n do
      begin
        sn.Name := DecodeStringBase64(ini.ReadString('Snippets', 'Name' + IntToStr(i), ''));
        sn.Svg := DecodeStringBase64(ini.ReadString('Snippets', 'Svg' + IntToStr(i), ''));
        sn.Icon := DecodeStringBase64(ini.ReadString('Snippets', 'Icon' + IntToStr(i), ''));
        sn.BuiltIn := False;
        if (sn.Name = '') or (sn.Svg = '') then Continue;
        SetLength(Snippets, Length(Snippets) + 1);
        Snippets[High(Snippets)] := sn;
      end;
    finally
      ini.Free;
    end;
  end;
  SnipPanel := TPanel.Create(Self);
  SnipPanel.Parent := Panel1;
  SnipPanel.Left := 5000;
  SnipPanel.Align := alLeft;            // a fixed width: four icons per row (the box inside scrolls when there are more rows)
  if NewIcons then SnipPanel.Width := 4 * 45 + 4 + 28 else SnipPanel.Width := 4 * 40 + 4 + 28;
  SnipPanel.BevelOuter := bvRaised;
  with TLabel.Create(Self) do
  begin
    Parent := SnipPanel;
    Caption := 'SVG Snippets';
    SetBounds(8, 8, 120, 16);
  end;
  SnipBox := TScrollBox.Create(Self);
  SnipBox.Parent := SnipPanel;
  SnipBox.Align := alClient;
  SnipBox.BorderSpacing.Top := 26;
  SnipBox.OnResize := @SnipBoxResize;
  SnipBox.BorderStyle := bsNone;
  SnipBox.HorzScrollBar.Visible := False;
  SnipBox.VertScrollBar.Tracking := True;
  SnipBox.AutoScroll := True;
  RebuildSnipButtons;
end;

procedure TForm1.SaveSnippets(ini: TIniFile);
var
  i, n: Integer;
begin
  ini.EraseSection('Snippets');
  n := 0;
  for i := 0 to High(Snippets) do
    if not Snippets[i].BuiltIn then
    begin
      Inc(n);
      ini.WriteString('Snippets', 'Name' + IntToStr(n), EncodeStringBase64(Snippets[i].Name));
      ini.WriteString('Snippets', 'Svg' + IntToStr(n), EncodeStringBase64(Snippets[i].Svg));
      ini.WriteString('Snippets', 'Icon' + IntToStr(n), EncodeStringBase64(Snippets[i].Icon));
    end;
  ini.WriteInteger('Snippets', 'Count', n);
end;

// the tile of the icons (dark rounded square, grid, frame), made like the ones of the icons folder
function MakeSnipTile(S: Integer): TBGRABitmap;
var
  x, y, k, j: Integer;
  t, f: Double;
  p: PBGRAPixel;
  r, g, b: Integer;

  function Mix(a, c: Integer; f: Double): Integer;
  begin
    Result := Round(a + (c - a) * f);
  end;

begin
  Result := TBGRABitmap.Create(S, S, BGRAPixelTransparent);
  Result.FillRoundRectAntialias(S * 2 / 128, S * 2 / 128, S * 125 / 128, S * 125 / 128, S * 32 / 128, S * 32 / 128, BGRA(255, 255, 255, 255));
  for y := 0 to S - 1 do
    for x := 0 to S - 1 do
    begin
      p := Result.Data + y * S + x;
      if p^.alpha = 0 then Continue;
      t := (x + y) / (2 * (S - 1));
      if t < 0.5 then
      begin
        f := t * 2;
        r := Mix($1e, $1e, f); g := Mix($3a, $1b, f); b := Mix($8a, $4b, f);
      end
      else
      begin
        f := (t - 0.5) * 2;
        r := Mix($1e, $3b, f); g := Mix($1b, $07, f); b := Mix($4b, $64, f);
      end;
      k := 0;
      for j := 0 to 2 do
        if (x = Round(S * (28 + 36 * j) / 128)) or (y = Round(S * (28 + 36 * j) / 128)) then k := 1;
      if k = 1 then
      begin
        r := Mix(r, 129, 0.16);
        g := Mix(g, 140, 0.16);
        b := Mix(b, 248, 0.16);
      end;
      p^.red := r;
      p^.green := g;
      p^.blue := b;
    end;
  Result.RoundRectAntialias(S * 2 / 128, S * 2 / 128, S * 125 / 128, S * 125 / 128, S * 32 / 128, S * 32 / 128, BGRA(129, 140, 248, 90), Max(1, S * 3 div 128));
end;

// the picture of a snippet on the tile of the new icons, as a glyph of the button
procedure TForm1.ApplySnipGlyph(b: TSpeedButton; const sn: TSnippet);
const
  S = 128;
  C = 96;       // size of the drawing on the tl
var
  g: TBitmap;
  src, tl, ic: TBGRABitmap;
  pc: TColor;
  lp, x, y, d, al, ch, o: Integer;
  p, q: PBGRAPixel;
  cr, cg, cb: Integer;
  hh, ss, ll, l2: Double;
begin
  pc := BackColorOf(b);
  lp := (Red(pc) * 30 + Green(pc) * 59 + Blue(pc) * 11) div 100;
  g := SnippetGlyph(sn, C);
  src := TBGRABitmap.Create(g);
  g.Free;
  tl := MakeSnipTile(S);
  try
    TintIconTile(tl, pc);
    o := (S - C) div 2;
    for y := 0 to C - 1 do
      for x := 0 to C - 1 do
      begin
        p := src.Data + y * C + x;
        d := Max(255 - p^.red, Max(255 - p^.green, 255 - p^.blue));
        al := Min(255, d * 2);
        if al = 0 then Continue;
        cr := 255 - (255 - p^.red) * 255 div al;
        cg := 255 - (255 - p^.green) * 255 div al;
        cb := 255 - (255 - p^.blue) * 255 div al;
        cr := Max(0, Min(255, cr));
        cg := Max(0, Min(255, cg));
        cb := Max(0, Min(255, cb));
        if lp < 128 then
        begin
          // dark panel: black strokes become light, dark colours are lifted
          IconRgbToHsl(cr, cg, cb, hh, ss, ll);
          if ss < 0.3 then l2 := 0.92 - 0.6 * ll else l2 := Max(ll, 0.5);
          IconHslToRgb(hh, ss, l2, cr, cg, cb);
          cr := Max(0, Min(255, cr));
          cg := Max(0, Min(255, cg));
          cb := Max(0, Min(255, cb));
        end;
        q := tl.Data + (y + o) * S + x + o;
        if q^.alpha = 0 then Continue;
        ch := 255 - al;
        q^.red := (q^.red * ch + cr * al) div 255;
        q^.green := (q^.green * ch + cg * al) div 255;
        q^.blue := (q^.blue * ch + cb * al) div 255;
      end;
    tl.InvalidateBitmap;
    ic := tl.Resample(Max(8, Min(b.Width, b.Height) - 6), Max(8, Min(b.Width, b.Height) - 6), rmFineResample) as TBGRABitmap;
    try
      ApplyGlyphIcon(b, ic, False);
    finally
      ic.Free;
    end;
  finally
    tl.Free;
    src.Free;
  end;
end;

// one button per snippet, four to a row; the box scrolls when there are more rows than it shows
procedure TForm1.RebuildSnipButtons;
var
  i: Integer;
  b: TSpeedButton;
  g: TBitmap;
begin
  for i := 0 to High(SnipButtons) do SnipButtons[i].Free;
  SetLength(SnipButtons, Length(Snippets));
  for i := 0 to High(Snippets) do
  begin
    b := TSpeedButton.Create(Self);
    b.Parent := SnipBox;
    if NewIcons then b.SetBounds(0, 0, 40, 36) else b.SetBounds(0, 0, 38, 31);
    b.Tag := i;
    b.Hint := Snippets[i].Name;
    b.ShowHint := True;
    b.OnClick := @SnipButtonClick;
    if NewIcons then ApplySnipGlyph(b, Snippets[i])
    else
    begin
      g := SnippetGlyph(Snippets[i], 26);
      try
        b.Glyph.Assign(g);
      finally
        g.Free;
      end;
    end;
    SnipButtons[i] := b;
  end;
  if (SnipIdx >= Length(Snippets)) then SnipIdx := -1;
  ArrangeSnipButtons;
end;

// as many buttons to a row as the box is wide
procedure TForm1.ArrangeSnipButtons;
var
  i, cols: Integer;
begin
  if NewIcons then
  begin
    cols := Max(1, (SnipBox.ClientWidth - 4) div 45);
    for i := 0 to High(SnipButtons) do
      SnipButtons[i].SetBounds(4 + (i mod cols) * 45, 2 + (i div cols) * 37, 40, 36);
    Exit;
  end;
  cols := Max(1, (SnipBox.ClientWidth - 4) div 40);
  for i := 0 to High(SnipButtons) do
    SnipButtons[i].SetBounds(4 + (i mod cols) * 40, 2 + (i div cols) * 33, 38, 31);
end;

procedure TForm1.SnipBoxResize(Sender: TObject);
begin
  ArrangeSnipButtons;
end;

procedure TForm1.SnipButtonClick(Sender: TObject);
begin
  SnipIdx := TSpeedButton(Sender).Tag;
  SetTool(tlSnippet);
  SnipStage := 0;
end;

function TForm1.SnipOwner(gid: Integer): TShape;
var
  i: Integer;
begin
  Result := nil;
  if gid <= 0 then Exit;
  for i := 0 to Doc.Shapes.Count - 1 do
    if (Doc.Shapes[i].GroupId = gid) and (Doc.Shapes[i].Snip <> '') then Exit(Doc.Shapes[i]);
end;

// the group that is the whole selection and was made from a snippet with parameters (0: none)
function TForm1.SnipGroupOfSelection: Integer;
var
  ts: TShapeArray;
  i, gid: Integer;
begin
  Result := 0;
  if SelQuote <> nil then Exit;
  ts := SelShapes;
  if Length(ts) = 0 then Exit;
  gid := ts[0].GroupId;
  if gid <= 0 then Exit;
  for i := 1 to High(ts) do
    if ts[i].GroupId <> gid then Exit;
  if SnipOwner(gid) <> nil then Result := gid;
end;

function StepDigits(step: Double): Integer;
begin
  if Abs(step - Round(step)) < 1e-9 then Result := 0
  else if step >= 0.1 - 1e-9 then Result := 1
  else if step >= 0.01 - 1e-9 then Result := 2
  else Result := 3;
end;

function SnipRgbToColor(rgb: Integer): TColor;
begin
  Result := TColor(((rgb shr 16) and $FF) or (rgb and $FF00) or ((rgb and $FF) shl 16));
end;

function SnipColorToRgb(c: TColor): Integer;
begin
  Result := ((Integer(c) and $FF) shl 16) or (Integer(c) and $FF00) or ((Integer(c) shr 16) and $FF);
end;

// the parameters of the selected snippet group: a spin edit and a slider for each
procedure TForm1.UpdateSnipRow(gid: Integer);
var
  own: TShape;
  src, body, err, key: string;
  vals: TSnipValues;
  texts: TSnipTexts;
  fx, fy, cw, ch: Double;
  i, nTicks, y, trkW: Integer;
  l: TLabel;
  p: TPanel;
begin
  if Rows[45] = nil then Exit;
  Rows[45].Visible := False;
  if gid <= 0 then Exit;
  own := SnipOwner(gid);
  if (own = nil) or not SnipDecodeT(own.Snip, src, vals, texts, fx, fy, cw, ch) or
     not SnipSplit(src, SnipPrm, body, err) or (Length(SnipPrm) = 0) then Exit;
  p := Rows[45];
  key := IntToStr(gid) + '#' + src;
  if key <> SnipUiKey then
  begin
    while p.ControlCount > 0 do p.Controls[0].Free;
    SetLength(SnipSpins, 0);
    SetLength(SnipTracks, 0);
    SetLength(SnipColors, 0);
    SetLength(SnipMemos, 0);
    l := TLabel.Create(Self);
    l.Parent := p;
    l.Caption := 'Snippet parameters';
    l.Font.Style := [fsBold];
    l.SetBounds(8, 6, 200, 18);
    SetLength(SnipSpins, Length(SnipPrm));
    SetLength(SnipTracks, Length(SnipPrm));
    SetLength(SnipColors, Length(SnipPrm));
    SetLength(SnipMemos, Length(SnipPrm));
    trkW := Math.Max(80, p.ClientWidth - 120);
    y := 28;
    for i := 0 to High(SnipPrm) do
    begin
      l := TLabel.Create(Self);
      l.Parent := p;
      l.Caption := Copy(SnipPrm[i].Caption, 1, Pos('\n', SnipPrm[i].Caption + '\n') - 1);
      l.AutoSize := False;
      l.WordWrap := SnipPrm[i].IsText;
      if SnipPrm[i].IsText then l.SetBounds(8, y, p.ClientWidth - 16, 34) else l.SetBounds(8, y, p.ClientWidth - 16, 18);
      if SnipPrm[i].IsText then
      begin
        // a table: a place to paste the CSV
        SnipMemos[i] := TMemo.Create(Self);
        with SnipMemos[i] do
        begin
          Parent := p;
          Tag := i;
          Anchors := [akLeft, akTop, akRight];
          SetBounds(8, y + 36, p.ClientWidth - 20, 140);
          ScrollBars := ssBoth;
          WordWrap := False;
          Font.Name := 'Monospace';
        end;
        with TButton.Create(Self) do
        begin
          Parent := p;
          Tag := i;
          Caption := 'OK';
          SetBounds(8, y + 36 + 144, 80, 26);
          OnClick := @SnipApply;
        end;
        Inc(y, 36 + 140 + 4 + 26 + 8);
        Continue;
      end;
      if SnipPrm[i].IsColor then
      begin
        SnipColors[i] := TColorButton.Create(Self);
        with SnipColors[i] do
        begin
          Parent := p;
          Tag := i;
          SetBounds(8, y + 20, 92, 24);
          ButtonColor := SnipRgbToColor(Round(SnipPrm[i].Def));
          OnColorChanged := @SnipColorChange;
        end;
        Inc(y, 54);
        Continue;
      end;
      SnipSpins[i] := TFloatSpinEdit.Create(Self);
      with SnipSpins[i] do
      begin
        Parent := p;
        Tag := i;
        SetBounds(8, y + 20, 92, 24);
        MinValue := SnipPrm[i].Min;
        MaxValue := SnipPrm[i].Max;
        Increment := SnipPrm[i].Step;
        DecimalPlaces := StepDigits(SnipPrm[i].Step);
        Value := SnipPrm[i].Def;
        OnChange := @SnipSpinChange;
        OnEditingDone := @SnipApply;
      end;
      nTicks := Round((SnipPrm[i].Max - SnipPrm[i].Min) / SnipPrm[i].Step);
      nTicks := Math.Max(1, Math.Min(1000, nTicks));
      SnipTracks[i] := TTrackBar.Create(Self);
      with SnipTracks[i] do
      begin
        Parent := p;
        Tag := i;
        Anchors := [akLeft, akTop, akRight];
        SetBounds(104, y + 19, trkW, 26);
        ShowHint := False;
        TickStyle := tsNone;
        Min := 0;
        Max := nTicks;
        OnChange := @SnipTrackChange;
      end;
      Inc(y, 54);
    end;
    p.Height := y + 6;
    SnipUiKey := key;
  end;
  // the values of this object
  SnipSync := True;
  try
    for i := 0 to High(SnipPrm) do
      if SnipPrm[i].IsText then
      begin
        // not while the user is typing in it
        if (i <= High(texts)) and (SnipMemos[i].Text <> texts[i]) then SnipMemos[i].Text := texts[i]
        else if (i > High(texts)) and (SnipMemos[i].Text <> '') then SnipMemos[i].Text := '';
      end
      else if (i <= High(vals)) and SnipPrm[i].IsColor then
        SnipColors[i].ButtonColor := SnipRgbToColor(Round(vals[i]))
      else if i <= High(vals) then
      begin
        SnipSpins[i].Value := vals[i];
        SnipTracks[i].Position := Round((vals[i] - SnipPrm[i].Min) / (SnipPrm[i].Max - SnipPrm[i].Min) * SnipTracks[i].Max);
      end;
  finally
    SnipSync := False;
  end;
  p.Visible := True;
end;

procedure TForm1.SnipMemoChange(Sender: TObject);
begin
  if UpdatingProps or SnipSync then Exit;
  SnipTimer.Enabled := False;
  SnipTimer.Enabled := True;
end;

procedure TForm1.SnipSpinChange(Sender: TObject);
var
  i: Integer;
begin
  if UpdatingProps or SnipSync then Exit;
  i := TComponent(Sender).Tag;
  if (i < 0) or (i > High(SnipTracks)) or (SnipSpins[i] = nil) then Exit;
  SnipSync := True;
  try
    SnipTracks[i].Position := Round((SnipSpins[i].Value - SnipPrm[i].Min) / (SnipPrm[i].Max - SnipPrm[i].Min) * SnipTracks[i].Max);
  finally
    SnipSync := False;
  end;
  SnipTimer.Enabled := False;
  SnipTimer.Enabled := True;
end;

procedure TForm1.SnipTrackChange(Sender: TObject);
var
  i: Integer;
  v: Double;
begin
  if UpdatingProps or SnipSync then Exit;
  i := TComponent(Sender).Tag;
  if (i < 0) or (i > High(SnipSpins)) or (SnipSpins[i] = nil) then Exit;
  v := SnipPrm[i].Min + SnipTracks[i].Position / SnipTracks[i].Max * (SnipPrm[i].Max - SnipPrm[i].Min);
  v := SnipPrm[i].Min + Round((v - SnipPrm[i].Min) / SnipPrm[i].Step) * SnipPrm[i].Step;
  SnipSync := True;
  try
    SnipSpins[i].Value := v;
  finally
    SnipSync := False;
  end;
  SnipTimer.Enabled := False;
  SnipTimer.Enabled := True;
end;

procedure TForm1.SnipColorChange(Sender: TObject);
begin
  if UpdatingProps or SnipSync then Exit;
  SnipTimer.Enabled := False;
  SnipTimer.Enabled := True;
end;

// the object is made again with the values in the controls, in the same place and with the same stretch
procedure TForm1.SnipApply(Sender: TObject);
var
  gid, i, at, k: Integer;
  own: TShape;
  src, svg, err: string;
  vals, oldVals: TSnipValues;
  texts, oldTexts: TSnipTexts;
  fx, fy, cw, ch, g0x, g0y, g1x, g1y, turn, gcx, gcy, ghw, ghh: Double;
  tl, p1: TPt;
  sk, dr, cv: Integer;
  oldIds, newIds: TIntArray;
  differs: Boolean;
  gname: string;
begin
  SnipTimer.Enabled := False;
  if UpdatingProps then Exit;
  gid := SnipGroupOfSelection;
  if gid = 0 then Exit;
  own := SnipOwner(gid);
  if not SnipDecodeT(own.Snip, src, oldVals, oldTexts, fx, fy, cw, ch) then Exit;
  if (Length(SnipSpins) <> Length(SnipPrm)) or (Length(SnipMemos) <> Length(SnipPrm)) then Exit;
  SetLength(vals, Length(SnipSpins));
  SetLength(texts, Length(SnipSpins));
  differs := Length(oldVals) <> Length(vals);
  for i := 0 to High(vals) do
  begin
    if SnipPrm[i].IsText then
    begin
      vals[i] := 0;
      texts[i] := SnipMemos[i].Text;
      if (i > High(oldTexts)) then differs := differs or (texts[i] <> '')
      else if oldTexts[i] <> texts[i] then differs := True;
      Continue;
    end;
    if SnipPrm[i].IsColor then vals[i] := SnipColorToRgb(SnipColors[i].ButtonColor)
    else vals[i] := SnipSpins[i].Value;
    if (i > High(oldVals)) or (Abs(oldVals[i] - vals[i]) > 1e-9) then differs := True;
  end;
  if not differs then Exit;
  if not SnipExpandT(src, vals, texts, svg, err) then
  begin
    SetStatus('Snippet: ' + err);
    Exit;
  end;
  gname := own.GroupName;
  SetLength(oldIds, 0);
  at := Doc.Shapes.Count;
  for i := 0 to Doc.Shapes.Count - 1 do
    if Doc.Shapes[i].GroupId = gid then
    begin
      SetLength(oldIds, Length(oldIds) + 1);
      oldIds[High(oldIds)] := Doc.Shapes[i].Id;
      at := Min(at, i);
    end;
  // the box of the group in its own frame (turned, if the group has been); its top left corner is what stays where it is
  turn := own.GroupRot;
  if not GroupFrame(oldIds, turn, gcx, gcy, ghw, ghh) then Exit;
  tl := FramePt(0, gcx, gcy, ghw, ghh, turn);
  // what the user did to the size of the group since it was made
  if cw > 1e-6 then fx := fx * (2 * ghw) / cw;
  if ch > 1e-6 then fy := fy * (2 * ghh) / ch;
  fx := Max(0.02, fx);
  fy := Max(0.02, fy);
  Checkpoint;
  for i := 0 to High(oldIds) do
    if Doc.FindShape(oldIds[i]) <> nil then Doc.DeleteShape(Doc.FindShape(oldIds[i]));
  try
    SVGToDoc(svg, Doc, True, 0, 0, newIds);
  except
    on E: Exception do
    begin
      SetStatus('Snippet: ' + E.Message);
      Exit;
    end;
  end;
  for i := 0 to High(newIds) do
    if Doc.FindShape(newIds[i]) <> nil then
    begin
      Doc.FindShape(newIds[i]).GroupId := gid;
      Doc.FindShape(newIds[i]).GroupName := gname;
      Doc.FindShape(newIds[i]).GroupRot := 0;
    end;
  if GroupBox(newIds, g0x, g0y, g1x, g1y) then
  begin
    Doc.StretchShapes(newIds, 0, 0, fx, fy);
    cw := (g1x - g0x) * fx;
    ch := (g1y - g0y) * fy;
    // the group is turned as it was, about the centre of its box
    if turn <> 0 then Doc.RotateShapes(newIds, (g0x + g1x) / 2 * fx, (g0y + g1y) / 2 * fy, turn, sk, dr, cv);
    // the top-left corner of the box stays where it was
    if GroupFrame(newIds, turn, gcx, gcy, ghw, ghh) then
    begin
      p1 := FramePt(0, gcx, gcy, ghw, ghh, turn);
      for i := 0 to High(newIds) do
        if Doc.FindShape(newIds[i]) <> nil then Doc.FindShape(newIds[i]).Translate(tl.x - p1.x, tl.y - p1.y);
    end;
  end;
  if Length(newIds) > 0 then Doc.FindShape(newIds[0]).Snip := SnipEncodeT(src, vals, texts, fx, fy, cw, ch);
  // the new shapes take the place of the old ones in the stacking order
  for k := 0 to High(newIds) do
    Doc.Shapes.Move(Doc.Shapes.IndexOf(Doc.FindShape(newIds[k])), Min(at + k, Doc.Shapes.Count - 1));
  Doc.Solve([]);
  SelClear;
  SetLength(Sel, Length(newIds));
  for i := 0 to High(newIds) do Sel[i] := MakeRef(newIds[i], -1);
  Commit;
  RefreshProps;
  Redraw;
end;

procedure TForm1.SnippetClick(px, py: Double);
var
  sw, sh, x, y, w, h: Double;
  ids: TIntArray;
  i, hi: Integer;
  svg, err, src: string;
  vals: TSnipValues;
  prms: TSnipParams;
  g0x, g0y, g1x, g1y: Double;
  texts: TSnipTexts;
  ti: Integer;
  ttxt: string;
begin
  if (SnipIdx < 0) or (SnipIdx > High(Snippets)) then Exit;
  case SnipStage of
    0:
      begin
        SnipP0 := MakePt(px, py);
        SnipCur := SnipP0;
        SnipStage := 1;
        SetStatus('SVG snippet: click the opposite corner to set width and height.');
      end;
    1:
      begin
        if (Abs(px - SnipP0.x) < 2) or (Abs(py - SnipP0.y) < 2) then
        begin
          SetStatus('SVG snippet: the box is too small, click farther from the first point.');
          Exit;
        end;
        SnipW := px - SnipP0.x;
        w := Abs(SnipW);
        h := Abs(py - SnipP0.y);
        x := Min(SnipP0.x, SnipP0.x + SnipW);
        y := Min(SnipP0.y, py);
        SnipStage := 0;
        src := Snippets[SnipIdx].Svg;
        // a snippet with tables (text parameters, as the graphs): the data are asked for now; left empty, the snippet is made empty
        // and filled in when they are written in its properties
        texts := nil;
        if SnipSplit(src, prms, svg, err) then
        begin
          SetLength(texts, Length(prms));
          for ti := 0 to High(prms) do
            if prms[ti].IsText then
            begin
              ttxt := '';
              if ShowTextDialog('"' + Snippets[SnipIdx].Name + '": paste the CSV data (empty: an empty graph)', ttxt, False,
                StringReplace(prms[ti].Caption, '\n', #10, [rfReplaceAll])) then
                texts[ti] := ttxt;
            end;
        end;
        if not SnipExpandT(src, nil, texts, svg, err) then
        begin
          SetStatus('SVG snippet "' + Snippets[SnipIdx].Name + '": ' + err);
          Redraw;
          Exit;
        end;
        if not SvgSize(svg, sw, sh) then
        begin
          SetStatus('SVG snippet: "' + Snippets[SnipIdx].Name + '" is not a valid SVG.');
          Redraw;
          Exit;
        end;
        // a snippet with the comment "natural size" (the Table) is fitted into the box keeping its proportions, so text never overflows
        if Pos('<!-- natural size -->', src) > 0 then
        begin
          if w / sw < h / sh then h := sh * w / sw else w := sw * h / sh;
        end;
        Checkpoint;
        try
          SVGToDoc(svg, Doc, True, x, y, ids);
        except
          on E: Exception do
          begin
            SetStatus('SVG snippet: ' + E.Message);
            Redraw;
            Exit;
          end;
        end;
        Doc.StretchShapes(ids, x, y, w / sw, h / sh);
        i := Doc.NewGroupId;
        for hi := 0 to High(ids) do
          if Doc.FindShape(ids[hi]) <> nil then
          begin
            Doc.FindShape(ids[hi]).GroupId := i;
            Doc.FindShape(ids[hi]).GroupName := Snippets[SnipIdx].Name;
          end;
        // a snippet with parameters remembers how it was made, to be made again when they change
        if SnipSplit(src, prms, svg, err) and (Length(prms) > 0) and (Length(ids) > 0) and GroupBox(ids, g0x, g0y, g1x, g1y) then
        begin
          vals := SnipDefaults(prms);
          Doc.FindShape(ids[0]).Snip := SnipEncodeT(src, vals, texts, w / sw, h / sh, g1x - g0x, g1y - g0y);
        end;
        Doc.Solve([]);
        SetTool(tlSelect);
        SelClear;
        SetLength(Sel, Length(ids));
        for i := 0 to High(ids) do Sel[i] := MakeRef(ids[i], -1);
        Commit;
        SetStatus('Inserted "' + Snippets[SnipIdx].Name + '".');
        RefreshProps;
      end;
  end;
  Redraw;
end;

// the box the snippet is going to fill, dashed
procedure TForm1.DrawSnippetPreview(cnv: TCanvas);
var
  x2, y2: Double;
  a, b: TPoint;
begin
  if (SnipIdx < 0) or (SnipIdx > High(Snippets)) then Exit;
  x2 := SnipCur.x;
  y2 := SnipCur.y;
  a := ScreenPt(SnipP0);
  b := ScreenPt(MakePt(x2, y2));
  cnv.Pen.Style := psDash;
  cnv.Pen.Width := 1;
  cnv.Pen.Color := TColor($1E78FF);
  cnv.Brush.Style := bsClear;
  cnv.Rectangle(a.x, a.y, b.x, b.y);
  cnv.Pen.Style := psSolid;
end;

type
  TSnipDlg = class
    Owner: TForm1;
    Form: TForm;
    Work: TSnippetArray;
    Lst: TListBox;
    EdName: TEdit;
    Img: TImage;
    Memo: TMemo;
    BtnIcon, BtnDefault, BtnAdd, BtnRemove, BtnOk, BtnCancel: TButton;
    Loading: Boolean;
    procedure FillList(sel: Integer);
    procedure ShowItem;
    procedure ListClick(Sender: TObject);
    procedure NameChange(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure MemoExit(Sender: TObject);
    procedure IconClick(Sender: TObject);
    procedure DefaultClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure RefreshIcon;
  end;

procedure TSnipDlg.FillList(sel: Integer);
var
  i: Integer;
begin
  Lst.Items.Clear;
  for i := 0 to High(Work) do Lst.Items.Add(Work[i].Name);
  if (sel >= 0) and (sel < Lst.Items.Count) then Lst.ItemIndex := sel;
  ShowItem;
end;

procedure TSnipDlg.RefreshIcon;
var
  i: Integer;
  g: TBitmap;
begin
  i := Lst.ItemIndex;
  if i < 0 then
  begin
    Img.Picture.Clear;
    Exit;
  end;
  g := Owner.SnippetGlyph(Work[i], 128);
  try
    Img.Picture.Bitmap.Assign(g);
  finally
    g.Free;
  end;
end;

procedure TSnipDlg.ShowItem;
var
  i: Integer;
  ro: Boolean;
begin
  i := Lst.ItemIndex;
  Loading := True;
  try
    if i < 0 then
    begin
      EdName.Text := '';
      Memo.Text := '';
      ro := True;
    end
    else
    begin
      EdName.Text := Work[i].Name;
      Memo.Text := Work[i].Svg;
      ro := Work[i].BuiltIn;
    end;
  finally
    Loading := False;
  end;
  EdName.ReadOnly := ro;
  Memo.ReadOnly := ro;
  BtnIcon.Enabled := not ro;
  BtnDefault.Enabled := (not ro) and (i >= 0) and (Work[i].Icon <> '');
  BtnRemove.Enabled := not ro;
  RefreshIcon;
end;

procedure TSnipDlg.ListClick(Sender: TObject);
begin
  ShowItem;
end;

procedure TSnipDlg.NameChange(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if Loading or (i < 0) or Work[i].BuiltIn then Exit;
  Work[i].Name := EdName.Text;
  Lst.Items[i] := EdName.Text;
  Lst.ItemIndex := i;
end;

procedure TSnipDlg.MemoChange(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if Loading or (i < 0) or Work[i].BuiltIn then Exit;
  Work[i].Svg := Memo.Text;
end;

procedure TSnipDlg.MemoExit(Sender: TObject);
begin
  RefreshIcon;
end;

// a PNG from a file, kept as a 64 x 64 picture (small enough for the configuration file)
procedure TSnipDlg.IconClick(Sender: TObject);
var
  dlg: TOpenDialog;
  png, out: TPortableNetworkGraphic;
  bmp: TBitmap;
  ss: TStringStream;
  i, w, h: Integer;
  z: Double;
begin
  i := Lst.ItemIndex;
  if (i < 0) or Work[i].BuiltIn then Exit;
  dlg := TOpenDialog.Create(Form);
  dlg.OnShow := @Form1.CenterCommonDlg;
  png := TPortableNetworkGraphic.Create;
  out := TPortableNetworkGraphic.Create;
  bmp := TBitmap.Create;
  try
    dlg.Title := 'Icon of the snippet (PNG)';
    dlg.Filter := 'PNG pictures|*.png|All files|*.*';
    if not dlg.Execute then Exit;
    try
      png.LoadFromFile(dlg.FileName);
    except
      on E: Exception do
      begin
        ShowMessage('Cannot read ' + dlg.FileName + LineEnding + E.Message);
        Exit;
      end;
    end;
    bmp.SetSize(64, 64);
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.FillRect(0, 0, 64, 64);
    z := Min(62 / Max(1, png.Width), 62 / Max(1, png.Height));
    w := Max(1, Round(png.Width * z));
    h := Max(1, Round(png.Height * z));
    bmp.Canvas.StretchDraw(Rect((64 - w) div 2, (64 - h) div 2, (64 - w) div 2 + w, (64 - h) div 2 + h), png);
    out.Assign(bmp);
    ss := TStringStream.Create('');
    try
      out.SaveToStream(ss);
      Work[i].Icon := ss.DataString;
    finally
      ss.Free;
    end;
    BtnDefault.Enabled := True;
    RefreshIcon;
  finally
    bmp.Free;
    out.Free;
    png.Free;
    dlg.Free;
  end;
end;

procedure TSnipDlg.DefaultClick(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if (i < 0) or Work[i].BuiltIn then Exit;
  Work[i].Icon := '';
  BtnDefault.Enabled := False;
  RefreshIcon;
end;

procedure TSnipDlg.AddClick(Sender: TObject);
var
  n: Integer;
begin
  n := Length(Work);
  SetLength(Work, n + 1);
  Work[n].Name := 'New snippet';
  Work[n].Svg := SnipTemplate;
  Work[n].Icon := '';
  Work[n].BuiltIn := False;
  FillList(n);
  EdName.SetFocus;
  EdName.SelectAll;
end;

procedure TSnipDlg.RemoveClick(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if (i < 0) or Work[i].BuiltIn then Exit;
  Delete(Work, i, 1);
  if i > High(Work) then i := High(Work);
  FillList(i);
end;

procedure TSnipDlg.OkClick(Sender: TObject);
var
  i: Integer;
  w, h: Double;
  svgT, errT: string;
begin
  for i := 0 to High(Work) do
    if not Work[i].BuiltIn then
    begin
      if Trim(Work[i].Name) = '' then Work[i].Name := 'Snippet ' + IntToStr(i + 1);
      if not SnipExpand(Work[i].Svg, nil, svgT, errT) then
      begin
        ShowMessage('The parameters or the {...} expressions of "' + Work[i].Name + '" are wrong: ' + errT);
        Lst.ItemIndex := i;
        ShowItem;
        Exit;
      end;
      if not SvgSize(svgT, w, h) then
      begin
        ShowMessage('The SVG of "' + Work[i].Name + '" cannot be read: it needs an <svg> element with a width and a height (or a viewBox).');
        Lst.ItemIndex := i;
        ShowItem;
        Exit;
      end;
    end;
  Form.ModalResult := mrOk;
end;

procedure TForm1.MenuSvgLibrary(Sender: TObject);
var
  d: TSnipDlg;
  f: TForm;
  pr, pb, pt, pbr: TPanel;
  l: TLabel;
begin
  d := TSnipDlg.Create;
  f := TForm.CreateNew(Application);
  try
    d.Owner := Self;
    d.Form := f;
    d.Work := Copy(Snippets);
    f.Caption := 'SVG Library';
    f.Position := poMainFormCenter;
    f.ClientWidth := 760;
    f.ClientHeight := 540;
    pb := TPanel.Create(f);
    pb.Parent := f;
    pb.Align := alBottom;
    pb.Height := 40;
    pb.BevelOuter := bvNone;
    d.Lst := TListBox.Create(f);
    d.Lst.Parent := f;
    d.Lst.Align := alLeft;
    d.Lst.Width := 218;
    d.Lst.OnClick := @d.ListClick;
    pr := TPanel.Create(f);
    pr.Parent := f;
    pr.Align := alClient;
    pr.BevelOuter := bvNone;
    pt := TPanel.Create(f);
    pt.Parent := pr;
    pt.Align := alTop;
    pt.Height := 272;
    pt.BevelOuter := bvNone;
    l := TLabel.Create(f);
    l.Parent := pt;
    l.Caption := 'Name';
    l.SetBounds(20, 14, 60, 20);
    d.EdName := TEdit.Create(f);
    d.EdName.Parent := pt;
    d.EdName.SetBounds(80, 10, 200, 26);
    d.EdName.OnChange := @d.NameChange;
    l := TLabel.Create(f);
    l.Parent := pt;
    l.Caption := 'Icon';
    l.SetBounds(70, 90, 60, 20);
    d.Img := TImage.Create(f);
    d.Img.Parent := pt;
    d.Img.SetBounds(150, 44, 132, 132);
    d.Img.Stretch := False;
    d.Img.Center := True;
    d.BtnIcon := TButton.Create(f);
    d.BtnIcon.Parent := pt;
    d.BtnIcon.Caption := 'Choose PNG...';
    d.BtnIcon.SetBounds(310, 80, 140, 28);
    d.BtnIcon.OnClick := @d.IconClick;
    d.BtnDefault := TButton.Create(f);
    d.BtnDefault.Parent := pt;
    d.BtnDefault.Caption := 'Draw from the SVG';
    d.BtnDefault.SetBounds(310, 114, 140, 28);
    d.BtnDefault.OnClick := @d.DefaultClick;
    l := TLabel.Create(f);
    l.Parent := pt;
    l.WordWrap := True;
    l.AutoSize := False;
    l.SetBounds(12, 184, 520, 84);
    l.Caption := 'Parameters: lines "@param Name = value [min, max, step] "Caption"" before the <svg>. In the SVG: {expression}, ' +
      '{for i = 0 to N} ... {end}, {if condition} ... {else} ... {end}. A colour parameter is written "@param Name = #rrggbb". ' +
      'The object made from it shows a slider (or a colour button) for every parameter. ' +
      'Tables: "@paramtext Data "Caption"" gives a box where a CSV is pasted; rows(Data), cols(Data), hdr(Data), num(Data, row, col), ' +
      'isnum, sum, csum, vmin, vmax, nicestep, {cell(Data, row, col)}, {hsl(h, s, l)} and {let name = value} read it.';
    d.Memo := TMemo.Create(f);
    d.Memo.Parent := pr;
    d.Memo.Align := alClient;
    d.Memo.ScrollBars := ssBoth;
    d.Memo.WordWrap := False;
    d.Memo.Font.Name := 'DejaVu Sans Mono';
    d.Memo.OnChange := @d.MemoChange;
    d.Memo.OnExit := @d.MemoExit;
    d.BtnAdd := TButton.Create(f);
    d.BtnAdd.Parent := pb;
    d.BtnAdd.Caption := 'Add';
    d.BtnAdd.SetBounds(8, 6, 96, 28);
    d.BtnAdd.OnClick := @d.AddClick;
    d.BtnRemove := TButton.Create(f);
    d.BtnRemove.Parent := pb;
    d.BtnRemove.Caption := 'Remove';
    d.BtnRemove.SetBounds(112, 6, 96, 28);
    d.BtnRemove.OnClick := @d.RemoveClick;
    pbr := TPanel.Create(f);
    pbr.Parent := pb;
    pbr.Align := alRight;
    pbr.Width := 232;
    pbr.BevelOuter := bvNone;
    d.BtnCancel := TButton.Create(f);
    d.BtnCancel.Parent := pbr;
    d.BtnCancel.Caption := 'Cancel';
    d.BtnCancel.SetBounds(120, 6, 100, 28);
    d.BtnCancel.ModalResult := mrCancel;
    d.BtnOk := TButton.Create(f);
    d.BtnOk.Parent := pbr;
    d.BtnOk.Caption := 'OK';
    d.BtnOk.SetBounds(12, 6, 100, 28);
    d.BtnOk.Default := True;
    d.BtnOk.OnClick := @d.OkClick;
    d.FillList(0);
    if f.ShowModal = mrOk then
    begin
      Snippets := Copy(d.Work);
      SaveConfig;
      RebuildSnipButtons;
      SetStatus('SVG library saved: ' + IntToStr(Length(Snippets)) + ' snippets.');
    end;
  finally
    f.Free;
    d.Free;
  end;
end;

{ ================= filters ================= }

const
  FilterTemplate =
    '@param Amount = 100 [0,100,1] "Amount"' + #10 +
    ''' the colour of every pixel: R, G, B (0..255) in; Ro, Go, Bo out.  X, Y: the position' + #10 +
    't = Amount / 100' + #10 +
    'Ro = MIX(R, 255 - R, t)' + #10 +
    'Go = MIX(G, 255 - G, t)' + #10 +
    'Bo = MIX(B, 255 - B, t)' + #10;

// the compiled script of a text (nil, and the error, when it is wrong)
function TForm1.ScriptFor(const src: string; out err: string): TFltScript;
var
  i: Integer;
  sc: TFltScript;
begin
  err := '';
  if FltScripts = nil then
  begin
    FltScripts := TStringList.Create;
    FltScripts.CaseSensitive := True;
  end;
  i := FltScripts.IndexOf(src);
  if i >= 0 then
  begin
    Result := TFltScript(FltScripts.Objects[i]);
    if Result = nil then err := 'the script is wrong';
    Exit;
  end;
  if FltScripts.Count > 40 then
  begin
    for i := 0 to FltScripts.Count - 1 do FltScripts.Objects[i].Free;
    FltScripts.Clear;
  end;
  sc := TFltScript.Create;
  if sc.Compile(src, err) then
  begin
    FltScripts.AddObject(src, sc);
    Result := sc;
  end
  else
  begin
    sc.Free;
    Result := nil;
  end;
end;

procedure TForm1.InitFilters;
var
  ini: TIniFile;
  n, i: Integer;
  fd: TFltDef;
begin
  SetLength(FltLib, 0);
  for i := 0 to FltBuiltinCount - 1 do
  begin
    SetLength(FltLib, Length(FltLib) + 1);
    FltLib[High(FltLib)].Name := FltBuiltinName(i);
    FltLib[High(FltLib)].Script := FltBuiltinScript(i);
    FltLib[High(FltLib)].BuiltIn := True;
  end;
  if FileExists(ConfigPath) then
  begin
    ini := TIniFile.Create(ConfigPath);
    try
      n := ini.ReadInteger('Filters', 'Count', 0);
      for i := 1 to n do
      begin
        fd.Name := DecodeStringBase64(ini.ReadString('Filters', 'Name' + IntToStr(i), ''));
        fd.Script := DecodeStringBase64(ini.ReadString('Filters', 'Script' + IntToStr(i), ''));
        fd.BuiltIn := False;
        if (fd.Name = '') or (fd.Script = '') then Continue;
        SetLength(FltLib, Length(FltLib) + 1);
        FltLib[High(FltLib)] := fd;
      end;
    finally
      ini.Free;
    end;
  end;
  FltPanel := TPanel.Create(Self);
  FltPanel.Parent := Panel1;
  FltPanel.Align := alLeft;
  FltPanel.Left := ColorPanel.Left;
  FltPanel.Width := 200;
  FltPanel.Visible := False;
  with TLabel.Create(Self) do
  begin
    Parent := FltPanel;
    Caption := 'Filters';
    SetBounds(8, 8, 120, 16);
  end;
  FltBox := TScrollBox.Create(Self);
  FltBox.Parent := FltPanel;
  FltBox.Align := alClient;
  FltBox.BorderSpacing.Top := 26;
  FltBox.OnResize := @FltBoxResize;
  FltBox.BorderStyle := bsNone;
  FltBox.HorzScrollBar.Visible := False;
  FltBox.VertScrollBar.Tracking := True;
  FltBox.AutoScroll := True;
  RebuildFltButtons;
end;

procedure TForm1.SaveFilters(ini: TIniFile);
var
  i, n: Integer;
begin
  ini.EraseSection('Filters');
  n := 0;
  for i := 0 to High(FltLib) do
    if not FltLib[i].BuiltIn then
    begin
      Inc(n);
      ini.WriteString('Filters', 'Name' + IntToStr(n), EncodeStringBase64(FltLib[i].Name));
      ini.WriteString('Filters', 'Script' + IntToStr(n), EncodeStringBase64(FltLib[i].Script));
    end;
  ini.WriteInteger('Filters', 'Count', n);
end;

// a small colour card through the filter, with the values of the script by default
function TForm1.FilterGlyph(const script: string; size: Integer): TBitmap;
var
  sc: TFltScript;
  err: string;
  img: TFltImage;
  x, y, k: Integer;
  r, g, b, fa: Double;
  li: TLazIntfImage;
begin
  Result := TBitmap.Create;
  Result.SetSize(size, size);
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(0, 0, size, size);
  sc := ScriptFor(script, err);
  img.W := size;
  img.H := size;
  SetLength(img.R, size * size);
  SetLength(img.G, size * size);
  SetLength(img.B, size * size);
  for y := 0 to size - 1 do
    for x := 0 to size - 1 do
    begin
      k := y * size + x;
      HslToRgb(x / size * 330, 90, 85 - 65 * y / size, r, g, b);
      if (Abs(x - y * 0.8 - size * 0.1) < size / 40 + 0.6) or (Abs(x - (size - 1 - y) * 0.5 - size * 0.45) < 0.8) then
      begin
        r := 255; g := 255; b := 255;
      end;
      img.R[k] := Round(r);
      img.G[k] := Round(g);
      img.B[k] := Round(b);
    end;
  if sc <> nil then
    if not sc.Run(img, sc.Defaults, size / 64, Rect(0, 0, size, size), err) then sc := nil;
  li := Result.CreateIntfImage;
  try
    for y := 0 to size - 1 do
      for x := 0 to size - 1 do
      begin
        k := y * size + x;
        if sc = nil then li.Colors[x, y] := TColorToFPColor(RGBToColor(200, 60, 60))
        else
        begin
          fa := img.A[k] / 255;
          // over the white of the icon
          li.Colors[x, y] := TColorToFPColor(RGBToColor(Round(255 + (img.R[k] - 255) * fa),
            Round(255 + (img.G[k] - 255) * fa), Round(255 + (img.B[k] - 255) * fa)));
        end;
      end;
    Result.LoadFromIntfImage(li);
  finally
    li.Free;
  end;
end;

// the menu Filters > Apply to the selected raster: one item for each filter of the library
procedure TForm1.RebuildFltApplyMenu;
var
  i: Integer;
  mi: TMenuItem;
begin
  if miFltApply = nil then Exit;
  miFltApply.Clear;
  for i := 0 to High(FltLib) do
  begin
    mi := TMenuItem.Create(miFltApply);
    mi.Caption := StringReplace(FltLib[i].Name, '&', '&&', [rfReplaceAll]);
    mi.Tag := i;
    mi.OnClick := @FltApplyClick;
    miFltApply.Add(mi);
  end;
end;

// the rasters that a filter can be applied to: the selected ones, or the raster of the selection of pixels that is selected (the
// filter then works only inside the selection)
function TForm1.FilterTargets(out useSel: Boolean): TShapeArray;
var
  ts: TShapeArray;
  i: Integer;
  img: TShape;
begin
  SetLength(Result, 0);
  useSel := False;
  ts := SelShapes;
  if Length(ts) = 0 then Exit;
  if AllSelections(ts) then
  begin
    img := Doc.FindShape(ts[0].SelTarget);
    if (img <> nil) and (img.Kind = skImage) and Doc.ShapeVisible(img) and not Doc.ShapeLocked(img) and (img.GroupId = 0) then
    begin
      SetLength(Result, 1);
      Result[0] := img;
      useSel := True;
    end;
    Exit;
  end;
  for i := 0 to High(ts) do
    if (ts[i].Kind = skImage) and (ts[i].SelTarget = 0) and not Doc.ShapeLocked(ts[i]) and (ts[i].GroupId = 0) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := ts[i];
    end;
end;

// the filter (a script) on the pixels of a raster: all of them, or only those inside its selections
function TForm1.ApplyFilterToRaster(img: TShape; const script: string; const vals: TFltValues; useSel: Boolean; feather, featherIn: Double): Boolean;
var
  raw: TGraphic;
  tb: TBitmap;
  bmp: TBGRABitmap;
  scr: TFltScript;
  fimg: TFltImage;
  err, data: string;
  mask: TBytes;
  w, h, x, y, k: Integer;
  px: PBGRAPixel;
  ms: TMemoryStream;
  fw: TSingleArray;
  inside: TBoolArray;
  fe: Double;
  oa, na: Integer;
  ra: Double;
begin
  Result := False;
  raw := RawImage(img);
  if raw = nil then Exit;
  scr := ScriptFor(script, err);
  if scr = nil then
  begin
    SetStatus('Filter: ' + err);
    Exit;
  end;
  tb := TBitmap.Create;
  try
    tb.Assign(raw);
    bmp := TBGRABitmap.Create(tb);
  finally
    tb.Free;
  end;
  try
    w := bmp.Width;
    h := bmp.Height;
    if (w <= 0) or (h <= 0) then Exit;
    SetLength(mask, 0);
    if useSel then mask := SelMask(img, SelListOf(img), w, h);
    fimg.W := w;
    fimg.H := h;
    SetLength(fimg.R, w * h);
    SetLength(fimg.G, w * h);
    SetLength(fimg.B, w * h);
    SetLength(fimg.A, w * h);
    for y := 0 to h - 1 do
    begin
      px := bmp.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        k := y * w + x;
        fimg.R[k] := px^.red;
        fimg.G[k] := px^.green;
        fimg.B[k] := px^.blue;
        fimg.A[k] := px^.alpha;
        Inc(px);
      end;
    end;
    // the filter sees the raster as a page of its own: its pixels are its units
    if not scr.RunAt(fimg, vals, 1, Rect(0, 0, w, h), 0, 0, w, h, err) then
    begin
      SetStatus('Filter: ' + err);
      Exit;
    end;
    // the effect fades towards the borders of its domain (the raster, or the selection)
    fw := nil;
    if (feather > 0) or (featherIn > 0) then
    begin
      inside := nil;
      if Length(mask) > 0 then
      begin
        SetLength(inside, w * h);
        for k := 0 to w * h - 1 do inside[k] := mask[k] <> 0;
      end;
      fw := FeatherMap(w, h, inside, feather, featherIn, 0, 0, w, h);
    end;
    for y := 0 to h - 1 do
    begin
      px := bmp.ScanLine[y];
      for x := 0 to w - 1 do
      begin
        k := y * w + x;
        if (Length(mask) = 0) or (mask[k] <> 0) then
        begin
          fe := 1;
          if Length(fw) > 0 then fe := fw[k];
          if fe >= 1 then
          begin
            px^.red := fimg.R[k];
            px^.green := fimg.G[k];
            px^.blue := fimg.B[k];
            px^.alpha := fimg.A[k];
          end
          else if fe > 0 then
          begin
            oa := px^.alpha;
            na := fimg.A[k];
            ra := oa + (na - oa) * fe;
            if ra < 0.5 then
              px^ := BGRAPixelTransparent
            else
            begin
              px^.red := Min(255, Round((px^.red * oa + (fimg.R[k] * na - px^.red * oa) * fe) / ra));
              px^.green := Min(255, Round((px^.green * oa + (fimg.G[k] * na - px^.green * oa) * fe) / ra));
              px^.blue := Min(255, Round((px^.blue * oa + (fimg.B[k] * na - px^.blue * oa) * fe) / ra));
              px^.alpha := Round(ra);
            end;
          end;
        end;
        Inc(px);
      end;
    end;
    bmp.InvalidateBitmap;
    ms := TMemoryStream.Create;
    try
      bmp.SaveToStreamAsPng(ms);
      SetString(data, PAnsiChar(ms.Memory), ms.Size);
    finally
      ms.Free;
    end;
    img.ImageData := EncodeStringBase64(data);
    img.KeyOn := False;
    img.KeyOrig := '';
    FlushImageCaches(img);
    Result := True;
  finally
    bmp.Free;
  end;
end;

// the filter with the values of the dialog, on the originals of the rasters
procedure TForm1.FltPreviewRaster(Sender: TObject);
var
  k: Integer;
  vals: TFltValues;
begin
  if FltPrevLayer = nil then Exit;
  vals := nil;
  SetLength(vals, Length(FltPrevLayer.FVals));
  for k := 0 to High(vals) do vals[k] := FltPrevLayer.FVals[k];
  Screen.Cursor := crHourGlass;
  try
    for k := 0 to High(FltPrevTargets) do
    begin
      FltPrevTargets[k].ImageData := FltPrevData[k];
      FltPrevTargets[k].KeyOrig := FltPrevKey[k];
      FltPrevTargets[k].KeyOn := FltPrevKeyOn[k];
      FlushImageCaches(FltPrevTargets[k]);
      ApplyFilterToRaster(FltPrevTargets[k], FltPrevScript, vals, FltPrevSel, FltPrevLayer.FFeather, FltPrevLayer.FFeatherIn);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TForm1.FltApplyClick(Sender: TObject);
var
  i, k, n: Integer;
  ts: TShapeArray;
  useSel: Boolean;
  sc: TFltScript;
  err: string;
  tmp: TLayer;
  vals: TFltValues;
  ok: Boolean;
  feather, featherIn: Double;
begin
  i := TMenuItem(Sender).Tag;
  ts := FilterTargets(useSel);
  if Length(ts) = 0 then
  begin
    SetStatus('Select a raster first (or a selection of pixels on it).');
    Exit;
  end;
  if (i < 0) or (i > High(FltLib)) then Exit;
  sc := ScriptFor(FltLib[i].Script, err);
  if sc = nil then
  begin
    SetStatus('Filter "' + FltLib[i].Name + '": ' + err);
    Exit;
  end;
  tmp := TLayer.Create;
  try
    tmp.FName := FltLib[i].Name;
    tmp.FScript := FltLib[i].Script;
    SetLength(tmp.FVals, Length(sc.Params));
    for k := 0 to High(tmp.FVals) do tmp.FVals[k] := sc.Params[k].Def;
    // the raster shows the filter while the sliders move: the originals are put back at the end
    FltPrevLayer := tmp;
    FltPrevScript := FltLib[i].Script;
    FltPrevSel := useSel;
    FltPrevTargets := ts;
    SetLength(FltPrevData, Length(ts));
    SetLength(FltPrevKey, Length(ts));
    SetLength(FltPrevKeyOn, Length(ts));
    for k := 0 to High(ts) do
    begin
      FltPrevData[k] := ts[k].ImageData;
      FltPrevKey[k] := ts[k].KeyOrig;
      FltPrevKeyOn[k] := ts[k].KeyOn;
    end;
    try
      ok := EditFilterValues(tmp, @FltPreviewRaster);
    finally
      for k := 0 to High(ts) do
      begin
        ts[k].ImageData := FltPrevData[k];
        ts[k].KeyOrig := FltPrevKey[k];
        ts[k].KeyOn := FltPrevKeyOn[k];
        FlushImageCaches(ts[k]);
      end;
      FltPrevLayer := nil;
      Redraw;
    end;
    if not ok then Exit;
    vals := nil;
    SetLength(vals, Length(tmp.FVals));
    for k := 0 to High(vals) do vals[k] := tmp.FVals[k];
    feather := tmp.FFeather;
    featherIn := tmp.FFeatherIn;
  finally
    tmp.Free;
  end;
  Checkpoint;
  Screen.Cursor := crHourGlass;
  n := 0;
  try
    for k := 0 to High(ts) do
      if ApplyFilterToRaster(ts[k], FltLib[i].Script, vals, useSel, feather, featherIn) then Inc(n);
  finally
    Screen.Cursor := crDefault;
  end;
  Commit;
  RefreshProps;
  Redraw;
  if n > 0 then
  begin
    if useSel then SetStatus('Filter "' + FltLib[i].Name + '" applied inside the selection.')
    else SetStatus('Filter "' + FltLib[i].Name + '" applied to ' + IntToStr(n) + ' raster(s).');
  end;
end;

procedure TForm1.RebuildFltButtons;
var
  i: Integer;
  b: TSpeedButton;
  g: TBitmap;
begin
  for i := 0 to High(FltButtons) do FltButtons[i].Free;
  SetLength(FltButtons, Length(FltLib));
  for i := 0 to High(FltLib) do
  begin
    b := TSpeedButton.Create(Self);
    b.Parent := FltBox;
    b.SetBounds(0, 0, 38, 31);
    b.Tag := i;
    b.Hint := FltLib[i].Name;
    b.ShowHint := True;
    b.OnClick := @FltButtonClick;
    g := FilterGlyph(FltLib[i].Script, 26);
    try
      b.Glyph.Assign(g);
    finally
      g.Free;
    end;
    FltButtons[i] := b;
  end;
  ArrangeFltButtons;
  RebuildFltApplyMenu;
end;

procedure TForm1.ArrangeFltButtons;
var
  i, cols: Integer;
begin
  cols := Max(1, (FltBox.ClientWidth - 4) div 40);
  for i := 0 to High(FltButtons) do
    FltButtons[i].SetBounds(4 + (i mod cols) * 40, 2 + (i div cols) * 33, 38, 31);
end;

procedure TForm1.FltBoxResize(Sender: TObject);
begin
  ArrangeFltButtons;
end;

type
  TFltParamDlg = class
    Owner: TForm1;
    Layer: TLayer;
    Prm: TSnipParams;
    Form: TForm;
    Spins: array of TFloatSpinEdit;
    Tracks: array of TTrackBar;
    Cols: array of TColorButton;
    Tm: TTimer;
    Busy: Boolean;
    OnPreview: TNotifyEvent;
    NP: Integer;        // the parameters of the script; after them comes the feather of the filter
    function Ticks(i: Integer): Integer;
    procedure Collect;
    procedure Push(Sender: TObject);
    procedure TrackChange(Sender: TObject);
    procedure SpinChange(Sender: TObject);
    procedure ColChange(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure SetControl(i: Integer; v: Double);
  end;

function TFltParamDlg.Ticks(i: Integer): Integer;
begin
  Result := Max(1, Min(1000, Round((Prm[i].Max - Prm[i].Min) / Prm[i].Step)));
end;

// the values of the controls go to the layer
procedure TFltParamDlg.Collect;
var
  i: Integer;
begin
  SetLength(Layer.FVals, NP);
  for i := 0 to High(Prm) do
    if i = NP then Layer.FFeather := Spins[i].Value
    else if i = NP + 1 then Layer.FFeatherIn := Spins[i].Value
    else if Prm[i].IsColor then Layer.FVals[i] := SnipColorToRgb(Cols[i].ButtonColor)
    else Layer.FVals[i] := Spins[i].Value;
end;

procedure TFltParamDlg.Push(Sender: TObject);
begin
  Tm.Enabled := False;
  Collect;
  if Assigned(OnPreview) then OnPreview(Self);
  Owner.Redraw;
end;

procedure TFltParamDlg.SetControl(i: Integer; v: Double);
begin
  Busy := True;
  try
    if Prm[i].IsColor then Cols[i].ButtonColor := SnipRgbToColor(Round(v))
    else
    begin
      Spins[i].Value := v;
      Tracks[i].Position := Round((v - Prm[i].Min) / (Prm[i].Max - Prm[i].Min) * Tracks[i].Max);
    end;
  finally
    Busy := False;
  end;
end;

// the drawing follows a moment after the last change: some filters take a while
procedure TFltParamDlg.TrackChange(Sender: TObject);
var
  i: Integer;
  v: Double;
begin
  if Busy then Exit;
  i := TComponent(Sender).Tag;
  v := Prm[i].Min + Tracks[i].Position / Tracks[i].Max * (Prm[i].Max - Prm[i].Min);
  v := Prm[i].Min + Round((v - Prm[i].Min) / Prm[i].Step) * Prm[i].Step;
  Busy := True;
  try
    Spins[i].Value := v;
  finally
    Busy := False;
  end;
  Tm.Enabled := False;
  Tm.Enabled := True;
end;

procedure TFltParamDlg.SpinChange(Sender: TObject);
var
  i: Integer;
begin
  if Busy then Exit;
  i := TComponent(Sender).Tag;
  Busy := True;
  try
    Tracks[i].Position := Round((Spins[i].Value - Prm[i].Min) / (Prm[i].Max - Prm[i].Min) * Tracks[i].Max);
  finally
    Busy := False;
  end;
  Tm.Enabled := False;
  Tm.Enabled := True;
end;

procedure TFltParamDlg.ColChange(Sender: TObject);
begin
  if Busy then Exit;
  Tm.Enabled := False;
  Tm.Enabled := True;
end;

procedure TFltParamDlg.ResetClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to High(Prm) do SetControl(i, Prm[i].Def);
  Push(nil);
end;

// the values of the parameters of the filter of the layer, tried on the drawing while they change; false: cancelled
// (the values are what they were)
function TForm1.EditFilterValues(l: TLayer; pv: TNotifyEvent): Boolean;
var
  sc: TFltScript;
  err: string;
  d: TFltParamDlg;
  f: TForm;
  i, y, trkW: Integer;
  lb: TLabel;
  b: TButton;
  old: array of Double;
  oldFeather, oldFeatherIn: Double;
  prm: TSnipParams;
begin
  Result := False;
  sc := ScriptFor(l.FScript, err);
  if sc = nil then Exit;
  old := Copy(l.FVals);
  oldFeather := l.FFeather;
  oldFeatherIn := l.FFeatherIn;
  SetLength(l.FVals, Length(sc.Params));
  for i := Length(old) to High(l.FVals) do l.FVals[i] := sc.Params[i].Def;
  d := TFltParamDlg.Create;
  f := TForm.CreateNew(Self);
  try
    d.Owner := Self;
    d.OnPreview := pv;
    d.Layer := l;
    // the last slider is the same for every filter: how many pixels the effect takes to fade towards the borders of its domain
    prm := Copy(sc.Params);
    SetLength(prm, Length(prm) + 2);
    with prm[High(prm) - 1] do
    begin
      Name := 'feather';
      Caption := 'Fade at the outer borders (px)';
      Def := 0;
      Min := 0;
      Max := 200;
      Step := 1;
      IsColor := False;
      IsText := False;
    end;
    with prm[High(prm)] do
    begin
      Name := 'featherin';
      Caption := 'Fade at the inner borders (holes) (px)';
      Def := 0;
      Min := 0;
      Max := 200;
      Step := 1;
      IsColor := False;
      IsText := False;
    end;
    d.NP := Length(sc.Params);
    d.Prm := prm;
    d.Form := f;
    SetLength(d.Spins, Length(d.Prm));
    SetLength(d.Tracks, Length(d.Prm));
    SetLength(d.Cols, Length(d.Prm));
    f.Caption := l.FName;
    f.Position := poOwnerFormCenter;
    f.BorderStyle := bsDialog;
    f.ClientWidth := 620;
    f.ClientHeight := 62 + Length(d.Prm) * 46;
    trkW := 620 - 24 - 250 - 100;
    d.Tm := TTimer.Create(f);
    d.Tm.Enabled := False;
    d.Tm.Interval := 250;
    d.Tm.OnTimer := @d.Push;
    for i := 0 to High(d.Prm) do
    begin
      y := 12 + i * 46;
      lb := TLabel.Create(f);
      lb.Parent := f;
      lb.Caption := d.Prm[i].Caption;
      lb.AutoSize := False;
      lb.SetBounds(12, y + 4, 240, 18);
      if d.Prm[i].IsColor then
      begin
        d.Cols[i] := TColorButton.Create(f);
        with d.Cols[i] do
        begin
          Parent := f;
          Tag := i;
          SetBounds(160, y, 92, 26);
          ButtonColor := SnipRgbToColor(Round(l.FVals[i]));
          OnColorChanged := @d.ColChange;
        end;
        Continue;
      end;
      d.Tracks[i] := TTrackBar.Create(f);
      with d.Tracks[i] do
      begin
        Parent := f;
        Tag := i;
        SetBounds(254, y, trkW, 30);
        TickStyle := tsNone;
        Min := 0;
        Max := d.Ticks(i);
        OnChange := @d.TrackChange;
      end;
      d.Spins[i] := TFloatSpinEdit.Create(f);
      with d.Spins[i] do
      begin
        Parent := f;
        Tag := i;
        SetBounds(254 + trkW + 8, y + 2, 92, 26);
        MinValue := d.Prm[i].Min;
        MaxValue := d.Prm[i].Max;
        Increment := d.Prm[i].Step;
        DecimalPlaces := StepDigits(d.Prm[i].Step);
        OnChange := @d.SpinChange;
      end;
      if i = d.NP then d.SetControl(i, l.FFeather)
      else if i = d.NP + 1 then d.SetControl(i, l.FFeatherIn)
      else d.SetControl(i, l.FVals[i]);
    end;
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Reset';
    b.SetBounds(12, f.ClientHeight - 40, 80, 28);
    b.OnClick := @d.ResetClick;
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'OK';
    b.ModalResult := mrOk;
    b.Default := True;
    b.SetBounds(f.ClientWidth - 200, f.ClientHeight - 40, 90, 28);
    b := TButton.Create(f);
    b.Parent := f;
    b.Caption := 'Cancel';
    b.ModalResult := mrCancel;
    b.Cancel := True;
    b.SetBounds(f.ClientWidth - 100, f.ClientHeight - 40, 90, 28);
    if f.ShowModal = mrOk then
    begin
      d.Collect;
      Result := True;
    end
    else
    begin
      l.FVals := old;
      l.FFeather := oldFeather;
      l.FFeatherIn := oldFeatherIn;
    end;
  finally
    f.Free;
    d.Free;
  end;
  Redraw;
end;

// a filter of the panel for the active filter layer
procedure TForm1.FltButtonClick(Sender: TObject);
var
  l: TLayer;
  i, k: Integer;
  oldName, oldScript: string;
  oldVals: array of Double;
  sc: TFltScript;
  err: string;
begin
  l := ActiveLayerObj;
  i := TSpeedButton(Sender).Tag;
  if (l = nil) or not l.IsFilter or (i < 0) or (i > High(FltLib)) then Exit;
  sc := ScriptFor(FltLib[i].Script, err);
  if sc = nil then
  begin
    SetStatus('Filter "' + FltLib[i].Name + '": ' + err);
    Exit;
  end;
  Checkpoint;
  oldName := l.FName;
  oldScript := l.FScript;
  oldVals := Copy(l.FVals);
  l.FName := FltLib[i].Name;
  l.FScript := FltLib[i].Script;
  SetLength(l.FVals, Length(sc.Params));
  for k := 0 to High(l.FVals) do l.FVals[k] := sc.Params[k].Def;
  Redraw;
  if (Length(sc.Params) > 0) and not EditFilterValues(l) then
  begin
    l.FName := oldName;
    l.FScript := oldScript;
    l.FVals := oldVals;
    Redraw;
    Exit;
  end;
  Commit;
  RefreshLayers;
  Redraw;
  SetStatus('Filter "' + l.FName + '" on the layer "' + l.Name + '".');
end;

procedure TForm1.MenuFilterParams(Sender: TObject);
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  if (l = nil) or not l.IsFilter or (l.FScript = '') then
  begin
    SetStatus('Choose a filter layer with a filter first.');
    Exit;
  end;
  Checkpoint;
  if EditFilterValues(l) then
  begin
    Commit;
    Redraw;
  end;
end;

procedure TForm1.MenuFilterClear(Sender: TObject);
var
  l: TLayer;
begin
  l := ActiveLayerObj;
  if (l = nil) or not l.IsFilter or (l.FScript = '') then Exit;
  Checkpoint;
  l.FScript := '';
  l.FName := '';
  SetLength(l.FVals, 0);
  Commit;
  RefreshLayers;
  Redraw;
  SetStatus('The layer "' + l.Name + '" has no filter now.');
end;

type
  TFltLibDlg = class
    Owner: TForm1;
    Form: TForm;
    Work: TFltDefArray;
    Lst: TListBox;
    EdName: TEdit;
    Img: TImage;
    Memo: TMemo;
    Info: TLabel;
    BtnAdd, BtnRemove, BtnTest, BtnOk, BtnCancel: TButton;
    Loading: Boolean;
    procedure FillList(sel: Integer);
    procedure ShowItem;
    procedure ListClick(Sender: TObject);
    procedure NameChange(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure TestClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure RefreshIcon;
  end;

procedure TFltLibDlg.FillList(sel: Integer);
var
  i: Integer;
begin
  Lst.Items.Clear;
  for i := 0 to High(Work) do Lst.Items.Add(Work[i].Name);
  if (sel >= 0) and (sel < Lst.Items.Count) then Lst.ItemIndex := sel;
  ShowItem;
end;

procedure TFltLibDlg.RefreshIcon;
var
  i: Integer;
  g: TBitmap;
begin
  i := Lst.ItemIndex;
  if i < 0 then
  begin
    Img.Picture.Clear;
    Exit;
  end;
  g := Owner.FilterGlyph(Work[i].Script, 128);
  try
    Img.Picture.Bitmap.Assign(g);
  finally
    g.Free;
  end;
end;

procedure TFltLibDlg.ShowItem;
var
  i: Integer;
  ro: Boolean;
begin
  i := Lst.ItemIndex;
  Loading := True;
  try
    if i < 0 then
    begin
      EdName.Text := '';
      Memo.Text := '';
      ro := True;
    end
    else
    begin
      EdName.Text := Work[i].Name;
      Memo.Text := Work[i].Script;
      ro := Work[i].BuiltIn;
    end;
  finally
    Loading := False;
  end;
  EdName.ReadOnly := ro;
  Memo.ReadOnly := ro;
  BtnRemove.Enabled := not ro;
  Info.Caption := '';
  RefreshIcon;
end;

procedure TFltLibDlg.ListClick(Sender: TObject);
begin
  ShowItem;
end;

procedure TFltLibDlg.NameChange(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if Loading or (i < 0) or Work[i].BuiltIn then Exit;
  Work[i].Name := EdName.Text;
  Lst.Items[i] := EdName.Text;
  Lst.ItemIndex := i;
end;

procedure TFltLibDlg.MemoChange(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if Loading or (i < 0) or Work[i].BuiltIn then Exit;
  Work[i].Script := Memo.Text;
end;

// compiles the script and shows the error, or the filter at work on the colour card
procedure TFltLibDlg.TestClick(Sender: TObject);
var
  i: Integer;
  sc: TFltScript;
  err: string;
begin
  i := Lst.ItemIndex;
  if i < 0 then Exit;
  sc := TFltScript.Create;
  try
    if sc.Compile(Work[i].Script, err) then Info.Caption := 'The script is good (' + IntToStr(Length(sc.Params)) + ' parameters).'
    else Info.Caption := 'Error, ' + err;
  finally
    sc.Free;
  end;
  RefreshIcon;
end;

procedure TFltLibDlg.AddClick(Sender: TObject);
var
  n: Integer;
begin
  n := Length(Work);
  SetLength(Work, n + 1);
  Work[n].Name := 'New filter';
  Work[n].Script := FilterTemplate;
  Work[n].BuiltIn := False;
  FillList(n);
  EdName.SetFocus;
  EdName.SelectAll;
end;

procedure TFltLibDlg.RemoveClick(Sender: TObject);
var
  i: Integer;
begin
  i := Lst.ItemIndex;
  if (i < 0) or Work[i].BuiltIn then Exit;
  Delete(Work, i, 1);
  if i > High(Work) then i := High(Work);
  FillList(i);
end;

procedure TFltLibDlg.OkClick(Sender: TObject);
var
  i: Integer;
  sc: TFltScript;
  err: string;
  ok: Boolean;
begin
  for i := 0 to High(Work) do
    if not Work[i].BuiltIn then
    begin
      if Trim(Work[i].Name) = '' then Work[i].Name := 'Filter ' + IntToStr(i + 1);
      sc := TFltScript.Create;
      try
        ok := sc.Compile(Work[i].Script, err);
      finally
        sc.Free;
      end;
      if not ok then
      begin
        ShowMessage('The script of "' + Work[i].Name + '" is wrong: ' + err);
        Lst.ItemIndex := i;
        ShowItem;
        Exit;
      end;
    end;
  Form.ModalResult := mrOk;
end;

procedure TForm1.MenuFilterLibrary(Sender: TObject);
var
  d: TFltLibDlg;
  f: TForm;
  pr, pb, pt, pbr: TPanel;
  l: TLabel;
begin
  d := TFltLibDlg.Create;
  f := TForm.CreateNew(Application);
  try
    d.Owner := Self;
    d.Form := f;
    d.Work := Copy(FltLib);
    f.Caption := 'Filters Library';
    f.Position := poMainFormCenter;
    f.ClientWidth := 800;
    f.ClientHeight := 580;
    pb := TPanel.Create(f);
    pb.Parent := f;
    pb.Align := alBottom;
    pb.Height := 40;
    pb.BevelOuter := bvNone;
    d.Lst := TListBox.Create(f);
    d.Lst.Parent := f;
    d.Lst.Align := alLeft;
    d.Lst.Width := 218;
    d.Lst.OnClick := @d.ListClick;
    pr := TPanel.Create(f);
    pr.Parent := f;
    pr.Align := alClient;
    pr.BevelOuter := bvNone;
    pt := TPanel.Create(f);
    pt.Parent := pr;
    pt.Align := alTop;
    pt.Height := 290;
    pt.BevelOuter := bvNone;
    l := TLabel.Create(f);
    l.Parent := pt;
    l.Caption := 'Name';
    l.SetBounds(20, 14, 60, 20);
    d.EdName := TEdit.Create(f);
    d.EdName.Parent := pt;
    d.EdName.SetBounds(80, 10, 240, 26);
    d.EdName.OnChange := @d.NameChange;
    d.Img := TImage.Create(f);
    d.Img.Parent := pt;
    d.Img.SetBounds(80, 44, 132, 132);
    d.Img.Stretch := False;
    d.Img.Center := True;
    d.BtnTest := TButton.Create(f);
    d.BtnTest.Parent := pt;
    d.BtnTest.Caption := 'Test the script';
    d.BtnTest.SetBounds(230, 44, 140, 28);
    d.BtnTest.OnClick := @d.TestClick;
    d.Info := TLabel.Create(f);
    d.Info.Parent := pt;
    d.Info.AutoSize := False;
    d.Info.WordWrap := True;
    d.Info.SetBounds(230, 80, 360, 96);
    l := TLabel.Create(f);
    l.Parent := pt;
    l.WordWrap := True;
    l.AutoSize := False;
    l.SetBounds(12, 182, 560, 104);
    l.Caption := 'The script runs for every pixel: R, G, B (0..255) and H, S, L (degrees, 0..100, 0..100) are the input, ' +
      'Ro, Go, Bo (or Ho, So, Lo) the output; A and Ao the opacity (0: transparent, 255: opaque; @premul before the code gives R, G, B multiplied by A); X, Y the position, MAXX, MAXY the last position, SCALE the pixels of one ' +
      'unit of the drawing. R[x, y] reads another pixel. IF/ELSEIF/ELSE/ENDIF, FOR/NEXT, WHILE/WEND, PASS (a new pass ' +
      'on the output of the last), AVGR/AVGG/AVGB/AVGA(x0, y0, x1, y1) the mean of a rectangle. Parameters: ' +
      '@param Name = value [min, max, step] "Caption".';
    d.Memo := TMemo.Create(f);
    d.Memo.Parent := pr;
    d.Memo.Align := alClient;
    d.Memo.ScrollBars := ssBoth;
    d.Memo.WordWrap := False;
    d.Memo.Font.Name := 'DejaVu Sans Mono';
    d.Memo.OnChange := @d.MemoChange;
    d.BtnAdd := TButton.Create(f);
    d.BtnAdd.Parent := pb;
    d.BtnAdd.Caption := 'Add';
    d.BtnAdd.SetBounds(8, 6, 96, 28);
    d.BtnAdd.OnClick := @d.AddClick;
    d.BtnRemove := TButton.Create(f);
    d.BtnRemove.Parent := pb;
    d.BtnRemove.Caption := 'Remove';
    d.BtnRemove.SetBounds(112, 6, 96, 28);
    d.BtnRemove.OnClick := @d.RemoveClick;
    pbr := TPanel.Create(f);
    pbr.Parent := pb;
    pbr.Align := alRight;
    pbr.Width := 232;
    pbr.BevelOuter := bvNone;
    d.BtnCancel := TButton.Create(f);
    d.BtnCancel.Parent := pbr;
    d.BtnCancel.Caption := 'Cancel';
    d.BtnCancel.SetBounds(120, 6, 100, 28);
    d.BtnCancel.ModalResult := mrCancel;
    d.BtnOk := TButton.Create(f);
    d.BtnOk.Parent := pbr;
    d.BtnOk.Caption := 'OK';
    d.BtnOk.SetBounds(12, 6, 100, 28);
    d.BtnOk.Default := True;
    d.BtnOk.OnClick := @d.OkClick;
    d.FillList(0);
    if f.ShowModal = mrOk then
    begin
      FltLib := Copy(d.Work);
      SaveConfig;
      RebuildFltButtons;
      SetStatus('Filters library saved: ' + IntToStr(Length(FltLib)) + ' filters.');
    end;
  finally
    f.Free;
    d.Free;
  end;
end;

procedure TForm1.BuildMenus;

  function Item(parent: TMenuItem; const cap: string; handler: TNotifyEvent;
    pos: Integer = -1): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Caption := cap;
    Result.OnClick := handler;
    if pos >= 0 then parent.Insert(pos, Result) else parent.Add(Result);
  end;

var
  viewMenu: TMenuItem;
begin
  MenuItem3.OnClick := @MenuOpen;
  MenuItem3.Caption := 'Open... (Ctrl+O)';
  MenuItem4.OnClick := @MenuSave;
  MenuItem4.Caption := 'Save (Ctrl+S)';
  MenuItem5.OnClick := @MenuSaveAs;
  MenuItem5.Caption := 'Save As... (SVG or PNG)';
  MenuItem6.OnClick := @MenuConfig;
  MenuItem7.OnClick := @MenuExit;
  MenuItem9.OnClick := @MenuCopy;
  MenuItem9.Caption := 'Copy (Ctrl+C)';
  MenuItem10.OnClick := @MenuCut;
  MenuItem10.Caption := 'Cut (Ctrl+X)';
  MenuItem11.OnClick := @MenuPasteSmart;
  MenuItem11.Caption := 'Paste (Ctrl+V)';
  MenuItem12.OnClick := @MenuPasteRaster;
  MenuItem12.Caption := 'Paste as Raster (Ctrl+Shift+V)';
  MenuItem13.OnClick := @MenuSettings;
  MenuItem14.OnClick := @MenuSvgCode;
  MenuItem17.OnClick := @MenuHelpSnippets;
  MenuItem18.OnClick := @MenuHelpFilters;
  Item(MenuItem8, 'SVG Library...', @MenuSvgLibrary);
  Item(MenuItem2, 'New (Ctrl+N)', @MenuNew, 0);
  Item(MenuItem2, 'Insert image from file...', @MenuInsertImage, MenuItem3.MenuIndex + 1);
  Item(MenuItem2, 'Print... (Ctrl+P)', @MenuPrint, MenuItem7.MenuIndex);
  Item(MenuItem8, 'Undo (Ctrl+Z)', @DoUndo, 0);
  Item(MenuItem8, 'Redo (Ctrl+Y)', @DoRedo, 1);
  Item(MenuItem8, '-', nil, 2);
  Item(MenuItem8, 'Delete (Del)', @MenuDelete);
  Item(MenuItem8, 'Select All (Ctrl+A)', @SelectAll);
  Item(MenuItem8, 'Invert Selection (Ctrl+I)', @InvertSelection);
  miGroup := Item(MenuItem8, 'Group (Ctrl+G)', @GroupClick);
  miUngroup := Item(MenuItem8, 'Ungroup (Ctrl+Shift+G)', @UngroupClick);
  miMerge := Item(MenuItem8, 'Merge two rasters', @MergeRastersClick);
  Item(MenuItem8, 'Bring to Front', @MenuFront);
  Item(MenuItem8, 'Send to Back', @MenuBack);
  viewMenu := TMenuItem.Create(Self);
  viewMenu.Caption := 'View';
  MainMenu1.Items.Add(viewMenu);
  Item(viewMenu, 'Zoom In (Ctrl+wheel)', @MenuZoomIn);
  Item(viewMenu, 'Zoom Out (Ctrl+wheel)', @MenuZoomOut);
  Item(viewMenu, 'Zoom 100% (Ctrl+0)', @MenuZoom100);
  Item(viewMenu, 'Fit page in window', @MenuZoomFit);
  miFilters := TMenuItem.Create(Self);
  miFilters.Caption := 'Filters';
  MainMenu1.Items.Add(miFilters);
  Item(miFilters, 'Filters Library...', @MenuFilterLibrary);
  Item(miFilters, '-', nil);
  miFltParams := Item(miFilters, 'Filter parameters...', @MenuFilterParams);
  miFltClear := Item(miFilters, 'Remove the filter of the layer', @MenuFilterClear);
  Item(miFilters, '-', nil);
  miFltApply := Item(miFilters, 'Apply to the selected raster', nil);
  RebuildFltApplyMenu;
  // the Help menu is the last one, at the right of the window
  MainMenu1.Items.Remove(MenuItem15);
  MainMenu1.Items.Add(MenuItem15);
  MenuItem15.RightJustify := True;
  RefreshLayers;
end;

end.
