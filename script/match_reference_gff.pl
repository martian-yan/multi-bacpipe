#!/usr/bin/env perl 

## similar to unify_strain_gff.pl, but different in few ways: 
## - no new GFF file is produced, only blast results are filtered and matched to existing ref features 
## - match has to be pretty close to qualify and also of the same kind  
## in the end, $TAG.match.tsv is generated 

use strict; 
use warnings; 
#use Data::Dumper; 

my $prokka_gff = shift @ARGV; 
my $blast_out = shift @ARGV; 
my $ref_fa = shift @ARGV; 
my $tag = shift @ARGV; 

my $match_table = $tag.".match.tsv";

open GFF,"<",$prokka_gff or die "$!"; 
open BLAST,"<",$blast_out or die "$!"; 
open FA,"<",$ref_fa or die "$!"; 
open MATCH,">",$match_table or die "$!"; 

my %length;
my $genes = {};
my $blast = {};
my $count = 1; 
$tag =~ m/(.*?)_.*/; 
my $prefix = $1; ## locus tag prefix, use same as Prokka 

## read reference fasta (make sure it's not folded!)
## get length of each sequence 
for (;;) {
   my $seq_name = <FA>;
   last if not defined $seq_name;
   my $seq = <FA>;
   last if not defined $seq;
   $seq_name =~ m/>(.*?)\n/; 
   my $seq_id = $1; 
   my $seq_len = length($seq)-1; 
   $length{$seq_id} = $seq_len; 
}

## parse all blast hits, get rid of the poor quality ones
## hash genes uses both names and prokka locus tags as keys 
## if there are multiple hits passing identity/length threshold, do the following: 
## - if hits are identical, keep all, add _2, _3 etc to gene name; 
## - if hits are not idential, keep only the longest (usually full length).
  
while (<BLAST>) { 
  my @t = split /\t+/;
  $t[0] =~ m/^(.*)\.(.*?)$/;
  my $name = $1; 
  my $type = $2;
  die "ERROR: external reference can be of CDS/ncRNA type only!" if ($type ne "CDS" && $type ne "ncRNA");  
  my $len_ratio = $t[3]/$length{$t[0]}; 

  ## retain all high identity matches in blast hash 
  if ($t[2] > 90 && $len_ratio > 0.9) {   
    my $hit = (defined $blast->{$name}) ? scalar(keys(%{$blast->{$name}})) + 1 : 1;
 
    if ($t[9] > $t[8]) { 
      $blast->{$name}->{$hit}->{type} = $type; 
      $blast->{$name}->{$hit}->{chr} = $t[1]; 
      $blast->{$name}->{$hit}->{beg} = $t[8]; 
      $blast->{$name}->{$hit}->{end} = $t[9]; 
      $blast->{$name}->{$hit}->{strand} = "+";
 
      $blast->{$name}->{$hit}->{ident} = $t[2]; 
      $blast->{$name}->{$hit}->{len} = $len_ratio; 
    } else { 
      $blast->{$name}->{$hit}->{type} = $type; 
      $blast->{$name}->{$hit}->{chr} = $t[1]; 
      $blast->{$name}->{$hit}->{beg} = $t[9]; 
      $blast->{$name}->{$hit}->{end} = $t[8]; 
      $blast->{$name}->{$hit}->{strand} = "-";
 
      $blast->{$name}->{$hit}->{ident} = $t[2]; 
      $blast->{$name}->{$hit}->{len} = $len_ratio; 
    } 
  } 
}

#print Dumper $blast;

foreach my $name (keys %{$blast}) { 
  if (scalar keys %{$blast->{$name}} == 1) { 
    ## one name - one hit, all is good 
    $genes->{$name}->{type} = $blast->{$name}->{1}->{type}; 
    $genes->{$name}->{chr} = $blast->{$name}->{1}->{chr}; 
    $genes->{$name}->{beg} = $blast->{$name}->{1}->{beg}; 
    $genes->{$name}->{end} = $blast->{$name}->{1}->{end}; 
    $genes->{$name}->{strand} = $blast->{$name}->{1}->{strand}; 
  } else {
    ## 2+ hits per name
    my @hits = keys %{$blast->{$name}}; 
    my $best_ident = 0; 
    my $best_len = 0;
    ## establish best length and best id
    foreach my $hit (@hits) { 
      $best_ident = ($blast->{$name}->{$hit}->{ident} > $best_ident) ? $blast->{$name}->{$hit}->{ident} : $best_ident;
      $best_len = ($blast->{$name}->{$hit}->{len} > $best_len) ? $blast->{$name}->{$hit}->{len} : $best_len;
    } 
    ## add qualifying hits to "genes" hash 
    my $append_counter = 2; 
    foreach my $hit (@hits) { 
      my $ident = $blast->{$name}->{$hit}->{ident};
      my $len = $blast->{$name}->{$hit}->{len};
      if ($ident == $best_ident && $len == $best_len) {
        if (defined $genes->{$name}) {
          my $appended_name = join "_",$name,$append_counter; 
          $append_counter++; 
          $genes->{$appended_name}->{type} = $blast->{$name}->{$hit}->{type}; 
          $genes->{$appended_name}->{chr} = $blast->{$name}->{$hit}->{chr}; 
          $genes->{$appended_name}->{beg} = $blast->{$name}->{$hit}->{beg}; 
          $genes->{$appended_name}->{end} = $blast->{$name}->{$hit}->{end}; 
          $genes->{$appended_name}->{strand} = $blast->{$name}->{$hit}->{strand}; 
        } else {  
          $genes->{$name}->{type} = $blast->{$name}->{$hit}->{type}; 
          $genes->{$name}->{chr} = $blast->{$name}->{$hit}->{chr}; 
          $genes->{$name}->{beg} = $blast->{$name}->{$hit}->{beg}; 
          $genes->{$name}->{end} = $blast->{$name}->{$hit}->{end}; 
          $genes->{$name}->{strand} = $blast->{$name}->{$hit}->{strand}; 
        } 
      }  
    }
  } 
}
# I mean, god damn! 

## now parse Prokka annotation, including rRNA/tRNA/CRISPR; rename tmRNA -> ncRNA

my $crispr_count = 1; 

while (<GFF>) {
  if (m/\t/) {  
    chomp; 
    my @t = split /\t+/;
    if ($t[8] =~ m/ID=(.*?);/) {
      my $lt = $1;
      ## rename misc_RNA, tmRNA etc into tRNA 
      $t[2] = "ncRNA" if ($t[2] =~ m/rna/i && $t[2] ne "rRNA" && $t[2] ne "tRNA");  
      $genes->{$lt}->{chr} = $t[0]; 
      $genes->{$lt}->{type} = $t[2]; 
      $genes->{$lt}->{beg} = $t[3]; 
      $genes->{$lt}->{end} = $t[4]; 
      $genes->{$lt}->{strand} = $t[6]; 
    } elsif ($t[2] eq "repeat_region") { 
      my $crispr_lt = join "","CRISPR_",$crispr_count; 
      $crispr_count++; 
      $genes->{$crispr_lt}->{chr} = $t[0]; 
      $genes->{$crispr_lt}->{type} = "CRISPR"; 
      $genes->{$crispr_lt}->{beg} = $t[3]; 
      $genes->{$crispr_lt}->{end} = $t[4]; 
      $genes->{$crispr_lt}->{strand} = $t[6];
    }  
  }      
}

## now compare appropriate features and drop FULL overlaps of same-typed features

print STDERR "Merging blast-based annotation with Prokka-predicted features for strain $tag:\n";
print STDERR "------------------------------------------------------------------------------\n";  
foreach my $i (keys %{$genes}) { 
  foreach my $j (keys %{$genes}) {
    if (defined $genes->{$i} && $genes->{$j}) {  
      if ($i gt $j) { 
        my $chr1 = $genes->{$i}->{chr};
        my $beg1 = $genes->{$i}->{beg};
        my $end1 = $genes->{$i}->{end};
        my $type1 = $genes->{$i}->{type}; 
        my $strand1 = $genes->{$i}->{strand};
 
        my $chr2 = $genes->{$j}->{chr};
        my $beg2 = $genes->{$j}->{beg};
        my $end2 = $genes->{$j}->{end};
        my $type2 = $genes->{$j}->{type}; 
        my $strand2 = $genes->{$j}->{strand}; 

        ## we don't delete ncRNA if it overlaps CDS, and vice versa
        if ($chr1 eq $chr2 && $strand1 eq $strand2 && $beg1 <= $beg2 && $end1 >= $end2 && $type1 eq $type2) {  
          printf STDERR "Strain $tag, overlap detected: kept $i ($chr1,$beg1:$end1), dropped $j ($chr2,$beg2:$end2)\n"; 
          delete $genes->{$j}; 
        } 
        if ($chr1 eq $chr2 && $strand1 eq $strand2 && $beg1 > $beg2 && $end1 < $end2 && $type1 eq $type2) {  
          printf STDERR "Strain $tag, overlap detected: kept $j ($chr2,$beg2:$end2), dropped $i ($chr1,$beg1:$end1)\n"; 
          delete $genes->{$i}; 
        } 
      }
    } 
  }
}

## great way to order by both chr and beg!
my @keys = sort { $genes->{$a}->{chr} cmp $genes->{$b}->{chr} || $genes->{$a}->{beg} <=> $genes->{$b}->{beg} } keys %{$genes};

## now assign new locus tags and print unitied GFF
foreach my $key (@keys) {
  my $padded = sprintf "%05d",$count; 
  my $new_lt = join "_",$prefix,$padded;
  $genes->{$key}->{new_lt} = $new_lt; 
 
  my $chr = $genes->{$key}->{chr};
  my $beg = $genes->{$key}->{beg};
  my $end = $genes->{$key}->{end};
  my $type = $genes->{$key}->{type}; 
  my $biotype = $type; 
  $biotype = "noncoding_rna" if ($type eq "ncRNA"); 
  $biotype = "protein_coding" if ($type eq "CDS"); 
  
  my $strand = $genes->{$key}->{strand};
  printf UNITED "%s\tBacpipe\t%s\t%d\t%d\t.\t%s\t.\tID=%s;gene_biotype=%s;\n",$chr,$type,$beg,$end,$strand,$new_lt,$biotype; 
  $count++;
}

## now print name-to-new lt table 
foreach my $key (@keys) { 
  if ($key !~ m/^${prefix}_/) { 
    printf MATCH "%s\t%s\n",$key,$genes->{$key}->{new_lt};
  } 
} 

close FA;
close GFF;  
close BLAST; 
close UNITED; 
close MATCH;  
