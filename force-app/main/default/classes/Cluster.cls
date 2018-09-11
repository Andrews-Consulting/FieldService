public with sharing class Cluster {

	public void main() {

		list<LocationPair__c> locRecords = LoadClusterRecords();
		list<Integer> baseIndex = CalculateCost(locRecords);

		System.debug('Deviations are ' + locRecords[baseIndex[0]].Std_Dev__c + ' and ' + locRecords[baseIndex[1]].Std_Dev__c);
	}





	// Get the service appointments
	// load the locationpair object with the sets of points.
	public list<LocationPair__c> LoadClusterRecords(    ) {


		list<LocationPair__c> locations = new list<LocationPair__c>();
		list<AC_Service_Appointment__c> li_sa = [Select Id, Location__c from AC_Service_Appointment__c];

		Integer i = 0;
		Integer j = 0;
		Integer c = 1;
		for (AC_Service_Appointment__c sa : li_sa) {
			locations.add(new LocationPair__c(RefId__c=sa.Id, 
											  Location__Longitude__s=sa.Location__Longitude__s, 
											  Location__Latitude__s=sa.Location__Latitude__s,
											  index__c = i, 
											  Cluster__c=c));
			i++;
			j++;
			if (j > 49) {
				i = 0;
				c++;
			}
		}
		return locations;
	}

	// The cost is the lowest Std. Deviation from the starting point.
	// The input is an array of longitude/latitude pairs

	// We return the locations of the base index for each cluster (whatever was marked as index 0 for each cluster)
	public list<Integer> CalculateCost(list<LocationPair__c> locations) {

		Integer i;
		if (locations.size() < 2) 
			return new list<Integer>();

		// Determine the number of clusters and the "center" of the cluster  (clusters are numbered 1-n)
		Integer NumClusters = 0;
		list<Integer> baseIndex = new list<Integer>();

		for (i = 0; i < locations.size(); i++) {
			if (locations[i].index__c == 0)  				
				baseIndex[(Integer)locations[i].Cluster__c] = i;
			if (locations[i].Cluster__c > NumClusters)
				NumClusters = (Integer)locations[i].Cluster__c;
		}


		// for each cluster, calculate the std deviation and save it away in the base index record.
		// Capturing a couple of values along the way

		// These are working totals for each cluster
		list<Decimal> li_totalDistance = new list<Decimal>();
		list<Decimal> li_totalDifference = new list<Decimal>();
		list<Decimal> li_distance = new list<Decimal>();
		list<Decimal> li_numEntries = new list<Decimal>();
		// that need to be initialized
		for (i = 0; i < NumClusters; i++) {
			li_totalDistance.add(0);
			li_totalDifference.add(0);
			li_distance.add(0);
			li_numEntries.add(0);
		}

		// Take an entry, find the cluster
		// Keep totals for each cluster, reference the starting location for the cluster, etc....

		for (i = 0; i < locations.size(); i++) { 
			Integer cluster = ((Integer)locations[i].Cluster__c) - 1;
			if (i != baseIndex[cluster]) {
				li_distance[cluster] =  Location.getDistance(locations[baseIndex[cluster]].Location__c, locations[i].Location__c,'mi');
				locations[baseIndex[cluster]].Distance__c = li_distance[cluster];
				li_totalDistance[cluster] += li_distance[cluster];
				li_numEntries[cluster] ++;
			}
		}

		// Calculate the mean for each cluster
		for (i = 0; i < NumClusters; i++) {
			locations[baseIndex[i]].Mean__c = li_totalDistance[i] / li_numEntries[i];
		}

		
		For (i = 1; i < locations.size(); i++) { 
			Integer cluster = ((Integer)locations[i].Cluster__c) - 1;
// TODO : At some point, see if the compiler knows to only compute the values once.			
			if (i != baseIndex[cluster])
				li_totalDifference[cluster] += (locations[i].Distance__c - locations[baseIndex[cluster]].Mean__c) * (locations[i].Distance__c - locations[baseIndex[cluster]].Mean__c);

		}

	// Calculate the mean for each cluster
		for (i = 0; i < NumClusters; i++) {
			locations[baseIndex[i]].Variance__c = li_totalDifference[i] / li_numEntries[i];
			locations[baseIndex[i]].Std_Dev__c = math.sqrt(li_totalDifference[i] / li_numEntries[i]);

		}

		return baseIndex;
	}

}