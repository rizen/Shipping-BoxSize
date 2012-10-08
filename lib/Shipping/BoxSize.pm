package Shipping::BoxSize;

use strict;
use warnings;
use Any::Moose;
use Moose::Util::TypeConstraints;
use Shipping::BoxSize::Box;
use Shipping::BoxSize::Item;

has start_rotation => (
    is          => 'rw',
    default     => 'YXZ', # Y is smallest side, Z is longest (ie flat side down)
    isa         => 'Str',
);

has enable_stats => (
    is          => 'rw',
    default     => 0,
    isa         => 'Bool',
);

has scale => (
    is          => 'rw',
    isa         => 'Int',
    default     => 1,
);

has sort_method => (
    is          => 'rw',
    default     => 'volume',
    isa         => subtype( 'Str' => where { $_ ~~ [qw(volume big_side_area)] } ),
);

has strategy => (
    is          => 'rw',
    default     => 'TryAllRotations_ThenNextCursor',
    isa         => subtype( 'Str' => where { $_ ~~ [qw(TryAllRotations_ThenNextCursor TryAllSpots_ThenNextRotation)] } )
);

has rotate_order => (
    is          => 'rw',
    default     => sub { [qw(XYZ YXZ XZY YZX)] },
    isa         => 'ArrayRef',
);

has items => (
    is          => 'rw',
    default => sub { [] },
    isa     => 'ArrayRef',
);

sub add_item {
    my ($self, %args) = @_;
    $args{rotation} = $self->start_rotation; 
    $args{scale} = $self->scale; 
    my $items = $self->items;
    push @{$items}, Shipping::BoxSize::Item->new(%args);
}

has boxes => (
    default => sub { [] },
    isa     => 'ArrayRef',
    is      => 'rw',
);

sub add_box {
    my ($self, %args) = @_;
    $args{rotation} = $self->start_rotation; 
    $args{scale} = $self->scale; 
    $args{enable_stats} = $self->enable_stats; 
    my $boxes = $self->boxes;
    push @{$boxes}, Shipping::BoxSize::Box->new(%args);
}

sub start_packing {
    my $self = shift;
    my @overflow = ();
    my $box = $self->boxes->[0]->clone; # TODO: get a box from the list, more than just the first one
    foreach my $item (@{$self->sort_items}) {
        unless ( $self->pack_item_in_box($box, $item) ) {
            push @overflow, $item;
            my ( $x, $y, $z ) = $item->dimensions;
            my $id = $item->id;
            print "pack_item_in_box failed for item:$id size ($x,$y,$z)\n";
            print "=============================\n";
        }
        else {
        }
    }
}

#  Place item in box, returns 0 if it can not fit in box
sub pack_item_in_box {
    my ($self, $box, $item) = @_;
    warn "packing item ".$item->id;

	my %duplicate         = ();
	my $location          = '';
	my $stat_count_cursor = 0;
	my $stat_count_rotation    = 0;
	my $this_cursor       = '';
	my $item_rotation     = '';
	my $pack_it            = 0;
	my $cursor_type       = '';

	# Simple size test #1
	my $avail_vol = $box->volume_remaining;
	my $item_vol  = $item->volume;
	if ( $item_vol > $avail_vol ) {
		print "Try item($item->id)  item_vol:$item_vol is greater than available volume:$avail_vol\n";
		return 0;
	}

    warn "Strategy: ".$self->strategy;
	if ( $self->strategy eq 'TryAllSpots_ThenNextRotation' ) {

		# Iterate over rotations slowly
        ROTATION: foreach $item_rotation (@{$self->rotate_order}) {
            if ( !$item_rotation ) {
                warn "empty rotation";
                next;
            }
            warn "Rotation: $item_rotation";

			# Try All Cursor Spots
			$stat_count_rotation++;
			my $stat_count_cursor = 0;
            CURSOR: foreach $cursor_type ( @{ $box->cursor_types } ) {
				if ( !$cursor_type ) {
                    warn "empty cursor";
                    next;
                }
                warn "Cursor Type: $cursor_type";
				$this_cursor = $box->cursors->{$cursor_type};
				$location    = $this_cursor->location_as_string;
				if ( $duplicate{$location} ) {
                    warn "duplicate location"; # some cursors are stacked in same spot
                    next;
                }
				$stat_count_cursor++;

				if ( $box->can_item_fit($item, $item_rotation, $this_cursor ) ) {
					$box->write_item($item, $item_rotation, $this_cursor );
					$pack_it = 1;
                    warn "can pack it";
					last ROTATION;    #end both loops
				}
			}
			$duplicate{$location} = 1;
		}    # end foreach rotation

	}
	else {

		# Assume default ($ITEM_STRATEGY eq ''TryAllRotations_ThenNextCursor'')
		# Iterate over cursors slowly
        CURSOR: foreach $cursor_type ( @{ $box->cursor_types } ) {
			if ( !$cursor_type ) {
                warn "empty cursor";
                next;
            }
            warn "Cursor Type: ".$cursor_type;
			$this_cursor = $box->cursors->{$cursor_type};
			$location    = $this_cursor->location;
			if ( $duplicate{$location}  ) {
                warn "duplicate location"; # some cursors are stacked in same spot
                next;
            }

			# Try All Rotations First
			$stat_count_cursor++;
			$stat_count_rotation = 0;
            ROTATION: foreach $item_rotation (@{$self->rotate_order}) {
				if ( !$item_rotation ) {
                    warn "empty rotation";
                    next;
                }
                warn "Rotation: $item_rotation";
				if ( $box->can_item_fit( $item, $item_rotation, $this_cursor ) ) {
					$box->write_item($item, $item_rotation, $this_cursor );
					$pack_it = 1;
                    warn "can pack it";
					last CURSOR;    #end both loops
				}
				$stat_count_rotation++;
			}
			$duplicate{$location} = 1;
		}
	}

	if ( $box->are_stats_enabled ) {
		$box->increment_stats(
			item_rotations => $stat_count_rotation,
			cursor_tests   => $stat_count_cursor
		);
		$box->increment_stats( cursor_first_success => 1 ) if ( $stat_count_cursor == 1 );
		$box->increment_stats( rotation_first_success => 1 ) if ( $stat_count_rotation == 0 );
	}

	return $pack_it;    #TRUE or FALSE
}

sub sort_items {
    my $self = shift;
	my %buffer = ();
	my $value  = 0;
	my @return = ();
	foreach my $item ( @{ $self->items } ) {
        my $sort_method = $self->sort_method;
		push( @{ $buffer{$item->$sort_method} }, $item );
	}
	foreach my $value ( sort { $b <=> $a } keys %buffer ) {
		push( @return, @{ $buffer{$value} } );
	}
	return \@return;
}

sub print_stats {
    no strict;
    no warnings;
    my $self = shift;
	my $stat      = '';
    my $box = $self->boxes->[0];
	my $remaining = $box->volume_remaining;
	my $total     = $box->volume;
	my $used_vol  = $total - $remaining;

	print "STRATEGY: \n";
	print "   Algorithm: ".$self->strategy." \n";
	print "   Sort: ".$self->sort_method." InitialRotation: ".$self->start_rotation."\n";
	print "   Box Cursors: " . join( ',', @{$box->cursor_types} ) . "\n";
	print "   Item Rotate: " . join( ',', @{$self->rotate_order} ) . "\n";
	print "STATS: \n";
    print "   total volume = $total\n";
	print "   remaining volume = $remaining\n";
	print "   percent full = "
	  . int( ( 1 - $remaining / $total ) * 100 ) . "%\n";

    my $stats = $box->stats;
	foreach $stat ( sort keys %{ $stats } ) {
		print "   $stat: $stats->{$stat}\n";
	}

	# special stats
    my $item_count = $stats->{items};
    if ($item_count) {
        print "AVERAGES: \n";
        print "    Excess Scans/Item: "
          . ( $stats->{cells_scanned_item} - $used_vol ) / $stats->{items}
          . "\n";
        print "    Rotations Checked/Item: "
          . ( $stats->{item_rotations} ) / $stats->{items} . "\n";
        print "    Cursors Checked/Item: "
          . ( $stats->{cursor_tests} ) / $stats->{items} . "\n";
        print "    Vol/Item: " . $used_vol / $stats->{items} . "\n";
    }
}



no Any::Moose;
__PACKAGE__->meta->make_immutable;
