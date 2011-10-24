#  Copyright (C) 2011  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software

# Hardware+Software inventory action for Actelis modems


package GP_xDSL::TL1::Mixin::Actelis;

use strict;
use warnings;

use JSON ();

our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    my $ret = {
        'actelis.inventory' => \&get_actelis_inventory,
    };

    return $ret;
};




sub get_actelis_inventory
{
    my $ahandler = shift;
    
    my $ret = {};

    my $acc = $ahandler->device->{'ACCESS_HANDLER'};

    # Hardware inventory
    my $result = $acc->tl1_command({'cmd' => 'RTRV-INVENTORY'});
    if( not $result->{'success'} )
    {
        return {'success' => 0, 'content' => $result->{'error'}};
    }

    foreach my $line (@{$result->{'response'}})
    {
        my ($card, $props) = split(/:/, $line);
        
        foreach my $entry (split(/,/, $props))
        {
            if( $entry =~ /^(\w+)=(.+)$/ )
            {
                my $key = $1;
                my $val = $2;
                $val =~ s/^\\\"//;
                $val =~ s/\\\"$//;                
                $ret->{'hardware'}{$card}{$key} = $val;
            }
        }
    }
    
    # Software inventory
    $result = $acc->tl1_command({'cmd' => 'RTRV-SW'});
    if( not $result->{'success'} )
    {
        return {'success' => 0, 'content' => $result->{'error'}};
    }
    
    foreach my $entry (split(/,/, $result->{'response'}[0]))
    {
        if( $entry =~ /^(\w+)=(.+)$/ )
        {
            $ret->{'software'}{'system'}{$1} = $2;
        }
    }    
    
    my $json = new JSON;
    $json->pretty(1);
    
    return {
        'success' => 1,
        'content' => $json->encode($ret),
        'rawdata' => $ret,
        'has_json' => 1,
        'has_rawdata' => 1,
    };
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
