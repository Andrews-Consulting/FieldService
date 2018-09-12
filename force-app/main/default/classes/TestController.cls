public with sharing class TestController {
    public TestController() {
    }

    public String stddev1 {get;set;}
	public String fitness11 {get; set;}
	public String fitness12 {get; set;}
    public String stddev2 {get;set;}
    public Integer numRecs {get;set;}
    public list<LocationData__c> locRecords {get;set;}


    public void RecordSet1() {
        
    	locRecords = Cluster.LoadClusterRecords();
    	numRecs = locRecords.size();
    }

    public void RecordSet2() {

		locRecords = Cluster.transposeClusterRecords(locRecords);
    	numRecs = locRecords.size();
    }

    public void CalculateCost() {

		list<Integer> baseIndex = Cluster.CalculateCost(locRecords);

		stddev1 = String.valueOf(locRecords[baseIndex[0]].Std_Dev__c);
		stddev2 = String.valueOf(locRecords[baseIndex[1]].Std_Dev__c);

		fitness11 = String.valueOf(locRecords[baseIndex[0]].Fitness__c);
		fitness12 = String.valueOf(locRecords[baseIndex[1]].Fitness__c);

    }
}