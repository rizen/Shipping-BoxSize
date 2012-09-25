package Shipping::BoxSize::Item;

use strict;
use warnings;
use Any::Moose;
use POSIX qw/ceil/;
use Shipping::BoxSize::Utility qw/xyz_rotate/;

has id => (
    is          => 'rw',
    required    => 1,
    isa         => 'Str',
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

has rotation => (
    is          => 'rw',
    required    => 1,
    isa         => 'Str',
);

has scale => (
    required    => 1,
    is          => 'rw',
    isa         => 'Int',
);

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    my $x = $args{x};
    my $y = $args{y};
    my $z = $args{z};
    my $rotation = $args{rotation} || 'XYZ';
    my $scale = $args{scale} || 1;
    
    # sort small to large
	( $x, $y, $z ) = sort { $a <=> $b } ( $x, $y, $z );
    
    # do the initial rotation
    ( $x, $y, $z ) = xyz_rotate($rotation, $x, $y, $z);

    # adjust the scale of the items. we assume the scale is 1 unit (inch, mm, cm, etc), but you may want to do 1/2 unit scale in which case the scale is 2
	( $x, $y, $z ) = map { $_ * $scale } ( $x, $y, $z );
    
    # we use ceil here because you can't fit a big item into a small hole, better to err on the item being big rather than small
    $x = ceil($x);
    $y = ceil($y);
    $z = ceil($z);
    
    return {
        x       => $x,
        y       => $y,
        z       => $z,
        volume  => ($x * $y * $z),
        id      => $args{id},
        scale   => $scale,
        rotation=> $rotation,
    };
};

sub dimensions {
    my $self = shift;
    return ($self->x, $self->y, $self->z);
}

sub big_side_area {
    my $self = shift;
	my ( $big, $next, $small ) = sort { $b <=> $a } ( $self->dimensions );
	return $big * $next;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

