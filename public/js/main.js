$(document).ready(function(){
	
	$('.contacts-list').on('click',function(e){
		var target = $(e.target);
		if (target.hasClass('cl-edit-button')) {
			target.closest('.cl-row-header').siblings('.expander-form').slideDown();
		};
	})
	
	$('#loginForm').on( "submit", function( event ) {
		$('.alert').remove();
		event.preventDefault();
		var data_ser = $(this).serialize();
		$.ajax({
			type: "POST",
			url: "/login",
			data: data_ser
		}).done( function(msg) {
			$("#loginForm").prepend('<div class="alert alert-success" role="alert">Success, redirecting to home</div>');	
			window.setTimeout(function(){window.location.replace("/home")} ,1000);
			
		}).fail(function(jqXHR, msg) {
			$("#loginForm").prepend('<div class="alert alert-danger" role="alert">Problem with login: '+jqXHR.responseText+'</div>');	
		});
	});
		
	$('#registerForm').on( "submit", function( event ) {
		$('.alert').remove();
		event.preventDefault();
		var data_ser = $(this).serialize();
		$.ajax({
			type: "POST",
			url: "/register",
			data: data_ser
		}).done( function(msg) {
			$("#registerForm").prepend('<div class="alert alert-success" role="alert">Success, redirecting to home</div>');	
			window.setTimeout(function(){window.location.replace("/home")} ,1000);
			
		}).fail(function(jqXHR, msg) {
			$("#registerForm").prepend('<div class="alert alert-danger" role="alert">Problem with registration: '+jqXHR.responseText+'</div>');	
		});

	});
});
