package App::SimpleScan::Plugin::LinkCheck;

$VERSION = '0.01';

use warnings;
use strict;
use Carp;

use Scalar::Util qw(looks_like_number);
use Text::Balanced qw(extract_quotelike extract_multiple);

sub import {
  no strict 'refs';
  *{caller() . '::_do_has_link'}   = \&_do_has_link;
  *{caller() . '::_do_no_link'}    = \&_do_no_link;
  *{caller() . '::link_condition'} = \&link_condition;
  *{caller() . '::_link_conditions'} = \&_link_conditions;
  *{caller() . '::_add_link_condition'} = \&_add_link_condition;

  *{caller() . '::_extract_quotelike_args'} = 
    \&_extract_quotelike_args;
}

sub pragmas {
  return ['has_link', \&_do_has_link],
         ['no_link',  \&_do_no_link];
         ['forget_link', \&_do_forget_link],
         ['forget_all_links', \&do_forget_all];
}

sub init {
  my($class, $app) = @_;
  $app->{Link_conditions} = {};
}

sub _do_forget_all {
  my($self, $args) = @_;
  $self->app->{Link_conditions} = {};
}

sub _do_forget_link {
  my($self, $args) = @_;
  my @links = $self->_extract_quotelike_args($args);
  for my $link (@links) {
    delete $self->app->{Link_conditions}->{$link};
  }
}

sub _do_has_link {
  my($self, $args) = @_;
  my($name, $compare, $count);
  if (!defined $args) {
    $self->stack_test( qq(fail "No arguments for %%has_link";\n) );
    return;
  }
  else {
    # Extract strings and backticked strings and just plain words.
    # We explicitly junk anything past the first three items.
    ($name, $compare, $count) = $self->_extract_quotelike_args($args);
  }
  $self->_add_link_condition( { name=>$name, compare=>$compare, count=>$count } );
}

sub _do_no_link {
  my($self, $args) = @_;
  if (!defined $args) {
    $self->stack_test( qq(fail "No arguments for %%no_link";\n) );
  }
  else {
    my ($name) = $self->_extract_quotelike_args($args);
    $self->_do_has_link(qq($name == 0));
  }
}

sub _link_conditions {
  my ($self) = shift;
  return wantarray ? @{ $self->{Link_conditions} } : $self->{Link_conditions};
}

sub _add_link_condition {
  my ($self, $condition) = @_;
  push @{ $self->{Link_conditions}->{ $condition->{name} } }, $condition;
}

sub per_test {
  my($class, $testspec) = @_;
  my $self = $testspec->app;
  return unless defined $self->_link_conditions;
  my @code;
  my $test_count = 0;

  for my $link_name (keys %{$self->_link_conditions()} ) {
    for my $link_condition ( @{ $self->{Link_conditions}->{$link_name} } ) {
      my $compare = $link_condition->{compare};
      my $count   = $link_condition->{count};
      my $name    = $link_condition->{name};
  
      my $not_bogus = 1;
      my %have_a;

      # name alone is "at least one link with this name"
      if (defined $name and (! defined $compare) and (! defined $count) ) {
        $compare = ">";
        $count   = "0";
      }

      if (!defined $name) {
        push @code, qq(fail "Missing name";\n);
        $test_count++;
        $not_bogus = 0;
      }
      else {
        # de-quote if necessary
        $name = eval $name if ($name =~ /^['"]/);
      }

      if (!defined($compare)) {
        push @code, qq(fail "Missing comparison operator (use < > <= >= == !=)";\n);
        $test_count++;
        $not_bogus = 0;
      }
      elsif (! grep {$compare eq $_} qw(== > < >= <= !=) ) {
        push @code, qq(fail "$compare is not a legal comparison operator (use < > <= >= == !=)";\n);
        $test_count++;
        $not_bogus = 0;
      }

      if (!defined($count)) {
        push @code, qq(fail "Missing count";\n);
        $test_count++;
        $not_bogus = 0;
      }
      elsif (! looks_like_number($count) ) {
        push @code, qq(fail "$count doesn't look like a legal number to me";\n);
        $test_count++;
        $not_bogus = 0;
      }

      if ($not_bogus) {
        push @code, qq(cmp_ok scalar \@{[mech()->find_all_links(text=>qq($name))]}, qq($compare), qq($count), "'$name' link count $compare $count";\n);
        $test_count++;
      }
    }
  }
  return $test_count, @code;
}


sub _extract_quotelike_args {
  # Extract strings and backticked strings and just plain words.
  my ($self, $string) = @_;

  # extract_quotelike complains if no quotelike strings were found.
  # Shut this up.
  no warnings;

  # The result of the extract multiple is to give us the whitespace
  # between words and strings with leading whitespace before the
  # first word of quotelike strings. Confused? This is what happens:
  #
  # for the string
  #   a test `backquoted' "just quoted"
  # we get
  #   'a'
  #   ' '
  #  'test'
  #  ' `backquoted'
  #  `backquoted`
  #  ' '
  #  ' "just'
  #  '"just quoted"'
  #
  # We do NOT use grep because if one of the arguments evaluates to 
  # zero, it won't get saved.
  my @wanted;
  foreach my $item 
    (extract_multiple($string, [qr/[^'"`\s]+/,\&extract_quotelike])) {
    push @wanted, $item if $item !~ /^\s/;
  }
  return @wanted;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

App::SimpleScan::Plugin::LinkCheck - [One line description of module's purpose here]


=head1 VERSION

This document describes App::SimpleScan::Plugin::LinkCheck version 0.0.1


=head1 SYNOPSIS

    use App::SimpleScan::Plugin::LinkCheck;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 init

Sets up the initial (empty) link conditions.

=head2 pragmas

Exports the definitions of C<has_link> and C<no_link> to C<simple_scan>.

=head2 per_test

Emits code to test all of the active link conditions for each testspec.

=head1 DIAGNOSTICS

=over

=item C<< %s is not a legal comparison operator (use < > <= >= == !=) >>

You supplied a comparison operator that wasn't one we expected.

=item C<< %s doesn't look like a legal number to me >>

The item you supplied as a count of the number of times you expect to 
see the link was not something that looks like a number to Perl.

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
App::SimpleScan::Plugin::LinkCheck requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-app-simplescan-plugin-linkcheck@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Joe McMahon  C<< <mcmahon@yahoo-inc.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Joe McMahon C<< <mcmahon@yahoo-inc.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
