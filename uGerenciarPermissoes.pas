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
    MemoLog: TMemo; // Adicionado para o log de exemplo em Salvar
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
    procedure MarcarNoAtualizarLista(ANodeData: PItemMenuData; ACheckedState: Boolean); // Declarado aqui
    procedure ProcessarNoParaSelecaoTotal(ANode: TTreeNode); // Declarado aqui


    // Simulação de ClientDataSets (em um projeto real, usar TClientDataSet)
    FEmpresasData: TStringList; // Formato: "ID|NOME_EMPRESA"
    FUsuariosData: TStringList; // Formato: "ID|NOME|ID_EMPRESA"
    FMenuEstrutura: TStringList; // Formato: "ID|TIPO|NOME|ID_PAI_MOD|ID_PAI_SUB|NOME_FORM|ORDEM" (complexo, simplificar)
                                 // Ou melhor, uma lista de records para estrutura de menu
    FPermissoesUsuarioAtual: TStringList; // Formato: "TIPO_ITEM|ID_ITEM|ACESSO|INSERIR|ALTERAR|EXCLUIR|IMPRIMIR"

    procedure SimularCargaEmpresas; // Método para simular dados sem banco
    procedure SimularCargaUsuarios(AIDEmpresa: Integer); // Método para simular dados
    procedure SimularCargaEstruturaMenu;
    procedure SimularCargaPermissoesUsuario(AIDUsuario, AIDEmpresa: Integer);
    procedure SalvarPermissaoParaNo(ANode: TTreeNode; AIDUsuario, AIDEmpresa: Integer);

  public
    { Public declarations }
  end;

var
  frmGerenciarPermissoes: TfrmGerenciarPermissoes;

implementation

{$R *.dfm} // Assume que o DFM correspondente existe e tem MemoLog

// uses uPermissaoController; // Descomentar quando a unit existir

{ TfrmGerenciarPermissoes }

procedure TfrmGerenciarPermissoes.FormCreate(Sender: TObject);
begin
  // FPermissaoController := TPermissaoController.Create(Self); // Ou similar
  FPermissoesModificadas := False;

  // Inicialização das listas de simulação
  FEmpresasData := TStringList.Create;
  FUsuariosData := TStringList.Create;
  FMenuEstrutura := TStringList.Create;
  FPermissoesUsuarioAtual := TStringList.Create;

  // Configurar TreeView
  tvMenu.ReadOnly := False; // Para permitir checkboxes nos nós, se for usar essa abordagem
  // Se usar checkboxes no TreeView: tvMenu.CheckBoxes := True;

  // Inicialmente desabilitar painel de permissões e botões de ação
  gbPermissoesItem.Enabled := False;
  btnSalvarPermissoes.Enabled := False;
  btnCopiarPermissoes.Enabled := False;
  btnLimparTodas.Enabled := False;
  btnSelecionarTodas.Enabled := False;
  MemoLog.Visible := True; // Para debug
  MemoLog.Clear;
end;

procedure TfrmGerenciarPermissoes.FormDestroy(Sender: TObject);
var
  i: Integer;
  NodeData: PItemMenuData;
begin
  // Liberar dados dos nós do TreeView
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
  // FreeAndNil(FPermissaoController);
end;

procedure TfrmGerenciarPermissoes.FormShow(Sender: TObject);
begin
  CarregarEmpresas;
  // Se houver apenas uma empresa, pode-se carregar usuários automaticamente
  if cbEmpresa.Items.Count = 1 then
  begin
    cbEmpresa.ItemIndex := 0;
    cbEmpresaChange(cbEmpresa); // Dispara o carregamento de usuários
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
  SimularCargaEmpresas; // Substituir pela chamada ao Controller

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
    cbEmpresa.ItemIndex := 0; // Seleciona a primeira por padrão

  cbEmpresaChange(nil); // Para carregar usuários da primeira empresa
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
  SimularCargaUsuarios(AIDEmpresa); // Substituir pela chamada ao Controller

  cbUsuario.Items.Clear;
  tvMenu.Items.Clear;
  LimparPermissoesVisuais;

  UsuarioInfo := TStringList.Create;
  try
    for i := 0 to FUsuariosData.Count - 1 do
    begin
      UsuarioInfo.Delimiter := '|';
      UsuarioInfo.DelimitedText := FUsuariosData[i];
      // UsuarioInfo[2] é ID_EMPRESA, já filtrado na simulação
      if UsuarioInfo.Count >= 2 then
         cbUsuario.Items.AddObject(UsuarioInfo[1], TObject(StrToInt(UsuarioInfo[0])));
    end;
  finally
    UsuarioInfo.Free;
  end;

  if cbUsuario.Items.Count > 0 then
  begin
    cbUsuario.ItemIndex := 0; // Seleciona o primeiro por padrão
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
  // Formato: "ID|TIPO|NOME|ID_PAI_MOD|ID_PAI_SUB|NOME_FORM|ORDEM"
  // TIPO: M=Modulo, S=Submodulo, R=Rotina
  // ID_PAI_MOD: ID do Módulo pai (para Submódulos e Rotinas diretas de Módulo)
  // ID_PAI_SUB: ID do Submódulo pai (para Submódulos aninhados e Rotinas de Submódulo)

  // Modulo Cadastro
  FMenuEstrutura.Add('1|M|Cadastro|0|0||1');
  FMenuEstrutura.Add('1|R|Ramo de Atividades|1|0|frmRamoAtividades|1');
  FMenuEstrutura.Add('2|R|Atividade econômica|1|0|frmAtividadeEconomica|2');
  // Submodulo Profissionais (dentro de Cadastro)
  FMenuEstrutura.Add('101|S|Profissionais|1|0||16'); // ID_SUBMODULO = 101 (evitar conflito com ID de rotina/módulo)
  FMenuEstrutura.Add('3|R|Funcionários-Vendedores-R.C.A|0|101|frmFuncionarios|1'); // Pai é Submódulo 101

  // Modulo Clientes
  FMenuEstrutura.Add('2|M|Clientes|0|0||2');
  FMenuEstrutura.Add('4|R|Clientes|2|0|frmClientes|1');
  // Submodulo SPC (dentro de Clientes)
  FMenuEstrutura.Add('102|S|SPC|2|0||4'); // ID_SUBMODULO = 102
  FMenuEstrutura.Add('5|R|Enviar ou Cancelar|0|102|frmSpcEnviarCancelar|1'); // Pai é Submódulo 102
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  i: Integer;
  ItemInfo: TStringList;
  Node, ParentNode: TTreeNode;
  ItemID, ParentModuloID, ParentSubmoduloID, Ordem: Integer;
  ItemTipo: Char;
  ItemNome, NomeForm: string;
  //NodeData: PItemMenuData; // Não usado diretamente aqui, mas em SetItemMenuData

  // Função auxiliar para encontrar nó no TreeView pelo seu Data (ID e Tipo)
  function FindNodeByData(Tree: TTreeView; SearchID: Integer; SearchTipo: Char): TTreeNode;
  var
    k: Integer;
    CurrentNode: TTreeNode;
    DataPtr: PItemMenuData;
    function FindRecursive(StartNode: TTreeNode): TTreeNode;
    var
      j: Integer;
      ChildNode: TTreeNode;
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
      // Verifica nós raiz primeiro
      DataPtr := PItemMenuData(CurrentNode.Data);
      if Assigned(DataPtr) and (DataPtr^.ID = SearchID) and (DataPtr^.Tipo = SearchTipo) then
      begin
        Result := CurrentNode;
        Exit;
      end;
      // Depois verifica filhos recursivamente
      Result := FindRecursive(CurrentNode);
      if Assigned(Result) then Exit;
    end;
  end;

begin
  SimularCargaEstruturaMenu; // Substituir por chamada ao Controller

  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear; // Limpa dados antigos do TreeView também
    ItemInfo := TStringList.Create;
    try
      // Passagem 1: Adicionar todos os Módulos (nível raiz)
      for i := 0 to FMenuEstrutura.Count - 1 do
      begin
        ItemInfo.Delimiter := '|';
        ItemInfo.DelimitedText := FMenuEstrutura[i];
        if ItemInfo.Count = 7 then
        begin
          ItemID := StrToInt(ItemInfo[0]);
          ItemTipo := ItemInfo[1][1];
          ItemNome := ItemInfo[2];
          // ParentModuloID := StrToInt(ItemInfo[3]);
          // ParentSubmoduloID := StrToInt(ItemInfo[4]);
          NomeForm := ItemInfo[5];
          Ordem := StrToInt(ItemInfo[6]); // Usar para ordenar, se necessário

          if ItemTipo = 'M' then
          begin
            Node := tvMenu.Items.AddObject(nil, ItemNome, nil);
            SetItemMenuData(Node, ItemID, ItemTipo, NomeForm);
            // Node.ImageIndex := ... ; Node.SelectedIndex := ...
          end;
        end;
      end;

      // Passagens subsequentes para popular Submódulos e Rotinas
      // Isso pode precisar de múltiplas passagens ou uma abordagem mais inteligente se a ordem no FMenuEstrutura não for garantida
      // (pais antes dos filhos)
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
          // Ordem := StrToInt(ItemInfo[6]);

          ParentNode := nil;
          if ItemTipo = 'S' then // Submódulo
          begin
            if ParentSubmoduloID <> 0 then // Filho de outro Submódulo
              ParentNode := FindNodeByData(tvMenu, ParentSubmoduloID, 'S')
            else if ParentModuloID <> 0 then // Filho de Módulo
              ParentNode := FindNodeByData(tvMenu, ParentModuloID, 'M');

            if Assigned(ParentNode) then
            begin
              Node := tvMenu.Items.AddChildObject(ParentNode, ItemNome, nil);
              SetItemMenuData(Node, ItemID, ItemTipo, NomeForm);
            end;
          end
          else if ItemTipo = 'R' then // Rotina
          begin
            if ParentSubmoduloID <> 0 then // Filho de Submódulo
              ParentNode := FindNodeByData(tvMenu, ParentSubmoduloID, 'S')
            else if ParentModuloID <> 0 then // Filho de Módulo
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
      tvMenu.Selected := tvMenu.Items[0]; // Seleciona o primeiro item
  end;
  btnLimparTodas.Enabled := tvMenu.Items.Count > 0;
  btnSelecionarTodas.Enabled := tvMenu.Items.Count > 0;
end;

procedure TfrmGerenciarPermissoes.SimularCargaPermissoesUsuario(AIDUsuario, AIDEmpresa: Integer);
begin
  FPermissoesUsuarioAtual.Clear;
  // Formato: "TIPO_ITEM|ID_ITEM|ACESSO|INSERIR|ALTERAR|EXCLUIR|IMPRIMIR"
  // Exemplo: Usuário 101, Empresa 1
  if (AIDUsuario = 101) and (AIDEmpresa = 1) then
  begin
    FPermissoesUsuarioAtual.Add('M|1|1|0|0|0|0'); // Acesso ao Módulo Cadastro
    FPermissoesUsuarioAtual.Add('R|1|1|1|1|0|0'); // Acesso, Inserir, Alterar para Rotina "Ramo de Atividades" (ID 1)
    FPermissoesUsuarioAtual.Add('S|101|1|0|0|0|0'); // Acesso ao Submódulo Profissionais (ID 101)
    FPermissoesUsuarioAtual.Add('R|3|1|1|1|1|1'); // Todas permissões para "Funcionários" (ID 3)
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
          Break; // Encontrou a permissão para este nó
        end;
      end;
    end;

    // Se o nó atual é o selecionado, atualiza os checkboxes no GroupBox
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
      else // Módulo ou Submódulo
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
       for i := 0 to tvMenu.Items.Count -1 do // Para cada nó raiz
          AplicarPermissoesAoNo(tvMenu.Items[i], IDUsuario, IDEmpresa); // Aplica recursivamente

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
        else // Para Módulo ou Submódulo, as permissões granulares são sempre '0' na lista
        begin
          PermInfo[3] := '0';
          PermInfo[4] := '0';
          PermInfo[5] := '0';
          PermInfo[6] := '0';
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
  i: Integer;
  //Node: TTreeNode; // Não usado mais aqui
  //NodeData: PItemMenuData; // Não usado mais aqui
  PermInfo: TStringList;
  PermLinha: string;
  //Acesso, Inserir, Alterar, Excluir, Imprimir: Boolean; // Não usado mais aqui
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
          // Em uma implementação real, chamaria:
          // FPermissaoController.SalvarPermissao(IDEmpresa, IDUsuario, StrToInt(PermInfo[1]), PermInfo[0][1],
          // PermInfo[2]='1', PermInfo[3]='1', PermInfo[4]='1', PermInfo[5]='1', PermInfo[6]='1');
        end;
      end;
      // O ideal aqui seria chamar um método no controller que receba FPermissoesUsuarioAtual
      // e ele resolva o que inserir/atualizar/deletar no banco.
      // Ex: FPermissaoController.SalvarTodasPermissoesUsuario(IDEmpresa, IDUsuario, FPermissoesUsuarioAtual);
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
//var
//  frmSelecionar: TfrmSelecionarUsuario; // Supondo que este formulário exista
//  IDUsuarioOrigem, IDUsuarioDestino, IDEmpresa: Integer;
begin
  if (cbEmpresa.ItemIndex = -1) or (cbUsuario.ItemIndex = -1) then
  begin
    ShowMessage('Selecione uma empresa e o usuário de DESTINO primeiro.');
    Exit;
  end;

  ShowMessage('Funcionalidade "Copiar Permissões" a ser implementada com frmSelecionarUsuario.');
  MemoLog.Lines.Add('Botão Copiar Permissões clicado.');
  // A lógica comentada anteriormente para chamar frmSelecionarUsuario seria ativada aqui.
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
        tmpPermInfo[2] := IfThen(ACheckedState, '1', '0'); // Acesso
        if ANodeData^.Tipo = 'R' then // Para rotinas, marca/desmarca tudo baseado em ACheckedState
        begin
          tmpPermInfo[3] := IfThen(ACheckedState, '1', '0'); // Inserir
          tmpPermInfo[4] := IfThen(ACheckedState, '1', '0'); // Alterar
          tmpPermInfo[5] := IfThen(ACheckedState, '1', '0'); // Excluir
          tmpPermInfo[6] := IfThen(ACheckedState, '1', '0'); // Imprimir
        end
        else // Módulos e Submódulos só têm Acesso, o resto é 0
        begin
          tmpPermInfo[3] := '0'; tmpPermInfo[4] := '0'; tmpPermInfo[5] := '0'; tmpPermInfo[6] := '0';
        end;
        FPermissoesUsuarioAtual[idx] := tmpPermInfo.DelimitedText;
        foundInList := True;
        Break;
      end;
    end;

    if not foundInList and ACheckedState then // Se não achou e estamos marcando, adiciona
    begin
      tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                  IfThen(ACheckedState, '1', '0') + '|' + // Acesso
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' + // Inserir
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' + // Alterar
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' + // Excluir
                  IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0');       // Imprimir
      FPermissoesUsuarioAtual.Add(tmpLinha);
    end
    else if not ACheckedState and foundInList then // Se desmarcando e existe, já foi atualizado para Acesso=0
    begin
      // A lógica atual já ajusta a linha existente para Acesso=0.
      // Se a regra fosse remover a linha se Acesso=0, seria feito aqui.
      // Ex: if not ACheckedState then FPermissoesUsuarioAtual.Delete(idx); (mas precisaria de cuidado com o loop)
    end;
  finally
    tmpPermInfo.Free;
  end;
end;

procedure TfrmGerenciarPermissoes.ProcessarNoParaSelecaoTotal(ANode: TTreeNode);
var
  j: Integer;
  NodeData: PItemMenuData;
begin
  if not Assigned(ANode) then Exit;

  NodeData := GetItemMenuData(ANode);
  MarcarNoAtualizarLista(NodeData, True); // True para selecionar

  // Se usar checkboxes no TreeView diretamente no nó:
  // ANode.Checked := True;

  for j := 0 to ANode.Count - 1 do
    ProcessarNoParaSelecaoTotal(ANode.Item[j]);
end;


procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var
  i: Integer;
  NodeData: PItemMenuData;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;

  // Limpa a lista de permissões em memória, mas de forma a marcar acesso como '0'
  // em vez de remover as linhas, para que o salvamento possa tratar como desativação.
  // Ou, se a lógica de salvar espera apenas as permissões ativas, limpar a lista é correto.
  // A lógica de MarcarNoAtualizarLista com False faz o correto.

  for i := 0 to tvMenu.Items.Count - 1 do // Para cada nó raiz
  begin
    procedure DesmarcarRecursivo(ANode: TTreeNode);
    var k: Integer; CurrentNodeData: PItemMenuData;
    begin
      if not Assigned(ANode) then Exit;
      CurrentNodeData := GetItemMenuData(ANode);
      MarcarNoAtualizarLista(CurrentNodeData, False); // False para desmarcar
      for k := 0 to ANode.Count -1 do
        DesmarcarRecursivo(ANode.Item[k]);
    end;
    DesmarcarRecursivo(tvMenu.Items[i]);
  end;


  // Limpa visualmente os checkboxes do item selecionado
  if Assigned(tvMenu.Selected) then
  begin
      AtualizarChecksPermissaoParaNo(tvMenu.Selected); // Re-lê da FPermissoesUsuarioAtual
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
