{-# LANGUAGE OverloadedStrings #-}
module Test where

import Codec.Xlsx
import Codec.Xlsx.Writer
import Data.Time.Calendar
import Data.Time.LocalTime
import Text.XML as X
import Text.XML.Cursor
import Data.Maybe (listToMaybe)



xText i t = Cell{cellIx=i,cellValue=Just $ CellText t,cellStyle=Just 0}
xDate i d = Cell{cellIx=i,cellValue=Just $ CellLocalTime d,cellStyle=Just 0}
xDouble i d = Cell{cellIx=i,cellValue=Just $ CellDouble d,cellStyle=Just 0}

test = writeXlsxStyles "test.xlsx" styles [sheet1, sheet2]
  where
    sheet1 = [[xText ("A", 1) "column1", xText ("B", 1) "column2", xText ("D", 1) "column4"],
              [xDate ("A", 2) $ LocalTime (fromGregorian 2012 05 06) (TimeOfDay 7 30 50), xDouble ("C", 2) 42.12345, xText  ("D", 2) "False"]]
    sheet2 = [[xText ("A", 1) "column1", xText ("B", 1) "column2", xText ("C", 1) "column2"]]

styles = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\
\<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><numFmts count=\"1\"><numFmt formatCode=\"GENERAL\" numFmtId=\"164\"/></numFmts><fonts count=\"4\"><font><name val=\"Courier New\"/><charset val=\"1\"/><family val=\"2\"/><sz val=\"10\"/></font><font><name val=\"Arial\"/><family val=\"0\"/><sz val=\"10\"/></font><font><name val=\"Arial\"/><family val=\"0\"/><sz val=\"10\"/></font><font><name val=\"Arial\"/><family val=\"0\"/><sz val=\"10\"/></font></fonts><fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills><borders count=\"1\"><border diagonalDown=\"false\" diagonalUp=\"false\"><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count=\"20\"><xf applyAlignment=\"true\" applyBorder=\"true\" applyFont=\"true\" applyProtection=\"true\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"164\"><alignment horizontal=\"general\" indent=\"0\" shrinkToFit=\"false\" textRotation=\"0\" vertical=\"bottom\" wrapText=\"false\"/><protection hidden=\"false\" locked=\"true\"/></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"2\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"2\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"0\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"43\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"41\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"44\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"42\"></xf><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"true\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"1\" numFmtId=\"9\"></xf></cellStyleXfs><cellXfs count=\"1\"><xf applyAlignment=\"false\" applyBorder=\"false\" applyFont=\"false\" applyProtection=\"false\" borderId=\"0\" fillId=\"0\" fontId=\"0\" numFmtId=\"164\" xfId=\"0\"></xf></cellXfs><cellStyles count=\"6\"><cellStyle builtinId=\"0\" customBuiltin=\"false\" name=\"Normal\" xfId=\"0\"/><cellStyle builtinId=\"3\" customBuiltin=\"false\" name=\"Comma\" xfId=\"15\"/><cellStyle builtinId=\"6\" customBuiltin=\"false\" name=\"Comma [0]\" xfId=\"16\"/><cellStyle builtinId=\"4\" customBuiltin=\"false\" name=\"Currency\" xfId=\"17\"/><cellStyle builtinId=\"7\" customBuiltin=\"false\" name=\"Currency [0]\" xfId=\"18\"/><cellStyle builtinId=\"5\" customBuiltin=\"false\" name=\"Percent\" xfId=\"19\"/></cellStyles></styleSheet>"

test2 = do
  doc <- X.parseLBS def xml
  let c = fromDocument doc
  print $ listToMaybe $ c $// element "bar" >=> attribute "foo"

xml = "<x>\
\   <x>\
\       <y>\
\           <x>\
\               <bar foo=\"1\"/>\
\           </x>\
\           <bar foo=\"2\"/>\
\       </y>\
\       <bar foo=\"3\"/>\
\   </x>\
\   <bar foo=\"4\"/>\
\</x>"