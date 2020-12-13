public class NewRFQHandler{

//Criado por: Renan Catto - 08/12/2020
//Ultima Modificação por: Renan Catto - 09/12/2020
    
    public void NovaOpp (String rfqId){
        
        Opportunity opp = new Opportunity();
        
        //seleciona a rfq que veio da trigger
        ccrz__E_RequestForQuote__c rfq = [
            SELECT Id, Name, ccrz__Account__c, ccrz__Account__r.Id, ccrz__Contact__c, ccrz__Contact__r.Name, ccrz__Amount__c, ccrz__Description__c, ccrz__CloseDate__c, ccrz__Cart__c
            FROM ccrz__E_RequestForQuote__c 
            WHERE Id =: rfqId 
            LIMIT 1
        ];
        
        //seleciona o standard pricebook, sem ele associado não conseguimos criar a oportunidade
        Pricebook2 pb2 = [
            SELECT Id, Name, IsActive 
            FROM PriceBook2 
            WHERE IsStandard = True 
            LIMIT 1
        ];
        
        //associa os valores da RFQ para a oportunidade criada
        opp.AccountId = rfq.ccrz__Account__c;
        opp.ContactId = rfq.ccrz__Contact__c;
        opp.Amount = rfq.ccrz__Amount__c;
        opp.Name = 'Pedido de Cotação realizado pelo B2B -> ' + rfq.ccrz__Contact__r.Name;
        opp.StageName = 'Definição do Potencial';
        opp.Description = rfq.ccrz__Description__c;
        opp.CC_Cart__c = rfq.ccrz__Cart__c;
        opp.CloseDate = rfq.ccrz__CloseDate__c;
        opp.ForecastCategoryName = 'Pipeline';
        opp.internoRFQB2B__c = TRUE; //campo criado para indicar as oportunidades criadas direto pelo b2b.
        opp.Pricebook2Id = pb2.Id;
        opp.LeadSource = 'Web';
        
        //insere oportunidade
        insert opp;
        
        //se a oportunidade e a rfq vierem com o campo de cart preenchidos
        if(opp.CC_Cart__c != Null && rfq.ccrz__Cart__c != Null){
            //lista todos os itens do carrinho
            List<ccrz__E_CartItem__c> ccItem = [
                SELECT id, Name, ccrz__Price__c, ccrz__Quantity__c, ccrz__Cart__c, ccrz__Product__r.ccrz__SKU__C 
                FROM ccrz__E_CartItem__c 
                WHERE ccrz__Cart__c =: rfq.ccrz__Cart__c 
            ];
            
            System.debug('cart list size: ' + ccItem.size());
            //cria uma nova lista para armazenar os itens (product2) de oportunidade
            List<OpportunityLineItem> listaOppLi = new List <OpportunityLineItem>();
            //para cada item no carrinho
            for(ccrz__E_CartItem__c ci : ccItem){
                //cria uma nova linha de item de oportunidade
                OpportunityLineItem oppli = new OpportunityLineItem();
                //associa o id da oportunidade ao item
                oppli.OpportunityId = opp.Id;
                //seleciona o product2 pelo SKU, ja que os cc product tem o mesmo sku dos product2
                Product2 p = [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode =: ci.ccrz__Product__r.ccrz__SKU__C];
                oppli.Product2Id = p.Id;
                oppli.Quantity = ci.ccrz__Quantity__c;
                //como os produtos podem ter preço zero, caso seja feita uma RFQ com produto de preço zerado
                if(ci.ccrz__Price__c != 0){
                    //só faz a multiplicação pela quantidade se o produto tiver preço diferente de zero
                    oppli.TotalPrice = ci.ccrz__Price__c*oppli.Quantity;
                }else{
                    //caso contrário o preço será zero
                    oppli.TotalPrice = 0;
                }
                //adiciona as linhas de produtos criados na lista
                listaOppLi.add(oppli);
            }
            System.debug('opp itens list size: ' + listaOppLi.size());
            //insere a lista
            insert listaOppLi;
        }
		//deleta a oportunidade padrão criada pelo B2B > necessario se nao ficam 2 oportunidades criadas iguais           
        deletaOpp(rfq.ccrz__Account__r.Id);

    }
    
	/*
	* como não existe um jeito de fazer um bypass pela trigger do próprio cloudcraze
	* criei um metodo que seleciona a oportunidade criada pelo cloudcraze filtrando por 2 campos personalizados: internoRFQB2B__c & CC_Cart__c
	* esses dois campos nao existem na trigger original e precisamos para fazer a construção da lista de produtos
	* a query irá selecionar apenas 1 oportunidade ordenada pela ordem decrescente
	*/
    @future
    public static void deletaOpp(String AccId){
        Opportunity opp = [
            SELECT Id 
            FROM Opportunity
            WHERE AccountId =: AccId AND internoRFQB2B__c = FALSE AND CC_Cart__c = NULL AND Name LIKE '%CloudCraze DefaultStore RFQ%' 
            ORDER BY CreatedDate DESC
            LIMIT 1 
        ];  
        delete opp;
    }
    
}