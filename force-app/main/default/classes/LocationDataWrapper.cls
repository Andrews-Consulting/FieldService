// compares locationData__c based upon the distance.
global class LocationDataWrapper implements Comparable {
    
    public LocationData__c ld;

    // Constructor
    public LocationDataWrapper(LocationData__c thisld) {
        ld = thisld;
    }
    
    // Compare opportunities based on the opportunity amount.
    global Integer compareTo(Object compareTo) {
        // Cast argument to OpportunityWrapper
        LocationDataWrapper ctLd = (LocationDataWrapper)compareTo;
        
        // The return value of 0 indicates that both elements are equal.
        Integer returnValue = 0;
        if (ld.Distance__c > ctLd.ld.Distance__c) {
            // Set return value to a positive value.
            returnValue = 1;
        } else if (ld.Distance__c < ctLd.ld.Distance__c) {
            // Set return value to a negative value.
            returnValue = -1;
        }
        
        return returnValue;       
    }
}