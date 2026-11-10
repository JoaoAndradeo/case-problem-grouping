/**
 * Dados de teste do agrupamento por problema.
 * Grava e lê em SYSTEM_MODE: a fábrica prepara o cenário e confere o resultado;
 * quem é testado com permissão é o serviço, dentro de runAs.
 */
@IsTest
public class ProblemTestData {

    public static Problem newProblem(String resolution) {
        Problem p = new Problem(Subject = 'Problema teste', Impact = 'High', Urgency = 'High', Resolucao_Padrao__c = resolution);
        Database.insert(p, true, AccessLevel.SYSTEM_MODE);
        return p;
    }

    public static List<Account> newAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Conta ' + i));
        }
        Database.insert(accounts, true, AccessLevel.SYSTEM_MODE);
        return accounts;
    }

    public static List<Case> newCases(List<Account> accounts, Integer perAccount) {
        List<Case> cases = new List<Case>();
        for (Account a : accounts) {
            for (Integer i = 0; i < perAccount; i++) {
                cases.add(new Case(Subject = 'Erro no login ' + i, AccountId = a.Id, Status = 'New'));
            }
        }
        Database.insert(cases, true, AccessLevel.SYSTEM_MODE);
        return cases;
    }

    public static void close(Case theCase) {
        theCase.Status = 'Closed';
        Database.update(theCase, true, AccessLevel.SYSTEM_MODE);
    }

    public static List<Id> idsOf(List<Case> cases) {
        return new List<Id>(new Map<Id, Case>(cases).keySet());
    }

    /** Clientes_Afetados__c do problema, lido sem depender da FLS do usuário que roda o teste. */
    public static Decimal affectedCustomers(Id problemId) {
        List<Problem> rows = Database.queryWithBinds(
            'SELECT Clientes_Afetados__c FROM Problem WHERE Id = :problemId',
            new Map<String, Object>{ 'problemId' => problemId },
            AccessLevel.SYSTEM_MODE
        );
        return rows[0].Clientes_Afetados__c;
    }

    /** Quantos dos casos estão marcados como fechados pelo problema. */
    public static Integer countFlagged(List<Case> cases) {
        Set<Id> ids = new Set<Id>(idsOf(cases));
        return Database.queryWithBinds(
            'SELECT Id FROM Case WHERE Fechado_Por_Problema__c = true AND Id IN :ids',
            new Map<String, Object>{ 'ids' => ids },
            AccessLevel.SYSTEM_MODE
        ).size();
    }
}