package Shipping::BoxSize::Box;

use strict;
use warnings;
use Any::Moose;
use POSIX qw/floor/;
use Shipping::BoxSize::Utility qw/xyz_rotate/;
use Storable qw(dclone);
use Shipping::BoxSize::Cursor;
use Data::GUID;

has cursor_types => (
    default     => sub { [qw(YXZ YZX XYZ ZXY)] },
    is          => 'rw',
);

has cursors => (
    is          => 'rw',
    default     => sub { {} },
    isa         => 'HashRef',
);

has id => (
    is          => 'rw',
    isa         => 'Str',
    lazy        => 1,
    default     => sub { Data::GUID->new->as_string },
);

has x => (
    is          => 'rw',
    required    => 1,
    isa         => 'Int',
);

has y => (
    is          => 'rw',
    required    => 1,
    isa         => 'Int',
);

has z => (
    is          => 'rw',
    required    => 1,
    isa         => 'Int',
);

has volume => (
    is          => 'rw',
    required    => 1,
    isa         => 'Num',
);

has volume_remaining => (
    is          => 'rw',
    required    => 1,
    isa         => 'Num',
);

has rotation => (
    is          => 'rw',
    required    => 1,
    isa         => 'Str',
);

has scale => (
    is          => 'rw',
    required    => 1,
    isa         => 'Int',
);

has enable_stats => (
    is          => 'rw',
    default     => 0,
    isa         => 'Bool',
);

has space => (
    is          => 'rw',
    required    => 1,
    isa         => 'ArrayRef',
);

has stats => (
    is          => 'rw',
    default    => sub { {} },
    isa         => 'HashRef',
);

has packing_list => (
    is          => 'rw',
    isa         => 'ArrayRef',
    default     => sub { [] },
);


around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    my $scale = $args{scale} || 1;

    # adjust the scale of the items. we assume the scale is 1 unit (inch, mm, cm, etc), but you may want to do 1/2 unit scale in which case the scale is 2
    # we use floor here because you can't fit a big item into a small hole, better to err on the side of the box being small rather than big
    my $x = floor($args{x} * $scale);
    my $y = floor($args{y} * $scale);
    my $z = floor($args{z} * $scale);
 
    # sort small to large
	( $x, $y, $z ) = sort { $a <=> $b } ( $x, $y, $z );
    
    $args{rotation} ||= 'XYZ';
    # do the initial rotation
    ( $x, $y, $z ) = xyz_rotate($args{rotation}, $x, $y, $z);

    # initialize 3D space    
    my @space = ();
    my ($x_iterator, $y_iterator, $z_iterator) = 0;
	while ( $x_iterator < $x ) {
		$y_iterator = 0;
		while ( $y_iterator < $y ) {
			$z_iterator = 0;
			while ( $z_iterator < $z ) {
				$space[$x_iterator][$y_iterator][$z_iterator] = 0; # this space is empty
				$z_iterator++;
			}
			$y_iterator++;
		}
		$x_iterator++;
	}
    my $volume = $x * $y * $z;

    $args{x} = $x;
    $args{y} = $y;
    $args{z} = $z;
    $args{volume} = $volume;
    $args{volume_remaining} = $volume;
    $args{space} = \@space;
    $args{scale} = $scale;

    return \%args;
};

sub BUILD {
    my $self = shift;
    foreach my $cursor_type ( @{ $self->cursor_types } ) {
        $self->cursors->{$cursor_type} = Shipping::BoxSize::Cursor->new;
	} 
};

sub clone {
   my ($self, %params) = @_; 
   my $clone = $self->meta->clone_object($self, %params);
   $clone->stats(dclone $self->stats);
   $clone->space(dclone $self->space);
   $clone->cursor_types(dclone $self->cursor_types);
   $clone->packing_list(dclone $self->packing_list);
   $clone->cursors(dclone $self->cursors);
   return $clone;
}

sub dimensions {
    my $self = shift;
    return ($self->x, $self->y, $self->z);
}

sub big_side_area {
    my $self = shift;
	my ( $big, $next, $small ) = sort { $b <=> $a } ( $self->dimensions );
	return $big * $next;
}

sub are_stats_enabled {
    my $self = shift;
    return $self->enable_stats;
}

sub increment_stats {
    my ($self, %attrib) = @_;
    my $stats = $self->stats;
    while ( my ( $key, $value ) = each %attrib ) {
		$stats->{$key} += $value;
	}
    $self->stats($stats);
}

sub decrease_volume_remaining {
    my ($self, $amount) = @_;
    $self->volume_remaining( $self->volume_remaining - $amount );
}

sub can_item_fit { #    Only searches in positive direction.
	my ( $self, $item, $rotation, $cursor ) = @_;

	my @space           = @{ $self->space };
	my $stat_cell_count = 0;
    my $can_fit         = 1;

	my ( $box_x,     $box_y,     $box_z )     = $self->dimensions;
	my ( $item_x, $item_y, $item_z ) = $item->dimensions;
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $item_x, $item_y, $item_z ) = xyz_rotate( $rotation, $item_x, $item_y, $item_z );
	}
	my ( $cursor_x, $cursor_y, $cursor_z ) = $cursor->location;

	# Simple size test
	if (  ( $item_x + $cursor_x ) > $box_x
		or ( $item_y + $cursor_y ) > $box_y
		or ( $item_z + $cursor_z ) > $box_z )
	{
		return 0;
	}

	# Set start point at cursor xyz
	my ( $x, $y, $z ) = ( $cursor_x, $cursor_y, $cursor_z );

	# We fill across the bottom, so test in X (narrowest) direction first
	while ( $z < $item_z + $cursor_z and $z < $box_z ) {
		$y = $cursor_y;
		while ( $y < $item_y + $cursor_y and $y < $box_y ) {
			$x = $cursor_x;
			while ( $x < $item_x + $cursor_x and $x < $box_x ) {
				$stat_cell_count++;
				if ( $space[$x][$y][$z] ne 0 ) {
					my $can_fit = 0;
					last;    #break out of all loops
				}
				$x++;
			}
			$y++;
		}
		$z++;
	}

	if ( $self->are_stats_enabled ) {
		$self->increment_stats(cells_scanned_item => $stat_cell_count );
	}

	return $can_fit;
}

#
# Move each cursor to next free spot in the box
#  optionaly provide item just written to shorten search for where to move cursors

#  Y is height of box, shortest dimension
#  X is width of box, middle
#  Z is length of box, longest dimension
#
#  YXZ scans up and over-X first, then back-Z on the long dimension
#  XYZ scans over-Z, then up, then back-z
#  ZXY scans length-z, then over-X along bottom before up

sub update_cursors {
	my ( $self, $item, $rotation ) = @_;
	my ( $box_x, $box_y, $box_z ) = $self->dimensions;
	my @space            = @{ $self->space };
	my $stat_count_moves = 0;
	my $stat_count_cells = 0;

	my ( $item_x, $item_y, $item_z ) = $item->dimensions;
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $item_x, $item_y, $item_z ) =
		  xyz_rotate( $rotation, $item_x, $item_y, $item_z );
	}

    CURSOR_TYPE: foreach my $cursor_type ( @{ $self->cursor_types } ) {
		my $this_cursor = $self->cursor->{$cursor_type};
		my ( $cursor_x, $cursor_y, $cursor_z ) = $this_cursor->location;
		if ( $space[$cursor_x][$cursor_y][$cursor_z] == 0 ) {
			next CURSOR_TYPE;    # nothing to change with this one
		}
		$stat_count_moves++;

        # Use xyz Rotate to set the Outer, Middle, and Inner loop variables
        # This is the dimension search order (aka gravity) controling which direction cursors prefer.
        # example:  cursor type is YXZ, so inner most loop should be Y to check all Y positions first.
        #  ($inner, $middle, $outer) = ( y, x, z) same as ($inner, $middle, $outer) = xyz_rotate( 'YXZ'...
        
		my ( $inner_init, $middle_init, $outer_init ) = xyz_rotate( $cursor_type, $cursor_x, $cursor_y, $cursor_z );
		my ( $inner, $middle, $outer ) = ( $inner_init, $middle_init, $outer_init );

		# If we have item dimensions, move one dimension of cursor that far
			my ( $item_length, undef, undef ) = xyz_rotate( $cursor_type, $item_x, $item_y, $item_z );
			$inner += $item_length;

		my ( $inner_max, $middle_max, $outer_max ) = xyz_rotate( $cursor_type, $box_x, $box_y, $box_z );

        my ($x, $y, $z);
		while ( $outer < $outer_max ) {
			while ( $middle < $middle_max ) {
				while ( $inner < $inner_max ) {
					( $x, $y, $z ) = reverse_xyz_rotate( $cursor_type, $inner, $middle, $outer );
					$stat_count_cells++;

					if ( $space[$x][$y][$z] == 0 ) { # found a open spot, need to set the right XYZ spot
                        $this_cursor->location($x, $y, $z);
						next CURSOR_TYPE;
					}
					$inner++;
				}
				$inner = $inner_init;    #start new where we started
				$middle++;
			}
			$middle = $middle_init;       #start new row
			$outer++;
		}

		# If we get here, next available spot is out of bounds
		# store it anyway so that the cursor is moved and less scanning happens
		# Delete the cursor so we do not keep trying it.
        $self->delete_cursor($cursor_type);

	}    #end boxUpdateCursor

	if ( $self->are_stats_enabled ) {
		$self->increment_stats(
			cursor_moves             => $stat_count_moves,
			cells_scanned_cursorMove => $stat_count_cells
		);
	}
	return 1;
}

sub delete_cursor {
	my ( $self, $cursor_type ) = @_;
	$self->cursor_types([ grep( !/^$cursor_type$/, @{ $self->cursor_types} ) ]);
	delete $self->cursors->{$cursor_type};
}

sub write_item {
	my ( $self, $item, $rotation, $cursor ) = @_;

	my @space = @{ $self->space };
	my ( $max_x,     $max_y,     $max_z )     = $self->dimensions;
	my ( $itemMax_x, $itemMax_y, $itemMax_z ) = $item->dimensions;
	my $itemVolume = $item->volume;
	if ( $rotation and $rotation ne 'XYZ' ) {
		( $itemMax_x, $itemMax_y, $itemMax_z ) = xyz_rotate( $rotation, $itemMax_x, $itemMax_y, $itemMax_z );
	}
	my $item_id = $item->id;
	my ( $cur_x, $cur_y, $cur_z ) = $cursor->location;

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
	$self->decrease_volume_remaining($itemVolume );
	if ( $self->are_stats_enabled ) {
		$self->increment_stats( items => 1 );
	}

    $self->update_cursors( $item, $rotation );
}



no Any::Moose;
__PACKAGE__->meta->make_immutable;
