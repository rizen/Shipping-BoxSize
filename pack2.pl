#!/usr/bin/perl

use Data::Dumper qw(Dumper);

# TODO
#~~~~~~~~~~
# Split module from examples
# Begin part of module
# Test different algorithms
# Multiple boxes:
#    1) pick smallest box that can hold whole volume
#	  2) Pack
#    3) If something does not fit and there is a bigger box, start over with bigger box
#	  4) If already at biggest box, pack till full, set full box aside
#	  5) start back at 1 with remaining items
# Some day:  Switch to use PDL for fast array searching
#            and when searching if a item fits in a box, only search item perimiter, not whole volume   

# ------------------------------------------------------------------
# SETTINGS
#   items go inside boxes
#   size of items are rounded up to nearest int
#   box sizes are rounded down to nearest int
# ------------------------------------------------------------------
my @BOX_CURSORS = qw(YXZ YZX XYZ ZXY);   # First cursor is tried first each time

my $ITEM_SORT = 'byVolume';              # or use byBiggestSide
my $ITEM_START_ROTATION =
  'YXZ';    # Y is smallest side, Z is longest (ie flat side down)
            # Boxes will use this same start rotation
my @ITEM_ROTATE_ORDER =    
  qw(XYZ YXZ XZY YZX);    # what order to try shapes inside the box
                          # xyz means don't rotate on first try
			  # See large comment block below for more info

my $ITEM_STRATEGY = 'TryAllRotations_ThenNextCursor';
			  # or 'TryAllSpots_ThenNextRotation';

my $SCALE = 2;  # SCALE=1 a 12x12 box = 144 item array.  System only handles whole numers.
		# use SCALE=2 for 0.5 inch accuracy. 12x12 becomes 24x24.
		# Larger scale GREATLY slows down performance

# ------------------------------------------------------------------
#
# ITEM ROTATION EXAMPLE
#   2 high, 1 wide, 3 long.
#   2 Y   , 1 X   , 3 Z
#   XYZ = 1,2,3
#         ___
#        /  /|
#       /  //| Z
#      /_ ///
# Y 2 |__|//
#   1 |__|/
#    0  1  X ->
#
#  If rotate biggest side down, 1 high, 2 wide, 3 long is the same as
#        rotate along XY (Z stays same) or ITEM_ROTATE = 'YXZ'
#  If rotated tall, so X still 1, Y=3 and Z=2
#        that is ITEM_ROTATE = 'XZY' where x stays the same.
# ------------------------------------------------------------------
# END SETTINGS
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# CONSTANTS
#   put this in a Begin someday
# ------------------------------------------------------------------
my $EMPTY           = undef;
my $TRUE            = 1;
my $FALSE           = undef;
my $FULL            = 1;
my %OPPOSITE_ROTATE = (
	XYZ => 'XYZ',
	XZY => 'XZY',
	ZYX => 'ZYX',
	YXZ => 'YXZ',
	ZXY => 'YZX',
	YZX => 'ZXY'
);

# ------------------------------------------------------------------
# PACKAGE GLOBALS
# ------------------------------------------------------------------
my $BOX_STATS = $FALSE;    # Gather and print statistics
my $XYZ_DELIM = ',';

# ------------------------------------------------------------------

# ------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------
# TEST ROTATES
# my ($I, $M, $O) = ();
# my ($I2, $M2, $O2) = ();
# my @types = qw(XYZ XZY ZYX ZXY YXZ YZX);
# foreach my $type (@types){
#    ($I, $M, $O) = xyzRotate( $type, qw(x y z));
#    my $rev_type = $OPPOSITE_ROTATE{$type};
#    ($I2, $M2, $O2) = reverse_xyzRotate( $type, $I, $M, $O);
#    print "(x y z) -$type-> ($I, $M, $O) -$rev_type-> ($I2, $M2, $O2)\n";
# }

# CREATE ONE BOX
# Typical box sizes
# 9,7,1.5
# 12,12,12
# 12,18,3
my %container = ();
boxCreate( \%container, 12, 12, 12 );
boxEnableStats( \%container );    #turn stats collection on

$Cards     = '2.5,3.5,1';
$Pawns     = '1,0.5,0.5';
$Dice      = '0.75,0.75,0.75';
$BoxedGame = '10.75,10.75,1.75';

# Make a simple packing list
my @packing_list  = ();
my %packing_items = (
	a => $BoxedGame,
	b => $BoxedGame,
	c => $BoxedGame,
	d => $BoxedGame,
	e => $Cards,
	f => $Cards,
	g => $Cards,
	h => $Cards,
	I => $Cards,
	j => $Cards,
	M => $BoxedGame,
	N => $BoxedGame,
	s => $Pawns,
	t => $Pawns,
	u => $Pawns,
	v => $Pawns,
	w => $Pawns,
	x => $Pawns,
	y => $Pawns,
	z => $Dice,
);

# Create Items
foreach my $id ( keys %packing_items ) {
	my %item = ();
	my ( $x, $y, $z ) = split( /,/, $packing_items{$id} );
	itemCreate( \%item, $x, $y, $z, $id );
	push @packing_list, \%item;
}

# Sort packing list biggest to smallest
@overflow = ();
my @list = sortStuff( order => $ITEM_SORT, object_list => \@packing_list );
foreach my $item (@list) {
	if ( !boxPackItem( \%container, $item ) ) {
		push @overflow, $item;
		my ( $x, $y, $z ) = itemGetDimensions($item);
		my $id = itemGetID($item);
		print "boxPackItem failed for item:$id size ($x,$y,$z)\n";
		print "=============================\n";
	}
	else {
	}
}

#print results
# boxPrint(\%container);
boxStatsPrint( \%container );

print "\n";
foreach my $item (@overflow) {
	my ( $x, $y, $z ) = itemGetDimensions($item);
	my $id = itemGetID($item);
	print "Could Not Pack: item:$id size($x,$y,$z)\n";
}

print "\n";

# END MAIN

# ///////////////////////////////////////////
# =============================================
sub sortStuff {
	my (%param) = @_;

	# Get all the values once and put in a hash
	my %buffer = ();
	my $value  = 0;
	my @return = ();
	foreach my $item ( @{ $param{object_list} } ) {
		if ( $param{order} eq 'byVolume' ) {
			$value = itemGetVolume($item);
		}
		elsif ( $param{order} eq 'byBiggestSide' ) {
			$value = itemGetBigSideArea($item);
		}
		push( @{ $buffer{$value} }, $item );
	}
	foreach $value ( sort { $b <=> $a } keys %buffer ) {
		push( @return, @{ $buffer{$value} } );
	}
	return @return;
}

# ///////////////////////////////////////////
#        ITEM                ITEM
# ///////////////////////////////////////////
# =============================================
sub itemGetID {
	my ($ref) = shift @_;
	return $ref->{id};
}

# =============================================
sub itemGetBigSideArea {
	my ($ref) = shift @_;
	my ( $big, $next, $small ) = sort { $b <=> $a } ( itemGetDimensions($ref) );
	return $big * $next;
}

# =============================================
sub itemGetVolume {
	my ($ref) = shift @_;
	return $ref->{volume};
}

# =============================================
sub itemSetID {
	my ($ref) = shift @_;
	$ref->{id} = shift @_;
}

# =============================================
sub itemSetLocation {
	my ( $ref, $x, $y, $z ) = @_;
	$ref->{x} = $x;
	$ref->{y} = $y;
	$ref->{z} = $z;
}

# =============================================
sub itemCreate {

	#   Make a simple rectangular box
	#
	#  Y is height of box, shortest dimension
	#  X is width of box, middle
	#  Z is length of box, longest dimension
	#
	#  START_ROTATION controls which way biggest side faces
	#

	my ( $ref, $x, $y, $z, $id ) = @_;

	# set Y dimension smallest
	( $x, $y, $z ) = sort { $a <=> $b } ( $x, $y, $z );    #sort small to large
	( $x, $y, $z ) = xyzRotate( $ITEM_START_ROTATION, $x, $y, $z );
	( $x, $y, $z ) = map { $_ * $SCALE } ( $x, $y, $z );
	$ref->{x}      = roundup($x);
	$ref->{y}      = roundup($y);
	$ref->{z}      = roundup($z);
	$ref->{volume} = $x * $y * $z;
	$ref->{id}     = $id;

	return $TRUE;

}

# =============================================
sub roundup {
	my $n = shift;
	return ( $n == int($n) ) ? $n : int( $n + 1 );
}

# =============================================
sub rounddown {
	my $n = shift;
	return int($n);    #rounds down
}

# =============================================
sub itemGetDimensions {
	my ($ref) = shift @_;
	if ( defined $ref->{x} ) {
		if (wantarray) {
			return ( $ref->{x}, $ref->{y}, $ref->{z} );
		}
		else {
			return join( $XYZ_DELIM, $ref->{x}, $ref->{y}, $ref->{z} );
		}
	}
	else {
		return $FALSE;
	}
}

# =============================================

# ///////////////////////////////////////////
#        CURSOR          CURSOR
# ///////////////////////////////////////////
# =============================================
sub cursorGetLocation {

	# return xyz of cursor
	return itemGetDimensions(@_);
}

# =============================================
sub cursorSetLocation {

	# return xyz of cursor
	return itemSetLocation(@_);
}

# =============================================
sub cursorSetId {
	my ($ref) = shift @_;
	$ref->{id} = shift @_;
}

# =============================================

# ///////////////////////////////////////////
#         BOX        BOX        BOX
# ///////////////////////////////////////////
# =============================================
sub boxCreate {

	#  Creates a new rectangular box with empty space in it
	#    See itemCreate for how dimensions are sorted small to large
	#
	#  Order of cursors is important
	#  YXZ scans up and over-X first, then back-Z on the long dimension
	#  XYZ scans over-Z, then up, then back-z
	#  ZXY scans length-z, then over-X along bottom before up
	#
	my ( $ref, $max_x, $max_y, $max_z, $id ) = @_;
	my ( $x, $y, $z ) = 0;

	# If given decimals, round down because we care about the size inside the box
	$x = rounddown($x);
	$y = rounddown($y);
	$z = rounddown($z);

	# itemCreate takes care of rotating everything
	# create then get back the rotated dimensions
	itemCreate( $ref, $max_x, $max_y, $max_z, $id );
	( $max_x, $max_y, $max_z ) = itemGetDimensions($ref);

	# Initialize cursors
	@{ $ref->{cursor_types} } = @BOX_CURSORS;

	#foreach my $cursor_type (@{ $ref->{cursor_types} }){
	#        my %cur = ();
	#        cursorSetLocation(\%cur, 0,0,0);
	#        $ref->{cursor}{$cursor_type} = \%cur;   # store new cursor
	#}

	# Initialize box empty space
	my @space = ();

	while ( $x < $max_x ) {
		$y = 0;
		while ( $y < $max_y ) {
			$z = 0;
			while ( $z < $max_z ) {
				$space[$x][$y][$z] = $EMPTY;
				$z++;
			}
			$y++;
		}
		$x++;
	}
	$ref->{volume_remaining} = ( $max_x * $max_y * $max_z );
	$ref->{space}            = \@space;
	$ref->{stats}            = $BOX_STATS;                     # true or false
	_boxUpdateCursors($ref);
}

# =============================================
sub boxDeleteCursor {
	my ( $ref, $cursor_type ) = @_;
	@{ $ref->{cursor_types} } =
	  grep( !/^$cursor_type$/, @{ $ref->{cursor_types} } );
	delete $ref->{cursor}{$cursor_type};

	print "DeleteCursor results: " . Dumper( $ref->{cursor} ) . "\n";
}

# =============================================
sub boxStatsPrint {
	my ($ref)     = shift @_;
	my $stat      = '';
	my $remaining = boxGetRemainingVolume($ref);
	my $total     = $ref->{volume};
	my $used_vol  = $total - $remaining;

	print "STRATEGY: \n";
	print "   Algorithm: $ITEM_STRATEGY \n";
	print "   Sort: $ITEM_SORT InitialRotation:$ITEM_START_ROTATION\n";
	print "   Box Cursors: " . join( ',', @BOX_CURSORS ) . "\n";
	print "   Item Rotate: " . join( ',', @ITEM_ROTATE_ORDER ) . "\n";
	print "STATS: \n";
	print "   remaining volume = $remaining\n";
	print "   percent full = "
	  . int( ( 1 - $remaining / $total ) * 100 ) . "%\n";

	foreach $stat ( sort keys %{ $ref->{stats} } ) {
		print "   $stat: $ref->{stats}{$stat}\n";
	}

	# special stats
	print "AVERAGES: \n";
	print "    Excess Scans/Item: "
	  . ( $ref->{stats}{cells_scanned_item} - $used_vol ) / $ref->{stats}{items}
	  . "\n";
	print "    Rotations Checked/Item: "
	  . ( $ref->{stats}{item_rotations} ) / $ref->{stats}{items} . "\n";
	print "    Cursors Checked/Item: "
	  . ( $ref->{stats}{cursor_tests} ) / $ref->{stats}{items} . "\n";
	print "    Vol/Item: " . $used_vol / $ref->{stats}{items} . "\n";

	return $TRUE;
}

# =============================================
sub boxStatsIncrement {
	my ( $ref, %attrib ) = @_;
	while ( my ( $key, $value ) = each %attrib ) {
		$ref->{stats}{$key} += $value;
	}
	return $TRUE;
}

# =============================================
sub boxEnableStats {
	my ($ref) = shift @_;
	$ref->{stats} = $TRUE;
}

# =============================================
sub boxDisableStats {
	my ($ref) = shift @_;
	$ref->{stats} = $FALSE;
}

# =============================================
sub boxIsStatsEnabled {
	my ($ref) = shift @_;
	return $ref->{stats};
}

# =============================================
sub boxGetDimensions {
	return itemGetDimensions(@_);
}

# =============================================
sub boxGetRemainingVolume {
	my ($ref) = shift @_;
	return $ref->{volume_remaining};
}

# =============================================
sub boxDecreaseRemainingVolume {
	my ( $ref, $amount ) = @_;
	my $orig = $ref->{volume_remaining};
	$ref->{volume_remaining} = $orig - $amount;

# print "\t boxDecreaseRemaining org:$orig  - amt:$amount= $ref->{volume_remaining}\n";

	return $ref->{volume_remaining};
}

# =============================================
sub boxPrint {
	my ($box) = shift @_;
	my ( $x, $y, $z ) = 0;
	my @table_head = ();
	my %cursors    = ();

	my @space = @{ $box->{space} };
	my ( $max_x, $max_y, $max_z ) = boxGetDimensions($box);

	foreach my $cursor_type ( @{ $box->{cursor_types} } ) {
		my $this_cursor = $box->{cursor}{$cursor_type};
		( $x, $y, $z ) = cursorGetLocation($this_cursor);

		# my $id = substr($cursor_type,0,1); #get first char
		# $id = 'c' . $id ;
		$cursors{"$x,$y,$z"} = $cursor_type;
	}
	$table_head[0] = " Z->|";
	$table_head[1] = "  X +";
	$z             = 0;
	while ( $z < $max_z ) {
		$table_head[0] .= sprintf( "%3s", $z );
		$table_head[1] .= "-" x 3;
		$z++;
	}
	$table_head[0] .= "|\n";
	$table_head[1] .= "+\n";

	( $x, $y, $z ) = ( 0, $max_y - 1, 0 );
	while ( $y >= 0 ) {
		print "\n    ------------ Slice Y=$y ------------\n";
		$x = 0;
		print $table_head[0];
		print $table_head[1];
		while ( $x < $max_x ) {
			printf( " %3s|", $x );    #
			$z = 0;
			while ( $z < $max_z ) {
				if ( defined $cursors{"$x,$y,$z"} ) {
					printf( "%3s", $cursors{"$x,$y,$z"} );
				}
				else {
					printf( "%3s", $space[$x][$y][$z] );
				}
				$z++;
			}
			print "|\n";
			$x++;
		}
		print $table_head[1];
		$y--;
	}
	print "============================================\n";
}    #end PrintBox

# =============================================
sub boxPackItem {

	#  Place item in box, returns 0 if it can not fit in box

	my ($box)             = shift @_;
	my ($item)            = shift @_;
	my %duplicate         = ();
	my $location          = '';
	my $stat_count_cursor = 0;
	my $stat_count_rot    = 0;
	my $this_cursor       = '';
	my $item_rotation     = '';
	my $PACKIT            = $FALSE;
	my $cursor_type       = '';

	# Simple size test #1
	my $avail_vol = boxGetRemainingVolume($box);
	my $item_vol  = itemGetVolume($item);
	if ( $item_vol > $avail_vol ) {
		print
"Try item($item->{id})  item_vol:$item_vol is greater than available volume:$avail_vol\n";
		return $FALSE;
	}

	# print "boxPackItem: Try item($item->{id}) _____________\n";

	if ( $ITEM_STRATEGY eq 'TryAllSpots_ThenNextRotation' ) {

		# Iterate over rotations slowly
	 ROTATION: foreach $item_rotation (@ITEM_ROTATE_ORDER) {
			next if ( !$item_rotation );

			# Try All Cursor Spots
			$stat_count_rot++;
			my $stat_count_cursor = 0;
		 CURSOR: foreach $cursor_type ( @{ $box->{cursor_types} } ) {
				next if ( !$cursor_type );
				$this_cursor = $box->{cursor}{$cursor_type};
				$location    = cursorGetLocation($this_cursor);
				next
				  if ( $duplicate{$location} eq $TRUE )
				  ;    # some cursors are stacked in same spot

				$stat_count_cursor++;

#print "Try item($item->{id}) cursor:$stat_count_cursor at:$location with rotation:$stat_count_rot rot:$item_rotation\n";
				if ( _boxCanItemFit( $box, $item, $item_rotation, $this_cursor ) ) {
					_boxUpdateCursors( $box, $item, $item_rotation );
					$PACKIT = $TRUE;
					$PACKIT = $TRUE;
					last ROTATION;    #end both loops
				}
			}
			$duplicate{$location} = $TRUE;
		}    # end foreach rotation

	}
	else {

		# Assume default ($ITEM_STRATEGY eq ''TryAllRotations_ThenNextCursor'')
		# Iterate over cursors slowly
	 CURSOR: foreach $cursor_type ( @{ $box->{cursor_types} } ) {
			next if ( !$cursor_type );
			$this_cursor = $box->{cursor}{$cursor_type};
			$location    = cursorGetLocation($this_cursor);
			next
			  if ( $duplicate{$location} eq $TRUE )
			  ;    # some cursors are stacked in same spot

			# Try All Rotations First
			$stat_count_cursor++;
			$stat_count_rot = 0;
		 ROTATION: foreach $item_rotation (@ITEM_ROTATE_ORDER) {
				next if ( !$item_rotation );
				if ( _boxCanItemFit( $box, $item, $item_rotation, $this_cursor ) ) {
					_boxWriteItem( $box, $item, $item_rotation, $this_cursor );
					_boxUpdateCursors( $box, $item, $item_rotation );
					$PACKIT = $TRUE;
					last CURSOR;    #end both loops
				}
				$stat_count_rot++;
			}
			$duplicate{$location} = $TRUE;
		}
	}

	if ( boxIsStatsEnabled($box) ) {
		boxStatsIncrement(
			$box,
			item_rotations => $stat_count_rot,
			cursor_tests   => $stat_count_cursor
		);
		boxStatsIncrement( $box, cursor_first_success => 1 )
		  if ( $stat_count_cursor == 1 );
		boxStatsIncrement( $box, rotation_first_success => 1 )
		  if ( $stat_count_rot == 0 );
	}

	return $PACKIT;    #TRUE or FALSE
}

# =============================================
sub _boxCanItemFit {

	#    Only searches in positive direction.

	my ( $box, $item, $rotation, $cursor ) = @_;

	my @space           = @{ $box->{space} };
	my $stat_cell_count = 0;
	my $CANFIT          = $TRUE;

	my ( $max_x,     $max_y,     $max_z )     = boxGetDimensions($box);
	my ( $itemMax_x, $itemMax_y, $itemMax_z ) = itemGetDimensions($item);
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $itemMax_x, $itemMax_y, $itemMax_z ) =
		  xyzRotate( $rotation, $itemMax_x, $itemMax_y, $itemMax_z );
	}
	my ( $cur_x, $cur_y, $cur_z ) = cursorGetLocation($cursor);

	# Simple size test
	if (  ( $itemMax_x + $cur_x ) > $max_x
		or ( $itemMax_y + $cur_y ) > $max_y
		or ( $itemMax_z + $cur_z ) > $max_z )
	{
		return $FALSE;
	}

	# Set start point at cursor xyz
	my ( $x, $y, $z ) = ( $cur_x, $cur_y, $cur_z );

	my %DEBUG_box = ();
	boxCreate( \%DEBUG_box, $max_x, $max_y, $max_z );
	my @DEBUG_space = @{ $DEBUG_box{space} };

	# We fill across the bottom, so test in X (narrowest) direction first
	while ( $z < $itemMax_z + $cur_z and $z < $max_z ) {
		$y = $cur_y;
		while ( $y < $itemMax_y + $cur_y and $y < $max_y ) {
			$x = $cur_x;
			while ( $x < $itemMax_x + $cur_x and $x < $max_x ) {
				$stat_cell_count++;
				$DEBUG_space[$x][$y][$z] = '+';
				if ( $space[$x][$y][$z] ne $EMPTY ) {
					my $CANFIT = $FALSE;
					last;    #break out of all loops
				}
				$x++;
			}
			$y++;
		}
		$z++;
	}

	#print "boxCanItemFit DEBUG print\n";
	#boxPrint(\%DEBUG_box);

	if ( boxIsStatsEnabled($box) ) {
		boxStatsIncrement( $box, cells_scanned_item => $stat_cell_count );
	}

	return $CANFIT;
}

# =============================================
sub _boxWriteItem {
	my ( $box, $item, $rotation, $cursor ) = @_;

	my @space = @{ $box->{space} };
	my ( $max_x,     $max_y,     $max_z )     = boxGetDimensions($box);
	my ( $itemMax_x, $itemMax_y, $itemMax_z ) = itemGetDimensions($item);
	my $itemVolume = itemGetVolume($item);
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $itemMax_x, $itemMax_y, $itemMax_z ) =
		  xyzRotate( $rotation, $itemMax_x, $itemMax_y, $itemMax_z );
	}
	my $item_id = itemGetID($item);
	my ( $cur_x, $cur_y, $cur_z ) = cursorGetLocation($cursor);

# print "boxWriteItem item:$item_id cursor:($cur_x,$cur_y,$cur_z) rotation: $rotation\n";

	# Set start point at cursor xyz
	my ( $x, $y, $z ) = ( $cur_x, $cur_y, $cur_z );

	$y = $cur_y;
	while ( $y < $itemMax_y + $cur_y and $y < $max_y ) {
		$x = $cur_x;
		while ( $x < $itemMax_x + $cur_x and $x < $max_x ) {

			$z = $cur_z;
			while ( $z < $itemMax_z + $cur_z and $z < $max_z ) {
				$space[$x][$y][$z] = $item_id;
				$z++;
			}
			$x++;
		}
		$y++;
	}
	boxDecreaseRemainingVolume( $box, $itemVolume );
	if ( boxIsStatsEnabled($box) ) {
		boxStatsIncrement( $box, items => 1 );
	}
}

# =============================================
sub _boxUpdateCursors {
#
# Move each cursor to next free spot in the box
#  optionaly provide item just written to shorten search for where to move cursors

	my ( $box, $item, $rotation ) = @_;

	#  Y is height of box, shortest dimension
	#  X is width of box, middle
	#  Z is length of box, longest dimension
	#
	#  YXZ scans up and over-X first, then back-Z on the long dimension
	#  XYZ scans over-Z, then up, then back-z
	#  ZXY scans length-z, then over-X along bottom before up

	my ( $max_x, $max_y, $max_z ) = boxGetDimensions($box);
	my @space            = @{ $box->{space} };
	my $stat_count_moves = 0;
	my $stat_count_cells = 0;

	my ( $item_x, $item_y, $item_z ) = itemGetDimensions($item);
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $item_x, $item_y, $item_z ) =
		  xyzRotate( $rotation, $item_x, $item_y, $item_z );
	}

 CURSOR_TYPE: foreach my $cursor_type ( @{ $box->{cursor_types} } ) {
		my ( $cur_x, $cur_y, $cur_z ) = ( 0, 0, 0 );
		my $this_cursor = $box->{cursor}{$cursor_type};
		if ( defined $this_cursor ) {
			( $cur_x, $cur_y, $cur_z ) = cursorGetLocation($this_cursor);
		}
		else {
			# somebody added a cursor, lets initialize it
			# print "UpdateCursors:  INITIALIZE cursor $cursor_type (0,0,0)\n";
			my %cur = ();
			$this_cursor = \%cur;
			cursorSetLocation( $this_cursor, 0, 0, 0 );
			$box->{cursor}{$cursor_type} = $this_cursor;    # store new cursor
			( $cur_x, $cur_y, $cur_z ) = cursorGetLocation($this_cursor);
		}
		if ( $space[$cur_x][$cur_y][$cur_z] eq $EMPTY ) {
			next CURSOR_TYPE;    # nothing to change with this one
		}
		$stat_count_moves++;

# Use xyz Rotate to set the Outer, Middle, and Inner loop variables
# This is the dimension search order (aka gravity) controling which direction cursors prefer.
# example:  cursor type is YXZ, so inner most loop should be Y to check all Y positions first.
#  ($I, $M, $O) = ( y, x, z) same as ($I, $M, $O) = xyzRotate( 'YXZ'...
#
#print "Type $cursor_type Initial Location ($cur_x, $cur_y, $cur_z) = [$space[$cur_x][$cur_y][$cur_z]]\n";
		my ( $I_init, $M_init, $O_init ) =
		  xyzRotate( $cursor_type, $cur_x, $cur_y, $cur_z );
		my ( $I, $M, $O ) = ( $I_init, $M_init, $O_init );

		# If we have item dimensions, move one dimension of cursor that far
		if ( $item_x >= 0 and $item_y >= 0 and $item_z >= 0 ) {
			( $item_length, undef, undef ) =
			  xyzRotate( $cursor_type, $item_x, $item_y, $item_z );
			$I = $I + $item_length;
		}

		my ( $Inner_max, $Mid_max, $Out_max ) =
		  xyzRotate( $cursor_type, $max_x, $max_y, $max_z );

		my ( $x, $y, $z ) = 0;
		while ( $O < $Out_max ) {
			while ( $M < $Mid_max ) {
				while ( $I < $Inner_max ) {
					( $x, $y, $z ) = reverse_xyzRotate( $cursor_type, $I, $M, $O );
					$stat_count_cells++;

 # print "Cur:$cursor_type IMO:$I,$M,$O: xyz($x,$y,$z)=[$space[$x][$y][$z]] \n";
					if ( $space[$x][$y][$z] eq $EMPTY ) {

						# found a open spot, need to set the right XYZ spot
						cursorSetLocation( $this_cursor, $x, $y, $z );
						next CURSOR_TYPE;
					}
					$I++;
				}

				#$I = 0;  #start new col at 0?
				$I = $I_init;    #start new where we started
				$M++;
			}

			#$M = 0;  #start new row
			$M = $M_init;       #start new row
			$O++;
		}

		# If we get here, next available spot is out of bounds
		# store it anyway so that the cursor is moved and less scanning happens
		# Delete the cursor so we do not keep trying it.
		boxDeleteCursor( $box, $cursor_type );

	}    #end boxUpdateCursor

	if ( boxIsStatsEnabled($box) ) {
		boxStatsIncrement(
			$box,
			cursor_moves             => $stat_count_moves,
			cells_scanned_cursorMove => $stat_count_cells
		);
	}

	# print "END UpdateCursors\n" .   boxPrint( $box );   #DEBUG
	return $TRUE;
}

# =============================================
sub reverse_xyzRotate {

	# a type of reverse rotation.  Do opposite of what type says
	my ( $type, $x, $y, $z ) = @_;
	return xyzRotate( $OPPOSITE_ROTATE{$type}, $x, $y, $z );
}

# =============================================
sub xyzRotate {

	# Transform x,y,z point to be some other order
	my ( $type, $x, $y, $z ) = @_;

	# print "xyzRotate: $type, $x,$y,$z\n";
	return ( $y, $z, $x ) if ( $type eq 'YZX' );
	return ( $y, $x, $z ) if ( $type eq 'YXZ' );
	return ( $z, $x, $y ) if ( $type eq 'ZXY' );
	return ( $z, $y, $x ) if ( $type eq 'ZYX' );
	return ( $x, $z, $y ) if ( $type eq 'XZY' );
	return ( $x, $y, $z );    # blank or XYZ
}

# =============================================

# =============================================
# END-OF-FILE
