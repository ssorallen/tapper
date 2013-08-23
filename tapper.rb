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

def commit_description(commit)
  committer = commit["committer"]

  <<-eos
Closed by #{committer["name"]} <#{committer["email"]}> via Tapper with
commit #{commit["id"]}[1].

[1] #{commit["url"]}
  eos
end

get "/" do
  "OK"
end

post "/commits" do
  if settings.respond_to?(:secret_key) &&
      settings.secret_key != params[:secret_key]
    halt 403, 'Invalid secret key.'
  end

  data = JSON.parse(params[:payload])

  # If this request has no payload or is otherwise malformed, bail.
  halt 400 if !data

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

      description = commit_description(commit)
      $stdout.puts(description)

      resource.put(
        {
          "description" => description,
          "status" => "submitted"
        },
        :content_type => "application/json")
    end
  end

  status 200
end
