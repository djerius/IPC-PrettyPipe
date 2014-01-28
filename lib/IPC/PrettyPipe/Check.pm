# --8<--8<--8<--8<--
#
# Copyright (C) 2010 Smithsonian Astrophysical Observatory
#
# This file is part of IPC::PrettyPipe
#
# IPC::PrettyPipe is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

package IPC::PrettyPipe::Check;

use strict;
use warnings;
use Carp;
our @CARP_NOT = ( qw[ IPC::PrettyPipe
                      IPC::PrettyPipe::Cmd
                      IPC::PrettyPipe::Arg
                      IPC::PrettyPipe::Stream
                      IPC::PrettyPipe::DSL
                      IPC::PrettyPipe::DSL::Cmd
                      IPC::PrettyPipe::DSL::Arg
                   ]);

use Params::Check qw[ check ];
use MooX::Types::MooseLike::Base ':all';

use Safe::Isa;

use base 'Exporter';
our @EXPORT =
  qw(
	    ArgSep
	    CheckArg
	    CheckArgFmt
	    CheckArgSep
	    CheckArrayRef
	    CheckBool
	    CheckCmd
	    CheckIsa
	    CheckRegexp
	    CheckStr
	    CheckStreamFmt
	    Compose
	    PluginOk
   );

# compose a bunch of check functions into one.  each function
# should throw an exception if it fails to match
sub Compose {

	my @subs = @_;
	return sub { local $_; $_->($_[0]) for @subs };

}

##################################3
# Moo isa
use constant ArgSep      => sub { ! defined $_[0] || is_Str($_[0])
                                    or croak( "illegal value for argsep\n" ) };
sub PluginOk {

    my ( $method ) = @_;

    return sub {

	return 1 if is_Str( $_[0] ) || $_[0]->$_can( $method );

	croak( "not a class name or does not support method $method\n" );

    };

};



##################################3
# Params::Check allow
use constant CheckArgSep => [ sub { ! defined $_[0] || is_Str($_[0]) } ];

use constant CheckBool   => [ sub { is_Bool($_[0]); } ];

use constant CheckRegexp => [ sub { is_RegexpRef($_[0]) } ];

use constant CheckStr    => [ sub { is_Str($_[0]) } ];

use constant CheckArrayRef => [ sub { is_ArrayRef($_[0]) } ];

use constant CheckArg    => [ sub {     ( is_ArrayRef($_[0]) && not @{$_[0]}%2 )
                                      ||  is_HashRef($_[0])
                                      ||  is_Str($_[0])
                                      ||  $_[0]->$_isa( 'IPC::PrettyPipe::Arg' )
                                   } ];

use constant CheckCmd    => [ sub {       is_Str($_[0])
                                      ||  $_[0]->$_isa( 'IPC::PrettyPipe::Cmd' )
                                   } ];


use constant CheckArgFmt  => [ sub { shift->$_isa( 'IPC::PrettyPipe::Arg::Format' ) } ];

sub CheckIsa {
    my $class = shift;
    return [ sub { $_[0]->$_isa( $class ) } ]
}


1;
