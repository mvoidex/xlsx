{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE TupleSections #-}

module Codec.Xlsx.Parser(
  xlsx,
  sheet,
  cellSource,
  sheetRowSource,
  sheetDataSource,
  sheetSource,
  onlyText, convertToText,

  Row, MapRow
  ) where

import           Control.Applicative
import           Control.Monad (join)
import           Control.Monad.IO.Class()
import           Data.Function (on)
import qualified Data.IntMap as M
import qualified Data.IntSet as S
import           Data.List
import qualified Data.Map as Map
import           Data.Maybe
import           Data.Ord
import           Prelude hiding (sequence)

import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Read as T
import qualified Data.ByteString.Lazy as L
import           Data.ByteString.Lazy.Char8()

import qualified Codec.Archive.Zip as Zip
import           Data.Conduit
import qualified Data.Conduit.List as CL
import           Data.Conduit.Util hiding (zip)
import           Data.XML.Types
import           System.FilePath
import           Text.XML as X
import           Text.XML.Cursor
import qualified Text.XML.Stream.Parse as Xml

import           Codec.Xlsx

type Row = Map.Map (Maybe CellValue) (Maybe CellValue)

type MapRow = Map.Map Text Text


-- | Read archive and preload 'Xlsx' fields
xlsx :: FilePath -> IO Xlsx
xlsx fname = do
  ar <- Zip.toArchive <$> L.readFile fname
  ss <- getSharedStrings ar
  st <- getStyles ar
  ws <- getWorksheetFiles ar
  return $ Xlsx ar ss st ws


-- | Get data from specified worksheet as conduit source.
cellSource :: MonadThrow m => Xlsx -> Int -> [Text] -> Source m [Cell]
cellSource x sheetN cols  =  getSheetCells x sheetN
                        $= filterColumns (S.fromList $ map col2int cols)
                        $= groupRows
                        $= reverseRows


decimal :: Monad m => Text -> m Int
decimal t = case T.decimal t of
  Right (d, _) -> return d
  _ -> fail "invalid decimal"

rational :: Monad m => Text -> m Double
rational t = case T.rational t of
  Right (r, _) -> return r
  _ -> fail "invalid rational"


sheet :: MonadThrow m => Xlsx -> Int -> m Worksheet
sheet Xlsx{xlArchive=ar, xlSharedStrings=ss, xlWorksheetFiles=sheets} sheetN
  | sheetN < 0 || sheetN >= length sheets
    = fail "parseSheet: Invalid sheet number"
  | otherwise
    = collect parse
  where
    filename = wfPath $ sheets !! sheetN
    sName = wfName $ sheets !! sheetN
    file = fromJust $ Zip.fromEntry <$> Zip.findEntryByPath filename ar
    doc = case parseLBS def file of
      Left _ -> error "could not read file"
      Right d -> d
    tc :: Cursor
    tc = fromDocument doc
    parse = (tc $/ parseColumns, tc $/ parseRows)
    parseColumns :: Cursor -> [ColumnsWidth]
    parseColumns = element (n"cols") &/ element (n"col") >=> parseColumn
    parseColumn :: Cursor -> [ColumnsWidth]
    parseColumn c = do
      min <- c $| attribute "min" >=> decimal
      max <- c $| attribute "max" >=> decimal
      width <- c $| attribute "width" >=> rational
      return $ ColumnsWidth min max width
    parseRows :: Cursor -> [(Int, Maybe Double, [(Int, Int, CellData)])]
    parseRows = element (n"sheetData") &/ element (n"row") >=> parseRow
    parseRow c = do
      r <- c $| attribute "r" >=> decimal
      let ht = if attribute "customHeight" c == ["true"] 
               then listToMaybe $ c $| attribute "ht" >=> rational
               else Nothing
      return (r, ht, c $/ element (n"c") >=> parseCell)
    parseCell :: Cursor -> [(Int, Int, CellData)]
    parseCell cell = do
      (c, r) <- T.span (>'9') <$> (cell $| attribute "r")
      return (col2int c, int r, CellData s d)
      where
        s = listToMaybe $ cell $| attribute "s" >=> decimal
        t = fromMaybe "n" $ listToMaybe $ cell $| attribute "t"
        d = listToMaybe $ cell $/ element (n"v") &/ content >=> extractValue
        extractValue v = case t of
          "n" ->
            case T.rational v of
              Right (d, _) -> [CellDouble d]
              _ -> []
          "s" ->
            case T.decimal v of
              Right (d, _) -> maybeToList $ fmap CellText $ M.lookup d ss
              _ -> []
          _ -> []
    collect (cw, rd) = return $ Worksheet sName minX maxX minY maxY cw rowMap cellMap
      where
        (rowMap, (minX, maxX, minY, maxY, cellMap)) = foldr collectRow rInit rd
        rInit = (Map.empty, (maxBound, minBound, maxBound, minBound, Map.empty))
        collectRow (_, Nothing, cells) (rowMap, cellData) = 
          (rowMap, foldr collectCell cellData cells)
        collectRow (n, Just h, cells) (rowMap, cellData) = 
          (Map.insert n h rowMap, foldr collectCell cellData cells)
        collectCell (x, y, cd) (minX, maxX, minY, maxY, cellMap) =
          (min minX x, max maxX x, min minY y, max maxY y, Map.insert (x,y) cd cellMap)
    

-- | Get all rows from specified worksheet.
sheetRowSource :: MonadThrow m => Xlsx -> Int -> Source m MapRow
sheetRowSource x sheetN
  =  getSheetCells x sheetN
  $= groupRows
  $= reverseRows
  $= mkMapRows

-- | Get all rows from specified worksheet without converting to text
sheetDataSource :: MonadThrow m => Xlsx -> Int -> Source m Row
sheetDataSource x sheetN
  =  getSheetCells x sheetN
  $= groupRows
  $= reverseRows
  $= mkDataRows

-- | Get all rows from specified worksheet with convert to text
sheetSource :: MonadThrow m => Xlsx -> Int -> (Maybe CellValue -> Text) -> (Maybe CellValue -> Text) -> Source m MapRow
sheetSource x sheetN convertHeader convertData = sheetDataSource x sheetN $= CL.map convertMap where
  convertMap = Map.map convertData . Map.mapKeys convertHeader

-- | Get only text
onlyText :: Maybe CellValue -> Text
onlyText Nothing = ""
onlyText (Just (CellText txt)) = txt
onlyText _ = ""

-- | Try convert CellValue to text with 'show'
convertToText :: Maybe CellValue -> Text
convertToText Nothing = ""
convertToText (Just (CellText txt)) = txt
convertToText (Just (CellDouble d)) = T.pack $ show d
convertToText (Just (CellLocalTime tm)) = T.pack $ show tm

-- | Make 'Conduit' from 'mkMapRowsSink'.
mkMapRows :: Monad m => Conduit [Cell] m MapRow
mkMapRows = CL.sequence mkMapRowsSink =$= CL.concatMap id

-- | Make 'Conduit' from 'mkCellRowsSink'
mkDataRows :: Monad m => Conduit [Cell] m Row
mkDataRows = CL.sequence mkDataRowsSink =$= CL.concatMap id

-- | Make 'MapRow' from list of 'Cell's.
mkMapRowsSink :: Monad m => Consumer [Cell] m [MapRow]
mkMapRowsSink = do
    header <- fromMaybe [] <$> CL.head
    rows   <- CL.consume

    return $ map (mkMapRow header) rows
  where
    mkMapRow header row = Map.fromList $ zipCells header row

    zipCells :: [Cell] -> [Cell] -> [(Text, Text)]
    zipCells []            _          = []
    zipCells header        []         = map (\h -> (txt h, "")) header
    zipCells header@(h:hs) row@(r:rs) =
        case comparing (fst . cellIx) h r of
          LT -> (txt h , ""   ) : zipCells hs     row
          EQ -> (txt h , txt r) : zipCells hs     rs
          GT -> (""    , txt r) : zipCells header rs

    txt = fromMaybe "" . cv
    cv Cell{cellData=CellData{cdValue=Just(CellText t)}} = Just t
    cv _ = Nothing

-- | Make 'Row' from list of 'Cell's
mkDataRowsSink :: Monad m => Consumer [Cell] m [Row]
mkDataRowsSink = do
  header <- fromMaybe [] <$> CL.head
  rows <- CL.consume

  return $ map (mkRow header) rows

  where
    mkRow header row = Map.fromList $ zipCells header row

    zipCells :: [Cell] -> [Cell] -> [(Maybe CellValue, Maybe CellValue)]
    zipCells [] _ = []
    zipCells header [] = map (\h -> (getData h, Nothing)) header
    zipCells header@(h:hs) row@(r:rs) =
      case comparing (fst . cellIx) h r of
        LT -> (getData h, Nothing) : zipCells hs row
        EQ -> (getData h, getData r) : zipCells hs rs
        GT -> (Nothing, getData r) : zipCells header rs

    getData Cell{cellData=CellData{cdValue=cd}} = cd

reverseRows :: Monad m => Conduit [a] m [a]
reverseRows = CL.map reverse
groupRows = CL.groupBy ((==) `on` (snd.cellIx))
filterColumns cs = CL.filter ((`S.member` cs) . col2int . fst . cellIx)


getSheetCells
 :: MonadThrow m => Xlsx -> Int -> Source m Cell
getSheetCells (Xlsx{xlArchive=ar, xlSharedStrings=ss, xlWorksheetFiles=sheets}) sheetN
  | sheetN < 0 || sheetN >= length sheets
    = error "parseSheet: Invalid sheet number"
  | otherwise
    = case xmlSource ar (wfPath $ sheets !! sheetN) of
      Nothing -> error "An impossible happened"
      Just xml -> xml $= mkXmlCond (getCell ss)


-- | Parse single cell from xml stream.
getCell
 :: MonadThrow m => M.IntMap Text -> Consumer Event m (Maybe Cell)
getCell ss = Xml.tagName (n"c") cAttrs cParser
  where
    cAttrs = do
      cellIx  <- Xml.requireAttr  "r"
      style   <- Xml.optionalAttr "s"
      typ <- Xml.optionalAttr "t"
      Xml.ignoreAttrs
      return (cellIx,style,typ)

    maybeCellDouble Nothing = Nothing
    maybeCellDouble (Just t) = either (const Nothing) (\(d,_) -> Just (CellDouble d)) $ T.rational t

    cParser (ix,style,typ) = do
      val <- case typ of
          Just "inlineStr" -> liftA (fmap CellText) (tagSeq ["is", "t"])
          Just "s" -> liftA (fmap CellText) (tagSeq ["v"] >>=
                                             return . join . fmap ((`M.lookup` ss).int))
          Just "n" -> liftA maybeCellDouble $ tagSeq ["v"]
          _        -> liftA maybeCellDouble $ tagSeq ["v"]
      return $ Cell (mkCellIx ix) $ CellData (int <$> style) val

    mkCellIx ix = let (c,r) = T.span (>'9') ix
                  in (c,int r)


-- | Add sml namespace to name
n x = Name
  {nameLocalName = x
  ,nameNamespace = Just "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  ,namePrefix = Nothing}

-- | Add office document relationship namespace to name
odr x = Name
  {nameLocalName = x
  ,nameNamespace = Just "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  ,namePrefix = Nothing}

-- | Add package relationship namespace to name
pr x = Name
  {nameLocalName = x
  ,nameNamespace = Just "http://schemas.openxmlformats.org/package/2006/relationships"
  ,namePrefix = Nothing}


-- | Get text from several nested tags
tagSeq :: MonadThrow m => [Text] -> Consumer Event m (Maybe Text)
tagSeq (x:xs)
  = Xml.tagNoAttr (n x)
  $ foldr (\x -> Xml.force "" . Xml.tagNoAttr (n x)) Xml.content xs

tagSeq _ = error "no tags in tag sequence"


-- | Get xml event stream from the specified file inside the zip archive.
xmlSource
 :: MonadThrow m => Zip.Archive -> FilePath -> Maybe (Source m Event)
xmlSource ar fname
  =   Xml.parseLBS Xml.def
  .   Zip.fromEntry
  <$> Zip.findEntryByPath fname ar


-- Get shared strings (if there are some) into IntMap.
getSharedStrings
  :: (MonadThrow m, Functor m)
  => Zip.Archive -> m (M.IntMap Text)
getSharedStrings x
  = case xmlSource x "xl/sharedStrings.xml" of
    Nothing -> return M.empty
    Just xml -> (M.fromAscList . zip [0..]) <$> getText xml

-- | Fetch all text from xml stream.
getText xml = xml $= mkXmlCond Xml.contentMaybe $$ CL.consume


getStyles :: (MonadThrow m, Functor m) => Zip.Archive -> m Styles
getStyles ar = case Zip.fromEntry <$> Zip.findEntryByPath "xl/styles.xml" ar of
  Nothing  -> return (Styles L.empty)
  Just xml -> return (Styles xml)

getWorksheetFiles :: (MonadThrow m, Functor m) => Zip.Archive -> m [WorksheetFile]
getWorksheetFiles ar = case xmlSource ar "xl/workbook.xml" of
  Nothing ->
    error "invalid workbook"
  Just xml -> do
    sheetData <- xml $= mkXmlCond getSheetData $$ CL.consume
    wbRels <- getWbRels ar
    return [WorksheetFile n ("xl" </> T.unpack (fromJust $ lookup rId wbRels)) | (n, rId) <- sheetData]

getSheetData = Xml.tagName (n"sheet") attrs return
  where
    attrs = do
      name <- Xml.requireAttr "name"
      rId  <- Xml.requireAttr (odr "id")
      Xml.ignoreAttrs
      return (name, rId)

getWbRels :: (MonadThrow m, Functor m) => Zip.Archive -> m [(Text, Text)]
getWbRels ar = case xmlSource ar "xl/_rels/workbook.xml.rels" of
  Nothing  -> return []
  Just xml -> xml $$ parseWbRels

parseWbRels = Xml.force "relationships required" $
              Xml.tagNoAttr (pr"Relationships") $
              Xml.many $ Xml.tagName (pr"Relationship") attr return
  where
    attr = do
      target <- Xml.requireAttr "Target"
      id <- Xml.requireAttr "Id"
      Xml.ignoreAttrs
      return (id, target)

-- ---------------------------------------------------------------------


int :: Text -> Int
int = either error fst . T.decimal


-- | Create conduit from xml sink
-- Resulting conduit filters nodes that `f` can consume and skips everything
-- else.
--
-- FIXME: Some benchmarking required: maybe it's not very efficient to `peek`i
-- each element twice. It's possible to swap call to `f` and `CL.peek`.
mkXmlCond f = self
  where
    self = CL.peek >>= maybe           -- try get current event form the stream
           (return ())                 -- stop if stream is empty
           (\_ -> yieldEvent >> self)  -- yield event and loop
    yieldEvent = f >>= maybe           -- try consume current event
                 (CL.drop 1)           -- skip it if can't process
                 yield                 -- yield result otherwise
