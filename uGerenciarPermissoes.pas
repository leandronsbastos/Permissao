unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList, StrUtils,
  uPermissaoController; // MOVIMOS uPermissaoController PARA A INTERFACE USES

type
  TItemMenuData = record
    ID: Integer;
    Tipo: Char;
    NomeForm: string;
  end;
  PItemMenuData = ^TItemMenuData;

  // _TUserPermissionItem e _TArrayOfUserPermissionItem REMOVIDOS DAQUI
  // pois TArrayOfUserPermissionItem agora vem de uPermissaoController

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
    // Campos primeiro
    FPermissaoController: TPermissaoController; // CORRETO
    FPermissoesModificadas: Boolean;
    FPermissoesEditadas: TStringList;

    // Listas de simulação de dados (serão progressivamente removidas ou usadas apenas para mock)
    FEmpresasData: TStringList;
    FUsuariosData: TStringList;
    FMenuEstruturaSimulada: TStringList; // Renomeado para clareza

    // Métodos
    procedure CarregarEmpresas;
    procedure CarregarUsuarios(AIDEmpresa: Integer);
    procedure LimparPermissoesVisuais;
    procedure PopularTreeView;
    // Assinaturas ajustadas para usar TArrayOfUserPermissionItem de uPermissaoController
    procedure AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
    procedure AtualizarChecksPermissaoParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
    function GetItemMenuData(ANode: TTreeNode): PItemMenuData;
    procedure SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);

    procedure MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
    procedure ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
    procedure ProcessarNoParaLimpezaTotal(ANode: TTreeNode);

    procedure SimularCargaEmpresas; // Manter por enquanto para cbEmpresa
    procedure SimularCargaUsuarios(AIDEmpresa: Integer); // Manter por enquanto para cbUsuario
    procedure SimularCargaEstruturaMenu; // Manter por enquanto para tvMenu

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

  if not FPermissaoController.TestConnection then // CORRIGIDO: Adicionado THEN
  begin
    ShowMessage('Falha ao conectar ao banco de dados! Verifique as configurações de conexão no FormCreate de uGerenciarPermissoes.');
  end;

  FPermissoesModificadas := False;
  FPermissoesEditadas := TStringList.Create;

  // Listas de simulação (ainda usadas para popular ComboBoxes e TreeView na fase de transição)
  FEmpresasData := TStringList.Create;
  FUsuariosData := TStringList.Create;
  FMenuEstruturaSimulada := TStringList.Create;


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
  FreeAndNil(FEmpresasData); // Liberar listas de simulação
  FreeAndNil(FUsuariosData);
  FreeAndNil(FMenuEstruturaSimulada);
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  if cbEmpresa.Items.Count > 0 then // CORRIGIDO: Adicionado THEN
  begin
    if cbEmpresa.ItemIndex = -1 then // CORRIGIDO: Adicionado THEN
       cbEmpresa.ItemIndex := 0;
  end else
  begin
     btnCarregarPermissoes.Enabled := False;
  end;
end;

// --- MÉTODOS DE SIMULAÇÃO (Manter por enquanto para popular ComboBoxes e TreeView) ---
procedure TfrmGerenciarPermissoes.SimularCargaEmpresas;
begin
  FEmpresasData.Clear;
  FEmpresasData.Add('1|Empresa A');
  FEmpresasData.Add('2|Empresa B');
end;

procedure TfrmGerenciarPermissoes.SimularCargaUsuarios(AIDEmpresa: Integer);
begin
  FUsuariosData.Clear;
  if AIDEmpresa = 1 then
  begin
    FUsuariosData.Add('101|Usuário Alpha|1');
    FUsuariosData.Add('102|Usuário Beta|1');
    FUsuariosData.Add('103|Admin Empresa A|1');
  end
  else if AIDEmpresa = 2 then
  begin
    FUsuariosData.Add('201|Usuário Gamma|2');
    FUsuariosData.Add('202|Usuário Delta|2');
  end;
end;

procedure TfrmGerenciarPermissoes.SimularCargaEstruturaMenu;
begin
  FMenuEstruturaSimulada.Clear;
  FMenuEstruturaSimulada.Add('1|M|Cadastro|0|0||1');
  FMenuEstruturaSimulada.Add('1|R|Ramo de Atividades|1|0|frmRamoAtividades|1');
  FMenuEstruturaSimulada.Add('101|S|Profissionais|1|0||16');
  FMenuEstruturaSimulada.Add('3|R|Funcionários|0|101|frmFuncionarios|1');
end;
// --- FIM MÉTODOS DE SIMULAÇÃO ---

procedure TfrmGerenciarPermissoes.CarregarEmpresas;
var
  i: Integer;
  EmpresaInfo: TStringList;
begin
  cbEmpresa.Items.Clear;
  // Simulação ainda usada para ComboBox, idealmente viria do Controller
  SimularCargaEmpresas;
  EmpresaInfo := TStringList.Create;
  try
    for i := 0 to FEmpresasData.Count - 1 do
    begin
      EmpresaInfo.Delimiter := '|';
      EmpresaInfo.DelimitedText := FEmpresasData[i];
      if EmpresaInfo.Count = 2 then // CORRIGIDO: Adicionado THEN
        cbEmpresa.Items.AddObject(EmpresaInfo[1], TObject(StrToInt(EmpresaInfo[0])));
    end;
  finally
    EmpresaInfo.Free;
  end;

  if cbEmpresa.Items.Count > 0 then // CORRIGIDO: Adicionado THEN
  begin
    cbEmpresa.ItemIndex := 0;
  end else
  begin
    cbUsuario.Items.Clear;
    btnCarregarPermissoes.Enabled := False;
  end;
end;

procedure TfrmGerenciarPermissoes.CarregarUsuarios(AIDEmpresa: Integer);
var
  i: Integer;
  UsuarioInfo: TStringList;
begin
  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais;

  // Simulação ainda usada para ComboBox
  SimularCargaUsuarios(AIDEmpresa);
  UsuarioInfo := TStringList.Create;
  try
    for i := 0 to FUsuariosData.Count - 1 do
    begin
      UsuarioInfo.Delimiter := '|';
      UsuarioInfo.DelimitedText := FUsuariosData[i];
      if UsuarioInfo.Count >= 2 then // CORRIGIDO: Adicionado THEN
         cbUsuario.Items.AddObject(UsuarioInfo[1], TObject(StrToInt(UsuarioInfo[0])));
    end;
  finally
    UsuarioInfo.Free;
  end;

  if cbUsuario.Items.Count > 0 then // CORRIGIDO: Adicionado THEN
  begin
    cbUsuario.ItemIndex := 0;
    btnCarregarPermissoes.Enabled := True;
    btnCarregarPermissoesClick(nil);
  end
  else
  begin
    btnCarregarPermissoes.Enabled := False;
  end;
  btnCopiarPermissoes.Enabled := (cbUsuario.Items.Count > 0);
end;

procedure TfrmGerenciarPermissoes.cbEmpresaChange(Sender: TObject);
var
  IDEmpresa: Integer;
begin
  if cbEmpresa.ItemIndex <> -1 then // CORRIGIDO: Adicionado THEN
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
  MenuEstruturaArray: TArrayOfMenuItemStructure; // Usa tipo do Controller
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
  if not Assigned(FPermissaoController) then
  begin
    ShowMessage('Controller não inicializado em PopularTreeView.');
    Exit;
  end;

  // Carrega a estrutura do menu usando o Controller
  if not FPermissaoController.CarregarEstruturaMenu(MenuEstruturaArray) then // CORRIGIDO: Adicionado THEN
  begin
    ShowMessage('Falha ao carregar estrutura do menu.');
    MemoLog.Lines.Add('Falha ao carregar estrutura do menu do controller.');
    Exit;
  end;

  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear;
    for Item in MenuEstruturaArray do // CORRIGIDO: Iterar sobre o array do controller
    begin
      if Item.Tipo = 'M' then
      begin
        Node := tvMenu.Items.AddObject(nil, Item.Nome, nil);
        SetItemMenuData(Node, Item.ID, Item.Tipo, Item.NomeForm);
      end;
    end;

    for i := 0 to Length(MenuEstruturaArray) -1 do
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
    if tvMenu.Items.Count > 0 then // CORRIGIDO: Adicionado THEN
      tvMenu.Selected := tvMenu.Items[0];
  end;
  btnLimparTodas.Enabled := (tvMenu.Items.Count > 0);
  btnSelecionarTodas.Enabled := (tvMenu.Items.Count > 0);
end;

procedure TfrmGerenciarPermissoes.AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var i: Integer; NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    PermString: string;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);
  TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;

  for PermItem in AUserPermissions do // CORRIGIDO: Iterar sobre AUserPermissions
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
  // Esta linha é crucial: FPermissoesEditadas deve refletir o estado inicial do banco
  PermString := NodeData^.Tipo + '|' + IntToStr(NodeData^.ID) + '|' +
                BoolToStrDB(TemAcesso) + '|' + BoolToStrDB(PodeInserir) + '|' +
                BoolToStrDB(PodeAlterar) + '|' + BoolToStrDB(PodeExcluir) + '|' +
                BoolToStrDB(PodeImprimir);

  // Remove entrada antiga se existir e adiciona a nova
  for i := FPermissoesEditadas.Count - 1 downto 0 do
  begin
    if Pos(NodeData^.Tipo + '|' + IntToStr(NodeData^.ID) + '|', FPermissoesEditadas[i]) = 1 then
    begin
      FPermissoesEditadas.Delete(i);
      Break;
    end;
  end;
  FPermissoesEditadas.Add(PermString);


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

  if ANode.HasChildren then // CORRIGIDO: Adicionado THEN
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
  FPermissoesEditadas.Clear;
  try
    PopularTreeView;

    if not FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then // CORRIGIDO: Adicionado THEN
    begin
      ShowMessage('Falha ao carregar permissões do usuário.');
      MemoLog.Lines.Add(Format('Falha ao carregar permissões para Usuário ID %d, Empresa ID %d', [IDUsuario, IDEmpresa]));
      Screen.Cursor := crDefault; // Restaurar cursor antes de Exit
      Exit;
    end;
    MemoLog.Lines.Add(Format('Permissões carregadas para Usuário ID %d: %d registros.', [IDUsuario, Length(UserPermissions)]));

    if tvMenu.Items.Count > 0 then // CORRIGIDO: Adicionado THEN
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
  FoundInEdited := False;

  PermInfoEdited := TStringList.Create;
  try
    for i := 0 to FPermissoesEditadas.Count - 1 do
    begin
      PermInfoEdited.Delimiter := '|'; PermInfoEdited.DelimitedText := FPermissoesEditadas[i];
      if PermInfoEdited.Count = 7 then // CORRIGIDO: Adicionado THEN
      begin
        PermItemTipoEdited := PermInfoEdited[0][1]; PermItemIDEdited := StrToInt(PermInfoEdited[1]);
        if (NodeData^.ID = PermItemIDEdited) and (NodeData^.Tipo = PermItemTipoEdited) then // CORRIGIDO: Adicionado THEN
        begin
          TemAcesso    := StrDBToBool(PermInfoEdited[2]); PodeInserir  := StrDBToBool(PermInfoEdited[3]);
          PodeAlterar  := StrDBToBool(PermInfoEdited[4]); PodeExcluir  := StrDBToBool(PermInfoEdited[5]);
          PodeImprimir := StrDBToBool(PermInfoEdited[6]);
          FoundInEdited := True; Break;
        end;
      end;
    end;
  finally PermInfoEdited.Free; end;

  if not FoundInEdited then // CORRIGIDO: Adicionado THEN
  begin
    for PermItem in AUserPermissions do
    begin
      if (PermItem.ItemID = NodeData^.ID) and (PermItem.ItemTipo = NodeData^.Tipo) then // CORRIGIDO: Adicionado THEN
      begin
        TemAcesso    := PermItem.Acesso; PodeInserir  := PermItem.Inserir;
        PodeAlterar  := PermItem.Alterar; PodeExcluir  := PermItem.Excluir;
        PodeImprimir := PermItem.Imprimir;
        Break;
      end;
    end;
  end;

  chkAcesso.Checked := TemAcesso;
  if NodeData^.Tipo = 'R' then // CORRIGIDO: Adicionado THEN
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
  if Assigned(tvMenu.Selected) then // CORRIGIDO: Adicionado THEN
  begin
     if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) then // CORRIGIDO: Adicionado THEN
     begin
        IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
        IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
        if Assigned(FPermissaoController) then // CORRIGIDO: Adicionado THEN
        begin
          // Recarrega as permissões originais para referência ao mudar seleção no TreeView
          if FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, UserPermissions) then // CORRIGIDO: Adicionado THEN
            AktualizarChecksPermissaoParaNo(tvMenu.Selected, UserPermissions)
          else
            MemoLog.Lines.Add('Falha ao recarregar permissões em tvMenuSelectionChanged.');
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
      if (tmpPermInfo.Count = 7) and (tmpPermInfo[0][1] = ANodeData^.Tipo) and (StrToInt(tmpPermInfo[1]) = ANodeData^.ID) then // CORRIGIDO: Adicionado THEN
      begin
        tmpPermInfo[2] := BoolToStrDB(ACheckedState);
        if ANodeData^.Tipo = 'R' then begin
             PodeInserir := chkInserir.Checked; // Usa o estado atual dos checkboxes para as permissões granulares
             PodeAlterar := chkAlterar.Checked;
             PodeExcluir := chkExcluir.Checked;
             PodeImprimir := chkImprimir.Checked;
             // Se Acesso é False, todas as outras são False, independente dos checkboxes
             if not ACheckedState then begin PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False; end;

             tmpPermInfo[3] := BoolToStrDB(PodeInserir); tmpPermInfo[4] := BoolToStrDB(PodeAlterar);
             tmpPermInfo[5] := BoolToStrDB(PodeExcluir); tmpPermInfo[6] := BoolToStrDB(PodeImprimir);
        end else begin tmpPermInfo[3] := '0'; tmpPermInfo[4] := '0'; tmpPermInfo[5] := '0'; tmpPermInfo[6] := '0'; end;
        FPermissoesEditadas[idx] := tmpPermInfo.DelimitedText; foundInList := True; Break;
      end;
    end;
    if not foundInList then
    begin
      if ANodeData^.Tipo = 'R' then begin
           PodeInserir := chkInserir.Checked; PodeAlterar := chkAlterar.Checked;
           PodeExcluir := chkExcluir.Checked; PodeImprimir := chkImprimir.Checked;
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
        if PermInfo.Count = 7 then // CORRIGIDO: Adicionado THEN
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

      if FPermissaoController.SalvarTodasPermissoesUsuario(IDEmpresa, IDUsuario, UserPermsToSave) then // CORRIGIDO: Adicionado THEN
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
    if frmSelUsu.ShowModal = mrOk then // CORRIGIDO: Adicionado THEN
    begin
      IDUsuOrigem := frmSelUsu.IDUsuarioSelecionado;
      if IDUsuOrigem > 0 then // CORRIGIDO: Adicionado THEN
      begin
        if MessageDlgFmt('Copiar todas as permissões do usuário "%s" para o usuário "%s"?',
                         [frmSelUsu.NomeUsuarioSelecionado, cbUsuario.Text],
                         mtConfirmation, [mbYes, mbNo],0) = mrYes then // CORRIGIDO: Adicionado THEN
        begin
          Screen.Cursor := crHourGlass;
          try
            if FPermissaoController.CopiarPermissoes(IDEmpresaCopia, IDUsuOrigem, IDUsuDestino) then // CORRIGIDO: Adicionado THEN
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

  if Assigned(tvMenu.Selected) then // CORRIGIDO: Adicionado THEN
  begin
    if (cbEmpresa.ItemIndex <> -1) and (cbUsuario.ItemIndex <> -1) and Assigned(FPermissaoController) then // CORRIGIDO: Adicionado THEN
    begin
        if FPermissaoController.CarregarPermissoesUsuario(Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]), Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]), UserPermissions) then // CORRIGIDO: Adicionado THEN
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
