$(document).ready(function(){
	
	$('#loginForm').on( "submit", function( event ) {
		var clone = prep_user_form($(this));
		event.preventDefault();
		var data_ser = $(clone).serialize();
		$.ajax({
			type: "POST",
			url: "/login",
			data: data_ser
		}).done( function(msg) {
			$("#loginForm").prepend('<div class="alert alert-success" role="alert">Success, redirecting to home</div>');	
			window.setTimeout(function(){window.location.replace("/")} ,1000);
			
		}).fail(function(jqXHR, msg) {
			$("#loginForm").prepend('<div class="alert alert-danger" role="alert">Problem with login: '+jqXHR.responseText+'</div>');	
		});
	});
		
	$('#registerForm').on( "submit", function( event ) {
		var clone = prep_user_form($(this));
		event.preventDefault();
		var data_ser = $(clone).serialize();
		$.ajax({
			type: "POST",
			url: "/register",
			data: data_ser
		}).done( function(msg) {
			$("#registerForm").prepend('<div class="alert alert-success" role="alert">Success, redirecting to payment page</div>');	
			window.setTimeout(function(){window.location.replace("/braintree_test")} ,1000);
			
		}).fail(function(jqXHR, msg) {
			$("#registerForm").prepend('<div class="alert alert-danger" role="alert">Problem with registration: '+jqXHR.responseText+'</div>');	
		});

	});
	
	$('#contactsForm').on( "submit", function( event ) {
		$('.alert').remove();
		event.preventDefault();
		var data_ser = $(this).serialize();
		$.ajax({
			type: "POST",
			url: "/",
			data: data_ser
		}).done( function(msg) {
			$("#contactsForm").prepend('<div class="alert alert-success" role="alert">Success, refreshing page</div>');	
			window.setTimeout(function(){window.location.replace("/")} ,1000);
			
		}).fail(function(jqXHR, msg) {
			$("#contactsForm").prepend('<div class="alert alert-danger" role="alert">Problem with updating contacts: '+jqXHR.responseText+'</div>');	
		});

	});
	
	$('#contactsForm').on('click',function(e){
		var target = $(e.target);
		if (target.hasClass('cl-edit-button')) {
			target.closest('.cl-row-header').siblings('.expander-form').slideToggle();
		} else if (target.hasClass('cl-delete-button')) {
			target
				.closest('.list-group-item').addClass('removed')
				.find('.expander-form').remove();
		}
	});
	
	$('#contactsForm .g-inputType input').on('change',function(e){
		var target = $(e.target);
		if (target.val() == "phone") {
			target.closest('.list-group-item').addClass('cl-phone-contact');
		} else {
			target.closest('.list-group-item').removeClass('cl-phone-contact');
		}
	});
	

	
	$('#cl-add-new').on( "click", function( event ) {
		var form = $('#contactsForm');
		var new_i = parseInt(form.find('#inputNumIncrem').val());
		form.find('#inputNumIncrem').val(parseInt(new_i)+1);
		var default_form_html = '<li class="list-group-item">'
			+'<div class="form-group">'
				+'<label class="col-sm-2 control-label">Name</label>'
				+'<div class="col-sm-10">'
					+'<input class="form-control" id="inputContactName" name="inputContactName'+new_i+'" value=""/>'
				+'</div>'
			+'</div>'
			+'<div class="form-group">'
				+'<label class="col-sm-2 control-label">Contact Type</label>'
				+'<div class="col-sm-10">'
+'					'
					+'<label class="radio-inline">'
					  +'<input type="radio" name="inputContactType'+new_i+'[]" id="inlineRadio1" value="phone"> phone'
					+'</label>'
					+'<label class="radio-inline">'
					  +'<input type="radio" name="inputContactType'+new_i+'[]" id="inlineRadio2" value="SMS" checked > SMS'
					+'</label>'
				+'</div>'
			+'</div>'
			+'<div class="form-group">'
				+'<label for="inputPhone" class="col-sm-2 control-label">Phone Number</label>'
				+'<div class="col-sm-10">'
					+'<input type="phone" class="form-control" id="inputPhone" name="inputContactPhone'+new_i+'" value="">'
				+'</div>'
			+'</div>'
			+'<div class="form-group">'
				+'<label for="inputMessage" class="col-sm-2 control-label">Message</label>'
				+'<div class="col-sm-10">'
					+'<textarea id="inputContactMessage" class="form-control" name="inputContactMessage'+new_i+'"  rows="2" >Hi Mum, Someone has called my Emergency phone number</textarea>'
				+'</div>'
			+'</div>'
			+'<i>Use the "Confirm Changes" button below to submit</i>'
		+'</li>';
		form.find('.contacts-list').append(default_form_html);
	});
	
});

function prep_user_form(form) {
	$('.alert').remove();
	var fullPhoneNum = $('#inputUserPhoneExt').text() + $('#inputUserPhone').val();
	var clone = form.clone();
	clone.find('#inputUserPhone').val(fullPhoneNum);
	return clone;
}
