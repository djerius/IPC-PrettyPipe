# --8<--8<--8<--8<--
#
# Copyright (C) 2012 Smithsonian Astrophysical Observatory
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

package IPC::PrettyPipe::Arg::Format;

use Moo;

use Carp;

use IPC::PrettyPipe::Check;
use MooX::Types::MooseLike::Base ':all';

with 'IPC::PrettyPipe::Format';

shadowable_attrs( qw[ pfx sep ] );

has pfx => (
    is        => 'rw',
    isa       => Str,
    clearer   => 1,
    predicate => 1,
);

has sep => (
    is        => 'rw',
    isa       => ArgSep,
    clearer   => 1,
    predicate => 1,
);

sub copy_into { $_[0]->_copy_attrs( $_[1], 'sep', 'pfx' ); }


1;
