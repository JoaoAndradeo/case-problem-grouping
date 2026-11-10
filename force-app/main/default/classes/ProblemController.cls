/** Dados e ações do painel de casos no registro de Problem. */
public with sharing class ProblemController {

    private static final Integer SEARCH_LIMIT = 20;

    @AuraEnabled(cacheable=true)
    public static Overview getOverview(Id problemId) {
        try {
            Overview view = new Overview();
            Problem target = ProblemSelector.problemsById(new Set<Id>{ problemId }).get(problemId);
            if (target == null) {
                throw new IllegalArgumentException('Problema não encontrado ou sem acesso.');
            }
            view.affectedCustomers = target.Clientes_Afetados__c == null ? 0 : target.Clientes_Afetados__c.intValue();
            view.canCloseCases = Schema.sObjectType.Problem.isUpdateable();
            addLinkedCases(view, ProblemSelector.linksByProblem(new Set<Id>{ problemId }));
            return view;
        } catch (IllegalArgumentException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível carregar os casos do problema.');
        }
    }

    @AuraEnabled
    public static List<CaseRow> searchCases(Id problemId, String term) {
        try {
            if (String.isBlank(term) || term.trim().length() < 3) {
                return new List<CaseRow>();
            }
            Set<Id> linked = new Set<Id>();
            for (CaseRelatedIssue link : ProblemSelector.linksByProblem(new Set<Id>{ problemId })) {
                linked.add(link.CaseId);
            }
            List<CaseRow> rows = new List<CaseRow>();
            for (Case found : ProblemSelector.searchOpenCases(term.trim(), linked, SEARCH_LIMIT)) {
                rows.add(toRow(found));
            }
            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível buscar os casos.');
        }
    }

    @AuraEnabled
    public static Integer linkCases(Id problemId, List<Id> caseIds) {
        try {
            return ProblemService.linkCases(problemId, caseIds);
        } catch (IllegalArgumentException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível vincular os casos.');
        }
    }

    @AuraEnabled
    public static Integer closeOpenCases(Id problemId) {
        try {
            return ProblemService.closeLinkedCases(problemId);
        } catch (IllegalArgumentException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível fechar os casos.');
        }
    }

    private static void addLinkedCases(Overview view, List<CaseRelatedIssue> links) {
        for (CaseRelatedIssue link : links) {
            view.cases.add(toRow(link));
            if (link.Case.IsClosed) {
                view.closedCases++;
            } else {
                view.openCases++;
            }
        }
        view.totalCases = view.cases.size();
    }

    private static CaseRow toRow(CaseRelatedIssue link) {
        CaseRow row = new CaseRow();
        row.caseId = link.CaseId;
        row.caseNumber = link.Case.CaseNumber;
        row.subject = link.Case.Subject;
        row.status = link.Case.Status;
        row.accountName = link.Case.Account?.Name;
        row.createdDate = link.Case.CreatedDate;
        row.isClosed = link.Case.IsClosed;
        return row;
    }

    private static CaseRow toRow(Case found) {
        CaseRow row = new CaseRow();
        row.caseId = found.Id;
        row.caseNumber = found.CaseNumber;
        row.subject = found.Subject;
        row.status = found.Status;
        row.accountName = found.Account?.Name;
        row.createdDate = found.CreatedDate;
        row.isClosed = false;
        return row;
    }

    public class Overview {
        @AuraEnabled public Integer totalCases = 0;
        @AuraEnabled public Integer openCases = 0;
        @AuraEnabled public Integer closedCases = 0;
        @AuraEnabled public Integer affectedCustomers = 0;
        @AuraEnabled public Boolean canCloseCases = false;
        @AuraEnabled public List<CaseRow> cases = new List<CaseRow>();
    }

    public class CaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String accountName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Boolean isClosed;
    }
}