#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Stream;

use Test::More;
use Test::Exception;


my @tests =
  (
 {
   op => '<',
   expect => { Op => '<', N => 0 }
 },

 { op => 'N<',
   expect => { Op => '<' },
 },

 { op => '>',
   expect => { Op => '>', N => 1 }
 },

 { op => 'N>',
   expect => { Op => '>' },
 },

 { op => '>>',
   expect => { Op => '>>', N => 1 },
 },

 { op  => 'N>>',
   expect => { Op => '>>' },
 },

 { op => '>&',
   expect => { Op => '>&' },
 },

 { op => '&>',
   expect => { Op => '&>' },
 },

 { op => '<pty',
   expect => { Op => '<pty', N => 0 },
 },

 { op => 'N<pty',
   expect => { Op => '<pty' },
 },

 { op => '>pty',
   expect => { Op => '>pty', N => 1 },
 },

 { op => 'N>pty',
   expect => { Op => '>pty' },
 },

 { op => 'N<&M',
   expect => { Op => '<&' },
 },

 { op => 'M>&N',
   expect => { Op => '>&' },
 },

 { op => 'N<&-',
   expect => { Op => '<&', M => '-' },
 },

 { op => '<pipe',
   expect => { Op => '<pipe', N => 0 },
 },

 { op => 'N<pipe',
   expect => { Op => '<pipe' },
 },

 { op => '>pipe',
   expect => { Op => '>pipe', N => 1 },
 },

 { op => 'N>pipe',
   expect => { Op => '>pipe' },
 },

);


sub test {

    my ( %par ) = @_;

    my $stream = IPC::PrettyPipe::Stream->new( op => $par{op} );

    my %got = (
        Op => $stream->Op,
        $stream->has_N ? ( N => $stream->N ) : (),
        $stream->has_M ? ( M => $stream->M ) : (),
    );

    $par{desc} //= $par{op};

    is_deeply( \%got, $par{expect}, $par{desc} );


}

for my $test ( @tests ) {

	my @pt = ( $test );

	my @ftests;

	my %r = ( N => [ 3, 45 ],
	          M => [ 6, 78 ]
	        );

	while ( @pt ) {

		my $t = shift @pt;

		if ( my ( $x ) = $t->{op} =~ /(N|M)/ ) {

			for my $r ( @{$r{$x}} ) {

				my %nt = %$t;
				$nt{expect} = { %{$nt{expect}} };
				$nt{op} =~ s/$x/$r/;
				$nt{expect}{$x} = $r;

				push @pt, \%nt;

			}

		}

		else {

			push @ftests, $t

		}

	}

	test( %$_ ) for @ftests;
}


done_testing;
