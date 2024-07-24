@RestResource(urlMapping='/actualizarEquipos/*')
global with sharing class FSLN_ActualizarEquipos {
    @HttpPatch
    global static void actualizarEquipos() {
        try {
             // Request
        	RestRequest req = RestContext.request;
        	Map<String, Object> request = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
		 
            //Obtenemos el Id de la WorkOrder
			String woId = RestContext.request.requestURI.substringAfterLast('/');
            
            // WorkOrder No existe
            List<WorkOrder> order = [SELECT Id FROM WorkOrder WHERE Id = :woId LIMIT 1];
            if(order.isEmpty()){
                String message = '{"error" : "Orden de trabajo no encontrada"}';
                throw new CustomException(message, 400);
            }

            //Update Actividades
            List<Object> workOrderItem = (List<Object>) request.get('workOrderItem');
            if(!workOrderItem.isEmpty()){
                List<WorkStep> wsList = new List<WorkStep>();
                for(Object o : workOrderItem){
                    Map<String,Object> item = (Map<String,Object>) o;
                    String idActividad = (String) item.get('id');
                    //Validar WorkSteps de la WorkOrder
                    List<WorkStep> wsToUpdate = [SELECT Id, Status FROM WorkStep WHERE WorkPlan.FSLN_IdExterno__c = :idActividad AND WorkOrderId = :woId];
                    if(!wsToUpdate.isEmpty()){
                        for(WorkStep ws : wsToUpdate){
                            ws.status = (String) item.get('status');
                            wsList.add(ws);
                        }
                    } else{
                        String message = '{"error" : "No se encuentra la actividad: '+ idActividad +'"}';
                        throw new CustomException(message, 417);
                    }
                }
                update wsList;
            }

            //Update Pruductos y Equipos 
            List<Object> productOrderItem = (List<Object>) request.get('productOrderItem');
            if(!productOrderItem.isEmpty()){
                List<WorkOrderLineItem> woliList = new List<WorkOrderLineItem>();
                List<WorkStep> wsToUpdateSAM = new List<WorkStep>();
                for(Object product : productOrderItem){
                    Map<String, Object> productMap = (Map<String, Object>) product;
                    String idProducto = (String) productMap.get('id');
                    List<WorkOrderLineItem> productToUpdate = [SELECT Id, Status FROM WorkOrderLineItem WHERE FSLN_ID_Producto__c = :idProducto AND WorkOrderId = :woId AND RecordType.DeveloperName = 'FSLN_Product_Type' LIMIT 1];
                    if(!productToUpdate.isEmpty()){
                        if(productToUpdate[0].Status != 'completed'){
                            productToUpdate[0].Status = (String) productMap.get('status');
                        }
                        if(productMap.containsKey('equipment')){
                            Map<String, Object> equipmentMap = (Map<String, Object>) productMap.get('equipment');
                            String idEquipo = (String) equipmentMap.get('id');
                            List<WorkOrderLineItem> equipmentToUpdate = [SELECT Id FROM WorkOrderLineItem WHERE FSLN_ID_Equipo__c = :idEquipo AND WorkOrderId = :woId AND RecordType.DeveloperName = 'FSLN_Equipment_Type' AND ParentWorkOrderLineItemId = :productToUpdate[0].Id LIMIT 1];
                            if(!equipmentToUpdate.isEmpty()){
                                //Update
                                equipmentToUpdate[0].Status = (String) equipmentMap.get('status');
                                if(equipmentMap.containsKey('serialNumber')){
                                    equipmentToUpdate[0].FSLN_SerialNumber__c  = (String) equipmentMap.get('serialNumber');
                                    // Actualizar WorkSteps relacionado a esta WOLI, al completar estos pasos el WorkPlan se actualizará
                                    List<WorkPlan> wpToUpdate = [SELECT Id FROM WorkPlan WHERE WorkOrderLineItemId = :equipmentToUpdate[0].Id AND FSLN_ActivaSAM__c = true];
                                    if(!wpToUpdate.isEmpty()){
                                        for(WorkPlan wp : wpToUpdate){
                                            List<WorkStep> wsRelatedWoli = [SELECT Id FROM WorkStep WHERE WorkPlanId = :wp.Id];
                                            for(WorkStep ws : wsRelatedWoli){
                                                ws.Status = 'Completed';
                                                wsToUpdateSAM.add(ws);
                                            }
                                        }
                                    }
                                }
                                woliList.add(equipmentToUpdate[0]);
                            } else {
                                //Error equipo no encontrado
                                String message = '{"error" : "No se encuentra el equipo: '+ idEquipo +'"}';
                                throw new CustomException(message, 417);
                            }
                        }
                        woliList.add(productToUpdate[0]);
                    } else {
                        //Error producto no encontrado
                        String message = '{"error" : "No se encuentra el producto: '+ idProducto +'"}';
                        throw new CustomException(message, 417);
                    }
                }
				update woliList;
                if(!wsToUpdateSAM.isEmpty()){
                    update wsToUpdateSAM;
                }
            }
            //Return Success
            String messageSuccess = '{"message" : "Actualización exitosa"}';
            sendSuccessResponse(messageSuccess);

        } catch (CustomException e) {
            sendErrorResponse(e.getMsg(), e.statusCode);
        } catch (Exception e) {
            String errormsg = '{"error" : "Se produjo un error al procesar la solicitud"}';
            sendErrorResponse(errormsg, 500);
        }
    }
    
    private static void sendSuccessResponse(String message) {
        RestContext.response.statusCode = 200;
        RestContext.response.responseBody = Blob.valueOf(message);
    }
    
    private static void sendErrorResponse(String message, Integer statusCode) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.responseBody = Blob.valueOf(message);
    }
    
    public class CustomException extends Exception {
        Integer statusCode;
        String message;
        public CustomException(String message, Integer statusCode) {
            this.message = message;
            this.statusCode = statusCode;
        } 
        public String getMsg(){
            return message;
        }
    }	
}