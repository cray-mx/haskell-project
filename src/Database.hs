-- | Functions for intracting with the database for storing.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
module Database where

-- import Database.SQLite.Simple.FromRow (Only(..))
import Database.SQLite.Simple
import Types
import Data.Char ( isDigit)
import Data.String (fromString)


-- | Opens a connection to the database and perform actions.
withConn :: String -> (Connection -> IO ()) -> IO ()
withConn dbName action = do
   conn <- open dbName
   action conn
   close conn


-- | Iterate over the list of GDP Record calling add GDP to save them in database.
saveGDPData :: [RecordGDP] -> IO ()
saveGDPData gdpData = mapM_ (addGDP gdpData) gdpData

-- | Iterate over the list of POP Record calling add GDP to save them in database.
savePOPData :: [RecordPOP] -> IO ()
savePOPData popData = mapM_ (addPOP popData) popData

-- | Fetches the GDP for a given year from user input
getGdp :: String -> [RecordGDP] -> Int
getGdp yr records =
    case filter (\r -> g_year r == yr) records of
        [] -> 0  -- or any other default value
        (x:_) -> read (filter Data.Char.isDigit (gdp x)) :: Int

-- | Adds the GDP record to the database.
addGDP :: [RecordGDP] -> RecordGDP -> IO ()
addGDP gdpData record = withConn dbPath  $ \conn -> do
    let countryNameG = g_country record
    let countryRecords = filter (\r -> g_country r == countryNameG) gdpData
    let gdp2010 = getGdp "2010" countryRecords
    let gdp2015 = getGdp "2015" countryRecords
    let gdp2021 = getGdp "2021" countryRecords
    execute conn "INSERT OR REPLACE INTO GDP (countryNameG, gdp2010, gdp2015, gdp2021) VALUES (?,?,?,?)" (countryNameG, gdp2010, gdp2015, gdp2021)

-- | Adds population record to the database.
addPOP :: [RecordPOP] -> RecordPOP -> IO ()
addPOP popData record = withConn dbPath  $ \conn -> do
    let countryNameP = p_country record
    let countryID = p_id record
    let countryRecords = filter (\r -> p_country r == countryNameP) popData
    let pop2010 = getPop "2010" countryRecords
    let pop2015 = getPop "2015" countryRecords
    let pop2021 = getPop "2021" countryRecords
    execute conn "INSERT OR REPLACE INTO POPULATION (countryID, countryNameP, pop2010, pop2015, pop2021) VALUES (?,?,?,?,?)" (countryID, countryNameP, pop2010, pop2015, pop2021)

-- | Fetches the population for a given country
getPop :: String -> [RecordPOP] -> String
getPop yr records =
    case filter (\r -> p_year r == yr) records of
        [] -> "0"
        (x:_) -> ((pop x)) :: String

-- | Creates tables in the databse for storing population and GDP data
createTables :: IO ()
createTables = withConn dbPath  $ \conn -> do
    execute_ conn "DROP TABLE IF EXISTS POPULATION;"
    execute_ conn "DROP TABLE IF EXISTS GDP;"
    execute_ conn "CREATE TABLE POPULATION (countryID INTEGER PRIMARY KEY, countryNameP TEXT, pop2010 TEXT, pop2015 TEXT, pop2021 TEXT);"
    execute_ conn "CREATE TABLE GDP (countryNameG TEXT PRIMARY KEY, gdp2010 FLOAT, gdp2015 FLOAT, gdp2021 FLOAT, FOREIGN KEY (countryNameG) REFERENCES POPULATION(countryNameP));"
    putStrLn "Tables created"

-- | Function to fetch GDP data
fetchGDP :: String -> String -> IO ()
fetchGDP countryName year = withConn dbPath  $ \conn -> do
    r <- query conn "SELECT gdp2010, gdp2015, gdp2021 FROM GDP WHERE countryNameG = ?" (Only countryName) :: IO [(Float, Float, Float)]
    case r of
        [] -> putStrLn "No data found"
        [(gdp2010, gdp2015, gdp2021)] -> putStrLn $ formatGDPData year countryName gdp2010 gdp2015 gdp2021
        _ -> putStrLn "Invalid year"

-- | Function to fetch population data
fetchPopulation :: String -> String -> IO ()
fetchPopulation countryName year = withConn dbPath  $ \conn -> do
    r <- query conn "SELECT pop2010, pop2015, pop2021 FROM POPULATION WHERE countryNameP = ?" (Only countryName ) :: IO [(String, String, String)]
    case r of
        [] -> putStrLn "No data found"
        [(pop2010, pop2015, pop2021)] -> putStrLn $ formatPopulationData year countryName pop2010 pop2015 pop2021
        _ -> putStrLn "Invalid year"

-- | Capitalise each word in a given string for error handling
-- capitalizeWords :: String -> String
-- capitalizeWords = unwords . map capitalizeWord . words

-- capitalizeWord :: [Char] -> [Char]
-- capitalizeWord "" = ""
-- capitalizeWord (x:xs) = toUpper x : map toLower xs

-- | execute a MATCH query on the fts5 table for the county name.
executeFuzzyMatch :: String -> String -> IO [CounOption]
executeFuzzyMatch dbPath userInput = 
  withConnection dbPath $ \conn -> do
    let que = "SELECT * FROM NameFts WHERE countrynamef MATCH ?;"
    query conn que (Only userInput)

-- | Function to fetch population and GDP data
fetchPopulationAndGDP :: String -> String -> IO ()
fetchPopulationAndGDP countryName year = withConn dbPath  $ \conn -> do
    popResult <- query conn "SELECT pop2010, pop2015, pop2021 FROM POPULATION WHERE countryNameP = ?" (Only countryName) :: IO [(String, String, String)]
    case popResult of
        [] -> putStrLn "No population data found"
        [(pop2010, pop2015, pop2021)] -> putStrLn $ formatPopulationData year countryName pop2010 pop2015 pop2021
        _ -> putStrLn "Error: Multiple population records found"

    gdpResult <- query conn "SELECT gdp2010, gdp2015, gdp2021 FROM GDP WHERE countryNameG = ?" (Only countryName) :: IO [(Float, Float, Float)]
    case gdpResult of
        [] -> putStrLn "No GDP data found"
        [(gdp2010, gdp2015, gdp2021)] -> putStrLn $ formatGDPData year countryName gdp2010 gdp2015 gdp2021
        _ -> putStrLn "Error: Multiple GDP records found"

-- | Function to format population data for display
formatPopulationData :: String -> String -> String -> String -> String -> String
formatPopulationData year countryName pop2010 pop2015 pop2021 =
    let population = case year of
            "2010" -> pop2010
            "2015" -> pop2015
            "2021" -> pop2021
            _ -> "Invalid year"
    in "\n\nPopulation Data of " ++ countryName ++ " for " ++ year ++ ": " ++ population ++ " Millions"

-- | Function to format GDP data for display
formatGDPData :: String -> String -> Float -> Float -> Float -> String
formatGDPData year countryName gdp2010 gdp2015 gdp2021 =
    let gdp = case year of
            "2010" -> gdp2010
            "2015" -> gdp2015
            "2021" -> gdp2021
            _ -> error "Invalid year"
    in "\nGDP Data of " ++ countryName ++ " for " ++ year ++ ": $ " ++ show gdp ++ "\n"

-- | Displays the population data of all countries 
displayAllPopulationData :: IO ()
displayAllPopulationData = withConn dbPath  $ \conn -> do
    rows <- query_ conn "SELECT countryID, countryNameP, pop2010, pop2015, pop2021 FROM POPULATION" :: IO [(Int, String, String, String, String)]
    putStrLn "\nPopulation Data of All Countries:"
    mapM_ printPopulation rows
  where
    printPopulation (id, name, pop2010, pop2015, pop2021) =
      putStrLn $ unwords [show id, "-", name, "Population in 2010:", pop2010, "| 2015:", pop2015, "| 2021:", pop2021]

-- | Displays the GDP data of all countries.
displayAllGDPData :: IO ()
displayAllGDPData = withConn dbPath  $ \conn -> do
    rows <- query_ conn "SELECT countryNameG, gdp2010, gdp2015, gdp2021 FROM GDP" :: IO [(String, Float, Float, Float)]
    putStrLn "\nGDP Data of All Countries:"
    mapM_ printGDP rows
  where
    printGDP (name, gdp2010, gdp2015, gdp2021) =
      putStrLn $ unwords [name, "- GDP in 2010: $", show gdp2010, "| 2015: $", show gdp2015, "| 2021: $", show gdp2021]

-- | Updates the population data for a specific country and year.
updatePopulationData :: String -> String -> String -> IO ()
updatePopulationData countryName year newPopulation = withConn dbPath $ \conn -> do
    let updateQuery = fromString $ "UPDATE POPULATION SET " ++ getPopulationColumn year ++ " = ? WHERE countryNameP = ?"
    execute conn updateQuery (newPopulation, countryName)
    putStrLn "Population data updated successfully."

-- | retrives the apppropriate column name for the specified year in the Population table
getPopulationColumn :: String -> String
getPopulationColumn "2010" = "pop2010"
getPopulationColumn "2015" = "pop2015"
getPopulationColumn "2021" = "pop2021"
getPopulationColumn _      = error "Invalid year"

-- | Updates the GDP data for the user given country and year in the database
updateGDPData :: String -> String -> String -> IO ()
updateGDPData countryName year newGDP = withConn dbPath $ \conn -> do
    let updateQuery = fromString $ "UPDATE GDP SET " ++ getGDPColumn year ++ " = ? WHERE countryNameG = ?"
    execute conn updateQuery (newGDP, countryName)
    putStrLn "GDP data updated successfully."

-- | retrives the apppropriate column name for the specified year in the GDP table
getGDPColumn :: String -> String
getGDPColumn "2010" = "gdp2010"
getGDPColumn "2015" = "gdp2015"
getGDPColumn "2021" = "gdp2021"
getGDPColumn _      = error "Invalid year"

-- | Create a virtual index with the help of FTS5 extension. And Inert all the country Name into it.
createFtsTable :: IO ()
createFtsTable= withConn dbPath  $ \conn -> do
    execute_ conn "DROP TABLE IF EXISTS NameFts;"
    execute_ conn "CREATE VIRTUAL TABLE NameFts USING FTS5(countrynamef);"
    execute_ conn "INSERT INTO NameFts SELECT countrynamep FROM POPULATION;"
