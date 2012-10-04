<?php 
header("content-type:text/json");

if(! $db = $dbh = new PDO('sqlite:data/gtfs_action.db') ) {
    die ("no database");
} else {
    switch($_GET['func']) {
        case 'running':
            $trips = $db->query('
SELECT route_id, shape_id, gtfs_trips.trip_id, s1.shape_dist_traveled 
FROM gtfs_calendar NATURAL JOIN gtfs_trips NATURAL JOIN gtfs_stop_times AS s1 JOIN gtfs_stop_times s2 ON s1.trip_id = s2.trip_id AND s1.stop_sequence = s2.stop_sequence +1 
WHERE 
    36000 >= s1.arrival_time_seconds AND s2.departure_time_seconds >= 36000 AND
CASE strftime("%w","2012-08-17")
 WHEN "0" THEN gtfs_calendar.sunday
 WHEN "1" THEN gtfs_calendar.monday
 WHEN "2" THEN gtfs_calendar.tuesday
 WHEN "3" THEN gtfs_calendar.wednesday
 WHEN "4" THEN gtfs_calendar.thursday
 WHEN "5" THEN gtfs_calendar.friday
 WHEN "6" THEN gtfs_calendar.saturday
END
AND strftime("%Y%m%d","2012-08-17") BETWEEN start_date AND end_date 
GROUP BY gtfs_trips.trip_id;'
            )->fetchAll(PDO::FETCH_ASSOC);
            print(json_encode($trips));
        break;
        case 'shape-pts':
            if(!array_key_exists('id',$_GET) ) {
                return;
            }
            $shape_pts = $db->prepare('
SELECT 
 shape_pt_lat,
 shape_pt_lon,
 shape_pt_sequence,
 shape_dist_traveled
FROM gtfs_shapes
WHERE shape_id = ? 
ORDER BY shape_pt_sequence;');



            $shape_pts->execute(array($_GET['id']));
            $feature = array(
                'type' => 'Feature',
                'id' => $_GET['id'],
                'properties' => array(
                    'shape_dist_traveled' => array()
                ),
                'geometry' => array(
                    'type' => 'LineString',
                    'coordinates' => array()
                )
            );
            foreach ($shape_pts->fetchAll(PDO::FETCH_ASSOC) as $pt ) {
                $feature['properties']['shape_dist_traveled'][] = 
                    $pt['shape_dist_traveled'];

                $feature['geometry']['coordinates'][] = array(
                    $pt['shape_pt_lon'],$pt['shape_pt_lat']
                );
            }
            print (json_encode($feature));
            print "\n";
        break;
    }
}
?>
