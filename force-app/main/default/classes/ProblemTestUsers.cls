/**
 * Usuários de teste com os permission sets do projeto, no perfil Standard User.
 * A criação roda em runAs do usuário atual para não misturar DML de setup com DML de dados.
 */
@IsTest
public class ProblemTestUsers {

    public static User gestor() {
        return userWith('Gestor_Problemas', 'gprb');
    }

    public static User agente() {
        return userWith('Agente_Problemas', 'aprb');
    }

    private static User userWith(String permissionSetName, String alias) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            u = new User(
                ProfileId = standardProfile.Id,
                LastName = permissionSetName + ' Teste',
                Email = alias + '@example.com',
                Username = alias + '.' + Datetime.now().getTime() + '@example.com',
                Alias = alias,
                TimeZoneSidKey = 'America/Sao_Paulo',
                LocaleSidKey = 'pt_BR',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'pt_BR'
            );
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }
}