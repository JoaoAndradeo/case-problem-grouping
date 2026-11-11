/**
 * Dados de demonstracao do agrupamento de casos por problema.
 *
 * Cria 3 contas, 10 casos abertos com o mesmo sintoma e 1 problema, e vincula
 * os casos ao problema pelo proprio servico, para que a trigger calcule os clientes afetados.
 *
 * Executar com:
 *   sf apex run --file scripts/apex/seed-demo.apex --target-org DevEd
 *
 * Para remover depois, use scripts/apex/seed-cleanup.apex.
 */
final String TAG = '[DEMO Problema]';

List<Account> contas = new List<Account>();
for (Integer i = 1; i <= 3; i++) {
    contas.add(new Account(Name = TAG + ' Cliente ' + i));
}
insert contas;

List<Case> casos = new List<Case>();
List<String> sintomas = new List<String>{
    'Erro ao fazer login no portal',
    'Login no portal retorna erro 500',
    'Nao consigo entrar no portal'
};
for (Integer i = 0; i < 10; i++) {
    casos.add(new Case(
        Subject = TAG + ' ' + sintomas[Math.mod(i, sintomas.size())],
        Description = 'Cliente relata falha de autenticacao desde hoje de manha.',
        AccountId = contas[Math.mod(i, contas.size())].Id,
        Status = 'New',
        Origin = 'Web'
    ));
}
insert casos;

Problem problema = new Problem(
    Subject = TAG + ' Indisponibilidade no servico de autenticacao',
    Description = 'Varios clientes sem conseguir autenticar no portal.',
    Impact = 'High',
    Urgency = 'High',
    Resolucao_Padrao__c = 'O servico de autenticacao foi restabelecido. '
        + 'Pedimos desculpas pelo transtorno. Caso o acesso ainda falhe, responda a este caso.'
);
insert problema;

Integer vinculados = ProblemService.linkCases(problema.Id, new List<Id>(new Map<Id, Case>(casos).keySet()));
Problem resultado = [SELECT Subject, Clientes_Afetados__c FROM Problem WHERE Id = :problema.Id];

System.debug('SEED problema=' + problema.Id);
System.debug('SEED casos=' + casos.size() + ' vinculados=' + vinculados);
System.debug('SEED clientes afetados=' + resultado.Clientes_Afetados__c);
