package CNC::Text::Font;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;

extends 'CNC::Drawing';

#  a char looks like
#  [ { command => 'L|A', coordinates => [ [x,y], ... ] } ]
has char => (
    is => 'rw',
    isa => 'HashRef',
    metaclass => 'Collection::Hash',
    default => sub { {} },
    provides => {
        exists => 'has_char',
        keys   => 'all_chars',
        get    => 'get_char',
        set    => 'set_char',
    },
);

has name => (is => 'rw', isa => 'Str');
has letter_spacing => (is => 'rw', isa => 'Num');
has word_spacing => (is => 'rw', isa => 'Num');
has line_spacing => (is => 'rw', isa => 'Num');

sub render {
    my $self = shift;
    my $char = shift;
    my $options = shift || {};
    
    my $data = $self->char->{$char}
        or die "cannot render char '$char': missing";
    
    # starting coordinates and z-depth to dive into
    my $x     = $options->{x} || 0;
    my $y     = $options->{y} || 0;
    my $z     = $options->{z} || -1;
    my $z_home= $options->{z_home} || 10;
    
    my $current_x = -9999; # relative coordinates taken from font
    my $current_y = -9999;
    
    foreach my $entry (@{$data}) {
        # process one drawing command
        
        # check if we need a moveto first
        my ($x0,$y0) = @{$entry->{coordinates}->[0]};
        if ($current_x != $x + $x0 || $current_y != $y + $y0) {
            # move to starting point first
            $current_x = $x + $x0;
            $current_y = $y + $y0;
            
            $self->append('g0', z => $z_home);
            $self->append('g0', x => $current_x, y => $current_y);
            $self->append('g1', z => $z);
        }
        
        # execute command
        if ($entry->{command} eq 'L') {
            # a line -- must moveto second coordinate
            my ($x1,$y1) = @{$entry->{coordinates}->[1]};
            $current_x = $x + $x1;
            $current_y = $y + $y1;
            $self->append('g1', x => $current_x, y => $current_y);
        } else {
            warn "unimplemented command '$entry->{command}'";
        }
    }
    
    $self->append('g0', z => $z_home);
    
    return $self;
}

sub get_dimension {
    my $self = shift;
    my $char = shift;
    my $options = shift || {};
    
    my $data = $self->char->{$char}
        or return;
    
    my $min_x = 999;
    my $min_y = 999;
    my $max_x = 0;
    my $max_y = 0;
    
    foreach my $entry (@{$data}) {
        foreach my $coord (@{$entry->{coordinates}}) {
            # print Data::Dumper->Dump([$coord]);
            my ($x, $y) = @{$coord};
            $max_x = $x if ($x > $max_x);
            $max_y = $y if ($y > $max_y);
            $min_x = $x if ($x < $min_x);
            $min_y = $y if ($y < $min_y);
        }
    }
    
    return wantarray 
        ? ( $max_x, $max_y ) 
        : {
              x => [ $min_x, $max_x ],
              y => [ $min_y, $max_y ],
          };
}

sub load {
    my $self = shift;
    my $path = shift;
    
    die "Font-File at '$path' not found" if (!-f $path);
    
    open(my $f, '<', $path);
    
    # read header
    while (1) {
        my $line = <$f>;
        chomp $line;
        last if ($line !~ m{\S}xms);
        
        next if ($line !~ m{\A \s* \# \s* (\w+) : \s* (\S+) \s* \z}xms);
        $self->name($2)           if ($1 eq 'Name');
        $self->letter_spacing($2) if ($1 eq 'LetterSpacing');
        $self->word_spacing($2)   if ($1 eq 'WordSpacing');
        $self->line_spacing($2)   if ($1 eq 'LineSpacingFactor');
    }
    
    # read characters
    my $last_char;
    while (my $line = <$f>) {
        chomp $line;
        
        if ($line =~ m{\A \s* \[ ([0-9a-fA-F]+) \]}xms) {
            # a new character starts
            $last_char = chr( hex($1) );
            $self->char->{$last_char} = [];
        } elsif ($last_char && $line =~ m{\A \s* (\w) \s+ (.+?) \s* \z}xms) {
            my @coords = split(qr{\s*,\s*}xms, $2);
            push @{$self->char->{$last_char}}, {
                command => $1,
                coordinates => [  map { [ $coords[2 * $_], $coords[2 * $_ + 1] ] } (0 .. int(scalar(@coords) / 2)-1) ],
            };
        }
    }
    
    close($f);
}

no Moose;
1;
