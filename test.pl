#!/bin/perl -w

use lib '.';
use PipeC;


{
  my $p = new PipeC;

  for my $n ( 1..5 )
  {
    my $h = $p->add( "cmd$n", [ input0 => INPUT, 
				input1 => INPUT, 
				input2 => INPUT, 
				output0 => OUTPUT,
				output1 => OUTPUT,
				output2 => OUTPUT
			      ] );
    $h->valrep( 'INPUT', 'INPUT', 'input-last', 'input-first' );
    $h->valrep( 'OUTPUT', 'OUTPUT', 'output-last', 'output-first' );
  }

  $p->valrep( 'INPUT', 'stdin', undef, 'InputFile' );
  $p->valrep( 'OUTPUT', 'stdout', 'OutputFile' );

  print $p->dump, "\n";

}

print "\n\n";

{
  my $p = new PipeC;
  $p->add( "cmd", [ input => INPUT, output => OUTPUT ] );
  $p->valrep( 'INPUT', 'stdin', undef, 'InputFile' );
  $p->valrep( 'OUTPUT', 'stdout', 'OutputFile' );
 
  print $p->dump, "\n";
  
}

print "\n\n";

{
  my $p = new PipeC;
  $p->add( "cmd", [ input => INPUT, output => OUTPUT ] );
  $p->valrep( 'INPUT', 'stdin', 'InputFile' );
  $p->valrep( 'OUTPUT', 'stdout', undef, 'OutputFile' );
 
  print $p->dump, "\n";
  
}
