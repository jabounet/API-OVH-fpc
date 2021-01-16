unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ssl_openssl, Forms,
  Controls, Graphics, Dialogs, StdCtrls, synautil,
  FpJson, JSonParser, DCPsha1, httpsend, lclintf, ExtCtrls, Grids, strutils,
  inifiles, DateUtils, syncobjs, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Label1: TLabel;
    Memo1: TMemo;
    StringGrid1: TStringGrid;

    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure StringGrid1PrepareCanvas(Sender: TObject; aCol, aRow: integer;
      aState: TGridDrawState);

  private

  public
    procedure OVHTimerEvent(Sender: TObject);
  end;

var
  Form1: TForm1;

type

  { TOVHThread }
  TOVHThread = class(TThread)
    consumerKey: string;
    critic: TcriticalSection;
    procedure Execute; override;



  public
  end;

var
  OVHThread: TOVHThread;

var
  curSessId, curToken: string;


var
  initTime, curTime: TdateTime;

var
  syncTime: boolean = False;

var
  startTimeStamp, curTimeStamp: int64;

const
  CRLF = #13#10;

const
  BASE_URL = 'https://eu.api.ovh.com/1.0';
  EVENTS_URL = 'https://events.voip.ovh.net/v2';

const
  OVH_URL_TIMESTAMP = '/auth/time';

const
  OVH_AK = 'n0NhFz3JavSGlkZY';

const
  OVH_AS = 'anSVC8QqIujgUZS4pY42CwnV959iQ68G';


var
  OVH_CK: string;

var
  ParamLines: string;

var
  params: string;

var
  BillingAccount: string = '';


const
  OVH_TimeOut = 1500;


type
  OVH_Query = record
    method: string;
    mimeType: string;
    queryURL: string;
    body: string;
    timestamp: string;
    signature: string;
    headers: string;
    keepalive: boolean;
    timeout: integer;
  end;

var
  DefOVH_Query: OVH_Query = (method: '';
  mimeType: '';
  queryURL: '';
  body: '';
  timestamp: '';
  signature: '';
  headers: '';
  keepalive: False;
  timeout: 1500; );

type
  OVH_ResultCK = record
    CK: string;
    validationUrl: string;
    state: string;
  end;




type
  Call_state = (idle, start_ringing, start_calling, end_ringing,
    end_calling, registered);

type
  OVH_Call = record
    CallId: string;
    Calling: string;
    Called: string;
    Dialed: string;
    current_state: Call_state;
    startTime: TDateTime;
    endTime: TDateTime;
  end;

const
  Def_OVH_Call: OVH_Call =
    (callid: ''; calling: ''; called: ''; dialed: ''; current_state: idle;
    starttime: default(Tdatetime); endTime: default(Tdatetime));

type
  OVH_Calls = array of OVH_Call;

var
  CurOVH_Calls: OVH_Calls;

type
  OVH_PhoneLine = record
    id: string;
    Calls: OVH_Calls;
  end;

type
  OVH_PhoneLines = array of OVH_PhoneLine;

var
  Cur_OVH_Phonelines: OVH_PhoneLines;


type
  OVHEvent = record
    event: string;
    calling: string;
    called: string;
  end;

type
  OVHEvents = array of OVHEvent;


function getsha1hash(S: string): string;
function CreateOVHQuery(m, q, b: string; ServiceName: string = ''): OVH_Query;
function Get_OVH_TimeStamp: int64;
function OVHClient(Query: OVH_QUERY): string;
function setiniparam(conf, sect, param, val: string): boolean;
function getiniparam(conf, sect, param: string; default_value: string = ''): string;
function GetEventsPoll(sessId: string): string;

type
  OVHBillingAccounts = array of string;
type
  OVHLines = array of string;

function GetOVHTelephony: OVHBillingAccounts;

implementation

{$R *.lfm}

{ TForm1 }


function IsValidJSON(JsonStr: string): boolean;
var
  Data: TJSONData;
begin
  Result := True;
  if length(JsonStr) = 0 then
  begin
    Result := False;
    exit;
  end;
  try
    Data := GetJSON(JSONstr);
  except
    On E: ejsonparser do
    begin
      Result := False;
    end;
  end;
  Data.Free;
end;


function flattenString(a: string): string;
begin
  Result := StringReplace(a, CRLF, '', [RfReplaceAll]);
end;

procedure log(a: string; Clear: boolean = False);
begin
  if Clear then
    form1.memo1.Lines.Clear;
  Form1.Memo1.Lines.Add(a);
end;

function getiniparam(conf, sect, param: string; default_value: string = ''): string;
var
  jini: tinifile;
  resultval: string;
begin
  if conf = '' then
    exit;
  jini := tinifile.Create(conf);
  resultval := jini.ReadString(sect, param, '');
  if resultval = '' then
    resultval := default_value;
  Result := resultval;
  jini.Free;
end;

function checkiniparam(conf, sect: string): boolean;
var
  jini: tinifile;
begin
  Result := False;
  if conf = '' then
    exit;
  jini := tinifile.Create(conf);
  Result := jini.SectionExists(uppercase(sect));
  jini.Free;

end;


function setiniparam(conf, sect, param, val: string): boolean;
var
  jini: tinifile;
begin
  Result := False;
  if conf = '' then
    exit;
  jini := tinifile.Create(conf);
  jini.WriteString(sect, param, val);
  jini.Free;
  Result := True;
end;



function GetMimeFromExt(extension: string): string;
begin
  Result := 'application/octet-stream';
  case extension of
    '.aac': Result := 'audio/aac';
    '.abw': Result := 'application/x-abiword';
    '.arc': Result := 'application/octet-stream';
    '.avi': Result := 'video/x-msvideo';
    '.azw': Result := 'application/vnd.amazon.ebook';
    '.bin': Result := 'application/octet-stream';
    '.bz': Result := 'application/x-bzip';
    '.bz2': Result := 'application/x-bzip2';
    '.csh': Result := 'application/x-csh';
    '.css': Result := 'text/css';
    '.csv': Result := 'text/csv';
    '.doc': Result := 'application/msword';
    '.docx': Result :=
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    '.eot': Result := 'application/vnd.ms-fontobject';
    '.epub': Result := 'application/epub+zip';
    '.gif': Result := 'image/gif';
    '.htm': Result := 'text/html';
    '.html': Result := 'text/html';
    '.ico': Result := 'image/x-icon';
    '.ics': Result := 'text/calendar';
    '.jar': Result := 'application/java-archive';
    '.jpeg': Result := 'image/jpeg';
    '.jpg': Result := 'image/jpeg';
    '.js': Result := 'application/javascript';
    '.json': Result := 'application/json';
    '.mid': Result := 'audio/midi';
    '.midi': Result := 'audio/midi';
    '.mpeg': Result := 'video/mpeg';
    '.mpkg': Result := 'application/vnd.apple.installer+xml';
    '.odp': Result := 'application/vnd.oasis.opendocument.presentation';
    '.ods': Result := 'application/vnd.oasis.opendocument.spreadsheet';
    '.odt': Result := 'application/vnd.oasis.opendocument.text';
    '.oga': Result := 'audio/ogg';
    '.ogv': Result := 'video/ogg';
    '.ogx': Result := 'application/ogg';
    '.otf': Result := 'font/otf';
    '.png': Result := 'image/png';
    '.pdf': Result := 'application/pdf';
    '.ppt': Result := 'application/vnd.ms-powerpoint';
    '.pptx': Result :=
        'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    '.rar': Result := 'application/x-rar-compressed';
    '.rtf': Result := 'application/rtf';
    '.sh': Result := 'application/x-sh';
    '.svg': Result := 'image/svg+xml';
    '.swf': Result := 'application/x-shockwave-flash';
    '.tar': Result := 'application/x-tar';
    '.tif': Result := 'image/tiff';
    '.tiff': Result := 'image/tiff';
    '.ts': Result := 'application/typescript';
    '.ttf': Result := 'font/ttf';
    '.vsd': Result := 'application/vnd.visio';
    '.wav': Result := 'audio/x-wav';
    '.weba': Result := 'audio/webm';
    '.webm': Result := 'video/webm';
    '.webp': Result := 'image/webp';
    '.woff': Result := 'font/woff';
    '.woff2': Result := 'font/woff2';
    '.xhtml': Result := 'application/xhtml+xml';
    '.xls': Result := 'application/vnd.ms-excel';
    '.xlsx': Result := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    '.xml': Result := 'application/xml';
    '.xul': Result := 'application/vnd.mozilla.xul+xml';
    '.zip': Result := 'application/zip';
    '.3gp': Result := 'video/3gpp';
    '.3g2': Result := 'video/3gpp2';
    '.7z': Result := 'application/x-7z-compressed';
  end;
end;


// Synchro du temps avec le serveur OVH
function GetCurTimeStamp: string;
begin
  Result := '-1';
  if not SyncTime then
  begin
    startTimeStamp := Get_OVH_TimeStamp;
    initTime := now;
    SyncTime := True;
  end;
  curTime := now;
  curTimeStamp := startTimeStamp + SecondsBetween(curtime, initTime);
  Result := IntToStr(curTimeStamp);
end;


// Création d'une requête OVH
function CreateOVHQuery(m, q, b: string; ServiceName: string = ''): OVH_Query;
begin
  Result := DefOVH_Query;
  with Result do
  begin
    method := m;
    queryURL := StringsReplace(q, ['{billingAccount}', '{serviceName}'],
      [BillingAccount, ServiceName], [RfReplaceAll]);
    body := b;
    timestamp := GetCurTimeStamp;
    signature := '$1$' + GetSHA1Hash(OVH_AS + '+' + OVH_CK + '+' +
      method + '+' + queryURL + '+' + body + '+' + timestamp);
    headers := 'X-Ovh-Application: ' + OVH_AK + CRLF + 'X-Ovh-Timestamp: ' +
      timestamp + CRLF + 'X-Ovh-Signature: ' + signature + CRLF +
      'X-Ovh-Consumer: ' + OVH_CK;
  end;
end;

// Encodage SHA1 pour la signature
function getsha1hash(S: string): string;
var
  Hash: TDCP_SHA1;
  Digest: array[0..31] of byte;
  i: integer;
  hashstr: string;
begin
  Result := '';

  TMBCSEncoding.Create;
  if S <> '' then
  begin
    Hash := TDCP_SHA1.Create(nil);
    Hash.Init;
    Hash.UpdateStr(S);
    Hash.Final(Digest);
    hashstr := '';
    for i := 0 to 19 do
      hashstr := hashstr + lowercase(IntToHex(Digest[i], 2));
    Result := (hashstr);
    Hash.Free;
  end;

end;

// Récupération du temps sur le serveur OVH
function Get_OVH_TimeStamp: int64;
var
  Response: TStringList;
  URL: string;
  HTTP: THTTPSend;
begin
  Result := -1;
  Response := TStringList.Create;
  HTTP := THTTPSend.Create;
  try
    URL := BASE_URL + OVH_URL_TIMESTAMP;
    HTTP.Timeout := OVH_TimeOut;
    HTTP.Sock.ConnectionTimeout := OVH_TimeOut;
    if HTTP.HTTPMethod('GET', URL) then
    begin
      if HTTP.ResultCode <> 200 then
      begin
        //log(URL + CRLF + HTTP.Headers.Text + CRLF + Result);
      end
      else
      begin
        Response.LoadFromStream(HTTP.Document);
        Result := strtointdef(response[0], -1);
      end;
    end;
  finally
    Response.Free;
    HTTP.Free;
  end;
end;




// Fonction globale OVH (GET/POST)
function OVHClient(Query: OVH_QUERY): string;
var
  Response: TStringList;
  URL: string;
  HTTP: THTTPSend;
  ParseResponse: TJSONData;
  Body: TStringList;
begin
  Result := '';
  Response := TStringList.Create;
  HTTP := THTTPSend.Create;
  try
    URL := Query.queryURL;
    HTTP.Document.Clear;
    HTTP.Headers.Clear;
    HTTP.Headers.Text := Query.headers;

    if length(Query.body) > 0 then
    begin
      WriteStrToStream(HTTP.Document, Query.body);
    end;
    HTTP.mimeType := (Query.mimeType);
    HTTP.Timeout := Query.timeout;
    HTTP.Sock.ConnectionTimeout := Query.TimeOut;
    HTTP.KeepAlive := Query.keepalive;
    HTTP.KeepAliveTimeOut := Query.Timeout;
    // log(HTTP.Headers.Text);

    // log(URL + '$'+HTTP.Headers.Text + '$'+Query.body);
    if HTTP.HTTPMethod(query.method, URL) then
    begin
      Response.LoadFromStream(HTTP.Document);
      if HTTP.ResultCode = 200 then
      begin
        Result := flattenString(Response.Text);
      end
      else
      begin
        log(URL + CRLF + HTTP.Headers.Text + CRLF + Response.Text);
      end;
    end;
  finally
    Response.Free;
    HTTP.Free;
  end;
end;




function Get_OVH_CK: Ovh_ResultCK;
var
  Response: TStringList;
  URL: string;
  HTTP: THTTPSend;
  Body: TStringList;
  ParseResponse: TJSONData;
begin

  Response := TStringList.Create;
  Body := TStringList.Create;
  HTTP := THTTPSend.Create;
  URL := BASE_URL + '/auth/credential';
  try
    HTTP.Document.Clear;
    HTTP.Headers.Add('X-Ovh-Application: ' + OVH_AK);
    HTTP.Headers.Add('Content-Type: application/json');
    HTTP.MimeType := getmimefromext('.json');
    Body.Clear;
    Body.Add(
      '{"accessRules": [{"method": "GET","path": "/*"},{"method": "POST","path": "/*"}],"redirection":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}');
    Body.SaveToStream(HTTP.Document);
    HTTP.Timeout := OVH_TimeOut;
    HTTP.Sock.ConnectionTimeout := OVH_TimeOut;

    if HTTP.HTTPMethod('POST', URL) then
    begin

      if HTTP.ResultCode <> 200 then
      begin
      end
      else
      begin
        Response.LoadFromStream(HTTP.Document);
        Parseresponse := GetJSon(Response.Text);
        Result.validationUrl := Parseresponse.FindPath('validationUrl').AsString;
        Result.CK := Parseresponse.FindPath('consumerKey').AsString;
        Result.state := Parseresponse.FindPath('state').AsString;
      end;

    end;
  finally
    Response.Free;
    HTTP.Free;
    Body.Free;
  end;
end;



function GetOVHTelephony: OVHBillingAccounts;
var
  i: integer;
  a: TJSONData;
  c: TJSONArray;
  rs: string;
begin
  Setlength(Result, 0);
  try
    rs := (OVHClient(CreateOVHQuery('GET', BASE_URL + '/telephony/', '')));
    a := getjson(rs);
    if a = nil then
      exit;
    c := TJSONArray(a);
    for i := 0 to (c.Count - 1) do
    begin
      Setlength(Result, i + 1);
      Result[i] := c.items[i].AsString;
    end;
  finally
    a.Free;
  end;
end;




function GetOVHPhoneLinesIds(Lines: string = ''): string;
var
  i: integer;
var
  a: TJSONData;
  c: TJSONArray;
var
  rs: string;
begin
  Result := '';
  Setlength(Cur_OVH_PhoneLines, 0);
  try
    if Lines = '' then
    begin
      log('Récupération des lignes associées au compte...');
      rs := (OVHClient(CreateOVHQuery('GET', BASE_URL +
        '/telephony/{billingAccount}/line', '')));
    end
    else
      rs := Lines;
    a := getjson(rs);
    if a = nil then
      exit;
    c := TJSONArray(a);
    for i := 0 to (c.Count - 1) do
    begin
      Setlength(Cur_OVH_PhoneLines, i + 1);
      with Cur_OVH_Phonelines[i] do
      begin
        id := c.items[i].AsString;
      end;
    end;
  finally
    a.Free;
    c:=nil;
  end;
  Result := rs;
end;

function GetOVHPhoneCallsIds: boolean;
var
  i, j: integer;
var
  a: TJSONData;
  c: TJSONArray;
var
  rs: string;
begin
  Result := False;
  if length(Cur_OVH_PhoneLines) = 0 then
    exit;
  try
    for i := 0 to length(Cur_OVH_PhoneLines) - 1 do
    begin
      a := getjson(OVHClient(CreateOVHQuery('GET', BASE_URL +
        '/telephony/{billingAccount}/line/{serviceName}/calls', '',
        Cur_OVH_PhoneLines[i].id)));
      if a <> nil then
      begin
        c := TJSONArray(a);
        Setlength(Cur_OVH_PhoneLines[i].Calls, 0);
        for j := 0 to (c.Count - 1) do
        begin
          Setlength(Cur_OVH_PhoneLines[i].Calls, j + 1);
          with Cur_OVH_Phonelines[i].Calls[j] do
          begin
            Callid := c.items[j].AsString;
          end;
        end;
        a.Free;
        c := nil;
      end;

    end;
  finally
  end;
  Result := True;
end;




// Génération d'un token pour le compte (durée illimitée)
function GetEventsToken: string;
var
  i, j: integer;
var
  a: TJSONData;
var
  q: OVH_Query;
var
  rs: string;
begin
  Result := '';
  try
    q := CreateOVHQuery('POST', BASE_URL + '/telephony/{billingAccount}/eventToken',
      '{"expiration":"unlimited"}');
    q.mimeType := GetMimeFromExt('.json');
    q.headers := q.headers + CRLF + 'Content-Type: ' + q.mimeType;
    rs := OVHClient(q);
    Result := StringsReplace((rs), ['"', CRLF], ['', ''], [RfReplaceall]);
  finally
  end;
end;

// Association SessionId / Token

function RegisterToken(sessId, Token: string): string;
var
  i, j: integer;
var
  a: TJSONData;
var
  q: OVH_Query;
var
  rs: string;
begin
  Result := '';
  try
    q := DefOVH_Query;
    with q do
    begin
      mimetype := '';
      headers := 'Cache-Control: no-cache';
      //+CRLF+'Content-Type: application/json'+CRLF+'Accept: text/plain';
      method := 'POST';
      body := '';
      queryURL := EVENTS_URL + '/session/' + SessId + '/subscribe/' + Token;

    end;
    rs := OVHClient(q);
    //Result :=rs;
    Result := rs;
    log(rs);

  finally
  end;
end;




// Récupération d'un identifiant de session
function GetEventsSessionId: string;
var
  i, j: integer;
var
  a: TJSONData;
var
  q: OVH_Query;
var
  rs: string;
begin
  Result := '';
  try
    q := DefOVH_Query;
    with q do
    begin
      body := '';
      headers := 'Content-Type: application/json' + CRLF + 'Accept: text/plain';
      method := 'POST';
      queryURL := EVENTS_URL + '/session';
    end;
    rs := OVHClient(q);
    a := getjson(rs);
    if a = nil then
      exit;
    Result := a.FindPath('id').AsString;
    a.Free;
  finally
  end;
end;



function GetEventsPoll(sessId: string): string;
var
  i, j: integer;
var
  a: TJSONData;
var
  q: OVH_Query;
var
  rs: string;
begin
  Result := '';
  try
    q := DefOVH_Query;
    with q do
    begin
      q.keepalive := True;
      q.timeout := 15000;
      body := '';
      headers := 'Content-Type: application/json' + CRLF + 'Accept: text/plain';
      method := 'GET';
      queryURL := EVENTS_URL + '/session/' + sessId + '/events/poll';
    end;
    rs := OVHClient(q);
    Result := rs;
  finally
  end;
end;


function GetState(state: string): call_state;
begin
  Result := idle;
  case lowercase(state) of
    'start_ringing': Result := start_ringing;
    'start_calling': Result := start_calling;
    'end_ringing': Result := end_ringing;
    'end_calling': Result := end_calling;
  end;
end;

function StateTostr(state: call_state): string;
begin
  Result := 'idle';
  case (state) of
    start_ringing: Result := 'start_ringing';
    start_calling: Result := 'start_calling';
    end_ringing: Result := 'end_ringing';
    end_calling: Result := 'end_calling';
  end;

end;

function CheckIfCallexists(id: string; calls: OVH_Calls): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to length(calls) - 1 do
    if calls[i].CallId = id then
      Result := True;
end;

function RemoveCall(id: string; var calls: OVH_Calls): OVH_Calls;
var
  i, j: integer;
begin
  j := 0;
  Setlength(Result, j);
  for i := 0 to length(calls) - 1 do
    if calls[i].CallId <> id then
    begin
      Inc(j);
      setLength(Result, j);
      Result[j - 1] := calls[i];
    end;
end;

function InsertCall(call: OVH_Call; calls: OVH_Calls): OVH_Calls;
var
  i, j: integer;
begin
  i := length(calls);
  Result := calls;
  Setlength(Result, i + 1);
  Result[i] := call;
end;


function ChangeState(call: OVH_Call; new_state: Call_state; calls: OVH_Calls): OVH_Calls;
var
  i: integer;
begin
  Result := calls;
  for i := 0 to length(Result) - 1 do
    if Result[i].callId = call.CallId then
    begin
      Result[i].current_state := new_state;
      break;
    end;
end;


function RefreshCalls(calls: OVH_Calls): OVH_Calls;
var
  i, j: integer;
var
  keep: boolean;
begin
  j := 0;
  Setlength(Result, j);
  for i := 0 to length(calls) - 1 do
  begin
    keep := True;
    with calls[i] do
      case current_state of
        end_ringing, end_calling:
        begin
          if endTime = startTime then
            endTime := incsecond(now, 10);
          if now >= endTime then
            keep := False;
        end;
      end;
    if keep then
    begin
      Inc(j);
      setLength(Result, j);
      Result[j - 1] := calls[i];
    end;
  end;
end;


procedure RefreshCallList(Sg: Tstringgrid; calls: OVH_Calls);
var
  i: integer;
begin
  sg.RowCount := 1;
  for i := 0 to length(calls) - 1 do
  begin
    sg.rowcount := i + 2;
    sg.Cells[0, i + 1] := Datetimetostr(calls[i].startTime);
    sg.Cells[1, i + 1] := Statetostr(calls[i].current_state);
    sg.Cells[2, i + 1] := calls[i].Calling;
    sg.Cells[3, i + 1] := calls[i].Called;
  end;

end;


procedure TOVHThread.Execute;
var
  b: TJSONData;
var
  a: TJSONArray;
var
  s: string;
var
  i, j: integer;
  t1, t2: TDateTime;
  ms: integer;
  Rs: string;
  main_count: int64;
  call: OVH_Call;
begin
  critic := TcriticalSection.Create;
  main_count := 0;

  critic.Enter;
  Setlength(CurOVH_Calls, 0);
  critic.leave;

  if (CurSessId = '') or (curToken = '') then
    exit;
  try
    repeat;
      sleep(50);
      Inc(main_count);
      critic.Enter;
      CurOVH_Calls := RefreshCalls(CurOVH_Calls);
      RefreshCallList(form1.StringGrid1, curOVH_Calls);

      rs := (GetEventsPoll(cursessId));

      if (isValidJson(rs)) then
      begin
        t1 := now;
        b := getJson(rs);
        a := TJsonArray(b);
        for i := 0 to a.Count - 1 do
        begin
          call := def_OVH_call;
          with call do
          begin
            CallId := a[i].FindPath('data.CallId').AsString;
            Called := a[i].FindPath('data.Called').AsString;
            Calling := a[i].FindPath('data.Calling').AsString;
            current_state := GetState(a[i].FindPath('event').AsString);
            startTime := now;
            endTime := now;
            log(DateTimetoStr(StartTime)+':'+calling + '>' + called + ':' + Statetostr(current_state));
          end;

          if (not checkifcallExists(call.CallId, CurOVH_Calls)) and
            (call.current_state <> idle) then
            CurOVH_Calls := Insertcall(call, CurOVH_Calls)
          else
            CurOVH_Calls := ChangeState(call, call.current_state, CurOVH_Calls);
        end;

        a := nil;
        b.Free;
        t2 := now;
        //log(IntToStr(millisecondsbetween(t1, t2)) + 'ms');
      end;

      critic.leave;
    until Terminated;

  finally
    critic.Free;
  end;
end;


procedure TForm1.OVHTimerEvent(Sender: TObject);
var
  a, b: TJSONData;
var
  c: TJSONArray;
var
  s, rs: string;
var
  i, j: integer;
  t1, t2: TDateTime;
  ms: integer;
begin
  Enabled := False;
  Application.ProcessMessages;
  try
    t1 := now;
    ParamLines := GetOVHPhoneLinesIds(ParamLines);
    GetOVHPhoneCallsIds;
    t2 := now;
    ms := millisecondsBetween(t1, t2);
    log('Appels en cours : ', True);
    for i := 0 to length(Cur_OVH_PhoneLines) - 1 do
      if length(Cur_OVH_PhoneLines[i].Calls) > 0 then
        for j := 0 to length(Cur_OVH_PhoneLines[i].Calls) - 1 do
          log('+' + Cur_OVH_PhoneLines[i].id + '>' +
            Cur_OVH_PhoneLines[i].Calls[j].CallId)
      else
        log('+' + Cur_OVH_PhoneLines[i].id + '> No calls in progress');
    log('(' + IntToStr(ms) + 'ms)');


  finally
    Enabled := True;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin

  if not Assigned(OVHThread) then
  begin

    CursessId := (GetEventsSessionId);
    log('Session_Id : ' + cursessId);
    Curtoken := (GetEventsToken);
    log('Token : ' + CurToken);
    log('Registering token...');
    RegisterToken(cursessid, curtoken);
    log('Reading events...');
    OVHThread := TOVHThread.Create(True);
    OVHThread.FreeOnTerminate := True;
    OVHThread.start;
  end
  else
  begin
    OVHThread.Terminate;
    OVHThread := nil;
    log('Thread terminated !');
  end;

end;

procedure TForm1.Button2Click(Sender: TObject);
var
  r: Ovh_ResultCK;
begin
  r := Get_OVH_CK;
  OpenURL(r.validationUrl);
  if r.state = 'pendingValidation' then
  begin
    OVH_CK := r.CK;
    setiniparam(params, 'Params', 'consumerKey', OVH_CK);
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  tok, sess: string;
begin
  log(GetOVHPhoneLinesIds);
  log(OVHClient(CreateOVHQuery('GET',BASE_URL+'/telephony/{billingAccount}/line/'+Cur_OVH_Phonelines[0].id+'/statistics?timeframe=daily&type=maxdelay','')));
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if assigned(OVHThread) then
  begin
    log('Please wait while the thread is finishing...');
    OVHThread.Terminate;
    OVHThread.WaitFor;
    sleep(200);
    OVHThread := nil;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  params := ExtractFilePath(ParamStr(0)) + 'params.ini';
  OVH_CK := getiniparam(params, 'Params', 'consumerKey');
  billingAccount := getiniparam(params, 'Params', 'billingAccount');
  // ParamLines := getiniparam(params, 'Params', 'lines');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin

end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
  aRect: TRect; aState: TGridDrawState);
begin

end;

procedure TForm1.StringGrid1PrepareCanvas(Sender: TObject; aCol, aRow: integer;
  aState: TGridDrawState);
begin

  case (Sender as TStringGrid).Cells[1, aRow] of
    'start_ringing':
      with (Sender as TStringGrid) do
      begin
        ;
        Canvas.Brush.Color := $00B3D9FF;
        Canvas.Font.Color := clblack;
        Canvas.Font.Style := [];
      end;
    'start_calling':
      with (Sender as TStringGrid) do
      begin
        ;
        Canvas.Brush.Color := $00B6F4AA;
        Canvas.Font.Color := clblack;
        Canvas.Font.Style := [fsbold];
      end;
    'end_ringing', 'end_calling':
      with (Sender as TStringGrid) do
      begin
        ;
        Canvas.Brush.Color := $00D0D0FF;
        Canvas.Font.Color := clblack;
        Canvas.Font.Style := [fsitalic];
      end;

  end;
end;

end.
/// FONCTIONS ANNEXES/// DANS LE THREAD{t1:=now;{ParamLines:=GetOVHPhoneLinesIds(ParamLines);
{GetOVHPhoneCallsIds;
t2:=now;

ms := millisecondsBetween(t1,t2);
log('Appels en cours : ',true);
for i := 0 to length(Cur_OVH_PhoneLines) - 1 do
  if length(Cur_OVH_PhoneLines[i].Calls)>0 then
  for j := 0 to length(Cur_OVH_PhoneLines[i].Calls) - 1 do
   log('+' + Cur_OVH_PhoneLines[i].id + '>' + Cur_OVH_PhoneLines[i].Calls[j].id)
  else
  log('+' + Cur_OVH_PhoneLines[i].id + '> Aucun appel en cours');
  log('('+inttostr(ms)+'ms)');
}
