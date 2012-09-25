package Shipping::BoxSize::Cursor;

use strict;
use warnings;
use Any::Moose;

has id => (
    is          => 'rw',
);

has x => (
    is          => 'rw',
    default     => 0,
    isa         => 'Int',
);

has y => (
    is          => 'rw',
    default     => 0,
    isa         => 'Int',
);

has z => (
    is          => 'rw',
    default     => 0,
    isa         => 'Int',
);

sub location {
    my ($self, $x, $y, $z) = @_;
    $self->x($x) if (defined $x);
    $self->y($y) if (defined $y);
    $self->z($z) if (defined $z);
    return ($self->x, $self->y, $self->z);
}

sub location_as_string {
    my $self = shift;
    return join(',', $self->location );
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

