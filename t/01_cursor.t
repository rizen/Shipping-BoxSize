use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;

use_ok 'Shipping::BoxSize::Cursor';

my $cursor = Shipping::BoxSize::Cursor->new;

isa_ok $cursor, 'Shipping::BoxSize::Cursor';

is $cursor->x, 0, 'x defaults to 0';
is $cursor->y, 0, 'y defaults to 0';
is $cursor->z, 0, 'z defaults to 0';

$cursor->x(1);
is $cursor->x, 1, 'can set x';

$cursor->y(2);
is $cursor->y, 2, 'can set y';

$cursor->z(3);
is $cursor->z, 3, 'can set z';

cmp_deeply [$cursor->location], [1,2,3], 'location';

is $cursor->location_as_string, '1,2,3', 'location_as_string';

done_testing;

