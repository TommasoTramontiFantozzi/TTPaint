//Versione 6
unit GrandeEditorTesto;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Types, Forms, Math,
  LCLIntf, LCLType, ExtCtrls, LazUTF8, Clipbrd, Menus, RegExpr, base64, LConvEncoding;

type
  TTextChangeEvent = procedure(Sender: TObject; VisLine, VisCol: Integer) of object;
  TNavigateEvent = procedure(Sender: TObject; FromVisLine, FromVisCol, ToVisLine, ToVisCol: Integer) of object;

  TEvidenziazione = record
    PosInizio: Integer;
    PosFine: Integer;
    Colore: TColor;
    OpID: Integer;
  end;

  TEvidenziazioniArray = array of TEvidenziazione;

  TVisualLine = record
    FisicaIndex: Integer;
    StartChar: Integer;
    StartByte: Integer;
    Lunghezza: Integer;
    ByteLen: Integer;
    IsFirstWrap: Boolean;
    offsetX: Integer;
  end;

  TUndoOperationType = (uoInsert, uoDelete);

  TUndoItem = record
    OpType: TUndoOperationType;
    FisicoX, FisicoY: Integer;
    Text: String;
    CaretBeforeX, CaretBeforeY: Integer;
    CaretAfterX, CaretAfterY: Integer;
    GroupID: Integer;
  end;

  TNavPosition = record
    PhysX, PhysY: Integer;
  end;

  TSearchType = (stText, stWildcard, stRegEx);

  TSearchOptions = record
    SearchType: TSearchType;
    CaseSensitive: Boolean;
    WholeWord: Boolean;
    MatchDiacritics: Boolean;
    removeOlder: Boolean;
  end;

  TSearchOperation = record
    ID: Integer;
    SearchText: String;
    Options: TSearchOptions;
    Color: TColor;
    MatchCount: Integer;
  end;

  TMatchResult = record
    CharX: Integer;
    CharLen: Integer;
  end;
  TMatchArray = array of TMatchResult;

  TMacroEventType = (meUTF8Char, meSpecialKey);

  TMacroEvent = record
    EventType: TMacroEventType;
    UTF8Char: TUTF8Char;
    Key: Word;
    Shift: TShiftState;
  end;

  TEditorMacro = record
    Events: array of TMacroEvent;
  end;

  TImageWrapMode = (iwNone, iwLeft);

  TEmbeddedImage = record
    B64Data: String;
    Col: Integer;
    WidthCols: Integer;
    Wrap: TImageWrapMode;
    Picture: TPicture;
    HeightRows: Integer;
  end;

  TImageCacheItem = record
    B64Hash: PtrInt;
    B64Data: String;
    Picture: TPicture;
  end;

  THyperlinkSpan = record
    Target: String;
    VisStartX, VisEndX: Integer;
    PhysStartX, PhysEndX: Integer;
  end;

  TCharStyle = record
    Style: TFontStyles;
    Color: TColor;
  end;

  TLineParseResult = record
    StrippedText: String;
    VisToPhys: array of Integer;
    PhysToVis: array of Integer;
    Links: array of THyperlinkSpan;
    CharStyles: array of TCharStyle;
    VisCols: array of Integer;
    HasImage: Boolean;
    EmbeddedImg: TEmbeddedImage;
  end;

  TLineInfoCache = record
    StrippedTextLen: Integer;
    MaxVisualCol: Integer;
    ByteLength: Integer;
    HasImage: Boolean;
    ImageWrap: TImageWrapMode;
    HeightRows: Integer;
    HasTab: Boolean;
    IsRich: Boolean;
  end;

  TGrandeEditorTesto = class(TCustomControl)
  private
    FTesto: TStringList;
    FScrollBar: TScrollBar;
    FHScrollBar: TScrollBar;
    FTopLine: Integer;
    FLeftCol: Integer;
    FLineHeight: Integer;
    FCharWidth: Integer;
    FMargineNumeri: Integer;
    FTabWidth: Integer;
    FWordWrap: Boolean;
    FAlignWrappedTabs: Boolean;
    FReadOnly: Boolean;
    FUseUTF8: Boolean;
    FByteSize: Int64;

    FTextCursor: TCursor;

    FUndoList: array of TUndoItem;
    FRedoList: array of TUndoItem;
    FMaxUndoLevel: Integer;
    FIsPerformingUndoRedo: Boolean;
    FNextGroupID: Integer;

    FNavHistory: array of TNavPosition;
    FNavIndex: Integer;

    FIsRecordingMacro: Boolean;
    FIsPlayingMacro: Boolean;
    FCurrentMacro: TEditorMacro;

    FSearchOperations: array of TSearchOperation;
    FNextOpID: Integer;

    FEnableRichText: Boolean;
    FLinkColor: TColor;
    FLinkCursor: TCursor;
    FHoveredLinkTarget: String;
    FImageLookbackLines: Integer;
    FImageCache: array of TImageCacheItem;

    FHighlightSelectedWord: Boolean;
    FHighlightWholeWordsOnly: Boolean;
    FSelectedWordColor: TColor;

    FHighlightMatchingBracket: Boolean;
    FMatchingBracketColor: TColor;

    FVisualLines: array of TVisualLine;
    FVisualCount: Integer;

    FCaretFisicoX: Integer;
    FCaretFisicoY: Integer;
    FShowCaret: Boolean;
    FCaretTimer: TTimer;

    FSelStartX, FSelStartY: Integer;
    FSelEndX, FSelEndY: Integer;
    FSelectingWithMouse: Boolean;
    FAutoScrollTimer: TTimer;

    FEvidenziazioni: TEvidenziazioniArray;

    FOnChange: TTextChangeEvent;
    FOnNavigate: TNavigateEvent;

    FLineCache: array of TLineInfoCache;

    function GetStrLength(const S: String): Integer; inline;
    function FastSeekChar(P: PChar; CharIndex: Integer): PChar;
    function FastCharPos(const SubStr, S: String; StartChar: Integer = 1): Integer;
    function CharIndexToByteOffset(const S: String; CharIdx: Integer): Integer;
    function ExtractViewportSlice(const S: String; StartCharIdx, CharCount: Integer; out ActualChars: Integer): String;
    function SubStringFast(const S: String; StartChar, CharCount: Integer): String;

    function TrovaRangeTagAtomico(const RawLine: String; PhysX: Integer; out StartDel, EndDel: Integer): Boolean;
    function GetVisColFromPhys(PhysX, PhysY: Integer): Integer;
    function GetPhysFromVisCol(TargetScreenVisCol, PhysY: Integer): Integer;
    function GetLeadingTabVisCols(const S: String): Integer;
    function GetCurrentVisualLineIndex: Integer;
    procedure SnapCaretToValidPhysX;
    procedure AggiornaCacheTestoCompleto;
    procedure AggiornaCacheRigaSingola(RigaFisica: Integer);
    procedure SetTesto(AValue: TStringList);
    procedure SetTabWidth(AValue: Integer);
    procedure SetWordWrap(AValue: Boolean);
    procedure SetAlignWrappedTabs(AValue: Boolean);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetUseUTF8(AValue: Boolean);
    procedure SetMaxUndoLevel(AValue: Integer);
    procedure SetEnableRichText(AValue: Boolean);
    procedure SetLinkColor(AValue: TColor);
    procedure SetTextCursor(AValue: TCursor);
    procedure SetHighlightSelectedWord(AValue: Boolean);
    procedure SetHighlightWholeWordsOnly(AValue: Boolean);
    procedure SetSelectedWordColor(AValue: TColor);
    procedure SetHighlightMatchingBracket(AValue: Boolean);
    procedure SetMatchingBracketColor(AValue: TColor);
    procedure RigheCambiate(Sender: TObject);
    procedure ScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
    procedure HScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
    procedure AggiornaScrollBar;
    procedure CalcolaDimensioni;
    procedure RigeneraMappaVisuale;
    procedure AggiornaMappaRigaSingola(RigaFisica: Integer);
    procedure CaretBlinkEvent(Sender: TObject);
    procedure AutoScrollTimerEvent(Sender: TObject);
    procedure SpostaCaretAVisualLine(VisualIndex, CarattereX: Integer; MantieniSelezione: Boolean);
    procedure AssicuratiCaretVisibile;
    function MaxTopLine: Integer;

    function GetCachedPicture(const B64Str: String): TPicture;
    procedure SvuotaCacheImmagini;
    function ParseRichTextLine(const RawLine: String; LinePhysIdx: Integer = -1): TLineParseResult;
    function GetColTagContentVisLen(const RawLine: String; FromPos: Integer): Integer;
    function TrovaBookmark(const TargetName: String; out BM_X, BM_Y: Integer): Boolean;

    procedure FisicoToVisibileCoords(PhysX, PhysY: Integer; out VisLine, VisCol: Integer);
    procedure DoNotifyChange(PhysX, PhysY: Integer);
    procedure PushNavHistory(PX, PY: Integer);

    procedure InsertTextFisico(AX, AY: Integer; const AText: String);
    function DeleteTextFisico(StartX, StartY, EndX, EndY: Integer): String;
    procedure CalcolaFineTesto(StartX, StartY: Integer; const AText: String; out EndX, EndY: Integer);
    procedure RecordInsert(FX, FY: Integer; const AText: String; CaretBeforeX, CaretBeforeY, CaretAfterX, CaretAfterY: Integer; GroupID: Integer = 0);
    procedure RecordDelete(FX, FY: Integer; const AText: String; CaretBeforeX, CaretBeforeY, CaretAfterX, CaretAfterY: Integer; GroupID: Integer = 0);
    procedure AddUndoItem(const AItem: TUndoItem);
    procedure ClearRedo;
    function NuovoGroupID: Integer;

    procedure NormalizzaSelezione(out OutStartX, OutStartY, OutEndX, OutEndY: Integer);
    function CarattereIsInSelezione(FisicoX, FisicoY: Integer): Boolean;
    procedure AggiornaSelezioneCaret(OldX, OldY: Integer; ExtendSelection: Boolean);
    procedure VisualCoordinateToFisico(X, Y: Integer; out OutFisicoX, OutFisicoY: Integer);
    procedure CancellaSelezione(AGroupID: Integer = 0);

    procedure AggiornaEvidenziazioniSuInserimento(APos, ALen: Integer);
    procedure AggiornaEvidenziazioniSuCancellazione(APos, ALen: Integer);
    function TrovaColoreEvidenziazione(AbsPos: Integer; out AColor: TColor): Boolean;
    function TrovaParentesiCorrispondente(out B1X, B1Y, B2X, B2Y: Integer): Boolean;
    function CercaInRiga(const LineText, SearchText: String; const AOptions: TSearchOptions): TMatchArray;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    function GetActiveOverlappingImage(LinePhysIdx: Integer; out Img: TEmbeddedImage; out ImgStartLine: Integer): integer;
    function GetActiveOverlappingImageVis(VIndex: Integer; out Img: TEmbeddedImage; out VisualLinesAbove: Integer): Boolean;
    function getFont: TFont;
    procedure setFont(FFont: TFont);
    function UTF8Copy(const s: string; StartCharIndex, CharCount: PtrInt): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Prev;
    procedure Next;
    function CanPrev: Boolean;
    function CanNext: Boolean;

    procedure ScorriAllaRiga(RigaFisica: Integer);
    function PrimaRigaMostrata: Integer;
    function UltimaRigaMostrata: Integer;

    function HaSelezione: Boolean;
    function TestoSelezionato: String;
    procedure SelezionaTutto;
    procedure AnnullaSelezione;
    procedure CopiaInAppunti;
    procedure TagliaInAppunti;
    procedure IncollaDaAppunti;
    function InizioSelezione: TPoint;
    function FineSelezione: TPoint;

    procedure Undo;
    procedure Redo;
    procedure AzzeraUndoRedo;
    function PuoAnnullare: Boolean;
    function PuoRipristinare: Boolean;

    procedure StartMacroRec;
    function StopMacroRec: TEditorMacro;
    procedure PlayMacro(const AMacro: TEditorMacro);

    procedure Evidenzia(const AEvidenziazioni: array of TEvidenziazione);
    procedure RimuoviEvidenziazioni;
    function LeggiEvidenziazioni: TEvidenziazioniArray;
    function FisicoToPosAssoluta(AX, AY: Integer): Integer;
    procedure PosAssolutaToFisico(APos: Integer; out AX, AY: Integer);

    function TrovaProssimo(const ASearchText: String; const AOptions: TSearchOptions; DaInizio: Boolean = False): Boolean;
    function TrovaPrecedente(const ASearchText: String; const AOptions: TSearchOptions): Boolean;
    function EvidenziaTutti(const ASearchText: String; const AOptions: TSearchOptions; AColor: TColor = $0080FFFF): Integer;
    procedure AnnullaEvidenzia(AOpID: Integer);
    procedure AnnullaEvidenziazioneRicerca;

    property Testo: TStringList read FTesto write SetTesto;
    property CaretX: Integer read FCaretFisicoX;
    property CaretY: Integer read FCaretFisicoY;
    property IsRecordingMacro: Boolean read FIsRecordingMacro;
    property ByteSize: Int64 read FByteSize;
  published
    property PopupMenu;
    property EditorFont: TFont read getFont write setFont;
    property TabWidth: Integer read FTabWidth write SetTabWidth default 2;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
    property AlignWrappedTabs: Boolean read FAlignWrappedTabs write SetAlignWrappedTabs default True;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property UseUTF8: Boolean read FUseUTF8 write SetUseUTF8 default True;
    property MaxUndoLevel: Integer read FMaxUndoLevel write SetMaxUndoLevel default 100;
    property TextCursor: TCursor read FTextCursor write SetTextCursor default crIBeam;

    property EnableRichText: Boolean read FEnableRichText write SetEnableRichText default False;
    property LinkColor: TColor read FLinkColor write SetLinkColor default clBlue;
    property LinkCursor: TCursor read FLinkCursor write FLinkCursor default crHandPoint;
    property ImageLookbackLines: Integer read FImageLookbackLines write FImageLookbackLines default 20;

    property HighlightSelectedWord: Boolean read FHighlightSelectedWord write SetHighlightSelectedWord default True;
    property HighlightWholeWordsOnly: Boolean read FHighlightWholeWordsOnly write SetHighlightWholeWordsOnly default True;
    property SelectedWordColor: TColor read FSelectedWordColor write SetSelectedWordColor default $00C0E0FF;

    property HighlightMatchingBracket: Boolean read FHighlightMatchingBracket write SetHighlightMatchingBracket default True;
    property MatchingBracketColor: TColor read FMatchingBracketColor write SetMatchingBracketColor default $00C0FFC0;

    property OnChange: TTextChangeEvent read FOnChange write FOnChange;
    property OnNavigate: TNavigateEvent read FOnNavigate write FOnNavigate;
    property OnClick;
    property OnDblClick;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnUTF8KeyPress;
  end;

implementation

function UTF8To1byteCod(const S: string): string;
var
  pIn, pOut: PChar;
  Len: Integer;
begin
  Len := Length(S);
  if Len = 0 then Exit('');
  SetLength(Result, Len);
  pIn := PChar(S);
  pOut := PChar(Result);
  while pIn^ <> #0 do
  begin
    if Byte(pIn^) > 128 then
      pOut^ := #186
    else
      pOut^ := pIn^;
    Inc(pIn);
    Inc(pOut);
  end;
end;

function IsWordChar(const C: String): Boolean;
begin
  if C = '' then Exit(False);
  if Length(C) = 1 then
    Result := C[1] in ['a'..'z', 'A'..'Z', '0'..'9', '_']
  else
    Result := True;
end;

function RimuoviAccenti(const S: String): String;
begin
  Result := S;
  if Result = '' then Exit;
  Result := StringReplace(Result, 'à', 'a', [rfReplaceAll]);
  Result := StringReplace(Result, 'á', 'a', [rfReplaceAll]);
  Result := StringReplace(Result, 'â', 'a', [rfReplaceAll]);
  Result := StringReplace(Result, 'ä', 'a', [rfReplaceAll]);
  Result := StringReplace(Result, 'À', 'A', [rfReplaceAll]);
  Result := StringReplace(Result, 'Á', 'A', [rfReplaceAll]);
  Result := StringReplace(Result, 'è', 'e', [rfReplaceAll]);
  Result := StringReplace(Result, 'é', 'e', [rfReplaceAll]);
  Result := StringReplace(Result, 'ê', 'e', [rfReplaceAll]);
  Result := StringReplace(Result, 'ë', 'e', [rfReplaceAll]);
  Result := StringReplace(Result, 'È', 'E', [rfReplaceAll]);
  Result := StringReplace(Result, 'É', 'E', [rfReplaceAll]);
  Result := StringReplace(Result, 'ì', 'i', [rfReplaceAll]);
  Result := StringReplace(Result, 'í', 'i', [rfReplaceAll]);
  Result := StringReplace(Result, 'î', 'i', [rfReplaceAll]);
  Result := StringReplace(Result, 'ï', 'i', [rfReplaceAll]);
  Result := StringReplace(Result, 'Ì', 'I', [rfReplaceAll]);
  Result := StringReplace(Result, 'Í', 'I', [rfReplaceAll]);
  Result := StringReplace(Result, 'ò', 'o', [rfReplaceAll]);
  Result := StringReplace(Result, 'ó', 'o', [rfReplaceAll]);
  Result := StringReplace(Result, 'ô', 'o', [rfReplaceAll]);
  Result := StringReplace(Result, 'ö', 'o', [rfReplaceAll]);
  Result := StringReplace(Result, 'Ò', 'O', [rfReplaceAll]);
  Result := StringReplace(Result, 'Ó', 'O', [rfReplaceAll]);
  Result := StringReplace(Result, 'ù', 'u', [rfReplaceAll]);
  Result := StringReplace(Result, 'ú', 'u', [rfReplaceAll]);
  Result := StringReplace(Result, 'û', 'u', [rfReplaceAll]);
  Result := StringReplace(Result, 'ü', 'u', [rfReplaceAll]);
  Result := StringReplace(Result, 'Ù', 'U', [rfReplaceAll]);
  Result := StringReplace(Result, 'Ú', 'U', [rfReplaceAll]);
end;

function WildcardToRegEx(const Pattern: String; FUseUTF8: Boolean): String;
var
  i, SLen: Integer;
  C: String;
begin
  Result := '';
  if FUseUTF8 then SLen := UTF8Length(Pattern) else SLen := Length(Pattern);
  for i := 1 to SLen do
  begin
    if FUseUTF8 then C := Copy(Pattern, i, 1) else C := Pattern[i];
    if C = '*' then Result := Result + '.*'
    else if C = '?' then Result := Result + '.'
    else if Pos(C, '.\+^$()[]{}|') > 0 then Result := Result + '\' + C
    else Result := Result + C;
  end;
end;

function GetAttrValue(const TagStr, AttrName: String): String;
var
  P, StartP, EndP: Integer;
  LowerTag, LowerAttr: String;
  QuoteChar: Char;
begin
  Result := '';
  LowerTag := UTF8LowerCase(TagStr);
  LowerAttr := UTF8LowerCase(AttrName) + '=';
  P := UTF8Pos(LowerAttr, LowerTag);
  if P = 0 then Exit;

  P := P + UTF8Length(LowerAttr);
  while (P <= UTF8Length(TagStr)) and (TagStr[P] = ' ') do Inc(P);

  if (P <= UTF8Length(TagStr)) and ((TagStr[P] = '"') or (TagStr[P] = '''')) then
  begin
    QuoteChar := TagStr[P];
    StartP := P + 1;
    EndP := StartP;
    while (EndP <= UTF8Length(TagStr)) and (TagStr[EndP] <> QuoteChar) do
      Inc(EndP);
    Result := UTF8Copy(TagStr, StartP, EndP - StartP);
  end;
end;

function Base64ToPicture(const B64Str: String): TPicture;
var
  InStream: TStringStream;
  B64Decoder: TBase64DecodingStream;
  PNG: TPortableNetworkGraphic;
begin
  Result := TPicture.Create;
  if B64Str = '' then Exit;

  PNG := TPortableNetworkGraphic.Create;
  InStream := TStringStream.Create(Trim(B64Str));
  try
    B64Decoder := TBase64DecodingStream.Create(InStream);
    try
      try
        PNG.LoadFromStream(B64Decoder);
        Result.Graphic := PNG;
      except
      end;
    finally
      B64Decoder.Free;
      PNG.Free;
    end;
  finally
    InStream.Free;
  end;
end;

function TGrandeEditorTesto.GetStrLength(const S: String): Integer;
begin
  if FUseUTF8 then
    Result := UTF8Length(S)
  else
    Result := Length(S);
end;

function TGrandeEditorTesto.FastSeekChar(P: PChar; CharIndex: Integer): PChar;
var
  i: Integer;
begin
  Result := P;
  if (Result = nil) or (CharIndex <= 0) then Exit;

  if not FUseUTF8 then
  begin
    while (CharIndex > 0) and (Result^ <> #0) do
    begin
      Inc(Result);
      Dec(CharIndex);
    end;
    Exit;
  end;

  for i := 1 to CharIndex do
  begin
    if Result^ = #0 then Break;
    Inc(Result);
    while (Ord(Result^) and $C0) = $80 do
      Inc(Result);
  end;
end;

function TGrandeEditorTesto.FastCharPos(const SubStr, S: String; StartChar: Integer): Integer;
begin
  if FUseUTF8 then
    Result := UTF8Pos(SubStr, S, StartChar)
  else
    Result := Pos(SubStr, S, StartChar);
end;

function TGrandeEditorTesto.getFont: TFont;
begin
  Result := Font;
end;

procedure TGrandeEditorTesto.setFont(FFont: TFont);
begin
  if FFont.IsMonoSpace = True then
    Font := FFont
  else
    raise Exception.Create('Only monospace fonts are supported');
end;

function TGrandeEditorTesto.CharIndexToByteOffset(const S: String; CharIdx: Integer): Integer;
var
  p: PChar;
begin
  if (S = '') or (CharIdx <= 0) then Exit(0);
  if not FUseUTF8 then Exit(CharIdx);

  p := FastSeekChar(PChar(S), CharIdx);
  Result := p - PChar(S);
end;

function TGrandeEditorTesto.GetLeadingTabVisCols(const S: String): Integer;
var
  P: PChar;
  VisCol, TabSpace, Tw: Integer;
begin
  Result := 0;
  if S = '' then Exit;
  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;
  VisCol := 0;
  P := PChar(S);
  while (P^ = #9) do
  begin
    TabSpace := Tw - (VisCol mod Tw);
    if TabSpace = 0 then TabSpace := Tw;
    Inc(VisCol, TabSpace);
    Inc(P);
  end;
  Result := VisCol;
end;

procedure TGrandeEditorTesto.DblClick;
var
  LineText, VisText, Ch: String;
  LineLen, PosChar, StartPos, EndPos: Integer;
  ParseRes: TLineParseResult;
  VisPos, VisStart, VisEnd: Integer;
  IsWord: Boolean;
begin
  inherited DblClick;

  if (FCaretFisicoY < 0) or (FCaretFisicoY >= FTesto.Count) then Exit;

  LineText := FTesto[FCaretFisicoY];
  LineLen := GetStrLength(LineText);
  if LineLen = 0 then Exit;

  if FEnableRichText and (FCaretFisicoY < Length(FLineCache)) and FLineCache[FCaretFisicoY].IsRich then
  begin
    ParseRes := ParseRichTextLine(LineText, FCaretFisicoY);
    VisText := ParseRes.StrippedText;
    LineLen := GetStrLength(VisText);
    if (LineLen = 0) or (Length(ParseRes.VisToPhys) = 0) then Exit;

    if (FCaretFisicoX >= 0) and (FCaretFisicoX < Length(ParseRes.PhysToVis)) then
      VisPos := ParseRes.PhysToVis[FCaretFisicoX]
    else
      VisPos := LineLen - 1;

    VisPos := EnsureRange(VisPos, 0, LineLen - 1);
    Ch := SubStringFast(VisText, VisPos + 1, 1);
    IsWord := IsWordChar(Ch);

    VisStart := VisPos;
    while (VisStart > 0) and
          (VisStart < Length(ParseRes.VisCols)) and
          (ParseRes.VisCols[VisStart] = ParseRes.VisCols[VisStart - 1] + 1) and
          (IsWordChar(SubStringFast(VisText, VisStart, 1)) = IsWord) and
          (SubStringFast(VisText, VisStart, 1) <> ' ') do
      Dec(VisStart);

    VisEnd := VisPos;
    while (VisEnd < LineLen) do
    begin
      if (VisEnd > VisPos) and (VisEnd < Length(ParseRes.VisCols)) and
         (ParseRes.VisCols[VisEnd] <> ParseRes.VisCols[VisEnd - 1] + 1) then
        Break;

      if (IsWordChar(SubStringFast(VisText, VisEnd + 1, 1)) <> IsWord) or
         (SubStringFast(VisText, VisEnd + 1, 1) = ' ') then
        Break;

      Inc(VisEnd);
    end;

    if VisStart < VisEnd then
    begin
      FSelStartY := FCaretFisicoY;
      FSelEndY := FCaretFisicoY;

      if VisStart < Length(ParseRes.VisToPhys) then
        FSelStartX := ParseRes.VisToPhys[VisStart]
      else
        FSelStartX := 0;

      if (VisEnd - 1 < Length(ParseRes.VisToPhys)) then
        FSelEndX := ParseRes.VisToPhys[VisEnd - 1] + 1
      else
        FSelEndX := GetStrLength(LineText);

      FCaretFisicoX := FSelEndX;
    end;
  end
  else
  begin
    PosChar := EnsureRange(FCaretFisicoX, 0, LineLen - 1);
    Ch := SubStringFast(LineText, PosChar + 1, 1);
    IsWord := IsWordChar(Ch);

    StartPos := PosChar;
    while (StartPos > 0) and (IsWordChar(SubStringFast(LineText, StartPos, 1)) = IsWord) and
          (SubStringFast(LineText, StartPos, 1) <> ' ') do
      Dec(StartPos);

    EndPos := PosChar;
    while (EndPos < LineLen) and (IsWordChar(SubStringFast(LineText, EndPos + 1, 1)) = IsWord) and
          (SubStringFast(LineText, EndPos + 1, 1) <> ' ') do
      Inc(EndPos);

    if StartPos < EndPos then
    begin
      FSelStartY := FCaretFisicoY;
      FSelEndY := FCaretFisicoY;
      FSelStartX := StartPos;
      FSelEndX := EndPos;
      FCaretFisicoX := EndPos;
    end;
  end;

  FSelectingWithMouse := False;
  AssicuratiCaretVisibile;
  DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
  Invalidate;
end;

function TGrandeEditorTesto.ExtractViewportSlice(const S: String; StartCharIdx, CharCount: Integer; out ActualChars: Integer): String;
var
  pStart, pEnd: PChar;
  cLen: Integer;
begin
  ActualChars := 0;
  if (S = '') or (CharCount <= 0) then Exit('');

  if not FUseUTF8 then
  begin
    ActualChars := Min(CharCount, Max(0, Length(S) - StartCharIdx + 1));
    Exit(Copy(S, StartCharIdx, ActualChars));
  end;

  pStart := FastSeekChar(PChar(S), StartCharIdx - 1);
  if (pStart = nil) or (pStart^ = #0) then Exit('');

  pEnd := pStart;
  while (ActualChars < CharCount) and (pEnd^ <> #0) do
  begin
    cLen := UTF8CharacterLength(pEnd);
    Inc(pEnd, cLen);
    Inc(ActualChars);
  end;

  SetString(Result, pStart, pEnd - pStart);
end;

function TGrandeEditorTesto.SubStringFast(const S: String; StartChar, CharCount: Integer): String;
var
  pStart, pEnd: PChar;
begin
  if (S = '') or (CharCount <= 0) then Exit('');
  if not FUseUTF8 then
    Exit(Copy(S, StartChar, CharCount));

  pStart := FastSeekChar(PChar(S), StartChar - 1);
  if (pStart = nil) or (pStart^ = #0) then Exit('');
  pEnd := FastSeekChar(pStart, CharCount);
  SetString(Result, pStart, pEnd - pStart);
end;

constructor TGrandeEditorTesto.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  TabStop := True;
  DoubleBuffered := True;

  FUseUTF8 := False;
  FTextCursor := crIBeam;
  Cursor := crDefault;

  FLineHeight := 15;
  FCharWidth := 8;
  FMargineNumeri := 40;
  FTabWidth := 2;
  FByteSize := 0;

  FTesto := TStringList.Create;
  FTesto.OnChange := @RigheCambiate;
  FTesto.Add('');
  FByteSize := Length(FTesto.Text);
  FWordWrap := True;
  FAlignWrappedTabs := True;
  FReadOnly := False;

  FMaxUndoLevel := 100;
  FIsPerformingUndoRedo := False;
  FNextGroupID := 1;
  SetLength(FUndoList, 0);
  SetLength(FRedoList, 0);

  FNavIndex := -1;
  SetLength(FNavHistory, 0);

  FIsRecordingMacro := False;
  FIsPlayingMacro := False;
  SetLength(FCurrentMacro.Events, 0);

  FNextOpID := 0;
  SetLength(FSearchOperations, 0);

  FEnableRichText := False;
  FLinkColor := clBlue;
  FLinkCursor := crHandPoint;
  FHoveredLinkTarget := '';
  FImageLookbackLines := 20;
  SetLength(FImageCache, 0);

  FHighlightSelectedWord := True;
  FHighlightWholeWordsOnly := True;
  FSelectedWordColor := $00C0E0FF;

  FHighlightMatchingBracket := True;
  FMatchingBracketColor := $00C0FFC0;

  FTopLine := 0;
  FLeftCol := 0;
  FCaretFisicoX := 0;
  FCaretFisicoY := 0;
  FShowCaret := False;

  FSelStartX := -1; FSelStartY := -1;
  FSelEndX := -1;   FSelEndY := -1;
  FSelectingWithMouse := False;

  SetLength(FEvidenziazioni, 0);

  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Kind := sbVertical;
  FScrollBar.Parent := Self;
  FScrollBar.Cursor := crDefault;
  FScrollBar.OnScroll := @ScrollBarScroll;

  FHScrollBar := TScrollBar.Create(Self);
  FHScrollBar.Kind := sbHorizontal;
  FHScrollBar.Parent := Self;
  FHScrollBar.Cursor := crDefault;
  FHScrollBar.OnScroll := @HScrollBarScroll;
  FHScrollBar.Visible := False;

  FCaretTimer := TTimer.Create(Self);
  FCaretTimer.Interval := 500;
  FCaretTimer.OnTimer := @CaretBlinkEvent;
  FCaretTimer.Enabled := False;

  FAutoScrollTimer := TTimer.Create(Self);
  FAutoScrollTimer.Interval := 40;
  FAutoScrollTimer.OnTimer := @AutoScrollTimerEvent;
  FAutoScrollTimer.Enabled := False;

  Font.Name := 'Monospace';
  Font.Size := 11;
end;

destructor TGrandeEditorTesto.Destroy;
begin
  SvuotaCacheImmagini;
  FTesto.Free;
  inherited Destroy;
end;

procedure TGrandeEditorTesto.SetTabWidth(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if FTabWidth <> AValue then
  begin
    FTabWidth := AValue;
    AggiornaCacheTestoCompleto;
    AggiornaScrollBar;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetAlignWrappedTabs(AValue: Boolean);
begin
  if FAlignWrappedTabs <> AValue then
  begin
    FAlignWrappedTabs := AValue;
    AggiornaScrollBar;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetUseUTF8(AValue: Boolean);
begin
  if FUseUTF8 <> AValue then
  begin
    FUseUTF8 := AValue;
    AggiornaCacheTestoCompleto;
    AggiornaScrollBar;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetTextCursor(AValue: TCursor);
begin
  if FTextCursor <> AValue then
  begin
    FTextCursor := AValue;
    Cursor := FTextCursor;
  end;
end;

procedure TGrandeEditorTesto.SvuotaCacheImmagini;
var
  i: Integer;
begin
  for i := 0 to High(FImageCache) do
  begin
    if FImageCache[i].Picture <> nil then
      FImageCache[i].Picture.Free;
  end;
  SetLength(FImageCache, 0);
end;

function TGrandeEditorTesto.GetVisColFromPhys(PhysX, PhysY: Integer): Integer;
var
  ParseRes: TLineParseResult;
  VisCol, i: Integer;
  LineText: String;
  P: PChar;
  ChCount, TabSpace, cLen, Tw: Integer;
  OverlapImg: TEmbeddedImage;
  ImgStartLine: Integer;
begin
  if (PhysY < 0) or (PhysY >= FTesto.Count) then Exit(0);

  if FEnableRichText and (PhysY < Length(FLineCache)) and FLineCache[PhysY].IsRich then
  begin
    ParseRes := ParseRichTextLine(FTesto[PhysY], PhysY);
    if Length(ParseRes.VisToPhys) > 0 then
    begin
      if PhysX >= ParseRes.VisToPhys[High(ParseRes.VisToPhys)] + 1 then
      begin
        if Length(ParseRes.VisCols) > 0 then
          VisCol := ParseRes.VisCols[High(ParseRes.VisCols)] + 1
        else
          VisCol := GetStrLength(ParseRes.StrippedText);
      end
      else if PhysX <= ParseRes.VisToPhys[0] then
      begin
        if Length(ParseRes.VisCols) > 0 then
          VisCol := ParseRes.VisCols[0]
        else
          VisCol := 0;
      end
      else
      begin
        VisCol := 0;
        for i := 0 to High(ParseRes.VisToPhys) do
        begin
          if ParseRes.VisToPhys[i] = PhysX then
          begin
            if i < Length(ParseRes.VisCols) then
              VisCol := ParseRes.VisCols[i]
            else
              VisCol := i;
            Break;
          end
          else if ParseRes.VisToPhys[i] + 1 = PhysX then
          begin
            if i < Length(ParseRes.VisCols) then
              VisCol := ParseRes.VisCols[i] + 1
            else
              VisCol := i + 1;
            Break;
          end
          else if ParseRes.VisToPhys[i] > PhysX then
          begin
            if (i > 0) and (i - 1 < Length(ParseRes.VisCols)) then
              VisCol := ParseRes.VisCols[i - 1] + 1
            else if i < Length(ParseRes.VisCols) then
              VisCol := ParseRes.VisCols[i]
            else
              VisCol := i;
            Break;
          end;
        end;
      end;
    end
    else
      VisCol := 0;

    Result := VisCol;
    Exit;
  end;

  if (PhysY < Length(FLineCache)) and not FLineCache[PhysY].HasTab then
    Exit(PhysX);

  LineText := FTesto[PhysY];
  VisCol := 0;
  P := PChar(LineText);
  ChCount := 0;
  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;

  while (ChCount < PhysX) and (P^ <> #0) do
  begin
    if P^ = #9 then
    begin
      TabSpace := Tw - (VisCol mod Tw);
      if TabSpace = 0 then TabSpace := Tw;
      Inc(VisCol, TabSpace);
      Inc(P);
    end
    else
    begin
      Inc(VisCol);
      if FUseUTF8 then
      begin
        cLen := UTF8CharacterLength(P);
        Inc(P, cLen);
      end
      else
        Inc(P);
    end;
    Inc(ChCount);
  end;

  Result := VisCol;
end;

function TGrandeEditorTesto.GetPhysFromVisCol(TargetScreenVisCol, PhysY: Integer): Integer;
var
  ParseRes: TLineParseResult;
  i, BestIdx, MinDiff, Diff, LocalVisCol: Integer;
  LineText: String;
  CurrVisCol, NextVisCol, TabSpace, ChCount, cLen, Tw: Integer;
  P: PChar;
  OverlapImg: TEmbeddedImage;
  ImgStartLine: Integer;
begin
  if (PhysY < 0) or (PhysY >= FTesto.Count) then Exit(0);

  LocalVisCol := TargetScreenVisCol;

  if FEnableRichText and (PhysY < Length(FLineCache)) and FLineCache[PhysY].IsRich then
  begin
    ParseRes := ParseRichTextLine(FTesto[PhysY], PhysY);
    if Length(ParseRes.VisCols) > 0 then
    begin
      if LocalVisCol > ParseRes.VisCols[High(ParseRes.VisCols)] then
        Result := ParseRes.VisToPhys[High(ParseRes.VisToPhys)] + 1
      else if LocalVisCol <= ParseRes.VisCols[0] then
        Result := ParseRes.VisToPhys[0]
      else
      begin
        BestIdx := 0;
        MinDiff := Abs(ParseRes.VisCols[0] - LocalVisCol);
        for i := 1 to High(ParseRes.VisCols) do
        begin
          Diff := Abs(ParseRes.VisCols[i] - LocalVisCol);
          if Diff < MinDiff then
          begin
            MinDiff := Diff;
            BestIdx := i;
          end;
        end;
        Result := ParseRes.VisToPhys[BestIdx];
      end;
    end
    else
      Result := GetStrLength(FTesto[PhysY]);
    Exit;
  end;

  if LocalVisCol <= 0 then Exit(0);

  if (PhysY < Length(FLineCache)) and not FLineCache[PhysY].HasTab then
    Exit(Min(LocalVisCol, GetStrLength(FTesto[PhysY])));

  LineText := FTesto[PhysY];
  CurrVisCol := 0;
  ChCount := 0;
  P := PChar(LineText);
  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;

  while (P^ <> #0) do
  begin
    if P^ = #9 then
    begin
      TabSpace := Tw - (CurrVisCol mod Tw);
      if TabSpace = 0 then TabSpace := Tw;
      NextVisCol := CurrVisCol + TabSpace;
    end
    else
      NextVisCol := CurrVisCol + 1;

    if LocalVisCol < NextVisCol then
    begin
      if (P^ = #9) and (LocalVisCol - CurrVisCol >= NextVisCol - LocalVisCol) then
        Exit(ChCount + 1)
      else
        Exit(ChCount);
    end;

    CurrVisCol := NextVisCol;
    Inc(ChCount);
    if FUseUTF8 and (P^ <> #9) then
    begin
      cLen := UTF8CharacterLength(P);
      Inc(P, cLen);
    end
    else
      Inc(P);
  end;
  Result := ChCount;
end;

function TGrandeEditorTesto.GetCurrentVisualLineIndex: Integer;
var
  i: Integer;
  VL: TVisualLine;
  IsLastWrapOfLine: Boolean;
begin
  Result := -1;
  if not FWordWrap then
  begin
    Result := FCaretFisicoY;
    Exit;
  end;

  for i := 0 to FVisualCount - 1 do
  begin
    VL := FVisualLines[i];
    if VL.FisicaIndex = FCaretFisicoY then
    begin
      IsLastWrapOfLine := (i = FVisualCount - 1) or (FVisualLines[i + 1].FisicaIndex <> FCaretFisicoY);
      if (FCaretFisicoX + 1 >= VL.StartChar) and
         ((FCaretFisicoX + 1 < VL.StartChar + VL.Lunghezza) or
          (IsLastWrapOfLine and (FCaretFisicoX + 1 <= VL.StartChar + VL.Lunghezza)) or
          (VL.Lunghezza = 0)) then
      begin
        Result := i;
        Exit;
      end;
    end;
  end;

  if Result = -1 then
  begin
    for i := 0 to FVisualCount - 1 do
      if FVisualLines[i].FisicaIndex = FCaretFisicoY then
        Exit(i);
  end;
end;

function TGrandeEditorTesto.TrovaRangeTagAtomico(const RawLine: String; PhysX: Integer; out StartDel, EndDel: Integer): Boolean;
var
  LowerLine: String;
  ImgStart, ImgEnd, PStart, PEnd, i, RawByteLen, CharPos: Integer;
  Ch: Char;
  InTag: Boolean;
begin
  Result := False;
  StartDel := -1;
  EndDel := -1;
  RawByteLen := Length(RawLine);
  if (PhysX < 0) or (PhysX >= GetStrLength(RawLine)) then Exit;

  LowerLine := UTF8LowerCase(RawLine);

  ImgStart := UTF8Pos('<image:base64', LowerLine);
  if ImgStart > 0 then
  begin
    ImgEnd := UTF8Pos('</image:base64>', LowerLine);
    if ImgEnd > 0 then
      ImgEnd := ImgEnd + UTF8Length('</image:base64>') - 1
    else
      ImgEnd := UTF8Length(RawLine);

    if (PhysX + 1 >= ImgStart) and (PhysX + 1 <= ImgEnd) then
    begin
      StartDel := ImgStart - 1;
      EndDel := ImgEnd;
      Exit(True);
    end;
  end;

  InTag := False;
  PStart := -1;
  PEnd := -1;
  CharPos := 0;

  for i := 1 to RawByteLen do
  begin
    if not FUseUTF8 or ((Ord(RawLine[i]) and $C0) <> $80) then
      Inc(CharPos);

    Ch := RawLine[i];
    if Ch = '<' then
    begin
      InTag := True;
      PStart := CharPos - 1;
    end;
    if (Ch = '>') and InTag then
    begin
      PEnd := CharPos;
      InTag := False;
      if (PhysX >= PStart) and (PhysX < PEnd) then
      begin
        StartDel := PStart;
        EndDel := PEnd;
        Exit(True);
      end;
    end;
  end;
end;

procedure TGrandeEditorTesto.AggiornaCacheRigaSingola(RigaFisica: Integer);
var
  S: String;
  ParseRes: TLineParseResult;
  MaxCol, StrLen: Integer;
  OverlapImg: TEmbeddedImage;
  ImgStartLine: Integer;
  HasT, HasRich: Boolean;
begin
  if (RigaFisica < 0) or (RigaFisica >= FTesto.Count) then Exit;

  if Length(FLineCache) <> FTesto.Count then
    SetLength(FLineCache, FTesto.Count);

  S := FTesto[RigaFisica];
  FLineCache[RigaFisica].ByteLength := Length(S);
  HasT := Pos(#9, S) > 0;
  FLineCache[RigaFisica].HasTab := HasT;

  HasRich := FEnableRichText and ((Pos('<text:', S) + Pos('<image:', S) > 0) or
             (GetActiveOverlappingImage(RigaFisica, OverlapImg, ImgStartLine) > 0));
  FLineCache[RigaFisica].IsRich := HasRich;

  if HasRich then
  begin
    ParseRes := ParseRichTextLine(S, RigaFisica);
    StrLen := GetStrLength(ParseRes.StrippedText);
    MaxCol := StrLen;

    if Length(ParseRes.VisCols) > 0 then
      MaxCol := Max(MaxCol, ParseRes.VisCols[High(ParseRes.VisCols)] + 1);

    if ParseRes.HasImage then
      MaxCol := Max(MaxCol, ParseRes.EmbeddedImg.Col + ParseRes.EmbeddedImg.WidthCols);

    if GetActiveOverlappingImage(RigaFisica, OverlapImg, ImgStartLine) > 0 then
      MaxCol := Max(MaxCol, OverlapImg.Col + OverlapImg.WidthCols);

    FLineCache[RigaFisica].StrippedTextLen := StrLen;
    FLineCache[RigaFisica].MaxVisualCol := MaxCol;
    FLineCache[RigaFisica].HasImage := ParseRes.HasImage;
    FLineCache[RigaFisica].ImageWrap := ParseRes.EmbeddedImg.Wrap;
    FLineCache[RigaFisica].HeightRows := ParseRes.EmbeddedImg.HeightRows;
  end
  else
  begin
    StrLen := GetStrLength(S);
    if HasT then
      MaxCol := GetVisColFromPhys(StrLen, RigaFisica)
    else
      MaxCol := StrLen;
    FLineCache[RigaFisica].StrippedTextLen := StrLen;
    FLineCache[RigaFisica].MaxVisualCol := MaxCol;
    FLineCache[RigaFisica].HasImage := False;
    FLineCache[RigaFisica].ImageWrap := iwNone;
    FLineCache[RigaFisica].HeightRows := 1;
  end;
end;

procedure TGrandeEditorTesto.SnapCaretToValidPhysX;
var
  ParseRes: TLineParseResult;
  i, N: Integer;
  LineText: String;
begin
  if not FEnableRichText or (FCaretFisicoY < 0) or (FCaretFisicoY >= FTesto.Count) then Exit;
  LineText := FTesto[FCaretFisicoY];
  if (Pos('<text:', LineText) = 0) and (Pos('<image:', LineText) = 0) then Exit;

  if FCaretFisicoX <= 0 then Exit;

  ParseRes := ParseRichTextLine(LineText, FCaretFisicoY);
  N := Length(ParseRes.VisToPhys);
  if N = 0 then Exit;

  for i := 0 to N - 1 do
  begin
    if (ParseRes.VisToPhys[i] = FCaretFisicoX) or
       (ParseRes.VisToPhys[i] + 1 = FCaretFisicoX) then
      Exit;
  end;

  if FCaretFisicoX >= GetStrLength(LineText) then Exit;

  for i := 0 to N - 2 do
  begin
    if (FCaretFisicoX > ParseRes.VisToPhys[i] + 1) and
       (FCaretFisicoX < ParseRes.VisToPhys[i + 1]) then
    begin
      FCaretFisicoX := ParseRes.VisToPhys[i + 1];
      Exit;
    end;
  end;

  if FCaretFisicoX > ParseRes.VisToPhys[N - 1] + 1 then
    FCaretFisicoX := ParseRes.VisToPhys[N - 1] + 1;
end;

procedure TGrandeEditorTesto.AggiornaCacheTestoCompleto;
var
  i: Integer;
begin
  SetLength(FLineCache, FTesto.Count);
  for i := 0 to FTesto.Count - 1 do
    AggiornaCacheRigaSingola(i);
end;

function TGrandeEditorTesto.GetCachedPicture(const B64Str: String): TPicture;
var
  i: Integer;
  HashVal: PtrInt;
begin
  Result := nil;
  if B64Str = '' then Exit;

  HashVal := PtrInt(Length(B64Str));
  for i := 0 to High(FImageCache) do
  begin
    if (FImageCache[i].B64Hash = HashVal) and (FImageCache[i].B64Data = B64Str) then
      Exit(FImageCache[i].Picture);
  end;

  Result := Base64ToPicture(B64Str);

  SetLength(FImageCache, Length(FImageCache) + 1);
  FImageCache[High(FImageCache)].B64Hash := HashVal;
  FImageCache[High(FImageCache)].B64Data := B64Str;
  FImageCache[High(FImageCache)].Picture := Result;
end;

procedure TGrandeEditorTesto.PushNavHistory(PX, PY: Integer);
begin
  if (FNavIndex >= 0) and (FNavIndex < High(FNavHistory)) then
    SetLength(FNavHistory, FNavIndex + 1);

  if (FNavIndex >= 0) and (FNavHistory[FNavIndex].PhysX = PX) and (FNavHistory[FNavIndex].PhysY = PY) then
    Exit;

  Inc(FNavIndex);
  SetLength(FNavHistory, FNavIndex + 1);
  FNavHistory[FNavIndex].PhysX := PX;
  FNavHistory[FNavIndex].PhysY := PY;
end;

function TGrandeEditorTesto.CanPrev: Boolean;
begin
  Result := FNavIndex > 0;
end;

function TGrandeEditorTesto.CanNext: Boolean;
begin
  Result := (FNavIndex >= 0) and (FNavIndex < High(FNavHistory));
end;

procedure TGrandeEditorTesto.Prev;
var
  FromX, FromY, FromVL, FromVC, ToVL, ToVC: Integer;
begin
  if not CanPrev then Exit;

  FromX := FCaretFisicoX;
  FromY := FCaretFisicoY;
  FisicoToVisibileCoords(FromX, FromY, FromVL, FromVC);

  Dec(FNavIndex);
  FCaretFisicoX := FNavHistory[FNavIndex].PhysX;
  FCaretFisicoY := FNavHistory[FNavIndex].PhysY;

  FisicoToVisibileCoords(FCaretFisicoX, FCaretFisicoY, ToVL, ToVC);

  ScorriAllaRiga(FCaretFisicoY);

  if Assigned(FOnNavigate) then
    FOnNavigate(Self, FromVL + 1, FromVC + 1, ToVL + 1, ToVC + 1);

  AnnullaSelezione;
  AssicuratiCaretVisibile;
  Invalidate;
end;

procedure TGrandeEditorTesto.Next;
var
  FromX, FromY, FromVL, FromVC, ToVL, ToVC: Integer;
begin
  if not CanNext then Exit;

  FromX := FCaretFisicoX;
  FromY := FCaretFisicoY;
  FisicoToVisibileCoords(FromX, FromY, FromVL, FromVC);

  Inc(FNavIndex);
  FCaretFisicoX := FNavHistory[FNavIndex].PhysX;
  FCaretFisicoY := FNavHistory[FNavIndex].PhysY;

  FisicoToVisibileCoords(FCaretFisicoX, FCaretFisicoY, ToVL, ToVC);

  ScorriAllaRiga(FCaretFisicoY);

  if Assigned(FOnNavigate) then
    FOnNavigate(Self, FromVL + 1, FromVC + 1, ToVL + 1, ToVC + 1);

  AnnullaSelezione;
  AssicuratiCaretVisibile;
  Invalidate;
end;

procedure TGrandeEditorTesto.FisicoToVisibileCoords(PhysX, PhysY: Integer; out VisLine, VisCol: Integer);
begin
  VisLine := PhysY;
  VisCol := GetVisColFromPhys(PhysX, PhysY);
end;

procedure TGrandeEditorTesto.DoNotifyChange(PhysX, PhysY: Integer);
var
  VL, VC: Integer;
begin
  if Assigned(FOnChange) then
  begin
    FisicoToVisibileCoords(PhysX, PhysY, VL, VC);
    FOnChange(Self, VL, VC);
  end;
end;

function TGrandeEditorTesto.GetColTagContentVisLen(const RawLine: String; FromPos: Integer): Integer;
var
  PosRaw, RawLen, TagStart, TagEnd, NestLevel: Integer;
  TagContent, LowerTag: String;
begin
  Result := 0;
  RawLen := GetStrLength(RawLine);
  PosRaw := FromPos;
  NestLevel := 1;

  while (PosRaw <= RawLen) and (NestLevel > 0) do
  begin
    if UTF8Copy(RawLine, PosRaw, 1) = '<' then
    begin
      TagStart := PosRaw;
      TagEnd := PosRaw;
      while (TagEnd <= RawLen) and (UTF8Copy(RawLine, TagEnd, 1) <> '>') do
        Inc(TagEnd);

      if TagEnd <= RawLen then
      begin
        TagContent := UTF8Copy(RawLine, TagStart, TagEnd - TagStart + 1);
        LowerTag := UTF8LowerCase(TagContent);

        if (FastCharPos('<text:col', LowerTag) = 1) and (FastCharPos('value=', LowerTag) > 0) then
          Inc(NestLevel)
        else if (FastCharPos('</text:col>', LowerTag) = 1) or (LowerTag = '<text:col>') or (LowerTag = '<text:col/>') or (LowerTag = '</text:col>') then
        begin
          Dec(NestLevel);
          if NestLevel = 0 then Break;
        end;
      end;
      PosRaw := TagEnd + 1;
    end
    else
    begin
      Inc(Result);
      Inc(PosRaw);
    end;
  end;
end;

function TGrandeEditorTesto.ParseRichTextLine(const RawLine: String; LinePhysIdx: Integer): TLineParseResult;
var
  PosByte, PosChar, RawByteLen, VisCharIdx, TagStartByte, TagEndByte, bIdx, EndImgTagPos, TagCharLen: Integer;
  TagContent, LowerRaw, TargetName, ValBold, ValUnder, ValItalic, ValStrike, AlignStr, WrapStr, ImgData, ImgBlockStr: String;
  InLink, InColTag: Boolean;
  CurLink: THyperlinkSpan;
  StyleStack: array of TCharStyle;
  CurStyle: TCharStyle;
  BulletStr, LowerLine, CurrentChar: String;
  NextAutoVisCol, ColVisCol, ColVal, ContentVisLen, VisCol, ChWidth, ImgWidthPx, ImgHeightPx, CharByteLen: Integer;
  OverlapImg: TEmbeddedImage;
  ImgStartLine, TabSpace, Tw: Integer;
begin
  StyleStack := nil;
  SetLength(StyleStack, 1);
  Result := Default(TLineParseResult);

  RawByteLen := Length(RawLine);
  PosByte := 1;
  PosChar := 0;
  VisCharIdx := 0;
  NextAutoVisCol := 0;
  InLink := False;
  InColTag := False;
  ColVisCol := 0;
  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;

  if FEnableRichText and (LinePhysIdx >= 0) and (GetActiveOverlappingImage(LinePhysIdx, OverlapImg, ImgStartLine) > 0) then
  begin
    NextAutoVisCol := OverlapImg.Col + OverlapImg.WidthCols + 1;
  end;

  SetLength(StyleStack, 1);
  StyleStack[0].Style := [];
  StyleStack[0].Color := clNone;

  ChWidth := FCharWidth;
  if ChWidth <= 0 then ChWidth := 8;

  while PosByte <= RawByteLen do
  begin
    if RawLine[PosByte] = '<' then
    begin
      TagStartByte := PosByte;
      TagEndByte := PosByte;
      while (TagEndByte <= RawByteLen) and (RawLine[TagEndByte] <> '>') do
        Inc(TagEndByte);

      if TagEndByte <= RawByteLen then
      begin
        TagContent := Copy(RawLine, TagStartByte, TagEndByte - TagStartByte + 1);
        LowerRaw := UTF8LowerCase(TagContent);
        TagCharLen := GetStrLength(TagContent);

        if FastCharPos('<image:base64', LowerRaw) = 1 then
        begin
          LowerLine := UTF8LowerCase(RawLine);
          EndImgTagPos := UTF8Pos('</image:base64>', LowerLine, TagEndByte + 1);
          if EndImgTagPos = 0 then
            EndImgTagPos := RawByteLen + 1;

          ImgData := Copy(RawLine, TagEndByte + 1, EndImgTagPos - (TagEndByte + 1));

          Result.HasImage := True;
          Result.EmbeddedImg.B64Data := ImgData;
          Result.EmbeddedImg.Col := StrToIntDef(GetAttrValue(TagContent, 'col'), 0);
          Result.EmbeddedImg.WidthCols := Max(1, StrToIntDef(GetAttrValue(TagContent, 'width'), 10));

          WrapStr := UTF8LowerCase(GetAttrValue(TagContent, 'wrap'));
          if WrapStr = 'left' then
            Result.EmbeddedImg.Wrap := iwLeft
          else
            Result.EmbeddedImg.Wrap := iwNone;

          Result.EmbeddedImg.Picture := GetCachedPicture(ImgData);

          if (Result.EmbeddedImg.Picture <> nil) and (Result.EmbeddedImg.Picture.Width > 0) then
          begin
            ImgWidthPx := Result.EmbeddedImg.WidthCols * ChWidth;
            ImgHeightPx := Round(ImgWidthPx * (Result.EmbeddedImg.Picture.Height / Result.EmbeddedImg.Picture.Width));
            Result.EmbeddedImg.HeightRows := Max(1, Ceil(ImgHeightPx / FLineHeight));
          end
          else
            Result.EmbeddedImg.HeightRows := 1;

          if Result.EmbeddedImg.Wrap = iwLeft then
            NextAutoVisCol := Max(NextAutoVisCol, Result.EmbeddedImg.Col + Result.EmbeddedImg.WidthCols + 1);

          ImgBlockStr := Copy(RawLine, TagStartByte, (EndImgTagPos + Length('</image:base64>')) - TagStartByte);
          TagCharLen := GetStrLength(ImgBlockStr);

          PosByte := EndImgTagPos + Length('</image:base64>');
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if (FastCharPos('<text:a ', LowerRaw) = 1) or (FastCharPos('<text:a>', LowerRaw) = 1) then
        begin
          TargetName := GetAttrValue(TagContent, 'xlink:href');
          if (TargetName <> '') and (TargetName[1] = '#') then
            Delete(TargetName, 1, 1);

          InLink := True;
          CurLink.Target := TargetName;
          CurLink.VisStartX := VisCharIdx;
          CurLink.PhysStartX := PosChar;

          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if FastCharPos('</text:a>', LowerRaw) = 1 then
        begin
          if InLink then
          begin
            CurLink.VisEndX := VisCharIdx;
            CurLink.PhysEndX := PosChar + TagCharLen - 1;
            SetLength(Result.Links, Length(Result.Links) + 1);
            Result.Links[High(Result.Links)] := CurLink;
            InLink := False;
          end;
          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if FastCharPos('<text:style', LowerRaw) = 1 then
        begin
          CurStyle := StyleStack[High(StyleStack)];

          ValBold := UTF8LowerCase(GetAttrValue(TagContent, 'bold'));
          ValUnder := UTF8LowerCase(GetAttrValue(TagContent, 'underlined'));
          if ValUnder = '' then ValUnder := UTF8LowerCase(GetAttrValue(TagContent, 'underline'));
          ValItalic := UTF8LowerCase(GetAttrValue(TagContent, 'italic'));
          ValStrike := UTF8LowerCase(GetAttrValue(TagContent, 'strikeout'));

          if ValBold = 'true' then Include(CurStyle.Style, fsBold)
          else if ValBold = 'false' then Exclude(CurStyle.Style, fsBold);

          if ValUnder = 'true' then Include(CurStyle.Style, fsUnderline)
          else if ValUnder = 'false' then Exclude(CurStyle.Style, fsUnderline);

          if ValItalic = 'true' then Include(CurStyle.Style, fsItalic)
          else if ValItalic = 'false' then Exclude(CurStyle.Style, fsItalic);

          if ValStrike = 'true' then Include(CurStyle.Style, fsStrikeOut)
          else if ValStrike = 'false' then Exclude(CurStyle.Style, fsStrikeOut);

          SetLength(StyleStack, Length(StyleStack) + 1);
          StyleStack[High(StyleStack)] := CurStyle;

          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if FastCharPos('</text:style>', LowerRaw) = 1 then
        begin
          if Length(StyleStack) > 1 then
            SetLength(StyleStack, Length(StyleStack) - 1);

          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if (FastCharPos('<text:col', LowerRaw) = 1) and (FastCharPos('value=', LowerRaw) > 0) then
        begin
          ColVal := StrToIntDef(GetAttrValue(TagContent, 'value'), 0);
          AlignStr := UTF8LowerCase(GetAttrValue(TagContent, 'align'));
          ContentVisLen := GetColTagContentVisLen(RawLine, PosChar + TagCharLen + 1);

          if AlignStr = 'center' then
            ColVisCol := ColVal - Max(0, (ContentVisLen - 1) div 2)
          else if AlignStr = 'right' then
            ColVisCol := ColVal - ContentVisLen
          else
            ColVisCol := ColVal;

          InColTag := True;
          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if (FastCharPos('</text:col>', LowerRaw) = 1) or (LowerRaw = '<text:col>') or (LowerRaw = '<text:col/>') or (LowerRaw = '</text:col>') then
        begin
          InColTag := False;
          NextAutoVisCol := ColVisCol;
          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if FastCharPos('<text:bullet>', LowerRaw) = 1 then
        begin
          BulletStr := '• ';
          for bIdx := 1 to GetStrLength(BulletStr) do
          begin
            Result.StrippedText := Result.StrippedText + UTF8Copy(BulletStr, bIdx, 1);
            SetLength(Result.VisToPhys, VisCharIdx + 1);

            if PosChar >= Length(Result.PhysToVis) then
              SetLength(Result.PhysToVis, PosChar + 16);

            Result.VisToPhys[VisCharIdx] := PosChar;
            Result.PhysToVis[PosChar] := VisCharIdx;

            SetLength(Result.CharStyles, VisCharIdx + 1);
            Result.CharStyles[VisCharIdx] := StyleStack[High(StyleStack)];

            if InColTag then
            begin
              VisCol := ColVisCol;
              Inc(ColVisCol);
              NextAutoVisCol := ColVisCol;
            end
            else
            begin
              VisCol := NextAutoVisCol;
              Inc(NextAutoVisCol);
            end;

            SetLength(Result.VisCols, VisCharIdx + 1);
            Result.VisCols[VisCharIdx] := VisCol;

            Inc(VisCharIdx);
          end;

          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;

        if (FastCharPos('</text:bullet>', LowerRaw) = 1) or
           (FastCharPos('<text:bookmark ', LowerRaw) = 1) or
           (FastCharPos('<text:bookmark/>', LowerRaw) = 1) then
        begin
          PosByte := TagEndByte + 1;
          Inc(PosChar, TagCharLen);
          Continue;
        end;
      end;
    end;

    if FUseUTF8 then
      CharByteLen := UTF8CharacterLength(@RawLine[PosByte])
    else
      CharByteLen := 1;

    CurrentChar := Copy(RawLine, PosByte, CharByteLen);

    Result.StrippedText := Result.StrippedText + CurrentChar;
    SetLength(Result.VisToPhys, VisCharIdx + 1);
    if PosChar >= Length(Result.PhysToVis) then SetLength(Result.PhysToVis, PosChar + 16);

    Result.VisToPhys[VisCharIdx] := PosChar;
    Result.PhysToVis[PosChar] := VisCharIdx;

    SetLength(Result.CharStyles, VisCharIdx + 1);
    Result.CharStyles[VisCharIdx] := StyleStack[High(StyleStack)];

    if CurrentChar = #9 then
    begin
      if InColTag then
      begin
        VisCol := ColVisCol;
        TabSpace := Tw - (ColVisCol mod Tw);
        if TabSpace = 0 then TabSpace := Tw;
        Inc(ColVisCol, TabSpace);
        NextAutoVisCol := ColVisCol;
      end
      else
      begin
        VisCol := NextAutoVisCol;
        TabSpace := Tw - (NextAutoVisCol mod Tw);
        if TabSpace = 0 then TabSpace := Tw;
        Inc(NextAutoVisCol, TabSpace);
      end;
    end
    else
    begin
      if InColTag then
      begin
        VisCol := ColVisCol;
        Inc(ColVisCol);
        NextAutoVisCol := ColVisCol;
      end
      else
      begin
        VisCol := NextAutoVisCol;
        Inc(NextAutoVisCol);
      end;
    end;

    SetLength(Result.VisCols, VisCharIdx + 1);
    Result.VisCols[VisCharIdx] := VisCol;

    Inc(VisCharIdx);
    Inc(PosByte, CharByteLen);
    Inc(PosChar);
  end;
end;

function TGrandeEditorTesto.TrovaBookmark(const TargetName: String; out BM_X, BM_Y: Integer): Boolean;
var
  Y, PosBm: Integer;
  LineText, SearchPattern: String;
begin
  Result := False;
  BM_X := 0; BM_Y := 0;
  if TargetName = '' then Exit;

  SearchPattern := 'text:name="' + TargetName + '"';

  for Y := 0 to FTesto.Count - 1 do
  begin
    LineText := FTesto[Y];
    if Pos(TargetName, LineText) > 0 then
    begin
      PosBm := Pos(SearchPattern, LineText);
      if PosBm = 0 then
        PosBm := Pos('text:name=''' + TargetName + '''', LineText);

      if PosBm > 0 then
      begin
        BM_Y := Y;
        BM_X := GetStrLength(Copy(LineText, 1, PosBm - 1));
        Exit(True);
      end;
    end;
  end;
end;

procedure TGrandeEditorTesto.StartMacroRec;
begin
  FIsRecordingMacro := True;
  SetLength(FCurrentMacro.Events, 0);
end;

function TGrandeEditorTesto.StopMacroRec: TEditorMacro;
begin
  FIsRecordingMacro := False;
  Result := FCurrentMacro;
  SetLength(FCurrentMacro.Events, 0);
end;

procedure TGrandeEditorTesto.PlayMacro(const AMacro: TEditorMacro);
var
  i: Integer;
  Ev: TMacroEvent;
begin
  if FIsRecordingMacro or FIsPlayingMacro or (Length(AMacro.Events) = 0) then Exit;

  FIsPlayingMacro := True;
  try
    for i := 0 to High(AMacro.Events) do
    begin
      Ev := AMacro.Events[i];
      case Ev.EventType of
        meSpecialKey: KeyDown(Ev.Key, Ev.Shift);
        meUTF8Char:   UTF8KeyPress(Ev.UTF8Char);
      end;
    end;
  finally
    FIsPlayingMacro := False;
  end;
end;

function UTF8CodepointStart(UTF8Str: PChar; Len, CodepointIndex: PtrInt): PChar;
var
  CharLen: LongInt;
begin
  Result := UTF8Str;
  if Result <> nil then
  begin
    while (CodepointIndex > 0) and (Len > 0) do
    begin
      CharLen := UTF8CodepointSize(Result);
      Dec(Len, CharLen);
      Dec(CodepointIndex);
      Inc(Result, CharLen);
    end;
    if (CodepointIndex <> 0) or (Len < 0) then
      Result := nil;
  end;
end;

function TGrandeEditorTesto.UTF8Copy(const s: string; StartCharIndex, CharCount: PtrInt): string;
var
  StartBytePos: PChar;
  EndBytePos: PChar;
  MaxBytes: PtrInt;
begin
  if FUseUTF8 then
  begin
    if StartCharIndex < 1 then
      StartCharIndex := 1;
    StartBytePos := UTF8CodepointStart(PChar(s), Length(s), StartCharIndex - 1);
    if StartBytePos = nil then
      Result := ''
    else
    begin
      MaxBytes := PtrInt(PChar(s) + Length(s) - StartBytePos);
      EndBytePos := UTF8CodepointStart(StartBytePos, MaxBytes, CharCount);
      if EndBytePos <> nil then
        MaxBytes := EndBytePos - StartBytePos;
      Result := Copy(s, StartBytePos - PChar(s) + 1, MaxBytes);
    end;
  end
  else
  begin
    if CharCount > 1 then Result := Copy(s, StartCharIndex, CharCount) else Result := s[StartCharIndex];
  end;
end;

procedure TGrandeEditorTesto.CalcolaDimensioni;
begin
  if (Parent = nil) or not HandleAllocated then Exit;

  Canvas.Font.Assign(Font);
  FLineHeight := Canvas.TextHeight('Wg1|');
  if FLineHeight <= 0 then FLineHeight := 15;

  FCharWidth := Canvas.TextWidth('A');
  if FCharWidth <= 0 then FCharWidth := 8;

  FMargineNumeri := Canvas.TextWidth(IntToStr(FTesto.Count + 1)) + 15;
  if FMargineNumeri < 40 then FMargineNumeri := 40;
end;

procedure TGrandeEditorTesto.RigeneraMappaVisuale;
var
  i, LarghezzaMassimaTesto, CaratteriMax, StartCh, Len, SLen, ExtraRows, k, AllocatedCount: Integer;
  LineInfo: TLineInfoCache;
  CurP: PChar;
  ChunkBytes, cLen, Tw, CurVisSpan, TabSpace: Integer;
  CurStartByte, StartByteDelta, StartChIdx: Integer;
  S: String;
  OffsetPx, LeadingTabCols, LineOffsetPx, CurCaratteriMax: Integer;
begin
  CalcolaDimensioni;

  if Length(FLineCache) <> FTesto.Count then
    AggiornaCacheTestoCompleto;

  if not FWordWrap then
  begin
    FVisualCount := FTesto.Count;
    Exit;
  end;

  FVisualCount := 0;
  AllocatedCount := FTesto.Count * 2 + 10;
  SetLength(FVisualLines, AllocatedCount);

  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;

  for i := 0 to FTesto.Count - 1 do
  begin
    LineInfo := FLineCache[i];
    SLen := LineInfo.StrippedTextLen;

    OffsetPx := 0;
    LarghezzaMassimaTesto := ClientWidth - FMargineNumeri - FScrollBar.Width - 10 - OffsetPx;
    if LarghezzaMassimaTesto < 50 then LarghezzaMassimaTesto := 50;

    CaratteriMax := Max(1, LarghezzaMassimaTesto div FCharWidth);

    LeadingTabCols := 0;
    if FAlignWrappedTabs and LineInfo.HasTab then
      LeadingTabCols := GetLeadingTabVisCols(FTesto[i]);

    if (SLen = 0) or (LineInfo.MaxVisualCol <= CaratteriMax) then
    begin
      if FVisualCount >= AllocatedCount then
      begin
        AllocatedCount := AllocatedCount * 2 + 10;
        SetLength(FVisualLines, AllocatedCount);
      end;
      FVisualLines[FVisualCount].FisicaIndex := i;
      FVisualLines[FVisualCount].StartChar := 1;
      FVisualLines[FVisualCount].StartByte := 0;
      FVisualLines[FVisualCount].Lunghezza := SLen;
      FVisualLines[FVisualCount].ByteLen := LineInfo.ByteLength;
      FVisualLines[FVisualCount].IsFirstWrap := True;
      FVisualLines[FVisualCount].offsetX := OffsetPx;
      Inc(FVisualCount);

      if FEnableRichText and LineInfo.HasImage and (LineInfo.ImageWrap = iwNone) then
      begin
        ExtraRows := LineInfo.HeightRows - 1;
        for k := 1 to ExtraRows do
        begin
          if FVisualCount >= AllocatedCount then
          begin
            AllocatedCount := AllocatedCount * 2 + 10;
            SetLength(FVisualLines, AllocatedCount);
          end;
          FVisualLines[FVisualCount].FisicaIndex := i;
          FVisualLines[FVisualCount].StartChar := 1;
          FVisualLines[FVisualCount].StartByte := 0;
          FVisualLines[FVisualCount].Lunghezza := 0;
          FVisualLines[FVisualCount].ByteLen := 0;
          FVisualLines[FVisualCount].IsFirstWrap := False;
          FVisualLines[FVisualCount].offsetX := 0;
          Inc(FVisualCount);
        end;
      end;
    end
    else
    begin
      S := FTesto[i];
      CurP := PChar(S);
      CurStartByte := 0;
      StartCh := 1;

      while (CurP^ <> #0) and (StartCh <= SLen) do
      begin
        CurVisSpan := 0;
        ChunkBytes := 0;
        Len := 0;
        StartByteDelta := CurStartByte;
        StartChIdx := StartCh;

        if (StartChIdx = 1) or not FAlignWrappedTabs or (LeadingTabCols = 0) then
        begin
          LineOffsetPx := OffsetPx;
          CurCaratteriMax := CaratteriMax;
        end
        else
        begin
          LineOffsetPx := OffsetPx + (LeadingTabCols * FCharWidth);
          if (ClientWidth - FMargineNumeri - FScrollBar.Width - 10 - LineOffsetPx < 50) then
          begin
            LineOffsetPx := OffsetPx;
            CurCaratteriMax := CaratteriMax;
          end
          else
            CurCaratteriMax := Max(1, (ClientWidth - FMargineNumeri - FScrollBar.Width - 10 - LineOffsetPx) div FCharWidth);
        end;

        while (CurP^ <> #0) do
        begin
          if CurP^ = #9 then
          begin
            TabSpace := Tw - (CurVisSpan mod Tw);
            if TabSpace = 0 then TabSpace := Tw;
            if (CurVisSpan + TabSpace > CurCaratteriMax) and (Len > 0) then Break;
            Inc(CurVisSpan, TabSpace);
            Inc(ChunkBytes);
            Inc(CurP);
          end
          else
          begin
            if FUseUTF8 then
              cLen := UTF8CharacterLength(CurP)
            else
              cLen := 1;

            if (CurVisSpan + 1 > CurCaratteriMax) and (Len > 0) then Break;
            Inc(CurVisSpan);
            Inc(ChunkBytes, cLen);
            Inc(CurP, cLen);
          end;
          Inc(Len);
        end;

        if Len = 0 then
        begin
          if FUseUTF8 then cLen := UTF8CharacterLength(CurP) else cLen := 1;
          Inc(ChunkBytes, cLen);
          Inc(CurP, cLen);
          Len := 1;
        end;

        if FVisualCount >= AllocatedCount then
        begin
          AllocatedCount := AllocatedCount * 2 + 10;
          SetLength(FVisualLines, AllocatedCount);
        end;

        FVisualLines[FVisualCount].FisicaIndex := i;
        FVisualLines[FVisualCount].StartChar := StartChIdx;
        FVisualLines[FVisualCount].StartByte := StartByteDelta;
        FVisualLines[FVisualCount].Lunghezza := Len;
        FVisualLines[FVisualCount].ByteLen := ChunkBytes;
        FVisualLines[FVisualCount].IsFirstWrap := (StartChIdx = 1);
        FVisualLines[FVisualCount].offsetX := LineOffsetPx;
        Inc(FVisualCount);

        Inc(CurStartByte, ChunkBytes);
        Inc(StartCh, Len);
      end;
    end;
  end;
  SetLength(FVisualLines, FVisualCount);
end;

procedure TGrandeEditorTesto.AggiornaMappaRigaSingola(RigaFisica: Integer);
var
  i, SLen, StartCh, CaratteriMax, LarghezzaMassimaTesto, Tw: Integer;
  S: String;
  CurP: PChar;
  CurStartByte, ChunkBytes, Len, cLen, CurVisSpan, TabSpace: Integer;
  OldLineCount, NewLineCount: Integer;
  FirstVIdx, StartByteDelta, StartChIdx: Integer;
  NewVLines: array of TVisualLine;
  LeadingTabCols, LineOffsetPx, CurCaratteriMax: Integer;
begin
  if not FWordWrap then Exit;

  S := FTesto[RigaFisica];
  SLen := GetStrLength(S);

  FirstVIdx := -1;
  OldLineCount := 0;
  for i := 0 to FVisualCount - 1 do
  begin
    if FVisualLines[i].FisicaIndex = RigaFisica then
    begin
      if FirstVIdx = -1 then FirstVIdx := i;
      Inc(OldLineCount);
    end
    else if FirstVIdx <> -1 then
      Break;
  end;

  if FirstVIdx = -1 then
  begin
    AggiornaScrollBar;
    Exit;
  end;

  LarghezzaMassimaTesto := ClientWidth - FMargineNumeri - FScrollBar.Width - 10;
  if LarghezzaMassimaTesto < 50 then LarghezzaMassimaTesto := 50;
  CaratteriMax := Max(1, LarghezzaMassimaTesto div FCharWidth);

  Tw := FTabWidth;
  if Tw < 1 then Tw := 2;

  LeadingTabCols := 0;
  if FAlignWrappedTabs and FLineCache[RigaFisica].HasTab then
    LeadingTabCols := GetLeadingTabVisCols(S);

  SetLength(NewVLines, 0);

  if (S = '') or (FLineCache[RigaFisica].MaxVisualCol <= CaratteriMax) then
  begin
    SetLength(NewVLines, 1);
    NewVLines[0].FisicaIndex := RigaFisica;
    NewVLines[0].StartChar := 1;
    NewVLines[0].StartByte := 0;
    NewVLines[0].Lunghezza := SLen;
    NewVLines[0].ByteLen := Length(S);
    NewVLines[0].IsFirstWrap := True;
    NewVLines[0].offsetX := 0;
  end
  else
  begin
    CurP := PChar(S);
    CurStartByte := 0;
    StartCh := 1;

    while (CurP^ <> #0) and (StartCh <= SLen) do
    begin
      CurVisSpan := 0;
      ChunkBytes := 0;
      Len := 0;
      StartByteDelta := CurStartByte;
      StartChIdx := StartCh;

      if (StartChIdx = 1) or not FAlignWrappedTabs or (LeadingTabCols = 0) then
      begin
        LineOffsetPx := 0;
        CurCaratteriMax := CaratteriMax;
      end
      else
      begin
        LineOffsetPx := LeadingTabCols * FCharWidth;
        if (ClientWidth - FMargineNumeri - FScrollBar.Width - 10 - LineOffsetPx < 50) then
        begin
          LineOffsetPx := 0;
          CurCaratteriMax := CaratteriMax;
        end
        else
          CurCaratteriMax := Max(1, (ClientWidth - FMargineNumeri - FScrollBar.Width - 10 - LineOffsetPx) div FCharWidth);
      end;

      while (CurP^ <> #0) do
      begin
        if CurP^ = #9 then
        begin
          TabSpace := Tw - (CurVisSpan mod Tw);
          if TabSpace = 0 then TabSpace := Tw;
          if (CurVisSpan + TabSpace > CurCaratteriMax) and (Len > 0) then Break;
          Inc(CurVisSpan, TabSpace);
          Inc(ChunkBytes);
          Inc(CurP);
        end
        else
        begin
          if FUseUTF8 then
            cLen := UTF8CharacterLength(CurP)
          else
            cLen := 1;

          if (CurVisSpan + 1 > CurCaratteriMax) and (Len > 0) then Break;
          Inc(CurVisSpan);
          Inc(ChunkBytes, cLen);
          Inc(CurP, cLen);
        end;
        Inc(Len);
      end;

      if Len = 0 then
      begin
        if FUseUTF8 then cLen := UTF8CharacterLength(CurP) else cLen := 1;
        Inc(ChunkBytes, cLen);
        Inc(CurP, cLen);
        Len := 1;
      end;

      SetLength(NewVLines, Length(NewVLines) + 1);
      NewVLines[High(NewVLines)].FisicaIndex := RigaFisica;
      NewVLines[High(NewVLines)].StartChar := StartChIdx;
      NewVLines[High(NewVLines)].StartByte := StartByteDelta;
      NewVLines[High(NewVLines)].Lunghezza := Len;
      NewVLines[High(NewVLines)].ByteLen := ChunkBytes;
      NewVLines[High(NewVLines)].IsFirstWrap := (StartChIdx = 1);
      NewVLines[High(NewVLines)].offsetX := LineOffsetPx;

      Inc(CurStartByte, ChunkBytes);
      Inc(StartCh, Len);
    end;
  end;

  NewLineCount := Length(NewVLines);

  if OldLineCount = NewLineCount then
  begin
    for i := 0 to NewLineCount - 1 do
      FVisualLines[FirstVIdx + i] := NewVLines[i];
  end
  else
  begin
    AggiornaScrollBar;
  end;
end;

function TGrandeEditorTesto.MaxTopLine: Integer;
var
  RigheVisibili, HBarHeight: Integer;
begin
  HBarHeight := 0;
  if not FWordWrap then HBarHeight := FHScrollBar.Height;
  RigheVisibili := Max(1, ((ClientHeight - HBarHeight) div FLineHeight) - 1);
  Result := Max(0, FVisualCount - RigheVisibili);
end;

procedure TGrandeEditorTesto.AggiornaScrollBar;
var
  RigheVisibili, CaratteriVisibili, MaxLen, i, L, HBarHeight, VBarWidth: Integer;
begin
  if (Parent = nil) or not HandleAllocated then Exit;

  RigeneraMappaVisuale;

  FHScrollBar.Visible := not FWordWrap;

  if FHScrollBar.Visible then
    HBarHeight := FHScrollBar.Height
  else
    HBarHeight := 0;

  VBarWidth := FScrollBar.Width;

  FScrollBar.Left := ClientWidth - VBarWidth;
  FScrollBar.Top := 0;
  FScrollBar.Height := Max(0, ClientHeight - HBarHeight);

  FHScrollBar.Left := FMargineNumeri;
  FHScrollBar.Top := ClientHeight - HBarHeight;
  FHScrollBar.Width := Max(0, ClientWidth - FMargineNumeri - VBarWidth);

  RigheVisibili := Max(1, ((ClientHeight - HBarHeight) div FLineHeight) - 1);

  FScrollBar.Min := 0;
  FScrollBar.Max := Max(0, FVisualCount - 1);
  FScrollBar.PageSize := RigheVisibili;

  if FTopLine > MaxTopLine then
    FTopLine := MaxTopLine;

  FScrollBar.Position := FTopLine;

  if not FWordWrap then
  begin
    MaxLen := 0;
    for i := 0 to High(FLineCache) do
    begin
      L := FLineCache[i].MaxVisualCol;
      if L > MaxLen then MaxLen := L;
    end;

    CaratteriVisibili := Max(1, (FHScrollBar.Width - 10) div FCharWidth);

    FHScrollBar.Min := 0;
    FHScrollBar.Max := Max(CaratteriVisibili, MaxLen);
    FHScrollBar.PageSize := CaratteriVisibili;

    if FLeftCol > Max(0, MaxLen - CaratteriVisibili) then
      FLeftCol := Max(0, MaxLen - CaratteriVisibili);

    FHScrollBar.Position := FLeftCol;
  end
  else
    FLeftCol := 0;
end;

procedure TGrandeEditorTesto.AssicuratiCaretVisibile;
var
  CaratteriVisibili, ChWidth, HBarHeight, RigheVisibili, CaretVIndex, CaretVisCol: Integer;
begin
  if (Parent = nil) or not HandleAllocated then Exit;

  HBarHeight := 0;
  if not FWordWrap then HBarHeight := FHScrollBar.Height;

  RigheVisibili := Max(1, (ClientHeight - HBarHeight) div FLineHeight);

  CaretVIndex := GetCurrentVisualLineIndex;

  if CaretVIndex >= 0 then
  begin
    if CaretVIndex < FTopLine then
    begin
      FTopLine := CaretVIndex;
      FTopLine := EnsureRange(FTopLine, 0, MaxTopLine);
      FScrollBar.Position := FTopLine;
    end
    else if CaretVIndex >= FTopLine + RigheVisibili then
    begin
      FTopLine := CaretVIndex - RigheVisibili + 1;
      FTopLine := EnsureRange(FTopLine, 0, MaxTopLine);
      FScrollBar.Position := FTopLine;
    end;
  end;

  if not FWordWrap then
  begin
    ChWidth := FCharWidth;
    if ChWidth <= 0 then ChWidth := 8;

    CaratteriVisibili := Max(1, (ClientWidth - FMargineNumeri - FScrollBar.Width - 10) div ChWidth);
    CaretVisCol := GetVisColFromPhys(FCaretFisicoX, FCaretFisicoY);

    if CaretVisCol < FLeftCol then
    begin
      FLeftCol := CaretVisCol;
      FHScrollBar.Position := FLeftCol;
    end
    else if CaretVisCol >= FLeftCol + CaratteriVisibili then
    begin
      FLeftCol := CaretVisCol - CaratteriVisibili + 1;
      FHScrollBar.Position := FLeftCol;
    end;
  end;
end;

function TGrandeEditorTesto.CercaInRiga(const LineText, SearchText: String; const AOptions: TSearchOptions): TMatchArray;
var
  PrepLine, PrepSearch, Pattern: String;
  StartPos, FoundPos, MatchX, SearchCharLen, LineCharLen: Integer;
  IsWordOk, LeftOk, RightOk: Boolean;
  Regex: TRegExpr;
  ByteStart, ByteLen, MatchLen: Integer;
begin
  SetLength(Result, 0);
  if (LineText = '') or (SearchText = '') then Exit;

  PrepLine := LineText;
  PrepSearch := SearchText;
  if not FUseUTF8 then PrepLine := UTF8To1byteCod(PrepLine);
  if not FUseUTF8 then PrepSearch := UTF8To1byteCod(PrepSearch);

  if not AOptions.MatchDiacritics then
  begin
    PrepLine := RimuoviAccenti(PrepLine);
    PrepSearch := RimuoviAccenti(PrepSearch);
  end;

  if not AOptions.CaseSensitive then
  begin
    if FUseUTF8 then
    begin
      PrepLine := UTF8LowerCase(PrepLine);
      PrepSearch := UTF8LowerCase(PrepSearch);
    end
    else
    begin
      PrepLine := LowerCase(PrepLine);
      PrepSearch := LowerCase(PrepSearch);
    end;
  end;

  if AOptions.SearchType = stText then
  begin
    StartPos := 1;
    LineCharLen := GetStrLength(PrepLine);
    SearchCharLen := GetStrLength(PrepSearch);

    while StartPos <= LineCharLen - SearchCharLen + 1 do
    begin
      FoundPos := FastCharPos(PrepSearch, PrepLine, StartPos);
      if FoundPos = 0 then Break;

      MatchX := FoundPos - 1;
      IsWordOk := True;

      if AOptions.WholeWord then
      begin
        LeftOk := (MatchX = 0) or not IsWordChar(UTF8Copy(LineText, MatchX, 1));
        RightOk := (MatchX + SearchCharLen >= GetStrLength(LineText)) or not IsWordChar(UTF8Copy(LineText, MatchX + SearchCharLen + 1, 1));
        IsWordOk := LeftOk and RightOk;
      end;

      if IsWordOk then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)].CharX := MatchX;
        Result[High(Result)].CharLen := SearchCharLen;
      end;

      StartPos := FoundPos + 1;
    end;
  end
  else
  begin
    if AOptions.SearchType = stWildcard then
      Pattern := WildcardToRegEx(PrepSearch, FUseUTF8)
    else
      Pattern := PrepSearch;

    Regex := TRegExpr.Create;
    try
      Regex.ModifierI := False;
      Regex.Expression := Pattern;
      try
        if Regex.Exec(PrepLine) then
        repeat
          ByteStart := Regex.MatchPos[0];
          ByteLen := Regex.MatchLen[0];

          if (ByteStart > 0) and (ByteLen > 0) then
          begin
            MatchX := GetStrLength(Copy(PrepLine, 1, ByteStart - 1));
            MatchLen := GetStrLength(Copy(PrepLine, ByteStart, ByteLen));

            IsWordOk := True;
            if AOptions.WholeWord then
            begin
              LeftOk := (MatchX = 0) or not IsWordChar(UTF8Copy(LineText, MatchX, 1));
              RightOk := (MatchX + MatchLen >= GetStrLength(LineText)) or not IsWordChar(UTF8Copy(LineText, MatchX + MatchLen + 1, 1));
              IsWordOk := LeftOk and RightOk;
            end;

            if IsWordOk then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[High(Result)].CharX := MatchX;
              Result[High(Result)].CharLen := MatchLen;
            end;
          end;
        until not Regex.ExecNext;
      except
      end;
    finally
      Regex.Free;
    end;
  end;
end;

function TGrandeEditorTesto.EvidenziaTutti(const ASearchText: String; const AOptions: TSearchOptions; AColor: TColor): Integer;
var
  i, FoundOpIdx: Integer;
  NewOp: TSearchOperation;
begin
  Result := 0;

  if AOptions.removeOlder then
    AnnullaEvidenziazioneRicerca;

  if ASearchText = '' then Exit;

  FoundOpIdx := -1;
  for i := 0 to High(FSearchOperations) do
  begin
    if (FSearchOperations[i].SearchText = ASearchText) and
       (FSearchOperations[i].Options.SearchType = AOptions.SearchType) and
       (FSearchOperations[i].Options.CaseSensitive = AOptions.CaseSensitive) and
       (FSearchOperations[i].Options.WholeWord = AOptions.WholeWord) and
       (FSearchOperations[i].Options.MatchDiacritics = AOptions.MatchDiacritics) then
    begin
      FoundOpIdx := i;
      Break;
    end;
  end;

  if FoundOpIdx >= 0 then
  begin
    if FSearchOperations[FoundOpIdx].Color <> AColor then
    begin
      FSearchOperations[FoundOpIdx].Color := AColor;
      Invalidate;
    end;
    Exit(FSearchOperations[FoundOpIdx].ID);
  end;

  Inc(FNextOpID);
  SetLength(FSearchOperations, Length(FSearchOperations) + 1);
  NewOp.ID := FNextOpID;
  NewOp.SearchText := ASearchText;
  NewOp.Options := AOptions;
  NewOp.Color := AColor;
  NewOp.MatchCount := 0;
  FSearchOperations[High(FSearchOperations)] := NewOp;

  Invalidate;
  Result := FNextOpID;
end;

procedure TGrandeEditorTesto.AnnullaEvidenzia(AOpID: Integer);
var
  i, WriteIdx: Integer;
begin
  if AOpID <= 0 then Exit;

  WriteIdx := 0;
  for i := 0 to High(FSearchOperations) do
  begin
    if FSearchOperations[i].ID <> AOpID then
    begin
      if WriteIdx <> i then
        FSearchOperations[WriteIdx] := FSearchOperations[i];
      Inc(WriteIdx);
    end;
  end;
  SetLength(FSearchOperations, WriteIdx);

  Invalidate;
end;

procedure TGrandeEditorTesto.AnnullaEvidenziazioneRicerca;
begin
  SetLength(FEvidenziazioni, 0);
  SetLength(FSearchOperations, 0);
  FNextOpID := 0;
  Invalidate;
end;

function TGrandeEditorTesto.TrovaProssimo(const ASearchText: String; const AOptions: TSearchOptions; DaInizio: Boolean): Boolean;
var
  StartY, StartX, Y, i: Integer;
  Matches: TMatchArray;
  M: TMatchResult;
begin
  Result := False;
  if ASearchText = '' then Exit;

  if DaInizio then
  begin
    StartY := 0;
    StartX := 0;
  end
  else
  begin
    StartY := FCaretFisicoY;
    StartX := FCaretFisicoX;
  end;

  for Y := StartY to FTesto.Count - 1 do
  begin
    Matches := CercaInRiga(FTesto[Y], ASearchText, AOptions);
    for i := 0 to High(Matches) do
    begin
      M := Matches[i];
      if (Y > StartY) or (M.CharX >= StartX) then
      begin
        FCaretFisicoX := M.CharX + M.CharLen;
        FCaretFisicoY := Y;

        FSelStartX := M.CharX;
        FSelStartY := Y;
        FSelEndX := M.CharX + M.CharLen;
        FSelEndY := Y;

        AggiornaScrollBar;
        AssicuratiCaretVisibile;
        Invalidate;
        Exit(True);
      end;
    end;
  end;
end;

function TGrandeEditorTesto.TrovaPrecedente(const ASearchText: String; const AOptions: TSearchOptions): Boolean;
var
  StartY, StartX, Y, i: Integer;
  Matches: TMatchArray;
  M: TMatchResult;
begin
  Result := False;
  if ASearchText = '' then Exit;

  StartY := FCaretFisicoY;
  StartX := FCaretFisicoX;

  if HaSelezione then
    StartX := FSelStartX;

  for Y := StartY downto 0 do
  begin
    Matches := CercaInRiga(FTesto[Y], ASearchText, AOptions);
    for i := High(Matches) downto 0 do
    begin
      M := Matches[i];
      if (Y < StartY) or (M.CharX < StartX) then
      begin
        FCaretFisicoX := M.CharX;
        FCaretFisicoY := Y;

        FSelStartX := M.CharX;
        FSelStartY := Y;
        FSelEndX := M.CharX + M.CharLen;
        FSelEndY := Y;

        AggiornaScrollBar;
        AssicuratiCaretVisibile;
        Invalidate;
        Exit(True);
      end;
    end;
  end;
end;

function TGrandeEditorTesto.NuovoGroupID: Integer;
begin
  Inc(FNextGroupID);
  Result := FNextGroupID;
end;

procedure TGrandeEditorTesto.ClearRedo;
begin
  SetLength(FRedoList, 0);
end;

procedure TGrandeEditorTesto.AzzeraUndoRedo;
begin
  SetLength(FUndoList, 0);
  SetLength(FRedoList, 0);
end;

function TGrandeEditorTesto.PuoAnnullare: Boolean;
begin
  Result := Length(FUndoList) > 0;
end;

function TGrandeEditorTesto.PuoRipristinare: Boolean;
begin
  Result := Length(FRedoList) > 0;
end;

procedure TGrandeEditorTesto.AddUndoItem(const AItem: TUndoItem);
begin
  SetLength(FUndoList, Length(FUndoList) + 1);
  FUndoList[High(FUndoList)] := AItem;

  if Length(FUndoList) > FMaxUndoLevel then
    Delete(FUndoList, 0, 1);
end;

procedure TGrandeEditorTesto.RecordInsert(FX, FY: Integer; const AText: String; CaretBeforeX, CaretBeforeY, CaretAfterX, CaretAfterY, GroupID: Integer);
var
  Item: TUndoItem;
  LastIdx: Integer;
begin
  if FIsPerformingUndoRedo or (AText = '') then Exit;

  ClearRedo;

  LastIdx := High(FUndoList);
  if (LastIdx >= 0) and (GroupID = 0) and (FUndoList[LastIdx].GroupID = 0) and
     (FUndoList[LastIdx].OpType = uoInsert) and
     (FUndoList[LastIdx].FisicoY = FY) and
     (FUndoList[LastIdx].FisicoX + GetStrLength(FUndoList[LastIdx].Text) = FX) and
     (Pos(#10, AText) = 0) and (Pos(#13, AText) = 0) and
     (AText <> ' ') and (AText <> #9) and
     (FUndoList[LastIdx].Text[Length(FUndoList[LastIdx].Text)] <> ' ') and
     (FUndoList[LastIdx].Text[Length(FUndoList[LastIdx].Text)] <> #9) then
  begin
    FUndoList[LastIdx].Text := FUndoList[LastIdx].Text + AText;
    FUndoList[LastIdx].CaretAfterX := CaretAfterX;
    FUndoList[LastIdx].CaretAfterY := CaretAfterY;
    Exit;
  end;

  Item.OpType := uoInsert;
  Item.FisicoX := FX;
  Item.FisicoY := FY;
  Item.Text := AText;
  Item.CaretBeforeX := CaretBeforeX;
  Item.CaretBeforeY := CaretBeforeY;
  Item.CaretAfterX := CaretAfterX;
  Item.CaretAfterY := CaretAfterY;
  Item.GroupID := GroupID;

  AddUndoItem(Item);
end;

procedure TGrandeEditorTesto.RecordDelete(FX, FY: Integer; const AText: String; CaretBeforeX, CaretBeforeY, CaretAfterX, CaretAfterY, GroupID: Integer);
var
  Item: TUndoItem;
begin
  if FIsPerformingUndoRedo or (AText = '') then Exit;

  ClearRedo;

  Item.OpType := uoDelete;
  Item.FisicoX := FX;
  Item.FisicoY := FY;
  Item.Text := AText;
  Item.CaretBeforeX := CaretBeforeX;
  Item.CaretBeforeY := CaretBeforeY;
  Item.CaretAfterX := CaretAfterX;
  Item.CaretAfterY := CaretAfterY;
  Item.GroupID := GroupID;

  AddUndoItem(Item);
end;

procedure TGrandeEditorTesto.CalcolaFineTesto(StartX, StartY: Integer; const AText: String; out EndX, EndY: Integer);
var
  Lines: TStringList;
begin
  if (Pos(#10, AText) = 0) and (Pos(#13, AText) = 0) then
  begin
    EndX := StartX + GetStrLength(AText);
    EndY := StartY;
  end
  else
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := AText;
      EndY := StartY + Lines.Count - 1;
      if Lines.Count = 1 then
        EndX := StartX + GetStrLength(Lines[0])
      else
        EndX := GetStrLength(Lines[Lines.Count - 1]);
    finally
      Lines.Free;
    end;
  end;
end;

procedure TGrandeEditorTesto.InsertTextFisico(AX, AY: Integer; const AText: String);
var
  i, OldLen, NewLen, CaratteriMax, LarghezzaMassimaTesto: Integer;
  OldVisCount, NewVisCount: Integer;
  S, LeftStr, RightStr: String;
  InsPos, SLen, PosStart, PosEnd, LineCount: Integer;
  LinesArr: array of String;
  ByteOffset: Integer;
begin
  if AText = '' then Exit;
  if AY >= FTesto.Count then AY := FTesto.Count - 1;
  if AY < 0 then AY := 0;

  Inc(FByteSize, Length(AText));

  FTesto.OnChange := nil;
  try
    if (Pos(#10, AText) = 0) and (Pos(#13, AText) = 0) then
    begin
      S := FTesto[AY];
      OldLen := GetStrLength(S);

      ByteOffset := CharIndexToByteOffset(S, AX);
      Insert(AText, S, ByteOffset + 1);

      NewLen := OldLen + GetStrLength(AText);

      LarghezzaMassimaTesto := ClientWidth - FMargineNumeri - FScrollBar.Width - 10;
      if LarghezzaMassimaTesto < 50 then LarghezzaMassimaTesto := 50;
      CaratteriMax := Max(1, LarghezzaMassimaTesto div FCharWidth);

      if (not FWordWrap) or (OldLen = 0) then
      begin
        OldVisCount := 1;
        NewVisCount := 1;
      end
      else
      begin
        OldVisCount := (OldLen - 1) div CaratteriMax + 1;
        NewVisCount := (NewLen - 1) div CaratteriMax + 1;
      end;

      FTesto[AY] := S;
      AggiornaCacheRigaSingola(AY);

      if OldVisCount = NewVisCount then
        AggiornaMappaRigaSingola(AY)
      else
        AggiornaScrollBar;
    end
    else
    begin
      SLen := Length(AText);
      PosStart := 1;
      LineCount := 0;
      SetLength(LinesArr, 10);

      while PosStart <= SLen do
      begin
        PosEnd := PosStart;
        while (PosEnd <= SLen) and (AText[PosEnd] <> #10) and (AText[PosEnd] <> #13) do
          Inc(PosEnd);

        if LineCount >= Length(LinesArr) then
          SetLength(LinesArr, LineCount * 2);

        LinesArr[LineCount] := Copy(AText, PosStart, PosEnd - PosStart);
        Inc(LineCount);

        if (PosEnd <= SLen) and (AText[PosEnd] = #13) then Inc(PosEnd);
        if (PosEnd <= SLen) and (AText[PosEnd] = #10) then Inc(PosEnd);

        PosStart := PosEnd;
      end;

      if (SLen > 0) and ((AText[SLen] = #10) or (AText[SLen] = #13)) then
      begin
        if LineCount >= Length(LinesArr) then
          SetLength(LinesArr, LineCount + 1);
        LinesArr[LineCount] := '';
        Inc(LineCount);
      end;

      S := FTesto[AY];
      ByteOffset := CharIndexToByteOffset(S, AX);
      LeftStr := Copy(S, 1, ByteOffset);
      RightStr := Copy(S, ByteOffset + 1, Length(S) - ByteOffset);

      FTesto[AY] := LeftStr + LinesArr[0];

      for i := 1 to LineCount - 2 do
        FTesto.Insert(AY + i, LinesArr[i]);

      FTesto.Insert(AY + LineCount - 1, LinesArr[LineCount - 1] + RightStr);

      SetLength(FLineCache, FTesto.Count);
      if (FTesto.Count - AY - LineCount > 0) then
        Move(FLineCache[AY + 1], FLineCache[AY + LineCount], (FTesto.Count - AY - LineCount) * SizeOf(TLineInfoCache));

      for i := 0 to LineCount - 1 do
        AggiornaCacheRigaSingola(AY + i);

      AggiornaScrollBar;
    end;
  finally
    FTesto.OnChange := @RigheCambiate;
  end;

  if Length(FEvidenziazioni) > 0 then
  begin
    InsPos := FisicoToPosAssoluta(AX, AY);
    AggiornaEvidenziazioniSuInserimento(InsPos, GetStrLength(AText));
  end;
end;

function TGrandeEditorTesto.DeleteTextFisico(StartX, StartY, EndX, EndY: Integer): String;
var
  i, OldLen, NewLen, CaratteriMax, LarghezzaMassimaTesto: Integer;
  OldVisCount, NewVisCount: Integer;
  StartStr, EndStr, NewStr: String;
  DelPos, StartByteOff, EndByteOff: Integer;
  LinesDeleted: Integer;
begin
  Result := '';

  if (FTesto.Count = 0) or (StartY < 0) or (StartY >= FTesto.Count) then Exit;
  EndY := EnsureRange(EndY, StartY, FTesto.Count - 1);
  if (StartY = EndY) and (StartX >= EndX) then Exit;

  FTesto.OnChange := nil;
  try
    if StartY = EndY then
    begin
      OldLen := GetStrLength(FTesto[StartY]);
      StartX := EnsureRange(StartX, 0, OldLen);
      EndX := EnsureRange(EndX, StartX, OldLen);
      if StartX = EndX then Exit;

      StartByteOff := CharIndexToByteOffset(FTesto[StartY], StartX);
      EndByteOff := CharIndexToByteOffset(FTesto[StartY], EndX);

      Result := Copy(FTesto[StartY], StartByteOff + 1, EndByteOff - StartByteOff);
      StartStr := Copy(FTesto[StartY], 1, StartByteOff);
      EndStr := Copy(FTesto[StartY], EndByteOff + 1, Length(FTesto[StartY]) - EndByteOff);
      NewStr := StartStr + EndStr;
      NewLen := GetStrLength(NewStr);

      FTesto[StartY] := NewStr;
      AggiornaCacheRigaSingola(StartY);

      if not FWordWrap then
      begin
        AggiornaMappaRigaSingola(StartY);
      end
      else
      begin
        LarghezzaMassimaTesto := ClientWidth - FMargineNumeri - FScrollBar.Width - 10;
        if LarghezzaMassimaTesto < 50 then LarghezzaMassimaTesto := 50;
        CaratteriMax := Max(1, LarghezzaMassimaTesto div FCharWidth);

        if OldLen = 0 then OldVisCount := 1 else OldVisCount := (OldLen - 1) div CaratteriMax + 1;
        if NewLen = 0 then NewVisCount := 1 else NewVisCount := (NewLen - 1) div CaratteriMax + 1;

        if (OldVisCount = NewVisCount) and (NewLen > 0) then
          AggiornaMappaRigaSingola(StartY)
        else
          AggiornaScrollBar;
      end;
    end
    else
    begin
      StartX := EnsureRange(StartX, 0, GetStrLength(FTesto[StartY]));
      EndX := EnsureRange(EndX, 0, GetStrLength(FTesto[EndY]));

      StartByteOff := CharIndexToByteOffset(FTesto[StartY], StartX);
      EndByteOff := CharIndexToByteOffset(FTesto[EndY], EndX);

      Result := Copy(FTesto[StartY], StartByteOff + 1, Length(FTesto[StartY]) - StartByteOff) + sLineBreak;
      for i := StartY + 1 to EndY - 1 do
        Result := Result + FTesto[i] + sLineBreak;
      Result := Result + Copy(FTesto[EndY], 1, EndByteOff);

      StartStr := Copy(FTesto[StartY], 1, StartByteOff);
      EndStr := Copy(FTesto[EndY], EndByteOff + 1, Length(FTesto[EndY]) - EndByteOff);

      LinesDeleted := EndY - StartY;
      for i := EndY downto StartY + 1 do
        FTesto.Delete(i);

      FTesto[StartY] := StartStr + EndStr;

      if Length(FLineCache) = FTesto.Count + LinesDeleted then
      begin
        if EndY + 1 < Length(FLineCache) then
          Move(FLineCache[EndY + 1], FLineCache[StartY + 1],
               (Length(FLineCache) - (EndY + 1)) * SizeOf(TLineInfoCache));
        SetLength(FLineCache, FTesto.Count);
      end
      else
        SetLength(FLineCache, FTesto.Count);

      AggiornaCacheRigaSingola(StartY);
      AggiornaScrollBar;
    end;

    Dec(FByteSize, Length(Result));

    if Length(FEvidenziazioni) > 0 then
    begin
      DelPos := FisicoToPosAssoluta(StartX, StartY);
      AggiornaEvidenziazioniSuCancellazione(DelPos, GetStrLength(Result));
    end;
  finally
    FTesto.OnChange := @RigheCambiate;
  end;
end;

procedure TGrandeEditorTesto.Undo;
var
  TargetGroup, LastIdx, EndX, EndY: Integer;
  Item, RedoItem: TUndoItem;
begin
  if not PuoAnnullare or FReadOnly then Exit;

  FIsPerformingUndoRedo := True;
  try
    LastIdx := High(FUndoList);
    TargetGroup := FUndoList[LastIdx].GroupID;

    while (LastIdx >= 0) and
          (((TargetGroup <> 0) and (FUndoList[LastIdx].GroupID = TargetGroup)) or
           ((TargetGroup = 0) and (LastIdx = High(FUndoList)))) do
    begin
      Item := FUndoList[LastIdx];
      RedoItem := Item;

      if Item.OpType = uoInsert then
      begin
        CalcolaFineTesto(Item.FisicoX, Item.FisicoY, Item.Text, EndX, EndY);
        DeleteTextFisico(Item.FisicoX, Item.FisicoY, EndX, EndY);
      end
      else
      begin
        InsertTextFisico(Item.FisicoX, Item.FisicoY, Item.Text);
      end;

      SetLength(FRedoList, Length(FRedoList) + 1);
      FRedoList[High(FRedoList)] := RedoItem;

      FCaretFisicoX := Item.CaretBeforeX;
      FCaretFisicoY := Item.CaretBeforeY;

      SetLength(FUndoList, LastIdx);
      Dec(LastIdx);

      if TargetGroup = 0 then Break;
    end;

    AnnullaSelezione;
    AggiornaScrollBar;
    AssicuratiCaretVisibile;
    DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
    Repaint;
  finally
    FIsPerformingUndoRedo := False;
  end;
end;

procedure TGrandeEditorTesto.Redo;
var
  TargetGroup, LastIdx, EndX, EndY: Integer;
  Item, UndoItem: TUndoItem;
begin
  if not PuoRipristinare or FReadOnly then Exit;

  FIsPerformingUndoRedo := True;
  try
    LastIdx := High(FRedoList);
    TargetGroup := FRedoList[LastIdx].GroupID;

    while (LastIdx >= 0) and
          (((TargetGroup <> 0) and (FRedoList[LastIdx].GroupID = TargetGroup)) or
           ((TargetGroup = 0) and (LastIdx = High(FRedoList)))) do
    begin
      Item := FRedoList[LastIdx];
      UndoItem := Item;

      if Item.OpType = uoInsert then
      begin
        InsertTextFisico(Item.FisicoX, Item.FisicoY, Item.Text);
      end
      else
      begin
        CalcolaFineTesto(Item.FisicoX, Item.FisicoY, Item.Text, EndX, EndY);
        DeleteTextFisico(Item.FisicoX, Item.FisicoY, EndX, EndY);
      end;

      AddUndoItem(UndoItem);

      FCaretFisicoX := Item.CaretAfterX;
      FCaretFisicoY := Item.CaretAfterY;

      SetLength(FRedoList, LastIdx);
      Dec(LastIdx);

      if TargetGroup = 0 then Break;
    end;

    AnnullaSelezione;
    AggiornaScrollBar;
    AssicuratiCaretVisibile;
    DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
    Repaint;
  finally
    FIsPerformingUndoRedo := False;
  end;
end;

function TGrandeEditorTesto.TrovaParentesiCorrispondente(out B1X, B1Y, B2X, B2Y: Integer): Boolean;
var
  TargetX, TargetY, Depth, Dir, CurrX, CurrY, LineLen: Integer;
  Ch, OpenCh, CloseCh, FoundCh: String;
  IsOpen: Boolean;
begin
  Result := False;
  B1X := -1; B1Y := -1;
  B2X := -1; B2Y := -1;

  if (FCaretFisicoY < 0) or (FCaretFisicoY >= FTesto.Count) then Exit;

  TargetX := FCaretFisicoX;
  TargetY := FCaretFisicoY;
  LineLen := GetStrLength(FTesto[TargetY]);

  Ch := '';
  if (TargetX >= 0) and (TargetX < LineLen) then
    Ch := SubStringFast(FTesto[TargetY], TargetX + 1, 1);

  if (Ch <> '(') and (Ch <> ')') and (Ch <> '[') and (Ch <> ']') and (Ch <> '{') and (Ch <> '}') then
  begin
    if (TargetX > 0) and (TargetX - 1 < LineLen) then
    begin
      TargetX := TargetX - 1;
      Ch := SubStringFast(FTesto[TargetY], TargetX + 1, 1);
    end;
  end;

  if (Ch <> '(') and (Ch <> ')') and (Ch <> '[') and (Ch <> ']') and (Ch <> '{') and (Ch <> '}') then
    Exit;

  case Ch of
    '(': begin OpenCh := '('; CloseCh := ')'; Dir := 1;  IsOpen := True; end;
    '[': begin OpenCh := '['; CloseCh := ']'; Dir := 1;  IsOpen := True; end;
    '{': begin OpenCh := '{'; CloseCh := '}'; Dir := 1;  IsOpen := True; end;
    ')': begin OpenCh := '('; CloseCh := ')'; Dir := -1; IsOpen := False; end;
    ']': begin OpenCh := '['; CloseCh := ']'; Dir := -1; IsOpen := False; end;
    '}': begin OpenCh := '{'; CloseCh := '}'; Dir := -1; IsOpen := False; end;
  end;

  B1X := TargetX;
  B1Y := TargetY;

  CurrX := TargetX;
  CurrY := TargetY;
  Depth := 1;

  while True do
  begin
    Inc(CurrX, Dir);

    if (CurrX < 0) or (CurrX >= LineLen) then
      Break;

    FoundCh := SubStringFast(FTesto[CurrY], CurrX + 1, 1);
    if IsOpen then
    begin
      if FoundCh = OpenCh then Inc(Depth)
      else if FoundCh = CloseCh then Dec(Depth);
    end
    else
    begin
      if FoundCh = CloseCh then Inc(Depth)
      else if FoundCh = OpenCh then Dec(Depth);
    end;

    if Depth = 0 then
    begin
      B2X := CurrX;
      B2Y := CurrY;
      Result := True;
      Break;
    end;
  end;
end;

function TGrandeEditorTesto.FisicoToPosAssoluta(AX, AY: Integer): Integer;
var
  i: Integer;
begin
  Result := 0;
  if AY >= FTesto.Count then AY := FTesto.Count - 1;

  for i := 0 to AY - 1 do
  begin
    if i < Length(FLineCache) then
      Result := Result + FLineCache[i].StrippedTextLen + 1
    else
      Result := Result + GetStrLength(FTesto[i]) + 1;
  end;

  Result := Result + Min(AX, GetStrLength(FTesto[AY]));
end;

procedure TGrandeEditorTesto.PosAssolutaToFisico(APos: Integer; out AX, AY: Integer);
var
  i, LineLen: Integer;
  CurrPos: Integer;
begin
  CurrPos := APos;
  for i := 0 to FTesto.Count - 1 do
  begin
    if i < Length(FLineCache) then
      LineLen := FLineCache[i].StrippedTextLen + 1
    else
      LineLen := GetStrLength(FTesto[i]) + 1;

    if CurrPos < LineLen then
    begin
      AY := i;
      AX := Min(CurrPos, GetStrLength(FTesto[i]));
      Exit;
    end;
    Dec(CurrPos, LineLen);
  end;

  AY := Max(0, FTesto.Count - 1);
  AX := GetStrLength(FTesto[AY]);
end;

function TGrandeEditorTesto.TrovaColoreEvidenziazione(AbsPos: Integer; out AColor: TColor): Boolean;
var
  k: Integer;
begin
  Result := False;
  for k := High(FEvidenziazioni) downto 0 do
  begin
    if (AbsPos >= FEvidenziazioni[k].PosInizio) and (AbsPos < FEvidenziazioni[k].PosFine) then
    begin
      AColor := FEvidenziazioni[k].Colore;
      Exit(True);
    end;
  end;
end;

procedure TGrandeEditorTesto.Evidenzia(const AEvidenziazioni: array of TEvidenziazione);
var
  i: Integer;
begin
  SetLength(FEvidenziazioni, Length(AEvidenziazioni));
  for i := 0 to High(AEvidenziazioni) do
    FEvidenziazioni[i] := AEvidenziazioni[i];
  Invalidate;
end;

procedure TGrandeEditorTesto.RimuoviEvidenziazioni;
begin
  SetLength(FEvidenziazioni, 0);
  Invalidate;
end;

function TGrandeEditorTesto.LeggiEvidenziazioni: TEvidenziazioniArray;
begin
  Result := Copy(FEvidenziazioni);
end;

procedure TGrandeEditorTesto.AggiornaEvidenziazioniSuInserimento(APos, ALen: Integer);
var
  i: Integer;
begin
  if Length(FEvidenziazioni) = 0 then Exit;

  for i := 0 to High(FEvidenziazioni) do
  begin
    if FEvidenziazioni[i].PosInizio >= APos then
    begin
      Inc(FEvidenziazioni[i].PosInizio, ALen);
      Inc(FEvidenziazioni[i].PosFine, ALen);
    end
    else if FEvidenziazioni[i].PosFine > APos then
    begin
      Inc(FEvidenziazioni[i].PosFine, ALen);
    end;
  end;
end;

procedure TGrandeEditorTesto.AggiornaEvidenziazioniSuCancellazione(APos, ALen: Integer);
var
  i, EndDel: Integer;
begin
  if Length(FEvidenziazioni) = 0 then Exit;

  EndDel := APos + ALen;

  for i := 0 to High(FEvidenziazioni) do
  begin
    if FEvidenziazioni[i].PosInizio >= EndDel then
      Dec(FEvidenziazioni[i].PosInizio, ALen)
    else if FEvidenziazioni[i].PosInizio > APos then
      FEvidenziazioni[i].PosInizio := APos;

    if FEvidenziazioni[i].PosFine >= EndDel then
      Dec(FEvidenziazioni[i].PosFine, ALen)
    else if FEvidenziazioni[i].PosFine > APos then
      FEvidenziazioni[i].PosFine := APos;
  end;
end;

procedure TGrandeEditorTesto.AutoScrollTimerEvent(Sender: TObject);
var
  P: TPoint;
  FX, FY: Integer;
begin
  if not FSelectingWithMouse then
  begin
    FAutoScrollTimer.Enabled := False;
    Exit;
  end;

  P := ScreenToClient(Mouse.CursorPos);

  if P.Y < 0 then
  begin
    if FTopLine > 0 then
    begin
      Dec(FTopLine);
      FScrollBar.Position := FTopLine;
    end;
  end
  else if P.Y > ClientHeight then
  begin
    if FTopLine < MaxTopLine then
    begin
      Inc(FTopLine);
      FScrollBar.Position := FTopLine;
    end;
  end;

  VisualCoordinateToFisico(P.X, P.Y, FX, FY);
  FCaretFisicoX := FX;
  FCaretFisicoY := FY;

  FSelEndX := FCaretFisicoX;
  FSelEndY := FCaretFisicoY;

  AssicuratiCaretVisibile;
  Invalidate;
end;

function TGrandeEditorTesto.HaSelezione: Boolean;
begin
  Result := (FSelStartY >= 0) and (FSelEndY >= 0) and
            ((FSelStartX <> FSelEndX) or (FSelStartY <> FSelEndY));
end;

procedure TGrandeEditorTesto.AnnullaSelezione;
begin
  FSelStartX := -1; FSelStartY := -1;
  FSelEndX := -1;   FSelEndY := -1;
  Invalidate;
end;

procedure TGrandeEditorTesto.CancellaSelezione(AGroupID: Integer);
var
  SX, SY, EX, EY: Integer;
  DelText: String;
begin
  if not HaSelezione or FReadOnly then Exit;

  NormalizzaSelezione(SX, SY, EX, EY);
  DelText := DeleteTextFisico(SX, SY, EX, EY);

  RecordDelete(SX, SY, DelText, EX, EY, SX, SY, AGroupID);

  FCaretFisicoX := SX;
  FCaretFisicoY := SY;
  AnnullaSelezione;
  AssicuratiCaretVisibile;
  DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
end;

procedure TGrandeEditorTesto.CopiaInAppunti;
begin
  if HaSelezione then
    Clipboard.AsText := TestoSelezionato;
end;

procedure TGrandeEditorTesto.TagliaInAppunti;
begin
  if FReadOnly or not HaSelezione then Exit;
  CopiaInAppunti;
  CancellaSelezione;
  AggiornaScrollBar;
  Invalidate;
end;

procedure TGrandeEditorTesto.IncollaDaAppunti;
var
  Txt: String;
  GroupID, OldX, OldY: Integer;
begin
  if FReadOnly or not Clipboard.HasFormat(CF_TEXT) then Exit;

  GroupID := NuovoGroupID;
  if HaSelezione then CancellaSelezione(GroupID);

  Txt := Clipboard.AsText;
  if Txt = '' then Exit;

  OldX := FCaretFisicoX;
  OldY := FCaretFisicoY;

  InsertTextFisico(FCaretFisicoX, FCaretFisicoY, Txt);

  CalcolaFineTesto(OldX, OldY, Txt, FCaretFisicoX, FCaretFisicoY);

  RecordInsert(OldX, OldY, Txt, OldX, OldY, FCaretFisicoX, FCaretFisicoY, GroupID);

  AggiornaScrollBar;
  AssicuratiCaretVisibile;
  DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
  Invalidate;
end;

procedure TGrandeEditorTesto.NormalizzaSelezione(out OutStartX, OutStartY, OutEndX, OutEndY: Integer);
begin
  if (FSelStartY < FSelEndY) or ((FSelStartY = FSelEndY) and (FSelStartX <= FSelEndX)) then
  begin
    OutStartX := FSelStartX; OutStartY := FSelStartY;
    OutEndX := FSelEndX;     OutEndY := FSelEndY;
  end
  else
  begin
    OutStartX := FSelEndX;   OutStartY := FSelEndY;
    OutEndX := FSelStartX;   OutEndY := FSelStartY;
  end;
end;

function TGrandeEditorTesto.CarattereIsInSelezione(FisicoX, FisicoY: Integer): Boolean;
var
  SX, SY, EX, EY: Integer;
begin
  Result := False;
  if not HaSelezione then Exit;

  NormalizzaSelezione(SX, SY, EX, EY);

  if (FisicoY < SY) or (FisicoY > EY) then Exit;
  if (FisicoY > SY) and (FisicoY < EY) then Exit(True);

  if (SY = EY) then
    Exit((FisicoX >= SX) and (FisicoX < EX));

  if FisicoY = SY then
    Exit(FisicoX >= SX);

  if FisicoY = EY then
    Exit(FisicoX < EX);
end;

function TGrandeEditorTesto.InizioSelezione: TPoint;
var
  SX, SY, EX, EY: Integer;
begin
  if HaSelezione then
  begin
    NormalizzaSelezione(SX, SY, EX, EY);
    Result := Point(SX, SY);
  end
  else
    Result := Point(-1, -1);
end;

function TGrandeEditorTesto.FineSelezione: TPoint;
var
  SX, SY, EX, EY: Integer;
begin
  if HaSelezione then
  begin
    NormalizzaSelezione(SX, SY, EX, EY);
    Result := Point(EX, EY);
  end
  else
    Result := Point(-1, -1);
end;

function TGrandeEditorTesto.TestoSelezionato: String;
var
  SX, SY, EX, EY, i, VisSX, VisEX: Integer;
  RigaText, VisText: String;
  ParseRes: TLineParseResult;
begin
  Result := '';
  if not HaSelezione then Exit;

  NormalizzaSelezione(SX, SY, EX, EY);

  for i := SY to EY do
  begin
    RigaText := FTesto[i];

    if FEnableRichText and (i < Length(FLineCache)) and FLineCache[i].IsRich then
    begin
      ParseRes := ParseRichTextLine(RigaText, i);
      VisText := ParseRes.StrippedText;

      if i = SY then
      begin
        VisSX := 0;
        while (VisSX < Length(ParseRes.VisToPhys)) and (ParseRes.VisToPhys[VisSX] < SX) do
          Inc(VisSX);
      end
      else
        VisSX := 0;

      if i = EY then
      begin
        VisEX := 0;
        while (VisEX < Length(ParseRes.VisToPhys)) and (ParseRes.VisToPhys[VisEX] < EX) do
          Inc(VisEX);
      end
      else
        VisEX := GetStrLength(VisText);

      if VisEX > VisSX then
        Result := Result + UTF8Copy(VisText, VisSX + 1, VisEX - VisSX);
    end
    else
    begin
      if i = SY then VisSX := SX else VisSX := 0;
      if i = EY then VisEX := EX else VisEX := GetStrLength(RigaText);

      Result := Result + SubStringFast(RigaText, VisSX + 1, VisEX - VisSX);
    end;

    if i < EY then
      Result := Result + sLineBreak;
  end;
end;

procedure TGrandeEditorTesto.SelezionaTutto;
begin
  if FTesto.Count = 0 then Exit;
  FSelStartX := 0;
  FSelStartY := 0;
  FSelEndY := FTesto.Count - 1;
  FSelEndX := GetStrLength(FTesto[FSelEndY]);
  Invalidate;
end;

procedure TGrandeEditorTesto.AggiornaSelezioneCaret(OldX, OldY: Integer; ExtendSelection: Boolean);
begin
  if ExtendSelection then
  begin
    if not HaSelezione then
    begin
      FSelStartX := OldX;
      FSelStartY := OldY;
    end;
    FSelEndX := FCaretFisicoX;
    FSelEndY := FCaretFisicoY;
  end
  else
  begin
    AnnullaSelezione;
  end;
end;

function TGrandeEditorTesto.GetActiveOverlappingImage(LinePhysIdx: Integer; out Img: TEmbeddedImage; out ImgStartLine: Integer): integer;
var
  k, PrevLineIdx: Integer;
  ParseRes: TLineParseResult;
  S: String;
begin
  Result := 0;
  Img := Default(TEmbeddedImage);
  ImgStartLine := -1;

  if (not FEnableRichText) or (LinePhysIdx <= 0) or (LinePhysIdx >= FTesto.Count) then Exit;

  for k := 1 to 30 do
  begin
    PrevLineIdx := LinePhysIdx - k;
    if PrevLineIdx < 0 then Break;

    S := FTesto[PrevLineIdx];
    if (Pos('<image:', S) > 0) then
    begin
      ParseRes := ParseRichTextLine(S, -1);
      if ParseRes.HasImage and (ParseRes.EmbeddedImg.Wrap = iwLeft) then
      begin
        if (LinePhysIdx >= PrevLineIdx) and (LinePhysIdx < PrevLineIdx + ParseRes.EmbeddedImg.HeightRows) then
        begin
          Img := ParseRes.EmbeddedImg;
          ImgStartLine := PrevLineIdx;
          Exit(k);
        end;
      end;
    end;
  end;
end;

function TGrandeEditorTesto.GetActiveOverlappingImageVis(VIndex: Integer; out Img: TEmbeddedImage; out VisualLinesAbove: Integer): Boolean;
var
  k, CheckVIndex, PhysIdx: Integer;
  ParseRes: TLineParseResult;
  S: String;
begin
  Result := False;
  Img := Default(TEmbeddedImage);
  VisualLinesAbove := 0;

  if (not FEnableRichText) or (VIndex <= 0) or (VIndex >= FVisualCount) then Exit;

  for k := 1 to 35 do
  begin
    CheckVIndex := VIndex - k;
    if CheckVIndex < 0 then Break;

    if (not FWordWrap) or FVisualLines[CheckVIndex].IsFirstWrap then
    begin
      if not FWordWrap then
        PhysIdx := CheckVIndex
      else
        PhysIdx := FVisualLines[CheckVIndex].FisicaIndex;

      if (PhysIdx >= 0) and (PhysIdx < FTesto.Count) then
      begin
        S := FTesto[PhysIdx];
        if (Pos('<image:', S) > 0) then
        begin
          ParseRes := ParseRichTextLine(S, PhysIdx);
          if ParseRes.HasImage and (ParseRes.EmbeddedImg.Wrap = iwLeft) then
          begin
            if VIndex < CheckVIndex + ParseRes.EmbeddedImg.HeightRows then
            begin
              Img := ParseRes.EmbeddedImg;
              VisualLinesAbove := VIndex - CheckVIndex;
              Exit(True);
            end;
          end;
          if ParseRes.HasImage and (ParseRes.EmbeddedImg.Wrap = iwNone) then
          begin
            if VIndex < CheckVIndex + ParseRes.EmbeddedImg.HeightRows then
            begin
              Img := ParseRes.EmbeddedImg;
              VisualLinesAbove := VIndex - CheckVIndex;
              Exit(True);
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TGrandeEditorTesto.Paint;
var
  FirstLine, LastLine, LineIndex: Integer;
  i, Y, FisY, DrawStartX: Integer;
  LineText, VisibleSlice: String;
  SliceChars, StartCharIdx, VisCount: Integer;
  TestoNumero: String;
  HBarHeight: Integer;
  SelSX, SelSY, SelEX, SelEY: Integer;
  CaretDrawX, CaretDrawY: Integer;
  HasCaretOnLine: Boolean;
  TotalLineLen: Integer;

  HasMatchingBrk: Boolean;
  Brk1X, Brk1Y, Brk2X, Brk2Y: Integer;
  IsBrkChar: Boolean;
  BrkChar: String;
  BrkVisColX: Integer;
  BrkCharRect: TRect;

  LineStartAbs, LineEndAbs: Integer;
  evIdx, EvStartX, EvEndX, VisEvStart, VisEvEnd, vCol: Integer;
  HasEvid: Boolean;
  EvidCol: TColor;
  LineSearchMatches: array of record
    MatchStart: Integer;
    MatchEnd: Integer;
    Color: TColor;
  end;
  opIdx, mIdx: Integer;
  SearchMatches: TMatchArray;
  HasSearchMatch: Boolean;
  SearchMatchColor: TColor;
  SelWord: String;
  SelWordOpt, SearchOpt: TSearchOptions;

  MarginLen, WinStartChar, WinEndChar, WinLen, PhysMatchStart, MatchEndChar: Integer;
  SearchWindowStr, SearchSourceText: String;
  IsWordOk, LeftOk, RightOk: Boolean;

  IsRichLine: Boolean;
  ParseRes: TLineParseResult;
  ImgWidthPx, ImgHeightPx, ImgX, ImgY, lineaFigura: Integer;
  ImgRect: TRect;
  OverlapImg: TEmbeddedImage;
  LinesAbove, CharIdx, SrcBytePos, CharByteLen, VisX, NextVisX, CharCols, FisX, LIdx: Integer;
  CharLogicalIdx, StartLineVisCol: Integer;
  Ch: String;
  CharRect: TRect;
  CharStyle: TCharStyle;
  IsLinkChar: Boolean;
  IsLastWrapOfLine: Boolean;
  NeedsPerCharRender: Boolean;
begin
  CalcolaDimensioni;

  HBarHeight := 0;
  if not FWordWrap then HBarHeight := FHScrollBar.Height;

  Canvas.Brush.Color := clWindow;
  Canvas.FillRect(Bounds(FMargineNumeri, 0, ClientWidth - FMargineNumeri - FScrollBar.Width, ClientHeight - HBarHeight));
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(Bounds(0, 0, FMargineNumeri, ClientHeight - HBarHeight));
  Canvas.Pen.Color := clBtnShadow;
  Canvas.Line(FMargineNumeri - 1, 0, FMargineNumeri - 1, ClientHeight - HBarHeight);

  if not FWordWrap then
  begin
    Canvas.Brush.Color := clBtnFace;
    Canvas.FillRect(Bounds(ClientWidth - FScrollBar.Width, ClientHeight - HBarHeight, FScrollBar.Width, HBarHeight));
    Canvas.FillRect(Bounds(0, ClientHeight - HBarHeight, FMargineNumeri, HBarHeight));
  end;

  Canvas.Font.Assign(Font);

  FirstLine := FTopLine;
  LastLine := Min(FVisualCount - 1, FTopLine + ((ClientHeight - HBarHeight) div FLineHeight) + 1);

  VisCount := Max(1, ((ClientWidth - FMargineNumeri - FScrollBar.Width) div FCharWidth) + 2);
  DrawStartX := FMargineNumeri + 5;

  if HaSelezione then
    NormalizzaSelezione(SelSX, SelSY, SelEX, SelEY)
  else
  begin
    SelSX := -1; SelSY := -1; SelEX := -1; SelEY := -1;
  end;

  HasMatchingBrk := False;
  Brk1X := -1; Brk1Y := -1; Brk2X := -1; Brk2Y := -1;
  if FHighlightMatchingBracket and not HaSelezione then
    HasMatchingBrk := TrovaParentesiCorrispondente(Brk1X, Brk1Y, Brk2X, Brk2Y);

  HasCaretOnLine := False;
  CaretDrawX := 0;
  CaretDrawY := 0;
  lineaFigura := 0;
  ImgWidthPx := 0;
  ImgRect.Right := 0;

  for LineIndex := FirstLine to LastLine do
  begin
    i := LineIndex - FTopLine;
    Y := i * FLineHeight;
    if Y + FLineHeight > ClientHeight - HBarHeight then Break;

    if not FWordWrap then
    begin
      FisY := LineIndex;
      StartCharIdx := 1;
      IsLastWrapOfLine := True;
      StartLineVisCol := 0;
    end
    else
    begin
      FisY := FVisualLines[LineIndex].FisicaIndex;
      StartCharIdx := FVisualLines[LineIndex].StartChar;
      VisCount := FVisualLines[LineIndex].Lunghezza;
      IsLastWrapOfLine := (LineIndex = FVisualCount - 1) or (FVisualLines[LineIndex + 1].FisicaIndex <> FisY);
      StartLineVisCol := GetVisColFromPhys(StartCharIdx - 1, FisY);
    end;

    if (FisY < 0) or (FisY >= FTesto.Count) then Continue;

    if (not FWordWrap) or FVisualLines[LineIndex].IsFirstWrap then
    begin
      Canvas.Brush.Color := clBtnFace;
      Canvas.Font.Color := clGrayText;
      TestoNumero := IntToStr(FisY + 1);
      Canvas.TextOut(FMargineNumeri - Canvas.TextWidth(TestoNumero) - 6, Y + 2, TestoNumero);
    end;

    LineText := FTesto[FisY];
    TotalLineLen := GetStrLength(LineText);

    IsRichLine := FEnableRichText and (FisY < Length(FLineCache)) and FLineCache[FisY].IsRich;

    if IsRichLine then
    begin
      ParseRes := ParseRichTextLine(LineText, FisY);
      SearchSourceText := ParseRes.StrippedText;

      if ParseRes.HasImage and (ParseRes.EmbeddedImg.Picture <> nil) and
         ((not FWordWrap) or FVisualLines[LineIndex].IsFirstWrap) then
      begin
        ImgWidthPx := ParseRes.EmbeddedImg.WidthCols * FCharWidth;
        if (ParseRes.EmbeddedImg.Picture.Width > 0) and (ParseRes.EmbeddedImg.Picture.Height > 0) then
          ImgHeightPx := Round(ImgWidthPx * (ParseRes.EmbeddedImg.Picture.Height / ParseRes.EmbeddedImg.Picture.Width))
        else
          ImgHeightPx := FLineHeight;

        lineaFigura := i;
        ImgX := FMargineNumeri + 5 + (ParseRes.EmbeddedImg.Col - FLeftCol) * FCharWidth;
        ImgY := Y;
        ImgRect := Rect(ImgX, ImgY, ImgX + ImgWidthPx, ImgY + ImgHeightPx);

        if (ImgRect.Right > FMargineNumeri + 5) and (ImgRect.Left < ClientWidth - FScrollBar.Width) then
        begin
          if ParseRes.EmbeddedImg.Picture.Graphic <> nil then
            Canvas.StretchDraw(ImgRect, ParseRes.EmbeddedImg.Picture.Graphic);
        end;
      end
      else if GetActiveOverlappingImageVis(LineIndex, OverlapImg, LinesAbove) then
      begin
        ImgWidthPx := OverlapImg.WidthCols * FCharWidth;
        if (OverlapImg.Picture <> nil) and (OverlapImg.Picture.Width > 0) and (OverlapImg.Picture.Height > 0) then
          ImgHeightPx := Round(ImgWidthPx * (OverlapImg.Picture.Height / OverlapImg.Picture.Width))
        else
          ImgHeightPx := FLineHeight;

        lineaFigura := i - LinesAbove;
        ImgX := FMargineNumeri + 5 + (OverlapImg.Col - FLeftCol) * FCharWidth;
        ImgY := Y - (LinesAbove * FLineHeight);
        ImgRect := Rect(ImgX, ImgY, ImgX + ImgWidthPx, ImgY + ImgHeightPx);

        if (i = 0) and (OverlapImg.Picture <> nil) and (OverlapImg.Picture.Graphic <> nil) then
        begin
          if (ImgRect.Right > FMargineNumeri + 5) and (ImgRect.Left < ClientWidth - FScrollBar.Width) then
            Canvas.StretchDraw(ImgRect, OverlapImg.Picture.Graphic);
        end;

        if OverlapImg.Wrap <> iwLeft then
          ImgRect.Right := 0;
      end
      else
        ImgRect.Right := 0;

      if ParseRes.StrippedText <> '' then
      begin
        if not FWordWrap then
        begin
          VisibleSlice := ParseRes.StrippedText;
          SliceChars := GetStrLength(VisibleSlice);
          StartCharIdx := 1;
        end
        else
        begin
          VisibleSlice := SubStringFast(ParseRes.StrippedText, StartCharIdx, VisCount);
          SliceChars := GetStrLength(VisibleSlice);
        end;
      end
      else
      begin
        VisibleSlice := '';
        SliceChars := 0;
      end;

      SetLength(LineSearchMatches, 0);
      if (SliceChars > 0) and (Length(FSearchOperations) > 0) then
      begin
        for opIdx := 0 to High(FSearchOperations) do
        begin
          MarginLen := Max(32, GetStrLength(FSearchOperations[opIdx].SearchText));
          WinStartChar := Max(1, StartCharIdx - MarginLen);
          WinEndChar := Min(GetStrLength(SearchSourceText), StartCharIdx + SliceChars - 1 + MarginLen);
          WinLen := Max(0, WinEndChar - WinStartChar + 1);

          if WinLen > 0 then
          begin
            SearchWindowStr := SubStringFast(SearchSourceText, WinStartChar, WinLen);
            SearchOpt := FSearchOperations[opIdx].Options;
            SearchOpt.WholeWord := False;

            SearchMatches := CercaInRiga(SearchWindowStr, FSearchOperations[opIdx].SearchText, SearchOpt);
            for mIdx := 0 to High(SearchMatches) do
            begin
              PhysMatchStart := (WinStartChar - 1) + SearchMatches[mIdx].CharX;
              MatchEndChar := PhysMatchStart + SearchMatches[mIdx].CharLen;

              IsWordOk := True;
              if FSearchOperations[opIdx].Options.WholeWord then
              begin
                if PhysMatchStart = 0 then
                  LeftOk := True
                else if (PhysMatchStart < Length(ParseRes.VisCols)) and (PhysMatchStart - 1 < Length(ParseRes.VisCols)) and
                        (ParseRes.VisCols[PhysMatchStart] <> ParseRes.VisCols[PhysMatchStart - 1] + 1) then
                  LeftOk := True
                else
                  LeftOk := not IsWordChar(SubStringFast(SearchSourceText, PhysMatchStart, 1));

                if MatchEndChar >= GetStrLength(SearchSourceText) then
                  RightOk := True
                else if (MatchEndChar > 0) and (MatchEndChar < Length(ParseRes.VisCols)) and
                        (ParseRes.VisCols[MatchEndChar] <> ParseRes.VisCols[MatchEndChar - 1] + 1) then
                  RightOk := True
                else
                  RightOk := not IsWordChar(SubStringFast(SearchSourceText, MatchEndChar + 1, 1));

                IsWordOk := LeftOk and RightOk;
              end;

              if IsWordOk then
              begin
                SetLength(LineSearchMatches, Length(LineSearchMatches) + 1);
                LineSearchMatches[High(LineSearchMatches)].MatchStart := PhysMatchStart;
                LineSearchMatches[High(LineSearchMatches)].MatchEnd := MatchEndChar;
                LineSearchMatches[High(LineSearchMatches)].Color := FSearchOperations[opIdx].Color;
              end;
            end;
          end;
        end;
      end;

      if (SliceChars > 0) and FHighlightSelectedWord and HaSelezione and (SelSY = SelEY) then
      begin
        SelWord := Trim(TestoSelezionato);
        if (SelWord <> '') and (Pos(#10, SelWord) = 0) and (Pos(#13, SelWord) = 0) then
        begin
          SelWordOpt.SearchType := stText;
          SelWordOpt.CaseSensitive := True;
          SelWordOpt.WholeWord := False;
          SelWordOpt.MatchDiacritics := True;
          SelWordOpt.removeOlder := False;

          MarginLen := Max(32, GetStrLength(SelWord));
          WinStartChar := Max(1, StartCharIdx - MarginLen);
          WinEndChar := Min(GetStrLength(SearchSourceText), StartCharIdx + SliceChars - 1 + MarginLen);
          WinLen := Max(0, WinEndChar - WinStartChar + 1);

          if WinLen > 0 then
          begin
            SearchWindowStr := SubStringFast(SearchSourceText, WinStartChar, WinLen);
            SearchMatches := CercaInRiga(SearchWindowStr, SelWord, SelWordOpt);
            for mIdx := 0 to High(SearchMatches) do
            begin
              PhysMatchStart := (WinStartChar - 1) + SearchMatches[mIdx].CharX;
              MatchEndChar := PhysMatchStart + SearchMatches[mIdx].CharLen;

              IsWordOk := True;
              if FHighlightWholeWordsOnly then
              begin
                if PhysMatchStart = 0 then
                  LeftOk := True
                else if (PhysMatchStart < Length(ParseRes.VisCols)) and (PhysMatchStart - 1 < Length(ParseRes.VisCols)) and
                        (ParseRes.VisCols[PhysMatchStart] <> ParseRes.VisCols[PhysMatchStart - 1] + 1) then
                  LeftOk := True
                else
                  LeftOk := not IsWordChar(SubStringFast(SearchSourceText, PhysMatchStart, 1));

                if MatchEndChar >= GetStrLength(SearchSourceText) then
                  RightOk := True
                else if (MatchEndChar < Length(ParseRes.VisCols)) and (MatchEndChar - 1 < Length(ParseRes.VisCols)) and
                        (ParseRes.VisCols[MatchEndChar] <> ParseRes.VisCols[MatchEndChar - 1] + 1) then
                  RightOk := True
                else
                  RightOk := not IsWordChar(SubStringFast(SearchSourceText, MatchEndChar + 1, 1));

                IsWordOk := LeftOk and RightOk;
              end;

              if IsWordOk then
              begin
                SetLength(LineSearchMatches, Length(LineSearchMatches) + 1);
                LineSearchMatches[High(LineSearchMatches)].MatchStart := PhysMatchStart;
                LineSearchMatches[High(LineSearchMatches)].MatchEnd := MatchEndChar;
                LineSearchMatches[High(LineSearchMatches)].Color := FSelectedWordColor;
              end;
            end;
          end;
        end;
      end;

      if SliceChars > 0 then
      begin
        LineStartAbs := 0;
        if Length(FEvidenziazioni) > 0 then
          LineStartAbs := FisicoToPosAssoluta(0, FisY);

        SrcBytePos := 1;
        for CharIdx := 1 to SliceChars do
        begin
          if FUseUTF8 then
            CharByteLen := UTF8CharacterLength(@VisibleSlice[SrcBytePos])
          else
            CharByteLen := 1;

          Ch := Copy(VisibleSlice, SrcBytePos, CharByteLen);
          Inc(SrcBytePos, CharByteLen);

          CharLogicalIdx := (StartCharIdx - 1) + (CharIdx - 1);

          if (CharLogicalIdx >= 0) and (CharLogicalIdx < Length(ParseRes.VisCols)) then
            VisX := ParseRes.VisCols[CharLogicalIdx] - FLeftCol
          else
            VisX := CharLogicalIdx - FLeftCol;

          if (CharLogicalIdx + 1 < Length(ParseRes.VisCols)) then
            NextVisX := ParseRes.VisCols[CharLogicalIdx + 1] - FLeftCol
          else
            NextVisX := VisX + 1;

          CharCols := Max(1, NextVisX - VisX);

          if (CharLogicalIdx >= 0) and (CharLogicalIdx < Length(ParseRes.VisToPhys)) then
            FisX := ParseRes.VisToPhys[CharLogicalIdx]
          else
            FisX := CharLogicalIdx;

          if VisX + CharCols <= 0 then Continue;

          CharRect := Rect(DrawStartX + VisX * FCharWidth, Y,
                           DrawStartX + (VisX + CharCols) * FCharWidth, Y + FLineHeight);

          if (CharRect.Right <= FMargineNumeri + 5) or
             (CharRect.Left >= ClientWidth - FScrollBar.Width) then Continue;

          CharStyle.Style := [];
          CharStyle.Color := clNone;
          IsLinkChar := False;

          if (CharLogicalIdx >= 0) and (CharLogicalIdx < Length(ParseRes.CharStyles)) then
            CharStyle := ParseRes.CharStyles[CharLogicalIdx];

          for LIdx := 0 to High(ParseRes.Links) do
          begin
            if (CharLogicalIdx >= ParseRes.Links[LIdx].VisStartX) and
               (CharLogicalIdx < ParseRes.Links[LIdx].VisEndX) then
            begin
              IsLinkChar := True;
              Break;
            end;
          end;

          Canvas.Font.Style := CharStyle.Style;

          IsBrkChar := HasMatchingBrk and (((FisY = Brk1Y) and (FisX = Brk1X)) or
                                           ((FisY = Brk2Y) and (FisX = Brk2X)));

          HasEvid := (Length(FEvidenziazioni) > 0) and TrovaColoreEvidenziazione(LineStartAbs + FisX, EvidCol);

          HasSearchMatch := False;
          SearchMatchColor := clNone;
          if Length(LineSearchMatches) > 0 then
          begin
            for opIdx := High(LineSearchMatches) downto 0 do
            begin
              if (CharLogicalIdx >= LineSearchMatches[opIdx].MatchStart) and
                 (CharLogicalIdx < LineSearchMatches[opIdx].MatchEnd) then
              begin
                HasSearchMatch := True;
                SearchMatchColor := LineSearchMatches[opIdx].Color;
                Break;
              end;
            end;
          end;

          if CarattereIsInSelezione(FisX, FisY) then
          begin
            Canvas.Brush.Color := clHighlight;
            Canvas.Font.Color := clHighlightText;
          end
          else if IsBrkChar then
          begin
            Canvas.Brush.Color := FMatchingBracketColor;
            Canvas.Font.Color := clWindowText;
          end
          else if HasEvid then
          begin
            Canvas.Brush.Color := EvidCol;
            if CharStyle.Color <> clNone then
              Canvas.Font.Color := CharStyle.Color
            else
              Canvas.Font.Color := clWindowText;
          end
          else if HasSearchMatch then
          begin
            Canvas.Brush.Color := SearchMatchColor;
            if CharStyle.Color <> clNone then
              Canvas.Font.Color := CharStyle.Color
            else
              Canvas.Font.Color := clWindowText;
          end
          else if IsLinkChar then
          begin
            Canvas.Brush.Color := clWindow;
            Canvas.Font.Color := FLinkColor;
            Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
          end
          else
          begin
            Canvas.Brush.Color := clWindow;
            if CharStyle.Color <> clNone then
              Canvas.Font.Color := CharStyle.Color
            else
              Canvas.Font.Color := clWindowText;
          end;

          Canvas.FillRect(CharRect);
          if (Ch <> #9) then
          begin
            if not FUseUTF8 then Ch := UTF8To1byteCod(Ch);
            Canvas.TextOut(CharRect.Left, Y + 2, Ch);
          end;
        end;
      end;
    end
    else
    begin
      if not FWordWrap then
      begin
        StartCharIdx := 1;
        VisibleSlice := LineText;
        SliceChars := TotalLineLen;
      end
      else
      begin
        if (FVisualLines[LineIndex].Lunghezza > 0) and (FVisualLines[LineIndex].ByteLen > 0) then
        begin
          if FVisualLines[LineIndex].StartByte < Length(LineText) then
            SetString(VisibleSlice, PChar(LineText) + FVisualLines[LineIndex].StartByte, Min(FVisualLines[LineIndex].ByteLen, Length(LineText) - FVisualLines[LineIndex].StartByte))
          else
            VisibleSlice := '';
          SliceChars := FVisualLines[LineIndex].Lunghezza;
        end
        else
        begin
          VisibleSlice := '';
          SliceChars := 0;
        end;
      end;

      SetLength(LineSearchMatches, 0);
      if (SliceChars > 0) and (Length(FSearchOperations) > 0) then
      begin
        for opIdx := 0 to High(FSearchOperations) do
        begin
          MarginLen := Max(32, GetStrLength(FSearchOperations[opIdx].SearchText));
          WinStartChar := Max(1, StartCharIdx - MarginLen);
          WinEndChar := Min(TotalLineLen, StartCharIdx + SliceChars - 1 + MarginLen);
          WinLen := Max(0, WinEndChar - WinStartChar + 1);

          if WinLen > 0 then
          begin
            SearchWindowStr := SubStringFast(LineText, WinStartChar, WinLen);
            SearchMatches := CercaInRiga(SearchWindowStr, FSearchOperations[opIdx].SearchText, FSearchOperations[opIdx].Options);
            for mIdx := 0 to High(SearchMatches) do
            begin
              PhysMatchStart := (WinStartChar - 1) + SearchMatches[mIdx].CharX;
              SetLength(LineSearchMatches, Length(LineSearchMatches) + 1);
              LineSearchMatches[High(LineSearchMatches)].MatchStart := PhysMatchStart;
              LineSearchMatches[High(LineSearchMatches)].MatchEnd := PhysMatchStart + SearchMatches[mIdx].CharLen;
              LineSearchMatches[High(LineSearchMatches)].Color := FSearchOperations[opIdx].Color;
            end;
          end;
        end;
      end;

      if (SliceChars > 0) and FHighlightSelectedWord and HaSelezione and (SelSY = SelEY) then
      begin
        SelWord := Trim(TestoSelezionato);
        if (Length(SelWord) < (FByteSize div 2)) and (SelWord <> '') and (Pos(#10, SelWord) = 0) and (Pos(#13, SelWord) = 0) then
        begin
          SelWordOpt.SearchType := stText;
          SelWordOpt.CaseSensitive := True;
          SelWordOpt.WholeWord := FHighlightWholeWordsOnly;
          SelWordOpt.MatchDiacritics := True;
          SelWordOpt.removeOlder := False;

          MarginLen := Max(32, GetStrLength(SelWord));
          WinStartChar := Max(1, StartCharIdx - MarginLen);
          WinEndChar := Min(TotalLineLen, StartCharIdx + SliceChars - 1 + MarginLen);
          WinLen := Max(0, WinEndChar - WinStartChar + 1);

          if WinLen > 0 then
          begin
            SearchWindowStr := SubStringFast(LineText, WinStartChar, WinLen);
            SearchMatches := CercaInRiga(SearchWindowStr, SelWord, SelWordOpt);
            for mIdx := 0 to High(SearchMatches) do
            begin
              PhysMatchStart := (WinStartChar - 1) + SearchMatches[mIdx].CharX;
              SetLength(LineSearchMatches, Length(LineSearchMatches) + 1);
              LineSearchMatches[High(LineSearchMatches)].MatchStart := PhysMatchStart;
              LineSearchMatches[High(LineSearchMatches)].MatchEnd := PhysMatchStart + SearchMatches[mIdx].CharLen;
              LineSearchMatches[High(LineSearchMatches)].Color := FSelectedWordColor;
            end;
          end;
        end;
      end;

      if SliceChars > 0 then
      begin
        NeedsPerCharRender := (FLineCache[FisY].HasTab) or
                              (HaSelezione and (FisY >= SelSY) and (FisY <= SelEY)) or
                              (Length(LineSearchMatches) > 0) or
                              (Length(FEvidenziazioni) > 0) or
                              (HasMatchingBrk and ((FisY = Brk1Y) or (FisY = Brk2Y)));

        if not NeedsPerCharRender then
        begin
          Canvas.Brush.Color := clWindow;
          Canvas.Font.Color := clWindowText;
          Canvas.Font.Style := [];
          if not FUseUTF8 then VisibleSlice := UTF8To1byteCod(VisibleSlice);
          if not FWordWrap then
            Canvas.TextOut(DrawStartX - FLeftCol * FCharWidth, Y + 2, VisibleSlice)
          else
            Canvas.TextOut(DrawStartX + FVisualLines[LineIndex].offsetX, Y + 2, VisibleSlice);
        end
        else
        begin
          LineStartAbs := 0;
          if Length(FEvidenziazioni) > 0 then
            LineStartAbs := FisicoToPosAssoluta(0, FisY);

          SrcBytePos := 1;
          for CharIdx := 1 to SliceChars do
          begin
            if FUseUTF8 then
              CharByteLen := UTF8CharacterLength(@VisibleSlice[SrcBytePos])
            else
              CharByteLen := 1;

            Ch := Copy(VisibleSlice, SrcBytePos, CharByteLen);
            Inc(SrcBytePos, CharByteLen);

            FisX := (StartCharIdx - 1) + (CharIdx - 1);

            if not FWordWrap then
            begin
              VisX := GetVisColFromPhys(FisX, FisY) - FLeftCol;
              NextVisX := GetVisColFromPhys(FisX + 1, FisY) - FLeftCol;
            end
            else
            begin
              VisX := (GetVisColFromPhys(FisX, FisY) - StartLineVisCol) + (FVisualLines[LineIndex].offsetX div FCharWidth);
              NextVisX := (GetVisColFromPhys(FisX + 1, FisY) - StartLineVisCol) + (FVisualLines[LineIndex].offsetX div FCharWidth);
            end;

            CharCols := Max(1, NextVisX - VisX);

            if VisX + CharCols <= 0 then Continue;

            CharRect := Rect(DrawStartX + VisX * FCharWidth, Y,
                             DrawStartX + (VisX + CharCols) * FCharWidth, Y + FLineHeight);

            if (CharRect.Right <= FMargineNumeri + 5) or
               (CharRect.Left >= ClientWidth - FScrollBar.Width) then Continue;

            Canvas.Font.Style := [];

            IsBrkChar := HasMatchingBrk and (((FisY = Brk1Y) and (FisX = Brk1X)) or
                                             ((FisY = Brk2Y) and (FisX = Brk2X)));

            HasEvid := (Length(FEvidenziazioni) > 0) and TrovaColoreEvidenziazione(LineStartAbs + FisX, EvidCol);

            HasSearchMatch := False;
            SearchMatchColor := clNone;
            if Length(LineSearchMatches) > 0 then
            begin
              for opIdx := High(LineSearchMatches) downto 0 do
              begin
                if (FisX >= LineSearchMatches[opIdx].MatchStart) and
                   (FisX < LineSearchMatches[opIdx].MatchEnd) then
                begin
                  HasSearchMatch := True;
                  SearchMatchColor := LineSearchMatches[opIdx].Color;
                  Break;
                end;
              end;
            end;

            if CarattereIsInSelezione(FisX, FisY) then
            begin
              Canvas.Brush.Color := clHighlight;
              Canvas.Font.Color := clHighlightText;
            end
            else if IsBrkChar then
            begin
              Canvas.Brush.Color := FMatchingBracketColor;
              Canvas.Font.Color := clWindowText;
            end
            else if HasEvid then
            begin
              Canvas.Brush.Color := EvidCol;
              Canvas.Font.Color := clWindowText;
            end
            else if HasSearchMatch then
            begin
              Canvas.Brush.Color := SearchMatchColor;
              Canvas.Font.Color := clWindowText;
            end
            else
            begin
              Canvas.Brush.Color := clWindow;
              Canvas.Font.Color := clWindowText;
            end;

            Canvas.FillRect(CharRect);
            if (Ch <> #9) then
            begin
              if not FUseUTF8 then Ch := UTF8To1byteCod(Ch);
              Canvas.TextOut(CharRect.Left, Y + 2, Ch);
            end;
          end;
        end;
      end;
    end;

    if (FCaretFisicoY = FisY) then
    begin
      if IsRichLine then
      begin
        VisX := GetVisColFromPhys(FCaretFisicoX, FisY) - FLeftCol;
        if (not FWordWrap) or FVisualLines[LineIndex].IsFirstWrap or IsLastWrapOfLine then
        begin
          if (VisX >= 0) and (VisX <= VisCount + 200) then
          begin
            HasCaretOnLine := True;
            CaretDrawX := DrawStartX + VisX * FCharWidth;
            CaretDrawY := Y + 2;
          end;
        end;
      end
      else if not FWordWrap then
      begin
        VisX := GetVisColFromPhys(FCaretFisicoX, FisY) - FLeftCol;
        if (VisX >= 0) and (VisX <= VisCount + 200) then
        begin
          HasCaretOnLine := True;
          CaretDrawX := DrawStartX + VisX * FCharWidth;
          CaretDrawY := Y + 2;
        end;
      end
      else
      begin
        if (FCaretFisicoX >= StartCharIdx - 1) and
           ((FCaretFisicoX < StartCharIdx - 1 + SliceChars) or
            (IsLastWrapOfLine and (FCaretFisicoX <= StartCharIdx - 1 + SliceChars))) then
        begin
          VisX := (GetVisColFromPhys(FCaretFisicoX, FisY) - StartLineVisCol) + (FVisualLines[LineIndex].offsetX div FCharWidth);
          HasCaretOnLine := True;
          CaretDrawX := DrawStartX + VisX * FCharWidth;
          CaretDrawY := Y + 2;
        end;
      end;
    end;
  end;

  if FShowCaret and HasCaretOnLine and Focused and
     (CaretDrawX >= DrawStartX) and (CaretDrawX <= ClientWidth - FScrollBar.Width) then
  begin
    Canvas.Pen.Color := clWindowText;
    Canvas.Pen.Width := 2;
    Canvas.Line(CaretDrawX, CaretDrawY, CaretDrawX, CaretDrawY + FLineHeight - 2);
    Canvas.Pen.Width := 1;
  end;
end;

procedure TGrandeEditorTesto.UTF8KeyPress(var UTF8Key: TUTF8Char);
var
  OldX, OldY, GroupID: Integer;
begin
  inherited UTF8KeyPress(UTF8Key);

  if FReadOnly then Exit;
  if (UTF8Key = '') or (UTF8Key = #8) or (UTF8Key = #9) or (UTF8Key = #13) or (UTF8Key = #27) then Exit;
  if (Length(UTF8Key) = 1) and (Ord(UTF8Key[1]) < 32) then Exit;

  if FIsRecordingMacro and not FIsPlayingMacro then
  begin
    SetLength(FCurrentMacro.Events, Length(FCurrentMacro.Events) + 1);
    FCurrentMacro.Events[High(FCurrentMacro.Events)].EventType := meUTF8Char;
    FCurrentMacro.Events[High(FCurrentMacro.Events)].UTF8Char := UTF8Key;
  end;

  GroupID := 0;
  if HaSelezione then
  begin
    GroupID := NuovoGroupID;
    CancellaSelezione(GroupID);
  end;

  if FTesto.Count = 0 then FTesto.Add('');

  OldX := FCaretFisicoX;
  OldY := FCaretFisicoY;

  InsertTextFisico(FCaretFisicoX, FCaretFisicoY, UTF8Key);

  Inc(FCaretFisicoX);

  RecordInsert(OldX, OldY, UTF8Key, OldX, OldY, FCaretFisicoX, FCaretFisicoY, GroupID);
  SnapCaretToValidPhysX;
  AssicuratiCaretVisibile;
  FShowCaret := True;
  DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
  Repaint;
end;

procedure TGrandeEditorTesto.KeyDown(var Key: Word; Shift: TShiftState);
var
  OldX, OldY, GroupID, PrevLen: Integer;
  IsShift, HandledInKeyDown: Boolean;
  DelText: String;
  CurVisCol: Integer;
  StartDel, EndDel: Integer;
  CurVIdx, TargetVIdx, TargetPhysY: Integer;
  CurScreenVisCol, TargetStartVisCol, TargetTotalVisCol, NewPhysX: Integer;
  TargetVL: TVisualLine;
  IsLastOfPhys: Boolean;
begin
  inherited KeyDown(Key, Shift);

  OldX := FCaretFisicoX;
  OldY := FCaretFisicoY;
  IsShift := ssShift in Shift;
  HandledInKeyDown := True;

  case Key of
    VK_LEFT:
      begin
        if FCaretFisicoX > 0 then
          Dec(FCaretFisicoX)
        else if FCaretFisicoY > 0 then
        begin
          Dec(FCaretFisicoY);
          FCaretFisicoX := GetStrLength(FTesto[FCaretFisicoY]);
        end;
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_RIGHT:
      begin
        if FCaretFisicoX < GetStrLength(FTesto[FCaretFisicoY]) then
          Inc(FCaretFisicoX)
        else if FCaretFisicoY < FTesto.Count - 1 then
        begin
          Inc(FCaretFisicoY);
          FCaretFisicoX := 0;
        end;
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_UP:
      begin
        if (not FWordWrap) or (FEnableRichText and (FCaretFisicoY < Length(FLineCache)) and FLineCache[FCaretFisicoY].IsRich) then
        begin
          if FCaretFisicoY > 0 then
          begin
            CurVisCol := GetVisColFromPhys(FCaretFisicoX, FCaretFisicoY);
            Dec(FCaretFisicoY);
            FCaretFisicoX := GetPhysFromVisCol(CurVisCol, FCaretFisicoY);
          end;
        end
        else
        begin
          CurVIdx := GetCurrentVisualLineIndex;
          if CurVIdx > 0 then
          begin
            TargetVIdx := CurVIdx - 1;
            TargetVL := FVisualLines[TargetVIdx];
            TargetPhysY := TargetVL.FisicaIndex;

            CurScreenVisCol := (GetVisColFromPhys(FCaretFisicoX, FCaretFisicoY) - GetVisColFromPhys(FVisualLines[CurVIdx].StartChar - 1, FCaretFisicoY)) + (FVisualLines[CurVIdx].offsetX div FCharWidth);

            TargetStartVisCol := GetVisColFromPhys(TargetVL.StartChar - 1, TargetPhysY);
            TargetTotalVisCol := TargetStartVisCol + Max(0, CurScreenVisCol - (TargetVL.offsetX div FCharWidth));
            NewPhysX := GetPhysFromVisCol(TargetTotalVisCol, TargetPhysY);

            IsLastOfPhys := (TargetVIdx = FVisualCount - 1) or (FVisualLines[TargetVIdx + 1].FisicaIndex <> TargetPhysY);
            if not IsLastOfPhys and (NewPhysX > TargetVL.StartChar - 1 + TargetVL.Lunghezza) then
              NewPhysX := TargetVL.StartChar - 1 + TargetVL.Lunghezza;
            if NewPhysX < TargetVL.StartChar - 1 then
              NewPhysX := TargetVL.StartChar - 1;

            FCaretFisicoY := TargetPhysY;
            FCaretFisicoX := NewPhysX;
          end;
        end;
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_DOWN:
      begin
        if (not FWordWrap) or (FEnableRichText and (FCaretFisicoY < Length(FLineCache)) and FLineCache[FCaretFisicoY].IsRich) then
        begin
          if FCaretFisicoY < FTesto.Count - 1 then
          begin
            CurVisCol := GetVisColFromPhys(FCaretFisicoX, FCaretFisicoY);
            Inc(FCaretFisicoY);
            FCaretFisicoX := GetPhysFromVisCol(CurVisCol, FCaretFisicoY);
          end;
        end
        else
        begin
          CurVIdx := GetCurrentVisualLineIndex;
          if (CurVIdx >= 0) and (CurVIdx < FVisualCount - 1) then
          begin
            TargetVIdx := CurVIdx + 1;
            TargetVL := FVisualLines[TargetVIdx];
            TargetPhysY := TargetVL.FisicaIndex;

            CurScreenVisCol := (GetVisColFromPhys(FCaretFisicoX, FCaretFisicoY) - GetVisColFromPhys(FVisualLines[CurVIdx].StartChar - 1, FCaretFisicoY)) + (FVisualLines[CurVIdx].offsetX div FCharWidth);

            TargetStartVisCol := GetVisColFromPhys(TargetVL.StartChar - 1, TargetPhysY);
            TargetTotalVisCol := TargetStartVisCol + Max(0, CurScreenVisCol - (TargetVL.offsetX div FCharWidth));
            NewPhysX := GetPhysFromVisCol(TargetTotalVisCol, TargetPhysY);

            IsLastOfPhys := (TargetVIdx = FVisualCount - 1) or (FVisualLines[TargetVIdx + 1].FisicaIndex <> TargetPhysY);
            if not IsLastOfPhys and (NewPhysX > TargetVL.StartChar - 1 + TargetVL.Lunghezza) then
              NewPhysX := TargetVL.StartChar - 1 + TargetVL.Lunghezza;
            if NewPhysX < TargetVL.StartChar - 1 then
              NewPhysX := TargetVL.StartChar - 1;

            FCaretFisicoY := TargetPhysY;
            FCaretFisicoX := NewPhysX;
          end;
        end;
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_HOME:
      begin
        FCaretFisicoX := 0;
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_END:
      begin
        FCaretFisicoX := GetStrLength(FTesto[FCaretFisicoY]);
        AggiornaSelezioneCaret(OldX, OldY, IsShift);
      end;
    VK_BACK:
      begin
        if not FReadOnly then
        begin
          if HaSelezione then
            CancellaSelezione
          else if FEnableRichText and TrovaRangeTagAtomico(FTesto[FCaretFisicoY], FCaretFisicoX - 1, StartDel, EndDel) then
          begin
            DelText := DeleteTextFisico(StartDel, FCaretFisicoY, EndDel, FCaretFisicoY);
            FCaretFisicoX := StartDel;
            RecordDelete(StartDel, FCaretFisicoY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end
          else if FCaretFisicoX > 0 then
          begin
            DelText := DeleteTextFisico(FCaretFisicoX - 1, FCaretFisicoY, FCaretFisicoX, FCaretFisicoY);
            Dec(FCaretFisicoX);
            RecordDelete(FCaretFisicoX, FCaretFisicoY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end
          else if FCaretFisicoY > 0 then
          begin
            PrevLen := GetStrLength(FTesto[FCaretFisicoY - 1]);
            DelText := DeleteTextFisico(PrevLen, FCaretFisicoY - 1, 0, FCaretFisicoY);
            Dec(FCaretFisicoY);
            FCaretFisicoX := PrevLen;
            RecordDelete(PrevLen, FCaretFisicoY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            AggiornaScrollBar;
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end;
        end;
      end;
    VK_DELETE:
      begin
        if not FReadOnly then
        begin
          if HaSelezione then
            CancellaSelezione
          else if FEnableRichText and TrovaRangeTagAtomico(FTesto[FCaretFisicoY], FCaretFisicoX, StartDel, EndDel) then
          begin
            DelText := DeleteTextFisico(StartDel, FCaretFisicoY, EndDel, FCaretFisicoY);
            FCaretFisicoX := StartDel;
            RecordDelete(OldX, OldY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end
          else if FCaretFisicoX < GetStrLength(FTesto[FCaretFisicoY]) then
          begin
            DelText := DeleteTextFisico(FCaretFisicoX, FCaretFisicoY, FCaretFisicoX + 1, FCaretFisicoY);
            RecordDelete(OldX, OldY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end
          else if FCaretFisicoY < FTesto.Count - 1 then
          begin
            DelText := DeleteTextFisico(FCaretFisicoX, FCaretFisicoY, 0, FCaretFisicoY + 1);
            RecordDelete(OldX, OldY, DelText, OldX, OldY, FCaretFisicoX, FCaretFisicoY);
            AggiornaScrollBar;
            DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
          end;
        end;
      end;
    VK_RETURN:
      begin
        if not FReadOnly then
        begin
          GroupID := 0;
          if HaSelezione then
          begin
            GroupID := NuovoGroupID;
            CancellaSelezione(GroupID);
          end;

          InsertTextFisico(FCaretFisicoX, FCaretFisicoY, sLineBreak);

          Inc(FCaretFisicoY);
          FCaretFisicoX := 0;

          RecordInsert(OldX, OldY, sLineBreak, OldX, OldY, FCaretFisicoX, FCaretFisicoY, GroupID);
          AggiornaScrollBar;
          DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
        end;
      end;
    VK_TAB:
      begin
        if not FReadOnly then
        begin
          GroupID := 0;
          if HaSelezione then
          begin
            GroupID := NuovoGroupID;
            CancellaSelezione(GroupID);
          end;

          InsertTextFisico(FCaretFisicoX, FCaretFisicoY, #9);

          Inc(FCaretFisicoX);

          RecordInsert(OldX, OldY, #9, OldX, OldY, FCaretFisicoX, FCaretFisicoY, GroupID);
          DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
        end;
        Key := 0;
      end;
    VK_Z:
      begin
        if ssCtrl in Shift then
        begin
          if ssShift in Shift then Redo else Undo;
        end
        else HandledInKeyDown := False;
      end;
    VK_Y:
      begin
        if ssCtrl in Shift then Redo else HandledInKeyDown := False;
      end;
    VK_C:
      if ssCtrl in Shift then CopiaInAppunti else HandledInKeyDown := False;
    VK_X:
      if ssCtrl in Shift then TagliaInAppunti else HandledInKeyDown := False;
    VK_V:
      if ssCtrl in Shift then IncollaDaAppunti else HandledInKeyDown := False;
    VK_A:
      if ssCtrl in Shift then SelezionaTutto else HandledInKeyDown := False;
  else
    HandledInKeyDown := False;
  end;

  if HandledInKeyDown and FIsRecordingMacro and not FIsPlayingMacro then
  begin
    SetLength(FCurrentMacro.Events, Length(FCurrentMacro.Events) + 1);
    FCurrentMacro.Events[High(FCurrentMacro.Events)].EventType := meSpecialKey;
    FCurrentMacro.Events[High(FCurrentMacro.Events)].Key := Key;
    FCurrentMacro.Events[High(FCurrentMacro.Events)].Shift := Shift;
  end;

  if HandledInKeyDown then
  begin
    SnapCaretToValidPhysX;
    AssicuratiCaretVisibile;
    FShowCaret := True;
    Repaint;
  end;
end;

procedure TGrandeEditorTesto.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
end;

procedure TGrandeEditorTesto.VisualCoordinateToFisico(X, Y: Integer; out OutFisicoX, OutFisicoY: Integer);
var
  VisualClickLine, CaratteriInLarghezza, ClicXCarattere, LineLen, LineOffsetPx: Integer;
  StartLineVisCol, TargetTotalVisCol: Integer;
  VL: TVisualLine;
  IsRich: Boolean;
begin
  OutFisicoX := 0;
  OutFisicoY := 0;

  if FTesto.Count = 0 then Exit;

  if FVisualCount > 0 then
  begin
    VisualClickLine := FTopLine + (Y div FLineHeight);
    VisualClickLine := EnsureRange(VisualClickLine, 0, FVisualCount - 1);

    if not FWordWrap then
    begin
      OutFisicoY := VisualClickLine;
      LineOffsetPx := 0;
    end
    else
    begin
      VL := FVisualLines[VisualClickLine];
      OutFisicoY := VL.FisicaIndex;
      LineOffsetPx := VL.offsetX;
    end;

    OutFisicoY := EnsureRange(OutFisicoY, 0, FTesto.Count - 1);

    CaratteriInLarghezza := FCharWidth;
    if CaratteriInLarghezza <= 0 then CaratteriInLarghezza := 8;

    ClicXCarattere := (X - FMargineNumeri - 5 - LineOffsetPx) div CaratteriInLarghezza;
    if not FWordWrap then
      ClicXCarattere := ClicXCarattere + FLeftCol;

    if ClicXCarattere < 0 then ClicXCarattere := 0;

    IsRich := FEnableRichText and (OutFisicoY < Length(FLineCache)) and FLineCache[OutFisicoY].IsRich;

    if IsRich then
    begin
      OutFisicoX := GetPhysFromVisCol(ClicXCarattere + (LineOffsetPx div CaratteriInLarghezza), OutFisicoY);
    end
    else if not FWordWrap then
    begin
      OutFisicoX := GetPhysFromVisCol(ClicXCarattere, OutFisicoY);
    end
    else
    begin
      StartLineVisCol := GetVisColFromPhys(VL.StartChar - 1, OutFisicoY);
      TargetTotalVisCol := StartLineVisCol + ClicXCarattere;
      OutFisicoX := GetPhysFromVisCol(TargetTotalVisCol, OutFisicoY);

      if not ((VisualClickLine = FVisualCount - 1) or (FVisualLines[VisualClickLine + 1].FisicaIndex <> OutFisicoY)) then
      begin
        if OutFisicoX > VL.StartChar - 1 + VL.Lunghezza then
          OutFisicoX := VL.StartChar - 1 + VL.Lunghezza;
      end;
    end;

    LineLen := GetStrLength(FTesto[OutFisicoY]);
    if OutFisicoX > LineLen then
      OutFisicoX := LineLen;
  end;
end;

procedure TGrandeEditorTesto.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  FX, FY, BM_X, BM_Y, FromVL, FromVC, ToVL, ToVC: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  SetFocus;

  VisualCoordinateToFisico(X, Y, FX, FY);

  if FEnableRichText and (FHoveredLinkTarget <> '') and (Button = mbLeft) then
  begin
    if TrovaBookmark(FHoveredLinkTarget, BM_X, BM_Y) then
    begin
      FisicoToVisibileCoords(FX, FY, FromVL, FromVC);
      PushNavHistory(FX, FY);

      FCaretFisicoX := BM_X;
      FCaretFisicoY := BM_Y;
      PushNavHistory(BM_X, BM_Y);

      FisicoToVisibileCoords(BM_X, BM_Y, ToVL, ToVC);

      ScorriAllaRiga(BM_Y);

      if Assigned(FOnNavigate) then
        FOnNavigate(Self, FromVL + 1, FromVC + 1, ToVL + 1, ToVC + 1);

      AnnullaSelezione;
      AssicuratiCaretVisibile;
      Invalidate;
      Exit;
    end;
  end;

  if Button = mbLeft then
  begin
    if ssShift in Shift then
    begin
      AggiornaSelezioneCaret(FCaretFisicoX, FCaretFisicoY, True);
    end
    else
    begin
      FSelStartX := FX;
      FSelStartY := FY;
      FSelEndX := FX;
      FSelEndY := FY;
    end;

    FCaretFisicoX := FX;
    FCaretFisicoY := FY;
    FSelectingWithMouse := True;
    FShowCaret := True;
    AssicuratiCaretVisibile;
    Invalidate;
  end
  else if Button = mbRight then
  begin
    if not CarattereIsInSelezione(FX, FY) then
    begin
      AnnullaSelezione;
      FCaretFisicoX := FX;
      FCaretFisicoY := FY;
      FSelStartX := FX; FSelStartY := FY;
      FSelEndX := FX;   FSelEndY := FY;
      FShowCaret := True;
      AssicuratiCaretVisibile;
      Invalidate;
    end;
  end;
end;

procedure TGrandeEditorTesto.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  FX, FY, VisCharIdx, LIdx: Integer;
  ParseRes: TLineParseResult;
  OverLink: Boolean;
  LineText: String;
  HBarHeight, VBarWidth: Integer;
  IsOverScrollBars: Boolean;
begin
  inherited MouseMove(Shift, X, Y);

  if FHScrollBar.Visible then
    HBarHeight := FHScrollBar.Height
  else
    HBarHeight := 0;

  VBarWidth := FScrollBar.Width;

  IsOverScrollBars := (X >= ClientWidth - VBarWidth) or
                      (Y >= ClientHeight - HBarHeight) or
                      (X < FMargineNumeri);

  if IsOverScrollBars then
  begin
    Cursor := crDefault;
    FHoveredLinkTarget := '';
  end
  else
  begin
    if FEnableRichText and not FSelectingWithMouse then
    begin
      VisualCoordinateToFisico(X, Y, FX, FY);
      if (FY >= 0) and (FY < FTesto.Count) and (FY < Length(FLineCache)) and FLineCache[FY].IsRich then
      begin
        LineText := FTesto[FY];
        ParseRes := ParseRichTextLine(LineText, FY);
        if (FX >= 0) and (FX < Length(ParseRes.PhysToVis)) then
        begin
          VisCharIdx := ParseRes.PhysToVis[FX];
          OverLink := False;
          for LIdx := 0 to High(ParseRes.Links) do
          begin
            if (VisCharIdx >= ParseRes.Links[LIdx].VisStartX) and
               (VisCharIdx < ParseRes.Links[LIdx].VisEndX) then
            begin
              Cursor := FLinkCursor;
              FHoveredLinkTarget := ParseRes.Links[LIdx].Target;
              OverLink := True;
              Break;
            end;
          end;

          if not OverLink then
          begin
            Cursor := FTextCursor;
            FHoveredLinkTarget := '';
          end;
        end;
      end
      else
      begin
        Cursor := FTextCursor;
        FHoveredLinkTarget := '';
      end;
    end
    else if not FSelectingWithMouse then
    begin
      Cursor := FTextCursor;
      FHoveredLinkTarget := '';
    end;
  end;

  if FSelectingWithMouse and (ssLeft in Shift) then
  begin
    if (Y < 0) or (Y > ClientHeight) then
    begin
      FAutoScrollTimer.Enabled := True;
    end
    else
    begin
      FAutoScrollTimer.Enabled := False;
      VisualCoordinateToFisico(X, Y, FX, FY);
      FCaretFisicoX := FX;
      FCaretFisicoY := FY;

      FSelEndX := FCaretFisicoX;
      FSelEndY := FCaretFisicoY;

      AssicuratiCaretVisibile;
      Invalidate;
    end;
  end;
end;

procedure TGrandeEditorTesto.MouseLeave;
begin
  inherited MouseLeave;
  Cursor := crDefault;
  FHoveredLinkTarget := '';
end;

procedure TGrandeEditorTesto.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FSelectingWithMouse := False;
    FAutoScrollTimer.Enabled := False;
  end;
end;

procedure TGrandeEditorTesto.SpostaCaretAVisualLine(VisualIndex, CarattereX: Integer; MantieniSelezione: Boolean);
var
  VL: TVisualLine;
  OldX, OldY, LineLen: Integer;
begin
  OldX := FCaretFisicoX;
  OldY := FCaretFisicoY;

  if not FWordWrap then
  begin
    FCaretFisicoY := VisualIndex;
    FCaretFisicoX := CarattereX;
  end
  else
  begin
    VL := FVisualLines[VisualIndex];
    FCaretFisicoY := VL.FisicaIndex;

    if CarattereX > VL.Lunghezza then CarattereX := VL.Lunghezza;
    FCaretFisicoX := VL.StartChar - 1 + CarattereX;
  end;

  LineLen := GetStrLength(FTesto[FCaretFisicoY]);
  if FCaretFisicoX > LineLen then
    FCaretFisicoX := LineLen;

  AggiornaSelezioneCaret(OldX, OldY, MantieniSelezione);
  AssicuratiCaretVisibile;
  FShowCaret := True;
  Invalidate;
end;

function TGrandeEditorTesto.PrimaRigaMostrata: Integer;
begin
  if (FVisualCount > 0) and (FTopLine >= 0) and (FTopLine < FVisualCount) then
  begin
    if not FWordWrap then
      Result := FTopLine
    else
      Result := FVisualLines[FTopLine].FisicaIndex;
  end
  else
    Result := -1;
end;

function TGrandeEditorTesto.UltimaRigaMostrata: Integer;
var
  RigheVisibili, IndiceUltimaVisuale, HBarHeight: Integer;
begin
  HBarHeight := 0;
  if not FWordWrap then HBarHeight := FHScrollBar.Height;
  RigheVisibili := Max(0, ((ClientHeight - HBarHeight) div FLineHeight) - 1);
  IndiceUltimaVisuale := Min(FVisualCount - 1, FTopLine + RigheVisibili);
  if IndiceUltimaVisuale >= 0 then
  begin
    if not FWordWrap then
      Result := IndiceUltimaVisuale
    else
      Result := FVisualLines[IndiceUltimaVisuale].FisicaIndex;
  end
  else
    Result := -1;
end;

procedure TGrandeEditorTesto.ScorriAllaRiga(RigaFisica: Integer);
var
  i: Integer;
begin
  if (RigaFisica < 0) or (RigaFisica >= FTesto.Count) then Exit;
  if not FWordWrap then
  begin
    FTopLine := Min(RigaFisica, MaxTopLine);
    FScrollBar.Position := FTopLine;
    Invalidate;
    Exit;
  end;

  for i := 0 to FVisualCount - 1 do
  begin
    if FVisualLines[i].FisicaIndex = RigaFisica then
    begin
      FTopLine := Min(i, MaxTopLine);
      FScrollBar.Position := FTopLine;
      Invalidate;
      Break;
    end;
  end;
end;

procedure TGrandeEditorTesto.CaretBlinkEvent(Sender: TObject);
begin
  if Focused then
  begin
    FShowCaret := not FShowCaret;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.DoEnter;
begin
  inherited DoEnter;
  FShowCaret := True;
  FCaretTimer.Enabled := True;
  Invalidate;
end;

procedure TGrandeEditorTesto.DoExit;
begin
  FCaretTimer.Enabled := False;
  FShowCaret := False;
  inherited DoExit;
  Invalidate;
end;

procedure TGrandeEditorTesto.SetWordWrap(AValue: Boolean);
var
  RigaFisicaCorrente: Integer;
begin
  if FWordWrap <> AValue then
  begin
    RigaFisicaCorrente := PrimaRigaMostrata;

    FWordWrap := AValue;
    FLeftCol := 0;

    AggiornaScrollBar;

    if RigaFisicaCorrente >= 0 then
      ScorriAllaRiga(RigaFisicaCorrente);

    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly <> AValue then
  begin
    FReadOnly := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetMaxUndoLevel(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if FMaxUndoLevel <> AValue then
  begin
    FMaxUndoLevel := AValue;
    while Length(FUndoList) > FMaxUndoLevel do
      Delete(FUndoList, 0, 1);
  end;
end;

procedure TGrandeEditorTesto.SetEnableRichText(AValue: Boolean);
begin
  if FEnableRichText <> AValue then
  begin
    FEnableRichText := AValue;
    FHoveredLinkTarget := '';
    Cursor := crDefault;
    SvuotaCacheImmagini;
    AggiornaCacheTestoCompleto;
    AggiornaScrollBar;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetLinkColor(AValue: TColor);
begin
  if FLinkColor <> AValue then
  begin
    FLinkColor := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetHighlightSelectedWord(AValue: Boolean);
begin
  if FHighlightSelectedWord <> AValue then
  begin
    FHighlightSelectedWord := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetHighlightWholeWordsOnly(AValue: Boolean);
begin
  if FHighlightWholeWordsOnly <> AValue then
  begin
    FHighlightWholeWordsOnly := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetSelectedWordColor(AValue: TColor);
begin
  if FSelectedWordColor <> AValue then
  begin
    FSelectedWordColor := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetHighlightMatchingBracket(AValue: Boolean);
begin
  if FHighlightMatchingBracket <> AValue then
  begin
    FHighlightMatchingBracket := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.SetMatchingBracketColor(AValue: TColor);
begin
  if FMatchingBracketColor <> AValue then
  begin
    FMatchingBracketColor := AValue;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.ScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if FTopLine <> ScrollPos then
  begin
    FTopLine := ScrollPos;
    Invalidate;
  end;
end;

procedure TGrandeEditorTesto.HScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if FLeftCol <> ScrollPos then
  begin
    FLeftCol := ScrollPos;
    Invalidate;
  end;
end;

function TGrandeEditorTesto.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  NuovaPos: Integer;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result then Exit;

  if WheelDelta > 0 then
    NuovaPos := FTopLine - 3
  else
    NuovaPos := FTopLine + 3;

  NuovaPos := EnsureRange(NuovaPos, 0, MaxTopLine);
  if FTopLine <> NuovaPos then
  begin
    FTopLine := NuovaPos;
    FScrollBar.Position := FTopLine;
    Invalidate;
  end;
  Result := True;
end;

procedure TGrandeEditorTesto.Resize;
var
  RigaFisicaInCima: Integer;
begin
  RigaFisicaInCima := PrimaRigaMostrata;

  inherited Resize;

  AggiornaScrollBar;

  if RigaFisicaInCima >= 0 then
    ScorriAllaRiga(RigaFisicaInCima);
end;

procedure TGrandeEditorTesto.RigheCambiate(Sender: TObject);
begin
  FByteSize := Length(FTesto.Text);
  AggiornaCacheTestoCompleto;
  AggiornaScrollBar;
  Invalidate;
  DoNotifyChange(FCaretFisicoX, FCaretFisicoY);
end;

procedure TGrandeEditorTesto.SetTesto(AValue: TStringList);
begin
  FTesto.OnChange := nil;
  FTopLine := 0;
  SetLength(FSearchOperations, 0);
  FNextOpID := 0;
  FHoveredLinkTarget := '';
  SvuotaCacheImmagini;
  FTesto.Assign(AValue);
  if FTesto.Count = 0 then FTesto.Add('');
  FByteSize := Length(FTesto.Text);
  AggiornaCacheTestoCompleto;
  AnnullaSelezione;
  RimuoviEvidenziazioni;
  AzzeraUndoRedo;
  FCaretFisicoX := 0;
  FCaretFisicoY := 0;
  FLeftCol := 0;
  FHoveredLinkTarget := '';
  FNavIndex := -1;
  SetLength(FNavHistory, 0);
  DoNotifyChange(0, 0);
  FTesto.OnChange := @RigheCambiate;
  AggiornaScrollBar;
end;

end.
