unit uSelecionarUsuario;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, DB, ComCtrls; // Removido Grids, DBGrids. Adicionado ComCtrls

// Forward declaration para TPermissaoController se não estiver na interface de uPermissaoController
type
  TPermissaoController = class;

type
  TfrmSelecionarUsuario = class(TForm)
    pnlBotoes: TPanel;
    btnSelecionar: TButton;
    btnCancelar: TButton;
    lbUsuarios: TListBox; // Substituído TDBGrid por TListBox
    procedure FormCreate(Sender: TObject); // Mantido para inicialização básica se DFM existir
    procedure FormShow(Sender: TObject);
    procedure lbUsuariosDblClick(Sender: TObject); // Evento para ListBox
    procedure btnSelecionarClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FIDEmpresaContexto: Integer;
    FIDUsuarioAIgnorar: Integer;
    FPrivPermissaoController: TPermissaoController;
    procedure PopularListaUsuarios;
  public
    { Public declarations }
    IDUsuarioSelecionado: Integer;
    NomeUsuarioSelecionado: string;
    constructor Create(AOwner: TComponent; APermissaoController: TPermissaoController); reintroduce;
    procedure CarregarEPopularUsuarios(AIDEmpresa, AIDUsuarioAIgnorarParam: Integer);
  end;

var
  frmSelecionarUsuario: TfrmSelecionarUsuario;

implementation

uses uPermissaoController; // Necessário para TPermissaoController

{$R *.dfm}

{ TfrmSelecionarUsuario }

constructor TfrmSelecionarUsuario.Create(AOwner: TComponent; APermissaoController: TPermissaoController);
begin
  inherited Create(AOwner);
  FPrivPermissaoController := APermissaoController;
  IDUsuarioSelecionado := 0;
  NomeUsuarioSelecionado := '';
end;

procedure TfrmSelecionarUsuario.FormCreate(Sender: TObject);
begin
  // Inicializações que não dependem do controller podem ficar aqui,
  // mas o controller é essencial para PopularListaUsuarios.
  IDUsuarioSelecionado := 0;
  NomeUsuarioSelecionado := '';
end;

procedure TfrmSelecionarUsuario.FormDestroy(Sender: TObject);
begin
  inherited Destroy;
end;

procedure TfrmSelecionarUsuario.FormShow(Sender: TObject);
begin
  // A carga de dados é iniciada por CarregarEPopularUsuarios antes do ShowModal.
  // Se a lista estiver vazia, pode ser um sinal de que CarregarEPopularUsuarios não foi chamado.
  if lbUsuarios.Items.Count = 0 then
  begin
    // Poderia adicionar um log ou mensagem, mas PopularListaUsuarios já trata
    // o caso de FPrivPermissaoController não estar atribuído.
    // PopularListaUsuarios; // Chamada aqui pode ser redundante se CarregarEPopularUsuarios for sempre usado.
  end;
  btnSelecionar.Enabled := (lbUsuarios.Items.Count > 0) and (lbUsuarios.ItemIndex <> -1);
end;

procedure TfrmSelecionarUsuario.PopularListaUsuarios;
var
  TempUsuariosList: TStringList;
  i: Integer;
  NomeUsuario: string;
  IDUsuarioAsInt: Integer;
begin
  lbUsuarios.Items.Clear;
  if not Assigned(FPrivPermissaoController) then
  begin
    ShowMessage('Controller de permissão não foi fornecido ao formulário de seleção de usuário.');
    Exit;
  end;

  TempUsuariosList := TStringList.Create;
  try
    if FPrivPermissaoController.CarregarUsuariosPorEmpresa(FIDEmpresaContexto, TempUsuariosList) then
    begin
      for i := 0 to TempUsuariosList.Count - 1 do
      begin
        IDUsuarioAsInt := Integer(TempUsuariosList.Objects[i]);
        if IDUsuarioAsInt <> FIDUsuarioAIgnorar then
        begin
          NomeUsuario := TempUsuariosList[i];
          lbUsuarios.Items.AddObject(NomeUsuario, TObject(IDUsuarioAsInt));
        end;
      end;
      if lbUsuarios.Items.Count > 0 then
        lbUsuarios.ItemIndex := 0; // Seleciona o primeiro item
    end
    else
    begin
      ShowMessage('Falha ao carregar a lista de usuários para cópia.');
    end;
  finally
    TempUsuariosList.Free;
  end;
  btnSelecionar.Enabled := (lbUsuarios.Items.Count > 0) and (lbUsuarios.ItemIndex <> -1);
end;

procedure TfrmSelecionarUsuario.CarregarEPopularUsuarios(AIDEmpresa, AIDUsuarioAIgnorarParam: Integer);
begin
  FIDEmpresaContexto := AIDEmpresa;
  FIDUsuarioAIgnorar := AIDUsuarioAIgnorarParam;
  PopularListaUsuarios;
end;

procedure TfrmSelecionarUsuario.lbUsuariosDblClick(Sender: TObject);
begin
  if (lbUsuarios.ItemIndex <> -1) then
    btnSelecionar.Click;
end;

procedure TfrmSelecionarUsuario.btnSelecionarClick(Sender: TObject);
begin
  if lbUsuarios.ItemIndex <> -1 then
  begin
    IDUsuarioSelecionado := Integer(lbUsuarios.Items.Objects[lbUsuarios.ItemIndex]);
    NomeUsuarioSelecionado := lbUsuarios.Items[lbUsuarios.ItemIndex];
    ModalResult := mrOk;
  end
  else
  begin
    ShowMessage('Nenhum usuário selecionado.');
    ModalResult := mrNone; // Mantém o diálogo aberto
  end;
end;

end.
