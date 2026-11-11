/**
 * Remove os dados criados por seed-demo.apex.
 *
 *   sf apex run --file scripts/apex/seed-cleanup.apex --target-org DevEd
 */
final String TAG = '%[DEMO Problema]%';

delete [SELECT Id FROM CaseRelatedIssue WHERE Case.Subject LIKE :TAG];
delete [SELECT Id FROM Case WHERE Subject LIKE :TAG];
delete [SELECT Id FROM Problem WHERE Subject LIKE :TAG];
delete [SELECT Id FROM Account WHERE Name LIKE :TAG];

System.debug('CLEANUP concluido');
