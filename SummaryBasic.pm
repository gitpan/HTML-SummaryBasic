package HTML::SummaryBasic;

use strict;
use Carp;
use warnings;

my $VERSION = 0.1;

=head1 NAME

HTML::SummaryBasic - basic summary info from meta tags and the first para.

=head1 SYNOPSIS

	use HTML::SummaryBasic;
	my $p = new HTML::SummaryBasic  {
		PATH => "D:/www/leegoddard_com/essays/aiCreativity.html",
		NOT_AVAILABLE =>"There ain't none",
	};
	# What did we get?
	foreach (keys %{$p->{SUMMARY}}){
		warn "$_ ... $p->{SUMMARY}->{$_}\n";
	}

=head1 DEPENDENCIES

	use HTML::TokeParser;
	use HTML::HeadParser;

=cut

use HTML::TokeParser;
use HTML::HeadParser;

=head1 DESCRIPTION

Creates a hash of useful summary information from C<meta> and C<body> elements.

=head1 GLOBAL VARIABLES

=item $NOT_AVAILABLE

May be over-ridden by supplying the constructor with a field of the same name.
See L<THE SUMMARY STRUCTURE>.

=cut

my  $NOT_AVAILABLE = '[Not available]';

=head1 CONSTRUCTOR (new)

Accepts a hash-like structure...

=over 4

=item PATH

Path to file to process.

=item SUMMARY

Filled after C<get_summary> is called (see L<METHOD get_summary> and
L<THE SUMMARY STRUCTURE>).

=item FIELDS

An array of C<meta> tag C<name>s whose C<content> value should be
placed into the respective slots of the C<SUMMARY> field after
C<get_summary> has been called.

=back

=head2 THE SUMMARY STRUCTURE

A field of the object which is a hash, with key/values as follows:

=over 4

=item AUTHOR, TITLE

HTML C<meta> tag of same names.

=item DESCRIPTION

Content of the C<meta> tag of the same name.

=item LAST_MODIFIED_META, LAST_MODIFIED_FILE

Time since of the modification of the file,
respectively according to any C<meta> tag of the same name,
and according to the file system. If the former does not exist,
it takes the value of the latter.

=item CREATED_META, CREATED_FILE

As above, but relating to the creation date of the file.

=item FIRST_PARA

The first HTML C<p> element of the document.

=item HEADLINE

The first C<h1> tag; failing that, the first C<h2>; failing that,
the value of C<$NOT_AVAILABLE>.

=item PLUS...

Any meta-fields specified in the C<FIELDS> field.

=back

=cut

sub new { my ($class) = (shift);
	warn __PACKAGE__."::new called without a class ref?" and return undef unless defined $class;
	my %args;
	my $self = {};
	bless $self,$class;
	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }
	# Defaults
	$self->{SUMMARY}	= {};
	# Load parameters
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }
	# Check required params
	foreach (qw(PATH )){
		croak "Required parameter field missing : $_" if not $self->{$_}
	}
	# Default method
	$NOT_AVAILABLE = $self->{NOT_AVAILABLE} if $self->{NOT_AVAILABLE};
	$self->get_summary() if $self->{PATH};
	# Done
	return $self;
}


=head1 METHOD get_summary

Optionally takes an argument that over-rides and re-sets the C<PATH> field.
Otherwise uses the C<PATH> field to get a summary and put it into the hash
that is the C<SUMMARY> field. See also L<THE SUMMARY STRUCTURE>.

Return C<1> on success, C<undef> on failure, setting C<$!> with an error message.

=cut

sub get_summary { my ($self,$path) = (shift,shift);
	my ($p,$token);
	if (defined $path){
		$self->{PATH} = $path
	} elsif (not $self->{PATH}){
		$! = "get_summary requires a path argument, or that the PATH field be set.";
		return undef;
	}
	my $html = $self->load_file() or return undef;
	# Get first para
	if (not $p = new HTML::TokeParser( $html ) ){
		$! = "HTML::TokeParser could not initiate: $!";
		return undef;
	}
	if ($token = $p->get_tag('h1')){
		$self->{SUMMARY}->{HEADLINE} = $p->get_trimmed_text;
	} else {
		if (not $p = new HTML::TokeParser( $html ) ){
			$! = "HTML::TokeParser could not initiate: $!";
			return undef;
		}
		if ($token = $p->get_tag('h2')){
			$self->{SUMMARY}->{HEADLINE} = $p->get_trimmed_text;
		} else {
			$self->{SUMMARY}->{HEADLINE} = $NOT_AVAILABLE;
		}
	}
	if (not $p = new HTML::TokeParser( $html ) ){
		$! = "HTML::TokeParser could not initiate: $!";
		return undef;
	}
	if ($token = $p->get_tag('p')){
		$self->{SUMMARY}->{FIRST_PARA} = $p->get_trimmed_text;
	} else {
		$self->{SUMMARY}->{FIRST_PARA} = $NOT_AVAILABLE
	}

	# Get common meta elements
	if (not $p = HTML::HeadParser->new){
		$! = "HTML::HeadParser could not initiate: $!";
		return undef;
	}
	$p->parse($$html);

	$self->{SUMMARY}->{TITLE} = $p->header('title')  || $NOT_AVAILABLE;
	$self->{SUMMARY}->{AUTHOR} = $p->header('X-META-AUTHOR') || $NOT_AVAILABLE;
	{
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
		   $atime,$mtime,$ctime,$blksize,$blocks) = stat $self->{PATH};

		$self->{SUMMARY}->{LAST_MODIFIED_FILE} = scalar localtime ( $mtime ) || $NOT_AVAILABLE;
		$self->{SUMMARY}->{LAST_MODIFIED_FILE} =~ s/\s+/ /g;

		$self->{SUMMARY}->{CREATED_FILE} = scalar localtime ( $ctime ) || $NOT_AVAILABLE;
		$self->{SUMMARY}->{CREATED_FILE} =~ s/\s+/ /g;
	}

	$self->{SUMMARY}->{LAST_MODIFIED_META} = $p->header('X-META-LAST-MODIFIED')
	|| $self->{SUMMARY}->{LAST_MODIFIED_FILE}
	|| $NOT_AVAILABLE;

	$self->{SUMMARY}->{CREATED_META} = $p->header('X-META-LAST-MODIFIED')
	|| $self->{SUMMARY}->{CREATED_FILE}
	|| $NOT_AVAILABLE;

	$self->{SUMMARY}->{DESCRIPTION} = $p->header('X-META-DESCRIPTION')
	|| $NOT_AVAILABLE;
	# Do user fields
	foreach (keys %{$self->{FIELDS}}) {
		next if $self->{SUMMARY}->{$_}; # Do not re-do anything.
		$self->{SUMMARY}->{$_} = $p->header('X-META-'.$_) || $NOT_AVAILABLE;
	}
	return 1;
}


=head1 METHOD load_file

Optionally takes an argument that over-rides and re-sets the C<PATH> field.
Otherwise uses the C<PATH> field to load an HTML file and return a reference
to a scalar full of it.

Return a reference to a scalar of HTML, or C<undef> on failure, setting C<$!> with an error message.

=cut

sub load_file { my ($self,$path) = (shift,shift);
	local *IN;
	if (defined $path){
		$self->{PATH} = $path
	} elsif (not $self->{PATH}){
		$! = "load_file requires a path argument, or that the PATH field be set.";
		return undef;
	}
	if (not open IN, $self->{PATH}){
		$! = "load_file could not open $self->{PATH}.";
		return undef;
	}
	read IN, $_, -s IN;
	close IN;
	return \$_;
}

1;

=head1 TODO

Maybe work on URI as well as file paths.

=head1 SEE ALSO

L<HTML::TokeParser>, L<HTML::HeadParser>.

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you may use and redistribute it or modify it
undef the same terms as Perl itself.



