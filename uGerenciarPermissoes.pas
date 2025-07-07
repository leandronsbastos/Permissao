unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList, StrUtils,
  uPermissaoController;

type
  TItemMenuData = record // Este é o record usado para Node.Data
    ID: Integer;
    Tipo: Char;
    NomeForm: string;
  end;
  PItemMenuData = ^TItemMenuData; // Ponteiro para TItemMenuData

  // TMenuItemStructure e TArrayOfMenuItemStructure vêm de uPermissaoController

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
  FPermissoesModificadas := False;
  FPermissoesEditadas.Clear;
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  MenuEstruturaArray: TArrayOfMenuItemStructure;
  Node, PaiNode: TTreeNode;
  ItemStruct: TMenuItemStructure; // Renomeado para não conflitar com 'Item' propriedade de TTreeNode
  MapaNos: TStringList;
  ChaveItem, ChavePai: string;
  I, J: Integer;
  ItensNaoProcessados: TList;
  ItemPtr: PMenuItemStructure; // Usando tipo ponteiro de uPermissaoController
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
        ItemPtr := PMenuItemStructure(ItensNaoProcessados[J]); // Cast para o tipo de ponteiro definido em uPermissaoController
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

          Dispose(ItemPtr); // CORRIGIDO: Usar Dispose para ponteiros alocados com New
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
      Dispose(PMenuItemStructure(ItensNaoProcessados[I])); // CORRIGIDO: Usar Dispose

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

procedure TfrmGerenciarPermissoes.AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var i: Integer; NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    PermString: string; FoundInList: Boolean;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);

  TemAcesso := False; PodeInserir := False; PodeAlterar := False;
  PodeExcluir := False; PodeImprimir := False;

  for PermItem in AUserPermissions do
  begin
    if (PermItem.ItemID = NodeData^.ID) and (PermItem.ItemTipo = NodeData^.Tipo) then
    begin
      TemAcesso    := PermItem.Acesso;
      PodeInserir  := PermItem.Inserir;
      PodeAlterar  := PermItem.Alterar;
      PodeExcluir  := PermItem.Excluir;
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
      FPermissoesEditadas[i] := PermString;
      FoundInList := True;
      Break;
    end;
  end;
  if not FoundInList then
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
    ValAcesso, ValInserir, ValAlterar, ValExcluir, ValImprimir: Boolean;
begin
  if not Assigned(ANodeData) then Exit; foundInList := False; tmpPermInfo := TStringList.Create;
  try
    ValAcesso := ACheckedState;

    if ANodeData^.Tipo = 'R' then
    begin
      // Ao marcar/desmarcar Acesso, as permissões granulares são baseadas no estado dos checkboxes
      // apenas se Acesso estiver True. Se Acesso for False, todas são False.
      ValInserir  := ValAcesso and chkInserir.Checked;
      ValAlterar  := ValAcesso and chkAlterar.Checked;
      ValExcluir  := ValAcesso and chkExcluir.Checked;
      ValImprimir := ValAcesso and chkImprimir.Checked;
    end else
    begin
      ValInserir := False; ValAlterar := False; ValExcluir := False; ValImprimir := False;
    end;

    for idx := 0 to FPermissoesEditadas.Count - 1 do
    begin
      tmpPermInfo.Delimiter := '|'; tmpPermInfo.DelimitedText := FPermissoesEditadas[idx];
      if (tmpPermInfo.Count = 7) and (tmpPermInfo[0][1] = ANodeData^.Tipo) and (StrToInt(tmpPermInfo[1]) = ANodeData^.ID) then
      begin
        tmpPermInfo[2] := BoolToStrDB(ValAcesso);
        tmpPermInfo[3] := BoolToStrDB(ValInserir);
        tmpPermInfo[4] := BoolToStrDB(ValAlterar);
        tmpPermInfo[5] := BoolToStrDB(ValExcluir);
        tmpPermInfo[6] := BoolToStrDB(ValImprimir);
        FPermissoesEditadas[idx] := tmpPermInfo.DelimitedText; foundInList := True; Break;
      end;
    end;

    if not foundInList then
    begin
      tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                  BoolToStrDB(ValAcesso) + '|' +
                  BoolToStrDB(ValInserir) + '|' +
                  BoolToStrDB(ValAlterar) + '|' +
                  BoolToStrDB(ValExcluir) + '|' +
                  BoolToStrDB(ValImprimir);
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
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := False; chkInserir.Checked := False; chkAlterar.Checked := False;
      chkExcluir.Checked := False; chkImprimir.Checked := False;
  end;
  MarcarNoAtualizarListaEditada(NodeData, False);

  if ANode = tvMenu.Selected then
  begin
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
  if ANode = tvMenu.Selected then
  begin
      chkAcesso.Checked := True;
      if NodeData^.Tipo = 'R' then
      begin
          chkInserir.Checked  := True; chkAlterar.Checked  := True;
          chkExcluir.Checked  := True; chkImprimir.Checked := True;
      end;
  end;
  MarcarNoAtualizarListaEditada(NodeData, True);

  if ANode = tvMenu.Selected then
  begin
      if NodeData^.Tipo = 'R' then
      begin
          chkInserir.Enabled  := True; chkAlterar.Enabled  := True;
          chkExcluir.Enabled  := True; chkImprimir.Enabled := True;
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
