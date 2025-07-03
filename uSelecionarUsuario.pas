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

implementation

{$R *.dfm}

{ TfrmSelecionarUsuario }

procedure TfrmSelecionarUsuario.FormCreate(Sender: TObject);
begin
  IDUsuarioSelecionado := 0;
  NomeUsuarioSelecionado := '';
  FUsuariosParaCopiaData := TStringList.Create;

  // Configuração do TDBGrid (exemplo, se usando ClientDataSet real)
  // Colunas para grdUsuarios:
  // 1. Título 'ID', FieldName 'ID_USUARIO', Visível=False (ou como preferir)
  // 2. Título 'Nome do Usuário', FieldName 'NOME', Width=350
end;

procedure TfrmSelecionarUsuario.FormShow(Sender: TObject);
begin
  // A carga de dados é feita via CarregarUsuariosParaCopia antes do ShowModal
  if FUsuariosParaCopiaData.Count = 0 then // Se não carregou dados
     SimularCargaUsuariosParaCopia; // Carga de exemplo

  // Popular o grid (simulação, pois não temos ClientDataSet aqui)
  // Em um caso real, o TClientDataSet já estaria populado e conectado ao TDBGrid via TDataSource.
  // Para simulação, poderíamos usar um TStringGrid se não quisermos simular TClientDataSet.
  // Por ora, o TDBGrid ficará vazio nesta simulação sem um TDataSet por trás.
  // Ou, poderíamos popular um TListView ou TListBox.
  // Para simplificar a simulação do DFM, o TDBGrid foi adicionado, mas a lógica de população
  // direta sem um DataSet é mais complexa.
  // Assumindo que o controller popularia um cdsUsuariosCopia.

  if FUsuariosParaCopiaData.Count > 0 then
    btnSelecionar.Enabled := True
  else
    btnSelecionar.Enabled := False;
end;

procedure TfrmSelecionarUsuario.SimularCargaUsuariosParaCopia;
var
  i: Integer;
  UsuarioInfo: TStringList;
begin
  // Limpa o grid ou a fonte de dados do grid
  // grdUsuarios.Columns.Clear; // Se fosse um StringGrid
  // Se fosse ClientDataSet: cdsUsuariosCopia.EmptyDataSet;

  FUsuariosParaCopiaData.Clear;
  // Exemplo: Carregaria todos os usuários da FIDEmpresaContexto, exceto FIDUsuarioAtual
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

  // Popularia o cdsUsuariosCopia com os dados de FUsuariosParaCopiaData
  // Exemplo conceitual de como seria com ClientDataSet:
  {
  cdsUsuariosCopia.Close;
  cdsUsuariosCopia.FieldDefs.Clear;
  cdsUsuariosCopia.FieldDefs.Add('ID_USUARIO', ftInteger);
  cdsUsuariosCopia.FieldDefs.Add('NOME', ftString, 100);
  cdsUsuariosCopia.CreateDataSet;
  cdsUsuariosCopia.Open;

  UsuarioInfo := TStringList.Create;
  try
    for i := 0 to FUsuariosParaCopiaData.Count - 1 do
    begin
      UsuarioInfo.Delimiter := '|';
      UsuarioInfo.DelimitedText := FUsuariosParaCopiaData[i];
      if UsuarioInfo.Count = 2 then
      begin
        cdsUsuariosCopia.Append;
        cdsUsuariosCopia.FieldByName('ID_USUARIO').AsInteger := StrToInt(UsuarioInfo[0]);
        cdsUsuariosCopia.FieldByName('NOME').AsString := UsuarioInfo[1];
        cdsUsuariosCopia.Post;
      end;
    end;
  finally
    UsuarioInfo.Free;
  end;
  }
  // Como estamos sem ClientDataSet, o TDBGrid não mostrará dados.
  // Para um teste funcional mínimo sem TClientDataSet, um TListBox seria mais simples.
  // Ex:
  // lbUsuarios.Items.Clear;
  // for i := 0 to FUsuariosParaCopiaData.Count -1 do
  //   lbUsuarios.Items.Add(ExtractDelimited(2, FUsuariosParaCopiaData[i], ['|']));
end;


procedure TfrmSelecionarUsuario.CarregarUsuariosParaCopia(AIDEmpresa, AIDUsuarioAIgnorar: Integer);
begin
  FIDEmpresaContexto := AIDEmpresa;
  FIDUsuarioAtual := AIDUsuarioAIgnorar;
  // Em uma implementação real, aqui você chamaria o Controller para buscar os usuários
  // e popular o ClientDataSet (cdsUsuariosCopia).
  SimularCargaUsuariosParaCopia; // Para este exemplo, usamos a simulação
end;

procedure TfrmSelecionarUsuario.grdUsuariosDblClick(Sender: TObject);
begin
  // if cdsUsuariosCopia.RecordCount > 0 then
  //   btnSelecionar.Click;
  // Como não temos cdsUsuariosCopia, esta parte é conceitual.
  // Se estivéssemos usando um ListBox:
  // if lbUsuarios.ItemIndex <> -1 then btnSelecionar.Click;
  ShowMessage('Simulação: Duplo clique no grid. Selecionaria o usuário.');
  // Para simular, vamos pegar o primeiro da lista de simulação se houver
  if FUsuariosParaCopiaData.Count > 0 then
  begin
    IDUsuarioSelecionado := StrToInt(ExtractDelimited(1, FUsuariosParaCopiaData[0], ['|']));
    NomeUsuarioSelecionado := ExtractDelimited(2, FUsuariosParaCopiaData[0], ['|']);
    ModalResult := mrOk;
  end;
end;

procedure TfrmSelecionarUsuario.btnSelecionarClick(Sender: TObject);
var
  IDStr, NomeStr: string;
begin
  // if cdsUsuariosCopia.RecordCount > 0 then
  // begin
  //   IDUsuarioSelecionado := cdsUsuariosCopia.FieldByName('ID_USUARIO').AsInteger;
  //   NomeUsuarioSelecionado := cdsUsuariosCopia.FieldByName('NOME').AsString;
  //   ModalResult := mrOk;
  // end
  // else
  // begin
  //   ShowMessage('Nenhum usuário selecionado.');
  //   ModalResult := mrNone; // Permanece no form
  // end;

  // Simulação sem ClientDataSet:
  // Se estivesse usando um ListBox:
  // if lbUsuarios.ItemIndex <> -1 then
  // begin
  //   ExtractStrings(['|'], [], PChar(FUsuariosParaCopiaData[lbUsuarios.ItemIndex]), IDStr, NomeStr);
  //   IDUsuarioSelecionado := StrToIntDef(IDStr, 0);
  //   NomeUsuarioSelecionado := NomeStr;
  //   ModalResult := mrOk;
  // end else ...

  // Para simular, vamos pegar o primeiro da lista de simulação se houver
  if FUsuariosParaCopiaData.Count > 0 then
  begin
    IDUsuarioSelecionado := StrToInt(ExtractDelimited(1, FUsuariosParaCopiaData[0], ['|']));
    NomeUsuarioSelecionado := ExtractDelimited(2, FUsuariosParaCopiaData[0], ['|']);
    ModalResult := mrOk;
  end
  else
  begin
    ShowMessage('Nenhum usuário disponível para selecionar.');
    ModalResult := mrNone;
  end;
end;

destructor TfrmSelecionarUsuario.Destroy;
begin
  FUsuariosParaCopiaData.Free;
  inherited Destroy;
end;

end.
