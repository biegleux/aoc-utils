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

unit RecAnalyst;

interface

{$IFDEF FPC}
  {$MODE Delphi}{$H+}
{$ENDIF}

uses
  Classes, SysUtils;

type
  TRevealMap = (rmNormal, rmExplored, rmAllVisible);
  TGameVersion = (gvUnknown, gvAOK, gvAOKTrial, gvAOK20, gvAOK20a, gvAOC,
    gvAOCTrial, gvAOC10, gvAOC10c);

  { TRecAnalyst }
  ERecAnalystException = class(Exception);

  TRecAnalyst = class
  protected
    FIsMgl: Boolean;
    FIsMgx: Boolean;

    FHeaderStream: TMemoryStream;
    FBodyStream: TMemoryStream;

    body_offset: LongInt;
    header_reveal_offset: LongInt;
    body_reveal_offset: LongInt;
    header_reveal_map: TRevealMap;
    body_reveal_map: TRevealMap;
    is_scenario: Boolean;
    game_version: TGameVersion;

    function ExtractStreams: Boolean;
    function AnalyzeHeader: Boolean;
    function AnalyzeBody: Boolean;
  public
    FileName: String;
    constructor Create;
    destructor Destroy; override;
    procedure RevealFix;
  end;

implementation

uses
  {$IFDEF FPC}paszlib{$ELSE}ZlibEx{$ENDIF};

resourcestring
  c_filenotspecified = 'No file has been specified for analyzing.';
  c_corruptedheader = 'Corruped header section.';
  c_cannotopenfile = 'Cannot open file "%s".';
  c_cannotreadsection = 'Cannot read sections.';
  c_cannotdecompress = 'Cannot decompress header section.';
  c_unknown = 'Unknown error';
  c_wrongfileext = 'Wrong file extenstion. Only mgx files are supported.';
  c_headerlenempty = 'Header length is zero.';
  c_triggerinfonotfound = '"Trigger Info" block has not been found.';

{$IFDEF FPC}
function ZDecompressStream2(inStream, outStream: TStream; windowBits: Integer): Integer; forward;
{$ENDIF}

const
  { version strings }
  VER_94 = 'VER 9.4';
  VER_93 = 'VER 9.3';
  TRL_93 = 'TRL 9.3';

{ TRecAnalyst }
constructor TRecAnalyst.Create;
begin
  with Self do
  begin
    FIsMgl := False;
    FIsMgx := False;

    FHeaderStream := TMemoryStream.Create;
    FBodyStream := TMemoryStream.Create;
    FileName := '';

    body_offset := 0;
    header_reveal_offset := 0;
    body_reveal_offset := 0;
    header_reveal_map := rmNormal;
    body_reveal_map := rmNormal;
    game_version := gvUnknown;
    is_scenario := False;
  end;
end;

destructor TRecAnalyst.Destroy;
begin
  FHeaderStream.Free;
  FBodyStream.Free;
end;

function TRecAnalyst.ExtractStreams: Boolean;
var
  ms, inStream: TMemoryStream;
  header_len, next_pos: Integer;
const
  MGL_EXT = '.mgl';
  MGX_EXT = '.mgx';
begin
  Result := False;

  if (FileName = '') then
    raise ERecAnalystException.Create (c_filenotspecified);

  if (LowerCase (ExtractFileExt (FileName)) = MGL_EXT) then
    FIsMgl := True
  else if (LowerCase (ExtractFileExt (FileName)) = MGX_EXT) then
    FIsMgx := True
  else
    raise ERecAnalystException.Create (c_wrongfileext);

  ms := TMemoryStream.Create;
  inStream := TMemoryStream.Create;
  try
    try
      ms.LoadFromFile (FileName);
      ms.Seek (0, soFromBeginning);

      if (ms.Read (header_len, SizeOf (header_len)) < SizeOf (header_len)) then
        raise ERecAnalystException.Create (c_corruptedheader);

      if (header_len = 0) then
        raise ERecAnalystException.Create (c_headerlenempty);

      { skip next_pos }
      if FIsMgx then
        ms.Read (next_pos, SizeOf (next_pos));

      if FIsMgx then
      begin
        Dec (header_len, SizeOf (next_pos) + SizeOf (header_len));
        body_offset := header_len + SizeOf (next_pos) + SizeOf (header_len);
      end else
      begin
        Dec (header_len, SizeOf (header_len));
        body_offset := header_len + SizeOf (header_len);
      end;

      inStream.CopyFrom (ms, header_len);
      instream.Seek (0, soFromBeginning);

      {$IFDEF FPC}
      if (ZDecompressStream2 (inStream, FHeaderStream, -15) < 0) then
        raise ERecAnalystException.Create (c_cannotdecompress);
      // zError (code)
      {$ELSE}
      ZDecompressStream2 (inStream, FHeaderStream, -15);
      {$ENDIF}

      if FIsMgx then
        FBodyStream.CopyFrom (ms, ms.Size - header_len - SizeOf (header_len) - 4 {next_pos})
      else
        FBodyStream.CopyFrom (ms, ms.Size - header_len - SizeOf (header_len));

      Result := True;
    except
      on ERecAnalystException do
        raise;
      on EReadError do
        raise ERecAnalystException.Create (c_cannotreadsection);
      on EFOpenError do
        raise ERecAnalystException.CreateFmt (c_cannotopenfile, [FileName]);
      {$IFNDEF FPC}
      on EZDecompressionError do
        raise ERecAnalystException.Create (c_cannotdecompress);
      {$ENDIF}
      else
        raise ERecAnalystException.Create (c_unknown);
    end;
  finally
    FreeAndNil (ms);
    FreeAndNil (inStream);
  end;
end;

function TRecAnalyst.AnalyzeHeader: Boolean;
const
  constant2: array[0..7] of Char = (#$9A, #$99, #$99, #$99, #$99, #$99, #$F9, #$3F);
var
  buff: array[0..7] of Byte;
  version: array[0..7] of Char;
  trigger_info_pos: LongInt;
  num_trigger: LongInt;
  reveal_map: LongInt;
  i, j: Integer;
  desc_len, num_effect, num_selected_object, text_len, sound_len: LongInt;
  name_len, num_condition: LongInt;
begin
  Result := False;
  FillChar (buff, SizeOf (buff), $00);

  with FHeaderStream do
  begin
    Seek (0, soFromBeginning);

    { getting version }
    FillChar (version, SizeOf (version), #0);
    Read (version, SizeOf (version));
    if (version = VER_94) then
      game_version := gvAOC
    else if (version = VER_93) then
      game_version := gvAOK
    else if (version = TRL_93) and FIsMgx then
      game_version := gvAOCTrial
    else if (version = TRL_93) and FIsMgl then
      game_version := gvAOKTrial
    else
      game_version := gvUnknown;

    case game_version of
      gvAOK, gvAOKTrial:
        begin
          FIsMgl := True;
          FIsMgx := False;
        end;
      gvAOC, gvAOCTrial:
        begin
          FIsMgl := False;
          FIsMgx := True;
        end;
    end;

    { getting Trigger_info }
    Seek (-SizeOf (constant2), soFromEnd);
    trigger_info_pos := 0;
    repeat
      Read (buff, SizeOf (constant2));
      if CompareMem (@buff, @constant2, SizeOf (constant2)) then
      begin
        trigger_info_pos := Position;
        Break;
      end;
      Seek (-(SizeOf (constant2) + 1), soFromCurrent);
    until (Position < 0);

    if (trigger_info_pos = 0) then
      raise ERecAnalystException.Create (c_triggerinfonotfound);

    { Trigger_info }
    Seek (trigger_info_pos + 1, soFromBeginning);

    Read (num_trigger, SizeOf (num_trigger));

    if (num_trigger <> 0) then
    begin
      { skip Trigger_info data }
      for i := 0 to num_trigger - 1 do
      begin
        Seek (18, soFromCurrent);
        Read (desc_len, SizeOf (desc_len));
        Seek (desc_len, soFromCurrent);
        Read (name_len, SizeOf (name_len));
        Seek (name_len, soFromCurrent);
        Read (num_effect, SizeOf (num_effect));
        for j := 0 to num_effect - 1 do
        begin
          Seek (24, soFromCurrent);
          Read (num_selected_object, SizeOf (num_selected_object));
          if num_selected_object = -1 then
            num_selected_object := 0;
          Seek (72, soFromCurrent);
          Read (text_len, SizeOf (text_len));
          Seek (text_len, soFromCurrent);
          Read (sound_len, SizeOf (sound_len));
          Seek (sound_len, soFromCurrent);
          Seek (num_selected_object * 4, soFromCurrent);
        end;
        Seek (num_effect * 4, soFromCurrent);
        Read (num_condition, SizeOf (num_condition));
        for j := 0 to num_condition - 1 do
          Seek (72, soFromCurrent);
        Seek (4 * num_condition, soFromCurrent);
      end;
      Seek (num_trigger * 4, soFromCurrent);
    end;

    { Other_data }
    Seek (9, soFromCurrent);

    header_reveal_offset := Position;
    Read (reveal_map, SizeOf (reveal_map));
    header_reveal_map := TRevealMap (reveal_map);

    Result := True;
  end;
end;

function TRecAnalyst.AnalyzeBody: Boolean;
var
  od_type, command, chat_len: LongInt;
  extra_sync, length: LongInt;
  reveal_map: LongInt;
begin
  Result := False;

  with FBodyStream do
  begin
    Seek (0, soFromBeginning);
    while (Position < Size - 3) do
    begin
      if (Position = 0) and FIsMgl then
        od_type := $04
      else
        Read (od_type, SizeOf (od_type));

      { ope_data types: 4(Game_start or Chat), 2(Sync), or 1(Command) }
      case od_type of
        $04, $03:
          begin
            Read (command, SizeOf (command));
            if (command = $01F4) then
            begin
              { Game_start }
              Seek (8, soFromCurrent);

              body_reveal_offset := Position;
              Read (reveal_map, SizeOf (reveal_map));
              body_reveal_map := TRevealMap (reveal_map);

              WriteLn (Format ('Reveal map data offset found at 0x%x.', [body_offset + body_reveal_offset]));
              Result := True;
              Exit;
            end else
              if (command = -1) then
              begin
                { Chat }
                Read (chat_len, SizeOf (chat_len));
                Seek (chat_len, soFromCurrent);
              end;
            end;
        $02:  begin
                { Sync }
                Seek (4, soFromCurrent);
                Read (extra_sync, SizeOf (extra_sync));
                if (extra_sync = 0) then
                  Seek (28, soFromCurrent);
                Seek (12, soFromCurrent);
              end;
        $01:  begin
                { Command }
                Read (length, SizeOf (length));
                Seek (length + 4, soFromCurrent);
              end;
        else  begin
                { shouldn't occure, just to prevent unexpected endless cycling }
                Seek (1, soFromCurrent);
              end;
      end;
    end;  { endwhile }
  end;
  Result := True;
end;

procedure TRecAnalyst.RevealFix;
var
  fs: TFileStream;
  reveal_map: LongInt;
  fh, fdate, fixed: Integer;
begin
  if not ExtractStreams then
    Exit;

  if not AnalyzeHeader then
    Exit;

  if (body_offset = 0) then
  begin
    WriteLn ('Body section offset has not been found.');
    Exit;
  end;

  if (header_reveal_offset = 0) then
  begin
    WriteLn ('Reveal map data offset has not been found in header section.');
    Exit;
  end;

  if (header_reveal_map <> rmExplored) then
  begin
    WriteLn ('Reveal map other than Explored has been detected.');
    Exit;
  end;

  WriteLn ('Getting reveal map data offset in body section...');

  if not AnalyzeBody then
    Exit;

  if (body_reveal_offset = 0) then
  begin
    WriteLn ('Reveal map data offset has not been found in body section.');
    Exit;
  end;

  if (body_reveal_map = rmAllVisible) then
  begin
    WriteLn ('Reveal map data seems to be OK.');
    Exit;
  end;

  { try to fix }
  { Explored -> Owner: All Visible, Others: Normal }
  WriteLn ('Fixing file...');

  fixed := 0; fdate := 0;
  fh := FileOpen (FileName, fmOpenRead);
  if (fh > 0) then
    fdate := FileGetDate (fh);
  FileClose(fh);

  fs := TFileStream.Create (FileName, fmOpenWrite);
  try
    fs.Seek (body_offset + body_reveal_offset, soFromBeginning);
    reveal_map := Ord (rmAllVisible);
    fs.Write (reveal_map, SizeOf (reveal_map));
    WriteLn ('Done!');
    fixed := 1;
  finally
    fs.Free;
  end;

  if (fdate <> 0) and (fixed = 1) then
    FileSetDate (FileName, fdate);
end;
{$IFDEF FPC}
function ZDecompressStream2(inStream, outStream: TStream; windowBits: Integer): Integer;
const
  bufferSize = 32768;
var
  zstream: TZStream;
  zresult: Integer;
  inBuffer: array [0..bufferSize-1] of Byte;
  outBuffer: array [0..bufferSize-1] of Byte;
  outSize: Integer;
begin
  Result := Z_OK;
  FillChar (zstream, SizeOf (zstream), 0);

  zresult := InflateInit2 (zstream, windowBits);
  if (zresult < 0) then
  begin
    Result := zresult;
    Exit;
  end;

  zresult := Z_STREAM_END;

  zstream.avail_in := inStream.Read (inBuffer, bufferSize);

  while zstream.avail_in > 0 do
  begin
    zstream.next_in := inBuffer;

    repeat
      zstream.next_out := outBuffer;
      zstream.avail_out := bufferSize;

      zresult := inflate (zstream, Z_NO_FLUSH);
      if (zresult < 0) then
      begin
        Result := zresult;
        Exit;
      end;

      outSize := bufferSize - zstream.avail_out;

      outStream.Write (outBuffer, outSize);
    until (zresult = Z_STREAM_END) or (zstream.avail_in = 0);

    if zresult <> Z_STREAM_END then
    begin
      zstream.avail_in := inStream.Read (inBuffer, bufferSize);
    end
    else if zstream.avail_in > 0 then
    begin
      inStream.Position := inStream.Position - zstream.avail_in;
      zstream.avail_in := 0;
    end;
  end;

  while zresult <> Z_STREAM_END do
  begin
    zstream.next_out := outBuffer;
    zstream.avail_out := bufferSize;

    zresult := inflate (zstream, Z_FINISH);
    if (zresult < 0) then
    begin
      { TODO: check why this sometimes flushes an error for fpc }
      //Result := zresult;
      Result := Z_OK;
      Exit;
    end;

    outSize := bufferSize - zstream.avail_out;

    outStream.Write (outBuffer, outSize);
  end;

  zresult := inflateEnd (zstream);
  if (zresult < 0) then
  begin
    Result := zresult;
    Exit;
  end;
end;
{$ENDIF}
end.
