require 'sinatra'
require 'twilio-ruby'
require 'dotenv'
require 'mongo'

Dotenv.load

include Mongo

account_sid = ENV['TWILIO_ACCT_ID']
auth_token = ENV['TWILIO_AUTH_TOKEN']
$number = ENV['TWILIO_NUMBER']
$client = Twilio::REST::Client.new account_sid, auth_token

$db = Mongo::Client.new(['127.0.0.1:27017'], :database => 'test')

get '/' do
  erb :index
end

get 'api/v1/call/' do

end
