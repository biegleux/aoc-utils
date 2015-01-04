{*
 * revealfix tool fixes initial map revealing in aoe2 recorded games
 * with reveal map set to explored
 *
 * Copyright (c) 2009-2013 biegleux <biegleux[at]gmail[dot]com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 *}

program revealfix;

{$IFNDEF FPC}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  RecAnalyst;

const
  VERSION = '1.2';

procedure Usage;
var
  argv0: String;
begin
  argv0 := ExtractFileName(ParamStr(0));
	WriteLn(Format(
    'Usage: %s filename | -h' + #13#10 +
    #9 + 'filename -- input recorded game'#13#10 +
    '%s fixes initial map revealing in recorded games with reveal map set to explored'#13#10 +
    '%s v%s, copyright(c) 2009 biegleux'#13#10, [argv0, argv0, argv0, VERSION]));
end;

var
  RA: TRecAnalyst;

begin
  if ParamCount = 0 then
  begin
    Usage;
    Exit;
  end;

  RA := TRecAnalyst.Create;
  try
    try
      RA.FileName := ParamStr(1);
      RA.RevealFix;
    except
      on E: Exception do
        WriteLn(E.Message);
    end;
  finally
    RA.Free;
  end;
end.
