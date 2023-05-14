module Main (main) where
import Words (wordBank)
import Data.Char
import Data.Time
import System.IO
import System.Random
import Control.Exception
import Control.Concurrent
import GHC.IO.Handle (hWaitForInput)

main :: IO ()
main = do
    hSetBuffering stdin NoBuffering
    hSetEcho stdin False
    startTime <- getCurrentTime
    mainLoop (addUTCTime 60 startTime)

{-
    | 
    The main loop function which takes a UTCTime deadline value.
    This value represents the time limit in which the user can type.
-}
mainLoop :: UTCTime -> IO ()
mainLoop deadline = do
    randomNums <- getListOfRandomInts 50 (length wordBank)
    let initialWordList = getWordsFromWordBank randomNums
    mainLoop' initialWordList 0 deadline

mainLoop' :: [String] -> Int -> UTCTime -> IO ()
mainLoop' wordList wordIndex deadline = do
    randomNum <- getRandomInt (length wordBank - 1)
    let extendedWordList = wordList ++ [wordBank !! randomNum]
    putStr clearScreen
    putStrLn ""
    putStrLn (insertLineBreaks (joinStringsWithSpaces (highlightStringInList extendedWordList wordIndex)))
    putStrLn ""
    wordFromUser <- getUserInputWithTimer deadline
    case wordFromUser of
        -- let wasSuccessful = (wordFromList == wordFromUser) will use this later
        Just x -> mainLoop' extendedWordList (wordIndex + 1) deadline
        Nothing -> return ()

{-
    | 
    This function gets the input word from the user. This function has a deadline
    parameter which is the amount of time the user has to input the next word before
    the function times out.
-}
getUserInputWithTimer :: UTCTime -> IO (Maybe [Char])
getUserInputWithTimer deadline = getUserInputWithTimer' "" deadline

getUserInputWithTimer' :: String -> UTCTime -> IO (Maybe [Char])
getUserInputWithTimer' xs deadline = do
    now <- getCurrentTime
    inputReady <- hWaitForInput stdin (round (diffUTCTime deadline now * 1000))
    if inputReady then do
        inputChar <- getChar
        case inputChar of
            c | isSpace c ->
                return (Just xs)
            '\DEL' ->
                if xs == "" then
                    getUserInputWithTimer' "" deadline
                else do
                    putStr removeLastCharacter
                    getUserInputWithTimer' (init xs) deadline
            _ -> do
                putChar inputChar
                getUserInputWithTimer' (xs ++ [inputChar]) deadline
    else return Nothing

-------------------- For generating random numbers

getRandomInt :: Int -> IO Int
getRandomInt upperRange = do randomRIO (0, upperRange) :: IO Int

-- | First argument is the length of the list. The second argument is the upper range for the list values (0 - upperRange)
getListOfRandomInts :: Int -> Int -> IO [Int]
getListOfRandomInts 0 _ = return []
getListOfRandomInts x upperRange = do
    num <- getRandomInt upperRange
    nums <- getListOfRandomInts (x - 1) upperRange
    return (num:nums)

-------------------- Pure Functions

-- | Takes a List of indexes and returns the Strings at thoes indexes in the wordBank
getWordsFromWordBank :: [Int] -> [String]
getWordsFromWordBank = map (wordBank !!)

-- | Returns a the given list with the word at the given index highlighted using the textColorCyan function
highlightStringInList :: [String] -> Int -> [String]
highlightStringInList words wordIndex = highlightStringInList' words wordIndex 0

highlightStringInList' :: [String] -> Int -> Int-> [String]
highlightStringInList' [] _ _ = []
highlightStringInList' (word:words) wordIndex count
    | wordIndex == count = (textColorCyan ++ word ++ textColorReset) : words
    | otherwise = word : highlightStringInList' words wordIndex (count + 1)

{-  |
    Takes a string and inserts a line break at the next space character after every x 
    amount of characters (x is the return of the lineCharacterLimit function).
-}
insertLineBreaks :: String -> String
insertLineBreaks x = insertLineBreaks' x 1

insertLineBreaks' :: String -> Int -> String
insertLineBreaks' [] _ = []
insertLineBreaks' (x:xs) count
    | x == '\ESC' = x : insertLineBreaks' xs (count - 4) -- TODO maybe think of a better way to do this
    | count >= lineCharacterLimit && x == ' ' = '\n' : insertLineBreaks' xs 1
    | otherwise = x : insertLineBreaks' xs (count + 1)

joinStringsWithSpaces :: [String] -> String
joinStringsWithSpaces = foldr (\ x y -> x ++ " " ++ y) ""

removeLastCharacter :: String
removeLastCharacter = "\b \b"

lineCharacterLimit :: Int
lineCharacterLimit = 80

-------------------- ANSI escape sequences
-- all excape codes can be found here https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
textColorReset :: String
textColorReset = "\ESC[0m"

textColorCyan :: String
textColorCyan = "\ESC[36m"

clearScreen :: String
clearScreen = "\ESC[2J"