use strict;
use warnings;

use Math::Clipper ':all';
use Test::More tests => 2;

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

my $clipper = Math::Clipper->new;
$clipper->add_subject_polygon($p1);
my $result = $clipper->execute(CT_UNION,PFT_NONZERO);
#diag("\nresult has:".scalar(@$result).": ".join(', ',map scalar(@$_), @$result)."\n");
#diag("in\n".join("\n",map {'['.join(', ',@$_).']'} @$p1)."\nout\n".join("\n",map {'['.join(', ',@$_).']'} @{$result->[0]})."\n");
is_deeply($result->[0], $p1, 'z coordinate passed through');

$clipper->clear();
$clipper->add_subject_polygon($p1);
$clipper->add_subject_polygon($p2);
$result = $clipper->execute(CT_UNION,PFT_NONZERO);
diag("\nresult has:".scalar(@$result).": ".join(', ',map scalar(@$_), @$result)."\n");
diag("in\n".join("\n",map join("\n",map {'['.join(', ',@$_).']'} @{$_})."\n", ($p1, $p2))."\n");
diag("out\n".join("\n",map join("\n",map {'['.join(', ',@$_).']'} @{$_})."\n", @$result)."\n");
diag("in flat: ".'M'.join("Z\nM",map ''.join("L",map {''.join(',',@$_[0,1]).''} @{$_}), ($p1, $p2)).'Z'."\n");
diag("out flat: ".'M'.join("Z\nM",map ''.join("L",map {''.join(',',@$_[0,1]).''} @{$_}), @$result).'Z'."\n");
ok(1);

__END__
