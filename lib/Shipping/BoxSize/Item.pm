package Shipping::BoxSize::Item;

use strict;
use warnings;
use Any::Moose;
use POSIX qw/ceil/;
use Shipping::BoxSize::Utility qw/xyz_rotate/;
use Data::GUID;

has id => (
    is          => 'rw',
    isa         => 'Str | Undef',
    lazy        => 1,
    default     => sub {Data::GUID->new->as_string()},
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
    my $rotation = $args{rotation} || 'XYZ';
    my $scale = $args{scale} || 1;

    # adjust the scale of the items. we assume the scale is 1 unit (inch, mm, cm, etc), but you may want to do 1/2 unit scale in which case the scale is 2
    # we use ceil here because you can't fit a big item into a small hole, better to err on the item being big rather than small
    my $x = ceil($args{x} * $scale);
    my $y = ceil($args{y} * $scale);
    my $z = ceil($args{z} * $scale);
    
    # sort small to large
	( $x, $y, $z ) = sort { $a <=> $b } ( $x, $y, $z );
    
    # do the initial rotation
    ( $x, $y, $z ) = xyz_rotate($rotation, $x, $y, $z);

    return {
        x       => $x,
        y       => $y,
        z       => $z,
        volume  => ($x * $y * $z),
        scale   => $scale,
        rotation=> $rotation,
        id      => $args{id},
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

