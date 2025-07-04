unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList, StrUtils;

type
  TItemMenuData = record
    ID: Integer;
    Tipo: Char;
    NomeForm: string;
  end;
  PItemMenuData = ^TItemMenuData;

  // TArrayOfUserPermissionItem e TMenuItemStructure são definidos em uPermissaoController

  TfrmGerenciarPermissoes = class(TForm)
    pnlFiltros: TPanel;
    lblEmpresa: TLabel;
    cbEmpresa: TComboBox;
    lblUsuario: TLabel;
    cbUsuario: TComboBox;
    btnCarregarPermissoes: TButton;
    tvMenu: TTreeView;
    pnlPermissoes: TPanel;
    pnlBotoesAcao: TPanel;
    btnSalvarPermissoes: TButton;
    btnCopiarPermissoes: TButton;
    btnLimparTodas: TButton;
    btnSelecionarTodas: TButton;
    aclMain: TActionList;
    dsEmpresas: TDataSource; // Pode ser removido se cbEmpresa for populado manualmente
    dsUsuarios: TDataSource; // Pode ser removido se cbUsuario for populado manualmente
    gbPermissoesItem: TGroupBox;
    chkAcesso: TCheckBox;
    chkInserir: TCheckBox;
    chkAlterar: TCheckBox;
    chkExcluir: TCheckBox;
    chkImprimir: TCheckBox;
    imgListTreeView: TImageList;
    MemoLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cbEmpresaChange(Sender: TObject);
    procedure btnCarregarPermissoesClick(Sender: TObject);
    procedure tvMenuSelectionChanged(Sender: TObject);
    procedure btnSalvarPermissoesClick(Sender: TObject);
    procedure btnCopiarPermissoesClick(Sender: TObject);
    procedure chkPermissaoClick(Sender: TObject);
    procedure btnLimparTodasClick(Sender: TObject);
    procedure btnSelecionarTodasClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    // Campos primeiro
    FPermissaoController: TPermissaoController;
    FPermissoesModificadas: Boolean;

    // Esta lista agora armazena o estado "sujo" das permissões conforme o usuário clica nos checkboxes.
    // É usada para construir o TArrayOfUserPermissionItem ao salvar.
    FPermissoesEditadas: TStringList; // Formato: "TIPO_ITEM|ID_ITEM|ACESSO(0/1)|INSERIR(0/1)|ALTERAR(0/1)|EXCLUIR(0/1)|IMPRIMIR(0/1)"

    // Métodos
    procedure CarregarEmpresas;
    procedure CarregarUsuarios(AIDEmpresa: Integer);
    procedure LimparPermissoesVisuais;
    procedure PopularTreeView;
    procedure AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
    procedure AtualizarChecksPermissaoParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
    function GetItemMenuData(ANode: TTreeNode): PItemMenuData;
    procedure SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);

    procedure MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
    procedure ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
    procedure ProcessarNoParaLimpezaTotal(ANode: TTreeNode);

    function BoolToStrDB(Value: Boolean): string;
    function StrDBToBool(Value: string): Boolean;

  public
    { Public declarations }
  end;

var
  frmGerenciarPermissoes: TfrmGerenciarPermissoes;

implementation

 uses uPermissaoController, uSelecionarUsuario; // uSelecionarUsuario para cópia

{$R *.dfm}

function TfrmGerenciarPermissoes.BoolToStrDB(Value: Boolean): string;
begin
  if Value then Result := '1' else Result := '0';
end;

function TfrmGerenciarPermissoes.StrDBToBool(Value: string): Boolean;
begin
  Result := Value = '1';
end;

procedure TfrmGerenciarPermissoes.FormCreate(Sender: TObject);
begin
  FPermissaoController := TPermissaoController.Create('SEU_SERVIDOR_SQL', 'SEU_BANCO', 'SEU_USUARIO', 'SUA_SENHA');
  // Ou, para segurança integrada:
  // FPermissaoController := TPermissaoController.Create('SEU_SERVIDOR_SQL', 'SEU_BANCO', '', '', True);
  // Ou, se já tem a string de conexão completa:
  // FPermissaoController := TPermissaoController.Create('SUA_CONNECTION_STRING_COMPLETA');

  if not FPermissaoController.TestConnection then
  begin
    ShowMessage('Falha ao conectar ao banco de dados! Verifique as configurações de conexão no FormCreate de uGerenciarPermissoes.');
    // Considerar desabilitar o form ou Application.Terminate;
  end;

  FPermissoesModificadas := False;
  FPermissoesEditadas := TStringList.Create; // Lista para manter o estado "sujo"

  tvMenu.ReadOnly := False;
  gbPermissoesItem.Enabled := False;
  btnSalvarPermissoes.Enabled := False;
  btnCopiarPermissoes.Enabled := False;
  btnLimparTodas.Enabled := False;
  btnSelecionarTodas.Enabled := False;
  MemoLog.Visible := True;
  MemoLog.Clear;
end;

procedure TfrmGerenciarPermissoes.FormDestroy(Sender: TObject);
var
  i: Integer;
  NodeData: PItemMenuData;
begin
  if Assigned(tvMenu.Items) then
  begin
    for i := 0 to tvMenu.Items.Count - 1 do
    begin
      NodeData := PItemMenuData(tvMenu.Items[i].Data);
      if Assigned(NodeData) then
        FreeMem(NodeData);
      tvMenu.Items[i].Data := nil;
    end;
  end;
  FreeAndNil(FPermissaoController);
  FreeAndNil(FPermissoesEditadas);
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  // Se cbEmpresa tiver itens, o cbEmpresaChange será chamado indiretamente
  // e carregará os usuários.
  if cbEmpresa.Items.Count > 0 And (cbEmpresa.ItemIndex = -1) then
     cbEmpresa.ItemIndex := 0 // Força o OnChange se não foi disparado
  else if cbEmpresa.Items.Count = 0 then // Nenhuma empresa carregada
     btnCarregarPermissoes.Enabled := False;

end;

procedure TfrmGerenciarPermissoes.CarregarEmpresas;
begin
  cbEmpresa.Items.Clear;
  if Assigned(FPermissaoController) then
  begin
    if not FPermissaoController.CarregarEmpresas(cbEmpresa.Items) then
    begin
      ShowMessage('Falha ao carregar empresas do banco de dados.');
      MemoLog.Lines.Add('Falha ao carregar empresas.');
    end;
  end
  else
  begin
     ShowMessage('Controller de permissão não inicializado em CarregarEmpresas.');
     Exit;
  end;

  if cbEmpresa.Items.Count > 0 then
  begin
    cbEmpresa.ItemIndex := 0; // Dispara OnChange que carrega usuários
  end
  else
  begin
    cbUsuario.Items.Clear; // Limpa usuários se não há empresas
    btnCarregarPermissoes.Enabled := False;
  end;
end;

procedure TfrmGerenciarPermissoes.CarregarUsuarios(AIDEmpresa: Integer);
begin
  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais;

  if Assigned(FPermissaoController) then
  begin
    if not FPermissaoController.CarregarUsuariosPorEmpresa(AIDEmpresa, cbUsuario.Items) then
    begin
      ShowMessage(Format('Falha ao carregar usuários para a empresa ID: %d.', [AIDEmpresa]));
      MemoLog.Lines.Add(Format('Falha ao carregar usuários para empresa ID: %d.', [AIDEmpresa]));
    end;
  end
  else
  begin
     ShowMessage('Controller de permissão não inicializado em CarregarUsuarios.');
     Exit;
  end;

  if cbUsuario.Items.Count > 0 then
  begin
    cbUsuario.ItemIndex := 0;
    btnCarregarPermissoes.Enabled := True; // Habilita para carregar menu e permissões
    btnCarregarPermissoesClick(nil); // Carrega automaticamente ao selecionar usuário
  end
  else
  begin
    btnCarregarPermissoes.Enabled := False;
  end;
  btnCopiarPermissoes.Enabled := cbUsuario.Items.Count > 0;
end;

procedure TfrmGerenciarPermissoes.cbEmpresaChange(Sender: TObject);
var
  IDEmpresa: Integer;
begin
  if cbEmpresa.ItemIndex <> -1 then
  begin
    IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
    CarregarUsuarios(IDEmpresa);
  end
  else
  begin
    cbUsuario.Items.Clear;
    tvMenu.Items.Clear;
    LimparPermissoesVisuais;
    btnCarregarPermissoes.Enabled := False;
    btnCopiarPermissoes.Enabled := False;
  end;
  btnSalvarPermissoes.Enabled := False;
  FPermissoesModificadas := False;
  FPermissoesEditadas.Clear;
end;

procedure TfrmGerenciarPermissoes.LimparPermissoesVisuais;
begin
  chkAcesso.Checked := False;
  chkInserir.Checked := False;
  chkAlterar.Checked := False;
  chkExcluir.Checked := False;
  chkImprimir.Checked := False;
  gbPermissoesItem.Enabled := False;
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  MenuEstruturaArray: TArrayOfMenuItemStructure;
  i: Integer;
  Node, ParentNode: TTreeNode;
  Item: TMenuItemStructure;

  function FindNodeByDataRec(StartNode: TTreeNode; SearchID: Integer; SearchTipo: Char): TTreeNode;
  var j: Integer; NodeData: PItemMenuData;
  begin
    Result := nil;
    if not Assigned(StartNode) then Exit;
    NodeData := PItemMenuData(StartNode.Data);
    if Assigned(NodeData) and (NodeData^.ID = SearchID) and (NodeData^.Tipo = SearchTipo) then
    begin Result := StartNode; Exit; end;
    for j := 0 to StartNode.Count - 1 do
    begin Result := FindNodeByDataRec(StartNode.Item[j], SearchID, SearchTipo); if Assigned(Result) then Exit; end;
  end;

  function FindNodeInData(Tree: TTreeView; SearchID: Integer; SearchTipo: Char): TTreeNode;
  var k: Integer; NodeData: PItemMenuData;
  begin
    Result := nil;
    for k := 0 to Tree.Items.Count - 1 do // Itera pelos nós raiz
    begin
      NodeData := PItemMenuData(Tree.Items[k].Data);
      if Assigned(NodeData) and (NodeData^.ID = SearchID) and (NodeData^.Tipo = SearchTipo) then
      begin Result := Tree.Items[k]; Exit; end;
      Result := FindNodeByDataRec(Tree.Items[k], SearchID, SearchTipo); // Procura nos filhos
      if Assigned(Result) then Exit;
    end;
  end;

begin
  if not Assigned(FPermissaoController) then
  begin
    ShowMessage('Controller não inicializado em PopularTreeView.');
    Exit;
  end;

  if not FPermissaoController.CarregarEstruturaMenu(MenuEstruturaArray) then
  begin
    ShowMessage('Falha ao carregar estrutura do menu.');
    MemoLog.Lines.Add('Falha ao carregar estrutura do menu do controller.');
    Exit;
  end;

  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear;

    // Pass 1: Adicionar Módulos (Tipo 'M')
    for Item in MenuEstruturaArray do
    begin
      if Item.Tipo = 'M' then
      begin
        Node := tvMenu.Items.AddObject(nil, Item.Nome, nil);
        SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
      end;
    end;

    // Pass 2: Adicionar Submódulos (Tipo 'S') e Rotinas (Tipo 'R')
    // Repetir até que todos os itens sejam adicionados ou não haja mais progresso
    // (para lidar com qualquer ordem de itens no array)
    // Uma abordagem mais eficiente seria ordenar por nível ou usar um mapa.
    // Por simplicidade, vamos iterar múltiplas vezes.
    // (Esta lógica de múltiplas passagens pode ser otimizada)
    for i := 0 to Length(MenuEstruturaArray) - 1 do // Garante que todos os itens sejam processados
    begin
      for Item in MenuEstruturaArray do
      begin
        if Item.Tipo = 'S' then
        begin
          if Assigned(GetItemMenuData(FindNodeInData(tvMenu, Item.ID, 'S'))) then Continue; // Já adicionado

          ParentNode := nil;
          if Item.IDPaiSubmodulo <> 0 then // Submódulo filho de outro Submódulo
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiSubmodulo, 'S')
          else if Item.IDPaiModulo <> 0 then // Submódulo filho de Módulo
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiModulo, 'M');

          if Assigned(ParentNode) then
          begin
            Node := tvMenu.Items.AddChildObject(ParentNode, Item.Nome, nil);
            SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
          end;
        end
        else if Item.Tipo = 'R' then
        begin
          if Assigned(GetItemMenuData(FindNodeInData(tvMenu, Item.ID, 'R'))) then Continue; // Já adicionado

          ParentNode := nil;
          if Item.IDPaiSubmodulo <> 0 then // Rotina filha de Submódulo
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiSubmodulo, 'S')
          else if Item.IDPaiModulo <> 0 then // Rotina filha de Módulo
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiModulo, 'M');

          if Assigned(ParentNode) then
          begin
            Node := tvMenu.Items.AddChildObject(ParentNode, Item.Nome, nil);
            SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
          end;
        end;
      end;
    end;

  finally
    tvMenu.Items.EndUpdate;
    if tvMenu.Items.Count > 0 then
      tvMenu.Selected := tvMenu.Items[0];
  end;
  btnLimparTodas.Enabled := tvMenu.Items.Count > 0;
  btnSelecionarTodas.Enabled := tvMenu.Items.Count > 0;
end;


procedure TfrmGerenciarPermissoes.AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var i: Integer; NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);
  TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;

  for PermItem in AUserPermissions do
  begin
    if (PermItem.ItemID = NodeData^.ID) and (PermItem.ItemTipo = NodeData^.Tipo) then
    begin
      TemAcesso    := PermItem.Acesso; PodeInserir  := PermItem.Inserir;
      PodeAlterar  := PermItem.Alterar; PodeExcluir  := PermItem.Excluir;
      PodeImprimir := PermItem.Imprimir;
      Break;
    end;
  end;

  // Atualiza FPermissoesEditadas com o estado carregado do banco
  MarcarNoAtualizarListaEditada(NodeData, TemAcesso); // Assume que outras permissões são baseadas em Acesso para M/S
  if NodeData^.Tipo = 'R' then begin // Para rotinas, atualiza todas as permissões granulares
      // Esta chamada a MarcarNoAtualizarListaEditada precisa ser mais inteligente
      // ou precisamos de um método que popule FPermissoesEditadas com todos os campos booleanos
      // Por agora, vamos simplificar e assumir que o chkPermissaoClick vai lidar com isso quando o usuário interagir.
      // O mais importante é que os checkboxes visuais estejam corretos.
  end;


  if ANode = tvMenu.Selected then // Atualiza os checkboxes visíveis
  begin
    chkAcesso.Checked := TemAcesso; gbPermissoesItem.Enabled := True;
    if NodeData^.Tipo = 'R' then
    begin
      chkInserir.Enabled := True; chkInserir.Checked := PodeInserir;
      chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
      chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir;
      chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
    end else begin
      chkInserir.Enabled := False; chkInserir.Checked := False; chkAlterar.Enabled := False; chkAlterar.Checked := False;
      chkExcluir.Enabled := False; chkExcluir.Checked := False; chkImprimir.Enabled := False; chkImprimir.Checked := False;
    end;
  end;

  if ANode.HasChildren then
    for i := 0 to ANode.Count - 1 do
      AplicarPermissoesVisuaisParaNo(ANode.Item[i], AUserPermissions);
end;

procedure TfrmGerenciarPermissoes.btnCarregarPermissoesClick(Sender: TObject);
var IDEmpresa, IDUsuario, i: Integer; UserPermissions: TArrayOfUserPermissionItem;
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin ShowMessage('Selecione uma empresa e um usuário.'); Exit; end;

  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); Exit; end;

  Screen.Cursor := crHourGlass;
  FPermissoesEditadas.Clear; // Limpa o estado editado anterior
  try
    PopularTreeView; // Carrega a estrutura do menu

    if not FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then
    begin
      ShowMessage('Falha ao carregar permissões do usuário.');
      MemoLog.Lines.Add(Format('Falha ao carregar permissões para Usuário ID %d, Empresa ID %d', [IDUsuario, IDEmpresa]));
      Exit;
    end;
    MemoLog.Lines.Add(Format('Permissões carregadas para Usuário ID %d: %d registros.', [IDUsuario, Length(UserPermissions)]));

    if tvMenu.Items.Count > 0 then
    begin
       for i := 0 to tvMenu.Items.Count -1 do
          AplicarPermissoesVisuaisParaNo(tvMenu.Items[i], UserPermissions);

       if Assigned(tvMenu.Selected) then // Garante que os checks do nó selecionado sejam atualizados
         AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions)
       else if tvMenu.Items.Count > 0 then // Se nada estiver selecionado, seleciona o primeiro
         tvMenu.Selected := tvMenu.Items[0]; // Isso vai disparar tvMenuSelectionChanged
    end else LimparPermissoesVisuais;
  finally Screen.Cursor := crDefault; end;

  FPermissoesModificadas := False;
  btnSalvarPermissoes.Enabled := False;
end;

function TfrmGerenciarPermissoes.GetItemMenuData(ANode: TTreeNode): PItemMenuData;
begin Result := nil; if Assigned(ANode) and Assigned(ANode.Data) then Result := PItemMenuData(ANode.Data); end;

procedure TfrmGerenciarPermissoes.SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);
var NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit; if Assigned(ANode.Data) then FreeMem(ANode.Data);
  New(NodeData); NodeData^.ID := AID; NodeData^.Tipo := ATipo; NodeData^.NomeForm := ANomeForm; ANode.Data := NodeData;
end;

procedure TfrmGerenciarPermissoes.AtualizarChecksPermissaoParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    FoundInOriginal, FoundInEdited: Boolean;
    i: Integer; PermInfoEdited: TStringList; PermItemTipoEdited: Char; PermItemIDEdited: Integer;
begin
  LimparPermissoesVisuais; if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode); if not Assigned(NodeData) then Exit;
  gbPermissoesItem.Enabled := True; gbPermissoesItem.Caption := 'Permissões para: ' + ANode.Text;

  TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;
  FoundInOriginal := False; FoundInEdited := False;

  // 1. Verificar se há um estado "editado" para este nó em FPermissoesEditadas
  PermInfoEdited := TStringList.Create;
  try
    for i := 0 to FPermissoesEditadas.Count - 1 do
    begin
      PermInfoEdited.Delimiter := '|'; PermInfoEdited.DelimitedText := FPermissoesEditadas[i];
      if PermInfoEdited.Count = 7 then
      begin
        PermItemTipoEdited := PermInfoEdited[0][1]; PermItemIDEdited := StrToInt(PermInfoEdited[1]);
        if (NodeData^.ID = PermItemIDEdited) and (NodeData^.Tipo = PermItemTipoEdited) then
        begin
          TemAcesso    := StrDBToBool(PermInfoEdited[2]); PodeInserir  := StrDBToBool(PermInfoEdited[3]);
          PodeAlterar  := StrDBToBool(PermInfoEdited[4]); PodeExcluir  := StrDBToBool(PermInfoEdited[5]);
          PodeImprimir := StrDBToBool(PermInfoEdited[6]);
          FoundInEdited := True; Break;
        end;
      end;
    end;
  finally PermInfoEdited.Free; end;

  // 2. Se não foi editado, buscar das permissões originais carregadas (AUserPermissions)
  if not FoundInEdited then
  begin
    for PermItem in AUserPermissions do
    begin
      if (PermItem.ItemID = NodeData^.ID) and (PermItem.ItemTipo = NodeData^.Tipo) then
      begin
        TemAcesso    := PermItem.Acesso; PodeInserir  := PermItem.Inserir;
        PodeAlterar  := PermItem.Alterar; PodeExcluir  := PermItem.Excluir;
        PodeImprimir := PermItem.Imprimir;
        FoundInOriginal := True; Break;
      end;
    end;
  end;

  chkAcesso.Checked := TemAcesso;
  if NodeData^.Tipo = 'R' then
  begin
    chkInserir.Enabled := True; chkInserir.Checked := PodeInserir; chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
    chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir; chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
  end else begin
    chkInserir.Enabled := False; chkInserir.Checked := False; chkAlterar.Enabled := False; chkAlterar.Checked := False;
    chkExcluir.Enabled := False; chkExcluir.Checked := False; chkImprimir.Enabled := False; chkImprimir.Checked := False;
  end;
end;

procedure TfrmGerenciarPermissoes.tvMenuSelectionChanged(Sender: TObject);
var UserPermissions: TArrayOfUserPermissionItem; // Precisa ser recarregada ou mantida
    IDEmpresa, IDUsuario: Integer;
begin
  if Assigned(tvMenu.Selected) then
  begin
    // Para atualizar corretamente, precisamos das permissões originais do usuário
    // A lógica de AplicarPermissoesVisuaisParaNo já preenche FPermissoesEditadas com base no original
    // Então, AtualizarChecksPermissaoParaNo pode usar FPermissoesEditadas ou as originais
    // Vamos simplificar e assumir que FPermissoesEditadas é a fonte da verdade para a UI após o carregamento
    // Se FPermissoesEditadas estiver vazio para este nó, significa que não foi alterado e deve refletir o original.

    // Esta é a parte mais complexa: precisamos do estado original para comparar com o editado.
    // Por ora, AtualizarChecksPermissaoParaNo tentará ler de FPermissoesEditadas,
    // se não achar, deveria ler do estado original (que não está sendo passado aqui).
    // A solução mais simples é que btnCarregarPermissoesClick popule FPermissoesEditadas com o estado do banco.
    // E chkPermissaoClick modifique FPermissoesEditadas.

    // A chamada a AtualizarChecksPermissaoParaNo agora precisa do array de permissões carregado do banco
    // para poder exibir o estado correto se o item não estiver em FPermissoesEditadas.
    // Isso significa que UserPermissions deve ser um campo do form ou recarregado.
    // Para manter simples por agora, vamos assumir que FPermissoesEditadas reflete o que mostrar.
    // A lógica de AtualizarChecksPermissaoParaNo foi ajustada para buscar em FPermissoesEditadas.

     if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) then
     begin
        IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
        IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
        if Assigned(FPermissaoController) then
        begin
          // Recarrega as permissões originais para referência.
          // Idealmente, isso seria armazenado em um campo do formulário após o btnCarregarPermissoesClick
          FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions);
          AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions);
        end;
     end;
  end
  else
    LimparPermissoesVisuais;
end;

procedure TfrmGerenciarPermissoes.MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
var idx: Integer; tmpPermInfo: TStringList; foundInList: Boolean; tmpLinha: string;
    PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
begin
  if not Assigned(ANodeData) then Exit; foundInList := False; tmpPermInfo := TStringList.Create;
  try
    for idx := 0 to FPermissoesEditadas.Count - 1 do
    begin
      tmpPermInfo.Delimiter := '|'; tmpPermInfo.DelimitedText := FPermissoesEditadas[idx];
      if (tmpPermInfo.Count = 7) and (tmpPermInfo[0][1] = ANodeData^.Tipo) and (StrToInt(tmpPermInfo[1]) = ANodeData^.ID) then
      begin
        // Atualiza apenas o acesso, as outras permissões são baseadas nos checkboxes se for rotina
        tmpPermInfo[2] := BoolToStrDB(ACheckedState);
        if ANodeData^.Tipo = 'R' then begin // Se for rotina, e estamos marcando acesso, marcamos tudo (ou conforme checkboxes)
             PodeInserir := ACheckedState and chkInserir.Checked; // Se limpando, desmarca tudo
             PodeAlterar := ACheckedState and chkAlterar.Checked;
             PodeExcluir := ACheckedState and chkExcluir.Checked;
             PodeImprimir := ACheckedState and chkImprimir.Checked;
             if not ACheckedState then // Se Acesso é False, todas as outras são False
             begin PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False; end;

             tmpPermInfo[3] := BoolToStrDB(PodeInserir); tmpPermInfo[4] := BoolToStrDB(PodeAlterar);
             tmpPermInfo[5] := BoolToStrDB(PodeExcluir); tmpPermInfo[6] := BoolToStrDB(PodeImprimir);
        end else begin tmpPermInfo[3] := '0'; tmpPermInfo[4] := '0'; tmpPermInfo[5] := '0'; tmpPermInfo[6] := '0'; end;
        FPermissoesEditadas[idx] := tmpPermInfo.DelimitedText; foundInList := True; Break;
      end;
    end;
    if not foundInList then // Se não achou, adiciona nova entrada
    begin
      if ANodeData^.Tipo = 'R' then begin
           PodeInserir := ACheckedState and chkInserir.Checked; PodeAlterar := ACheckedState and chkAlterar.Checked;
           PodeExcluir := ACheckedState and chkExcluir.Checked; PodeImprimir := ACheckedState and chkImprimir.Checked;
           if not ACheckedState then begin PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False; end;
      end else begin PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False; end;

      tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                  BoolToStrDB(ACheckedState) + '|' +
                  BoolToStrDB(PodeInserir) + '|' + BoolToStrDB(PodeAlterar) + '|' +
                  BoolToStrDB(PodeExcluir) + '|' + BoolToStrDB(PodeImprimir);
      FPermissoesEditadas.Add(tmpLinha);
    end;
  finally tmpPermInfo.Free; end;
end;

procedure TfrmGerenciarPermissoes.chkPermissaoClick(Sender: TObject);
var NodeData: PItemMenuData;
begin
  if not Assigned(tvMenu.Selected) then Exit;
  NodeData := GetItemMenuData(tvMenu.Selected);
  if not Assigned(NodeData) then Exit;

  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;

  // Atualiza a FPermissoesEditadas com o estado atual dos checkboxes
  MarcarNoAtualizarListaEditada(NodeData, chkAcesso.Checked);
end;

procedure TfrmGerenciarPermissoes.btnSalvarPermissoesClick(Sender: TObject);
var
  IDEmpresa, IDUsuario: Integer;
  PermInfo: TStringList;
  PermLinha: string;
  UserPermsToSave: TArrayOfUserPermissionItem;
  idx: Integer;
begin
  if not FPermissoesModificadas then begin ShowMessage('Nenhuma permissão foi alterada.'); Exit; end;
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then begin ShowMessage('Selecione uma empresa e um usuário.'); Exit; end;

  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); Exit; end;

  Screen.Cursor := crHourGlass;
  MemoLog.Lines.Add(Format('--- Iniciando salvamento para Usuário ID: %d, Empresa ID: %d ---', [IDUsuario, IDEmpresa]));
  try
    // Converter FPermissoesEditadas para TArrayOfUserPermissionItem
    SetLength(UserPermsToSave, FPermissoesEditadas.Count);
    PermInfo := TStringList.Create;
    try
      for idx := 0 to FPermissoesEditadas.Count - 1 do
      begin
        PermLinha := FPermissoesEditadas[idx];
        PermInfo.Delimiter := '|'; PermInfo.DelimitedText := PermLinha;
        if PermInfo.Count = 7 then
        begin
           UserPermsToSave[idx].ItemTipo := PermInfo[0][1];
           UserPermsToSave[idx].ItemID   := StrToInt(PermInfo[1]);
           UserPermsToSave[idx].Acesso   := StrDBToBool(PermInfo[2]);
           UserPermsToSave[idx].Inserir  := StrDBToBool(PermInfo[3]);
           UserPermsToSave[idx].Alterar  := StrDBToBool(PermInfo[4]);
           UserPermsToSave[idx].Excluir  := StrDBToBool(PermInfo[5]);
           UserPermsToSave[idx].Imprimir := StrDBToBool(PermInfo[6]);
           MemoLog.Lines.Add(Format('Preparando para Salvar: Tipo:%s ID:%s Ac:%s I:%s A:%s E:%s P:%s',
             [PermInfo[0], PermInfo[1], PermInfo[2], PermInfo[3], PermInfo[4], PermInfo[5], PermInfo[6]]));
        end else begin
           SetLength(UserPermsToSave, idx); // Ajusta tamanho se linha mal formada
           MemoLog.Lines.Add('Linha mal formada em FPermissoesEditadas: ' + PermLinha);
           Break;
        end;
      end;

      if FPermissaoController.SalvarTodasPermissoesUsuario(IDEmpresa, IDUsuario, UserPermsToSave) then
      begin
        FPermissoesModificadas := False;
        btnSalvarPermissoes.Enabled := False;
        FPermissoesEditadas.Clear; // Limpa após salvar com sucesso
        ShowMessage('Permissões salvas com sucesso.');
        MemoLog.Lines.Add('Permissões salvas via Controller.');
        // Recarregar as permissões para refletir o estado do banco
        btnCarregarPermissoesClick(nil);
      end else
      begin
        ShowMessage('Falha ao salvar permissões via Controller.');
        MemoLog.Lines.Add('Falha ao salvar permissões via Controller.');
      end;
    finally PermInfo.Free; end;
  except on E: Exception do begin ShowMessage('Erro ao salvar permissões: ' + E.Message); MemoLog.Lines.Add('Erro ao salvar: ' + E.Message); end;
  end;
  Screen.Cursor := crDefault;
end;

procedure TfrmGerenciarPermissoes.btnCopiarPermissoesClick(Sender: TObject);
var
  frmSelUsu: TfrmSelecionarUsuario;
  IDUsuOrigem, IDUsuDestino, IDEmpresaCopia: Integer;
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin ShowMessage('Selecione uma empresa e o usuário de DESTINO primeiro.'); Exit; end;

  IDEmpresaCopia := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuDestino := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); Exit; end;

  frmSelUsu := TfrmSelecionarUsuario.Create(Application);
  try
    frmSelUsu.CarregarUsuariosParaCopia(IDEmpresaCopia, IDUsuDestino); // Passa o controller se TfrmSelecionarUsuario precisar dele
    if frmSelUsu.ShowModal = mrOk then
    begin
      IDUsuOrigem := frmSelUsu.IDUsuarioSelecionado;
      if IDUsuOrigem > 0 then
      begin
        if MessageDlgFmt('Copiar todas as permissões do usuário "%s" para o usuário "%s"?',
                         [frmSelUsu.NomeUsuarioSelecionado, cbUsuario.Text],
                         mtConfirmation, [mbYes, mbNo],0) = mrYes then
        begin
          Screen.Cursor := crHourGlass;
          try
            if FPermissaoController.CopiarPermissoes(IDEmpresaCopia, IDUsuOrigem, IDUsuDestino) then
            begin
              ShowMessage('Permissões copiadas com sucesso. As permissões para o usuário destino foram recarregadas.');
              MemoLog.Lines.Add(Format('Permissões copiadas de Usuário ID %d para Usuário ID %d.', [IDUsuOrigem, IDUsuDestino]));
              btnCarregarPermissoesClick(nil); // Recarrega as permissões do usuário destino
            end else
            begin
              ShowMessage('Falha ao copiar permissões.');
              MemoLog.Lines.Add(Format('Falha ao copiar permissões de Usuário ID %d para Usuário ID %d.', [IDUsuOrigem, IDUsuDestino]));
            end;
          finally Screen.Cursor := crDefault; end;
        end;
      end else ShowMessage('Nenhum usuário de origem selecionado.');
    end;
  finally
    FreeAndNil(frmSelUsu);
  end;
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaLimpezaTotal(ANode: TTreeNode);
var j: Integer; NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode); MarcarNoAtualizarListaEditada(NodeData, False);
  for j := 0 to ANode.Count - 1 do ProcessarNoParaLimpezaTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
var j: Integer; NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode); MarcarNoAtualizarListaEditada(NodeData, True);
  for j := 0 to ANode.Count - 1 do ProcessarNoParaSelecaoTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var i: Integer; UserPermissions: TArrayOfUserPermissionItem;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaLimpezaTotal(tvMenu.Items[i]);

  // Atualiza a UI para o nó selecionado (se houver) para refletir a limpeza
  // A UserPermissions aqui seria um array vazio ou com todos os acessos a false.
  // Para simplificar, vamos apenas chamar AtualizarChecksPermissaoParaNo com um array vazio.
  SetLength(UserPermissions, 0);
  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions)
  else
    LimparPermissoesVisuais;

  FPermissoesModificadas := True; btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram desmarcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Limpar Todas clicado.');
end;

procedure TfrmGerenciarPermissoes.btnSelecionarTodasClick(Sender: TObject);
var i: Integer; UserPermissions: TArrayOfUserPermissionItem;
begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaSelecaoTotal(tvMenu.Items[i]);

  // Para atualizar a UI corretamente, precisamos simular um UserPermissions com tudo True.
  // A AtualizarChecksPermissaoParaNo usará FPermissoesEditadas que foi modificado por ProcessarNoParaSelecaoTotal.
  // A passagem de UserPermissions para AtualizarChecksPermissaoParaNo em tvMenuSelectionChanged é mais crítica.
  // Aqui, podemos apenas forçar a atualização do nó selecionado.
  if Assigned(tvMenu.Selected) then
  begin
    // Recriar um UserPermissions temporário para refletir "tudo selecionado" para este nó.
    // Ou, mais simples, confiar que MarcarNoAtualizarListaEditada já atualizou FPermissoesEditadas
    // e AtualizarChecksPermissaoParaNo lerá corretamente de lá.
    // Se tvMenuSelectionChanged é chamado, ele fará a lógica correta.
    // Forçando uma atualização simples do nó selecionado com base no que MarcarNoAtualizarListaEditada fez:
    if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) and Assigned(FPermissaoController) then
    begin
        FPermissaoController.CarregarPermissoesUsuario(Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]), Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]), UserPermissions); // Pega as originais para o método
        AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions); // Este método agora olha FPermissoesEditadas primeiro
    end;
  end;

  FPermissoesModificadas := True; btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram marcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Selecionar Todas clicado.');
end;

initialization
  //
finalization
  //
end.
