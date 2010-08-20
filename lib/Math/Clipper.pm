package Math::Clipper;

use 5.008;
use strict;
use warnings;
use Carp 'croak';

use Exporter();
our $VERSION = '0.01';
our @ISA = qw(Exporter);

require XSLoader;
XSLoader::load('Math::Clipper', $VERSION);

# TODO: keep in sync with docs below and xsp/Clipper.xsp

our %EXPORT_TAGS = (
    cliptypes     => [qw/CT_INTERSECTION CT_UNION CT_DIFFERENCE CT_XOR/],
    #polytypes     => [qw/PT_SUBJECT PT_CLIP/],
    polyfilltypes => [qw/PFT_EVENODD PFT_NONZERO/],
);

$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();


1;
__END__

=head1 NAME

Math::Clipper - Polygon clipping in 2D

=head1 SYNOPSIS

  use Math::Clipper ':all';
  my $clipper = Math::Clipper->new;
  
  # Add the polygon to-be-clipped
  $clipper->add_subject_polygon(
    [ [$x1, $y1],
      [$x2, $y2],
      ...
    ],
  );

  # Add the polygon that defines the clipping
  $clipper->add_clip_polygon(
    [ [$x1, $y1],
      [$x2, $y2],
      ...
    ],
  );
=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

TODO: Clear with clipper author!

The Math::Clipper module is

Copyright (C) 2010 by Steffen Mueller

=cut
