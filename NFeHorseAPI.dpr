program NFeHorseAPI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  uRoutes in 'uRoutes.pas',
  uNFeStorageService in 'uNFeStorageService.pas',
  uNFeDistribuicaoService in 'uNFeDistribuicaoService.pas';

begin
  Writeln('NFeHorseAPI iniciando na porta 9000...');
  RegisterRoutes;

  THorse.Listen(9000);
end.
