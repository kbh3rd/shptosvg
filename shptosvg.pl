#!/usr/bin/perl

#------------------------------------------------------------------------
# Copyright (c) 2009, Ken Hardy
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#------------------------------------------------------------------------


use Geo::ShapeFile ;
use SVG ;
use Geo::Point ;
use Geo::Proj4 ;

$default_width = 72 * 8 ;
$default_height = 72 * 10 ;

require 'getopt.pl' ;
&Getopt ('xyTpd') ;
sub Usage { my ($msg) = @_ ;
        print STDERR $msg, "\n" if ($msg ne "") ;
        print STDERR <<_EOU;
Usage: $0 [-x xsize] [-y ysize] [-l] [-p precision] [-d deltamin] [-T srs] [-S srs] inputspec [inputspec ...]\n" ;
        -l lists the names of the attribute fields in the shapefile and then exits.
        -x xsize is image width (in points?); defaults to 
        -y ysize is image height (in points?)
        -T srs is for Target projection spatial reference system in Proj4 format; defaults to rectilinear lat/lon 
        -S srs is the default Source spatial reference system in Proj4 format; defaults to rectilinear lat/lon 
        -p precision is the number of decimal points used in the SVG for position coordinates; defaults to 1
        -d deltamin is the minimum change in either x or y from the previously plotted point in a line or polygon
           for the next one to be plotted.  This reduces file size by omitting points that are very, very close to
           each other.  Good results are achieved with -p1 -d0.5, which are the defaults.

        An "inputspec" contains the shapefile path (with or without .shp) and a list of processing/rendering options
           separated by commas but no spaces.  (Spaces are okay in some options where needed, but not between.)
           Options contain a name and a value joined by an equal signe: name=value.  Currently supported options:

                        Option    Value
                        srs       Source SRS for the shapefile, in Proj4 format
                        group     Name of an attribute to group objects by
                        grep      Name of an attribute by which to select records for inclusion, and a
                                  pcre regex by which to choose them, joined with a tilde.
                                  E.g.: "grep=FIPSCODE~(04)|(35)" might choose records for Arizona and New Mexico
                                  if the records has a field named FIPSCODE that contains the state FIPS code.
                        style     Additional or replacement SVG "style" elements for rendering this shapefile
                                  E.g.: "style=stroke: #800000; stroke-width: 1.5; fill: #ffff80"
                        rad       Radius for the circle drawn for point shapes.  Only circles are currently used.
                        nodraw    Set to "true" or "1" to inhibit rendering of the shapefile; useful for influencing
                                  the scale when rendering other files, as when creating layers separately.
                        colorby   An attribute name followed by a list of pcre regexes and color specs; the fill for
                                  each shape is set to the color associated with the first matching regex.
                                  E.g.: "colorby="RANGE;m/0 to 50/#cfef7f;m/50 to 100/#a1f574;m/100 to 200/#95fbcb"
                                  In this example, the RANGE field contains strings like "0 to 50".  Full-blown
                                  regexes are possible, though.
         Example inputspec: 
            Rivers.shp,grep="NAME~(Red)|(Brazos)|(Pecos)",style="stroke:#1821DE;stroke-width:1",srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" 
_EOU
        exit 1 ;
}

&Usage if (defined ($opt_h) ) ;
&Usage('no input files')  unless ($#ARGV >= 0) ;


#  Parse input files & handling
#-----------------------------------------------------------------------

#- default coord systems ... not very universal
$main::opt_S = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" unless (defined ($opt_S) ) ;
$main::opt_T = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" unless (defined ($opt_T) ) ;

my $s_srs      = Geo::Proj4->new($opt_S) if (defined ($opt_S) ) ;
my $t_srs      = Geo::Proj4->new($opt_T) if (defined ($opt_T) ) ;

my $prec = (defined ($opt_p) ? $opt_p : 1) ;
my $delta = (defined ($opt_d) ? $delta : 0.5) ;

#- find maximum bounds and a common scale
$main::opt_x = $default_width, printf STDERR "no x size specified; using %d\n", $opt_x   unless (defined ($opt_x) ) ;
$main::opt_y = $default_height, printf STDERR "no y size specified; using %d\n", $opt_y   unless (defined ($opt_y) ) ;
my ($x_min, $y_min, $x_max, $y_max) = (999999999, 999999999, -999999999, -999999999) ;


my @shpf ;	# array of shapefile objects
my @flist ;	# array of file names


my ( %srs, %grpby, %grep, %pcre, %style, %nosho, %grpsof, %cmatch ); # commandline parameters, parsed, per inputfile

foreach (@ARGV) {

	#- Peak ahead at each shapefile; qualifying records if grep is used.
	#- Find a bounding box so a scale factor can be determined.

	my ($f, @opt) = split(/,/) ;		# split inputspec into file & options
	$f =~ s/\.[sdpt][hbrx][pfjxnt]$// ;	# strip .shp .dbf .prj .sbx .sbn .txt
	$bn = $f ; $bn =~ s=.*/== ;		# basename w/o directories or suffix
	push @flist, $f ;

	$shpf[$#flist] = new Geo::ShapeFile($f) || die "Ack! $!" ;

	if (defined ($opt_l) ) {
		#- user looking for list of field names only
		print $f, ":" ;
		my %dbf = $shpf[$#flist]->get_dbf_record(1) ; # read first dbf for keys
		foreach my $k (keys %dbf) {
			print " '", $k, "' " unless ($k =~ m/^_/ || $k =~ m/_$/) ;
		}
		print "\n" ;
		next ;	#- so shortcircuit everything below.
	}

	foreach my $o (@opt) {
		#- parse out all the inputspec options
		if ($o =~ m/([^=]+)=(.+)/) {
			my ($k, $v) = ($1, $2) ;
			$k =~ tr/[A-Z]/[a-z]/ ;
			# looks something like: inputfile[,srs="+proj=...",group="fldname",grep="fldname~pcre",style="svg-styles,nodraw=[yes|1]"
			if (		$k eq "srs"	) {
				#$srs{$f} = $v ;
				$srs{$f} = Geo::Proj4->new($v) ;
			} elsif (	$k eq "group"	) {
				$grpby{$f} = $v ;
			} elsif (	$k eq "grep"	) {
				($grep{$f}, $pcre{$f}) = split(/~/, $v) ;
			} elsif (	$k eq "style"	) {
				$style{$f} = $v ;
			} elsif (	$k eq "rad"	) {
				$radius{$f} = $v ;
			} elsif (	$k eq "nodraw"	) {
				$nosho{$f} = 1 if ($v =~ m/^y/i  ||  $v =~ m/^true/i) ;
			} elsif (	$k = "colorby"	) {
				my @clist = split (/;/, $v) ;
				$clrfld{$f} = shift @clist ;
				foreach my $cx (@clist) {
					if ($cx =~ m=m/([^/]*)/(#[0-9a-f]+)=i) {
						$cmatch{$f}{$1} = $2 ;
					}
				}
				undef $cx ;
			} else {
			  	printf STDERR "Input spec error: file '%s': unknown directive '%s'\n", $f, $k ;
			}

		} else {
			printf STDERR "Input spec error: file '%s' cannot parse '%s'\n", $f, $o ;
			exit 1 ;
		}
	}

	#- this file uses default srs because none specified in inputspec
	$srs{$f} = $s_srs if (!defined ($srs{$f}) ) ;

	#- if grepping but not group specified, group by the grep field
	$grpby{$f} = $grep{$f} if (defined ($grep{$f}) && !defined ($grpby{$f}) ) ;


	if (defined ($grpby{$f}) || defined ($grep{$f}) ) {
		#- build list(s) of records to include from this shapefile, whether grepping or just grouping
		my $rmax = $shpf[$#flist]->records() ;
		my @rlist ;
		foreach my $rx (1 .. $rmax) {
			my %data = $shpf[$#flist]->get_dbf_record($rx) ;
			if (defined ($pcre{$f}) ) {
				next unless ($data{$grep{$f}} =~ m/$pcre{$f}/i) ;
			}
			push @{$grpsof{$f}{$data{$grpby{$f}}}}, $rx ;
			my $shp = $shpf[$#flist]->get_shp_record($rx);
			foreach my $pt ($shp->points() ) {
				#- searching for the shapes' projected bounding box.
				#- problems with this approach in comments a little
				#- farther down the page.
				my $pr_pt = $srs{$f}->transform($t_srs, [$pt->X, $pt->Y]);
				$x_min = $pr_pt->[0] if ($pr_pt->[0] < $x_min) ;
				$y_min = $pr_pt->[1] if ($pr_pt->[1] < $y_min) ;
				$x_max = $pr_pt->[0] if ($pr_pt->[0] > $x_max) ;
				$y_max = $pr_pt->[1] if ($pr_pt->[1] > $y_max) ;
			}
		}
	} else {
		#- one group of all shapes, to make rendering code a single case
		my $rmax = $shpf[$#flist]->records() ;
		my @rlist ;
		foreach my $rx (1 .. $rmax) {
			push @{$grpsof{$f}{$bn}}, $rx ;
		}
	}

	if (!defined ($grpby{$f}) ) {
		#- bounds weren't discovered above, do it here based on projection of the
		#- shapefiles' bounds.
		#- NOTE: This is imperfect because of the projecting going on; the sides might
		#-       bow out, e.g.  The "right" way would be /very/ slow, and this is "okay"-ish.
		my ($x0, $y0, $x1, $y1) = $shpf[$#flist]->bounds() ;
		my $pr_point = $srs{$f}->transform($t_srs, [$x0, $y0]);
		  $x0 = $pr_point->[0] ; $y0 = $pr_point->[1] ;
		my $pr_point = $srs{$f}->transform($t_srs, [$x1, $y1]);
		  $x1 = $pr_point->[0] ; $y1 = $pr_point->[1] ;
		$x_min = $x0 if ($x0 < $x_min) ;
		$y_min = $y0 if ($y0 < $y_min) ;
		$x_max = $x1 if ($x1 > $x_max) ;
		$y_max = $y1 if ($y1 > $y_max) ;
	}

}
exit 0 if (defined ($opt_l) ) ; #- that's all the user wanted.



#-----------------------------------------------------------------------

#- A scaling factor can be determined now from the bounding box discovered
#- above and the output size.

my $scale = $opt_x / ($x_max - $x_min)  ;
my $yscale = $opt_y / ($y_max - $y_min)  ;
$scale = $yscale if ($yscale < $scale) ;

#- default line styles
my %default_styles =	(	'stroke-width'		=> '1'
			,	'stroke-linecap'	=> 'square'
			,	'stroke-linejoin'	=> 'bevel'
			,	'stroke-miterlimit'	=> '3'
			,	'stroke-opacity'	=> '1'
			,	'stroke-width'		=> '0.5'
			,	'stroke'		=> '#000000'
			,	'fill'			=> 'none'
			) ;


#- Definitely gonna need one of these...
my $svg= SVG->new(width=>$opt_x,height=>$opt_y);

#- not used... a half-baked idea for autocoloring variations... put back in the oven sometime later...
my @strokes = ("'black'", "'red'", "'green'", "'blue'", "'magenta'", "'brown'", "'orange'") ;

#- for making unique group & shape object id's
my $shpct = 1 ;
my $grpct = 1 ;

#- The fun begins... go through each shapefile, rendering the shapes selected in the peek-head loop above.

foreach my $fx (0 .. $#shpf) {

	next if (defined ($nosho{$f}) ) ;

	my $f = $flist[$fx] ;								#- filename is the key to the inputspec hashes
	my $fgroup = $svg->group( id => &GrpName(\$grpct, $f)) ; $grpct++ ;

	my %lstyle ; # = %default_styles ;
	foreach my $k (keys %default_styles) {
		$lstyle{$k} = $default_styles{$k} ;
	}
	if (defined ($style{$f}) ) {
		foreach (split (/\s*;\s*/, $style{$f}) ) {
			my ($k,$v) = split (/\s*:\s*/) ;
			$lstyle{$k} = $v ;
		}
	}
	undef ($lstyle{fill}) if (defined ($clrfld{$f}) ) ; # scotch that if using per-shape colors

	printf STDERR "Input '%s'", $f ;

	#- for each group of shapes...
	foreach my $grpkey (keys %{$grpsof{$f}} ) {
		printf STDERR "   %s", $grpkey ;

		my $g=$fgroup->group( id => &GrpName(\$grpct, $grpkey), style => \%lstyle) ;	#- new SVG group

		foreach my $sx (@{$grpsof{$f}{$grpkey}}) {					#- iterate list of shapes for this group...
			my $shp = $shpf[$fx]->get_shp_record($sx) ;				#- get a shape record
			my %dbf = $shpf[$fx]->get_dbf_record($sx) ;				#- get attributes, we might need them
			my $type = $shp->shape_type() ;						#- what kind of tiger is this?
			my %shtyle = () ;							#- scratchpad for per-item style if needed
			if (defined ($clrfld{$f}) ) {						#- for 'colorby' inputspec
				foreach my $pcre (keys %{$cmatch{$f}}) {
					if ($dbf{$clrfld{$f}} =~ m/$pcre/i) {			#- find a regex that this record matches
						$shtyle{fill} = $cmatch{$f}{$pcre} ;		#- and set the corresponding fill color
					}
				}
			} else {
				undef %shtyle ;							#- nah, false alarm, no grepping here
			}


			next if ($type == 0) ;							#- a null type?  yeah, that's useful!

			if ($type == 1 || $type == 8 || $type == 11 || $type == 18 || $type == 21 || $type == 28) {
				#- a Point type.  We'll use a circle that's big enough to see, instead.
				#- Note: need a way to specify different sorts of shapes to render for a point object.

				my @points = $shp->points() ;
				foreach my $pt (@points) {
					#- iterating through the points in the shape

					my $pr_pt = new Geo::Point ;				#- for translating

					#- do the translation from source srs to target srs
					if (defined ($srs{$f}) && defined ($opt_T) ) {
						$pr_pt = $srs{$f}->transform($t_srs, [$pt->X, $pt->Y]);
					} else {
						$pr_pt = [$pt->X, $pt->Y] ;			#- null translation (ever gonna happen?)
					}

					#- scale and translate
					my $nx = sprintf "%0.*f", $prec, (($pr_pt->[0]-$x_min)*$scale) ;
					my $ny = sprintf "%0.*f", $prec, ($opt_y - (($pr_pt->[1]-$y_min)*$scale)) ;
					#- render with or without per-shape color
					if (defined ($clrfld{$f} && $clrfld{$f} ne "") ) {
						$g->circle(	cx=>$nx
							,	cy=>$ny
							,	r=>(defined($radius{$f})?$radius{$f}:2)
							,	id=>'circ'.$shpct++
							,	style=> \%shtyle
							) ;
					} else {
						$g->circle(	cx=>$nx
							,	cy=>$ny
							,	r=>(defined($radius{$f})?$radius{$f}:2)
							,	id=>'circ'.$shpct++
							) ;
					}
					undef $pr_pt ;
				}
			} else {
				#- this is a line or a line or polygon
				#- build a list of points either way

				foreach my $px (1 .. $shp->num_parts() ) {				#- could be multiple parts
					my $pstr = "" ;							#- empty string of points
					my ($prx, $pry) = (-1, -99.228) ;				#- "p"revious point; need a better "none yet" flag
					my ($nx, $ny) ;							#- next point coords in shapefile coords
					my @points = $shp->get_part($px) ;				#- get a list of points
					my $pr_pt = new Geo::Point ;					#- for "pr"ojected point
					foreach my $pt (@points) {

						#- project the point (or not)
						if (defined ($srs{$f}) && defined ($t_srs) ) {
							$pr_pt = $srs{$f}->transform($t_srs, [$pt->X, $pt->Y]);
						} else {
							$pr_pt = [$pt->X, $pt->Y] ;
						}

						#- scale and translate the projected points
						$nx = ( ( ($pr_pt->[0] - $x_min)*$scale)) ; 
						$ny = ((($pr_pt->[1]-$y_min)*$scale));

						#- add to list of points iff "-d deltamin" distance away from previously plotted point
						#- (should this use (sqrt(dx^2+dy^2) i.e. hypotenuseal(?) distance instead of just x,y?)
						if ( (abs($nx-$px) > $delta) || (abs($ny-$py) > $delta) ) {
							$pstr .= sprintf "%.*f,%.*f ", $prec, $nx, $prec, $opt_y - $ny ;
							$px = $nx ; $py = $ny ;
						}
					}
					undef $pr_pt ;
				
					#- polygon or line, colorby or not
					if ($type == 5 || $type == 15 || type == 25) {
						if (defined ($clrfld{$f}) && $clrfld{$f} ne "") {
							$g->polygon (	points=>$pstr
								,	id=>"pgon$shpct"
								,	style=> \%shtyle
								) ;
						} else {
							$g->polygon (	points=>$pstr
								,	id=>"pgon$shpct"
								) ;
						}
						$shpct++ ;
					} else {
						if (defined ($clrfld{$f}) && $clrfld{$f} ne "") {
							$g->polyline (	points=>$pstr
								,	id=>"line$shpct"
								,	style=> \%shtyle
								) ;
						} else {
							$g->polyline (	points=>$pstr
								,	id=>"line$shpct"
								) ;
						}
						$shpct++ ;
					}
				}
			}
		}
		print STDERR "\n" ;
	}
}

#- render SVG to stdout
print $svg->xmlify ;



exit 0 ;	#- C'est finis.  Et tres magnifique.

################################################################################
#- utility functions

sub PrintDetails { my ($shpfr) = @_ ;

	printf "Shape type:        %d (%s)\n", $$shpfr->shape_type(), $$shpfr->shape_type_text() ;
	printf "Number of shapes:  %d\n", $$shpfr->shapes() ;
	printf "Number of records: %d\n", $$shpfr->records() ;
	my ($x_min, $y_min, $x_max, $y_max) = $$shpfr->bounds() ;
	printf "Bounds:            %0.3f, %0.3f ... %0.3f, %0.3f  (%0.3f x %0.3f)\n", $x_min, $y_min, $x_max, $y_max, ($x_max - $x_min), ($y_max - $y_min) ;
}
#-------------------------------------------------------------------------------

sub AlphaNum {	my ($word) = @_ ;

	$word =~ s/[^-A-Z0-9_]+/_/ig ;

	return $word ;
}
#-------------------------------------------------------------------------------

sub GrpName {	my ($ctref, $title) = @_ ;

	$title = "g" . $$ctref . "-" . substr (&AlphaNum ($title), 0, 32) ;
	$$ctref++ ;
	return $title ;
}
#-------------------------------------------------------------------------------
