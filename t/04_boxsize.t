use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;
use Shipping::BoxSize::Item;
use strict;

use_ok 'Shipping::BoxSize';

my $sizer = Shipping::BoxSize->new(enable_stats => 1);

$sizer->add_box(x => 12, y => 12, z => 12, id => 'big cube', scale => 2);

$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'A');
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'B');
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'C');
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'D');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'E');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'F');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'G');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'H');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'I');
$sizer->add_item(x => 2.5, y => 3.5, z => 1, id => 'J');
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'K');
$sizer->add_item(x => 10.75, y => 10.75, z => 1.75, id => 'L');
$sizer->add_item(x => 1, y => 0.5, z => 0.5, id => 'M');
$sizer->add_item(x => 0.75, y => 0.75, z => 0.75, id => 'N');

$sizer->start_packing;

$sizer->print_stats;


done_testing;

