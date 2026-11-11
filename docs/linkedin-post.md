Publiquei no GitHub um projeto de Service Cloud: agrupamento de casos por problema.

Quando uma falha derruba o serviço, dezenas de clientes abrem casos sobre a mesma coisa. Vários agentes investigam o mesmo incidente e, quando a correção sai, alguém responde caso a caso. O projeto resolve isso agrupando os casos em um registro de Problem, mostrando quantos clientes foram afetados e fechando todos de uma vez com a mesma resolução.

A decisão que mais mudou o projeto foi não criar um objeto custom. Antes de desenhar qualquer coisa, consultei a org e vi que o Incident Management nativo já estava disponível, com Problem, Incident e CaseRelatedIssue. O vínculo entre caso e problema já existia, com proteção contra duplicidade na própria plataforma. Acrescentei só o que faltava: a contagem de clientes afetados, a resolução padrão e uma marca de auditoria no caso.

Outras escolhas:

- A contagem é de contas distintas, não de casos. Dez casos de um cliente são uma falha menor que dez casos de dez clientes, e é esse número que o gestor usa para priorizar.
- Os testes de permissão criam um usuário com apenas o permission set do projeto e rodam em System.runAs. Um teste rodando como administrador passaria mesmo com a regra de permissão errada.
- Um teste vincula e fecha 200 casos em uma transação, conferindo o número de consultas com Limits.getQueries().

Resultado na Developer Edition: 18 testes Apex e 10 testes Jest passando, cobertura entre 92% e 100% nas classes do projeto.

Duas coisas que aprendi no caminho e estão no README: CaseRelatedIssue.RelatedIssueId não pode ser alterado depois de criado, então não existe "mover um caso de problema"; e o PMD analisa JavaScript com um parser que não reconhece campos de classe do LWC, gerando 20 alertas de severidade alta que são falso positivo.

Repositório: https://github.com/JoaoAndradeo/case-problem-grouping

#Salesforce #ServiceCloud #Apex #LWC #IncidentManagement
