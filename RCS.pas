////////////////////////////////////////////////////////////////////////////////
// RCS.pas
// Interface to Railroad Control System (e.g. MTB, simulator, possibly DCC).
// (c) Jan Horacek, Michal Petrilak 2009-2017
// jan.horacek@kmz-brno.cz, engineercz@gmail.com
// license: Apache license v2.0
////////////////////////////////////////////////////////////////////////////////

{
   LICENSE:

   Copyright 2017 Jan Horacek, Michal Petrilak

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
  limitations under the License.
}

{
  TRCSIFace class allows its parent to load dll library with railroad control
  system and simply use its functions.
}

{
  WARNING:
   It is required to check whether functions in this class are really mapped to
   dll functions (the do not have to exist)
}

unit RCS;

interface

uses
  SysUtils, Classes, Windows, RCSErrors, Generics.Collections;

type
  ///////////////////////////////////////////////////////////////////////////
  // Events called from library to TRCSIFace:

  TStdNotifyEvent = procedure (Sender: TObject; data:Pointer); stdcall;
  TStdLogEvent = procedure (Sender: TObject; data:Pointer; logLevel:Integer; msg:PChar); stdcall;
  TStdErrorEvent = procedure (Sender: TObject; data:Pointer; errValue: word; errAddr: byte; errMsg:PChar); stdcall;
  TStdModuleChangeEvent = procedure (Sender: TObject; data:Pointer; module: byte); stdcall;

  ///////////////////////////////////////////////////////////////////////////
  // Events called from TRCSIFace to parent:

  TLogEvent = procedure (Sender: TObject; logLevel:Integer; msg:PChar) of object;
  TErrorEvent = procedure (Sender: TObject; errValue: word; errAddr: byte; errMsg:PChar) of object;
  TModuleChangeEvent = procedure (Sender: TObject; module: byte) of object;

  ///////////////////////////////////////////////////////////////////////////
  // Prototypes of functions called to library:

  TDllPGeneral = procedure(); stdcall;
  TDllFGeneral = function():Integer; stdcall;
  TDllFCardGeneral = function():Cardinal; stdcall;

  TDllFileIO = function(filename:PChar):Integer; stdcall;

  TDllSetLogLevel = procedure(loglevel:Cardinal); stdcall;
  TDllGetLogLevel = function(loglevel:Cardinal):Cardinal; stdcall;

  TDllOpenDevice = function(device:PChar; persist:boolean):Integer; stdcall;
  TDllBoolGetter = function():boolean; stdcall;
  TDllModuleGet = function(module, port:Cardinal):Integer; stdcall;
  TDllModuleSet = function(module, port:Cardinal; state:Integer):Integer; stdcall;
  TDllModuleBoolGetter = function(module:Cardinal):boolean; stdcall;
  TDllModuleIntGetter = function(module:Cardinal):Integer; stdcall;
  TDllModuleStringGetter = function(module:Cardinal; str:PChar; strMaxLen:Cardinal):Integer; stdcall;

  TDllDeviceSerialGetter = procedure(index:Integer; serial:PChar; serialLen:Cardinal); stdcall;
  TDllDeviceVersionGetter = function(version:PChar; versionMaxLen:Cardinal):Integer; stdcall;
  TDllVersionGetter = procedure(version:PChar; versionMaxLen:Cardinal); stdcall;

  TDllStdNotifyBind = procedure(event:TStdNotifyEvent; data:Pointer); stdcall;
  TDllStdLogBind = procedure(event:TStdLogEvent; data:Pointer); stdcall;
  TDllStdErrorBind = procedure(event:TStdErrorEvent; data:Pointer); stdcall;
  TDllStdModuleChangeBind = procedure(event:TStdModuleChangeEvent; data:Pointer); stdcall;

  ///////////////////////////////////////////////////////////////////////////

  TRCSInputState = (
    isOff = 0,
    isOn = 1,
    failure = RCS_MODULE_FAILED,
    notYetScanned = RCS_INPUT_NOT_YET_SCANNED
  );

  ///////////////////////////////////////////////////////////////////////////

  TRCSIFace = class
  private
    dllName: string;
    dllHandle: Cardinal;

    // ------------------------------------------------------------------
    // Functions called to library:

    // config file load/save
    dllFuncLoadConfig: TDllFileIO;
    dllFuncSaveConfig: TDllFileIO;

    // logging
    dllFuncSetLogLevelFile: TDllSetLogLevel;
    dllFuncSetLogLevel: TDllSetLogLevel;
    dllFuncGetLogLevel: TDllGetLogLevel;

    // dialogs
    dllFuncShowConfigDialog : TDllPGeneral;
    dllFuncHideConfigDialog : TDllPGeneral;

    // open/close
    dllFuncOpen : TDllFGeneral;
    dllFuncOpenDevice : TDllOpenDevice;
    dllFuncClose : TDllFGeneral;
    dllFuncOpened : TDllBoolGetter;

    // start/stop
    dllFuncStart : TDllFGeneral;
    dllFuncStop : TDllFGeneral;
    dllFuncStarted : TDllBoolGetter;

    // ports IO
    dllFuncGetInput : TDllModuleGet;
    dllFuncGetOutput : TDllModuleGet;
    dllFuncSetOutput : TDllModuleSet;
    dllFuncSetInput : TDllModuleSet;

    // devices
    dllFuncGetDeviceCount : TDllFGeneral;
    dllFuncGetDeviceSerial : TDllDeviceSerialGetter;

    // modules
    dllFuncIsModule : TDllModuleBoolGetter;
    dllFuncIsModuleFailure: TDllModuleBoolGetter;
    dllFuncGetModuleCount : TDllFCardGeneral;
    dllFuncGetModuleType : TDllModuleIntGetter;
    dllFuncGetModuleName : TDllModuleStringGetter;
    dllFuncGetModuleFW : TDllModuleStringGetter;

    // versions
    dllFuncGetDeviceVersion : TDllDeviceVersionGetter;
    dllFuncGetVersion : TDllVersionGetter;

    // ------------------------------------------------------------------
    // Events from TRCSIFace

    eBeforeOpen : TNotifyEvent;
    eAfterOpen : TNotifyEvent;
    eBeforeClose : TNotifyEvent;
    eAfterClose : TNotifyEvent;

    eBeforeStart : TNotifyEvent;
    eAfterStart : TNotifyEvent;
    eBeforeStop : TNotifyEvent;
    eAfterStop : TNotifyEvent;

    eOnError: TErrorEvent;
    eOnLog : TLogEvent;
    eOnInputChange : TModuleChangeEvent;
    eOnOutputChange : TModuleChangeEvent;
    eOnScanned : TNotifyEvent;

     procedure SetLibName(s: string);

  public

    unbound: TList<string>;                                                     // list of unbound functions

     constructor Create();
     destructor Destroy(); override;

     procedure LoadConfig(fn:string);
     procedure SaveConfig(fn:string);

     procedure Open();                                                           // otevrit zarizeni
     procedure OpenDevice(device:string; persist:boolean);
     procedure Close();                                                          // uzavrit zarizeni

     procedure Start();                                                          // spustit komunikaci
     procedure Stop();                                                           // zastavit komunikaci

     procedure SetOutput(module, port: Integer; state: Integer);                // nastavit vystupni port
     function GetInput(module, port: Integer): TRCSInputState;                   // vratit hodnotu na vstupnim portu
     procedure SetInput(module, port: Integer; State : Integer);                 // nastavit vstupni port (pro debug ucely)
     function GetOutput(module, port:Integer):Integer;                            // ziskani stavu vystupu

     procedure ShowConfigDialog();                                               // zobrazit konfiguracni dialog knihovny
     procedure HideConfigDialog();                                               // skryt konfiguracni dialog knihovny

     function GetDllVersion():string;                                         // vrati verzi MTBdrv drivery v knihovne
     function GetDeviceVersion():string;                                         // vrati verzi FW v MTB-USB desce

     function GetModuleName(module:Cardinal):string;                              // vrati jmeno modulu

     function IsModule(Module:Cardinal):boolean;                           // vrati jestli modul existuje
     function GetModuleType(Module:Cardinal):Integer;                              // vrati typ modulu
     function GetModuleFW(Module:Cardinal):string;                          // vrati verzi FW v modulu

     procedure LoadLib();                                                        // nacte knihovnu

     // eventy z TMTBIFace do rodice:
     property BeforeOpen:TNotifyEvent read eBeforeOpen write eBeforeOpen;
     property AfterOpen:TNotifyEvent read eAfterOpen write eAfterOpen;
     property BeforeClose:TNotifyEvent read eBeforeClose write eBeforeClose;
     property AfterClose:TNotifyEvent read eAfterClose write eAfterClose;

     property BeforeStart:TNotifyEvent read eBeforeStart write eBeforeStart;
     property AfterStart:TNotifyEvent read eAfterStart write eAfterStart;
     property BeforeStop:TNotifyEvent read eBeforeStop write eBeforeStop;
     property AfterStop:TNotifyEvent read eAfterStop write eAfterStop;

     property OnError:TErrorEvent read eOnError write eOnError;
     property OnLog:TLogEvent read eOnLog write eOnLog;
     property OnInputChanged:TModuleChangeEvent read eOnInputChange write eOnInputChange;
     property OnOutputChanged:TModuleChangeEvent read eOnOutputChange write eOnOutputChange;

     property OnScanned:TNotifyEvent read eOnScanned write eOnScanned;

     property Lib: string read dllName write SetLibName;

  end;


implementation

////////////////////////////////////////////////////////////////////////////////

constructor TRCSIFace.Create();
 begin
  inherited;
  Self.unbound := TList<string>.Create();
 end;

destructor TRCSIFace.Destroy();
 begin
  Self.unbound.Free();
  inherited;
 end;

////////////////////////////////////////////////////////////////////////////////

procedure TRCSIFace.SetLibName(s: string);
 begin
  if FileExists(s) then
    dllName := s
  else
    raise ERCSLibNotFound.Create('Library '+s+' not found!');
 end;

////////////////////////////////////////////////////////////////////////////////
// Events from dll library, these evetns must be declared as functions
// (not as functions of objects)

procedure dllBeforeOpen(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).BeforeOpen)) then TRCSIFace(data).BeforeOpen(TRCSIFace(data));
 end;

procedure dllAfterOpen(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).AfterOpen)) then TRCSIFace(data).AfterOpen(TRCSIFace(data));
 end;

procedure dllBeforeClose(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).BeforeClose)) then TRCSIFace(data).BeforeClose(TRCSIFace(data));
 end;

procedure dllAfterClose(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).AfterClose)) then TRCSIFace(data).AfterClose(TRCSIFace(data));
 end;

procedure dllBeforeStart(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).BeforeStart)) then TRCSIFace(data).BeforeStart(TRCSIFace(data));
 end;

procedure dllAfterStart(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).AfterStart)) then TRCSIFace(data).AfterStart(TRCSIFace(data));
 end;

procedure dllBeforeStop(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).BeforeStop)) then TRCSIFace(data).BeforeStop(TRCSIFace(data));
 end;

procedure dllAfterStop(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).AfterStop)) then TRCSIFace(data).AfterStop(TRCSIFace(data));
 end;

procedure dllOnError(Sender: TObject; data:Pointer; errValue: word; errAddr: byte; errMsg:PChar); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnError)) then TRCSIFace(data).OnError(TRCSIFace(data), errValue, errAddr, errMsg);
 end;

procedure dllOnLog(Sender: TObject; data:Pointer; logLevel:Integer; msg:PChar); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnLog)) then TRCSIFace(data).OnLog(TRCSIFace(data), logLevel, msg);
 end;

procedure dllOnInputChanged(Sender: TObject; data:Pointer; module:byte); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnInputChanged)) then TRCSIFace(data).OnInputChanged(TRCSIFace(data), module);
 end;

procedure dllOnOutputChanged(Sender: TObject; data:Pointer; module:byte); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnOutputChanged)) then TRCSIFace(data).OnOutputChanged(TRCSIFace(data), module);
 end;

procedure dllOnScanned(Sender: TObject; data:Pointer; module:byte); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnScanned)) then TRCSIFace(data).OnScanned(TRCSIFace(data));
 end;

////////////////////////////////////////////////////////////////////////////////
// Load dll library

procedure TRCSIFace.LoadLib();
var dllFuncStdNotifyBind: TDllStdNotifyBind;
    dllFuncOnErrorBind: TDllStdErrorBind;
    dllFuncOnLogBind: TDllStdLogBind;
    dllFuncOnChangedBind: TDllStdModuleChangeBind;
 begin
  Self.unbound.Clear();

  dllHandle := LoadLibrary(PChar(dllName));
  if (dllHandle = 0) then
    raise ERCSCannotLoadLib.Create('Library not loaded');

  // config file load/save
  dllFuncLoadConfig := TDllFileIO(GetProcAddress(dllHandle, 'LoadConfig'));
  if (not Assigned(dllFuncLoadConfig)) then unbound.Add('LoadConfig');
  dllFuncSaveConfig := TDllFileIO(GetProcAddress(dllHandle, 'SaveConfig'));
  if (not Assigned(dllFuncSaveConfig)) then unbound.Add('SaveConfig');

  // logging
  dllFuncSetLogLevelFile := TDllSetLogLevel(GetProcAddress(dllHandle, 'SetLogLevelFile'));
  if (not Assigned(dllFuncSetLogLevelFile)) then unbound.Add('SetLogLevelFile');
  dllFuncSetLogLevel     := TDllSetLogLevel(GetProcAddress(dllHandle, 'SetLogLevel'));
  if (not Assigned(dllFuncSetLogLevel)) then unbound.Add('SetLogLevel');
  dllFuncGetLogLevel     := TDllGetLogLevel(GetProcAddress(dllHandle, 'GetLogLevel'));
  if (not Assigned(dllFuncGetLogLevel)) then unbound.Add('GetLogLevel');

  // dialogs
  dllFuncShowConfigDialog := TDllPGeneral(GetProcAddress(dllHandle, 'ShowConfigDialog'));
  if (not Assigned(dllFuncShowConfigDialog)) then unbound.Add('ShowConfigDialog');
  dllFuncHideConfigDialog := TDllPGeneral(GetProcAddress(dllHandle, 'HideConfigDialog'));
  if (not Assigned(dllFuncHideConfigDialog)) then unbound.Add('HideConfigDialog');

  // open/close
  dllFuncOpen := TDllFGeneral(GetProcAddress(dllHandle, 'Open'));
  if (not Assigned(dllFuncOpen)) then unbound.Add('Open');
  dllFuncOpenDevice := TDllOpenDevice(GetProcAddress(dllHandle, 'OpenDevice'));
  if (not Assigned(dllFuncOpenDevice)) then unbound.Add('OpenDevice');
  dllFuncClose := TDllFGeneral(GetProcAddress(dllHandle, 'Close'));
  if (not Assigned(dllFuncClose)) then unbound.Add('Close');
  dllFuncOpened := TDllBoolGetter(GetProcAddress(dllHandle, 'Opened'));
  if (not Assigned(dllFuncOpened)) then unbound.Add('Opened');

  // start/stop
  dllFuncStart := TDllFGeneral(GetProcAddress(dllHandle, 'Start'));
  if (not Assigned(dllFuncStart)) then unbound.Add('Start');
  dllFuncStop := TDllFGeneral(GetProcAddress(dllHandle, 'Stop'));
  if (not Assigned(dllFuncStop)) then unbound.Add('Stop');
  dllFuncStarted := TDllBoolGetter(GetProcAddress(dllHandle, 'Started'));
  if (not Assigned(dllFuncStarted)) then unbound.Add('Started');

  // ports IO
  dllFuncGetInput := TDllModuleGet(GetProcAddress(dllHandle, 'GetInput'));
  if (not Assigned(dllFuncGetInput)) then unbound.Add('GetInput');
  dllFuncGetOutput := TDllModuleGet(GetProcAddress(dllHandle, 'GetOutput'));
  if (not Assigned(dllFuncGetOutput)) then unbound.Add('GetOutput');
  dllFuncSetOutput := TDllModuleSet(GetProcAddress(dllHandle, 'SetOutput'));
  if (not Assigned(dllFuncSetOutput)) then unbound.Add('SetOutput');
  dllFuncSetInput := TDllModuleSet(GetProcAddress(dllHandle, 'SetInput'));
  if (not Assigned(dllFuncSetInput)) then unbound.Add('SetInput');

  // devices
  dllFuncGetDeviceCount := TDllFGeneral(GetProcAddress(dllHandle, 'GetDeviceCount'));
  if (not Assigned(dllFuncGetDeviceCount)) then unbound.Add('GetDeviceCount');
  dllFuncGetDeviceSerial := TDllDeviceSerialGetter(GetProcAddress(dllHandle, 'GetDeviceSerial'));
  if (not Assigned(dllFuncGetDeviceSerial)) then unbound.Add('GetDeviceSerial');

  // modules
  dllFuncIsModule := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModule'));
  if (not Assigned(dllFuncIsModule)) then unbound.Add('IsModule');
  dllFuncIsModuleFailure := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModuleFailure'));
  if (not Assigned(dllFuncIsModuleFailure)) then unbound.Add('IsModuleFailure');
  dllFuncGetModuleCount := TDllFCardGeneral(GetProcAddress(dllHandle, 'GetModuleCount'));
  if (not Assigned(dllFuncGetModuleCount)) then unbound.Add('GetModuleCount');
  dllFuncGetModuleType := TDllModuleIntGetter(GetProcAddress(dllHandle, 'GetModuleType'));
  if (not Assigned(dllFuncGetModuleType)) then unbound.Add('GetModuleType');
  dllFuncGetModuleName := TDllModuleStringGetter(GetProcAddress(dllHandle, 'GetModuleName'));
  if (not Assigned(dllFuncGetModuleName)) then unbound.Add('GetModuleName');
  dllFuncGetModuleFW := TDllModuleStringGetter(GetProcAddress(dllHandle, 'GetModuleFW'));
  if (not Assigned(dllFuncGetModuleFW)) then unbound.Add('GetModuleFW');

  // versions
  dllFuncGetDeviceVersion := TDllDeviceVersionGetter(GetProcAddress(dllHandle, 'GetDeviceVersion'));
  if (not Assigned(dllFuncGetDeviceVersion)) then unbound.Add('GetDeviceVersion');
  dllFuncGetVersion := TDllVersionGetter(GetProcAddress(dllHandle, 'GetDriverVersion'));
  if (not Assigned(dllFuncGetVersion)) then unbound.Add('GetDriverVersion');

  // events open/close
  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeOpen'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeOpen, self)
  else unbound.Add('BindBeforeOpen');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterOpen'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterOpen, self)
  else unbound.Add('BindAfterOpen');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeClose'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeClose, self)
  else unbound.Add('BindBeforeClose');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterClose'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterClose, self)
  else unbound.Add('BindAfterClose');

  // events start/stop
  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeStart'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeStart, self)
  else unbound.Add('BindBeforeStart');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterStart'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterStart, self)
  else unbound.Add('BindAfterStart');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeStop'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeStop, self)
  else unbound.Add('BindBeforeStop');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterStop'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterStop, self)
  else unbound.Add('BindAfterStop');

  // other events
  dllFuncOnErrorBind := TDllStdErrorBind(GetProcAddress(dllHandle, 'BindOnError'));
  if (Assigned(dllFuncOnErrorBind)) then dllFuncOnErrorBind(@dllOnError, self)
  else unbound.Add('BindOnError');

  dllFuncOnLogBind := TDllStdLogBind(GetProcAddress(dllHandle, 'BindOnLog'));
  if (Assigned(dllFuncOnLogBind)) then dllFuncOnLogBind(@dllOnLog, self)
  else unbound.Add('BindOnLog');

  dllFuncOnChangedBind := TDllStdModuleChangeBind(GetProcAddress(dllHandle, 'BindOnInputChanged'));
  if (Assigned(dllFuncOnChangedBind)) then dllFuncOnChangedBind(@dllOnInputChanged, self)
  else unbound.Add('BindOnInputChanged');

  dllFuncOnChangedBind := TDllStdModuleChangeBind(GetProcAddress(dllHandle, 'BindOnOutputChanged'));
  if (Assigned(dllFuncOnChangedBind)) then dllFuncOnChangedBind(@dllOnOutputChanged, self)
  else unbound.Add('BindOnOutputChanged');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindOnScanned'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllOnScanned, self)
  else unbound.Add('BindOnScanned');
 end;

////////////////////////////////////////////////////////////////////////////////
// Parent should call these methods:

procedure TRCSIFace.ShowConfigDialog();
 begin
  if (Assigned(dllFuncShowConfigDialog)) then
    dllFuncShowConfigDialog()
  else
    raise ERCSFuncNotAssigned.Create('FFuncShowConfigDialog not assigned');
 end;

procedure TRCSIFace.HideConfigDialog();
 begin
  if (Assigned(dllFuncHideConfigDialog)) then
    dllFuncHideConfigDialog()
  else
    raise ERCSFuncNotAssigned.Create('FFuncHideConfigDialog not assigned');
 end;

function TRCSIFace.GetInput(module, port: Integer):TRCSInputState;
var tmp:Integer;
 begin
  if (not Assigned(dllFuncGetInput)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetInput not assigned');

  tmp := dllFuncGetInput(module, port);

  if (tmp = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (tmp = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module adderess: '+IntToStr(module)+'!')
  else if (tmp = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (tmp = RCS_GENERAL_EXCEPTION) then
    raise ERCSGeneralException.Create('General exception in RCS library!');

  Result := TRCSInputState(tmp);
 end;

procedure TRCSIFace.SetOutput(module, port: Integer; state: Integer);
var res:Integer;
 begin
  if (not Assigned(dllFuncSetOutput)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetOutput not assigned');

  res := dllFuncSetOutput(module, port, state);

  if (res = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if (res = RCS_MODULE_FAILED) then
    raise ERCSModuleFailed.Create('Module '+IntToStr(module)+' failed!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (res = RCS_INVALID_SCOM_CODE) then
    raise ERCSInvalidScomCode.Create('Invalid scom code : '+IntToStr(state)+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.SetInput(module, port: Integer; state: Integer);
var res:Integer;
 begin
  if (not Assigned(dllFuncSetInput)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetInput not assigned');

  res := dllFuncSetInput(module, port, state);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if (res = RCS_MODULE_FAILED) then
    raise ERCSModuleFailed.Create('Module '+IntToStr(module)+' failed!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

function TRCSIFace.GetOutput(module, port:Integer):Integer;
 begin
  if (not Assigned(dllFuncGetOutput)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetOutput not assigned');

  Result := dllFuncGetOutput(module, port);

  if (Result = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (Result = RCS_PORT_INVALID_NUMBER) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if (Result = RCS_MODULE_FAILED) then
    raise ERCSModuleFailed.Create('Module '+IntToStr(module)+' failed!')
  else if (Result = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (Result = RCS_GENERAL_EXCEPTION) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

function TRCSIFace.GetDeviceVersion():string;
const STR_LEN = 32;
var str:string[STR_LEN];
    res:Integer;
 begin
  if (not Assigned(dllFuncGetDeviceVersion)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetLibVersion not assigned');

  res := dllFuncGetDeviceVersion(@str, STR_LEN);

  if (res = RCS_DEVICE_DISCONNECTED) then
    raise ERCSNotOpened.Create('Device not opened, cannot read version!');

  Result := string(str);
 end;

function TRCSIFace.GetDllVersion():String;
const STR_LEN = 32;
var str:string[STR_LEN];
 begin
  if (not Assigned(dllFuncGetVersion)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetDriverVersion not assigned');

  dllFuncGetVersion(@str, STR_LEN);
  Result := string(str);
 end;

function TRCSIFace.IsModule(Module:Cardinal):boolean;
 begin
  if (Assigned(dllFuncIsModule)) then
    Result := dllFuncIsModule(Module)
  else
    raise ERCSFuncNotAssigned.Create('FFuncModuleExists not assigned');
 end;

function TRCSIFace.GetModuleType(Module:Cardinal):Integer;
 begin
  if (not Assigned(dllFuncGetModuleType)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleType not assigned');

  Result := dllFuncGetModuleType(Module);

  if (Result = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module address : '+IntToStr(Module)+'!');
 end;

function TRCSIFace.GetModuleName(Module:Cardinal):string;
const STR_LEN = 128;
var str:string[STR_LEN];
    res:Integer;
 begin
  if (not Assigned(dllFuncGetModuleName)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleName not assigned');

  res := dllFuncGetModuleName(Module, @str, STR_LEN);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module address : '+IntToStr(Module)+'!');

  Result := string(str);
 end;

procedure TRCSIFace.Open();
var res:Integer;
 begin
  if (not Assigned(dllFuncOpen)) then
    raise ERCSFuncNotAssigned.Create('FFuncOpen not assigned');

  res := dllFuncOpen();

  if (res = RCS_ALREADY_OPENNED) then
    raise ERCSAlreadyOpened.Create('Device already opened!')
  else if (res = RCS_CANNOT_OPEN_PORT) then
    raise ERCSCannotOpenPort.Create('Cannot open this port!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.OpenDevice(device:string; persist:boolean);
var res:Integer;
 begin
  if (not Assigned(dllFuncOpenDevice)) then
    raise ERCSFuncNotAssigned.Create('FFuncOpenDevice not assigned');

  res := dllFuncOpenDevice(PChar(device), persist);

  if (res = RCS_ALREADY_OPENNED) then
    raise ERCSAlreadyOpened.Create('Device already opened!')
  else if (res = RCS_CANNOT_OPEN_PORT) then
    raise ERCSCannotOpenPort.Create('Cannot open this port!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

procedure TRCSIFace.Close();
var res:Integer;
 begin
  if (not Assigned(dllFuncClose)) then
    raise ERCSFuncNotAssigned.Create('FFuncClose not assigned');

  res := dllFuncClose();

  if (res = RCS_NOT_OPENED) then
    raise ERCSNotOpened.Create('Device not opened!')
  else if (res = RCS_SCANNING_NOT_FINISHED) then
    raise ERCSScanningNotFinished.Create('Initial scanning of modules not finished, cannot close!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.Start();
var res:Integer;
begin
  if (not Assigned(dllFuncStart)) then
    raise ERCSFuncNotAssigned.Create('FFuncStart not assigned');

  res := dllFuncStart();

  if (res = RCS_ALREADY_STARTED) then
    raise ERCSAlreadyStarted.Create('Communication already started!')
  else if (res = RCS_FIRMWARE_TOO_LOW) then
    raise ERCSFirmwareTooLow.Create('RCS-PC module firware too low!')
  else if (res = RCS_NO_MODULES) then
    raise ERCSNoModules.Create('No modules found, cannot start!')
  else if (res = RCS_NOT_OPENED) then
    raise ERCSNotOpened.Create('Device not opened, cannot start!')
  else if (res = RCS_SCANNING_NOT_FINISHED) then
    raise ERCSScanningNotFinished.Create('Initial scanning of modules not finished, cannot start!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

procedure TRCSIFace.Stop();
var res:Integer;
begin
  if (not Assigned(dllFuncStop)) then
    raise ERCSFuncNotAssigned.Create('FFuncStop not assigned');

  res := dllFuncStop();

  if (res = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Device not started, cannot stop!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

function TRCSIFace.GetModuleFW(Module:Cardinal):string;
const STR_LEN = 16;
var str:string[STR_LEN];
    res:Integer;
 begin
  if (not Assigned(dllFuncGetModuleFW)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleFirmware not assigned');

  res := dllFuncGetModuleFW(Module, @str, STR_LEN);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module adderess: '+IntToStr(Module)+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

////////////////////////////////////////////////////////////////////////////////

procedure TRCSIFace.LoadConfig(fn:string);
var res:Integer;
begin
  if (not Assigned(dllFuncLoadConfig)) then
    raise ERCSFuncNotAssigned.Create('FFuncLoadConfig not assigned');

  res := dllFuncLoadConfig(PChar(fn));

  if (res = RCS_FILE_CANNOT_ACCESS) then
    raise ERCSCannotAccessFile.Create('Cannot read file '+fn+'!')
  else if (res = RCS_FILE_DEVICE_OPENED) then
    raise ERCSDeviceOpened.Create('Cannot reload config, device opened!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

procedure TRCSIFace.SaveConfig(fn:string);
var res:Integer;
begin
  if (not Assigned(dllFuncSaveConfig)) then
    raise ERCSFuncNotAssigned.Create('FFuncSaveConfig not assigned');

  res := dllFuncSaveConfig(PChar(fn));

  if (res = RCS_FILE_CANNOT_ACCESS) then
    raise ERCSCannotAccessFile.Create('Cannot write to file '+fn+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

////////////////////////////////////////////////////////////////////////////////

end.//unit

