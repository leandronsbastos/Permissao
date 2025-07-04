unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList, StrUtils,
  uPermissaoController;

type
  TItemMenuData = record
    ID: Integer;
    Tipo: Char;
    NomeForm: string;
  end;
  PItemMenuData = ^TItemMenuData;

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
    dsEmpresas: TDataSource;
    dsUsuarios: TDataSource;
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
    FPermissaoController: TPermissaoController;
    FPermissoesModificadas: Boolean;
    FPermissoesEditadas: TStringList;

    // Estas listas de simulação não são mais usadas para carregar dados principais,
    // mas podem ser mantidas se houver alguma lógica de fallback ou teste futuro.
    // Por ora, suas chamadas de população serão removidas dos métodos de carga principais.
    FEmpresasData: TStringList;
    FUsuariosData: TStringList;
    FMenuEstruturaSimulada: TStringList;

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

uses uSelecionarUsuario;

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
  FPermissaoController := TPermissaoController.Create('SEU_SERVIDOR_SQL', 'SEU_BANCO_DE_DADOS', 'SEU_USUARIO_SQL', 'SUA_SENHA_SQL');
  // Ou para segurança integrada:
  // FPermissaoController := TPermissaoController.Create('SEU_SERVIDOR_SQL', 'SEU_BANCO_DE_DADOS', '', '', True);
  // Ou se já tem a string de conexão completa:
  // FPermissaoController := TPermissaoController.Create('SUA_CONNECTION_STRING_COMPLETA');

  if not FPermissaoController.TestConnection then
  begin
    ShowMessage('Falha ao conectar ao banco de dados! Verifique as configurações de conexão no FormCreate de uGerenciarPermissoes.');
    MemoLog.Lines.Add('FALHA na conexão com BD no FormCreate!');
  end else
  begin
    MemoLog.Lines.Add('Conexão com BD bem-sucedida no FormCreate!');
  end;

  FPermissoesModificadas := False;
  FPermissoesEditadas := TStringList.Create;

  FEmpresasData := TStringList.Create; // Ainda criado, mas não usado para popular se controller funcionar
  FUsuariosData := TStringList.Create; // Idem
  FMenuEstruturaSimulada := TStringList.Create; // Idem


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
  FreeAndNil(FEmpresasData);
  FreeAndNil(FUsuariosData);
  FreeAndNil(FMenuEstruturaSimulada);
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  if cbEmpresa.Items.Count > 0 then
  begin
    if cbEmpresa.ItemIndex = -1 then
       cbEmpresa.ItemIndex := 0; // Disparará OnChange se mudar de -1 para 0
    else if cbEmpresa.ItemIndex = 0 then // Se já era 0, OnChange não dispara, então chamamos manualmente
       cbEmpresaChange(cbEmpresa);
  end else
  begin
     btnCarregarPermissoes.Enabled := False;
     MemoLog.Lines.Add('Nenhuma empresa para exibir no FormShow.');
  end;
end;

procedure TfrmGerenciarPermissoes.CarregarEmpresas;
begin
  MemoLog.Lines.Add('Iniciando TfrmGerenciarPermissoes.CarregarEmpresas...');
  cbEmpresa.Items.Clear;
  if Assigned(FPermissaoController) then
  begin
    if not FPermissaoController.CarregarEmpresas(cbEmpresa.Items) then
    begin
      ShowMessage('Falha ao carregar empresas do banco de dados.');
      MemoLog.Lines.Add('FPermissaoController.CarregarEmpresas retornou False.');
    end
    else
    begin
      MemoLog.Lines.Add(Format('Empresas carregadas pelo controller: %d itens no ComboBox.', [cbEmpresa.Items.Count]));
    end;
  end
  else
  begin
     ShowMessage('Controller de permissão não inicializado em CarregarEmpresas.');
     MemoLog.Lines.Add('FPermissaoController não atribuído em CarregarEmpresas.');
     Exit;
  end;

  if cbEmpresa.Items.Count > 0 then
  begin
    // Se ItemIndex já for 0 (ex: se houver apenas uma empresa e o evento OnChange não disparou),
    // precisamos garantir que CarregarUsuarios seja chamado.
    // Se ItemIndex é mudado de -1 para 0, OnChange será disparado.
    if cbEmpresa.ItemIndex <> 0 then
      cbEmpresa.ItemIndex := 0
    else if cbEmpresa.ItemIndex = 0 then // Já é 0, OnChange não vai disparar
      cbEmpresaChange(cbEmpresa); // Força a chamada
  end
  else
  begin
    cbUsuario.Items.Clear;
    btnCarregarPermissoes.Enabled := False;
    MemoLog.Lines.Add('Nenhuma empresa carregada, ComboBox de usuário limpo.');
  end;
end;

procedure TfrmGerenciarPermissoes.CarregarUsuarios(AIDEmpresa: Integer);
begin
  MemoLog.Lines.Add(Format('Iniciando TfrmGerenciarPermissoes.CarregarUsuarios para Empresa ID: %d...', [AIDEmpresa]));
  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais; // Limpa os checkboxes de permissão

  if Assigned(FPermissaoController) then
  begin
    if not FPermissaoController.CarregarUsuariosPorEmpresa(AIDEmpresa, cbUsuario.Items) then
    begin
      ShowMessage(Format('Falha ao carregar usuários para a empresa ID: %d.', [AIDEmpresa]));
      MemoLog.Lines.Add(Format('FPermissaoController.CarregarUsuariosPorEmpresa retornou False para Empresa ID: %d.', [AIDEmpresa]));
    end
    else
    begin
      MemoLog.Lines.Add(Format('Usuários carregados para Empresa ID %d: %d itens no ComboBox.', [AIDEmpresa, cbUsuario.Items.Count]));
    end;
  end
  else
  begin
     ShowMessage('Controller de permissão não inicializado em CarregarUsuarios.');
     MemoLog.Lines.Add('FPermissaoController não atribuído em CarregarUsuarios.');
     Exit;
  end;

  if cbUsuario.Items.Count > 0 then
  begin
    // Similar a CarregarEmpresas, precisamos garantir que btnCarregarPermissoesClick seja chamado.
    if cbUsuario.ItemIndex <> 0 then
       cbUsuario.ItemIndex := 0 // OnChange do cbUsuario (se atribuído) ou btnCarregarPermissoesClick manualmente
    else if cbUsuario.ItemIndex = 0 then
       btnCarregarPermissoesClick(nil); // Chama diretamente se já era 0

    btnCarregarPermissoes.Enabled := True;
  end
  else
  begin
    btnCarregarPermissoes.Enabled := False;
    MemoLog.Lines.Add(Format('Nenhum usuário carregado para Empresa ID: %d.', [AIDEmpresa]));
  end;
  btnCopiarPermissoes.Enabled := (cbUsuario.Items.Count > 0);
end;

procedure TfrmGerenciarPermissoes.cbEmpresaChange(Sender: TObject);
var
  IDEmpresa: Integer;
begin
  MemoLog.Lines.Add('TfrmGerenciarPermissoes.cbEmpresaChange disparado.');
  if cbEmpresa.ItemIndex <> -1 then
  begin
    IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
    MemoLog.Lines.Add(Format('Empresa selecionada ID: %d, Nome: %s', [IDEmpresa, cbEmpresa.Text]));
    CarregarUsuarios(IDEmpresa);
  end
  else
  begin
    MemoLog.Lines.Add('Nenhuma empresa selecionada em cbEmpresaChange.');
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
    for k := 0 to Tree.Items.Count - 1 do
    begin
      NodeData := PItemMenuData(Tree.Items[k].Data);
      if Assigned(NodeData) and (NodeData^.ID = SearchID) and (NodeData^.Tipo = SearchTipo) then
      begin Result := Tree.Items[k]; Exit; end;
      Result := FindNodeByDataRec(Tree.Items[k], SearchID, SearchTipo);
      if Assigned(Result) then Exit;
    end;
  end;

begin
  MemoLog.Lines.Add('Iniciando PopularTreeView...');
  if not Assigned(FPermissaoController) then
  begin
    ShowMessage('Controller não inicializado em PopularTreeView.');
    MemoLog.Lines.Add('Controller não inicializado em PopularTreeView.');
    Exit;
  end;

  if not FPermissaoController.CarregarEstruturaMenu(MenuEstruturaArray) then
  begin
    ShowMessage('Falha ao carregar estrutura do menu.');
    MemoLog.Lines.Add('FPermissaoController.CarregarEstruturaMenu retornou False.');
    Exit;
  end;
  MemoLog.Lines.Add(Format('Estrutura de menu carregada pelo controller: %d itens.', [Length(MenuEstruturaArray)]));

  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear;
    for Item in MenuEstruturaArray do
    begin
      if Item.Tipo = 'M' then
      begin
        Node := tvMenu.Items.AddObject(nil, Item.Nome, nil);
        SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
      end;
    end;

    for i := 0 to Length(MenuEstruturaArray) -1 do // Múltiplas passagens para garantir hierarquia
    begin
      for Item in MenuEstruturaArray do
      begin
        if Item.Tipo = 'S' then
        begin
          if Assigned(FindNodeInData(tvMenu, Item.ID, 'S')) then Continue;
          ParentNode := nil;
          if Item.IDPaiSubmodulo <> 0 then
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiSubmodulo, 'S')
          else if Item.IDPaiModulo <> 0 then
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiModulo, 'M');
          if Assigned(ParentNode) then
          begin
            Node := tvMenu.Items.AddChildObject(ParentNode, Item.Nome, nil);
            SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
          end;
        end
        else if Item.Tipo = 'R' then
        begin
          if Assigned(FindNodeInData(tvMenu, Item.ID, 'R')) then Continue;
          ParentNode := nil;
          if Item.IDPaiSubmodulo <> 0 then
            ParentNode := FindNodeInData(tvMenu, Item.IDPaiSubmodulo, 'S')
          else if Item.IDPaiModulo <> 0 then
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
    MemoLog.Lines.Add(Format('TreeView populado. %d nós raiz.', [tvMenu.Items.Count]));
  end;
  btnLimparTodas.Enabled := (tvMenu.Items.Count > 0);
  btnSelecionarTodas.Enabled := (tvMenu.Items.Count > 0);
end;


procedure TfrmGerenciarPermissoes.AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var i: Integer; NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    PermString: string; FoundInList: Boolean;
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

  PermString := NodeData^.Tipo + '|' + IntToStr(NodeData^.ID) + '|' +
                BoolToStrDB(TemAcesso) + '|' + BoolToStrDB(PodeInserir) + '|' +
                BoolToStrDB(PodeAlterar) + '|' + BoolToStrDB(PodeExcluir) + '|' +
                BoolToStrDB(PodeImprimir);

  FoundInList := False;
  for i := 0 to FPermissoesEditadas.Count - 1 do
  begin
    if Pos(NodeData^.Tipo + '|' + IntToStr(NodeData^.ID) + '|', FPermissoesEditadas[i]) = 1 then
    begin
      FPermissoesEditadas[i] := PermString; // Atualiza se já existe
      FoundInList := True;
      Break;
    end;
  end;
  if not FoundInList then
    FPermissoesEditadas.Add(PermString); // Adiciona se não existe

  if ANode = tvMenu.Selected then
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
  MemoLog.Lines.Add('btnCarregarPermissoesClick iniciado.');
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin
    ShowMessage('Selecione uma empresa e um usuário.');
    MemoLog.Lines.Add('Empresa ou usuário não selecionado em btnCarregarPermissoesClick.');
    Exit;
  end;

  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
  MemoLog.Lines.Add(Format('Carregando para Empresa ID: %d, Usuário ID: %d', [IDEmpresa, IDUsuario]));

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); MemoLog.Lines.Add('Controller não inicializado em btnCarregarPermissoesClick.'); Exit; end;

  Screen.Cursor := crHourGlass;
  FPermissoesEditadas.Clear;
  try
    PopularTreeView;

    if not FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then
    begin
      ShowMessage('Falha ao carregar permissões do usuário.');
      MemoLog.Lines.Add(Format('FPermissaoController.CarregarPermissoesUsuario retornou False para Usuário ID %d.', [IDUsuario]));
      Screen.Cursor := crDefault;
      Exit;
    end;
    MemoLog.Lines.Add(Format('Permissões carregadas do controller para Usuário ID %d: %d registros.', [IDUsuario, Length(UserPermissions)]));

    if tvMenu.Items.Count > 0 then
    begin
       for i := 0 to tvMenu.Items.Count -1 do
          AplicarPermissoesVisuaisParaNo(tvMenu.Items[i], UserPermissions);

       if Assigned(tvMenu.Selected) then
         AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions)
       else if tvMenu.Items.Count > 0 then
         tvMenu.Selected := tvMenu.Items[0];
    end else LimparPermissoesVisuais;
  finally Screen.Cursor := crDefault; end;

  FPermissoesModificadas := False;
  btnSalvarPermissoes.Enabled := False;
  MemoLog.Lines.Add('btnCarregarPermissoesClick finalizado.');
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
    FoundInEdited: Boolean;
    i: Integer; PermInfoEdited: TStringList; PermItemTipoEdited: Char; PermItemIDEdited: Integer;
begin
  LimparPermissoesVisuais; if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode); if not Assigned(NodeData) then Exit;
  gbPermissoesItem.Enabled := True; gbPermissoesItem.Caption := 'Permissões para: ' + ANode.Text;

  TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;
  FoundInEdited := False;

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

  if not FoundInEdited then
  begin
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
var UserPermissions: TArrayOfUserPermissionItem;
    IDEmpresa, IDUsuario: Integer;
begin
  MemoLog.Lines.Add('tvMenuSelectionChanged disparado.');
  if Assigned(tvMenu.Selected) then
  begin
     MemoLog.Lines.Add('Nó selecionado: ' + tvMenu.Selected.Text);
     if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) then
     begin
        IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
        IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
        if Assigned(FPermissaoController) then
        begin
          if FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then
            AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions)
          else
            MemoLog.Lines.Add('Falha ao recarregar permissões em tvMenuSelectionChanged.');
        end else MemoLog.Lines.Add('FPermissaoController não atribuído em tvMenuSelectionChanged.');
     end else MemoLog.Lines.Add('Empresa ou Usuário não selecionado em tvMenuSelectionChanged.');
  end
  else
  begin
    MemoLog.Lines.Add('Nenhum nó selecionado em tvMenuSelectionChanged.');
    LimparPermissoesVisuais;
  end;
end;

procedure TfrmGerenciarPermissoes.MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
var idx: Integer; tmpPermInfo: TStringList; foundInList: Boolean; tmpLinha: string;
    PodeInserirCurrent, PodeAlterarCurrent, PodeExcluirCurrent, PodeImprimirCurrent: Boolean;
begin
  if not Assigned(ANodeData) then Exit; foundInList := False; tmpPermInfo := TStringList.Create;
  try
    // Preserva o estado atual dos checkboxes granulares se for uma rotina
    if ANodeData^.Tipo = 'R' then
    begin
      PodeInserirCurrent := chkInserir.Checked;
      PodeAlterarCurrent := chkAlterar.Checked;
      PodeExcluirCurrent := chkExcluir.Checked;
      PodeImprimirCurrent := chkImprimir.Checked;
    end else
    begin
      PodeInserirCurrent := False; PodeAlterarCurrent := False; PodeExcluirCurrent := False; PodeImprimirCurrent := False;
    end;

    for idx := 0 to FPermissoesEditadas.Count - 1 do
    begin
      tmpPermInfo.Delimiter := '|'; tmpPermInfo.DelimitedText := FPermissoesEditadas[idx];
      if (tmpPermInfo.Count = 7) and (tmpPermInfo[0][1] = ANodeData^.Tipo) and (StrToInt(tmpPermInfo[1]) = ANodeData^.ID) then
      begin
        tmpPermInfo[2] := BoolToStrDB(ACheckedState);
        if ANodeData^.Tipo = 'R' then
        begin
             tmpPermInfo[3] := BoolToStrDB(if ACheckedState then PodeInserirCurrent else False);
             tmpPermInfo[4] := BoolToStrDB(if ACheckedState then PodeAlterarCurrent else False);
             tmpPermInfo[5] := BoolToStrDB(if ACheckedState then PodeExcluirCurrent else False);
             tmpPermInfo[6] := BoolToStrDB(if ACheckedState then PodeImprimirCurrent else False);
        end else begin tmpPermInfo[3] := '0'; tmpPermInfo[4] := '0'; tmpPermInfo[5] := '0'; tmpPermInfo[6] := '0'; end;
        FPermissoesEditadas[idx] := tmpPermInfo.DelimitedText; foundInList := True; Break;
      end;
    end;
    if not foundInList then
    begin
      tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                  BoolToStrDB(ACheckedState) + '|' +
                  BoolToStrDB(if ACheckedState and (ANodeData^.Tipo = 'R') then PodeInserirCurrent else False) + '|' +
                  BoolToStrDB(if ACheckedState and (ANodeData^.Tipo = 'R') then PodeAlterarCurrent else False) + '|' +
                  BoolToStrDB(if ACheckedState and (ANodeData^.Tipo = 'R') then PodeExcluirCurrent else False) + '|' +
                  BoolToStrDB(if ACheckedState and (ANodeData^.Tipo = 'R') then PodeImprimirCurrent else False);
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

  // A MarcarNoAtualizarListaEditada agora usa o estado dos checkboxes para permissões granulares
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
           SetLength(UserPermsToSave, idx);
           MemoLog.Lines.Add('Linha mal formada em FPermissoesEditadas: ' + PermLinha);
           Break;
        end;
      end;

      if FPermissaoController.SalvarTodasPermissoesUsuario(IDEmpresa, IDUsuario, UserPermsToSave) then
      begin
        FPermissoesModificadas := False;
        btnSalvarPermissoes.Enabled := False;
        FPermissoesEditadas.Clear;
        ShowMessage('Permissões salvas com sucesso.');
        MemoLog.Lines.Add('Permissões salvas via Controller.');
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
  FormattedMsg: string;
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin ShowMessage('Selecione uma empresa e o usuário de DESTINO primeiro.'); Exit; end;

  IDEmpresaCopia := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuDestino := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); Exit; end;

  frmSelUsu := TfrmSelecionarUsuario.Create(Application);
  try
    frmSelUsu.CarregarUsuariosParaCopia(IDEmpresaCopia, IDUsuDestino);
    if frmSelUsu.ShowModal = mrOk then
    begin
      IDUsuOrigem := frmSelUsu.IDUsuarioSelecionado;
      if IDUsuOrigem > 0 then
      begin
        FormattedMsg := Format('Copiar todas as permissões do usuário "%s" para o usuário "%s"?',
                               [frmSelUsu.NomeUsuarioSelecionado, cbUsuario.Text]);
        if MessageDlg(FormattedMsg, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        begin
          Screen.Cursor := crHourGlass;
          try
            if FPermissaoController.CopiarPermissoes(IDEmpresaCopia, IDUsuOrigem, IDUsuDestino) then
            begin
              ShowMessage('Permissões copiadas com sucesso. As permissões para o usuário destino foram recarregadas.');
              MemoLog.Lines.Add(Format('Permissões copiadas de Usuário ID %d para Usuário ID %d.', [IDUsuOrigem, IDUsuDestino]));
              btnCarregarPermissoesClick(nil);
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
  if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode);
  // Ao limpar, todas as permissões do nó são setadas para False (0)
  MarcarNoAtualizarListaEditada(NodeData, False);
  // Limpa visualmente os checkboxes (se este nó estiver selecionado)
  // A atualização visual principal será feita em btnLimparTodasClick
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := False; chkInserir.Checked := False; chkAlterar.Checked := False;
      chkExcluir.Checked := False; chkImprimir.Checked := False;
      if NodeData^.Tipo <> 'R' then
      begin
          chkInserir.Enabled  := False; chkAlterar.Enabled  := False;
          chkExcluir.Enabled  := False; chkImprimir.Enabled := False;
      end;
  end;

  for j := 0 to ANode.Count - 1 do ProcessarNoParaLimpezaTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
var j: Integer; NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode);
  // Ao selecionar todos, Acesso é True. Para Rotinas, todas as outras também são True.
  MarcarNoAtualizarListaEditada(NodeData, True);
  // Atualiza visualmente os checkboxes (se este nó estiver selecionado)
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := True;
      if NodeData^.Tipo = 'R' then
      begin
          chkInserir.Enabled  := True; chkInserir.Checked  := True;
          chkAlterar.Enabled  := True; chkAlterar.Checked  := True;
          chkExcluir.Enabled  := True; chkExcluir.Checked  := True;
          chkImprimir.Enabled := True; chkImprimir.Checked := True;
      end;
  end;
  for j := 0 to ANode.Count - 1 do ProcessarNoParaSelecaoTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var i: Integer; UserPermissions: TArrayOfUserPermissionItem;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaLimpezaTotal(tvMenu.Items[i]);

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
    IDEmpresa, IDUsuario: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaSelecaoTotal(tvMenu.Items[i]);

  if Assigned(tvMenu.Selected) then
  begin
    if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) and Assigned(FPermissaoController) then
    begin
        IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
        IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
        // Recarrega as permissões originais para que AtualizarChecksPermissaoParaNo
        // possa usar FPermissoesEditadas (que foi modificado por ProcessarNoParaSelecaoTotal)
        // e as originais se o item não estiver em FPermissoesEditadas (embora agora deva estar).
        if FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then
          AtualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions);
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
