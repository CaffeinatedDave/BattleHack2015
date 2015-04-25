require 'sinatra'
require 'twilio-ruby'
require 'dotenv'
require 'mongo'
require 'braintree'

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

	# Test the different example nonces (Braintree::Test::Nonce::<test_nonce>)
	#	nonce                              result.success?
	#
	#	Transactable                       true
	#	Consumed                           .
	#	fake-apple-pay-amex-nonce          .
	#	fake-apple-pay-visa-nonce          .
	#	fake-apple-pay-mastercard-nonce    .
	#	PayPalOneTimePayment               .
	#	PayPalFuturePayment                .
	#nonce = Braintree::Test::Nonce::Consumed

	result = Braintree::Transaction.sale(
		:amount => "10.00",
		:payment_method_nonce => nonce,
		:options => {
			:submit_for_settlement     => true,
			:store_in_vault_on_success => true
		}
	)

	errors = ""
	if ! result.success?
		result.errors.each do |error|
			puts error.code
			puts error.message
		end
	end

	# check whether this was sucessful
	warn "nonce:           #{nonce}"
	warn "result:          #{result}"
	warn "result.inspect:  #{result.inspect}"
	warn "result.success?: #{result.success?}"


	if result.success?
		#TODO: update DB: this customer has paid

		redirect '/braintree_success'
	end
end

get "/braintree_success" do
	erb :braintree_success
end

get '/api/v1/test/msg/:number' do
	message = $client.account.messages.create(
		:body => "Success!",
		:to   => params[:number],
		:from => $number)
	message.sid
end

get '/api/v1/test/call/:number' do
	call = $client.account.calls.create(
		:url => 'http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient',
		:to   => params[:number],
		:from => $number)
	call.sid
end

get '/api/v1/call/incoming' do
	res = $db[:users].find({'phone' => params['From']})

	Thread.new do 
		res.each do |r|
			r["contacts"].each do |c|
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
	end

	Twilio::TwiML::Response.new do |r|
		r.Say 'Ice, Ice, Baby'
	end.text
end
