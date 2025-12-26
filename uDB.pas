unit uDB;

interface

uses
  FireDAC.Comp.Client;

function GetConnection: TFDConnection;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys.Intf,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef,
  FireDAC.ConsoleUI.Wait,
  FireDAC.DApt;

var
  GConn: TFDConnection;

const
  // AJUSTE AQUI PARA O SEU BANCO
  FB_DATABASE = 'C:\ATIP\comercio\BANCO.GDB';
  FB_USER     = 'SYSDBA';
  FB_PASSWORD = 'masterkey';

function GetConnection: TFDConnection;
begin
  if GConn = nil then
  begin
    GConn := TFDConnection.Create(nil);
    GConn.Params.DriverID := 'FB';
    GConn.Params.Database := FB_DATABASE;
    GConn.Params.UserName := FB_USER;
    GConn.Params.Password := FB_PASSWORD;
    GConn.Params.Add('Server=localhost');
    GConn.Params.Add('Protocol=TCPIP');
    // charset se precisar:
    // GConn.Params.Add('CharacterSet=UTF8');
  end;

  if not GConn.Connected then
    GConn.Connected := True;

  Result := GConn;
end;

initialization
  GConn := nil;

finalization
  FreeAndNil(GConn);

end.

