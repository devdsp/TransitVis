#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use JSON::XS;

die "need a database as the first parameter" unless (
    defined $ARGV[0] && -f $ARGV[0]
);

my $dbh = DBI->connect(
    'dbi:SQLite:dbname='.$ARGV[0],'','',
) or die $!;

my (%sql,%sth);

$sql{'select_shapes'} = <<EOSQL;
SELECT shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence,shape_dist_traveled
FROM gtfs_shapes
EOSQL

foreach my $key (keys %sql) {
    $sth{$key} = $dbh->prepare($sql{$key}) or die $!;
}


$sth{'select_shapes'}->execute() or die $!;

my $feature_collection = {
    'type' => 'FeatureCollection',
    'features' => {}
};

while( my $shape_pt = $sth{'select_shapes'}->fetchrow_hashref() ) {
    if( not defined $feature_collection->{'features'}->{ $shape_pt->{'shape_id'} } ) {
        $feature_collection->{'features'}->{ $shape_pt->{'shape_id'} } = {
            'type' => 'Feature',
            'id' => $shape_pt->{'shape_id'},
            'properties' => {
                'shape_dist_traveled' => []
            },
            'geometry' => {
                'type' => 'LineString',
                'coordinates' => []
            }
        };
    }
    my $feature;
    $feature = $feature_collection->{'features'}->{$shape_pt->{'shape_id'}};
    push (
        @{$feature->{'properties'}->{'shape_dist_traveled'}},
        $shape_pt->{'shape_dist_traveled'} 
    );
    push (
        @{$feature->{'geometry'}->{'coordinates'}},
        [@{$shape_pt}{'shape_pt_lon','shape_pt_lat'}]
    );
}

$feature_collection->{'features'} = [values %{$feature_collection->{'features'}}];

print JSON::XS->new->ascii->encode ($feature_collection);
