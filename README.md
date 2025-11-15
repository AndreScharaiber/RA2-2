# Atividade Avaliativa - RA2: Sistema de Inventário Haskell

**Disciplina:** Programação Lógica e Funcional
**Professor:** Frank Coelho de Alcantara
**Curso:** Ciência da Computação
**Universidade:** Pontifícia Universidade Católica do Paraná (PUC-PR)

## Dados do Aluno

| Nome | Usuário no GitHub |
| :--- | :--- |
| André Luis Scharaiber Alves | AndreScharaiber |

***

## Link de Execução

O projeto é executável diretamente no ambiente virtual **Online GDB** através do link abaixo. O código finalizado está na aba `main.hs`.

[**LINK DO PROJETO NO ONLINE GDB**](https://onlinegdb.com/bFD7x6vYv)

***

## Instruções de Execução

O sistema deve ser iniciado no terminal do Online GDB para ativar o Loop Interativo (REPL).

1.  **Compilação:** Clique no botão **"Run"** (ou "Executar") para compilar o código.
2.  **Início do Sistema:**
3.  O sistema se iniciará e exibirá o prompt interativo **`~ % `** simulando o terminal do MacOS.

***

## Arquitetura e Funcionalidades

O projeto cumpre todos os requisitos definidos na atividade, separando as funcionalidades em:

* **Lógica Pura:** Funções de negócio (`addItem`, `removeItem`, `updateQty`) e de relatórios (`logsDeErro`, `historicoPorItem`, `itemMaisMovimentado`) são puras e não dependem de I/O.
* **Persistência (I/O):** O estado do sistema é salvo e recuperado automaticamente nos arquivos `Inventario.dat` e `Auditoria.log` ao iniciar e encerrar o programa.
* **Log Robusto:** O campo `itemIdLog :: Maybe String` foi adicionado ao `LogEntry` para garantir que a consulta e a agregação dos relatórios sejam seguras e eficientes.

***

## Comandos

O sistema aceita os seguintes comandos no prompt **`~ % `**:

| Comando | Formato | Descrição |
| :--- | :--- | :--- |
| **Adicionar** | `add <ID> <Nome> <Qtd> <Categoria>` | Adiciona um item novo (verifica ID duplicado). |
| **Remover** | `remove <ID> <Qtd>` | Remove a quantidade do item (verifica estoque). |
| **Atualizar Qtd** | `update <ID> <Nova Qtd>` | Ajusta a quantidade exata de um item. |
| **Listar** | `listar` | Exibe o inventário completo. |
| **Relatório Erros** | `relatorio erros` | Lista todos os logs com status `Falha`. |
| **Relatório Histórico**| `relatorio historico <ID>` | Lista as transações de movimento de um item. |
| **Relatório +Mov** | `relatorio mais-movimentado` | Identifica o `itemID` com mais movimentos registrados. |
| **Sair** | `sair` | Salva o estado e encerra o programa. |

***

## Cenários de Teste Manuais

Os comandos abaixo demonstram os fluxos de sucesso e falha do sistema, cumprindo o requisito de **Robustez**:

| Comando | Lógica Testada | Resultado Esperado |
| :--- | :--- | :--- |
| `add LIV01 Livro de HF 5 Literatura` | Adição (Sucesso) | `OK` (Item adicionado) |
| `update LIV01 10` | Update (Sucesso) | `OK` (Quantidade ajustada para 10) |
| `remove LIV01 2` | Remoção (Sucesso) | `OK` (Estoque ajustado para 8) |
| `add LIV01 Outro Livro 1 Drama` | **Falha: ID Duplicado** | `Erro: ID ja existe: LIV01` |
| `remove LIV01 100` | **Falha: Estoque Insuficiente** | `Erro: Estoque insuficiente. Disponivel: 8` |
| `relatorio erros` | **Relatório Erros** | Lista as duas entradas de `Falha` acima. |
| `relatorio historico LIV01` | **Relatório Histórico** | Lista as 4 transações de movimento (`Add`, `Update`, `Remove`, `Falha`) relacionadas. |
| `relatorio mais-movimentado` | **Relatório +Mov** | Retorna **LIV01** (o único item movimentado). |


## Cenário 1: Persistência de Estado (Sucesso)
<img width="915" height="575" alt="Frank 1" src="https://github.com/user-attachments/assets/7a065667-ef0b-45ef-99df-d7e33e0630d5" />
<img width="1173" height="383" alt="Log1" src="https://github.com/user-attachments/assets/255da996-f65a-49a3-959b-06d5207b2d62" />
<img width="1163" height="384" alt="Inv1" src="https://github.com/user-attachments/assets/41dbb01b-1b8a-4b85-a3b8-2bf3851800a5" />
<img width="1187" height="504" alt="Frank11" src="https://github.com/user-attachments/assets/e8d70e9d-fe92-43c8-9acc-5c487565e938" />

## Cenário 2: Erro de Lógica (Estoque Insuficiente)

<img width="1175" height="493" alt="Frank2" src="https://github.com/user-attachments/assets/4b9a1e5e-e77c-45c6-a6f6-223618b838d8" />
<img width="1143" height="504" alt="Erro2" src="https://github.com/user-attachments/assets/c64f7fbc-2426-42b0-b2af-95d0f6216bf6" />

## Cenário 3: Geração de Relatório de Erros

<img width="1413" height="404" alt="Frank3" src="https://github.com/user-attachments/assets/f665f015-956c-4cbe-bd96-fc06edd847c7" />
<img width="1143" height="504" alt="TelaErro3" src="https://github.com/user-attachments/assets/200453a4-42ae-423b-b11a-469d332caac3" />


