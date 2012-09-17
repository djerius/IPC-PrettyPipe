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

use Params::Check qw[ check ];
use MooX::Types::MooseLike::Base ':all';

use base 'Exporter';
our @EXPORT =
  qw(
	    ArgSep
	    CheckArgSep
	    CheckBool
	    CheckRegexp
	    CheckStr
   );

# Moo isa
use constant ArgSep      => sub { ! defined $_[0] || is_Str($_[0]) or die( "illegal value for argsep\n" ) };

# Params::Check allow
use constant CheckArgSep => [ sub { ! defined $_[0] || is_Str($_[0]) } ];
use constant CheckBool   => [ sub { is_Bool($_[0]); } ];
use constant CheckRegexp => [ sub { is_RegexpRef($_[0]) } ];
use constant CheckStr    => [ sub { is_Str($_[0]) } ];

1;
