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
    FEstadoAtualPermissoesUI: TStringList;
    FPermissoesOriginais: TArrayOfUserPermissionItem;

    procedure CarregarEmpresas;
    procedure CarregarUsuarios(AIDEmpresa: Integer);
    procedure LimparPermissoesVisuais;
    procedure PopularTreeView;
    procedure AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
    procedure AtualizarChecksPermissaoParaNo(ANode: TTreeNode); // Assinatura corrigida
    function GetItemMenuData(ANode: TTreeNode): PItemMenuData;
    procedure SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);

    procedure MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
    procedure AtualizarEstadoPermissaoUI(ANodeData: PItemMenuData; AAcesso, AInserir, AAlterar, AExcluir, AImprimir: Boolean); // Já estava correta
    function GetEstadoPermissaoUI(ANodeData: PItemMenuData; out ValAcesso, ValInserir, ValAlterar, ValExcluir, ValImprimir: Boolean): Boolean;

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
  FEstadoAtualPermissoesUI := TStringList.Create;
  FEstadoAtualPermissoesUI.Sorted := True;
  FEstadoAtualPermissoesUI.Duplicates := dupIgnore;

  SetLength(FPermissoesOriginais, 0);

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
  FreeAndNil(FEstadoAtualPermissoesUI);
  SetLength(FPermissoesOriginais, 0);
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
  FEstadoAtualPermissoesUI.Clear;
  SetLength(FPermissoesOriginais, 0);
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

procedure TfrmGerenciarPermissoes.AplicarPermissoesVisuaisParaNo(ANode: TTreeNode; const AUserPermissions: TArrayOfUserPermissionItem);
var i: Integer; NodeData: PItemMenuData; PermItem: TUserPermissionItem;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    PermString, ChaveItem: string;
    IdxCache: Integer;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);
  ChaveItem := NodeData^.Tipo + '_' + IntToStr(NodeData^.ID);

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

  PermString := BoolToStrDB(TemAcesso) + '|' + BoolToStrDB(PodeInserir) + '|' +
                BoolToStrDB(PodeAlterar) + '|' + BoolToStrDB(PodeExcluir) + '|' +
                BoolToStrDB(PodeImprimir);

  if FEstadoAtualPermissoesUI.Find(ChaveItem, IdxCache) then
      FEstadoAtualPermissoesUI.ValueFromIndex[IdxCache] := PermString
  else
      FEstadoAtualPermissoesUI.Add(ChaveItem + '=' + PermString);


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
var IDEmpresa, IDUsuario, i: Integer;
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
  FEstadoAtualPermissoesUI.Clear;
  SetLength(FPermissoesOriginais, 0);
  try
    PopularTreeView;

    if not FPermissaoController.CarregarPermissoesUsuario(IDEmpresa, IDUsuario, FPermissoesOriginais) then
    begin
      ShowMessage('Falha ao carregar permissões do usuário.');
      MemoLog.Lines.Add(Format('FPermissaoController.CarregarPermissoesUsuario retornou False para Usuário ID %d.', [IDUsuario]));
      Screen.Cursor := crDefault;
      Exit;
    end;
    MemoLog.Lines.Add(Format('Permissões ORIGINAIS carregadas para Usuário ID %d: %d registros.', [IDUsuario, Length(FPermissoesOriginais)]));

    if tvMenu.Items.Count > 0 then
    begin
       for i := 0 to tvMenu.Items.Count -1 do
          AplicarPermissoesVisuaisParaNo(tvMenu.Items[i], FPermissoesOriginais);

       if Assigned(tvMenu.Selected) then
         AtualizarChecksPermissaoParaNo(tvMenu.Selected)
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

procedure TfrmGerenciarPermissoes.AtualizarChecksPermissaoParaNo(ANode: TTreeNode);
var NodeData: PItemMenuData;
    TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
    PermItemOriginal: TUserPermissionItem;
    FoundOriginal: Boolean;
begin
  LimparPermissoesVisuais;
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;

  gbPermissoesItem.Enabled := True;
  gbPermissoesItem.Caption := 'Permissões para: ' + ANode.Text;

  // Tenta obter do estado editado primeiro (FEstadoAtualPermissoesUI)
  if not GetEstadoPermissaoUI(NodeData, TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir) then
  begin
    // Se não foi editado, pega das permissões originais carregadas (FPermissoesOriginais)
    FoundOriginal := False;
    for PermItemOriginal in FPermissoesOriginais do
    begin
      if (PermItemOriginal.ItemID = NodeData^.ID) and (PermItemOriginal.ItemTipo = NodeData^.Tipo) then
      begin
        TemAcesso    := PermItemOriginal.Acesso; PodeInserir  := PermItemOriginal.Inserir;
        PodeAlterar  := PermItemOriginal.Alterar; PodeExcluir  := PermItemOriginal.Excluir;
        PodeImprimir := PermItemOriginal.Imprimir;
        FoundOriginal := True; // Hint H2077: Value assigned to 'FoundOriginal' never used - REMOVIDO
        Break;
      end;
    end;
    // Se não encontrou no original, todas as permissões são False (estado padrão de LimparPermissoesVisuais)
  end;

  chkAcesso.Checked := TemAcesso;
  if NodeData^.Tipo = 'R' then
  begin
    chkInserir.Enabled := True; chkInserir.Checked := PodeInserir;
    chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
    chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir;
    chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
  end else begin
    chkInserir.Enabled := False; chkInserir.Checked := False;
    chkAlterar.Enabled := False; chkAlterar.Checked := False;
    chkExcluir.Enabled := False; chkExcluir.Checked := False;
    chkImprimir.Enabled := False; chkImprimir.Checked := False;
  end;
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

procedure TfrmGerenciarPermissoes.AtualizarEstadoPermissaoUI(ANodeData: PItemMenuData;
  AAcesso, AInserir, AAlterar, AExcluir, AImprimir: Boolean);
var
  ChaveItem, PermString: string;
  Idx: Integer;
begin
  if not Assigned(ANodeData) then Exit;
  ChaveItem := ANodeData^.Tipo + '_' + IntToStr(ANodeData^.ID);
  PermString := BoolToStrDB(AAcesso) + '|' + BoolToStrDB(AInserir) + '|' +
                BoolToStrDB(AAlterar) + '|' + BoolToStrDB(AExcluir) + '|' +
                BoolToStrDB(AImprimir);

  if FEstadoAtualPermissoesUI.Find(ChaveItem, Idx) then
    FEstadoAtualPermissoesUI.ValueFromIndex[Idx] := PermString
  else
    FEstadoAtualPermissoesUI.Add(ChaveItem + '=' + PermString);

  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
end;

function TfrmGerenciarPermissoes.GetEstadoPermissaoUI(ANodeData: PItemMenuData;
  out ValAcesso, ValInserir, ValAlterar, ValExcluir, ValImprimir: Boolean): Boolean;
var
  ChaveItem, PermStringValores: string;
  Idx: Integer;
  PermInfo: TStringList;
begin
  Result := False;
  ValAcesso := False; ValInserir := False; ValAlterar := False; ValExcluir := False; ValImprimir := False;

  if not Assigned(ANodeData) then Exit;
  ChaveItem := ANodeData^.Tipo + '_' + IntToStr(ANodeData^.ID);

  if FEstadoAtualPermissoesUI.Find(ChaveItem, Idx) then
  begin
    PermStringValores := FEstadoAtualPermissoesUI.ValueFromIndex[Idx];
    PermInfo := TStringList.Create;
    try
      PermInfo.Delimiter := '|';
      PermInfo.DelimitedText := PermStringValores;
      if PermInfo.Count = 5 then
      begin
        ValAcesso    := StrDBToBool(PermInfo[0]);
        ValInserir   := StrDBToBool(PermInfo[1]);
        ValAlterar   := StrDBToBool(PermInfo[2]);
        ValExcluir   := StrDBToBool(PermInfo[3]);
        ValImprimir  := StrDBToBool(PermInfo[4]);
        Result := True;
      end;
    finally
      PermInfo.Free;
    end;
  end;
end;


procedure TfrmGerenciarPermissoes.MarcarNoAtualizarListaEditada(ANodeData: PItemMenuData; ACheckedState: Boolean);
var ValAcesso, ValInserir, ValAlterar, ValExcluir, ValImprimir: Boolean;
begin
  if not Assigned(ANodeData) then Exit;

  ValAcesso := ACheckedState;

  if ANodeData^.Tipo = 'R' then
  begin
    ValInserir  := ValAcesso and chkInserir.Checked;
    ValAlterar  := ValAcesso and chkAlterar.Checked;
    ValExcluir  := ValAcesso and chkExcluir.Checked;
    ValImprimir := ValAcesso and chkImprimir.Checked;
  end else
  begin
    ValInserir := False; ValAlterar := False; ValExcluir := False; ValImprimir := False;
  end;
  AtualizarEstadoPermissaoUI(ANodeData, ValAcesso, ValInserir, ValAlterar, ValExcluir, ValImprimir);
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
  PermStringValores, ChaveItem : string;
  PermissoesParaSalvar: TArrayOfUserPermissionItem;
  idx, CountAlteradas: Integer;
  NodeTipo: Char; NodeID: Integer;
  PermItemOriginal: TUserPermissionItem;
  OriginalAcesso, OriginalInserir, OriginalAlterar, OriginalExcluir, OriginalImprimir: Boolean;
  EditadoAcesso, EditadoInserir, EditadoAlterar, EditadoExcluir, EditadoImprimir: Boolean;
  EncontrouOriginal, HouveMudanca: Boolean;
begin
  if not FPermissoesModificadas then begin ShowMessage('Nenhuma permissão foi alterada.'); Exit; end;
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then begin ShowMessage('Selecione uma empresa e um usuário.'); Exit; end;

  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);

  if not Assigned(FPermissaoController) then
  begin ShowMessage('Controller não inicializado.'); Exit; end;

  Screen.Cursor := crHourGlass;
  MemoLog.Lines.Add(Format('--- Iniciando salvamento para Usuário ID: %d, Empresa ID: %d ---', [IDUsuario, IDEmpresa]));

  SetLength(PermissoesParaSalvar, 0);
  CountAlteradas := 0;
  PermInfo := TStringList.Create;
  try
    for idx := 0 to FEstadoAtualPermissoesUI.Count - 1 do
    begin
      ChaveItem := FEstadoAtualPermissoesUI.Names[idx];
      PermStringValores := FEstadoAtualPermissoesUI.ValueFromIndex[idx];

      PermInfo.Delimiter := '|'; PermInfo.DelimitedText := PermStringValores;
      if PermInfo.Count = 5 then
      begin
        NodeTipo := ChaveItem[1];
        NodeID   := StrToInt(Copy(ChaveItem, 3, Length(ChaveItem)-2));

        EditadoAcesso   := StrDBToBool(PermInfo[0]);
        EditadoInserir  := StrDBToBool(PermInfo[1]);
        EditadoAlterar  := StrDBToBool(PermInfo[2]);
        EditadoExcluir  := StrDBToBool(PermInfo[3]);
        EditadoImprimir := StrDBToBool(PermInfo[4]);

        OriginalAcesso := False; OriginalInserir := False; OriginalAlterar := False; OriginalExcluir := False; OriginalImprimir := False;
        EncontrouOriginal := False;
        for PermItemOriginal in FPermissoesOriginais do
        begin
          if (PermItemOriginal.ItemID = NodeID) and (PermItemOriginal.ItemTipo = NodeTipo) then
          begin
            OriginalAcesso := PermItemOriginal.Acesso; OriginalInserir := PermItemOriginal.Inserir;
            OriginalAlterar := PermItemOriginal.Alterar; OriginalExcluir := PermItemOriginal.Excluir;
            OriginalImprimir := PermItemOriginal.Imprimir;
            EncontrouOriginal := True;
            Break;
          end;
        end;

        HouveMudanca := (EditadoAcesso <> OriginalAcesso) or
                        (EditadoInserir <> OriginalInserir) or
                        (EditadoAlterar <> OriginalAlterar) or
                        (EditadoExcluir <> OriginalExcluir) or
                        (EditadoImprimir <> OriginalImprimir);

        if not EncontrouOriginal and (EditadoAcesso or EditadoInserir or EditadoAlterar or EditadoExcluir or EditadoImprimir) then
           HouveMudanca := True;

        if HouveMudanca then
        begin
          SetLength(PermissoesParaSalvar, CountAlteradas + 1);
          PermissoesParaSalvar[CountAlteradas].ItemTipo := NodeTipo;
          PermissoesParaSalvar[CountAlteradas].ItemID   := NodeID;
          PermissoesParaSalvar[CountAlteradas].Acesso   := EditadoAcesso;
          PermissoesParaSalvar[CountAlteradas].Inserir  := EditadoInserir;
          PermissoesParaSalvar[CountAlteradas].Alterar  := EditadoAlterar;
          PermissoesParaSalvar[CountAlteradas].Excluir  := EditadoExcluir;
          PermissoesParaSalvar[CountAlteradas].Imprimir := EditadoImprimir;
          Inc(CountAlteradas);
          MemoLog.Lines.Add(Format('ALTERADA: Tipo:%s ID:%d Ac:%s I:%s A:%s E:%s P:%s',
             [NodeTipo, NodeID, PermInfo[0], PermInfo[1], PermInfo[2], PermInfo[3], PermInfo[4]]));
        end;
      end;
    end;

    if Length(PermissoesParaSalvar) > 0 then
    begin
      if FPermissaoController.AtualizarPermissoesEspecificas(IDEmpresa, IDUsuario, PermissoesParaSalvar) then
      begin
        FPermissoesModificadas := False;
        btnSalvarPermissoes.Enabled := False;
        ShowMessage('Permissões alteradas salvas com sucesso.');
        MemoLog.Lines.Add('Permissões alteradas salvas via Controller.');
        btnCarregarPermissoesClick(nil);
      end else
      begin
        ShowMessage('Falha ao salvar permissões alteradas via Controller.');
        MemoLog.Lines.Add('Falha ao salvar permissões alteradas via Controller.');
      end;
    end else
    begin
        ShowMessage('Nenhuma permissão foi efetivamente alterada para salvar.');
        FPermissoesModificadas := False;
        btnSalvarPermissoes.Enabled := False;
    end;

  finally
    PermInfo.Free;
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

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaLimpezaTotal(tvMenu.Items[i]);

  // Atualiza a UI para o nó selecionado após a limpeza de FEstadoAtualPermissoesUI
  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected)
  else
    LimparPermissoesVisuais;

  FPermissoesModificadas := True; btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram desmarcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Limpar Todas clicado.');
end;

procedure TfrmGerenciarPermissoes.btnSelecionarTodasClick(Sender: TObject);
var i: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;

  for i := 0 to tvMenu.Items.Count - 1 do ProcessarNoParaSelecaoTotal(tvMenu.Items[i]);

  // Atualiza a UI para o nó selecionado após FEstadoAtualPermissoesUI ser preenchido
  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);

  FPermissoesModificadas := True; btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram marcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Selecionar Todas clicado.');
end;

initialization
  //
finalization
  //
end.
