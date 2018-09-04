// written by mueller@cognita.ch
$(document).ready(function() {
	//mark items with no submenu
	$('.menu a:only-child').parent().removeClass('menuClose');
	$('.menu a:only-child').parent().removeClass('menuOpen');
	$('.menu a:only-child').parent().addClass('menuLink');
	$('.listheading > th:only-child').addClass('sectionheading');

	//add active-class (trail)
	$('.menuLink a').click(function() {
		$('.activeTrail').each(function(){
			$(this).removeClass('activeTrail');
		});
		$(this).parent().toggleClass('activeTrail');
	});
	
	$("a[href^='https://doc.runmyaccounts.com/alfresco/webdav/Mandanten/']")
	   .each(function()
	   { 
	      this.href = this.href.replace(/^https:\/\/doc.runmyaccounts.com\/alfresco\/webdav\/Mandanten\/([a-zA-Z0-9]*)\/(.*)/, 
	         "https://service.runmyaccounts.com/api/latest/clients/$1/dms/content?t=iframe&path=/$2");
	   });
	
	$("form").filter(function(){
		if($(this).attr('action').match(/[a-z]+.pl/)){
			$(this).closest("form").append('<input type="hidden" name="FRONTEND_HEADER" value="'+getCookie("FRONTEND_COOKIE")+'" />');
		}
	});
	
	function getCookie(cname) {
	    var name = cname + "=";
	    var ca = document.cookie.split(';');
	    for(var i = 0; i <ca.length; i++) {
	        var c = ca[i];
	        while (c.charAt(0)==' ') {
	            c = c.substring(1);
	        }
	        if (c.indexOf(name) == 0) {
	            return c.substring(name.length,c.length);
	        }
	    }
	    return "";
	}
	
	$(document).mousemove( function(e) {
		window.parent.parent.postMessage('mousemoved' ,'*');
	});
	
	/*
	//Navigation Frame
	//group list
	$('.menu > .menuOut').each(function(){
		$(this).add( $(this).nextUntil('.menuOut') ).wrapAll('<div class="ul"/>');
	});
	//mark first/last item as last for logout-button
	$('.ul:first').addClass('nothing');
	$('.ul:last-child').addClass('logout');
	//add .hover class
	$('.menu div').hover(function() {
	  $(this).addClass('hover');
		}, function() {
	  $(this).removeClass('hover');
	});
	//add active-class (trail)
	$('.ul .menuOut').click(function() {
		$(this).not('.layerone').toggleClass('active');
		$('.active').next().removeClass('third');
		$('.active').next().addClass('third');
	});
	$('.layerone > a').click(function() {
		$('.active-trail').removeClass('active-trail');
		$(this).parent().addClass('active-trail');
	});
	$('.submenu a').click(function() {
		$('.active-trail').removeClass('active-trail')
		$(this).addClass('active-trail');
	});
	//add +/- indicators
	$('.submenu').prev().append("<span class='visible'>+</span><span>&ndash;</span>");
	$('.submenu').prev().click(function() {
		$(this).children().toggleClass('visible');
	});
	
	//Main Frame
	$('.submit:first, .listrow0 td:first-child, .listrow1 td:first-child, .listsubtotal td:first-child, .listsubtotal th:first-child, .listtotal td:first-child, .listtotal th:first-child').addClass('first')
	$('.submit:last, .listrow0 td:last-child, .listrow1 td:last-child, .listsubtotal td:last-child, .listsubtotal th:last-child, .listtotal td:last-child, .listtotal th:last-child').addClass('last')
	$('.submit').wrapAll('<div class="buttons" />');
	$('body',top.frames['main_window'].document).addClass('main').wrapInner('<div id="wrap"/>');
	$('td[align=right]').addClass('right');
	$('.listheading[colspan=2]').addClass('header');
	$('h1.login').parents('body').addClass('start');
	$('td:empty, th:empty').html('&nbsp;');
	*/
});

function resizeTables()
{
    var tableArr = document.getElementsByTagName('table');
    var cellWidths = new Array();

    // get widest
    for(i = 0; i < tableArr.length; i++)
    {
        for(j = 0; j < tableArr[i].rows[0].cells.length; j++)
        {
           var cell = tableArr[i].rows[0].cells[j];

           if(!cellWidths[j] || cellWidths[j] < cell.clientWidth)
                cellWidths[j] = cell.clientWidth;
        }
    }

    // set all columns to the widest width found
    for(i = 0; i < tableArr.length; i++)
    {
        for(j = 0; j < tableArr[i].rows[0].cells.length; j++)
        {
            tableArr[i].rows[0].cells[j].style.width = cellWidths[j]+'px';
        }
    }
}
