package Math::Clipper::WithZ;

use 5.008;
use strict;
use warnings;
use Carp qw(croak carp);
use Config;

use Exporter();
our $VERSION;
our @ISA = qw(Exporter);

BEGIN {
    use XSLoader;
    $VERSION = '1.22';
    XSLoader::load('Math::Clipper::WithZ', $VERSION);
}

# TODO: keep in sync with docs below and xsp/Clipper.xsp

our %EXPORT_TAGS = (
    cliptypes     => [qw/CT_INTERSECTION CT_UNION CT_DIFFERENCE CT_XOR/],
    #polytypes     => [qw/PT_SUBJECT PT_CLIP/],
    polyfilltypes => [qw/PFT_EVENODD PFT_NONZERO PFT_POSITIVE PFT_NEGATIVE/],
    jointypes     => [qw/JT_MITER JT_ROUND JT_SQUARE/],
    endtypes     => [qw/ET_SQUARE ET_ROUND ET_BUTT ET_CLOSED/],
    utilities       => [qw/area offset is_counter_clockwise orientation integerize_coordinate_sets unscale_coordinate_sets
                    simplify_polygon simplify_polygons int_offset ex_int_offset ex_int_offset2/],
);

$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

my %intspecs = (
    '64' => {
            maxint    => 4611686018427387902,   # Clipper-imposed max when using 64 bit integer math
            maxdigits => 19
            },
    '53' => {
            maxint    => 9007199254740992, # signed 53 bit integer max, for integers stored in double precision floats
            maxdigits => 16
            },
    '32' => {
            maxint    => 1073741822,   # Clipper-imposed max to avoid calculations with large integer types
            maxdigits => 10
            },
    );

my $is64safe = ((defined($Config{use64bitint})   && $Config{use64bitint}   eq 'define') || $Config{longsize}   >= 8 ) &&
               ((defined($Config{uselongdouble}) && $Config{uselongdouble} eq 'define') || $Config{doublesize} >= 10);

sub offset {
    my ($polygons, $delta, $scale, $jointype, $miterlimit) = @_;
    $scale      ||= 100;
	$jointype   = JT_MITER if !defined $jointype;
	$miterlimit ||= 2;
	
	my $scalevec=[$scale,$scale];
	my $polyscopy=[(map {[(map {[(map {$_*$scalevec->[0]} @{$_})]} @{$_})]} @{$polygons})];
	my $ret = _offset($polyscopy,$delta*$scale, $jointype, $miterlimit);
	unscale_coordinate_sets($scalevec , $ret) if @$ret;
	return $ret;
	}

*is_counter_clockwise = *orientation;

sub unscale_coordinate_sets { # to undo what integerize_coordinate_sets() does
    my $scale_vector=shift;
    my $coord_sets=shift;
    my $coord_count=scalar(@{$coord_sets->[0]->[0]});
    if (!ref($scale_vector)) {$scale_vector=[(map {$scale_vector} (0..$coord_count-1))];}
    foreach my $set (@{$coord_sets}) {
        foreach my $vector (@{$set}) {
            for (my $ci=0;$ci<$coord_count;$ci++) {
                $vector->[$ci] /= $scale_vector->[$ci] if $scale_vector->[$ci]; # avoid divide by zero
                }
            }
        }
    }

sub integerize_coordinate_sets {
    my %opts=();
    if (ref($_[0]) =~ /HASH/) {%opts=%{(shift)};}
    $opts{constrain} =  1 if !defined($opts{constrain});
    $opts{bits}      = ($is64safe ? 64 : 53) if !defined($opts{bits});
	if ($opts{bits} == 64 && !$is64safe) {$opts{bits} = 53; carp "Integerize to 64 bits requires both long long and long double underlying Perl's default integer and double types. Using 53 bits instead.";}
    $opts{margin} =  0 if !defined($opts{margin});

    # assume all coordinate vectors (points) have same number of coordinates; get that count from first one
    my $coord_count=scalar(@{$_[0]->[0]});

    # return this with scaled data, so user can "unscale" Clipper results
    my @scale_vector;
    
    # deal with each coordinate "column" (eg. x column, y column, ... possibly more)
    for (my $ci=0;$ci<$coord_count;$ci++) {
        my $maxc=$_[0]->[0]->[$ci];
        my $max_exp;

        # go through all the coordinate sets, looking just at the current column
        foreach my $set (@_) {
            # for each "point"
            foreach my $vector (@{$set}) {
                # looking for the maximum magnitude
                if ($maxc<abs($vector->[$ci]) + $opts{margin}) {$maxc=abs($vector->[$ci]) + $opts{margin};}
                # looking for the maximum exponent, when coords are in scientific notation
                if (sprintf("%.20e",$vector->[$ci] + ($vector->[$ci]<0?-1:1)*$opts{margin}) =~ /[eE]([+-])0*(\d+)$/) {
                    my $exp1 = eval($1.$2);
                    if (defined $vector->[$ci] && (!defined($max_exp) || $max_exp<$exp1)) {$max_exp=$exp1} 
                    }
                else {croak "some coordinate didn't look like a number: ",$vector->[$ci]}
                }
            }

        # Set scale for this coordinate column to the largest value that will convert the
        # larges coordinate in the set to near the top of the available integer range.
        # There's never any question of how much precision the user wants -
        # we just always give as much as possible, within the integer limit in effect (53 bit or 64 bit)

        $scale_vector[$ci]=10**(-$max_exp + ($intspecs{$opts{bits}}->{maxdigits} - 1));

        if ($maxc * $scale_vector[$ci] > $intspecs{$opts{bits}}->{maxint}) {
            # Both 53 bit and 64 bit integers
            # have max values near 9*10**(16 or 19).
            # So usually you have 16 or 19 digits to use. 
            # But if your scaled-up max values enter the
            # zone just beyond the integer max, we'll only
            # scale up to 15 or 18 digit integers instead.

            $scale_vector[$ci]=10**(-$max_exp + ($intspecs{$opts{bits}}->{maxdigits} - 2));

            }
        }
    
    # If the "constrain" option is set false,
	# scaling is independent for each
    # coordinate column - all the Xs get one scale
    # all the Ys something else - to take the greatest
    # advantage of the available integer domain.
    # But if the "constrain" option is set true, we use
    # the minimum scale from all the coordinate columns.
    # The minimum scale is the one that will work
    # for all columns, without overflowing our integer limits.
    if ($opts{constrain}) {
        my $min_scale=(sort {$a<=>$b} @scale_vector)[0];
        @scale_vector = map {$min_scale} @scale_vector;
        }

    # Scale the original data
    foreach my $set (@_) {
        foreach my $vector (@{$set}) {
            for (my $ci=0;$ci<$coord_count;$ci++) {
                $vector->[$ci] *= $scale_vector[$ci];
                if (abs($vector->[$ci] < 1)) {$vector->[$ci] = sprintf("%.1f",$vector->[$ci]/10)*10;}
                }
            }
        }

    return \@scale_vector;
    }

# keep this method as a no-op, as it was removed in Clipper 4.5.5
sub use_full_coordinate_range {}

sub CLONE_SKIP { 1 }

1;
__END__

=head1 NAME

Math::Clipper::WithZ - Polygon clipping in 2D

=head1 SYNOPSIS

 use Math::Clipper::WithZ ':all';

 my $clipper_with_z = Math::Clipper::WithZ->new;

 my $p1 = [
    [ 20, -10,    1],
    [ 50,   0,   -2],
    [ 20,  10,   0xFFFFFFFF],
    [-10,   0,    0],
 ];

 $clipper->add_subject_polygon( $p1 );

 my $result = $clipper->execute(CT_UNION);

 # Z value pass through
 # $result is now:
 # [
 #   [
 #     [20, -10, 1],
 #     [50, 0, -2],
 #     [20, 10, 4294967295],
 #     [-10, 0, 0]
 #   ]
 # ]



=head1 DESCRIPTION

C<Clipper> is a C++ (and Delphi) library that implements
polygon clipping. Version 6.0.0 alpha adds compile-time
support for points with an additional Z value, in addition
to the the normal X and Y values.

Z is for arbitrary data associated with each point or edge.
Clipper does nothing with this value but pass it through to 
the result.

For new points generated at intersections, Z is set to 0
by default in results. A "zFill" callback function may be 
provided to set the Z at intersections to something else, 
based on neighboring Z values. But this is a callback 
in C, not Perl.

In addition to providing the basic Z pass-through feature
Math::Clipper::WithZ aims to provide a few predetermined 
callback options that will determine how Clipper sets Z 
values at intersections.

Other than those additional features, this module should 
work identically to Math::Clipper. See the
Math::Clipper docs for overall usage.

=head1 METHODS

All methods are the same as Math::Clipper except that
the three execute methods take an additional argument,
specifying a predetermined zFill option.

=head2 execute, ex_execute, pt_execute

The optional zFill arguments follows the normal Math::Clipper
arguments.

    my $result = $clipper->execute( CT_UNION , PFT_NONZERO, undef, ZFT_MAX);

This is a union operation, with the subject fill type set to nonzero and the
clip fill type left to it's default.

The last argument specifies that we want to use a zFill function that sets 
Z for the intersection point to the maximum Z value of the two intersecting 
edges. (Points correspond to edges. The Z value of an edge is the Z value of 
the point at the beginning of that edge.)

=head1 Z FILL OPTIONS

=head2 ZFT_BOTH_UINT32
=head2 ZFT_MAX
=head2 ZFT_MIN
=head2 ZFT_MEAN

=head1 NO Z FILL FOR OFFSETS

Clipper does not attempt to pass Z values through for offset operations.
The way offset points are generated, the result would often be quite scrambled
and meaningless.

However, sometimes it wouldn't. You might consider calculating your own offset points
with Z values in a manner similar to Clipper, and then using a Z-preserving union to
clean up the results, just as Clipper does. It should be fairly simple to glean the 
initial offset point calculation from the Clipper source.

=head1 VERSION

This module was built around, and includes, Clipper version 6.0.0 alpha.

=head1 AUTHOR

Math::Clipper was written by:

Steffen Mueller (E<lt>smueller@cpan.orgE<gt>),
Mike Sheldrake and Alessandro Ranellucci (aar/alexrj)

and these WithZ additions are by Mike Sheldrake.

But the underlying library C<Clipper> was written by
Angus Johnson. Check the SourceForge project page for
contact information.

=head1 COPYRIGHT AND LICENSE

The C<Math::Clipper::WithZ> module is

Copyright (C) 2013 Mike Sheldrake

And is derived, with only a few additions, from C<Math::Clipper>

Copyright (C) 2010, 2011 by Steffen Mueller

Copyright (C) 2011 by Mike Sheldrake

Copyright (C) 2012, 2013 by Alessandro Ranellucci and Mike Sheldrake

but we are shipping a copy of the C<Clipper> C++ library, which
is

Copyright (C) 2010, 2011, 2012, 2013 by Angus Johnson.

C<Math::Clipper::WithZ> is available under the same
license as C<Clipper> itself. This is the C<boost> license:

  Boost Software License - Version 1.0 - August 17th, 2003
  http://www.boost.org/LICENSE_1_0.txt
  
  Permission is hereby granted, free of charge, to any person or organization
  obtaining a copy of the software and accompanying documentation covered by
  this license (the "Software") to use, reproduce, display, distribute,
  execute, and transmit the Software, and to prepare derivative works of the
  Software, and to permit third-parties to whom the Software is furnished to
  do so, all subject to the following:
  
  The copyright notices in the Software and this entire statement, including
  the above license grant, this restriction and the following disclaimer,
  must be included in all copies of the Software, in whole or in part, and
  all derivative works of the Software, unless such copies or derivative
  works are solely in the form of machine-executable object code generated by
  a source language processor.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
  SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
  FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.

=cut
