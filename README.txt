Last updated $Date: 2009/08/01 01:45:17 $

"shptosvg.pl" is a Perl program (script, whatever) that renders one or
more ESRI Shapefiles in an SVG (Scalable Vector Graphics) file.  The SVG
file created can be subsequently edited with an SVG editor like Inkscape
to ammend the results of the rendering and to add finishing touches.

Three external Perl modules (available from CPAN) are required by this
program:

    Geo::ShapeFile
        http://search.cpan.org/~jasonk/Geo-ShapeFile-2.52/lib/Geo/ShapeFile.pm  
    SVG
        http://search.cpan.org/~ronan/SVG-2.49/lib/SVG/Manual.pm
    Geo::Point 
        http://search.cpan.org/~markov/Geo-Point-0.91/lib/Geo/Point.pod
    Geo::Proj4
        http://search.cpan.org/~markov/Geo-Proj4-1.01/lib/Geo/Proj4.pod

No other external dependencies should exit.

------------------------------------------------------------------------

Manifest:

    shptosvg.pl:   The perl program
    mkogallala.sh: A shellscript containing an example use of the program
    README.txt:    You're reading it now.

------------------------------------------------------------------------

Command line arguments and parameters (seen with "-h" option):

Usage: $0 [-x xsize] [-y ysize] [-l] [-p precision] [-d deltamin] [-T srs] [-S srs] inputspec [inputspec ...]\n" ;

    -l lists the names of the attribute fields in the shapefile and
       then exits.

    -x xsize is image width (in points?); defaults to 576

    -y ysize is image height (in points?) 720

    -T srs is for Target projection spatial reference system in
       Proj4 format; defaults to rectilinear lat/lon

    -S srs is the default Source spatial reference system in Proj4
       format; defaults to rectilinear lat/lon

    -p precision is the number of decimal points used in the SVG
       for position coordinates; defaults to 1

    -d deltamin is the minimum change in either x or y from the
       previously plotted point in a line or polygon for the next one
       to be plotted.  This reduces file size by omitting points that
       are very, very close to each other.  Good results are achieved
       with -p1 -d0.5, which are the defaults.

    An "inputspec" contains a shapefile path (with or without .shp)
    and a list of processing/rendering options separated by commas
    but no spaces.  (Spaces are okay in some options where needed,
    but not between.)  Options contain a name and a value joined by
    an equal signe: name=value.  Currently supported options:

	Option	  Value
	--------  -------------------------------------------------- 
	srs       Source SRS for the shapefile, in Proj4 format

	group	  Name of an attribute to group objects by

	grep	  Name of an attribute by which to select records for
		  inclusion, and a pcre regex by which to choose them,
		  joined with a tilde.	E.g.: "grep=FIPSCODE~(04)|(35)"
		  might choose records for Arizona and New Mexico if
		  the records has a field named FIPSCODE that contains
		  the state FIPS code.

	style	  Additional or replacement SVG "style" elements for
		  rendering this shapefile E.g.: "style=stroke: #800000;
		  stroke-width: 1.5; fill: #ffff80"

	rad	  Radius for the circle drawn for point shapes.
	          Only circles are currently used.

	nodraw	  Set to "true" or "1" to inhibit rendering of the
		  shapefile; useful for influencing the scale when
		  rendering other files, as when creating layers
		  separately.

	colorby   An attribute name followed by a list of pcre regexes
		  and color specs; the fill for each shape is set to
		  the color associated with the first matching regex.
		  E.g.: "colorby="RANGE;m/0 to 50/#cfef7f;m/50 to
		  100/#a1f574;m/100 to 200/#95fbcb" In this example,
		  the RANGE field contains strings like "0 to 50".
		  Full-blown regexes are possible, though.

Example inputspec: 
Rivers.shp,grep="NAME~(Red)|(Brazos)|(Pecos)",style="stroke:#1821DE;stroke-width:1",srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" 


