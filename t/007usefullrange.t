use Math::Clipper::WithZ ':all';
use Test::More tests=>1;

my $clipper = Math::Clipper::WithZ->new;

$clipper->use_full_coordinate_range(1);
pass();
