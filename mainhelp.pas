unit mainHelp;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, LCLType, grandeeditortesto;

type

  { TForm2 }

  TForm2 = class(TForm)
    Label1: TLabel;
    ListBox1: TListBox;
    Panel1: TPanel;
    Panel2: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
  private
    Editor: TGrandeEditorTesto;
    EdSearch: TEdit;
    BtnSearch, BtnReset: TButton;
    SearchWord: string;              // the word of the search that is on (it is marked in the text)
    AllTopics: TStringList;          // the complete list of the topics
    procedure SearchClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure SearchKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    function TopicHas(const topic, word: string): Boolean;
    function FirstLineWith(const topic, word: string): Integer;
    procedure MarkWord;
    procedure FillList(const word: string);
    function HelpDir: string;
    function TopicFile(const topic: string): string;
    procedure LoadTopic(idx: Integer);
  public
    procedure ShowTopic(const topic: string);
  end;

var
  Form2: TForm2;

implementation

{$R *.lfm}

var
  HelpPlaced: Boolean = False;   // the window was already shown in this session
  HelpLeft, HelpTop: Integer;    // where the user left it

{ TForm2 }

// the texts of the help are in the folder "help" next to the program: one file for each topic, in the format of the editor
function TForm2.HelpDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'help' + PathDelim;
end;

// "Main Purpose" -> main_purpose.txt
function TForm2.TopicFile(const topic: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(topic) do
    if topic[i] in ['A'..'Z'] then Result := Result + Chr(Ord(topic[i]) + 32)
    else if topic[i] in ['a'..'z', '0'..'9'] then Result := Result + topic[i]
    else Result := Result + '_';
  Result := HelpDir + Result + '.txt';
end;

procedure TForm2.LoadTopic(idx: Integer);
var
  sl: TStringList;
  fn: string;
begin
  if (idx < 0) or (idx >= ListBox1.Items.Count) then Exit;
  sl := TStringList.Create;
  try
    fn := TopicFile(ListBox1.Items[idx]);
    if FileExists(fn) then sl.LoadFromFile(fn)
    else
    begin
      sl.Add('<text:style bold="true">' + ListBox1.Items[idx] + '</text:style>');
      sl.Add('');
      sl.Add('This topic has not been written yet.');
    end;
    Editor.Testo := sl;
  finally
    sl.Free;
  end;
  MarkWord;
end;

// the first line of the topic that contains the word, -1 if there is none (the text only: the pictures and the styles of the editor are left out)
function TForm2.FirstLineWith(const topic, word: string): Integer;
var
  sl: TStringList;
  fn, ln: string;
  i, a, b: Integer;
begin
  Result := -1;
  fn := TopicFile(topic);
  if not FileExists(fn) then Exit;
  sl := TStringList.Create;
  try
    sl.LoadFromFile(fn);
    for i := 0 to sl.Count - 1 do
    begin
      ln := sl[i];
      // <image:base64 ...>data</image:base64> goes away
      a := Pos('<image:base64', ln);
      while a > 0 do
      begin
        b := Pos('</image:base64>', ln);
        if b = 0 then b := Length(ln) else b := b + Length('</image:base64>') - 1;
        Delete(ln, a, b - a + 1);
        a := Pos('<image:base64', ln);
      end;
      // the other tags: <text:...> and </text:...>
      a := Pos('<', ln);
      while a > 0 do
      begin
        b := Pos('>', ln);
        if (b > a) and ((Copy(ln, a, 6) = '<text:') or (Copy(ln, a, 7) = '</text:')) then Delete(ln, a, b - a + 1)
        else b := a;
        a := PosEx('<', ln, b + 1);
      end;
      if Pos(LowerCase(word), LowerCase(ln)) > 0 then Exit(i);
    end;
  finally
    sl.Free;
  end;
end;

function TForm2.TopicHas(const topic, word: string): Boolean;
begin
  Result := (Pos(LowerCase(word), LowerCase(topic)) > 0) or (FirstLineWith(topic, word) >= 0);
end;

// the word of the search is marked in the text, and the text goes to its first place
procedure TForm2.MarkWord;
var
  o: TSearchOptions;
  k: Integer;
begin
  Editor.AnnullaEvidenziazioneRicerca;
  if (SearchWord = '') or (ListBox1.ItemIndex < 0) then Exit;
  FillChar(o, SizeOf(o), 0);
  o.SearchType := stText;
  o.CaseSensitive := False;
  o.WholeWord := False;
  o.MatchDiacritics := False;
  o.removeOlder := True;
  Editor.EvidenziaTutti(SearchWord, o, TColor($0080FFFF));
  k := FirstLineWith(ListBox1.Items[ListBox1.ItemIndex], SearchWord);
  if k >= 0 then Editor.ScorriAllaRiga(k);
end;

// the list shows only the topics that contain the word (all of them when it is empty)
procedure TForm2.FillList(const word: string);
var
  i, k: Integer;
  cur: string;
begin
  cur := '';
  if ListBox1.ItemIndex >= 0 then cur := ListBox1.Items[ListBox1.ItemIndex];
  ListBox1.Items.BeginUpdate;
  try
    ListBox1.Items.Clear;
    for i := 0 to AllTopics.Count - 1 do
      if (word = '') or TopicHas(AllTopics[i], word) then ListBox1.Items.Add(AllTopics[i]);
  finally
    ListBox1.Items.EndUpdate;
  end;
  k := ListBox1.Items.IndexOf(cur);
  if k >= 0 then ListBox1.ItemIndex := k
  else if ListBox1.Items.Count > 0 then
  begin
    ListBox1.ItemIndex := 0;
    LoadTopic(0);
  end;
end;

procedure TForm2.SearchClick(Sender: TObject);
var
  w: string;
  sl: TStringList;
begin
  w := Trim(EdSearch.Text);
  SearchWord := w;
  FillList(w);
  MarkWord;
  if (w <> '') and (ListBox1.Items.Count = 0) then
  begin
    sl := TStringList.Create;
    try
      Editor.Testo := sl;
    finally
      sl.Free;
    end;
    Caption := 'TTPaint Help - nothing found for "' + w + '"';
  end
  else if w <> '' then Caption := 'TTPaint Help - ' + IntToStr(ListBox1.Items.Count) + ' topic(s) with "' + w + '"'
  else Caption := 'TTPaint Help';
end;

procedure TForm2.ResetClick(Sender: TObject);
begin
  EdSearch.Text := '';
  SearchClick(nil);
end;

procedure TForm2.SearchKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    SearchClick(nil);
  end
  else if Key = VK_ESCAPE then
  begin
    Key := 0;
    ResetClick(nil);
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  AllTopics := TStringList.Create;
  AllTopics.Assign(ListBox1.Items);
  // the search, at the right of the title
  BtnReset := TButton.Create(Self);
  BtnReset.Parent := Panel1;
  BtnReset.Align := alRight;
  BtnReset.Width := 70;
  BtnReset.BorderSpacing.Around := 4;
  BtnReset.Caption := 'Reset';
  BtnReset.Hint := 'Clear the search: all the topics are in the list again';
  BtnReset.ShowHint := True;
  BtnReset.OnClick := @ResetClick;
  BtnSearch := TButton.Create(Self);
  BtnSearch.Parent := Panel1;
  BtnSearch.Align := alRight;
  BtnSearch.Width := 70;
  BtnSearch.BorderSpacing.Around := 4;
  BtnSearch.Caption := 'Search';
  BtnSearch.Hint := 'Show only the topics that contain the word';
  BtnSearch.ShowHint := True;
  BtnSearch.OnClick := @SearchClick;
  EdSearch := TEdit.Create(Self);
  EdSearch.Parent := Panel1;
  EdSearch.Align := alRight;
  EdSearch.Width := 180;
  EdSearch.BorderSpacing.Around := 8;
  EdSearch.TextHint := 'word to search';
  EdSearch.OnKeyDown := @SearchKey;
  Editor := TGrandeEditorTesto.Create(Self);
  Editor.Parent := Panel2;
  Editor.Align := alClient;
  Editor.EnableRichText:=true;
  Editor.ReadOnly:=true;
  // a window of the main one: it is not a program of its own for the desktop (no icon of its own in the task bar) and it stays over it
  if Application.MainForm <> nil then PopupParent := Application.MainForm;
end;

procedure TForm2.FormShow(Sender: TObject);
var
  mf: TCustomForm;
  x, y: Integer;
begin
  // the first time at the centre of the main window; then where the user left it
  mf := Application.MainForm;
  if HelpPlaced then
    SetBounds(HelpLeft, HelpTop, Width, Height)
  else if mf <> nil then
  begin
    x := mf.Left + (mf.Width - Width) div 2;
    y := mf.Top + (mf.Height - Height) div 2;
    SetBounds(Max(0, x), Max(0, y), Width, Height);
  end;
  HelpPlaced := True;
  HelpLeft := Left;
  HelpTop := Top;
  if ListBox1.ItemIndex < 0 then
  begin
    ListBox1.ItemIndex := 0;
    LoadTopic(0);
  end;
end;

procedure TForm2.FormHide(Sender: TObject);
begin
  HelpLeft := Left;
  HelpTop := Top;
end;

// opens the help on a topic of the list
procedure TForm2.ShowTopic(const topic: string);
var
  i: Integer;
begin
  Show;
  BringToFront;
  i := ListBox1.Items.IndexOf(topic);
  if i < 0 then
  begin
    // the topic is hidden by a search: the search is cleared
    ResetClick(nil);
    i := ListBox1.Items.IndexOf(topic);
  end;
  if i >= 0 then
  begin
    ListBox1.ItemIndex := i;
    LoadTopic(i);
  end;
end;

procedure TForm2.ListBox1Click(Sender: TObject);
begin
  LoadTopic(ListBox1.ItemIndex);
end;

end.
