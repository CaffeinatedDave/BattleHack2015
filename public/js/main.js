$(document).ready(function(){
	
	$('.contacts-list').on('click',function(e){
		var target = $(e.target);
		if (target.hasClass('cl-edit-button')) {
			target.closest('.cl-row-header').siblings('.expander-form').slideDown();
		};
	})
	
	$('#loginForm').submit(function(e){
		alert("submit");
		$.ajax({
			type: "POST",
			url: "/login",
			data: this.serialize(),
			success: function(msg) {
				alert(msg);
			},
			error: function(msg) {
				alert("ERROR"+msg);	
			},
			dataType: json
		});
		return false;
	})
});
