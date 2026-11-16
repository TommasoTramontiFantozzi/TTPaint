{ The zoom of the wheel on the graphics card.

  While the zoom is animated, the picture that is on the screen is a texture of the card, drawn as a quad that is enlarged or reduced
  at each step: no layout and no redraw of the document are needed in the meantime. When there is no usable card (no OpenGL, or only
  a software renderer) Available is False and the program zooms as it did before. }
unit ttgl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, OpenGLContext, ttgl_gl, ttgl_glx, BGRABitmap, BGRABitmapTypes;

type
  TZoomGL = class
  private
    Ctl: TOpenGLControl;
    Par: TWinControl;
    Tex, Tex2: GLuint;
    HasTex, HasPage: Boolean;
    PgL, PgT, PgR, PgB: Double;          // the quad of the whole page (it fills what the view texture does not reach)
    QL, QT, QR, QB: Double;          // the quad (in pixels of the control)
    BgR, BgG, BgB: Single;
    procedure Render;
    procedure CtlPaint(Sender: TObject);
  public
    Renderer: string;
    constructor Create(AParent: TWinControl);
    destructor Destroy; override;
    // True when a context could be made on a real card (TTP_FORCE_GL=1 accepts a software renderer, to test)
    function Init(l, t, w, h: Integer): Boolean;
    procedure Place(l, t, w, h: Integer);
    procedure Show;
    procedure Hide;
    function Visible: Boolean;
    procedure Upload(bmp: TBitmap);
    procedure UploadPage(bmp: TBitmap);
    function HasPageTexture: Boolean;
    procedure ForgetPage;
    procedure Frame(l, t, r, b: Double; bg: TColor; pl, pt, pr, pb: Double);
  end;

implementation

const
  GL_BGRA_EXT = $80E1;

constructor TZoomGL.Create(AParent: TWinControl);
begin
  Par := AParent;
end;

destructor TZoomGL.Destroy;
begin
  Ctl.Free;
  inherited Destroy;
end;

function TZoomGL.Init(l, t, w, h: Integer): Boolean;
var
  p: PChar;
  low: string;
begin
  Result := False;
  // no libGL on the system (it is loaded when the program starts, without being needed): nothing is created
  if (LibGL = 0) or not Assigned(glGetString) or not Assigned(glXChooseVisual) or not Assigned(glXMakeCurrent) then Exit;
  try
    Ctl := TOpenGLControl.Create(Par);
    Ctl.Parent := Par;
    Ctl.Visible := False;
    Ctl.AutoResizeViewport := True;
    Ctl.OnPaint := @CtlPaint;
    Ctl.SetBounds(l, t, w, h);
    Ctl.Visible := True;
    Ctl.HandleNeeded;
    if not Ctl.MakeCurrent then Exit;
    p := PChar(glGetString(GL_RENDERER));
    if p = nil then Exit;
    Renderer := string(p);
    low := LowerCase(Renderer);
    if (GetEnvironmentVariable('TTP_FORCE_GL') <> '1') and
       ((Pos('llvmpipe', low) > 0) or (Pos('softpipe', low) > 0) or (Pos('swrast', low) > 0) or (Pos('software', low) > 0)) then Exit;
    glGenTextures(1, @Tex);
    glGenTextures(1, @Tex2);
    Result := True;
  except
    Result := False;
  end;
  if Ctl <> nil then Ctl.Visible := False;
end;

procedure TZoomGL.Place(l, t, w, h: Integer);
begin
  if (Ctl.Left <> l) or (Ctl.Top <> t) or (Ctl.Width <> w) or (Ctl.Height <> h) then Ctl.SetBounds(l, t, w, h);
end;

procedure TZoomGL.Show;
begin
  Ctl.Visible := True;
  Ctl.BringToFront;
end;

procedure TZoomGL.Hide;
begin
  Ctl.Visible := False;
end;

function TZoomGL.Visible: Boolean;
begin
  Result := Ctl.Visible;
end;

procedure UploadTo(tex: GLuint; bmp: TBitmap);
var
  b: TBGRABitmap;
  px: TBGRAPixel;
  fmt: GLenum;
begin
  b := TBGRABitmap.Create(bmp);
  try
    // the order of the bytes of a pixel depends on the system
    px.red := 1;
    px.green := 2;
    px.blue := 3;
    px.alpha := 4;
    if PByte(@px)^ = 1 then fmt := GL_RGBA else fmt := GL_BGRA_EXT;
    glBindTexture(GL_TEXTURE_2D, tex);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, b.Width, b.Height, 0, fmt, GL_UNSIGNED_BYTE, b.Data);
  finally
    b.Free;
  end;
end;

procedure TZoomGL.Upload(bmp: TBitmap);
begin
  if not Ctl.MakeCurrent then Exit;
  UploadTo(Tex, bmp);
  HasTex := True;
end;

procedure TZoomGL.UploadPage(bmp: TBitmap);
begin
  if not Ctl.MakeCurrent then Exit;
  UploadTo(Tex2, bmp);
  HasPage := True;
end;

function TZoomGL.HasPageTexture: Boolean;
begin
  Result := HasPage;
end;

procedure TZoomGL.ForgetPage;
begin
  HasPage := False;
end;

procedure DrawQuad(tex: GLuint; l, t, r, b: Double);
begin
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, tex);
  glColor4f(1, 1, 1, 1);
  glBegin(GL_QUADS);
  glTexCoord2f(0, 0); glVertex2f(l, t);
  glTexCoord2f(1, 0); glVertex2f(r, t);
  glTexCoord2f(1, 1); glVertex2f(r, b);
  glTexCoord2f(0, 1); glVertex2f(l, b);
  glEnd;
  glDisable(GL_TEXTURE_2D);
end;

procedure TZoomGL.Render;
begin
  if not Ctl.MakeCurrent then Exit;
  glViewport(0, 0, Ctl.Width, Ctl.Height);
  glClearColor(BgR, BgG, BgB, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, Ctl.Width, Ctl.Height, 0, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glDisable(GL_BLEND);
  if HasPage then DrawQuad(Tex2, PgL, PgT, PgR, PgB);
  if HasTex then DrawQuad(Tex, QL, QT, QR, QB);
  Ctl.SwapBuffers;
end;

procedure TZoomGL.CtlPaint(Sender: TObject);
begin
  Render;
end;

procedure TZoomGL.Frame(l, t, r, b: Double; bg: TColor; pl, pt, pr, pb: Double);
var
  c: LongInt;
begin
  QL := l; QT := t; QR := r; QB := b;
  PgL := pl; PgT := pt; PgR := pr; PgB := pb;
  c := ColorToRGB(bg);
  BgR := (c and $FF) / 255;
  BgG := ((c shr 8) and $FF) / 255;
  BgB := ((c shr 16) and $FF) / 255;
  Render;
end;

end.
