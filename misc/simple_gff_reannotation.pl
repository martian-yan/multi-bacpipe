#!/usr/bin/env perl 

## similar to ncbi_to_roary.pl, but with some differences 
## basically all "gene" features are included, and reannotated based on the 
## features that have the same locus_tag (usually halves of a pseudogene) are unified into one feature 
## "CDS" gff now contains "pseudogene" entries as well. 
## "ncRNA" gff contains all of things that match *rna (non-case-spec), but not rRNA/tRNA. 

use strict;
use warnings; 

if ($#ARGV != 1) {
  die "USAGE: simple_gff_reannotation.pl <ncbi_gff> <tag>\n";
}

my $gff = shift @ARGV; 
my $tag = shift @ARGV; 

open GFF,"<",$gff or die "$!"; 
open GENE,">","$tag.gene.gff" or die "$!"; 

my $gene = {};
my $prod = {};
my ($coding,$pseudo,$ncrna,$trna,$rrna,$other,$notag) = (0)x7; 


while (<GFF>) { 
  if (m/\tgene\t/) {
    my @t = split /\t+/; 
    my $id = ($t[8] =~ m/ID=(.*?);/) ? $1 : "NONE"; 
    my $name = ($t[8] =~ m/Name=(.*?);/) ? $1 : "NONE"; 
    my $biotype = ($t[8] =~ m/;gene_biotype=(\w+)/) ? $1 : "NONE";
    ## quite few annotations have ncRNAs and rRNA/tRNA without a locus tag
    my $lt   = ($t[8] =~ m/;locus_tag=(\w+)/) ? $1 : join ('',$tag,"_",$id); 
    $notag++ if ($lt =~ m/_$id$/); 
    ## a bit of extra safety 
    $biotype = "pseudogene" if ($t[8] =~ m/pseudo=true/); 
    ## this accounts for duplicate locus tags in 
    if (! defined $gene->{$lt}) { 
      $gene->{$lt}->{lt} = $lt;  
      $gene->{$lt}->{id} = $id;  
      $gene->{$lt}->{name} = $name;  
      $gene->{$lt}->{biotype} = $biotype;
      $gene->{$lt}->{chr} = $t[0];   
      $gene->{$lt}->{beg} = $t[3];   
      $gene->{$lt}->{end} = $t[4];   
      $gene->{$lt}->{strand} = $t[6];
    } else { 
      $gene->{$lt}->{beg} = ($gene->{$lt}->{beg} <= $t[3]) ? $gene->{$lt}->{beg} : $t[3];  
      $gene->{$lt}->{end} = ($gene->{$lt}->{end} >= $t[4]) ? $gene->{$lt}->{end} : $t[4];  
      ## everything else is defined and stays the same 
    } 
  } elsif (m/Parent=gene/) {
    my @t = split /\t+/; 
    my $id = ($t[8] =~ m/Parent=(.*?);/) ? $1 : "NONE"; 
    my $product = ($t[8] =~ m/;product=(.*?);/) ? $1 : "NONE"; 
    my $note = ($t[8] =~ m/;Note=(.*?);/) ? $1 : "NONE"; 

    ## gene0 can be found on chr and plasmid sometimes, so
    $prod->{$t[0]}->{$id}->{product} = $product; 
    $prod->{$t[0]}->{$id}->{note} = $note; 
  } elsif (m/\tpseudogene\t/) {
    my @t = split /\t+/; 
    my $id = ($t[8] =~ m/ID=(.*?);/) ? $1 : "NONE"; 
    my $name = ($t[8] =~ m/Name=(.*?);/) ? $1 : "NONE"; 
    my $biotype = "pseudogene";
    my $lt   = ($t[8] =~ m/;locus_tag=(\w+)/) ? $1 : join ('',$tag,"_",$id); 
    $notag++ if ($lt =~ m/_$id$/); 

    ## this accounts for duplicate locus tags in 
    if (!defined $gene->{$lt}) { 
      $gene->{$lt}->{lt} = $lt;  
      $gene->{$lt}->{id} = $id;  
      $gene->{$lt}->{name} = $name;  
      $gene->{$lt}->{biotype} = $biotype;
      $gene->{$lt}->{chr} = $t[0];   
      $gene->{$lt}->{beg} = $t[3];   
      $gene->{$lt}->{end} = $t[4];   
      $gene->{$lt}->{strand} = $t[6];
    } else {
      $gene->{$lt}->{beg} = ($gene->{$lt}->{beg} <= $t[3]) ? $gene->{$lt}->{beg} : $t[3];  
      $gene->{$lt}->{end} = ($gene->{$lt}->{end} >= $t[4]) ? $gene->{$lt}->{end} : $t[4]; 
      ## everything else is defined and stays the same 
    } 
  } 
} 

print STDERR "GFF annotation processed; found $notag gene entries without a locus tag, for which new locus tags were generated.\n";

foreach my $lt (sort keys %{$gene}) {
  if ($lt ne "NONE") { 
    my $out = sprintf "%s\tBacpipe\tgene\t%s\t%s\t.\t%s\t.\t",$gene->{$lt}->{chr},$gene->{$lt}->{beg},$gene->{$lt}->{end},$gene->{$lt}->{strand};
    $out = join ('',$out,"ID=",$lt,";");
    my $name = ($gene->{$lt}->{name} eq "NONE") ? $lt : $gene->{$lt}->{name}; 
    $out = join ('',$out,"Name=",$name,";");
    my $product = (defined $prod->{$gene->{$lt}->{chr}}->{$gene->{$lt}->{id}}->{product}) ? $prod->{$gene->{$lt}->{chr}}->{$gene->{$lt}->{id}}->{product} : "NONE"; 
    my $note    = (defined $prod->{$gene->{$lt}->{chr}}->{$gene->{$lt}->{id}}->{note}) ? $prod->{$gene->{$lt}->{chr}}->{$gene->{$lt}->{id}}->{note} : "NONE"; 
    
    ## if product is defined, then use product; if note is defined instead of product, use note;
    ## if neither is defined, use nothing. 
    my $biotype = $gene->{$lt}->{biotype}; 
    if ($biotype =~ m/rna/i && $biotype ne "rRNA" && $biotype ne "tRNA") { 
      $biotype = "noncoding_rna"; 
    }
    if ($biotype eq "protein_coding") { 
      $coding++; 
    } elsif ($biotype eq "pseudogene") { 
      $pseudo++;
    } elsif ($biotype eq "noncoding_rna") { 
      $ncrna++; 
    } elsif ($biotype eq "rRNA") { 
      $rrna++; 
    } elsif ($biotype eq "tRNA") { 
      $trna++; 
    } else { 
      $other++; 
    } 
    
    $out = join ('',$out,"gene_biotype=",$biotype,";");
   
    if ($product ne "NONE") { 
      $out = join ('',$out,"product=",$product,";");
    } elsif ($note ne "NONE") { 
      $out = join ('',$out,"product=",$note,";");
    } 
    $out = join ('',$out,"locus_tag=",$lt,"\n");
    ## print out every gene entry, even rRNA and tRNA (they won't have expression since reads are removed from BAM)
    ## merge pseudogene halves into one "gene" entry with the same locus tag if LT of halves are the same 
    print GENE $out; 
  }
} 

print STDERR "GFF output stats: $coding protein coding, $pseudo pseudogenes, $ncrna noncoding RNAs, $trna tRNAs, $rrna rRNAs, $other others.\n"; 

close GFF; 
close GENE; 
