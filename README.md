# Agrupamento de Casos por Problema

Quando uma falha derruba o serviço, dezenas de clientes abrem casos sobre o mesmo assunto. Este projeto agrupa esses casos em um registro de **Problem** (Incident Management nativo do Service Cloud), mostra quantos clientes foram afetados e fecha todos os casos de uma vez com a mesma resolução.

## Por que importa

Sem agrupamento, cada caso é tratado como se fosse único: vários agentes investigam a mesma falha, o gestor não sabe o tamanho do estrago e, quando a correção sai, alguém precisa responder caso a caso. O retrabalho cresce junto com o número de clientes atingidos, justamente quando a operação está sob pressão.

## Ganho

- **Uma investigação em vez de dez.** Os casos ficam sob um problema, com a causa registrada em um lugar só.
- **Dimensão real da falha.** `Clientes_Afetados__c` conta contas distintas, não casos. Dez casos de três clientes são três clientes, e é esse número que importa para priorizar.
- **Fechamento em lote com resposta padrão.** Um clique fecha os casos abertos e grava a mesma resolução em cada um, em vez de copiar e colar.
- **Rastro de auditoria.** `Fechado_Por_Problema__c` marca o que foi fechado em lote, separando do que o agente fechou manualmente.

## Como funciona

1. O gestor cria um **Problem** e escreve a resolução padrão.
2. No painel do problema, busca casos abertos por assunto e seleciona os que pertencem à mesma falha.
3. Ao vincular, a plataforma cria um **CaseRelatedIssue** por caso, e a trigger recalcula os clientes afetados.
4. Quando a correção sai, o botão **Fechar N casos abertos** fecha todos de uma vez: grava a resolução como comentário em cada caso e marca `Fechado_Por_Problema__c`.

O agente pode vincular seus casos ao problema, mas não fecha em lote. Quem fecha é quem tem permissão de editar o problema.

## Por que `Problem` nativo e não um objeto custom

A primeira ideia era um `Problema__c` próprio. Verifiquei a org e o **Incident Management** já estava disponível, com `Problem`, `Incident`, `ChangeRequest` e `CaseRelatedIssue`. Usar o nativo custa menos e entrega mais:

- O vínculo caso-problema já existe como `CaseRelatedIssue`, com proteção contra duplicidade na própria plataforma.
- `Problem` já traz impacto, urgência, prioridade derivada, causa raiz e resolução, campos que eu teria de recriar.
- Um objeto custom exigiria relacionamento próprio, layouts e permissões do zero, e deixaria a org com dois conceitos de "problema" se o cliente ativasse o nativo depois.

O projeto acrescenta ao nativo só o que faltava: a contagem de clientes afetados, a resolução padrão e a marca de auditoria no caso.

## Estrutura

```
force-app/main/default/
├── classes/
│   ├── ProblemSelector.cls                 consultas, todas WITH USER_MODE
│   ├── ProblemService.cls                  regras: vincular, contar, fechar em lote
│   ├── ProblemController.cls               endpoints @AuraEnabled para o LWC
│   ├── CaseRelatedIssueTriggerHandler.cls  recalcula a contagem
│   └── *Test.cls                           testes, com fábrica de dados e usuários
├── triggers/
│   └── CaseRelatedIssueTrigger.trigger     after insert, delete e undelete
├── lwc/problemCaseOverview/                cards, tabela, busca e fechamento em lote
├── flexipages/Problem_Record_Page          página de registro de Problem
├── objects/
│   ├── Problem/fields/                     Clientes_Afetados__c, Resolucao_Padrao__c
│   └── Case/fields/                        Fechado_Por_Problema__c
└── permissionsets/
    ├── Gestor_Problemas                    cria, vincula e fecha em lote
    └── Agente_Problemas                    consulta e vincula os próprios casos
scripts/apex/                               seed e limpeza dos dados de demonstração
```

## Instalação

Pré-requisitos: Salesforce CLI, Node.js e uma org com Incident Management disponível.

```bash
sf org login web --alias DevEd --set-default --instance-url https://login.salesforce.com
sf project deploy validate --source-dir force-app --target-org DevEd --test-level RunLocalTests
sf project deploy start --source-dir force-app --target-org DevEd --test-level RunLocalTests
sf org assign permset --name Gestor_Problemas --target-org DevEd
```

Use `validate` antes do `start`: ele mostra erros de metadado e de teste sem alterar a org.

Depois do deploy, **ative a página**. A FlexiPage vai no metadado, mas a atribuição como página padrão do objeto não: em *Setup → Lightning App Builder*, abra **Problem com casos vinculados** e clique em *Activation*.

Dados de demonstração (3 contas, 10 casos abertos e 1 problema):

```bash
sf apex run --file scripts/apex/seed-demo.apex --target-org DevEd
sf apex run --file scripts/apex/seed-cleanup.apex --target-org DevEd
```

Testes do LWC:

```bash
npm install
npm run test:unit
```

## Testes

- **18 testes Apex**, sem `SeeAllData`, cada um criando os próprios dados.
- **10 testes Jest** no componente: cards, estado vazio, erro do Apex, busca, vínculo, confirmação e cancelamento do fechamento.
- Cobertura na DevEd: `ProblemService` 96,8%, `ProblemSelector` 96,6%, `ProblemController` 92%, handler e trigger 100%.
- Um teste vincula e fecha **200 casos** em uma transação, conferindo o número de consultas com `Limits.getQueries()`.

Os testes de permissão criam um usuário Standard User com apenas o permission set do projeto e rodam as ações em `System.runAs`. É assim que o teste prova que o agente não consegue fechar em lote: um teste rodando como administrador passaria mesmo com a regra errada.

A criação dos dados fica em `ProblemTestData`, que grava em `AccessLevel.SYSTEM_MODE`. A fábrica prepara o cenário; quem é exercitado com permissão é o serviço, dentro do `runAs`.

## Decisões

- **Contagem de contas, não de casos.** Dez casos de um único cliente são uma falha menor do que dez casos de dez clientes. O campo responde "quantos clientes estão parados", que é a pergunta de quem prioriza.
- **A contagem é gravada sem compartilhamento.** `Clientes_Afetados__c` é mantido pelo sistema: quem vincula um caso pode não ter acesso de edição ao problema. A gravação fica isolada em uma classe interna `CounterWriter`, marcada `without sharing`. É o único ponto do projeto sem compartilhamento, e está comentado no código.
- **A resolução vai como `CaseComment`.** Case não tem campo padrão de resolução nesta org, e o comentário fica visível no histórico do caso.
- **Fechamento em lote por DML direto.** Acima de 10.000 casos abertos o serviço recusa com mensagem clara, em vez de estourar o limite. Batch Apex fica para quando houver volume que justifique.
- **O botão de fechar só aparece para quem pode fechar.** O Apex recusa de qualquer forma, mas esconder o botão evita o erro antes dele acontecer.

## Limitações

- **Vínculo não se move entre problemas.** `CaseRelatedIssue.RelatedIssueId` não é alterável depois de criado: é preciso desvincular e vincular de novo. Isso apareceu durante os testes, e o tratamento de `after update` foi removido da trigger por ser inalcançável.
- **A busca de casos é por assunto, com `LIKE`.** Não há similaridade nem correção de digitação. Casos escritos de formas muito diferentes não aparecem juntos na busca.
- **A ativação da página é manual**, como descrito na instalação.
- **Sem Knowledge, Omni-Channel ou Experience Cloud.** Não estavam disponíveis na org usada, então não há artigo sugerido, roteamento por fila nem portal do cliente.
- **Análise estática.** Com os motores de Apex (PMD, CPD e SFGE) não há ocorrência de severidade 1 ou 2. Incluindo o motor ESLint, aparecem 20 ocorrências de severidade alta da regra `GlobalVariable`, todas apontando para declarações de campo de classe do LWC (`overview;`, `searchTerm = '';`). São falso positivo: o PMD analisa o JavaScript com um parser que não reconhece essa sintaxe. A qualidade do LWC é verificada pelo ESLint oficial do Salesforce (`npm run lint`), que passa sem avisos.
