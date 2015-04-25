$(document).ready(function(){
	
	$('.contacts-list').on('click',function(e){
		var target = $(e.target);
		if (target.hasClass('cl-edit-button')) {
			target.closest('.cl-row-header').siblings('.expander-form').slideDown();
		};
	})
	
});