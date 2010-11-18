package CNC::Drawing;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;

# the current x,y,z cooddinates (machine coordinates after transform)
has x => ( is => 'rw', default => 0 );
has y => ( is => 'rw', default => 0 );
has z => ( is => 'rw', default => 0 );

#  the gcode commands we collect
has gcode => (
    is => 'rw',
    isa => 'ArrayRef',
    metaclass => 'Collection::Array',
    default => sub { [] },
    # provides => {
    #     add    => 'push',
    #     get    => 'get',
    # },
);

# the transformation matrix like PostScript
has ctm => (
    is => 'rw',
    isa => 'ArrayRef',
    metaclass => 'Collection::Array',
    default => sub { [1,0, 0,1, 0,0] },
);


### TODO: must maintain x,y,z coordinates while drawing

sub as_text {
    my $self = shift;
    
    return join("\n", map { join(' ', 
                                 map { ref($_) ? @{$_} : $_ } @{$_}) }
                      @{$self->gcode});
}

# add a gcode command, coordinates are transformed before
# $x->append('gcode', x => x-value, y => y-value, ...)
sub append {
    my $self = shift;
    
    # scan thru args, check for x,y -> transform them
    my @code;
    my $must_scale = 0;
    while (scalar(@_)) {
        my $part = shift;
        if (ref($part) eq 'SCALAR') {
            push @code, "($$part)";
        } elsif (ref($part)) {
            push @code, $part;
            $must_scale = 1 if (ref($part) eq 'ARRAY' && $part->[0] =~ m{\A [xy] \z}xms);
        } elsif (lc($part) =~ m{\A [xy] \z}xms) {
            # x or y -- must scale (later!)
            $must_scale = 1;
            push @code, [ $part, shift() ];
        } elsif (lc($part) =~ m{\A [zabcijkuvw] \z}xms) {
            push @code, [ $part, shift() ];
        } else {
            push @code, $part;
        }
    }
    
    # check if we must transform x or y
    if ($must_scale) {
        my ($x_block) = grep {ref($_) eq 'ARRAY' && lc($_->[0]) eq 'x'} @code;
        my ($y_block) = grep {ref($_) eq 'ARRAY' && lc($_->[0]) eq 'y'} @code;
        
        my ($x, $y) = $self->transform( $x_block ? $x_block->[1] : $self->x,
                                        $y_block ? $y_block->[1] : $self->y );
        
        $x_block->[1] = $x;
        $y_block->[1] = $y;
        
        $self->x($x);
        $self->y($y);
    };
    
    push @{$self->gcode}, \@code;
}

# init coordinate transformation
sub init {
    my $self = shift;
    
    $self->ctm([1,0, 0,1, 0,0]); # 3 lines, 2 columns
    
    return $self;
}

sub scale {
    my $self = shift;
    my $sx = shift;
    my $sy = shift // $sx;
    
    $self->ctm->[0] *= $sx;
    $self->ctm->[2] *= $sx;
    
    $self->ctm->[1] *= $sy;
    $self->ctm->[3] *= $sy;
    
    return $self;
}

sub rotate {
    my $self = shift;
    my $angle = shift;
    
    my @ctm = @{$self->ctm};
    my $sin = sin( $angle / 180 * 3.1415 );
    my $cos = cos( $angle / 180 * 3.1415 );
    
    # mat multiply (cos -sin sin cos 0 0) * ctm --> ctm
    $self->ctm( [
        $cos * $ctm[0] - $sin * $ctm[2],
        $cos * $ctm[1] - $sin * $ctm[3],
        $sin * $ctm[0] + $cos * $ctm[2],
        $sin * $ctm[1] + $cos * $ctm[3],
        $ctm[4],
        $ctm[5]
    ] );
    
    return $self;
}

sub translate {
    my $self = shift;
    my $x = shift;
    my $y = shift;
    
    $self->ctm->[4] += $x;
    $self->ctm->[5] += $y;
}

sub transform {
    my $self = shift;
    my $x = shift;
    my $y = shift;
    
    my @ctm = @{$self->ctm};
    
    my ($xx, $yy) = ( sprintf('%0.2f', $x * $ctm[0] + $y * $ctm[1] + $ctm[4]),
                      sprintf('%0.2f', $x * $ctm[2] + $y * $ctm[3] + $ctm[5]) );
    
    return wantarray ? ($xx, $yy) : [$xx, $yy];
}

no Moose;
1;
