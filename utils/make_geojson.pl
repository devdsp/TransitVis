#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use JSON::XS;

die "Usage ./make_geojson.pl <directory with extracted GTFS>" unless (
    defined $ARGV[0] && -d $ARGV[0]
);

die "'$ARGV[0]/shapes.txt' does not exist" unless -f $ARGV[0]."/shapes.txt";

open (FH, $ARGV[0].'/shapes.txt') or die "Can't read shapes.txt";
my $header = <FH>;
die "shapes file must contain shape_dist_traveled column" 
    unless $header =~ m/shape_dist_traveled/;

my $dbh = DBI->connect(
    'dbi:CSV:','','',
    {
        f_dir => $ARGV[0],
        f_ext => '.txt',
    }
) or die $!;

my (%sql,%sth);

$sql{'select_shapes'} = <<EOSQL;
SELECT shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence,shape_dist_traveled
FROM shapes
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
