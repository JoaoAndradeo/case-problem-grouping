/**
 * Mantém Clientes_Afetados__c quando vínculos de caso são criados ou removidos.
 * Só problemas entram na conta: RelatedIssueId também pode apontar para Incident.
 * Não há tratamento de update: RelatedIssueId não pode ser alterado depois de criado.
 */
public with sharing class CaseRelatedIssueTriggerHandler {

    public static void afterInsert(List<CaseRelatedIssue> links) {
        ProblemService.recalculateAffectedCustomers(problemIdsOf(links));
    }

    public static void afterDelete(List<CaseRelatedIssue> links) {
        ProblemService.recalculateAffectedCustomers(problemIdsOf(links));
    }

    private static Set<Id> problemIdsOf(List<CaseRelatedIssue> links) {
        Set<Id> problemIds = new Set<Id>();
        for (CaseRelatedIssue link : links) {
            if (link.RelatedIssueId != null && link.RelatedIssueId.getSObjectType() == Problem.SObjectType) {
                problemIds.add(link.RelatedIssueId);
            }
        }
        return problemIds;
    }
}