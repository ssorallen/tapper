require "json"
require "rest_client"

require "sinatra"
require "sinatra/config_file"

config_file "credentials.yml"

if !(settings.respond_to?(:username) &&
    settings.respond_to?(:password) &&
    settings.respond_to?(:reviewboard_url))
  abort "Set 'username', 'password', and 'reviewboard_url' in credentials.yml"
end

REVIEWBOARD_API_REQUEST_URL = "#{settings.reviewboard_url}api/review-requests/%i/"

# Matches review comments appended to commit messages and returns the review
# request ID as a string.
#
# Example:
#
#   > commit_message = <<-eos
#     Mock the flow
#
#     Review: https://rb.test.com/r/2222
#   eos
#   > REVIEW_REGEX.match(str)
#   => #<MatchData "Review: https://rb.test.com/r/222" 1:"222">
REVIEW_REGEX = Regexp.new("Review: #{settings.reviewboard_url}r/(\\d+)")

get "/" do
  "OK"
end

post "/commits" do
  data = JSON.parse(request.body.read)

  commits = data["commits"]

  # If there aren't any commits, there is nothing to do
  halt 400 if !commits

  commits.each do |commit|
    match = REVIEW_REGEX.match(commit["message"])

    if match
      review_request_id = match[1].to_i

      resource = RestClient::Resource.new(
        REVIEWBOARD_API_REQUEST_URL % review_request_id,
        settings.username,
        settings.password)
      resource.put({"status" => "submitted"},
        :content_type => "application/json")
    end
  end

  status 200
end
