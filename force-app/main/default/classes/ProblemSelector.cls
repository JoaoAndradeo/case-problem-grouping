/**
 * Consultas do agrupamento de casos por problema. Todas com WITH USER_MODE.
 */
public with sharing class ProblemSelector {

    /** Problemas por Id, com a resolução padrão. */
    public static Map<Id, Problem> problemsById(Set<Id> problemIds) {
        return new Map<Id, Problem>([
            SELECT Id, Subject, Status, Resolucao_Padrao__c, Clientes_Afetados__c
            FROM Problem
            WHERE Id IN :problemIds
            WITH USER_MODE
        ]);
    }

    /** Vínculos dos problemas, com os dados do caso usados na tela e na contagem. */
    public static List<CaseRelatedIssue> linksByProblem(Set<Id> problemIds) {
        return [
            SELECT Id, CaseId, RelatedIssueId, RelationshipType,
                   Case.CaseNumber, Case.Subject, Case.Status, Case.IsClosed,
                   Case.AccountId, Case.Account.Name, Case.CreatedDate
            FROM CaseRelatedIssue
            WHERE RelatedIssueId IN :problemIds
            WITH USER_MODE
            ORDER BY Case.CreatedDate DESC
        ];
    }

    /** Ids dos casos já vinculados ao problema, entre os informados. */
    public static Set<Id> linkedCaseIds(Id problemId, Set<Id> caseIds) {
        Set<Id> linked = new Set<Id>();
        for (CaseRelatedIssue link : [
            SELECT CaseId
            FROM CaseRelatedIssue
            WHERE RelatedIssueId = :problemId AND CaseId IN :caseIds
            WITH USER_MODE
        ]) {
            linked.add(link.CaseId);
        }
        return linked;
    }

    /** Casos abertos vinculados ao problema. */
    public static List<Case> openCasesLinkedTo(Id problemId) {
        Set<Id> caseIds = new Set<Id>();
        for (CaseRelatedIssue link : [
            SELECT CaseId
            FROM CaseRelatedIssue
            WHERE RelatedIssueId = :problemId
            WITH USER_MODE
        ]) {
            caseIds.add(link.CaseId);
        }
        return [
            SELECT Id, Status, Fechado_Por_Problema__c
            FROM Case
            WHERE Id IN :caseIds AND IsClosed = false
            WITH USER_MODE
        ];
    }

    /** Casos abertos cujo assunto contém o termo, fora os já vinculados. */
    public static List<Case> searchOpenCases(String term, Set<Id> excludeCaseIds, Integer maxRows) {
        if (String.isBlank(term)) {
            return new List<Case>();
        }
        String pattern = '%' + String.escapeSingleQuotes(term) + '%';
        return [
            SELECT Id, CaseNumber, Subject, Status, AccountId, Account.Name, CreatedDate
            FROM Case
            WHERE IsClosed = false
              AND Subject LIKE :pattern
              AND Id NOT IN :excludeCaseIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :maxRows
        ];
    }
}