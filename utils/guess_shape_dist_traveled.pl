#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Math::Trig qw(great_circle_distance deg2rad);

sub NESW {deg2rad($_[0]), deg2rad(90 - $_[1])}

$/ = "\r\n"; 

$_ = <>;
chomp;
@_ = split /,/;

my %columns;
for( my $i = 0; $i < @_; ++$i ) {
    $columns{$_[$i]} = $i;
}

print $_,",shape_dist_traveled\r\n";

my $data; 
while(<>){
    chomp; @_ = split /,/;
    my @current_point = NESW( 
        $_[$columns{'shape_pt_lon'}], 
        $_[$columns{'shape_pt_lat'}] 
    );
    if( 
        $data->{$_[$columns{'shape_id'}]} && 
        $data->{$_[$columns{'shape_id'}]}->{last_point} 
    ) {
        $data->{$_[$columns{'shape_id'}]}->{distance} += great_circle_distance( 
            @{$data->{$_[$columns{'shape_id'}]}->{last_point}}, 
            @current_point,
            6378
        );
    } else {
        $data->{$_[$columns{'shape_id'}]} = { distance => 0 };
    }

    $data->{$_[$columns{'shape_id'}]}->{last_point} = [@current_point];

    print join(",", (@_,$data->{$_[$columns{'shape_id'}]}->{distance})),"\r\n";
} 

