#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Math::Trig qw(great_circle_distance deg2rad);

use DBI;
die "need a database as the first parameter" unless (
    defined $ARGV[0] && -f $ARGV[0]
);

my $dbh = DBI->connect(
    'dbi:SQLite:dbname='.$ARGV[0],'','',
) or die $!;

sub NESW {deg2rad($_[0]), deg2rad(90 - $_[1])}


my (%sql,%sth);

$sql{'select_shapes'} = <<EOSQL;
SELECT *
FROM gtfs_shapes
WHERE shape_dist_traveled IS NULL
ORDER BY shape_id, shape_pt_sequence
EOSQL

$sql{'update_shape_pt'} = <<EOSQL;
UPDATE gtfs_shapes
SET shape_dist_traveled = ?
WHERE shape_id = ? AND shape_pt_sequence = ?
EOSQL

foreach my $key (keys %sql) {
    $sth{$key} = $dbh->prepare($sql{$key}) or die $!;
}

$| = 1;

print "Selecting shape data\n";
$sth{'select_shapes'}->execute();

print "Processing shape data\n";
my $row_count = 0;
my $data; 
$dbh->do('BEGIN TRANSACTION') or die $!;
while(my $row = $sth{'select_shapes'}->fetchrow_hashref() ){
    my @current_point = NESW( 
        $row->{'shape_pt_lon'}, 
        $row->{'shape_pt_lat'} 
    );
    if( 
        $data->{$row->{'shape_id'}} && 
        $data->{$row->{'shape_id'}}->{last_point} 
    ) {
        $data->{$row->{'shape_id'}}->{distance} += great_circle_distance( 
            @{$data->{$row->{'shape_id'}}->{last_point}}, 
            @current_point,
            6378
        );
    } else {
        $data->{$row->{'shape_id'}} = { distance => 0 };
    }

    $data->{$row->{'shape_id'}}->{last_point} = [@current_point];

    $sth{'update_shape_pt'}->execute(
        $data->{$row->{'shape_id'}}->{distance},
        $row->{'shape_id'},
        $row->{'shape_pt_sequence'} 
    ) or die $!;
    ++$row_count;
    if ($row_count % 1000 == 0 ) {
        $dbh->do('COMMIT TRANSACTION');
        $dbh->do('BEGIN TRANSACTION');
        print ".";
    }
} 
$dbh->do('COMMIT TRANSACTION') or die $!;
print "\nall done\n";

