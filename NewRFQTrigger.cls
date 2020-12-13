trigger NewRFQTrigger on ccrz__E_RequestForQuote__c (after insert) {
    
    NewRFQHandler handler = new NewRFQHandler();
    
    handler.NovaOpp(Trigger.New[0].Id);

    
}