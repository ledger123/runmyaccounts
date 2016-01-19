######################################################################
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#######################################################################
#
# two frame layout with refractured menu
#
#######################################################################

$menufile = "menu.ini";
use SL::Menu;


1;
# end of main


sub display {

  $menuwidth = ($ENV{HTTP_USER_AGENT} =~ /links/i) ? "240" : "155";
  $menuwidth = $myconfig{menuwidth} if $myconfig{menuwidth};

  $form->header;

  $callbacks = { 
	'ar:ar_reports:ar_reports_transactions' => 'ar.pl?action=search&nextsub=transactions&level=AR--Reports--Transactions',
	'ar:ar_reports:ar_reports_outstanding' => 'ar.pl?action=search&nextsub=transactions&outstanding=1&level=AR--Reports--Outstanding',
	'ap:ap_reports:ap_reports_outstanding' => 'ap.pl?action=search&nextsub=transactions&outstanding=1&level=AP--Reports--Outstanding',
  	'general_ledger:general_ledger_reports:general_ledger_reports_income_statement' => 'rp.pl?action=report&report=income_statement&level=General+Ledger--Reports--Income+Statement',
  };

  print qq|

<FRAMESET COLS="240,*" BORDER="1" bordercolor="#53626A">
  <FRAME NAME="acc_menu" SRC="$form->{script}?login=$form->{login}&action=acc_menu&path=$form->{path}&js=$form->{js}&menuids=$form->{menuids}">
|;

  if ($form->{menuids}){
    print qq|  <FRAME NAME="main_window" SRC="$callbacks->{$form->{menuids}}&login=$form->{login}&path=$form->{path}">|;
  } else {
    print qq|  <FRAME NAME="main_window" SRC="am.pl?login=$form->{login}&action=$form->{main}&path=$form->{path}">|;
  }

  print qq|
</FRAMESET>

</BODY>
</HTML>
|;

}



sub acc_menu {

  my $menu = new Menu "$menufile";
  $menu->add_file("custom_$menufile") if -f "custom_$menufile";
  $menu->add_file("$form->{login}_$menufile") if -f "$form->{login}_$menufile";
  
  $form->{title} = $locale->text('Accounting Menu');

  $form->header;

  print qq|
<script type="text/javascript">
function SwitchMenu(obj) {
  if (document.getElementById) {
    var el = document.getElementById(obj);

    if (el.style.display == "none") {
      el.style.display = "block"; //display the block of info
    } else {
      el.style.display = "none";
    }
  }
}

function ChangeClass(menu, newClass) {
  if (document.getElementById) {
    document.getElementById(menu).className = newClass;
  }
}
document.onselectstart = new Function("return false");

function SwitchMenuAndSub(menu, submenu) {
  if (document.getElementById) {
    var el = document.getElementById(submenu);

    if (el.style.display == "none") {
      el.style.display = "block"; //display the block of info
    } else {
      el.style.display = "none";
    }
    
    if ( document.getElementById(menu).className == 'menuClose' ) {
    	document.getElementById(menu).className = 'menuOpen';
    } else if ( document.getElementById(menu).className == 'menuOpen' ) {
    	document.getElementById(menu).className = 'menuClose';
    }
  }
}
</script>

<body class=menu>

|;

  if ($form->{js}) {
    &js_menu($menu);
  } else {
    &section_menu($menu);
  }

  print qq|
</body>
</html>
|;

}


sub section_menu {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder) {
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/$level--//g;

    my $spacer = "&nbsp;" x (($item =~ s/--/--/g) * 2);

    $label =~ s/.*--//g;
    $label = $locale->text($label);
    $label =~ s/ /&nbsp;/g if $label !~ /<img /i;

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};
    
    if ($menu->{$item}{submenu}) {

      $menu->{$item}{$item} = !$form->{$item};

      if ($form->{level} && $item =~ $form->{level}) {

        # expand menu
	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;

	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;

      } else {

	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label&nbsp;...</a>|;

        # remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

      }
      
    } else {
    
      if ($menu->{$item}{module}) {

	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;
	
      } else {

        $form->{tag}++;
	print qq|<a name="id$form->{tag}"></a>
	<p><b>$label</b>|;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;

      }
    }
  }
}



sub js_menu {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder){
    #$i++;
    $item = shift @menuorder;
    $label = $item;
    $i = lc $label;
    $i =~ s/--/_/g;
    $i =~ s/&//g;
    $i =~ s/  /_/g;
    $i =~ s/ /_/g;
    $i =~ s/-/_/g;
    $i =~ s/\//_/g;
    $label =~ s/.*--//g;
    $label = $locale->text($label);

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};

    if ($menu->{$item}{submenu}) {
      
	$display = "display: none;" unless $level eq ' ';

	print qq|
        <div id="menu$i" class="menuClose" onclick="SwitchMenuAndSub('menu$i','sub$i')">$label</div>
	<div class="submenu" id="sub$i" style="$display">|;
	
	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

	&js_menu($menu, $item);
	
	print qq|
	</div>
|;

    } else {

      if ($menu->{$item}{module}) {
	if ($level eq "") {
	  print qq|<div id="menu$i" class="menuClose"> |. 
	  $menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a></div>|;

	  # remove same level items
	  map { shift @menuorder } grep /^$item/, @menuorder;

          &js_menu($menu, $item);

	} else {
	
	  print qq|<div class="submenu"> |.
          $menu->menuitem(\%myconfig, \%$form, $item, $level, $i).qq|$label</a></div>|;
	}

      } else {

	$display = "display: none;" unless $item eq ' ';

	print qq|
<div id="menu$i" class="menuClose" onclick="SwitchMenuAndSub('menu$i','sub$i')">$label</div>
	<div class="submenu" id="sub$i" style="$display">|;
	
	&js_menu($menu, $item);
	
	print qq|
	</div>
|;

      }

    }

  }

}


sub menubar {

  1;

}


