package CNC::Text;
use Moose;

extends 'CNC::Drawing';

has font => (
    is => 'rw',
    isa => 'Object',
    
    # coerce: 'path-string' => font-object
);

sub render {
    my $self = shift;
    my $text = shift;
    my $options = shift || {};
    
    die 'no font defined' if (!$self->font);
    
    # starting coordinates and z-depth to dive into
    my $x     = $options->{x}      // 0;
    my $y     = $options->{y}      // 0;
    my $z     = $options->{z}      // 0;
    my $scale = $options->{scale}  // 1;
    my $angle = $options->{rotate} // 0;
    my $z_home= $options->{z_home} // 10;
    
    # save old CTM
    my @ctm = @{ $self->ctm };
    
    # apply requested params
    $self->font->init();
    $self->font->translate($x, $y);
    $self->font->scale($scale);
    $self->font->rotate($angle);
    
    # draw lines
    my $x_offset = 0;
    foreach my $char (split(//, $text)) {
        if ($char eq ' ') {
            $self->append();
            $self->append(\"WHITE SPACE: ${\$self->font->word_spacing}");
            $x_offset += $self->font->word_spacing;
        } else {
            $self->append();
            $self->append(\"Character '$char'");
            
            $self->font->gcode([]);
            $self->font->render($char, {x => $x_offset, z => $z, z_home => $z_home});
            my ($w, $h) = $self->font->get_dimension($char);
            
            $self->append(@{$_})
                for @{$self->font->gcode};
            
            $x_offset += $w + $self->font->letter_spacing;
        }
    }
    
    # restore CTM
    $self->ctm( \@ctm );
    
    # done
    return $self;
}

sub get_dimension {
    my $self = shift;
    my $text = shift;
    my $options = shift || {};
    
    die 'no font defined' if (!$self->font);
    
    my $scale = $options->{scale}  // 1;
    
    my $w = 0;
    my $h = 0;
    foreach my $char (split(//, $text)) {
        if ($char eq ' ') {
            $w += $self->font->word_spacing;
        } else {
            my ($cw, $ch) = $self->font->get_dimension($char);
            $w += $cw + $self->font->letter_spacing;
            $h = $ch if ($ch > $h);
        }
    }
    
    return wantarray 
        ? ( $w*$scale, $h*$scale )
        : [ $w*$scale, $h*$scale ];
}

no Moose;
1;

__END__


my $gcode = CNC::Drawing->new(
    {
        unit => 'mm', 
        home => {x => 0, y => 0, z => 10}
    });

$gcode->text('Hello, World', {x => 10, y => 42, z => -5});

$gcode->command(g01 => {x => 42, l => 33});

$gcode->save('/path/to/file.gnc');

