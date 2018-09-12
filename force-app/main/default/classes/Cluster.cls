public with sharing class Cluster {

	public static void main() {

		list<LocationData__c> locRecords = LoadClusterRecords();
		list<Integer> baseIndex = CalculateCost(locRecords);

		System.debug('Deviations are ' + locRecords[baseIndex[0]].Std_Dev__c + ' and ' + locRecords[baseIndex[1]].Std_Dev__c);
	}

	// Get the service appointments
	// load the locationpair object with the sets of points.
	public static list<LocationData__c> LoadClusterRecords(    ) {


		list<LocationData__c> locations = new list<LocationData__c>();
		list<AC_Service_Appointment__c> li_sa = [Select Id, Location__Longitude__s,Location__Latitude__s from AC_Service_Appointment__c limit 20];

		Integer i = 0;
		Integer j = 0;
		Integer c = 1;
		for (AC_Service_Appointment__c sa : li_sa) {
			locations.add(new LocationData__c(RefId__c=sa.Id, 
											  Location__Longitude__s=sa.Location__Longitude__s, 
											  Location__Latitude__s=sa.Location__Latitude__s,
											  index__c = i, 
											  Cluster__c=c));
			i++;
			j++;
			if (j >= (integer)(li_sa.size() / 2)) {
				i = 0;
				j = -1;
				c++;
			}
		}
		return locations;
	}

	// 
	//  Transpose every other item - Assumes 2 clusters
	//
	public static  list<LocationData__c> transposeClusterRecords(list<LocationData__c> locations) {
		Integer i,j, k;

		list<LocationData__c> newLocs = new list<LocationData__c>(locations);

		for (j = newLocs.size() - 1, i = 0; i < j;) {
			Integer chold = (Integer) newLocs[i].Cluster__c;
			newLocs[i].Cluster__c = newLocs[j].Cluster__c;
			newLocs[j].Cluster__c = chold;
			i += 2;
			j -= 2;
		}
		for (k = 0, i = 0, j = 0; k < newLocs.size(); k++){
			if (newLocs[k].Cluster__c == 1)
				newLocs[k].index__c = i++;
			else 
				newLocs[k].index__c = j++;
		}


		return newLocs;
	}

	//
	//	Generate Child record with parent1 providing dominant traits.
	//
	public static list<LocationData__c> generateChildRecord(list<LocationData__c> parent1, list<LocationData__c> parent2) {
		Integer i,j, childLocs_filled;
		list<Id> usedlocations = new list<Id>();
		list<LocationData__c> childLocs = new list<LocationData__c>();
		Integer Seg1Start, Seg2Start, Seg3Start; 


		if (parent1.size() < 10) {	// special version for smaller blocks (only keeps half of the parent1)
			Seg1Start = 0;
			Seg2Start = (integer)Math.ceil((parent1.size() + parent2.size()) / 4);
			Seg3Start = parent1.size();
		}
		else {						// otherwise keep first and last third from parent1
			Seg1Start = 0;
			Seg2Start = (integer)Math.ceil((parent1.size() + parent2.size()) / 6);
			Seg3Start = (integer)Math.ceil((parent1.size() + parent2.size()) / 3);
		}

		// copy down segment 1 and keep track of used locations using trhe reference Id.
		for (i = Seg1Start; i < Seg2Start; i++) {
			childLocs.add(parent1[i]);
			usedlocations.add(parent1[i].refId__c);
		}

		// copy down the third segment (if it exists)
		for (i = Seg3Start; i < parent1.size(); i++) {
			childLocs.add(parent1[i]);
			usedlocations.add(parent1[i].refId__c);
		}

		// Grab every other location from the first half of the parent2 and insert it into the second half of the child.
		j = 0;
		Integer childLocsMax = (integer)Math.ceil((parent1.size() + parent2.size()) / 2);
		for (i = Seg2Start; i < childLocsMax ; i += 2) {
			childLocs.add(parent2[j]);
			usedlocations.add(parent2[j].refId__c);
			j += 2;
		}

		// now fill in the gaps in the child with parent2 locations (starting with the 2nd half and wrapping if needed)
		Boolean completeloop = false;

		for (j = Seg2Start+1, i = childLocs.size(); i < childLocsMax;) {
			while (usedlocations.contains(parent2[j].refId__c) && j < parent2.size())
				j++;
			if (j < parent2.size())
				childLocs.add(parent2[j]);
			else {
				if (completeloop)
					break;
				j = 1;
				completeloop = true;
				continue;
			}
			i++;
		}

		//Since this is for clustering only - We're going to reset the home

		return childLocs;
	}

	//
	// Method 1 to find the right members for Cluster 1
	// Pick out a set of locations, find the center
	// go find everything that is close and move it into the cluster. 
	// recheck and save if it looks good.
	//
	public static void buildCluster1(list<LocationData__c> locations) {
		// assumes that clusters are built
		list<LocationData__c> cluster = new list<LocationData__c>();
		list<LocationData__c> otherClusters = new list<LocationData__c>();

		for (Integer i = 0; i < locations.size(); i++) {
			if (locations[i].Cluster__c == 1)
				cluster.add(locations[i]);
			else
				otherClusters.add(locations[i]);
		}
		// mark that as the center
		Integer bc = bestCenter(cluster);
		Location center = Location.newInstance(cluster[bc].Location__Latitude__s, cluster[bc].Location__Longitude__s); 

		for (Integer i = 0, j = 1; i < cluster.size(); i++)
			if (i == bc) {
				cluster[i].Index__c = 0;
				cluster[i].Distance__c = 0;
			}
			else {
				cluster[i].Index__c = j++;
				cluster[i].Distance__c = Location.getDistance(center,Location.newInstance(cluster[i].Location__Latitude__s, 
																						   cluster[i].Location__Longitude__s),
																							'mi');
			}
		for (Integer i = 0; i < otherClusters.size(); i++)
			otherClusters[i].Distance__c = Location.getDistance(center,Location.newInstance(otherClusters[i].Location__Latitude__s, 
																						    otherClusters[i].Location__Longitude__s),
																							'mi');
		// sort by distance from the center (lowest distance)
		list<LocationData__c> sortedCluster = SortDistance(cluster);
		list<LocationData__c> sortedOtherCluster =  SortDistance(otherClusters);

		// move the closest entries into the base cluster

	}

	//
	//	Sort the location data based upon the Distance value.
	//	Not sure if this is faster than writing my own sort for the limited number of elements in a cluster.
	//
	private static list<LocationData__c> SortDistance(list<LocationData__c> li_ld) {
		list<LocationDataWrapper> ldwList = new List<LocationDataWrapper>();
		for (LocationData__c ld : li_ld)
			ldwList.add(new LocationDataWrapper(ld));

		ldwList.sort();
		list<LocationData__c> sortedList = new list<LocationData__c>();
		for (Integer i = 0; i < ldwList.size(); i++)
			sortedList.add(ldwList[i].ld);
		return sortedList;
	}



	//
	//  method to find the best Center within a single cluster using the Fitness1 calculation
	//
	public static Integer bestCenter(list<LocationData__c> locations) {
		Decimal bestFitness = 200000000;		// Set a really high (bad) value to start with;
		Integer bestCenter = 0;
		for (Integer i = 0; i < locations.size(); i++) {
			Decimal newFitness = betterCenter(locations, i, bestFitness);
			if (newFitness < bestFitness) {
				bestCenter = i; 
				bestFitness = newFitness;
			}
		}
		return bestCenter;
	}

	//
	//	Given a list of locations, a center, and a previous "fitness" value, determine if this is a better center or not 
	//  using the fitness1 calculation.
	//
	public static Decimal betterCenter(list<LocationData__c> locations, Integer prevCenter, Decimal prevFitness) {	
		Decimal runningDistanceSquared;
		Decimal maxDistance = 0;
		Location center = Location.newInstance(locations[prevCenter].Location__Latitude__s, locations[prevCenter].Location__Longitude__s);

		for (Integer i = 0; i < locations.size(); i++) {
			if (i != prevCenter) {
				Decimal thisDistance = Location.getDistance(center,Location.newInstance(locations[i].Location__Latitude__s, 
																						   locations[i].Location__Longitude__s),
																							'mi');
				if (thisDistance > maxDistance)
					maxDistance = thisDistance;
				runningDistanceSquared += thisDistance;
				if ((Math.sqrt(runningDistanceSquared) + maxDistance) > prevFitness)
					return (Math.sqrt(runningDistanceSquared) + maxDistance);
			}
		}
		return (Math.sqrt(runningDistanceSquared) + maxDistance);
	}

	// The cost is the lowest Std. Deviation from the starting point.
	// The input is an array of longitude/latitude pairs

	// We return the locations of the base index for each cluster (whatever was marked as index 0 for each cluster)
	public static list<Integer> CalculateCost(list<LocationData__c> locations) {

		Integer i;
		if (locations.size() < 2) 
			return new list<Integer>();

		// Determine the number of clusters and the "center" of the cluster  (clusters are numbered 1-n)
		Integer NumClusters = 0;
		list<Integer> baseIndex = new list<Integer>();
		list<Location> baseLocation = new list<Location>();

		for (i = 0; i < locations.size(); i++) {
			if (locations[i].Cluster__c > NumClusters) 				// Keep track of the max number of clusters
				NumClusters = (Integer)locations[i].Cluster__c;
			if (baseIndex.size() < NumClusters)						// make sure the array can handle the max size
				for (Integer j = 0, k = NumClusters-baseIndex.size(); j < k; j++) {
					baseIndex.add(0);
					baseLocation.add(new Location());
				}
			if (locations[i].index__c == 0) { 						// store the index and location of the "center" location
				baseIndex[((Integer)locations[i].Cluster__c)-1] = i;
				baseLocation[((Integer)locations[i].Cluster__c)-1] = Location.newInstance(locations[i].Location__Latitude__s, 
																   								 locations[i].Location__Longitude__s);
			}
			locations[i].Mean__c = null;
			locations[i].Variance__c = null;
			locations[i].Std_Dev__c = null;
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
				li_distance[cluster] =  Location.getDistance(baseLocation[cluster], 
															 Location.newInstance(locations[i].Location__Latitude__s, 
																			   	  locations[i].Location__Longitude__s),
															 'mi');
				locations[i].Distance__c = li_distance[cluster];
				li_totalDistance[cluster] += li_distance[cluster];
				li_numEntries[cluster] ++;
			}
			else locations[i].Distance__c = null;
		}

		//CalculateStandardDeviations(locations, baseIndex, li_totalDistance, li_numEntries, li_totalDifference, NumClusters);
		CalculateFitness1(locations, baseIndex, li_totalDistance, li_numEntries, li_totalDifference, NumClusters);

		return baseIndex;
	}

	// ---------------------------------------------------------------
	// Routine to calculate fitness routine #1
	// ---------------------------------------------------------------
	private static void CalculateFitness1(list<LocationData__c> locations, list<Integer> baseIndex, list<Decimal> li_maxDistance, list<Decimal> li_numEntries, list<Decimal> li_totalDifference, Integer NumClusters) {
		Integer i;
		Integer cluster;

		// calculate the sum of the difference between each point and the start
		For (i = 0; i < locations.size(); i++) { 
			cluster = ((Integer)locations[i].Cluster__c) - 1;
			if (i != baseIndex[cluster])
				li_totalDifference[cluster] += (locations[i].Distance__c * locations[i].Distance__c);
				if (li_maxDistance[cluster] < locations[i].Distance__c)
					li_maxDistance[cluster] = locations[i].Distance__c;
		}

		for (cluster = 0; cluster < NumClusters; cluster++) {
			locations[baseIndex[cluster]].Fitness__c = math.sqrt(li_totalDifference[cluster]) + li_maxDistance[cluster];

		}
	}


	// ---------------------------------------------------------------
	// Routine to calculate standard deviation for the distances
	// ---------------------------------------------------------------
	private static void CalculateStandardDeviations(list<LocationData__c> locations, list<Integer> baseIndex, list<Decimal> li_totalDistance, list<Decimal> li_numEntries, list<Decimal> li_totalDifference, Integer NumClusters) {
		Integer i;
		Integer cluster;
		// Calculate the mean for each cluster
		for (cluster = 0; cluster < NumClusters; cluster++) {
			locations[baseIndex[cluster]].Mean__c = li_totalDistance[cluster] / li_numEntries[cluster];
		}

		// calculate the sum of the difference between the distance and the mean squared
		For (i = 0; i < locations.size(); i++) { 
			cluster = ((Integer)locations[i].Cluster__c) - 1;
// TODO : At some point, see if the compiler knows to only compute the values once.			
			if (i != baseIndex[cluster])
				li_totalDifference[cluster] += (locations[i].Distance__c - locations[baseIndex[cluster]].Mean__c) * (locations[i].Distance__c - locations[baseIndex[cluster]].Mean__c);
		}

		// Calculate the variance and std. dev for each cluster
		for (cluster = 0; cluster < NumClusters; cluster++) {
			locations[baseIndex[cluster]].Variance__c = li_totalDifference[cluster] / li_numEntries[cluster];
			locations[baseIndex[cluster]].Std_Dev__c = math.sqrt(li_totalDifference[cluster] / li_numEntries[cluster]);
		}
	}



	// ---------------------------------------------------------------
	// Here are the cross cluster manipulation routines 
	// In-route mutations 

	// a sequence in the middle of the cluster is extracted, reversed, and re-inserted in the same location.
	// ---------------------------------------------------------------
	public static void PerformClusterIRInversion (list<LocationData__c> locations) {
	}

	// ---------------------------------------------------------------
	// two values are transpositioned in a cluster
	// ---------------------------------------------------------------
	public static void PerformClusterIRTransposition (list<LocationData__c> locations) {
	}

	// ---------------------------------------------------------------
	// a value is moved from one location to another within a cluster
	// ---------------------------------------------------------------
	public static void PerformClusterIRInsertion (list<LocationData__c> locations) {
	}

	// ---------------------------------------------------------------
	// Cross-route mutations 

	// n number of items are transposed with n number of items in a different cluster
	// ---------------------------------------------------------------
	public static void PerformClusterCRTransposition (list<LocationData__c> locations) {
	}

	// ---------------------------------------------------------------
	// two clusters are combined and then cluster sizes equalized.
	// ---------------------------------------------------------------
	public static void PerformClusterCRContraction (list<LocationData__c> locations) {
	}

	// ---------------------------------------------------------------
	// a cluster is broken into two clusters and clusters sizes are equalized
	// ---------------------------------------------------------------
	public static void PerformClusterCRInsertion (list<LocationData__c> locations) {
	}




}