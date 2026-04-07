unit DIHExample.Memo;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Winapi.Windows, Winapi.Messages;

type
  /// <summary>
  ///  TDIHMemo - A TMemo descendant with line numbering and a configurable gutter. Used as an example for Delphi Install Helper.
  /// </summary>
  TDIHMemo = class(TMemo)
  private
    FGutterWidth: Integer;
    FGutterColor: TColor;
    FShowLineNumbers: Boolean;
    procedure SetGutterWidth(const Value: Integer);
    procedure SetGutterColor(const Value: TColor);
    procedure SetShowLineNumbers(const Value: Boolean);
  protected
    procedure CreateWnd; override;
    procedure WndProc(var Message: TMessage); override;
    procedure PaintGutter;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property GutterWidth: Integer read FGutterWidth write SetGutterWidth default 40;
    property GutterColor: TColor read FGutterColor write SetGutterColor default clBtnFace;
    property ShowLineNumbers: Boolean read FShowLineNumbers write SetShowLineNumbers default True;
  end;

implementation

{ TDIHMemo }

constructor TDIHMemo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGutterWidth := 40;
  FGutterColor := clBtnFace;
  FShowLineNumbers := True;
end;

procedure TDIHMemo.CreateWnd;
begin
  inherited CreateWnd;
  if FShowLineNumbers then
    SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN, MakeLParam(FGutterWidth, 0));
end;

procedure TDIHMemo.WndProc(var Message: TMessage);
begin
  inherited WndProc(Message);

  // Repaint gutter after any message that causes visual changes
  if FShowLineNumbers and HandleAllocated then
    case Message.Msg of
      WM_PAINT, WM_KEYDOWN, WM_KEYUP, WM_CHAR,
      WM_LBUTTONDOWN, WM_LBUTTONUP, WM_MOUSEMOVE,
      WM_VSCROLL, WM_HSCROLL, WM_MOUSEWHEEL,
      WM_SIZE, WM_SETFONT, WM_SETTEXT,
      EM_REPLACESEL, EM_SETSEL,
      CM_FONTCHANGED, CM_TEXTCHANGED:
        PaintGutter;
    end;
end;

procedure TDIHMemo.SetGutterWidth(const Value: Integer);
begin
  if FGutterWidth <> Value then
  begin
    FGutterWidth := Value;
    if HandleAllocated then
    begin
      SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN, MakeLParam(FGutterWidth, 0));
      Invalidate;
    end;
  end;
end;

procedure TDIHMemo.SetGutterColor(const Value: TColor);
begin
  if FGutterColor <> Value then
  begin
    FGutterColor := Value;
    Invalidate;
  end;
end;

procedure TDIHMemo.SetShowLineNumbers(const Value: Boolean);
begin
  if FShowLineNumbers <> Value then
  begin
    FShowLineNumbers := Value;
    if HandleAllocated then
    begin
      if FShowLineNumbers then
        SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN, MakeLParam(FGutterWidth, 0))
      else
        SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN, MakeLParam(0, 0));
      Invalidate;
    end;
  end;
end;

procedure TDIHMemo.PaintGutter;
var
  DC: HDC;
  R: TRect;
  I, FirstLine, LineCount, LineHeight: Integer;
  Y: Integer;
  OldBkMode: Integer;
  OldFont: HFONT;
  LogFont: TLogFont;
  GutterFont: HFONT;
  TextStr: string;
begin
  DC := GetDC(Handle);
  try
    // Draw gutter background
    R := Rect(0, 0, FGutterWidth - 2, ClientHeight);
    SetBkColor(DC, ColorToRGB(FGutterColor));
    ExtTextOut(DC, 0, 0, ETO_OPAQUE, @R, nil, 0, nil);

    // Draw separator line
    SelectObject(DC, GetStockObject(DC_PEN));
    SetDCPenColor(DC, ColorToRGB(clGrayText));
    MoveToEx(DC, FGutterWidth - 2, 0, nil);
    LineTo(DC, FGutterWidth - 2, ClientHeight);

    // Get line metrics
    FirstLine := SendMessage(Handle, EM_GETFIRSTVISIBLELINE, 0, 0);
    LineCount := Lines.Count;
    if LineCount = 0 then
      LineCount := 1;

    // Create font matching the memo font
    GetObject(Font.Handle, SizeOf(LogFont), @LogFont);
    GutterFont := CreateFontIndirect(LogFont);
    OldFont := SelectObject(DC, GutterFont);
    OldBkMode := SetBkMode(DC, TRANSPARENT);
    SetTextColor(DC, ColorToRGB(clGrayText));

    LineHeight := Abs(Font.Height) + 2;
    Y := 1;
    I := FirstLine;

    while (Y < ClientHeight) and (I < LineCount) do
    begin
      TextStr := IntToStr(I + 1);
      R := Rect(2, Y, FGutterWidth - 4, Y + LineHeight);
      DrawText(DC, PChar(TextStr), Length(TextStr), R, DT_RIGHT or DT_SINGLELINE);
      Inc(Y, LineHeight);
      Inc(I);
    end;

    SetBkMode(DC, OldBkMode);
    SelectObject(DC, OldFont);
    DeleteObject(GutterFont);
  finally
    ReleaseDC(Handle, DC);
  end;
end;

end.
