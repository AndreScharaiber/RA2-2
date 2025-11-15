module Main where

import Control.Exception (catch, SomeException(..))
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Ord (comparing)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.IO (appendFile, writeFile, hFlush, stdout)

-- Estrutura básica de um item no estoque.
-- Só registra o essencial para consulta e operações.
data Item = Item
    { itemID     :: String
    , nome       :: String
    , quantidade :: Int
    , categoria  :: String
    } deriving (Show, Read, Eq)

-- O inventário é apenas um mapa de ID → item.
type Inventario = Map String Item

-- Estado final de uma operação.
data StatusLog
    = Sucesso
    | Falha String
    deriving (Show, Read, Eq)

-- Tipos de operações que podem aparecer no registro.
data AcaoLog
    = Add
    | Remove
    | Update
    | QueryFail
    | Report
    | List
    deriving (Show, Read, Eq)

-- Estrutura de log. Nada fora do padrão = timestamp, ação, ID (se houver),
-- descrição e status.
data LogEntry = LogEntry
    { timestamp :: UTCTime
    , acao      :: AcaoLog
    , itemIdLog :: Maybe String
    , detalhes  :: String
    , status    :: StatusLog
    } deriving (Show, Read, Eq)

type ResultadoOperacao = (Inventario, LogEntry)
type SistemaEstado = (Inventario, [LogEntry])

-- Função de adicionar item
addItem :: UTCTime -> Item -> Inventario -> Either String ResultadoOperacao
addItem now newItem inventario =
    case Map.lookup (itemID newItem) inventario of
        Just _ ->
            let msg = "ID ja existe: " ++ itemID newItem
                logEntry = LogEntry now Add (Just (itemID newItem))
                           ("Item duplicado ao tentar adicionar: " ++ itemID newItem)
                           (Falha msg)
            in Left msg

        Nothing ->
            let newInv = Map.insert (itemID newItem) newItem inventario
                logDetails = nome newItem ++ " adicionado (" ++ show (quantidade newItem) ++ ")"
                logEntry = LogEntry now Add (Just (itemID newItem)) logDetails Sucesso
            in Right (newInv, logEntry)

-- Remoção de unidades de um item
removeItem :: UTCTime -> String -> Int -> Inventario -> Either String ResultadoOperacao
removeItem now itemId qtd inv =
    case Map.lookup itemId inv of
        Nothing ->
            let msg = "Item nao encontrado: " ++ itemId
                logEntry = LogEntry now Remove (Just itemId)
                           ("Remocao falhou: item inexistente")
                           (Falha msg)
            in Left msg

        Just item ->
            let atual = quantidade item
            in if qtd > atual
                then
                    let msg = "Estoque insuficiente. Disponivel: " ++ show atual
                        logEntry = LogEntry now Remove (Just itemId)
                                   ("Tentativa de remover mais do que disponivel")
                                   (Falha msg)
                    in Left msg

                else
                    let newQtd = atual - qtd
                        newItem = item { quantidade = newQtd }
                        newInv  = Map.insert itemId newItem inv
                        logDetails = "Removidas " ++ show qtd ++ " un. Estoque agora: " ++ show newQtd
                        logEntry = LogEntry now Remove (Just itemId) logDetails Sucesso
                    in Right (newInv, logEntry)

-- Atualização direta da quantidade de um item
updateQty :: UTCTime -> String -> Int -> Inventario -> Either String ResultadoOperacao
updateQty now itemId novaQtd inv =
    case Map.lookup itemId inv of
        Nothing ->
            let msg = "Item nao encontrado: " ++ itemId
                logEntry = LogEntry now Update (Just itemId)
                           ("Falha ao atualizar: item nao existe")
                           (Falha msg)
            in Left msg

        Just item ->
            if novaQtd < 0
                then
                    let msg = "Quantidade nao pode ser negativa"
                        logEntry = LogEntry now Update (Just itemId)
                                   ("Valor negativo informado: " ++ show novaQtd)
                                   (Falha msg)
                    in Left msg
                else
                    let itemNovo = item { quantidade = novaQtd }
                        newInv   = Map.insert itemId itemNovo inv
                        logDetails = "Quantidade ajustada para " ++ show novaQtd
                        logEntry = LogEntry now Update (Just itemId) logDetails Sucesso
                    in Right (newInv, logEntry)

-- Listagem geral do inventário
listarInventario :: UTCTime -> Inventario -> ResultadoOperacao
listarInventario now inv =
    let info = "Itens listados: " ++ show (Map.size inv)
        entry = LogEntry now List Nothing info Sucesso
    in (inv, entry)

-- Consulta só de erros
logsDeErro :: [LogEntry] -> [LogEntry]
logsDeErro = filter (\l -> case status l of Falha _ -> True; _ -> False)

-- Histórico por item
historicoPorItem :: String -> [LogEntry] -> [LogEntry]
historicoPorItem idAlvo =
    filter (\e -> case itemIdLog e of Just id' -> id' == idAlvo; _ -> False)

-- Item mais movimentado (simples contagem)
itemMaisMovimentado :: [LogEntry] -> Maybe String
itemMaisMovimentado logs =
    let somenteMov e =
            case acao e of Add -> True; Remove -> True; Update -> True; _ -> False

        movs = filter somenteMov logs
        cont = foldr
            (\lg mp -> case itemIdLog lg of
                Just i -> Map.insertWith (+) i 1 mp
                _      -> mp)
            Map.empty movs
    in case Map.maxViewWithKey cont of
        Just ((itemId, _), _) -> Just itemId
        _ -> Nothing

-- Formatação de saída de logs
formatLogEntry :: LogEntry -> String
formatLogEntry e =
    show (timestamp e) ++ " | " ++
    show (acao e) ++ " | " ++
    detalhes e ++ " | " ++
    case status e of
        Sucesso     -> "Sucesso"
        Falha msg   -> "Erro: " ++ msg


-- Formatação de itens ao listar
formatItem :: Item -> String
formatItem i =
    "ID: " ++ itemID i ++
    " | Nome: " ++ nome i ++
    " | Qtd: " ++ show (quantidade i) ++
    " | Cat: " ++ categoria i

-- Operações de persistência simples
saveInventario :: Inventario -> IO ()
saveInventario inv = writeFile "Inventario.dat" (show inv)

appendLogEntry :: LogEntry -> IO ()
appendLogEntry lg = appendFile "Auditoria.log" (show lg ++ "\n")

loadInventario :: IO Inventario
loadInventario =
    (readFile "Inventario.dat" >>= return . read)
    `catch` (\(_::SomeException) -> return Map.empty)

loadLogs :: IO [LogEntry]
loadLogs =
    (readFile "Auditoria.log" >>= return . map read . lines)
    `catch` (\(_::SomeException) -> return [])

-- Processamento de erros/sucessos dentro do REPL
processarTransacao :: UTCTime -> Either String ResultadoOperacao -> SistemaEstado -> IO SistemaEstado
processarTransacao now (Left msg) (inv, logs) = do
    putStrLn ("Erro: " ++ msg)
    let lg = LogEntry now QueryFail Nothing ("Erro: " ++ msg) (Falha msg)
    appendLogEntry lg
    return (inv, logs ++ [lg])

processarTransacao now (Right (novoInv, lg)) (_, logs) = do
    putStrLn "OK"
    saveInventario novoInv
    appendLogEntry lg
    return (novoInv, logs ++ [lg])

-- Parser do comando ADD (evita erro de leitura)

parseComandoAdd :: [String] -> Maybe (String, String, Int, String)
parseComandoAdd ["add", itemId, nome, qStr, cat] =
    case reads qStr of
        [(q, "")] | q >= 0 -> Just (itemId, nome, q, cat)
        _ -> Nothing
parseComandoAdd _ = Nothing

-- Loop principal (REPL)

repl :: SistemaEstado -> IO ()
repl estado@(inv, logs) = do
    putStr "~ % "
    hFlush stdout
    cmd <- getLine
    now <- getCurrentTime
    
    case words cmd of
        [] -> repl estado

        ["sair"] -> putStrLn "Encerrando." >> return ()

        "add":args ->
            case parseComandoAdd ("add":args) of
                Just (i, n, q, c) -> do
                    let novo = Item i n q c
                    processarTransacao now (addItem now novo inv) estado >>= repl
                _ -> putStrLn "Uso: add ID Nome Qtd Categoria" >> repl estado

        ["remove", i, qStr] ->
            case reads qStr of
                [(q, "")] | q > 0 ->
                    processarTransacao now (removeItem now i q inv) estado >>= repl
                _ -> putStrLn "Quantidade invalida." >> repl estado

        ["update", i, qStr] ->
            case reads qStr of
                [(q, "")] | q >= 0 ->
                    processarTransacao now (updateQty now i q inv) estado >>= repl
                _ -> putStrLn "Valor invalido." >> repl estado

        ["listar"] -> do
            let (_, entry) = listarInventario now inv
            putStrLn "Inventario:"
            if Map.null inv
                then putStrLn "   (vazio)"
                else mapM_ (putStrLn . ("   " ++) . formatItem) (Map.elems inv)
            putStrLn ("Total: " ++ show (Map.size inv))
            repl estado

        ["relatorio", "erros"] -> do
            let erros = logsDeErro logs
            putStrLn "Erros registrados:"
            if null erros
                then putStrLn "   Nenhum."
                else mapM_ (putStrLn . ("   " ++) . formatLogEntry) erros
            putStrLn ("Total: " ++ show (length erros))
            repl estado

        ["relatorio", "historico", itemId] -> do
            let hist = historicoPorItem itemId logs
            putStrLn ("Historico do item " ++ itemId ++ ":")
            if null hist
                then putStrLn "   Nenhum dado."
                else mapM_ (putStrLn . ("   " ++) . formatLogEntry) hist
            putStrLn ("Total: " ++ show (length hist))
            repl estado

        ["relatorio", "mais-movimentado"] -> do
            putStrLn "Item com mais movimentacoes:"
            case itemMaisMovimentado logs of
                Just i  -> putStrLn ("   " ++ i)
                Nothing -> putStrLn "   Nenhum registro."
            repl estado

        _ -> putStrLn "Comando invalido." >> repl estado

-- Dados iniciais para testes
popularInventarioInicial :: Inventario -> Inventario
popularInventarioInicial inv =
    foldr (\(i, n, q, c) acc -> Map.insert i (Item i n q c) acc) inv
        [ ("SAL01", "Lays Original", 100, "Salgadinhos")
        , ("SAL02", "Ruffles Queijo", 80, "Salgadinhos")
        , ("SAL03", "Doritos Nacho", 75, "Salgadinhos")
        , ("SAL04", "Cheetos Bola", 60, "Salgadinhos")
        , ("SAL05", "Fandangos Queijo", 50, "Salgadinhos")
        , ("REF01", "Pepsi Cola 2L", 40, "Refrigerantes")
        , ("REF02", "Guarana Antarctica 2L", 35, "Refrigerantes")
        , ("REF03", "Coca-Cola 2L", 45, "Refrigerantes")
        , ("REF04", "Fanta Laranja 2L", 30, "Refrigerantes")
        , ("REF05", "Sprite 2L", 25, "Refrigerantes")
        ]


-- Main 
-- Aqui é onde se testa o sistema
main :: IO ()
main = do
    putStrLn "Sistema de Inventario"
    putStrLn "Carregando dados..."

    inv <- loadInventario
    logs <- loadLogs

    let invFinal =
            if Map.null inv
                then popularInventarioInicial inv
                else inv

    if Map.null inv
        then putStrLn "Inventario inicial carregado."
        else putStrLn "Estado salvo recuperado."

    putStrLn "Digite 'sair' para fechar."
    putStrLn ""

    repl (invFinal, logs)
