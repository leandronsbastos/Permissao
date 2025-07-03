unit uGerenciarPermissoes;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, DBCtrls, DB, ActnList, ImgList;
  // Assumindo que TPermissaoController e TMenuBuilder (ou suas funcionalidades)
  // estarão em uma unidade separada, ex: uPermissaoController
  // uses uPermissaoController;

type
  TItemMenuData = record
    ID: Integer;
    Tipo: Char; // 'M' = Modulo, 'S' = Submodulo, 'R' = Rotina
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
    imgListTreeView: TImageList; // Para ícones no TreeView
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
    FPermissaoController: TObject; // Deveria ser TPermissaoController
    FPermissoesModificadas: Boolean;
    procedure CarregarEmpresas;
    procedure CarregarUsuarios(AIDEmpresa: Integer);
    procedure LimparPermissoesVisuais;
    procedure PopularTreeView;
    procedure AplicarPermissoesAoNo(ANode: TTreeNode; AIDUsuario, AIDEmpresa: Integer);
    procedure AtualizarChecksPermissaoParaNo(ANode: TTreeNode);
    function GetItemMenuData(ANode: TTreeNode): PItemMenuData;
    procedure SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);
    procedure MarcarNoAtualizarLista(ANodeData: PItemMenuData; ACheckedState: Boolean);
    procedure ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
    procedure ProcessarNoParaLimpezaTotal(ANode: TTreeNode); // Declarado aqui


    // Simulação de ClientDataSets (em um projeto real, usar TClientDataSet)
    FEmpresasData: TStringList;
    FUsuariosData: TStringList;
    FMenuEstrutura: TStringList;
    FPermissoesUsuarioAtual: TStringList;

    procedure SimularCargaEmpresas;
    procedure SimularCargaUsuarios(AIDEmpresa: Integer);
    procedure SimularCargaEstruturaMenu;
    procedure SimularCargaPermissoesUsuario(AIDUsuario, AIDEmpresa: Integer);
    procedure SalvarPermissaoParaNo(ANode: TTreeNode; AIDUsuario, AIDEmpresa: Integer);

  public
    { Public declarations }
  end;

var
  frmGerenciarPermissoes: TfrmGerenciarPermissoes;

implementation

{$R *.dfm}

{ TfrmGerenciarPermissoes }

procedure TfrmGerenciarPermissoes.FormCreate(Sender: TObject);
begin
  FPermissoesModificadas := False;
  FEmpresasData := TStringList.Create;
  FUsuariosData := TStringList.Create;
  FMenuEstrutura := TStringList.Create;
  FPermissoesUsuarioAtual := TStringList.Create;
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
  FEmpresasData.Free;
  FUsuariosData.Free;
  FMenuEstrutura.Free;
  FPermissoesUsuarioAtual.Free;
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  if cbEmpresa.Items.Count = 1 then
  begin
    cbEmpresa.ItemIndex := 0;
    cbEmpresaChange(cbEmpresa);
  end;
end;

procedure TfrmGerenciarPermissoes.SimularCargaEmpresas;
begin
  FEmpresasData.Clear;
  FEmpresasData.Add('1|Empresa A');
  FEmpresasData.Add('2|Empresa B');
end;

procedure TfrmGerenciarPermissoes.CarregarEmpresas;
var
  i: Integer;
  EmpresaInfo: TStringList;
begin
  SimularCargaEmpresas;
  cbEmpresa.Items.Clear;
  EmpresaInfo := TStringList.Create;
  try
    for i := 0 to FEmpresasData.Count - 1 do
    begin
      EmpresaInfo.Delimiter := '|';
      EmpresaInfo.DelimitedText := FEmpresasData[i];
      if EmpresaInfo.Count = 2 then
        cbEmpresa.Items.AddObject(EmpresaInfo[1], TObject(StrToInt(EmpresaInfo[0])));
    end;
  finally
    EmpresaInfo.Free;
  end;
  if cbEmpresa.Items.Count > 0 then
    cbEmpresa.ItemIndex := 0;
  cbEmpresaChange(nil);
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

procedure TfrmGerenciarPermissoes.CarregarUsuarios(AIDEmpresa: Integer);
var
  i: Integer;
  UsuarioInfo: TStringList;
begin
  SimularCargaUsuarios(AIDEmpresa);
  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais;
  UsuarioInfo := TStringList.Create;
  try
    for i := 0 to FUsuariosData.Count - 1 do
    begin
      UsuarioInfo.Delimiter := '|';
      UsuarioInfo.DelimitedText := FUsuariosData[i];
      if UsuarioInfo.Count >= 2 then
         cbUsuario.Items.AddObject(UsuarioInfo[1], TObject(StrToInt(UsuarioInfo[0])));
    end;
  finally
    UsuarioInfo.Free;
  end;
  if cbUsuario.Items.Count > 0 then
  begin
    cbUsuario.ItemIndex := 0;
    btnCarregarPermissoes.Enabled := True;
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

procedure TfrmGerenciarPermissoes.SimularCargaEstruturaMenu;
begin
  FMenuEstrutura.Clear;
  FMenuEstrutura.Add('1|M|Cadastro|0|0||1');
  FMenuEstrutura.Add('1|R|Ramo de Atividades|1|0|frmRamoAtividades|1');
  FMenuEstrutura.Add('2|R|Atividade econômica|1|0|frmAtividadeEconomica|2');
  FMenuEstrutura.Add('101|S|Profissionais|1|0||16');
  FMenuEstrutura.Add('3|R|Funcionários-Vendedores-R.C.A|0|101|frmFuncionarios|1');
  FMenuEstrutura.Add('2|M|Clientes|0|0||2');
  FMenuEstrutura.Add('4|R|Clientes|2|0|frmClientes|1');
  FMenuEstrutura.Add('102|S|SPC|2|0||4');
  FMenuEstrutura.Add('5|R|Enviar ou Cancelar|0|102|frmSpcEnviarCancelar|1');
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  i: Integer;
  ItemInfo: TStringList;
  Node, ParentNode: TTreeNode;
  ItemID, ParentModuloID, ParentSubmoduloID, Ordem: Integer;
  ItemTipo: Char;
  ItemNome, NomeForm: string;
  function FindNodeByData(Tree: TTreeView; SearchID: Integer; SearchTipo: Char): TTreeNode;
  var
    k: Integer;
    CurrentNode: TTreeNode;
    DataPtr: PItemMenuData;
    function FindRecursive(StartNode: TTreeNode): TTreeNode;
    var
      j: Integer;
      ChildDataPtr: PItemMenuData;
    begin
      Result := nil;
      if not Assigned(StartNode) then Exit;
      ChildDataPtr := PItemMenuData(StartNode.Data);
      if Assigned(ChildDataPtr) and (ChildDataPtr^.ID = SearchID) and (ChildDataPtr^.Tipo = SearchTipo) then
      begin
        Result := StartNode;
        Exit;
      end;
      for j := 0 to StartNode.Count - 1 do
      begin
        Result := FindRecursive(StartNode.Item[j]);
        if Assigned(Result) then Exit;
      end;
    end;
  begin
    Result := nil;
    for k := 0 to Tree.Items.Count - 1 do
    begin
      CurrentNode := Tree.Items[k];
      DataPtr := PItemMenuData(CurrentNode.Data);
      if Assigned(DataPtr) and (DataPtr^.ID = SearchID) and (DataPtr^.Tipo = SearchTipo) then
      begin
        Result := CurrentNode;
        Exit;
      end;
      Result := FindRecursive(CurrentNode);
      if Assigned(Result) then Exit;
    end;
  end;
begin
  SimularCargaEstruturaMenu;
  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear;
    ItemInfo := TStringList.Create;
    try
      for i := 0 to FMenuEstrutura.Count - 1 do
      begin
        ItemInfo.Delimiter := '|';
        ItemInfo.DelimitedText := FMenuEstrutura[i];
        if ItemInfo.Count = 7 then
        begin
          ItemID := StrToInt(ItemInfo[0]);
          ItemTipo := ItemInfo[1][1];
          ItemNome := ItemInfo[2];
          NomeForm := ItemInfo[5];
          if ItemTipo = 'M' then
          begin
            Node := tvMenu.Items.AddObject(nil, ItemNome, nil);
            SetItemMenuData(Node, ItemID, ItemTipo, NomeForm);
          end;
        end;
      end;
      for i := 0 to FMenuEstrutura.Count - 1 do
      begin
        ItemInfo.Delimiter := '|';
        ItemInfo.DelimitedText := FMenuEstrutura[i];
        if ItemInfo.Count = 7 then
        begin
          ItemID := StrToInt(ItemInfo[0]);
          ItemTipo := ItemInfo[1][1];
          ItemNome := ItemInfo[2];
          ParentModuloID := StrToInt(ItemInfo[3]);
          ParentSubmoduloID := StrToInt(ItemInfo[4]);
          NomeForm := ItemInfo[5];
          ParentNode := nil;
          if ItemTipo = 'S' then
          begin
            if ParentSubmoduloID <> 0 then
              ParentNode := FindNodeByData(tvMenu, ParentSubmoduloID, 'S')
            else if ParentModuloID <> 0 then
              ParentNode := FindNodeByData(tvMenu, ParentModuloID, 'M');
            if Assigned(ParentNode) then
            begin
              Node := tvMenu.Items.AddChildObject(ParentNode, ItemNome, nil);
              SetItemMenuData(Node, ItemID, ItemTipo, NomeForm);
            end;
          end
          else if ItemTipo = 'R' then
          begin
            if ParentSubmoduloID <> 0 then
              ParentNode := FindNodeByData(tvMenu, ParentSubmoduloID, 'S')
            else if ParentModuloID <> 0 then
              ParentNode := FindNodeByData(tvMenu, ParentModuloID, 'M');
            if Assigned(ParentNode) then
            begin
              Node := tvMenu.Items.AddChildObject(ParentNode, ItemNome, nil);
              SetItemMenuData(Node, ItemID, ItemTipo, NomeForm);
            end;
          end;
        end;
      end;
    finally
      ItemInfo.Free;
    end;
  finally
    tvMenu.Items.EndUpdate;
    if tvMenu.Items.Count > 0 then
      tvMenu.Selected := tvMenu.Items[0];
  end;
  btnLimparTodas.Enabled := tvMenu.Items.Count > 0;
  btnSelecionarTodas.Enabled := tvMenu.Items.Count > 0;
end;

procedure TfrmGerenciarPermissoes.SimularCargaPermissoesUsuario(AIDUsuario, AIDEmpresa: Integer);
begin
  FPermissoesUsuarioAtual.Clear;
  if (AIDUsuario = 101) and (AIDEmpresa = 1) then
  begin
    FPermissoesUsuarioAtual.Add('M|1|1|0|0|0|0');
    FPermissoesUsuarioAtual.Add('R|1|1|1|1|0|0');
    FPermissoesUsuarioAtual.Add('S|101|1|0|0|0|0');
    FPermissoesUsuarioAtual.Add('R|3|1|1|1|1|1');
  end;
end;

procedure TfrmGerenciarPermissoes.AplicarPermissoesAoNo(ANode: TTreeNode; AIDUsuario, AIDEmpresa: Integer);
var
  i: Integer;
  PermInfo: TStringList;
  NodeData: PItemMenuData;
  PermItemID: Integer;
  PermItemTipo: Char;
  TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);
  PermInfo := TStringList.Create;
  try
    TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;
    for i := 0 to FPermissoesUsuarioAtual.Count - 1 do
    begin
      PermInfo.Delimiter := '|';
      PermInfo.DelimitedText := FPermissoesUsuarioAtual[i];
      if PermInfo.Count = 7 then
      begin
        PermItemTipo := PermInfo[0][1];
        PermItemID := StrToInt(PermInfo[1]);
        if (NodeData^.ID = PermItemID) and (NodeData^.Tipo = PermItemTipo) then
        begin
          TemAcesso    := PermInfo[2] = '1';
          PodeInserir  := PermInfo[3] = '1';
          PodeAlterar  := PermInfo[4] = '1';
          PodeExcluir  := PermInfo[5] = '1';
          PodeImprimir := PermInfo[6] = '1';
          Break;
        end;
      end;
    end;
    if ANode = tvMenu.Selected then
    begin
      chkAcesso.Checked := TemAcesso;
      gbPermissoesItem.Enabled := True;
      if NodeData^.Tipo = 'R' then
      begin
        chkInserir.Enabled := True; chkInserir.Checked := PodeInserir;
        chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
        chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir;
        chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
      end
      else
      begin
        chkInserir.Enabled := False; chkInserir.Checked := False;
        chkAlterar.Enabled := False; chkAlterar.Checked := False;
        chkExcluir.Enabled := False; chkExcluir.Checked := False;
        chkImprimir.Enabled := False; chkImprimir.Checked := False;
      end;
    end;
  finally
    PermInfo.Free;
  end;
  if ANode.HasChildren then
    for i := 0 to ANode.Count - 1 do
      AplicarPermissoesAoNo(ANode.Item[i], AIDUsuario, AIDEmpresa);
end;

procedure TfrmGerenciarPermissoes.btnCarregarPermissoesClick(Sender: TObject);
var
  IDEmpresa, IDUsuario: Integer;
  i: Integer;
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin
    ShowMessage('Selecione uma empresa e um usuário.');
    Exit;
  end;
  IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);
  IDUsuario := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
  Screen.Cursor := crHourGlass;
  try
    PopularTreeView;
    SimularCargaPermissoesUsuario(IDUsuario, IDEmpresa);
    if tvMenu.Items.Count > 0 then
    begin
       for i := 0 to tvMenu.Items.Count -1 do
          AplicarPermissoesAoNo(tvMenu.Items[i], IDUsuario, IDEmpresa);
       if Assigned(tvMenu.Selected) then
         tvMenuSelectionChanged(tvMenu)
       else if tvMenu.Items.Count > 0 then
       begin
         tvMenu.Selected := tvMenu.Items[0];
       end;
    end
    else
    begin
      LimparPermissoesVisuais;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  FPermissoesModificadas := False;
  btnSalvarPermissoes.Enabled := False;
end;

function TfrmGerenciarPermissoes.GetItemMenuData(ANode: TTreeNode): PItemMenuData;
begin
  Result := nil;
  if Assigned(ANode) and Assigned(ANode.Data) then
    Result := PItemMenuData(ANode.Data);
end;

procedure TfrmGerenciarPermissoes.SetItemMenuData(ANode: TTreeNode; AID: Integer; ATipo: Char; ANomeForm: string);
var
  NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit;
  if Assigned(ANode.Data) then
    FreeMem(ANode.Data);
  New(NodeData);
  NodeData^.ID := AID;
  NodeData^.Tipo := ATipo;
  NodeData^.NomeForm := ANomeForm;
  ANode.Data := NodeData;
end;

procedure TfrmGerenciarPermissoes.AtualizarChecksPermissaoParaNo(ANode: TTreeNode);
var
  NodeData: PItemMenuData;
  i: Integer;
  PermInfo: TStringList;
  PermItemID: Integer;
  PermItemTipo: Char;
  TemAcesso, PodeInserir, PodeAlterar, PodeExcluir, PodeImprimir: Boolean;
begin
  LimparPermissoesVisuais;
  if not Assigned(ANode) then Exit;
  NodeData := GetItemMenuData(ANode);
  if not Assigned(NodeData) then Exit;
  gbPermissoesItem.Enabled := True;
  gbPermissoesItem.Caption := 'Permissões para: ' + ANode.Text;
  TemAcesso := False; PodeInserir := False; PodeAlterar := False; PodeExcluir := False; PodeImprimir := False;
  PermInfo := TStringList.Create;
  try
    for i := 0 to FPermissoesUsuarioAtual.Count - 1 do
    begin
      PermInfo.Delimiter := '|';
      PermInfo.DelimitedText := FPermissoesUsuarioAtual[i];
      if PermInfo.Count = 7 then
      begin
        PermItemTipo := PermInfo[0][1];
        PermItemID := StrToInt(PermInfo[1]);
        if (NodeData^.ID = PermItemID) and (NodeData^.Tipo = PermItemTipo) then
        begin
          TemAcesso    := PermInfo[2] = '1';
          PodeInserir  := PermInfo[3] = '1';
          PodeAlterar  := PermInfo[4] = '1';
          PodeExcluir  := PermInfo[5] = '1';
          PodeImprimir := PermInfo[6] = '1';
          Break;
        end;
      end;
    end;
  finally
    PermInfo.Free;
  end;
  chkAcesso.Checked := TemAcesso;
  if NodeData^.Tipo = 'R' then
  begin
    chkInserir.Enabled := True; chkInserir.Checked := PodeInserir;
    chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
    chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir;
    chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
  end
  else
  begin
    chkInserir.Enabled := False; chkInserir.Checked := False;
    chkAlterar.Enabled := False; chkAlterar.Checked := False;
    chkExcluir.Enabled := False; chkExcluir.Checked := False;
    chkImprimir.Enabled := False; chkImprimir.Checked := False;
  end;
end;

procedure TfrmGerenciarPermissoes.tvMenuSelectionChanged(Sender: TObject);
begin
  if Assigned(tvMenu.Selected) then
  begin
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  end
  else
  begin
    LimparPermissoesVisuais;
  end;
end;

procedure TfrmGerenciarPermissoes.chkPermissaoClick(Sender: TObject);
var
  NodeData: PItemMenuData;
  PermItemID: Integer;
  PermItemTipo: Char;
  i: Integer;
  PermInfo: TStringList;
  Found: Boolean;
  NovaLinhaPermissao: string;
begin
  if not Assigned(tvMenu.Selected) then Exit;
  NodeData := GetItemMenuData(tvMenu.Selected);
  if not Assigned(NodeData) then Exit;
  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
  PermItemID := NodeData^.ID;
  PermItemTipo := NodeData^.Tipo;
  Found := False;
  PermInfo := TStringList.Create;
  try
    for i := 0 to FPermissoesUsuarioAtual.Count - 1 do
    begin
      PermInfo.Delimiter := '|';
      PermInfo.DelimitedText := FPermissoesUsuarioAtual[i];
      if (PermInfo.Count = 7) and (PermInfo[0][1] = PermItemTipo) and (StrToInt(PermInfo[1]) = PermItemID) then
      begin
        PermInfo[2] := IfThen(chkAcesso.Checked, '1', '0');
        if PermItemTipo = 'R' then
        begin
          PermInfo[3] := IfThen(chkInserir.Checked, '1', '0');
          PermInfo[4] := IfThen(chkAlterar.Checked, '1', '0');
          PermInfo[5] := IfThen(chkExcluir.Checked, '1', '0');
          PermInfo[6] := IfThen(chkImprimir.Checked, '1', '0');
        end
        else
        begin
          PermInfo[3] := '0'; PermInfo[4] := '0'; PermInfo[5] := '0'; PermInfo[6] := '0';
        end;
        FPermissoesUsuarioAtual[i] := PermInfo.DelimitedText;
        Found := True;
        Break;
      end;
    end;
    if not Found then
    begin
      NovaLinhaPermissao := PermItemTipo + '|' + IntToStr(PermItemID) + '|' +
                            IfThen(chkAcesso.Checked, '1', '0') + '|' +
                            IfThen(chkInserir.Checked and (PermItemTipo = 'R'), '1', '0') + '|' +
                            IfThen(chkAlterar.Checked and (PermItemTipo = 'R'), '1', '0') + '|' +
                            IfThen(chkExcluir.Checked and (PermItemTipo = 'R'), '1', '0') + '|' +
                            IfThen(chkImprimir.Checked and (PermItemTipo = 'R'), '1', '0');
      FPermissoesUsuarioAtual.Add(NovaLinhaPermissao);
    end;
  finally
    PermInfo.Free;
  end;
end;

procedure TfrmGerenciarPermissoes.SalvarPermissaoParaNo(ANode: TTreeNode; AIDUsuario, AIDEmpresa: Integer);
var
  NodeData: PItemMenuData;
  PermInfo: TStringList;
  i: Integer;
  Found: Boolean;
  Acesso, Inserir, Alterar, Excluir, Imprimir: Boolean;
  PermItemID: Integer;
  PermItemTipo: Char;
begin
  if not Assigned(ANode) or not Assigned(ANode.Data) then Exit;
  NodeData := PItemMenuData(ANode.Data);
  Found := False;
  Acesso := False; Inserir := False; Alterar := False; Excluir := False; Imprimir := False;
  PermInfo := TStringList.Create;
  try
    for i := 0 to FPermissoesUsuarioAtual.Count - 1 do
    begin
      PermInfo.Delimiter := '|';
      PermInfo.DelimitedText := FPermissoesUsuarioAtual[i];
      if PermInfo.Count = 7 then
      begin
        PermItemTipo := PermInfo[0][1];
        PermItemID   := StrToInt(PermInfo[1]);
        if (NodeData^.ID = PermItemID) and (NodeData^.Tipo = PermItemTipo) then
        begin
          Acesso    := PermInfo[2] = '1';
          Inserir   := PermInfo[3] = '1';
          Alterar   := PermInfo[4] = '1';
          Excluir   := PermInfo[5] = '1';
          Imprimir  := PermInfo[6] = '1';
          Found := True;
          Break;
        end;
      end;
    end;
  finally
    PermInfo.Free;
  end;
  if Found then
  begin
    MemoLog.Lines.Add(Format('Controller->Salvar: E:%d U:%d Tipo:%s ID:%d Ac:%s I:%s A:%s E:%s P:%s',
      [AIDEmpresa, AIDUsuario, NodeData^.Tipo, NodeData^.ID,
       BoolToStr(Acesso,True), BoolToStr(Inserir,True), BoolToStr(Alterar,True),
       BoolToStr(Excluir,True), BoolToStr(Imprimir,True)]));
  end;
end;

procedure TfrmGerenciarPermissoes.btnSalvarPermissoesClick(Sender: TObject);
var
  IDEmpresa, IDUsuario: Integer;
  PermInfo: TStringList;
  PermLinha: string;
begin
  if not FPermissoesModificadas then
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
  Screen.Cursor := crHourGlass;
  MemoLog.Lines.Add(Format('--- Iniciando salvamento para Usuário ID: %d, Empresa ID: %d ---', [IDUsuario, IDEmpresa]));
  try
    PermInfo := TStringList.Create;
    try
      for PermLinha in FPermissoesUsuarioAtual do
      begin
        PermInfo.Delimiter := '|';
        PermInfo.DelimitedText := PermLinha;
        if PermInfo.Count = 7 then
        begin
           MemoLog.Lines.Add(Format('Controller->SalvarPermissao: E:%d U:%d Tipo:%s IDItem:%s Ac:%s I:%s A:%s E:%s P:%s',
             [IDEmpresa, IDUsuario, PermInfo[0], PermInfo[1], PermInfo[2], PermInfo[3], PermInfo[4], PermInfo[5], PermInfo[6]]));
        end;
      end;
      MemoLog.Lines.Add('--- Fim do salvamento (simulação) ---');
    finally
      PermInfo.Free;
    end;
    FPermissoesModificadas := False;
    btnSalvarPermissoes.Enabled := False;
    ShowMessage('Permissões salvas com sucesso (simulação - verifique o MemoLog).');
  except
    on E: Exception do
    begin
      ShowMessage('Erro ao salvar permissões: ' + E.Message);
       MemoLog.Lines.Add('Erro ao salvar: ' + E.Message);
    end;
  end;
  Screen.Cursor := crDefault;
end;

procedure TfrmGerenciarPermissoes.btnCopiarPermissoesClick(Sender: TObject);
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin
    ShowMessage('Selecione uma empresa e o usuário de DESTINO primeiro.');
    Exit;
  end;
  ShowMessage('Funcionalidade "Copiar Permissões" a ser implementada com frmSelecionarUsuario.');
  MemoLog.Lines.Add('Botão Copiar Permissões clicado.');
end;

procedure TfrmGerenciarPermissoes.MarcarNoAtualizarLista(ANodeData: PItemMenuData; ACheckedState: Boolean);
var
  idx: Integer;
  tmpPermInfo: TStringList;
  foundInList: Boolean;
  tmpLinha: string;
begin
  if not Assigned(ANodeData) then Exit;
  foundInList := False;
  tmpPermInfo := TStringList.Create;
  try
    for idx := 0 to FPermissoesUsuarioAtual.Count - 1 do
    begin
      tmpPermInfo.Delimiter := '|';
      tmpPermInfo.DelimitedText := FPermissoesUsuarioAtual[idx];
      if (tmpPermInfo.Count = 7) and (tmpPermInfo[0][1] = ANodeData^.Tipo) and (StrToInt(tmpPermInfo[1]) = ANodeData^.ID) then
      begin
        tmpPermInfo[2] := IfThen(ACheckedState, '1', '0');
        if ANodeData^.Tipo = 'R' then
        begin
          tmpPermInfo[3] := IfThen(ACheckedState, '1', '0');
          tmpPermInfo[4] := IfThen(ACheckedState, '1', '0');
          tmpPermInfo[5] := IfThen(ACheckedState, '1', '0');
          tmpPermInfo[6] := IfThen(ACheckedState, '1', '0');
        end
        else
        begin
          tmpPermInfo[3] := '0'; tmpPermInfo[4] := '0'; tmpPermInfo[5] := '0'; tmpPermInfo[6] := '0';
        end;
        FPermissoesUsuarioAtual[idx] := tmpPermInfo.DelimitedText;
        foundInList := True;
        Break;
      end;
    end;
    if not foundInList and ACheckedState then
    begin
      tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                  IfThen(ACheckedState, '1', '0') + '|' +
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0');
      FPermissoesUsuarioAtual.Add(tmpLinha);
    end;
  finally
    tmpPermInfo.Free;
  end;
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaLimpezaTotal(ANode: TTreeNode);
var
  j: Integer;
  NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit;
  NodeData := GetItemMenuData(ANode);
  MarcarNoAtualizarLista(NodeData, False); // False para desmarcar / limpar
  for j := 0 to ANode.Count - 1 do
    ProcessarNoParaLimpezaTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
var
  j: Integer;
  NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit;
  NodeData := GetItemMenuData(ANode);
  MarcarNoAtualizarLista(NodeData, True);
  for j := 0 to ANode.Count - 1 do
    ProcessarNoParaSelecaoTotal(ANode.Item[j]);
end;

procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var
  i: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;
  for i := 0 to tvMenu.Items.Count - 1 do
  begin
    ProcessarNoParaLimpezaTotal(tvMenu.Items[i]);
  end;
  if Assigned(tvMenu.Selected) then
  begin
      AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  end
  else
  begin
    LimparPermissoesVisuais;
  end;
  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram desmarcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Limpar Todas clicado.');
end;

procedure TfrmGerenciarPermissoes.btnSelecionarTodasClick(Sender: TObject);
var
  i: Integer;
begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;
  for i := 0 to tvMenu.Items.Count - 1 do
  begin
    ProcessarNoParaSelecaoTotal(tvMenu.Items[i]);
  end;
  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);
  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram marcadas visualmente. Clique em Salvar para aplicar.');
  MemoLog.Lines.Add('Botão Selecionar Todas clicado.');
end;

initialization
  //
finalization
  //
end.
