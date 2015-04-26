require 'sinatra'
require 'twilio-ruby'
require 'dotenv'
require 'mongo'
require 'braintree'
require 'json'
require 'sendgrid-ruby'

enable :sessions

set :server, 'webrick'

Dotenv.load

include Mongo

account_sid = ENV['TWILIO_ACCT_ID']
auth_token  = ENV['TWILIO_AUTH_TOKEN']
$number     = ENV['TWILIO_NUMBER']
$client     = Twilio::REST::Client.new account_sid, auth_token

$db = Mongo::Client.new(ENV['MONGOD_AWS_URI'])

Braintree::Configuration.environment = :sandbox
Braintree::Configuration.merchant_id = ENV['BRAINTREE_MERCHANT_ID']
Braintree::Configuration.public_key = ENV['BRAINTREE_PUBLIC_KEY']
Braintree::Configuration.private_key = ENV['BRAINREE_PRIVATE_KEY']

sendgrid_api_user = ENV['SENDGRID_API_USER']
sendgrid_api_key  = ENV['SENDGRID_API_KEY']
$sendgrid = SendGrid::Client.new(api_user: sendgrid_api_user, api_key: sendgrid_api_key)

def updateMongoDoc( id, field )
	$db[:users].find(id).find_one_and_update( "$set" => field )
end

# not a braintree page, unless we say otherwise
@braintree = false

get '/login' do
	@mode = "login"
	erb :userform
end

post '/login' do
	warn("loginsubmit")
	warn(params)
	
	if params['inputUserPhone'] == "" or params['inputUserPassword'] == ""
		status 400
		"Username/Password empty"
	else 
		# Login user
		res = $db[:users].find({'phone' => params['inputUserPhone']}).to_a
		
		if res.empty? 
			status 400
			"No user with that phone number found"
		elsif res[0]["password"] != params['inputUserPassword']
			status 400
			"Password incorrect"
		else
			loginUser( params['inputUserPhone'] )
			
			status 200
			"LOGIN"
		end
	end
	
end

get '/register' do
	@mode = "register"
	erb :userform
end

def emailNewUser( emailAddr )

	email = SendGrid::Mail.new do |m|
		m.to      = emailAddr
		m.from    = 'EaaS@example.com'
		m.subject = 'Welcome to EaaS'
		m.html    = '<h1>Welcome to EaaS: Emergency as a Service</h1><p>Here at EaaS, your safety is our number one priorty (so much so that we have rushed this app out without sending it to the spell-checkers!).</p><p>Please return to <a href="https://obbattlehack.herokuapp.com/">EaaS</a> to complete your registration</p>'
	end

	$sendgrid.send(email)
end

post '/register' do
	warn("loginsubmit")
	warn(params)
	
	if params['inputUserPhone'] == "" or params['inputUserPassword'] == "" or params['inputUserEmail'] == ""
		status 400
		"Username/Password/Email empty"
	else 
		# Login user
		res = $db[:users].find({'phone' => params['inputUserPhone']}).to_a
		if !res.empty? 
			status 400
			"A user with that phone number already exists"
		else
			$db[:users].insert_one(
				{
					:phone => params['inputUserPhone'],
					:email => params['inputUserEmail'],
					:password => params['inputUserPassword'],
					:contacts =>[],
					:twilio_number => "N/A"
				}
			);
			loginUser( params['inputUserPhone'] )
			session['user_phone'] = params['inputUserPhone']

			emailNewUser( params['inputUserEmail'] )

			status 200
			"REGISTERED SUCCESSFULLY #{params}"
		end
	end
	
end

get '/logout' do
	warn("logout")
	warn(params)
	
	logoutUser()
	redirect '/login'
end

def loginUser( phone )
	session["loggedInPhone"] = phone
	warn(session["loggedInPhone"])
end

def logoutUser()
	session["loggedInPhone"] = ""
end

get '/' do
	if !session['loggedInPhone'] || session["loggedInPhone"] == ""
		redirect '/login'
	else
		res = $db[:users].find({'phone' => session["loggedInPhone"]}).to_a
		# If no user with that phone number in the DB, go to error page
		if res.empty?
			warn("no user found for phone #{session["loggedInPhone"]}")
			
			redirect '/login'
		else
			# TODO: if user has not paid, redirect to payment page

			@user = res[0]
		end
		erb :home
	end
end


post '/' do
	warn("Doing contacts")
	warn(params)
	#validate contacts
	max = params["inputNumIncrem"].to_i
	i = 0
	contacts = []
	while i < max do
		warn("doing #{i}")
		i_str = i.to_s
		if params.include?("inputContactName"+i_str) 
			if params["inputContactName"+i_str] != "" and
				!params["inputContactType"+i_str].empty? and
				params["inputContactPhone"+i_str] != "" and
				params["inputContactMessage"+i_str] != ""
			
				contact = {
					:name => params["inputContactName"+i_str], 
					:type => params["inputContactType"+i_str][0], 
					:phone => params["inputContactPhone"+i_str], 
					:message => params["inputContactMessage"+i_str], 
					:active => 1
				}
				
				contacts << contact
				
			else
				status 400
				"One of the contacts had a missing field"
			end
		else
			warn(i_str +"wasnt found")
		end
		# increment
		i+=1
	end
	
	warn(contacts)
	#delete old contacts
	#add new contacts
	result = $db[:users]
		.find(:phone => session["loggedInPhone"])
		.find_one_and_update('$set' => { :contacts => contacts })

	status 200
	"Updated contacts correctly"
end



get '/braintree_init' do
	erb :braintree_init
end

get '/braintree_test' do
	@user_phone = session['user_phone']
	@braintree = true

	# Find the user in the DB. Assume user phone number is unique
	res = $db[:users].find({'phone' => @user_phone}).to_a

	# If no user with that phone number in the DB, go to error page
	if res.empty?
		session["error_code"]    = "DB404"
		session["error_message"] = "No user in the DB for phone number #{@user_phone}"

		redirect '/braintree_error'
	end

	warn "Does this customer have a braintree_customer_id?"
	warn "res.inspect: #{res.inspect}"
	# Does this user have a Braintree customer?
	if res[0].include? 'braintree_customer_id'
		a_customer_id  = res[0]['braintree_customer_id']

		warn "Customer already has braintree_customer_id"
	else
		warn "Customer has no braintree_customer_id"

		# They shouldn't have if they're new, so create one, with an email address and phone number, and get their customer_id
		result = Braintree::Customer.create(
			:email => res[0]['email'],
			:phone => res[0]['phone']
		)
		if result.success?
			a_customer_id = result.customer.id
			warn "Sucessfully added a customer. ID: #{a_customer_id}"

			# Update db document with _id : res[0]['_id']
			#$db[:users].find(:_id => res[0]['_id']).find_one_and_update( "$set" => { :test_col_3 => "bar" } )

			updateMongoDoc( {:_id => res[0]['_id']}, { :braintree_customer_id => result.customer.id } )

			#db.users.update( {_id: ObjectId("553bcdcdf4356848e62008d8")}, {$set: { test_col : "foo" }} )
		else
			result.errors.each do |error|
				warn "error.code:      #{error.code}"
				warn "error.message:   #{error.message}"

				session["error_code"]    = error.code
				session["error_message"] = error.message
			end
			redirect '/braintree_error'
		end
	end

	# For now, use a placeholder
	@client_token = Braintree::ClientToken.generate(
		:customer_id => a_customer_id
	)
	erb :braintree_test
end

post "/checkout_test" do
	user_phone = session['user_phone']
	warn("user phone: #{user_phone}")

	# Find the user in the DB. Assume user phone number is unique
	res = $db[:users].find({'phone' => user_phone}).to_a

	# If no user with that phone number in the DB, go to error page
	if res.empty?
		session["error_code"]    = "DB404"
		session["error_message"] = "No user in the DB for phone number #{user_phone}"

		redirect '/braintree_error'
	end

	warn "res: #{res.inspect}"





	nonce = params[:payment_method_nonce]

	result = Braintree::Transaction.sale(
		:amount => "10.00",
		:payment_method_nonce => nonce,
		:options => {
			:submit_for_settlement     => true,
			:store_in_vault_on_success => true
		}
	)

	# check whether this was sucessful
	warn "nonce:           #{nonce}"
	warn "result:          #{result}"
	warn "result.inspect:  #{result.inspect}"
	warn "result.success?: #{result.success?}"

	# Assume no errors, until we've checked.
	errors                   = ""
	session["error_code"]    = ""
	session["error_message"] = ""

	if ! result.success?
		# Yes, I know this could technically return multiple errors, but for now I'll just spit out the last error.
		result.errors.each do |error|
			warn "error.code:      #{error.code}"
			warn "error.message:   #{error.message}"

			session["error_code"]    = error.code
			session["error_message"] = error.message
		end

		redirect '/braintree_error'
	end


	if result.success?
		#TODO: update DB: this customer has paid

		begin
			numbers = $client.account.available_phone_numbers.get("GB").mobile.list(:contains => "+447")
			@phone_number = numbers[0].phone_number
			$client.account.incoming_phone_numbers.create(:phone_number => @phone_number)
			updateMongoDoc({:_id => res[0]['_id']}, {"twilio_number" => @phone_number})
		rescue
			warn("Can't purchase a new number...")
			# Who they gonna call....?
			@phone_number = "+13115552368"
			updateMongoDoc({:_id => res[0]['_id']}, {"twilio_number" => @phone_number})
		end

		redirect '/braintree_success'
	end
end

get "/braintree_error" do
	@error_code    = session["error_code"]
	@error_message = session["error_message"]

	erb :braintree_error
end

get "/braintree_success" do
	erb :braintree_success
end

get '/api/v1/test/msg' do
	message = $client.account.messages.create(
		:body => "Success!",
		:to   => params["number"],
		:from => $number)
	message.sid
end

get '/api/v1/test/call' do
	call = $client.account.calls.create(
		:url => 'http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient',
		:to   => params["number"],
		:from => $number)
	call.sid
end

get '/api/v1/call/incoming' do
	res = $db[:users].find({'twilio_number' => params['To']}).to_a
	message = ""
	dial = ""

	if res.empty?
		warn("Couldn't find any records for " + params['To'])
		message = "This number has not been recognised, and no help is coming. Sorry."
	else
		Thread.new do 
			# We have to only have one... right?
			res[0]["contacts"].each do |c|
				if c["active"] == 1 && c["type"] == "SMS"
					message = $client.account.messages.create(
						:body => c["message"],
						:to   => c["phone"],
						:from => $number 
					)
					warn("Sent message " + message.sid + " to " + c["name"])
				end
			end
		end

		res[0]["contacts"].each do |c|
			if dial == ""
				if c["active"] == 1 && c["type"] == "Phone"
					dial = c["phone"]
					dialee = c["name"]
					warn("Going to call " + c["name"])
				end
			end
		end

		if dial == ""
			message = "Your call has been registered, and the person's contacts have been notified. Thank you"
		else
			message = "Your call has been registered, you will now be put through to this person's emergency contact. Please hold"
		end
	end

	Twilio::TwiML::Response.new do |r|
		r.Say "#{message}"
		if dial != ""
			r.Dial dial
		end
	end.text
end

