unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ssl_openssl,Forms,
  Controls, Graphics, Dialogs, StdCtrls,synautil,
  FpJson, JSonParser, DCPsha1,httpsend, lclintf, strutils;

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

  end;

var
  Form1: TForm1;

const CRLF = #13#10;
const BASE_URL ='https://eu.api.ovh.com/1.0';
const OVH_URL_TIMESTAMP = '/auth/time';
const  OVH_AK = 'n0NhFz3JavSGlkZY';
const OVH_AS = 'anSVC8QqIujgUZS4pY42CwnV959iQ68G';


var OVH_CK:string;
var BillingAccount: String='jf91384-ovh-1';
var serviceName: String='0033428299336';


const OVH_TimeOut = 1500;

type OVH_Query = record
method : string;
mimeType: string;
url: String;
query : string;
body : string;
timestamp : string;
signature : string;
end;

type OVH_ResultCK = record
CK : string;
redirect:string;
end;

function getsha1hash(S: string): string;
function CreateOVHQuery(m,q,b:string):OVH_Query;
function Get_OVH_TimeStamp: string;
function Get_OVH(Query:OVH_QUERY): String;

implementation

{$R *.lfm}

{ TForm1 }

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


function CreateOVHQuery(m,q,b:string):OVH_Query;
begin
with Result do begin
method:=m;
query:=StringsReplace(q,
['{billingAccount}','{serviceName}'],
[BillingAccount,ServiceName],[RfReplaceAll]);
body:=b;
timestamp:=Get_Ovh_TimeStamp;
Form1.Memo1.lines.add(OVH_AS+'+'+OVH_CK+'+'+m+'+'+query+'+'+b+'+'+timestamp);
signature:='$1$'+GetSHA1Hash(OVH_AS+'+'+OVH_CK+'+'+m+'+'+query+'+'+b+'+'+timestamp);
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
  URL := BASE_URL+OVH_URL_TIMESTAMP;
  HTTP.Timeout := OVH_TimeOut;
  HTTP.Sock.ConnectionTimeout := OVH_TimeOut;
  if HTTP.HTTPMethod('GET', URL) then
  begin
    if HTTP.ResultCode <> 200 then
    begin
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


Function CustomOVHHeaders(query:OVH_QUERY):String;
begin
Result:=
'X-Ovh-Application: '+OVH_AK+CRLF+
'X-Ovh-Timestamp: '+Query.timestamp+CRLF+
'X-Ovh-Signature: '+Query.signature+CRLF+
'X-Ovh-Consumer: '+OVH_CK;
end;


function Get_OVH(Query:OVH_QUERY): String;
var
  Response: TStringList;
  URL: string;
  HTTP: THTTPSend;
  ParseResponse : TJSONData;
begin

  Response := TStringList.Create;
  HTTP := THTTPSend.Create;
  URL := Query.query;
  try
  HTTP.Document.Clear;
  HTTP.Headers.text := CustomOVHHeaders(Query);

  HTTP.mimeType := GetMimeFromExt(Query.mimeType);
  HTTP.Timeout := OVH_TimeOut;
  HTTP.Sock.ConnectionTimeout := OVH_TimeOut;
  form1.memo1.lines.add(HTTP.Headers.text);
  if HTTP.HTTPMethod(query.method, URL) then
  begin
    Response.LoadFromStream(HTTP.Document);
      Result := HTTP.Headers.text+CRLF+Response.Text;
    if HTTP.ResultCode <> 200 then
    begin
    end
    else
    begin

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
  Body: TStringlist;
  ParseResponse : TJSONData;
begin

  Response := TStringList.Create;
  Body := TstringList.create;
  HTTP := THTTPSend.Create;
  URL := BASE_URL+'/auth/credential';
  try
  HTTP.Document.Clear;
  HTTP.Headers.Add('X-Ovh-Application: '+OVH_AK);
  HTTP.Headers.Add('Content-Type: application/json');
  HTTP.MimeType:=getmimefromext('.json');
  Body.Clear;
  Body.Add('{"accessRules": [{"method": "GET","path": "/*"},{"method": "POST","path": "/*"}],"redirection":"https://www.jvet.fr/"}');
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
      Result.redirect := Parseresponse.FindPath('validationUrl').AsString;
      Result.CK := Parseresponse.FindPath('consumerKey').AsString;
    end;

  end;
  finally
  Response.Free;
  HTTP.Free;
  Body.free;
  end;
end;





procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.Button1Click(Sender: TObject);
begin

if OVH_CK='' then exit;
Memo1.lines.add( Get_OVH(
CreateOVHQuery('GET',BASE_URL+'/telephony/{billingAccount}/line/{serviceName}/calls','')));

end;

procedure TForm1.Button2Click(Sender: TObject);
var r:Ovh_ResultCK;
begin
 r:=Get_OVH_CK;
  Memo1.lines.add(r.CK+CRLF+r.redirect);//getsha1hash(Edit1.text);
  OpenURL(r.redirect);
  OVH_CK := r.CK;
end;

end.

