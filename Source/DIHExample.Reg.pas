unit DIHExample.Reg;

interface

procedure Register;

implementation

uses
  System.Classes, DIHExample.Memo;

{$R DIHExample.Memo.res}

procedure Register;
begin
  RegisterComponents('DIH Example', [TDIHMemo]);
end;

end.
