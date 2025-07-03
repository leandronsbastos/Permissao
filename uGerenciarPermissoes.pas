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

    // Simulação de ClientDataSets (em um projeto real, usar TClientDataSet)
    FEmpresasData: TStringList; // Formato: "ID|NOME_EMPRESA"
    FUsuariosData: TStringList; // Formato: "ID|NOME|ID_EMPRESA"
    FMenuEstrutura: TStringList; // Formato: "ID|TIPO|NOME|ID_PAI|TIPO_PAI|NOME_FORM|ORDEM" (complexo, simplificar)
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

{$R *.dfm}

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
  FMenuEstrutura.Add('1|S|Profissionais|1|0||16'); // ID_SUBMODULO = 1
  FMenuEstrutura.Add('3|R|Funcionários-Vendedores-R.C.A|0|1|frmFuncionarios|1'); // Pai é Submódulo 1

  // Modulo Clientes
  FMenuEstrutura.Add('2|M|Clientes|0|0||2');
  FMenuEstrutura.Add('4|R|Clientes|2|0|frmClientes|1');
  // Submodulo SPC (dentro de Clientes)
  FMenuEstrutura.Add('2|S|SPC|2|0||4'); // ID_SUBMODULO = 2
  FMenuEstrutura.Add('5|R|Enviar ou Cancelar|0|2|frmSpcEnviarCancelar|1'); // Pai é Submódulo 2
end;

procedure TfrmGerenciarPermissoes.PopularTreeView;
var
  i: Integer;
  ItemInfo: TStringList;
  Node, ParentNode: TTreeNode;
  ItemID, ParentModuloID, ParentSubmoduloID, Ordem: Integer;
  ItemTipo: Char;
  ItemNome, NomeForm: string;
  NodeData: PItemMenuData;

  procedure AddNode(AParentNode: TTreeNode; AItemID: Integer; AItemTipo: Char; AItemNome, ANomeForm: string; AOrdem: Integer);
  var
    NewNode: TTreeNode;
    NewNodeData: PItemMenuData;
  begin
    NewNode := tvMenu.Items.AddChildObject(AParentNode, AItemNome, nil);
    NewNodeData := AllocMem(SizeOf(TItemMenuData));
    NewNodeData^.ID := AItemID;
    NewNodeData^.Tipo := AItemTipo;
    NewNodeData^.NomeForm := ANomeForm;
    NewNode.Data := NewNodeData;
    // Aqui você pode definir o ícone baseado no ItemTipo usando imgListTreeView
    // NewNode.ImageIndex := ...; NewNode.SelectedIndex := ...;
  end;

begin
  SimularCargaEstruturaMenu; // Substituir por chamada ao Controller

  tvMenu.Items.BeginUpdate;
  try
    tvMenu.Items.Clear;
    ItemInfo := TStringList.Create;
    try
      // Primeira passagem para Módulos (pais diretos)
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
          Ordem := StrToInt(ItemInfo[6]); // Usar para ordenar, se necessário

          if ItemTipo = 'M' then
          begin
            AddNode(nil, ItemID, ItemTipo, ItemNome, NomeForm, Ordem);
          end;
        end;
      end;

      // Passagens subsequentes para Submódulos e Rotinas
      // Esta é uma forma simplificada. Uma abordagem recursiva ou com múltiplas passagens
      // seria mais robusta para hierarquias complexas.
      // Para este exemplo, vamos popular de forma simples baseado no ID_PAI_MOD e ID_PAI_SUB

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
          Ordem := StrToInt(ItemInfo[6]);

          ParentNode := nil;
          if ItemTipo = 'S' then // Submódulo
          begin
            if ParentSubmoduloID <> 0 then // Aninhado em outro Submódulo
            begin
              // Encontrar nó do Submódulo Pai
              // Esta busca é ineficiente, idealmente ter um mapa de IDs para Treenodes
              for Node in tvMenu.Items do
                if Assigned(Node.Data) and (PItemMenuData(Node.Data)^.Tipo = 'S') and (PItemMenuData(Node.Data)^.ID = ParentSubmoduloID) then
                begin
                  ParentNode := Node;
                  Break;
                end;
            end
            else if ParentModuloID <> 0 then // Aninhado em um Módulo
            begin
              // Encontrar nó do Módulo Pai
              for Node in tvMenu.Items do
                if Assigned(Node.Data) and (PItemMenuData(Node.Data)^.Tipo = 'M') and (PItemMenuData(Node.Data)^.ID = ParentModuloID) then
                begin
                  ParentNode := Node;
                  Break;
                end;
            end;
            if Assigned(ParentNode) or (ParentModuloID <> 0 AND ParentNode = nil) then // Adiciona ao módulo se pai submódulo não encontrado mas deveria
                 AddNode(ParentNode, ItemID, ItemTipo, ItemNome, NomeForm, Ordem);

          end
          else if ItemTipo = 'R' then // Rotina
          begin
            if ParentSubmoduloID <> 0 then // Rotina de Submódulo
            begin
               for Node in tvMenu.Items do // Precisa iterar em todos os nós, incluindo filhos
                 if Assigned(Node.Data) and (PItemMenuData(Node.Data)^.Tipo = 'S') and (PItemMenuData(Node.Data)^.ID = ParentSubmoduloID) then
                 begin
                   ParentNode := Node;
                   Break;
                 end;
            end
            else if ParentModuloID <> 0 then // Rotina de Módulo
            begin
               for Node in tvMenu.Items do
                 if Assigned(Node.Data) and (PItemMenuData(Node.Data)^.Tipo = 'M') and (PItemMenuData(Node.Data)^.ID = ParentModuloID) then
                 begin
                   ParentNode := Node;
                   Break;
                 end;
            end;
            if Assigned(ParentNode) then
                 AddNode(ParentNode, ItemID, ItemTipo, ItemNome, NomeForm, Ordem);
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
    FPermissoesUsuarioAtual.Add('S|1|1|0|0|0|0'); // Acesso ao Submódulo Profissionais (ID 1)
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

    // Se for usar checkboxes no TreeView para acesso rápido:
    // ANode.Checked := TemAcesso;

    // Se o nó atual é o selecionado, atualiza os checkboxes no GroupBox
    if ANode = tvMenu.Selected then
    begin
      chkAcesso.Checked := TemAcesso;
      // Habilita/desabilita e marca permissões granulares
      // Apenas Rotinas têm permissões granulares efetivas neste modelo
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

  // Recursivamente para os filhos
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
    PopularTreeView; // Carrega/Atualiza a estrutura do menu
    SimularCargaPermissoesUsuario(IDUsuario, IDEmpresa); // Carrega as permissões do usuário

    // Itera pelos nós e aplica as permissões (ex: marcando checkboxes no treeview se usar)
    // Ou apenas armazena para consulta quando um nó é selecionado.
    // Para este exemplo, vamos chamar AplicarPermissoesAoNo para o nó selecionado e seus filhos.
    if tvMenu.Items.Count > 0 then
    begin
       // Aplicar a todos os nós para o caso de checkboxes no treeview
       for i := 0 to tvMenu.Items.Count -1 do
          AplicarPermissoesAoNo(tvMenu.Items[i], IDUsuario, IDEmpresa);

       if Assigned(tvMenu.Selected) then
         tvMenuSelectionChanged(tvMenu) // Força atualização dos checkboxes detalhados
       else if tvMenu.Items.Count > 0 then
       begin
         tvMenu.Selected := tvMenu.Items[0]; // tvMenuSelectionChanged será chamado
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
  if Assigned(ANode.Data) then // Libera memória antiga se houver
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

  // Busca a permissão na lista FPermissoesUsuarioAtual
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

  if NodeData^.Tipo = 'R' then // Rotinas têm permissões granulares
  begin
    chkInserir.Enabled := True; chkInserir.Checked := PodeInserir;
    chkAlterar.Enabled := True; chkAlterar.Checked := PodeAlterar;
    chkExcluir.Enabled := True; chkExcluir.Checked := PodeExcluir;
    chkImprimir.Enabled := True; chkImprimir.Checked := PodeImprimir;
  end
  else // Módulos e Submódulos apenas 'Acesso'
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

  // Atualiza FPermissoesUsuarioAtual
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
        end;
        FPermissoesUsuarioAtual[i] := PermInfo.DelimitedText;
        Found := True;
        Break;
      end;
    end;

    if not Found then // Adiciona nova entrada de permissão
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

  // Lógica de hierarquia (opcional, pode ser complexa)
  // Ex: Se desmarcar acesso de um módulo, desmarcar de todos os filhos.
  // if (Sender = chkAcesso) and (not chkAcesso.Checked) and (NodeData^.Tipo <> 'R') then
  // begin
  //   procedure DesmarcarFilhos(AParentNode: TTreeNode);
  //   var childIdx: Integer; childNodeData: PItemMenuData;
  //   begin
  //     for childIdx := 0 to AParentNode.Count -1 do
  //     begin
  //        // ... lógica para encontrar e atualizar FPermissoesUsuarioAtual para filhos
  //        DesmarcarFilhos(AParentNode.Item[childIdx]);
  //     end;
  //   end;
  //   DesmarcarFilhos(tvMenu.Selected);
  //   AtualizarChecksPermissaoParaNo(tvMenu.Selected); // Re-atualiza visualização
  // end;
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

  // Encontra a permissão correspondente em FPermissoesUsuarioAtual
  // (já deve estar atualizada pelo chkPermissaoClick)
  // Aqui seria a chamada ao FPermissaoController.SalvarPermissao(
  //   AIDEmpresa, AIDUsuario, NodeData^.ID, NodeData^.Tipo,
  //   chkAcesso.Checked, chkInserir.Checked, ... );

  // Simulação: Apenas mostra que salvaria
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

  if Found or chkAcesso.Checked then // Salva se encontrou ou se tem acesso marcado (para novos)
  begin
    // Esta condição Found acima pode ser só Found se FPermissoesUsuarioAtual refletir o estado dos checks.
    // Se FPermissoesUsuarioAtual só tem o que veio do banco, e os checks são o estado "sujo",
    // então usa-se o estado dos checks para salvar.
    // A lógica atual em chkPermissaoClick já atualiza FPermissoesUsuarioAtual.

    // Log simulação
    // ShowMessage(Format('Salvando: Usuário %d, Empresa %d, Item %s (%s - %d), Acesso: %s, Ins: %s, Alt: %s, Exc: %s, Imp: %s',
    //  [AIDUsuario, AIDEmpresa, ANode.Text, NodeData^.Tipo, NodeData^.ID,
    //   BoolToStr(Acesso,True), BoolToStr(Inserir,True), BoolToStr(Alterar,True),
    //   BoolToStr(Excluir,True), BoolToStr(Imprimir,True)]));
  end
  else
  begin
    // Se não encontrou e não tem acesso, significa que a permissão deve ser removida (ou nunca existiu)
    // FPermissaoController.RemoverPermissao(...)
    // Log simulação
    // ShowMessage(Format('Removendo/Ignorando: Usuário %d, Empresa %d, Item %s (%s - %d)',
    //  [AIDUsuario, AIDEmpresa, ANode.Text, NodeData^.Tipo, NodeData^.ID]));
  end;

  // Salvar recursivamente para filhos (se a lógica de salvar permissões for por nó individualmente)
  // if ANode.HasChildren then
  //   for i := 0 to ANode.Count - 1 do
  //     SalvarPermissaoParaNo(ANode.Item[i], AIDUsuario, AIDEmpresa);
end;

procedure TfrmGerenciarPermissoes.btnSalvarPermissoesClick(Sender: TObject);
var
  IDEmpresa, IDUsuario: Integer;
  i: Integer;
  Node: TTreeNode;
  NodeData: PItemMenuData;
  PermInfo: TStringList;
  PermLinha: string;
  Acesso, Inserir, Alterar, Excluir, Imprimir: Boolean;
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
  try
    // Aqui, o FPermissaoController.SalvarTodasPermissoesUsuario(IDUsuario, IDEmpresa, FPermissoesUsuarioAtual)
    // seria chamado, passando a lista completa de permissões como está em FPermissoesUsuarioAtual.
    // O controller se encarregaria de comparar com o banco, inserir, atualizar ou deletar.

    // Simulação:
    ShowMessage(Format('Iniciando salvamento para Usuário ID: %d, Empresa ID: %d', [IDUsuario, IDEmpresa]));
    PermInfo := TStringList.Create;
    try
      for PermLinha in FPermissoesUsuarioAtual do
      begin
        PermInfo.Delimiter := '|';
        PermInfo.DelimitedText := PermLinha;
        if PermInfo.Count = 7 then
        begin
          // Chamar o controller para salvar esta permissão específica
          // FPermissaoController.SalvarPermissao(IDEmpresa, IDUsuario, StrToInt(PermInfo[1]), PermInfo[0][1],
          // PermInfo[2]='1', PermInfo[3]='1', PermInfo[4]='1', PermInfo[5]='1', PermInfo[6]='1');
           MemoLog.Lines.Add(Format('Controller->Salvar: E:%d U:%d Tipo:%s ID:%s Ac:%s I:%s A:%s E:%s P:%s',
             [IDEmpresa, IDUsuario, PermInfo[0], PermInfo[1], PermInfo[2], PermInfo[3], PermInfo[4], PermInfo[5], PermInfo[6]]));
        end;
      end;
      // Após salvar, o controller também precisaria lidar com permissões que foram removidas
      // (ou seja, existem no banco mas não mais em FPermissoesUsuarioAtual com Acesso=true)
      // Isso geralmente é feito limpando as permissões antigas e inserindo as novas,
      // ou por uma lógica de diff mais complexa.
    finally
      PermInfo.Free;
    end;

    FPermissoesModificadas := False;
    btnSalvarPermissoes.Enabled := False;
    ShowMessage('Permissões salvas com sucesso (simulação).');
  except
    on E: Exception do
    begin
      ShowMessage('Erro ao salvar permissões: ' + E.Message);
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

  //IDUsuarioDestino := Integer(cbUsuario.Items.Objects[cbUsuario.ItemIndex]);
  //IDEmpresa := Integer(cbEmpresa.Items.Objects[cbEmpresa.ItemIndex]);

  //frmSelecionar := TfrmSelecionarUsuario.Create(Self);
  //try
  //  frmSelecionar.CarregarUsuariosParaCopia(IDEmpresa, IDUsuarioDestino);
  //  if frmSelecionar.ShowModal = mrOk then
  //  begin
  //    IDUsuarioOrigem := frmSelecionar.IDUsuarioSelecionado;
  //    if IDUsuarioOrigem > 0 then
  //    begin
  //      if MessageDlg(Format('Copiar todas as permissões do usuário %s para o usuário %s?',
  //                           [frmSelecionar.NomeUsuarioSelecionado, cbUsuario.Text]),
  //                    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  //      begin
  //        Screen.Cursor := crHourGlass;
  //        try
  //          // FPermissaoController.CopiarPermissoes(IDEmpresa, IDUsuarioOrigem, IDUsuarioDestino);
  //          ShowMessage('Permissões copiadas com sucesso (simulação). Recarregue as permissões do usuário destino.');
  //          FPermissoesModificadas := True; // Força recarga ou marca como sujo
  //          btnCarregarPermissoesClick(nil); // Recarrega
  //        finally
  //          Screen.Cursor := crDefault;
  //        end;
  //      end;
  //    end;
  //  end;
  //finally
  //  frmSelecionar.Free;
  //end;
  ShowMessage('Funcionalidade "Copiar Permissões" a ser implementada com frmSelecionarUsuario.');
end;

procedure TfrmGerenciarPermissoes.btnLimparTodasClick(Sender: TObject);
var
  i: Integer;
  Node: TTreeNode;
  NodeData: PItemMenuData;
  PermInfo: TStringList;
  PermItemID: Integer;
  PermItemTipo: Char;
begin
  if tvMenu.Items.Count = 0 then Exit;
  if MessageDlg('Deseja realmente limpar TODAS as permissões para o usuário selecionado (apenas visualmente)?'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;

  FPermissoesUsuarioAtual.Clear; // Limpa a lista de permissões em memória

  // Limpa visualmente os checkboxes do item selecionado
  LimparPermissoesVisuais;
  if Assigned(tvMenu.Selected) then
  begin
      chkAcesso.Checked := False;
      chkInserir.Checked := False;
      chkAlterar.Checked := False;
      chkExcluir.Checked := False;
      chkImprimir.Checked := False;
      // Se o item selecionado for Módulo/Submódulo, desabilitar os checks granulares
      NodeData := GetItemMenuData(tvMenu.Selected);
      if Assigned(NodeData) and (NodeData^.Tipo <> 'R') then
      begin
        chkInserir.Enabled := False;
        chkAlterar.Enabled := False;
        chkExcluir.Enabled := False;
        chkImprimir.Enabled := False;
      end;
  end;


  // Se usar checkboxes no TreeView, desmarcar todos
  // for i := 0 to tvMenu.Items.Count - 1 do
  //   tvMenu.Items[i].Checked := False; // E recursivamente para filhos

  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram desmarcadas visualmente. Clique em Salvar para aplicar.');
end;

procedure TfrmGerenciarPermissoes.btnSelecionarTodasClick(Sender: TObject);
var
  i, k: Integer;
  Node: TTreeNode;
  NodeData: PItemMenuData;
  PermInfo: TStringList;
  NovaLinhaPermissao: string;
  PermItemID: Integer;
  PermItemTipo: Char;
  Found: Boolean;

  procedure MarcarNoAtualizarLista(ANodeData: PItemMenuData; ACheckedState: Boolean);
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
          if ANodeData^.Tipo = 'R' then // Para rotinas, marca tudo
          begin
            tmpPermInfo[3] := IfThen(ACheckedState, '1', '0'); // Inserir
            tmpPermInfo[4] := IfThen(ACheckedState, '1', '0'); // Alterar
            tmpPermInfo[5] := IfThen(ACheckedState, '1', '0'); // Excluir
            tmpPermInfo[6] := IfThen(ACheckedState, '1', '0'); // Imprimir
          end;
          FPermissoesUsuarioAtual[idx] := tmpPermInfo.DelimitedText;
          foundInList := True;
          Break;
        end;
      end;

      if not foundInList and ACheckedState then
      begin
        tmpLinha := ANodeData^.Tipo + '|' + IntToStr(ANodeData^.ID) + '|' +
                    IfThen(ACheckedState, '1', '0') + '|' + // Acesso
                    IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                    IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                    IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0') + '|' +
                    IfThen(ACheckedState and (ANodeData^.Tipo = 'R'), '1', '0');
        FPermissoesUsuarioAtual.Add(tmpLinha);
      end
      else if not ACheckedState and foundInList then // Se desmarcando e existe, remover da lista (ou marcar acesso como 0)
      begin
         // A lógica atual de chkPermissaoClick já ajusta para 0, então não precisa remover.
         // Se a regra fosse remover se Acesso=0, faria aqui.
      end;

    finally
      tmpPermInfo.Free;
    end;
  end;

begin
  if tvMenu.Items.Count = 0 then Exit;
   if MessageDlg('Deseja realmente marcar TODAS as permissões de ACESSO para o usuário selecionado (apenas visualmente)?'+
                #13#10'Para Rotinas, todas as sub-permissões também serão marcadas.'+
                #13#10'As alterações só serão efetivadas ao Salvar.', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;

  // Itera por todos os nós do TreeView e seus filhos
  for i := 0 to tvMenu.Items.Count - 1 do
  begin
    procedure ProcessarNo(ANode: TTreeNode);
    var
      j: Integer;
      ChildNodeData: PItemMenuData;
    begin
      ChildNodeData := GetItemMenuData(ANode);
      MarcarNoAtualizarLista(ChildNodeData, True);
      // Se usar checkboxes no TreeView: ANode.Checked := True;
      for j := 0 to ANode.Count - 1 do
        ProcessarNo(ANode.Item[j]);
    end;
    ProcessarNo(tvMenu.Items[i]);
  end;

  // Atualiza visualmente os checkboxes do item atualmente selecionado
  if Assigned(tvMenu.Selected) then
    AtualizarChecksPermissaoParaNo(tvMenu.Selected);

  FPermissoesModificadas := True;
  btnSalvarPermissoes.Enabled := True;
  ShowMessage('Todas as permissões foram marcadas visualmente. Clique em Salvar para aplicar.');
end;

initialization
  // Registrar a classe TItemMenuData para que possa ser usada com TTreeNode.Data
  // Não é estritamente necessário para Pointers, mas boa prática se fosse um objeto.

finalization
  //

end.
