unit LuiRecordBuffer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Sqlite3DS, db;

type

  TGetPrimaryKeyEvent = procedure(Sender: TObject; out NewKey: Integer) of object;

  { TLuiRecordBuffer }

  TLuiRecordBuffer = class(TSqlite3Dataset)
  private
    FAppendMode: Boolean;
    FAfterSave: TNotifyEvent;
    FBeforeLoad: TNotifyEvent;
    FAfterLoad: TNotifyEvent;
    FBeforeSave: TNotifyEvent;
    FOnClear: TNotifyEvent;
    FOnGetPrimaryKey: TGetPrimaryKeyEvent;
    FPrimaryKeyField: String;
    FSourceDataSet: TDataSet;
    procedure AddRecord;
    function GetPrimaryKeyFromSource: Integer;
    procedure InitPrimaryKey;
    procedure InitTable;
  protected
    procedure DoAfterLoad; virtual;
    procedure DoBeforeLoad; virtual;
    procedure DoAfterSave; virtual;
    procedure DoBeforeSave; virtual;
    procedure DoClear; virtual;
    function DoGetPrimaryKey: Integer; virtual;
  public
    procedure Clear;
    procedure Load;
    procedure Save;
  published
    property AppendMode: Boolean read FAppendMode write FAppendMode;
    property SourceDataSet: TDataSet read FSourceDataSet write FSourceDataSet;
    property AfterLoad: TNotifyEvent read FAfterLoad write FAfterLoad;
    property BeforeLoad: TNotifyEvent read FBeforeLoad write FBeforeLoad;
    property AfterSave: TNotifyEvent read FAfterSave write FAfterSave;
    property BeforeSave: TNotifyEvent read FBeforeSave write FBeforeSave;
    property OnClear: TNotifyEvent read FOnClear write FOnClear;
    property OnGetPrimaryKey: TGetPrimaryKeyEvent read FOnGetPrimaryKey write FOnGetPrimaryKey;
  end;

implementation

function IsFieldReadOnly(Field: TField): Boolean;
begin
  //todo: remove as soon autoinc.readonly is fixed. fpc224 is not fixed yet
  Result := Field.ReadOnly or (Field.DataType = ftAutoInc);
end;

procedure AssignFieldValue(DestField, SrcField: TField);
begin
  if IsFieldReadOnly(DestField) then
    Exit;
  DestField.Value := SrcField.Value;
end;

{ TLuiRecordBuffer }

procedure TLuiRecordBuffer.DoAfterLoad;
begin
  if Assigned(FAfterLoad) then
    FAfterLoad(Self);
end;

procedure TLuiRecordBuffer.DoBeforeLoad;
begin
  if Assigned(FBeforeLoad) then
    FBeforeLoad(Self);
end;

procedure TLuiRecordBuffer.DoAfterSave;
begin
  if Assigned(FAfterSave) then
    FAfterSave(Self);
end;

procedure TLuiRecordBuffer.DoBeforeSave;
begin
  if Assigned(FBeforeSave) then
    FBeforeSave(Self);
end;

procedure TLuiRecordBuffer.DoClear;
begin
  if Assigned(FOnClear) then
    FOnClear(Self);
end;

function TLuiRecordBuffer.DoGetPrimaryKey: Integer;
begin
  if FAppendMode then
  begin
    if Assigned(FOnGetPrimaryKey) then
      FOnGetPrimaryKey(Self, Result)
    else
      Result := GetPrimaryKeyFromSource;
  end
  else
    Result := SourceDataset.FieldByName(FPrimaryKeyField).AsInteger;
end;

procedure TLuiRecordBuffer.Clear;
var
  i: Integer;
begin
  DisableControls;
  Edit;
  for i := 0 to Fields.Count - 1 do
    Fields[i].SetData(nil);
  Post;
  EnableControls;
  InitPrimaryKey;
  DoClear;
end;

procedure TLuiRecordBuffer.Load;
begin
  DoBeforeLoad;
  InitTable;
  AddRecord;
  InitPrimaryKey;
  DoAfterLoad;
end;

procedure TLuiRecordBuffer.Save;
var
  i: Integer;
  FieldName: String;
begin
  if State in dsEditModes then
    Post;

  if FAppendMode then
    SourceDataset.Append
  else
    SourceDataset.Edit;
  DoBeforeSave;
  for i := 0 to SourceDataset.FieldDefs.Count - 1 do
  begin
    FieldName := SourceDataset.FieldDefs[i].Name;
    AssignFieldValue(SourceDataSet.FieldByName(FieldName), FieldByName(FieldName));
  end;
  DoAfterSave;
  SourceDataset.Post;
end;

procedure TLuiRecordBuffer.AddRecord;
var
  i: Integer;
  FieldName: String;
begin
  Append;
  if not FAppendMode then
  begin
    for i := 0 to SourceDataset.FieldDefs.Count - 1 do
    begin
      FieldName := SourceDataset.FieldDefs[i].Name;
      AssignFieldValue(FieldByName(FieldName), SourceDataset.FieldByName(FieldName));
    end;
  end;
  Post;
end;

function TLuiRecordBuffer.GetPrimaryKeyFromSource: Integer;
var
  OldRecNo: Integer;
begin
  OldRecNo := SourceDataset.RecNo;
  SourceDataset.DisableControls;
  try
    SourceDataset.Append;
    try
      Edit;
      Result := SourceDataset.FieldByName(FPrimaryKeyField).AsInteger;
      Post;
    finally
      SourceDataset.Cancel;
    end;
  finally
    if OldRecNo > 0 then
      SourceDataset.RecNo := OldRecNo;
    SourceDataset.EnableControls;
  end;
end;

procedure TLuiRecordBuffer.InitPrimaryKey;
var
  Key: Integer;
begin
  //todo: change key to a string type
  if FPrimaryKeyField = '' then
    Exit;
  //It's necessary to get the key before calling Edit because DoGetPrimaryKey call Cancel
  Key := DoGetPrimaryKey;
  Edit;
  FieldByName(FPrimaryKeyField).AsInteger := Key;
  Post;
end;

procedure TLuiRecordBuffer.InitTable;
var
  i: Integer;
begin
  FPrimaryKeyField := PrimaryKey;
  Close;
  FieldDefs.Clear;
  for i := 0 to FSourceDataset.FieldDefs.Count - 1 do
    with FSourceDataset.FieldDefs[i] do
    begin
      if DataType = ftAutoInc then
      begin
        if FPrimaryKeyField = '' then
          FPrimaryKeyField := Name;
        FieldDefs.Add(Name, ftInteger, Size, Required)
      end
      else
        FieldDefs.Add(Name, DataType, Size, Required);
    end;

  CreateTable;
  Open;
end;

end.

