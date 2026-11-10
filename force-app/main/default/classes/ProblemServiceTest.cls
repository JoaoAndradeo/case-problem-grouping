/**
 * Os dados são criados pela fábrica (SYSTEM_MODE). As ações do serviço rodam como
 * gestor ou agente (runAs), para que os permission sets sejam de fato exercitados.
 */
@IsTest
private class ProblemServiceTest {

    @IsTest
    static void linkCasesCreatesLinksAndSkipsAlreadyLinked() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 3);

        Integer first;
        Integer second;
        System.runAs(ProblemTestUsers.gestor()) {
            first = ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
            second = ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
        }

        System.assertEquals(3, first, 'Três vínculos novos na primeira chamada');
        System.assertEquals(0, second, 'Casos já vinculados não geram vínculo novo');
        System.assertEquals(3, [SELECT COUNT() FROM CaseRelatedIssue WHERE RelatedIssueId = :p.Id], 'Sem vínculo duplicado');
    }

    @IsTest
    static void linkCasesIgnoresNullAndEmptyInput() {
        Problem p = ProblemTestData.newProblem(null);

        System.runAs(ProblemTestUsers.gestor()) {
            System.assertEquals(0, ProblemService.linkCases(p.Id, null), 'Lista nula não vincula nada');
            System.assertEquals(0, ProblemService.linkCases(p.Id, new List<Id>{ null }), 'Id nulo é ignorado');
        }
    }

    @IsTest
    static void linkCasesRejectsUnknownProblem() {
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 1);

        System.runAs(ProblemTestUsers.gestor()) {
            Boolean rejected = false;
            try {
                ProblemService.linkCases(null, ProblemTestData.idsOf(cases));
            } catch (IllegalArgumentException e) {
                rejected = true;
            }
            System.assert(rejected, 'Problema inexistente deve ser rejeitado');
        }
    }

    @IsTest
    static void affectedCustomersCountsDistinctAccounts() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(2), 2);

        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
        }

        System.assertEquals(2, ProblemTestData.affectedCustomers(p.Id), 'Quatro casos de duas contas contam duas contas');
    }

    @IsTest
    static void unlinkingRecalculatesAffectedCustomers() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(2), 1);

        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
            delete [SELECT Id FROM CaseRelatedIssue WHERE CaseId = :cases[0].Id];
        }

        System.assertEquals(1, ProblemTestData.affectedCustomers(p.Id), 'Remover o vínculo tira a conta da contagem');
    }

    @IsTest
    static void recalculateIgnoresEmptyInputAndIncidents() {
        Problem p = ProblemTestData.newProblem(null);

        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.recalculateAffectedCustomers(null);
            ProblemService.recalculateAffectedCustomers(new Set<Id>());
            ProblemService.recalculateAffectedCustomers(new Set<Id>{ p.Id });
        }

        System.assertEquals(0, ProblemTestData.affectedCustomers(p.Id), 'Problema sem vínculos fica com zero');
    }

    @IsTest
    static void closeLinkedCasesClosesOnlyOpenOnesAndWritesResolution() {
        Problem p = ProblemTestData.newProblem('Correção aplicada no servidor de autenticação.');
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 3);
        ProblemTestData.close(cases[0]);

        Integer closed;
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
            Test.startTest();
            closed = ProblemService.closeLinkedCases(p.Id);
            Test.stopTest();
        }

        System.assertEquals(2, closed, 'Só os dois casos abertos são fechados');
        System.assertEquals(3, [SELECT COUNT() FROM Case WHERE IsClosed = true AND Id IN :cases], 'Todos ficam fechados');
        System.assertEquals(2, ProblemTestData.countFlagged(cases), 'O caso já fechado não é marcado');
        System.assertEquals(2, [SELECT COUNT() FROM CaseComment WHERE ParentId IN :cases], 'Um comentário com a resolução por caso fechado');
    }

    @IsTest
    static void closeLinkedCasesWithoutResolutionWritesNoComment() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 1);

        Integer closed;
        Integer closedAgain;
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
            closed = ProblemService.closeLinkedCases(p.Id);
            closedAgain = ProblemService.closeLinkedCases(p.Id);
        }

        System.assertEquals(1, closed, 'Um caso fechado');
        System.assertEquals(0, closedAgain, 'Segunda chamada não tem o que fechar');
        System.assertEquals(0, [SELECT COUNT() FROM CaseComment WHERE ParentId IN :cases], 'Sem resolução, sem comentário');
    }

    @IsTest
    static void closeLinkedCasesIsRejectedForAgent() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 1);
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
        }

        System.runAs(ProblemTestUsers.agente()) {
            Boolean rejected = false;
            try {
                ProblemService.closeLinkedCases(p.Id);
            } catch (IllegalArgumentException e) {
                rejected = true;
            }
            System.assert(rejected, 'Agente não pode fechar em lote');
        }
        System.assertEquals(0, [SELECT COUNT() FROM Case WHERE IsClosed = true AND Id IN :cases], 'Nenhum caso foi fechado');
    }

    @IsTest
    static void agentCanLinkCasesAndCountIsMaintained() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(2), 1);

        Integer linked;
        System.runAs(ProblemTestUsers.agente()) {
            linked = ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
        }

        System.assertEquals(2, linked, 'Agente vincula casos');
        System.assertEquals(2, ProblemTestData.affectedCustomers(p.Id), 'Contagem atualizada mesmo sem o agente poder editar o problema');
    }

    @IsTest
    static void linkAndCloseHandleTwoHundredCasesWithFewQueries() {
        Problem p = ProblemTestData.newProblem('Resolvido.');
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(20), 10);

        Integer linked;
        Integer closed;
        Integer queriesAfterLink;
        System.runAs(ProblemTestUsers.gestor()) {
            Test.startTest();
            linked = ProblemService.linkCases(p.Id, ProblemTestData.idsOf(cases));
            queriesAfterLink = Limits.getQueries();
            closed = ProblemService.closeLinkedCases(p.Id);
            Test.stopTest();
        }

        System.assertEquals(200, linked, 'Duzentos vínculos');
        System.assertEquals(200, closed, 'Duzentos casos fechados');
        System.assert(queriesAfterLink <= 6, 'Vincular 200 casos deve usar poucas consultas, usou ' + queriesAfterLink);
        System.assertEquals(20, ProblemTestData.affectedCustomers(p.Id), 'Vinte contas afetadas');
    }
}