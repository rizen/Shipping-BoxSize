use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;

use_ok 'Shipping::BoxSize::Item';

my $item = Shipping::BoxSize::Item->new(x => 3, y => 7, z => 2, id => 'test');

isa_ok $item, 'Shipping::BoxSize::Item';

is $item->x, 2, 'x defaults to 2';
is $item->y, 3, 'y defaults to 3';
is $item->z, 7, 'z defaults to 7';

is $item->volume, 3*7*2, 'volume';

cmp_deeply [$item->dimensions], [2,3,7], 'dimensions';

is $item->big_side_area, 3*7, 'big_side_area';

# test scaling

my $scaled = Shipping::BoxSize::Item->new(x => 3.1, y => 7.6, z => 2.46, id => 'test2', scale => 2);

is $scaled->x, 5, 'scaled x defaults to 5';
is $scaled->y, 7, 'scaled y defaults to 7';
is $scaled->z, 16, 'scaled z defaults to 16';


done_testing;

