require 'sinatra'
require 'twilio-ruby'
require 'dotenv'
require 'mongo'
require 'braintree'

enable :sessions

Dotenv.load

include Mongo

account_sid = ENV['TWILIO_ACCT_ID']
auth_token  = ENV['TWILIO_AUTH_TOKEN']
$number     = ENV['TWILIO_NUMBER']
$client     = Twilio::REST::Client.new account_sid, auth_token

$db = Mongo::Client.new(ENV['MONGOLAB_URI'])

Braintree::Configuration.environment = :sandbox
Braintree::Configuration.merchant_id = ENV['BRAINTREE_MERCHANT_ID']
Braintree::Configuration.public_key = ENV['BRAINTREE_PUBLIC_KEY']
Braintree::Configuration.private_key = ENV['BRAINREE_PRIVATE_KEY']

get '/' do
	erb :index
end

get '/braintree_test' do
	@client_token = Braintree::ClientToken.generate()
	erb :braintree_test
end

post "/checkout_test" do
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
		:to   => params["From"],
		:from => $number)
	message.sid
end

get '/api/v1/test/call' do
	call = $client.account.calls.create(
		:url => 'http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient',
		:to   => params["From"],
		:from => $number)
	call.sid
end

get '/api/v1/call/incoming' do
	res = $db[:users].find({'phone' => params['From']}).to_a
	message = ""

	if res.empty?
		warn("Couldn't find any records for " + params['From'])
		message = "This number has not been recognised, and no help is coming. Sorry."
	else
		Thread.new do 
			# We have to only have one... right?
			res[0]["contacts"].each do |c|
				if c["active"] == 1
					message = $client.account.messages.create(
						:body => c["message"],
						:to   => c["phone"],
						:from => $number 
					)
					warn("Sent message " + message.sid + " to " + c["name"])
				end
			end
		end

		message = 'Ice, Ice, Baby'
	end

	Twilio::TwiML::Response.new do |r|
		r.Say "#{message}"
	end.text
end
