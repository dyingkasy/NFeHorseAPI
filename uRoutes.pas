unit uRoutes;

interface

procedure RegisterRoutes;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  System.Zip,
  Horse,
  uNFeDistribuicaoService,
  uNFeStorageService;

function StatusFromDistrib(const R: TDistribuicaoZipResult): Integer;
begin
  if R.Sucesso then
    Exit(200);

  if R.cStat = 656 then
    Exit(429);

  if (R.cStat > 0) and (R.cStat <> -1) then
    Exit(502);

  Result := 500;
end;

procedure GetPing(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  Res.Send('pong');
end;

function GetJsonValue(const Obj: TJSONObject; const Name, DefaultValue: string): string;
var
  Val: TJSONValue;
begin
  if Obj = nil then
    Exit(DefaultValue);

  Val := Obj.GetValue(Name);
  if Val = nil then
    Exit(DefaultValue);

  Result := Val.Value;
end;

procedure PostZipByCNPJ(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Body: TJSONObject;
  CNPJ: string;
  CertSerie: string;
  CertSenha: string;
  Ambiente: string;
  UltNSU: string;
  CodUF: Integer;
  R: TDistribuicaoZipResult;
  ZipStream: TMemoryStream;
  ZipFile: TZipFile;
  Item: TDocZipItem;
  EntryName: string;
  BytesStream: TBytesStream;
  RefDate: TDateTime;
  Err: TJSONObject;
begin
  Body := nil;
  if Trim(Req.Body) <> '' then
  begin
    Body := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
  end;

  try
    CNPJ := OnlyDigits(Req.Params.Items['cnpj']);
    if CNPJ = '' then
      CNPJ := OnlyDigits(GetJsonValue(Body, 'cnpj', ''));

    CertSerie := GetJsonValue(Body, 'certSerie', '');
    CertSenha := GetJsonValue(Body, 'certSenha', '');
    Ambiente := GetJsonValue(Body, 'ambiente', 'producao');
    UltNSU := GetJsonValue(Body, 'ultNSU', '');
    CodUF := StrToIntDef(GetJsonValue(Body, 'codUF', '0'), 0);
  finally
    Body.Free;
  end;

  if CNPJ = '' then
  begin
    Err := TJSONObject.Create;
    try
      Err.AddPair('sucesso', TJSONBool.Create(False));
      Err.AddPair('mensagem', 'CNPJ nao informado.');
      Res.Status(400).ContentType('application/json').Send(Err.ToJSON);
    finally
      Err.Free;
    end;
    Exit;
  end;

  if CodUF = 0 then
  begin
    Err := TJSONObject.Create;
    try
      Err.AddPair('sucesso', TJSONBool.Create(False));
      Err.AddPair('mensagem', 'CodUF nao informado.');
      Res.Status(400).ContentType('application/json').Send(Err.ToJSON);
    finally
      Err.Free;
    end;
    Exit;
  end;

  if UltNSU = '' then
    UltNSU := LoadUltNSU(CNPJ);
  if UltNSU = '' then
    UltNSU := '0';

  R := DistribuicaoZipPorUltNSU(CNPJ, CertSerie, CertSenha, Ambiente, CodUF, UltNSU);


  if (R.cStat = 138) and (Length(R.DocZips) > 0) then
  begin
    RefDate := Now;
    ZipStream := TMemoryStream.Create;
    ZipFile := TZipFile.Create;
    try
      ZipFile.Open(ZipStream, zmWrite);
      for Item in R.DocZips do
      begin
        SaveDocZipToFile(CNPJ, Item.NSU, Item.Schema, Item.ZipBytes, RefDate);
        EntryName := Item.NSU + '_' + Item.Schema + '.zip';
        BytesStream := TBytesStream.Create(Item.ZipBytes);
        try
          ZipFile.Add(BytesStream, EntryName, zcStored);
        finally
          BytesStream.Free;
        end;
      end;
      ZipFile.Close;

      ZipStream.Position := 0;
      Res.Status(200)
         .ContentType('application/zip')
         .Send(ZipStream);
      ZipStream := nil;

      if R.UltNSU <> '' then
        SaveUltNSU(CNPJ, R.UltNSU);
    finally
      ZipFile.Free;
      ZipStream.Free;
    end;
    Exit;
  end;

  if R.cStat = 137 then
  begin
    Res.Status(204).Send('');
    Exit;
  end;

  Err := TJSONObject.Create;
  try
    Err.AddPair('sucesso', TJSONBool.Create(False));
    Err.AddPair('mensagem', R.Mensagem);
    Err.AddPair('cStat', TJSONNumber.Create(R.cStat));
    Err.AddPair('xMotivo', R.xMotivo);
    Res.Status(StatusFromDistrib(R)).ContentType('application/json').Send(Err.ToJSON);
  finally
    Err.Free;
  end;
end;

procedure RegisterRoutes;
begin
  THorse.Get('/ping', GetPing);
  THorse.Post('/nfe/zip/:cnpj', PostZipByCNPJ);
end;

end.
