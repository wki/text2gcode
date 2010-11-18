#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";

binmode(STDOUT=>':encoding(utf8)');

use CNC::Drawing;
use CNC::Text;
use CNC::Text::Font;
use Data::Dumper; $Data::Dumper::Sortkeys = 1;

my $font = CNC::Text::Font->new();
$font->load('/Users/wolfgang/CNC_Programme/qcad_fonts/romans2.cxf');

my $d = CNC::Text->new({font => $font});
$d->append('g0', x => 0, y => 10, z => 2, \'first goto');
# $d->rotate(45);
$d->append('g0', x => 10, y => 0, z => 2);

#$d->font($font);
#$d->font->render('A');
#print $d->font->as_text . "\n";  exit;

# $d->rotate(15);
$d->render('Hello', {x => 0, y => 0, angle => 10});
$d->render('World!', {x => 0, y => -10, angle => -5, scale => 0.75});

$d->translate(10,20);
$d->scale(1,0.3);
$d->render('it works');

# $d->append('g1', z => 0);
print $d->as_text . "\n";

exit;


__END__
my $font = CNC::Text::Font->new();
$font->load('/Users/wolfgang/CNC_Programme/qcad_fonts/romans.cxf');

print Data::Dumper->Dump([join(', ', sort $font->all_chars)], ['chars']);

# calc min and max for coordinates
my $min_x = 999; my $min_x_char = '';
my $min_y = 999; my $min_y_char = '';
my $max_x = 0;   my $max_x_char = '';
my $max_y = 0;   my $max_y_char = '';

foreach my $char ($font->all_chars) {
    my $data = $font->char->{$char};
    #print Data::Dumper->Dump([$data], ['data']); exit;
    
    foreach my $entry (@{$data}) {
        foreach my $coord (@{$entry->{coordinates}}) {
            my ($x, $y) = @{$coord};
            do { $max_x_char = $char; $max_x = $x; } if ($x > $max_x);
            do { $max_y_char = $char; $max_y = $y; } if ($y > $max_y);
            do { $min_x_char = $char; $min_x = $x; } if ($x < $min_x);
            do { $min_y_char = $char; $min_y = $y; } if ($y < $min_y);
        }
    }
}

# print "min = ($min_x <$min_x_char>, $min_y <$max_y_char>), max = ($max_x <$max_x_char>, $max_y <$max_y_char>)\n";
# 
# print Data::Dumper->Dump([$font->get_dimension('g')], ['g_dim']);
# print Data::Dumper->Dump([$font->get_dimension('A')], ['A_dim']);
# print Data::Dumper->Dump([$font->get_dimension('x'), $font->char->{'A'}], ['x_dim', 'A']);


print "" . $font->gcode('x') . "\n";
