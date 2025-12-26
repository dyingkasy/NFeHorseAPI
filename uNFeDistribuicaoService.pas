unit uNFeDistribuicaoService;

interface

uses
  System.SysUtils;

type
  TDocZipItem = record
    NSU: string;
    Schema: string;
    ZipBytes: TBytes;
  end;

  TDistribuicaoZipResult = record
    Sucesso: Boolean;
    Mensagem: string;
    cStat: Integer;
    xMotivo: string;
    UltNSU: string;
    MaxNSU: string;
    DocZips: TArray<TDocZipItem>;
  end;

function OnlyDigits(const AValue: string): string;

function DistribuicaoZipPorUltNSU(
  const CNPJ, CertSerie, CertSenha, Ambiente: string;
  CodUF: Integer;
  const UltNSU: string
): TDistribuicaoZipResult;

implementation

uses
  System.NetEncoding,
  System.Variants,
  Xml.XMLDoc,
  Xml.XMLIntf,
  ACBrNFe,
  ACBrDFeSSL,
  ACBrDFeComum.RetDistDFeInt,
  ACBrDFeConfiguracoes,
  ACBrDFe.Conversao;

var
  GBlockedUntil: TDateTime;
  GUltNSUCache: string;
  GMaxNSUCache: string;

function OnlyDigits(const AValue: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
    if CharInSet(AValue[I], ['0'..'9']) then
      Result := Result + AValue[I];
end;

procedure AddDocZip(var Items: TArray<TDocZipItem>; const Item: TDocZipItem);
var
  Len: Integer;
begin
  Len := Length(Items);
  SetLength(Items, Len + 1);
  Items[Len] := Item;
end;

procedure CollectDocZipNodes(const Node: IXMLNode; var Items: TArray<TDocZipItem>);
var
  I: Integer;
  Item: TDocZipItem;
  Base64Text: string;
begin
  if Node = nil then
    Exit;

  if SameText(Node.LocalName, 'docZip') then
  begin
    Base64Text := Trim(Node.Text);
    if Base64Text <> '' then
    begin
      Item.NSU := VarToStr(Node.Attributes['NSU']);
      Item.Schema := VarToStr(Node.Attributes['schema']);
      Item.ZipBytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Text);
      AddDocZip(Items, Item);
    end;
  end;

  for I := 0 to Node.ChildNodes.Count - 1 do
    CollectDocZipNodes(Node.ChildNodes[I], Items);
end;

procedure ConfigureACBr(
  const ACBr: TACBrNFe;
  const CertSerie, CertSenha, Ambiente: string
);
begin
  ACBr.Configuracoes.WebServices.TimeOut := 60000;

  ACBr.Configuracoes.Geral.SSLCryptLib := cryWinCrypt;
  ACBr.Configuracoes.Geral.SSLHttpLib := httpWinHttp;
  ACBr.Configuracoes.Geral.SSLLib := libWinCrypt;

  ACBr.Configuracoes.Certificados.NumeroSerie := CertSerie;
  ACBr.Configuracoes.Certificados.Senha := CertSenha;

  if SameText(Ambiente, 'taHomologacao') or SameText(Ambiente, 'homologacao') then
    ACBr.Configuracoes.WebServices.Ambiente := taHomologacao
  else
    ACBr.Configuracoes.WebServices.Ambiente := taProducao;

  ACBr.Configuracoes.Arquivos.Salvar := False;
end;

function DistribuicaoZipPorUltNSU(
  const CNPJ, CertSerie, CertSenha, Ambiente: string;
  CodUF: Integer;
  const UltNSU: string
): TDistribuicaoZipResult;
var
  ACBr: TACBrNFe;
  CleanCNPJ: string;
  AppPath: string;
  ResponseXml: string;
  XmlDoc: IXMLDocument;
  EffectiveUltNSU: string;
begin
  Result.Sucesso := False;
  Result.Mensagem := '';
  Result.cStat := 0;
  Result.xMotivo := '';
  Result.UltNSU := '';
  Result.MaxNSU := '';
  SetLength(Result.DocZips, 0);

  CleanCNPJ := OnlyDigits(CNPJ);
  if (CleanCNPJ = '') or (CodUF <= 0) then
  begin
    Result.Mensagem := 'Parametros obrigatorios ausentes.';
    Exit;
  end;

  if (GBlockedUntil > 0) and (Now < GBlockedUntil) then
  begin
    Result.cStat := 656;
    Result.Mensagem := 'Limite de consulta atingido. Aguarde para nova consulta.';
    Result.xMotivo := 'Consumo indevido - bloqueio temporario.';
    Result.UltNSU := GUltNSUCache;
    Result.MaxNSU := GMaxNSUCache;
    Exit;
  end;

  if UltNSU <> '' then
    EffectiveUltNSU := UltNSU
  else
    EffectiveUltNSU := '0';

  ACBr := TACBrNFe.Create(nil);
  try
    AppPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    ACBr.Configuracoes.Arquivos.PathSchemas := AppPath + 'Schemas\NFe';

    ConfigureACBr(ACBr, CertSerie, CertSenha, Ambiente);

    ACBr.DistribuicaoDFePorUltNSU(CodUF, CleanCNPJ, EffectiveUltNSU);

    with ACBr.WebServices.DistribuicaoDFe.retDistDFeInt do
    begin
      Result.cStat := cStat;
      Result.xMotivo := xMotivo;
      Result.UltNSU := ultNSU;
      Result.MaxNSU := maxNSU;
    end;

    GUltNSUCache := Result.UltNSU;
    GMaxNSUCache := Result.MaxNSU;

    Result.Sucesso := Result.cStat in [137, 138];

    if Result.cStat = 138 then
      Result.Mensagem := 'Documentos localizados.'
    else if Result.cStat = 137 then
      Result.Mensagem := 'Nenhum documento localizado.'
    else
      Result.Mensagem := Format('Erro na SEFAZ: %d - %s', [Result.cStat, Result.xMotivo]);

    ResponseXml := ACBr.WebServices.DistribuicaoDFe.retDistDFeInt.XML;
    if ResponseXml <> '' then
    begin
      XmlDoc := LoadXMLData(ResponseXml);
      CollectDocZipNodes(XmlDoc.DocumentElement, Result.DocZips);
    end;

    if Result.Sucesso and
       (
         (Result.cStat = 137) or
         ((Result.UltNSU <> '') and (Result.MaxNSU <> '') and (Result.UltNSU = Result.MaxNSU))
       ) then
      GBlockedUntil := Now + EncodeTime(1, 0, 0, 0);

  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      if Pos('Consumo Indevido', E.Message) > 0 then
      begin
        Result.cStat := 656;
        Result.xMotivo := 'Consumo Indevido';
        Result.Mensagem := E.Message;
        GBlockedUntil := Now + EncodeTime(1, 0, 0, 0);
      end
      else
      begin
        if Result.cStat = 0 then
          Result.cStat := -1;
        Result.Mensagem := 'Erro interno: ' + E.Message;
      end;
    end;
  end;

  ACBr.Free;
end;

initialization
  GBlockedUntil := 0;
  GUltNSUCache := '';
  GMaxNSUCache := '';

end.
