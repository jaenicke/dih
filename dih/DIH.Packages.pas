(*
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *)
unit DIH.Packages;

interface

uses
  System.SysUtils, System.Win.Registry, Winapi.Windows,
  DIH.Types, DIH.Logger, DIH.Placeholders;

type
  TDIHPackageManager = class
  private
    FLogger: TDIHLogger;
    FResolver: TDIHPlaceholderResolver;
    function GetKnownPackagesKey(APlatform: TDIHPlatform): string;
  public
    constructor Create(ALogger: TDIHLogger; AResolver: TDIHPlaceholderResolver);
    procedure RegisterPackages(const APackages: TArray<TDIHPackageEntry>; APlatform: TDIHPlatform);
    procedure UnregisterPackages(const APackages: TArray<TDIHPackageEntry>; APlatform: TDIHPlatform);
  end;

implementation

{ TDIHPackageManager }

constructor TDIHPackageManager.Create(ALogger: TDIHLogger; AResolver: TDIHPlaceholderResolver);
begin
  inherited Create;
  FLogger := ALogger;
  FResolver := AResolver;
end;

function TDIHPackageManager.GetKnownPackagesKey(APlatform: TDIHPlatform): string;
begin
  Result := FResolver.Resolve('{#BDS}') + '\Known Packages';
end;

procedure TDIHPackageManager.RegisterPackages(const APackages: TArray<TDIHPackageEntry>;
  APlatform: TDIHPlatform);
var
  Reg: TRegistry;
  Pkg: TDIHPackageEntry;
  BplPath, RegKey: string;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    RegKey := GetKnownPackagesKey(APlatform);

    if not Reg.OpenKey(RegKey, True) then
    begin
      FLogger.Error('Failed to open Known Packages registry key');
      Exit;
    end;

    try
      for Pkg in APackages do
      begin
        if not (APlatform in Pkg.Platforms) then
          Continue;

        BplPath := FResolver.ResolveKeepEnvVars(Pkg.BplPath);
        Reg.WriteString(BplPath, Pkg.Description);
        FLogger.Detail('Registered package: %s (%s)', [ExtractFileName(BplPath), Pkg.Description]);
      end;
    finally
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TDIHPackageManager.UnregisterPackages(const APackages: TArray<TDIHPackageEntry>;
  APlatform: TDIHPlatform);
var
  Reg: TRegistry;
  Pkg: TDIHPackageEntry;
  BplPath, RegKey: string;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    RegKey := GetKnownPackagesKey(APlatform);

    if not Reg.OpenKey(RegKey, False) then
      Exit;

    try
      for Pkg in APackages do
      begin
        if not (APlatform in Pkg.Platforms) then
          Continue;

        BplPath := FResolver.ResolveKeepEnvVars(Pkg.BplPath);
        if Reg.ValueExists(BplPath) then
        begin
          Reg.DeleteValue(BplPath);
          FLogger.Detail('Unregistered package: %s', [ExtractFileName(BplPath)]);
        end;
      end;
    finally
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

end.
