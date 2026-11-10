@IsTest
private class ProblemControllerTest {

    @IsTest
    static void getOverviewSummarizesLinkedCases() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(2), 1);
        ProblemTestData.close(cases[0]);

        ProblemController.Overview view;
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemController.linkCases(p.Id, ProblemTestData.idsOf(cases));
            view = ProblemController.getOverview(p.Id);
        }

        System.assertEquals(2, view.totalCases, 'Dois casos vinculados');
        System.assertEquals(1, view.openCases, 'Um aberto');
        System.assertEquals(1, view.closedCases, 'Um fechado');
        System.assertEquals(2, view.affectedCustomers, 'Duas contas');
        System.assertEquals(true, view.canCloseCases, 'Gestor pode fechar em lote');
        System.assertEquals(2, view.cases.size(), 'Uma linha por caso');
        System.assertNotEquals(null, view.cases[0].accountName, 'Linha traz o nome da conta');
    }

    @IsTest
    static void getOverviewRejectsUnknownProblem() {
        System.runAs(ProblemTestUsers.gestor()) {
            Boolean rejected = false;
            try {
                ProblemController.getOverview(null);
            } catch (AuraHandledException e) {
                rejected = true;
            }
            System.assert(rejected, 'Problema inexistente vira AuraHandledException');
        }
    }

    @IsTest
    static void searchCasesExcludesLinkedAndClosedCases() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 3);
        ProblemTestData.close(cases[0]);

        List<ProblemController.CaseRow> rows;
        Integer shortTermRows;
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemController.linkCases(p.Id, new List<Id>{ cases[1].Id });
            rows = ProblemController.searchCases(p.Id, 'login');
            shortTermRows = ProblemController.searchCases(p.Id, 'lo').size();
        }

        System.assertEquals(1, rows.size(), 'Só o caso aberto e não vinculado aparece');
        System.assertEquals(cases[2].Id, rows[0].caseId, 'É o terceiro caso');
        System.assertEquals(0, shortTermRows, 'Termo curto não busca');
    }

    @IsTest
    static void closeOpenCasesIsRejectedForAgentAsAuraHandled() {
        Problem p = ProblemTestData.newProblem(null);
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 1);
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemController.linkCases(p.Id, ProblemTestData.idsOf(cases));
        }

        System.runAs(ProblemTestUsers.agente()) {
            Boolean rejected = false;
            try {
                ProblemController.closeOpenCases(p.Id);
            } catch (AuraHandledException e) {
                rejected = true;
            }
            System.assert(rejected, 'Agente recebe AuraHandledException ao fechar');
            System.assertEquals(false, ProblemController.getOverview(p.Id).canCloseCases, 'Tela sabe que o agente não fecha');
        }
    }

    @IsTest
    static void closeOpenCasesClosesThroughController() {
        Problem p = ProblemTestData.newProblem('Ok');
        List<Case> cases = ProblemTestData.newCases(ProblemTestData.newAccounts(1), 2);

        Integer closed;
        System.runAs(ProblemTestUsers.gestor()) {
            ProblemController.linkCases(p.Id, ProblemTestData.idsOf(cases));
            closed = ProblemController.closeOpenCases(p.Id);
        }

        System.assertEquals(2, closed, 'Dois casos fechados pelo controller');
    }

    @IsTest
    static void linkCasesRejectsUnknownProblemAsAuraHandled() {
        System.runAs(ProblemTestUsers.gestor()) {
            Boolean rejected = false;
            try {
                ProblemController.linkCases(null, new List<Id>());
            } catch (AuraHandledException e) {
                rejected = true;
            }
            System.assert(rejected, 'Problema nulo vira AuraHandledException');
        }
    }

    @IsTest
    static void linkCasesWithWrongIdTypeIsHiddenAsAuraHandled() {
        Problem p = ProblemTestData.newProblem(null);
        List<Account> accounts = ProblemTestData.newAccounts(1);

        System.runAs(ProblemTestUsers.gestor()) {
            Boolean rejected = false;
            try {
                ProblemController.linkCases(p.Id, new List<Id>{ accounts[0].Id });
            } catch (AuraHandledException e) {
                rejected = true;
            }
            System.assert(rejected, 'Erro interno de DML vira AuraHandledException genérica');
        }
        System.assertEquals(0, [SELECT COUNT() FROM CaseRelatedIssue WHERE RelatedIssueId = :p.Id], 'Nada foi vinculado');
    }
}