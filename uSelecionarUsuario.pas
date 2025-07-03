unit uSelecionarUsuario;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, DBGrids, StdCtrls, ExtCtrls, DB;

type
  TfrmSelecionarUsuario = class(TForm)
    pnlBotoes: TPanel;
    btnSelecionar: TButton;
    btnCancelar: TButton;
    grdUsuarios: TDBGrid;
    dsUsuariosCopia: TDataSource;
    // cdsUsuariosCopia: TClientDataSet; // Em um projeto real
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure grdUsuariosDblClick(Sender: TObject);
    procedure btnSelecionarClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject); // Adicionado FormDestroy
  private
    { Private declarations }
    FIDEmpresaContexto: Integer;
    FIDUsuarioAtual: Integer;
    FUsuariosParaCopiaData: TStringList; // Simulação: "ID|NOME"
    procedure SimularCargaUsuariosParaCopia;

  public
    { Public declarations }
    IDUsuarioSelecionado: Integer;
    NomeUsuarioSelecionado: string;
    procedure CarregarUsuariosParaCopia(AIDEmpresa, AIDUsuarioAIgnorar: Integer);
  end;

var
  frmSelecionarUsuario: TfrmSelecionarUsuario;

// Função auxiliar para extrair campos de uma string delimitada
function GetDelimitedField(const SourceString: string; Delimiter: Char; FieldIndex: Integer): string;

implementation

{$R *.dfm}

function GetDelimitedField(const SourceString: string; Delimiter: Char; FieldIndex: Integer): string;
var
  P: Integer;
  CurrentIndex: Integer;
  TempStr: string;
  StartPos: Integer; // Não utilizado na lógica atual, mas comum em outras implementações
begin
  Result := '';
  if FieldIndex < 1 then Exit;

  TempStr := SourceString;
  CurrentIndex := 1;

  while (CurrentIndex <= FieldIndex) and (TempStr <> '') do
  begin
    P := Pos(Delimiter, TempStr);
    if P = 0 then // Último campo ou único campo
    begin
      if CurrentIndex = FieldIndex then
        Result := TempStr;
      TempStr := ''; // Força saída do loop
    end
    else
    begin
      if CurrentIndex = FieldIndex then
      begin
        Result := Copy(TempStr, 1, P - 1);
        TempStr := ''; // Força saída do loop
      end
      else
      begin
        // Remove o campo atual e o delimitador para processar o próximo
        TempStr := Copy(TempStr, P + 1, Length(TempStr));
      end;
    end;
    Inc(CurrentIndex);
  end;
end;

{ TfrmSelecionarUsuario }

procedure TfrmSelecionarUsuario.FormCreate(Sender: TObject);
begin
  IDUsuarioSelecionado := 0;
  NomeUsuarioSelecionado := '';
  FUsuariosParaCopiaData := TStringList.Create;
end;

procedure TfrmSelecionarUsuario.FormDestroy(Sender: TObject); // Implementação do Destructor
begin
  FUsuariosParaCopiaData.Free;
  inherited Destroy; // Chama o destructor da classe pai
end;

procedure TfrmSelecionarUsuario.FormShow(Sender: TObject);
begin
  if FUsuariosParaCopiaData.Count = 0 then
     SimularCargaUsuariosParaCopia;

  if FUsuariosParaCopiaData.Count > 0 then
    btnSelecionar.Enabled := True
  else
    btnSelecionar.Enabled := False;
end;

procedure TfrmSelecionarUsuario.SimularCargaUsuariosParaCopia;
//var
  // i: Integer; // Não usado na simulação atual
  // UsuarioInfo: TStringList; // Não usado na simulação atual
begin
  FUsuariosParaCopiaData.Clear;
  if FIDEmpresaContexto = 1 then
  begin
    if FIDUsuarioAtual <> 101 then FUsuariosParaCopiaData.Add('101|Usuário Alpha');
    if FIDUsuarioAtual <> 102 then FUsuariosParaCopiaData.Add('102|Usuário Beta');
    if FIDUsuarioAtual <> 103 then FUsuariosParaCopiaData.Add('103|Admin Empresa A');
  end
  else if FIDEmpresaContexto = 2 then
  begin
    if FIDUsuarioAtual <> 201 then FUsuariosParaCopiaData.Add('201|Usuário Gamma');
    if FIDUsuarioAtual <> 202 then FUsuariosParaCopiaData.Add('202|Usuário Delta');
  end;

  // Aqui seria a lógica para popular o TClientDataSet (cdsUsuariosCopia)
  // e o TDBGrid o exibiria. Como não temos o CDS, o grid ficará vazio.
  // Para teste visual sem CDS, um TListBox ou TStringGrid seria mais direto de popular.
  // Exemplo de como seria com TListBox (se existisse um 'lbUsuarios' no form):
  (*
  lbUsuarios.Items.Clear;
  for i := 0 to FUsuariosParaCopiaData.Count - 1 do
    lbUsuarios.Items.AddObject(
      GetDelimitedField(FUsuariosParaCopiaData[i], '|', 2), // Nome
      TObject(StrToIntDef(GetDelimitedField(FUsuariosParaCopiaData[i], '|', 1),0)) // ID
    );
  *)
end;


procedure TfrmSelecionarUsuario.CarregarUsuariosParaCopia(AIDEmpresa, AIDUsuarioAIgnorar: Integer);
begin
  FIDEmpresaContexto := AIDEmpresa;
  FIDUsuarioAtual := AIDUsuarioAIgnorar;
  SimularCargaUsuariosParaCopia;
end;

procedure TfrmSelecionarUsuario.grdUsuariosDblClick(Sender: TObject);
var
  DataLinhaSimulada: string; // Para simulação
begin
  // Lógica real com TDBGrid e DataSet:
  // if cdsUsuariosCopia.RecordCount > 0 then
  //   btnSelecionar.Click;

  // Simulação, pois não temos cdsUsuariosCopia populado:
  // Vamos simular a seleção do primeiro usuário da lista de simulação
  if FUsuariosParaCopiaData.Count > 0 then
  begin
    DataLinhaSimulada := FUsuariosParaCopiaData[0]; // Pega o primeiro para o exemplo
    IDUsuarioSelecionado := StrToIntDef(GetDelimitedField(DataLinhaSimulada, '|', 1), 0);
    NomeUsuarioSelecionado := GetDelimitedField(DataLinhaSimulada, '|', 2);
    if IDUsuarioSelecionado > 0 then // Verifica se conseguiu um ID válido
        ModalResult := mrOk
    else
        ShowMessage('Erro ao obter dados do usuário selecionado (simulação).');
  end
  else
  begin
    ShowMessage('Nenhum usuário para selecionar por duplo clique (simulação).');
  end;
end;

procedure TfrmSelecionarUsuario.btnSelecionarClick(Sender: TObject);
var
  DataLinhaSimulada: string; // Para simulação
begin
  // Lógica real com TDBGrid e DataSet:
  // if cdsUsuariosCopia.Active and (cdsUsuariosCopia.RecordCount > 0) then
  // begin
  //   IDUsuarioSelecionado := cdsUsuariosCopia.FieldByName('ID_USUARIO').AsInteger;
  //   NomeUsuarioSelecionado := cdsUsuariosCopia.FieldByName('NOME').AsString;
  //   ModalResult := mrOk;
  // end
  // else
  // begin
  //   ShowMessage('Nenhum usuário selecionado.');
  //   ModalResult := mrNone;
  // end;

  // Simulação, pois não temos cdsUsuariosCopia populado:
  // Vamos simular a seleção do primeiro usuário da lista de simulação
  // Em um cenário real com TDBGrid, você pegaria o registro corrente do DataSet.
  if FUsuariosParaCopiaData.Count > 0 then
  begin
    DataLinhaSimulada := FUsuariosParaCopiaData[0]; // Pega o primeiro para o exemplo
    IDUsuarioSelecionado := StrToIntDef(GetDelimitedField(DataLinhaSimulada, '|', 1), 0);
    NomeUsuarioSelecionado := GetDelimitedField(DataLinhaSimulada, '|', 2);

    if IDUsuarioSelecionado > 0 then // Verifica se conseguiu um ID válido
        ModalResult := mrOk
    else
    begin
        ShowMessage('Erro ao obter dados do usuário selecionado (simulação).');
        ModalResult := mrNone; // Permanece no form
    end;
  end
  else
  begin
    ShowMessage('Nenhum usuário disponível para selecionar.');
    ModalResult := mrNone; // Permanece no form
  end;
end;

end.
