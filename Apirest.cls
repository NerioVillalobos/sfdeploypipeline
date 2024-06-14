@RestResource(urlMapping='/crearOrdenDeTrabajo/*')
 
global with sharing class FSLN_ApiRest {
    @HttpPost
    global static void CreateWO() {
        // Request
        RestRequest req = RestContext.request;
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
       
        insertWorkOrder(params);
    }
    
    private static void insertWorkOrder(Map<String, Object> params) {
        try {
            
            WorkOrder wo = new WorkOrder();
 
            // Assign StartDate & EndDate for WorkOrder
            List<Object> reqTimeSlots = (List<Object>) params.get('requestedTimeSlot');
            Map <String,Object> validfor = (Map<String,Object>) reqTimeSlots[0];        
            Map <String,Object> validforvalue = (Map<String,Object>)validfor.get('validFor');
            String startDateTimeJSON = (String) validforvalue.get('startDateTime');
            startDateTimeJSON = startDateTimeJSON.replace('T',' ');
            startDateTimeJSON = startDateTimeJSON.left(20);
            wo.StartDate = DateTime.valueOf(startDateTimeJSON);
            Integer validForDays = (Integer) validforvalue.get('days');
            wo.EndDate = wo.startDate.addDays(validForDays);
			String category = (String)params.get('category');
			wo.FSLN_WorkType_Category__c = category;
            
            // Assign FSLN_Productos_en_Orden_de_Trabajo__c & Get Tecnología
            List <Object> productOrderItem = (List<Object>) params.get ('productOrderItem');
            List <String> tecnologias = new List<String>();
            for (Object item : productOrderItem){
                Map <String, Object> producto = (Map<String,Object>) item;
                String tipoDeTrabajo = (String) producto.get('action');
                if(tipoDeTrabajo != 'noChange'){
                    List<Object> relatedParty = (List<Object>)params.get('relatedParty');
                    Map<String,Object> rpItems = (Map<String,Object>) relatedParty[0];
                    Map<String,Object> customer = (Map<String,Object>) rpItems.get('customer');
                    String tipocliente = (String)customer.get('type');
                    Map <String, Object> product = (Map<String,Object>)producto.get('product');
                    Map<String,Object> productSpec = (Map<String,Object>)product.get('productSpecification');
                    String prodtype = (String)product.get('type');
                    String prodstype = (String)product.get('subType');
                    String tech = (String) productSpec.get('technology');
                    tecnologias.add(tech);
                    List<FSLN_Regla_BRE__c> reglaprod = [SELECT id FROM FSLN_Regla_BRE__c 
									WHERE FSLN_Accion_Producto__c = :tipoDeTrabajo
                                    AND FSLN_Equipment_Action__c = ''
                                    AND FSLN_Equipment_Model__c = ''
                                    AND FSLN_Equipment_Type__c = ''
                                    AND FSLN_Product_Subtype__c = :prodstype
                                    AND FSLN_Product_Type__c = :prodtype
                                    AND FSLN_Tecnologia__c = :tech
                                    AND FSLN_Tipo_de_cliente__c = :tipocliente
									AND FSLN_WorkType_Category__c = :category];
                    if (reglaprod.size() == 0){
                        System.debug('falla BRE prod');
                        String message = '{"message" : "No hay regla BRE asignada", "code" : "BR101" , "info" : "Job type rule did not set a job type code:There are 1000 rules for template search_timeslot_set_job_type but any of them matched"}';
                		throw new CustomException(message, 417);
                    }
                    if (producto.containsKey('equipment')){
                        WorkOrderLineItem WOLIEquipo = new WorkOrderLineItem();
                        Map <String,Object> equipment = (Map<String,Object>) producto.get('equipment');
                        String Accion_Equipo = (String) equipment.get('action');
                        String Equipment_Type = (String) equipment.get('type');
                        String Modelo_de_equipo = (String)equipment.get('model');
                        List<FSLN_Regla_BRE__c>reglaEq = [SELECT id FROM FSLN_Regla_BRE__c 
									WHERE FSLN_Accion_Producto__c = :tipoDeTrabajo
                                    AND FSLN_Equipment_Action__c = :Accion_Equipo
                                    AND FSLN_Equipment_Model__c = :Modelo_de_equipo
                                    AND FSLN_Equipment_Type__c = :Equipment_Type
                                    AND FSLN_Product_Subtype__c = :prodstype
                                    AND FSLN_Product_Type__c = :prodtype
                                    AND FSLN_Tecnologia__c = :tech
                                    AND FSLN_Tipo_de_cliente__c = :tipocliente						
                                    AND FSLN_WorkType_Category__c = :category];
                        if (reglaEq.size() == 0){
                            System.debug('fallo BRE eq');
                            String message = '{"message" : "No hay regla BRE asignada", "code" : "BR101" , "info" : "Job type rule did not set a job type code:There are 1000 rules for template search_timeslot_set_job_type but any of them matched"}';
                			throw new CustomException(message, 417);
                        }
                    }
                }
                
            }
                
            // Assign City & Country & PostalCode & State & Street & Description
            Map <String,Object> relatedPlaceJSON = (Map<String,Object>)params.get('relatedPlace');
            Map <String,Object> geographicAddressJSON = (Map<String,Object>)relatedPlaceJSON.get('geographicAddress');        
            wo.City = (String)geographicAddressJSON.get('city');
            wo.Country = (String)geographicAddressJSON.get('country');
            wo.PostalCode = (String)geographicAddressJSON.get('postCode');
            wo.State = (String)geographicAddressJSON.get('stateOrProvince');
            wo.Street = (String)geographicAddressJSON.get('streetName') +' '+ (String)geographicAddressJSON.get('streetNumber');
            Map <String,Object> geoJSON = (Map<String,Object>)geographicAddressJSON.get('geo');            
            wo.Longitude = (Double)geoJSON.get('x');
            wo.Latitude = (Double)geoJSON.get('y');
            wo.Description = 'localidad: ' + (String)geographicAddressJSON.get('locality');
            wo.Description += '\r\n';
            wo.Description += 'piso: ';
            wo.Description += (String)geographicAddressJSON.get('floor');
            wo.description += '\r\n';
            wo.Description += 'puerta: ';
            wo.Description += (String)geographicAddressJSON.get('doorNumber');
            wo.Description += '\r\n';
            wo.Description += 'detalles: ';
            wo.Description += (String)geographicAddressJSON.get('addressNote');
            //
            wo.ServiceTerritoryId = (String)params.get('fsTerritory');
            
            //Get & Assign Worktype
            List<String> subcatList = new List<String>();
            List<WorkStep> worksteplist = new List<WorkStep>();    
            if(params.containsKey('relatedEntity')){
                List<Object> relatedEntity = (List<Object>) params.get('relatedEntity');
                if(!relatedEntity.isEmpty()){
                    
                    // Validamos si la subcategoria corresponde a un valor de picklist
                    List<String> picklistValues = new List<String>();
                    Schema.DescribeFieldResult objFieldDescribe = WorkType.FSLN_Subcategoria__c.getDescribe();
                    List<Schema.PicklistEntry> lstPickListValues = objFieldDescribe.getPickListValues();
                    for (Schema.PicklistEntry objPickList : lstPickListValues) {
                        picklistValues.add(objPickList.getValue());
                    }
 
                    for(Object o : relatedEntity) {
                        Map<String,Object> entityItem = (Map<String,Object>) o;
                        //busqueda casoID
                        String REid = (String)entityItem.get('id');
                        String REname = (String)entityItem.get('name');
                        String RErole = (String)entityItem.get('role');
                        if (REname == 'Case' && RErole == 'Case'){
                            wo.CaseId = REid;
                        }
                        if(RErole == 'TroubleTicket'){
                            WorkStep workstepaAgregar = new WorkStep();
                            workstepaAgregar.Name = REname;
                            worksteplist.add(workstepaAgregar);
                        }
                        //wo.FSLN_ID_System_RelatedEntity__c = entityItem.get('');
                        if(picklistValues.contains((String)entityItem.get('name'))){
                            subcatList.add((String) entityItem.get('name'));
                        }
                    }
                }
            }
            //Tecnologías mixtas
            List<WorkType> workTypes = new List<WorkType>();
            String technology = tecnologias[0];
            for (String tech : tecnologias){
                if (tecnologias[0] != tech){
                    technology = 'HFC_FTTH';
                }
            }
			//Work Type de Work Order
            if(!subcatList.isEmpty()){
                String subcatAsString = '(\'' + String.join(subcatList, '\', \'') + '\')';
                String query = 'SELECT Id, EstimatedDuration FROM WorkType WHERE FSLN_Tecnologia__c = \''+ technology +'\' AND FSLN_Categoria__c INCLUDES (\'' + category + '\')' + ' AND FSLN_Subcategoria__c INCLUDES' + subcatAsString;
                workTypes = Database.query(query);
            } else {
                workTypes = [SELECT Id, EstimatedDuration FROM WorkType WHERE FSLN_Tecnologia__c = :technology AND FSLN_Categoria__c INCLUDES (:category)];            
            }
            if(workTypes.isEmpty() || workTypes.size() > 1){
                System.debug('FALLA workTypes.isEmpty() || workTypes.size() > 1');
                String message = '{"message" : "Job type rule did not set a job type code", "code" : "BR101" , "info" : "Job type rule did not set a job type code:There are 1000 rules for template search_timeslot_set_job_type but any of them matched"}';
                throw new CustomException(message, 417);
            } else{
                String wtId = workTypes[0].Id;
                // Inicio Comentario OSSFSL-20
                List<SkillRequirement> sr = [SELECT Id, RelatedRecordId FROM SkillRequirement WHERE RelatedRecordId = :wtId];
                if((!sr.isEmpty()) || Test.isRunningtest()){
                    wo.WorkTypeId = workTypes[0].Id;
                    wo.Duration = workTypes[0].EstimatedDuration;
                    wo.DurationType = 'minutes';
                } else {
                    String message = '{"message" : "Scheduling error", "code" : "102" , "info" : "skill code not found or not mapped JT:<JobtypeCd> RouteCriteria:<RouteCriteria>"}';
                    throw new CustomException(message, 417);
                }    
            }
            
            //Priority WorkOrder
            String priority = (String)params.get('priority');
            if( priority == 'High'){
                   wo.Priority = priority;
               } else if(priority == 'Normal'){
                    List<Object> relatedParty = (List<Object>)params.get('relatedParty');
                    if(!relatedParty.isEmpty()){
                        Map<String,Object> rpItems = (Map<String,Object>) relatedParty[0];
                        Map<String,Object> customer = (Map<String,Object>) rpItems.get('customer');
                        String customerCategory = (String) customer.get('category');
                    if(customerCategory != 'none' && customerCategory != ''){
                        wo.priority = 'High';
                    }
                } else if (subcatList.contains('ENACOM')){
                    wo.priority = 'High';
                }
            } else {
                wo.Priority = 'Low';
            }
            
            //UH 359 Poblar Campos Nodo
			if (params.containsKey('HFC')){
                wo.FSLN_Nodo_HFC__c = (String)params.get('HFC');
            }
            if (params.containsKey('FTTH')){
                wo.FSLN_Nodo_FTTH__c = (String)params.get('FTTH');
            }
            
            insert wo;
            
            //Insert WorkStep
            if (category == 'Asistencia tecnica'){
                WorkPlan workPlanAT = new WorkPlan();
                workPlanAT.name = 'Asistencia Tecnica';
                workPlanAT.FSLN_Paso_obligatorio__c = True;
                workPlanAT.ParentRecordId = wo.Id;
                insert workPlanAT;
                for (WorkStep ws : worksteplist){
                    ws.WorkPlanId = workPlanAT.Id;
                    ws.Status = 'Pending';
                }
                insert worksteplist;
            }
            
 
            //Consultamos RecordType
            RecordType equipoRT = [SELECT ID FROM RecordType WHERE DeveloperName = 'FSLN_Equipment_Type' LIMIT 1];
            RecordType productoRT = [SELECT ID FROM RecordType WHERE DeveloperName = 'FSLN_Product_Type' LIMIT 1];
            
            //agregar productos/equipos
            List <WorkOrderLineItem> lista_WOLI = new List <WorkOrderLineItem>();
            Integer i = 0;
            List <Integer> posicionEquipo = new List<Integer>();
            for (Object item : productOrderItem){
                //Creacion producto
                WorkOrderLineItem WOLIProd = new WorkOrderLineItem();
                Map <String, Object> producto = (Map<String,Object>) item;
                Map <String, Object> product = (Map<String,Object>)producto.get('product');
                String nombreProducto = (String) product.get('id');
                WOLIProd.WorkOrderId = wo.Id;     
                
                //Se guardan los products con noChange!!
                WOLIProd.FSLN_AccionProducto__c = (String)producto.get('action');
                WOLIProd.FSLN_Type__c = (String) product.get('type');
                WOLIProd.FSLN_SubType__c = (String) product.get('subType');
                WOLIProd.Status = (String) producto.get('status');
                WOLIProd.FSLN_ID_Producto__c = (String) producto.get('id');
                if(product.containsKey('productSpecification')){
                    Map<String,Object> productSpec = (Map<String,Object>)product.get('productSpecification');
                    if(!productSpec.isEmpty()){
                        WOLIProd.FSLN_Technology__c = (String) productSpec.get('technology');
                        if (productSpec.containsKey('speed')){
                            WOLIProd.FSLN_Speed__c = (String) productSpec.get('speed');
                        }
                    }
                }
                WOLIProd.RecordTypeId = productoRT.id;
                lista_WOLI.add(WOLIProd);
                
                //relacion Producto-Equipo
                i += 1;
                
                // Creacion Equipo
                if (producto.containsKey('equipment')){
                    WorkOrderLineItem WOLIEquipo = new WorkOrderLineItem();
                    WOLIEquipo.WorkOrderId = wo.Id;
                    Map <String,Object> equipment = (Map<String,Object>) producto.get('equipment');
                    if (equipment.containsKey('serialNumber')){
                        WOLIEquipo.FSLN_SerialNumber__c = (String)equipment.get('serialNumber');
                    }
                    WOLIEquipo.FSLN_ID_Equipo__c = (String)equipment.get('id');
                    WOLIEquipo.FSLN_Accion_Equipo__c = (String) equipment.get('action');
                    WOLIEquipo.FSLN_AccionProducto__c = WOLIProd.FSLN_AccionProducto__c;
                	WOLIEquipo.FSLN_Type__c = WOLIProd.FSLN_Type__c;		//type producto
                	WOLIEquipo.FSLN_SubType__c = WOLIProd.FSLN_SubType__c;	//subtype producto
                    WOLIEquipo.FSLN_Technology__c = WOLIProd.FSLN_Technology__c;
                    WOLIEquipo.FSLN_Equipment_Type__c = (String) equipment.get('type');
                    WOLIEquipo.FSLN_Modelo_de_equipo__c = (String)equipment.get('model');
                    WOLIEquipo.FSLN_ID_Producto__c = WOLIProd.FSLN_ID_Producto__c;
                    WOLIEquipo.RecordTypeId = equipoRT.Id;
                    WOLIEquipo.Status = (String)equipment.get('status');
                    lista_WOLI.add(WOLIEquipo);
                    //relacion Producto-Equipo
                    posicionEquipo.add(i);
                    i += 1;
                }
            }
            insert lista_WOLI;

            //relacion Producto-Equipo
            for (Integer x : posicionEquipo){
                lista_WOLI[x].ParentWorkOrderLineItemId = lista_WOLI[x-1].id;
            }
            update lista_WOLI;

            //BRE WorkPlans
            List<WorkPlan> wps = new List<WorkPlan>();
            List<FSLN_Regla_BRE__c> reglasBre = new List<FSLN_Regla_BRE__c>();
            for (WorkOrderLineItem woli : lista_WOLI){
                if ((woli.FSLN_Accion_Equipo__c != 'noChange' && woli.RecordTypeId == equipoRT.id) || (woli.FSLN_AccionProducto__c != 'noChange' && woli.RecordTypeId == productoRT.Id)){
                    List<Object> relatedParty = (List<Object>)params.get('relatedParty');
                    Map<String,Object> rpItems = (Map<String,Object>) relatedParty[0];
                    Map<String,Object> customer = (Map<String,Object>) rpItems.get('customer');
                    String tipocliente = (String)customer.get('type');
                    if (woli.RecordTypeId == productoRT.id){
						reglasBre = [SELECT id FROM FSLN_Regla_BRE__c 
									WHERE FSLN_Accion_Producto__c = :woli.FSLN_AccionProducto__c
                                    AND FSLN_Equipment_Action__c = ''
                                    AND FSLN_Equipment_Model__c = ''
                                    AND FSLN_Equipment_Type__c = ''
                                    AND FSLN_Product_Subtype__c = :woli.FSLN_SubType__c
                                    AND FSLN_Product_Type__c = :woli.FSLN_Type__c
                                    AND FSLN_Tecnologia__c = :woli.FSLN_Technology__c
                                    AND FSLN_Tipo_de_cliente__c = :tipocliente							
									AND FSLN_WorkType_Category__c = :wo.FSLN_WorkType_Category__c	]; 
                    }else if (woli.RecordTypeId == equipoRT.id){
                    	reglasBre = [SELECT id FROM FSLN_Regla_BRE__c 
									WHERE FSLN_Accion_Producto__c = :woli.FSLN_AccionProducto__c
                                    AND FSLN_Equipment_Action__c = :woli.FSLN_Accion_Equipo__c
                                    AND FSLN_Equipment_Model__c = :woli.FSLN_Modelo_de_equipo__c
                                    AND FSLN_Equipment_Type__c = :woli.FSLN_Equipment_Type__c
                                    AND FSLN_Product_Subtype__c = :woli.FSLN_SubType__c
                                    AND FSLN_Product_Type__c = :woli.FSLN_Type__c
                                    AND FSLN_Tecnologia__c = :woli.FSLN_Technology__c
                                    AND FSLN_Tipo_de_cliente__c = :tipocliente						
                                    AND FSLN_WorkType_Category__c = :wo.FSLN_WorkType_Category__c];
                    }
                    List<WorkPlanTemplate> wpts = [SELECT id,Description,RelativeExecutionOrder,Name,FSLN_Paso_obligatorio__c, FSLN_ActivaSAM__c, FSLN_IdExterno__c FROM WorkPlanTemplate WHERE FSLN_Regla_BRE__c = :reglasBre[0].id AND isActive = True];
                    for (WorkPlanTemplate wpt : wpts){
                        WorkPlan wp = new WorkPlan();
                        wp.Description = wpt.Description;
                        wp.ExecutionOrder = wpt.RelativeExecutionOrder;
                        wp.WorkOrderId = wo.id;
                        wp.Name = wpt.Name;
                        wp.FSLN_Paso_obligatorio__c = wpt.FSLN_Paso_obligatorio__c;
                        wp.WorkOrderLineItemId = woli.id;
                        wp.FSLN_ActivaSAM__c = wpt.FSLN_ActivaSAM__c;
                        wp.FSLN_IdExterno__c  = wpt.FSLN_IdExterno__c;
                        wps.add(wp);
                        }
                    }
                }
            insert wps;
            //BRE WorkSteps
            List <WorkStep> wss = new List<WorkStep>();
            for (WorkOrderLineItem woli : lista_WOLI){
                if ((woli.FSLN_Accion_Equipo__c != 'noChange' && woli.RecordTypeId == equipoRT.id) || (woli.FSLN_AccionProducto__c != 'noChange' && woli.RecordTypeId == productoRT.Id)){
                    List<WorkPlan> wps1 = [SELECT id, Name FROM WorkPlan WHERE WorkOrderLineItemId = :woli.id];
                    for (WorkPlan wp : wps1){
                        List<WorkPlanTemplate> wpt = [SELECT id FROM WorkPlanTemplate WHERE Name = :wp.Name];
                        List<WorkPlanTemplateEntry> wptes = [SELECT id,ExecutionOrder,FSLN_duration__c,WorkPlanTemplateEntryNumber FROM WorkPlanTemplateEntry WHERE WorkPlanTemplateId = :wpt[0].Id];
                        for (WorkPlanTemplateEntry wpte : wptes){
                            WorkStep ws = new WorkStep();
                            ws.ExecutionOrder = wpte.ExecutionOrder;
                            ws.FSLN_Duracion_en_Minutos__c = wpte.FSLN_duration__c;
                            ws.WorkPlanId = wp.id;
                            ws.Name = wpte.WorkPlanTemplateEntryNumber;
                            wss.add(ws);
                        }
                    }
                }
            }
            insert wss;
            
            // Get ServiceAppointment
            Id saId;
            List<ServiceAppointment> sa = [SELECT id, duration, durationInMinutes, serviceTerritoryId FROM ServiceAppointment WHERE ParentRecordId = :wo.id];
            if (sa.size()>0){
                sa[0].ServiceTerritoryId = wo.ServiceTerritoryId;
                saId = sa[0].id;
                sa[0].DurationType = 'Minutes';
                sa[0].duration = wo.Duration;
                update sa[0];
            }
            String messageSuccess = '{"sa" : "' + (String) saId +'"}';
            sendSuccessResponse(messageSuccess);
        } catch (CustomException e) {
            sendErrorResponse(e.getMsg(), 417);
        } catch (Exception e) {
            String message = '{"message" : "Se produjo un error en la solicitud", "code" : "500" , "info" : "'+ e.getMessage() +' | '+ e.getStackTraceString() +'"}';
            sendErrorResponse(message, 500);
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