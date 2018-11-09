package IPC::PrettyPipe::Types;

# ABSTRACT: Types

use strict;
use warnings;

our $VERSION = '0.06';

use Type::Library
  -base,
  -declare =>
  qw[
      Arg
      AutoArrayRef
      Cmd
   ];

use Type::Utils -all;
use Types::Standard -types;

use List::Util qw[ pairmap ];

declare AutoArrayRef, as ArrayRef;
coerce AutoArrayRef,
  from Any, via { [ $_ ] };

class_type Cmd, { class => 'IPC::PrettyPipe::Cmd' };
class_type Arg, { class => 'IPC::PrettyPipe::Arg' };


1;

# COPYRIGHT
