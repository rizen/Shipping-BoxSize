use Test::More;
use Test::Deep;

use lib '../lib';
use 5.010;

use_ok 'Shipping::BoxSize::Utility';

use Shipping::BoxSize::Utility qw(xyz_rotate reverse_xyz_rotate);

my @start = (10, 2, 5);

cmp_deeply [xyz_rotate('ZYX', @start)], [2,5,10], 'YZX';
cmp_deeply [xyz_rotate('XZY', @start)], [2,10,5], 'YXZ';
cmp_deeply [xyz_rotate('ZYX', @start)], [5,10,2], 'ZXY';
cmp_deeply [xyz_rotate('ZYX', @start)], [5,2,10], 'ZYX';
cmp_deeply [xyz_rotate('ZYX', @start)], [10,5,2], 'XZY';
cmp_deeply [xyz_rotate('XYZ', @start)], \@start, 'XYZ';
cmp_deeply [xyz_rotate('', @start)], \@start, 'blank';

#cmp_deeply [reverse_xyz_rotate('ZYX', @start)], [2,5,10], 'YZX';
#cmp_deeply [reverse_xyz_rotate('XZY', @start)], [2,10,5], 'YXZ';
#cmp_deeply [reverse_xyz_rotate('ZYX', @start)], [5,10,2], 'ZXY';
#cmp_deeply [reverse_xyz_rotate('ZYX', @start)], [5,2,10], 'ZYX';
#cmp_deeply [reverse_xyz_rotate('ZYX', @start)], [10,5,2], 'XZY';
#cmp_deeply [reverse_xyz_rotate('XYZ', @start)], \@start, 'XYZ';
#cmp_deeply [reverse_xyz_rotate('', @start)], \@start, 'blank';

done_testing;

