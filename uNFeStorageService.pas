unit uNFeStorageService;

interface

uses
  System.SysUtils,
  uNFeDistribuicaoService;

function GetZipBaseDir(const CNPJ: string; RefDate: TDateTime): string;
function SaveDocZipToFile(
  const CNPJ, NSU, Schema: string;
  const ZipBytes: TBytes;
  RefDate: TDateTime
): string;

function LoadUltNSU(const CNPJ: string): string;
procedure SaveUltNSU(const CNPJ, UltNSU: string);

implementation

uses
  System.IOUtils,
  System.Types;

function CleanCNPJ(const CNPJ: string): string;
begin
  Result := OnlyDigits(CNPJ);
end;

function IsInvalidFileChar(Ch: Char; const Invalids: TCharArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Invalids) - 1 do
    if Ch = Invalids[I] then
      Exit(True);
end;

function SanitizeFileName(const Value: string): string;
var
  I: Integer;
  Ch: Char;
  Invalids: TCharArray;
begin
  Result := Value;
  Invalids := TPath.GetInvalidFileNameChars;
  for I := 1 to Length(Result) do
  begin
    Ch := Result[I];
    if IsInvalidFileChar(Ch, Invalids) then
      Result[I] := '_';
  end;
end;

function GetDocumentsRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(TPath.GetDocumentsPath) + 'NFeHorseAPI\';
end;

function GetZipBaseDir(const CNPJ: string; RefDate: TDateTime): string;
var
  Clean: string;
  DirBase: string;
  DirMonth: string;
begin
  Clean := CleanCNPJ(CNPJ);
  DirBase := IncludeTrailingPathDelimiter(GetDocumentsRoot + 'Download');
  DirMonth := IncludeTrailingPathDelimiter(DirBase + FormatDateTime('yyyymm', RefDate));
  Result := IncludeTrailingPathDelimiter(DirMonth + 'Down\' + Clean);
end;

function SaveDocZipToFile(
  const CNPJ, NSU, Schema: string;
  const ZipBytes: TBytes;
  RefDate: TDateTime
): string;
var
  DirFinal: string;
  FileName: string;
  CleanSchema: string;
begin
  Result := '';
  if Length(ZipBytes) = 0 then
    Exit;

  DirFinal := GetZipBaseDir(CNPJ, RefDate);
  ForceDirectories(DirFinal);

  CleanSchema := SanitizeFileName(Schema);
  FileName := DirFinal + NSU + '_' + CleanSchema + '.zip';
  TFile.WriteAllBytes(FileName, ZipBytes);
  Result := FileName;
end;

function GetStateDir(const CNPJ: string): string;
var
  Clean: string;
begin
  Clean := CleanCNPJ(CNPJ);
  Result := IncludeTrailingPathDelimiter(GetDocumentsRoot + 'State\' + Clean);
end;

function LoadUltNSU(const CNPJ: string): string;
var
  Path: string;
begin
  Result := '';
  Path := GetStateDir(CNPJ) + 'ultnsu.txt';
  if TFile.Exists(Path) then
    Result := Trim(TFile.ReadAllText(Path, TEncoding.UTF8));
end;

procedure SaveUltNSU(const CNPJ, UltNSU: string);
var
  Path: string;
begin
  if UltNSU = '' then
    Exit;

  Path := GetStateDir(CNPJ) + 'ultnsu.txt';
  ForceDirectories(ExtractFilePath(Path));
  TFile.WriteAllText(Path, UltNSU, TEncoding.UTF8);
end;

end.
