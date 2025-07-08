unit uPermissaoController;

interface

uses
  SysUtils, Classes, DB, ADODB, Variants;

type
  TMenuItemStructure = record
    ID: Integer;
    Tipo: Char;
    Nome: string;
    IDPaiModulo: Integer;
    IDPaiSubmodulo: Integer;
    NomeForm: string;
    OrdemExibicao: Integer;
  end;
  PMenuItemStructure = ^TMenuItemStructure;
  TArrayOfMenuItemStructure = array of TMenuItemStructure;

  // TUserPermissionItem = record // Estrutura Antiga - REMOVIDA
  //   ItemID: Integer;
  //   ItemTipo: Char;
  //   Acesso: Boolean;
  //   Inserir: Boolean;
  //   Alterar: Boolean;
  //   Excluir: Boolean;
  //   Imprimir: Boolean;
  // end;
  // PUserPermissionItem = ^TUserPermissionItem; // Antigo
  // TArrayOfUserPermissionItem = array of TUserPermissionItem; // Antigo

  TSingleUserPermission = record
    ItemID: Integer;
    ItemTipo: Char;
    NomePermissao: string;
    Valor: Boolean;
  end;
  TArrayOfSingleUserPermission = array of TSingleUserPermission;

  TPermissaoController = class
  private
    FADOConnection: TADOConnection;
    FConnectionString: string;

    function QueryToRecords(SQL: string; var ARecords: TArrayOfMenuItemStructure): Boolean; overload;
    // function QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean; overload; // Antigo - REMOVIDO
    function QueryToSingleUserPermissions(SQL: string; var APermissions: TArrayOfSingleUserPermission): Boolean; // Novo
    function ExecuteSQL(SQL: string; out FilasAfetadas: Integer): Boolean; overload; // Modificado para retornar FilasAfetadas
    function ExecuteSQL(SQL: string): Boolean; overload; // Mantido para compatibilidade onde FilasAfetadas não é necessário

    function QuotedStrDB(const S: string): string;
    function BoolToCharSN(Value: Boolean): Char;
    function CharSNToBool(Value: Char): Boolean;
    function GetFieldAsBoolean(DataSet: TDataSet; const FieldName: string): Boolean;
    function BoolToDBInt(Value: Boolean): Integer;

  public
    constructor Create(const AConnString: string); overload;
    constructor Create(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean = False); overload;
    destructor Destroy; override;

    procedure SetSQLServerConnectionParameters(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean = False);
    function TestConnection: Boolean;

    function CarregarEstruturaMenu(var AMenuEstrutura: TArrayOfMenuItemStructure): Boolean;
    // function CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfUserPermissionItem): Boolean; // Assinatura Antiga
    function CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfSingleUserPermission): Boolean; // Nova Assinatura
    // function AtualizarPermissoesEspecificas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfUserPermissionItem): Boolean; // Assinatura Antiga
    function SalvarPermissoesAlteradas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfSingleUserPermission): Boolean; // Nova Assinatura e Nome
    function CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean;

    function PopularPermissoesDefaultParaUsuario(AIDEmpresa, AIDUsuario: Integer): Boolean;
    function PopularPermissoesDefaultParaNovoItemMenu(AItemID: Integer; AItemTipo: Char; ANomeFormParaRotina: string): Boolean;


    function ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; ANomeForm: string; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean; overload;
    function ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; AItemID: Integer; AItemTipo: Char; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean; overload;

    function CarregarEmpresas(var EmpresasList: TStringList): Boolean;
    function CarregarUsuariosPorEmpresa(AIDEmpresa: Integer; var UsuariosList: TStringList): Boolean;
  end;

implementation

{ TPermissaoController }

constructor TPermissaoController.Create(const AConnString: string);
begin
  inherited Create;
  FConnectionString := AConnString;
  FADOConnection := TADOConnection.Create(nil);
  FADOConnection.LoginPrompt := False;
end;

constructor TPermissaoController.Create(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean = False);
begin
  inherited Create;
  FADOConnection := TADOConnection.Create(nil);
  FADOConnection.LoginPrompt := False;
  SetSQLServerConnectionParameters(AServer, ADatabase, AUser, APassword, AIntegratedSecurity);
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

procedure TPermissaoController.SetSQLServerConnectionParameters(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean);
begin
  if AIntegratedSecurity then
    FConnectionString := Format('Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;Initial Catalog=%s;Data Source=%s',
                              [ADatabase, AServer])
  else
    FConnectionString := Format('Provider=SQLOLEDB.1;Password=%s;Persist Security Info=True;User ID=%s;Initial Catalog=%s;Data Source=%s',
                              [APassword, AUser, ADatabase, AServer]);
  if Assigned(FADOConnection) and FADOConnection.Connected then
    FADOConnection.Connected := False;
end;

function TPermissaoController.TestConnection: Boolean;
begin
  Result := False;
  try
    if Assigned(FADOConnection) and FADOConnection.Connected then
      FADOConnection.Connected := False;

    if FConnectionString = '' then Exit;

    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
    Result := FADOConnection.Connected;
  except
    Result := False;
  end;
end;


function TPermissaoController.QuotedStrDB(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function TPermissaoController.BoolToDBInt(Value: Boolean): Integer;
begin
  Result := Ord(Value);
end;

function TPermissaoController.BoolToCharSN(Value: Boolean): Char;
begin
  if Value then Result := 'S' else Result := 'N';
end;

function TPermissaoController.CharSNToBool(Value: Char): Boolean;
begin
  Result := UpCase(Value) = 'S';
end;

function TPermissaoController.GetFieldAsBoolean(DataSet: TDataSet; const FieldName: string): Boolean;
begin
  // Try to get as Integer first (0 or 1)
  try
    Result := DataSet.FieldByName(FieldName).AsInteger = 1;
    Exit;
  except
    // If not an integer, try as String ('S' or 'N', or '0' or '1')
    try
      Result := CharSNToBool(DataSet.FieldByName(FieldName).AsString[1]);
    except
      Result := False; // Default to false if conversion fails
    end;
  end;
end;

function TPermissaoController.ExecuteSQL(SQL: string; out FilasAfetadas: Integer): Boolean;
var
  ADOCommand: TADOCommand;
  RecordsAffected: OleVariant; // Para ExecuteOptions com eoExecuteNoRecords
begin
  Result := False;
  FilasAfetadas := 0;
  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;

  if FADOConnection.Connected then
  begin
    ADOCommand := TADOCommand.Create(nil);
    try
      ADOCommand.Connection := FADOConnection;
      ADOCommand.CommandText := SQL;
      // Para INSERT, UPDATE, DELETE, é melhor usar Execute com eoExecuteNoRecords
      // e pegar o número de linhas afetadas diretamente.
      // O método Execute padrão retorna um Recordset se a query for um SELECT.
      // Para DML, o Recordset retornado pode ser nil ou fechado.
      // A propriedade RowsAffected do TADOConnection é mais confiável após um ExecuteSQL
      // ou usando o parâmetro RecordsAffected do método Execute.
      ADOCommand.Execute(RecordsAffected); // RecordsAffected receberá o número de linhas
      if VarIsType(RecordsAffected, varInteger) or VarIsType(RecordsAffected, varSmallint) then // Adicionado varSmallint
         FilasAfetadas := RecordsAffected
      else if FADOConnection.RecordsAffected > -1 then // Fallback se RecordsAffected não for numérico
         FilasAfetadas := FADOConnection.RecordsAffected
      else
         FilasAfetadas := 0; // Ou 1 se a execução foi bem sucedida mas não retornou contagem

      Result := True; // Se não houve exceção, consideramos sucesso
    except
      on E: Exception do
      begin
        Result := False;
        // Adicionar log de erro aqui seria útil
      end;
    end;
    FreeAndNil(ADOCommand);
  end;
end;

// Sobrecarga para manter compatibilidade com chamadas existentes que não precisam de FilasAfetadas
function TPermissaoController.ExecuteSQL(SQL: string): Boolean;
var
  DummyFilasAfetadas: Integer;
begin
  Result := ExecuteSQL(SQL, DummyFilasAfetadas);
end;

function TPermissaoController.QueryToRecords(SQL: string; var ARecords: TArrayOfMenuItemStructure): Boolean;
var
  ADODataSet: TADODataSet;
  i: Integer;
begin
  Result := False;
  SetLength(ARecords, 0);

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;

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
            ID := ADODataSet.FieldByName('ITEM_ID').AsInteger;
            Tipo := ADODataSet.FieldByName('ITEM_TIPO').AsString[1];
            Nome := ADODataSet.FieldByName('ITEM_NOME').AsString;
            if ADODataSet.FieldByName('ID_MODULO_ASSOCIADO').IsNull then IDPaiModulo := 0
            else IDPaiModulo := ADODataSet.FieldByName('ID_MODULO_ASSOCIADO').AsInteger;

            if ADODataSet.FieldByName('ID_SUBMODULO_PAI').IsNull then IDPaiSubmodulo := 0
            else IDPaiSubmodulo := ADODataSet.FieldByName('ID_SUBMODULO_PAI').AsInteger;

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
        Result := True;
      end;
    except
      on E: Exception do
      begin
        SetLength(ARecords, 0);
        Result := False;
      end;
    end;
    FreeAndNil(ADODataSet);
  end;
end;

// Antiga QueryToUserPermissions - REMOVIDA
// function TPermissaoController.QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean;
// ... corpo da função removida ...

function TPermissaoController.QueryToSingleUserPermissions(SQL: string; var APermissions: TArrayOfSingleUserPermission): Boolean;
var
  ADODataSet: TADODataSet;
  i: Integer;
  ValItemID: Integer;
  ValItemTipo: Char;
  ValNomePermissao: string;
  ValValorPermissao: Char;
begin
  Result := False;
  SetLength(APermissions, 0);

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;

  if FADOConnection.Connected then
  begin
    ADODataSet := TADODataSet.Create(nil);
    try
      ADODataSet.Connection := FADOConnection;
      ADODataSet.CommandText := SQL;
      ADODataSet.Open;
      if not ADODataSet.IsEmpty then
      begin
        SetLength(APermissions, ADODataSet.RecordCount); // Alocação inicial, pode ser ajustada
        i := 0;
        ADODataSet.First;
        while not ADODataSet.Eof do
        begin
          ValItemID := 0;
          ValItemTipo := #0;

          if not ADODataSet.FieldByName('ID_MODULO_REF').IsNull then
          begin
            ValItemID := ADODataSet.FieldByName('ID_MODULO_REF').AsInteger;
            ValItemTipo := 'M';
          end
          else if not ADODataSet.FieldByName('ID_SUBMODULO_REF').IsNull then
          begin
            ValItemID := ADODataSet.FieldByName('ID_SUBMODULO_REF').AsInteger;
            ValItemTipo := 'S';
          end
          else if not ADODataSet.FieldByName('ID_ROTINA_REF').IsNull then
          begin
            ValItemID := ADODataSet.FieldByName('ID_ROTINA_REF').AsInteger;
            ValItemTipo := 'R';
          end
          else
          begin
            // Registro inválido ou inesperado na tabela PERMISSAO_USUARIO
            // Poderia logar um aviso aqui
            ADODataSet.Next;
            Continue; // Pula para o próximo registro
          end;

          ValNomePermissao := ADODataSet.FieldByName('NOME_PERMISSAO').AsString;
          ValValorPermissao := ADODataSet.FieldByName('VALOR_PERMISSAO').AsString[1]; // Pega o primeiro caracter

          // Adiciona ao array apenas se o tipo de item foi determinado
          if (ValItemTipo <> #0) and (ValNomePermissao <> '') then
          begin
            APermissions[i].ItemID := ValItemID;
            APermissions[i].ItemTipo := ValItemTipo;
            APermissions[i].NomePermissao := ValNomePermissao;
            APermissions[i].Valor := CharSNToBool(ValValorPermissao);
            Inc(i);
          end;
          ADODataSet.Next;
        end;
        SetLength(APermissions, i); // Ajusta o tamanho final do array
        Result := True;
      end
      else // DataSet vazio, o que é um resultado válido (nenhuma permissão explícita)
      begin
        Result := True;
      end;
    except
      on E: Exception do
      begin
        SetLength(APermissions, 0);
        Result := False;
        // Adicionar log de erro aqui seria útil
      end;
    end;
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.CarregarEstruturaMenu(var AMenuEstrutura: TArrayOfMenuItemStructure): Boolean;
var
  SQL: string;
begin
  SQL :=
    'SELECT ID_MODULO AS ITEM_ID, ''M'' AS ITEM_TIPO, NOME_MODULO AS ITEM_NOME, ' +
    '   CAST(NULL AS INT) AS ID_MODULO_ASSOCIADO, CAST(NULL AS INT) AS ID_SUBMODULO_PAI, CAST(NULL AS VARCHAR(100)) AS NOME_FORM, ORDEM_EXIBICAO ' + // SQL Server specific NULL typing
    'FROM MODULO ' +
    'UNION ALL ' +
    'SELECT ID_SUBMODULO AS ITEM_ID, ''S'' AS ITEM_TIPO, NOME_SUBMODULO AS ITEM_NOME, ' +
    '   ID_MODULO_ASSOCIADO, ID_SUBMODULO_PAI, CAST(NULL AS VARCHAR(100)) AS NOME_FORM, ORDEM_EXIBICAO ' +
    'FROM SUBMODULO ' +
    'UNION ALL ' +
    'SELECT ID_ROTINA AS ITEM_ID, ''R'' AS ITEM_TIPO, NOME_ROTINA AS ITEM_NOME, ' +
    '   ID_MODULO_ASSOCIADO, ID_SUBMODULO_ASSOCIADO AS ID_SUBMODULO_PAI, NOME_FORM, ORDEM_EXIBICAO ' +
    'FROM ROTINA ' +
    'ORDER BY ITEM_TIPO, ORDEM_EXIBICAO, ITEM_NOME';
  Result := QueryToRecords(SQL, AMenuEstrutura);
end;

// function TPermissaoController.CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfUserPermissionItem): Boolean; // Assinatura Antiga
function TPermissaoController.CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfSingleUserPermission): Boolean; // Nova Assinatura
var
  SQL: string;
begin
  // A nova tabela PERMISSAO_USUARIO tem colunas:
  // ID_PERMISSAO_USUARIO (PK), ID_EMPRESA, ID_USUARIO, ID_MODULO_REF, ID_SUBMODULO_REF, ID_ROTINA_REF, NOME_PERMISSAO, VALOR_PERMISSAO
  SQL := Format(
    'SELECT ID_MODULO_REF, ID_SUBMODULO_REF, ID_ROTINA_REF, NOME_PERMISSAO, VALOR_PERMISSAO ' +
    'FROM PERMISSAO_USUARIO ' +
    'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d',
    [AIDEmpresa, AIDUsuario]
  );
  Result := QueryToSingleUserPermissions(SQL, APermissoes); // Nova Chamada
end;

// function TPermissaoController.AtualizarPermissoesEspecificas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfUserPermissionItem): Boolean; // Assinatura Antiga
function TPermissaoController.SalvarPermissoesAlteradas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfSingleUserPermission): Boolean; // Nova Assinatura e Nome
var
  PermItem: TSingleUserPermission;
  SQL_Update, SQL_Insert: string;
  ItemRefFieldPK, ItemRefValuePK: string;
  RowsAffectedUpdate, RowsAffectedInsert: Integer;
  ValorCharSN: Char;
  ColModulo, ColSubmodulo, ColRotina: string;
begin
  Result := False;
  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  FADOConnection.BeginTrans;
  try
    for PermItem in AListaPermissoesAlteradas do
    begin
      ItemRefFieldPK := ''; ItemRefValuePK := IntToStr(PermItem.ItemID);
      ValorCharSN := BoolToCharSN(PermItem.Valor);

      ColModulo    := 'NULL'; ColSubmodulo := 'NULL'; ColRotina    := 'NULL';
      case PermItem.ItemTipo of
        'M': begin ItemRefFieldPK := 'ID_MODULO_REF';    ColModulo    := ItemRefValuePK; end;
        'S': begin ItemRefFieldPK := 'ID_SUBMODULO_REF'; ColSubmodulo := ItemRefValuePK; end;
        'R': begin ItemRefFieldPK := 'ID_ROTINA_REF';    ColRotina    := ItemRefValuePK; end;
      else
        Continue; // Tipo de item inválido
      end;

      SQL_Update := Format(
        'UPDATE PERMISSAO_USUARIO SET VALOR_PERMISSAO = %s ' +
        'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s = %s AND NOME_PERMISSAO = %s',
        [QuotedStrDB(String(ValorCharSN)), AIDEmpresa, AIDUsuario, ItemRefFieldPK, ItemRefValuePK, QuotedStrDB(PermItem.NomePermissao)]
      );

      if not ExecuteSQL(SQL_Update, RowsAffectedUpdate) then
      begin
        FADOConnection.RollbackTrans;
        Exit;
      end;

      if (RowsAffectedUpdate = 0) and (PermItem.Valor = True) then // Apenas insere se for para 'S' e não existia
      begin
        SQL_Insert := Format(
          'INSERT INTO PERMISSAO_USUARIO (ID_EMPRESA, ID_USUARIO, ID_MODULO_REF, ID_SUBMODULO_REF, ID_ROTINA_REF, NOME_PERMISSAO, VALOR_PERMISSAO) ' +
          'VALUES (%d, %d, %s, %s, %s, %s, %s)',
          [AIDEmpresa, AIDUsuario,
           ColModulo, ColSubmodulo, ColRotina, // Valores corretos para as colunas FK
           QuotedStrDB(PermItem.NomePermissao), QuotedStrDB(String(ValorCharSN))]
        );

        if not ExecuteSQL(SQL_Insert, RowsAffectedInsert) then
        begin
          FADOConnection.RollbackTrans;
          Exit;
        end;
      end;
    end;
    FADOConnection.CommitTrans;
    Result := True;
  except
    on E: Exception do
    begin
      FADOConnection.RollbackTrans;
      Result := False;
      // Adicionar log de erro aqui seria útil
    end;
  end;
end;

function TPermissaoController.CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean;
var
  PermissoesOrigem: TArrayOfSingleUserPermission;
  PermissoesParaSalvarDestino: TArrayOfSingleUserPermission;
  PermItemOrigem: TSingleUserPermission;
  SQL_LimparDestino: string;
  DummyRowsAffected: Integer;
begin
  Result := False;
  if not CarregarPermissoesUsuario(AIDEmpresa, AIDUsuarioOrigem, PermissoesOrigem) then
  begin
    Exit;
  end;

  SetLength(PermissoesParaSalvarDestino, 0);
  for PermItemOrigem in PermissoesOrigem do
  begin
    if PermItemOrigem.Valor then // Copiar apenas as permissões que são 'S' (True)
    begin
      SetLength(PermissoesParaSalvarDestino, Length(PermissoesParaSalvarDestino) + 1);
      PermissoesParaSalvarDestino[High(PermissoesParaSalvarDestino)] := PermItemOrigem;
    end;
  end;

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  FADOConnection.BeginTrans;
  try
    SQL_LimparDestino := Format(
      'UPDATE PERMISSAO_USUARIO SET VALOR_PERMISSAO = ''N'' ' +
      'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d',
      [AIDEmpresa, AIDUsuarioDestino]
    );
    if not ExecuteSQL(SQL_LimparDestino, DummyRowsAffected) then
    begin
      FADOConnection.RollbackTrans;
      Exit;
    end;

    if Length(PermissoesParaSalvarDestino) > 0 then
    begin
      // Reutiliza a lógica de SalvarPermissoesAlteradas, mas dentro da transação atual.
      // Para isso, SalvarPermissoesAlteradas não deve gerenciar sua própria transação
      // ou deve ser capaz de detectar uma transação existente.
      // ASSUMINDO que SalvarPermissoesAlteradas foi modificada para não criar transação se já houver uma.
      // Se SalvarPermissoesAlteradas ainda comita/rollbacka, esta transação pode ser problemática.
      // A melhor abordagem seria passar a conexão/transação para SalvarPermissoesAlteradas ou
      // replicar a lógica de insert/update aqui.
      // Para este exemplo, vamos assumir que podemos chamar SalvarPermissoesAlteradas
      // e se ela falhar, esta transação será rollbackada pela exceção.

      // Como SalvarPermissoesAlteradas já tem sua própria transação,
      // é mais seguro replicar a lógica de UPSERT aqui para garantir uma única transação.
      var
        PermItem: TSingleUserPermission;
        SQL_Update, SQL_Insert: string;
        ItemRefFieldPK, ItemRefValuePK: string;
        RowsAffectedUpdate, RowsAffectedInsert: Integer;
        ValorCharSN: Char;
        ColModulo, ColSubmodulo, ColRotina: string;
      begin
        for PermItem in PermissoesParaSalvarDestino do
        begin
            ItemRefFieldPK := ''; ItemRefValuePK := IntToStr(PermItem.ItemID);
            // As permissões copiadas são sempre 'S'
            ValorCharSN := 'S'; // PermItem.Valor deve ser True aqui, então BoolToCharSN(PermItem.Valor) resultaria 'S'

            ColModulo    := 'NULL'; ColSubmodulo := 'NULL'; ColRotina    := 'NULL';
            case PermItem.ItemTipo of
              'M': begin ItemRefFieldPK := 'ID_MODULO_REF';    ColModulo    := ItemRefValuePK; end;
              'S': begin ItemRefFieldPK := 'ID_SUBMODULO_REF'; ColSubmodulo := ItemRefValuePK; end;
              'R': begin ItemRefFieldPK := 'ID_ROTINA_REF';    ColRotina    := ItemRefValuePK; end;
              else Continue;
            end;

            SQL_Update := Format(
              'UPDATE PERMISSAO_USUARIO SET VALOR_PERMISSAO = %s ' +
              'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s = %s AND NOME_PERMISSAO = %s',
              [QuotedStrDB(String(ValorCharSN)), AIDEmpresa, AIDUsuarioDestino, ItemRefFieldPK, ItemRefValuePK, QuotedStrDB(PermItem.NomePermissao)]
            );
            if not ExecuteSQL(SQL_Update, RowsAffectedUpdate) then begin FADOConnection.RollbackTrans; Exit; end;

            if (RowsAffectedUpdate = 0) then // Se não atualizou (não existia ou já era 'S'), e queremos 'S', então INSERT.
            begin
              SQL_Insert := Format(
                'INSERT INTO PERMISSAO_USUARIO (ID_EMPRESA, ID_USUARIO, ID_MODULO_REF, ID_SUBMODULO_REF, ID_ROTINA_REF, NOME_PERMISSAO, VALOR_PERMISSAO) ' +
                'VALUES (%d, %d, %s, %s, %s, %s, %s)',
                [AIDEmpresa, AIDUsuarioDestino,
                 ColModulo, ColSubmodulo, ColRotina,
                 QuotedStrDB(PermItem.NomePermissao), QuotedStrDB(String(ValorCharSN))]
              );
              if not ExecuteSQL(SQL_Insert, RowsAffectedInsert) then begin FADOConnection.RollbackTrans; Exit; end;
            end;
        end;
      end;
    end;

    FADOConnection.CommitTrans;
    Result := True;
  except
    on E: Exception do
    begin
      FADOConnection.RollbackTrans;
      Result := False;
    end;
  end;
end;

function TPermissaoController.PopularPermissoesDefaultParaUsuario(AIDEmpresa, AIDUsuario: Integer): Boolean;
begin
  // Conforme a decisão do usuário, a ausência de um registro em PERMISSAO_USUARIO
  // implica que a permissão é 'N' (negada/não concedida).
  // Portanto, esta função não precisa inserir registros default com 'N'.
  Result := True; // Operação bem-sucedida, pois não há nada a fazer.
end;

function TPermissaoController.PopularPermissoesDefaultParaNovoItemMenu(AItemID: Integer; AItemTipo: Char; ANomeFormParaRotina: string): Boolean;
begin
  // Similar a PopularPermissoesDefaultParaUsuario, não é necessário
  // criar entradas default 'N' para novos itens de menu para todos os usuários.
  // A ausência da permissão na tabela já significa 'N'.
  Result := True; // Operação bem-sucedida.
end;


function TPermissaoController.ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; ANomeForm: string; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
  IsAdmin: Boolean;
  RotinaID: Integer;
begin
  Result := False; // Default: Acesso negado
  PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  ADODataSet := TADODataSet.Create(nil);
  try
    SQL := Format('SELECT ADMINISTRADOR FROM USUARIO WHERE ID_USUARIO = %d AND ID_EMPRESA = %d AND ATIVO = 1',
                  [AIDUsuario, AIDEmpresa]);
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    IsAdmin := False;
    if not ADODataSet.IsEmpty then
      IsAdmin := GetFieldAsBoolean(ADODataSet, 'ADMINISTRADOR');
    ADODataSet.Close;

    if IsAdmin then
    begin
      Result := True; PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      Exit;
    end;

    RotinaID := 0;
    SQL := Format('SELECT ID_ROTINA FROM ROTINA WHERE NOME_FORM = %s', [QuotedStrDB(ANomeForm)]);
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
      RotinaID := ADODataSet.FieldByName('ID_ROTINA').AsInteger;
    ADODataSet.Close;

    if RotinaID = 0 then Exit;

    SQL := Format(
      'SELECT NOME_PERMISSAO ' +
      'FROM PERMISSAO_USUARIO ' +
      'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND ID_ROTINA_REF = %d AND VALOR_PERMISSAO = ''S''',
      [AIDEmpresa, AIDUsuario, RotinaID]
    );
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      while not ADODataSet.Eof do
      begin
        Dim NomePerm: string;
        NomePerm := ADODataSet.FieldByName('NOME_PERMISSAO').AsString;
        if SameText(NomePerm, 'ACESSO') then Result := True
        else if SameText(NomePerm, 'P_INSERIR') then PInserir := True
        else if SameText(NomePerm, 'P_ALTERAR') then PAlterar := True
        else if SameText(NomePerm, 'P_EXCLUIR') then PExcluir := True
        else if SameText(NomePerm, 'P_IMPRIMIR') then PImprimir := True;
        ADODataSet.Next;
      end;
    end;

    if not Result then
    begin
      PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;
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
  ItemRefField: string;
begin
  Result := False;
  PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  ADODataSet := TADODataSet.Create(nil);
  try
    SQL := Format('SELECT ADMINISTRADOR FROM USUARIO WHERE ID_USUARIO = %d AND ID_EMPRESA = %d AND ATIVO = 1',
                  [AIDUsuario, AIDEmpresa]);
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    IsAdmin := False;
    if not ADODataSet.IsEmpty then
      IsAdmin := GetFieldAsBoolean(ADODataSet, 'ADMINISTRADOR');
    ADODataSet.Close;

    if IsAdmin then
    begin
      Result := True;
      if AItemTipo = 'R' then
      begin
        PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      end;
      Exit;
    end;

    case AItemTipo of
      'M': ItemRefField := 'ID_MODULO_REF';
      'S': ItemRefField := 'ID_SUBMODULO_REF';
      'R': ItemRefField := 'ID_ROTINA_REF';
    else
      Exit;
    end;

    SQL := Format(
      'SELECT NOME_PERMISSAO ' +
      'FROM PERMISSAO_USUARIO ' +
      'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s = %d AND VALOR_PERMISSAO = ''S''',
      [AIDEmpresa, AIDUsuario, ItemRefField, AItemID]
    );
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      while not ADODataSet.Eof do
      begin
        Dim NomePerm: string;
        NomePerm := ADODataSet.FieldByName('NOME_PERMISSAO').AsString;
        if SameText(NomePerm, 'ACESSO') then Result := True;
        if AItemTipo = 'R' then
        begin
          if SameText(NomePerm, 'P_INSERIR') then PInserir := True
          else if SameText(NomePerm, 'P_ALTERAR') then PAlterar := True
          else if SameText(NomePerm, 'P_EXCLUIR') then PExcluir := True
          else if SameText(NomePerm, 'P_IMPRIMIR') then PImprimir := True;
        end;
        ADODataSet.Next;
      end;
    end;

    if not Result then
    begin
      PInserir := False; PAlterar := False; PExcluir := False; PImprimir := False;
    end;
  finally
    FreeAndNil(ADODataSet);
  end;
end;

function TPermissaoController.CarregarEmpresas(var EmpresasList: TStringList): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
begin
  Result := False;
  EmpresasList.Clear;
  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  SQL := 'SELECT ID_EMPRESA, NOME_EMPRESA FROM EMPRESA WHERE ATIVO = 1 ORDER BY NOME_EMPRESA';
  ADODataSet := TADODataSet.Create(nil);
  try
    ADODataSet.Connection := FADOConnection;
    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    while not ADODataSet.Eof do
    begin
      EmpresasList.AddObject(ADODataSet.FieldByName('NOME_EMPRESA').AsString,
                             TObject(ADODataSet.FieldByName('ID_EMPRESA').AsInteger));
      ADODataSet.Next;
    end;
    Result := True;
  except
    on E:Exception do
    begin
      Result := False;
    end;
  end;
  FreeAndNil(ADODataSet);
end;

function TPermissaoController.CarregarUsuariosPorEmpresa(AIDEmpresa: Integer; var UsuariosList: TStringList): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
begin
  Result := False;
  UsuariosList.Clear;

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  SQL := Format('SELECT ID_USUARIO, NOME FROM USUARIO WHERE ID_EMPRESA = %d AND ATIVO = 1 ORDER BY NOME', [AIDEmpresa]);
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
      Result := False;
    end;
  end;
  FreeAndNil(ADODataSet);
end;

end.
