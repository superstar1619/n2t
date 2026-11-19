#!/usr/bin/perl -w
use strict;
use v5.34;

use File::Spec::Functions qw(catfile);
use File::Basename qw(fileparse basename dirname);

use constant {
    KEYWORD => "keyword",
    SYMBOL => "symbol",
    INDENTIFIER => "identifier",
    INT_CONST => "integerConstant",
    STRING_CONST => "stringConstant",
};
my $dr = '.';

##############
# subroutine #
##############

sub file_sub {
    my ($pattern, @source) = @_;
    my $filelists = [];
    if(-d $source[0])
    {
        # $dr = $source[0];
        opendir my $dh, $source[0];
        foreach (readdir $dh){
            if(/$pattern/)
            {
                push @$filelists, [catfile($source[0], $_), catfile($dr, $_ =~ s/${pattern}$/T.xml/r), catfile($dr, $_ =~ s/${pattern}$/.xml/r)];
            }
        }
    }
    else
    {
        foreach (@source){
            if(/$pattern/)
            {
                push @$filelists, [$_, catfile($dr, (basename $_) =~ s/${pattern}$/T.xml/r), catfile($dr, (basename $_) =~ s/${pattern}$/.xml/r) ];
            }
        }
    }
    return $filelists;
}

sub ign_blank {
    my $fh = shift;
    open my $sh, ">", \ my $string;
    while(<$fh>)
    {
        chomp;
        # say "$_ ";
        $_ =~ s/\/\/.*/ /;
        print {$sh} "$_ ";
        # say "$_ ";
    }
    close $sh;
    $string =~ s/\/\*\*?.*?\*\// /g;
    $string .= ' ';
    return $string;
}

sub JackTokenizer {
    my $fs = shift;
    my $keyword = qr/class|constructor|function|method|field|static|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return/;
    my $symbol = qr/\{|\}|\(|\)|\[|\]|\.|\,|\;|\+|\-|\*|\/|\&|\||\<|\>|\=|\~/;
    my $number = qr/\d+/;
    my $string = qr/[^\"]*/;
    my $indentifier = qr/[\_a-zA-Z]{1}[\_a-zA-Z\d]*/;
    my $tokenlists = [];
    while($fs ne "")
    {
        my $pattern;
        $fs =~ s/^\s+//;
        last if $fs eq "";
        
        if($fs =~ m/^($keyword)[^\_a-zA-Z\d]/)
        {
            push @$tokenlists, [$1, KEYWORD];   
        }
        elsif($fs =~ m/^($symbol)/)
        {
            push @$tokenlists, [$1, SYMBOL]; 
        }
        elsif($fs =~ m/^($number)/)
        {
            push @$tokenlists, [$1, INT_CONST]; 
        }
        elsif($fs =~ m/^(\"($string)\")/)
        {
            push @$tokenlists, [$2, STRING_CONST];
        }
        elsif($fs =~ m/^($indentifier)/)
        {
            push @$tokenlists, [$1, INDENTIFIER]; 
        }

        if(!(defined $1) || $1 eq "")
        {
            print $fs;
        }
        else
        {
            $pattern = qr/\Q$1\E/;
            $fs =~ s/^$pattern//;
        }
    }
    return $tokenlists;
}

sub output_token {
    my $fh = shift;
    my $tokenlists = shift;
    say {$fh}"<tokens>";
    foreach (@$tokenlists){
        print {$fh}"<$_->[1]>";
        if($_->[0] eq '<')
        {
            print {$fh}" \&lt; ";
        }
        elsif($_->[0] eq '>')
        {
            print {$fh}" \&gt; ";
        }
        elsif($_->[0] eq '&')
        {
            print {$fh}" \&amp; ";
        }
        else
        {
            print {$fh}" $_->[0] ";
        }
        print {$fh}"<\/$_->[1]>";
        print {$fh}"\n";
    }
    say {$fh}"<\/tokens>";
}

sub CompileEngine {
    my ($fh, $tokenlists) = @_;
    my $mb = [];
    my $matchbracket;
    my $compileSingle;
    my $compileClass;
    my $compileClassVarDec;
    my $compileSubroutine;
    my $compileParameterList;
    my $compileSubroutineBody;
    my $compileVarDec;
    my $compileStatements;
    my $compileLet;
    my $compileIf;
    my $compileWhile;
    my $compileDo;
    my $compileReturn;
    my $compileExpression;
    my $compileTerm;
    my $compileExpressionList;
    my $compileSubroutineCall;
    
    $matchbracket = sub {
        my ($start, $end) = @_;
        my @stack;
        for(my $i=$start; $i<=$end; $i++)
        {
            if($tokenlists->[$i]->[0] eq '(' || $tokenlists->[$i]->[0] eq '[' || $tokenlists->[$i]->[0] eq '{')
            {
                push @stack, $i;
            }
            elsif($tokenlists->[$i]->[0] eq ')' || $tokenlists->[$i]->[0] eq ']' || $tokenlists->[$i]->[0] eq '}')
            {
                my $p = pop @stack;
                $mb->[$p] = $i;
            }
        }
    };

    $compileClass = sub {
        my ($start, $end) = @_;
        $matchbracket->($start, $end);
        say {$fh} "<class>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileSingle->($start+2);
        my $i = $start + 3;
        my $j = $end - 1;
        for(my ($now, $pre) = ($i + 1, $i);$now <= $j; $now++)
        {
            if(($tokenlists->[$now+1]->[0] =~ m/static|field|constructor|function|method/)||($now == $j))
            {
                if($tokenlists->[$pre]->[0] =~ m/static|field/)
                {
                    $compileClassVarDec->($pre, $now);
                }
                else
                {
                    $compileSubroutine->($pre, $now);
                }
                $pre = $now + 1;
            }
        }
        $compileSingle->($end);
        say {$fh} "<\/class>";
    };
    $compileClassVarDec = sub {
        my ($start, $end) = @_;
        say {$fh} "<classVarDec>";
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }
        say {$fh} "<\/classVarDec>";
    };
    $compileSubroutine = sub {
        my ($start, $end) = @_;
        say {$fh} "<subroutineDec>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileSingle->($start+2);
        $compileSingle->($start+3);
        my $right = $mb->[$start+3];
        $compileParameterList->($start+4, $right-1);
        $compileSingle->($right);
        $compileSubroutineBody->($right+1, $end);
        say {$fh} "<\/subroutineDec>";
    };
    $compileParameterList = sub {
        my ($start, $end) = @_;
        say {$fh} "<parameterList>";
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }
        say {$fh} "<\/parameterList>";
    };
    $compileSubroutineBody = sub {
        my ($start, $end) = @_;
        say {$fh} "<subroutineBody>";
        $compileSingle->($start);
        if($tokenlists->[$start+1]->[0] ne 'var')
        {
            $compileStatements->($start+1,$end-1);
        }
        else
        {
            for(my ($i, $pre) = ($start+1, $start+1); $i<=$end-1 ;$i++)
            {
                if($tokenlists->[$i]->[0] eq ';')
                {
                    $compileVarDec->($pre, $i);
                    if($tokenlists->[$i+1]->[0] ne 'var')
                    {
                        $compileStatements->($i+1,$end-1);
                        last;
                    }
                    else
                    {
                        $pre = $i+1;
                    }
                }
            }
        }
        $compileSingle->($end);
        say {$fh} "<\/subroutineBody>";
    };
    $compileVarDec = sub {
        my ($start, $end) = @_;
        say {$fh} "<varDec>";
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }
        say {$fh} "<\/varDec>";
    };
    $compileStatements = sub {
        my ($start, $end) = @_;
        say {$fh} "<statements>";
        my $j;
        for(my $i = $start; $i<=$end ;$i=$j+1)
        {
            if($tokenlists->[$i]->[0] eq 'let')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileLet->($i,$j);
            }
            elsif($tokenlists->[$i]->[0] eq 'if')
            {
                my @arr;
                $j = $mb->[$i+1];
                push @arr, $j;
                $j = $mb->[$j+1];
                push @arr, $j;
                if($tokenlists->[$j+1]->[0] eq 'else')
                {
                    $j = $mb->[$j+2];
                    push @arr, $j;
                }
                $compileIf->($i, $j, @arr);
            }
            elsif($tokenlists->[$i]->[0] eq 'while')
            {
                my @arr;
                $j = $mb->[$i+1];
                push @arr, $j;
                $j = $mb->[$j+1];
                push @arr, $j;
                $compileWhile->($i, $j, @arr);
            }
            elsif($tokenlists->[$i]->[0] eq 'do')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileDo->($i,$j);
            }
            elsif($tokenlists->[$i]->[0] eq 'return')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileReturn->($i,$j);
            }
        }
        say {$fh} "<\/statements>";
    };
    $compileLet = sub {
        my ($start, $end) = @_;
        say {$fh} "<letStatement>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        my $now = $start + 2;
        if($tokenlists->[$now]->[0] eq '[')
        {
            $compileSingle->($now);
            my $next = $mb->[$now];
            $compileExpression->($now+1, $next-1);
            $compileSingle->($next);
            $now = $next+1;
        }
        $compileSingle->($now);
        $compileExpression->($now+1, $end-1);
        $compileSingle->($end);
        say {$fh} "<\/letStatement>";
    };
    $compileIf = sub {
        my ($start, $end, @arr) = @_;
        say {$fh} "<ifStatement>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileExpression->($start+2, $arr[0]-1);
        $compileSingle->($arr[0]);
        $compileSingle->($arr[0]+1);
        $compileStatements->($arr[0]+2, $arr[1]-1);
        $compileSingle->($arr[1]);
        if(defined $arr[2])
        {
            $compileSingle->($arr[1]+1);
            $compileSingle->($arr[1]+2);
            $compileStatements->($arr[1]+3, $arr[2]-1);
            $compileSingle->($arr[2]);
        }
        say {$fh} "<\/ifStatement>";
    };
    $compileWhile = sub {
        my ($start, $end, @arr) = @_;
        say {$fh} "<whileStatement>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileExpression->($start+2, $arr[0]-1);
        $compileSingle->($arr[0]);
        $compileSingle->($arr[0]+1);
        $compileStatements->($arr[0]+2, $arr[1]-1);
        $compileSingle->($arr[1]);
        say {$fh} "<\/whileStatement>";
    };
    $compileDo = sub {
        my ($start, $end) = @_;
        say {$fh} "<doStatement>";
        $compileSingle->($start);
        $compileSubroutineCall->($start+1, $end-1);
        $compileSingle->($end);
        say {$fh} "<\/doStatement>";
    };
    $compileReturn = sub {
        my ($start, $end) = @_;
        say {$fh} "<returnStatement>";
        $compileSingle->($start);
        if($start+1 <= $end-1)
        {
            $compileExpression->($start+1, $end-1);
        }
        $compileSingle->($end);
        say {$fh} "<\/returnStatement>";
    };
    $compileExpression = sub {
        my ($start, $end) = @_;
        say {$fh} "<expression>";
        my $i=$start;
        my $j;
        my $flag=0;
        while($i<=$end)
        {
            if($flag == 1)
            {
                $compileSingle->($i);
                $i++;
            }
            $i = $compileTerm->($i) + 1;
            $flag=1;
        }
        say {$fh} "<\/expression>";
    };
    $compileTerm = sub {
        my $p = shift;
        say {$fh} "<term>";
        if($tokenlists->[$p]->[1] eq INT_CONST)
        {
            $compileSingle->($p);
            say {$fh} "<\/term>";   
            return $p;
        }
        elsif($tokenlists->[$p]->[1] eq STRING_CONST)
        {
            $compileSingle->($p);
            say {$fh} "<\/term>";   
            return $p;
        }
        elsif($tokenlists->[$p]->[0] =~ m/true|false|null|this/)
        {
            $compileSingle->($p);
            say {$fh} "<\/term>";   
            return $p;
        }
        elsif($tokenlists->[$p]->[1] eq INDENTIFIER)
        {
            my $next;
            if($tokenlists->[$p+1]->[0] eq '[')
            {
                $compileSingle->($p);
                my $count=1;
                my $next = $mb->[$p+1];
                $compileSingle->($p+1);
                $compileExpression->($p+2, $next-1);
                $compileSingle->($next);
                say {$fh} "<\/term>";
                return $next;
            }
            elsif($tokenlists->[$p+1]->[0] eq '(')
            {
                my $count=1;
                my $next = $mb->[$p+1];
                $compileSubroutineCall->($p,$next);
                say {$fh} "<\/term>";
                return $next;   
            }
            elsif($tokenlists->[$p+1]->[0] eq '.')
            {
                my $count=1;
                my $next = $mb->[$p+3];
                $compileSubroutineCall->($p,$next);
                say {$fh} "<\/term>";
                return $next;
            }
            else{
                $compileSingle->($p);
                say {$fh} "<\/term>";
                return $p;
            }
        }
        elsif($tokenlists->[$p]->[0] eq '(')
        {
            my $next = $mb->[$p];
            $compileSingle->($p);
            $compileExpression->($p+1, $next-1);
            $compileSingle->($next);
            say {$fh} "<\/term>";
            return $next;
        }
        elsif($tokenlists->[$p]->[0] =~ m/\-|\~/)
        {
            $compileSingle->($p);
            my $p = $compileTerm->($p+1);
            say {$fh} "<\/term>";
            return $p;
        }
    };
    $compileExpressionList = sub {
        my ($start, $end) = @_;
        say {$fh} "<expressionList>";
        my $p;
        for($p=$start;$p<=$end;$p++)
        {
            if($tokenlists->[$p]->[0] eq ',')
            {
                $compileExpression->($start, $p-1);
                $start = $p+1;
                $compileSingle->($p);
            }
        }
        if($start <= $end)
        {
            $compileExpression->($start, $end);
        }
        say {$fh} "<\/expressionList>";
    };
    $compileSubroutineCall = sub {
        my ($start, $end) = @_;
        $compileSingle->($start);
        if($tokenlists->[$start+1]->[0] eq '.')
        {
            $compileSingle->($start+1);
            $compileSingle->($start+2);
            $compileSingle->($start+3);
            $compileExpressionList->($start+4, $end-1);
            $compileSingle->($end);
        }
        else
        {
            $compileSingle->($start+1);
            $compileExpressionList->($start+2, $end-1);
            $compileSingle->($end);
        }
    };
    $compileSingle = sub {
        my $position = shift;
        my $word = $tokenlists->[$position];
        print {$fh}"<$word->[1]>";
        if($word->[0] eq '<')
        {
            print {$fh}" \&lt; ";
        }
        elsif($word->[0] eq '>')
        {
            print {$fh}" \&gt; ";
        }
        elsif($word->[0] eq '&')
        {
            print {$fh}" \&amp; ";
        }
        else
        {
            print {$fh}" $word->[0] ";
        }
        print {$fh}"<\/$word->[1]>";
        print {$fh}"\n";
    };
    return $compileClass;
}

########
# main #
########


my $filelists = file_sub(qr/\.jack/, @ARGV);

foreach my $filename (@$filelists){
    open my $fh, "<", $filename->[0];
    my $content = ign_blank $fh;
    close $fh;
    my $tokenlists = JackTokenizer $content;
    # open $fh, ">", $filename->[1];
    open $fh, ">", $filename->[1];
    output_token $fh, $tokenlists;
    close $fh;
    open $fh, ">", $filename->[2];
    my $ce = CompileEngine($fh, $tokenlists);
    $ce->(0, $#$tokenlists);
}