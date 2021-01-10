unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ssl_openssl, Forms,
  Controls, Graphics, Dialogs, StdCtrls, synautil,
  FpJson, JSonParser, DCPsha1, httpsend, lclintf, ExtCtrls, strutils,
  inifiles, DateUtils;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Memo1: TMemo;

    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);

  private

  public
  procedure OVHTimerEvent(Sender:TObject);
  end;

var
  Form1: TForm1;

var  ovhtimer: Ttimer;
const
  CRLF = #13#10;

const
  BASE_URL = 'https://eu.api.ovh.com/1.0';

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
  BillingAccount: string;


const
  OVH_TimeOut = 1500;

type
  OVH_Query = record
    method: string;
    mimeType: string;
    url: string;
    query: string;
    body: string;
    timestamp: string;
    signature: string;
  end;

type
  OVH_ResultCK = record
    CK: string;
    validationUrl: string;
    state: string;
  end;

type
  Call_state = (idle, calling);

type
  OVH_Call = record
    id: string;
    phone_number: string;
    state: Call_state;
  end;

type
  OVH_Calls = array of OVH_Call;

type
  OVH_PhoneLine = record
    id: string;
    Calls: OVH_Calls;
  end;

type
  OVH_PhoneLines = array of OVH_PhoneLine;

var
  Cur_OVH_Phonelines: OVH_PhoneLines;

function getsha1hash(S: string): string;
function CreateOVHQuery(m, q, b: string; ServiceName: string = ''): OVH_Query;
function Get_OVH_TimeStamp: string;
function OVHClient(Query: OVH_QUERY): string;

implementation

{$R *.lfm}

{ TForm1 }

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


function CreateOVHQuery(m, q, b: string; ServiceName: string = ''): OVH_Query;
begin
  with Result do
  begin
    method := m;
    query := StringsReplace(q, ['{billingAccount}', '{serviceName}'],
      [BillingAccount, ServiceName], [RfReplaceAll]);
    body := b;
    timestamp := Get_Ovh_TimeStamp;
    signature := '$1$' + GetSHA1Hash(OVH_AS + '+' + OVH_CK + '+' +
      m + '+' + query + '+' + b + '+' + timestamp);
  end;
end;

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

function Get_OVH_TimeStamp: string;
var
  Response: TStringList;
  URL: string;
  HTTP: THTTPSend;
begin
  Result := '';
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
        log(URL + CRLF + HTTP.Headers.Text + CRLF + Result);
      end
      else
      begin
        Response.LoadFromStream(HTTP.Document);
        Result := response[0];
      end;
    end;
  finally
    Response.Free;
    HTTP.Free;
  end;
end;


function CustomOVHHeaders(query: OVH_QUERY): string;
begin
  Result :=
    'X-Ovh-Application: ' + OVH_AK + CRLF + 'X-Ovh-Timestamp: ' +
    Query.timestamp + CRLF + 'X-Ovh-Signature: ' + Query.signature +
    CRLF + 'X-Ovh-Consumer: ' + OVH_CK;
end;


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
  Body := TStringList.Create;
  URL := Query.query;
  try
    HTTP.Document.Clear;
    HTTP.Headers.Text := CustomOVHHeaders(Query);
    Body.Clear;
    Body.Add(Query.body);
    if Query.body <> '' then
      Body.SaveToStream(HTTP.Document);

    HTTP.mimeType := GetMimeFromExt(Query.mimeType);
    HTTP.Timeout := OVH_TimeOut;
    HTTP.Sock.ConnectionTimeout := OVH_TimeOut;
    if HTTP.HTTPMethod(query.method, URL) then
    begin
      if HTTP.ResultCode = 200 then
      begin
        Response.LoadFromStream(HTTP.Document);
        Result := (Response[0]);
      end
      else
      begin
        log(URL + CRLF + HTTP.Headers.Text + CRLF + Result);
      end;
    end;
  finally
    Response.Free;
    HTTP.Free;
    Body.Free;
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
      '{"accessRules": [{"method": "GET","path": "/*"},{"method": "POST","path": "/*"}],"redirection":"https://www.jvet.fr/"}');
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




function GetOVHPhoneLinesIds(lines:string=''): boolean;
var
  i: integer;
var
  a: TJSONData;
  c: TJSONArray;
var
  rs: string;
begin
  Result := False;
  Setlength(Cur_OVH_PhoneLines, 0);
  try
    if lines=''  then
    rs := (OVHClient(CreateOVHQuery('GET', BASE_URL +
      '/telephony/{billingAccount}/line', '')))
      else rs:=lines;
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
  end;
  Result := True;
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
        '/telephony/{billingAccount}/line/{serviceName}/calls', '', Cur_OVH_PhoneLines[i].id)));
      if a <> nil then
      begin
        c := TJSONArray(a);
        Setlength(Cur_OVH_PhoneLines[i].Calls, 0);
        for j := 0 to (c.Count - 1) do
        begin
          Setlength(Cur_OVH_PhoneLines[i].Calls, j + 1);
          with Cur_OVH_Phonelines[i].Calls[j] do
          begin
            id := c.items[j].AsString;
          end;
        end;
      end;

    end;
  finally
  end;
  Result := True;
end;


Procedure TForm1.OVHTimerEvent(Sender:TObject);
var
  a, b: TJSONData;
var
  c: TJSONArray;
var
  s, rs: string;
var
  i, j: integer;
  t1,t2 : TDateTime;
  ms:integer;
begin
  Enabled:=false;
  Application.Processmessages;
  try
  t1:=now;
  GetOVHPhoneLinesIds(ParamLines);
  GetOVHPhoneCallsIds;
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


  finally
  Enabled:=True;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
OVHTimer.Enabled:=Not OVHTimer.Enabled;
Case OVHTimer.Enabled of
  False:log('La détection des appels est désactivée');
  True:log('La détection des appels est activée');
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

procedure TForm1.FormCreate(Sender: TObject);
begin
  params := ExtractFilePath(ParamStr(0)) + 'params.ini';
  OVH_CK := getiniparam(params, 'Params', 'consumerKey');
  billingAccount := getiniparam(params, 'Params', 'billingAccount');
  ParamLines := getiniparam(params, 'Params', 'lines');
  OVHTimer := TTimer.create(self);
  with OVHTimer do begin
  Interval:=2000;
  Enabled:=False;
  OnTimer:=@OVHTimerEvent;
  end;
end;

end.
