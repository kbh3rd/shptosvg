#!/bin/sh

########################################################################
#  Example of how to use shptosvg.pl
########################################################################
#
#  This script was used to generate the map found at
#  http://commons.wikimedia.org/wiki/File:Ogallala_saturated_thickness_1997-sattk97-v2.svg
# 
#  The shapefiles used are:
# 
#    ogallala_us_state.shp: Outline of the 8 states overlying the Ogallala
# 	Aquifer.  This is used twice; once for the background color that
# 	must underly all other layers, and once for just the outlines
# 	that lie above the aquifer rendering.  These two uses invoke
# 	the same file(s) under two different names (ogallala_us..., and
# 	og-ogallala_us...) that are links of the same instance because
# 	of a shortcoming in the current code; the inputspec parameters
# 	are hashed by the filename.  It would be easy to code around
# 	this problem and it's on the first list of enhancements to make.
# 
#    sattk_97.shp: Saturated thickness of the aquifer.  This file contains
# 	complex shapes that overlap each other.  They must be drawn in
# 	the order encountered, so no regrouping can be done.  The shapes
# 	are colored according to the "RANGE" attribute, which contains
# 	the specific strings being matched in the inputspec.
# 
#    co99_d00.shp: All counties in the United States.  Only the files in
# 	the 8 states shown are drawn by using a 'grep' directive in the
# 	input spec that selects the countyies by the states' FIPS codes.
# 
#    Rivers.sh: The channels of the major rivers of the United States.
# 	Select only the Platte, Arkansas, Red, and Brazos rivers by use
# 	of the 'grep' directive.  This picks up the Red River in North
# 	Dakota, so that must be removed later by postprocess editing.
# 	Also, the Red and Arkansas are post-edited to remove the extents
# 	that lie beyond the eight target states.
# 
#  The SRS of each input file is specified in its inputspec.
# 
#  The target projection is an Albers Equal Area centered on the aquifer
#  at 100 degrees west longitude with standard parallels at 29.5 and 45.5
#  degrees north latitude.  This is specified in the +proj argument to
#  the -T parameter.
# 
#  The only post-processing on the output of this script before posting to wikimedia:
# 
#    * The rivers were edited to remove the extraneous northern Red River
#      and to clip the Arkansas and Red rivers at the state lines.
#      Also, a reservoir outline on the Red River was manually removed.
#    * The thin stroke outline was added to the aquifer areas; this ought
#      to have been there from the script and bears
#      further investigation.
#    * The state names and legends were manually added.
########################################################################

shptosvg.pl -x 600 -y 800 "$@" -T "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-100 +x_0=0 +y_0=0 +ellps=clrk66 +datum=NAD83 +units=m +no_defs"	\
\
\
  data/ogallala_us_state.shp,srs="+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs",style="fill:#ffffd0;stroke:none" \
\
\
  data/sattk_97.shp,style="stroke-width:0.333;stroke:#00000;fill:#808080",srs="+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=clrk66 +datum=NAD27 +units=m +no_defs ",colorby="RANGE;m/island/#ffffff;m/0 to 50/#cfef7f;m/50 to 100/#a1f574;m/100 to 200/#95fbcb;m/200 to 400/#77d9f0;m/400 to 600/#93beea;m/600 to 800/#7e90dc;m/800 to 1000/#6145fd;m/1000 to 1200/#1c00d2" \
\
\
  data/co99_d00.shp,srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs ",style="stroke-width:0.333;fill:none;stroke:#D0C0A0",grep="STATE~(48)|(08)|(20)|(31)|(35)|(40)|(46)|(56)",group=STATE \
\
\
  data/og-ogallala_us_state.shp,group=NAME,srs="+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs",style="stroke-width:1;fill:none;stroke:#a08070" \
\
\
  data/Rivers,grep="NAME~(Platte)|(Red)|(Brazos)|(Arkansas)",style="stroke:#1821DE;stroke-width:1",srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" \
\
    > ogallala.svg


exit $?

