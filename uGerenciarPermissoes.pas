unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList, StrUtils,
  uPermissaoController, Generics.Collections; // Adicionado Generics.Collections

type
  TItemMenuData = record
    ID: Integer;
    Tipo: Char;
    NomeForm: string;
  end;
  PItemMenuData = ^TItemMenuData;

  // Estrutura para armazenar o estado de uma permissão específica na UI (modificada ou não)
  TUIPermissionState = record
    NomePermissao: string; // 'ACESSO', 'P_INSERIR', etc.
    Valor: Boolean;        // True se marcada, False se desmarcada
    Modificada: Boolean;   // True se o usuário alterou o estado desta permissão
  end;
  TArrayOfUIPermissionState = array of TUIPermissionState;

  // Dicionário para mapear um ItemID_ItemTipo para um array de estados de permissão da UI
  // Chave: String (ex: 'R_101' para Rotina ID 101)
  // Valor: TArrayOfUIPermissionState
  TItemUIPermissions = TDictionary<string, TArrayOfUIPermissionState>;


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
    FPermissoesModificadasGeral: Boolean; // Indica se QUALQUER permissão foi modificada

    // FEstadoAtualPermissoesUI: TStringList; // Antigo, será substituído
    // FPermissoesOriginais: TArrayOfUserPermissionItem; // Antigo, será substituído

    // Novas estruturas para armazenar permissões
    FPermissoesOriginaisCarregadas: TArrayOfSingleUserPermission; // Permissões como vieram do banco
    FUIPermissionsState: TItemUIPermissions; // Estado atual das permissões na UI, incluindo modificações

    procedure CarregarEmpresas;
    procedure CarregarUsuarios(AIDEmpresa: Integer);
    procedure LimparPermissoesVisuais;
    procedure PopularTreeView;
    // procedure AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem); // Assinatura Antiga
    procedure AplicarPermissoesCarregadasParaTodosNos(const AUserPermissions: TArrayOfSingleUserPermission);
    procedure AtualizarChecksPermissaoParaNo(ANode: TTreeNode);
    function GetItemMenuData(ANode: TTreeNode): PItemMenuData;
    procedure SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);
    procedure InicializarEstadoUIParaNodeRecursivo(ANode: TTreeNode; const AOriginalPermissions: TArrayOfSingleUserPermission); // Auxiliar


    // Novos métodos para gerenciar o estado da UI com TDictionary
    procedure InicializarEstadoUIParaNode(ANode: TTreeNode; const AOriginalPermissions: TArrayOfSingleUserPermission);
    procedure SetUIPermissionState(AItemTipo: Char; AItemID: Integer; ANomePermissao: string; AValor: Boolean; AModificada: Boolean);
    function GetUIPermissionState(AItemTipo: Char; AItemID: Integer; ANomePermissao: string; out AValor: Boolean; out AModificada: Boolean): Boolean; // Adicionado AModificada
    function GetNomePermissaoFromCheckBox(ACheckBox: TCheckBox): string;
    procedure LimparTodosOsEstadosUIPermissions;

    procedure ProcessarNoParaSelecaoTotal(ANode: TTreeNode; Selecionar: Boolean);
    // procedure ProcessarNoParaLimpezaTotal(ANode: TTreeNode); // Será unificado com ProcessarNoParaSelecaoTotal

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

  if not FPermissaoController.TestConnection then
  begin
    ShowMessage('Falha ao conectar ao banco de dados! Verifique as configurações de conexão no FormCreate de uGerenciarPermissoes.');
    MemoLog.Lines.Add('FALHA na conexão com BD no FormCreate!');
  end else
  begin
    MemoLog.Lines.Add('Conexão com BD bem-sucedida no FormCreate!');
  end;

  FPermissoesModificadasGeral := False;
  // FEstadoAtualPermissoesUI := TStringList.Create; // Antigo
  // FEstadoAtualPermissoesUI.Sorted := True;
  // FEstadoAtualPermissoesUI.Duplicates := dupIgnore;
  FUIPermissionsState := TItemUIPermissions.Create;


  SetLength(FPermissoesOriginaisCarregadas, 0);

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
  // FreeAndNil(FEstadoAtualPermissoesUI); // Antigo
  FreeAndNil(FUIPermissionsState); // Novo
  SetLength(FPermissoesOriginaisCarregadas, 0); // Novo
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  if cbEmpresa.Items.Count > 0 then
  begin
    if cbEmpresa.ItemIndex = -1 then
       cbEmpresa.ItemIndex := 0
    else if cbEmpresa.ItemIndex = 0 then
       cbEmpresaChange(cbEmpresa);
  end;
end;

procedure TfrmGerenciarPermissoes.LimparPermissoesVisuais;
begin
  chkAcesso.Checked := False;
  chkInserir.Checked := False;
  chkAlterar.Checked := False;
  chkExcluir.Checked := False;
  chkImprimir.Checked := False;

  chkInserir.Enabled := False;
  chkAlterar.Enabled := False;
  chkExcluir.Enabled := False;
  chkImprimir.Enabled := False;

  gbPermissoesItem.Enabled := False;
  gbPermissoesItem.Caption := 'Permissões para o item selecionado';
end;

procedure TfrmGerenciarPermissoes.CarregarEmpresas;
var
  TempEmpresasList: TStringList;
begin
  MemoLog.Lines.Add('Iniciando TfrmGerenciarPermissoes.CarregarEmpresas...');
  cbEmpresa.Items.Clear;
  TempEmpresasList := TStringList.Create;
  try
    if Assigned(FPermissaoController) then
    begin
      if not FPermissaoController.CarregarEmpresas(TempEmpresasList) then
      begin
        ShowMessage('Falha ao carregar empresas do banco de dados.');
        MemoLog.Lines.Add('FPermissaoController.CarregarEmpresas retornou False.');
      end
      else
      begin
        cbEmpresa.Items.Assign(TempEmpresasList);
        MemoLog.Lines.Add(Format('Empresas carregadas pelo controller: %d itens no ComboBox.', [cbEmpresa.Items.Count]));
      end;
    end
    else
    begin
       ShowMessage('Controller de permissão não inicializado em CarregarEmpresas.');
       MemoLog.Lines.Add('FPermissaoController não atribuído em CarregarEmpresas.');
       Exit;
    end;
  finally
    TempEmpresasList.Free;
  end;

  if cbEmpresa.Items.Count > 0 then
  begin
    if cbEmpresa.ItemIndex <> 0 then
      cbEmpresa.ItemIndex := 0
    else
      cbEmpresaChange(cbEmpresa);
  end
  else
  begin
    cbUsuario.Items.Clear;
    btnCarregarPermissoes.Enabled := False;
    MemoLog.Lines.Add('Nenhuma empresa carregada, ComboBox de usuário limpo.');
  end;
end;

procedure TfrmGerenciarPermissoes.CarregarUsuarios(AIDEmpresa: Integer);
var
  TempUsuariosList: TStringList;
begin
  MemoLog.Lines.Add(Format('Iniciando TfrmGerenciarPermissoes.CarregarUsuarios para Empresa ID: %d...', [AIDEmpresa]));
  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais;

  TempUsuariosList := TStringList.Create;
  try
    if Assigned(FPermissaoController) then
    begin
      if not FPermissaoController.CarregarUsuariosPorEmpresa(AIDEmpresa, TempUsuariosList) then
      begin
        ShowMessage(Format('Falha ao carregar usuários para a empresa ID: %d.', [AIDEmpresa]));
        MemoLog.Lines.Add(Format('FPermissaoController.CarregarUsuariosPorEmpresa retornou False para Empresa ID: %d.', [AIDEmpresa]));
      end
      else
      begin
        cbUsuario.Items.Assign(TempUsuariosList);
        MemoLog.Lines.Add(Format('Usuários carregados para Empresa ID %d: %d itens no ComboBox.', [AIDEmpresa, cbUsuario.Items.Count]));
      end;
    end
    else
    begin
       ShowMessage('Controller de permissão não inicializado em CarregarUsuarios.');
       MemoLog.Lines.Add('FPermissaoController não atribuído em CarregarUsuarios.');
       Exit;
    end;
  finally
    TempUsuariosList.Free;
  end;

  if cbUsuario.Items.Count > 0 then
  begin
    if cbUsuario.ItemIndex <> 0 then
      cbUsuario.ItemIndex := 0
    else
      btnCarregarPermissoesClick(nil);

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
  FPermissoesModificadasGeral := False; // Modificado
  // FEstadoAtualPermissoesUI.Clear; // Antigo
  LimparTodosOsEstadosUIPermissions; // Novo
  SetLength(FPermissoesOriginaisCarregadas, 0); // Modificado
end;

procedure TfrmGerenciarPermissoes.LimparTodosOsEstadosUIPermissions;
var
  Key: string;
  StatesArray: TArrayOfUIPermissionState;
begin
  if Assigned(FUIPermissionsState) then
  begin
    // Para liberar a memória dos arrays internos antes de limpar o dicionário
    for Key in FUIPermissionsState.Keys do
    begin
      StatesArray := FUIPermissionsState.Items[Key];
      SetLength(StatesArray, 0); // Libera o array
    end;
    FUIPermissionsState.Clear;
  end;
end;

procedure TfrmGerenciarPermissoes.GetNomePermissaoFromCheckBox(ACheckBox: TCheckBox): string;
begin
  Result := '';
  if ACheckBox = chkAcesso then Result := 'ACESSO'
  else if ACheckBox = chkInserir then Result := 'P_INSERIR'
  else if ACheckBox = chkAlterar then Result := 'P_ALTERAR'
  else if ACheckBox = chkExcluir then Result := 'P_EXCLUIR'
  else if ACheckBox = chkImprimir then Result := 'P_IMPRIMIR';
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  MenuEstruturaArray: TArrayOfMenuItemStructure;
  Node, PaiNode: TTreeNode;
  ItemStruct: TMenuItemStructure;
  MapaNos: TStringList;
  ChaveItem, ChavePai: string;
  I, J: Integer;
  ItensNaoProcessados: TList;
  ItemPtr: PMenuItemStructure;
  FezProgressoNestaPassagem: Boolean;
  Tentativas: Integer;
begin
  MemoLog.Lines.Add('Iniciando PopularTreeView (Versão Otimizada com Mapa)...');
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
  MemoLog.Lines.Add(Format('Estrutura de menu carregada: %d itens.', [Length(MenuEstruturaArray)]));

  tvMenu.Items.BeginUpdate;
  MapaNos := TStringList.Create;
  MapaNos.Sorted := False;
  ItensNaoProcessados := TList.Create;
  try
    tvMenu.Items.Clear;

    for I := Low(MenuEstruturaArray) to High(MenuEstruturaArray) do
    begin
      ItemStruct := MenuEstruturaArray[I];
      ChaveItem := ItemStruct.Tipo + '_' + IntToStr(ItemStruct.ID);
      if ItemStruct.Tipo = 'M' then
      begin
        Node := tvMenu.Items.AddObject(nil, ItemStruct.Nome, nil);
        SetItemMenuData(Node, ItemStruct.ID, ItemStruct.Tipo, ItemStruct.NomeForm);
        MapaNos.AddObject(ChaveItem, Node);
      end
      else
      begin
        New(ItemPtr);
        ItemPtr^ := ItemStruct;
        ItensNaoProcessados.Add(ItemPtr);
      end;
    end;

    Tentativas := 0;
    while (ItensNaoProcessados.Count > 0) and (Tentativas < Length(MenuEstruturaArray) + 5) do
    begin
      FezProgressoNestaPassagem := False;
      J := ItensNaoProcessados.Count - 1;
      while J >= 0 do
      begin
        ItemPtr := PMenuItemStructure(ItensNaoProcessados[J]);
        ItemStruct := ItemPtr^;
        ChaveItem := ItemStruct.Tipo + '_' + IntToStr(ItemStruct.ID);

        PaiNode := nil;
        if ItemStruct.IDPaiSubmodulo <> 0 then
          ChavePai := 'S_' + IntToStr(ItemStruct.IDPaiSubmodulo)
        else if ItemStruct.IDPaiModulo <> 0 then
          ChavePai := 'M_' + IntToStr(ItemStruct.IDPaiModulo)
        else
          ChavePai := '';

        if ChavePai <> '' then
        begin
          I := MapaNos.IndexOf(ChavePai);
          if I <> -1 then
            PaiNode := TTreeNode(MapaNos.Objects[I]);
        end;

        if Assigned(PaiNode) then
        begin
          Node := tvMenu.Items.AddChildObject(PaiNode, ItemStruct.Nome, nil);
          SetItemMenuData(Node, ItemStruct.ID, ItemStruct.Tipo, ItemStruct.NomeForm);
          MapaNos.AddObject(ChaveItem, Node);

          Dispose(ItemPtr);
          ItensNaoProcessados.Delete(J);
          FezProgressoNestaPassagem := True;
        end;
        Dec(J);
      end;
      Inc(Tentativas);
      if not FezProgressoNestaPassagem and (ItensNaoProcessados.Count > 0) then
      begin
        MemoLog.Lines.Add(Format('AVISO: %d itens do menu não puderam ser hierarquizados (pais não encontrados ou dependência circular).', [ItensNaoProcessados.Count]));
        for I := 0 to ItensNaoProcessados.Count - 1 do
        begin
            ItemPtr := PMenuItemStructure(ItensNaoProcessados[I]);
            MemoLog.Lines.Add(Format('  Órfão: %s (Tipo: %s, ID: %d, PaiM: %d, PaiS: %d)', [ItemPtr^.Nome, ItemPtr^.Tipo, ItemPtr^.ID, ItemPtr^.IDPaiModulo, ItemPtr^.IDPaiSubmodulo]));
        end;
        Break;
      end;
    end;

    for I := 0 to ItensNaoProcessados.Count - 1 do
      Dispose(PMenuItemStructure(ItensNaoProcessados[I]));
    ItensNaoProcessados.Clear;

  finally
    tvMenu.Items.EndUpdate;
    FreeAndNil(MapaNos);
    FreeAndNil(ItensNaoProcessados);
    if tvMenu.Items.Count > 0 then
      tvMenu.Selected := tvMenu.Items[0];
    MemoLog.Lines.Add(Format('TreeView populado. %d nós raiz.', [tvMenu.Items.Count]));
  end;

  btnLimparTodas.Enabled := (tvMenu.Items.Count > 0);
  btnSelecionarTodas.Enabled := (tvMenu.Items.Count > 0);
end;

// Procedure AplicarPermissoesVisuaisParaNo - REMOVIDA E SUBSTITUÍDA
// A lógica agora é:
// 1. CarregarPermissoesUsuario -> FPermissoesOriginaisCarregadas
// 2. PopularTreeView
// 3. InicializarEstadoUIParaNode para cada nó (usa FPermissoesOriginaisCarregadas)
// 4. AtualizarChecksPermissaoParaNo (usa FUIPermissionsState)

procedure TfrmGerenciarPermissoes.AplicarPermissoesCarregadasParaTodosNos(const AUserPermissions: TArrayOfSingleUserPermission);
var
  i: Integer;
begin
  // Limpa o estado anterior da UI antes de aplicar as novas permissões carregadas
  LimparTodosOsEstadosUIPermissions;

  // Itera sobre todos os nós do TreeView e inicializa seu estado de UI
  // com base nas permissões carregadas do banco (AUserPermissions)
  if Assigned(tvMenu.Items) then
  begin
    for i := 0 to tvMenu.Items.Count - 1 do
      InicializarEstadoUIParaNodeRecursivo(tvMenu.Items[i], AUserPermissions);
  end;
end;

// Função auxiliar recursiva para InicializarEstadoUIParaNode
procedure TfrmGerenciarPermissoes.InicializarEstadoUIParaNodeRecursivo(ANode: TTreeNode; const AOriginalPermissions: TArrayOfSingleUserPermission);
var
  i: Integer;
begin
  if not Assigned(ANode) then Exit;
  InicializarEstadoUIParaNode(ANode, AOriginalPermissions);
  if ANode.HasChildren then
    for i := 0 to ANode.Count - 1 do
      InicializarEstadoUIParaNodeRecursivo(ANode.Item[i], AOriginalPermissions);
end;

procedure TfrmGerenciarPermissoes.InicializarEstadoUIParaNode(ANode: TTreeNode; const AOriginalPermissions: TArrayOfSingleUserPermission);
var
  NodeData: PItemMenuData;
  NodeKey: string;
  PermStateArray: TArrayOfUIPermissionState;
  PermOriginal: TSingleUserPermission;
  NomePerm: string;
  ValorPerm: Boolean;
  PermissoesPadrao: array[0..4] of string;
  i: Integer;
  Found: Boolean;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;

  NodeKey := NodeData^.Tipo + '_' + IntToStr(NodeData^.ID);

  PermissoesPadrao[0] := 'ACESSO';
  PermissoesPadrao[1] := 'P_INSERIR';
  PermissoesPadrao[2] := 'P_ALTERAR';
  PermissoesPadrao[3] := 'P_EXCLUIR';
  PermissoesPadrao[4] := 'P_IMPRIMIR';

  SetLength(PermStateArray, Length(PermissoesPadrao));

  for i := Low(PermissoesPadrao) to High(PermissoesPadrao) do
  begin
    NomePerm := PermissoesPadrao[i];
    ValorPerm := False; // Default é False

    // Procura a permissão nas originais carregadas
    Found := False;
    for PermOriginal in AOriginalPermissions do
    begin
      if (PermOriginal.ItemID = NodeData^.ID) and
         (PermOriginal.ItemTipo = NodeData^.Tipo) and
         (SameText(PermOriginal.NomePermissao, NomePerm)) then
      begin
        ValorPerm := PermOriginal.Valor;
        Found := True;
        Break;
      end;
    end;

    PermStateArray[i].NomePermissao := NomePerm;
    PermStateArray[i].Valor := ValorPerm;
    PermStateArray[i].Modificada := False; // Inicialmente, nenhuma permissão da UI foi modificada pelo usuário
  end;
  FUIPermissionsState.AddOrSetValue(NodeKey, PermStateArray);
end;


procedure TfrmGerenciarPermissoes.btnCarregarPermissoesClick(Sender: TObject);
var IDEmpresa, IDUsuario: Integer;
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
  LimparTodosOsEstadosUIPermissions; // Limpa o estado da UI
  SetLength(FPermissoesOriginaisCarregadas, 0); // Limpa as permissões originais antigas
  try
    PopularTreeView; // Popula o TreeView primeiro

    // Carrega as permissões do usuário do banco
    if not FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, FPermissoesOriginaisCarregadas) then
    begin
      ShowMessage('Falha ao carregar permissões do usuário.');
      MemoLog.Lines.Add(Format('FPermissaoController.CarregarPermissoesUsuario retornou False para Usuário ID %d.', [IDUsuario]));
      Screen.Cursor := crDefault;
      Exit;
    end;
    MemoLog.Lines.Add(Format('Permissões ORIGINAIS carregadas para Usuário ID %d: %d registros.', [IDUsuario, Length(FPermissoesOriginaisCarregadas)]));

    // Aplica as permissões carregadas para inicializar o FUIPermissionsState
    AplicarPermissoesCarregadasParaTodosNos(FPermissoesOriginaisCarregadas);

    // Atualiza a UI (checkboxes) para o nó selecionado (ou o primeiro nó)
    if tvMenu.Items.Count > 0 then
    begin
       if not Assigned(tvMenu.Selected) and (tvMenu.Items.Count > 0) then
         tvMenu.Selected := tvMenu.Items[0]; // Seleciona o primeiro nó se nenhum estiver selecionado

       if Assigned(tvMenu.Selected) then
         AtualizarChecksPermissaoParaNo(tvMenu.Selected); // Atualiza os checkboxes para o nó agora selecionado
    end else
        LimparPermissoesVisuais; // Se não há itens no menu, limpa os checkboxes

  finally Screen.Cursor := crDefault; end;

  FPermissoesModificadasGeral := False; // Reseta o indicador de modificações gerais
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

procedure TfrmGerenciarPermissoes.AtualizarChecksPermissaoParaNo(ANode: TTreeNode);
var
  NodeData: PItemMenuData;
  NodeKey: string;
  PermStateArray: TArrayOfUIPermissionState;
  PermUIState: TUIPermissionState;
  ValorAcesso, ValorInserir, ValorAlterar, ValorExcluir, ValorImprimir: Boolean;
begin
  LimparPermissoesVisuais;
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;

  gbPermissoesItem.Enabled := True;
  gbPermissoesItem.Caption := 'Permissões para: ' + ANode.Text;
  NodeKey := NodeData^.Tipo + '_' + IntToStr(NodeData^.ID);

  ValorAcesso := False; ValorInserir := False; ValorAlterar := False;
  ValorExcluir := False; ValorImprimir := False;

  if FUIPermissionsState.TryGetValue(NodeKey, PermStateArray) then
  begin
    for PermUIState in PermStateArray do
    begin
      if SameText(PermUIState.NomePermissao, 'ACESSO') then ValorAcesso := PermUIState.Valor
      else if SameText(PermUIState.NomePermissao, 'P_INSERIR') then ValorInserir := PermUIState.Valor
      else if SameText(PermUIState.NomePermissao, 'P_ALTERAR') then ValorAlterar := PermUIState.Valor
      else if SameText(PermUIState.NomePermissao, 'P_EXCLUIR') then ValorExcluir := PermUIState.Valor
      else if SameText(PermUIState.NomePermissao, 'P_IMPRIMIR') then ValorImprimir := PermUIState.Valor;
    end;
  end;
  // Se não encontrou no FUIPermissionsState, os valores default (False) são usados,
  // o que é correto pois InicializarEstadoUIParaNode já tratou as permissões originais.

  chkAcesso.Checked := ValorAcesso;
  // Habilita/desabilita e marca sub-permissões com base no tipo de item e na permissão de acesso
  if NodeData^.Tipo = 'R' then // Rotinas podem ter sub-permissões
  begin
    chkInserir.Enabled  := ValorAcesso; // Sub-permissões só habilitadas se Acesso = True
    chkAlterar.Enabled  := ValorAcesso;
    chkExcluir.Enabled  := ValorAcesso;
    chkImprimir.Enabled := ValorAcesso;

    chkInserir.Checked  := ValorAcesso and ValorInserir; // Marcado apenas se Acesso E a própria sub-permissão forem True
    chkAlterar.Checked  := ValorAcesso and ValorAlterar;
    chkExcluir.Checked  := ValorAcesso and ValorExcluir;
    chkImprimir.Checked := ValorAcesso and ValorImprimir;
  end
  else // Módulos e Submódulos não têm sub-permissões diretamente editáveis aqui
  begin
    chkInserir.Enabled  := False; chkInserir.Checked  := False;
    chkAlterar.Enabled  := False; chkAlterar.Checked  := False;
    chkExcluir.Enabled  := False; chkExcluir.Checked  := False;
    chkImprimir.Enabled := False; chkImprimir.Checked := False;
  end;
  // O GroupBox de permissões está habilitado se um nó estiver selecionado.
  // A habilitação individual dos checkboxes de sub-permissão é controlada acima.
end;

procedure TfrmGerenciarPermissoes.tvMenuSelectionChanged(Sender: TObject);
begin
  MemoLog.Lines.Add('tvMenuSelectionChanged disparado.');
  if Assigned(tvMenu.Selected) then
  begin
     MemoLog.Lines.Add('Nó selecionado: ' + tvMenu.Selected.Text);
     AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  end
  else
  begin
    MemoLog.Lines.Add('Nenhum nó selecionado em tvMenuSelectionChanged.');
    LimparPermissoesVisuais;
  end;
end;

// procedure TfrmGerenciarPermissoes.AtualizarEstadoPermissaoUI - REMOVIDO E SUBSTITUIDO por SetUIPermissionState
// function TfrmGerenciarPermissoes.GetEstadoPermissaoUI - REMOVIDO E SUBSTITUIDO por GetUIPermissionState
// procedure TfrmGerenciarPermissoes.MarcarNoAtualizarListaEditada - REMOVIDO, lógica integrada em chkPermissaoClick


procedure TfrmGerenciarPermissoes.SetUIPermissionState(AItemTipo: Char; AItemID: Integer; ANomePermissao: string; AValor: Boolean; AModificada: Boolean);
var
  NodeKey: string;
  PermStateArray: TArrayOfUIPermissionState;
  i: Integer;
  Found: Boolean;
begin
  NodeKey := AItemTipo + '_' + IntToStr(AItemID);
  Found := False;

  if FUIPermissionsState.TryGetValue(NodeKey, PermStateArray) then
  begin
    for i := Low(PermStateArray) to High(PermStateArray) do
    begin
      if SameText(PermStateArray[i].NomePermissao, ANomePermissao) then
      begin
        PermStateArray[i].Valor := AValor;
        PermStateArray[i].Modificada := AModificada or PermStateArray[i].Modificada; // Se já estava modificada, mantém true
        FUIPermissionsState.AddOrSetValue(NodeKey, PermStateArray); // Reatribui para garantir atualização no Dictionary
        Found := True;
        Break;
      end;
    end;
  end;

  if not Found then // Deveria ter sido inicializado em AplicarPermissoesCarregadas
  begin
    // Isso não deveria acontecer se InicializarEstadoUIParaNode foi chamado corretamente.
    // Mas, como fallback, podemos adicionar:
    SetLength(PermStateArray, 1); // Cria um novo array se não existia (improvável)
    PermStateArray[0].NomePermissao := ANomePermissao;
    PermStateArray[0].Valor := AValor;
    PermStateArray[0].Modificada := AModificada;
    FUIPermissionsState.AddOrSetValue(NodeKey, PermStateArray);
    MemoLog.Lines.Add(Format('AVISO: Permissão %s para %s não encontrada em FUIPermissionsState. Criada dinamicamente.', [ANomePermissao, NodeKey]));
  end;

  if AModificada then
  begin
    FPermissoesModificadasGeral := True;
    btnSalvarPermissoes.Enabled := True;
  end;
end;

function TfrmGerenciarPermissoes.GetUIPermissionState(AItemTipo: Char; AItemID: Integer; ANomePermissao: string; out AValor: Boolean; out AModificada: Boolean): Boolean;
var
  NodeKey: string;
  PermStateArray: TArrayOfUIPermissionState;
  PermState: TUIPermissionState;
begin
  Result := False; // Indica se a permissão foi encontrada no array
  AValor := False;
  AModificada := False;
  NodeKey := AItemTipo + '_' + IntToStr(AItemID);

  if FUIPermissionsState.TryGetValue(NodeKey, PermStateArray) then
  begin
    for PermState in PermStateArray do
    begin
      if SameText(PermState.NomePermissao, ANomePermissao) then
      begin
        AValor := PermState.Valor;
        AModificada := PermState.Modificada;
        Result := True;
        Exit;
      end;
    end;
  end;
end;

procedure TfrmGerenciarPermissoes.chkPermissaoClick(Sender: TObject);
var
  NodeData: PItemMenuData;
  CheckBox: TCheckBox;
  NomePermissaoClicada: string;
  NovoValor: Boolean;
  ValorAcessoAtual: Boolean;
  DummyModificada: Boolean; // Não precisamos do estado de modificação aqui
begin
  if not Assigned(tvMenu.Selected) then Exit;
  NodeData := GetItemMenuData(tvMenu.Selected);
  if not Assigned(NodeData) then Exit;

  CheckBox := TCheckBox(Sender);
  NomePermissaoClicada := GetNomePermissaoFromCheckBox(CheckBox);
  NovoValor := CheckBox.Checked;

  // Define o estado da permissão clicada
  SetUIPermissionState(NodeData^.Tipo, NodeData^.ID, NomePermissaoClicada, NovoValor, True);

  // Se o checkbox de Acesso foi alterado, precisamos reavaliar a habilitação e o estado
  // dos checkboxes de sub-permissões (Inserir, Alterar, Excluir, Imprimir)
  if CheckBox = chkAcesso then
  begin
    // Atualiza os checkboxes visuais com base no novo estado de Acesso
    // e os valores atuais das sub-permissões no FUIPermissionsState.
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  end
  else // Se um checkbox de sub-permissão foi alterado
  begin
    // Garante que, se uma sub-permissão for marcada, a permissão de Acesso também seja
    // considerada como marcada no estado da UI (se ainda não estiver).
    if NovoValor then // Se P_INSERIR (ou outra) foi marcada para True
    begin
      // Verifica o estado atual de ACESSO
      if GetUIPermissionState(NodeData^.Tipo, NodeData^.ID, 'ACESSO', ValorAcessoAtual, DummyModificada) then
      begin
        if not ValorAcessoAtual then // Se ACESSO estava False
        begin
          SetUIPermissionState(NodeData^.Tipo, NodeData^.ID, 'ACESSO', True, True);
          chkAcesso.Checked := True; // Atualiza visualmente
          // Re-habilita sub-checkboxes pois Acesso agora é True
          AtualizarChecksPermissaoParaNo(tvMenu.Selected);
        end;
      end;
    end;
  end;

  FPermissoesModificadasGeral := True;
  btnSalvarPermissoes.Enabled := True;
end;

procedure TfrmGerenciarPermissoes.btnSalvarPermissoesClick(Sender: TObject);
var
  IDEmpresa, IDUsuario: Integer;
  PermissoesParaSalvar: TArrayOfSingleUserPermission;
  NodeKey: string;
  ItemTipo: Char;
  ItemID: Integer;
  PermStateArray: TArrayOfUIPermissionState;
  PermUIState: TUIPermissionState;
  CountAlteradas: Integer;
  OriginalValue, CurrentValue, WasModified: Boolean;
  OriginalPerm: TSingleUserPermission;
  FoundOriginal: Boolean;
  j: Integer;
begin
  if not FPermissoesModificadasGeral then
  begin
    ShowMessage('Nenhuma permissão foi alterada.');
    Exit;
  end;

  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin
    ShowMessage('Selecione uma empresa e um usuário.');
    Exit;
  end;

  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin
    ShowMessage('Controller de permissão não inicializado.');
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  MemoLog.Lines.Add(Format('--- Iniciando salvamento para Usuário ID: %d, Empresa ID: %d ---', [IDUsuario, IDEmpresa]));
  SetLength(PermissoesParaSalvar, 0);
  CountAlteradas := 0;

  try
    // Iterar sobre o FUIPermissionsState para encontrar permissões modificadas
    for NodeKey in FUIPermissionsState.Keys do
    begin
      ItemTipo := NodeKey[1];
      ItemID   := StrToInt(Copy(NodeKey, 3, Length(NodeKey) - 2));
      PermStateArray := FUIPermissionsState.Items[NodeKey];

      for PermUIState in PermStateArray do
      begin
        if PermUIState.Modificada then // Apenas considera as que o usuário alterou na UI
        begin
          // Precisamos comparar com o valor original carregado do banco
          OriginalValue := False; // Default se não encontrar no original (deveria encontrar)
          FoundOriginal := False;
          for OriginalPerm in FPermissoesOriginaisCarregadas do
          begin
            if (OriginalPerm.ItemTipo = ItemTipo) and
               (OriginalPerm.ItemID = ItemID) and
               (SameText(OriginalPerm.NomePermissao, PermUIState.NomePermissao)) then
            begin
              OriginalValue := OriginalPerm.Valor;
              FoundOriginal := True;
              Break;
            end;
          end;

          // Se não encontrou no original, mas foi modificada, significa que era False e agora pode ser True.
          // Ou se encontrou e o valor mudou.
          if (not FoundOriginal and PermUIState.Valor) or (FoundOriginal and (PermUIState.Valor <> OriginalValue)) then
          begin
            SetLength(PermissoesParaSalvar, CountAlteradas + 1);
            PermissoesParaSalvar[CountAlteradas].ItemTipo := ItemTipo;
            PermissoesParaSalvar[CountAlteradas].ItemID   := ItemID;
            PermissoesParaSalvar[CountAlteradas].NomePermissao := PermUIState.NomePermissao;
            PermissoesParaSalvar[CountAlteradas].Valor   := PermUIState.Valor;
            Inc(CountAlteradas);

            MemoLog.Lines.Add(Format('ALTERADA: Item %s, ID %d, Perm: %s, Novo Valor: %s (Original: %s)',
              [ItemTipo, ItemID, PermUIState.NomePermissao, BoolToStrDB(PermUIState.Valor), BoolToStrDB(OriginalValue)]));
          end;
        end;
      end;
    end;

    if Length(PermissoesParaSalvar) > 0 then
    begin
      if FPermissaoController.SalvarPermissoesAlteradas(IDEmpresa, IDUsuario, PermissoesParaSalvar) then
      begin
        FPermissoesModificadasGeral := False;
        btnSalvarPermissoes.Enabled := False;
        ShowMessage('Permissões alteradas salvas com sucesso.');
        MemoLog.Lines.Add('Permissões alteradas salvas via Controller.');
        // Recarregar as permissões para refletir o estado atual do banco e resetar 'Modificada'
        btnCarregarPermissoesClick(nil);
      end
      else
      begin
        ShowMessage('Falha ao salvar permissões alteradas via Controller.');
        MemoLog.Lines.Add('Falha ao salvar permissões alteradas via Controller.');
      end;
    end
    else
    begin
      ShowMessage('Nenhuma permissão foi efetivamente alterada para salvar (comparado ao estado original).');
      FPermissoesModificadasGeral := False;
      btnSalvarPermissoes.Enabled := False;
       MemoLog.Lines.Add('Nenhuma alteração efetiva detectada para salvar.');
    end;

  finally
    Screen.Cursor := crDefault;
  end;
  MemoLog.Lines.Add('--- Fim do salvamento ---');
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
  if not Assigned(NodeData) then Exit;

  // Atualiza FEstadoAtualPermissoesUI para este nó com todas as permissões como False
  AtualizarEstadoPermissaoUI(NodeData, False, False, False, False, False);

  // Se este nó é o que está atualmente selecionado na UI, atualiza os checkboxes visuais
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := False;
      chkInserir.Checked := False; chkInserir.Enabled := (NodeData^.Tipo = 'R');
      chkAlterar.Checked := False; chkAlterar.Enabled := (NodeData^.Tipo = 'R');
      chkExcluir.Checked := False; chkExcluir.Enabled := (NodeData^.Tipo = 'R');
      chkImprimir.Checked := False; chkImprimir.Enabled := (NodeData^.Tipo = 'R');
      if NodeData^.Tipo <> 'R' then gbPermissoesItem.Enabled := True else gbPermissoesItem.Enabled := chkAcesso.Checked; // Habilita groupbox se for M ou S e Acesso é true (aqui será false)
  end;

  for j := 0 to ANode.Count - 1 do ProcessarNoParaLimpezaTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
var j: Integer; NodeData: PItemMenuData;
    TodasPermsParaRotina: Boolean;
begin
  if not Assigned(ANode) then Exit; NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;

  TodasPermsParaRotina := (NodeData^.Tipo = 'R');

  // Atualiza FEstadoAtualPermissoesUI para este nó com Acesso=True, e outras True se for Rotina
  AtualizarEstadoPermissaoUI(NodeData, True, TodasPermsParaRotina, TodasPermsParaRotina, TodasPermsParaRotina, TodasPermsParaRotina);

  // Se este nó é o que está atualmente selecionado na UI, atualiza os checkboxes visuais
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := True;
      gbPermissoesItem.Enabled := True;
      if NodeData^.Tipo = 'R' then
      begin
          chkInserir.Enabled  := True; chkInserir.Checked  := True;
          chkAlterar.Enabled  := True; chkAlterar.Checked  := True;
          chkExcluir.Enabled  := True; chkExcluir.Checked  := True;
          chkImprimir.Enabled := True; chkImprimir.Checked := True;
      end else begin
          chkInserir.Enabled := False; chkInserir.Checked := False;
          chkAlterar.Enabled := False; chkAlterar.Checked := False;
          chkExcluir.Enabled := False; chkExcluir.Checked := False;
          chkImprimir.Enabled := False; chkImprimir.Checked := False;
      end;
  end;
  for j := 0 to ANode.Count - 1 do ProcessarNoParaSelecaoTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var i: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do
    ProcessarNoParaSelecaoOuLimpeza(tvMenu.Items[i], False); // False para Limpar

  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected)
  else if tvMenu.Items.Count > 0 then
  begin
    tvMenu.Selected := tvMenu.Items[0]; // Seleciona o primeiro para atualizar a UI
    AtualizarChecksPermissaoParaNo(tvMenu.Items[0]);
  end
  else
    LimparPermissoesVisuais;

  FPermissoesModificadasGeral := True;
  btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram desmarcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Limpar Todas clicado.');
end;


procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoOuLimpeza(ANode: TTreeNode; ASelecionar: Boolean);
var
  j: Integer;
  NodeData: PItemMenuData;
  PermNome: string;
  ValorAplicar: Boolean;
  PermissoesNomes: array[0..4] of string;
  k: Integer;
begin
  if not Assigned(ANode) then Exit;
  NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;

  PermissoesNomes[0] := 'ACESSO';
  PermissoesNomes[1] := 'P_INSERIR';
  PermissoesNomes[2] := 'P_ALTERAR';
  PermissoesNomes[3] := 'P_EXCLUIR';
  PermissoesNomes[4] := 'P_IMPRIMIR';

  for k := Low(PermissoesNomes) to High(PermissoesNomes) do
  begin
    PermNome := PermissoesNomes[k];

    // Define o valor base (True para selecionar, False para limpar)
    ValorAplicar := ASelecionar;

    // Lógica específica para ACESSO e sub-permissões
    if PermNome = 'ACESSO' then
    begin
      // Para ACESSO, o valor é diretamente ASelecionar (True para selecionar, False para limpar)
      SetUIPermissionState(NodeData^.Tipo, NodeData^.ID, PermNome, ASelecionar, True);
    end
    else // Para P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR
    begin
      if NodeData^.Tipo = 'R' then // Sub-permissões só se aplicam a Rotinas
      begin
        // Se estamos selecionando tudo (ASelecionar = True), então todas as sub-permissões da rotina também são True.
        // Se estamos limpando tudo (ASelecionar = False), então todas as sub-permissões da rotina também são False.
        SetUIPermissionState(NodeData^.Tipo, NodeData^.ID, PermNome, ASelecionar, True);
      end
      else // Para Módulos e Submódulos, as sub-permissões são sempre False e não são "modificadas" por esta ação em massa.
      begin
        SetUIPermissionState(NodeData^.Tipo, NodeData^.ID, PermNome, False, False);
      end;
    end;
  end;

  // Processa filhos recursivamente
  for j := 0 to ANode.Count - 1 do
    ProcessarNoParaSelecaoOuLimpeza(ANode.Item[j], ASelecionar);
end;

procedure TfrmGerenciarPermissoes.btnSelecionarTodasClick(Sender: TObject);
var i: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do
    ProcessarNoParaSelecaoTotal(tvMenu.Items[i], True); // True para Selecionar

  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  else if tvMenu.Items.Count > 0 then // Se nada estiver selecionado, mas há itens, atualize o primeiro
  begin
    tvMenu.Selected := tvMenu.Items[0];
    AtualizarChecksPermissaoParaNo(tvMenu.Items[0]);
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
