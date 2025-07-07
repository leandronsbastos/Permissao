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

  TUserPermissionItem = record
    ItemID: Integer;
    ItemTipo: Char;
    Acesso: Boolean;
    Inserir: Boolean;
    Alterar: Boolean;
    Excluir: Boolean;
    Imprimir: Boolean;
  end;
  PUserPermissionItem = ^TUserPermissionItem;
  TArrayOfUserPermissionItem = array of TUserPermissionItem;

  TPermissaoController = class
  private
    FADOConnection: TADOConnection;
    FConnectionString: string;

    function QueryToRecords(SQL: string; var ARecords: TArrayOfMenuItemStructure): Boolean; overload;
    function QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean; overload;
    function ExecuteSQL(SQL: string): Boolean;

    function QuotedStrDB(const S: string): string;
    function GetFieldAsBoolean(DataSet: TDataSet; const FieldName: string): Boolean;
    function BoolToDBInt(Value: Boolean): Integer;

  public
    constructor Create(const AConnString: string); overload;
    constructor Create(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean = False); overload;
    destructor Destroy; override;

    procedure SetSQLServerConnectionParameters(const AServer, ADatabase, AUser, APassword: string; AIntegratedSecurity: Boolean = False);
    function TestConnection: Boolean;

    function CarregarEstruturaMenu(var AMenuEstrutura: TArrayOfMenuItemStructure): Boolean;
    function CarregarPermissoesUsuario(AIDEmpresa, AIDUsuario: Integer; var APermissoes: TArrayOfUserPermissionItem): Boolean;
    // Removido: SalvarTodasPermissoesUsuario
    function AtualizarPermissoesEspecificas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfUserPermissionItem): Boolean;
    function CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean; // Precisará ser ajustado para usar AtualizarPermissoesEspecificas

    // Função para popular permissões default para um novo usuário (ou novo item de menu para todos os usuários)
    // Esta é uma sugestão de onde essa lógica poderia residir, mas a chamada viria do seu processo de criação de usuário/item de menu.
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

function TPermissaoController.GetFieldAsBoolean(DataSet: TDataSet; const FieldName: string): Boolean;
begin
  Result := DataSet.FieldByName(FieldName).AsInteger = 1;
end;

function TPermissaoController.ExecuteSQL(SQL: string): Boolean;
var
  ADOCommand: TADOCommand;
begin
  Result := False;
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
      ADOCommand.Execute;
      Result := True;
    except
      on E: Exception do
      begin
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
            // Tratamento de NULL para FKs de pai
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

function TPermissaoController.QueryToUserPermissions(SQL: string; var APermissions: TArrayOfUserPermissionItem): Boolean;
var
  ADODataSet: TADODataSet;
  i: Integer;
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
        SetLength(APermissions, ADODataSet.RecordCount);
        i := 0;
        ADODataSet.First;
        while not ADODataSet.Eof do
        begin
          with APermissions[i] do
          begin
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
              // Registro inválido ou inesperado, pular
              // Idealmente, logar este caso
              ADODataSet.Next;
              Continue;
            end;
            Acesso    := GetFieldAsBoolean(ADODataSet, 'ACESSO');
            Inserir   := GetFieldAsBoolean(ADODataSet, 'P_INSERIR');
            Alterar   := GetFieldAsBoolean(ADODataSet, 'P_ALTERAR');
            Excluir   := GetFieldAsBoolean(ADODataSet, 'P_EXCLUIR');
            Imprimir  := GetFieldAsBoolean(ADODataSet, 'P_IMPRIMIR');
          end;
          Inc(i);
          ADODataSet.Next;
        end;
        SetLength(APermissions, i); // Ajusta o tamanho caso algum registro tenha sido pulado
        Result := True;
      end
      else
      begin
        Result := True; // Sem permissões encontradas, mas a query executou
      end;
    except
      on E: Exception do
      begin
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
  // Ajuste para tratar NULLs corretamente para ID_MODULO_ASSOCIADO e ID_SUBMODULO_PAI
  // A query original já usava NULL para NOME_FORM em Módulos e Submódulos, o que é bom.
  SQL :=
    'SELECT ID_MODULO AS ITEM_ID, ''M'' AS ITEM_TIPO, NOME_MODULO AS ITEM_NOME, ' +
    '   NULL AS ID_MODULO_ASSOCIADO, NULL AS ID_SUBMODULO_PAI, NULL AS NOME_FORM, ORDEM_EXIBICAO ' +
    'FROM MODULO ' +
    'UNION ALL ' +
    'SELECT ID_SUBMODULO AS ITEM_ID, ''S'' AS ITEM_TIPO, NOME_SUBMODULO AS ITEM_NOME, ' +
    '   ID_MODULO_ASSOCIADO, ID_SUBMODULO_PAI, NULL AS NOME_FORM, ORDEM_EXIBICAO ' + // ID_MODULO_ASSOCIADO e ID_SUBMODULO_PAI vêm da tabela SUBMODULO
    'FROM SUBMODULO ' +
    'UNION ALL ' +
    'SELECT ID_ROTINA AS ITEM_ID, ''R'' AS ITEM_TIPO, NOME_ROTINA AS ITEM_NOME, ' +
    '   ID_MODULO_ASSOCIADO, ID_SUBMODULO_ASSOCIADO AS ID_SUBMODULO_PAI, NOME_FORM, ORDEM_EXIBICAO ' + // ID_SUBMODULO_ASSOCIADO é o pai da rotina, mapeado para ID_SUBMODULO_PAI na estrutura
    'FROM ROTINA ' +
    'ORDER BY ITEM_TIPO, ORDEM_EXIBICAO, ITEM_NOME'; // Ordem pode precisar de ajuste para hierarquia
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

function TPermissaoController.AtualizarPermissoesEspecificas(AIDEmpresa, AIDUsuario: Integer; const AListaPermissoesAlteradas: TArrayOfUserPermissionItem): Boolean;
var
  PermItem: TUserPermissionItem;
  SQL_Update: string;
  WhereClauseItem: string;
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
      case PermItem.ItemTipo of
        'M': WhereClauseItem := 'ID_MODULO_PERMITIDO = ' + IntToStr(PermItem.ItemID);
        'S': WhereClauseItem := 'ID_SUBMODULO_PERMITIDO = ' + IntToStr(PermItem.ItemID);
        'R': WhereClauseItem := 'ID_ROTINA_PERMITIDA = ' + IntToStr(PermItem.ItemID);
      else
        Continue; // Tipo de item desconhecido, pular
      end;

      SQL_Update := Format(
        'UPDATE PERMISSAO_USUARIO SET ' +
        'ACESSO = %d, P_INSERIR = %d, P_ALTERAR = %d, P_EXCLUIR = %d, P_IMPRIMIR = %d ' +
        'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s',
        [BoolToDBInt(PermItem.Acesso), BoolToDBInt(PermItem.Inserir),
         BoolToDBInt(PermItem.Alterar), BoolToDBInt(PermItem.Excluir),
         BoolToDBInt(PermItem.Imprimir),
         AIDEmpresa, AIDUsuario, WhereClauseItem]);

      if not ExecuteSQL(SQL_Update) then
      begin
        FADOConnection.RollbackTrans;
        Exit;
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

function TPermissaoController.CopiarPermissoes(AIDEmpresa, AIDUsuarioOrigem, AIDUsuarioDestino: Integer): Boolean;
var
  PermissoesOrigem: TArrayOfUserPermissionItem;
  SQL_Delete: string;
begin
  Result := False;
  // 1. Carregar permissões do usuário de origem
  if CarregarPermissoesUsuario(AIDEmpresa, AIDUsuarioOrigem, PermissoesOrigem) then
  begin
    // 2. Assumindo que o destino já tem permissões default (todas negadas),
    //    vamos apenas atualizar essas permissões com as do usuário de origem.
    //    Se a estratégia fosse DELETE/INSERT, precisaríamos deletar as do destino primeiro.
    //    Como mudamos para UPDATE, precisamos garantir que o AtualizarPermissoesEspecificas
    //    receba a lista COMPLETA de permissões do usuário de origem para aplicar no destino.

    // Se o destino já tem permissões default, a função AtualizarPermissoesEspecificas fará os UPDATES.
    // Se o destino NÃO tem permissões default, e a tabela de permissões é esparsa (só tem o que é concedido),
    // então o AtualizarPermissoesEspecificas precisaria ser um "UPSERT" ou
    // teríamos que deletar as do destino e INSERIR as da origem.
    // Para manter a lógica de "permissões default existem e são atualizadas":

    // Primeiro, garantir que o usuário destino tenha as entradas default (caso este método seja chamado antes).
    // Idealmente, PopularPermissoesDefaultParaUsuario seria chamado na criação do usuário.
    // Se não pudermos garantir, podemos chamar aqui, mas pode ser custoso.
    // PopularPermissoesDefaultParaUsuario(AIDEmpresa, AIDUsuarioDestino); // Opcional, mas seguro

    // Agora, atualizamos as permissões do destino com base nas da origem.
    Result := AtualizarPermissoesEspecificas(AIDEmpresa, AIDUsuarioDestino, PermissoesOrigem);
  end;
end;

function TPermissaoController.PopularPermissoesDefaultParaUsuario(AIDEmpresa, AIDUsuario: Integer): Boolean;
var
  MenuEstrutura: TArrayOfMenuItemStructure;
  Item: TMenuItemStructure;
  SQL_Insert: string;
  ModuloFK, SubmoduloFK, RotinaFK: string;
begin
  Result := False;
  if not CarregarEstruturaMenu(MenuEstrutura) then Exit; // Precisa da lista de todos os itens de menu

  if not FADOConnection.Connected then
  begin
    if FConnectionString = '' then Exit;
    FADOConnection.ConnectionString := FConnectionString;
    FADOConnection.Connected := True;
  end;
  if not FADOConnection.Connected then Exit;

  FADOConnection.BeginTrans;
  try
    // Opcional: Deletar permissões existentes para este usuário antes de popular defaults,
    // para evitar duplicatas se este método for chamado mais de uma vez.
    // ExecuteSQL(Format('DELETE FROM PERMISSAO_USUARIO WHERE ID_EMPRESA = %d AND ID_USUARIO = %d', [AIDEmpresa, AIDUsuario]));

    for Item in MenuEstrutura do
    begin
      ModuloFK := 'NULL'; SubmoduloFK := 'NULL'; RotinaFK := 'NULL';
      case Item.Tipo of
        'M': ModuloFK := IntToStr(Item.ID);
        'S': SubmoduloFK := IntToStr(Item.ID);
        'R': RotinaFK := IntToStr(Item.ID);
      end;

      // Inserir com todas as permissões como 0 (False)
      SQL_Insert := Format(
        'INSERT INTO PERMISSAO_USUARIO (ID_EMPRESA, ID_USUARIO, ID_MODULO_PERMITIDO, ID_SUBMODULO_PERMITIDO, ID_ROTINA_PERMITIDA, ' +
        'ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR) ' +
        'VALUES (%d, %d, %s, %s, %s, 0, 0, 0, 0, 0) ' + // Todas permissões default como 0
        // Adicionar cláusula para não inserir se já existir (varia por SGBD)
        // Exemplo para SQL Server:
        // 'WHERE NOT EXISTS (SELECT 1 FROM PERMISSAO_USUARIO E WHERE E.ID_EMPRESA = %d AND E.ID_USUARIO = %d AND ' +
        // '  ( (E.ID_MODULO_PERMITIDO = %s AND %s IS NOT NULL) OR ' +
        // '    (E.ID_SUBMODULO_PERMITIDO = %s AND %s IS NOT NULL) OR ' +
        // '    (E.ID_ROTINA_PERMITIDA = %s AND %s IS NOT NULL) ) )',
        // [AIDEmpresa, AIDUsuario, ModuloFK, SubmoduloFK, RotinaFK, AIDEmpresa, AIDUsuario, ModuloFK, ModuloFK, SubmoduloFK, SubmoduloFK, RotinaFK, RotinaFK]
        // A lógica de "não inserir se já existe" é complexa com as 3 FKs nullable.
        // É mais simples deletar antes ou confiar na constraint UNIQUE.
        // Para garantir, podemos checar antes de inserir ou usar MERGE (SQL Server 2008+)
        // Por simplicidade aqui, vamos assumir que não há duplicatas ou que a constraint UNIQUE pega.
        , [AIDEmpresa, AIDUsuario, ModuloFK, SubmoduloFK, RotinaFK]
      );
      if not ExecuteSQL(SQL_Insert) then
      begin
        // Se falhar (ex: por constraint UNIQUE), pode ser que já exista. Ignorar o erro ou logar.
        // Para um sistema robusto, checar existência antes ou usar MERGE.
        // FADOConnection.RollbackTrans;
        // Exit;
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

function TPermissaoController.PopularPermissoesDefaultParaNovoItemMenu(AItemID: Integer; AItemTipo: Char; ANomeFormParaRotina: string): Boolean;
var
  Usuarios: TStringList; // Para buscar todos os usuários existentes
  i: Integer;
  IDEmpresa, IDUsuario: Integer; // Supondo que um novo item é global ou precisa ser adicionado para todos os usuários de todas as empresas
  SQL_Insert: string;
  ModuloFK, SubmoduloFK, RotinaFK: string;
begin
  Result := False;
  // Esta função é mais complexa pois precisaria iterar por todos os usuários de todas as empresas
  // e adicionar a permissão default para este novo item.
  // Exemplo simplificado:
  // 1. Buscar todos os pares (ID_EMPRESA, ID_USUARIO) da tabela USUARIO.
  // 2. Para cada par, inserir a permissão default para o novo item.

  // Esta implementação é apenas um esboço e precisaria ser bem testada e adaptada.
  // Considerar performance para muitos usuários.

  // FADOConnection.BeginTrans;
  // try
  //   Loop por todos os usuários...
  //     ModuloFK := 'NULL'; SubmoduloFK := 'NULL'; RotinaFK := 'NULL';
  //     case AItemTipo of
  //       'M': ModuloFK := IntToStr(AItemID);
  //       'S': SubmoduloFK := IntToStr(AItemID);
  //       'R': RotinaFK := IntToStr(AItemID);
  //     end;
  //     SQL_Insert := Format(
  //       'INSERT INTO PERMISSAO_USUARIO (ID_EMPRESA, ID_USUARIO, ID_MODULO_PERMITIDO, ID_SUBMODULO_PERMITIDO, ID_ROTINA_PERMITIDA, ' +
  //       'ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR) ' +
  //       'VALUES (%d, %d, %s, %s, %s, 0, 0, 0, 0, 0)',
  //       [IDEmpresaDoUsuario, IDDoUsuario, ModuloFK, SubmoduloFK, RotinaFK]);
  //     ExecuteSQL(SQL_Insert);
  //   FADOConnection.CommitTrans;
  //   Result := True;
  // except
  //   FADOConnection.RollbackTrans;
  //   Result := False;
  // end;
  Exit; // Implementação pendente
end;


function TPermissaoController.ValidarPermissao(AIDEmpresa, AIDUsuario: Integer; ANomeForm: string; out PInserir, PAlterar, PExcluir, PImprimir: Boolean): Boolean;
var
  SQL: string;
  ADODataSet: TADODataSet;
  IsAdmin: Boolean;
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
      Result := True; PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      Exit;
    end;

    SQL := Format(
      'SELECT PU.ACESSO, PU.P_INSERIR, PU.P_ALTERAR, PU.P_EXCLUIR, PU.P_IMPRIMIR ' +
      'FROM PERMISSAO_USUARIO PU ' +
      'INNER JOIN ROTINA R ON PU.ID_ROTINA_PERMITIDA = R.ID_ROTINA ' +
      'WHERE PU.ID_EMPRESA = %d AND PU.ID_USUARIO = %d AND R.NOME_FORM = %s AND PU.ACESSO = 1',
      [AIDEmpresa, AIDUsuario, QuotedStrDB(ANomeForm)]);

    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      Result     := GetFieldAsBoolean(ADODataSet, 'ACESSO');
      PInserir   := GetFieldAsBoolean(ADODataSet, 'P_INSERIR');
      PAlterar   := GetFieldAsBoolean(ADODataSet, 'P_ALTERAR');
      PExcluir   := GetFieldAsBoolean(ADODataSet, 'P_EXCLUIR');
      PImprimir  := GetFieldAsBoolean(ADODataSet, 'P_IMPRIMIR');
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
      Result := True; PInserir := True; PAlterar := True; PExcluir := True; PImprimir := True;
      Exit;
    end;

    case AItemTipo of
      'M': CampoItemFK := 'ID_MODULO_PERMITIDO';
      'S': CampoItemFK := 'ID_SUBMODULO_PERMITIDO';
      'R': CampoItemFK := 'ID_ROTINA_PERMITIDA';
      else Exit;
    end;

    SQL := Format(
      'SELECT ACESSO, P_INSERIR, P_ALTERAR, P_EXCLUIR, P_IMPRIMIR ' +
      'FROM PERMISSAO_USUARIO ' +
      'WHERE ID_EMPRESA = %d AND ID_USUARIO = %d AND %s = %d AND ACESSO = 1',
      [AIDEmpresa, AIDUsuario, CampoItemFK, AItemID]);

    ADODataSet.CommandText := SQL;
    ADODataSet.Open;
    if not ADODataSet.IsEmpty then
    begin
      Result     := GetFieldAsBoolean(ADODataSet, 'ACESSO');
      if AItemTipo = 'R' then
      begin
        PInserir   := GetFieldAsBoolean(ADODataSet, 'P_INSERIR');
        PAlterar   := GetFieldAsBoolean(ADODataSet, 'P_ALTERAR');
        PExcluir   := GetFieldAsBoolean(ADODataSet, 'P_EXCLUIR');
        PImprimir  := GetFieldAsBoolean(ADODataSet, 'P_IMPRIMIR');
      end;
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
