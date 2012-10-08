use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;
use Shipping::BoxSize::Item;
use strict;

use_ok 'Shipping::BoxSize::Box';

my $box = Shipping::BoxSize::Box->new(x => 3, y => 7, z => 2, id => 'test');

isa_ok $box, 'Shipping::BoxSize::Box';

is $box->x, 2, 'x defaults to 2, sorted';
is $box->y, 3, 'y defaults to 3, sorted';
is $box->z, 7, 'z defaults to 7, sorted';

is $box->volume_remaining, 3*7*2, 'volume_remaining';

ok exists $box->space->[0][0][0], 'low limit of space initialized';
ok exists $box->space->[1][2][6], 'high limit of space initialized';
ok !exists $box->space->[1][2][7], 'space does not go too far';

cmp_deeply [$box->dimensions], [2,3,7], 'dimensions';

is scalar(keys %{$box->cursors}), 4, 'cursors initialized';

is scalar(@{$box->packing_list}), 0, 'packing_list initialized';

is $box->big_side_area, 3*7, 'big_side_area';

is $box->decrease_volume_remaining(5), ((3 * 7 * 2) - 5), 'decrease_volume_remaining';

my $default_box = Shipping::BoxSize::Box->new(x => 2, y => 2, z => 8);
cmp_ok length($default_box->id), '>', 0, 'box has an autocreated id when none is passed';

my $clone = $box->clone;
cmp_deeply $clone, $box, 'clone';
isnt "$box", "$clone", 'clone is copy not a pointer';

ok !$box->enable_stats, 'stats disabled by default';
ok !$box->are_stats_enabled, 'are_stats_enabled false';
$box->enable_stats(1);
ok $box->are_stats_enabled, 'are_stats_enabled true';

$box->stats->{foo} = 5;
$box->increment_stats(foo => 3);
is $box->stats->{foo}, 8, 'increment_stats';

my $too_big = Shipping::BoxSize::Item->new(x => 2, y => 2, z => 8, id => 'too big');
my $just_right = Shipping::BoxSize::Item->new(x => 2, y => 3, z => 4, id => 'just right');
ok !$box->can_item_fit($too_big, 'XYZ', $box->cursors->{XYZ}), 'can_item_fit too big';
ok $box->can_item_fit($just_right, 'XYZ', $box->cursors->{XYZ}), 'can_item_fit too big';

# TODO
# update_cursors

# write_item

ok exists $box->cursors->{'YXZ'}, 'Box has a YZX cursor';
cmp_deeply $box->cursor_types, [qw(YXZ YZX XYZ ZXY)], 'checking default set of cursor_types';
$box->cursors->{'YXZ'}->id('YXZ');

my $cursor = $box->delete_cursor('YXZ');

isa_ok $cursor, 'Shipping::BoxSize::Cursor';
is $cursor->id, 'YXZ', 'Deleted cursor has the right id';

ok ! exists $box->cursors->{'YXZ'}, 'YZX cursor was deleted from the set of cursors in the box';
cmp_deeply $box->cursor_types, [qw(YZX XYZ ZXY)], 'checking update of cursor_types';


# test scaling

my $scaled = Shipping::BoxSize::Box->new(x => 3.1, y => 7.6, z => 2.46, id => 'test2', scale => 2);

is $scaled->x, 4, 'scaled x defaults to 4';
is $scaled->y, 6, 'scaled y defaults to 6';
is $scaled->z, 15, 'scaled z defaults to 15';


done_testing;

