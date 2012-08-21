#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use Math::Trig qw(great_circle_distance deg2rad );
sub NESW { deg2rad($_[0]), deg2rad(90 - $_[1]) }

use List::Util qw( min max reduce );

use Cache::MemoryCache;
my $cache = new Cache::MemoryCache;

use DBI;
die "need a database as the first parameter" unless (
    defined $ARGV[0] && -f $ARGV[0]
);

my $dbh = DBI->connect(
    'dbi:SQLite:dbname='.$ARGV[0],'','',
) or die $!;
#my $dbh = DBI->connect(
#    'dbi:CSV:','','',
#    {
#        f_dir => $ARGV[0],
#        f_ext => '.txt',
#    }
#) or die $!;

my (%sql,%sth);

$sql{'select_trips'} = <<EOSQL;
SELECT route_id, service_id, trip_id, shape_id
FROM gtfs_trips
ORDER BY route_id, service_id, trip_id
EOSQL

$sql{'select_stops'} = <<EOSQL;
SELECT stop_id, stop_lat, stop_lon, trip_id, stop_sequence
FROM gtfs_stop_times NATURAL JOIN gtfs_stops
WHERE trip_id = ? AND shape_dist_traveled IS NULL
ORDER BY stop_sequence
EOSQL

$sql{'select_shape'} = <<EOSQL;
SELECT *
FROM gtfs_shapes
WHERE shape_id = ?
ORDER BY shape_pt_sequence
EOSQL

$sql{'update_stop_times'} = <<EOSQL;
UPDATE gtfs_stop_times
SET shape_dist_traveled = ?
WHERE trip_id = ? AND stop_sequence = ?
EOSQL

foreach my $key (keys %sql) {
    $sth{$key} = $dbh->prepare($sql{$key}) or die $!;
}

my $DEBUG = 0;

$| = 1;

$sth{'select_trips'}->execute() or die $!;
while (my $trip = $sth{'select_trips'}->fetchrow_hashref()) {
    $dbh->do("BEGIN TRANSACTION");

    $sth{'select_shape'}->execute($trip->{'shape_id'});
    $sth{'select_stops'}->execute($trip->{'trip_id'});
    
    my $shape = $sth{'select_shape'}->fetchall_arrayref({});
    my $stops = $sth{'select_stops'}->fetchall_arrayref({});

    printf( "route: %s trip: %s shape: %s\n", $trip->{'route_id'},$trip->{'trip_id'},$trip->{'shape_id'});

    for( my ($i,$j) = (0,0); $i < @$stops; ++$i ) {
        my $key = join(":", ($trip->{'shape_id'},$stops->[$i]->{'stop_id'}));
        print "Looking for $key\n" if $DEBUG > 1;
    

        my $short = [-1,-1];
        if( not defined $cache->get($key)) {
            print "Cache Miss\n" if $DEBUG > 2;

            my $data = [];
            for(; $j < @$shape-1; ++$j ) {
        
                my $dist1_to_stop = great_circle_distance(
                    NESW(@{$stops->[$i]}{'stop_lat','stop_lon'}),
                    NESW(@{$shape->[$j]}{'shape_pt_lat','shape_pt_lon'}),
                    6378
                );
                my $dist2_to_stop = great_circle_distance(
                    NESW(@{$stops->[$i+0]}{'stop_lat','stop_lon'}),
                    NESW(@{$shape->[$j+1]}{'shape_pt_lat','shape_pt_lon'}),
                    6378
                );
                my $segment_length = great_circle_distance(
                    NESW(@{$shape->[$j+0]}{'shape_pt_lat','shape_pt_lon'}),
                    NESW(@{$shape->[$j+1]}{'shape_pt_lat','shape_pt_lon'}),
                    6378
                );
                push @{$data}, [$j,$dist1_to_stop + $dist2_to_stop - $segment_length];
            }
            $short = reduce { $a->[1] < $b->[1] ? $a : $b } @{$data};
            $j = $short->[0];
            $cache->set($key,$j);
        } else {
            print "Cache Hit\n" if $DEBUG > 2;
            $j = $cache->get($key);
        }

        my $distance = 
            $shape->[$j]->{'shape_dist_traveled'} + 
            great_circle_distance(
                NESW(@{$stops->[$i]}{'stop_lat','stop_lon'}),
                NESW(@{$shape->[$j]}{'shape_pt_lat','shape_pt_lon'}),
            );
        
        printf "%3i : %3i : %02.2f\n",$i,$j,$distance,if $DEBUG > 0;
        $sth{'update_stop_times'}->execute($distance,$stops->[$i]->{'trip_id'},$stops->[$i]->{'stop_sequence'}) or warn $!;
    }
    $dbh->do("COMMIT TRANSACTION");
#    last;
}


