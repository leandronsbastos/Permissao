unit uPermissaoController;

interface

uses
  SysUtils, Classes, DB, ADODB; // Ou qualquer outra unit de acesso a dados (e.g., FireDAC.Comp.Client)

type
  // Estrutura para retornar os itens de menu para o TreeView
  TMenuItemStructure = record
    ID: Integer;
    Tipo: Char; // 'M'odulo, 'S'ubmodulo, 'R'otina
    Nome: string;
    IDPaiModulo: Integer;    // ID do Módulo pai (se Tipo='S' ou 'R' e pai é Módulo)
    IDPaiSubmodulo: Integer; // ID do Submódulo pai (se Tipo='S' ou 'R' e pai é Submódulo)
    NomeForm: string;
    OrdemExibicao: Integer;
  end;
  TArrayOfMenuItemStructure = array of TMenuItemStructure;

  // Estrutura para as permissões de um usuário para um item específico
  TUserPermissionItem = record
    ItemID: Integer;
    ItemTipo: Char; // M, S, R
    Acesso: Boolean;
    Inserir: Boolean;
    Alterar: Boolean;
    Excluir: Boolean;
    Imprimir: Boolean;
  end;
  TArrayOfUserPermissionItem = array of TUserPermissionItem;

  TPermissaoController = class
  private
    FADOConnection: TADOConnection; // Exemplo com ADO, substitua pelo seu componente de conexão
    FDataPath: string; // Caminho para o banco de dados (ex: Access MDB) ou string de conexão

    // Procedimentos internos para executar queries
    function QueryToRecords(SQL: string; var ARecords: TArrayOfMenuItemStructure): Boolean; overload;
    function QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean; overload;
    function ExecuteSQL(SQL: string): Boolean;

    // Funções auxiliares para construir as queries de forma segura (evitar SQL Injection)
    function QuotedStrDB(const S: string): string;
    function GetConnectionString: string;

  public
    constructor Create(ADataPath: string); // Ou recebe TADOConnection configurado
    destructor Destroy; override;

    // Métodos principais conforme o plano
    function CarregarEstruturaMenu(var AMenuEstrutura: TArrayOfMenuItemStructure): Boolean;
    function CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfUserPermissionItem): Boolean;

    // Salvar permissões: Pode ser uma lista de todas as permissões ou uma por uma.
    // Para simplificar, vamos assumir que recebe a lista completa do estado desejado.
    // O controller fará o diff com o banco ou limpará e inserirá.
    function SalvarTodasPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoes: TArrayOfUserPermissionItem): Boolean;

    function CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean;
    function ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; ANomeForm: string; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean; overload;
    function ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; AItemID: Integer; AItemTipo: Char; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean; overload;

    // Funções para popular ComboBoxes (exemplo)
    function CarregarEmpresas(var EmpresasList: TStrings): Boolean; // Formato: "ID|Nome"
    function CarregarUsuariosPorEmpresa(AIDEmpresa: Integer; var UsuariosList: TStrings): Boolean; // Formato: "ID|Nome"
  end;

implementation

uses Variants; // Para VarToStrDef e outros

{ TPermissaoController }

constructor TPermissaoController.Create(ADataPath: string);
begin
  inherited Create;
  FDataPath := ADataPath; // Pode ser o caminho de um MDB ou uma string de conexão completa
  FADOConnection := TADOConnection.Create(nil);
  // FADOConnection.LoginPrompt := False; // Desabilitar prompt de login
  // Configurar a conexão aqui ou usar uma existente
  // Exemplo para Access:
  // FADOConnection.ConnectionString := 'Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + FDataPath + ';Persist Security Info=False;';
  // Para outros bancos, a ConnectionString será diferente.
end;

destructor TPermissaoController.Destroy;
begin
  if Assigned(FADOConnection) then
  begin
    if FADOConnection.Connected then
      FADOConnection.Connected := False;
    FreeAndNil(FADOConnection);
  end;
  inherited Destroy;
end;

function TPermissaoController.GetConnectionString: string;
begin
  // Esta função pode ser mais elaborada para buscar de um arquivo .ini, registro, etc.
  // Por agora, um exemplo simples para MS Access.
  // ATENÇÃO: Substitua pelo seu provedor e caminho corretos.
  // Para Delphi 7, 'Microsoft.Jet.OLEDB.4.0' é mais comum para MDBs antigos.
  // 'Microsoft.ACE.OLEDB.12.0' ou 'Microsoft.ACE.OLEDB.16.0' para accdb ou se o Access Database Engine estiver instalado.
  Result := 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=' + FDataPath + ';Persist Security Info=False;';
  // Exemplo SQL Server:
  // Result := 'Provider=SQLOLEDB;Data Source=NOMESERVIDOR;Initial Catalog=NOMEBANCO;User ID=usuario;Password=senha;';
end;


function TPermissaoController.QuotedStrDB(const S: string): string;
begin
  // Simples substituição de apóstrofo para evitar SQL Injection básico.
  // Para segurança robusta, usar parâmetros em queries é o ideal.
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function TPermissaoController.ExecuteSQL(SQL: string): Boolean;
var
  ADOCommand: TADOCommand;
begin
  Result := False;
  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString; // Garante que a string de conexão está definida
    FADOConnection.Connected := True;

  if FADOConnection.Connected then
  begin
    ADOCommand := TADOCommand.Create(nil);
    try
      ADOCommand.Connection := FADOConnection;
      ADOCommand.CommandText := SQL;
      ADOCommand.Execute;
      Result := True;
    except
      on E: Exception do
      begin
        // Logar erro E.Message
        Result := False;
      end;
    end;
    FreeAndNil(ADOCommand);
  end;
end;


function TPermissaoController.QueryToRecords(SQL: string; var ARecords: TArrayOfMenuItemStructure): Boolean;
var
  ADODataSet: TADODataSet;
  i: Integer;
begin
  Result := False;
  SetLength(ARecords, 0);

  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;

  if FADOConnection.Connected then
  begin
    ADODataSet := TADODataSet.Create(nil);
    try
      ADODataSet.Connection := FADOConnection;
      ADODataSet.CommandText := SQL;
      ADODataSet.Open;
      if not ADODataSet.IsEmpty then
      begin
        SetLength(ARecords, ADODataSet.RecordCount);
        i := 0;
        ADODataSet.First;
        while not ADODataSet.Eof do
        begin
          with ARecords[i] do
          begin
            // Os nomes dos campos devem corresponder aos da sua query SQL
            ID := ADODataSet.FieldByName('ITEM_ID').AsInteger; // Nome genérico, ajustar
            Tipo := ADODataSet.FieldByName('ITEM_TIPO').AsString[1]; // 'M', 'S', 'R'
            Nome := ADODataSet.FieldByName('ITEM_NOME').AsString;
            IDPaiModulo := ADODataSet.FieldByName('ID_MODULO_ASSOCIADO').AsInteger; // Ou similar
            IDPaiSubmodulo := ADODataSet.FieldByName('ID_SUBMODULO_PAI').AsInteger; // Ou similar
            NomeForm := VarToStrDef(ADODataSet.FieldByName('NOME_FORM').Value, '');
            OrdemExibicao := ADODataSet.FieldByName('ORDEM_EXIBICAO').AsInteger;
          end;
          Inc(i);
          ADODataSet.Next;
        end;
        Result := True;
      end
      else
      begin
        Result := True; // Query executada, mas sem resultados
      end;
    except
      on E: Exception do
      begin
        // Logar erro E.Message
        SetLength(ARecords, 0);
        Result := False;
      end;
    end;
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean;
var
  ADODataSet: TADODataSet;
  i: Integer;
begin
  Result := False;
  SetLength(APermissions, 0);

  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;

  if FADOConnection.Connected then
  begin
    ADODataSet := TADODataSet.Create(nil);
    try
      ADODataSet.Connection := FADOConnection;
      ADODataSet.CommandText := SQL;
      ADODataSet.Open;
      if not ADODataSet.IsEmpty then
      begin
        SetLength(APermissions, ADODataSet.RecordCount);
        i := 0;
        ADODataSet.First;
        while not ADODataSet.Eof do
        begin
          with APermissions[i] do
          begin
            // Determinar ItemID e ItemTipo baseado em qual FK está preenchida
            if not ADODataSet.FieldByName('ID_MODULO_PERMITIDO').IsNull then
            begin
              ItemID := ADODataSet.FieldByName('ID_MODULO_PERMITIDO').AsInteger;
              ItemTipo := 'M';
            end
            else if not ADODataSet.FieldByName('ID_SUBMODULO_PERMITIDO').IsNull then
            begin
              ItemID := ADODataSet.FieldByName('ID_SUBMODULO_PERMITIDO').AsInteger;
              ItemTipo := 'S';
            end
            else if not ADODataSet.FieldByName('ID_ROTINA_PERMITIDA').IsNull then
            begin
              ItemID := ADODataSet.FieldByName('ID_ROTINA_PERMITIDA').AsInteger;
              ItemTipo := 'R';
            end
            else
            begin
              // Registro inválido na tabela PERMISSAO_USUARIO, pular
              ADODataSet.Next;
              Continue;
            end;

            Acesso    := ADODataSet.FieldByName('ACESSO').AsBoolean;
            Inserir   := ADODataSet.FieldByName('P_INSERIR').AsBoolean;
            Alterar   := ADODataSet.FieldByName('P_ALTERAR').AsBoolean;
            Excluir   := ADODataSet.FieldByName('P_EXCLUIR').AsBoolean;
            Imprimir  := ADODataSet.FieldByName('P_IMPRIMIR').AsBoolean;
          end;
          Inc(i);
          ADODataSet.Next;
        end;
        // Ajustar o tamanho do array se algum registro foi pulado
        SetLength(APermissions, i);
        Result := True;
      end
      else
      begin
        Result := True; // Query executada, mas sem resultados (sem permissões)
      end;
    except
      on E: Exception do
      begin
        // Logar erro E.Message
        SetLength(APermissions, 0);
        Result := False;
      end;
    end;
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.CarregarEstruturaMenu(var AMenuEstrutura: TArrayOfMenuItemStructure): Boolean;
var
  SQL: string;
begin
  // Query para buscar todos os Módulos, Submódulos e Rotinas
  // A query precisa trazer campos que permitam reconstruir a hierarquia.
  // Exemplo UNION (pode ser complexo dependendo do SGBD e otimizações):
  SQL := 'SELECT ID_MODULO AS ITEM_ID, ''M'' AS ITEM_TIPO, NOME_MODULO AS ITEM_NOME, ' +
         'NULL AS ID_MODULO_ASSOCIADO, NULL AS ID_SUBMODULO_PAI, NULL AS NOME_FORM, ORDEM_EXIBICAO ' +
         'FROM MODULO ' +
         'UNION ALL ' +
         'SELECT ID_SUBMODULO AS ITEM_ID, ''S'' AS ITEM_TIPO, NOME_SUBMODULO AS ITEM_NOME, ' +
         'ID_MODULO_ASSOCIADO, ID_SUBMODULO_PAI, NULL AS NOME_FORM, ORDEM_EXIBICAO ' +
         'FROM SUBMODULO ' +
         'UNION ALL ' +
         'SELECT ID_ROTINA AS ITEM_ID, ''R'' AS ITEM_TIPO, NOME_ROTINA AS ITEM_NOME, ' +
         'ID_MODULO_ASSOCIADO, ID_SUBMODULO_ASSOCIADO AS ID_SUBMODULO_PAI, NOME_FORM, ORDEM_EXIBICAO ' +
         'FROM ROTINA ' +
         'ORDER BY ORDEM_EXIBICAO, ITEM_NOME'; // A ordenação aqui é global, precisa ser refinada para hierarquia

  // Uma abordagem mais simples pode ser carregar cada tipo separadamente e montar a hierarquia na aplicação.
  // Para este exemplo, a query acima é conceitual.
  // A lógica de reconstrução da árvore no form precisará lidar com os IDs pai.

  // Log de SQL (para debug)
  // ShowMessage(SQL);

  Result := QueryToRecords(SQL, AMenuEstrutura);
end;

function TPermissaoController.CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfUserPermissionItem): Boolean;
var
  SQL: string;
begin
  SQL := Format('SELECT ID_MODULO_PERMITIDO, ID_SUBMODULO_PERMITIDO, ID_ROTINA_PERMITIDA, ' +
                'ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR ' +
                'FROM PERMISSAO_USUARIO ' +
                'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d', [AIDEmpresa, AIDUsuario]);
  Result := QueryToUserPermissions(SQL, APermissoes);
end;

function TPermissaoController.SalvarTodasPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoes: TArrayOfUserPermissionItem): Boolean;
var
  i: Integer;
  SQL_Delete, SQL_Insert: string;
  PermItem: TUserPermissionItem;
  ModuloFK, SubmoduloFK, RotinaFK: string;
begin
  Result := False;
  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;

  if not FADOConnection.Connected then Exit;

  // Iniciar transação
  FADOConnection.BeginTrans;
  try
    // 1. Deletar permissões existentes para este usuário/empresa
    SQL_Delete := Format('DELETE FROM PERMISSAO_USUARIO WHERE ID_EMPRESA = %d AND ID_USUARIO = %d',
                         [AIDEmpresa, AIDUsuario]);
    ExecuteSQL(SQL_Delete); // Erros dentro de ExecuteSQL não param a transação aqui, idealmente ExecuteSQL retornaria boolean

    // 2. Inserir as novas permissões da lista
    for PermItem in AListaPermissoes do
    begin
      // Só insere se tiver Acesso = True, ou conforme regra de negócio
      // if not PermItem.Acesso then Continue; // Exemplo: não salvar se não tem acesso

      ModuloFK := 'NULL'; SubmoduloFK := 'NULL'; RotinaFK := 'NULL';
      case PermItem.ItemTipo of
        'M': ModuloFK := IntToStr(PermItem.ItemID);
        'S': SubmoduloFK := IntToStr(PermItem.ItemID);
        'R': RotinaFK := IntToStr(PermItem.ItemID);
      end;

      SQL_Insert := Format(
        'INSERT INTO PERMISSAO_USUARIO (ID_EMPRESA, ID_USUARIO, ID_MODULO_PERMITIDO, ID_SUBMODULO_PERMITIDO, ID_ROTINA_PERMITIDA, ' +
        'ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR) ' +
        'VALUES (%d, %d, %s, %s, %s, %s, %s, %s, %s, %s)',
        [AIDEmpresa, AIDUsuario, ModuloFK, SubmoduloFK, RotinaFK,
         IfThen(PermItem.Acesso, '1', '0'),   // Adapte para True/False ou 1/0 do seu SGBD
         IfThen(PermItem.Inserir, '1', '0'),
         IfThen(PermItem.Alterar, '1', '0'),
         IfThen(PermItem.Excluir, '1', '0'),
         IfThen(PermItem.Imprimir, '1', '0')]);
      if not ExecuteSQL(SQL_Insert) then
      begin
        FADOConnection.RollbackTrans;
        Exit; // Falha ao inserir
      end;
    end;

    FADOConnection.CommitTrans;
    Result := True;
  except
    on E: Exception do
    begin
      FADOConnection.RollbackTrans;
      // Logar erro E.Message
      Result := False;
    end;
  end;
end;

function TPermissaoController.CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean;
var
  PermissoesOrigem: TArrayOfUserPermissionItem;
begin
  Result := False;
  // 1. Carregar permissões do usuário de origem
  if CarregarPermissoesUsuario(AIDEmpresa, AIDUsuarioOrigem, PermissoesOrigem) then
  begin
    // 2. Salvar essas permissões para o usuário de destino
    //    A função SalvarTodasPermissoesUsuario já lida com limpar as antigas do destino.
    Result := SalvarTodasPermissoesUsuario(AIDEmpresa, AIDUsuarioDestino, PermissoesOrigem);
  end;
end;

function TPermissaoController.ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; ANomeForm: string; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
  IsAdmin: Boolean;
begin
  Result := False; // Acesso negado por padrão
  PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;

  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;
  if not FADOConnection.Connected then Exit;

  // 1. Verificar se o usuário é Administrador (tem acesso a tudo)
  ADODataSet := TADODataSet.Create(nil);
  try
    SQL := Format('SELECT ADMINISTRADOR FROM USUARIO WHERE ID_USUARIO = %d AND ID_EMPRESA = %d AND ATIVO = True',
                  [AIDUsuario, AIDEmpresa]);
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    IsAdmin := False;
    if not ADODataSet.IsEmpty then
      IsAdmin := ADODataSet.FieldByName('ADMINISTRADOR').AsBoolean;
    ADODataSet.Close;

    if IsAdmin then
    begin
      Result := True; PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      Exit;
    end;

    // 2. Se não for admin, verificar permissão específica para a rotina (NOME_FORM)
    SQL := Format(
      'SELECT PU.ACESSO, PU.P_INSERIR, PU.P_ALTERAR, PU.P_EXCLUIR, PU.P_IMPRIMIR ' +
      'FROM PERMISSAO_USUARIO PU ' +
      'INNER JOIN ROTINA R ON PU.ID_ROTINA_PERMITIDA = R.ID_ROTINA ' +
      'WHERE PU.ID_EMPRESA = %d AND PU.ID_USUARIO = %d AND R.NOME_FORM = %s AND PU.ACESSO = True',
      [AIDEmpresa, AIDUsuario, QuotedStrDB(ANomeForm)]);

    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      Result     := ADODataSet.FieldByName('ACESSO').AsBoolean; // Deveria ser True pela query
      PInserir   := ADODataSet.FieldByName('P_INSERIR').AsBoolean;
      PAlterar   := ADODataSet.FieldByName('P_ALTERAR').AsBoolean;
      PExcluir   := ADODataSet.FieldByName('P_EXCLUIR').AsBoolean;
      PImprimir  := ADODataSet.FieldByName('P_IMPRIMIR').AsBoolean;
    end;
  finally
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; AItemID: Integer; AItemTipo: Char; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
  IsAdmin: Boolean;
  CampoItemFK: string;
begin
  Result := False; // Acesso negado por padrão
  PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;

  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;
  if not FADOConnection.Connected then Exit;

  // 1. Verificar se o usuário é Administrador
  ADODataSet := TADODataSet.Create(nil);
  try
    SQL := Format('SELECT ADMINISTRADOR FROM USUARIO WHERE ID_USUARIO = %d AND ID_EMPRESA = %d AND ATIVO = True',
                  [AIDUsuario, AIDEmpresa]);
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    IsAdmin := False;
    if not ADODataSet.IsEmpty then
      IsAdmin := ADODataSet.FieldByName('ADMINISTRADOR').AsBoolean;
    ADODataSet.Close;

    if IsAdmin then
    begin
      Result := True; PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      Exit;
    end;

    // 2. Se não for admin, verificar permissão específica para o item
    case AItemTipo of
      'M': CampoItemFK := 'ID_MODULO_PERMITIDO';
      'S': CampoItemFK := 'ID_SUBMODULO_PERMITIDO';
      'R': CampoItemFK := 'ID_ROTINA_PERMITIDA';
      else Exit; // Tipo de item inválido
    end;

    SQL := Format(
      'SELECT ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR ' +
      'FROM PERMISSAO_USUARIO ' +
      'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s = %d AND ACESSO = True',
      [AIDEmpresa, AIDUsuario, CampoItemFK, AItemID]);

    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      Result     := ADODataSet.FieldByName('ACESSO').AsBoolean;
      if AItemTipo = 'R' then // Permissões granulares só para rotinas
      begin
        PInserir   := ADODataSet.FieldByName('P_INSERIR').AsBoolean;
        PAlterar   := ADODataSet.FieldByName('P_ALTERAR').AsBoolean;
        PExcluir   := ADODataSet.FieldByName('P_EXCLUIR').AsBoolean;
        PImprimir  := ADODataSet.FieldByName('P_IMPRIMIR').AsBoolean;
      end;
    end;
  finally
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.CarregarEmpresas(var EmpresasList: TStrings): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
begin
  Result := False;
  EmpresasList.Clear;
  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;
  if not FADOConnection.Connected then Exit;

  SQL := 'SELECT ID_EMPRESA, NOME_EMPRESA FROM EMPRESA WHERE ATIVO = True ORDER BY NOME_EMPRESA';
  ADODataSet := TADODataSet.Create(nil);
  try
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    while not ADODataSet.Eof do
    begin
      // Adiciona no formato "Nome Empresa" com ID_EMPRESA como Object
      EmpresasList.AddObject(ADODataSet.FieldByName('NOME_EMPRESA').AsString,
                             TObject(ADODataSet.FieldByName('ID_EMPRESA').AsInteger));
      ADODataSet.Next;
    end;
    Result := True;
  except
    on E:Exception do
    begin
      // Log E.Message
      Result := False;
    end;
  end;
  FreeAndNil(ADODataSet);
end;

function TPermissaoController.CarregarUsuariosPorEmpresa(AIDEmpresa: Integer; var UsuariosList: TStrings): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
begin
  Result := False;
  UsuariosList.Clear;

  if not FADOConnection.Connected then
    FADOConnection.ConnectionString := GetConnectionString;
    FADOConnection.Connected := True;
  if not FADOConnection.Connected then Exit;

  SQL := Format('SELECT ID_USUARIO, NOME FROM USUARIO WHERE ID_EMPRESA = %d AND ATIVO = True ORDER BY NOME', [AIDEmpresa]);
  ADODataSet := TADODataSet.Create(nil);
  try
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    while not ADODataSet.Eof do
    begin
      UsuariosList.AddObject(ADODataSet.FieldByName('NOME').AsString,
                             TObject(ADODataSet.FieldByName('ID_USUARIO').AsInteger));
      ADODataSet.Next;
    end;
    Result := True;
  except
    on E:Exception do
    begin
      // Log E.Message
      Result := False;
    end;
  end;
  FreeAndNil(ADODataSet);
end;

end.
