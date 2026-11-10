/**
 * Regras do agrupamento de casos por problema (Incident Management nativo).
 *
 * O vínculo entre caso e problema é o CaseRelatedIssue padrão. Este serviço cuida de
 * vincular sem duplicar, manter a contagem de clientes afetados e fechar os casos em lote.
 */
public with sharing class ProblemService {

    public static final String RELATIONSHIP_TYPE = 'Root Cause';
    public static final String CLOSED_STATUS = 'Closed';
    /** Acima disso, o fechamento em lote precisa de Batch Apex. Limite de linhas de DML por transação. */
    public static final Integer MAX_CASES_PER_CLOSE = 10000;

    /**
     * Vincula os casos ao problema. Casos já vinculados são ignorados.
     * Devolve quantos vínculos novos foram criados.
     */
    public static Integer linkCases(Id problemId, List<Id> caseIds) {
        Problem target = requireProblem(problemId);
        Set<Id> wanted = new Set<Id>();
        for (Id caseId : caseIds == null ? new List<Id>() : caseIds) {
            if (caseId != null) {
                wanted.add(caseId);
            }
        }
        if (wanted.isEmpty()) {
            return 0;
        }

        wanted.removeAll(ProblemSelector.linkedCaseIds(target.Id, wanted));
        List<CaseRelatedIssue> links = new List<CaseRelatedIssue>();
        for (Id caseId : wanted) {
            links.add(new CaseRelatedIssue(
                CaseId = caseId,
                RelatedIssueId = target.Id,
                RelationshipType = RELATIONSHIP_TYPE
            ));
        }
        Database.insert(links, true, AccessLevel.USER_MODE);
        // A trigger de CaseRelatedIssue recalcula Clientes_Afetados__c.
        return links.size();
    }

    /**
     * Recalcula Clientes_Afetados__c: contas distintas entre os casos vinculados.
     * A gravação é feita por CounterWriter (sem compartilhamento e em SYSTEM_MODE), porque o
     * campo é mantido pelo sistema: quem vincula um caso pode não ter acesso de edição ao problema.
     */
    public static void recalculateAffectedCustomers(Set<Id> problemIds) {
        if (problemIds == null || problemIds.isEmpty()) {
            return;
        }
        Map<Id, Set<Id>> accountsByProblem = new Map<Id, Set<Id>>();
        for (Id problemId : problemIds) {
            accountsByProblem.put(problemId, new Set<Id>());
        }
        for (CaseRelatedIssue link : ProblemSelector.linksByProblem(problemIds)) {
            if (link.Case.AccountId != null) {
                accountsByProblem.get(link.RelatedIssueId).add(link.Case.AccountId);
            }
        }

        List<Problem> updates = new List<Problem>();
        for (Id problemId : problemIds) {
            updates.add(new Problem(
                Id = problemId,
                Clientes_Afetados__c = accountsByProblem.get(problemId).size()
            ));
        }
        new CounterWriter().updateProblems(updates);
    }

    /**
     * Grava a contagem sem compartilhamento. O campo é mantido pelo sistema: quem vincula um
     * caso pode não ser dono do problema nem ter permissão de editá-lo. Só este método usa isso.
     */
    private without sharing class CounterWriter {
        public void updateProblems(List<Problem> updates) {
            Database.update(updates, true, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * Fecha os casos abertos vinculados ao problema. Marca Fechado_Por_Problema__c e, se o
     * problema tem resolução padrão, grava um comentário com ela em cada caso.
     * Só quem pode editar o problema pode fechar em lote. Devolve quantos casos foram fechados.
     */
    public static Integer closeLinkedCases(Id problemId) {
        if (!Schema.sObjectType.Problem.isUpdateable()) {
            throw new IllegalArgumentException('Sem permissão para fechar casos em lote a partir do problema.');
        }
        Problem target = requireProblem(problemId);
        List<Case> openCases = ProblemSelector.openCasesLinkedTo(target.Id);
        if (openCases.isEmpty()) {
            return 0;
        }
        if (openCases.size() > MAX_CASES_PER_CLOSE) {
            throw new IllegalArgumentException('Mais de ' + MAX_CASES_PER_CLOSE
                + ' casos abertos. O fechamento precisa ser feito em lotes.');
        }

        List<CaseComment> comments = new List<CaseComment>();
        for (Case openCase : openCases) {
            openCase.Status = CLOSED_STATUS;
            openCase.Fechado_Por_Problema__c = true;
            if (String.isNotBlank(target.Resolucao_Padrao__c)) {
                comments.add(new CaseComment(ParentId = openCase.Id, CommentBody = target.Resolucao_Padrao__c));
            }
        }
        Database.update(openCases, true, AccessLevel.USER_MODE);
        if (!comments.isEmpty()) {
            Database.insert(comments, true, AccessLevel.USER_MODE);
        }
        return openCases.size();
    }

    private static Problem requireProblem(Id problemId) {
        Problem target = problemId == null
            ? null
            : ProblemSelector.problemsById(new Set<Id>{ problemId }).get(problemId);
        if (target == null) {
            throw new IllegalArgumentException('Problema não encontrado ou sem acesso.');
        }
        return target;
    }
}