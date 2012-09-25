package Shipping::BoxSize::Utility;

use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(xyz_rotate reverse_xyz_rotate);

sub xyz_rotate {
    my ($type, $x, $y, $z) = @_;
    $type ||= 'XYZ';
    return ( $y, $z, $x ) if ( $type eq 'YZX' );
	return ( $y, $x, $z ) if ( $type eq 'YXZ' );
	return ( $z, $x, $y ) if ( $type eq 'ZXY' );
	return ( $z, $y, $x ) if ( $type eq 'ZYX' );
	return ( $x, $z, $y ) if ( $type eq 'XZY' );
	return ( $x, $y, $z );    # blank or XYZ
}

my %OPPOSITE_ROTATE = (
	XYZ => 'XYZ',
	XZY => 'XZY',
	ZYX => 'ZYX',
	YXZ => 'YXZ',
	ZXY => 'YZX',
	YZX => 'ZXY'
);

sub reverse_xyz_rotate {
    my ($type, $x, $y, $z) = @_;
    return xyz_rotate($OPPOSITE_ROTATE{$type}, $x, $y, $z);
}


1;
