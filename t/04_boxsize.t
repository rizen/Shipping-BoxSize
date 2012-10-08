use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;
use Shipping::BoxSize::Item;
use strict;

use_ok 'Shipping::BoxSize';

my $sizer = Shipping::BoxSize->new(enable_stats => 1);

$sizer->add_box(x => 12, y => 12, z => 12, id => 'big cube', scale => 2);

$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 2.5, y => 3.5, z => 1);
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75);
$sizer->add_item(x => 1, y => 0.5, z => 0.5);
$sizer->add_item(x => 0.75, y => 0.75, z => 0.75);


$sizer->print_stats;


done_testing;

