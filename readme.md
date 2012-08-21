TransitVis
==========

TransitVis is a (very rough and no where near complete) visualisation tool for 
[GTFS](https://developers.google.com/transit/gtfs/reference) files.

It uses [OpenLayers](http://openlayers.org) to pull in
[OpenStreetMap](http://openstreetmap.org) tiles and a
[GeoJson](http://geojson.org) file with the data from the shapes file. A few
short perl scripts in the util/ directory can be used to generate the
geojson.

So far the easiest way I have found to work on GTFS data is to import it in
to an SQLite database. I have a fork of cbick's
[gtfs_SQL_importer](https://github.com/devdsp/gtfs_SQL_importer) which has
an additional index but will hopefully be merged back in.

Current State
=============
At the moment it is all pretty hacky and very incomplete. A few people have
expressed interest in seeing what I am up to and having it not die on a hard
drive never to be worked on again. So here it is. If you line your ducks up
right you will see little busses moving along the shapes from start to end
at a constant speed and returning to the start to go again.

I have a few scripts in the utils directory which are handy for guessing the
shape_dist_traveled field in both the gtfs_shapes table and the
gtfs_stop_times tables. They aren't exactly fast nor do I claim them to be
particularly acurate, but they will do the job for now.

TODO
====
All that's left to do is everything.

