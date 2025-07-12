Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get('cgcloud__Account_Task_Template__c').getDescribe();

System.debug('--- Relaciones hijas ---');
for (Schema.ChildRelationship rel : describeResult.getChildRelationships()) {
    System.debug('Nombre Relación: ' + rel.getRelationshipName());
    System.debug('Objeto Hijo: ' + rel.getChildSObject());
    System.debug('Campo de relación: ' + rel.getField());
}
