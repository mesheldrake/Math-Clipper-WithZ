use strict;
use warnings;

use Math::Clipper::WithZ ':all';
use Test::More tests => 1;

my $p1 = [
    [20, -10, 0],
    [50, 0, 12],
    [20, 10, 0],
    [-10, 0, -12],
];

my $p2 = [
    [-20, -10, 0],
    [10, 0, 12],
    [-20, 10, 0],
    [-50, 0, -12],
];

my $clipper = Math::Clipper::WithZ->new;
$clipper->add_subject_polygon($p1);
my $result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,0);
#diag("\nresult has:".scalar(@$result).": ".join(', ',map scalar(@$_), @$result)."\n");
#diag("in\n".join("\n",map {'['.join(', ',@$_).']'} @$p1)."\nout\n".join("\n",map {'['.join(', ',@$_).']'} @{$result->[0]})."\n");
is_deeply($result->[0], $p1, 'z coordinate passed through');

__END__
