use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;

use_ok 'Shipping::BoxSize::Box';

my $box = Shipping::BoxSize::Box->new(x => 3, y => 7, z => 2, id => 'test');

isa_ok $box, 'Shipping::BoxSize::Box';

is $box->x, 2, 'x defaults to 2';
is $box->y, 3, 'y defaults to 3';
is $box->z, 7, 'z defaults to 7';

is $box->volume_remaining, 3*7*2, 'volume_remaining';

ok exists $box->space->[0][0][0], 'low limit of space initialized';
ok exists $box->space->[1][2][6], 'high limit of space initialized';

ok !$box->enable_stats, 'stats disabled by default';

cmp_deeply [$box->dimensions], [2,3,7], 'dimensions';

is scalar(@{ keys %{$box->{cursors}}}), 4, 'cursors initialized';

is scalar(@{$box->packing_list}), 0, 'packing_list initialized';

is $box->big_side_area, 3*7, 'big_side_area';

is $box->decrease_volume_remaining(5), ((3 * 7 * 2) - 5), 'decrease_volume_remaining';

# test scaling

my $scaled = Shipping::BoxSize::Box->new(x => 3.1, y => 7.6, z => 2.46, id => 'test2', scale => 2);

is $scaled->x, 4, 'scaled x defaults to 4';
is $scaled->y, 6, 'scaled y defaults to 6';
is $scaled->z, 15, 'scaled z defaults to 15';


done_testing;

